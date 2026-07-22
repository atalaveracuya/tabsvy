{smcl}
{* *! version 1.0  21jul2026}{...}
{viewerdialog tabsvy "dialog tabsvy"}{...}
{vieweralsosee "tabsvyexport" "help tabsvyexport"}{...}
{vieweralsosee "parmby" "help parmby"}{...}
{vieweralsosee "frameappend" "help frameappend"}{...}
{title:Title}

{phang}
{bf:tabsvy} {hline 2} Motor generico de estimacion con encuestas complejas
(svy + parmby), por niveles de agregacion, con acumulacion en un frame

{title:Syntax}

{p 8 17 2}
{cmd:tabsvy} {cmd:,}
{cmdab:estcmd(}{it:string}{cmd:)}
{cmdab:varname(}{it:varname}{cmd:)}
{cmdab:years(}{it:numlist}{cmd:)}
[{it:opciones}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Requeridas}
{synopt:{opt estcmd(string)}}comando de estimacion completo, sin la clausula
{cmd:over()} (esta la agrega {cmd:tabsvy}). Ej: {cmd:"svy linear: proportion indicador if omision1==0"}{p_end}
{synopt:{opt varname(varname)}}nombre de la variable estimada; se usa para
identificar la categoria de cada fila dentro de {cmd:parm}{p_end}
{synopt:{opt years(numlist)}}anios en el {bf:orden real} en que quedaron
codificados en {cmd:ANIO_} (posicion 1, 2, 3, ...). Ej: {cmd:2014 2015 2016 2017 2018 2019 2020 2022}{p_end}

{syntab:Opcionales}
{synopt:{opt caida(string)}}niveles de agregacion sobre los que se corre el
{cmd:over()}, uno a la vez. Por defecto {cmd:"NACIONAL REGION NOMBREDD_"}{p_end}
{synopt:{opt sexovar(varname)}}variable adicional que entra al {cmd:over()}
entre el nivel de agregacion y {cmd:ANIO_} (tipicamente {cmd:sexo}, sexo).
Si se especifica, se genera ademas la variable {cmd:SEXO} con su categoria{p_end}
{synopt:{opt keepcat(string)}}si se especifica, conserva solo esa categoria de
{cmd:varname} (ej. {cmd:1} = "si tiene"). Pensado para loops donde varias
variables binarias comparten plantilla (ej. un mismo bloque tematico) y se
identifican con {opt tipo()} en vez de con la categoria de {cmd:varname}{p_end}
{synopt:{opt expectcats(numlist)}}categorias que {bf:deberia} tener
{cmd:varname}, declaradas de entrada (ej. {cmd:1 2} para una dicotomica). Si
las categorias observadas en los datos no coinciden exactamente, {cmd:tabsvy}
se detiene ahi mismo con un error, en vez de seguir y dejar que el problema
aparezca recien en la exportacion (filas invertidas o con datos de otra
categoria). {bf:Muy recomendado} cuando la codificacion de la variable no la
controla directamente el que arma el cuadro{p_end}
{synopt:{opt tipo(#)}}etiqueta numerica (1, 2, 3, ...) que se guarda en una
variable {cmd:TIPO}, para acumular varias variables/preguntas bajo la misma
estructura de cuadro. Se usa junto con llamadas repetidas de {cmd:tabsvy} en
un {cmd:forvalues}{p_end}
{synopt:{opt frame(name)}}nombre del frame acumulador. Por defecto {cmd:ACUM_ALL}{p_end}
{synopt:{opt threshold(#)}}umbral de coeficiente de variacion (%) a partir del
cual se marca la referencia {cmd:"a/"}. Por defecto {cmd:15}{p_end}
{synopt:{opt replace}}si se especifica, borra y vuelve a crear el frame
acumulador antes de estimar (usar en la {bf:primera} llamada de cada cuadro;
las llamadas siguientes del mismo cuadro deben omitirlo para que se acumulen){p_end}
{synoptline}

{title:Description}

{pstd}
{cmd:tabsvy} encapsula el patron que se repite cuadro tras cuadro en
do-files de indicadores de una encuesta con diseño muestral complejo: por
cada nivel de agregacion en
{opt caida()} (Nacional, Región, Departamento, ...) corre el comando de
estimacion indicado en {opt estcmd()} con {cmd:over(nivel [sexovar] ANIO_)},
lo pasa por {cmd:parmby} (debe estar instalado, {stata ssc install parmest}),
identifica el anio real a partir de la posicion que ocupa {cmd:ANIO_} en el
string {cmd:parm} devuelto, calcula el coeficiente de variacion y la marca de
referencia, extrae {cmd:NIVEL}/{cmd:CAIDA}/{cmd:[SEXO]}/{cmd:[var|TIPO]}, y
acumula todo en el frame indicado en {opt frame()} usando {cmd:frameappend}
(debe estar instalado, {stata ssc install frameappend}).

{pstd}
El resultado queda listo para pasarlo a {helpb tabsvyexport}, que hace el
{cmd:reshape wide} por anio, ordena los niveles y exporta a la plantilla Excel.

{pstd}
{cmd:tabsvy} {bf:no} hace la preparacion de datos previa (recodificaciones,
creacion de {cmd:NOMBREDD_}, {cmd:ANIO_}, {cmd:CONGLO_ANIO}/{cmd:ESTRATO_ANIO},
ni el {cmd:svyset}); eso sigue haciendose en el do-file, tal como siempre,
antes de llamar a {cmd:tabsvy}.

{title:Requisitos}

{pstd}
Antes de llamar a {cmd:tabsvy} debe existir en la base:{p_end}
{phang2}- el diseño muestral declarado con {cmd:svyset}{p_end}
{phang2}- una variable numerica por cada nombre en {opt caida()} (ej. {cmd:NACIONAL}, {cmd:REGION}, {cmd:NOMBREDD_}), cada una con valor 1 para "aplica"{p_end}
{phang2}- {cmd:ANIO_}, version numerica/encoded del anio{p_end}
{phang2}- {cmd:parmby} y {cmd:frameappend} instalados{p_end}

{title:Ejemplos}

{pstd}Cuadro simple, sin dimension sexo, sin loop de variables, con validacion
de categorias desde el arranque ({opt expectcats()}):{p_end}
{phang2}{cmd:. tabsvy, estcmd("svy linear: proportion indicador if omision1==0") varname(indicador) years(2014 2015 2016 2017 2018 2019 2020 2022) expectcats(1 2 3 4) frame(F1) replace}{p_end}

{pstd}Mismo indicador, con dimension sexo (sexo) en el over():{p_end}
{phang2}{cmd:. tabsvy, estcmd("svy linear: proportion indicador if omision1==0 & omision2==0") varname(indicador) years(2014 2015 2016 2017 2018 2019 2020 2022) sexovar(sexo) frame(F2) replace}{p_end}

{pstd}Loop de varias variables binarias (ej. 6 un mismo bloque tematico), cada una
con su propia condicion de omision, conservando solo la categoria "1" y
etiquetando con {cmd:tipo()}:{p_end}
{phang2}{cmd:. local VARLIST varA varB varC varD varE varF}{p_end}
{phang2}{cmd:. local nvar : word count `VARLIST'}{p_end}
{phang2}{cmd:. forvalues vv = 1/`nvar' {c -(}}{p_end}
{phang3}{cmd:.     local v : word `vv' of `VARLIST'}{p_end}
{phang3}{cmd:.     tabsvy, estcmd("svy linear: proportion `v' if OMISION_`vv'==0") varname(`v') years(2014 2015 2016 2017 2018 2019 2020 2022) keepcat(1) tipo(`vv') frame(F3) `=cond(`vv'==1,"replace","")'}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{title:Stored results}

{pstd}
{cmd:tabsvy} no deja resultados guardados en {cmd:r()}/{cmd:e()}; el
resultado util es el frame acumulador indicado en {opt frame()}.

{title:Author}

{pstd}Andres Talavera Cuya, INEI - Dirección Nacional de Censos y Encuestas.{p_end}

{title:Also see}

{psee}
Help: {helpb tabsvyexport}, {helpb parmby}, {helpb frameappend}, {helpb svy}
{p_end}
