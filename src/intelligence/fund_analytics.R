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
