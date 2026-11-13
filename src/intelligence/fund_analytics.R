# Phase 1.3 analytics over the derived fund metrics (deterministic, no LLM).
# Rules, stated once:
# - Periods after `today` are excluded (and counted): they cannot be reports yet.
# - The latest month of a family is often incomplete while reports are still
#   being filed. A month is complete when its reporting funds reach
#   `complete_share` of the median of the previous six reported months.
# - Family figures use the family's own reports. Market totals count each
#   CNPJ once per month (a few funds report under two families).
# - Changes compare a month with the same month one year earlier.
# Requires src/intelligence/search_fund_reports.R (normalize_search_text) and
# src/data/entity_resolution.R (entity_key; names from the entity catalog).

fund_family_order <- c("fii", "fidc", "fip", "fiagro")

prepare_metrics <- function(metrics, today = Sys.Date()) {
  future <- !is.na(metrics$period) & metrics$period > format(today, "%Y-%m-%d")
  m <- metrics[!future, , drop = FALSE]
  m$month <- substr(m$period, 1, 7)
  m$carried <- rep(FALSE, nrow(m))
  m <- rbind(m, carry_forward(m))
  structure(m, future_rows = sum(future))
}

# FIP reports every three or four months, so a plain monthly sum alternates
# between months with and without reports. A balance holds until the next
# report: each FIP report is repeated (carried = TRUE, same period and
# citation) in the following months until the fund's next report, at most
# `max_months` ahead and never past the family's latest reported month.
carry_forward <- function(m, families = "fip", max_months = 3L) {
  f <- m[m$family %in% families & !m$carried, , drop = FALSE]
  if (nrow(f) == 0L) return(m[0, , drop = FALSE])
  f <- f[order(f$family, f$fund_cnpj, f$month, method = "radix"), , drop = FALSE]
  n <- nrow(f)
  same_fund <- c(f$family[-1] == f$family[-n] & f$fund_cnpj[-1] == f$fund_cnpj[-n], FALSE)
  next_month <- ifelse(same_fund, c(f$month[-1], NA), NA)
  last_month <- tapply(f$month, f$family, max)[f$family]
  out <- lapply(seq_len(max_months), function(k) {
    target <- shift_month(f$month, k)
    keep <- target <= last_month & (is.na(next_month) | target < next_month)
    rows <- f[keep, , drop = FALSE]
    rows$month <- target[keep]
    rows$carried <- rep(TRUE, nrow(rows))
    rows
  })
  do.call(rbind, out)
}

family_monthly <- function(m) {
  if (nrow(m) == 0L) {
    return(data.frame(family = character(), month = character(), net_assets = numeric(),
                      funds = integer(), quotaholders = numeric()))
  }
  key <- paste(m$family, m$month)
  out <- data.frame(
    family = tapply(m$family, key, `[`, 1), month = tapply(m$month, key, `[`, 1),
    net_assets = tapply(m$net_assets, key, sum, na.rm = TRUE),
    funds = as.integer(tapply(m$fund_cnpj, key, function(x) length(unique(x)))),
    quotaholders = tapply(m$quotaholders, key, function(v) if (all(is.na(v))) NA_real_ else sum(v, na.rm = TRUE)),
    stringsAsFactors = FALSE)
  out <- out[order(match(out$family, fund_family_order), out$month), ]
  rownames(out) <- NULL
  out
}

# Last complete month of each family (see header).
complete_months <- function(series, complete_share = 0.9) {
  sapply(split(series, series$family), function(d) {
    d <- d[order(d$month), ]
    for (i in rev(seq_len(nrow(d)))) {
      previous <- d$funds[max(1, i - 6):max(1, i - 1)]
      if (i == 1 || d$funds[i] >= complete_share * stats::median(previous)) return(d$month[i])
    }
    d$month[nrow(d)]
  })
}

shift_month <- function(month, by) {
  d <- as.Date(paste0(month, "-01"))
  y <- as.integer(format(d, "%Y")); mo <- as.integer(format(d, "%m")) + by
  y <- y + (mo - 1) %/% 12; mo <- (mo - 1) %% 12 + 1
  sprintf("%04d-%02d", y, mo)
}

pct_change <- function(now, before) ifelse(is.na(before) | before == 0, NA_real_, now / before - 1)

# Headline figures per family at its last complete month, with the change
# against the same month one year earlier.
family_overview <- function(series, complete = complete_months(series)) {
  rows <- lapply(fund_family_order[fund_family_order %in% names(complete)], function(f) {
    d <- series[series$family == f, ]
    now <- d[d$month == complete[[f]], ]
    before <- d[d$month == shift_month(complete[[f]], -12), ]
    data.frame(family = f, month = now$month, net_assets = now$net_assets, funds = now$funds,
               quotaholders = now$quotaholders,
               net_assets_change = if (nrow(before)) pct_change(now$net_assets, before$net_assets) else NA_real_,
               funds_change = if (nrow(before)) now$funds - before$funds else NA_integer_,
               latest_month = max(d$month), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# Each family's rows at its complete month; one row per CNPJ across families.
market_snapshot <- function(m, complete) {
  keep <- m$month == unname(complete[m$family])
  s <- m[!is.na(keep) & keep, , drop = FALSE]
  s <- s[order(match(s$family, fund_family_order)), , drop = FALSE]
  s[!duplicated(s$fund_cnpj), , drop = FALSE]
}

# Market change over 12 months: each family's complete month against the same
# month one year earlier, both counted with the snapshot rules.
market_change <- function(m, complete) {
  before <- stats::setNames(shift_month(unname(complete), -12), names(complete))
  pct_change(sum(market_snapshot(m, complete)$net_assets, na.rm = TRUE),
             sum(market_snapshot(m, before)$net_assets, na.rm = TRUE))
}

# Funds of the snapshot with their name and administrator, largest first.
snapshot_funds <- function(snapshot, admins, families = fund_family_order, administrator = NULL) {
  s <- merge(snapshot[snapshot$family %in% families, c("family", "fund_cnpj", "period", "net_assets", "quotaholders")],
             admins, by = c("family", "fund_cnpj"), all.x = TRUE)
  s$key <- administrator_key(s$administrator_cnpj, s$administrator_name)
  if (!is.null(administrator)) s <- s[which(s$key == administrator), , drop = FALSE]
  s <- s[order(s$net_assets, decreasing = TRUE, na.last = TRUE), , drop = FALSE]
  rownames(s) <- NULL
  s
}

# Latest administrator per fund from the search directory. Some FIAGRO
# reports carry the fund (class) name in the administrator name field while
# the administrator CNPJ is right: such names are dropped (`name_is_fund`)
# and the label comes from the other reports of that CNPJ.
fund_administrators <- function(directory, master = NULL) {
  d <- directory[order(directory$last_period, decreasing = TRUE, method = "radix"), ]
  d <- d[!duplicated(paste(d$family, d$fund_cnpj)), c("family", "fund_cnpj", "fund_name",
                                                         "administrator_name", "administrator_cnpj")]
  d$name_is_fund <- !is.na(d$administrator_name) &
    normalize_search_text(d$administrator_name) == normalize_search_text(d$fund_name)
  d$administrator_name[d$name_is_fund] <- NA_character_
  key <- administrator_key(d$administrator_cnpj, d$administrator_name)
  labels <- tapply(d$administrator_name, key, function(v) {
    v <- stats::na.omit(v)
    if (length(v)) names(sort(table(v), decreasing = TRUE))[1] else NA_character_
  })
  fill <- is.na(d$administrator_name) & !is.na(d$administrator_cnpj)
  d$administrator_name[fill] <- labels[key[fill]]
  d$administrator_name[fill & is.na(d$administrator_name)] <-
    paste("CNPJ", d$administrator_cnpj[fill & is.na(d$administrator_name)])
  # With the entity catalog, both names are the current denomination of the
  # entity (its CNPJ), the same in every area of the app.
  if (!is.null(master)) {
    e <- master$entities
    a <- match(key, e$entity_id)
    d$administrator_name <- ifelse(is.na(a), d$administrator_name, e$display_name[a])
    f <- match(entity_key("fund", d$fund_cnpj, d$fund_name), e$entity_id)
    d$fund_name <- ifelse(is.na(f), d$fund_name, e$display_name[f])
  }
  rownames(d) <- NULL
  d
}

# Administrator identity: the central entity key (src/data/entity_resolution.R).
administrator_key <- function(cnpj, name) entity_key("administrator", cnpj, name)

# Herfindahl-Hirschman index on shares in percent (0-10,000).
hhi <- function(values) {
  s <- values[!is.na(values) & values > 0]
  if (!length(s)) return(NA_real_)
  sum((100 * s / sum(s))^2)
}

hhi_label <- function(x) {
  if (is.na(x)) return("sem dados")
  if (x < 1500) "baixa concentração" else if (x <= 2500) "concentração moderada" else "alta concentração"
}

# Administrators ranked by net assets of the funds they administer in the
# snapshot. FIP does not publish its administrator and is left out.
administrator_ranking <- function(snapshot, admins, families = c("fii", "fidc", "fiagro")) {
  s <- merge(snapshot[snapshot$family %in% families, c("family", "fund_cnpj", "net_assets")],
             admins[, c("family", "fund_cnpj", "administrator_name", "administrator_cnpj")],
             by = c("family", "fund_cnpj"), all.x = TRUE)
  s$administrator_name[is.na(s$administrator_name)] <- "(não informado)"
  total <- sum(s$net_assets, na.rm = TRUE)
  # Group by the administrator CNPJ (names are spelled differently across
  # reports); the name is only a fallback key when the CNPJ is missing.
  key <- administrator_key(s$administrator_cnpj, s$administrator_name)
  out <- data.frame(
    administrator_name = tapply(s$administrator_name, key, function(v) names(sort(table(v), decreasing = TRUE))[1]),
    administrator_cnpj = tapply(s$administrator_cnpj, key, function(v) stats::na.omit(v)[1]),
    net_assets = tapply(s$net_assets, key, sum, na.rm = TRUE),
    funds = as.integer(tapply(s$fund_cnpj, key, length)),
    families = tapply(s$family, key, function(v) paste(toupper(fund_family_order[fund_family_order %in% v]),
                                                       collapse = " · ")),
    stringsAsFactors = FALSE)
  out$key <- rownames(out)
  out$share <- out$net_assets / total
  out <- out[order(out$net_assets, decreasing = TRUE), ]
  out$rank <- seq_len(nrow(out))
  out$cumulative_share <- cumsum(out$share)
  rownames(out) <- NULL
  structure(out, hhi = hhi(out$net_assets), total = total)
}

# One fund: its series, latest values, 12-month change and position among
# the funds of its family in the snapshot.
fund_profile <- function(m, snapshot, family, cnpj) {
  d <- m[m$family == family & m$fund_cnpj == cnpj & !m$carried, , drop = FALSE]
  d <- d[order(d$period), , drop = FALSE]
  if (nrow(d) == 0L) return(NULL)
  last <- d[nrow(d), ]
  before <- d[d$month == shift_month(last$month, -12), ]
  peers <- snapshot$net_assets[snapshot$family == family & !is.na(snapshot$net_assets)]
  percentile <- if (length(peers) && !is.na(last$net_assets)) mean(peers <= last$net_assets) else NA_real_
  rank <- if (length(peers) && !is.na(last$net_assets)) sum(peers > last$net_assets) + 1L else NA_integer_
  list(series = d, last = last,
       net_assets_change = if (nrow(before)) pct_change(last$net_assets, before$net_assets[1]) else NA_real_,
       percentile = percentile, rank = rank, peers = length(peers))
}

# Total net assets per month of one administrator's funds (complete months).
# `administrator` is a key from administrator_key().
administrator_series <- function(m, admins, administrator, complete) {
  funds <- admins[administrator_key(admins$administrator_cnpj, admins$administrator_name) == administrator, ]
  d <- merge(m, funds[, c("family", "fund_cnpj")], by = c("family", "fund_cnpj"))
  d <- d[d$month <= max(unname(complete)), , drop = FALSE]
  if (nrow(d) == 0L) return(data.frame(month = character(), net_assets = numeric(), funds = integer()))
  out <- data.frame(month = sort(unique(d$month)))
  out$net_assets <- as.numeric(tapply(d$net_assets, d$month, sum, na.rm = TRUE)[out$month])
  out$funds <- as.integer(tapply(d$fund_cnpj, d$month, length)[out$month])
  out
}

# Net assets (PL) of every fund for the fund lists, with its share of the
# family total. Funds in the snapshot (each family at its last complete month,
# as in the Panorama) take that month's value and share; the others (ended, or
# only in a month still being delivered) take their latest report and no
# share. Never a sum across months.
fund_net_assets <- function(m, snapshot) {
  last <- m[!m$carried & !is.na(m$net_assets), c("family", "fund_cnpj", "month", "net_assets")]
  last <- last[order(last$family, last$fund_cnpj, last$month, method = "radix"), , drop = FALSE]
  last <- last[!duplicated(paste(last$family, last$fund_cnpj), fromLast = TRUE), , drop = FALSE]
  s <- snapshot[!is.na(snapshot$net_assets), c("family", "fund_cnpj", "month", "net_assets")]
  totals <- tapply(s$net_assets, s$family, sum)
  s$share <- s$net_assets / as.numeric(totals[s$family])
  out <- merge(last, s, by = c("family", "fund_cnpj"), all.x = TRUE, suffixes = c("_last", "_ref"))
  ref <- !is.na(out$net_assets_ref)
  data.frame(family = out$family, fund_cnpj = out$fund_cnpj,
             net_assets = ifelse(ref, out$net_assets_ref, out$net_assets_last),
             net_assets_month = ifelse(ref, out$month_ref, out$month_last),
             net_assets_share = ifelse(ref, out$share, NA_real_),
             in_reference = ref, stringsAsFactors = FALSE)
}

# Adds the PL columns of fund_net_assets() to fund list rows.
attach_fund_net_assets <- function(rows, pl) {
  k <- match(paste(rows$family, rows$fund_cnpj), paste(pl$family, pl$fund_cnpj))
  rows$net_assets <- pl$net_assets[k]
  rows$net_assets_month <- pl$net_assets_month[k]
  rows$net_assets_share <- pl$net_assets_share[k]
  rows
}

# Number of quotaholders of each fund in the latest month that published it
# (reported months only): family, fund_cnpj, quotaholders, month.
fund_latest_quotaholders <- function(m) {
  h <- m[!m$carried & !is.na(m$quotaholders), c("family", "fund_cnpj", "month", "quotaholders"), drop = FALSE]
  h <- h[order(h$family, h$fund_cnpj, h$month, method = "radix"), , drop = FALSE]
  h <- h[!duplicated(paste(h$family, h$fund_cnpj), fromLast = TRUE), , drop = FALSE]
  rownames(h) <- NULL
  h
}

# Adds quotaholders and quotaholders_month to fund list rows.
attach_fund_quotaholders <- function(rows, holders) {
  k <- match(paste(rows$family, rows$fund_cnpj), paste(holders$family, holders$fund_cnpj))
  rows$quotaholders <- holders$quotaholders[k]
  rows$quotaholders_month <- holders$month[k]
  rows
}

# Funds behind one point of administrator_series(): the administrator's
# current funds with their net assets in `month` (largest first). `carried`
# marks a value repeated from the fund's last report (FIP, quarterly).
administrator_month_funds <- function(m, admins, administrator, month) {
  funds <- admins[administrator_key(admins$administrator_cnpj, admins$administrator_name) == administrator,
                  c("family", "fund_cnpj", "fund_name")]
  d <- m[m$month == month, c("family", "fund_cnpj", "month", "net_assets", "carried")]
  d <- merge(d, funds, by = c("family", "fund_cnpj"))
  d <- d[order(d$net_assets, decreasing = TRUE, na.last = TRUE), , drop = FALSE]
  rownames(d) <- NULL
  d
}

# Index for the Administradores area, built once per context: the
# administrator key of every metrics row and the snapshot already joined to
# the administrators. The admin_* queries below then only subset (no merge
# per click); they return the same rows as snapshot_funds(),
# administrator_series() and administrator_month_funds().
admin_index <- function(m, snapshot, admins) {
  fund <- paste(admins$family, admins$fund_cnpj)
  key <- administrator_key(admins$administrator_cnpj, admins$administrator_name)
  list(m_key = key[match(paste(m$family, m$fund_cnpj), fund)], fund = fund,
       snapshot = snapshot_funds(snapshot, admins))
}

admin_snapshot_funds <- function(idx, families, administrator) {
  s <- idx$snapshot[idx$snapshot$family %in% families & idx$snapshot$key %in% administrator, , drop = FALSE]
  rownames(s) <- NULL
  s
}

admin_series <- function(m, idx, families, administrator, complete) {
  sel <- which(idx$m_key %in% administrator & m$family %in% families & m$month <= max(unname(complete)))
  if (!length(sel)) return(data.frame(month = character(), net_assets = numeric(), funds = integer()))
  d <- m[sel, c("month", "net_assets", "fund_cnpj"), drop = FALSE]
  out <- data.frame(month = sort(unique(d$month)))
  out$net_assets <- as.numeric(tapply(d$net_assets, d$month, sum, na.rm = TRUE)[out$month])
  out$funds <- as.integer(tapply(d$fund_cnpj, d$month, length)[out$month])
  out
}

admin_month_funds <- function(m, idx, admins, families, administrator, month) {
  sel <- which(m$month == month & idx$m_key %in% administrator & m$family %in% families)
  d <- m[sel, c("family", "fund_cnpj", "month", "net_assets", "carried"), drop = FALSE]
  d$fund_name <- admins$fund_name[match(paste(d$family, d$fund_cnpj), idx$fund)]
  # Same order as the merge-based version: by fund, then largest first.
  d <- d[order(d$family, d$fund_cnpj, method = "radix"), , drop = FALSE]
  d <- d[order(d$net_assets, decreasing = TRUE, na.last = TRUE), , drop = FALSE]
  rownames(d) <- NULL
  d
}

# Values in reais, abbreviated the way Brazilian reports write them.
format_brl <- function(x, digits = 1) {
  vapply(x, function(v) {
    if (is.na(v)) return("—")
    a <- abs(v)
    unit <- if (a >= 1e12) c(1e12, "tri") else if (a >= 1e9) c(1e9, "bi") else if (a >= 1e6) c(1e6, "mi")
            else if (a >= 1e3) c(1e3, "mil") else c(1, "")
    n <- formatC(v / as.numeric(unit[1]), format = "f", digits = if (unit[2] == "") 0 else digits,
                 big.mark = ".", decimal.mark = ",")
    trimws(paste("R$", n, unit[2]))
  }, character(1))
}

format_pct <- function(x, digits = 1, sign = TRUE) {
  vapply(x, function(v) {
    if (is.na(v)) return("—")
    s <- formatC(100 * v, format = "f", digits = digits, decimal.mark = ",")
    paste0(if (sign && v > 0) "+" else "", s, "%")
  }, character(1))
}

format_int <- function(x) ifelse(is.na(x), "—", formatC(x, format = "d", big.mark = ".", decimal.mark = ","))

month_label <- function(month) {
  names <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
  paste0(names[as.integer(substr(month, 6, 7))], "/", substr(month, 1, 4))
}

# Share of a total with two decimals; a positive share below 0,01% is shown as
# "< 0,01%" (never a misleading zero).
format_share <- function(x) {
  ifelse(is.na(x), "—", ifelse(x > 0 & x < 0.00005, "< 0,01%", format_pct(x, digits = 2, sign = FALSE)))
}

# Monthly return of each fund, in percent, as published by the CVM reports:
# FIDC TAB_X_VL_RENTAB_MES (percent, one line per class/series of quotas),
# FII Percentual_Rentabilidade_Efetiva_Mes (a fraction: x 100) and FIAGRO
# Rentabilidade_Efetiva_Mes (percent). FIP reports have no return field.
fund_return_sources <- list(
  fidc = list(table = "inf_mensal_fidc_tab_X_3", column = "TAB_X_VL_RENTAB_MES", scale = 1,
              class = "TAB_X_CLASSE_SERIE"),
  fii = list(table = "inf_mensal_fii_complemento", column = "Percentual_Rentabilidade_Efetiva_Mes", scale = 100),
  fiagro = list(table = "inf_mensal_fiagro", column = "Rentabilidade_Efetiva_Mes", scale = 1))

# Published numbers, including scientific notation ("1.5E-4"); anything else is NA.
parse_return_number <- function(x) {
  x <- trimws(x)
  ok <- !is.na(x) & grepl("^-?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$", x)
  out <- rep(NA_real_, length(x))
  out[ok] <- as.numeric(x[ok])
  out
}

# family, fund_cnpj, month, class, value (percent): one value per fund and
# month (latest version of the report). For FIDC, the class/series with the
# most months is kept (named in `class`); the others are not mixed in.
fund_returns <- function(root, sources = fund_return_sources, family = NULL, cnpj = NULL) {
  fams <- if (is.null(family)) names(sources) else intersect(family, names(sources))
  parts <- lapply(fams, function(family) {
    s <- sources[[family]]
    rows <- read_return_rows(root, family, s$table, c(s$column, s$class), cnpj)
    if (is.null(rows)) return(NULL)
    class <- if (is.null(s$class)) rep("", nrow(rows)) else ifelse(is.na(rows[[s$class]]), "", trimws(rows[[s$class]]))
    rows$class <- class
    rows <- latest_version(rows, paste(rows$fund_cnpj, rows$period, rows$class, sep = "\r"))
    v <- parse_return_number(rows[[s$column]]) * s$scale
    out <- data.frame(family = family, fund_cnpj = rows$fund_cnpj, month = substr(rows$period, 1, 7),
                      class = rows$class, value = v, stringsAsFactors = FALSE)
    out <- out[!is.na(out$value), , drop = FALSE]
    if (!is.null(s$class) && nrow(out)) {
      n <- table(paste(out$fund_cnpj, out$class, sep = "\r"))
      best <- data.frame(key = names(n), n = as.integer(n), stringsAsFactors = FALSE)
      best$fund <- sub("\r.*$", "", best$key)
      best <- best[order(best$fund, -best$n, best$key, method = "radix"), , drop = FALSE]
      best <- best[!duplicated(best$fund), , drop = FALSE]
      out <- out[paste(out$fund_cnpj, out$class, sep = "\r") %in% best$key, , drop = FALSE]
    }
    out
  })
  out <- do.call(rbind, parts)
  if (is.null(out)) out <- data.frame(family = character(), fund_cnpj = character(), month = character(),
                                      class = character(), value = numeric(), stringsAsFactors = FALSE)
  out <- out[order(out$family, out$fund_cnpj, out$month, method = "radix"), , drop = FALSE]
  rownames(out) <- NULL
  out
}

fund_return_min_months <- 6L

# Rows of one return table (read_metric_rows columns), optionally of one fund only
# (filtered in the Parquet scan, so the app reads a few rows per click).
read_return_rows <- function(root, family, table, columns, cnpj = NULL) {
  dir <- file.path(fund_processed_paths(root)$base, family, table)
  if (!dir.exists(dir)) return(NULL)
  ds <- arrow::open_dataset(dir, format = "parquet", unify_schemas = TRUE)
  wanted <- c("fund_cnpj_normalized", "fund_cnpj_original", fund_period_columns, fund_version_columns,
              columns, "zip_sha256", "source_file", "source_line")
  scan <- ds$NewScan()
  scan$Project(intersect(wanted, ds$schema$names))
  if (!is.null(cnpj)) scan$Filter(arrow::Expression$field_ref("fund_cnpj_normalized") == arrow::Expression$scalar(cnpj))
  df <- as.data.frame(scan$Finish()$ToTable())
  if (nrow(df) == 0L) return(NULL)
  for (column in setdiff(columns, names(df))) df[[column]] <- NA_character_
  df$fund_cnpj <- ifelse(is.na(df$fund_cnpj_normalized), df$fund_cnpj_original, df$fund_cnpj_normalized)
  period <- coalesce_columns(df, fund_period_columns)
  df$period <- ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", period), substr(period, 1, 10), NA_character_)
  df$version <- suppressWarnings(as.numeric(coalesce_columns(df, fund_version_columns)))
  df[!is.na(df$fund_cnpj) & nzchar(df$fund_cnpj) & !is.na(df$period), , drop = FALSE]
}

# Distribution of one fund's monthly returns for the normal-curve chart: mean,
# standard deviation, last month, and a histogram over a display range of
# mean +/- 4 standard deviations (cut to the observed values); values outside
# the range are counted, never dropped silently. NULL below the minimum months.
fund_return_distribution <- function(values, months, class = "") {
  ok <- !is.na(values)
  values <- values[ok]; months <- months[ok]
  n <- length(values)
  if (n < fund_return_min_months) return(NULL)
  m <- mean(values); s <- stats::sd(values)
  # Chart only: values winsorized at 2.5% on each side (fund_winsorize), then
  # drawn on the display scale (fund_display_scale); mean, deviation and every
  # label stay in original values.
  w <- fund_winsorize(values)
  sc <- fund_display_scale(w$values)
  tv <- fund_scale_fwd(w$values, sc)
  dm <- mean(tv); ds <- stats::sd(tv)
  lo <- fund_scale_fwd(w$lo, sc); hi <- fund_scale_fwd(w$hi, sc)
  if (!is.finite(ds) || ds == 0 || hi <= lo) { lo <- dm - 1; hi <- dm + 1 }
  bins <- min(16L, max(6L, as.integer(ceiling(sqrt(n)))))
  breaks <- seq(lo, hi, length.out = bins + 1L)
  inside <- tv >= lo & tv <= hi
  counts <- as.integer(table(cut(tv[inside], breaks, include.lowest = TRUE)))
  last <- order(months, decreasing = TRUE, method = "radix")[1]
  list(n = n, mean = m, sd = if (is.finite(s)) s else 0, min = min(values), max = max(values),
       scale = sc, dmean = dm, dsd = if (is.finite(ds)) ds else 0,
       lo = lo, hi = hi, counts = counts, outside = w$clamped, wlo = w$lo, whi = w$hi,
       last = values[last], last_month = months[last], first_month = min(months), class = class)
}

# Winsorization of the values drawn in the distribution charts (developer
# decision, 2026-11-13): values below the 2.5th percentile or above the 97.5th
# are drawn at those limits (the edge bars), so a few extremes do not stretch
# the axis. Only the chart: means, deviations, percentiles and positions use
# the original values. clamped = number of values moved to a limit.
fund_winsor_share <- 0.025
fund_winsorize <- function(values) {
  lim <- stats::quantile(values, c(fund_winsor_share, 1 - fund_winsor_share), names = FALSE, type = 7)
  list(values = pmin(pmax(values, lim[1]), lim[2]), lo = lim[1], hi = lim[2],
       clamped = sum(values < lim[1] | values > lim[2]))
}

# Display scale of a distribution, only to draw it: NA = linear; a number c =
# signed logarithm asinh(v / c), used for every distribution chart: fund values
# span orders of magnitude (most funds near zero and a few very large ones),
# which would squeeze the histogram into one bar. asinh keeps zero and negative
# values and is close to linear for |v| < c. Positions (percentiles), means
# and every label use the original values. Same rule in taxminer_static.js.
fund_display_scale <- function(values) {
  values <- values[is.finite(values)]
  if (length(unique(values)) < 3L) return(NA_real_)
  # Always on the log scale (developer decision, 2026-11-13); linear only
  # when there are fewer than three distinct values.
  q <- stats::quantile(values, c(0.01, 0.25, 0.5, 0.75, 0.99), names = FALSE, type = 7)
  iqr <- q[4] - q[2]
  c <- max(iqr, abs(q[3])) / 2
  if (!is.finite(c) || c <= 0) c <- (q[5] - q[1]) / 100
  if (!is.finite(c) || c <= 0) return(NA_real_)
  c
}
fund_scale_fwd <- function(v, c) if (is.null(c) || is.na(c)) v else asinh(v / c)
fund_scale_inv <- function(t, c) if (is.null(c) || is.na(c)) t else sinh(t) * c

# Distribution of one fund from fund_returns() (NULL when not enough months).
fund_return_profile <- function(returns, family, cnpj) {
  if (is.null(returns)) return(NULL)
  r <- returns[returns$family == family & returns$fund_cnpj == cnpj, , drop = FALSE]
  if (!nrow(r)) return(NULL)
  fund_return_distribution(r$value, r$month, r$class[1])
}

# Percent in pt-BR from a value already in percent ("1,23%"), never scientific.
format_return_pct <- function(x, digits = 2) {
  ifelse(is.na(x), "—", paste0(formatC(x, format = "f", digits = digits, big.mark = ".", decimal.mark = ","), "%"))
}

# Compact pt-BR number for axes and captions ("1,2 bi", "35,4 mil", "0,0123"),
# never in scientific notation.
format_compact_number <- function(x) {
  vapply(x, function(v) {
    if (is.na(v)) return("—")
    a <- abs(v); s <- if (v < 0) "-" else ""
    fmt <- function(n, d) formatC(n, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
    if (a >= 1e9) paste0(s, fmt(a / 1e9, 1), " bi") else if (a >= 1e6) paste0(s, fmt(a / 1e6, 1), " mi")
    else if (a >= 1e4) paste0(s, fmt(a / 1e3, 1), " mil") else if (a >= 100) paste0(s, fmt(a, 0))
    else if (a >= 1 || a == 0) paste0(s, fmt(a, 2)) else paste0(s, fmt(a, 4))
  }, character(1), USE.NAMES = FALSE)
}

# Small SVG of a distribution (fund_return_distribution): histogram of the
# periods (bars), the normal curve with the same mean and deviation (line), the
# mean (dashed) and the latest period (marker). `fmt` formats the axis values;
# ticks = FALSE leaves the axis without text (thumbnails).
fund_distribution_svg <- function(d, width = 340, height = 128, fmt = format_return_pct, ticks = TRUE, label = "") {
  ml <- 4; mr <- 4; mt <- 6; mb <- if (ticks) 16 else 4
  pw <- width - ml - mr; ph <- height - mt - mb
  # lo, hi, counts, dmean and dsd are on the display scale (d$scale); the
  # marked value and the axis labels are original values.
  sc <- if (is.null(d$scale)) NA_real_ else d$scale
  dm <- if (is.null(d$dmean)) d$mean else d$dmean
  ds <- if (is.null(d$dsd)) d$sd else d$dsd
  k <- length(d$counts); bw <- (d$hi - d$lo) / k
  sx <- function(v) ml + (v - d$lo) / (d$hi - d$lo) * pw
  dens <- function(v) if (ds > 0) stats::dnorm(v, dm, ds) * d$n * bw else rep(0, length(v))
  xs <- seq(d$lo, d$hi, length.out = 60L)
  top <- max(c(d$counts, dens(xs), 1))
  sy <- function(v) mt + ph - v / top * ph
  f <- function(v) formatC(v, format = "f", digits = 1)
  bars <- vapply(seq_len(k), function(i) {
    if (!d$counts[i]) return("")
    x0 <- sx(d$lo + (i - 1) * bw) + 0.6; x1 <- sx(d$lo + i * bw) - 0.6
    sprintf('<rect class="tm-rd-bar" x="%s" y="%s" width="%s" height="%s" rx="1.5"/>', f(x0), f(sy(d$counts[i])),
            f(max(0.8, x1 - x0)), f(mt + ph - sy(d$counts[i])))
  }, character(1))
  curve <- if (ds > 0) sprintf('<path class="tm-rd-curve" d="M%s"/>',
                               paste(sprintf("%s,%s", f(sx(xs)), f(sy(dens(xs)))), collapse = " L")) else ""
  mean_x <- f(sx(dm))
  # A marked value outside the scale shows as a dot on the nearest edge.
  lt <- if (is.null(d$last) || is.na(d$last)) NA_real_ else fund_scale_fwd(d$last, sc)
  last <- if (is.na(lt)) "" else if (lt >= d$lo && lt <= d$hi)
    sprintf('<line class="tm-rd-last" x1="%s" x2="%s" y1="%s" y2="%s"/><circle class="tm-rd-dot" cx="%s" cy="%s" r="3"/>',
            f(sx(lt)), f(sx(lt)), mt, mt + ph, f(sx(lt)), mt + 3) else
    sprintf('<circle class="tm-rd-dot" cx="%s" cy="%s" r="3"/>', f(if (lt < d$lo) ml + 3 else width - mr - 3), mt + ph - 3)
  axis <- sprintf('<line class="tm-rd-axis" x1="%s" x2="%s" y1="%s" y2="%s"/>', ml, width - mr, mt + ph, mt + ph)
  # The middle label is dropped when it would run into the edge labels; on the
  # log scale it names the original value under the centre of the curve.
  keep <- c(TRUE, min(sx(dm) - ml, width - mr - sx(dm)) >= 0.22 * pw, TRUE)
  tk <- if (ticks) paste(sprintf('<text class="tm-rd-tick" x="%s" y="%s" text-anchor="%s">%s</text>',
                                 c(ml, mean_x, width - mr)[keep], height - 4, c("start", "middle", "end")[keep],
                                 htmltools::htmlEscape(fmt(fund_scale_inv(c(d$lo, dm, d$hi), sc))[keep])), collapse = "") else ""
  if (!is.na(sc)) tk <- paste0(tk, sprintf('<text class="tm-rd-tick tm-rd-log" x="%s" y="%s" text-anchor="end">escala log</text>',
                                           width - mr, mt + 6))
  sprintf(paste0('<svg class="tm-rd-svg" viewBox="0 0 %s %s" width="100%%" role="img" aria-label="%s">',
                 '%s%s%s<line class="tm-rd-mean" x1="%s" x2="%s" y1="%s" y2="%s"/>%s%s</svg>'),
          width, height, htmltools::htmlEscape(label), axis, paste(bars, collapse = ""), curve,
          mean_x, mean_x, mt, mt + ph, last, tk)
}

fund_return_svg <- function(d, width = 340, height = 128, ticks = TRUE) {
  fund_distribution_svg(d, width, height, function(v) format_return_pct(v, 2), ticks, fund_return_caption(d))
}

fund_return_caption <- function(d) {
  paste0("Média ", format_return_pct(d$mean), " ao mês · desvio-padrão ",
         formatC(d$sd, format = "f", digits = 2, decimal.mark = ","), " p.p. · ",
         format_int(d$n), " meses (", month_label(d$first_month), " a ", month_label(d$last_month), ") · último mês ",
         format_return_pct(d$last))
}
