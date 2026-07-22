{smcl}
{* *! version 1.0  21jul2026}{...}
{viewerdialog tabsvyexport "dialog tabsvyexport"}{...}
{vieweralsosee "tabsvy" "help tabsvy"}{...}
{title:Title}

{phang}
{bf:tabsvyexport} {hline 2} Reshape y exportacion a plantilla Excel de lo
acumulado por {helpb tabsvy}

{title:Syntax}

{p 8 17 2}
{cmd:tabsvyexport} {cmd:,}
{cmdab:using(}{it:string}{cmd:)}
{cmdab:sheet(}{it:string}{cmd:)}
{cmdab:idvars(}{it:varlist}{cmd:)}
{cmdab:cellnac(}{it:string}{cmd:)}
{cmdab:cellreg(}{it:string}{cmd:)}
{cmdab:celldep(}{it:string}{cmd:)}
[{cmdab:catorder(}{it:numlist}{cmd:)} {cmdab:catvar(}{it:name}{cmd:)} {it:opciones}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Requeridas}
{synopt:{opt using(string)}}ruta completa del archivo Excel plantilla (el
mismo que usa {cmd:export excel ... using}){p_end}
{synopt:{opt sheet(string)}}nombre de la hoja destino dentro de la plantilla{p_end}
{synopt:{opt idvars(varlist)}}variables identificadoras adicionales a
{cmd:NIVEL CAIDA} (que siempre entran). Tipicamente {cmd:var} en un cuadro
simple, {cmd:SEXO var} si hay dimension sexo, o {cmd:TIPO} si se acumulo con
un loop de variables (ver {opt tipo()} en {helpb tabsvy}){p_end}
{synopt:{opt cellnac(string)}}celda de inicio (ej. {cmd:D11}) para el bloque
{cmd:NIVEL=="NACIONAL"}{p_end}
{synopt:{opt cellreg(string)}}celda de inicio para el bloque {cmd:NIVEL=="REGION"}{p_end}
{synopt:{opt celldep(string)}}celda de inicio para el bloque {cmd:NIVEL=="NOMBREDD"}{p_end}

{syntab:Opcionales}
{synopt:{opt catorder(numlist)}}orden {bf:explicito} de filas para la variable
categorica (ver {opt catvar()}). Ej. {cmd:catorder(1 2)} pone primero la fila
del codigo 1 y luego la del codigo 2, sin importar cual codigo sea numericamente
mas chico. {bf:Muy recomendado}: sin esta opcion, el orden se infiere
ascendente por el valor numerico, que es exactamente el supuesto que causa
filas invertidas (ej. "No" apareciendo donde va "Si") cuando la variable no
esta codificada en el orden que espera la plantilla{p_end}
{synopt:{opt catvar(name)}}cual variable de {opt idvars()} ordena
{opt catorder()}. Por defecto, la {bf:ultima} variable listada en
{opt idvars()} (convencion usada por {helpb tabsvy}: {cmd:var} o {cmd:TIPO}
van al final){p_end}
{synopt:{opt frame(name)}}frame acumulador a exportar (el mismo que se usó en
{cmd:tabsvy}, opción {opt frame()}). Por defecto {cmd:ACUM_ALL}{p_end}
{synopt:{opt mult(#)}}factor de escala aplicado a {cmd:ESTIMA} antes de
exportar. Por defecto {cmd:100} (pasa proporciones a porcentaje, ej. 0.163 -> 16.3){p_end}
{synoptline}

{title:Description}

{pstd}
{cmd:tabsvyexport} toma el frame que fue llenando {helpb tabsvy} (con
{cmd:NIVEL CAIDA [SEXO] [var|TIPO] ESTIMA ANIO REF_ CV ...}), lo escala
({opt mult()}), le calcula la posicion del anio (para no depender de que la
plantilla tenga exactamente esos anios calendario), hace
{cmd:reshape wide ESTIMA REF_} por esa posicion, ordena
Nacional {c ->} Región {c ->} Departamento (y dentro de cada nivel por
{opt idvars()}, respetando {opt catorder()} si se especifico), intercala
columnas {cmd:ESTIMA#}/{cmd:REF_#}, y exporta con {cmd:export excel ... keepcellfmt}
tres bloques (Nacional, Región, Departamento) a las celdas indicadas en
{opt cellnac()}/{opt cellreg()}/{opt celldep()}.

{pstd}
Antes de reordenar, {cmd:tabsvyexport} siempre imprime en pantalla las
categorias de {opt catvar()} realmente presentes en los datos (via
{cmd:levelsof}), para que las compares contra la plantilla. Si diste
{opt catorder()} y alguna categoria observada no esta en esa lista, el
comando se detiene con un error en vez de exportar con filas faltantes o
mal ubicadas.

{pstd}
El orden de columnas en la hoja queda: {cmd:ESTIMA1 REF_1 ESTIMA2 REF_2 ...},
una pareja por cada anio, en el mismo orden en que se pasaron en
{opt years()} al llamar a {cmd:tabsvy}.

{title:Ejemplos}

{pstd}Cuadro simple (identificador adicional: {cmd:var}; se fija de entrada
que la fila 1 del bloque sea la categoria 1 y la fila 2 la categoria 2):{p_end}
{phang2}{cmd:. tabsvyexport, frame(F1) using("$output/mi_plantilla.xlsx") sheet("Cuadro1") idvars(var) catorder(1 2) cellnac(D11) cellreg(D14) celldep(D21)}{p_end}

{pstd}Mismo cuadro, pero la variable resulto codificada al reves de lo que
espera la plantilla (1=No, 2=Si en vez de 1=Si, 2=No): basta con invertir
{opt catorder()}, sin tocar el resto:{p_end}
{phang2}{cmd:. tabsvyexport, frame(F1) using("$output/mi_plantilla.xlsx") sheet("Cuadro1") idvars(var) catorder(2 1) cellnac(D11) cellreg(D14) celldep(D21)}{p_end}

{pstd}Cuadro con dimension sexo (Hombre antes que Mujer si {cmd:sexo} esta
codificado 1=Hombre 2=Mujer; {cmd:catorder()} aplica sobre {cmd:var}, la
ultima variable de {opt idvars()}, no sobre {cmd:SEXO}):{p_end}
{phang2}{cmd:. tabsvyexport, frame(F2) using("$output/mi_plantilla.xlsx") sheet("Cuadro2") idvars(SEXO var) catorder(1 2) cellnac(E11) cellreg(E20) celldep(E45)}{p_end}

{pstd}Cuadro acumulado con loop de variables (identificador: {cmd:TIPO}; el
orden aqui coincide con el orden en que se llamo a {cmd:tabsvy}):{p_end}
{phang2}{cmd:. tabsvyexport, frame(F3) using("$output/mi_plantilla.xlsx") sheet("Cuadro3") idvars(TIPO) catorder(1 2 3 4 5 6) cellnac(D11) cellreg(D18) celldep(D37)}{p_end}

{title:Notas}

{pstd}
{opt idvars()} debe coincidir con las variables identificadoras que
efectivamente existan en el frame (ademas de {cmd:NIVEL CAIDA}); si se pide
una variable que no existe, Stata detendra la ejecucion con un error de
variable no encontrada al momento del {cmd:reshape}.

{pstd}
Las celdas de {opt cellreg()} y {opt celldep()} dependen del numero de filas
que ocupe cada bloque en la plantilla (ej. si hay dimension sexo, cada fila
de {cmd:CAIDA} ocupa el doble de filas por Hombre/Mujer); revisa la plantilla
antes de fijar estos valores, igual que se hacia con los {cmd:export excel ... cell()} del do-file original.

{title:Author}

{pstd}Andres Talavera Cuya, INEI - Dirección Nacional de Censos y Encuestas.{p_end}

{title:Also see}

{psee}
Help: {helpb tabsvy}, {helpb export excel}, {helpb reshape}
{p_end}
