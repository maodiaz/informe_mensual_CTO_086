# ==============================================================================
# PROYECTO: INFORME MENSUAL CT 086
# SCRIPT: 1_cargar_mes.R — CARGA MANUAL DE UN MES (.XLSX -> datos/m.MM.YY.rds)
# ------------------------------------------------------------------------------
# OBJETIVO: Cargar el archivo .xlsx CRUDO de UN mes (el que el usuario elija)
#           y guardarlo como RDS con el nombre m.MM.YY en 'datos/'.
#           Re-ejecutable: se corre una vez por mes que se quiera procesar.
#
# USO:
#   1) Abrir este script en RStudio (o correr desde main.R con source()).
#   2) Ejecutar el script:
#        - selecciona el archivo .xlsx del mes,
#        - elige la hoja (nombre distinto en cada archivo),
#        - ingresa el MES (MM) y el AÑO (YY).
#   3) El mes queda en datos/m.MM.YY.rds y se registra en registro_carga.csv.
#
# NOTA: El flujo es idéntico al de 'recuento_estudios_anual/1_cargar_datos.R'
#       (mismos diálogos, misma validación), pero para UN mes a la vez en vez
#       del bucle de 78 archivos históricos.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN INICIAL
# ------------------------------------------------------------------------------

# Librerías necesarias (silencioso). Si ya están cargadas por main.R, no hace nada.
invisible(lapply(
  c("readxl", "tidyverse", "rstudioapi"),
  library,
  character.only = TRUE,
  quietly = TRUE,
  warn.conflicts = FALSE
))

# Carpeta de salida donde se guardan los RDS con nombre m.MM.YY
carpeta_salida <- file.path(getwd(), "datos")
dir.create(carpeta_salida, showWarnings = FALSE, recursive = TRUE)

# Registro de carga (log) para controlar qué meses ya se procesaron
archivo_registro <- file.path(getwd(), "registro_carga.csv")

# ------------------------------------------------------------------------------
# 2. FUNCIONES AUXILIARES (traslado de 'recuento_estudios_anual/1_cargar_datos.R')
# ------------------------------------------------------------------------------

# Función para seleccionar un archivo xlsx de forma manual (diálogo de RStudio
# o, en su defecto, file.choose). Retorna la ruta completa o NULL si se cancela.
seleccionar_archivo <- function() {
  ruta <- NULL
  if (interactive()) {
    if (rstudioapi::isAvailable()) {
      ruta <- tryCatch(
        rstudioapi::selectFile(
          caption = "Selecciona el archivo .xlsx (mes a cargar)",
          filter = "Archivos Excel (*.xlsx)",
          path = getwd()
        ),
        error = function(e) NULL
      )
    }
    if (is.null(ruta) || length(ruta) == 0) {
      ruta <- tryCatch(file.choose(), error = function(e) NULL)
    }
  }
  if (is.null(ruta) || length(ruta) == 0 || !file.exists(ruta)) {
    return(NULL)
  }
  return(ruta)
}

# Función para elegir la hoja de un archivo xlsx mediante lista desplegable.
# Muestra los nombres de todas las hojas y el usuario elige una.
elegir_hoja <- function(ruta_xlsx) {
  hojas <- readxl::excel_sheets(ruta_xlsx)
  if (length(hojas) == 0) {
    cat("   [!] El archivo no contiene hojas.\n")
    return(NULL)
  }
  if (length(hojas) == 1) {
    cat("   [i] El archivo tiene una sola hoja: '", hojas, "'\n", sep = "")
    return(hojas[1])
  }
  cat("   Hojas disponibles en el archivo:\n")
  print(hojas)

  # Intento 1: lista desplegable gráfica (puede fallar o devolver vacío)
  seleccion <- tryCatch(
    utils::select.list(
      choices = hojas,
      title = "Selecciona la hoja a cargar (haz clic y presiona OK)",
      graphics = TRUE
    ),
    error = function(e) ""
  )
  if (length(seleccion) == 0 || is.na(seleccion) || seleccion == "") {
    # Intento 2: menú numerado en la consola
    cat("   La lista gráfica no devolvió selección; se usa el menú en consola:\n")
    seleccion <- utils::select.list(
      choices = hojas,
      title = "Selecciona la hoja a cargar (número y Enter)",
      graphics = FALSE
    )
  }
  if (length(seleccion) == 0 || is.na(seleccion) || seleccion == "") {
    # Intento 3: ingreso manual del nombre exacto de la hoja
    cat("   El menú no devolvió selección.\n")
    seleccion <- readline(prompt = "   Escribe el nombre EXACTO de la hoja a cargar: ")
    seleccion <- trimws(seleccion)
    if (!(seleccion %in% hojas)) {
      cat("   [!] Nombre de hoja no válido.\n")
      return(NULL)
    }
  }
  return(seleccion)
}

# Función para pedir el mes y año (MM y YY) de forma manual.
# Retorna el nombre del archivo: m.MM.YY
pedir_mmyy <- function() {
  repeat {
    mm <- readline(prompt = "   Ingresa el MES (MM, 2 dígitos, ej. 03 = marzo): ")
    mm <- trimws(mm)
    if (grepl("^[0-9]{1,2}$", mm)) {
      mm_num <- as.integer(mm)
      if (mm_num >= 1 && mm_num <= 12) {
        mm <- sprintf("%02d", mm_num)
        break
      }
    }
    cat("   [!] Mes inválido. Debe ser un número entre 01 y 12.\n")
  }
  repeat {
    yy <- readline(prompt = "   Ingresa el AÑO (YY, 2 dígitos, ej. 26 = 2026): ")
    yy <- trimws(yy)
    if (grepl("^[0-9]{2}$", yy)) {
      break
    }
    cat("   [!] Año inválido. Debe ser 2 dígitos (ej. 20, 21, 22... 26).\n")
  }
  nombre <- paste0("m.", mm, ".", yy)
  return(list(mm = mm, yy = yy, nombre = nombre))
}

# Función para cargar la hoja seleccionada del archivo xlsx
cargar_datos <- function(ruta_xlsx, hoja) {
  datos <- readxl::read_excel(ruta_xlsx, sheet = hoja)
  return(datos)
}

# Función para guardar los datos como RDS con el nombre m.MM.YY.
# Si ya existe, pregunta si se sobrescribe.
guardar_rds <- function(datos, nombre) {
  ruta_destino <- file.path(carpeta_salida, paste0(nombre, ".rds"))
  if (file.exists(ruta_destino)) {
    cat("   [!] Ya existe '", nombre, ".rds' en la carpeta de salida.\n", sep = "")
    respuesta <- readline(prompt = "   ¿Sobrescribir? (s/n): ")
    if (tolower(trimws(respuesta)) != "s") {
      cat("   [-] Se omite el guardado de '", nombre, "'. Continuando...\n", sep = "")
      return(FALSE)
    }
  }
  readr::write_rds(datos, ruta_destino)
  return(TRUE)
}

# Función para registrar la carga en el log (registro_carga.csv)
registrar_carga <- function(nombre, ruta_xlsx, hoja, filas, columnas) {
  registro <- data.frame(
    nombre   = nombre,
    archivo  = basename(ruta_xlsx),
    hoja     = hoja,
    filas    = filas,
    columnas = columnas,
    fecha    = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )
  if (file.exists(archivo_registro)) {
    registro_previo <- read.csv(archivo_registro, stringsAsFactors = FALSE)
    # Evitar duplicar el mismo nombre m.MM.YY
    registro_previo <- registro_previo[registro_previo$nombre != nombre, , drop = FALSE]
    registro <- rbind(registro_previo, registro)
  }
  write.csv(registro, archivo_registro, row.names = FALSE)
  cat("   [OK] Registro actualizado en:", archivo_registro, "\n")
}

# ------------------------------------------------------------------------------
# 3. FUNCIÓN PRINCIPAL: cargar_mes(mm_yy = NULL)
# ------------------------------------------------------------------------------
# Carga el .xlsx de UN mes y lo guarda como datos/m.MM.YY.rds.
#   mm_yy : "MM.YY" (ej. "07.26"). Si es NULL (o al ejecutarse en solitario),
#           el programa pregunta el mes y el año.
# Retorna (invisible) el nombre del mes cargado (ej. "m.07.26") o NULL si se
# canceló. Al llamarla desde main.R no se cierra la sesión si se cancela.
cargar_mes <- function(mm_yy = NULL) {

  cat("\n====================================================\n")
  cat(" CARGA MANUAL DE UN MES (xlsx -> datos/m.MM.YY.rds)\n")
  cat(" Carpeta de salida:", carpeta_salida, "\n")
  cat("====================================================\n")

  # Mes/año: si se pasa mm_yy se usa; si no, se pregunta.
  if (!is.null(mm_yy) && !identical(trimws(as.character(mm_yy)), "")) {
    mm_txt   <- sub("[.].*$", "", mm_yy)
    anio_txt <- sub("^[0-9]{2}[.]", "", mm_yy)
    if (!grepl("^[0-9]{2}$", mm_txt) || !grepl("^[0-9]{2,4}$", anio_txt)) {
      stop("Formato de mes inválido: '", mm_yy, "'. Use MM.YY (ej. 07.26).")
    }
    mm <- sprintf("%02d", as.integer(mm_txt))
    yy <- if (nchar(anio_txt) == 4) substr(anio_txt, 3, 4) else anio_txt
    nombre_info <- list(mm = mm, yy = yy, nombre = paste0("m.", mm, ".", yy))
  } else {
    nombre_info <- pedir_mmyy()
  }

  # 3.1 Selección manual del archivo xlsx
  ruta_xlsx <- seleccionar_archivo()
  if (is.null(ruta_xlsx)) {
    cat("   [!] No se seleccionó archivo. Proceso detenido.\n")
    return(invisible(NULL))
  }

  # 3.2 Selección manual de la hoja (nombre distinto en cada archivo)
  hoja <- elegir_hoja(ruta_xlsx)
  if (is.null(hoja)) {
    cat("   [!] No se seleccionó hoja. Proceso detenido.\n")
    return(invisible(NULL))
  }
  cat("   Hoja seleccionada: '", hoja, "'\n", sep = "")

  # 3.3 Cargar los datos de la hoja
  datos <- cargar_datos(ruta_xlsx, hoja)
  cat("   [i] Datos leídos:", nrow(datos), "filas x", ncol(datos), "columnas\n")
  cat("   [i] Primeras filas (verificación de que la hoja es la correcta):\n")
  print(utils::head(datos, 5))

  # 3.4 Guardar como RDS con nombre m.MM.YY
  guardado <- guardar_rds(datos, nombre_info$nombre)
  if (guardado) {
    registrar_carga(
      nombre    = nombre_info$nombre,
      ruta_xlsx = ruta_xlsx,
      hoja      = hoja,
      filas     = nrow(datos),
      columnas  = ncol(datos)
    )
    cat("   [OK] Guardado:", file.path(carpeta_salida, paste0(nombre_info$nombre, ".rds")), "\n")
  }

  # 3.5 Resumen
  cat("\n----------------------------------------------------\n")
  cat(" RESUMEN DE LA CARGA\n")
  cat("----------------------------------------------------\n")
  cat(" Archivo            :", basename(ruta_xlsx), "\n")
  cat(" Hoja               :", hoja, "\n")
  cat(" Mes                :", nombre_info$nombre, "\n")
  cat(" Filas / columnas   :", nrow(datos), "/", ncol(datos), "\n")
  cat(" RDS guardado en    :", file.path(carpeta_salida, paste0(nombre_info$nombre, ".rds")), "\n")

  invisible(nombre_info$nombre)
}

# ------------------------------------------------------------------------------
# Modo standalone (Rscript 1_cargar_mes.R): se ejecuta solo si se corre directo.
# Al ser source() desde main.R solo se define la función cargar_mes().
# ------------------------------------------------------------------------------
if (sys.nframe() == 0) {
  cargar_mes()
}
