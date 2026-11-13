# Validates the metric catalog (config/metric_catalog.csv, config/metric_mappings.csv)
# and writes reports/metric_catalog/validation_report.md. Run from the project root:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/validate_metric_catalog.R
# Without TAXMINER_DATA_DIR only the static checks run. With it, also: availability over
# the consolidated layouts, dictionary review of every layout or table change, and the
# comparison of the default metrics with the series the Ficha shows today
# (processed/metrics/fund_period_metrics.parquet). Exit status 1 on any problem.

for (f in c("src/common/signatures.R", "src/common/safe_io.R", "src/common/parquet_io.R",
            "src/common/data_layout.R", "src/data/consolidate_fund_reports.R", "src/data/build_fund_metrics.R",
            "src/intelligence/search_fund_reports.R", "src/data/metric_catalog.R")) {
  source(f, encoding = "UTF-8")
}

cat_ <- metric_catalog_read("config")
problems <- metric_catalog_check(cat_)
md_table <- function(df) {
  if (!nrow(df)) return("Nenhum.")
  esc <- function(x) gsub("|", "\\|", ifelse(is.na(x), "", as.character(x)), fixed = TRUE)
  c(paste0("| ", paste(names(df), collapse = " | "), " |"), paste0("|", strrep(" --- |", ncol(df))),
    apply(df, 1, function(r) paste0("| ", paste(esc(r), collapse = " | "), " |")))
}
fmt_int <- function(x) formatC(x, format = "d", big.mark = ".")

c_ <- cat_$catalog
lines <- c("# Catálogo de métricas: relatório de validação", "",
           sprintf("Gerado em %s por `scripts/validate_metric_catalog.R`.", format(Sys.time(), "%Y-%m-%d %H:%M")), "",
           sprintf("Métricas: %d (%d declaradas, %d derivadas); mapeamentos: %d; famílias: %s.",
                   nrow(c_), sum(c_$value_type == "declared"), sum(c_$value_type == "derived"),
                   nrow(cat_$mappings), paste(unique(c_$family), collapse = ", ")), "",
           "## Verificação estática", "", md_table(problems), "")

# Default metrics must read the same columns as the current Ficha (fund_metric_sources).
consistency <- list()
expect <- list(patrimonio_liquido = "net_assets", cotistas = "quotaholders", ativo_total = "total_assets")
for (family in names(fund_metric_sources)) {
  src <- fund_metric_sources[[family]]
  for (name in names(expect)) {
    id <- paste(family, name, sep = ".")
    maps <- cat_$mappings[cat_$mappings$metric_id == id, , drop = FALSE]
    current <- if (family == "fidc" && name == "cotistas") src$class_quotaholders else src[[expect[[name]]]]
    tables <- if (family == "fidc" && name == "cotistas") src$class_table else src$table
    if (!length(current)) next
    ok <- nrow(maps) > 0 && all(maps$field %in% current) && all(maps$table_name %in% tables)
    consistency[[length(consistency) + 1L]] <- data.frame(
      metric_id = id, catalog = paste(unique(paste(maps$table_name, maps$field, sep = ".")), collapse = ", "),
      ficha_atual = paste(paste(tables, current[1], sep = "."), collapse = ", "),
      resultado = if (ok) "igual" else "DIFERENTE", stringsAsFactors = FALSE)
  }
}
consistency <- do.call(rbind, consistency)
lines <- c(lines, "## Consistência com a Ficha atual (fund_metric_sources)", "", md_table(consistency), "")
failed <- nrow(problems) > 0 || any(consistency$resultado != "igual")

data_dir <- Sys.getenv("TAXMINER_DATA_DIR")
if (nzchar(data_dir)) {
  root <- source_data_root(resolve_data_dir(data_dir), "investment_fund_reports")
  layouts <- metric_layout_columns(root, unique(cat_$mappings$table_name))
  av <- metric_availability(cat_, layouts)
  review <- metric_equivalence_review(cat_, fund_field_descriptions(root))
  bad_review <- review$equivalence == "proven" & review$verdict == "descrições diferentes: não comprovada"
  unavailable <- av$metrics$metric_id[av$metrics$status == "indisponível"]
  m <- av$mappings
  m$gaps <- ifelse(nchar(m$gaps) > 80, paste0(substr(m$gaps, 1, 77), "..."), m$gaps)
  m$files <- fmt_int(m$files)
  m$files_with_field <- fmt_int(m$files_with_field)
  lines <- c(lines, "## Disponibilidade por métrica", "",
             md_table(merge(c_[, c("metric_id", "display_name", "value_type")], av$metrics, sort = FALSE)), "",
             "## Disponibilidade por mapeamento (arquivos consolidados com o campo no leiaute)", "",
             md_table(m), "",
             "## Mudanças de tabela ou campo: revisão pelo dicionário da CVM", "",
             md_table(review), "")
  failed <- failed || any(bad_review) || length(unavailable) > 0

  # Values: default metrics against the series the Ficha shows today.
  metrics_path <- metric_paths(root)$table
  if (file.exists(metrics_path)) {
    current <- as.data.frame(arrow::read_parquet(metrics_path))
    column <- c(patrimonio_liquido = "net_assets", cotistas = "quotaholders")
    cmp <- list()
    for (id in c_$metric_id[c_$is_default == "TRUE"]) {
      name <- sub("^[a-z]+\\.", "", id)
      family <- sub("\\..*$", "", id)
      s <- metric_series(root, cat_, id)
      cur <- current[current$family == family, c("fund_cnpj", "period", column[[name]])]
      if (is.null(s)) s <- data.frame(fund_cnpj = character(), period = character(), value = numeric())
      j <- merge(cur, s[, c("fund_cnpj", "period", "value")], by = c("fund_cnpj", "period"), all.x = TRUE)
      a <- j[[column[[name]]]]
      b <- j$value
      same <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) <= 1e-6 * pmax(1, abs(a)))
      cmp[[length(cmp) + 1L]] <- data.frame(
        metric_id = id, pontos_ficha = fmt_int(sum(!is.na(a))), pontos_catalogo = fmt_int(sum(!is.na(b))),
        divergencias = fmt_int(sum(!same)), resultado = if (all(same)) "igual" else "DIFERENTE",
        stringsAsFactors = FALSE)
    }
    cmp <- do.call(rbind, cmp)
    lines <- c(lines, "## Valores das métricas padrão contra a série atual da Ficha", "", md_table(cmp), "")
    failed <- failed || any(cmp$resultado != "igual")
  } else {
    lines <- c(lines, "Série atual da Ficha ausente: comparação de valores não executada.", "")
  }
} else {
  lines <- c(lines, "TAXMINER_DATA_DIR não definido: somente a verificação estática foi executada.", "")
}

mat <- metric_table_matrix(cat_)
mat_df <- data.frame(metric_id = rownames(mat), mat, check.names = FALSE, stringsAsFactors = FALSE)
lines <- c(lines, "## Matriz métrica × tabela da CVM (campo físico)", "", md_table(mat_df), "")

out <- file.path("reports", "metric_catalog", "validation_report.md")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
writeLines(enc2utf8(lines), out, useBytes = TRUE)
cat("Written", out, "\n")
cat(if (failed) "Result: problems found\n" else "Result: ok\n")
if (failed) quit(status = 1L)
