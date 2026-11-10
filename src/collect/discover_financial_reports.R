# Discovery of public financial reports (financial_disclosures, MVP Phase 2).
# Source: CVM open data yearly DFP/ITR ZIPs (ODbL). Each ZIP holds an index
# CSV (`{form}_cia_aberta_{year}.csv`) whose LINK_DOC points to the filing
# package on RAD/ENET. See docs/data_sources.md.

cvm_open_data_url <- "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC"
cvm_forms <- c("dfp", "itr")

cvm_index_zip_url <- function(form, year) {
  form <- match.arg(form, cvm_forms)
  sprintf("%s/%s/DADOS/%s_cia_aberta_%d.zip", cvm_open_data_url, toupper(form),
          form, as.integer(year))
}

# Parse one index CSV (Latin-1 in the source; UTF-8 in public fixtures).
parse_cvm_index <- function(csv_path, form, encoding = "latin1") {
  form <- match.arg(form, cvm_forms)
  index <- utils::read.csv2(csv_path, fileEncoding = encoding,
                            colClasses = "character", check.names = FALSE)
  normalize_cvm_index(index, form)
}

read_cvm_index_zip <- function(zip_path, form, year) {
  form <- match.arg(form, cvm_forms)
  member <- sprintf("%s_cia_aberta_%d.csv", form, as.integer(year))
  members <- utils::unzip(zip_path, list = TRUE)$Name
  if (!member %in% members) stop("Index member not found in ", zip_path, ": ", member)
  index <- utils::read.csv2(unz(zip_path, member), fileEncoding = "latin1",
                            colClasses = "character", check.names = FALSE)
  normalize_cvm_index(index, form)
}

normalize_cvm_index <- function(index, form) {
  required <- c("CNPJ_CIA", "DT_REFER", "VERSAO", "DENOM_CIA", "CD_CVM",
                "CATEG_DOC", "ID_DOC", "DT_RECEB", "LINK_DOC")
  missing <- setdiff(required, names(index))
  if (length(missing) > 0) stop("Index columns missing: ", paste(missing, collapse = ", "))
  cnpj_digits <- gsub("[^0-9]", "", index$CNPJ_CIA)
  data.frame(
    source_id = paste0("cvm_open_data_", form),
    report_id = sprintf("cvm:%s:%s:%s:v%s", form, index$CD_CVM, index$DT_REFER,
                        index$VERSAO),
    source_document_id = index$ID_DOC,
    report_type = toupper(form),
    source_category = index$CATEG_DOC,
    cvm_code = index$CD_CVM,
    company_cnpj = ifelse(nchar(cnpj_digits) == 14, cnpj_digits, NA_character_),
    company_name = index$DENOM_CIA,
    reporting_period_end = index$DT_REFER,
    document_version = as.integer(index$VERSAO),
    filing_date = index$DT_RECEB,
    source_url = sub("^http://", "https://", index$LINK_DOC),
    stringsAsFactors = FALSE
  )
}

# Build a catalog from already downloaded index ZIPs named as on the source.
build_financial_report_catalog <- function(index_dir, forms = cvm_forms,
                                           years = 2010:as.integer(format(Sys.Date(), "%Y"))) {
  parts <- list()
  for (form in forms) for (year in years) {
    zip_path <- file.path(index_dir, sprintf("%s_cia_aberta_%d.zip", form, year))
    if (!file.exists(zip_path) || !is_zip_signature(zip_path)) next
    part <- read_cvm_index_zip(zip_path, form, year)
    part$index_year <- rep(as.integer(year), nrow(part))
    parts[[length(parts) + 1]] <- part
  }
  if (length(parts) == 0) stop("No index ZIPs found in ", index_dir)
  catalog <- do.call(rbind, parts)
  duplicated_id <- duplicated(catalog$source_document_id)
  if (any(duplicated_id)) catalog <- catalog[!duplicated_id, ]
  # Newest periods first, so a partial run covers the most recent filings.
  catalog[order(catalog$report_type, -xtfrm(catalog$reporting_period_end),
                catalog$cvm_code, catalog$document_version), ]
}

is_zip_signature <- function(path) {
  file.size(path) >= 4 &&
    identical(readBin(path, "raw", 4), as.raw(c(0x50, 0x4b, 0x03, 0x04)))
}
