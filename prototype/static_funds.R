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
    stringsAsFactors = FALSE)
}

static_fund_index_json <- function(index, master, meta) {
  rows <- json_array(json_string(index$family), json_string(index$entity), json_string(index$cnpj),
                     json_string(index$key), json_string(index$name), index$names, json_string(index$admin),
                     json_string(index$admin_entity), json_string(index$admin_cnpj), json_string(index$first),
                     json_string(index$last), index$count, json_number(index$pl), json_string(index$pl_month),
                     json_number(index$change12, 4L), ifelse(is.na(index$rank), "null", index$rank),
                     ifelse(is.na(index$peers), "null", index$peers), json_number(index$percentile, 4L),
                     json_number(index$quotaholders, 0L), json_number(index$share, 6L),
                     json_string(index$investment_entity))
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
                                                   json_string(unname(fund_table_labels))), collapse = ","), "}"))
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
# fund is opened: {"t": [objects of static_ficha_objects]}.
# data/fichas/urls.json lists the CVM files.
write_static_fichas <- function(out_dir, root, data, tables = static_ficha_tables) {
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
  for (key in keys) {
    writeLines(enc2utf8(paste0("{\"t\":[", paste(parts[[key]], collapse = ","), "]}")),
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
