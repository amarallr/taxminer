# Fund tabs of the published (static) dashboard: data files for the browser
# (prototype/static/taxminer_static.js renders them). Same sources as the app:
# fund list and denominations from the entity catalog
# (src/data/entity_resolution.R), profile figures from the derived metrics.
# Raw report rows (Ficha, Série completa) stay in the local app. JSON writers
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
    stringsAsFactors = FALSE)
}

static_fund_index_json <- function(index, master, meta) {
  rows <- json_array(json_string(index$family), json_string(index$entity), json_string(index$cnpj),
                     json_string(index$key), json_string(index$name), index$names, json_string(index$admin),
                     json_string(index$admin_entity), json_string(index$admin_cnpj), json_string(index$first),
                     json_string(index$last), index$count, json_number(index$pl), json_string(index$pl_month),
                     json_number(index$change12, 4L), ifelse(is.na(index$rank), "null", index$rank),
                     ifelse(is.na(index$peers), "null", index$peers), json_number(index$percentile, 4L),
                     json_number(index$quotaholders, 0L), json_number(index$share, 6L))
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
                                                         json_string(unname(fund_family_names))), collapse = ","), "}"))
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

# Tab body: filled in the browser by taxminer_static.js.
static_funds_ui <- function(family = NULL) {
  page <- shiny::div(class = "tm-page tm-fill-page tm-static-funds", `data-family` = if (is.null(family)) "" else family,
                     shiny::div(class = "tm-empty", "Carregando fundos…"))
  htmltools::bindFillRole(page, container = TRUE, item = TRUE)
}
