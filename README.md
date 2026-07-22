# tabsvy / tabsvyexport

Motor generico de estimacion con encuestas complejas (`svy` + `parmby`) y
exportacion a plantillas Excel, para cuadros de indicadores estadisticos
repetitivos.

Reemplaza el patron que se repite cuadro tras cuadro en los do-files de
indicadores: por cada nivel de agregacion (Nacional, Region, Departamento)
corre `svy` + `parmby`, identifica el anio, calcula CV/referencia, y arma
las columnas por anio listas para exportar.

## Instalacion

```stata
ssc install parmest        // dependencia, si no la tienen
ssc install frameappend    // dependencia, si no la tienen

net install tabsvy, ///
    from("https://raw.githubusercontent.com/[usuario]/tabsvy/main") replace
```

Para verificar:
```stata
which tabsvy
which tabsvyexport
help tabsvy
help tabsvyexport
```

Para actualizar cuando salga una nueva version, repetir el `net install`
con `replace`.

## Uso rapido

```stata
svyset CONGLO_ANIO [pweight=FACTORFINAL], strata(ESTRATO_ANIO) ///
    vce(linearized) singleunit(certainty)
gen NACIONAL = 1

tabsvy, estcmd("svy linear: proportion indicador if omision1==0") ///
    varname(indicador) years(2014 2015 2016 2017 2018 2019 2020 2022) ///
    expectcats(1 2 3 4) frame(F1) replace

tabsvyexport, frame(F1) using("$output/mi_plantilla.xlsx") ///
    sheet("Cuadro1") idvars(var) catorder(1 2 3 4) ///
    cellnac(D11) cellreg(D14) celldep(D21)
```

Ver `help tabsvy` y `help tabsvyexport` para la sintaxis completa (dimension
sexo, loops de variables tipo TIPO, validacion de categorias, etc.)

## Versiones

| Version | Cambio |
|---|---|
| v1.0 | Motor base: estimacion por nivel + reshape + export |
| v1.1 | `expectcats()` en `tabsvy` (valida categorias al estimar) y `catorder()`/`catvar()` en `tabsvyexport` (fija el orden de filas explicitamente, en vez de inferirlo ascendente) |
| v1.2 | `tabsvyexport` filtra internamente a `NIVEL CAIDA idvars ESTIMA ANIO REF_` antes del reshape (evita el error "variable X not constant" por columnas crudas de `parmby`) |

## Autor

Andres Talavera Cuya — INEI Peru / Encuesta Nacional Agropecuaria (ENA), Lima 2026.
