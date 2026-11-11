# 📋 PLAN DE TRABAJO — Informe Mensual CT 086 (traslado de negocio)

**Proyecto:** `informe_mensual_ct086`
**Fecha:** 2026-08-14
**Estado:** ✅ Creado (scripts listos para ejecutar por mes)
**Actualización 2026-10-25:** ✅ Añadidas las versiones **V.3.0** (columnas
`ADICIONAL` / `CTO_086`) y **V.4.0** (solo cantidades).
**Actualización 2026-11-11:** ✅ Las 4 versiones se generan **en una sola ejecución
del pipeline** (Paso 4). El tarifario alternativo se renombró de
`..._BORRADOR.xlsx` a **`Tarifario_CTO_086_2026_V3.xlsx`** (ver sección 9).

---

## 1. Objetivo

Crear un proyecto R nuevo que **traslade parte del negocio** de
`recuento_estudios_anual`: procesar **un mes** (carga + limpieza/normalización),
cruzar contra el **catálogo del tarifario** producido por
`tarifario_CTO_086_V_2` (aún en proceso) y generar el **informe de ejecución en
2 versiones (HTML) y su exportación a PDF**.

Requisitos del usuario (confirmados):
1. ✅ Cargar los datos de un mes (desde el `.xlsx` crudo, igual que el proyecto origen).
2. ✅ Limpiar los datos (normalizar).
3. ✅ Cargar el catálogo **modificado por `tarifario_CTO_086_V_2`** (aún en proceso;
   puede cambiar) — copia **self-contained** en `datos/`.
4. ✅ Generar el informe en sus **2 versiones** en **HTML y PDF**.
5. ✅ El informe se mantiene **como está hoy** (NO incorpora la columna `CTO_086`).
   - *Excepción (2026-10-25):* la **versión V.3.0** (informe borrador) **sí**
     incorpora `ADICIONAL` y `CTO_086`. Las versiones oficiales V.1.0/V.2.0 no cambian.

---

## 2. Decisión de arquitectura

El nuevo proyecto es **autocontenido**: recibe insumos **xlsx** que el usuario
aporta (Excel del mes, tarifario, CUPS) y no depende de los proyectos previos:

```mermaid
flowchart LR
    subgraph Usuario[Insumos xlsx que aporta el usuario]
        A[Excel del mes] --> D[Carga + Limpieza<br/>limpiar_mes()]
        B[CUPS.2025.xlsx] --> D
    end
    subgraph Tarifario[tarifario_CTO_086_V_2]
        E[Tarifario_CTO_086_2026.xlsx<br/>CODIGO|CLASE|TARIFAS_2026]
    end
    D --> F[Cruce por código]
    E --> F
    F --> G[Informe HTML<br/>V.1.0 y V.2.0]
    G --> H[PDF vía Chrome headless]
```

Clave: el tarifario (`Tarifario_CTO_086_2026.xlsx`) trae las columnas que usa el
informe (CODIGO, DESCRIPCION, CLASE, ADICIONAL y la tarifa en `TARIFAS_2026`),
por lo que el cruce de `script_informe_mes.R` funciona **casi sin cambios**;
solo cambia la fuente (xlsx) y se elimina la dependencia de lista única/rds.

---

## 3. Estructura del proyecto

```
informe_mensual_ct086/
├── main.R                        # Orquestador (librerías + pasos comentados)
├── 1_cargar_mes.R                # Carga manual de UN mes (.xlsx -> datos/m.MM.YY.rds)
├── 2_limpiar_mes.R               # Traslado de limpiar_mes.R (normaliza; lee de datos/)
├── 3_cargar_catalogo.R           # Verifica/actualiza insumos xlsx (tarifario + CUPS)
├── 4_generar_informe.R           # Genera las 4 versiones (V.1.0 a V.4.0) + configuración
├── 5_exportar_pdf.R              # Exportación a PDF (4 versiones) con Chrome headless
├── PLAN_DE_TRABAJO.md            # Este documento
├── registro_carga.csv            # Log de meses cargados (lo genera 1_cargar_mes.R)
└── datos/                        # Insumos self-contained (los copia 3_cargar_catalogo.R)
    ├── m.MM.YY.rds               # Mes crudo (lo genera 1_cargar_mes.R)
    ├── m.MM.YY_limpio.rds        # Mes normalizado (OBLIGATORIO; lo genera 2_limpiar_mes.R)
    ├── m.MM.YY_normalizacion.pdf  # Informe explicativo de la normalización (Paso 2)
    ├── m.MM.YY_normalizacion.html # Informe explicativo (para ver en el navegador)
    ├── m.MM.YY_normalizacion.csv  # Resumen de la normalización (Paso 2)
    ├── m.MM.YY_normalizacion_detalle.csv  # Detalle de códigos asignados (Paso 2, si hubo)
    ├── Tarifario_CTO_086_2026.xlsx  # TARIFARIO OFICIAL con precios (lo aporta el usuario; Paso 3 actualiza)
    ├── Tarifario_CTO_086_2026_V3.xlsx # Tarifario para V.3.0 y V.4.0 (precios propios; OBLIGATORIO)
    ├── CUPS.2025.xlsx             # Respaldo por similitud (lo aporta el usuario)
    └── tarifas_especiales_2026.xlsx # Solo junta médica y servicio nocturno (opcional; valores por defecto si falta)
```

---

## 4. Qué se trasladó (y qué no)

### 4.1 Trasladado íntegro (lógica de negocio)

| Lógica | Origen | Destino | Cambios |
|---|---|---|---|
| Carga manual de un mes (selector + hoja + MM.YY + registro) | `1_cargar_datos.R` | `1_cargar_mes.R` | Sin bucle de 78; una iteración por mes |
| Limpieza/normalización (`limpiar_mes()`) | `limpiar_mes.R` | `2_limpiar_mes.R` | CUPS desde xlsx (`CUPS.2025.xlsx`); sin lista única |
| Informe mensual (`generar_informe_mes()`) | `script_informe_mes.R` | `4_generar_informe.R` | Tarifario → `datos/Tarifario_CTO_086_2026.xlsx` (mapea `TARIFAS_2026`→`TARIFA`) |
| Filas especiales HORA JUNTA MEDICA / VALOR FIJO | `script_informe_mes.R` | `4_generar_informe.R` | Ruta de tarifas clases → `datos/` |
| Lista `excluidos_por_decision` | `script_informe_mes.R` | `4_generar_informe.R` | Sin cambios |
| Exportación a PDF (Chrome headless) | Notas de `script_informe_mes.R` | `5_exportar_pdf.R` | Script propio |

### 4.2 NO se trasladó (sigue en el proyecto origen)

- El pipeline histórico de generación del catálogo (scripts `2_`…`27_` de
  `recuento_estudios_anual`). Este proyecto **consume** el tarifario (xlsx), no lo genera.
- La columna `CTO_086` del catálogo del tarifario en las versiones **oficiales**
  (V.1.0/V.2.0 se mantienen como están). Sí se usa en las **V.3.0 y V.4.0**.

---

## 5. Flujo de uso (por mes)

```bash
# FLUJO NORMAL DE UN MES (1 → 2 → 4 → 5):
# 1) Cargar el mes (interactivo: archivo + hoja + MM/YY)
Rscript 1_cargar_mes.R              # o source() desde main.R

# 2) Normalizar el mes (OBLIGATORIO antes del informe)
Rscript 2_limpiar_mes.R 07.26       # -> datos/m.07.26_limpio.rds

# 4) Generar las CUATRO versiones del informe (HTML)
Rscript 4_generar_informe.R 07.26              # V.1.0, V.2.0, V.3.0 y V.4.0
Rscript 4_generar_informe.R 07.26 --junta=105  # forzando la HORA JUNTA MEDICA

# 5) Exportar a PDF (las cuatro versiones)
Rscript 5_exportar_pdf.R 07.26

# OPCIONAL (solo cuando cambian los precios del tarifario OFICIAL):
# 3) Actualizar el catálogo del tarifario oficial
Rscript 3_cargar_catalogo.R --actualizar
# (el tarifario V3 se edita directamente en datos/Tarifario_CTO_086_2026_V3.xlsx)
```

> Nota: la **normalización (paso 2) es obligatoria** — el Paso 4 exige
> `datos/m.MM.YY_limpio.rds` y no genera el informe si el mes no está
> normalizado. El proyecto es **autocontenido**: los insumos xlsx (tarifario +
> CUPS) los pone el usuario en `datos/`; el paso 3 solo se ejecuta cuando
> cambian precios.

---

## 6. Manejo del catálogo del tarifario (EN PROCESO)

El tarifario `tarifario_CTO_086_V_2` **aún está en elaboración** (fases 5-8
pendientes) y su catálogo **puede cambiar**. Por eso:

- El proyecto es **autocontenido**: no necesita los demás proyectos para generar
  informes; los insumos xlsx (tarifario + CUPS) están en `datos/`.
- El nuevo proyecto **no edita** el catálogo: solo lo **copia** a `datos/`.
- Cuando el tarifario cambie (Paso 3 opcional), basta:
  ```bash
  Rscript 3_cargar_catalogo.R --actualizar   # re-copia TODO (sobrescribe)
  Rscript 4_generar_informe.R 07.26          # regenera el informe con el catálogo vigente
  Rscript 5_exportar_pdf.R 07.26
  ```
- No hay caché: cada generación usa el catálogo presente en `datos/`.

---

## 7. Criterios de éxito

- [ ] `1_cargar_mes.R` carga un mes sin errores y lo guarda en `datos/m.MM.YY.rds`.
- [ ] `2_limpiar_mes.R` normaliza el mes (OBLIGATORIO) y garantiza 0 códigos vacíos/NA.
- [ ] `3_cargar_catalogo.R` (OPCIONAL) verifica/actualiza el tarifario y CUPS (xlsx) y valida las columnas.
- [ ] `4_generar_informe.R` genera las **cuatro** versiones en una sola ejecución:
      `informe_MM.YY_V.1.0.html`, `V.2.0`, `V.3.0` y `V.4.0`
      (exige el mes normalizado del Paso 2 y solo si el cruce está completo).
- [ ] `5_exportar_pdf.R` genera el PDF de cada una de las cuatro versiones.
- [ ] Re-ejecutar `3 --actualizar` + `4` + `5` tras un cambio del tarifario oficial
      regenera los informes con el catálogo vigente.
- [ ] La V.3.0 incluye las columnas `ADICIONAL` y `CTO_086`; la V.4.0 incluye
      únicamente cantidades (sin columnas de dinero).

---

## 8. Pendientes / a confirmar

- [ ] Primera ejecución real: cargar un mes de prueba y generar sus informes.
- [ ] Confirmar el estado final del tarifario (cuando `tarifario_CTO_086_V_2` termine)
      y re-copiar el catálogo.
- [ ] Validar que las tarifas de HORA JUNTA MEDICA / VALOR FIJO siguen vigentes.

---

## 9. Las cuatro versiones del informe

**Actualizado 2026-11-11.** Las 4 versiones se generan **en una sola ejecución** del
Paso 4 (o de `main.R`). No hay scripts auxiliares ni pasos manuales.

### Resumen

| Versión | TABLA ESTUDIOS | TABLA PROCEDIMIENTOS | "Valor Ejecutado" | Tarifario |
|---|---|---|---|---|
| **V.1.0** | plana por CLASE: `CLASE / TARIFA / CANTIDAD / VALOR TOTAL` | `CODIGO / DESCRIPCION / TARIFA / CANTIDAD / VALOR TOTAL / ADICIONAL` | Sí | OFICIAL |
| **V.2.0** | expandida por código (mismas columnas) | igual | Sí | OFICIAL |
| **V.3.0** | expandida + `ADICIONAL` y `CTO_086` | + `CTO_086` | Sí | **V3** |
| **V.4.0** | solo `CLASE / CÓDIGO` y `CANTIDAD` (sin SUBTOTAL ADICIONALES ni TOTAL) | solo `CODIGO / DESCRIPCION / CANTIDAD` (con fila TOTAL) | **No** | **V3** |

### Tarifarios

| Archivo | Se usa en | Contenido |
|---|---|---|
| `datos/Tarifario_CTO_086_2026.xlsx` | V.1.0 y V.2.0 | Tarifario **oficial** (lo actualiza el Paso 3) |
| `datos/Tarifario_CTO_086_2026_V3.xlsx` | V.3.0 y V.4.0 | Tarifario **V3** (precios propios; se edita a mano) |

> El tarifario V3 se llamaba antes `Tarifario_CTO_086_2026_BORRADOR.xlsx`; se renombró
> el 2026-11-11 porque dejó de ser un borrador temporal.

### Configuración centralizada

Todo lo que distingue a las versiones está en el bloque **0. CONFIGURACIÓN DE LAS
VERSIONES** de `4_generar_informe.R`:

```r
TARIFARIO_OFICIAL <- "Tarifario_CTO_086_2026.xlsx"     # V.1.0 y V.2.0
TARIFARIO_V3      <- "Tarifario_CTO_086_2026_V3.xlsx"  # V.3.0 y V.4.0
TARIFA_FIJO_V3    <- 56560000                          # VALOR FIJO NOCTURNO

JUNTA_POR_MES    <- c("06.26" = 105L, "07.26" = 116L, "08.26" = 100L,
                      "09.26" = 100L, "10.26" = 105L)
JUNTA_V4_POR_MES <- c("09.26" = 103L, "10.26" = 105L)  # excepción de la V.4.0
```

**Alta de un mes nuevo:** agregar su cantidad de HORA JUNTA MEDICA a
`JUNTA_POR_MES` (y a `JUNTA_V4_POR_MES` solo si la V.4.0 necesita otra cantidad).
Si el mes no está en la tabla, el script avisa y usa 100.

### Uso

```bash
# Todas las versiones de un mes
Rscript 4_generar_informe.R 10.26
Rscript 5_exportar_pdf.R 10.26

# Forzando la cantidad de HORA JUNTA MEDICA
Rscript 4_generar_informe.R 10.26 --junta=105

# Desde RStudio / main.R (source() solo define las funciones)
generar_todas_las_versiones("10.26")
```

### Funciones disponibles

| Función | Para qué |
|---|---|
| `generar_todas_las_versiones(mes, cant_junta = NULL)` | Genera las 4 versiones (lo que usa el pipeline) |
| `generar_informe_mes(mes, version, ruta_tarifario, cant_junta_param, tarifa_fijo_param)` | Una versión concreta, con control total |

| Parámetro de `generar_informe_mes()` | Default | Para qué |
|---|---|---|
| `version` | `c("1.0", "2.0")` | Versión(es) a generar (`"1.0"`, `"2.0"`, `"3.0"`, `"4.0"`) |
| `ruta_tarifario` | `NULL` (oficial de `datos/`) | Usar un tarifario alternativo |
| `cant_junta_param` | `NULL` (100 por Rscript / pregunta en RStudio) | Fijar HORA JUNTA MEDICA |
| `tarifa_fijo_param` | `NULL` (la de `tarifas_especiales_2026.xlsx`) | Fijar VALOR FIJO NOCTURNO |

### Cantidad de HORA JUNTA MEDICA por mes

| Mes | V.1.0 / V.2.0 / V.3.0 | V.4.0 |
|---|---|---|
| 06.26 | 105 | 105 |
| 07.26 | 116 | 116 |
| 08.26 | 100 | 100 |
| 09.26 | 100 | **103** |
| 10.26 | 105 | 105 |

### Nota sobre el tarifario oficial (2026-10-25)

El tarifario oficial en `datos/` **no coincide** con el que produjo el informe de
07.26: el código `559301` (REEMPLAZO DE CATETER DE NEFROSTOMIA) está en **320.719** y
en ese informe figuraba en **483.080**. Por eso **regenerar el 07.26 oficial
cambiaría sus totales** (diferencia exacta: 91 × 162.361 = 14.774.851).
