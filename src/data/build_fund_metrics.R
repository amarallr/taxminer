# Phase 1.3 derived table: one row per fund and report period with the
# headline numbers (net assets, total assets, quotaholders) parsed from the
# consolidated CVM tables. Source values stay in the Data P04 Parquet; this
# table only converts them, keeps the citation of the row each number came
# from and records how resubmissions were resolved.
#
# Requires src/common/{signatures,safe_io,parquet_io}.R and
# src/data/consolidate_fund_reports.R to be sourced first.

# Per family: the table and CVM columns (first present wins) of each measure.
# FIDC publishes quotaholders per class/series in tab_X_1; they are summed.
fund_metric_sources <- list(
  fii = list(table = "inf_mensal_fii_complemento", net_assets = "Patrimonio_Liquido",
             total_assets = "Valor_Ativo", quotaholders = "Total_Numero_Cotistas"),
  fiagro = list(table = "inf_mensal_fiagro", net_assets = "Patrimonio_Liquido",
                total_assets = "Valor_Ativo", quotaholders = "Numero_Cotistas"),
  fip = list(table = c("inf_trimestral_fip", "inf_quadrimestral_fip"), net_assets = "VL_PATRIM_LIQ",
             total_assets = character(), quotaholders = "NR_COTST"),
  fidc = list(table = "inf_mensal_fidc_tab_IV", net_assets = "TAB_IV_A_VL_PL",
              total_assets = character(), quotaholders = character(),
              class_table = "inf_mensal_fidc_tab_X_1", class_quotaholders = "TAB_X_NR_COTST",
              class_key = "TAB_X_CLASSE_SERIE"))

fund_metric_columns <- c("family", "fund_cnpj", "period", "net_assets", "total_assets", "quotaholders",
                         "rows_in_period", "table_name", "zip_sha256", "source_file", "source_line")

# CVM numbers use a dot as decimal separator and no thousands separator.
# Anything else becomes NA (never zero); the caller counts those.
parse_cvm_number <- function(x) {
  x <- trimws(x)
  ok <- !is.na(x) & grepl("^-?[0-9]+(\\.[0-9]+)?$", x)
  out <- rep(NA_real_, length(x))
  out[ok] <- as.numeric(x[ok])
  out
}

metric_paths <- function(root) {
  base <- file.path(fund_processed_paths(root)$base, "metrics")
  list(base = base, table = file.path(base, "fund_period_metrics.parquet"),
       index = file.path(base, "fund_period_metrics_index.rds"))
}

# First non-empty value among candidate columns, row by row.
coalesce_columns <- function(df, candidates) {
  out <- rep(NA_character_, nrow(df))
  for (column in intersect(candidates, names(df))) {
    take <- is.na(out) & !is.na(df[[column]]) & nzchar(trimws(df[[column]]))
    out[take] <- trimws(df[[column]][take])
  }
  out
}

read_metric_rows <- function(root, family, table, columns) {
  dir <- file.path(fund_processed_paths(root)$base, family, table)
  if (!dir.exists(dir)) return(NULL)
  ds <- arrow::open_dataset(dir, format = "parquet", unify_schemas = TRUE)
  wanted <- c("fund_cnpj_normalized", "fund_cnpj_original", fund_period_columns, fund_version_columns,
              columns, "zip_sha256", "source_file", "source_line")
  scan <- ds$NewScan()
  scan$Project(intersect(wanted, ds$schema$names))
  df <- as.data.frame(scan$Finish()$ToTable())
  if (nrow(df) == 0L) return(NULL)
  for (column in setdiff(columns, names(df))) df[[column]] <- NA_character_
  df$fund_cnpj <- ifelse(is.na(df$fund_cnpj_normalized), df$fund_cnpj_original, df$fund_cnpj_normalized)
  period <- coalesce_columns(df, fund_period_columns)
  df$period <- ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", period), substr(period, 1, 10), NA_character_)
  version <- coalesce_columns(df, fund_version_columns)
  df$version <- suppressWarnings(as.numeric(version))
  df$table_name <- table
  df[!is.na(df$fund_cnpj) & nzchar(df$fund_cnpj) & !is.na(df$period), , drop = FALSE]
}

# Keep one row per key: highest version, then the latest file and line.
latest_version <- function(df, key) {
  # Within a key: highest version first, then the later file and line.
  o <- order(key, ifelse(is.na(df$version), -Inf, df$version), df$source_file,
             as.integer(df$source_line),
             method = "radix", decreasing = TRUE)
  first <- o[!duplicated(key[o])]
  out <- df[first, , drop = FALSE]
  out$rows_in_period <- as.integer(table(key)[key[first]])
  out
}

build_fund_metrics <- function(root) {
  parts <- list()
  issues <- list(unparsed = 0L, resolved_rows = 0L)
  for (family in names(fund_metric_sources)) {
    src <- fund_metric_sources[[family]]
    columns <- c(src$net_assets, src$total_assets, src$quotaholders)
    rows <- do.call(rbind, lapply(src$table, function(t) read_metric_rows(root, family, t, columns)))
    if (is.null(rows)) next
    key <- paste(rows$fund_cnpj, rows$period, sep = "\r")
    picked <- latest_version(rows, key)
    issues$resolved_rows <- issues$resolved_rows + nrow(rows) - nrow(picked)
    value <- function(cols) {
      if (!length(cols)) return(rep(NA_real_, nrow(picked)))
      raw <- coalesce_columns(picked, cols)
      parsed <- parse_cvm_number(raw)
      issues$unparsed <<- issues$unparsed + sum(!is.na(raw) & is.na(parsed))
      parsed
    }
    out <- data.frame(family = family, fund_cnpj = picked$fund_cnpj, period = picked$period,
                      net_assets = value(src$net_assets), total_assets = value(src$total_assets),
                      quotaholders = value(src$quotaholders), rows_in_period = picked$rows_in_period,
                      table_name = picked$table_name, zip_sha256 = picked$zip_sha256,
                      source_file = picked$source_file, source_line = as.integer(picked$source_line),
                      stringsAsFactors = FALSE)
    if (!is.null(src$class_table)) {
      classes <- read_metric_rows(root, family, src$class_table, c(src$class_quotaholders, src$class_key))
      if (!is.null(classes)) {
        ckey <- paste(classes$fund_cnpj, classes$period, classes[[src$class_key]], sep = "\r")
        classes <- latest_version(classes, ckey)
        n <- parse_cvm_number(classes[[src$class_quotaholders]])
        total <- tapply(n, paste(classes$fund_cnpj, classes$period, sep = "\r"),
                        function(v) if (all(is.na(v))) NA_real_ else sum(v, na.rm = TRUE))
        out$quotaholders <- unname(total[paste(out$fund_cnpj, out$period, sep = "\r")])
      }
    }
    parts[[family]] <- out
  }
  metrics <- do.call(rbind, parts)
  if (is.null(metrics)) {
    metrics <- as.data.frame(setNames(replicate(length(fund_metric_columns), character(), simplify = FALSE),
                                      fund_metric_columns))
  }
  rownames(metrics) <- NULL
  structure(metrics[, fund_metric_columns], issues = issues)
}

fund_metrics_signature <- function(root) {
  index <- read_rds_recoverable(fund_processed_paths(root)$index, is.data.frame)
  tables <- unlist(lapply(fund_metric_sources, function(s) c(s$table, s$class_table)))
  compute_signature_hash(list(
    parts = sort(index$output_sha256[index$table_name %in% tables]),
    functions = transformation_signature(list(
      parse_cvm_number = parse_cvm_number, coalesce_columns = coalesce_columns,
      read_metric_rows = read_metric_rows,
      latest_version = latest_version, build_fund_metrics = build_fund_metrics)),
    sources = fund_metric_sources, columns = fund_metric_columns))
}

load_fund_metrics <- function(root, rebuild = FALSE) {
  paths <- metric_paths(root)
  signature <- fund_metrics_signature(root)
  cached <- if (file.exists(paths$index)) read_rds_recoverable(paths$index, is.list) else NULL
  if (!rebuild && file.exists(paths$table) && identical(cached$signature, signature)) {
    out <- as.data.frame(arrow::read_parquet(paths$table))
    return(structure(out, issues = cached$issues))
  }
  metrics <- build_fund_metrics(root)
  dir.create(paths$base, recursive = TRUE, showWarnings = FALSE)
  write_parquet_validated(as.data.frame(metrics), paths$table)
  write_validated_atomic(list(signature = signature, rows = nrow(metrics), issues = attr(metrics, "issues"),
                              built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
                         paths$index, format = "rds")
  metrics
}
