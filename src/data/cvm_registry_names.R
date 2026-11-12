# CNPJ -> name table from the CVM registries (src/collect/collect_cvm_registries.R):
# names as published, never edited. One name per CNPJ, by source priority:
# listed companies, then funds and classes (current register, then the old
# fund register), then service providers named in the fund registers
# (administrator, manager, auditor, custodian, controller). Used to name FIDC
# cedentes that the report publishes without a name.

cvm_registry_name_sources <- c(
  cia = "Cadastro de companhias abertas (CVM)",
  fund = "Cadastro de fundos e classes (CVM)",
  provider = "Prestador de serviços nos cadastros de fundos (CVM)")

cnpj_digits <- function(x) {
  d <- gsub("\\D", "", x)
  ifelse(nchar(d) > 0 & nchar(d) <= 14, formatC(suppressWarnings(as.numeric(d)), width = 14, format = "f", digits = 0, flag = "0"),
         NA_character_)
}

read_registry_csv <- function(path, member = NULL) {
  # The registries are Latin-1: read the bytes, convert, then parse.
  con <- if (is.null(member)) file(path, "rb") else unz(path, member, "rb")
  on.exit(close(con))
  lines <- iconv(readLines(con, warn = FALSE, encoding = "bytes"), "latin1", "UTF-8")
  utils::read.csv(text = lines, sep = ";", colClasses = "character", quote = "", na.strings = "",
                  check.names = FALSE, comment.char = "", encoding = "UTF-8")
}

# pairs: list of data frames (cnpj, name) in priority order, each with a source key.
registry_name_pairs <- function(df, cnpj_col, name_col, source, keep = NULL) {
  if (!all(c(cnpj_col, name_col) %in% names(df))) return(NULL)
  if (!is.null(keep)) df <- df[keep, , drop = FALSE]
  data.frame(cnpj = cnpj_digits(df[[cnpj_col]]), name = trimws(df[[name_col]]), source = source,
             stringsAsFactors = FALSE)
}

build_cvm_registry_names <- function(files) {
  parts <- list()
  add <- function(x) if (!is.null(x)) parts[[length(parts) + 1L]] <<- x
  if (!is.na(files[["cad_cia_aberta.csv"]])) {
    cia <- read_registry_csv(files[["cad_cia_aberta.csv"]])
    add(registry_name_pairs(cia, "CNPJ_CIA", "DENOM_SOCIAL", "cia"))
  }
  reg <- files[["registro_fundo_classe.zip"]]
  rf <- rc <- NULL
  if (!is.na(reg)) {
    rf <- read_registry_csv(reg, "registro_fundo.csv")
    rc <- read_registry_csv(reg, "registro_classe.csv")
    add(registry_name_pairs(rf, "CNPJ_Fundo", "Denominacao_Social", "fund"))
    add(registry_name_pairs(rc, "CNPJ_Classe", "Denominacao_Social", "fund"))
  }
  cad <- if (is.na(files[["cad_fi.csv"]])) NULL else read_registry_csv(files[["cad_fi.csv"]])
  if (!is.null(cad)) add(registry_name_pairs(cad, "CNPJ_FUNDO", "DENOM_SOCIAL", "fund"))
  if (!is.null(rf)) {
    add(registry_name_pairs(rf, "CNPJ_Administrador", "Administrador", "provider"))
    add(registry_name_pairs(rf, "CPF_CNPJ_Gestor", "Gestor", "provider", keep = rf$Tipo_Pessoa_Gestor %in% "PJ"))
  }
  if (!is.null(rc)) for (p in c("Auditor", "Custodiante", "Controlador")) add(registry_name_pairs(rc, paste0("CNPJ_", p), p, "provider"))
  if (!is.null(cad)) {
    add(registry_name_pairs(cad, "CNPJ_ADMIN", "ADMIN", "provider"))
    add(registry_name_pairs(cad, "CPF_CNPJ_GESTOR", "GESTOR", "provider", keep = cad$PF_PJ_GESTOR %in% "PJ"))
    for (p in c("AUDITOR", "CUSTODIANTE", "CONTROLADOR")) add(registry_name_pairs(cad, paste0("CNPJ_", p), p, "provider"))
  }
  all <- do.call(rbind, parts)
  if (is.null(all)) return(data.frame(cnpj = character(), name = character(), source = character()))
  all <- all[!is.na(all$cnpj) & !is.na(all$name) & nzchar(all$name) & all$cnpj != strrep("0", 14), , drop = FALSE]
  all <- all[!duplicated(all$cnpj), , drop = FALSE]   # first = highest priority
  rownames(all) <- NULL
  all
}

# Cached table (rds beside the raw files), rebuilt when a raw file changes.
load_cvm_registry_names <- function(root = cvm_registry_root()) {
  files <- latest_cvm_registry_files(root)
  if (all(is.na(files))) return(NULL)
  out <- file.path(root, "processed", "cnpj_names.rds")
  sig <- paste(basename(stats::na.omit(files)), collapse = "|")
  stamp <- file.path(root, "processed", "cnpj_names.signature")
  if (file.exists(out) && file.exists(stamp) && identical(readLines(stamp, warn = FALSE), sig)) return(readRDS(out))
  names_table <- build_cvm_registry_names(files)
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  saveRDS(names_table, out); writeLines(sig, stamp)
  names_table
}
