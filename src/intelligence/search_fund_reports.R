# Phase 1.3 search over the consolidated CVM investment fund reports
# (req_0014, work_0022). Independent of the other source families: reads only
# the Data P04 Parquet tables, its consolidation index and the Collect P05
# manifests under the investment_fund_reports root.
#
# Requires src/common/{signatures,safe_io,parquet_io}.R and
# src/data/consolidate_fund_reports.R to be sourced first.

# Tables that carry the fund's name and, when published, its administrator.
# FIP reports do not publish the administrator.
fund_directory_tables <- data.frame(
  family = c("fii", "fidc", "fip", "fip", "fiagro"),
  table_name = c("inf_mensal_fii_geral", "inf_mensal_fidc_tab_I", "inf_trimestral_fip",
                 "inf_quadrimestral_fip", "inf_mensal_fiagro"),
  stringsAsFactors = FALSE)

# Candidate CVM columns, first non-empty value wins (layouts renamed them).
fund_name_columns <- c("Nome_Fundo_Classe", "Nome_Fundo", "Nome_Classe", "DENOM_SOCIAL")
fund_admin_name_columns <- c("Nome_Administrador", "ADMIN")
fund_admin_cnpj_columns <- c("CNPJ_Administrador", "CNPJ_ADMIN")

fund_directory_columns <- c("family", "fund_cnpj", "fund_cnpj_original", "fund_name",
                            "administrator_name", "administrator_cnpj", "first_period",
                            "last_period", "period_count", "fund_period_count", "zip_sha256", "source_file",
                            "source_line")

fund_search_paths <- function(root) {
  base <- file.path(fund_processed_paths(root)$base, "search")
  list(base = base, directory = file.path(base, "fund_directory.parquet"),
       index = file.path(base, "fund_directory_index.rds"))
}

# Upper case without accents, single spaces: the comparison form for text filters.
normalize_search_text <- function(x) {
  from <- "ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ"
  x <- toupper(enc2utf8(as.character(ifelse(is.na(x), "", x))))
  x <- chartr(from, "AAAAAEEEEIIIIOOOOOUUUUCN", x)
  gsub("\\s+", " ", trimws(x))
}

# Period bounds typed as yyyy, yyyy-mm or yyyy-mm-dd, turned into dates that
# compare as strings with the CVM period columns.
period_bound <- function(value, upper = FALSE) {
  if (is.null(value) || is.na(value) || !nzchar(trimws(value))) return(NA_character_)
  value <- trimws(value)
  if (!grepl("^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$", value)) {
    stop("period must be yyyy, yyyy-mm or yyyy-mm-dd: ", value, call. = FALSE)
  }
  if (nchar(value) == 4L) value <- paste0(value, if (upper) "-12" else "-01")
  if (nchar(value) == 7L) value <- paste0(value, if (upper) "-31" else "-01")
  value
}

first_present <- function(df, candidates) {
  out <- rep(NA_character_, nrow(df))
  for (column in intersect(candidates, names(df))) {
    take <- is.na(out) & !is.na(df[[column]]) & nzchar(trimws(df[[column]]))
    out[take] <- trimws(df[[column]][take])
  }
  out
}

row_period <- function(df) {
  value <- first_present(df, fund_period_columns)
  ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", value), substr(value, 1L, 10L), NA_character_)
}

read_fund_columns <- function(root, family, table_name, columns, filter = NULL) {
  ds <- open_fund_table(root, family, table_name)
  scan <- ds$NewScan()
  scan$Project(intersect(columns, ds$schema$names))
  if (!is.null(filter)) scan$Filter(filter)
  as.data.frame(scan$Finish()$ToTable())
}

# FIP "entidade de investimento" indicator (ENTID_INVEST: S or N, as
# published): the most recent non-empty value of each fund across the
# quarterly (until 2023) and four-monthly (from 2024) reports. Funds that never
# published it are left out (shown as "não informado"); values other than S
# and N are kept as published.
fund_investment_entity_tables <- c("inf_trimestral_fip", "inf_quadrimestral_fip")

latest_investment_entity <- function(rows) {
  v <- trimws(rows$ENTID_INVEST)
  rows <- rows[!is.na(v) & nzchar(v) & !is.na(rows$fund_cnpj_normalized), , drop = FALSE]
  v <- toupper(trimws(rows$ENTID_INVEST))
  period <- row_period(rows)
  o <- order(rows$fund_cnpj_normalized, period, decreasing = c(FALSE, TRUE), na.last = TRUE, method = "radix")
  rows <- rows[o, , drop = FALSE]; v <- v[o]; period <- period[o]
  first <- !duplicated(rows$fund_cnpj_normalized)
  data.frame(fund_cnpj = rows$fund_cnpj_normalized[first], investment_entity = v[first],
             investment_entity_period = substr(period[first], 1L, 7L), stringsAsFactors = FALSE)
}

fund_investment_entity <- function(root) {
  base <- fund_processed_paths(root)$base
  parts <- lapply(fund_investment_entity_tables, function(t) {
    if (!dir.exists(file.path(base, "fip", t))) return(NULL)
    df <- read_fund_columns(root, "fip", t, c("fund_cnpj_normalized", "ENTID_INVEST", fund_period_columns))
    if (!"ENTID_INVEST" %in% names(df)) return(NULL)
    for (column in setdiff(fund_period_columns, names(df))) df[[column]] <- NA_character_
    df[, c("fund_cnpj_normalized", "ENTID_INVEST", fund_period_columns), drop = FALSE]
  })
  rows <- do.call(rbind, parts)
  if (is.null(rows) || !nrow(rows)) {
    return(data.frame(fund_cnpj = character(), investment_entity = character(),
                      investment_entity_period = character()))
  }
  latest_investment_entity(rows)
}

# Fund characteristics shown in the fund tabs: the most recent non-empty value
# of each field per fund, as published (S/N fields upper-cased and trimmed,
# other values kept). Each family only has the fields its CVM report carries;
# the others are "not in the report" (see fund_attribute_families).
fund_attribute_specs <- data.frame(
  attribute = c("condominium", "exclusive", "single_interest", "exclusive", "exclusive",
                "family_link", "family_link", "investment_entity", "investment_entity", "family_link"),
  family = c("fidc", "fidc", "fidc", "fii", "fii", "fii", "fii", "fip", "fip", "fiagro"),
  table_name = c("inf_mensal_fidc_tab_I", "inf_mensal_fidc_tab_I", "inf_mensal_fidc_tab_I",
                 "inf_mensal_fii_geral", "inf_trimestral_fii_geral", "inf_mensal_fii_geral",
                 "inf_trimestral_fii_geral", "inf_trimestral_fip", "inf_quadrimestral_fip", "inf_mensal_fiagro"),
  column = c("CONDOM", "FUNDO_EXCLUSIVO", "COTST_INTERESSE", "Fundo_Exclusivo", "Fundo_Exclusivo",
             "Cotistas_Vinculo_Familiar", "Cotistas_Vinculo_Familiar", "ENTID_INVEST", "ENTID_INVEST",
             "Cotistas_Vinculo_Familiar"),
  stringsAsFactors = FALSE)

fund_attribute_labels <- c(
  condominium = "Condomínio", exclusive = "Fundo exclusivo",
  single_interest = "Cotistas com interesse único e indissociável",
  investment_entity = "Entidade de investimento",
  family_link = "Cotistas com vínculo familiar ou societário familiar")

# Families whose report has each field (the rest show "não consta do informe").
fund_attribute_families <- function(attribute) {
  unique(fund_attribute_specs$family[fund_attribute_specs$attribute == attribute])
}

# rows: fund_cnpj_normalized, value, period columns; one result row per fund.
latest_attribute <- function(rows) {
  v <- trimws(rows$value)
  rows <- rows[!is.na(v) & nzchar(v) & !is.na(rows$fund_cnpj_normalized), , drop = FALSE]
  v <- trimws(rows$value)
  v <- ifelse(toupper(v) %in% c("S", "N"), toupper(v), v)
  period <- row_period(rows)
  o <- order(rows$fund_cnpj_normalized, period, decreasing = c(FALSE, TRUE), na.last = TRUE, method = "radix")
  rows <- rows[o, , drop = FALSE]; v <- v[o]; period <- period[o]
  first <- !duplicated(rows$fund_cnpj_normalized)
  data.frame(fund_cnpj = rows$fund_cnpj_normalized[first], value = v[first],
             period = substr(period[first], 1L, 7L), stringsAsFactors = FALSE)
}

# Long table: family, fund_cnpj, attribute, value, period.
fund_attributes <- function(root, specs = fund_attribute_specs) {
  base <- fund_processed_paths(root)$base
  out <- list()
  for (key in unique(paste(specs$family, specs$attribute))) {
    s <- specs[paste(specs$family, specs$attribute) == key, , drop = FALSE]
    parts <- lapply(seq_len(nrow(s)), function(i) {
      if (!dir.exists(file.path(base, s$family[i], s$table_name[i]))) return(NULL)
      df <- read_fund_columns(root, s$family[i], s$table_name[i],
                              c("fund_cnpj_normalized", s$column[i], fund_period_columns))
      if (!s$column[i] %in% names(df)) return(NULL)
      for (column in setdiff(fund_period_columns, names(df))) df[[column]] <- NA_character_
      data.frame(fund_cnpj_normalized = df$fund_cnpj_normalized, value = as.character(df[[s$column[i]]]),
                 df[, fund_period_columns, drop = FALSE], stringsAsFactors = FALSE)
    })
    rows <- do.call(rbind, parts)
    if (is.null(rows) || !nrow(rows)) next
    l <- latest_attribute(rows)
    if (nrow(l)) out[[key]] <- data.frame(family = s$family[1], fund_cnpj = l$fund_cnpj, attribute = s$attribute[1],
                                          value = l$value, period = l$period, stringsAsFactors = FALSE)
  }
  if (!length(out)) return(data.frame(family = character(), fund_cnpj = character(), attribute = character(),
                                      value = character(), period = character()))
  do.call(rbind, unname(out))
}

# Display text of one characteristic of one fund ("sim", "não", "fechado",
# "não informado" or "não consta do informe").
fund_attribute_text <- function(attributes, family, cnpj, attribute) {
  if (!family %in% fund_attribute_families(attribute)) return(list(text = "não consta do informe", period = NA_character_))
  k <- which(attributes$family == family & attributes$fund_cnpj == cnpj & attributes$attribute == attribute)
  if (!length(k)) return(list(text = "não informado", period = NA_character_))
  v <- attributes$value[k[1]]
  list(text = switch(v, S = "sim", N = "não", tolower(v)), period = attributes$period[k[1]])
}

# Keeps the FIPs whose latest indicator is `value` ("S", "N" or "NA" for not
# published); other families are not affected by the filter.
filter_investment_entity <- function(rows, entity, value) {
  if (is.null(value) || !length(value) || !nzchar(value[1])) return(rows)
  v <- entity$investment_entity[match(rows$fund_cnpj, entity$fund_cnpj)]
  keep <- rows$family != "fip" | (if (value[1] == "NA") is.na(v) else !is.na(v) & v == value[1])
  rows[keep, , drop = FALSE]
}

fund_directory_signature <- function(root) {
  index <- read_rds_recoverable(fund_processed_paths(root)$index, is.data.frame)
  family <- sub("^cvm:([^:]+):.*$", "\\1", index$source_id)
  keep <- paste(family, index$table_name) %in%
    paste(fund_directory_tables$family, fund_directory_tables$table_name)
  compute_signature_hash(list(
    parts = sort(index$output_sha256[keep]),
    functions = transformation_signature(list(
      build_fund_directory = build_fund_directory, first_present = first_present,
      row_period = row_period)),
    columns = list(fund_directory_tables, fund_name_columns, fund_admin_name_columns,
                   fund_admin_cnpj_columns, fund_directory_columns)))
}

# One row per fund, name and administrator as published, with the period span
# and a citation of the most recent report that carries them.
build_fund_directory <- function(root) {
  columns <- c("fund_cnpj_normalized", "fund_cnpj_original", fund_name_columns,
               fund_admin_name_columns, fund_admin_cnpj_columns, fund_period_columns,
               "zip_sha256", "source_file", "source_line")
  parts <- lapply(seq_len(nrow(fund_directory_tables)), function(i) {
    family <- fund_directory_tables$family[i]
    table <- fund_directory_tables$table_name[i]
    if (!dir.exists(file.path(fund_processed_paths(root)$base, family, table))) return(NULL)
    df <- read_fund_columns(root, family, table, columns)
    if (nrow(df) == 0L) return(NULL)
    data.frame(
      family = family,
      fund_cnpj = ifelse(is.na(df$fund_cnpj_normalized), df$fund_cnpj_original,
                         df$fund_cnpj_normalized),
      fund_cnpj_original = df$fund_cnpj_original,
      fund_name = first_present(df, fund_name_columns),
      administrator_name = first_present(df, fund_admin_name_columns),
      administrator_cnpj = first_present(df, fund_admin_cnpj_columns),
      period = row_period(df),
      zip_sha256 = df$zip_sha256, source_file = df$source_file,
      source_line = as.integer(df$source_line), stringsAsFactors = FALSE)
  })
  rows <- do.call(rbind, parts)
  if (is.null(rows)) {
    empty <- as.data.frame(setNames(replicate(length(fund_directory_columns), character(),
                                              simplify = FALSE), fund_directory_columns))
    empty$period_count <- integer()
    empty$fund_period_count <- integer()
    empty$source_line <- integer()
    return(empty)
  }
  rows <- rows[!is.na(rows$fund_cnpj) & nzchar(rows$fund_cnpj), , drop = FALSE]
  key <- paste(rows$family, rows$fund_cnpj, rows$fund_name, rows$administrator_name,
               rows$administrator_cnpj, sep = "\r")
  ascending <- order(key, rows$period, na.last = TRUE, method = "radix")
  first <- ascending[!duplicated(key[ascending])]
  # Most recent row per key carries the citation.
  descending <- order(key, rows$period, rows$source_file, rows$source_line, decreasing = TRUE,
                      na.last = TRUE, method = "radix")
  latest <- descending[!duplicated(key[descending])]
  out <- rows[latest, , drop = FALSE]
  out$last_period <- out$period
  out$first_period <- rows$period[first][match(key[latest], key[first])]
  distinct <- !is.na(rows$period) & !duplicated(paste(key, rows$period, sep = "\r"))
  counts <- table(factor(key[distinct], levels = unique(key)))
  out$period_count <- as.integer(counts[key[latest]])
  fund <- paste(rows$family, rows$fund_cnpj, sep = "\r")
  fund_distinct <- !is.na(rows$period) & !duplicated(paste(fund, rows$period, sep = "\r"))
  fund_counts <- table(factor(fund[fund_distinct], levels = unique(fund)))
  out$fund_period_count <- as.integer(fund_counts[paste(out$family, out$fund_cnpj, sep = "\r")])
  out$fund_period_count[is.na(out$fund_period_count)] <- 0L
  out <- out[order(out$family, normalize_search_text(out$fund_name), out$fund_cnpj,
                   out$last_period, method = "radix"), fund_directory_columns]
  rownames(out) <- NULL
  out
}

# Directory cached as Parquet next to the tables; rebuilt when the registry
# table parts or this code change.
load_fund_directory <- function(root, rebuild = FALSE) {
  paths <- fund_search_paths(root)
  signature <- fund_directory_signature(root)
  cached <- if (file.exists(paths$index)) read_rds_recoverable(paths$index, is.list) else NULL
  if (!rebuild && file.exists(paths$directory) && identical(cached$signature, signature)) {
    return(as.data.frame(arrow::read_parquet(paths$directory)))
  }
  directory <- build_fund_directory(root)
  dir.create(paths$base, recursive = TRUE, showWarnings = FALSE)
  write_parquet_validated(directory, paths$directory)
  write_validated_atomic(list(signature = signature, rows = nrow(directory),
                              built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
                         paths$index, format = "rds")
  directory
}

# Filters combine with AND. cnpj matches a prefix of the 14-character CNPJ
# (punctuation ignored); administrator matches the name or CNPJ; name matches
# the fund name; text matching ignores case and accents. Periods keep funds
# whose reports overlap [period_from, period_to].
search_fund_directory <- function(directory, family = NULL, cnpj = NULL, administrator = NULL,
                                  name = NULL, period_from = NULL, period_to = NULL) {
  keep <- rep(TRUE, nrow(directory))
  if (length(family)) keep <- keep & directory$family %in% family
  if (length(cnpj) && nzchar(trimws(cnpj))) {
    query <- toupper(gsub("[^0-9A-Za-z]", "", cnpj))
    keep <- keep & startsWith(toupper(gsub("[^0-9A-Za-z]", "", directory$fund_cnpj)), query)
  }
  if (length(administrator) && nzchar(trimws(administrator))) {
    query <- normalize_search_text(administrator)
    digits <- gsub("[^0-9]", "", administrator)
    hit <- grepl(query, normalize_search_text(directory$administrator_name), fixed = TRUE)
    if (nchar(digits) >= 4L) {
      hit <- hit | grepl(digits, gsub("[^0-9]", "", directory$administrator_cnpj), fixed = TRUE)
    }
    keep <- keep & hit
  }
  if (length(name) && nzchar(trimws(name))) {
    keep <- keep & grepl(normalize_search_text(name), normalize_search_text(directory$fund_name),
                         fixed = TRUE)
  }
  from <- period_bound(period_from)
  to <- period_bound(period_to, upper = TRUE)
  if (!is.na(from)) keep <- keep & !is.na(directory$last_period) & directory$last_period >= from
  if (!is.na(to)) keep <- keep & !is.na(directory$first_period) & directory$first_period <= to
  out <- directory[keep, , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Directory rows with their entity ids (src/data/entity_resolution.R): the
# fund by its CNPJ, the administrator by its CNPJ (a name equal to the fund
# name is a known CVM data error and is not used).
annotate_directory_entities <- function(directory) {
  same <- !is.na(directory$administrator_name) &
    normalize_search_text(directory$administrator_name) == normalize_search_text(directory$fund_name)
  directory$fund_entity <- entity_key("fund", directory$fund_cnpj_original, directory$fund_name)
  directory$administrator_entity <- entity_key("administrator", directory$administrator_cnpj,
                                               ifelse(same, NA_character_, directory$administrator_name))
  directory
}

# A filter value: selected options (entity or denomination ids, several
# allowed) or free text (CNPJ with or without mask, current, historical,
# normalized or abbreviated name). Returns entity ids, or NULL for no filter.
resolve_entity_query <- function(value, master, type, rules = NULL) {
  value <- value[!is.na(value) & nzchar(trimws(value))]
  if (!length(value)) return(NULL)
  ids <- startsWith(value, paste0(type, ":"))
  out <- resolve_entity_ids(value[ids])
  for (text in value[!ids]) out <- c(out, match_entities(master, type, text, rules))
  unique(out)
}

# Search by entity: every directory row of the selected entities, whatever
# the name used in each period.
search_fund_entities <- function(directory, family = NULL, funds = NULL, administrators = NULL,
                                 period_from = NULL, period_to = NULL) {
  keep <- rep(TRUE, nrow(directory))
  if (length(family)) keep <- keep & directory$family %in% family
  if (!is.null(funds)) keep <- keep & directory$fund_entity %in% funds
  if (!is.null(administrators)) keep <- keep & directory$administrator_entity %in% administrators
  from <- period_bound(period_from)
  to <- period_bound(period_to, upper = TRUE)
  if (!is.na(from)) keep <- keep & !is.na(directory$last_period) & directory$last_period >= from
  if (!is.na(to)) keep <- keep & !is.na(directory$first_period) & directory$first_period <= to
  out <- directory[keep, , drop = FALSE]
  rownames(out) <- NULL
  out
}

# One line per fund and family: the denomination from the entity catalog,
# the latest administrator, the full period span and report count.
fund_list <- function(rows, master) {
  if (!nrow(rows)) {
    rows$cnpj_formatted <- character(); rows$name_count <- integer(); rows$administrator_display <- character()
    return(rows)
  }
  key <- paste(rows$family, rows$fund_entity, sep = "\r")
  latest <- order(key, rows$last_period, decreasing = TRUE, na.last = TRUE, method = "radix")
  latest <- latest[!duplicated(key[latest])]
  out <- rows[latest, , drop = FALSE]
  k <- key[latest]
  out$first_period <- as.character(tapply(rows$first_period, key, function(v) { v <- v[!is.na(v)]; if (length(v)) min(v) else NA_character_ })[k])
  out$last_period <- as.character(tapply(rows$last_period, key, function(v) { v <- v[!is.na(v)]; if (length(v)) max(v) else NA_character_ })[k])
  out$period_count <- out$fund_period_count
  e <- master$entities
  m <- match(out$fund_entity, e$entity_id)
  out$fund_name <- ifelse(is.na(m), out$fund_name, e$display_name[m])
  out$cnpj_formatted <- ifelse(is.na(m), out$fund_cnpj_original, e$cnpj_formatted[m])
  out$name_count <- ifelse(is.na(m), 1L, e$name_count[m])
  a <- match(out$administrator_entity, e$entity_id)
  out$administrator_display <- ifelse(is.na(a), out$administrator_name, e$display_name[a])
  rownames(out) <- NULL
  out
}

# Official download URL of each stored file, from the Collect P05 manifests.
fund_source_urls <- function(root) {
  files <- list.files(file.path(root, "manifests"), pattern = "\\.csv$", full.names = TRUE)
  rows <- do.call(rbind, lapply(files, function(f) {
    m <- utils::read.csv(f, colClasses = "character", check.names = FALSE)
    m[!is.na(m$file_sha256) & nzchar(m$file_sha256), c("file_sha256", "source_url"), drop = FALSE]
  }))
  if (is.null(rows)) return(data.frame(file_sha256 = character(), source_url = character()))
  rows[!duplicated(rows$file_sha256), , drop = FALSE]
}

# Tables available for a family, with row counts and period span of the files.
fund_tables <- function(root, family = NULL) {
  index <- read_rds_recoverable(fund_processed_paths(root)$index, is.data.frame)
  index$family <- sub("^cvm:([^:]+):.*$", "\\1", index$source_id)
  index$period <- sub("^.*_([0-9]{4,6})\\.csv$", "\\1", index$source_file)
  if (length(family)) index <- index[index$family %in% family, , drop = FALSE]
  if (nrow(index) == 0L) {
    return(data.frame(family = character(), table_name = character(), members = integer(),
                      rows = integer(), layouts = integer(), first_period = character(),
                      last_period = character()))
  }
  out <- do.call(rbind, lapply(split(index, list(index$family, index$table_name), drop = TRUE),
                               function(d) {
    data.frame(family = d$family[1], table_name = d$table_name[1], members = nrow(d),
               rows = sum(d$row_count), layouts = length(unique(d$layout_version)),
               first_period = min(d$period), last_period = max(d$period))
  }))
  out <- out[order(out$family, out$table_name), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Remembers the datasets opened and the last `size` fund queries, so reopening
# a fund, or going back to a table already seen, costs no new parquet scan.
# The processed data does not change while the app runs.
fund_rows_cache <- function(root, urls, size = 40L) {
  datasets <- new.env(parent = emptyenv())
  results <- new.env(parent = emptyenv())
  order <- character()
  function(family, table_name, cnpj, period_from = NULL, period_to = NULL) {
    key <- paste(family, table_name, cnpj, paste(period_from, collapse = ","),
                 paste(period_to, collapse = ","), sep = "|")
    if (!is.null(results[[key]])) return(results[[key]])
    dkey <- paste(family, table_name, sep = "/")
    if (is.null(datasets[[dkey]])) assign(dkey, open_fund_table(root, family, table_name), envir = datasets)
    r <- fund_report_rows(root, family, table_name, cnpj, period_from, period_to,
                          urls = urls, ds = datasets[[dkey]])
    assign(key, r, envir = results)
    order <<- c(setdiff(order, key), key)
    if (length(order) > size) {
      rm(list = order[1L], envir = results)
      order <<- order[-1L]
    }
    r
  }
}

# Rows of one table for one fund, original values plus a citation of the CVM
# file (dataset, stored file hash, member and line) and its official URL.
fund_report_rows <- function(root, family, table_name, cnpj, period_from = NULL,
                             period_to = NULL, drop_empty = TRUE, urls = fund_source_urls(root),
                             ds = open_fund_table(root, family, table_name)) {
  query <- toupper(gsub("[^0-9A-Za-z]", "", cnpj))
  column <- if (!is.na(normalize_cnpj(query))) "fund_cnpj_normalized" else "fund_cnpj_original"
  filter <- arrow::Expression$create("equal", arrow::Expression$field_ref(column),
                                     arrow::Expression$scalar(if (column == "fund_cnpj_normalized") query else cnpj))
  scan <- ds$NewScan()
  scan$Filter(filter)
  rows <- as.data.frame(scan$Finish()$ToTable())
  period <- row_period(rows)
  from <- period_bound(period_from)
  to <- period_bound(period_to, upper = TRUE)
  keep <- rep(TRUE, nrow(rows))
  if (!is.na(from)) keep <- keep & !is.na(period) & period >= from
  if (!is.na(to)) keep <- keep & !is.na(period) & period <= to
  rows <- rows[keep, , drop = FALSE]
  period <- period[keep]
  rows <- rows[order(period, rows$source_file, rows$source_line, method = "radix"), , drop = FALSE]
  rows$source_url <- urls$source_url[match(rows$zip_sha256, urls$file_sha256)]
  rows$citation <- sprintf("CVM %s, %s, linha %s, arquivo SHA-256 %s", rows$dataset,
                           rows$source_file, rows$source_line, substr(rows$zip_sha256, 1L, 12L))
  lineage <- c("citation", "source_url", "reference_period", "layout_version", "fund_cnpj_original",
               "fund_cnpj_normalized", "zip_sha256", "source_file", "source_line")
  cvm <- setdiff(names(rows), c(lineage, fund_report_columns))
  if (drop_empty && nrow(rows)) {
    cvm <- cvm[vapply(cvm, function(n) any(!is.na(rows[[n]]) & nzchar(rows[[n]])), logical(1))]
  }
  rows <- rows[, c(lineage, cvm), drop = FALSE]
  rownames(rows) <- NULL
  rows
}

# Quality records of the consolidation, summed per family and issue type.
fund_quality_summary <- function(root) {
  base <- fund_processed_paths(root)$base
  families <- list.dirs(base, recursive = FALSE, full.names = FALSE)
  parts <- lapply(families, function(family) {
    dir <- file.path(base, family, "fund_quality_issues")
    if (!dir.exists(dir)) return(NULL)
    scan <- arrow::open_dataset(dir, format = "parquet")$NewScan()
    scan$Project(c("issue_type", "row_count"))
    df <- as.data.frame(scan$Finish()$ToTable())
    if (nrow(df) == 0L) return(NULL)
    counts <- tapply(as.numeric(df$row_count), df$issue_type, sum)
    data.frame(family = family, issue_type = names(counts), records = as.numeric(counts))
  })
  out <- do.call(rbind, parts)
  if (is.null(out)) return(data.frame(family = character(), issue_type = character(),
                                      records = numeric()))
  rownames(out) <- NULL
  out
}

# Names shown in the table pickers instead of the CVM file names. FIDC: the
# sections of the monthly report (ICVM 489 / Res. CVM 175 form); X.7 has no
# description in the CVM dictionary, its name comes from its fields
# (TAB_X_PR_GARANTIA_DIRCRED, TAB_X_VL_GARANTIA_DIRCRED). The CVM name stays in
# the tooltip and in each citation.
fund_table_labels <- c(
  inf_mensal_fidc_tab_I = "I – Aplicações",
  inf_mensal_fidc_tab_II = "II – Carteira por segmento",
  inf_mensal_fidc_tab_III = "III – Passivo",
  inf_mensal_fidc_tab_IV = "IV – Patrimônio líquido",
  inf_mensal_fidc_tab_V = "V – Carteira de direitos creditórios com aquisição substancial dos riscos e benefícios",
  inf_mensal_fidc_tab_VI = "VI – Carteira de direitos creditórios sem aquisição substancial dos riscos e benefícios",
  inf_mensal_fidc_tab_VII = "VII – Negócios com direitos creditórios realizados no mês",
  inf_mensal_fidc_tab_VIII = "VIII – Valor devido dos 25 maiores devedores (sacados)",
  inf_mensal_fidc_tab_IX = "IX – Taxas praticadas nos negócios com direitos creditórios do mês",
  inf_mensal_fidc_tab_X = "X – Outras informações",
  inf_mensal_fidc_tab_X_1 = "X.1 – Número de cotistas",
  inf_mensal_fidc_tab_X_1_1 = "X.1.1 – Número de cotistas por classe e tipo de investidor",
  inf_mensal_fidc_tab_X_2 = "X.2 – Descrição da série/classe",
  inf_mensal_fidc_tab_X_3 = "X.3 – Rentabilidade apurada no mês",
  inf_mensal_fidc_tab_X_4 = "X.4 – Captações, resgates e amortizações",
  inf_mensal_fidc_tab_X_5 = "X.5 – Liquidez",
  inf_mensal_fidc_tab_X_6 = "X.6 – Desempenho esperado (benchmark) e realizado",
  inf_mensal_fidc_tab_X_7 = "X.7 – Garantias dos direitos creditórios",
  inf_mensal_fii_geral = "Mensal – Geral",
  inf_mensal_fii_complemento = "Mensal – Complemento",
  inf_mensal_fii_ativo_passivo = "Mensal – Ativo e passivo",
  inf_trimestral_fii_geral = "Trimestral – Geral",
  inf_trimestral_fii_complemento = "Trimestral – Complemento",
  inf_trimestral_fii_ativo = "Trimestral – Ativos",
  inf_trimestral_fii_ativo_garantia_rentabilidade = "Trimestral – Ativos com garantia de rentabilidade",
  inf_trimestral_fii_direito = "Trimestral – Direitos",
  inf_trimestral_fii_imovel = "Trimestral – Imóveis",
  inf_trimestral_fii_imovel_desempenho = "Trimestral – Desempenho dos imóveis",
  inf_trimestral_fii_imovel_renda_acabado_contrato = "Trimestral – Imóveis para renda acabados: contratos",
  inf_trimestral_fii_imovel_renda_acabado_inquilino = "Trimestral – Imóveis para renda acabados: inquilinos",
  inf_trimestral_fii_terreno = "Trimestral – Terrenos",
  inf_trimestral_fii_aquisicao_imovel = "Trimestral – Aquisição de imóveis",
  inf_trimestral_fii_aquisicao_terreno = "Trimestral – Aquisição de terrenos",
  inf_trimestral_fii_alienacao_imovel = "Trimestral – Alienação de imóveis",
  inf_trimestral_fii_alienacao_terreno = "Trimestral – Alienação de terrenos",
  inf_trimestral_fii_rentabilidade_efetiva = "Trimestral – Rentabilidade efetiva",
  inf_trimestral_fii_resultado_contabil_financeiro = "Trimestral – Resultado contábil e financeiro",
  inf_anual_fii_geral = "Anual – Geral",
  inf_anual_fii_complemento = "Anual – Complemento",
  inf_anual_fii_ativo_adquirido = "Anual – Ativos adquiridos",
  inf_anual_fii_ativo_transacao = "Anual – Transações de ativos",
  inf_anual_fii_ativo_valor_contabil = "Anual – Valor contábil dos ativos",
  inf_anual_fii_distribuicao_cotistas = "Anual – Distribuição de cotistas",
  inf_anual_fii_diretor_responsavel = "Anual – Diretor responsável",
  inf_anual_fii_experiencia_profissional = "Anual – Experiência profissional",
  inf_anual_fii_prestador_servico = "Anual – Prestadores de serviço",
  inf_anual_fii_processo = "Anual – Processos",
  inf_anual_fii_processo_semelhante = "Anual – Processos semelhantes",
  inf_anual_fii_representante_cotista = "Anual – Representantes de cotistas",
  inf_anual_fii_representante_cotista_fundo = "Anual – Representantes de cotistas (fundo)",
  inf_trimestral_fip = "Informe trimestral",
  inf_quadrimestral_fip = "Informe quadrimestral",
  inf_mensal_fiagro = "Informe mensal",
  inf_mensal_fiagro_subclasse = "Informe mensal – Subclasses")

# Display name of each table; unknown tables keep their CVM name.
fund_table_label <- function(table_name) {
  out <- unname(fund_table_labels[table_name])
  ifelse(is.na(out), table_name, out)
}

# Field descriptions from the CVM META dictionaries stored in <root>/meta
# ("Campo: X" followed by "Descrição : ..."). One row per table and field;
# tables are named as in the consolidation (meta_{table}.txt).
fund_field_descriptions <- function(root) {
  files <- list.files(file.path(root, "meta"), pattern = "^meta_.*\\.(zip|txt)$", full.names = TRUE)
  rows <- list()
  for (path in files) {
    texts <- if (grepl("\\.zip$", path)) {
      members <- utils::unzip(path, list = TRUE)$Name
      stats::setNames(lapply(members, function(m) readLines(unz(path, m), warn = FALSE)), members)
    } else {
      stats::setNames(list(readLines(path, warn = FALSE)), basename(path))
    }
    for (member in names(texts)) {
      lines <- trimws(iconv(texts[[member]], "latin1", "UTF-8"))
      field_at <- grep("^Campo:", lines)
      if (!length(field_at)) next
      desc_at <- grep("^Descri", lines)
      description <- vapply(field_at, function(i) {
        j <- desc_at[desc_at > i][1]
        nxt <- c(field_at[field_at > i], Inf)[1]
        if (is.na(j) || j > nxt) NA_character_ else trimws(sub("^[^:]*:", "", lines[j]))
      }, character(1))
      rows[[length(rows) + 1L]] <- data.frame(
        table_name = sub("^meta_", "", sub("\\.txt$", "", basename(member))),
        field = trimws(sub("^Campo:", "", lines[field_at])), description = description,
        stringsAsFactors = FALSE)
    }
  }
  if (!length(rows)) return(data.frame(table_name = character(), field = character(), description = character()))
  out <- do.call(rbind, rows)
  out$description[!is.na(out$description) & !nzchar(out$description)] <- NA_character_
  out[!duplicated(paste(out$table_name, tolower(out$field))), , drop = FALSE]
}

# Description of each field of one table (case-insensitive); NA when unknown.
describe_fields <- function(descriptions, table_name, fields) {
  d <- descriptions[descriptions$table_name == table_name, , drop = FALSE]
  unname(d$description[match(tolower(fields), tolower(d$field))])
}
