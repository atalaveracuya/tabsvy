*********************************************************************************
*   EJEMPLO DE USO: tabsvy / tabsvyexport                                       *
*   Cuatro casos de uso tipicos, para validar el patron antes de migrar una      *
*   bateria completa de cuadros a este flujo.                                   *
*                                                                                 *
*   IMPORTANTE: corre esto sobre una COPIA de tu plantilla real, y compara       *
*   celda a celda contra tu proceso actual antes de reemplazarlo en produccion.  *
*********************************************************************************

clear all
set more off
set linesize 255

* ado files (ajusta la ruta si no estan en tu PERSONAL/ado/plus)
adopath ++ "RUTA_A_LA_CARPETA_DONDE_GUARDES_tabsvy.ado_Y_tabsvyexport.ado"

global base    "C:\ruta\a\tu\base"
global output  "C:\ruta\a\tu\plantilla"
global YEARS8  "2014 2015 2016 2017 2018 2019 2020 2022"    // orden real de ANIO_ 1..8


*===============================================================================*
* Cuadro 1: cuadro "simple" -- una variable, sin dimension sexo, sin loop
*===============================================================================*
use "$base\base_indicador1", clear
* ... aqui va tu preparacion comun (recode REGION, encode NOMBREDD_, CCDD,
*     ANIO_, CONGLO_ANIO/ESTRATO_ANIO, etc.) -- no cambia con tabsvy ...
svyset CONGLO_ANIO [pweight=FACTORFINAL], strata(ESTRATO_ANIO) vce(linearized) singleunit(certainty)
gen NACIONAL = 1

* indicador tiene 4 grupos (1..4) -> se declara de arranque con expectcats()
tabsvy, estcmd("svy linear: proportion indicador if omision1==0") ///
    varname(indicador) years(`YEARS8') expectcats(1 2 3 4) frame(F1) replace

* catorder(1 2 3 4): las 4 filas del bloque van en ese mismo orden de codigo
tabsvyexport, frame(F1) using("$output/mi_plantilla.xlsx") ///
    sheet("Cuadro1") idvars(var) catorder(1 2 3 4) ///
    cellnac(D11) cellreg(D14) celldep(D21)


*===============================================================================*
* Cuadro 2: misma variable, pero con dimension SEXO en el over()
*===============================================================================*
use "$base\base_indicador1", clear
* ... preparacion comun ...
svyset CONGLO_ANIO [pweight=FACTORFINAL], strata(ESTRATO_ANIO) vce(linearized) singleunit(certainty)
gen NACIONAL = 1

tabsvy, estcmd("svy linear: proportion indicador if omision1==0 & omision2==0") ///
    varname(indicador) years(`YEARS8') sexovar(sexo) expectcats(1 2 3 4) frame(F2) replace

* catorder() ordena por defecto la ULTIMA variable de idvars ("var"); SEXO
* se mantiene ascendente (1=Hombre antes que 2=Mujer, por ejemplo) porque
* no es catvar() -- si tu codificacion de sexo viene al reves, agrega
* catvar(SEXO) y tu propio catorder() para esa variable
tabsvyexport, frame(F2) using("$output/mi_plantilla.xlsx") ///
    sheet("Cuadro2") idvars(SEXO var) catorder(1 2 3 4) ///
    cellnac(E11) cellreg(E20) celldep(E45)


*===============================================================================*
* Cuadro 3: loop de 6 variables de un mismo bloque tematico, cada una con su
* propia condicion de omision, quedandose solo con la categoria "1" y
* acumulando por TIPO
*===============================================================================*
use "$base\base_variables_tipo", clear
keep if FILTRO_APLICABLE == 1
local i = 1
while `i' <= 6 {
    recode var`i' (miss=2)
    gen OMISION_`i' = (var`i' == 9)
    local i = `i' + 1
}
recode varA varB varC varD varE varF (2=0)
* ... preparacion comun ...
svyset CONGLO_ANIO [pweight=FACTORFINAL], strata(ESTRATO_ANIO) vce(linearized) singleunit(certainty)
gen NACIONAL = 1

local VARLIST varA varB varC varD varE varF
local nvar : word count `VARLIST'
forvalues vv = 1/`nvar' {
    local v : word `vv' of `VARLIST'
    * var`vv' es dicotomica 0/1 tras el recode de arriba -> expectcats(0 1)
    tabsvy, estcmd("svy linear: proportion `v' if OMISION_`vv'==0") ///
        varname(`v') years(`YEARS8') expectcats(0 1) keepcat(1) tipo(`vv') frame(F3) ///
        `=cond(`vv'==1, "replace", "")'
}

* catorder aqui aplica sobre TIPO (1..6, el orden en que se corrio el loop)
tabsvyexport, frame(F3) using("$output/mi_plantilla.xlsx") ///
    sheet("Cuadro3") idvars(TIPO) catorder(1 2 3 4 5 6) ///
    cellnac(D11) cellreg(D18) celldep(D37)


*===============================================================================*
* Cuadro 4: otro cuadro simple, variable distinta -- ilustra el caso de una
* variable codificada al reves de lo que espera la plantilla
*===============================================================================*
use "$base\base_variable2", clear
recode variable2 (0=2)
svyset CONGLO_ANIO [pweight=FACTORFINAL], strata(ESTRATO_ANIO) vce(linearized) singleunit(certainty)
gen NACIONAL = 1

* variable2 recodificada arriba a 1/2 -> expectcats(1 2)
tabsvy, estcmd("svy linear: proportion variable2") ///
    varname(variable2) years(`YEARS8') expectcats(1 2) frame(F4) replace

* IMPORTANTE: revisa primero el value label real de variable2 antes de fijar
* catorder() -- no asumas que el orden de la plantilla coincide con el orden
* ascendente del codigo numerico:
*   . label list variable2
* Si 1="Si" y 2="No" (y asi lo espera la plantilla), usa catorder(1 2).
* Si en cambio 1="No" y 2="Si", usa catorder(2 1) -- eso, y NADA MAS, es
* lo que corrige el orden; no hay que tocar la estimacion ni el reshape.
tabsvyexport, frame(F4) using("$output/mi_plantilla.xlsx") ///
    sheet("Cuadro4") idvars(var) catorder(1 2) ///
    cellnac(D11) cellreg(D14) celldep(D21)


*===============================================================================*
* COMPARACION SUGERIDA
*===============================================================================*
* 1. Corre esto sobre una copia de tu plantilla ("mi_plantilla - TEST.xlsx").
* 2. Corre tu proceso actual sobre otra copia ("mi_plantilla - ORIGINAL.xlsx").
* 3. Compara hoja por hoja las celdas exportadas -- deben coincidir
*    exactamente (ESTIMA y REF_).
* 4. Si coincide en estos 4 casos (simple / sexo / loop-tipo / codificacion
*    invertida), el patron esta validado y puedes migrar el resto de tus
*    cuadros, reemplazando cada uno por dos llamadas cortas.
