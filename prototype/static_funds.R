# Fund tabs of the published (static) dashboard: data files for the browser
# (prototype/static/taxminer_static.js renders them). Same sources as the app:
# fund list and denominations from the entity catalog
# (src/data/entity_resolution.R), profile figures from the derived metrics.
# Ficha and Série completa: one file per fund (write_static_fichas). JSON writers
# and the per-fund monthly series: src/intelligence/panorama_data.R.

# Profile figures per fund (vectorized fund_profile): latest reported month,
# 12-month change, rank and percentile within the family snapshot.
static_fund_profiles <- function(ctx) {
  m <- ctx$m[!ctx$m$carried, , drop = FALSE]
  m <- m[order(m$family, m$fund_cnpj, m$period, method = "radix"), , drop = FALSE]
  key <- paste(m$family, m$fund_cnpj)
  last <- m[!duplicated(key, fromLast = TRUE), , drop = FALSE]
  lkey <- paste(last$family, last$fund_cnpj)
  before <- match(paste(lkey, vapply(last$month, shift_month, character(1), -12L)), paste(key, m$month))
  last$change12 <- ifelse(is.na(before), NA_real_, (last$net_assets - m$net_assets[before]) / m$net_assets[before])
  last$change12[!is.finite(last$change12)] <- NA_real_
  # Latest month with a published number of quotaholders (fund characteristics).
  h <- m[!is.na(m$quotaholders), , drop = FALSE]
  h <- h[!duplicated(paste(h$family, h$fund_cnpj), fromLast = TRUE), , drop = FALSE]
  k <- match(lkey, paste(h$family, h$fund_cnpj))
  last$holders_last <- h$quotaholders[k]; last$holders_month <- h$month[k]
  last$rank <- NA_integer_; last$peers <- NA_integer_; last$percentile <- NA_real_
  for (f in unique(last$family)) {
    s <- sort(ctx$snapshot$net_assets[ctx$snapshot$family == f & !is.na(ctx$snapshot$net_assets)])
    i <- which(last$family == f & !is.na(last$net_assets))
    if (!length(s) || !length(i)) next
    le <- findInterval(last$net_assets[i], s)
    last$rank[i] <- length(s) - le + 1L
    last$peers[i] <- length(s)
    last$percentile[i] <- le / length(s)
  }
  last
}

# One line per fund and family, as in the app list.
static_fund_index <- function(data, ctx) {
  l <- fund_list(data$directory, data$master)
  p <- static_fund_profiles(ctx)
  k <- match(paste(l$family, l$fund_cnpj), paste(p$family, p$fund_cnpj))
  e <- data$master$entities
  a <- match(l$administrator_entity, e$entity_id)
  pl <- attach_fund_net_assets(l, ctx$fund_pl)  # same PL and share as the app list
  data.frame(
    family = l$family, entity = l$fund_entity, cnpj = l$cnpj_formatted, key = l$fund_cnpj,
    name = display_name(l$fund_name), names = l$name_count,
    admin = ifelse(is.na(l$administrator_display), NA_character_, l$administrator_display),
    admin_entity = l$administrator_entity,
    admin_cnpj = ifelse(is.na(a), NA_character_, e$cnpj_formatted[a]),
    first = substr(l$first_period, 1, 7), last = substr(l$last_period, 1, 7), count = l$period_count,
    pl = pl$net_assets, pl_month = pl$net_assets_month, share = pl$net_assets_share, change12 = p$change12[k], rank = p$rank[k],
    peers = p$peers[k], percentile = p$percentile[k], quotaholders = p$quotaholders[k],
    investment_entity = if (is.null(data$investment_entity)) NA_character_ else ifelse(
      l$family == "fip", data$investment_entity$investment_entity[match(l$fund_cnpj, data$investment_entity$fund_cnpj)], NA_character_),
    traits = static_fund_traits(data$attributes, l$family, l$fund_cnpj),
    holders_last = p$holders_last[k], holders_month = p$holders_month[k],
    stringsAsFactors = FALSE)
}

# Characteristics of each fund as a JSON array in static_trait_order: each item
# is [value, "YYYY-MM"] (latest report that filled it) or null.
static_trait_order <- fund_attribute_order
static_fund_traits <- function(attributes, family, cnpj) {
  if (is.null(attributes)) return(rep("null", length(family)))
  key <- paste(family, cnpj)
  items <- vapply(static_trait_order, function(a) {
    x <- attributes[attributes$attribute == a, , drop = FALSE]
    k <- match(key, paste(x$family, x$fund_cnpj))
    ifelse(is.na(k), "null", sprintf("[%s,%s]", json_string(x$value[k]), json_string(x$period[k])))
  }, character(length(family)))
  if (!is.matrix(items)) items <- matrix(items, nrow = length(family))
  sprintf("[%s]", apply(items, 1, paste, collapse = ","))
}

static_fund_index_json <- function(index, master, meta) {
  rows <- json_array(json_string(index$family), json_string(index$entity), json_string(index$cnpj),
                     json_string(index$key), json_string(index$name), index$names, json_string(index$admin),
                     json_string(index$admin_entity), json_string(index$admin_cnpj), json_string(index$first),
                     json_string(index$last), index$count, json_number(index$pl), json_string(index$pl_month),
                     json_number(index$change12, 4L), ifelse(is.na(index$rank), "null", index$rank),
                     ifelse(is.na(index$peers), "null", index$peers), json_number(index$percentile, 4L),
                     json_number(index$quotaholders, 0L), json_number(index$share, 6L),
                     json_string(index$investment_entity), index$traits,
                     json_number(index$holders_last, 0L), json_string(index$holders_month))
  # Every denomination of the listed funds (the Denominações tab and the search).
  h <- master$name_history[master$name_history$entity_id %in% index$entity, , drop = FALSE]
  n <- master$entity_names[match(h$name_id, master$entity_names$name_id), ]
  h <- h[order(h$entity_id, h$first_observed_period, h$original_name, method = "radix"), , drop = FALSE]
  n <- master$entity_names[match(h$name_id, master$entity_names$name_id), ]
  names_rows <- json_array(json_string(h$entity_id), json_string(n$display_name), json_string(h$original_name),
                           json_string(h$source), json_string(substr(h$first_observed_period, 1, 7)),
                           json_string(substr(h$last_observed_period, 1, 7)), h$observed_periods,
                           ifelse(n$needs_review, "true", "false"))
  meta_json <- paste0("{", paste(sprintf("%s:%s", json_string(names(meta)), unlist(meta)), collapse = ","), "}")
  paste0("{\"meta\":", meta_json, ",\"funds\":[", paste(rows, collapse = ",\n"),
         "],\"names\":[", paste(names_rows, collapse = ",\n"), "]}")
}

# Labels and CVM columns of the characteristics, per family, for the browser:
# {"order":[...],"labels":{...},"columns":{"fidc":{"condominium":"CONDOM"},...}}, plus
# the medium and short labels, the core fields, the numeric ones, the highlighted
# values and, per attribute, each published value part -> [filter key, display
# text, option text] (fund_attribute_key, fund_attribute_value_text), so the
# browser shows and filters exactly as the app.
static_traits_meta <- function(attributes = NULL) {
  obj <- function(v) paste0("{", paste(sprintf("%s:%s", json_string(names(v)), json_string(unname(v))), collapse = ","), "}")
  values <- vapply(fund_attribute_order, function(a) {
    p <- if (is.null(attributes)) character() else unique(unlist(strsplit(attributes$value[attributes$attribute == a], " / ", fixed = TRUE)))
    if (!length(p)) return("{}")
    key <- fund_attribute_key(p)
    opt <- if (a == "public") fund_public_text(key) else fund_attribute_value_text(a, p)
    opt <- paste0(toupper(substr(opt, 1, 1)), substr(opt, 2, nchar(opt)))
    paste0("{", paste(sprintf("%s:[%s,%s,%s]", json_string(p), json_string(key), json_string(fund_attribute_value_text(a, p)),
                              json_string(opt)), collapse = ","), "}")
  }, character(1))
  extra <- paste0(",\"medium\":", obj(fund_attribute_medium), ",\"short\":", obj(fund_attribute_short),
                  ",\"core\":[", paste(json_string(fund_attribute_core), collapse = ","), "]",
                  ",\"numeric\":[", paste(json_string(fund_attribute_numeric), collapse = ","), "]",
                  ",\"alert\":", obj(fund_attribute_alert_values),
                  ",\"values\":{", paste(sprintf("%s:%s", json_string(fund_attribute_order), values), collapse = ","), "}")
  sp <- fund_attribute_specs[!duplicated(paste(fund_attribute_specs$family, fund_attribute_specs$attribute)), ]
  cols <- vapply(split(sp, sp$family), function(x) paste0("{", paste(sprintf("%s:%s", json_string(x$attribute),
                                                                           json_string(x$column)), collapse = ","), "}"), character(1))
  paste0("{\"order\":[", paste(json_string(static_trait_order), collapse = ","), "],\"labels\":{",
         paste(sprintf("%s:%s", json_string(names(fund_attribute_labels)), json_string(unname(fund_attribute_labels))), collapse = ","),
         "},\"columns\":{", paste(sprintf("%s:%s", json_string(names(cols)), cols), collapse = ","), "}",
         ",\"notes\":{", paste(sprintf("%s:[%s]", json_string(names(fund_field_notes)),
                                        vapply(fund_field_notes, function(n) paste(json_string(n), collapse = ","), "")),
                                collapse = ","), "}", extra, "}")
}

write_static_fund_data <- function(out_dir, data, ctx, generated) {
  dir <- file.path(out_dir, "data")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(dir, c("funds.json", "admins", "series")), recursive = TRUE)
  index <- static_fund_index(data, ctx)
  meta <- list(generated = json_string(generated), rule_version = json_string(data$master$rule_version),
               colors = paste0("{", paste(sprintf("%s:%s", json_string(names(fund_family_colors)),
                                                   json_string(unname(fund_family_colors))), collapse = ","), "}"),
               family_names = paste0("{", paste(sprintf("%s:%s", json_string(names(fund_family_names)),
                                                         json_string(unname(fund_family_names))), collapse = ","), "}"),
               tables = paste0("{", paste(sprintf("%s:%s", json_string(names(fund_table_labels)),
                                                   json_string(unname(fund_table_labels))), collapse = ","), "}"),
               traits = static_traits_meta(data$attributes))
  writeLines(enc2utf8(static_fund_index_json(index, data$master, meta)), file.path(dir, "funds.json"), useBytes = TRUE)
  invisible(list(funds = nrow(index)))
}

# Funds of one administrator per month (the points of its chart), for the
# month picker of the static Administradores tab: data/admins/{i}.json with
# {"months": [...], "funds": [[name, family, CNPJ]], "rows": [[[fund, net
# assets, carried]] per month]}, largest first.
write_static_admin_months <- function(out_dir, ctx, keys, families = unname(admin_families)) {
  dir <- file.path(out_dir, "data", "admins")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  admins <- ctx$admins[ctx$admins$family %in% families, , drop = FALSE]
  akey <- administrator_key(admins$administrator_cnpj, admins$administrator_name)
  files <- character(length(keys))
  for (i in seq_along(keys)) {
    funds <- admins[which(akey == keys[i]), c("family", "fund_cnpj", "fund_name")]
    d <- merge(ctx$m[, c("family", "fund_cnpj", "month", "net_assets", "carried")], funds, by = c("family", "fund_cnpj"))
    d <- d[d$month <= max(unname(ctx$complete)), , drop = FALSE]
    d$fund <- match(paste(d$family, d$fund_cnpj), paste(funds$family, funds$fund_cnpj)) - 1L
    d <- d[order(d$month, -d$net_assets, method = "radix"), , drop = FALSE]
    months <- sort(unique(d$month))
    rows <- vapply(split(d, d$month)[months], function(x) json_array(paste(
      sprintf("[%d,%s,%d]", x$fund, json_number(x$net_assets), as.integer(x$carried)), collapse = ",")), character(1))
    fund_rows <- sprintf("[%s,%s,%s]", json_string(display_name(funds$fund_name)), json_string(funds$family),
                         json_string(format_cnpj(funds$fund_cnpj)))
    files[i] <- file.path("data", "admins", sprintf("%d.json", i))
    writeLines(enc2utf8(paste0("{\"months\":[", paste(json_string(months), collapse = ","), "],\"funds\":[",
                               paste(fund_rows, collapse = ",\n"), "],\"rows\":[", paste(rows, collapse = ",\n"), "]}")),
               file.path(out_dir, files[i]), useBytes = TRUE)
  }
  files
}

# --- Ficha and Série completa -------------------------------------------------
# Main report tables of each family (the ones the local app opens first), in
# data/fichas/. The other FIDC tables go compressed to data/fichas_x/ and are
# read only when chosen (write_static_ficha_extras); the other tables of FII,
# FIP and FIAGRO stay in the local app.
static_ficha_tables <- list(
  fidc = "inf_mensal_fidc_tab_I",
  fii = c("inf_mensal_fii_geral", "inf_mensal_fii_complemento", "inf_mensal_fii_ativo_passivo"),
  fip = c("inf_trimestral_fip", "inf_quadrimestral_fip"),
  fiagro = "inf_mensal_fiagro")
static_ficha_extra_tables <- list(
  fidc = paste0("inf_mensal_fidc_tab_", c("II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                                          "X_1", "X_1_1", "X_2", "X_3", "X_4", "X_5", "X_6", "X_7")))

# One table of one family as JSON objects, one per fund: {"n": table, "c":
# [[period, dataset, file, line, sha12, url index]] (most recent first), "f":
# [[label, code, derived, numeric flags, [values]]]}. Values are already
# formatted with the rules of the app (display_values) and labels come from the
# CVM dictionary (field_labels), so both versions show the same text; empty
# values are "". Fields empty in every row of the fund are left out. Returns
# NULL when the table is missing.
static_ficha_objects <- function(root, fam, tn, urls, descriptions) {
  base <- fund_processed_paths(root)$base
  if (!dir.exists(file.path(base, fam, tn))) return(NULL)
  lineage <- c("citation", "source_url", "zip_sha256", "source_file", "source_line",
               "fund_cnpj_normalized", "reference_period", "layout_version")
  r <- as.data.frame(open_fund_table(root, fam, tn))
  r <- r[!is.na(r$fund_cnpj_normalized), , drop = FALSE]
  period <- row_periods(r)
  o <- order(r$fund_cnpj_normalized, period, r$source_file, r$source_line,
             decreasing = c(FALSE, TRUE, FALSE, FALSE), method = "radix")
  r <- r[o, , drop = FALSE]; period <- period[o]
  shown <- ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", period), substr(period, 1, 7), period)
  url <- match(r$zip_sha256, urls$file_sha256)
  cols <- sprintf("[%s,%s,%s,%s,%s,%s]", json_string(shown), json_string(r$dataset), json_string(r$source_file),
                  ifelse(is.na(r$source_line), "null", r$source_line), json_string(substr(r$zip_sha256, 1L, 12L)),
                  ifelse(is.na(url), "null", url - 1L))
  fields <- c("fund_cnpj_original", setdiff(names(r), c(lineage, fund_report_columns)))
  labels <- field_labels(fields, descriptions, tn)
  filled <- matrix(FALSE, nrow(r), length(fields))
  text <- vector("list", length(fields)); num <- text
  for (k in seq_along(fields)) {
    v <- r[[fields[k]]]
    filled[, k] <- !is.na(v) & nzchar(trimws(v))
    d <- display_values(v, fields[k])
    text[[k]] <- json_string(ifelse(filled[, k], d$text, ""))
    num[[k]] <- ifelse(d$num, "1", "0")
  }
  head <- sprintf("[%s,%s,%d,", json_string(labels$label), json_string(labels$field), as.integer(labels$derived))
  groups <- split(seq_len(nrow(r)), r$fund_cnpj_normalized)
  obj <- vapply(groups, function(i) {
    keep <- which(colSums(filled[i, , drop = FALSE]) > 0)
    f <- vapply(keep, function(k) paste0(head[k], "\"", paste(num[[k]][i], collapse = ""), "\",[",
                                         paste(text[[k]][i], collapse = ","), "]]"), character(1))
    sprintf("{\"n\":%s,\"c\":[%s],\"f\":[%s]}", json_string(tn), paste(cols[i], collapse = ","), paste(f, collapse = ","))
  }, character(1))
  list(cnpj = names(groups), obj = unname(obj), rows = nrow(r), n = unname(lengths(groups)),
       first = vapply(groups, function(i) shown[i[length(i)]], character(1), USE.NAMES = FALSE),
       last = vapply(groups, function(i) shown[i[1L]], character(1), USE.NAMES = FALSE))
}

# One file per fund, data/fichas/{family}/{CNPJ digits}.json, read when the
# fund is opened: {"t": [objects of static_ficha_objects], "r": HTML of the
# monthly return chart (fund_return_ui, the same markup as the app), "j":
# [lines, period] of the joint special-rights notice (fund_joint_rights), when any}.
# data/fichas/urls.json lists the CVM files.
write_static_fichas <- function(out_dir, root, data, tables = static_ficha_tables,
                                returns = if (exists("fund_returns", mode = "function")) fund_returns(root)) {
  dir <- file.path(out_dir, "data", "fichas")
  unlink(dir, recursive = TRUE)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  urls <- data$urls
  parts <- new.env(parent = emptyenv())
  rows_total <- 0L
  for (fam in names(tables)) for (tn in tables[[fam]]) {
    x <- static_ficha_objects(root, fam, tn, urls, data$descriptions)
    if (is.null(x)) next
    rows_total <- rows_total + x$rows
    for (j in seq_along(x$cnpj)) {
      key <- paste(fam, x$cnpj[j], sep = "/")
      assign(key, c(parts[[key]], x$obj[j]), envir = parts)
    }
    rm(x); invisible(gc())
  }
  for (fam in names(tables)) dir.create(file.path(dir, fam), showWarnings = FALSE)
  keys <- ls(parts)
  by_fund <- if (is.null(returns)) NULL else split(returns, paste(returns$family, returns$fund_cnpj, sep = "/"))
  jr <- if (is.null(data$attributes)) NULL else data$attributes[data$attributes$attribute == "joint_rights", , drop = FALSE]
  joint <- if (is.null(jr) || !nrow(jr)) character() else
    stats::setNames(sprintf("[%s,%s]", json_string(jr$value), json_string(jr$period)), paste(jr$family, jr$fund_cnpj, sep = "/"))
  for (key in keys) {
    fam <- sub("/.*$", "", key); cnpj <- sub("^.*/", "", key)
    ret <- if (is.null(returns)) NULL else
      as.character(fund_return_ui(root, fam, cnpj, returns = if (is.null(by_fund[[key]])) returns[0, ] else by_fund[[key]]))
    writeLines(enc2utf8(paste0("{\"t\":[", paste(parts[[key]], collapse = ","), "]",
                               if (!is.null(ret)) paste0(",\"r\":", json_string(ret)),
                               if (!is.na(joint[key])) paste0(",\"j\":", joint[key]), "}")),
               file.path(dir, paste0(key, ".json")), useBytes = TRUE)
  }
  writeLines(enc2utf8(paste0("[", paste(json_string(urls$source_url), collapse = ","), "]")),
             file.path(dir, "urls.json"), useBytes = TRUE)
  invisible(list(funds = length(keys), rows = rows_total))
}

# Other tables of a family, gzip compressed (GitHub Pages limits the site to
# 1 GB): data/fichas_x/{family}/{CNPJ digits}.json.gz holds {"t": [objects of
# static_ficha_objects]} with every extra table of the fund, read only when one
# of them is chosen; data/fichas_x/{family}/index.json.gz lists them per fund:
# {"tables": [names], "funds": {"CNPJ": [[table index, first period, last
# period, rows]]}}. One table is read at a time and each fund's objects are
# appended to a temporary file, so memory stays at one table. Both files use
# the same urls.json as data/fichas/.
write_static_ficha_extras <- function(out_dir, root, data, tables = static_ficha_extra_tables) {
  dir <- file.path(out_dir, "data", "fichas_x")
  unlink(dir, recursive = TRUE)
  tmp <- tempfile("fichas_x"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  funds <- 0L; rows_total <- 0L
  for (fam in names(tables)) {
    dir.create(file.path(dir, fam), recursive = TRUE, showWarnings = FALSE)
    index <- new.env(parent = emptyenv())
    for (ti in seq_along(tables[[fam]])) {
      x <- static_ficha_objects(root, fam, tables[[fam]][ti], data$urls, data$descriptions)
      if (is.null(x)) next
      rows_total <- rows_total + x$rows
      for (j in seq_along(x$cnpj)) {
        cnpj <- x$cnpj[j]
        first <- is.null(index[[cnpj]])
        cat(if (first) "" else ",\n", x$obj[j], file = file.path(tmp, paste0(cnpj, ".part")), sep = "", append = !first)
        assign(cnpj, c(index[[cnpj]], sprintf("[%d,%s,%s,%d]", ti - 1L, json_string(x$first[j]),
                                              json_string(x$last[j]), x$n[j])), envir = index)
      }
      rm(x); invisible(gc())
    }
    keys <- sort(ls(index))
    for (cnpj in keys) {
      part <- file.path(tmp, paste0(cnpj, ".part"))
      body <- readLines(part, warn = FALSE, encoding = "UTF-8")
      con <- gzfile(file.path(dir, fam, paste0(cnpj, ".json.gz")), "wb", compression = 9)
      writeLines(enc2utf8(paste0("{\"t\":[", paste(body, collapse = "\n"), "]}")), con, useBytes = TRUE)
      close(con)
      unlink(part)
    }
    con <- gzfile(file.path(dir, fam, "index.json.gz"), "wb", compression = 9)
    writeLines(enc2utf8(paste0("{\"tables\":[", paste(json_string(tables[[fam]]), collapse = ","), "],\"funds\":{",
                               paste(sprintf("%s:[%s]", json_string(keys),
                                             vapply(keys, function(k) paste(index[[k]], collapse = ","), character(1))),
                                     collapse = ","), "}}")), con, useBytes = TRUE)
    close(con)
    funds <- funds + length(keys)
  }
  invisible(list(funds = funds, rows = rows_total))
}

static_peer_tables <- function() {
  stats::setNames(lapply(names(static_ficha_tables), function(f) c(static_ficha_tables[[f]], static_ficha_extra_tables[[f]])),
                  names(static_ficha_tables))
}

# Funds of the same family at each competência, for the tab Distribuições
# (fund_peer_summaries): data/peers/{family}/{table}/{period}.json.gz, one file
# per table and period as shown in the Ficha (YYYY-MM for dates), read only
# when that period is chosen: {"funds": funds with rows, "f": {field: [n, mean,
# sd, lo, hi, outside, [counts], [101 percentiles], display scale (null =
# linear, else c of asinh(v / c)), display mean, display sd, robust scale (scaled
# MAD of the display values, fund_peer_robust_scale), funds left out for an
# invalid ratio denominator]}}; lo, hi and the counts are on the display scale.
# Fields "r:<field>" and "a:<field>/<den>" are the relative metrics (mode
# Relativo; rules in window.TM_RATIOS). Same tables as the Ficha; numbers with 7
# significant digits.
static_peer_number <- function(x) {
  out <- sprintf("%.7g", x)
  out[!is.finite(x)] <- "null"
  out
}

static_peer_json <- function(s) {
  sprintf("[%d,%s,%s,%s,%s,%d,[%s],[%s],%s,%s,%s,%s,%d]", s$n, static_peer_number(s$mean), static_peer_number(s$sd),
          static_peer_number(s$lo), static_peer_number(s$hi), s$outside, paste(s$counts, collapse = ","),
          paste(static_peer_number(s$q), collapse = ","), static_peer_number(s$scale),
          static_peer_number(s$dmean), static_peer_number(s$dsd), static_peer_number(s$rs),
          if (is.null(s$excluded)) 0L else as.integer(s$excluded))
}

# Fund values per competência of some fields: field -> median of the rows of each
# fund, named "<shown period>\r<fund>" (the key shared by every table of a family).
static_keyed_values <- function(r, shown, fields) {
  out <- list()
  for (fld in intersect(fields, names(r))) {
    num <- fund_numeric_values(r[[fld]], fld)
    ok <- !is.na(num)
    if (any(ok)) out[[fld]] <- fund_median_by(num[ok], paste(shown[ok], r$fund_cnpj_normalized[ok], sep = "\r"))
  }
  out
}

static_shown_period <- function(r) {
  period <- row_periods(r)
  ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", period), substr(period, 1, 7), period)
}

# Ratio entries (mode Relativo, src/intelligence/fund_ratios.R) of one numerator
# field: summaries by shown period, keyed "r:<field>" / "a:<field>/<den>".
static_ratio_entries <- function(plan, tn, fld, med, den_vals) {
  rows <- plan[plan$field == fld, , drop = FALSE]
  if (!nrow(rows)) return(list())
  vals <- den_vals
  vals[[tn]][[fld]] <- med
  rv <- fund_ratio_values(rows, tn, vals)
  out <- list()
  for (k in names(rv$values)) {
    v <- rv$values[[k]]
    lost <- setdiff(names(med), names(v))
    lost_by <- table(sub("\r.*$", "", lost))
    by_period <- split(unname(v), sub("\r.*$", "", names(v)))
    linear <- fund_ratio_linear(rows$kind[rows$key == k][1])
    for (p in names(by_period)) {
      s <- fund_peer_summary(by_period[[p]], linear = linear)
      if (is.null(s)) next
      s$excluded <- if (p %in% names(lost_by)) lost_by[[p]] else 0L
      out[[p]] <- c(out[[p]], paste0(json_string(k), ":", static_peer_json(s)))
    }
  }
  out
}

write_static_peers <- function(out_dir, root, tables = static_peer_tables(),
                               rules = if (exists("fund_ratio_rules")) fund_ratio_rules() else NULL) {
  dir <- file.path(out_dir, "data", "peers")
  unlink(dir, recursive = TRUE)
  base <- fund_processed_paths(root)$base
  files <- 0L
  for (fam in names(tables)) {
   den_cache <- list()  # denominator fields of other tables, read once per family
   for (tn in tables[[fam]]) {
    if (!dir.exists(file.path(base, fam, tn))) next
    r <- as.data.frame(open_fund_table(root, fam, tn))
    r <- fund_peer_split(r[!is.na(r$fund_cnpj_normalized), , drop = FALSE])  # X.4 by operation type
    shown <- static_shown_period(r)
    funds <- tapply(r$fund_cnpj_normalized, shown, function(v) length(unique(v)))
    fields <- fund_distribution_fields(names(r))
    plan <- if (exists("fund_ratio_plan")) fund_ratio_plan(rules, tn, fields) else NULL
    den_vals <- list()
    if (!is.null(plan) && nrow(plan)) for (dt in unique(plan$den_table)) {
      cols <- if (dt == tn) names(r) else if (dir.exists(file.path(base, fam, dt))) names(open_fund_table(root, fam, dt)) else character()
      need <- unique(unlist(lapply(plan$den[plan$den_table == dt], function(d)
        unlist(lapply(fund_ratio_terms(d), function(t) fund_ratio_term_fields(t, cols))))))
      if (dt == tn) { den_vals[[dt]] <- static_keyed_values(r, shown, need); next }
      miss <- setdiff(need, names(den_cache[[dt]]))
      if (length(miss) && length(cols)) {
        d <- as.data.frame(open_fund_table(root, fam, dt))
        d <- d[!is.na(d$fund_cnpj_normalized), , drop = FALSE]
        den_cache[[dt]] <- c(den_cache[[dt]], static_keyed_values(d, static_shown_period(d), miss))
        rm(d)
      }
      den_vals[[dt]] <- den_cache[[dt]][intersect(need, names(den_cache[[dt]]))]
    }
    out <- list()
    for (fld in fields) {
      num <- fund_numeric_values(r[[fld]], fld)
      ok <- !is.na(num)
      if (!any(ok)) next
      med <- fund_median_by(num[ok], paste(shown[ok], r$fund_cnpj_normalized[ok], sep = "\r"))
      by_period <- split(unname(med), sub("\r.*$", "", names(med)))
      for (p in names(by_period)) {
        s <- fund_peer_summary(by_period[[p]])
        if (!is.null(s)) out[[p]] <- c(out[[p]], paste0(json_string(fld), ":", static_peer_json(s)))
      }
      if (!is.null(plan) && nrow(plan)) {
        ratio <- static_ratio_entries(plan, tn, fld, med, den_vals)
        for (p in names(ratio)) out[[p]] <- c(out[[p]], ratio[[p]])
      }
    }
    if (!length(out)) next
    dir.create(file.path(dir, fam, tn), recursive = TRUE, showWarnings = FALSE)
    for (p in names(out)) {
      con <- gzfile(file.path(dir, fam, tn, paste0(p, ".json.gz")), "wb", compression = 9)
      writeLines(enc2utf8(sprintf("{\"funds\":%d,\"f\":{%s}}", funds[[p]], paste(out[[p]], collapse = ","))), con, useBytes = TRUE)
      close(con)
      files <- files + 1L
    }
    rm(r); invisible(gc())
   }
   rm(den_cache); invisible(gc())
  }
  invisible(list(files = files))
}

# FICHA tab: any fund's Ficha and Série completa (RecordTab in taxminer_static.js).
static_record_ui <- function() {
  page <- shiny::div(class = "tm-page tm-fill-page tm-static-record", shiny::div(class = "tm-empty", "Carregando fundos…"))
  htmltools::bindFillRole(page, container = TRUE, item = TRUE)
}

# Tab body: filled in the browser by taxminer_static.js.
static_funds_ui <- function(family = NULL) {
  page <- shiny::div(class = "tm-page tm-fill-page tm-static-funds", `data-family` = if (is.null(family)) "" else family,
                     shiny::div(class = "tm-empty", "Carregando fundos…"))
  htmltools::bindFillRole(page, container = TRUE, item = TRUE)
}
