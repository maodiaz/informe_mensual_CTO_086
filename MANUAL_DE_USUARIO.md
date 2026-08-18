# 📘 MANUAL DE USUARIO — INFORME MENSUAL CTO 086

**Proyecto:** `informe_mensual_CTO_086`
**Para quién:** personas que van a **usar** el proyecto (no hace falta saber programar)
**Fecha:** 2026-08-15

---

## 1. ¿Qué hace este proyecto? (en palabras sencillas)

Cada mes, el servicio de imágenes diagnósticas genera una **lista enorme en Excel**
con todos los estudios realizados (radiografías, ecografías, tomografías,
resonancias, biopsias, etc.) y sus valores.

Este proyecto hace el trabajo pesado por usted, en **5 pasos automáticos**:

1. **Toma el Excel del mes** que usted elige.
2. **Limpia y ordena** los datos (conserva solo las filas **aprobadas**, quita
   las administrativas y completa los códigos que faltan).
3. **Usa la lista oficial de precios** (el "tarifario"), que usted coloca en la
   carpeta `datos/` como `Tarifario_CTO_086_2026.xlsx`. Cuando cambian los
   precios, se actualiza (paso opcional).
4. **Compara** cada estudio del mes con el catálogo y calcula cuántos estudios
   de cada tipo se hicieron y **cuánto vale cada uno**.
5. **Genera el informe final en 2 versiones** (una resumida y una detallada) en
   dos formatos:
   - **HTML** → para verlo y/o imprimirlo.
   - **PDF** → para guardarlo o enviarlo por correo tal cual.

> Usted **no programa nada**. Solo abre el proyecto, ejecuta los pasos en orden
> y responde unas pocas preguntas simples que el programa le hace. Este manual
> le dice exactamente qué hacer en cada paso.

---

## 2. Qué necesita tener listo antes de empezar

Antes de usar el proyecto, verifique que tiene lo siguiente:

| # | Qué necesita | ¿Para qué? |
|---|---|---|
| 1 | **R y RStudio** instalados en el computador | Para abrir y ejecutar los pasos |
| 2 | **Google Chrome** instalado | Para generar el **PDF** (Paso 5) |
| 3 | El **archivo Excel del mes** (el que sale del sistema, por ejemplo el que envía Angela Lopez) | Para cargar el mes (Paso 1) |
| 4 | Que en `datos/` estén el **tarifario** (`Tarifario_CTO_086_2026.xlsx`) y **CUPS** (`CUPS.2025.xlsx`) | Para generar los informes sin depender de otros proyectos |
| 5 | Que el **catálogo de precios esté actualizado** | Para que el informe use los precios vigentes |

> **Importante sobre el tarifario:** el tarifario con precios se genera en el
> proyecto `tarifario_CTO_086_V_2`, que **todavía está en proceso** y puede
> cambiar. Usted lo coloca en `datos/` con el nombre **`Tarifario_CTO_086_2026.xlsx`**.
> Este proyecto es **autocontenido**: con el tarifario, CUPS y el Excel del mes
> genera los informes sin depender de los demás proyectos. Cuando el tarifario
> cambie, actualícelo con el Paso 3 (opcional) y repita los Pasos 4 y 5.

### Lo que debe estar en la carpeta `datos/` antes de empezar

Son los **insumos xlsx** que usted debe asegurar que estén en `datos/`:

| Archivo en `datos/` | ¿Qué es? | ¿Obligatorio? | ¿Para qué lo necesita? |
|---|---|---|---|
| `Tarifario_CTO_086_2026.xlsx` | **El tarifario con los precios** (lo genera el proyecto tarifario) | **Sí** | Paso 4 |
| `CUPS.2025.xlsx` | Catálogo de referencia para completar códigos | **Sí** | Paso 2 |
| `tarifas_especiales_2026.xlsx` | Tarifas especiales (solo junta médica y servicio nocturno) | No (se usan valores por defecto) | Paso 4 |

**Además, tenga a la mano el Excel del mes** (el archivo de origen con los
datos del mes). No necesita estar dentro de la carpeta `datos/`: el Paso 1 le
pedirá que lo seleccione desde su computador.

> ⚠️ Los archivos `m.MM.YY.rds` y `m.MM.YY_limpio.rds` **NO los pone usted**:
> los crea el programa en los Pasos 1 y 2. Lo que usted debe asegurar es el
> **tarifario** (`Tarifario_CTO_086_2026.xlsx`), **CUPS** (`CUPS.2025.xlsx`) y
> el **Excel del mes**. Si el tarifario cambia, actualícelo con el Paso 3
> (`--actualizar`).

### Cómo abrir el proyecto en RStudio (primera vez)

1. Abra **RStudio**.
2. En el menú, escoja **File ▸ Open Project...** (Archivo ▸ Abrir Proyecto).
3. Busque la carpeta `informe_mensual_CTO_086` y abra el archivo que termina en `.Rproj`.
4. RStudio abrirá el proyecto. En la parte **inferior derecha** verá la lista de
   los archivos del proyecto (los que empiezan con números: `1_cargar_mes.R`,
   `2_limpiar_mes.R`, etc.).
5. Para ejecutar comandos, use la **pestaña "Terminal"** (está junto a la pestaña
   "Consola", en la parte inferior). Ahí se escriben los comandos que se indican
   en este manual y se presiona **Enter**.
6. **La forma más fácil de todo el proceso** es usar el asistente `main.R`
   (vea la sección 3): un solo clic en **Source** y usted solo responde preguntas.

---

## 3. La forma más fácil: ejecutar `main.R` (asistente paso a paso)

**No tiene que escribir ningún comando ni recordar fechas.** El proyecto trae un
**asistente** (`main.R`) que lo guía por todos los pasos de un mes: usted solo
responde unas pocas preguntas y el programa hace el trabajo.

**Cómo usarlo (muy fácil):**
1. Abra el proyecto en RStudio (sección 2).
2. En la lista de archivos, haga **clic en `main.R`** (es el que NO tiene número).
3. En la barra superior del editor, haga clic en **Source** (o **Run** / **Ejecutar**).
4. Conteste las preguntas que el programa le va haciendo en la **Consola** (la
   ventana de abajo). Son simples, como estas:

| El asistente le pregunta... | Qué debe responder |
|---|---|
| `¿Tiene a mano el archivo .xlsx del mes que va a procesar?` | `s` (sí) para empezar |
| `Mes/año (MM.YY, ej. 07.26):` | El mes y año en 2 dígitos, por ejemplo `07.26` (julio 2026), y **Enter** |
| `¿Ejecutar el PASO 1 ahora? (s/n)` | `s` para ejecutarlo (o `n` para saltarlo) |
| `¿Ejecutar el PASO 2 ahora? (s/n)` | `s` |
| `¿Cambiaron los precios del tarifario? (s/n)` | `n` en un mes normal; `s` solo si cambiaron los precios |
| `¿Ejecutar el PASO 4 ahora? (s/n)` | `s` |
| `¿Ejecutar el PASO 5 ahora? (s/n)` | `s` |

5. **Antes de cada paso**, el asistente le muestra un **breve resumen** de lo que
   va a hacer y le pregunta si lo ejecuta. Usted responde `s` (sí) o `n` (no).
6. Al final, el asistente le muestra un **resumen** con los archivos que se
   generaron (marcados con `[x]`).

**Ventajas de usar `main.R`:**
- No hay que abrir la Terminal ni escribir comandos con fechas.
- Pide el mes **una sola vez** y lo usa en todos los pasos.
- Muestra un resumen de cada paso antes de ejecutarlo.
- Si un paso falla, le avisa y **no detiene todo** el proceso.

> Los Pasos 1, 2, 4 y 5 funcionan igual que si los ejecutara por separado. El
> Paso 3 (tarifario) solo se ejecuta si usted responde que **cambiaron los
> precios**. La sección 5 de este manual explica en detalle qué hace cada paso,
> por si quiere ejecutarlos uno por uno o entender mejor el proceso.

---

## 4. Los 5 pasos de un vistazo

| Paso | Script | ¿Qué hace? | Necesita (entrada) | Produce (salida) |
|---|---|---|---|---|
| **1** | `1_cargar_mes.R` | Guarda el Excel del mes dentro del proyecto | El **Excel del mes** | `datos/m.MM.YY.rds` (el mes guardado) |
| **2** | `2_limpiar_mes.R` | **Normaliza** el mes (obligatorio antes del informe) | El mes guardado en el Paso 1 | `datos/m.MM.YY_limpio.rds` + resumen de normalización (CSV) |
| **3** *(opcional)* | `3_cargar_catalogo.R` | Verifica / actualiza el tarifario cuando cambian | Solo si cambiaron los precios (proyecto tarifario) | Tarifario actualizado en `datos/` |
| **4** | `4_generar_informe.R` | Compara el mes normalizado con los precios y crea el informe | El mes normalizado (Paso 2) y el tarifario (en `datos/`) | `informe_MM.YY_V.1.0.html` y `informe_MM.YY_V.2.0.html` |
| **5** | `5_exportar_pdf.R` | Convierte el informe a PDF | Los archivos HTML del Paso 4 | `informe_MM.YY_V.1.0.pdf` y `informe_MM.YY_V.2.0.pdf` |

> **MM.YY** es el mes y año en 2 dígitos. Por ejemplo, julio de 2026 se escribe **07.26**.
> Los archivos se nombran con ese código (ej.: `informe_07.26_V.2.0.pdf`).
>
> **Flujo normal de un mes: Pasos 1 → 2 → 4 → 5.** El Paso 3 es opcional (solo
> cuando cambian los precios del catálogo).

---

## 5. Paso a paso (con cada script)

> 💡 **Recomendado:** en la mayoría de los casos **NO necesita ejecutar cada
> script por separado**. Use el asistente `main.R` (sección 3), que ejecuta
> estos mismos pasos preguntándole solo lo necesario. Esta sección detalla cada
> paso por si quiere ejecutarlos uno por uno o entender qué hace el programa.

---

### ✅ PASO 1 — Cargar el mes (script `1_cargar_mes.R`)

**¿Para qué sirve?**
Guarda el Excel del mes dentro del proyecto para poder trabajarlo. Se hace **una vez por mes**.

**¿Qué necesita tener a mano?**
El archivo Excel (.xlsx) del mes que quiere procesar.

**Cómo ejecutarlo:**
1. Haga clic en el archivo `1_cargar_mes.R` (en la lista de archivos del proyecto).
2. En la barra superior del editor haga clic en **Source** (o **Run** / **Ejecutar**).
3. Siga lo que el programa le pide en la pantalla:

| El programa le pide... | Qué debe hacer |
|---|---|
| Elegir el archivo .xlsx | Se abre una ventana para **buscar y seleccionar el Excel del mes**. Apriete OK. |
| Elegir la hoja | Si el archivo tiene varias hojas, aparece una lista. **Elija la hoja** con los datos (la correcta) y apriete OK. |
| Ingresar el MES (MM) | Escriba el mes en 2 dígitos (ej. `07` para julio) y presione **Enter**. |
| Ingresar el AÑO (YY) | Escriba el año en 2 dígitos (ej. `26` para 2026) y presione **Enter**. |

**Qué va a ver en pantalla:**
- El número de filas y columnas leídas (ej.: 9.500 filas).
- Las **primeras filas** del Excel, para que usted confirme que eligió la hoja correcta.

**Qué archivo se crea (salida):**
- `datos/m.MM.YY.rds` (ej.: `datos/m.07.26.rds`).

**¿Cómo saber que salió bien?**
Al final aparece un resumen con el nombre del mes guardado y la ruta del archivo
(por ejemplo: `[OK] Guardado: .../datos/m.07.26.rds`).

> Si el mes ya estaba cargado, el programa le preguntará `¿Sobrescribir? (s/n)`.
> Escriba `s` si quiere reemplazarlo o `n` para dejarlo como estaba.

---

### ✅ PASO 2 — Normalizar el mes (script `2_limpiar_mes.R`) — OBLIGATORIO

**¿Para qué sirve?**
**Normaliza los datos del mes**: conserva solo las filas con **estado APROBADO**
y quita las administrativas, completa los códigos que faltan y deja todo con el
mismo formato. **Este paso es obligatorio**: el informe (Paso 4) **no se genera
si el mes no está normalizado**. Además, en pantalla verá el detalle de la
limpieza y se guarda una copia limpia del mes que puede revisar.

**¿Qué necesita?**
Que el mes ya esté cargado (Paso 1).

**Cómo ejecutarlo (por Terminal):**
1. Abra la pestaña **Terminal** en RStudio.
2. Escriba el comando con el mes y el año, y presione **Enter**:

```
Rscript 2_limpiar_mes.R 07.26
```

*(reemplace `07.26` por el mes y año que corresponda)*

**Qué va a ver en pantalla:**
Un resumen de la limpieza, por ejemplo:
- Filas crudas (las que traía el Excel).
- Cuántas filas se quitaron por **no estar aprobadas** o por ser administrativas.
- Cuántos códigos se completaron automáticamente.
- Al final debe aparecer: **`✓ NINGUNA FILA SIN CÓDIGO (objetivo cumplido)`**.

**Qué archivos se crean (salida):**
- `datos/m.MM.YY_limpio.rds` → el mes normalizado (ej.: `datos/m.07.26_limpio.rds`).
- `datos/m.MM.YY_normalizacion.pdf` → **informe explicativo de la normalización**
  (en PDF). Léalo o imprímalo: explica en lenguaje sencillo qué hizo el programa
  (no es "caja negra").
- `datos/m.MM.YY_normalizacion.html` → la misma explicación, para ver en el navegador.
- `datos/m.MM.YY_normalizacion.csv` → resumen en tabla (para abrir en Excel).
- `datos/m.MM.YY_normalizacion_detalle.csv` → detalle de los códigos asignados
  (solo si hubo): qué estudio recibió qué código y por qué método.

**¿Cómo saber que salió bien?**
Si al final dice `✓ NINGUNA FILA SIN CÓDIGO`, el mes quedó bien limpio. También
se crean el **informe de normalización** (PDF/HTML) y los resúmenes (CSV) para
que pueda revisar qué cambios hizo el programa.

> Si en vez del ✓ apareciera `✗ QUEDAN ... FILAS SIN CÓDIGO`, avise a la persona
> encargada del proyecto: hay datos que no se pudieron completar solos.

---

### 🔄 PASO 3 — Verificar / actualizar el tarifario (script `3_cargar_catalogo.R`) — OPCIONAL

**¿Para qué sirve?**
Verifica que los insumos xlsx estén en `datos/` (el tarifario y CUPS) y que el
tarifario tenga las columnas que necesita el informe. **En un mes normal NO hace
falta ejecutarlo** si ya colocó `Tarifario_CTO_086_2026.xlsx` y `CUPS.2025.xlsx`
en `datos/`. Solo se usa cuando:
- **Cambiaron los precios** en el proyecto del tarifario
  (`tarifario_CTO_086_V_2`), **o**
- Falta el tarifario en la carpeta `datos/` (por ejemplo, computador nuevo).

**¿Qué necesita?**
Tener el archivo `Tarifario_CTO_086_2026.xlsx` (lo puede copiar del proyecto
tarifario) y `CUPS.2025.xlsx` en `datos/`.

**Cómo ejecutarlo:**
- **Opción sencilla (RStudio):** haga clic en `3_cargar_catalogo.R` y luego en **Source**.
- **Opción por Terminal:**

```
Rscript 3_cargar_catalogo.R
```

Si ya está todo en orden, el programa le dirá que **no hay nada que hacer**
(este paso es opcional) y terminará.

**¿Cuándo usar la opción "actualizar"?**
Si **cambiaron los precios** en el proyecto del tarifario, ejecute:

```
Rscript 3_cargar_catalogo.R --actualizar
```

Esto **copia el tarifario nuevo** (`Tarifario_CTO_086_2026.xlsx`) desde el
proyecto tarifario (sobrescribe). Le pedirá confirmación: escriba `s` para
aceptar. Después, repita los Pasos 4 y 5 para que el informe use los precios nuevos.

**Qué archivos se revisan/actualizan (salida):**
En la carpeta `datos/`:
- `Tarifario_CTO_086_2026.xlsx` → **el tarifario con precios** (lo más importante).
- `CUPS.2025.xlsx` → catálogo de referencia (debe estar presente).
- `tarifas_especiales_2026.xlsx` → solo junta médica y servicio nocturno (opcional; valores por defecto si falta).

**¿Cómo saber que salió bien?**
Al final debe aparecer:
- `[OK] El tarifario tiene las columnas requeridas por el informe (tarifa en 'TARIFAS_2026').`
- `[OK] Insumos listos en 'datos/'.`

> ⚠️ Si el tarifario falta, el Paso 4 se detiene y le indica que ejecute este
> Paso 3 (o que coloque `Tarifario_CTO_086_2026.xlsx` en `datos/`).

---

### ✅ PASO 4 — Generar el informe (script `4_generar_informe.R`)

**¿Para qué sirve?**
Este es el paso **principal**: compara cada estudio del mes con el catálogo de
precios y genera el informe final (la "cuenta" del mes). Se hace **una vez por mes**
después de los Pasos 1 y 3.

**¿Qué necesita?**
- El mes ya **normalizado** (Paso 2) — es obligatorio.
- El **tarifario** (`Tarifario_CTO_086_2026.xlsx`) en `datos/` (solo si cambiaron
  los precios, ejecute antes el Paso 3 con "actualizar").

**Cómo ejecutarlo (por Terminal):**
*(requiere haber normalizado el mes en el Paso 2)*

```
Rscript 4_generar_informe.R 07.26
```

*(reemplace `07.26` por el mes y año que corresponda)*

**Qué va a ver en pantalla:**
1. El resumen de la limpieza (igual que en el Paso 2).
2. El **resumen del cruce** con los precios:
   - `X (filas limpias)` → cuántos estudios quedaron después de limpiar.
   - `Y (con CLASE + TARIFA)` → cuántos quedaron con precio.
   - `Z = 100 %` → **esto es lo que se quiere ver**: todos los estudios tienen precio.
   - `EXCLUIDOS POR DECISIÓN` → estudios que se descartan del informe porque ya se
     decidió que no se incluyen (no es un error).
3. Puede preguntarle una confirmación:
   - `¿CONFIRMAS excluir estos códigos por decisión? (s/n)` → escriba `s` (sí) y Enter.
4. Al final, los totales del mes:
   - `TOTAL Estudios`, `TOTAL Procs` y **`VALOR EJECUTADO MES ...`** (el valor total del mes).

**Qué archivos se crean (salida):**
- `informe_MM.YY_V.1.0.html` → versión **resumida** (una línea por tipo de estudio).
- `informe_MM.YY_V.2.0.html` → versión **detallada** (cada código por separado).

**¿Cómo saber que salió bien?**
- En pantalla dice `✔ CRUCE COMPLETO — procede a generar el informe.`
- Se ve `Informe generado: .../informe_MM.YY_V.1.0.html` y lo mismo para la V.2.0.

**⚠️ Caso importante — si el informe NO se genera:**
Si hay estudios del mes que **no tienen precio** en el catálogo, el programa se
**detiene a propósito** y muestra `>>> NO SE GENERA EL INFORME` con la lista de
los códigos sin precio. **No es un error del computador**: significa que el
catálogo está incompleto o desactualizado. En ese caso:
1. Anote los códigos que aparecen en la lista.
2. Avise a la persona encargada del catálogo (proyecto `tarifario_CTO_086_V_2`).
3. Cuando el catálogo se actualice, repita el **Paso 3 con `--actualizar`** y luego este Paso 4.

---

### ✅ PASO 5 — Exportar el informe a PDF (script `5_exportar_pdf.R`)

**¿Para qué sirve?**
Convierte los informes HTML del Paso 4 a **PDF**, para guardarlos o enviarlos tal cual.

**¿Qué necesita?**
- Los informes HTML ya generados (Paso 4).
- **Google Chrome** instalado (el programa lo busca solo).

**Cómo ejecutarlo (por Terminal):**

```
Rscript 5_exportar_pdf.R 07.26
```

*(reemplace `07.26` por el mes y año que corresponda)*

**Qué va a ver en pantalla:**
- `Chrome: /Applications/Google Chrome...` (la ruta donde encontró Chrome).
- Por cada versión: `[>] Exportando...` y luego `[OK] PDF generado: ...`.

**Qué archivos se crean (salida):**
- `informe_MM.YY_V.1.0.pdf` → PDF de la versión resumida.
- `informe_MM.YY_V.2.0.pdf` → PDF de la versión detallada.

**¿Cómo saber que salió bien?**
Aparece `[OK] PDF generado:` para cada versión.

> Si aparece un aviso de que **no se encontró el HTML**, significa que todavía no
> hizo el Paso 4 (o el mes no coincide). Haga el Paso 4 y repita este paso.

---

## 6. Las preguntas que le hará el programa (y qué responder)

> Si usa el asistente `main.R` (sección 3), estas son las preguntas típicas.

| Pregunta | ¿Qué significa? | Qué responder |
|---|---|---|
| `¿Tiene a mano el archivo .xlsx del mes...?` (asistente) | Pregunta si tiene el Excel del mes listo | `s` (sí) |
| `Mes/año (MM.YY, ej. 07.26):` (asistente) | El mes que va a procesar | `07.26` (o el que corresponda) y Enter |
| `¿Ejecutar el PASO ... ahora? (s/n)` (asistente) | Confirma si ejecuta ese paso | `s` = sí / `n` = saltar |
| `¿Cambiaron los precios del tarifario? (s/n)` (asistente) | Pregunta si el tarifario cambió | `n` en mes normal / `s` si cambiaron los precios |
| `¿Sobrescribir? (s/n)` (Paso 1) | Ya existía el mes y pregunta si lo reemplaza | `s` = sí / `n` = no |
| `¿Deseas detener el proceso ahora? (s/n)` (Paso 1) | Si no eligió archivo u hoja, pregunta si quiere salir | `n` = continuar / `s` = salir |
| `¿RE-COPIAR los insumos...? (s/n)` (Paso 3, con `--actualizar`) | Confirma que quiere copiar de nuevo los precios | `s` = sí (recomendado si cambiaron los precios) |
| `CANTIDAD HORA JUNTA MEDICA (provisional = 100)...` (Paso 4, en RStudio) | Pregunta cuántas horas de junta médica van en el informe | Presione **Enter** para usar 100, o escriba el número |
| `¿CONFIRMAS excluir estos códigos por decisión? (s/n)` (Paso 4) | Confirma que se descarten estudios ya acordados | `s` = sí (respuesta normal) |

> Consejo: cuando en una pregunta no sepa qué responder, la mayoría de las veces
> lo correcto es presionar **Enter** (usa la respuesta sugerida) o escribir **`s`**.

---

## 7. Cómo saber que todo salió bien (mensajes de éxito)

Busque estos mensajes en la pantalla:

| Paso | Mensaje de éxito |
|---|---|
| 1 | `[OK] Guardado: .../datos/m.07.26.rds` |
| 2 | `✓ NINGUNA FILA SIN CÓDIGO (objetivo cumplido)` |
| 3 | `[OK] El catálogo del tarifario tiene las 5 columnas requeridas` y `[OK] Insumos listos` |
| 4 | `✔ CRUCE COMPLETO` y `Informe generado: ..._V.1.0.html` (y V.2.0) |
| 5 | `[OK] PDF generado: ..._V.1.0.pdf` (y V.2.0) |

Y al final del día, en la carpeta del proyecto debe tener estos archivos del mes:

```
informe_07.26_V.1.0.html
informe_07.26_V.2.0.html
informe_07.26_V.1.0.pdf
informe_07.26_V.2.0.pdf
datos/m.07.26.rds
datos/m.07.26_limpio.rds
datos/m.07.26_normalizacion.pdf          ← informe explicativo de la normalización (Paso 2)
datos/m.07.26_normalizacion.html         ← informe explicativo (para ver en el navegador)
datos/m.07.26_normalizacion.csv          ← resumen de la normalización (Paso 2)
datos/m.07.26_normalizacion_detalle.csv  ← detalle de códigos asignados (Paso 2, si hubo)
```

---

## 8. Problemas comunes y cómo resolverlos

| Problema | Causa probable | Solución |
|---|---|---|
| "No se encontró el mes: ...m.07.26.rds" | No cargó el mes | Haga el **Paso 1** con el mes correcto |
| "No se encontró el mes NORMALIZADO: ...m.07.26_limpio.rds" | No normalizó el mes | Ejecute el **Paso 2** con el mismo mes |
| "No se encontró el tarifario" | Falta `Tarifario_CTO_086_2026.xlsx` en `datos/` (ej. computador nuevo) | Colóquelo en `datos/` o ejecute el **Paso 3 con `--actualizar`** |
| "NO SE GENERA EL INFORME" con códigos sin precio | Hay estudios sin precio en el catálogo | Anote los códigos, actualice el catálogo y repita Paso 3 (`--actualizar`) + Paso 4 |
| "No se encontró el HTML" (en el Paso 5) | No generó el informe o escribió otro mes | Haga el **Paso 4** con el mismo mes |
| "No se encontró Google Chrome" | Chrome no está instalado | Instale **Google Chrome** y repita el Paso 5 |
| El informe se ve con precios viejos | El catálogo cambió y no se actualizó | Repita **Paso 3 con `--actualizar`** y luego Pasos 4 y 5 |
| Escribí mal el mes (ej. `7` en vez de `07`) | El formato debe ser de 2 dígitos | Use `07`, `08`, `09`... |

---

## 9. Glosario sencillo

| Término | Qué significa (en palabras simples) |
|---|---|
| **Catálogo** | La **lista oficial de precios** de cada estudio (código, descripción y valor). |
| **CLASE / TARIFA** | **CLASE** = el tipo de estudio (radiografía, tomografía...). **TARIFA** = el precio del estudio. |
| **Código** | El número de identificación que tiene cada estudio en el sistema. |
| **Cruzar / cruce** | **Comparar y emparejar** cada estudio del mes con su precio en el catálogo. |
| **Limpiar / normalizar** | Quitar filas que no sirven, completar códigos faltantes y dejar todo con el mismo formato. |
| **Limpio** | El mes después de la limpieza. |
| **Excluidos por decisión** | Estudios que ya se acordó **no incluir** en el informe (no es un error). |
| **HTML** | Un formato de archivo para **ver en el navegador** e imprimir. |
| **PDF** | Un formato de archivo **listo para guardar o enviar** (se ve igual en todas partes). |
| **Consola / Terminal** | La ventana donde se **escriben los comandos** y donde el programa **muestra los mensajes**. |
| **Script / archivo .R** | Cada uno de los **archivos del proyecto** que hacen un paso (los que empiezan con número). |
| **.rds** | Formato interno del proyecto para guardar datos (no lo necesita abrir; el programa lo usa solo). |

---

## 10. Resumen de los comandos (para tener a la mano)

> ⭐ **La forma más fácil (recomendada):** abra `main.R` en RStudio y haga clic en
> **Source**. El asistente le pedirá el mes y ejecutará los pasos. Los comandos de
> abajo son por si prefiere ejecutar un paso a la vez (avanzado).

```
# ⭐ FLUJO NORMAL DE UN MES (1 → 2 → 4 → 5)
# MODO RECOMENDADO: abrir main.R y hacer clic en 'Source' (asistente interactivo).
# (No se necesita Terminal ni escribir fechas.)

# Paso 1 — Cargar el mes (en RStudio: abrir 1_cargar_mes.R y dar clic en Source)

# Paso 2 — Normalizar el mes (OBLIGATORIO)
Rscript 2_limpiar_mes.R 07.26

# Paso 4 — Generar el informe (HTML)
Rscript 4_generar_informe.R 07.26

# Paso 5 — Exportar a PDF
Rscript 5_exportar_pdf.R 07.26

# ── OPCIONAL ────────────────────────────────────────────────
# Paso 3 — Actualizar el catálogo (solo cuando cambian los precios)
Rscript 3_cargar_catalogo.R --actualizar
```

**El orden normal de un mes es:** 1 → 2 → 4 → 5 (el Paso 3 es opcional).
Cuando cambien los precios: **3 (con `--actualizar`) → 4 → 5**.
