*! tabsvyexport.ado v1.2  21jul2026  Andres Talavera Cuya - INEI / DNCE
*
*  Toma lo acumulado por tabsvy (frame con NIVEL CAIDA [SEXO] [var|TIPO]
*  ESTIMA ANIO REF_ CV ...), lo pasa a formato ancho (un bloque de
*  columnas ESTIMA/REF_ por anio) y lo exporta a la plantilla Excel,
*  en las celdas de inicio que corresponden a cada NIVEL.
*
*  v1.2: hace un keep interno de solo NIVEL CAIDA idvars ESTIMA ANIO REF_
*  antes del reshape. El frame que deja tabsvy trae ademas las columnas
*  crudas de parmby (parm, parmseq, dof, t, p, ERROR_ST, LIM_INF, LIM_SUP,
*  es_1, N_SIN_PON, N_PONDERA, CV), que varian por anio: si se dejan
*  sueltas, "reshape wide" truena con "variable X not constant within...".
*  Ya NO hace falta que el usuario haga ese keep a mano antes de llamar a
*  tabsvyexport.
*
*  v1.1: el orden de las categorias (ej. fila "Si" antes que fila "No") ya
*  NO se infiere por orden ascendente del codigo numerico -- eso fallaba en
*  silencio cuando una variable venia codificada al reves (ej. 1=No, 2=Si).
*  Ahora se declara explicitamente con catorder(), y si no coincide con lo
*  que hay en los datos el comando se detiene con un error (no exporta mal).
*
*  USO (cuadro simple, sin sexo; tenencia_var = 1 "Si" 2 "No" en la plantilla):
*
*      tabsvyexport, frame(F1) using("$output/mi_plantilla.xlsx")   ///
*          sheet("Cuadro1") idvars(var) catorder(1 2)            ///
*          cellnac(D11) cellreg(D14) celldep(D21)
*
*  USO (cuadro con dimension sexo -> agrega SEXO a idvars; catorder aplica
*  sobre la ultima variable de idvars por defecto, aqui "var"):
*
*      tabsvyexport, frame(F2) using("$output/mi_plantilla.xlsx")    ///
*          sheet("Cuadro2") idvars(SEXO var) catorder(1 2)   ///
*          cellnac(E11) cellreg(E20) celldep(E45)
*
*  USO (cuadro con loop de variables tipo bloque tematico -> idvars(TIPO), el
*  orden de TIPO es el orden real en que se llamo a tabsvy):
*
*      tabsvyexport, frame(F3) using("$output/mi_plantilla.xlsx")    ///
*          sheet("Cuadro3") idvars(TIPO) catorder(1 2 3 4 5 6) ///
*          cellnac(D11) cellreg(D18) celldep(D37)

capture program drop tabsvyexport
program define tabsvyexport
    version 17

    syntax , USING(string) SHEET(string) IDVARS(string)          ///
        CELLNAC(string) CELLREG(string) CELLDEP(string)          ///
        [                                                        ///
        CATORDER(numlist)    /// orden EXPLICITO de filas para la variable
                              /// categorica (ver catvar()). Ej: catorder(1 2)
                              /// = primero categoria 1, luego categoria 2,
                              /// SIN IMPORTAR cual sea el codigo mas chico.
                              /// Muy recomendado: sin esto, el orden se
                              /// infiere ascendente y puede salir al reves.
        CATVAR(name)          /// cual variable de idvars ordena catorder().
                              /// Por defecto, la ULTIMA variable de idvars
                              /// (convencion: var/TIPO va al final)
        FRAME(name)          /// frame acumulador a exportar. Def: ACUM_ALL
        MULT(real 100)       /// factor de escala de ESTIMA (100 = pasa a %)
        ]

    if "`frame'" == "" local frame "ACUM_ALL"

    * --- variable categorica sobre la que aplica catorder() ---
    if "`catvar'" == "" {
        local nidv : word count `idvars'
        local catvar : word `nidv' of `idvars'
    }
    local catvar_en_idvars = 0
    foreach v of local idvars {
        if "`v'" == "`catvar'" local catvar_en_idvars = 1
    }
    if !`catvar_en_idvars' {
        di as error "tabsvyexport: catvar(`catvar') debe ser una de las variables listadas en idvars(`idvars')"
        exit 198
    }

    frame `frame' {
        preserve

        * --- diagnostico: categorias realmente presentes en los datos,
        *     SIEMPRE se muestra para que puedas verificarlas contra la
        *     plantilla antes (o en vez) de fijar catorder() ---
        quietly levelsof `catvar', local(catlist_datos)
        di as text "tabsvyexport: categorias de `catvar' presentes en los datos: " as result "`catlist_datos'"

        * el frame que deja tabsvy trae ademas columnas crudas de parmby
        * (parm, parmseq, ERROR_ST, t, p, LIM_INF, LIM_SUP, N_SIN_PON,
        * N_PONDERA, CV, etc.) que varian por ANIO y no entran al reshape;
        * si no se descartan aca, "reshape wide" truena con
        * "variable X not constant within NIVEL CAIDA ..."
        keep NIVEL CAIDA `idvars' ESTIMA REF_ ANIO

        replace ESTIMA = ESTIMA * `mult'      // la plantilla muestra 16,3 no .163

        * posicion del anio (1..k) en vez del anio calendario, evita
        * depender de que la plantilla tenga exactamente esos anios
        egen byte anio_pos = group(ANIO)
        drop ANIO

        * NIVEL siempre entra en el i() del reshape, junto con lo que
        * venga en idvars (CAIDA, [SEXO], var|TIPO)
        reshape wide ESTIMA REF_, i(NIVEL CAIDA `idvars') j(anio_pos)

        gen byte orden_nivel = .
        replace orden_nivel = 1 if NIVEL == "NACIONAL"
        replace orden_nivel = 2 if NIVEL == "REGION"
        replace orden_nivel = 3 if NIVEL == "NOMBREDD"
        assert !missing(orden_nivel)

        * --- orden de filas dentro de cada bloque ---
        if "`catorder'" != "" {
            * orden EXPLICITO: catrank = posicion de cada codigo en catorder()
            tempvar catrank
            gen long `catrank' = .
            local k = 0
            foreach cv of numlist `catorder' {
                local k = `k' + 1
                replace `catrank' = `k' if `catvar' == `cv'
            }
            capture assert !missing(`catrank')
            if _rc {
                di as error "tabsvyexport: hay valores de `catvar' que NO estan en catorder(`catorder')."
                di as error "  Revise con: levelsof `catvar'  -- y complete catorder() con TODOS los codigos."
                exit 498
            }

            local sortvars ""
            foreach v of local idvars {
                if "`v'" == "`catvar'" local sortvars "`sortvars' `catrank'"
                else                   local sortvars "`sortvars' `v'"
            }
            sort orden_nivel CAIDA `sortvars'
        }
        else {
            * sin catorder(): orden ascendente por defecto (comportamiento
            * v1.0). Se advierte porque es el supuesto que causo el error
            * de filas invertidas -- mejor practica es siempre fijar catorder()
            di as error "tabsvyexport: ADVERTENCIA - no especificaste catorder()."
            di as error "  El orden de `catvar' se define por su codigo numerico ascendente."
            di as error "  Verifica que coincida con el orden de filas de la plantilla (ej. Si/No)."
            di as error "  Mejor practica: agrega la opcion catorder(), ej. catorder(1 2)."
            sort orden_nivel CAIDA `idvars'
        }
        drop orden_nivel

        * numero de anios detectados a partir de las columnas ESTIMA#
        unab estimavars : ESTIMA*
        local nyears : word count `estimavars'

        local ordvars ""
        forvalues yy = 1/`nyears' {
            local ordvars "`ordvars' ESTIMA`yy' REF_`yy'"
        }
        order `ordvars'

        export excel `ordvars' if NIVEL=="NACIONAL" ///
            using "`using'", sheet("`sheet'", modify) cell(`cellnac') keepcellfmt

        export excel `ordvars' if NIVEL=="REGION" ///
            using "`using'", sheet("`sheet'", modify) cell(`cellreg') keepcellfmt

        export excel `ordvars' if NIVEL=="NOMBREDD" ///
            using "`using'", sheet("`sheet'", modify) cell(`celldep') keepcellfmt

        restore
    }

    di as text "tabsvyexport: exportado a hoja " as result "`sheet'" ///
        as text " (" as result "`using'" as text ")"
end
