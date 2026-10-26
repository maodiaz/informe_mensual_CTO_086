# ==============================================================================
# PROYECTO: INFORME MENSUAL CT 086
# SCRIPT: 6_generar_borrador.R — INFORME BORRADOR V.3.0 (BORRADOR / NO DEFINITIVO)
# ------------------------------------------------------------------------------
# Genera la versión V.3.0 de los informes de los meses indicados usando un
# TARIFARIO ALTERNATIVO con precios que NO son definitivos:
#
#   datos/Tarifario_CTO_086_2026_BORRADOR.xlsx
#
# La V.3.0 es la tabla DETALLADA por código (igual que la V.2.0) más dos
# columnas adicionales por código: ADICIONAL y CTO_086.
#
# GARANTÍAS (no toca nada oficial):
#   - NO modifica datos/Tarifario_CTO_086_2026.xlsx (el tarifario oficial).
#   - NO sobrescribe informe_MM.YY_V.1.0.* ni informe_MM.YY_V.2.0.*
#     (escribe archivos NUEVOS informe_MM.YY_V.3.0.html / .pdf).
#
# USO:
#   Rscript 6_generar_borrador.R                 # genera 06.26 y 07.26
#   Rscript 6_generar_borrador.R 06.26 07.26     # solo los meses indicados
#   Rscript 6_generar_borrador.R 06.26 --sin-pdf # solo HTML
#
# PREREQUISITOS: los meses ya normalizados en 'datos/'
#   (m.MM.YY_limpio.rds, generados por el Paso 2).
# ==============================================================================

invisible(lapply(c("readr", "readxl", "dplyr", "stringdist", "stringi"), library,
                 character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE))

# --- 1. Argumentos --------------------------------------------------------------
args      <- commandArgs(trailingOnly = TRUE)
generar_pdf <- !("--sin-pdf" %in% args)
meses     <- args[!startsWith(args, "--")]
if (length(meses) == 0) meses <- c("06.26", "07.26")

# Cantidad de HORA JUNTA MEDICA por mes: se replica la del informe OFICIAL
# correspondiente (verificada en los HTML oficiales) para que el borrador sea
# comparable. Ajuste aquí si cambia para algún mes.
junta_por_mes <- c("06.26" = 105L, "07.26" = 116L,
                   "08.26" = 100L, "09.26" = 100L)

# --- 2. Tarifario del borrador --------------------------------------------------
ruta_borrador <- file.path(getwd(), "datos", "Tarifario_CTO_086_2026_BORRADOR.xlsx")
if (!file.exists(ruta_borrador)) {
  stop("No se encontró el tarifario del borrador:\n  ", ruta_borrador,
       "\n\nCópielo del oficial y luego ajuste los precios en Excel:\n  ",
       "cp datos/Tarifario_CTO_086_2026.xlsx datos/Tarifario_CTO_086_2026_BORRADOR.xlsx")
}

# --- 3. Funciones del pipeline (solo las definen, no las ejecutan) --------------
source("4_generar_informe.R")   # generar_informe_mes()
source("5_exportar_pdf.R")      # exportar_pdf()

# --- 4. Generación --------------------------------------------------------------
cat("\n======================================================================\n")
cat(" INFORME BORRADOR V.3.0 — PRECIOS NO DEFINITIVOS\n")
cat(" Tarifario : ", ruta_borrador, "\n", sep = "")
cat(" Meses     : ", paste(meses, collapse = ", "), "\n", sep = "")
cat(" Versión   : V.3.0 (detallada por código + ADICIONAL y CTO_086)\n")
cat("======================================================================\n")

for (m in meses) {
  cat("\n------------------------------ MES ", m, " ------------------------------\n", sep = "")
  cj <- if (m %in% names(junta_por_mes)) junta_por_mes[[m]] else NULL
  if (is.null(cj)) {
    warning("No hay cantidad de HORA JUNTA MEDICA definida para ", m,
            "; se usará el valor por defecto (100). Agréguela a 'junta_por_mes'.")
  }
  # HTML V.3.0 con el tarifario del borrador
  generar_informe_mes(m, version = "3.0", ruta_tarifario = ruta_borrador,
                      cant_junta_param = cj)

  if (generar_pdf) {
    exportar_pdf(m, version = "3.0")
  }
}

cat("\n======================================================================\n")
cat(" LISTO. Archivos generados (borrador, no definitivos):\n")
for (m in meses) {
  cat("   informe_", m, "_V.3.0.html\n", sep = "")
  if (generar_pdf) cat("   informe_", m, "_V.3.0.pdf\n", sep = "")
}
cat("\n Los informes oficiales V.1.0 y V.2.0 NO se modificaron.\n")
cat("======================================================================\n")
