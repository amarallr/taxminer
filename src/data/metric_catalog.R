# Metric catalog (explorador multimétrico, ETAPA 02; req_0019).
# One central list of business metrics (config/metric_catalog.csv) and their
# mappings to physical CVM tables and fields (config/metric_mappings.csv). The
# interface asks for metric ids, never for columns, tables, files or layouts.
#
# Equivalence rule between layouts (spec, section 4.2, item 8): similar names
# never imply accounting or regulatory equivalence.
#   same_field  the same column of the same table; a layout change that does not
#               touch the column keeps the series.
#   proven      another table or column feeds the same series only with written
#               evidence, checked against the CVM dictionary when it is available.
#   not_proven  the mapping starts a new segment: the series shows a discontinuity
#               and the two segments are never joined.
# A period where the mapped column is missing from the layout is a gap; gaps are
# never interpolated.
#
# Requires src/common/{signatures,safe_io,parquet_io}.R, src/data/consolidate_fund_reports.R
# and src/data/build_fund_metrics.R (parse_cvm_number, read_metric_rows, latest_version)
# to be sourced first.

metric_catalog_enums <- list(
  unit = c("BRL", "count", "pct", "ratio"),
  nature = c("stock", "flow", "rate"),
  granularity = c("fund", "class_series"),
  aggregation = c("latest_version", "sum_classes_same_period", "none"),
  value_type = c("declared", "derived"),
  equivalence = c("same_field", "proven", "not_proven"),
  transform = c("cvm_number"),
  periodicity = c("monthly", "quarterly", "four_monthly"))

metric_catalog_columns <- c("metric_id", "display_name", "description", "family", "category", "unit", "nature",
                            "granularity", "aggregation", "value_type", "formula", "is_default", "notes")
metric_mapping_columns <- c("metric_id", "table_name", "field", "valid_from", "valid_to", "filter_field",
                            "filter_value", "class_key", "transform", "equivalence", "evidence", "periodicity")

read_catalog_csv <- function(path, columns) {
  df <- utils::read.csv(path, colClasses = "character", na.strings = character(), check.names = FALSE,
                        fileEncoding = "UTF-8", stringsAsFactors = FALSE)
  missing <- setdiff(columns, names(df))
  if (length(missing)) stop(basename(path), ": missing columns ", paste(missing, collapse = ", "), call. = FALSE)
  df[] <- lapply(df, trimws)
  df[, columns, drop = FALSE]
}

metric_catalog_read <- function(dir = "config") {
  list(catalog = read_catalog_csv(file.path(dir, "metric_catalog.csv"), metric_catalog_columns),
       mappings = read_catalog_csv(file.path(dir, "metric_mappings.csv"), metric_mapping_columns))
}

# Metric ids referenced by a formula, in order of appearance.
metric_formula_refs <- function(formula) {
  if (is.na(formula) || !nzchar(formula)) return(character())
  unique(regmatches(formula, gregexpr("[a-z]+\\.[a-z0-9_]+", formula))[[1]])
}

# Static syntax: metric ids, numbers, + - * / and parentheses, the only function pct_change().
metric_formula_problem <- function(formula) {
  if (!grepl("^[a-z0-9_. ()+*/-]+$", formula)) return("caracteres não permitidos na fórmula")
  chars <- strsplit(formula, "")[[1]]
  depth <- cumsum((chars == "(") - (chars == ")"))
  if (any(depth < 0) || utils::tail(depth, 1) != 0) return("parênteses desbalanceados")
  calls <- regmatches(formula, gregexpr("[a-z_]+\\(", formula))[[1]]
  if (length(setdiff(calls, "pct_change("))) return("função não permitida na fórmula")
  if (!length(metric_formula_refs(formula))) return("fórmula sem métrica")
  NA_character_
}

# "YYYY-MM" -> month number; "" -> default.
metric_month <- function(x, default) {
  out <- rep(default, length(x))
  ok <- !is.na(x) & grepl("^[0-9]{4}-(0[1-9]|1[0-2])$", x)
  out[ok] <- as.integer(substr(x[ok], 1, 4)) * 12L + as.integer(substr(x[ok], 6, 7)) - 1L
  out
}
metric_month_label <- function(m) sprintf("%04d-%02d", m %/% 12L, m %% 12L + 1L)

# Static checks of the catalog and the mappings. One row per problem; zero rows means valid.
metric_catalog_check <- function(cat) {
  out <- list()
  add <- function(id, check, problem) out[[length(out) + 1L]] <<- data.frame(
    metric_id = id, check = check, problem = problem, stringsAsFactors = FALSE)
  c <- cat$catalog
  m <- cat$mappings
  dup <- unique(c$metric_id[duplicated(c$metric_id)])
  for (id in dup) add(id, "id", "metric_id duplicado")
  for (i in seq_len(nrow(c))) {
    r <- c[i, ]
    if (!grepl("^[a-z]+\\.[a-z0-9_]+$", r$metric_id) || !startsWith(r$metric_id, paste0(r$family, ".")))
      add(r$metric_id, "id", "metric_id deve ser <família>.<nome> em minúsculas")
    for (f in c("unit", "nature", "granularity", "aggregation", "value_type")) {
      if (!r[[f]] %in% metric_catalog_enums[[f]]) add(r$metric_id, f, sprintf("valor inválido: %s", r[[f]]))
    }
    if (!r$is_default %in% c("TRUE", "FALSE")) add(r$metric_id, "is_default", "use TRUE ou FALSE")
    if (!nzchar(r$display_name) || !nzchar(r$description)) add(r$metric_id, "texto", "nome e descrição obrigatórios")
    maps <- m[m$metric_id == r$metric_id, , drop = FALSE]
    if (r$nature == "rate" && r$aggregation == "sum_classes_same_period")
      add(r$metric_id, "agregação", "taxa não pode ser somada entre classes")
    if (r$aggregation == "sum_classes_same_period" && r$granularity != "class_series")
      add(r$metric_id, "agregação", "soma entre classes exige granularidade class_series")
    if (r$value_type == "declared") {
      if (!nrow(maps)) add(r$metric_id, "mapeamento", "métrica declarada sem mapeamento")
      if (nzchar(r$formula)) add(r$metric_id, "fórmula", "métrica declarada não tem fórmula")
      if (r$granularity == "class_series" && any(!nzchar(maps$class_key)))
        add(r$metric_id, "granularidade", "granularidade class_series exige class_key no mapeamento")
      if (r$granularity == "fund" && any(nzchar(maps$class_key)))
        add(r$metric_id, "granularidade", "class_key em métrica de granularidade fund")
    } else if (r$value_type == "derived") {
      if (nrow(maps)) add(r$metric_id, "mapeamento", "métrica derivada não tem mapeamento físico")
      if (r$is_default == "TRUE") add(r$metric_id, "is_default", "somente métricas declaradas são padrão")
      if (!nzchar(r$formula)) { add(r$metric_id, "fórmula", "métrica derivada sem fórmula"); next }
      p <- metric_formula_problem(r$formula)
      if (!is.na(p)) { add(r$metric_id, "fórmula", p); next }
      refs <- metric_formula_refs(r$formula)
      unknown <- setdiff(refs, c$metric_id)
      if (length(unknown)) { add(r$metric_id, "fórmula", paste("métrica inexistente:", paste(unknown, collapse = ", "))); next }
      if (r$metric_id %in% refs) add(r$metric_id, "fórmula", "fórmula referencia a própria métrica")
      ref <- c[match(refs, c$metric_id), , drop = FALSE]
      if (any(ref$family != r$family)) add(r$metric_id, "fórmula", "operandos de outra família")
      if (any(ref$value_type != "declared")) add(r$metric_id, "fórmula", "operandos devem ser métricas declaradas")
      if (any(ref$aggregation == "none" & ref$granularity == "class_series"))
        add(r$metric_id, "granularidade", "operando por classe/série sem agregação ao fundo")
      if (r$unit == "ratio" && !grepl("/", r$formula, fixed = TRUE))
        add(r$metric_id, "unidade", "razão exige divisão")
      if (!grepl("[*/]|pct_change", r$formula)) {
        if (length(unique(ref$unit)) > 1L || ref$unit[1] != r$unit)
          add(r$metric_id, "unidade", "soma ou diferença de unidades diferentes")
        if (length(unique(ref$nature)) > 1L) add(r$metric_id, "natureza", "soma de estoque com fluxo")
      }
      if (grepl("pct_change", r$formula) && (length(refs) != 1L || r$unit != "pct"))
        add(r$metric_id, "unidade", "pct_change usa uma métrica e resulta em pct")
    }
  }
  orphan <- setdiff(m$metric_id, c$metric_id)
  for (id in orphan) add(id, "mapeamento", "mapeamento de métrica inexistente")
  for (i in seq_len(nrow(m))) {
    r <- m[i, ]
    if (!nzchar(r$table_name) || !nzchar(r$field)) add(r$metric_id, "mapeamento", "tabela e campo obrigatórios")
    for (f in c("transform", "equivalence", "periodicity")) {
      if (!r[[f]] %in% metric_catalog_enums[[f]]) add(r$metric_id, f, sprintf("valor inválido: %s", r[[f]]))
    }
    if (xor(nzchar(r$filter_field), nzchar(r$filter_value))) add(r$metric_id, "filtro", "filter_field e filter_value juntos")
    for (f in c("valid_from", "valid_to")) {
      if (nzchar(r[[f]]) && is.na(metric_month(r[[f]], NA_integer_))) add(r$metric_id, "vigência", paste(f, "deve ser AAAA-MM"))
    }
    if (metric_month(r$valid_from, -Inf) > metric_month(r$valid_to, Inf)) add(r$metric_id, "vigência", "início após o fim")
    if (r$equivalence == "proven" && !nzchar(r$evidence)) add(r$metric_id, "equivalência", "equivalência comprovada exige evidência")
  }
  # Per metric: mappings with the same filter must not overlap in time, and a change of
  # table or field needs an explicit equivalence (proven or not_proven).
  for (id in unique(m$metric_id)) {
    g <- m[m$metric_id == id, , drop = FALSE]
    g <- g[order(metric_month(g$valid_from, -1L)), , drop = FALSE]
    from <- metric_month(g$valid_from, -1L)
    to <- metric_month(g$valid_to, .Machine$integer.max)
    for (a in seq_len(nrow(g) - 1L)) for (b in (a + 1L):nrow(g)) {
      if (g$filter_value[a] == g$filter_value[b] && from[b] <= to[a] && from[a] <= to[b])
        add(id, "vigência", sprintf("mapeamentos sobrepostos (%s.%s e %s.%s)", g$table_name[a], g$field[a],
                                   g$table_name[b], g$field[b]))
    }
    for (b in seq_len(nrow(g))[-1L]) {
      changed <- g$table_name[b] != g$table_name[b - 1L] || g$field[b] != g$field[b - 1L]
      if (changed && g$equivalence[b] == "same_field")
        add(id, "equivalência", sprintf("troca para %s.%s exige proven ou not_proven", g$table_name[b], g$field[b]))
    }
  }
  if (!length(out)) return(data.frame(metric_id = character(), check = character(), problem = character()))
  do.call(rbind, out)
}

# Columns of every consolidated file, from one Parquet schema per table and layout
# (the consolidation index keeps one output per source file). Returns the files
# (table_name, layout_version, source_file, period_start, period_end as month numbers)
# and the columns of each "table|layout".
metric_layout_columns <- function(root, tables = NULL) {
  index <- read_rds_recoverable(fund_processed_paths(root)$index, is.data.frame)
  if (!is.null(tables)) index <- index[index$table_name %in% tables, , drop = FALSE]
  period <- regmatches(index$source_file, regexpr("[0-9]{4}([0-9]{2})?(?=\\.csv$)", index$source_file, perl = TRUE))
  ok <- regexpr("[0-9]{4}([0-9]{2})?(?=\\.csv$)", index$source_file, perl = TRUE) > 0
  index <- index[ok, , drop = FALSE]
  year <- as.integer(substr(period, 1, 4))
  monthly <- nchar(period) == 6L
  month <- ifelse(monthly, suppressWarnings(as.integer(substr(period, 5, 6))), NA_integer_)
  files <- data.frame(table_name = index$table_name, layout_version = index$layout_version,
                      source_file = index$source_file,
                      period_start = ifelse(monthly, year * 12L + month - 1L, year * 12L),
                      period_end = ifelse(monthly, year * 12L + month - 1L, year * 12L + 11L),
                      stringsAsFactors = FALSE)
  keys <- unique(paste(index$table_name, index$layout_version, sep = "|"))
  columns <- stats::setNames(lapply(keys, function(k) {
    p <- index$output_path[paste(index$table_name, index$layout_version, sep = "|") == k][1]
    tryCatch(names(arrow::open_dataset(file.path(root, p), format = "parquet")$schema),
             error = function(e) character())
  }), keys)
  list(files = files, columns = columns)
}

# Availability of each mapping and of each metric over the consolidated files.
# A file is in a mapping's window when its period overlaps valid_from..valid_to; the
# mapping is present in a file when the layout of the file has the mapped field (and
# the filter field and class key, when set). Derived metrics take the intersection
# of their operands. Returns list(mappings, metrics).
metric_availability <- function(cat, layouts) {
  m <- cat$mappings
  f <- layouts$files
  rows <- lapply(seq_len(nrow(m)), function(i) {
    r <- m[i, ]
    g <- f[f$table_name == r$table_name &
             f$period_end >= metric_month(r$valid_from, -1L) &
             f$period_start <= metric_month(r$valid_to, .Machine$integer.max), , drop = FALSE]
    need <- c(r$field, if (nzchar(r$filter_field)) r$filter_field, if (nzchar(r$class_key)) r$class_key)
    has <- vapply(paste(g$table_name, g$layout_version, sep = "|"),
                  function(k) all(need %in% layouts$columns[[k]]), logical(1))
    present <- g[has, , drop = FALSE]
    missing <- g[!has, , drop = FALSE]
    data.frame(metric_id = r$metric_id, table_name = r$table_name, field = r$field,
               equivalence = r$equivalence, files = nrow(g), files_with_field = nrow(present),
               first = if (nrow(present)) min(present$period_start) else NA_integer_,
               last = if (nrow(present)) max(present$period_end) else NA_integer_,
               gaps = paste(unique(metric_month_label(missing$period_start[order(missing$period_start)])),
                            collapse = " "),
               stringsAsFactors = FALSE)
  })
  maps <- if (length(rows)) do.call(rbind, rows) else NULL
  c <- cat$catalog
  status <- function(id) {
    g <- maps[maps$metric_id == id, , drop = FALSE]
    if (!nrow(g) || all(g$files_with_field == 0L)) return(list(status = "indisponível", first = NA, last = NA,
                                                               discontinuities = ""))
    g <- g[order(g$first), , drop = FALSE]
    breaks <- g$first[g$equivalence == "not_proven" & seq_len(nrow(g)) > 1L]
    st <- if (length(breaks)) "descontínua" else if (any(nzchar(g$gaps))) "com lacunas" else "disponível"
    list(status = st, first = min(g$first, na.rm = TRUE), last = max(g$last, na.rm = TRUE),
         discontinuities = paste(metric_month_label(breaks), collapse = " "))
  }
  rank <- c("disponível" = 1L, "com lacunas" = 2L, "descontínua" = 3L, "indisponível" = 4L)
  out <- lapply(seq_len(nrow(c)), function(i) {
    id <- c$metric_id[i]
    if (c$value_type[i] == "derived") {
      refs <- metric_formula_refs(c$formula[i])
      s <- lapply(refs[refs %in% c$metric_id], status)
      if (!length(s)) return(data.frame(metric_id = id, status = "indisponível", first = NA, last = NA,
                                        discontinuities = "", stringsAsFactors = FALSE))
      worst <- names(rank)[max(rank[vapply(s, `[[`, "", "status")])]
      firsts <- vapply(s, function(x) as.numeric(x$first), 0)
      lasts <- vapply(s, function(x) as.numeric(x$last), 0)
      return(data.frame(metric_id = id, status = worst, first = max(firsts), last = min(lasts),
                        discontinuities = paste(unique(unlist(lapply(s, `[[`, "discontinuities"))[
                          nzchar(unlist(lapply(s, `[[`, "discontinuities")))]), collapse = " "),
                        stringsAsFactors = FALSE))
    }
    s <- status(id)
    data.frame(metric_id = id, status = s$status, first = s$first, last = s$last,
               discontinuities = s$discontinuities, stringsAsFactors = FALSE)
  })
  metrics <- do.call(rbind, out)
  metrics$first <- ifelse(is.na(metrics$first), "", metric_month_label(as.integer(metrics$first)))
  metrics$last <- ifelse(is.na(metrics$last), "", metric_month_label(as.integer(metrics$last)))
  maps$first <- ifelse(is.na(maps$first), "", metric_month_label(maps$first))
  maps$last <- ifelse(is.na(maps$last), "", metric_month_label(maps$last))
  list(mappings = maps, metrics = metrics)
}

# Dictionary cross-check of every table or field change: a "proven" mapping must
# keep the CVM description of the column it replaces; a "not_proven" one is reported
# with both descriptions. descriptions: data.frame(table_name, field, description).
metric_equivalence_review <- function(cat, descriptions) {
  m <- cat$mappings
  out <- list()
  desc <- function(t, f) {
    d <- descriptions$description[descriptions$table_name == t & descriptions$field == f]
    if (length(d) && !is.na(d[1]) && nzchar(d[1])) trimws(d[1]) else NA_character_
  }
  for (id in unique(m$metric_id)) {
    g <- m[m$metric_id == id, , drop = FALSE]
    g <- g[order(metric_month(g$valid_from, -1L)), , drop = FALSE]
    for (b in seq_len(nrow(g))[-1L]) {
      if (g$table_name[b] == g$table_name[b - 1L] && g$field[b] == g$field[b - 1L]) next
      before <- desc(g$table_name[b - 1L], g$field[b - 1L])
      after <- desc(g$table_name[b], g$field[b])
      same <- !is.na(before) && !is.na(after) && identical(before, after)
      verdict <- if (g$equivalence[b] == "not_proven") "descontinuidade declarada"
        else if (same) "comprovada pelo dicionário"
        else if (is.na(before) || is.na(after)) "sem descrição no dicionário: evidência só documental"
        else "descrições diferentes: não comprovada"
      out[[length(out) + 1L]] <- data.frame(
        metric_id = id, from = paste(g$table_name[b - 1L], g$field[b - 1L], sep = "."),
        to = paste(g$table_name[b], g$field[b], sep = "."), since = g$valid_from[b],
        equivalence = g$equivalence[b], description_before = before, description_after = after,
        verdict = verdict, stringsAsFactors = FALSE)
    }
  }
  if (!length(out)) return(data.frame(metric_id = character(), from = character(), to = character(),
                                      since = character(), equivalence = character(),
                                      description_before = character(), description_after = character(),
                                      verdict = character()))
  do.call(rbind, out)
}

# Matrix metric x CVM form table: the mapped field, or empty.
metric_table_matrix <- function(cat) {
  m <- cat$mappings
  tables <- sort(unique(m$table_name))
  ids <- cat$catalog$metric_id[cat$catalog$value_type == "declared"]
  mat <- matrix("", length(ids), length(tables), dimnames = list(ids, tables))
  for (i in seq_len(nrow(m))) {
    if (m$metric_id[i] %in% ids) mat[m$metric_id[i], m$table_name[i]] <- m$field[i]
  }
  mat
}

# Series of one declared metric from rows already read per mapping (pure, testable).
# rows: list with one data.frame per mapping row of the metric, each with fund_cnpj,
# period (YYYY-MM-DD), version, source_file, source_line and the mapped columns.
# Keeps the latest version per fund, period (and class); applies the filter; sums the
# classes when the metric says so. Every point carries its lineage (table, field,
# segment). A new segment starts at each not_proven mapping; segments are never joined.
metric_series_from_rows <- function(metric, maps, rows) {
  maps <- maps[order(metric_month(maps$valid_from, -1L)), , drop = FALSE]
  segment <- cumsum(c(1L, maps$equivalence[-1L] == "not_proven"))
  parts <- list()
  for (i in seq_len(nrow(maps))) {
    r <- maps[i, ]
    df <- rows[[i]]
    if (is.null(df) || !nrow(df)) next
    month <- metric_month(substr(df$period, 1, 7), NA_integer_)
    keep <- !is.na(month) & month >= metric_month(r$valid_from, -1L) &
      month <= metric_month(r$valid_to, .Machine$integer.max)
    if (nzchar(r$filter_field)) keep <- keep & !is.na(df[[r$filter_field]]) & df[[r$filter_field]] == r$filter_value
    df <- df[keep, , drop = FALSE]
    if (!nrow(df)) next
    cls <- if (nzchar(r$class_key)) df[[r$class_key]] else rep("", nrow(df))
    df <- latest_version(df, paste(df$fund_cnpj, df$period, cls, sep = "\r"))
    df$value <- parse_cvm_number(df[[r$field]])
    df$class <- if (nzchar(r$class_key)) df[[r$class_key]] else NA_character_
    if (metric$aggregation == "sum_classes_same_period") {
      key <- paste(df$fund_cnpj, df$period, sep = "\r")
      first <- !duplicated(key)
      total <- tapply(df$value, key, function(v) if (all(is.na(v))) NA_real_ else sum(v, na.rm = TRUE))
      n <- tapply(df$value, key, length)
      df <- df[first, , drop = FALSE]
      df$value <- unname(total[key[first]])
      df$classes <- as.integer(n[key[first]])
      df$class <- NA_character_
    } else {
      df$classes <- if (nzchar(r$class_key)) 1L else NA_integer_
    }
    parts[[length(parts) + 1L]] <- data.frame(
      metric_id = metric$metric_id, fund_cnpj = df$fund_cnpj, period = df$period, class = df$class,
      value = df$value, classes = df$classes, segment = segment[i], table_name = r$table_name, field = r$field,
      equivalence = r$equivalence, source_file = df$source_file, source_line = as.integer(df$source_line),
      stringsAsFactors = FALSE)
  }
  if (!length(parts)) return(NULL)
  out <- do.call(rbind, parts)
  out[order(out$fund_cnpj, out$period, out$class), , drop = FALSE]
}

# Series of one declared metric read from the consolidated Parquet.
metric_series <- function(root, cat, metric_id, family = NULL) {
  metric <- cat$catalog[cat$catalog$metric_id == metric_id, , drop = FALSE]
  if (nrow(metric) != 1L) stop("Unknown metric: ", metric_id, call. = FALSE)
  if (metric$value_type != "declared") stop("Only declared metrics are read: ", metric_id, call. = FALSE)
  maps <- cat$mappings[cat$mappings$metric_id == metric_id, , drop = FALSE]
  maps <- maps[order(metric_month(maps$valid_from, -1L)), , drop = FALSE]
  family <- if (is.null(family)) metric$family else family
  rows <- lapply(seq_len(nrow(maps)), function(i) {
    cols <- c(maps$field[i], if (nzchar(maps$filter_field[i])) maps$filter_field[i],
              if (nzchar(maps$class_key[i])) maps$class_key[i])
    read_metric_rows(root, family, maps$table_name[i], cols)
  })
  metric_series_from_rows(metric, maps, rows)
}
