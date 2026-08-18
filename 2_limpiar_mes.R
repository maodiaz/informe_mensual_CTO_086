# ==============================================================================
# PROYECTO: INFORME MENSUAL CT 086
# SCRIPT AUXILIAR: 2_limpiar_mes.R — LIMPIEZA/NORMALIZACIÓN DE UN MES CRUDO
# ------------------------------------------------------------------------------
# TRASLADO de 'recuento_estudios_anual/limpiar_mes.R': aplica a un mes crudo
# (datos/m.MM.YY.rds) las MISMAS correcciones del pipeline anual, para que el
# informe de un mes sea consistente con el histórico:
#   1) Conservar SOLO las filas con STTEXT = "Aprobado" (equivale a descartar
#      las que tenían DOCTEXT vacío) y excluir además las administrativas
#      "Philips, Admin".
#   2) Quitar la 'L' final de CODIGO (879301L -> 879301), igual que el script 6.
#   3) Asignar código a celdas vacías/NA con el MAPEO DURO PRESTACION -> CODIGO
#      (idéntico al script 5) y respaldo por similitud (Jaro-Winkler) vs
#      CUPS.2025 (xlsx, aportado por el usuario) para las que no estén en el mapeo.
#   4) Descartar la prestación sin código único ("AG BIOPSIA ... DE GLÁNDULA").
#
# NOTA: el proyecto es AUTOCONTENIDO. NO usa lista_unica_codigos_2020_2026.rds
# (su columna de descripción canónica no la usa el informe).
#
# Define:
#   limpiar_mes(mes, cups = NULL, lista = NULL, verbose = TRUE)  -> mes limpio
#   limpiar_mes_archivo(mm_yy = "07.26")                         -> limpia y guarda
#                                                                   datos/m.MM.YY_limpio.rds
#
# RECUENTO: el objetivo es que NINGUNA fila quede con código vacío/NA. La
# función hace el recuento por etapa (inicial, con 'L', por mapeo, por
# similitud y final) y lo muestra EN PANTALLA al usuario (verbose = TRUE).
# Además, limpiar_mes_archivo() guarda ARTEFACTOS DE TRAZABILIDAD:
#   - CSV (resumen + detalle de códigos asignados) para abrir en Excel, y
#   - un INFORME LEGIBLE (HTML + PDF) redactado para usuarios SIN conocimientos
#     técnicos, que explica en lenguaje sencillo qué hizo la normalización.
# Si al final quedaran filas sin código, se listan para revisión.
#
# Modo standalone (Rscript 2_limpiar_mes.R MM.YY): limpia datos/m.MM.YY.rds y
# guarda datos/m.MM.YY_limpio.rds con el recuento en pantalla. Al ser source()
# desde otro script solo se definen las funciones (no se ejecuta nada).
#
# NOTA: los insumos auxiliares se leen desde 'datos/': CUPS.2025.xlsx (lo aporta
# el usuario; respaldo CUPS.2025.rds). El tarifario (Tarifario_CTO_086_2026.xlsx)
# lo aporta el usuario; el Paso 3 verifica/actualiza si hace falta.
# ==============================================================================

invisible(lapply(c("readr", "readxl", "dplyr", "stringdist", "stringi"), library,
                 character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE))

# --- Helpers -------------------------------------------------------------------
norm_txt <- function(x) {
  x <- toupper(as.character(x))
  x <- stringi::stri_trans_general(x, "Latin-ASCII")
  x <- gsub("[[:punct:]]", " ", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

# --- 1. limpiar_mes() -----------------------------------------------------------
# Muestra en pantalla el recuento de la limpieza (resumen por etapas).
imprimir_resumen_limpieza <- function(mes, l) {
  cat("\n===== RECUENTO DE LIMPIEZA DEL MES =====\n")
  cat("Filas crudas                     :", l$filas_crudas, "\n")
  cat("Descartes STTEXT ≠ Aprobado      :", l$n_vac, "(equivale a DOCTEXT vacío)\n")
  cat("Descartes \"Philips, Admin\"       :", l$n_phil, "\n")
  cat("Filas tras descartes             :", nrow(mes), "\n")
  cat("Códigos con 'L' final            :", l$n_con_L, "(normalizados sin la L)\n")
  cat("Códigos vacíos/NA al inicio      :", l$vacios_inicial, "\n")
  cat("  - asignados por mapeo (script 5):", l$n_mapeo, "\n")
  cat("  - asignados por similitud        :", l$n_similitud, "\n")
  cat("  - restantes tras similitud       :", l$vacios_post_similitud, "\n")
  cat("Prestación sin código descartada  :", l$n_desc, "(AG BIOPSIA ... DE GLÁNDULA)\n")
  cat("Filas resultantes                 :", nrow(mes), "\n")
  cat("CÓDIGOS VACÍOS/NA AL FINAL        :", l$vacios_final, "\n")
  if (l$vacios_final == 0) {
    cat("ESTADO: ✓ NINGUNA FILA SIN CÓDIGO (objetivo cumplido)\n")
  } else {
    cat("ESTADO: ✗ QUEDAN", l$vacios_final, "FILAS SIN CÓDIGO — revisar:\n")
    print(l$restantes)
  }
  cat("=====================================\n")
}

limpiar_mes <- function(mes, cups = NULL, verbose = TRUE) {
  filas_crudas <- nrow(mes)

  # CUPS: lo aporta el usuario como xlsx (CUPS.2025.xlsx). Respaldo: rds.
  if (is.null(cups)) {
    ruta_cups_xlsx <- file.path(getwd(), "datos", "CUPS.2025.xlsx")
    ruta_cups_rds  <- file.path(getwd(), "datos", "CUPS.2025.rds")
    if (file.exists(ruta_cups_xlsx)) {
      cups <- readxl::read_excel(ruta_cups_xlsx)
    } else if (file.exists(ruta_cups_rds)) {
      cups <- readr::read_rds(ruta_cups_rds)
    } else {
      stop("No se encontró CUPS.2025 en 'datos/' (xlsx o rds). ",
           "Coloque 'CUPS.2025.xlsx' o ejecute: Rscript 3_cargar_catalogo.R --actualizar")
    }
  }

  # CUPS limpio (6 dígitos, sin NA, únicos) — para el respaldo por similitud
  cups_u <- cups %>%
    dplyr::filter(grepl("^[0-9]{5,6}$", as.character(CODIGO)),
                  !is.na(DESCRIPCION), trimws(as.character(DESCRIPCION)) != "") %>%
    dplyr::distinct(CODIGO, .keep_all = TRUE)
  cups_u$CODIGO <- sprintf("%06d", as.integer(cups_u$CODIGO))

  # --- Recuento inicial de códigos vacíos/NA -----------------------------------
  vacios_inicial <- sum(is.na(mes$CODIGO) | trimws(as.character(mes$CODIGO)) == "")

  # --- 1) Descartes: conservar SOLO filas con STTEXT = "Aprobado" --------------
  # (Verificado con datos reales: STTEXT = "Aprobado" coincide exactamente con
  #  DOCTEXT con texto; las filas no aprobadas son las que antes se descartaban
  #  por DOCTEXT vacío. El filtro principal pasa a ser el ESTADO.)
  sttext   <- tolower(trimws(as.character(mes$STTEXT)))
  aprobado <- !is.na(sttext) & sttext == "aprobado"   # NA en STTEXT = no aprobado
  n_vac    <- sum(!aprobado)   # filas NO aprobadas o sin estado (equivale a DOCTEXT vacío)
  # Excluir además las filas administrativas "Philips, Admin" (son Aprobado)
  doctext <- as.character(mes$DOCTEXT)
  philips <- grepl("Philips, Admin", doctext, fixed = TRUE)
  n_phil  <- sum(philips)
  mes     <- mes[aprobado & !philips, , drop = FALSE]

  # --- Completar DOCTEXT desde TECHTEXT cuando falta (solo filas Aprobado) ---
  # 07.26: 2 filas aprobadas sin doctor; TECHTEXT trae el nombre del doctor.
  # Se copia TECHTEXT -> DOCTEXT para atribuir las filas a su doctor.
  idx_sin_doctor <- which(is.na(mes$DOCTEXT) | trimws(as.character(mes$DOCTEXT)) == "")
  if (length(idx_sin_doctor) > 0) {
    tec  <- as.character(mes$TECHTEXT[idx_sin_doctor])
    llenar <- !is.na(tec) & trimws(tec) != ""
    if (any(llenar)) {
      cat("  [i] DOCTEXT completado desde TECHTEXT en", sum(llenar), "fila(s)\n")
      mes$DOCTEXT[idx_sin_doctor[llenar]] <- tec[llenar]
    }
  }

  # --- 2) Quitar la 'L' final de CODIGO (879301L -> 879301) --------------------
  n_con_L <- sum(grepl("L$", trimws(as.character(mes$CODIGO))))
  mes$CODIGO <- sub("L$", "", trimws(as.character(mes$CODIGO)))

  # --- 3) Mapeo duro PRESTACION -> CODIGO (idéntico al script 5) ---------------
  vacios_vec_pre_mapeo <- is.na(mes$CODIGO) | trimws(as.character(mes$CODIGO)) == ""
  vacios_pre_mapeo <- sum(vacios_vec_pre_mapeo)
  mes <- mes %>%
    dplyr::mutate(
      CODIGO = dplyr::case_when(
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "CT AXIAL COMPUTADA EN RECONSTRUCCION TRIDIMENSIONAL" ~ "879910",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "RM LECTURA RESONANCIA DE SISTEMA MUSCULO ESQUELETICO NCOC" ~ "883590",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "RM RESONANCIA MAGNÉTICA DE VÍA URINARIA [URORRESONANCIA]" ~ "883435",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "US DOPPLER DE VASOS ARTERIALES DE MIEMBROS INFERIORES" ~ "882308",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "US TORACENTESIS DIAGNÓSTICA" ~ "345001",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "RX DE ESOFAGO" ~ "871320",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "AG OCLUSION DE VASOS DE MIEMBROS SUPERIORES, VIA ENDOVAS" ~ "385320",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "AG SIALOGRAFIA (CUALQUIER GLANDULA) SOD" ~ "874701",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "CT BIOPSIA DE TEJIDO BLANDO:MUSCULOS, TENDON, FACIA Y BURSA" ~ "832102",
        (is.na(CODIGO) | CODIGO == "") &
          trimws(PRESTACION) == "RX LECTURA RADIOGRAFIA DE CRANEO SIMPLE" ~ "870001",
        # Seguro de vida: conserva el código original si no aplica ninguna regla
        TRUE ~ CODIGO
      )
    )
  vacios_vec_post_mapeo <- is.na(mes$CODIGO) | trimws(as.character(mes$CODIGO)) == ""
  vacios_post_mapeo <- sum(vacios_vec_post_mapeo)
  n_mapeo <- vacios_pre_mapeo - vacios_post_mapeo

  # Detalle (trazabilidad): filas a las que se asignó código por mapeo
  idx_mapeo <- which(vacios_vec_pre_mapeo & !vacios_vec_post_mapeo)
  det_mapeo <- if (length(idx_mapeo) > 0) {
    data.frame(
      PRESTACION = mes$PRESTACION[idx_mapeo],
      CODIGO     = mes$CODIGO[idx_mapeo],
      METODO     = "mapeo (script 5)",
      stringsAsFactors = FALSE
    ) %>% dplyr::distinct()
  } else {
    NULL
  }

  # --- 4) Respaldo por similitud vs CUPS.2025 para celdas aún vacías -----------
  na_rows <- is.na(mes$CODIGO) | trimws(as.character(mes$CODIGO)) == ""
  n_similitud <- sum(na_rows)
  det_sim <- NULL
  if (n_similitud > 0) {
    prest_n   <- norm_txt(mes$PRESTACION)
    cups_desc <- norm_txt(cups_u$DESCRIPCION)
    dm  <- stringdist::stringdistmatrix(prest_n[na_rows], cups_desc, method = "jw")
    sim <- 1 - dm
    cod_final <- as.character(mes$CODIGO)
    idx <- which(na_rows)
    for (k in seq_along(idx)) {
      if (is.na(prest_n[idx[k]])) next   # sin descripción: no se puede asignar por similitud
      j <- which.max(sim[k, ])
      cod_final[idx[k]] <- cups_u$CODIGO[j]
    }
    mes$CODIGO <- cod_final

    # Detalle (trazabilidad): filas a las que se asignó código por similitud
    det_sim <- data.frame(
      PRESTACION = mes$PRESTACION[idx],
      CODIGO     = cod_final[idx],
      METODO     = "similitud (CUPS.2025)",
      stringsAsFactors = FALSE
    ) %>% dplyr::distinct()
  }
  vacios_post_similitud <- sum(is.na(mes$CODIGO) | trimws(as.character(mes$CODIGO)) == "")

  # --- 5) Descartar la prestación sin código único -----------------------------
  prestacion_descartada <- "AG BIOPSIA [PERCUTANEA] [AGUJA] DE GLÁNDULA"
  n_desc <- sum(trimws(as.character(mes$PRESTACION)) == prestacion_descartada)
  mes <- mes[trimws(as.character(mes$PRESTACION)) != prestacion_descartada, , drop = FALSE]

  # --- Recuento final: ninguna fila debe quedar sin código ---------------------
  vacios_final_vec <- is.na(mes$CODIGO) | trimws(as.character(mes$CODIGO)) == ""
  vacios_final <- sum(vacios_final_vec)
  restantes <- NULL
  if (vacios_final > 0) {
    restantes <- as.data.frame(
      table(trimws(as.character(mes$PRESTACION[vacios_final_vec]))),
      stringsAsFactors = FALSE
    )
    names(restantes) <- c("PRESTACION", "N_FILAS")
  }

  # Detalle combinado de códigos asignados (mapeo + similitud) — trazabilidad
  asignados <- rbind(det_mapeo, det_sim)
  if (!is.null(asignados) && nrow(asignados) == 0) asignados <- NULL

  attr(mes, "limpieza") <- list(
    filas_crudas = filas_crudas,
    n_vac = n_vac, n_phil = n_phil,
    n_asign = n_mapeo + n_similitud,   # compat: total de códigos asignados
    vacios_inicial = vacios_inicial,
    n_con_L = n_con_L,
    n_mapeo = n_mapeo,
    n_similitud = n_similitud,
    vacios_post_similitud = vacios_post_similitud,
    n_desc = n_desc,
    vacios_final = vacios_final,
    restantes = restantes,
    asignados = asignados
  )

  # Mostrar el recuento de la limpieza EN PANTALLA
  if (verbose) imprimir_resumen_limpieza(mes, attr(mes, "limpieza"))

  mes
}

# --- 2. limpiar_mes_archivo() ---------------------------------------------------
limpiar_mes_archivo <- function(mm_yy = "07.26") {
  ruta_in  <- file.path(getwd(), "datos", paste0("m.", mm_yy, ".rds"))
  ruta_out <- file.path(getwd(), "datos", paste0("m.", mm_yy, "_limpio.rds"))
  if (!file.exists(ruta_in)) stop("No se encontró: ", ruta_in)

  cat("====================================================\n")
  cat(" LIMPIAR MES", mm_yy, "\n")
  cat("====================================================\n")
  mes_raw <- readr::read_rds(ruta_in)
  cat("Filas crudas:", nrow(mes_raw), "\n")

  # limpiar_mes() imprime el recuento de la limpieza en pantalla (verbose = TRUE)
  mes <- limpiar_mes(mes_raw)

  readr::write_rds(mes, ruta_out)
  cat("Guardado en:", ruta_out, "\n")
  cat("Códigos vacíos/NA al final:", attr(mes, "limpieza")$vacios_final, "\n")

  # ---------------------------------------------------------------------------
  # ARTEFACTO DE TRAZABILIDAD: resumen de la normalización (legible, no caja negra)
  # Se guarda un CSV con los cambios realizados para que el usuario pueda leerlos.
  # ---------------------------------------------------------------------------
  l <- attr(mes, "limpieza")
  filas_tras_descartes <- l$filas_crudas - l$n_vac - l$n_phil
  resumen <- data.frame(
    concepto = c(
      "Mes procesado",
      "Filas crudas del mes",
      "Filas descartadas (STTEXT ≠ Aprobado)",
      "Filas descartadas (DOCTEXT = Philips, Admin)",
      "Filas tras descartes",
      "Códigos con 'L' final normalizados",
      "Códigos vacíos al inicio",
      "Códigos asignados por mapeo (script 5)",
      "Códigos asignados por similitud (CUPS.2025)",
      "Códigos vacíos tras la asignación",
      "Prestación sin código descartada",
      "Filas resultantes (mes normalizado)",
      "Códigos vacíos/NA al final"
    ),
    cantidad = c(
      mm_yy, l$filas_crudas, l$n_vac, l$n_phil, filas_tras_descartes,
      l$n_con_L, l$vacios_inicial, l$n_mapeo, l$n_similitud,
      l$vacios_post_similitud, l$n_desc, nrow(mes), l$vacios_final
    ),
    nota = c(
      "Mes y año del archivo procesado",
      "Filas que traía el Excel original",
      "Se eliminan: su estado no es APROBADO (equivale a DOCTEXT vacío)",
      "Se eliminan: filas administrativas",
      "Crudas menos los descartes anteriores",
      "Ej.: 879301L -> 879301",
      "Celdas de código sin valor antes de asignar",
      "Código asignado con la tabla de mapeo conocida",
      "Código asignado por parecido con CUPS.2025",
      "Celdas aún vacías tras mapeo + similitud",
      "AG BIOPSIA ... DE GLÁNDULA (no tiene código único)",
      "Filas que quedan listas para el informe",
      if (l$vacios_final == 0) "OK - ninguna fila sin código" else "REVISAR - quedan filas sin código"
    ),
    stringsAsFactors = FALSE
  )
  ruta_resumen <- file.path(getwd(), "datos", paste0("m.", mm_yy, "_normalizacion.csv"))
  readr::write_csv(resumen, ruta_resumen)
  cat("Artefacto de normalización (resumen) :", ruta_resumen, "\n")

  # Detalle de códigos asignados (solo si hubo cambios)
  det <- l$asignados
  if (!is.null(det) && nrow(det) > 0) {
    ruta_detalle <- file.path(getwd(), "datos", paste0("m.", mm_yy, "_normalizacion_detalle.csv"))
    readr::write_csv(det, ruta_detalle)
    cat("Artefacto de normalización (detalle) :", ruta_detalle, "\n")
  } else {
    cat("Artefacto de normalización (detalle) : no hubo códigos asignados (sin archivo)\n")
  }

  # Informe legible de la normalización (HTML + PDF) para el usuario no técnico
  generar_informe_normalizacion(mm_yy, l, mes)
}

# --- 2.1 localizar_chrome() -----------------------------------------------------
# Busca el navegador (Chrome/Chromium/Edge) para convertir HTML a PDF.
localizar_chrome <- function() {
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
  for (c in candidatos) if (file.exists(c)) return(c)
  NULL
}

# --- 2.2 generar_informe_normalizacion() ---------------------------------------
# Genera un documento explicativo (HTML -> PDF) con el resumen y el detalle de la
# normalización, redactado para un usuario SIN conocimientos técnicos. Además de
# los CSV (para abrir en Excel), se deja un informe legible e imprimible.
generar_informe_normalizacion <- function(mm_yy, l, mes,
                                          carpeta = file.path(getwd(), "datos")) {
  fmt_n <- function(x) format(round(x), big.mark = ".", decimal.mark = ",",
                              scientific = FALSE, trim = TRUE)
  esc <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
  }

  filas_tras_descartes <- l$filas_crudas - l$n_vac - l$n_phil
  estado_ok <- l$vacios_final == 0
  estado_txt <- if (estado_ok) "OK: ninguna fila quedó sin código" else "REVISAR: quedaron filas sin código"

  # --- Párrafos narrativos (lenguaje sencillo) ---------------------------------
  parrafo_que_es <- paste0(
    "<p>Este documento explica de forma sencilla qué se hizo con el archivo del mes ",
    "<strong>", mm_yy, "</strong> al <strong>normalizar los datos</strong>. Normalizar es ",
    "preparar la información para poder calcular el informe: se quitan las filas que no ",
    "sirven (por ejemplo, las que no tienen estado APROBADO o las filas administrativas), ",
    "se corrigen los códigos y se completan los que faltan, de modo que <strong>todas las filas ",
    "queden con su código</strong> y listas para compararlas con el tarifario de precios.</p>"
  )

  parrafo_resumen <- paste0(
    "<p>El archivo original traía <strong>", fmt_n(l$filas_crudas), "</strong> filas. ",
    "Durante la normalización se <strong>descartaron ", fmt_n(l$n_vac),
    "</strong> filas porque su estado no era APROBADO y <strong>", fmt_n(l$n_phil),
    "</strong> filas administrativas (\u201CPhilips, Admin\u201D), por lo que quedaron <strong>",
    fmt_n(filas_tras_descartes), "</strong> filas. Se normalizaron <strong>", fmt_n(l$n_con_L),
    "</strong> códigos que terminaban en \u201CL\u201D y se <strong>completaron ",
    fmt_n(l$n_asign), "</strong> códigos que estaban vacíos (", fmt_n(l$n_mapeo),
    " con la tabla de correspondencias conocida y ", fmt_n(l$n_similitud),
    " buscando el parecido con CUPS.2025). Al final quedaron <strong>", fmt_n(nrow(mes)),
    "</strong> filas, con <strong>", fmt_n(l$vacios_final),
    "</strong> filas sin código. Estado: <strong>", estado_txt, "</strong>.</p>"
  )

  # --- Tabla resumen -----------------------------------------------------------
  resumen_df <- data.frame(
    concepto = c("Mes procesado", "Filas crudas del mes",
                 "Filas descartadas (STTEXT ≠ Aprobado)",
                 "Filas descartadas (DOCTEXT = Philips, Admin)", "Filas tras descartes",
                 "Códigos con 'L' final normalizados", "Códigos vacíos al inicio",
                 "Códigos asignados por mapeo", "Códigos asignados por similitud",
                 "Códigos vacíos tras la asignación", "Prestación sin código descartada",
                 "Filas resultantes (mes normalizado)", "Códigos vacíos/NA al final"),
    cantidad = c(mm_yy, l$filas_crudas, l$n_vac, l$n_phil, filas_tras_descartes,
                 l$n_con_L, l$vacios_inicial, l$n_mapeo, l$n_similitud,
                 l$vacios_post_similitud, l$n_desc, nrow(mes), l$vacios_final),
    nota = c("Mes y año del archivo procesado", "Filas que traía el Excel original",
             "Se eliminan: su estado no es APROBADO (equivale a DOCTEXT vacío)",
             "Se eliminan: filas administrativas",
             "Crudas menos los descartes anteriores", "Ej.: 879301L -> 879301",
             "Celdas de código sin valor antes de asignar", "Código asignado con la tabla conocida",
             "Código asignado por parecido con CUPS.2025", "Celdas aún vacías tras mapeo + similitud",
             "AG BIOPSIA ... DE GLÁNDULA (no tiene código único)",
             "Filas que quedan listas para el informe",
             if (estado_ok) "OK - ninguna fila sin código" else "REVISAR - quedan filas sin código"),
    stringsAsFactors = FALSE
  )
  filas_tabla_resumen <- vapply(seq_len(nrow(resumen_df)), function(i) {
    r <- resumen_df[i, ]
    cantidad_celda <- if (grepl("^Mes procesado$", r$concepto)) esc(r$cantidad) else fmt_n(as.numeric(r$cantidad))
    paste0("<tr><td>", esc(r$concepto), "</td><td class='num'>", cantidad_celda,
           "</td><td>", esc(r$nota), "</td></tr>")
  }, character(1))

  # --- Detalle de códigos asignados ---------------------------------------------
  det <- l$asignados
  if (!is.null(det) && nrow(det) > 0) {
    parrafo_detalle <- paste0(
      "<p>Estos estudios llegaron <strong>sin código</strong> en el archivo del mes y el ",
      "programa les asignó uno automáticamente. \u201Cmapeo\u201D significa que se usó una ",
      "tabla de correspondencias ya conocida; \u201Csimilitud\u201D significa que se buscó el ",
      "código más parecido en CUPS.2025:</p>")
    filas_tabla_detalle <- vapply(seq_len(nrow(det)), function(i) {
      r <- det[i, ]
      paste0("<tr><td>", esc(r$PRESTACION), "</td><td>", esc(r$CODIGO),
             "</td><td>", esc(r$METODO), "</td></tr>")
    }, character(1))
    bloque_detalle <- paste0(
      "<h2>3. Códigos asignados automáticamente</h2>", parrafo_detalle,
      "<table><thead><tr><th>Estudio (PRESTACION)</th><th>Código asignado</th><th>Cómo se asignó</th></tr></thead><tbody>",
      paste(filas_tabla_detalle, collapse = ""), "</tbody></table>")
  } else {
    bloque_detalle <- paste0(
      "<h2>3. Códigos asignados automáticamente</h2>",
      "<p>En este mes no hubo códigos por asignar: todas las filas ya traían su código.</p>")
  }

  # --- Armar el HTML ------------------------------------------------------------
  html <- c(
    "<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'>",
    paste0("<title>Informe de Normalización — Mes ", mm_yy, "</title>"),
    "<style>",
    "body{font-family:Calibri,Arial,sans-serif;margin:40px;color:#222;font-size:11pt}",
    "h1{font-size:18pt;color:#1f4e79;border-bottom:2px solid #1f4e79;padding-bottom:6px}",
    "h2{font-size:13pt;color:#1f4e79;margin-top:24px}",
    "p{text-align:justify;line-height:1.5}",
    "table{border-collapse:collapse;width:100%;font-size:10pt;margin:12px 0}",
    "th,td{border:1px solid #999;padding:5px 8px;text-align:left;vertical-align:top}",
    "th{background:#1f4e79;color:#fff}",
    "td.num{text-align:right;white-space:nowrap}",
    "@media print{body{margin:15mm}}",
    "</style></head><body>",
    paste0("<h1>Informe de Normalización — Mes ", mm_yy, "</h1>"),
    "<p><strong>Fecha de elaboración:</strong> ", format(Sys.Date(), "%Y-%m-%d"), "</p>",
    "<h2>1. ¿Qué es la normalización y por qué se hace?</h2>", parrafo_que_es,
    "<h2>2. Qué se hizo con el mes</h2>", parrafo_resumen,
    "<table><thead><tr><th>Concepto</th><th>Cantidad</th><th>Explicación</th></tr></thead><tbody>",
    paste(filas_tabla_resumen, collapse = ""), "</tbody></table>",
    bloque_detalle,
    "<h2>4. Resultado</h2>",
    paste0("<p>El mes quedó <strong>listo para generar el informe</strong>. Si quiere revisar ",
           "los datos en detalle, también puede abrir los archivos <em>m.", mm_yy,
           "_normalizacion.csv</em> y <em>m.", mm_yy,
           "_normalizacion_detalle.csv</em> (se abren con Excel).</p>"),
    "</body></html>"
  )
  ruta_html <- file.path(carpeta, paste0("m.", mm_yy, "_normalizacion.html"))
  writeLines(html, ruta_html, useBytes = TRUE)
  cat("Informe de normalización (HTML)    :", ruta_html, "\n")

  # Convertir a PDF con Chrome headless (si está disponible)
  chrome <- localizar_chrome()
  if (!is.null(chrome)) {
    ruta_pdf <- file.path(carpeta, paste0("m.", mm_yy, "_normalizacion.pdf"))
    comando <- paste(shQuote(chrome),
                     "--headless --disable-gpu --no-pdf-header-footer",
                     paste0("--print-to-pdf=", shQuote(ruta_pdf)),
                     shQuote(paste0("file://", ruta_html)))
    system(comando, intern = FALSE, ignore.stdout = FALSE, ignore.stderr = TRUE)
    if (file.exists(ruta_pdf) && file.info(ruta_pdf)$size > 0) {
      cat("Informe de normalización (PDF)     :", ruta_pdf, "\n")
    } else {
      warning("No se pudo generar el PDF de normalización; el HTML quedó guardado.")
    }
  } else {
    warning("No se encontró Chrome; el informe de normalización quedó solo en HTML.",
            " Ábralo en el navegador y use 'Imprimir a PDF' si lo necesita.")
  }
  invisible(NULL)
}

# --- Modo standalone (Rscript 2_limpiar_mes.R MM.YY) ----------------------------
# Se ejecuta SOLO si el script se corre directamente; al ser source() desde
# otro script (p. ej. 4_generar_informe.R) solo se definen las funciones.
if (sys.nframe() == 0) {
  args  <- commandArgs(trailingOnly = TRUE)
  mm_yy <- if (length(args) >= 1) args[1] else "07.26"
  limpiar_mes_archivo(mm_yy)
}
