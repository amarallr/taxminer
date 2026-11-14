# Shiny area for Phase 1.3 (investment fund reports). Presentation only: the
# search logic lives in src/intelligence/search_fund_reports.R.

fund_family_labels <- c(FII = "fii", FIDC = "fidc", FIP = "fip", FIAGRO = "fiagro")
fund_result_limit <- 500L

escape_html <- function(x) htmltools::htmlEscape(ifelse(is.na(x), "", as.character(x)))

format_count <- function(x) formatC(x, format = "d", big.mark = ".", decimal.mark = ",")

# Fields holding identifiers or codes: shown exactly as published.
fund_code_fields <- "CNPJ|CPF|CEP|ISIN|TEL|FONE|FAX|^CD_|_CD_|^COD|_COD|^ID_|_ID$|^ANO|_ANO$|^NR_PROC|VERSAO|^TP_|CODIGO"

# CPF as 000.000.000-00 when the check digits are right (numeric values that
# lost leading zeros are padded); anything else is returned as published.
format_cpf <- function(x) {
  out <- ifelse(is.na(x), NA_character_, trimws(x))
  d <- gsub("[.[:space:]-]", "", out)
  short <- !is.na(d) & grepl("^[0-9]{9,10}$", d)
  d[short] <- paste0(strrep("0", 11L - nchar(d[short])), d[short])
  ok <- !is.na(d) & grepl("^[0-9]{11}$", d) & !grepl("^(.)\\1{10}$", d)
  ok[ok] <- vapply(d[ok], function(v) {
    n <- utf8ToInt(v) - 48L
    dv <- function(k) { r <- (sum(n[seq_len(k)] * seq(k + 1L, 2L)) * 10L) %% 11L; if (r == 10L) 0L else r }
    dv(9L) == n[10] && dv(10L) == n[11]
  }, logical(1), USE.NAMES = FALSE)
  out[ok] <- sprintf("%s.%s.%s-%s", substr(d[ok], 1, 3), substr(d[ok], 4, 6), substr(d[ok], 7, 9), substr(d[ok], 10, 11))
  out
}

# CNPJ and CPF fields of the reports shown with their masks. Fields named for
# both (e.g. CPF/CNPJ of a cedente) take CPF when the value is a valid CPF.
format_tax_id <- function(x, field) {
  f <- toupper(field)
  has_cnpj <- grepl("CNPJ", f); has_cpf <- grepl("CPF", f)
  if (!has_cnpj && !has_cpf) return(x)
  if (!has_cnpj) return(format_cpf(x))
  cnpj <- format_cnpj(x)
  if (!has_cpf) return(cnpj)
  cpf <- format_cpf(x)
  digits <- gsub("[^0-9]", "", ifelse(is.na(x), "", x))
  use_cpf <- !is.na(cpf) & nchar(digits) <= 11L & grepl("^[0-9]{3}[.][0-9]{3}[.][0-9]{3}-[0-9]{2}$", cpf)
  ifelse(use_cpf, cpf, cnpj)
}

# Published numbers in scientific notation ("1.2345E-5", "3e+06") rewritten as
# plain decimals ("0.000012345", "3000000"), keeping every significant digit;
# other values are returned unchanged. Scientific notation is never displayed.
fund_scientific_pattern <- "^-?[0-9]+([.][0-9]+)?[eE][-+]?[0-9]+$"
expand_scientific <- function(v) {
  v <- as.character(v)
  sci <- !is.na(v) & grepl(fund_scientific_pattern, trimws(v))
  if (!any(sci)) return(v)
  s <- trimws(v[sci])
  mant <- sub("[eE].*$", "", s)
  expo <- as.integer(sub("^.*[eE]", "", s))
  dec <- ifelse(grepl(".", mant, fixed = TRUE), nchar(sub("^[^.]*[.]", "", mant)), 0L)
  digits <- pmin(pmax(0L, dec - expo), 20L)
  out <- vapply(seq_along(s), function(i)
    formatC(as.numeric(s[i]), format = "f", digits = digits[i], big.mark = ""), character(1))
  # Trailing zeros added by the conversion (beyond the published digits) are dropped.
  out <- ifelse(grepl(".", out, fixed = TRUE), sub("[.]$", "", sub("0+$", "", out)), out)
  v[sci] <- out
  v
}

# Display of published values (presentation only; stored values unchanged):
# plain numbers get "." for thousands and "," for decimals, keeping the
# published decimal places; values already in that format pass through. CVM
# files use "." for decimals, so "12.345" is twelve point 345 ("12,345"), not
# a masked thousand: only text that is not a plain number counts as masked.
# Returns the text and whether it is numeric (right-aligned).
display_value <- function(v, field = "") {
  if (is.na(v) || !nzchar(trimws(v))) return(list(text = "—", num = FALSE))
  v <- trimws(v)
  if (grepl(fund_code_fields, toupper(field))) return(list(text = format_tax_id(v, field), num = FALSE))
  v <- expand_scientific(v)
  plain <- grepl("^-?[0-9]+([.][0-9]+)?$", v) && !grepl("^-?0[0-9]", v)
  if (!plain && grepl("^-?[0-9]{1,3}([.][0-9]{3})*(,[0-9]+)?$", v) && grepl("[.,]", v))
    return(list(text = v, num = TRUE))
  if (!plain) return(list(text = v, num = FALSE))
  parts <- strsplit(sub("^-", "", v), ".", fixed = TRUE)[[1]]
  int <- gsub("(?<=[0-9])(?=([0-9]{3})+$)", ".", parts[1], perl = TRUE)
  text <- paste0(if (startsWith(v, "-")) "-" else "", int, if (length(parts) > 1) paste0(",", parts[2]) else "")
  list(text = text, num = TRUE)
}

# Vectorised display_value for one column (same rules): text and numeric flag.
display_values <- function(v, field = "") {
  v <- trimws(as.character(v))
  empty <- is.na(v) | !nzchar(v)
  text <- ifelse(empty, "—", v)
  num <- rep(FALSE, length(v))
  if (grepl(fund_code_fields, toupper(field))) {
    text[!empty] <- format_tax_id(v[!empty], field)
    return(list(text = text, num = num))
  }
  ok <- !empty
  v[ok] <- expand_scientific(v[ok])
  plain <- ok & grepl("^-?[0-9]+([.][0-9]+)?$", v) & !grepl("^-?0[0-9]", v)
  masked <- ok & !plain & grepl("^-?[0-9]{1,3}([.][0-9]{3})*(,[0-9]+)?$", v) & grepl("[.,]", v)
  num[masked | plain] <- TRUE
  if (any(plain)) {
    p <- v[plain]
    neg <- startsWith(p, "-")
    p <- sub("^-", "", p)
    int <- gsub("(?<=[0-9])(?=([0-9]{3})+$)", ".", sub("[.].*$", "", p), perl = TRUE)
    dec <- ifelse(grepl(".", p, fixed = TRUE), paste0(",", sub("^[^.]*[.]", "", p)), "")
    text[plain] <- paste0(ifelse(neg, "-", ""), int, dec)
  }
  list(text = text, num = num)
}

value_cell <- function(v, field) {
  d <- display_value(v, field)
  shiny::tags$td(class = if (d$num) "tm-num", d$text)
}

# Autocomplete settings: free text is kept, so partial values still filter.
autocomplete_options <- function(placeholder) {
  list(create = TRUE, createOnBlur = TRUE, persist = FALSE, maxItems = 1,
       maxOptions = 50, placeholder = placeholder)
}

# Entity filters: several options; free text is kept and searched in the
# catalog (CNPJ with or without mask, current or former names).
entity_autocomplete_options <- function(placeholder) {
  list(create = TRUE, createOnBlur = TRUE, persist = FALSE, maxItems = 5,
       maxOptions = 50, placeholder = placeholder, plugins = list("remove_button"))
}

# Fund options from the entity catalog: one per denomination,
# "00.000.000/0000-00 — NAME"; the value is the denomination id, which the
# search resolves to the entity (its CNPJ) before querying.
fund_choices <- function(master, directory = NULL) {
  n <- master$entity_names[master$entity_names$entity_type == "fund", , drop = FALSE]
  if (!is.null(directory)) n <- n[n$entity_id %in% directory$fund_entity, , drop = FALSE]
  cnpj <- master$entities$cnpj_formatted[match(n$entity_id, master$entities$entity_id)]
  n <- n[order(normalize_search_text(n$display_name), cnpj, method = "radix"), , drop = FALSE]
  cnpj <- master$entities$cnpj_formatted[match(n$entity_id, master$entities$entity_id)]
  stats::setNames(n$name_id, sprintf("%s — %s", cnpj, n$display_name))
}

period_choices <- function(directory) {
  first <- min(directory$first_period, na.rm = TRUE)
  last <- max(directory$last_period, na.rm = TRUE)
  months <- seq(as.Date(paste0(substr(first, 1, 7), "-01")),
                as.Date(paste0(substr(last, 1, 7), "-01")), by = "month")
  rev(c(unique(format(months, "%Y")), format(months, "%Y-%m")))
}

kpi <- function(label, value, note = NULL) {
  shiny::div(class = "tm-kpi", shiny::div(class = "tm-kpi-value", value),
             shiny::div(class = "tm-kpi-label", label),
             if (!is.null(note)) shiny::div(class = "tm-kpi-note", note))
}

# Characteristics of one fund in the detail header: number of quotaholders
# (latest report that published it) and the fields of fund_attribute_specs,
# as published in the latest report that filled them. Fields that the report
# of this family does not have read "não consta do informe".
fund_traits_ui <- function(attributes, family, cnpj, profile = NULL) {
  if (is.null(attributes)) return(NULL)
  # Grid of label over value; highlighted values (fund_attribute_alert) in amber.
  trait <- function(label, text, tip, alert = FALSE, info = NULL) {
    shiny::div(class = paste("tm-tr", if (alert) "tm-tr-alert"), `data-tip` = tip,
               shiny::div(class = "tm-tr-label", label, info),
               shiny::div(class = if (text == "não informado") "tm-tr-value tm-muted" else "tm-tr-value", text))
  }
  holders <- if (is.null(profile)) NULL else {
    d <- profile$series[!is.na(profile$series$quotaholders), , drop = FALSE]
    if (nrow(d)) d[nrow(d), ] else NULL
  }
  # Fields of this family's report in the grid; the core ones it lacks in one
  # muted line ("Não constam do informe de FII: ...").
  shown <- fund_display_attributes(family)
  # The characteristics with a hint (FIP special rights) are named there too, with
  # their hover hint, so it is reachable in every family (filters unchanged).
  absent <- Filter(function(a) !family %in% fund_attribute_families(a),
                   union(shown, intersect(fund_attribute_order, names(fund_attribute_hints))))
  items <- lapply(setdiff(shown, absent), function(a) {
    x <- fund_attribute_text(attributes, family, cnpj, a)
    spec <- fund_attribute_specs[fund_attribute_specs$attribute == a & fund_attribute_specs$family == family, , drop = FALSE]
    tip <- if (!nrow(spec)) sprintf("O informe da CVM de %s não tem este campo.", toupper(family))
           else paste0(sprintf("%s (%s)%s", fund_attribute_labels[[a]], spec$column[1],
                               if (is.na(x$period)) " · não preenchido nos informes" else paste0(" · informe de ", x$period)),
                       fund_field_note_text(spec$column[1]))
    raw <- attributes$value[attributes$family == family & attributes$fund_cnpj == cnpj & attributes$attribute == a][1]
    trait(fund_attribute_medium[[a]], x$text, paste0(tip, fund_hint_tip_text(a)), alert = fund_attribute_alert(a, raw))
  })
  joint <- attributes[attributes$family == family & attributes$fund_cnpj == cnpj & attributes$attribute == "joint_rights", , drop = FALSE]
  # The explanatory notes of the fields (Entidade de investimento) are in the
  # hover tooltips only (fund_field_note_text), not as a block below.
  shiny::tagList(
    shiny::div(class = "tm-traits-grid",
               trait("Cotistas", if (is.null(holders)) "não informado" else format_int(holders$quotaholders),
                     if (is.null(holders)) "Quantidade de cotistas não publicada nos informes."
                     else paste0("Quantidade de cotistas · informe de ", month_label(holders$month))),
               items),
    if (length(absent)) shiny::div(class = "tm-traits-absent",
      `data-tip` = "Campos que o informe da CVM desta família não tem (não é falta de preenchimento).",
      sprintf("Não constam do informe de %s: ", toupper(family)),
      lapply(seq_along(absent), function(i)
        shiny::tagList(if (i > 1) ", ", fund_hint_name(absent[i]))), "."),
    if (nrow(joint)) fund_joint_ui(joint$value[1], joint$period[1]))
}

# Name of an absent characteristic; with a hint (FIP special rights), a span
# whose hover tooltip shows it, like the tooltip of Entidade de investimento.
fund_hint_name <- function(attribute) {
  name <- tolower(fund_attribute_medium[[attribute]])
  hint <- fund_hint_tip_text(attribute)
  if (!nzchar(hint)) name
  else shiny::span(class = "tm-hint-name", `data-tip` = paste0(fund_attribute_labels[[attribute]], hint), name)
}

# Informative notice when one class has both special rights (fund_joint_rights):
# what the CVM published (lines and competência) and the developer text.
fund_joint_ui <- function(lines, period) {
  n <- suppressWarnings(as.integer(lines))
  shiny::div(class = "tm-joint", role = "note",
             shiny::div(class = "tm-joint-title", fund_joint_hint$title),
             shiny::p(fund_joint_hint$text),
             shiny::p(class = "tm-joint-src", sprintf(paste(
               "Fonte: informe FIP de %s, %s com DIREITO_POLIT_CLASSE = S e DIREITO_ECON_CLASSE = S na mesma linha",
               "(mesma classe e competência). Aviso informativo: não altera destaques nem a classificação de entidade de investimento."),
               period, if (!is.na(n) && n == 1L) "1 linha" else paste(format_int(n), "linhas"))))
}


# Monthly return of the fund on a normal curve, small, beside the fund name in
# the detail header: histogram of the published months, the normal curve with
# the same mean and deviation, the mean (dashed) and the latest month (orange).
# The full caption, legend and notes go to the tooltip. Read on demand for the
# selected fund only (the published site gets this markup in the fund's file).
fund_return_ui <- function(root, family, cnpj, returns = NULL, peers = NULL) {
  # Without the analytics layer (src/intelligence/fund_analytics.R) there is no chart.
  if (!exists("fund_return_sources", mode = "list")) return(NULL)
  src <- fund_return_sources[[family]]
  box <- function(..., tip, empty = FALSE) shiny::div(class = paste("tm-rdm", if (empty) "tm-rdm-empty"), `data-tip` = tip,
                                                      shiny::div(class = "tm-rdm-title", "Rentabilidade mensal"), ...)
  if (is.null(src)) return(box(shiny::div(class = "tm-rdm-cap", "não publicada no informe"), empty = TRUE,
                               tip = sprintf("O informe da CVM de %s não publica rentabilidade.", toupper(family))))
  r <- if (is.null(returns)) tryCatch(fund_returns(root, family = family, cnpj = cnpj), error = function(e) NULL) else returns
  d <- fund_return_profile(r, family, cnpj)
  # Robust z ruler on top: each month against the fund's own months (0 = their
  # median), on the display scale, like the comparison with the funds beside it.
  if (!is.null(d)) {
    d$zmed <- fund_scale_fwd(stats::median(d$values), d$scale)
    d$rs <- fund_peer_robust_scale(fund_scale_fwd(d$values, d$scale))
    zl <- if (is.na(d$rs)) NA_real_ else (fund_scale_fwd(d$last, d$scale) - d$zmed) / d$rs
  }
  # Beside it: the latest month among the funds of the family (fund_return_peer_box).
  if (!is.null(d) && is.null(peers)) peers <- fund_return_family_index(root, family)
  peer <- if (is.null(d)) NULL else fund_return_peer_box(peers, family, cnpj, r, d, src)
  field <- sprintf("Campo CVM %s (tabela %s)%s.", src$column, src$table,
                   if (src$scale != 1) ", publicado como fração e exibido em %" else ", publicado em %")
  if (is.null(d)) return(box(shiny::div(class = "tm-rdm-cap", sprintf("menos de %d meses publicados", fund_return_min_months)),
                             empty = TRUE, tip = paste("Distribuição não exibida:", field)))
  notes <- c(if (nzchar(d$class)) sprintf("Classe/série: %s (a de mais meses publicados).", d$class),
             sprintf(paste0("Gráfico winsorizado a 2,5%% de cada lado: meses abaixo de P2,5 (%s) ou acima de P97,5 (%s) ",
                            "aparecem nesses limites%s; a média e o desvio usam os valores publicados (de %s a %s)."),
                     format_return_pct(d$wlo), format_return_pct(d$whi),
                     if (d$outside == 1) " (1 mês)" else if (d$outside > 1) sprintf(" (%s meses)", format_int(d$outside)) else "",
                     format_return_pct(d$min), format_return_pct(d$max)))
  tip <- paste(c(fund_return_caption(d),
                 paste0(if (is.na(d$scale)) "Barras: meses; curva: normal com a mesma média e desvio; "
                        else "Barras: meses; curva: normal ajustada na escala exibida; ",
                        "tracejado: mediana dos meses", if (!is.na(d$rs)) " (0 da régua de z)", "; ",
                        "laranja: último mês."),
                 if (!is.na(d$rs)) sprintf(paste0("Mediana dos meses %s · último mês z %s (|z| < 2 típico; 2 a 3,5 atípico; 3,5 ou mais extremo). ",
                                                  "Régua superior: z robusto de cada mês em relação aos meses do próprio fundo: ",
                                                  "z = (mês − mediana dos meses) ÷ desvio robusto dos meses (MAD escalonado), na escala do gráfico."),
                                           format_return_pct(stats::median(d$values)), fund_peer_z_text(zl)),
                 fund_scale_note(d$scale, stats::median(d$values), format_return_pct, median = "dos meses"),
                 notes, field), collapse = "\n")
  own <- box(htmltools::HTML(fund_return_svg(d, width = 220, height = 62)),
      shiny::div(class = "tm-rdm-cap", sprintf("média %s · dp %s p.p. · %s meses%s", format_return_pct(d$mean),
                                               formatC(d$sd, format = "f", digits = 2, decimal.mark = ","), format_int(d$n),
                                               paste0(if (d$outside > 0) sprintf(" · %s fora", format_int(d$outside)) else "",
                                                      if (!is.na(d$scale)) " · escala log" else ""))),
      tip = tip)
  if (is.null(peer)) own else shiny::div(class = "tm-rdm-pair", own, peer)
}

# Monthly returns of every fund of a family, indexed by "family|month" (one value
# per fund: the class/series with most published months, latest report
# version, as in fund_returns), with the peer summaries computed once.
fund_return_peer_index <- function(returns) {
  idx <- new.env(parent = emptyenv())
  idx$values <- if (is.null(returns) || !nrow(returns)) list()
                else split(returns$value, paste(returns$family, returns$month, sep = "|"))
  idx$stats <- new.env(parent = emptyenv())
  idx
}
fund_return_peer_stats <- function(idx, family, month) {
  key <- paste(family, month, sep = "|")
  if (!exists(key, envir = idx$stats, inherits = FALSE))
    assign(key, fund_peer_summary(idx$values[[key]]), envir = idx$stats)
  get(key, envir = idx$stats, inherits = FALSE)
}
# The app reads every fund's returns once (load_fund_returns: cached Parquet;
# they do not change while it runs); without the cache layer, the family only.
fund_return_family_memo <- new.env(parent = emptyenv())
fund_return_family_index <- function(root, family) {
  key <- if (exists("load_fund_returns", mode = "function")) "all" else family
  if (!exists(key, envir = fund_return_family_memo, inherits = FALSE))
    assign(key, tryCatch(fund_return_peer_index(if (key == "all") load_fund_returns(root) else fund_returns(root, family = family)),
                         error = function(e) NULL), envir = fund_return_family_memo)
  get(key, envir = fund_return_family_memo, inherits = FALSE)
}

# The fund's latest monthly return among the funds of its family in the same
# month, with the method of the tab Distribuições: percentile, robust z (with
# its ruler on top), winsorized chart on the display scale, position in the
# previous month, and the same tooltip (fund_peer_tip).
fund_return_peer_box <- function(peers, family, cnpj, r, d, src) {
  if (is.null(peers)) return(NULL)
  fam <- toupper(family); fmt <- function(x) format_return_pct(x, 2)
  title <- shiny::div(class = "tm-rdm-title", paste("Rentabilidade × fundos", fam))
  v <- d$last; month <- d$last_month
  s <- fund_return_peer_stats(peers, family, month)
  if (is.null(s)) return(shiny::div(class = "tm-rdm tm-rdm-peer tm-rdm-empty", title,
    `data-tip` = sprintf("Menos de %d fundos %s com rentabilidade publicada em %s.", fund_peer_min_funds, fam, month_label(month)),
    shiny::div(class = "tm-rdm-cap", sprintf("menos de %d fundos no mês", fund_peer_min_funds))))
  p <- fund_peer_percentile(s, v); rb <- fund_peer_robust(s, v)
  own <- r[r$family == family & r$fund_cnpj == cnpj, , drop = FALSE]
  pm <- sort(unique(own$month[own$month < month]), decreasing = TRUE)[1]
  prev <- if (!is.na(pm)) {
    sp <- fund_return_peer_stats(peers, family, pm); vp <- own$value[own$month == pm][1]
    if (!is.null(sp) && !is.na(vp)) list(period = pm, p = fund_peer_percentile(sp, vp), z = fund_peer_robust(sp, vp)$z)
  }
  tip <- fund_peer_tip(paste("Rentabilidade mensal entre os fundos", fam), src$column, s, v, p, family, month, 1L, NULL, rb, prev, fmt)
  tip <- sub("Um valor por fundo: quando há várias linhas na data \\(classes, séries ou versões do informe\\), vale a mediana delas.",
             "Um valor por fundo: a classe/série com mais meses publicados, na versão mais recente do informe (a mesma do gráfico ao lado).",
             tip)
  dd <- s; dd$last <- v; dd$zmed <- fund_scale_fwd(s$q[51], s$scale)
  lv <- c(`típico` = "tm-z-typ", `atípico` = "tm-z-atp", extremo = "tm-z-ext")[rb$level]
  shiny::div(class = paste("tm-rdm tm-rdm-peer", if (!is.na(lv)) lv), `data-tip` = tip, title,
             htmltools::HTML(fund_distribution_svg(dd, 220, 62, fmt, TRUE, paste("Rentabilidade mensal entre os fundos", fam))),
             shiny::div(class = "tm-rdm-cap", sprintf("%s · z %s %s · %s fundos · %s", fund_peer_text(p), fund_peer_z_text(rb$z),
                                                     rb$level, format_int(s$n), month_label(month))))
}

# Hint line of a chart drawn on the log display scale (fund_display_scale);
# NULL on the linear scale.
# median: FALSE (dashed line = curve centre), TRUE (median of the funds) or the
# text naming whose median it is ("dos meses").
fund_scale_note <- function(scale, centre, fmt = format_compact_number, median = FALSE) {
  if (is.null(scale) || is.na(scale)) return(NULL)
  sprintf(paste0("Escala logarítmica (asinh) só para exibição, para comparar valores de ordens de grandeza diferentes: o eixo e este ",
                 "texto mostram valores originais; ",
                 if (!isFALSE(median)) paste0("o tracejado marca a mediana ", if (isTRUE(median)) "dos fundos" else median, " (%s).")
                 else "o tracejado marca o centro da curva nessa escala (%s), que não é a média."),
          fmt(centre))
}

# Distributions of every numeric field of the chosen report table (tab
# Distribuições): one small normal-curve chart per field over the fund's rows,
# with the same parsing as the Ficha (display_values: codes and identifiers are
# not numbers). Fields with fewer than fund_return_min_months values, or with
# a single value, are counted and left out. Periods with several rows (classes
# or series) contribute every row, and the chart says so.
fund_field_distributions <- function(r, descriptions = NULL, table_name = NULL) {
  fields <- fund_distribution_fields(names(r))
  periods <- row_periods(r)
  out <- list(); few <- 0L; constant <- 0L
  for (fld in fields) {
    num <- fund_numeric_values(r[[fld]], fld)
    ok <- !is.na(num)
    if (sum(ok) < fund_return_min_months) { if (any(ok)) few <- few + 1L; next }
    if (length(unique(num[ok])) < 2L) { constant <- constant + 1L; next }
    dist <- fund_return_distribution(num[ok], periods[ok])
    dist$rows_per_period <- sum(ok) / length(unique(periods[ok]))
    out[[fld]] <- dist
  }
  labels <- field_labels(names(out), descriptions, table_name)
  structure(out, labels = labels, few = few, constant = constant)
}


# --- Position among the funds of the family (tab Distribuições) --------------
# Each chart of the matrix shows one numeric field across the funds of the same
# family at the same competência (the period chosen in the Ficha), with the fund
# marked. One value per fund: the median of its rows at that date (classes,
# series or report versions), so the counts are funds. Fields need at least
# fund_peer_min_funds funds and two distinct values. The summary keeps the 101
# percentiles: the fund's position comes from them (fund_peer_percentile), the
# same rule in the app and in the published panel (taxminer_static.js).
fund_peer_min_funds <- 6L
fund_peer_bins <- 16L

fund_distribution_fields <- function(names) {
  setdiff(names, c("citation", "source_url", "zip_sha256", "source_file", "source_line", "fund_cnpj_normalized",
                   "fund_cnpj_original", fund_report_columns))
}

# Tables whose rows mix kinds of value in the same columns: FIDC X.4 has one row
# per operation type (TAB_X_TP_OPER: captações, resgates, resgates solicitados,
# amortizações), so a median over all its rows would mix them. Each numeric field
# is split into one virtual field per type, "<field>|<type>", with the values of
# the rows of that type (rows without a type are left out). The same split in the
# app, the export (write_static_peers) and the published panel (splitTable, from
# window.TM_SPLIT).
fund_peer_split_columns <- c("TAB_X_TP_OPER")

fund_peer_split <- function(r) {
  sc <- intersect(fund_peer_split_columns, names(r))
  if (!length(sc) || !nrow(r)) return(r)
  op <- trimws(as.character(r[[sc[1]]]))
  op[!is.na(op) & !nzchar(op)] <- NA
  ops <- sort(unique(op[!is.na(op)]))
  for (f in setdiff(fund_distribution_fields(names(r)), sc)) {
    if (all(is.na(fund_numeric_values(r[[f]], f)))) next
    for (o in ops) r[[paste0(f, "|", o)]] <- ifelse(!is.na(op) & op == o, r[[f]], NA)
    r[[f]] <- NULL
  }
  r
}

# CVM code of a field as shown in the tips ("TAB_X_VL_TOTAL · Captações no Mês").
fund_peer_field_code <- function(f) sub("|", " · ", f, fixed = TRUE)

# Numeric values of a field as in the Ficha (display_values: codes and
# identifiers are not numbers), NA elsewhere.
# Same rules as display_values, without building the text (fast enough for
# whole tables in the export): plain numbers, also in scientific notation, and
# numbers already masked in pt-BR; codes, identifiers and zero-padded values are not numbers.
fund_numeric_values <- function(v, field) {
  out <- rep(NA_real_, length(v))
  if (grepl(fund_code_fields, toupper(field))) return(out)
  idx <- which(!is.na(v) & nzchar(v))
  if (!length(idx)) return(out)
  v <- trimws(as.character(v[idx]))
  plain <- grepl("^-?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$", v, perl = TRUE) & !grepl("^-?0[0-9]", v, perl = TRUE)
  masked <- !plain & grepl("^-?[0-9]{1,3}([.][0-9]{3})*(,[0-9]+)?$", v, perl = TRUE) & grepl("[.,]", v, perl = TRUE)
  out[idx[plain]] <- as.numeric(v[plain])
  if (any(masked)) out[idx[masked]] <- as.numeric(sub(",", ".", gsub(".", "", v[masked], fixed = TRUE), fixed = TRUE))
  out
}

# Median of x per key, named by key; keys with a single value skip the median.
fund_median_by <- function(x, key) {
  dup <- duplicated(key) | duplicated(key, fromLast = TRUE)
  out <- stats::setNames(x[!dup], key[!dup])
  if (any(dup)) out <- c(out, vapply(split(x[dup], key[dup]), stats::median, numeric(1)))
  out
}

# One value per fund (median of its rows) for every numeric field of rows.
fund_peer_values <- function(r) {
  key <- r$fund_cnpj_normalized
  out <- list()
  for (fld in fund_distribution_fields(names(r))) {
    num <- fund_numeric_values(r[[fld]], fld)
    ok <- !is.na(num) & !is.na(key)
    if (!any(ok)) next
    out[[fld]] <- fund_median_by(num[ok], key[ok])
  }
  out
}

fund_peer_summary <- function(values, linear = FALSE) {
  values <- values[!is.na(values)]
  n <- length(values)
  if (n < fund_peer_min_funds || length(unique(values)) < 2L) return(NULL)
  q <- stats::quantile(values, seq(0, 1, 0.01), names = FALSE, type = 7)
  m <- mean(values); s <- stats::sd(values)
  # Chart only: winsorized at 2.5% on each side (fund_winsorize) and drawn on the
  # display scale (fund_display_scale; linear for bounded shares); q, mean and sd stay original.
  w <- fund_winsorize(values)
  sc <- if (linear) NA_real_ else fund_display_scale(w$values)
  tv <- fund_scale_fwd(w$values, sc)
  tv0 <- fund_scale_fwd(values, sc)  # not winsorized: robust z (fund_peer_robust)
  dm <- mean(tv); ds <- stats::sd(tv)
  lo <- fund_scale_fwd(w$lo, sc); hi <- fund_scale_fwd(w$hi, sc)
  if (hi <= lo) { lo <- fund_scale_fwd(q[1], sc); hi <- fund_scale_fwd(q[101], sc) }
  breaks <- seq(lo, hi, length.out = fund_peer_bins + 1L)
  inside <- tv >= lo & tv <= hi
  counts <- as.integer(table(cut(tv[inside], breaks, include.lowest = TRUE)))
  list(n = n, mean = m, sd = if (is.finite(s)) s else 0, min = q[1], max = q[101], lo = lo, hi = hi,
       counts = counts, outside = w$clamped, q = q, scale = sc, dmean = dm, dsd = if (is.finite(ds)) ds else 0,
       rs = fund_peer_robust_scale(tv0, if (linear) fund_peer_share_floor else 0))
}

# Field summaries of the rows of one family, table and period; attribute funds
# = funds with any row at that date.
fund_peer_summaries <- function(r) {
  v <- fund_peer_values(r)
  out <- Filter(Negate(is.null), lapply(v, fund_peer_summary))
  structure(out, funds = length(unique(r$fund_cnpj_normalized[!is.na(r$fund_cnpj_normalized)])))
}

# --- Relative metrics (mode Relativo; src/intelligence/fund_ratios.R) --------
# Competência as shown in the Ficha (YYYY-MM for dates): the key that joins a
# table with the table of its denominator (e.g. FIDC Tabela I with Tabela IV).
fund_shown_period <- function(p) ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", p), substr(p, 1, 7), p)

fund_ratio_pct <- function(x) {
  vapply(x, function(v) {
    if (is.na(v)) return("—")
    p <- 100 * v
    paste0(formatC(p, format = "f", digits = if (abs(p) >= 100) 0 else if (abs(p) >= 1) 1 else 2,
                   big.mark = ".", decimal.mark = ","), "%")
  }, character(1))
}

# Summaries of the ratios of one table and period; vals = list(table ->
# fund_peer_values of that table at the period). Each summary keeps the number of
# funds left out for a missing, zero or negative denominator.
fund_peer_ratio_summaries <- function(plan, table_name, vals) {
  if (is.null(plan) || !nrow(plan)) return(list())
  rv <- fund_ratio_values(plan, table_name, vals)
  out <- list()
  for (k in names(rv$values)) {
    s <- fund_peer_summary(rv$values[[k]], linear = fund_ratio_linear(plan$kind[plan$key == k][1]))
    if (is.null(s)) next
    s$excluded <- unname(rv$excluded[[k]])
    out[[k]] <- s
  }
  out
}

# Fund values of the table and of its denominator tables at period: rows_of(table,
# shown period) gives the rows of each denominator table at that competência.
fund_ratio_inputs <- function(plan, table_name, period, rows, rows_of) {
  vals <- list()
  vals[[table_name]] <- fund_peer_values(rows[row_periods(rows) == period, , drop = FALSE])
  sp <- fund_shown_period(period)
  for (dt in fund_ratio_tables(plan, table_name)) {
    d <- tryCatch(rows_of(dt, sp), error = function(e) NULL)
    if (is.null(d) || !nrow(d)) next
    vals[[dt]] <- fund_peer_values(d)
  }
  vals
}

# Percentile of value v among the funds (0-100): the share of funds below it,
# interpolated between the stored percentiles; ties take the middle of the tie.
fund_peer_percentile <- function(s, v) {
  if (is.null(s) || is.na(v)) return(NA_real_)
  q <- s$q
  if (v <= q[1]) return(if (v < q[1]) 0 else (max(which(q == v)) - 1) / 2)
  if (v >= q[101]) return(if (v > q[101]) 100 else (min(which(q == v)) - 1 + 100) / 2)
  eq <- which(q == v)
  if (length(eq)) return((min(eq) - 1 + max(eq) - 1) / 2)
  k <- max(which(q < v))
  (k - 1) + (v - q[k]) / (q[k + 1] - q[k])
}

# Reads each table once (the last `size` tables stay in memory) and keeps the
# summaries already computed; the processed data does not change while the app runs.
fund_peer_cache <- function(root, size = 3L, rules = if (exists("fund_ratio_rules")) fund_ratio_rules() else NULL) {
  tables <- new.env(parent = emptyenv())
  results <- new.env(parent = emptyenv())
  order <- character()
  load <- function(family, table_name) {
    tkey <- paste(family, table_name, sep = "/")
    if (is.null(tables[[tkey]])) {
      r <- fund_peer_split(as.data.frame(open_fund_table(root, family, table_name)))
      assign(tkey, list(r = r, p = row_periods(r)), envir = tables)
      order <<- c(setdiff(order, tkey), tkey)
      if (length(order) > size) { rm(list = order[1L], envir = tables); order <<- order[-1L] }
    }
    tables[[tkey]]
  }
  function(family, table_name, period) {
    key <- paste(family, table_name, period, sep = "|")
    if (!is.null(results[[key]])) return(results[[key]])
    t <- load(family, table_name)
    rows <- t$r[t$p == period, , drop = FALSE]
    s <- fund_peer_summaries(rows)
    plan <- if (exists("fund_ratio_plan")) fund_ratio_plan(rules, table_name, fund_distribution_fields(names(t$r))) else NULL
    if (!is.null(plan) && nrow(plan)) {
      vals <- fund_ratio_inputs(plan, table_name, period, rows, function(dt, sp) {
        d <- load(family, dt)
        d$r[fund_shown_period(d$p) == sp, , drop = FALSE]
      })
      s <- structure(c(s, fund_peer_ratio_summaries(plan, table_name, vals)), funds = attr(s, "funds"), plan = plan)
    }
    assign(key, s, envir = results)
    s
  }
}

fund_peer_text <- function(p) {
  if (is.na(p)) return("—")
  sprintf("percentil %s", formatC(round(p), format = "d"))
}

# --- Robust position statistics (tab Distribuições) --------------------------
# Fund values are skewed and heavy-tailed, where the usual z-score (mean and
# standard deviation) is pulled by the extremes it should reveal. The robust
# z-score uses the median and the scaled MAD (1.4826 x median absolute
# deviation, a consistent estimator of the deviation under normality) on the
# log display scale (asinh, fund_display_scale), and the class thresholds follow
# Iglewicz and Hoaglin (1993): |z| >= 3.5 extreme, |z| >= 2 atypical. Tukey's
# fences (1977), Q1 - 1.5 IQR and Q3 + 1.5 IQR on the same scale, say whether
# the value would be drawn as an outlier in a box plot. All of it is
# descriptive: a position among peers, never a judgement about the fund.
fund_peer_z_atypical <- 2
# How the robust z is computed (tooltip of each distribution chart and of its z ruler).
fund_z_explain <- paste("Régua superior: z robusto (0 = mediana dos fundos). Cálculo: z = (valor do fundo − mediana dos fundos) ÷ desvio robusto, ambos na escala do gráfico (asinh quando a escala é log) e sobre os valores originais, sem winsorização. Desvio robusto = MAD escalonado (1,4826 × mediana dos desvios absolutos em relação à mediana); se o MAD for zero (maioria dos fundos com o mesmo valor), 1,2533 × desvio absoluto médio; se ainda for zero, o desvio-padrão. Nas participações, o desvio robusto mínimo é de 1 ponto percentual. |z| de 2 a 3,5 = atípico; 3,5 ou mais = extremo (Iglewicz e Hoaglin, 1993).")
fund_peer_z_extreme <- 3.5

# Robust scale of the peers on the display scale: scaled MAD; when more than
# half of the funds share one value (MAD = 0, e.g. shares where most funds hold
# 0%), the mean absolute deviation from the median x 1.253314 (the fallback of
# the modified z-score; the IQR there is nearly zero and blew z up to hundreds);
# then the standard deviation; NA when all of them are zero. floor = minimum
# scale (1 percentage point for shares, fund_peer_share_floor).
fund_peer_share_floor <- 0.01

fund_peer_robust_scale <- function(tv, floor = 0) {
  r <- stats::mad(tv)
  if (!is.finite(r) || r <= 0) r <- 1.253314 * mean(abs(tv - stats::median(tv)))
  if (!is.finite(r) || r <= 0) r <- stats::sd(tv)
  if (!is.finite(r) || r <= 0) return(if (floor > 0) floor else NA_real_)
  max(r, floor)
}

# Robust z of value v among the peers (summary s), its class and Tukey's fences.
fund_peer_robust <- function(s, v) {
  out <- list(z = NA_real_, level = "—", tukey = NA)
  if (is.null(s) || is.na(v) || is.null(s$rs) || is.na(s$rs)) return(out)
  f <- function(x) fund_scale_fwd(x, s$scale)
  z <- (f(v) - f(s$q[51])) / s$rs
  q1 <- f(s$q[26]); q3 <- f(s$q[76]); iqr <- q3 - q1
  out$z <- z
  out$level <- if (abs(z) >= fund_peer_z_extreme) "extremo" else if (abs(z) >= fund_peer_z_atypical) "atípico" else "típico"
  out$tukey <- f(v) < q1 - 1.5 * iqr || f(v) > q3 + 1.5 * iqr
  out
}

fund_peer_z_text <- function(z) {
  if (is.na(z)) return("—")
  paste0(if (z > 0) "+" else "", formatC(z, format = "f", digits = 1, decimal.mark = ","))
}

# Hint of one chart: what it shows and how to read the position.
fund_peer_tip <- function(label, field, s, v, p, family, period, rows, history, rb = fund_peer_robust(s, v),
                          prev = NULL, fmt = format_compact_number, ratio = NULL) {
  fam <- toupper(family)
  paste(c(
    if (is.null(ratio)) sprintf("%s\nCampo CVM: %s", label, fund_peer_field_code(field))
    else sprintf("%s\nValor relativo: %s, campo CVM %s (fundo: %s), dividido por %s%s (fundo: %s).",
                 label, ratio$num_label, fund_peer_field_code(field), format_compact_number(ratio$num), ratio$den_label,
                 if (nzchar(ratio$den_table)) paste0(", em ", fund_table_label(ratio$den_table)) else "",
                 format_compact_number(ratio$den)),
    sprintf(paste0("Posição do fundo entre os %s fundos %s com este campo publicado na competência %s: %s ",
                   "(o valor do fundo, %s, é maior que o de %s%% deles)."),
            format_int(s$n), fam, period, fund_peer_text(p), fmt(v),
            formatC(round(p), format = "d")),
    if (!is.na(rb$z)) sprintf(paste0("Z robusto %s: %s (|z| < 2 típico; 2 a 3,5 atípico; 3,5 ou mais extremo). ",
                                     "Mede a distância à mediana em desvios robustos (MAD; desvio absoluto médio quando a maioria dos fundos tem o mesmo valor) na escala do gráfico%s."),
                              fund_peer_z_text(rb$z), rb$level,
                              if (isTRUE(rb$tukey)) "; fora das cercas de Tukey (seria um ponto isolado num boxplot)" else ""),
    if (!is.null(prev)) sprintf("Na competência anterior (%s): %s, %s; variação de %s pontos percentuais.",
                                prev$period, fund_peer_text(prev$p), paste("z", fund_peer_z_text(prev$z)),
                                fund_peer_z_text(p - prev$p)),
    if (is.na(s$scale)) paste0("Barras = quantidade de fundos por faixa de valor; curva = normal com a mesma média e desvio-padrão ",
                               "dos fundos; tracejado = mediana dos fundos (0 da régua de z); laranja = este fundo.")
    else paste0("Barras = quantidade de fundos por faixa de valor; curva = normal ajustada na escala exibida; ",
                "tracejado = mediana dos fundos (0 da régua de z); laranja = este fundo."),
    if (!is.null(s$rs) && !is.na(s$rs))
      fund_z_explain,
    sprintf("Fundos %s: P25 %s · mediana %s · P75 %s (metade dos fundos fica entre P25 e P75).", fam,
            fmt(s$q[26]), fmt(s$q[51]), fmt(s$q[76])),
    sprintf("Média %s · desvio-padrão %s · mínimo %s · máximo %s.", fmt(s$mean), fmt(s$sd), fmt(s$min), fmt(s$max)),
    if (!is.null(ratio) && isTRUE(s$excluded > 0))
      sprintf("%s fundos com o campo ficaram fora desta comparação: denominador ausente, zero ou negativo (ex.: PL ≤ 0).",
              format_int(s$excluded)),
    if (!is.null(ratio) && is.na(s$scale)) "Participação desenhada em escala linear (de 0 a 100%).",
    sprintf(paste0("Gráfico winsorizado a 2,5%% de cada lado: valores abaixo de P2,5 (%s) ou acima de P97,5 (%s) ",
                   "aparecem nesses limites%s; média, desvio, percentis e posição usam os valores originais."),
            fmt(fund_scale_inv(s$lo, s$scale)), fmt(fund_scale_inv(s$hi, s$scale)),
            if (s$outside > 0) sprintf(" (%s fundos)", format_int(s$outside)) else ""),
    if (v < fund_scale_inv(s$lo, s$scale) || v > fund_scale_inv(s$hi, s$scale))
      "O fundo está entre os valores winsorizados: o ponto laranja fica na borda.",
    fund_scale_note(s$scale, s$q[51], fmt, median = TRUE),
    if (is.null(ratio)) "Um valor por fundo: quando há várias linhas na data (classes, séries ou versões do informe), vale a mediana delas."
    else "Um valor por fundo: mediana das linhas do numerador sobre a mediana das linhas do denominador na mesma competência.",
    if (rows > 1) sprintf("Este fundo tem %s linhas nesta data.", format_int(rows)),
    if (!is.null(history)) sprintf("Histórico do próprio fundo: média %s · desvio-padrão %s · %s valores (%s a %s).",
                                   format_compact_number(history$mean), format_compact_number(history$sd),
                                   format_int(history$n), history$first_month, history$last_month),
    fund_field_note_text(sub("\\|.*$", "", field))), collapse = "\n")
}

# Competência before `period` among the fund's rows (NULL when none).
fund_previous_period <- function(r, period) {
  p <- sort(unique(row_periods(r)))
  p <- p[p < period & p != "(sem período)"]
  if (length(p)) p[length(p)] else NULL
}

# Matrix of the tab Distribuições: r = rows of the fund (all periods), period =
# the competência of the Ficha, peers = fund_peer_summaries of that table and
# period, family = the fund's family; prev_peers / prev_period = the same for the
# fund's previous competência (trajectory), when known. Cells keep the field
# order of the Ficha; a panel lists the highlights, most atypical first.
fund_distribution_matrix_ui <- function(r, descriptions = NULL, table_name = NULL, period = NULL,
                                        peers = NULL, family = "", prev_peers = NULL, prev_period = NULL,
                                        mode = "rel", rows_of = NULL) {
  if (!nrow(r)) return(shiny::div(class = "tm-empty", "Sem linhas nesta tabela para o fundo."))
  if (is.null(period) || !nzchar(period)) return(shiny::div(class = "tm-empty", "Escolha a competência."))
  if (!is.null(attr(peers, "error"))) return(shiny::div(class = "tm-empty", paste("Erro ao ler os demais fundos:", attr(peers, "error"))))
  r <- fund_peer_split(r)
  at <- r[row_periods(r) == period, , drop = FALSE]
  own <- fund_peer_values(at)
  before <- if (is.null(prev_period) || is.null(prev_peers)) list() else fund_peer_values(r[row_periods(r) == prev_period, , drop = FALSE])
  history <- fund_field_distributions(r)
  fam <- toupper(family)
  # Items of the matrix: in mode Relativo each field with a base ratio is shown
  # as that ratio, the others as published, plus the analytic ratios.
  plan <- attr(peers, "plan")
  relative <- identical(mode, "rel") && !is.null(plan) && nrow(plan) > 0 && !is.null(rows_of)
  base_lab <- field_labels(names(own), descriptions, table_name)
  item <- function(key, field, v, s, prev_v, ratio = NULL, label = NULL) {
    i <- match(field, names(own))
    list(key = key, field = field, s = s, v = v, label = if (is.null(label)) base_lab$label[i] else label,
         derived = isTRUE(base_lab$derived[i]), ratio = ratio, prev_v = prev_v)
  }
  items <- list()
  if (relative) {
    rows_at <- function(dt, sp) { d <- rows_of(dt); if (is.null(d) || !nrow(d)) NULL else d[fund_shown_period(row_periods(d)) == sp, , drop = FALSE] }
    ov <- fund_ratio_inputs(plan, table_name, period, r, rows_at)
    orv <- fund_ratio_values(plan, table_name, ov)$values
    prv <- if (!is.null(prev_period) && !is.null(prev_peers))
      fund_ratio_values(plan, table_name, fund_ratio_inputs(plan, table_name, prev_period, r, rows_at))$values else list()
    for (fld in names(own)) {
      k <- paste0("r:", fld)
      if (!(k %in% plan$key)) { items[[length(items) + 1L]] <- item(fld, fld, unname(own[[fld]][1]), peers[[fld]],
                                                                    if (fld %in% names(before)) unname(before[[fld]][1])); next }
      if (is.null(orv[[k]])) next
      items[[length(items) + 1L]] <- item(k, fld, unname(orv[[k]][1]), peers[[k]], if (!is.null(prv[[k]])) unname(prv[[k]][1]))
    }
    for (k in plan$key[plan$kind == "analytic"]) {
      if (is.null(orv[[k]])) next
      items[[length(items) + 1L]] <- item(k, plan$field[plan$key == k], unname(orv[[k]][1]), peers[[k]],
                                          if (!is.null(prv[[k]])) unname(prv[[k]][1]))
    }
    items <- lapply(items, function(x) {
      if (!startsWith(x$key, "r:") && !startsWith(x$key, "a:")) return(x)
      pl <- plan[plan$key == x$key, , drop = FALSE]
      den <- fund_ratio_denominator(pl$den, pl$den_table, ov)
      dt <- if (pl$den_table == table_name) "" else pl$den_table
      den_fields <- unlist(lapply(fund_ratio_terms(pl$den), function(t) fund_ratio_term_fields(t, names(ov[[pl$den_table]]))))
      den_lab <- if (length(den_fields)) paste(field_labels(den_fields, descriptions, pl$den_table)$label, collapse = " + ") else pl$den
      x$ratio <- list(num_label = x$label, num = unname(own[[x$field]][1]), den = unname(den[1]), den_label = den_lab,
                      den_table = dt, kind = pl$kind)
      x$label <- fund_ratio_label(pl$label, x$label)
      x
    })
  } else {
    items <- lapply(names(own), function(fld) item(fld, fld, unname(own[[fld]][1]), peers[[fld]],
                                                   if (fld %in% names(before)) unname(before[[fld]][1])))
  }
  no_peer <- sum(vapply(items, function(x) is.null(x$s), logical(1)))
  items <- Filter(function(x) !is.null(x$s), items)
  if (!length(items)) return(shiny::div(class = "tm-empty", sprintf(
    "Nenhum campo numérico do fundo em %s tem ao menos %d fundos %s com valores distintos para comparar.",
    period, fund_peer_min_funds, fam)))
  stat <- lapply(items, function(x) {
    ps <- prev_peers[[x$key]]
    pv <- if (!is.null(x$prev_v) && !is.null(ps))
      list(period = prev_period, p = fund_peer_percentile(ps, x$prev_v), z = fund_peer_robust(ps, x$prev_v)$z)
    c(x, list(p = fund_peer_percentile(x$s, x$v), rb = fund_peer_robust(x$s, x$v), prev = pv,
              fmt = if (is.null(x$ratio)) format_compact_number else fund_ratio_pct))
  })
  az <- vapply(stat, function(x) if (is.na(x$rb$z)) -1 else abs(x$rb$z), numeric(1))
  # Charts keep the field order of the Ficha and the Série completa.
  lab <- list(label = vapply(stat, `[[`, "", "label"), derived = vapply(stat, function(x) isTRUE(x$derived) || !is.null(x$ratio), logical(1)))
  fields <- vapply(stat, `[[`, "", "key")
  levels <- vapply(stat, function(x) x$rb$level, "")
  cells <- lapply(seq_along(stat), function(i) {
    x <- stat[[i]]; d <- x$s; d$last <- x$v
    # Robust z axis on top (fund_distribution_svg): median of the peers on the display scale.
    d$zmed <- fund_scale_fwd(x$s$q[51], x$s$scale)
    tip <- fund_peer_tip(lab$label[i], x$field, x$s, x$v, x$p, family, period, nrow(at),
                         if (is.null(x$ratio)) history[[x$field]], x$rb, x$prev, x$fmt, x$ratio)
    lv <- c(`típico` = "tm-z-typ", `atípico` = "tm-z-atp", extremo = "tm-z-ext")[x$rb$level]
    shiny::div(class = paste("tm-dist", if (!is.na(lv)) lv), `data-tip` = trimws(tip),
               shiny::div(class = if (lab$derived[i]) "tm-dist-label tm-derived" else "tm-dist-label", lab$label[i]),
               htmltools::HTML(fund_distribution_svg(d, 200, 64, x$fmt, TRUE, lab$label[i])),
               shiny::div(class = "tm-dist-cap",
                          shiny::tags$b(class = "tm-dist-pos", fund_peer_text(x$p)),
                          if (!is.na(x$rb$z)) shiny::span(class = "tm-z-badge", paste("z", fund_peer_z_text(x$rb$z))),
                          if (!is.null(x$prev) && !is.na(x$prev$p)) shiny::span(
                            class = paste("tm-z-delta", if (x$p - x$prev$p >= 0) "tm-up" else "tm-down"),
                            paste0(if (x$p - x$prev$p >= 0) "▲" else "▼", formatC(abs(round(x$p - x$prev$p)), format = "d"))),
                          sprintf(" · fundo %s · %s fundos", x$fmt(x$v), format_int(x$s$n))))
  })
  # Highlights: the most atypical fields, with direction and trajectory.
  # Highlights: from the most to the least atypical (|robust z|).
  off <- order(-az); off <- off[levels[off] %in% c("atípico", "extremo")]
  top <- off[seq_len(min(6L, length(off)))]
  n_ext <- sum(levels == "extremo"); n_atp <- sum(levels == "atípico")
  highlights <- shiny::div(
    class = "tm-z-panel", `data-tip` = paste(
      "Z robusto: distância do fundo à mediana dos fundos da família na mesma competência, em desvios robustos",
      "(MAD escalonado, na escala log). |z| de 2 a 3,5 = atípico; 3,5 ou mais = extremo (Iglewicz e Hoaglin, 1993).",
      "Resistente aos valores extremos, que distorcem a média e o desvio-padrão. Descritivo: posição entre os pares,",
      "não um juízo sobre o fundo. ▲▼ = variação do percentil desde a competência anterior do fundo."),
    shiny::div(class = "tm-z-head",
               shiny::span(class = "tm-z-title", "Destaques estatísticos"),
               sprintf("%s de %s campos fora do típico: %s extremos, %s atípicos%s.",
                       format_int(n_ext + n_atp), format_int(length(stat)), format_int(n_ext), format_int(n_atp),
                       if (!is.null(prev_period)) paste0(" · comparação com ", prev_period) else "")),
    if (length(top)) shiny::tags$ol(class = "tm-z-list", lapply(top, function(i) {
      x <- stat[[i]]
      shiny::tags$li(class = if (x$rb$level == "extremo") "tm-z-ext" else "tm-z-atp",
                     shiny::span(class = "tm-z-name", lab$label[i]),
                     sprintf(" %s da mediana · fundo %s, mediana %s · %s · z %s%s",
                             if (x$rb$z > 0) "acima" else "abaixo", x$fmt(x$v), x$fmt(x$s$q[51]),
                             fund_peer_text(x$p), fund_peer_z_text(x$rb$z),
                             if (!is.null(x$prev) && !is.na(x$prev$p)) sprintf(" · antes %s", fund_peer_text(x$prev$p)) else ""))
    })) else shiny::div(class = "tm-z-none", "Todos os campos estão na faixa típica da família (|z| < 2)."))
  skipped <- if (no_peer > 0) sprintf("%s sem ao menos %d fundos com valores distintos",
                                      if (no_peer == 1) "1 campo" else paste(format_int(no_peer), "campos"), fund_peer_min_funds)
  shiny::tagList(
    shiny::div(class = "tm-caption", `data-tip` = paste0(
      "Cada gráfico compara o fundo com os demais fundos ", fam, " que publicaram o campo na mesma competência. ",
      "O percentil diz quantos por cento desses fundos têm valor menor que o do fundo (percentil 90 = maior que 90% deles). ",
      "Os gráficos seguem a ordem dos campos da Ficha e da Série completa; os destaques, do mais ao menos atípico (|z robusto|). Troque a competência no seletor de período da Ficha. ",
      "Passe o mouse em um gráfico para ver P25, mediana, P75, média, extremos e o histórico do próprio fundo."),
      sprintf("Posição do fundo entre os %s fundos %s na competência %s, campo a campo (%s, na ordem da Ficha): ",
              format_int(attr(peers, "funds")), fam, period,
              if (length(fields) == 1L) "1 campo numérico" else paste(format_int(length(fields)), "campos numéricos")),
      "barras = fundos por faixa de valor; curva = normal ajustada; tracejado = mediana; laranja = este fundo. ",
      "Passe o mouse para a explicação.",
      if (relative) paste0(" Valores relativos: cada item dividido pelo total da sua tabela, os totais pelo PL e razões analíticas ",
                           "(ex.: inadimplência sobre os direitos creditórios); campos sem regra aparecem como publicados.")
      else if (!is.null(plan) && nrow(plan)) " Valores absolutos, como publicados pela CVM.",
      if (length(skipped)) paste0(" Fora da matriz: ", skipped, ".") else ""),
    highlights,
    shiny::div(class = "tm-dist-grid", cells))
}

fund_page_size <- 25L
fund_card_columns <- 6L

# Sortable columns of the result list: header label and default direction
# (names A-Z; most recent and most reports first).
fund_sort_columns <- data.frame(by = c("name", "last", "count", "pl", "share"), label = c("Fundo", "Informes", "Nº", "PL", "%"),
                                decreasing = c(FALSE, TRUE, TRUE, TRUE, TRUE), stringsAsFactors = FALSE)
fund_sort_tips <- c(name = "Clique para ordenar; de novo para inverter",
                    last = "Clique para ordenar; de novo para inverter",
                    count = "Clique para ordenar; de novo para inverter",
                    pl = "Patrimônio líquido no mês de referência do tipo (último mês completo; para fundos fora dele, o último informe). Clique para ordenar",
                    share = "Participação do fundo no patrimônio total do seu tipo no mês de referência (mesma base do Panorama). Clique para ordenar")

# Published names such as "NA", "," or "0" carry no letters: shown as missing,
# sorted last, the stored value is unchanged.
has_name <- function(x) !is.na(x) & grepl("[[:alpha:]]", x) & x != "NA"
display_name <- function(x) ifelse(has_name(x), x, "(sem nome publicado)")

# Characteristics published by at least one of the families, in display order.
fund_scope_attributes <- function(families) {
  fund_attribute_order[vapply(fund_attribute_order, function(a) any(fund_attribute_families(a) %in% families), logical(1))]
}

# Columns of the list for the characteristics in scope: Cotistas and one per
# characteristic (attr_<name>), after the fixed ones.
fund_list_columns <- function(attrs = character(), holders = TRUE) {
  extra <- data.frame(by = c(if (holders) "holders", if (length(attrs)) paste0("attr_", attrs)),
                      label = c(if (holders) "Cotistas", unname(fund_attribute_short[attrs])),
                      decreasing = c(if (holders) TRUE, attrs %in% fund_attribute_numeric), stringsAsFactors = FALSE)
  rbind(fund_sort_columns, extra)
}

fund_column_tip <- function(by) {
  if (by %in% names(fund_sort_tips)) return(fund_sort_tips[[by]])
  if (by == "holders") return("Quantidade de cotistas no último informe que a publicou. Clique para ordenar")
  a <- sub("^attr_", "", by)
  sp <- fund_attribute_specs[fund_attribute_specs$attribute == a, , drop = FALSE]
  paste0(fund_attribute_labels[[a]], " (", paste(unique(paste(toupper(sp$family), sp$column)), collapse = "; "),
         "), último informe que o preencheu. Em branco: o informe da família não tem o campo; —: não preenchido. ",
         "Clique para ordenar")
}

# Adds the characteristics as attr_<name> columns (published values).
attach_fund_attributes <- function(rows, attributes) {
  if (is.null(attributes)) return(rows)
  w <- fund_attribute_wide(attributes, rows$family, rows$fund_cnpj)
  for (a in names(w)) rows[[paste0("attr_", a)]] <- w[[a]]
  rows
}

# Sort key of a characteristic: the number (percentages) or the folded text;
# a joined value (several classes) sorts by its first part.
attribute_sort_key <- function(v, attribute) {
  first <- sub(" / .*$", "", v)
  if (attribute %in% fund_attribute_numeric) suppressWarnings(as.numeric(first)) else fund_attribute_key(first)
}

sort_directory <- function(r, by, decreasing = NULL) {
  if (is.null(decreasing)) {
    decreasing <- fund_sort_columns$decreasing[match(by, fund_sort_columns$by)]
    if (is.na(decreasing)) decreasing <- by == "holders" || sub("^attr_", "", by) %in% fund_attribute_numeric
  }
  # Characteristic and quotaholder columns: funds without a value stay last.
  if (by == "holders" && !is.null(r$quotaholders)) {
    return(r[order(is.na(r$quotaholders), r$quotaholders, decreasing = c(FALSE, decreasing), method = "radix"), , drop = FALSE])
  }
  if (startsWith(by, "attr_") && !is.null(r[[by]])) {
    k <- attribute_sort_key(r[[by]], sub("^attr_", "", by))
    return(r[order(is.na(k), k, decreasing = c(FALSE, decreasing), method = "radix"), , drop = FALSE])
  }
  # Without PL data (no analytics context) the PL sorts fall back to the name.
  if (by %in% c("pl", "share") && is.null(r[[if (by == "pl") "net_assets" else "net_assets_share"]])) {
    by <- "name"; decreasing <- FALSE
  }
  key <- switch(by,
    last = order(r$last_period, decreasing = decreasing, method = "radix"),
    cnpj = order(r$fund_cnpj, decreasing = decreasing, method = "radix"),
    count = order(r$period_count, decreasing = decreasing, method = "radix"),
    # Funds without a value stay last in both directions.
    pl = order(is.na(r$net_assets), r$net_assets, decreasing = c(FALSE, decreasing), method = "radix"),
    share = order(is.na(r$net_assets_share), r$net_assets_share, decreasing = c(FALSE, decreasing), method = "radix"),
    # Missing names stay last in both directions.
    order(!has_name(r$fund_name), normalize_search_text(r$fund_name),
          decreasing = c(FALSE, decreasing), method = "radix"))
  r[key, , drop = FALSE]
}

# Clickable results: each row sends "family|cnpj" to the `pick` input; each
# sortable header sends its column to `sort_input` (click again to reverse).
results_table <- function(r, input_id, selected = NULL, sort_input = NULL, sort = NULL, attrs = character()) {
  keys <- paste(r$family, r$fund_cnpj, sep = "|")
  holders <- !is.null(r$quotaholders)
  columns <- fund_list_columns(attrs, holders)
  # Characteristic cells: blank when the family's report lacks the field, "—"
  # when not filled, else the published value (sim/não, percent, text).
  extra_cells <- function(i) {
    c(if (holders) list(shiny::tags$td(class = "tm-num", `data-tip` = if (!is.na(r$quotaholders_month[i]))
                                         sprintf("Cotistas em %s", month_label(r$quotaholders_month[i])),
                                       format_int(r$quotaholders[i]))),
      lapply(attrs, function(a) {
        if (!r$family[i] %in% fund_attribute_families(a))
          return(shiny::tags$td(class = "tm-attr tm-muted", `data-tip` = sprintf("O informe de %s não tem este campo.", toupper(r$family[i])), ""))
        v <- r[[paste0("attr_", a)]][i]
        text <- if (is.na(v)) "—" else fund_attribute_value_text(a, v)
        shiny::tags$td(class = paste("tm-attr", if (a %in% fund_attribute_numeric) "tm-num", if (is.na(v)) "tm-muted",
                                     if (fund_attribute_alert(a, v)) "tm-attr-alert"), text)
      }))
  }
  rows <- lapply(seq_len(nrow(r)), function(i) {
    shiny::tags$tr(
      `data-key` = keys[i], class = if (identical(keys[i], selected)) "tm-selected",
      shiny::tags$td(
        shiny::div(class = "tm-id",
                   shiny::span(class = paste0("tm-tag tm-tag-", r$family[i]), toupper(r$family[i])),
                   shiny::span(class = "tm-mono", if (is.null(r$cnpj_formatted)) r$fund_cnpj_original[i]
                                                  else r$cnpj_formatted[i]),
                   if (!is.null(r$name_count) && isTRUE(r$name_count[i] > 1L))
                     shiny::span(class = "tm-names-badge", `data-tip` = "Denominações diferentes ao longo do tempo; veja a aba Denominações.",
                                 sprintf("%d nomes", r$name_count[i]))),
        shiny::div(class = if (has_name(r$fund_name[i])) "tm-fund" else "tm-fund tm-muted",
                   display_name(r$fund_name[i])),
        shiny::div(class = "tm-admin", {
          a <- if (is.null(r$administrator_display)) r$administrator_name[i] else r$administrator_display[i]
          if (is.na(a)) "administrador não publicado" else a
        })),
      shiny::tags$td(class = "tm-mono", substr(r$first_period[i], 1, 7), shiny::br(),
                     substr(r$last_period[i], 1, 7)),
      shiny::tags$td(class = "tm-num", format_count(r$period_count[i])),
      shiny::tags$td(class = "tm-num", `data-tip` = if (!is.null(r$net_assets_month) && !is.na(r$net_assets_month[i]))
                       sprintf("PL em %s", month_label(r$net_assets_month[i])),
                     if (is.null(r$net_assets)) "—" else format_brl(r$net_assets[i])),
      shiny::tags$td(class = "tm-num",
                     if (is.null(r$net_assets_share) || is.na(r$net_assets_share[i])) "—"
                     else format_share(r$net_assets_share[i])),
      extra_cells(i))
  })
  header <- lapply(seq_len(nrow(columns)), function(k) {
    col <- columns[k, ]
    active <- !is.null(sort) && identical(sort$by, col$by)
    arrow <- if (active) (if (isTRUE(sort$decreasing)) " ▼" else " ▲") else ""
    num <- col$by %in% c("count", "pl", "share", "holders") || sub("^attr_", "", col$by) %in% fund_attribute_numeric
    shiny::tags$th(class = paste("tm-sortable", if (active) "tm-sorted", if (num) "tm-num",
                                 if (startsWith(col$by, "attr_")) "tm-attr"),
                   `data-sort` = col$by, title = paste0(fund_column_tip(col$by), fund_hint_tip_text(sub("^attr_", "", col$by))),
                   paste0(col$label, arrow))
  })
  shiny::tags$table(
    class = paste("tm-results", if (length(attrs) || holders) "tm-results-wide"),
    `data-input` = input_id, `data-sort-input` = sort_input,
    shiny::tags$thead(shiny::tags$tr(header)),
    shiny::tags$tbody(rows))
}

# Administrator options: one per denomination with the CNPJ and the number of
# funds of the entity (most funds first); the value resolves to the entity.
administrator_choices <- function(master, directory) {
  d <- directory[!is.na(directory$administrator_entity), , drop = FALSE]
  d <- d[!duplicated(paste(d$administrator_entity, d$family, d$fund_entity)), , drop = FALSE]
  funds <- table(d$administrator_entity)
  n <- master$entity_names[master$entity_names$entity_id %in% names(funds), , drop = FALSE]
  if (!nrow(n)) return(character())
  n$funds <- as.integer(funds[n$entity_id])
  n <- n[order(-n$funds, normalize_search_text(n$display_name), method = "radix"), , drop = FALSE]
  cnpj <- master$entities$cnpj_formatted[match(n$entity_id, master$entities$entity_id)]
  stats::setNames(n$name_id, sprintf("%s — %s (%s fundos)", ifelse(is.na(cnpj), "sem CNPJ", cnpj),
                                     n$display_name, format_count(n$funds)))
}

# Readable label for a CVM field code when the META dictionary has no
# description: underscores to spaces, sentence case.
humanize_field <- function(field) {
  y <- gsub("_+", " ", field)
  y <- ifelse(grepl("[a-z]", y), y, tolower(y))
  paste0(toupper(substr(y, 1, 1)), substr(y, 2, nchar(y)))
}

# Field labels: the META description when published, else the humanized code
# (marked `derived`). The code itself goes to the tooltip.
# Virtual fields "<field>|<type>" (fund_peer_split) take the label of the field
# followed by the type ("Valor total · Captações no Mês").
field_labels <- function(fields, descriptions = NULL, table_name = NULL) {
  base <- sub("\\|.*$", "", fields)
  op <- ifelse(grepl("|", fields, fixed = TRUE), sub("^[^|]*\\|", "", fields), NA_character_)
  desc <- if (is.null(descriptions) || is.null(table_name)) rep(NA_character_, length(fields))
          else describe_fields(descriptions, table_name, base)
  label <- ifelse(is.na(desc), humanize_field(base), desc)
  data.frame(field = fields, label = ifelse(is.na(op), label, paste0(label, " · ", op)),
             derived = is.na(desc), stringsAsFactors = FALSE)
}

# One report row: fields as a compact two-column grid (label above value).
ficha_grid <- function(r, labels) {
  items <- lapply(seq_len(nrow(labels)), function(k) {
    v <- r[[labels$field[k]]][1]
    shiny::div(class = "tm-ficha-item",
               shiny::div(class = if (labels$derived[k]) "tm-ficha-label tm-derived" else "tm-ficha-label",
                          `data-tip` = paste0(sprintf("%s\nCampo CVM: %s%s", labels$label[k], labels$field[k],
                                                       if (labels$derived[k]) " (sem descrição no dicionário)" else ""),
                                               fund_field_note_text(labels$field[k])),
                          labels$label[k]),
               {
                 d <- display_value(v, labels$field[k])
                 shiny::div(class = if (d$num) "tm-ficha-value tm-num" else "tm-ficha-value", d$text)
               })
  })
  cite <- if (is.na(r$source_url[1])) r$citation[1]
          else shiny::tags$a(href = r$source_url[1], target = "_blank", rel = "noopener", r$citation[1])
  shiny::tagList(shiny::div(class = "tm-ficha-cite", "Fonte: ", cite), shiny::div(class = "tm-ficha", items))
}

# One column per report row of the chosen period, one line per CVM field.
# Fields empty in every shown row are left out (counted in `hidden`).
report_card <- function(r, descriptions = NULL, table_name = NULL) {
  r <- utils::head(r, fund_card_columns)
  fields <- setdiff(names(r), c("citation", "source_url", "zip_sha256", "source_file", "source_line",
                                "fund_cnpj_normalized", "reference_period", "layout_version"))
  filled <- vapply(fields, function(f) any(!is.na(r[[f]]) & nzchar(trimws(r[[f]]))), logical(1))
  labels <- field_labels(fields[filled], descriptions, table_name)
  if (nrow(r) == 1L) return(structure(ficha_grid(r, labels), hidden = sum(!filled)))
  cite <- lapply(seq_len(nrow(r)), function(i) {
    text <- r$citation[i]
    shiny::tags$th(if (is.na(r$source_url[i])) text
                   else shiny::tags$a(href = r$source_url[i], target = "_blank", rel = "noopener", text))
  })
  body <- lapply(seq_len(nrow(labels)), function(k) {
    f <- labels$field[k]
    shiny::tags$tr(shiny::tags$th(class = if (labels$derived[k]) "tm-field tm-derived" else "tm-field",
                                  `data-tip` = paste0(sprintf("%s\nCampo CVM: %s%s", labels$label[k], f,
                                                               if (labels$derived[k]) " (sem descrição no dicionário)" else ""),
                                                       fund_field_note_text(f)),
                                  labels$label[k]),
                   lapply(r[[f]], function(v) value_cell(v, f)))
  })
  structure(shiny::tags$table(
    class = "tm-card-table",
    shiny::tags$thead(shiny::tags$tr(shiny::tags$th(class = "tm-field", "Campo"), cite)),
    shiny::tags$tbody(body)), hidden = sum(!filled))
}

# Full series, transposed like a financial statement: one line per CVM field
# with the same labels as the Ficha (dictionary description; italic when the
# dictionary has none; field code on hover), one column per report row, most
# recent period first. Each column header is the period, linked to the CVM
# file, with the full citation on hover. Fields empty in every row are left
# out (counted in `hidden`). Built as text: a tag object per cell took ~25 s
# for a FIDC with 165 periods and ~80 fields.
wide_table <- function(r, descriptions = NULL, table_name = NULL) {
  fields <- setdiff(names(r), c("citation", "source_url", "zip_sha256", "source_file", "source_line",
                                "fund_cnpj_normalized", "reference_period", "layout_version"))
  if (nrow(r)) r <- r[order(row_periods(r), decreasing = TRUE, method = "radix"), , drop = FALSE]
  filled <- vapply(fields, function(f) any(!is.na(r[[f]]) & nzchar(trimws(r[[f]]))), logical(1))
  labels <- field_labels(fields[filled], descriptions, table_name)
  period <- if (nrow(r)) row_periods(r) else character()
  period <- ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", period), substr(period, 1, 7), period)
  cite <- if (is.null(r$citation)) rep("", nrow(r)) else escape_html(r$citation)
  url <- if (is.null(r$source_url)) rep(NA_character_, nrow(r)) else r$source_url
  head <- paste0(ifelse(is.na(url),
                        sprintf('<th class="tm-col-period" title="%s">%s</th>', cite, escape_html(period)),
                        sprintf('<th class="tm-col-period" title="%s"><a href="%s" target="_blank" rel="noopener">%s</a></th>',
                                cite, escape_html(url), escape_html(period))), collapse = "")
  body <- vapply(seq_len(nrow(labels)), function(k) {
    f <- labels$field[k]
    d <- display_values(r[[f]], f)
    tip <- paste0(sprintf("%s\nCampo CVM: %s%s", labels$label[k], f,
                          if (labels$derived[k]) " (sem descrição no dicionário)" else ""), fund_field_note_text(f))
    paste0('<tr><th class="', if (labels$derived[k]) "tm-field tm-derived" else "tm-field", '" data-tip="',
           escape_html(tip), '">', escape_html(labels$label[k]), "</th>",
           paste0("<td", ifelse(d$num, ' class="tm-num"', ""), ">", escape_html(d$text), "</td>", collapse = ""),
           "</tr>")
  }, character(1))
  structure(htmltools::HTML(sprintf(
    '<table class="tm-wide tm-series"><thead><tr><th class="tm-field">Campo</th>%s</tr></thead><tbody>%s</tbody></table>',
    head, paste0(body, collapse = ""))), hidden = sum(!filled))
}

row_periods <- function(r) {
  p <- first_present(r, fund_period_columns)
  ifelse(is.na(p), "(sem período)", substr(p, 1, 10))
}

# Characteristic filters of the families in scope: a collapsible panel whose
# summary counts the active filters (fund_search_server, output$attr_active);
# inside, a grid of labelled fields: a select per category (options filled by
# the server from the data: Todos, the published values, Não informado, Não
# consta do informe) and min/max for quotaholders and the subscribed percentage.
# A value keeps only the families whose report has the field.
fund_attribute_filters_ui <- function(ns, families) {
  attrs <- fund_scope_attributes(families)
  field <- function(label, tip, ..., info = NULL) shiny::div(class = "tm-cf", `data-tip` = tip,
                                                 shiny::tags$label(class = "tm-cf-label", label, info), ...)
  range <- function(id, label, tip, step, unit = NULL) field(label, tip, shiny::div(
    class = "tm-cf-range",
    shiny::numericInput(ns(paste0(id, "_min")), NULL, value = NA, min = 0, step = step, width = "100%"),
    shiny::span(class = "tm-cf-sep", "a"),
    shiny::numericInput(ns(paste0(id, "_max")), NULL, value = NA, min = 0, step = step, width = "100%"),
    if (!is.null(unit)) shiny::span(class = "tm-cf-sep", unit)))
  selects <- lapply(setdiff(fund_display_attributes(families), fund_attribute_numeric), function(a) {
    sp <- fund_attribute_specs[fund_attribute_specs$attribute == a & fund_attribute_specs$family %in% families, , drop = FALSE]
    tip <- if (!nrow(sp)) paste0(fund_attribute_labels[[a]], ": o informe da CVM de ",
                                 paste(toupper(families), collapse = ", "), " não tem este campo.")
           else paste0(fund_attribute_labels[[a]], " (", paste(unique(paste(toupper(sp$family), sp$column)), collapse = "; "),
                       "), último informe que o preencheu. Com um valor escolhido, ficam só os fundos das famílias cujo informe tem o campo; ",
                       "\"Não consta do informe\" seleciona os das demais famílias.", fund_field_note_text(sp$column[1]))
    field(fund_attribute_medium[[a]], paste0(tip, fund_hint_tip_text(a)),
          shiny::selectInput(ns(paste0("attr_", a)), NULL, width = "100%", selectize = FALSE, choices = c(Todos = "")))
  })
  shiny::tags$details(
    class = "tm-cf-panel",
    shiny::tags$summary(class = "tm-cf-summary",
                        shiny::span(class = "tm-cf-title", "Características"),
                        shiny::uiOutput(ns("attr_active"), inline = TRUE),
                        shiny::span(class = "tm-cf-hint", "cotistas, condomínio, público-alvo, direitos e outras; clique para abrir")),
    shiny::div(class = "tm-cf-grid",
               range("holders", "Cotistas", "Quantidade de cotistas no último informe que a publicou (mínimo e máximo).", 1),
               selects,
               if ("subscribed_pct" %in% attrs)
                 range("subscribed", "Cotas subscritas", paste("Percentual total das cotas subscritas (FIP, PR_TOTAL_COTA_SUBSCR),",
                                                               "mínimo e máximo; com várias classes, basta uma no intervalo."), 0.01, "%"),
               shiny::div(class = "tm-cf-actions",
                          shiny::actionLink(ns("attr_clear"), "Limpar características", class = "tm-link"))))
}

fund_search_ui <- function(id, family = NULL) {
  ns <- shiny::NS(id)
  title <- if (is.null(family)) "Informes de fundos da CVM"
           else sprintf("%s · %s", toupper(family), fund_family_names[[family]])
  page <- shiny::div(
    class = "tm-page tm-fill-page",
    shiny::tags$script(shiny::HTML(
      "if (!window.tmResultsBound) {
         window.tmResultsBound = true;
         $(document).on('click', 'table.tm-results tbody tr[data-key]', function() {
           var t = $(this).closest('table');
           t.find('tr.tm-selected').removeClass('tm-selected');
           $(this).addClass('tm-selected');
           // The detail of the new fund opens on Perfil; the old one fades until it arrives.
           var d = $(this).closest('.tm-page').find('.tm-detail');
           if (String($(this).data('key')) !== String(d.attr('data-fund'))) {
             d.addClass('tm-refreshing');
             d.find('.nav-link[data-value=\"Perfil\"]').tab('show');
           }
           Shiny.setInputValue(t.data('input'), $(this).data('key'), {priority: 'event'});
         });
         $(document).on('click', 'table.tm-results th[data-sort]', function() {
           Shiny.setInputValue($(this).closest('table').data('sort-input'), $(this).data('sort'),
                               {priority: 'event'});
         });
       }")),
    shiny::div(class = "tm-dash-head",
               shiny::div(shiny::span(class = "tm-eyebrow", if (is.null(family)) "Fundos · Fase 1.3"
                                                            else paste("Fundos", toupper(family), "· Fase 1.3")),
                          shiny::h1(title)),
               shiny::div(class = "tm-dash-meta", shiny::uiOutput(ns("kpis"), inline = TRUE))),
    # Filter bar: applies as you choose. Fund and administrator take options
    # from the entity catalog (several allowed) or free text (CNPJ with or
    # without mask, current or former name, abbreviation).
    shiny::div(
      class = "tm-filterbar",
      if (is.null(family)) shiny::div(class = "tm-filter tm-filter-family",
                 shiny::checkboxGroupInput(ns("family"), NULL, choices = fund_family_labels,
                                           selected = unname(fund_family_labels), inline = TRUE)),
      shiny::div(class = "tm-filter tm-filter-wide",
                 shiny::selectizeInput(ns("fund_query"), NULL, choices = NULL, width = "100%", multiple = TRUE,
                                       options = entity_autocomplete_options("Fundo: CNPJ ou nome (atual ou anterior)"))),
      shiny::div(class = "tm-filter tm-filter-wide",
                 shiny::selectizeInput(ns("administrator"), NULL, choices = NULL, width = "100%", multiple = TRUE,
                                       options = entity_autocomplete_options("Administrador: CNPJ ou nome"))),
      shiny::div(class = "tm-filter tm-filter-period",
                 shiny::selectizeInput(ns("period_from"), NULL, choices = NULL, width = "100%",
                                       options = autocomplete_options("De (aaaa-mm)"))),
      shiny::div(class = "tm-filter tm-filter-period",
                 shiny::selectizeInput(ns("period_to"), NULL, choices = NULL, width = "100%",
                                       options = autocomplete_options("Até (aaaa-mm)"))),
      shiny::actionLink(ns("clear"), "Limpar", class = "tm-link tm-filter-clear",
                        title = "Limpar todos os filtros")),
    fund_attribute_filters_ui(ns, if (is.null(family)) unname(fund_family_labels) else family),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, xl = c(5, 7)), class = "tm-master-detail",
      fill = TRUE, row_heights = "minmax(0, 1fr)",
      bslib::card(
        class = "tm-section tm-pane",
        bslib::card_header(class = "tm-card-head",
                           shiny::div(class = "tm-card-title", shiny::textOutput(ns("summary"), inline = TRUE)),
                           shiny::span(class = "tm-head-note", "clique no cabeçalho para ordenar")),
        bslib::card_body(padding = 0, class = "tm-scroll", shiny::uiOutput(ns("funds"))),
        bslib::card_footer(class = "tm-pager",
                           shiny::actionLink(ns("prev"), "‹ Anterior"),
                           shiny::span(class = "tm-muted", shiny::textOutput(ns("page"), inline = TRUE)),
                           shiny::actionLink(ns("next_page"), "Próxima ›"))),
      shiny::div(class = "tm-pane-wrap", shiny::uiOutput(ns("detail"), fill = TRUE),
                 shiny::div(class = "tm-empty tm-hint", "Selecione um fundo na lista."))))
  # Fills the window (page_navbar fillable): list and detail stay inside the
  # window; the page itself never scrolls.
  htmltools::bindFillRole(page, container = TRUE, item = TRUE)
}

# Everything the fund areas read, loaded once and shared by every tab.
fund_search_data <- function(root, directory = load_fund_directory(root), rules = load_entity_rules(),
                             master = load_entity_master(root, directory, rules)) {
  urls <- fund_source_urls(root)
  list(directory = annotate_directory_entities(directory), master = master, rules = rules,
       tables = fund_tables(root), urls = urls, report_rows = fund_rows_cache(root, urls), peers = fund_peer_cache(root),
       descriptions = fund_field_descriptions(root), investment_entity = fund_investment_entity(root),
       attributes = fund_attributes(root))
}

# Denominations of an entity over time: a separate analytical view; the
# filters always keep the whole CNPJ history.
name_timeline_ui <- function(master, entity_id) {
  t <- entity_name_timeline(master, entity_id)
  if (!nrow(t)) return(shiny::div(class = "tm-empty", "Sem denominações registradas."))
  rows <- lapply(seq_len(nrow(t)), function(i) {
    shiny::tags$tr(
      shiny::tags$td(shiny::div(class = "tm-fund", t$denomination[i]),
                     if (t$original_name[i] != t$denomination[i])
                       shiny::div(class = "tm-admin", "publicado como: ", t$original_name[i]),
                     if (isTRUE(t$needs_review[i])) shiny::span(class = "tm-review", `data-tip` =
                       "Parecida com outra denominação deste CNPJ, mas não equivalente pelas regras: em revisão.",
                       "revisar")),
      shiny::tags$td(toupper(t$source[i])),
      shiny::tags$td(class = "tm-mono", substr(t$first_observed_period[i], 1, 7)),
      shiny::tags$td(class = "tm-mono", substr(t$last_observed_period[i], 1, 7)),
      shiny::tags$td(class = "tm-num", format_count(t$observed_periods[i])))
  })
  shiny::tagList(
    shiny::div(class = "tm-caption",
               sprintf("%d denominações após as regras de equivalência (versão %s). Datas são de observação nos informes, não de vigência jurídica.",
                       length(unique(t$name_id)), master$rule_version)),
    shiny::tags$table(class = "tm-card-table tm-timeline",
                      shiny::tags$thead(shiny::tags$tr(shiny::tags$th("Denominação"), shiny::tags$th("Família"),
                                                       shiny::tags$th("Primeira"), shiny::tags$th("Última"),
                                                       shiny::tags$th(class = "tm-num", "Períodos"))),
                      shiny::tags$tbody(rows)))
}

# `analytics` (fund_analytics_context) adds the fund profile tab when given;
# `families` fixes the family (one tab per fund type).
fund_search_server <- function(id, root, analytics = NULL, data = NULL, families = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    if (is.null(data)) data <- fund_search_data(root)
    directory <- data$directory
    master <- data$master
    tables <- data$tables
    urls <- data$urls
    report_rows <- if (is.null(data$report_rows)) fund_rows_cache(root, urls) else data$report_rows
    peers <- if (is.null(data$peers)) fund_peer_cache(root) else data$peers
    descriptions <- data$descriptions
    scope <- if (is.null(families)) unname(fund_family_labels) else families
    in_scope <- directory[directory$family %in% scope, , drop = FALSE]
    holders <- if (is.null(analytics$m)) NULL else fund_latest_quotaholders(analytics$m)
    scope_attrs <- fund_scope_attributes(scope)
    category_attrs <- setdiff(fund_display_attributes(scope), fund_attribute_numeric)
    # Options of the characteristic filters, from the published values in scope.
    for (a in category_attrs) {
      ch <- if (is.null(data$attributes)) character() else fund_attribute_choices(data$attributes, a, scope)
      shiny::updateSelectInput(session, paste0("attr_", a), choices = c(Todos = "", ch,
        if (any(scope %in% fund_attribute_families(a))) c(`Não informado` = "NA"),
        if (!all(scope %in% fund_attribute_families(a))) c(`Não consta do informe` = "NC")))
    }
    num_or_na <- function(v) if (is.null(v) || !length(v) || is.na(v)) NA_real_ else as.numeric(v)
    # Columns of the list: the characteristics of the checked families.
    list_attrs <- shiny::reactive(fund_scope_attributes(if (is.null(families)) input$family else families))

    shiny::updateSelectizeInput(session, "fund_query", choices = fund_choices(master, in_scope),
                                selected = character(), server = TRUE)
    shiny::updateSelectizeInput(session, "administrator", choices = administrator_choices(master, in_scope),
                                selected = character(), server = TRUE)
    periods <- period_choices(in_scope)
    shiny::updateSelectizeInput(session, "period_from", choices = periods, selected = character())
    shiny::updateSelectizeInput(session, "period_to", choices = periods, selected = character())

    clear_attributes <- function() {
      for (a in category_attrs) shiny::updateSelectInput(session, paste0("attr_", a), selected = "")
      for (n in c("holders_min", "holders_max", "subscribed_min", "subscribed_max")) shiny::updateNumericInput(session, n, value = NA)
    }
    shiny::observeEvent(input$attr_clear, clear_attributes())
    # Number of characteristic filters in use, shown on the closed panel.
    output$attr_active <- shiny::renderUI({
      n <- sum(vapply(category_attrs, function(a) { v <- input[[paste0("attr_", a)]]; !is.null(v) && nzchar(v) }, logical(1))) +
        sum(!is.na(num_or_na(input$holders_min)) | !is.na(num_or_na(input$holders_max))) +
        sum(!is.na(num_or_na(input$subscribed_min)) | !is.na(num_or_na(input$subscribed_max)))
      if (n) shiny::span(class = "tm-cf-count", sprintf("%d %s", n, if (n == 1) "filtro ativo" else "filtros ativos"))
    })
    shiny::observeEvent(input$clear, {
      if (is.null(families)) shiny::updateCheckboxGroupInput(session, "family", selected = unname(fund_family_labels))
      for (field in c("fund_query", "administrator", "period_from", "period_to")) {
        shiny::updateSelectizeInput(session, field, selected = character())
      }
      clear_attributes()
    })

    # Filters apply as soon as a value is chosen (no search button). Any
    # option of an entity resolves to its id, so every name returns the
    # whole CNPJ history; one line per fund and family.
    results <- shiny::reactive({
      fam <- if (is.null(families)) input$family else families
      tryCatch({
        rows <- search_fund_entities(
          directory, family = fam,
          funds = resolve_entity_query(input$fund_query, master, "fund", data$rules),
          administrators = resolve_entity_query(input$administrator, master, "administrator", data$rules),
          period_from = input$period_from, period_to = input$period_to)
        out <- fund_list(rows, master)
        out <- attach_fund_attributes(out, data$attributes)
        filters <- stats::setNames(lapply(category_attrs, function(a) input[[paste0("attr_", a)]]), category_attrs)
        if ("subscribed_pct" %in% scope_attrs) filters$subscribed_pct <- c(num_or_na(input$subscribed_min), num_or_na(input$subscribed_max))
        out <- filter_fund_attributes(out, data$attributes, filters)
        if (!is.null(holders)) {
          out <- attach_fund_quotaholders(out, holders)
          lo <- num_or_na(input$holders_min); hi <- num_or_na(input$holders_max)
          if (!is.na(lo) || !is.na(hi)) out <- out[!is.na(out$quotaholders) & (is.na(lo) | out$quotaholders >= lo) &
                                                   (is.na(hi) | out$quotaholders <= hi), , drop = FALSE]
        }
        if (!is.null(analytics$fund_pl)) out <- attach_fund_net_assets(out, analytics$fund_pl)
        structure(out, rows = rows)
      }, error = function(e) structure(fund_list(directory[0, ], master), rows = directory[0, ],
                                       error = conditionMessage(e)))
    })

    # Header clicks: a new column sorts in its default direction, the same
    # column again reverses it.
    sort_state <- shiny::reactiveVal(list(by = "pl", decreasing = TRUE))  # largest funds first
    shiny::observeEvent(input$sort_col, {
      s <- sort_state()
      by <- input$sort_col
      cols <- fund_list_columns(list_attrs(), !is.null(holders))
      if (!by %in% cols$by) return()
      sort_state(if (identical(s$by, by)) list(by = by, decreasing = !s$decreasing)
                 else list(by = by, decreasing = cols$decreasing[cols$by == by]))
    })

    sorted <- shiny::reactive({
      r <- results()
      if (nrow(r) == 0L) return(r)
      s <- sort_state()
      sort_directory(r, s$by, s$decreasing)
    })

    page <- shiny::reactiveVal(1L)
    pages <- shiny::reactive(max(1L, ceiling(nrow(sorted()) / fund_page_size)))
    shiny::observeEvent(sorted(), page(1L))
    shiny::observeEvent(input$prev, page(max(1L, page() - 1L)))
    shiny::observeEvent(input$next_page, page(min(pages(), page() + 1L)))

    picked <- shiny::reactiveVal(NULL)
    # Funds the user clicked (the app's current fund, prototype/app.R).
    chosen <- shiny::reactiveVal(NULL)
    shiny::observeEvent(input$pick, { picked(input$pick); chosen(input$pick) })
    # A new search selects its first fund, so the detail is never stale; the
    # fund already selected stays when the new list still has it.
    shiny::observeEvent(results(), {
      sort_state(list(by = "pl", decreasing = TRUE))
      r <- sorted()
      keys <- paste(r$family, r$fund_cnpj, sep = "|")
      p <- shiny::isolate(picked())
      if (is.null(p) || !p %in% keys) picked(if (nrow(r)) keys[1] else NULL)
    })

    output$kpis <- shiny::renderUI({
      r <- attr(results(), "rows")
      funds <- length(unique(r$fund_entity))
      span <- if (nrow(r)) sprintf("%s – %s", substr(min(r$first_period, na.rm = TRUE), 1, 7),
                                   substr(max(r$last_period, na.rm = TRUE), 1, 7)) else "—"
      admins <- length(unique(stats::na.omit(r$administrator_entity)))
      shiny::span(class = "tm-strip",
                  shiny::tags$b(format_count(funds)), " fundos · ", shiny::tags$b(format_count(admins)),
                  " administradores · ", shiny::tags$b(length(unique(r$family))), if (length(unique(r$family)) == 1L) " família · " else " famílias · ",
                  shiny::tags$b(span))
    })

    output$summary <- shiny::renderText({
      r <- results()
      if (!is.null(attr(r, "error"))) return(paste("Erro:", attr(r, "error")))
      sprintf("%s %s", format_count(nrow(r)), if (nrow(r) == 1L) "fundo" else "fundos")
    })

    output$page <- shiny::renderText(sprintf("Página %d de %d", page(), pages()))

    output$funds <- shiny::renderUI({
      r <- sorted()
      if (nrow(r) == 0L) return(shiny::div(class = "tm-empty", "Nenhum fundo com esses filtros."))
      first <- (page() - 1L) * fund_page_size + 1L
      r <- r[first:min(nrow(r), first + fund_page_size - 1L), , drop = FALSE]
      results_table(r, ns("pick"), picked(), ns("sort_col"), sort_state(), attrs = list_attrs())
    })

    selected <- shiny::reactive({
      shiny::req(picked())
      parts <- strsplit(picked(), "|", fixed = TRUE)[[1]]
      info <- directory[directory$family == parts[1] & directory$fund_cnpj == parts[2], , drop = FALSE]
      info <- info[order(!has_name(info$fund_name), info$last_period, decreasing = c(FALSE, TRUE), method = "radix"), ]
      list(family = parts[1], cnpj = parts[2], info = info, entity = info$fund_entity[1])
    })

    output$detail <- shiny::renderUI({
      s <- selected()
      i <- s$info[1, ]
      t <- tables[tables$family == s$family, , drop = FALSE]
      e <- master$entities
      ent <- e[match(s$entity, e$entity_id), ]
      admin_ids <- unique(stats::na.omit(s$info$administrator_entity[order(s$info$last_period, decreasing = TRUE)]))
      admins <- ifelse(is.na(match(admin_ids, e$entity_id)), admin_ids, e$display_name[match(admin_ids, e$entity_id)])
      bslib::card(
        class = "tm-section tm-detail tm-pane", `data-fund` = paste(s$family, s$cnpj, sep = "|"),
        bslib::card_header(
          class = "tm-detail-head",
          # Name and identification on the left, the return curve beside it.
          shiny::div(class = "tm-detail-top", shiny::div(class = "tm-detail-id",
          shiny::div(class = "tm-eyebrow", sprintf("%s · %s", toupper(s$family), format_cnpj(i$fund_cnpj_original))),
          shiny::h2(class = "tm-detail-title", if (is.na(ent$display_name)) display_name(i$fund_name) else ent$display_name),
          shiny::div(class = "tm-detail-meta",
                     shiny::span(shiny::strong("Administrador: "),
                                 if (length(admins)) paste(admins, collapse = "; ") else "não publicado"),
                     shiny::span(shiny::strong("Informes: "),
                                 sprintf("%s a %s", substr(min(s$info$first_period), 1, 7),
                                         substr(max(s$info$last_period), 1, 7))),
                     if (isTRUE(ent$name_count > 1L))
                       shiny::span(shiny::strong("Denominações: "), ent$name_count)),
            # Characteristics stay in the left column, beside the return curve.
            fund_traits_ui(data$attributes, s$family, s$cnpj,
                           if (!is.null(analytics)) fund_profile(analytics$m, analytics$snapshot, s$family, s$cnpj))),
            fund_return_ui(root, s$family, s$cnpj))),
        bslib::card_body(
          fillable = FALSE, class = "tm-detail-body",
          bslib::layout_columns(
            col_widths = c(8, 4), class = "tm-detail-tools",
            shiny::selectizeInput(ns("table"), NULL, width = "100%",
                                  choices = stats::setNames(t$table_name, sprintf(
                                    "%s  (%s–%s)", fund_table_label(t$table_name), t$first_period, t$last_period)),
                                  selected = t$table_name[grepl("geral|tab_I$|fip$|fiagro$",
                                                                t$table_name)][1]),
            shiny::selectizeInput(ns("period"), NULL, choices = NULL, width = "100%",
                                  options = list(placeholder = "Período"))),
          shiny::div(class = "tm-caption", shiny::textOutput(ns("rows_summary"))),
          bslib::navset_underline(
            if (!is.null(analytics)) bslib::nav_panel("Perfil", shiny::uiOutput(ns("profile"))),
            bslib::nav_panel("Ficha", shiny::div(class = "tm-table-wrap", shiny::uiOutput(ns("card")))),
            bslib::nav_panel("Série completa",
                             shiny::div(class = "tm-table-wrap tm-tall", shiny::uiOutput(ns("rows")))),
            bslib::nav_panel("Distribuições",
                             shiny::div(class = "tm-table-wrap tm-tall", shiny::uiOutput(ns("dists")))),
            bslib::nav_item(shiny::div(class = "tm-dist-mode", title = "Valores das distribuições: relativos (itens / total da tabela, totais / PL, razões analíticas) ou absolutos, como publicados", shiny::radioButtons(ns("dist_mode"), NULL, c(Relativo = "rel", Absoluto = "abs"), "rel", inline = TRUE))),
            bslib::nav_panel("Denominações", shiny::div(class = "tm-table-wrap", shiny::uiOutput(ns("names")))))))
    })

    output$names <- shiny::renderUI(name_timeline_ui(master, selected()$entity))
    # One normal curve per numeric field of the chosen table: the funds of the
    # family at the competência of the Ficha, with this fund marked.
    output$dists <- shiny::renderUI({
      r <- rows()
      if (!is.null(attr(r, "error"))) return(shiny::div(class = "tm-empty", paste("Erro:", attr(r, "error"))))
      s <- selected(); shiny::req(input$period)
      p <- tryCatch(peers(s$family, input$table, input$period), error = function(e) structure(list(), error = conditionMessage(e)))
      pp <- fund_previous_period(r, input$period)
      prev <- if (!is.null(pp)) tryCatch(peers(s$family, input$table, pp), error = function(e) NULL)
      fund_distribution_matrix_ui(r, descriptions, input$table, input$period, p, s$family, prev, if (!is.null(prev)) pp,
                                  mode = if (is.null(input$dist_mode)) "rel" else input$dist_mode,
                                  rows_of = function(tn) tryCatch(report_rows(s$family, tn, s$cnpj), error = function(e) NULL))
    })

    output$profile <- shiny::renderUI({
      s <- selected()
      fund_profile_ui(analytics, s$family, s$cnpj)
    })

    rows <- shiny::reactive({
      shiny::req(input$table)
      s <- selected()
      shiny::req(input$table %in% tables$table_name[tables$family == s$family])
      tryCatch(report_rows(s$family, input$table, s$cnpj,
                           period_from = input$period_from, period_to = input$period_to),
               error = function(e) structure(data.frame(), error = conditionMessage(e)))
    })

    shiny::observe({
      r <- rows()
      p <- if (nrow(r)) rev(unique(row_periods(r))) else character()
      shiny::updateSelectizeInput(session, "period", choices = p, selected = p[1])
    })

    output$rows_summary <- shiny::renderText({
      r <- rows()
      if (!is.null(attr(r, "error"))) return(paste("Erro:", attr(r, "error")))
      sprintf("%s linhas em %s períodos · valores originais da CVM, cada coluna cita o arquivo de origem",
              format_count(nrow(r)), format_count(length(unique(row_periods(r)))))
    })

    output$card <- shiny::renderUI({
      r <- rows()
      shiny::req(nrow(r) > 0L, input$period)
      r <- r[row_periods(r) == input$period, , drop = FALSE]
      if (nrow(r) == 0L) return(NULL)
      card <- report_card(r, descriptions, input$table)
      notes <- c(if (nrow(r) > fund_card_columns)
                   sprintf("Mostrando %d de %d linhas deste período; veja todas em Série completa.",
                           fund_card_columns, nrow(r)),
                 if (attr(card, "hidden") > 0)
                   if (attr(card, "hidden") == 1) "1 campo vazio neste período oculto."
                   else sprintf("%s campos vazios neste período ocultos.", format_count(attr(card, "hidden"))))
      shiny::tagList(if (length(notes)) shiny::div(class = "tm-caption", paste(notes, collapse = " ")), card)
    })

    output$rows <- shiny::renderUI({
      r <- rows()
      if (nrow(r) == 0L) return(shiny::div(class = "tm-empty", "Sem linhas nesta tabela para o fundo."))
      tab <- wide_table(r, descriptions, input$table)
      hidden <- attr(tab, "hidden")
      shiny::tagList(
        shiny::div(class = "tm-caption", paste(c(
          "Períodos do mais recente ao mais antigo; passe o mouse no período para ver a citação da fonte.",
          if (hidden == 1) "1 campo vazio em todos os períodos oculto."
          else if (hidden > 1) sprintf("%s campos vazios em todos os períodos ocultos.", format_count(hidden))),
          collapse = " ")),
        tab)
    })
    # Selected fund ("family|CNPJ"); chosen: the user's clicks; show(): selects
    # the app's current fund when it is in this tab's families (prototype/app.R).
    list(picked = picked, chosen = chosen, show = function(value) {
      p <- strsplit(value, "|", fixed = TRUE)[[1]]
      if (length(p) == 2L && p[1] %in% scope && any(directory$family == p[1] & directory$fund_cnpj == p[2]) &&
          !identical(value, shiny::isolate(picked()))) picked(value)
    })
  })
}
fund_coverage_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(
    class = "tm-page",
    shiny::div(class = "tm-hero",
               shiny::div(class = "tm-eyebrow", "Fase 1.3 · Cobertura e qualidade"),
               shiny::h1("O que foi consolidado"),
               shiny::p(class = "tm-lede",
                        "Nenhuma linha é descartada. Os registros de qualidade apontam duplicatas,",
                        "versões reapresentadas e diferenças frente aos dicionários da CVM.")),
    shiny::uiOutput(ns("kpis")),
    # Two sub-tabs: the consolidated tables (with each table's name and description,
    # from fund_table_labels) and the quality records.
    bslib::navset_card_underline(
      id = ns("view"),
      bslib::nav_panel("Tabelas consolidadas", shiny::uiOutput(ns("tables"))),
      bslib::nav_panel("Registro de qualidade",
                       shiny::div(class = "tm-table-wrap", shiny::tableOutput(ns("quality")))))
  )
}

fund_coverage_server <- function(id, root) {
  shiny::moduleServer(id, function(input, output, session) {
    tables <- fund_tables(root)
    quality <- fund_quality_summary(root)
    output$kpis <- shiny::renderUI({
      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3), class = "tm-kpis",
        kpi("Linhas consolidadas", format_count(sum(as.numeric(tables$rows)))),
        kpi("Tabelas", nrow(tables)),
        kpi("Famílias", length(unique(tables$family))),
        kpi("Registros de qualidade", format_count(sum(quality$records))))
    })
    # Consolidated tables: one sub-tab per family (pills), each with its tables.
    # Quality: one row per record type, the count per family (columns) and the total.
    families <- sort(unique(c(tables$family, quality$family)))
    table_families <- sort(unique(tables$family))
    for (f in table_families) local({
      fam <- f
      output[[paste0("tables_", fam)]] <- shiny::renderTable({
        t <- tables[tables$family == fam, , drop = FALSE]
        # Report order of the CVM form (fund_table_labels: I, II, ..., IX, X, X.1, ...).
        t <- t[order(match(t$table_name, names(fund_table_labels)), t$table_name), , drop = FALSE]
        data.frame(Tabela = t$table_name, `Nome e descrição` = fund_table_label(t$table_name),
                   Arquivos = t$members, Linhas = format_count(t$rows), Layouts = t$layouts,
                   `Períodos` = paste(t$first_period, "–", t$last_period), check.names = FALSE)
      }, spacing = "s", align = "llrrrl")
    })
    output$tables <- shiny::renderUI({
      ns <- session$ns
      do.call(bslib::navset_pill, c(list(id = ns("family")), lapply(table_families, function(f) {
        n <- sum(tables$family == f)
        bslib::nav_panel(title = sprintf("%s (%d)", toupper(f), n), value = f,
                         shiny::div(class = "tm-table-wrap tm-family-tables",
                                    shiny::tableOutput(ns(paste0("tables_", f)))))
      })))
    })
    output$quality <- shiny::renderTable({
      types <- sort(unique(quality$issue_type))
      out <- data.frame(Registro = types, check.names = FALSE)
      for (f in families) {
        n <- vapply(types, function(t) sum(quality$records[quality$family == f & quality$issue_type == t]), numeric(1))
        out[[toupper(f)]] <- ifelse(n > 0, format_count(n), "")
      }
      out$Total <- format_count(vapply(types, function(t) sum(quality$records[quality$issue_type == t]), numeric(1)))
      out
    }, spacing = "s", align = paste0("l", strrep("r", length(families) + 1L)))
  })
}
