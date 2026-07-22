*! tabsvy.ado v1.3  22jul2026  Andres Talavera Cuya - INEI / DNCE
*
*  Motor generico de estimacion con encuestas complejas.
*  Generaliza el bloque que se repite, cuadro tras cuadro, en cualquier
*  do-file de indicadores estadisticos:
*
*      foreach a in NACIONAL REGION NOMBREDD_ {
*          svy linear: proportion VAR [if cond], over(`a' [SEXOVAR] ANIO_)
*          parmby ...
*          -> ANIO por regex, renombres, CV, REF, NIVEL/CAIDA/[SEXO]/var
*          -> se acumula en un frame
*      }
*
*  v1.3: years() ya NO asume que ANIO_ va 1..k sin huecos. tabsvy ahora lee
*  con levelsof que codigos tiene REALMENTE ANIO_ en los datos actuales, los
*  ordena ascendente, y los mapea uno a uno contra years() (que debe traer
*  la misma cantidad de anios, en orden cronologico). Esto es lo que
*  soluciona el caso de variables que faltan en algun anio de la ronda
*  global (ej. 2014 o 2020): ya no hay que averiguar "el codigo real es
*  2,3,4,5,6,8"; alcanza con pasar los anios reales de ESTA base, en orden.
*  Si la cantidad de anios en years() no calza con la cantidad de codigos
*  distintos que trae ANIO_, tabsvy se detiene con un mensaje claro (en vez
*  de desalinear silenciosamente los anios).
*
*  v1.1: agrega expectcats() para declarar "de arranque" que categorias
*  debe tener VARNAME (ej. 1 2 para una dicotomica). Si la codificacion real
*  no calza, tabsvy se detiene ahi mismo en vez de seguir y exportar mal
*  (ver tambien catorder() en tabsvyexport, para fijar el ORDEN de filas).
*
*  USO TIPICO (un cuadro "simple", sin sexo, sin loop de variables; se
*  declara de entrada que tenencia_var solo debe tomar los valores 1 y 2):
*
*      tabsvy, estcmd("svy linear: proportion indicador if omision1==0") ///
*          varname(indicador) years(2014 2015 2016 2017 2018 2019 2020 2022)  ///
*          expectcats(1 2) frame(F1) replace
*
*  USO CUANDO A LA VARIABLE LE FALTAN ANIOS DE LA RONDA GLOBAL (ej. no se
*  pregunto en 2014 ni en 2020): simplemente pasa los anios que SI tiene
*  esta base, en orden cronologico -- tabsvy detecta el resto solo:
*
*      tabsvy, estcmd("svy linear: proportion indicador") ///
*          varname(indicador) years(2015 2016 2017 2018 2019 2022) ///
*          expectcats(1 2) frame(F1) replace
*
*  USO CON DIMENSION SEXO (agrega sexo al over() y a las columnas de salida):
*
*      tabsvy, estcmd("svy linear: proportion indicador if omision1==0 & omision2==0") ///
*          varname(indicador) years(...) sexovar(sexo) frame(F2) replace
*
*  USO CON LOOP DE VARIABLES (tipo bloque tematico: 6 variables, se queda solo con
*  la categoria "1" de cada una y las apila con una etiqueta TIPO 1..6):
*
*      local VARLIST varA varB varC varD varE varF
*      local nvar : word count `VARLIST'
*      forvalues vv = 1/`nvar' {
*          local v : word `vv' of `VARLIST'
*          tabsvy, estcmd("svy linear: proportion `v' if OMISION_`vv'==0") ///
*              varname(`v') years(...) keepcat(1) tipo(`vv') frame(F3) ///
*              `=cond(`vv'==1,"replace","")'
*      }
*
*  Requiere: parmby (SSC), frameappend (SSC), y que el usuario ya haya hecho
*  el svyset del diseño complejo (CONGLO_ANIO / ESTRATO_ANIO / FACTORFINAL)
*  y la preparacion comun (REGION, NOMBREDD_, ANIO_, NACIONAL=1, etc.), tal
*  como se hace al inicio de cada seccion de tu do-file original.

capture program drop tabsvy
program define tabsvy
    version 17

    syntax , ESTCMD(string) VARNAME(string) YEARS(numlist ascending)      ///
        [                                                                 ///
        CAIDA(string)        /// niveles de agregacion. Def: "NACIONAL REGION NOMBREDD_"
        SEXOVAR(string)      /// variable extra en over() (ej. sexo). Opcional
        KEEPCAT(string)      /// si se da, se queda solo con esta categoria de VARNAME
                              /// (uso tipico: loops tipo bloque tematico). Deja la
                              /// identificacion "var" a cargo de TIPO() en su lugar
        EXPECTCATS(numlist)  /// categorias que DEBERIA tener VARNAME (ej. 1 2 para
                              /// una dicotomica). Si las categorias observadas en
                              /// los datos no calzan EXACTO con esta lista, tabsvy
                              /// se detiene ahi mismo -- mejor detectar un cambio
                              /// de codificacion al estimar que al exportar
        TIPO(integer 0)      /// etiqueta numerica para acumular multiples variables
        FRAME(name)          /// frame acumulador. Def: ACUM_ALL
        THRESHOLD(real 15)   /// umbral de CV(%) para marcar "a/"
        REPLACE               /// si se especifica, reinicia el frame acumulador
        ]

    if "`caida'"  == "" local caida "NACIONAL REGION NOMBREDD_"
    if "`frame'"  == "" local frame "ACUM_ALL"

    * ---------------------------------------------------------------
    * 1. Prepara el frame acumulador
    * ---------------------------------------------------------------
    if "`replace'" != "" {
        capture frame drop `frame'
    }
    capture confirm frame `frame'
    if _rc {
        frame create `frame'
    }

    local nyears : word count `years'

    * ---------------------------------------------------------------
    * 1b. Detecta los codigos REALES de ANIO_ presentes en los datos
    *     actuales (en vez de asumir que van 1..n sin huecos). Esto es
    *     lo que permite que years() sea simplemente la lista de anios
    *     reales de esta base, en orden cronologico, sin que el usuario
    *     tenga que saber si ANIO_ salta algun codigo (ej. porque a esta
    *     variable puntual le faltan 2014 o 2020 en la ronda global).
    * ---------------------------------------------------------------
    capture confirm variable ANIO_
    if _rc {
        di as error "tabsvy: no se encontro la variable ANIO_ en los datos actuales."
        exit 111
    }
    quietly levelsof ANIO_, local(codigos_anio)
    local ncodigos : word count `codigos_anio'
    if `ncodigos' != `nyears' {
        di as error "tabsvy: years() tiene `nyears' elemento(s) pero ANIO_ tiene `ncodigos' codigo(s) distinto(s) en los datos actuales (`codigos_anio')."
        di as error "  Deben coincidir uno a uno: el codigo mas chico de ANIO_ -> el primer anio de years(), en orden cronologico."
        di as error "  Revise con: tab ANIO_, nolabel"
        exit 198
    }

    * ---------------------------------------------------------------
    * 2. Un svy + parmby por cada nivel de agregacion (NACIONAL/REGION/...)
    * ---------------------------------------------------------------
    foreach a of local caida {

        local overlist "`a'"
        if "`sexovar'" != "" local overlist "`overlist' `sexovar'"
        local overlist "`overlist' ANIO_"

        local cmd `"`estcmd', over(`overlist')"'

        capture frame drop PARM_TMP
        parmby "`cmd'", frame(PARM_TMP, replace) ev(_N _N_subp) es(N)

        frame PARM_TMP {

            capture confirm variable estimate
            if _rc {
                di as error "tabsvy: parmby no devolvio 'estimate'. Revise el comando:"
                di as error `"    `cmd'"'
                exit 498
            }

            * --- ANIO segun el codigo REAL que ocupa en ANIO_, no la
            *     posicion asumida 1..k. codigos_anio ya viene ordenado
            *     ascendente (levelsof), igual que years() debe estar. ---
            gen ANIO = .
            forvalues yy = 1/`nyears' {
                local code : word `yy' of `codigos_anio'
                local yval : word `yy' of `years'
                replace ANIO = `yval' if regexm(parm, "`code'\.ANIO_")
            }
            assert !missing(ANIO)

            rename estimate  ESTIMA
            rename stderr    ERROR_ST
            rename min95     LIM_INF
            rename max95     LIM_SUP
            capture rename ev_1 N_SIN_PON
            capture rename ev_2 N_PONDERA

            gen double CV = (ERROR_ST / ESTIMA) * 100

            * --- si se pide, filtra una unica categoria de VARNAME ---
            if "`keepcat'" != "" {
                keep if strpos(parm, "`keepcat'.`varname'@") == 1
            }

            if `tipo' != 0 {
                gen byte TIPO = `tipo'
            }

            * --- NIVEL / CAIDA / [SEXO] a partir del string parm ---
            * Patron sin sexo:  N.var@C.NIVEL_#A.ANIO_
            * Patron con sexo:  N.var@C.NIVEL_#S.SEXOVAR#A.ANIO_
            capture drop NIVEL CAIDA_
            gen str12  NIVEL  = ""
            gen double CAIDA_ = .

            if "`sexovar'" == "" {
                replace NIVEL  = regexs(2)       if regexm(parm, "@([0-9]+)\.([A-Z_]+)#")
                replace CAIDA_ = real(regexs(1)) if regexm(parm, "@([0-9]+)\.([A-Z_]+)#")
            }
            else {
                capture drop SEXO
                gen byte SEXO = .
                replace NIVEL  = regexs(2)       ///
                    if regexm(parm, "@([0-9]+)\.([A-Z_]+)#([0-9]+)\.`sexovar'#")
                replace CAIDA_ = real(regexs(1)) ///
                    if regexm(parm, "@([0-9]+)\.([A-Z_]+)#([0-9]+)\.`sexovar'#")
                replace SEXO   = real(regexs(3)) ///
                    if regexm(parm, "@([0-9]+)\.([A-Z_]+)#([0-9]+)\.`sexovar'#")
            }
            replace NIVEL = subinstr(NIVEL, "_", "", .)   // NOMBREDD_ -> NOMBREDD
            assert !missing(NIVEL)
            assert !missing(CAIDA_)
            if "`sexovar'" != "" assert !missing(SEXO)
            rename CAIDA_ CAIDA

            * --- categoria de VARNAME (solo si no se filtro con KEEPCAT) ---
            if "`keepcat'" == "" {
                capture drop var
                gen byte var = real(regexs(1)) if regexm(parm, "^([0-9]+)\.`varname'@")
                assert !missing(var)
            }

            * --- validacion fail-fast: las categorias declaradas "de
            *     arranque" en expectcats() deben coincidir exacto con las
            *     que trae la variable. Si alguien cambio la codificacion
            *     (value label) sin avisar, se corta ACA, no en el export ---
            if "`expectcats'" != "" {
                if "`keepcat'" == "" {
                    quietly levelsof var, local(catlist_obs)
                    local catlist_obs : list sort catlist_obs
                    local catlist_exp : list sort expectcats
                    if "`catlist_obs'" != "`catlist_exp'" {
                        di as error "tabsvy: las categorias observadas de `varname' (`catlist_obs') no coinciden con expectcats(`expectcats')."
                        di as error "  Revise la codificacion (value label) de `varname' antes de seguir."
                        exit 498
                    }
                }
                else {
                    local keepcat_ok : list keepcat in expectcats
                    if !`keepcat_ok' {
                        di as error "tabsvy: keepcat(`keepcat') no esta dentro de expectcats(`expectcats')."
                        exit 498
                    }
                }
            }

            gen str2 REF_ = ""
            replace REF_ = "a/" if CV > `threshold' & CV != .

            frame `frame': frameappend PARM_TMP
        }
        capture frame drop PARM_TMP
    }

    frame `frame' {
        count
        di as text "tabsvy: `frame' acumula ahora " as result r(N) as text " filas (VARNAME=`varname'`=cond("`keepcat'"!="", " KEEPCAT=`keepcat' TIPO=`tipo'", "")')"
    }
end
