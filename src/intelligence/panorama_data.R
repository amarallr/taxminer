# Panorama data package (req_0019, work_0030). Every Panorama component (KPIs,
# family panels, composition bar, the two rankings) is computed in the browser
# by prototype/www/panorama.js from the same facts, so a selection anywhere
# changes every component consistently (cross-filtering). Same files for the
# local app (served under panorama-data/) and the published page
# (site/app/data/panorama/).
#
# Facts: one row per fund (family + CNPJ) and month, from the derived metrics
# (src/data/build_fund_metrics.R, FIP balances carried as in the app), with the
# administrator reported for THAT month (historical link from the search
# directory, never the current administrator retroacted).
#
# Files (JSON, written in base R):
#   index.json            dictionaries (funds, administrators), months, colours
#   months/YYYY-MM.json   [fund, administrator, net assets, quotaholders, carried]
#   series_family.json    family totals per month (net assets, funds)
#   series_admin.json     per administrator and family per month (historical link)
#   series/{fam}_{c}.json per fund per month (net assets, quotaholders)

panorama_data_version <- "1"
panorama_months_selectable <- 24L

# --- Minimal JSON writers (text, numbers, null) ------------------------------

json_string <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("[[:cntrl:]]", " ", x)
  ifelse(is.na(x), "null", paste0("\"", x, "\""))
}
json_number <- function(x, digits = 2L) {
  out <- sprintf(paste0("%.", digits, "f"), x)
  # Trailing decimal zeros only (never the zeros of the integer part).
  if (digits > 0) out <- sub("\\.$", "", sub("(\\.[0-9]*?)0+$", "\\1", out))
  out[out == "-0"] <- "0"
  ifelse(is.na(x) | !is.finite(x), "null", out)
}
json_array <- function(...) paste0("[", paste(..., sep = ","), "]")
json_object <- function(keys, values) paste0("{", paste(json_string(keys), values, sep = ":", collapse = ","), "}")

month_index <- function(month) {
  as.integer(substr(month, 1, 4)) * 12L + as.integer(substr(month, 6, 7)) - 1L
}

# --- Facts -------------------------------------------------------------------

# Administrator key of each (family, fund_cnpj, month) row from the directory,
# which has one row per published combination with its first and last period.
# Chosen: the combination observed in that month (latest-ending when several);
# in a gap, the nearest combination in time. FIAGRO rows that carry the fund
# name in the administrator field keep only the administrator CNPJ.
fund_month_administrator <- function(rows, directory) {
  d <- directory[, c("family", "fund_cnpj", "fund_name", "administrator_name", "administrator_cnpj",
                     "first_period", "last_period")]
  fund_name <- !is.na(d$administrator_name) &
    normalize_search_text(d$administrator_name) == normalize_search_text(d$fund_name)
  d$administrator_name[fund_name] <- NA_character_
  d$key <- administrator_key(d$administrator_cnpj, d$administrator_name)
  d <- d[!is.na(d$key), , drop = FALSE]
  out <- rep(NA_character_, nrow(rows))
  if (!nrow(rows) || !nrow(d)) return(out)
  r <- data.frame(i = seq_len(nrow(rows)), family = rows$family, fund_cnpj = rows$fund_cnpj,
                  m = month_index(rows$month), stringsAsFactors = FALSE)
  d$first <- month_index(d$first_period); d$last <- month_index(d$last_period)
  x <- merge(r, d[, c("family", "fund_cnpj", "key", "first", "last")], by = c("family", "fund_cnpj"))
  if (!nrow(x)) return(out)
  dist <- ifelse(x$m < x$first, x$first - x$m, ifelse(x$m > x$last, x$m - x$last, 0L))
  x <- x[order(x$i, dist, -x$last, x$key, method = "radix"), , drop = FALSE]
  x <- x[!duplicated(x$i), , drop = FALSE]
  out[x$i] <- x$key
  out
}

# One row per family, fund and month (a report and a carried FIP balance for
# the same month never both count).
panorama_facts <- function(m, directory) {
  f <- m[!is.na(m$month), c("family", "fund_cnpj", "month", "period", "net_assets", "quotaholders", "carried")]
  f <- f[order(f$family, f$fund_cnpj, f$month, f$carried, -xtfrm(f$period), method = "radix"), , drop = FALSE]
  f <- f[!duplicated(paste(f$family, f$fund_cnpj, f$month)), , drop = FALSE]
  f$admin <- fund_month_administrator(f, directory)
  # FIP does not publish an administrator in these reports.
  f$admin[!f$family %in% admin_families] <- NA_character_
  rownames(f) <- NULL
  f
}

# Dictionaries: display names from the entity catalog (current denomination).
panorama_dictionaries <- function(facts, directory, master = NULL) {
  funds <- unique(facts[, c("family", "fund_cnpj")])
  funds <- funds[order(match(funds$family, fund_family_order), funds$fund_cnpj, method = "radix"), , drop = FALSE]
  latest <- directory[order(directory$last_period, decreasing = TRUE, method = "radix"), ]
  latest <- latest[!duplicated(paste(latest$family, latest$fund_cnpj)), ]
  k <- match(paste(funds$family, funds$fund_cnpj), paste(latest$family, latest$fund_cnpj))
  funds$name <- latest$fund_name[k]
  if (!is.null(master)) {
    e <- master$entities
    i <- match(entity_key("fund", funds$fund_cnpj, funds$name), e$entity_id)
    funds$name <- ifelse(is.na(i), funds$name, e$display_name[i])
  }
  funds$name <- display_name(funds$name)
  funds$cnpj_formatted <- format_cnpj(funds$fund_cnpj)
  rownames(funds) <- NULL

  keys <- sort(unique(stats::na.omit(facts$admin)))
  d <- directory[!is.na(directory$administrator_cnpj) | !is.na(directory$administrator_name), ]
  d$key <- administrator_key(d$administrator_cnpj, d$administrator_name)
  name_of <- tapply(d$administrator_name, d$key, function(v) {
    v <- stats::na.omit(v); if (length(v)) names(sort(table(v), decreasing = TRUE))[1] else NA_character_
  })
  cnpj_of <- tapply(d$administrator_cnpj, d$key, function(v) stats::na.omit(v)[1])
  admins <- data.frame(key = keys, name = unname(name_of[keys]), cnpj = unname(cnpj_of[keys]), stringsAsFactors = FALSE)
  if (!is.null(master)) {
    i <- match(admins$key, master$entities$entity_id)
    admins$name <- ifelse(is.na(i), admins$name, master$entities$display_name[i])
  }
  admins$name[is.na(admins$name)] <- paste("CNPJ", admins$cnpj[is.na(admins$name)])
  admins$name[is.na(admins$name) | admins$name == "CNPJ NA"] <- "(administrador sem nome)"
  admins$cnpj_formatted <- ifelse(is.na(admins$cnpj), "sem CNPJ", format_cnpj(admins$cnpj))
  list(funds = funds, admins = admins)
}

# --- Writers -------------------------------------------------------------------

panorama_month_json <- function(rows, dict) {
  fi <- match(paste(rows$family, rows$fund_cnpj), paste(dict$funds$family, dict$funds$fund_cnpj)) - 1L
  ai <- match(rows$admin, dict$admins$key) - 1L
  ai[is.na(ai)] <- -1L
  paste0("{\"rows\":[", paste(sprintf("[%d,%d,%s,%s,%d]", fi, ai, json_number(rows$net_assets),
                                      json_number(rows$quotaholders, 0L), as.integer(rows$carried)),
                              collapse = ",\n"), "]}")
}

# {fam: [first month, [net assets], [funds]]} with every month in between.
series_arrays <- function(months, pl, count) {
  all <- seq(month_index(min(months)), month_index(max(months)))
  i <- match(all, month_index(months))
  sprintf("[%s,[%s],[%s]]", json_string(min(months)), paste(json_number(pl[i]), collapse = ","),
          paste(ifelse(is.na(i), "null", count[i]), collapse = ","))
}

panorama_family_series_json <- function(series, complete) {
  parts <- vapply(names(complete), function(f) {
    d <- series[series$family == f & series$month <= complete[[f]], , drop = FALSE]
    d <- d[order(d$month), , drop = FALSE]
    series_arrays(d$month, d$net_assets, d$funds)
  }, character(1))
  json_object(names(complete), parts)
}

panorama_admin_series_json <- function(facts, dict, complete) {
  f <- facts[!is.na(facts$admin) & facts$month <= unname(complete[facts$family]), , drop = FALSE]
  key <- paste(f$admin, f$family, f$month, sep = "|")
  pl <- tapply(f$net_assets, key, sum, na.rm = TRUE)
  n <- tapply(f$fund_cnpj, key, length)
  parts <- strsplit(names(pl), "|", fixed = TRUE)
  g <- data.frame(admin = vapply(parts, `[`, "", 1), family = vapply(parts, `[`, "", 2),
                  month = vapply(parts, `[`, "", 3), pl = as.numeric(pl), n = as.integer(n),
                  stringsAsFactors = FALSE)
  g <- g[order(g$admin, g$family, g$month, method = "radix"), , drop = FALSE]
  by_admin <- split(g, g$admin)
  items <- vapply(by_admin, function(a) {
    fams <- split(a, a$family)
    json_object(names(fams), vapply(fams, function(x) series_arrays(x$month, x$pl, x$n), character(1)))
  }, character(1))
  idx <- match(names(by_admin), dict$admins$key) - 1L
  paste0("{", paste(sprintf("\"%d\":%s", idx, items), collapse = ",\n"), "}")
}

# Per fund (chunks by family and first CNPJ character), read on demand:
# {"cnpj": [first month, [net assets], [quotaholders]]}; months without a
# report are null (never zero).
panorama_fund_series_chunks <- function(facts) {
  m <- facts[!facts$carried, c("family", "fund_cnpj", "month", "net_assets", "quotaholders")]
  m <- m[order(m$family, m$fund_cnpj, m$month, method = "radix"), , drop = FALSE]
  m$chunk <- paste0(m$family, "_", tolower(substr(m$fund_cnpj, 1, 1)))
  lapply(split(m, m$chunk), function(c) {
    funds <- split(c, c$fund_cnpj)
    items <- vapply(funds, function(f) {
      all <- seq(month_index(f$month[1]), month_index(f$month[nrow(f)]))
      i <- match(all, month_index(f$month))
      sprintf("%s:[%s,[%s],[%s]]", json_string(f$fund_cnpj[1]), json_string(f$month[1]),
              paste(json_number(f$net_assets[i]), collapse = ","), paste(json_number(f$quotaholders[i], 0L), collapse = ","))
    }, character(1))
    paste0("{", paste(items, collapse = ",\n"), "}")
  })
}

write_json_file <- function(text, path) {
  con <- file(path, "wb"); on.exit(close(con))
  writeBin(charToRaw(enc2utf8(text)), con)
}

# Writes the package into `dir` (replaced). `ctx` from fund_analytics_context().
write_panorama_data <- function(dir, ctx, directory, master = NULL, generated = format(Sys.time(), "%Y-%m-%d %H:%M"),
                                selectable = panorama_months_selectable) {
  unlink(dir, recursive = TRUE)
  dir.create(file.path(dir, "months"), recursive = TRUE)
  dir.create(file.path(dir, "series"), recursive = TRUE)
  facts <- panorama_facts(ctx$m, directory)
  dict <- panorama_dictionaries(facts, directory, master)
  complete <- ctx$complete[fund_family_order[fund_family_order %in% names(ctx$complete)]]
  last <- max(unname(complete))
  months <- vapply(rev(seq_len(selectable)) - 1L, function(k) shift_month(last, -k), character(1))
  needed <- sort(unique(c(months, vapply(months, shift_month, character(1), -12L), unname(complete),
                          vapply(unname(complete), shift_month, character(1), -12L))))
  for (mo in needed) {
    write_json_file(panorama_month_json(facts[facts$month == mo, , drop = FALSE], dict),
                    file.path(dir, "months", paste0(mo, ".json")))
  }
  write_json_file(panorama_family_series_json(ctx$series, complete), file.path(dir, "series_family.json"))
  write_json_file(panorama_admin_series_json(facts, dict, complete), file.path(dir, "series_admin.json"))
  chunks <- panorama_fund_series_chunks(facts)
  for (n in names(chunks)) write_json_file(chunks[[n]], file.path(dir, "series", paste0(n, ".json")))
  latest <- tapply(ctx$series$month, ctx$series$family, max)
  index <- paste0(
    "{\"version\":", json_string(panorama_data_version), ",\"generated\":", json_string(generated),
    ",\"families\":[", paste(json_string(names(complete)), collapse = ","), "]",
    ",\"admin_families\":[", paste(json_string(unname(admin_families)), collapse = ","), "]",
    ",\"colors\":", json_object(names(fund_family_colors), json_string(unname(fund_family_colors))),
    ",\"names\":", json_object(names(fund_family_names), json_string(unname(fund_family_names))),
    ",\"complete\":", json_object(names(complete), json_string(unname(complete))),
    ",\"latest\":", json_object(names(latest), json_string(unname(latest))),
    ",\"months\":[", paste(json_string(months), collapse = ","), "]",
    ",\"available\":[", paste(json_string(needed), collapse = ","), "]",
    ",\"funds\":[", paste(sprintf("[%s,%s,%s,%s]", json_string(dict$funds$family), json_string(dict$funds$cnpj_formatted),
                                  json_string(dict$funds$name), json_string(dict$funds$fund_cnpj)), collapse = ",\n"), "]",
    ",\"admins\":[", paste(sprintf("[%s,%s,%s]", json_string(dict$admins$key), json_string(dict$admins$name),
                                   json_string(dict$admins$cnpj_formatted)), collapse = ",\n"), "]}")
  write_json_file(index, file.path(dir, "index.json"))
  invisible(list(dir = dir, facts = nrow(facts), funds = nrow(dict$funds), admins = nrow(dict$admins),
                 months = length(needed), chunks = length(chunks)))
}

# Cached package under processed/metrics/panorama: rebuilt only when the
# metrics, the directory, the entity rules, the reference date or this code
# change.
panorama_data_signature <- function(root, master = NULL, today = Sys.Date()) {
  metrics <- file.path(fund_processed_paths(root)$base, "metrics", "fund_period_metrics.parquet")
  compute_signature_hash(list(
    version = panorama_data_version, today = format(today), directory = fund_directory_signature(root),
    metrics = unname(tools::md5sum(metrics)), rules = if (is.null(master)) NA else master$rule_version,
    functions = transformation_signature(list(
      fund_month_administrator = fund_month_administrator, panorama_facts = panorama_facts,
      panorama_dictionaries = panorama_dictionaries, panorama_month_json = panorama_month_json,
      series_arrays = series_arrays, panorama_admin_series_json = panorama_admin_series_json,
      panorama_fund_series_chunks = panorama_fund_series_chunks, write_panorama_data = write_panorama_data,
      json_number = json_number, json_string = json_string))))
}

load_panorama_data <- function(root, ctx, directory, master = NULL, rebuild = FALSE) {
  dir <- file.path(fund_processed_paths(root)$base, "metrics", "panorama")
  sig <- panorama_data_signature(root, master, ctx$today)
  stamp <- file.path(dir, "signature.txt")
  if (!rebuild && file.exists(stamp) && identical(readLines(stamp, warn = FALSE), sig) &&
      file.exists(file.path(dir, "index.json"))) {
    return(dir)
  }
  write_panorama_data(dir, ctx, directory, master)
  writeLines(sig, stamp)
  dir
}
