# ==============================================================================
# PROYECTO: INFORME MENSUAL CT 086
# SCRIPT: 5_exportar_pdf.R — EXPORTACIÓN DEL INFORME HTML A PDF
# ------------------------------------------------------------------------------
# Convierte los informes HTML generados (informe_MM.YY_V.1.0.html y
# informe_MM.YY_V.2.0.html) a PDF usando Chrome en modo headless, que
# conserva tablas, colores y estilos (mismo método que 'recuento_estudios_anual').
#
# USO:
#   Rscript 5_exportar_pdf.R MM.YY [version]
#     MM.YY   : mes.año (ej. 07.26 o 07.2026)
#     version : "1.0", "2.0", "3.0" o los que se indiquen (default: 1.0 y 2.0)
#   Salida   : informe_MM.YY_V.{version}.pdf
#
# PREREQUISITO: el HTML debe existir (generarlo antes con 4_generar_informe.R).
#
# Chrome: busca el ejecutable en las rutas habituales (macOS primero):
#   /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
#   /Applications/Chromium.app/Contents/MacOS/Chromium
#   google-chrome / chromium (Linux)
# ==============================================================================

invisible(lapply(c("readr"), library,
                 character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE))

# ------------------------------------------------------------------------------
# 1. Localización de Chrome
# ------------------------------------------------------------------------------
encontrar_chrome <- function() {
  candidatos <- c(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",   # macOS Chrome
    "/Applications/Chromium.app/Contents/MacOS/Chromium",            # macOS Chromium
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge", # macOS Edge
    Sys.which("google-chrome"),                                      # Linux Chrome
    Sys.which("chromium"),                                           # Linux Chromium
    Sys.which("chromium-browser"),
    Sys.which("chrome")
  )
  candidatos <- candidatos[candidatos != ""]
  for (c in candidatos) {
    if (file.exists(c)) return(c)
  }
  return(NULL)
}

# ------------------------------------------------------------------------------
# 2. FUNCIÓN PRINCIPAL: exportar_pdf(mes_arg, version)
# ------------------------------------------------------------------------------
# Convierte informe_MM.YY_V.{version}.html a PDF con Chrome headless.
#   mes_arg : "MM.YY" (acepta 07.26 o 07.2026)
#   version : "1.0", "2.0", "3.0" o los que se indiquen (default: 1.0 y 2.0)
# Al ser source() desde main.R solo se define la función; por Rscript se ejecuta.
exportar_pdf <- function(mes_arg, version = c("1.0", "2.0")) {

  if (missing(mes_arg) || is.null(mes_arg) || trimws(as.character(mes_arg)) == "") {
    stop("Falta el mes. Uso: exportar_pdf(\"MM.YY\") o Rscript 5_exportar_pdf.R MM.YY [version]")
  }
  version <- unique(version)
  if (!all(version %in% c("1.0", "2.0", "3.0"))) {
    stop("Versión(es) inválida(s): ", paste(version, collapse = ", "),
         ". Use '1.0', '2.0' y/o '3.0'.")
  }

  # Normalizar MM.YY (acepta 07.26 o 07.2026)
  mm_txt   <- sub("[.].*$", "", mes_arg)
  anio_txt <- sub("^[0-9]{2}[.]", "", mes_arg)
  if (!grepl("^[0-9]{2}$", mm_txt) || !grepl("^[0-9]{2,4}$", anio_txt)) {
    stop("Formato de mes inválido: '", mes_arg, "'. Use MM.YY (ej. 07.26) o MM.YYYY (ej. 07.2026).")
  }
  yy <- if (nchar(anio_txt) == 4) substr(anio_txt, 3, 4) else anio_txt
  mm_yy <- paste0(mm_txt, ".", yy)

  chrome <- encontrar_chrome()
  if (is.null(chrome)) {
    stop("No se encontró Google Chrome/Chromium. Instálalo o edita 'encontrar_chrome()' ",
         "en 5_exportar_pdf.R con la ruta de tu navegador.")
  }

  # ----------------------------------------------------------------------------
  # 3. Exportación a PDF
  # ----------------------------------------------------------------------------
  cat("====================================================\n")
  cat(" EXPORTAR INFORME A PDF — MES", mm_yy, "\n")
  cat(" Chrome:", chrome, "\n")
  cat("====================================================\n")

  for (v in version) {
    ruta_html <- file.path(getwd(), paste0("informe_", mm_yy, "_V.", v, ".html"))
    ruta_pdf  <- file.path(getwd(), paste0("informe_", mm_yy, "_V.", v, ".pdf"))

    if (!file.exists(ruta_html)) {
      warning("No se encontró el HTML: ", ruta_html,
              " (generarlo antes con 4_generar_informe.R). Se omite la versión ", v, ".")
      next
    }

    cat("\n[>] Exportando:", basename(ruta_html), "->", basename(ruta_pdf), "\n")
    ruta_url <- paste0("file://", ruta_html)

    # --headless --print-to-pdf conserva tablas, colores y estilos
    cmd <- shQuote(chrome)
    comando <- paste(
      cmd,
      "--headless --disable-gpu --no-pdf-header-footer",
      paste0("--print-to-pdf=", shQuote(ruta_pdf)),
      shQuote(ruta_url)
    )

    system(comando, intern = FALSE, ignore.stdout = FALSE, ignore.stderr = TRUE)
    if (file.exists(ruta_pdf) && file.info(ruta_pdf)$size > 0) {
      cat("[OK] PDF generado:", ruta_pdf,
          "(", file.info(ruta_pdf)$size, "bytes )\n")
    } else {
      warning("La exportación de ", basename(ruta_html), " NO produjo PDF. Revisa Chrome.")
    }
  }

  cat("\n====================================================\n")
  cat(" Fin de la exportación a PDF.\n")
  cat("====================================================\n")
}

# ------------------------------------------------------------------------------
# Modo standalone (Rscript 5_exportar_pdf.R MM.YY [version])
# ------------------------------------------------------------------------------
if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) >= 1) {
    version <- if (length(args) >= 2) args[2] else c("1.0", "2.0")
    exportar_pdf(args[1], version)
  } else {
    stop("Uso: Rscript 5_exportar_pdf.R MM.YY [version]")
  }
}
