# ==============================================================================
# PROYECTO: INFORME MENSUAL CTO 086
# SCRIPT: 3_cargar_catalogo.R — VERIFICAR / ACTUALIZAR INSUMOS XLSX (PASO OPCIONAL)
# ------------------------------------------------------------------------------
# ⚠️ PASO OPCIONAL: el proyecto es AUTOCONTENIDO y funciona SOLO con insumos
# XLSX que el usuario pone en 'datos/': Tarifario_CTO_086_2026.xlsx (tarifario
# con precios), CUPS.2025.xlsx y (opcional) tarifas_especiales_2026.xlsx.
#
# Este script SOLO se ejecuta para:
#   - VERIFICAR que los insumos xlsx estén en 'datos/' (y que el tarifario tenga
#     las columnas que necesita el informe), o
#   - ACTUALIZAR el tarifario cuando cambian los precios en el proyecto tarifario
#     (copia Tarifario_CTO_086_2026.xlsx desde tarifario_CTO_086_V_2 con --actualizar).
#
# USO:
#   Rscript 3_cargar_catalogo.R              # paso OPCIONAL: verifica sin cambios
#   Rscript 3_cargar_catalogo.R --actualizar # actualiza el tarifario desde el
#                                            # proyecto tarifario (si cambió)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN INICIAL
# ------------------------------------------------------------------------------

invisible(lapply(c("readr", "readxl", "tidyverse"), library,
                 character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE))

# Ruta base del proyecto nuevo (donde está este script)
ruta_proyecto <- getwd()

# Carpeta de insumos (subcarpeta 'datos/')
carpeta_datos <- file.path(ruta_proyecto, "datos")
dir.create(carpeta_datos, showWarnings = FALSE, recursive = TRUE)

# Ruta del proyecto tarifario (hermano; solo se usa con --actualizar)
ruta_tarifario <- file.path(dirname(ruta_proyecto), "tarifario_CTO_086_V_2")

# Confirmación interactiva (RStudio)
preguntar <- function(mensaje, default = "n") {
  if (interactive()) {
    r <- tolower(trimws(readline(prompt = mensaje)))
    if (r == "") r <- default
    r
  } else {
    default
  }
}

# ------------------------------------------------------------------------------
# 2. DEFINICIÓN DE LOS INSUMOS XLSX (obligatorios y opcionales)
# ------------------------------------------------------------------------------

insumos <- list(
  list(
    etiqueta    = "TARIFARIO CON PRECIOS (Tarifario_CTO_086_2026.xlsx)",
    archivo     = file.path(carpeta_datos, "Tarifario_CTO_086_2026.xlsx"),
    obligatorio = TRUE
  ),
  list(
    etiqueta    = "CUPS.2025 (CUPS.2025.xlsx)",
    archivo     = file.path(carpeta_datos, "CUPS.2025.xlsx"),
    obligatorio = TRUE
  ),
  list(
    etiqueta    = "Tarifas especiales (solo junta médica y servicio nocturno)",
    archivo     = file.path(carpeta_datos, "tarifas_especiales_2026.xlsx"),
    obligatorio = FALSE
  )
)

# ------------------------------------------------------------------------------
# 2. FUNCIÓN PRINCIPAL: actualizar_insumos(actualizar = FALSE)
# ------------------------------------------------------------------------------
# Verifica (y opcionalmente actualiza) los insumos xlsx en 'datos/'.
#   actualizar : TRUE copia el tarifario nuevo desde el proyecto tarifario;
#                FALSE solo verifica (salida temprana si ya está todo).
# Al ser source() desde main.R solo se define la función; por Rscript se ejecuta.
actualizar_insumos <- function(actualizar = FALSE) {

  cat("==============================================================\n")
  cat(" 3_cargar_catalogo.R — VERIFICAR / ACTUALIZAR INSUMOS (PASO OPCIONAL)\n")
  cat("==============================================================\n")
  cat(" Modo:", if (actualizar) "ACTUALIZAR TARIFARIO (--actualizar)" else "verificar (sin cambios)", "\n\n")

  # 3. SALIDA TEMPRANA (paso opcional): si NO se pidió --actualizar y los insumos
  #    obligatorios ya están en 'datos/', no hay nada que hacer.
  if (!actualizar) {
    todos_ok <- all(vapply(insumos, function(ins) {
      if (!ins$obligatorio) TRUE else file.exists(ins$archivo)
    }, logical(1)))
    if (todos_ok) {
      cat("✔ Los insumos obligatorios ya están en 'datos/' (paso OPCIONAL).\n")
      cat("  No hace falta ejecutar nada. Use --actualizar solo cuando cambien\n")
      cat("  los precios en el proyecto tarifario.\n")
      cat("==============================================================\n")
      return(invisible(TRUE))
    }
  }

  # 4. ACTUALIZAR EL TARIFARIO DESDE EL PROYECTO TARIFARIO (--actualizar)
  if (actualizar) {
    r <- preguntar("¿Actualizar el tarifario desde el proyecto tarifario (sobrescribe datos/Tarifario_CTO_086_2026.xlsx)? (s/n): ",
                   default = "n")
    if (r != "s") {
      cat("[-] Actualización cancelada por el usuario.\n")
      return(invisible(FALSE))
    }
    origen_tarifario  <- file.path(ruta_tarifario, "entregables", "Tarifario_CTO_086_2026.xlsx")
    destino_tarifario <- file.path(carpeta_datos, "Tarifario_CTO_086_2026.xlsx")
    if (file.exists(origen_tarifario)) {
      file.copy(origen_tarifario, destino_tarifario, overwrite = TRUE)
      cat("[i] Tarifario actualizado desde:", origen_tarifario, "\n")
    } else {
      warning("\n[!] No se encontró el tarifario en el proyecto tarifario:\n    ",
              origen_tarifario,
              "\n    Coloque manualmente 'Tarifario_CTO_086_2026.xlsx' en 'datos/'.")
    }
  }

  # 5. VERIFICACIÓN DE LOS INSUMOS
  cat("\n--- VERIFICACIÓN DE INSUMOS ---\n")
  ok <- TRUE
  for (ins in insumos) {
    existe <- file.exists(ins$archivo)
    if (existe) {
      obj <- readxl::read_excel(ins$archivo)
      cat("[OK]", basename(ins$archivo),
          "->", nrow(obj), "filas x", ncol(obj), "columnas |",
          paste(names(obj), collapse = " | "), "\n")
    } else {
      if (ins$obligatorio) {
        ok <- FALSE
        cat("[!] FALTA (obligatorio):", basename(ins$archivo),
            "\n    Colóquelo en 'datos/' o ejecute: Rscript 3_cargar_catalogo.R --actualizar\n")
      } else {
        cat("[ ] OPCIONAL (se usan valores por defecto):", basename(ins$archivo), "\n")
      }
    }
  }

  # Verificación de control: el tarifario debe traer las columnas que usa el
  # informe (CODIGO, DESCRIPCION, CLASE, ADICIONAL) y una columna de tarifa
  # (TARIFA o TARIFAS_2026).
  ruta_tar <- file.path(carpeta_datos, "Tarifario_CTO_086_2026.xlsx")
  if (file.exists(ruta_tar)) {
    tar_obj <- readxl::read_excel(ruta_tar)
    req <- c("CODIGO", "DESCRIPCION", "CLASE", "ADICIONAL")
    faltan <- setdiff(req, names(tar_obj))
    tiene_tarifa <- "TARIFA" %in% names(tar_obj) || "TARIFAS_2026" %in% names(tar_obj)
    if (length(faltan) > 0 || !tiene_tarifa) {
      ok <- FALSE
      warning("\n[!] El tarifario no tiene las columnas requeridas por el informe.\n    ",
              "Requiere: CODIGO, DESCRIPCION, CLASE, ADICIONAL y una columna de tarifa",
              " (TARIFA o TARIFAS_2026).\n    Columnas actuales: ",
              paste(names(tar_obj), collapse = " | "))
    } else {
      cat("\n[OK] El tarifario tiene las columnas requeridas por el informe",
          "(tarifa en 'TARIFAS_2026').\n")
    }
  }

  cat("\n==============================================================\n")
  if (ok) {
    cat("[OK] Insumos listos en 'datos/'. Siguiente paso: 4_generar_informe.R\n")
  } else {
    cat("[!] HAY INSUMOS FALTANTES — revisar los mensajes anteriores.\n")
  }
  cat("     Recuerde: este paso es OPCIONAL (solo para verificar o actualizar).\n")
  cat("==============================================================\n")
  invisible(ok)
}

# ------------------------------------------------------------------------------
# Modo standalone (Rscript 3_cargar_catalogo.R [--actualizar])
# ------------------------------------------------------------------------------
if (sys.nframe() == 0) {
  args_cli <- commandArgs(trailingOnly = TRUE)
  actualizar_insumos(actualizar = "--actualizar" %in% args_cli)
}
