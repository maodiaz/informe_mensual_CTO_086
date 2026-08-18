# ==============================================================================
# PROYECTO: INFORME MENSUAL CTO 086
# SCRIPT MAESTRO: CONTROL DE PARÁMETROS Y LIBRERÍAS + ORQUESTACIÓN
# ------------------------------------------------------------------------------
# Este proyectos procesa UN MES (carga, limpieza/normalización) y genera el informe de
# ejecución en DOS versiones (HTML V.1.0 resumida y V.2.0 detallada) más su
# exportación a PDF, cruzando contra el TARIFARIO vigente que aporta el usuario
# (Tarifario_CTO_086_2026.xlsx, generado por 'tarifario_CTO_086_V_2').
#
# FLUJO (1 mes):
#   PASO 1 — CARGA DEL MES   -> 1_cargar_mes.R
#            Selecciona el .xlsx crudo del mes, elige la hoja, ingresa MM.YY
#            y guarda datos/m.MM.YY.rds (re-ejecutable una vez por mes).
#   PASO 2 — LIMPIEZA/NORMALIZACIÓN (OBLIGATORIO) -> 2_limpiar_mes.R
#            Aplica al mes las MISMAS correcciones del pipeline anual:
#            conserva SOLO STTEXT = Aprobado (+ excluye Philips, Admin), quitar 'L' final,
#            mapeo duro PRESTACION->CODIGO + respaldo por similitud vs
#            CUPS.2025, descartar la prestación sin código y descripción
#            canónica. Garantiza 0 filas sin código y guarda
#            datos/m.MM.YY_limpio.rds (el PASO 4 lo exige: no se genera
#            informe sin normalizar).
#   PASO 3 — VERIFICAR / ACTUALIZAR EL TARIFARIO (OPCIONAL) -> 3_cargar_catalogo.R
#            El usuario coloca el tarifario (Tarifario_CTO_086_2026.xlsx) y CUPS
#            (CUPS.2025.xlsx) en 'datos/'; el proyecto es autocontenido y NO
#            depende de los demás para generar informes. Solo se ejecuta cuando
#            cambian los precios: Rscript 3_cargar_catalogo.R --actualizar
#   PASO 4 — INFORME -> 4_generar_informe.R
#            Cruza el mes limpio contra el catálogo, valida que no queden
#            filas sin CLASE/TARIFA y genera informe_MM.YY_V.1.0.html y
#            informe_MM.YY_V.2.0.html.
#   PASO 5 — PDF -> 5_exportar_pdf.R
#            Exporta las versiones HTML a PDF con Chrome headless
#            (conserva tablas, colores y estilos).
#
# FLUJO NORMAL DE UN MES: 1 -> 2 -> 4 -> 5 (el Paso 3 es OPCIONAL).
# El informe es RE-EJECUTABLE: si cambia el catálogo del tarifario, basta
# re-ejecutar 3 (--actualizar) + 4 (+ 5) y el informe se regenera.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. INSTALACIÓN DE LIBRERÍAS (¡SOLO SI ES NECESARIO!)
# ------------------------------------------------------------------------------
# Dejamos las líneas comentadas con un '#' para que R las ignore. Solo las
# descomentarías si vas a correr este código en una computadora nueva.

# install.packages("tidyverse")
# install.packages("readxl")
# install.packages("writexl")
# install.packages("stringi")
# install.packages("rstudioapi")
# install.packages("stringdist")

# ------------------------------------------------------------------------------
# 2. CARGA DE LIBRERÍAS GLOBALES (CON CONTROL DE CONFLICTOS)
# ------------------------------------------------------------------------------
# Se cargan primero las librerías secundarias y al FINAL Tidyverse, para que sus
# funciones ('filter', 'lag') tengan la máxima prioridad en memoria.

invisible(lapply(
  c("readxl", "writexl", "readr", "stringi", "stringdist", "rstudioapi"),
  library,
  character.only = TRUE,
  quietly = TRUE,
  warn.conflicts = FALSE
))

library(
  tidyverse,
  warn.conflicts = FALSE,
  quietly = TRUE
)

# ==============================================================================
# 3. ORQUESTACIÓN INTERACTIVA (ASISTENTE PASO A PASO)
# ==============================================================================
# main.R es un ASISTENTE INTERACTIVO: al ejecutarlo (botón 'Source' en RStudio)
# le pide el mes una sola vez y luego recorre el flujo paso a paso, mostrando un
# breve resumen de cada paso y preguntando antes de ejecutar.
#
#   PASO 1 — CARGA DEL MES   (1_cargar_mes.R):     elige el .xlsx crudo del mes
#   PASO 2 — NORMALIZACIÓN   (2_limpiar_mes.R):    obligatorio, STTEXT=Aprobado
#   PASO 3 — TARIFARIO       (3_cargar_catalogo.R): OPCIONAL, solo si cambió el precio
#   PASO 4 — INFORME         (4_generar_informe.R): V.1.0 y V.2.0 en HTML
#   PASO 5 — PDF             (5_exportar_pdf.R):    exporta HTML -> PDF
#
# Los scripts se cargan con source() (solo definen sus funciones; gracias a la
# guarda 'sys.nframe() == 0' no ejecutan nada al ser source()).

# Cargar las funciones de cada paso (sin ejecutarlos)
source("1_cargar_mes.R")        # cargar_mes(mm_yy)
source("2_limpiar_mes.R")       # limpiar_mes_archivo(mm_yy)
source("3_cargar_catalogo.R")   # actualizar_insumos(actualizar)
source("4_generar_informe.R")   # generar_informe_mes(mm_yy)
source("5_exportar_pdf.R")      # exportar_pdf(mm_yy)

# --- Utilidades del asistente -----------------------------------------------

# Pregunta sí/no en la consola (vacío o 's' = sí).
preguntar_si_no <- function(mensaje) {
  repeat {
    r <- tolower(trimws(readline(prompt = mensaje)))
    if (r %in% c("s", "n")) return(r == "s")
    if (r == "") return(TRUE)
    cat("   Responda 's' (sí) o 'n' (no).\n")
  }
}

# Pide un mes en formato MM.YY (acepta 07.26 o 07.2026) y lo normaliza a MM.YY.
pedir_mes_interactivo <- function() {
  repeat {
    mm_yy <- trimws(readline(prompt = "   Mes/año (MM.YY, ej. 07.26): "))
    mm_txt   <- sub("[.].*$", "", mm_yy)
    anio_txt <- sub("^[0-9]{2}[.]", "", mm_yy)
    if (grepl("^[0-9]{2}$", mm_txt) && grepl("^[0-9]{2,4}$", anio_txt)) {
      yy <- if (nchar(anio_txt) == 4) substr(anio_txt, 3, 4) else anio_txt
      return(paste0(mm_txt, ".", yy))
    }
    cat("   Formato inválido. Use MM.YY (ej. 07.26).\n")
  }
}

# Ejecuta un paso con su resumen y confirmación. Devuelve TRUE si se ejecutó OK.
ejecutar_paso <- function(numero, titulo, resumen, fn) {
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat(" PASO", numero, "—", titulo, "\n")
  cat(strrep("=", 70), "\n", sep = "")
  cat(resumen, "\n\n")
  if (!preguntar_si_no(sprintf("   ¿Ejecutar el PASO %s ahora? (s/n): ", numero))) {
    cat("   Paso omitido por el usuario.\n")
    return(invisible(FALSE))
  }
  ok <- tryCatch({
    fn()
    TRUE
  }, error = function(e) {
    cat("\n   [!] ERROR en el PASO", numero, ":\n     ", conditionMessage(e), "\n")
    FALSE
  })
  if (ok) cat("\n   [OK] PASO", numero, "completado.\n")
  invisible(ok)
}

# --- Asistente principal -----------------------------------------------------

main_interactivo <- function() {

  cat("\n")
  cat("=====================================================================\n")
  cat(" INFORME MENSUAL CT 086 — ASISTENTE INTERACTIVO\n")
  cat("=====================================================================\n")
  cat(" Este asistente lo guía mes a mes para generar el informe de ejecución\n")
  cat(" en dos versiones (HTML y PDF). Flujo de un mes normal:\n")
  cat("\n")
  cat("   PASO 1  Cargar el mes          (elige el .xlsx crudo del mes)\n")
  cat("   PASO 2  Normalizar el mes      (obligatorio: STTEXT = Aprobado)\n")
  cat("   PASO 3  Actualizar tarifario   (OPCIONAL: solo si cambiaron precios)\n")
  cat("   PASO 4  Generar el informe     (V.1.0 resumida + V.2.0 detallada)\n")
  cat("   PASO 5  Exportar a PDF         (Chrome headless, conserva estilos)\n")
  cat("=====================================================================\n")

  if (!interactive()) {
    cat("\n[!] Este asistente es INTERACTIVO. Debe ejecutarse en RStudio\n")
    cat("    (abrir main.R y pulsar 'Source') o en una consola interactiva.\n")
    cat("    Si lo corre por Rscript, use los scripts por separado con su fecha\n")
    cat("    (ver MANUAL_DE_USUARIO.md, sección de comandos).\n")
    return(invisible(NULL))
  }

  cat("\n--- Antes de empezar ---\n")
  if (!preguntar_si_no("   ¿Tiene a mano el archivo .xlsx del mes que va a procesar? (s/n): ")) {
    cat("   Es necesario tener el .xlsx del mes. Deteniendo el asistente.\n")
    return(invisible(NULL))
  }

  # 1) Se pide el mes UNA sola vez y se usa en todos los pasos.
  mm_yy <- pedir_mes_interactivo()
  cat("   [i] Mes a procesar:", mm_yy, "\n")

  # 2) PASO 1 — CARGAR EL MES
  ejecutar_paso(
    1,
    "CARGAR EL MES",
    paste0("Seleccione el archivo .xlsx crudo del mes y la hoja correspondiente.\n",
           "   El asistente lo guardará como datos/m.", gsub("[.]", ".", mm_yy),
           ".rds (re-ejecutable por mes)."),
    function() cargar_mes(mm_yy)
  )

  # 3) PASO 2 — NORMALIZAR (OBLIGATORIO; el Paso 4 lo exige)
  ejecutar_paso(
    2,
    "NORMALIZAR EL MES (OBLIGATORIO)",
    paste0("Aplica las mismas correcciones del pipeline anual: conserva solo\n",
           "   STTEXT = Aprobado (excluye 'Philips, Admin'), quita la 'L' final de\n",
           "   los códigos, mapea PRESTACION -> CODIGO y respalda por similitud vs\n",
           "   CUPS.2025. Garantiza 0 filas sin código y genera artefactos de\n",
           "   trazabilidad (datos/m.", gsub("[.]", ".", mm_yy), "_normalizacion.*)."),
    function() limpiar_mes_archivo(mm_yy)
  )

  # 4) PASO 3 — OPCIONAL: solo si cambiaron los precios del tarifario
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat(" PASO 3 — ACTUALIZAR EL TARIFARIO (OPCIONAL)\n")
  cat(strrep("=", 70), "\n", sep = "")
  cat(" Este paso solo hace falta cuando cambian los precios en el proyecto\n")
  cat(" tarifario (tarifario_CTO_086_V_2). Si el tarifario ya está en 'datos/'\n")
  cat(" y los precios no cambiaron, puede omitirlo.\n\n")
  if (preguntar_si_no("   ¿Cambiaron los precios del tarifario desde la última vez? (s/n): ")) {
    ejecutar_paso(
      3,
      "ACTUALIZAR EL TARIFARIO",
      "Copia el tarifario nuevo (Tarifario_CTO_086_2026.xlsx) desde el proyecto\n   tarifario hacia 'datos/' y verifica que los insumos estén listos.",
      function() actualizar_insumos(actualizar = TRUE)
    )
  } else {
    cat("   Se omite el Paso 3 (los precios no cambiaron).\n")
    # Verificación rápida sin cambios, para confirmar que los insumos existen.
    actualizar_insumos(actualizar = FALSE)
  }

  # 5) PASO 4 — GENERAR EL INFORME
  ejecutar_paso(
    4,
    "GENERAR EL INFORME",
    paste0("Cruza el mes normalizado (datos/m.", gsub("[.]", ".", mm_yy),
           "_limpio.rds) contra el tarifario,\n   valida que no queden filas sin ",
           "CLASE/TARIFA y genera:\n     - informe_", gsub("[.]", ".", mm_yy),
           "_V.1.0.html (resumida)\n     - informe_", gsub("[.]", ".", mm_yy),
           "_V.2.0.html (detallada)"),
    function() generar_informe_mes(mm_yy)
  )

  # 6) PASO 5 — EXPORTAR A PDF
  ejecutar_paso(
    5,
    "EXPORTAR A PDF",
    paste0("Convierte los HTML del mes (informe_", gsub("[.]", ".", mm_yy),
           "_V.*.html) a PDF con Chrome\n   headless, conservando tablas, colores y estilos."),
    function() exportar_pdf(mm_yy)
  )

  # 7) RESUMEN FINAL
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat(" RESUMEN FINAL — MES", mm_yy, "\n")
  cat(strrep("=", 70), "\n", sep = "")
  archivos <- c(
    paste0("datos/m.", mm_yy, ".rds"),
    paste0("datos/m.", mm_yy, "_limpio.rds"),
    paste0("informe_", mm_yy, "_V.1.0.html"),
    paste0("informe_", mm_yy, "_V.2.0.html"),
    paste0("informe_", mm_yy, "_V.1.0.pdf"),
    paste0("informe_", mm_yy, "_V.2.0.pdf")
  )
  for (a in archivos) {
    cat(if (file.exists(a)) "  [x]" else "  [ ]", " ", a, "\n", sep = "")
  }
  cat(strrep("=", 70), "\n", sep = "")
  cat(" Listo. Puede re-ejecutar los Pasos 4 y 5 si cambia el tarifario.\n")
  cat(" Ver MANUAL_DE_USUARIO.md ante cualquier duda.\n")
}

main_interactivo()
