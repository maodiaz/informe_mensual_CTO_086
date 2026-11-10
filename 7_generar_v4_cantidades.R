# ==============================================================================
# PROYECTO: INFORME MENSUAL CT 086
# SCRIPT: 7_generar_v4_cantidades.R — INFORME V.4.0 (SOLO CANTIDADES, TEMPORAL)
# ------------------------------------------------------------------------------
# Genera la versión 4.0 de un mes: informe de CANTIDADES, sin dinero.
#
# Se construye sobre la V.3.0 (tabla detallada por código) con estos cambios:
#   - TABLA ESTUDIOS        : solo columnas CLASE / CÓDIGO y CANTIDAD.
#                             Sin SUBTOTAL ADICIONALES ni TOTAL.
#   - TABLA PROCEDIMIENTOS  : solo CODIGO / DESCRIPCION / CANTIDAD.
#                             Conserva la fila TOTAL (suma de cantidades).
#   - Se elimina la sección "Valor Ejecutado - Valor por facturar".
#   - El Resumen Ejecutivo y las Salvedades no mencionan precios.
#
# USO:
#   Rscript 7_generar_v4_cantidades.R              # 09.26
#   Rscript 7_generar_v4_cantidades.R 09.26
#   Rscript 7_generar_v4_cantidades.R 09.26 --sin-pdf
#
# NO modifica los informes oficiales (V.1.0/V.2.0), ni los del borrador (V.3.0),
# ni el tarifario oficial.
# ==============================================================================

invisible(lapply(c("readr", "readxl", "dplyr", "stringdist", "stringi"), library,
                 character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE))

# --- 1. Argumentos --------------------------------------------------------------
args        <- commandArgs(trailingOnly = TRUE)
generar_pdf <- !("--sin-pdf" %in% args)
meses       <- args[!startsWith(args, "--")]
if (length(meses) == 0) meses <- "09.26"

# Cantidad de HORA JUNTA MEDICA para esta versión (requisito: 103 en 09.26).
junta_v4 <- c("09.26" = 103L, "10.26" = 105L)

# Tarifario: el mismo del borrador (solo define CLASE y qué códigos son
# PROCEDIMIENTO; no afecta las cantidades).
ruta_borrador <- file.path(getwd(), "datos", "Tarifario_CTO_086_2026_BORRADOR.xlsx")
ruta_tarifario_usar <- if (file.exists(ruta_borrador)) ruta_borrador else NULL

# --- 2. Funciones del pipeline (solo las definen) -------------------------------
source("4_generar_informe.R")   # generar_informe_mes()
source("5_exportar_pdf.R")      # exportar_pdf()

# --- 3. Generación --------------------------------------------------------------
cat("\n======================================================================\n")
cat(" INFORME V.4.0 — SOLO CANTIDADES (temporal)\n")
cat(" Meses : ", paste(meses, collapse = ", "), "\n", sep = "")
cat("======================================================================\n")

for (m in meses) {
  cj <- if (m %in% names(junta_v4)) junta_v4[[m]] else NULL
  if (is.null(cj)) {
    warning("No hay cantidad de HORA JUNTA MEDICA definida para ", m,
            "; se usará el valor por defecto (100). Agréguela a 'junta_v4'.")
  }
  cat("\n------------------------------ MES ", m, " ------------------------------\n", sep = "")
  generar_informe_mes(m, version = "4.0",
                      ruta_tarifario = ruta_tarifario_usar,
                      cant_junta_param = cj)
  if (generar_pdf) exportar_pdf(m, version = "4.0")
}

cat("\n======================================================================\n")
cat(" LISTO. Archivos generados:\n")
for (m in meses) {
  cat("   informe_", m, "_V.4.0.html\n", sep = "")
  if (generar_pdf) cat("   informe_", m, "_V.4.0.pdf\n", sep = "")
}
cat(" Los informes oficiales (V.1.0/V.2.0) y el borrador (V.3.0) NO se modificaron.\n")
cat("======================================================================\n")
