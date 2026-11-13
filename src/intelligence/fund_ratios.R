# Relative metrics of the tab Distribuições (docs/metric_relativization_proposal.md).
# Rules in config/metric_ratio_rules.csv: each numeric field of a report table can
# be shown as a share of the table total (share_of_total) or over the net assets
# (over_pl); analytic rules add extra ratios (analytic); keep leaves the field
# as published. The ratio of a fund is the median of its numerator rows over the
# median of its denominator rows at the same competência (the same "one value
# per fund" rule as the absolute values), so the published panel computes it
# from the Ficha rows exactly as the app does. Denominators that are missing,
# zero or negative leave the fund out of that ratio, and the count is reported.

fund_ratio_kinds <- c("share_of_total", "over_pl", "analytic", "keep")

fund_ratio_rules <- function(path = file.path("config", "metric_ratio_rules.csv")) {
  if (!file.exists(path)) return(NULL)
  r <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = character(), encoding = "UTF-8")
  stopifnot(all(r$kind %in% fund_ratio_kinds))
  r
}

# Terms of a denominator: "A+B" (fields) or "sum(<regex>)" (all matching fields).
fund_ratio_terms <- function(den) {
  if (!nzchar(den)) return(character())
  strsplit(den, "+", fixed = TRUE)[[1]]
}

fund_ratio_term_fields <- function(term, fields) {
  if (startsWith(term, "sum(")) grep(substr(term, 5, nchar(term) - 1), fields, perl = TRUE, value = TRUE) else term
}

# Ratio plan of one table: one row per ratio key. key = "r:<field>" for the base
# ratio of a field (first share_of_total / over_pl rule that matches it, unless a
# keep rule matches first) and "a:<field>/<denominator>" for analytic ratios.
fund_ratio_plan <- function(rules, table_name, fields) {
  empty <- data.frame(key = character(), field = character(), kind = character(), label = character(),
                      den_table = character(), den = character(), stringsAsFactors = FALSE)
  if (is.null(rules) || !length(fields)) return(empty)
  mine <- rules[vapply(strsplit(rules$table_name, "|", fixed = TRUE), function(t) table_name %in% t, logical(1)), , drop = FALSE]
  if (!nrow(mine)) return(empty)
  out <- list()
  for (f in fields) {
    hit <- mine[vapply(mine$numerator, function(p) grepl(p, f, perl = TRUE), logical(1)), , drop = FALSE]
    if (!nrow(hit)) next
    base <- hit[hit$kind != "analytic", , drop = FALSE]
    if (nrow(base) && base$kind[1] != "keep")
      out[[length(out) + 1L]] <- data.frame(key = paste0("r:", f), field = f, kind = base$kind[1], label = base$label_pt[1],
                                            den_table = base$denominator_table[1], den = base$denominator[1], stringsAsFactors = FALSE)
    an <- hit[hit$kind == "analytic", , drop = FALSE]
    for (i in seq_len(nrow(an)))
      out[[length(out) + 1L]] <- data.frame(key = paste0("a:", f, "/", an$denominator[i]), field = f, kind = "analytic",
                                            label = an$label_pt[i], den_table = an$denominator_table[i], den = an$denominator[i],
                                            stringsAsFactors = FALSE)
  }
  if (!length(out)) return(empty)
  out <- do.call(rbind, out)
  out$den_table[out$den_table == "same_row"] <- table_name
  out[!duplicated(out$key), , drop = FALSE]
}

# Denominator per fund: sum of its terms (fund values named by fund key); a fund
# needs at least one term published. vals = list(table -> list(field -> named vector)).
fund_ratio_denominator <- function(den, den_table, vals) {
  tv <- vals[[den_table]]
  if (is.null(tv)) return(numeric())
  parts <- unlist(lapply(fund_ratio_terms(den), function(t) fund_ratio_term_fields(t, names(tv))), use.names = FALSE)
  parts <- intersect(parts, names(tv))
  if (!length(parts)) return(numeric())
  keys <- unique(unlist(lapply(parts, function(p) names(tv[[p]])), use.names = FALSE))
  m <- vapply(parts, function(p) unname(tv[[p]][keys]), numeric(length(keys)))
  if (is.null(dim(m))) m <- matrix(m, nrow = length(keys))
  stats::setNames(rowSums(m, na.rm = TRUE), keys)
}

# Ratios per fund for every row of plan: list(values = key -> named vector,
# excluded = key -> funds with the numerator but no valid denominator).
fund_ratio_values <- function(plan, table_name, vals) {
  values <- list(); excluded <- integer()
  for (i in seq_len(nrow(plan))) {
    num <- vals[[table_name]][[plan$field[i]]]
    if (is.null(num) || !length(num)) next
    den <- fund_ratio_denominator(plan$den[i], plan$den_table[i], vals)
    d <- unname(den[names(num)])
    ok <- !is.na(d) & d > 0
    excluded[[plan$key[i]]] <- sum(!ok)
    if (any(ok)) values[[plan$key[i]]] <- num[ok] / d[ok]
  }
  list(values = values, excluded = excluded)
}

# Tables a plan reads besides its own.
fund_ratio_tables <- function(plan, table_name) setdiff(unique(plan$den_table), c(table_name, ""))

# Label of a ratio: "{item}" is replaced by the field label.
fund_ratio_label <- function(label, item) gsub("{item}", item, label, fixed = TRUE)

# Bounded shares are drawn on a linear scale; other ratios keep the log scale.
fund_ratio_linear <- function(kind) kind == "share_of_total"

# Rules as JSON for the published panel: [[table_name, numerator, den_table, den, kind, label], ...].
fund_ratio_rules_json <- function(rules = fund_ratio_rules()) {
  if (is.null(rules)) return("[]")
  s <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE)
  paste0("[", paste(vapply(seq_len(nrow(rules)), function(i)
    s(unname(as.list(rules[i, c("table_name", "numerator", "denominator_table", "denominator", "kind", "label_pt")]))),
    character(1)), collapse = ","), "]")
}
