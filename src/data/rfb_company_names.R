# Corporate names (razão social) by CNPJ root from the Receita Federal CNPJ
# open data "Empresas" files (src/collect/collect_rfb_cnpj.R), as published.
# The files are large (about 60 million companies): each zip is read as a
# stream and only the requested roots are kept. Layout of each line, no
# header, ';' separated, quoted, Latin-1: CNPJ_BASICO; RAZAO_SOCIAL;
# NATUREZA_JURIDICA; QUALIFICACAO_RESPONSAVEL; CAPITAL_SOCIAL; PORTE;
# ENTE_FEDERATIVO_RESPONSAVEL.

rfb_company_columns <- c("root", "name", "legal_nature", "responsible_qualification", "capital", "size",
                         "federal_entity")

# Latest month with all ten Empresas files downloaded (NA if none).
rfb_companies_month <- function(root) {
  m <- read_rfb_manifest(root)
  m <- m[m$outcome == "downloaded" & grepl("^Empresas[0-9]\\.zip$", m$file_name), , drop = FALSE]
  full <- names(which(tapply(m$file_name, m$month, function(x) length(unique(x))) == 10L))
  if (length(full)) max(full) else NA_character_
}

# Lines of one zip whose CNPJ root is in `roots`, parsed.
read_rfb_company_zip <- function(path, roots, chunk = 500000L) {
  member <- utils::unzip(path, list = TRUE)$Name[1]
  con <- unz(path, member, "rb"); on.exit(close(con))
  keep <- character()
  repeat {
    lines <- readLines(con, n = chunk, warn = FALSE, encoding = "bytes")
    if (!length(lines)) break
    hit <- substr(lines, 2L, 9L) %in% roots
    if (any(hit)) keep <- c(keep, iconv(lines[hit], "latin1", "UTF-8"))
  }
  if (!length(keep)) return(NULL)
  df <- utils::read.csv(text = keep, sep = ";", header = FALSE, colClasses = "character", quote = "\"",
                        na.strings = "", col.names = rfb_company_columns, encoding = "UTF-8")
  df
}

build_rfb_company_names <- function(root, roots, month = rfb_companies_month(root)) {
  roots <- unique(roots[!is.na(roots) & nchar(roots) == 8L])
  if (is.na(month) || !length(roots)) return(NULL)
  files <- file.path(root, "raw", "rfb_cnpj", month, sprintf("Empresas%d.zip", 0:9))
  out <- do.call(rbind, lapply(files, read_rfb_company_zip, roots = roots))
  if (is.null(out)) return(data.frame(root = character(), name = character(), month = character()))
  out <- out[!is.na(out$name) & nzchar(trimws(out$name)), , drop = FALSE]
  out <- out[!duplicated(out$root), , drop = FALSE]
  data.frame(root = out$root, name = trimws(out$name), legal_nature = out$legal_nature, month = month,
             stringsAsFactors = FALSE)
}

# Cached under <root>/processed, rebuilt when the month or the set of roots changes.
load_rfb_company_names <- function(root, roots) {
  month <- rfb_companies_month(root)
  if (is.na(month)) return(NULL)
  roots <- sort(unique(roots[!is.na(roots) & nchar(roots) == 8L]))
  sig <- paste(month, compute_signature_hash(roots))
  out <- file.path(root, "processed", "rfb_company_names.rds")
  stamp <- file.path(root, "processed", "rfb_company_names.signature")
  if (file.exists(out) && file.exists(stamp) && identical(readLines(stamp, warn = FALSE), sig)) return(readRDS(out))
  names_table <- build_rfb_company_names(root, roots, month)
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  saveRDS(names_table, out); writeLines(sig, stamp)
  names_table
}
