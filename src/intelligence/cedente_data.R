# FIDC cedentes (assignors) as published in the monthly report, table I: for
# each fund and month, the 9 largest cedentes of each block with their CPF or
# CNPJ and their share (percent, as published). The report has no cedente
# name; a name is shown only when the CNPJ is a known entity of the catalog.
# CPFs are shown in full (public CVM data; developer decision 2026-11-11).
# Read by the CEDENTES tab of the app and of the published dashboard through
# the same JSON files (prototype/www/cedentes.js).

cedente_data_version <- "1"

# Blocks of table I that list cedentes (CVM dictionary codes).
cedente_blocks <- data.frame(
  block = c("TAB_I2A12", "TAB_I2B12", "TAB_I2B1"),
  label = c("I.2.a.12 · com aquisição substancial dos riscos e benefícios",
            "I.2.b.12 · sem aquisição substancial dos riscos e benefícios",
            "I.2.b.1 · leiaute até out/2019"),
  stringsAsFactors = FALSE)

# Long table: one row per fund, month, block and position with a cedente.
# Positions filled with zeros (no cedente) are left out; a fund reported twice
# in the same month keeps its last published line (latest version).
fidc_cedente_rows <- function(df) {
  df$month <- substr(row_period(df), 1L, 7L)
  df <- df[!is.na(df$month) & !is.na(df$fund_cnpj_normalized), , drop = FALSE]
  df <- df[order(df$fund_cnpj_normalized, df$month, df$source_file, df$source_line, method = "radix"), , drop = FALSE]
  df <- df[!duplicated(paste(df$fund_cnpj_normalized, df$month), fromLast = TRUE), , drop = FALSE]
  parts <- list()
  for (b in cedente_blocks$block) for (k in 1:9) {
    id_col <- sprintf("%s_CPF_CNPJ_CEDENTE_%d", b, k)
    pr_col <- sprintf("%s_PR_CEDENTE_%d", b, k)
    if (!id_col %in% names(df)) next
    id <- trimws(df[[id_col]])
    ok <- !is.na(id) & nzchar(id) & !grepl("^[0./ -]+$", id)
    if (!any(ok)) next
    share <- if (pr_col %in% names(df)) trimws(df[[pr_col]][ok]) else NA_character_
    parts[[length(parts) + 1L]] <- data.frame(
      fund_cnpj = df$fund_cnpj_normalized[ok], month = df$month[ok], block = b, rank = k,
      cedente_original = id[ok], share = ifelse(is.na(share) | !nzchar(share), NA_character_, share),
      stringsAsFactors = FALSE)
  }
  out <- if (length(parts)) do.call(rbind, parts) else
    data.frame(fund_cnpj = character(), month = character(), block = character(), rank = integer(),
               cedente_original = character(), share = character(), stringsAsFactors = FALSE)
  # CPF or CNPJ with the masks of the app; type by the result (invalid values
  # stay as published, type "?").
  out$cedente <- format_tax_id(out$cedente_original, "CPF_CNPJ")
  out$type <- ifelse(grepl("^[0-9]{3}[.][0-9]{3}[.][0-9]{3}-[0-9]{2}$", out$cedente), "PF",
                     ifelse(grepl("^[0-9]{2}[.][0-9]{3}[.][0-9]{3}/[0-9]{4}-[0-9]{2}$", out$cedente), "PJ", "?"))
  rownames(out) <- NULL
  out
}

read_fidc_cedentes <- function(root) {
  ds <- open_fund_table(root, "fidc", "inf_mensal_fidc_tab_I")
  cols <- grep("_(CPF_CNPJ|PR)_CEDENTE_[1-9]$", ds$schema$names, value = TRUE)
  df <- read_fund_columns(root, "fidc", "inf_mensal_fidc_tab_I",
                          c("fund_cnpj_normalized", fund_period_columns, "source_file", "source_line", cols))
  fidc_cedente_rows(df)
}

# Share as a number for sorting (published as 93.53 or 93,53); text kept.
cedente_share_number <- function(x) {
  v <- ifelse(grepl(",", x, fixed = TRUE), gsub(",", ".", gsub(".", "", x, fixed = TRUE), fixed = TRUE), x)
  suppressWarnings(as.numeric(v))
}

# JSON package: index.json (months, blocks, cedentes, FIDCs) and
# months/{yyyy-mm}.json with rows [cedente, fund, block, position, share text].
write_cedente_data <- function(dir, rows, funds, master = NULL, reference = NULL) {
  unlink(dir, recursive = TRUE)
  dir.create(file.path(dir, "months"), recursive = TRUE, showWarnings = FALSE)
  ced <- unique(rows[, c("cedente", "type")])
  ced <- ced[order(ced$cedente, method = "radix"), , drop = FALSE]
  ced <- ced[!duplicated(ced$cedente), , drop = FALSE]
  name <- rep(NA_character_, nrow(ced))
  if (!is.null(master)) {
    e <- master$entities
    k <- match(ced$cedente, e$cnpj_formatted)
    name <- ifelse(ced$type == "PJ" & !is.na(k), e$display_name[k], NA_character_)
  }
  ci <- match(rows$cedente, ced$cedente) - 1L
  span <- tapply(rows$month, ci, range)
  nmonths <- tapply(paste(ci, rows$month), ci, function(v) length(unique(v)))
  first <- vapply(span, `[`, "", 1L); last <- vapply(span, `[`, "", 2L)
  key <- as.character(seq_len(nrow(ced)) - 1L)
  fund_keys <- sort(unique(rows$fund_cnpj))
  fk <- match(fund_keys, funds$fund_cnpj)
  fi <- match(rows$fund_cnpj, fund_keys) - 1L
  bi <- match(rows$block, cedente_blocks$block) - 1L
  months <- sort(unique(rows$month), decreasing = TRUE)
  if (is.null(reference) || !reference %in% months) reference <- months[1]
  index <- paste0(
    "{\"version\":", json_string(cedente_data_version), ",\"reference\":", json_string(reference),
    ",\"months\":[", paste(json_string(months), collapse = ","), "]",
    ",\"blocks\":[", paste(json_string(cedente_blocks$label), collapse = ","), "]",
    ",\"cedentes\":[", paste(sprintf("[%s,%s,%s,%s,%s,%s]", json_string(ced$cedente), json_string(ced$type),
                                     json_string(name), json_string(first[key]), json_string(last[key]),
                                     as.integer(nmonths[key])), collapse = ",\n"), "]",
    ",\"funds\":[", paste(sprintf("[%s,%s,%s]", json_string(fund_keys), json_string(format_cnpj(fund_keys)),
                                  json_string(ifelse(is.na(fk), NA_character_, funds$fund_name[fk]))),
                          collapse = ",\n"), "]}")
  writeLines(enc2utf8(index), file.path(dir, "index.json"), useBytes = TRUE)
  by_month <- split(seq_len(nrow(rows)), rows$month)
  for (m in names(by_month)) {
    i <- by_month[[m]]
    i <- i[order(ci[i], fi[i], bi[i], rows$rank[i], method = "radix")]
    writeLines(sprintf("{\"rows\":[%s]}", paste(sprintf("[%d,%d,%d,%d,%s]", ci[i], fi[i], bi[i], rows$rank[i],
                                                        json_string(rows$share[i])), collapse = ",")),
               file.path(dir, "months", paste0(m, ".json")), useBytes = TRUE)
  }
  invisible(list(months = length(months), cedentes = nrow(ced), rows = nrow(rows)))
}

# FIDC names for the package: the list of the fund tabs (catalog names).
cedente_funds <- function(data) {
  l <- fund_list(data$directory[data$directory$family == "fidc", , drop = FALSE], data$master)
  l[, c("fund_cnpj", "fund_name")]
}

cedente_data_signature <- function(root, master = NULL) {
  index <- read_rds_recoverable(fund_processed_paths(root)$index, is.data.frame)
  keep <- grepl("^cvm:fidc:", index$source_id) & index$table_name == "inf_mensal_fidc_tab_I"
  compute_signature_hash(list(
    version = cedente_data_version, parts = sort(index$output_sha256[keep]),
    directory = fund_directory_signature(root), rules = if (is.null(master)) NA else master$rule_version,
    functions = transformation_signature(list(
      fidc_cedente_rows = fidc_cedente_rows, read_fidc_cedentes = read_fidc_cedentes,
      write_cedente_data = write_cedente_data, format_tax_id = format_tax_id, format_cpf = format_cpf))))
}

# App: the package under processed/metrics/cedentes, rebuilt only when table I
# or the catalog changes.
load_cedente_data <- function(root, data, reference = NULL, rebuild = FALSE) {
  dir <- file.path(fund_processed_paths(root)$base, "metrics", "cedentes")
  sig <- paste(cedente_data_signature(root, data$master), if (is.null(reference)) "" else reference)
  stamp <- file.path(dir, "signature.txt")
  if (!rebuild && file.exists(stamp) && identical(readLines(stamp, warn = FALSE), sig) &&
      file.exists(file.path(dir, "index.json"))) {
    return(dir)
  }
  write_cedente_data(dir, read_fidc_cedentes(root), cedente_funds(data), data$master, reference)
  writeLines(sig, stamp)
  dir
}

# Tab body: filled in the browser by cedentes.js from `src`.
cedentes_ui <- function(src) {
  page <- shiny::div(class = "tm-page tm-fill-page tm-cedentes", `data-src` = src,
                     shiny::div(class = "tm-empty", "Carregando cedentes…"))
  htmltools::bindFillRole(page, container = TRUE, item = TRUE)
}
