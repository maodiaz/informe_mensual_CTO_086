# ==============================================================================
# PROYECTO: INFORME MENSUAL CT 086
# SCRIPT: 4_generar_informe.R — INFORME RESUMEN DE EJECUCIÓN DE UN MES (m.MM.YY)
# ------------------------------------------------------------------------------
# TRASLADO de 'recuento_estudios_anual/script_informe_mes.R': genera el informe
# imprimible (HTML) para CUALQUIER mes cargado en 'datos/'. La diferencia es la
# FUENTE del catálogo: aquí se cruza contra el TARIFARIO vigente aportado por
# el usuario (datos/Tarifario_CTO_086_2026.xlsx, generado por el proyecto
# 'tarifario_CTO_086_V_2'); respaldo en catalogo_cto086_2026.rds.
#
#   Rscript 4_generar_informe.R MM.YY [version]
#     MM.YY   : mes.año (acepta "07.26" o "07.2026")
#     version : "1.0" (TABLA ESTUDIOS plana), "2.0" (expandida, default) o
#               "3.0" (expandida + columnas ADICIONAL y CTO_086; informe borrador)
#   Salida   : informe_MM.YY_V.{version}.html
#
# Flujo:
#   1) Exige el mes YA NORMALIZADO: datos/m.MM.YY_limpio.rds, producido por el
#      PASO 2 (2_limpiar_mes.R) — OBLIGATORIO. Si no existe, se detiene y pide
#      ejecutar el Paso 2 primero (el mes crudo m.MM.YY.rds NO se usa aquí).
#   2) Lee el mes normalizado y su resumen de limpieza (el RDS normalizado
#      guarda el atributo 'limpieza' con los recuentos del Paso 2).
#   3) Cruza contra el catálogo ACTUAL (datos/catalogo_cto086_2026.rds, el del
#      tarifario CT 086) y muestra el cruce en pantalla, DESTACANDO las filas
#      vacías (sin CLASE o sin TARIFA en el catálogo).
#   4) Valida que TODAS las filas limpias del mes queden con CLASE y TARIFA.
#   5) Genera TABLA ESTUDIOS y TABLA PROCEDIMIENTOS con su valor total SOLO si
#      el cruce está completo (0 filas vacías); en caso contrario NO genera el
#      informe y detiene el proceso. Para cada mes genera las DOS versiones:
#      V.1.0 (TABLA ESTUDIOS resumida/plana) y V.2.0 (detallada/expandida).
#      Las filas HORA JUNTA MEDICA y VALOR FIJO POR SERVICIO DE LA NOCHE toman
#      su TARIFA de tarifas_especiales_2026.xlsx (no están fijas).
#
# NOTA: el informe se mantiene EXACTAMENTE como está hoy (no incorpora la
# columna CTO_086 del catálogo del tarifario).
#
# RE-EJECUTABLE: si cambian las tarifas o el catálogo del tarifario, basta
# re-ejecutar 3_cargar_catalogo.R --actualizar y luego este script para el/los
# mes(es); el informe se regenera con el catálogo vigente. NO modifica el
# pipeline histórico ni el catálogo.
# ==============================================================================

invisible(lapply(c("readr", "readxl", "dplyr", "stringdist", "stringi"), library,
                 character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE))

source("2_limpiar_mes.R")   # define limpiar_mes() (la normalización la hace el PASO 2)

# ================================================================================
# 1. Función principal: generar_informe_mes(mes_arg, version = "2.0")
# ------------------------------------------------------------------------------
# mes_arg        : "MM.YY" (acepta 07.26 o 07.2026)
# version        : "1.0" (TABLA ESTUDIOS plana), "2.0" (expandida, default) o
#                  "3.0" (expandida + ADICIONAL y CTO_086; informe borrador)
# ruta_tarifario : NULL = tarifario OFICIAL de 'datos/' (por defecto);
#                  ruta a un xlsx alternativo (p. ej. un tarifario BORRADOR con
#                  precios no definitivos).
# cant_junta_param : NULL = 100 por Rscript / pregunta en RStudio (por defecto);
#                  número = cantidad fija de HORA JUNTA MEDICA (no pregunta).
# Se invoca por Rscript (4_generar_informe.R MM.YY) o, al ser source() desde
# main.R (PASO 4), llamando directamente a generar_informe_mes("MM.YY").
# Las decisiones se CONSULTAN al usuario en RStudio (interactivo); por Rscript
# se usan los valores por defecto.
# ================================================================================
generar_informe_mes <- function(mes_arg, version = c("1.0", "2.0"),
                                ruta_tarifario = NULL, cant_junta_param = NULL) {

  meses_es <- c("enero","febrero","marzo","abril","mayo","junio","julio",
                "agosto","septiembre","octubre","noviembre","diciembre")

  # --- Consulta de decisiones al usuario (RStudio interactivo) ------------------
  # Por Rscript (no interactivo) devuelve el default sin preguntar.
  preguntar <- function(mensaje, default = "s") {
    if (interactive()) {
      r <- tolower(trimws(readline(prompt = mensaje)))
      if (r == "") r <- default
      r
    } else {
      default
    }
  }

  if (missing(mes_arg) || is.null(mes_arg) || trimws(as.character(mes_arg)) == "") {
    stop("Falta el mes. Uso: generar_informe_mes(\"MM.YY\") o Rscript 4_generar_informe.R MM.YY [version]")
  }
  version <- unique(version)
  if (!all(version %in% c("1.0", "2.0", "3.0"))) {
    stop("Versión(es) inválida(s): ", paste(version, collapse = ", "),
         ". Use '1.0' (plana), '2.0' (expandida) y/o '3.0' (detallada + ADICIONAL/CTO_086).")
  }

  # Parsear MM y año (acepta 07.26 o 07.2026)
  mm_txt   <- sub("[.].*$", "", mes_arg)
  anio_txt <- sub("^[0-9]{2}[.]", "", mes_arg)
  if (!grepl("^[0-9]{2}$", mm_txt) || !grepl("^[0-9]{2,4}$", anio_txt)) {
    stop("Formato de mes inválido: '", mes_arg, "'. Use MM.YY (ej. 07.26) o MM.YYYY (ej. 07.2026).")
  }
  MM <- as.integer(mm_txt)
  if (is.na(MM) || MM < 1 || MM > 12) stop("Mes inválido: ", mes_arg)
  yy    <- if (nchar(anio_txt) == 4) substr(anio_txt, 3, 4) else anio_txt
  anno  <- if (nchar(anio_txt) == 4) anio_txt else paste0("20", anio_txt)

  mm          <- sprintf("%02d", MM)
  mm_yy       <- paste0(mm, ".", yy)                    # "07.26"
  mes_nombre  <- meses_es[MM]                           # "julio"
  mes_titulo  <- paste0(toupper(substr(mes_nombre, 1, 1)), substring(mes_nombre, 2))  # "Julio"
  mes_label   <- paste0(mes_nombre, " ", anno)          # "julio 2026"
  mes_upper   <- toupper(mes_label)                     # "JULIO 2026"

  # --- Rutas ---------------------------------------------------------------------
  # El mes debe estar YA NORMALIZADO (PASO 2 OBLIGATORIO): datos/m.MM.YY_limpio.rds
  ruta_mes_limpio <- file.path(getwd(), "datos", paste0("m.", mm_yy, "_limpio.rds"))
  fecha_elab      <- format(Sys.Date(), "%Y-%m-%d")
  # ruta_html se define por versión en el bucle de generación (sección 7)

  if (!file.exists(ruta_mes_limpio)) stop(
    "No se encontró el mes NORMALIZADO: ", ruta_mes_limpio,
    "\nEl Paso 2 (normalización) es OBLIGATORIO. Ejecute primero:",
    "\n    Rscript 2_limpiar_mes.R ", mm_yy)

  # Catálogo del tarifario: por defecto el OFICIAL de 'datos/'
  # (Tarifario_CTO_086_2026.xlsx; se acepta también el nombre anterior
  # tarifario_cto086_2026.xlsx). Si se pasa 'ruta_tarifario' se usa ese archivo
  # (p. ej. un tarifario BORRADOR con precios experimentales).
  # Respaldo: catalogo_cto086_2026.rds.
  ruta_cat_rds <- file.path(getwd(), "datos", "catalogo_cto086_2026.rds")
  if (!is.null(ruta_tarifario)) {
    if (!file.exists(ruta_tarifario)) {
      stop("No se encontró el tarifario indicado: ", ruta_tarifario)
    }
    ruta_cat_xlsx <- ruta_tarifario
  } else {
    nombres_tarifario <- c("Tarifario_CTO_086_2026.xlsx", "tarifario_cto086_2026.xlsx")
    rutas_tarifario   <- file.path(getwd(), "datos", nombres_tarifario)
    ruta_cat_xlsx     <- rutas_tarifario[file.exists(rutas_tarifario)][1]
  }
  if (!is.na(ruta_cat_xlsx)) {
    ruta_cat <- ruta_cat_xlsx
    cat <- readxl::read_excel(ruta_cat)
  } else if (file.exists(ruta_cat_rds)) {
    ruta_cat <- ruta_cat_rds
    cat <- readr::read_rds(ruta_cat)
  } else {
    stop("No se encontró el tarifario en 'datos/'.",
         "\n  Nombres buscados: Tarifario_CTO_086_2026.xlsx | tarifario_cto086_2026.xlsx",
         "\n  Coloque 'Tarifario_CTO_086_2026.xlsx' en 'datos/' (o ejecute: ",
         "Rscript 3_cargar_catalogo.R --actualizar)")
  }
  cat("[i] Tarifario usado:", ruta_cat, "\n")
  # El tarifario xlsx trae la tarifa en 'TARIFAS_2026' (el rds la trae en 'TARIFA').
  if ("TARIFAS_2026" %in% names(cat) && !"TARIFA" %in% names(cat)) {
    names(cat)[names(cat) == "TARIFAS_2026"] <- "TARIFA"
  }

  # Verificación de control: el catálogo debe traer las columnas del informe
  columnas_requeridas <- c("CODIGO", "DESCRIPCION", "CLASE", "ADICIONAL", "TARIFA")
  faltantes <- setdiff(columnas_requeridas, names(cat))
  if (length(faltantes) > 0) {
    stop("El catálogo del tarifario no tiene las columnas requeridas: ",
         paste(faltantes, collapse = ", "))
  }

# --- Tarifas de las filas especiales (HORA JUNTA MEDICA / VALOR FIJO) ----------
# Se toman de tarifas_especiales_2026.xlsx (CLASE | TARIFA) para que el
# informe use las tarifas vigentes; si no se encuentra el archivo o la clase, se
# usan los valores por defecto.
ruta_tarifas_clases <- file.path(getwd(), "datos", "tarifas_especiales_2026.xlsx")
if (file.exists(ruta_tarifas_clases)) {
  tarifas_clases <- readxl::read_excel(ruta_tarifas_clases)
} else {
  warning("No se encontró ", ruta_tarifas_clases,
          "; HORA JUNTA MEDICA y VALOR FIJO usarán tarifas por defecto.")
  tarifas_clases <- NULL
}
obtener_tarifa <- function(patron, default) {
  if (!is.null(tarifas_clases)) {
    idx <- grepl(patron, trimws(as.character(tarifas_clases$CLASE)))
    if (any(idx)) {
      v <- suppressWarnings(as.numeric(tarifas_clases$TARIFA[idx]))
      v <- v[!is.na(v)]
      if (length(v) >= 1) return(v[1])
    }
  }
  default
}
tarifa_junta <- obtener_tarifa("JUNTA", 133897)
tarifa_fijo  <- obtener_tarifa("VALOR FIJO", 62618981)
cant_junta   <- 100L   # CANTIDAD provisional (se consulta al usuario en RStudio)
cant_fijo    <- 1L
if (!is.null(cant_junta_param)) {
  # Cantidad indicada por quien llama (p. ej. el borrador, para replicar la del
  # informe oficial). En este caso NO se pregunta.
  cant_junta <- as.integer(cant_junta_param)
} else if (interactive()) {
  entrada_junta <- readline(prompt = "CANTIDAD HORA JUNTA MEDICA (provisional = 100). Enter para usar 100 o escribe el número: ")
  entrada_junta <- trimws(entrada_junta)
  if (grepl("^[0-9]+$", entrada_junta)) cant_junta <- as.integer(entrada_junta)
}

# ================================================================================
# 2. LECTURA DEL MES YA NORMALIZADO (Paso 2 — 2_limpiar_mes.R, OBLIGATORIO)
# ================================================================================
# La normalización es OBLIGATORIA y la hace 2_limpiar_mes.R, que guarda el mes
# normalizado junto con su resumen de limpieza en el atributo 'limpieza' del RDS.
# Aquí SOLO se lee ese resultado ya normalizado (no se normaliza por dentro).
mes  <- readr::read_rds(ruta_mes_limpio)
limp <- attr(mes, "limpieza")
if (is.null(limp)) {
  stop("El mes normalizado no trae el resumen de limpieza (atributo 'limpieza').\n",
       "Reejecute el Paso 2: Rscript 2_limpiar_mes.R ", mm_yy)
}
n_vac   <- limp$n_vac
n_phil  <- limp$n_phil
n_asign <- limp$n_asign
filas_crudas <- limp$filas_crudas

X <- nrow(mes)                       # filas tras descartes (limpias)
estado_aprobado <- sum(tolower(trimws(as.character(mes$STTEXT))) == "aprobado")

# ================================================================================
# 3. Cruce contra el catálogo
# ================================================================================
norm <- function(x) {
  x <- as.character(x)
  x <- sub("L$", "", x)
  x <- gsub("[^0-9]", "", x)
  num <- suppressWarnings(as.integer(x))
  ifelse(is.na(num), NA_character_, sprintf("%06d", num))
}
fmt_num <- function(x) format(round(x), big.mark = ".", decimal.mark = ",",
                              scientific = FALSE, trim = TRUE)

cod_final_n <- norm(mes$CODIGO)

# Mapa catálogo (normalizado)
cat_map <- data.frame(
  CODIGO = norm(cat$CODIGO),
  CLASE = cat$CLASE, DESCRIPCION = cat$DESCRIPCION,
  ADICIONAL = cat$ADICIONAL,
  # CTO_086 se usa solo en la versión 3.0 (informe borrador). Si el tarifario no
  # la trae, queda NA y la columna se muestra vacía.
  CTO_086 = if ("CTO_086" %in% names(cat)) as.character(cat$CTO_086) else NA_character_,
  TARIFA = cat$TARIFA,
  stringsAsFactors = FALSE
) %>% dplyr::distinct(CODIGO, .keep_all = TRUE)
rownames(cat_map) <- NULL

# --- Códigos EXCLUIDOS POR DECISIÓN (no están en el catálogo; NO bloquean) ------
# Códigos retirados/ausentes del catálogo por decisión del usuario (ver REGISTRO).
# Se indica el NOMBRE de cada uno para entender el motivo (algunos son variantes
# "VÍA ABIERTA" / "VÍA LAPAROSCÓPICA" / "VÍA ENDOSCÓPICA" que no se cuentan):
#   - script 9  : 870310 (CT LECTURA TOMOGRAFIA FUNCIONAL DE LARINGE — no existe en CUPS)
#                 429301 (INSERCION DE DISPOSITIVO EN ESOFAGO VIA ENDOSCOPICA)
#                 542803 (PARACENTESIS ABDOMINAL TERAPEUTICA VIA LAPAROSCOPICA)
#                 832101 (BIOPSIA DE TEJIDO BLANDO: MUSCULOS, TENDON, FASCIA Y BURSA
#                         [INCLUYENDO MANO] VIA ABIERTA)
#                 876131 (ARTERIOGRAFIA PULMONAR BILATERAL CON CATETERISMO DERECHO)
#   - script 21 : 389104 (INSERCION DE CATETER CENTRAL VIA ABIERTA)
#   - script 23 : 401001 (BIOPSIA DE GANGLIO LINFATICO CENTINELA CON TINCION)
#                 401002 (BIOPSIA DE GANGLIO LINFATICO CENTINELA CON RADIOMARCACION)
#   - script 25 : 874112 (ARTERIOGRAFIA DE CAROTIDA EXTERNA BILATERAL SELECTIVA INTRACRANEANA)
#                 874113 (ARTERIOGRAFIA DE CAROTIDA EXTERNA UNILATERAL SELECTIVA EXTRACRANEANA)
#                 874121 (ARTERIOGRAFIA DE CAROTIDA INTERNA BILATERAL SELECTIVA EXTRACRANENANA)
#                 874125 (ARTERIOGRAFIA DE CAROTIDA BILATERAL SELECTIVA EXTRACRANEANA
#                         CON AORTOGRAMA DE CAYADO)
#                 874132 (ARTERIOGRAFIA VERTEBRAL SELECTIVA INTRACRANEANA)
#                 874134 (ARTERIOGRAFIA VERTEBRAL BILATERAL SELECTIVA EXTRACRANEANA
#                         CON AORTOGRAMA DE CAYADO)
#   - faltante real : 976200 (EXTRACCION DE TUBO DE PIELOSTOMIA Y NEFROSTOMIA — pendiente)
#   - decisión 2026-08-17 : 033201 (ex 33201 — BIOPSIA DE TUMOR INTRADURALES
#     [INTRAMEDULARES Y EXTRAMEDULARES] CERVICALES, DORSALES, LUMBOSACROS O COCCIGEOS)
excluidos_por_decision <- c(
  "870310",                                                      # script 9
  "429301", "542803", "832101", "876131",                        # script 9
  "389104",                                                      # script 21
  "401001", "401002",                                            # script 23
  "874112", "874113", "874121", "874125", "874132", "874134",    # script 25
  "976200",                                                      # faltante real
  "033201"                                                       # decisión 2026-08-17 (ex 33201)
)
excluidos   <- !is.na(cod_final_n) & (cod_final_n %in% excluidos_por_decision)
n_excluidos <- sum(excluidos)
excl_cods   <- sort(unique(cod_final_n[excluidos & !is.na(cod_final_n)]))

# Cruce: CLASE y TARIFA de cada fila limpia del mes
idx_cat     <- match(cod_final_n, cat_map$CODIGO)
clase_fila  <- cat_map$CLASE[idx_cat]
tarifa_fila <- cat_map$TARIFA[idx_cat]

# Filas con cruce VACÍO INESPERADO: sin código válido o sin CLASE/TARIFA en el
# catálogo y que NO estén en la lista de excluidos por decisión.
sin_cruce   <- (is.na(cod_final_n) | is.na(clase_fila) | is.na(tarifa_fila)) & !excluidos
n_sin_cruce <- sum(sin_cruce)

# Filas que quedan en el informe (con CLASE y TARIFA, sin excluidos)
en_informe  <- !is.na(cod_final_n) & !is.na(clase_fila) & !is.na(tarifa_fila) & !excluidos
Y <- sum(en_informe)
Z <- if (X - n_excluidos > 0) round(100 * Y / (X - n_excluidos), 2) else NA_real_

# --- Reporte en pantalla del cruce + validación ---------------------------------
cat("====================================================\n")
cat(" INFORME RESUMEN DE EJECUCIÓN — MES", mm_yy, "\n")
cat("====================================================\n")
cat("Filas mes crudo        :", filas_crudas, "\n")
cat("Descartes STTEXT≠Aprobado:", n_vac, "| Philips, Admin:", n_phil, "\n")
cat("Códigos asignados      :", n_asign, "(mapeo script 5 + similitud)\n")
cat("X (filas limpias)      :", X, "| ESTADO Aprobado:", estado_aprobado, "\n")
cat("Y (con CLASE + TARIFA) :", Y, "| Z =", Z, "%\n")
cat("EXCLUIDOS POR DECISIÓN :", n_excluidos, "\n")
cat("FILAS SIN CRUCE        :", n_sin_cruce, "\n")
cat("Tarifa HORA JUNTA MEDICA   :", fmt_num(tarifa_junta), "| CANTIDAD:", cant_junta, "(provisional)\n")
cat("Tarifa VALOR FIJO NOCTURNO :", fmt_num(tarifa_fijo), "| CANTIDAD:", cant_fijo, "\n")

# Destacar los excluidos por decisión y CONSULTAR al usuario (NO bloquean; se descartan del informe)
if (n_excluidos > 0) {
  excl_tabla <- unique(data.frame(
    CODIGO     = cod_final_n[excluidos],
    PRESTACION = mes$PRESTACION[excluidos],
    stringsAsFactors = FALSE
  ))
  # CANTIDAD de filas que se descartan por cada código excluido
  cnt_excl <- table(cod_final_n[excluidos])
  excl_tabla$CANTIDAD <- as.integer(cnt_excl[excl_tabla$CODIGO])
  excl_tabla <- excl_tabla[, c("CODIGO", "PRESTACION", "CANTIDAD")]
  cat(">>> EXCLUIDOS POR DECISIÓN detectados en el mes (se descartan del informe):\n")
  print(excl_tabla, row.names = FALSE)
  cat("    Lista de excluidos por decisión del script:",
      paste(excluidos_por_decision, collapse = ", "), "\n")
  r_excl <- preguntar("¿CONFIRMAS excluir estos códigos por decisión? (s = sí / n = no): ", default = "s")
  if (r_excl == "n") {
    stop("Exclusión NO confirmada por el usuario. Revise la lista 'excluidos_por_decision' del script o los códigos del mes. Informe NO generado.", call. = FALSE)
  }
  cat("✔ Exclusión por decisión confirmada.\n")
}

if (n_sin_cruce > 0) {
  # Destacar en pantalla las filas vacías INESPERADAS (sin CLASE/TARIFA en catálogo)
  faltantes_tabla <- unique(data.frame(
    CODIGO     = cod_final_n[sin_cruce],
    PRESTACION = mes$PRESTACION[sin_cruce],
    stringsAsFactors = FALSE
  ))
  cat(">>> FILAS SIN CRUCE EN EL CATÁLOGO (vacíos inesperados en el cruce):\n")
  print(faltantes_tabla, row.names = FALSE)
  cat(">>> NO SE GENERA EL INFORME: hay", n_sin_cruce,
      "fila(s) sin CLASE/TARIFA en el catálogo (no excluidas por decisión). Revise y complete el cruce.\n")
  stop("Cruce incompleto: ", n_sin_cruce,
       " fila(s) sin CLASE/TARIFA en el catálogo. Informe NO generado.",
       call. = FALSE)
} else {
  cat("✔ TODAS las filas limpias quedaron con CLASE y TARIFA o son excluidas por decisión.\n")
  cat("✔ CRUCE COMPLETO — procede a generar el informe.\n")
}

# ================================================================================
# 4. TABLA ESTUDIOS
# ================================================================================
estudios_base <- cat_map %>%
  dplyr::filter(CLASE != "PROCEDIMIENTO") %>%
  dplyr::distinct(CLASE, TARIFA) %>%
  dplyr::arrange(CLASE)

tabla_estudios <- data.frame(
  CLASE       = estudios_base$CLASE,
  TARIFA      = estudios_base$TARIFA,
  CANTIDAD    = vapply(estudios_base$CLASE, function(cl)
    sum(clase_fila == cl & !excluidos & !is.na(clase_fila)), integer(1)),
  stringsAsFactors = FALSE
)
tabla_estudios$VALOR_TOTAL <- tabla_estudios$CANTIDAD * tabla_estudios$TARIFA

# Filas especiales (tarifas tomadas de tarifas_especiales_2026.xlsx)
tabla_estudios <- rbind(tabla_estudios, data.frame(
  CLASE = c("HORA JUNTA MEDICA", "VALOR FIJO POR SERVICIO DE LA NOCHE"),
  TARIFA = c(tarifa_junta, tarifa_fijo),
  CANTIDAD = c(cant_junta, cant_fijo),
  VALOR_TOTAL = c(cant_junta * tarifa_junta, cant_fijo * tarifa_fijo)
))

total_estudios <- sum(tabla_estudios$VALOR_TOTAL)
tabla_estudios <- rbind(tabla_estudios, data.frame(
  CLASE = "TOTAL", TARIFA = NA_real_, CANTIDAD = NA_integer_,
  VALOR_TOTAL = total_estudios
))

# ================================================================================
# 5. TABLA PROCEDIMIENTOS
# ================================================================================
proc <- cat_map %>% dplyr::filter(CLASE == "PROCEDIMIENTO")

# CANTIDAD excluye las filas EXCLUIDAS POR DECISIÓN (aunque el código siga en el
# catálogo), para que la exclusión sea efectiva en la tabla y en el total.
tabla_proc <- data.frame(
  CODIGO     = proc$CODIGO,
  DESCRIPCION = proc$DESCRIPCION,
  TARIFA     = proc$TARIFA,
  ADICIONAL  = proc$ADICIONAL,
  CTO_086    = proc$CTO_086,
  CANTIDAD   = vapply(proc$CODIGO, function(cd)
    sum(cod_final_n == cd & !excluidos & !is.na(cod_final_n)), integer(1)),
  stringsAsFactors = FALSE
)
tabla_proc$VALOR_TOTAL <- tabla_proc$CANTIDAD * tabla_proc$TARIFA

# Mostrar únicamente los códigos con conteo DISTINTO DE CERO
n_proc_total <- nrow(tabla_proc)
n_proc_cero  <- sum(tabla_proc$CANTIDAD == 0)
tabla_proc <- tabla_proc[tabla_proc$CANTIDAD > 0, , drop = FALSE]
rownames(tabla_proc) <- NULL

total_proc   <- sum(tabla_proc$VALOR_TOTAL)
total_proc_c <- sum(tabla_proc$CANTIDAD)
tabla_proc <- rbind(tabla_proc, data.frame(
  CODIGO = "TOTAL", DESCRIPCION = "", TARIFA = NA_real_,
  ADICIONAL = "", CTO_086 = "", CANTIDAD = total_proc_c, VALOR_TOTAL = total_proc
))

# ================================================================================
# 6. Salida final en consola (totales)
# ================================================================================
cat("\n--- Tablas calculadas (cruce completo) ---\n")
cat("Procedimientos tabla   :", n_proc_total, "códigos | con CANTIDAD 0:", n_proc_cero,
    "| mostrados:", nrow(tabla_proc) - 1, "\n")
cat("Filas en tablas        : Estudios", sum(tabla_estudios$CANTIDAD[is.na(tabla_estudios$TARIFA) == FALSE][1:14], na.rm = TRUE),
    "| Procedimientos", total_proc_c, "\n")
cat("TOTAL Estudios :", fmt_num(total_estudios), "\n")
cat("TOTAL Procs    :", fmt_num(total_proc), "\n")
total_general <- total_estudios + total_proc
cat("VALOR EJECUTADO MES", mes_upper, ":", fmt_num(total_general), "\n")

# --- Conteo de filas y subtotales (se muestran en el informe, ambas versiones) ---
# Verificación del mes: X filas limpias = PROCEDIMIENTOS + ESTUDIOS.
#   - PROCEDIMIENTOS : filas con código PROCEDIMIENTO en el catálogo, SIN las
#                      excluidas por decisión (coincide con TABLA PROCEDIMIENTOS).
#   - ESTUDIOS       : filas NO excluidas que no son PROCEDIMIENTO (coincide con
#                      TABLA ESTUDIOS; excluye HORA JUNTA MEDICA y VALOR FIJO
#                      POR SERVICIO DE LA NOCHE, que no son filas del mes).
#   - EXCLUIDAS      : filas excluidas por decisión (no se cuentan en las tablas).
#   Verificación: PROCEDIMIENTOS + ESTUDIOS + EXCLUIDAS = X.
n_proc_filas <- sum(cod_final_n %in% cat_map$CODIGO[cat_map$CLASE == "PROCEDIMIENTO"] & !excluidos)
n_est_filas  <- X - n_excluidos - n_proc_filas

# Subtotales de precios: ESTUDIOS (sin junta/noche) y ADICIONALES (junta + noche)
valor_junta <- cant_junta * tarifa_junta
valor_noche <- cant_fijo * tarifa_fijo
subtotal_estudios    <- total_estudios - valor_junta - valor_noche
subtotal_adicionales <- valor_junta + valor_noche
# Cantidad de ESTUDIOS (suma hasta TORACENTESIS; sin junta/noche) para la fila resumen
subtotal_estudios_cant <- sum(tabla_estudios$CANTIDAD[
  !tabla_estudios$CLASE %in% c("HORA JUNTA MEDICA", "VALOR FIJO POR SERVICIO DE LA NOCHE", "TOTAL")],
  na.rm = TRUE)

# Bloque HTML: contador de filas del mes (verificación)
html_conteo <- paste0(
  "<h2>CONTEO DE FILAS DEL MES</h2>",
  "<table><thead><tr><th>TIPO</th><th>CANTIDAD</th></tr></thead><tbody>",
  "<tr><td>TOTAL FILAS PROCESADAS</td><td class='num'>", fmt_num(X), "</td></tr>",
  "<tr><td>PROCEDIMIENTOS</td><td class='num'>", fmt_num(n_proc_filas), "</td></tr>",
  "<tr><td>ESTUDIOS</td><td class='num'>", fmt_num(n_est_filas), "</td></tr>",
  "<tr><td>EXCLUIDAS POR DECISIÓN</td><td class='num'>", fmt_num(n_excluidos), "</td></tr>",
  "</tbody></table>",
  "<p>El conteo de ESTUDIOS <strong>excluye</strong> la <em>HORA JUNTA MEDICA</em> y el ",
  "<em>VALOR FIJO POR SERVICIO DE LA NOCHE</em> (adicionales, no son filas del mes). ",
  "Las <strong>EXCLUIDAS POR DECISIÓN</strong> se descartan del informe y no se ",
  "cuentan en PROCEDIMIENTOS ni en ESTUDIOS.</p>"
)

# (Los subtotales se muestran como filas dentro de la TABLA ESTUDIOS: verde = ESTUDIOS,
#  rojo = ADICIONALES junta+noche; ver construir_html_tabla_est).

# ================================================================================
# 7. Generación del HTML imprimible
# ================================================================================
esc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

# Códigos que componen cada CLASE (para la tabla ESTUDIOS expandida)
clases_info <- cat_map %>%
  dplyr::filter(CLASE != "PROCEDIMIENTO") %>%
  dplyr::distinct(CLASE, TARIFA) %>%
  dplyr::arrange(CLASE)
est_codes <- cat_map[cat_map$CLASE != "PROCEDIMIENTO",
                    c("CLASE", "CODIGO", "DESCRIPCION", "ADICIONAL", "CTO_086", "TARIFA")]
est_codes$CANTIDAD <- vapply(est_codes$CODIGO, function(cd)
  sum(cod_final_n == cd & !excluidos & !is.na(cod_final_n)), integer(1))
est_codes$VALOR_TOTAL <- est_codes$CANTIDAD * est_codes$TARIFA

# Construye la TABLA ESTUDIOS según la versión:
#   "1.0" = plana (una fila por CLASE)
#   "2.0" = expandida (una fila por código)
#   "3.0" = expandida + columnas ADICIONAL y CTO_086 (informe borrador)
construir_html_tabla_est <- function(ver) {
  extra <- identical(as.character(ver), "3.0")
  celda <- function(x) ifelse(is.na(x), "", esc(as.character(x)))

  # Fila estándar de la tabla (clase, tarifa, cantidad, valor, clase CSS opcional).
  # En la versión 3.0 se intercalan ADICIONAL y CTO_086 antes de TARIFA.
  fila_html <- function(clase, tarifa, cantidad, valor, cl = "",
                        adicional = "", cto = "", clase_celda = "") {
    celdas_extra <- if (extra) paste0("<td>", celda(adicional), "</td>",
                                      "<td>", celda(cto), "</td>") else ""
    td_clase <- paste0("<td",
                       if (clase_celda != "") paste0(" class='", clase_celda, "'") else "",
                       ">", esc(clase), "</td>")
    paste0("<tr", if (cl != "") paste0(" class='", cl, "'") else "",">",
           td_clase, celdas_extra,
           "<td class='num'>", ifelse(is.na(tarifa), "", fmt_num(tarifa)), "</td>",
           "<td class='num'>", ifelse(is.na(cantidad), "", cantidad), "</td>",
           "<td class='num'>", fmt_num(valor), "</td></tr>")
  }

  cabecera <- if (extra) {
    paste0("<table><thead><tr><th>CLASE / CÓDIGO</th><th>ADICIONAL</th><th>CTO_086</th>",
           "<th>TARIFA</th><th>CANTIDAD</th><th>VALOR TOTAL</th></tr></thead><tbody>")
  } else {
    "<table><thead><tr><th>CLASE</th><th>TARIFA</th><th>CANTIDAD</th><th>VALOR TOTAL</th></tr></thead><tbody>"
  }
  if (ver == "1.0") {
    # TABLA ESTUDIOS plana (V.1.0): una fila por CLASE (hasta TORACENTESIS)
    est <- tabla_estudios[
      !tabla_estudios$CLASE %in% c("HORA JUNTA MEDICA", "VALOR FIJO POR SERVICIO DE LA NOCHE", "TOTAL"), ,
      drop = FALSE
    ]
    filas <- vapply(seq_len(nrow(est)), function(i) {
      r <- est[i, ]
      fila_html(r$CLASE, r$TARIFA, r$CANTIDAD, r$VALOR_TOTAL)
    }, character(1))
    filas <- c(filas,
      fila_html("SUBTOTAL ESTUDIOS", NA, subtotal_estudios_cant, subtotal_estudios, "subtotal-estudios"),
      fila_html("HORA JUNTA MEDICA", tarifa_junta, cant_junta, valor_junta),
      fila_html("VALOR FIJO POR SERVICIO DE LA NOCHE", tarifa_fijo, cant_fijo, valor_noche),
      fila_html("SUBTOTAL ADICIONALES", NA, NA, subtotal_adicionales, "subtotal-adicionales"),
      fila_html("TOTAL", NA, NA, total_estudios, "total")
    )
    c(cabecera, filas, "</tbody></table>")
  } else {
    # TABLA ESTUDIOS expandida (V.2.0 y V.3.0): CLASE + códigos que la componen
    filas <- character(0)
    for (cl in clases_info$CLASE) {
      tar  <- clases_info$TARIFA[clases_info$CLASE == cl]
      cods <- est_codes[est_codes$CLASE == cl, , drop = FALSE]
      cods <- cods[order(cods$CODIGO), , drop = FALSE]
      cods <- cods[cods$CANTIDAD > 0, , drop = FALSE]   # solo códigos con conteo > 0
      cnt  <- sum(cods$CANTIDAD)
      filas <- c(filas, fila_html(cl, tar, cnt, cnt * tar, "clase"))
      for (k in seq_len(nrow(cods))) {
        filas <- c(filas, fila_html(
          paste0(cods$CODIGO[k], " - ", cods$DESCRIPCION[k]),
          cods$TARIFA[k], cods$CANTIDAD[k], cods$VALOR_TOTAL[k],
          cl = "sub", adicional = cods$ADICIONAL[k], cto = cods$CTO_086[k],
          clase_celda = "code"))
      }
    }
    filas <- c(filas,
      fila_html("SUBTOTAL ESTUDIOS", NA, subtotal_estudios_cant, subtotal_estudios, "subtotal-estudios"),
      fila_html("HORA JUNTA MEDICA", tarifa_junta, cant_junta, valor_junta),
      fila_html("VALOR FIJO POR SERVICIO DE LA NOCHE", tarifa_fijo, cant_fijo, valor_noche),
      fila_html("SUBTOTAL ADICIONALES", NA, NA, subtotal_adicionales, "subtotal-adicionales"),
      fila_html("TOTAL", NA, NA, total_estudios, "total")
    )
    c(cabecera, filas, "</tbody></table>")
  }
}

# Construye la TABLA PROCEDIMIENTOS. La versión 3.0 agrega la columna CTO_086.
construir_html_tabla_proc <- function(ver) {
  extra <- identical(as.character(ver), "3.0")
  filas <- vapply(seq_len(nrow(tabla_proc)), function(i) {
    r <- tabla_proc[i, ]
    es_total <- r$CODIGO == "TOTAL"
    tds <- paste0("<td>", esc(r$CODIGO), "</td>",
                  "<td>", esc(r$DESCRIPCION), "</td>",
                  "<td class='num'>", ifelse(is.na(r$TARIFA), "", fmt_num(r$TARIFA)), "</td>",
                  "<td class='num'>", ifelse(is.na(r$CANTIDAD), "", r$CANTIDAD), "</td>",
                  "<td class='num'>", fmt_num(r$VALOR_TOTAL), "</td>",
                  "<td>", esc(r$ADICIONAL), "</td>",
                  if (extra) paste0("<td>",
                                    ifelse(is.na(r$CTO_086), "", esc(as.character(r$CTO_086))),
                                    "</td>") else "")
    paste0("<tr", ifelse(es_total, " class='total'", ""), ">", tds, "</tr>")
  }, character(1))
  cab <- if (extra) {
    paste0("<table><thead><tr><th>CODIGO</th><th>DESCRIPCION</th><th>TARIFA</th>",
           "<th>CANTIDAD</th><th>VALOR TOTAL</th><th>ADICIONAL</th><th>CTO_086</th></tr></thead><tbody>")
  } else {
    "<table><thead><tr><th>CODIGO</th><th>DESCRIPCION</th><th>TARIFA</th><th>CANTIDAD</th><th>VALOR TOTAL</th><th>ADICIONAL</th></tr></thead><tbody>"
  }
  c(cab, filas, "</tbody></table>")
}

resumen <- paste0(
  "<p>El presente informe resume la ejecución del mes <strong>", mes_label, " (m.", mm_yy, ")</strong> ",
  "basado en el informe generado por el sistema Phillips - SAP del INC, enviado por Angela Lopez ",
  "(alopez@cancer.gov.co) - Secretaria - Auxiliar Administrativo Imágenes Diagnósticas. Se procesaron ",
  fmt_num(filas_crudas), " filas del mes; tras conservar únicamente las filas con <em>ESTADO</em> = <strong>APROBADO</strong> (",
  fmt_num(n_vac), " filas descartadas por no estar aprobadas) y excluir las de <em>DOCTEXT</em> = \u201CPhilips, Admin\u201D (", fmt_num(n_phil),
  "), quedan <strong>", fmt_num(X), " filas</strong>. ",
  "A las ", fmt_num(n_asign), " celdas sin código se les asignó un código (mapeo del script 5 ",
  "y respaldo por similitud entre <em>PRESTACION</em> y <em>DESCRIPCION</em> de CUPS.2025). ",
  "Del cruce por código, <strong>", fmt_num(Y), " filas</strong> (de ", fmt_num(X),
  ") quedaron con <strong>CLASE y TARIFA</strong> en el catálogo; ",
  # Solo se mencionan las exclusiones si realmente ocurrieron en el mes
  if (n_excluidos > 0) paste0(fmt_num(n_excluidos), " filas quedaron <strong>excluidas por decisión</strong> (",
                              esc(paste(excl_cods, collapse = ", ")), ") y se descartan del informe. ") else "",
  "El cruce quedó completo (0 filas vacías inesperadas, Z = ", Z,
  "%). A continuación se presentan la <em>TABLA ESTUDIOS</em> y la ",
  "<em>TABLA PROCEDIMIENTOS</em> con sus recuentos (CANTIDAD) y valores totales (VALOR TOTAL)."
)

salvedades <- paste0(
  "<p><strong>Salvedades:</strong></p><ul>",
  "<li>Se descartaron las filas con <em>ESTADO</em> distinto de <strong>APROBADO</strong> (",
  fmt_num(n_vac), ").</li>",
  "<li>Se descartaron las filas con <em>DOCTEXT</em> = <strong>\u201CPhilips, Admin\u201D</strong> (",
  fmt_num(n_phil), ").</li>",
  "<li>Se verificó que las <strong>", fmt_num(X), "</strong> filas resultantes tienen ",
  "<strong>ESTADO = APROBADO</strong> (verificadas: ", fmt_num(estado_aprobado), ") y que ",
  "<strong>todas quedaron con CLASE y TARIFA</strong> en el catálogo",
  # Solo se mencionan las exclusiones si realmente ocurrieron en el mes
  if (n_excluidos > 0) paste0(" o son <strong>excluidas por decisión</strong> (",
                              fmt_num(n_excluidos), " filas: ",
                              esc(paste(excl_cods, collapse = ", ")),
                              "), que se descartan del informe") else "",
  ".</li>",
  "</ul>"
)

# Genera las DOS versiones del informe (V.1.0 resumida y V.2.0 detallada)
for (v in version) {
  ruta_html <- file.path(getwd(), paste0("informe_", mm_yy, "_V.", v, ".html"))
  html_tabla_est  <- construir_html_tabla_est(v)
  html_tabla_proc <- construir_html_tabla_proc(v)

  html <- c(
    "<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'>",
    paste0("<title>Informe Resumen de Ejecución — Mes ", mm_yy, "</title>"),
    "<style>",
    "body{font-family:Calibri,Arial,sans-serif;margin:40px;color:#222}",
    "h1{font-size:20pt;color:#1f4e79;border-bottom:2px solid #1f4e79;padding-bottom:6px}",
    "h2{font-size:14pt;color:#1f4e79;margin-top:28px}",
    "p{font-size:11pt;text-align:justify;line-height:1.5}",
    "table{border-collapse:collapse;width:100%;font-size:10pt;margin:12px 0}",
    "th,td{border:1px solid #999;padding:5px 8px;text-align:left;vertical-align:top}",
    "th{background:#1f4e79;color:#fff}",
    "td.num{text-align:right;white-space:nowrap}","tr.clase td{font-weight:bold;background:#eef3f9}",
    "tr.sub td{color:#5a6b7a;font-size:9pt}",
    "td.code{padding-left:24px}",  "tr.total td{background:#dbe7f4;font-weight:bold}",
    "tr.subtotal-estudios td{background:#dff0d8;font-weight:bold}",
    "tr.subtotal-adicionales td{background:#f2dede;font-weight:bold}",
    ".meta{font-size:10pt;color:#555;margin-bottom:20px}",
    "ul{font-size:11pt;line-height:1.5}",
    "@media print{body{margin:15mm}}",
    "</style></head><body>",
    paste0("<h1>Informe Resumen de Ejecución — Mes ", mes_titulo, " ", anno, " (m.", mm_yy, ")</h1>"),
    "<div class='meta'>Fecha de elaboración: ", fecha_elab, "</div>",
    "<h2>Resumen Ejecutivo</h2>", resumen,
    html_conteo,
    "<h2>TABLA ESTUDIOS</h2>", html_tabla_est,
    "<h2>TABLA PROCEDIMIENTOS</h2>", html_tabla_proc,
    "<h2>Valor Ejecutado - Valor por facturar</h2>",
    paste0("<table><tr class='total'><td>VALOR EJECUTADO MES ", mes_upper, "</td><td class='num'>",
           fmt_num(total_general), "</td></tr></table>"),
    "<h2>Salvedades</h2>", salvedades,
    "</body></html>"
  )

  writeLines(html, ruta_html, useBytes = TRUE)
  cat("\nInforme generado:", ruta_html, "\n")
}

}   # fin de generar_informe_mes()

# ==============================================================================
# Modo CLI (Rscript 4_generar_informe.R MM.YY [version])
# ------------------------------------------------------------------------------
# Se ejecuta SOLO si el script se corre directamente; al ser source() desde
# otro script (p. ej. main.R PASO 4) solo se define la función generar_informe_mes().
# ==============================================================================
if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) >= 1) {
    # Sin argumento de versión: se generan AMBAS versiones (V.1.0 y V.2.0)
    version <- if (length(args) >= 2) args[2] else c("1.0", "2.0")
    generar_informe_mes(args[1], version)
  } else {
    stop("Uso: Rscript 4_generar_informe.R MM.YY [version]")
  }
}

# ==============================================================================
# NOTAS DE USO — REGENERACIÓN Y EXPORTACIÓN
# ------------------------------------------------------------------------------
# 1) REGENERAR el informe de un mes (desde la carpeta del proyecto):
#      Rscript 4_generar_informe.R 07.26        # -> genera V.1.0 y V.2.0
#      Rscript 4_generar_informe.R 07.26 2.0    # -> solo informe_07.26_V.2.0.html
#    En RStudio (main.R PASO 4), con source():
#      source("4_generar_informe.R")
#      generar_informe_mes("07.26")             # -> genera V.1.0 y V.2.0
#    Si cambia el catálogo del tarifario:
#      Rscript 3_cargar_catalogo.R --actualizar
#      Rscript 4_generar_informe.R 07.26        # -> regenera con el catálogo vigente
#
# 2) EXPORTAR a PDF (Chrome headless — conserva tablas, colores y estilos):
#      Rscript 5_exportar_pdf.R 07.26           # -> V.1.0 y V.2.0
# ==============================================================================
