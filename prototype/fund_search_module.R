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

# Display of published values (presentation only; stored values unchanged):
# plain numbers get "." for thousands and "," for decimals, keeping the
# published decimal places; values already in that format pass through.
# Returns the text and whether it is numeric (right-aligned).
display_value <- function(v, field = "") {
  if (is.na(v) || !nzchar(trimws(v))) return(list(text = "—", num = FALSE))
  v <- trimws(v)
  if (grepl(fund_code_fields, toupper(field))) return(list(text = format_tax_id(v, field), num = FALSE))
  if (grepl("^-?[0-9]{1,3}([.][0-9]{3})*(,[0-9]+)?$", v) && grepl("[.,]", v))
    return(list(text = v, num = TRUE))
  if (!grepl("^-?[0-9]+([.][0-9]+)?$", v) || grepl("^-?0[0-9]", v)) return(list(text = v, num = FALSE))
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
  masked <- ok & grepl("^-?[0-9]{1,3}([.][0-9]{3})*(,[0-9]+)?$", v) & grepl("[.,]", v)
  plain <- ok & !masked & grepl("^-?[0-9]+([.][0-9]+)?$", v) & !grepl("^-?0[0-9]", v)
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

sort_directory <- function(r, by, decreasing = NULL) {
  if (is.null(decreasing)) {
    decreasing <- fund_sort_columns$decreasing[match(by, fund_sort_columns$by)]
    if (is.na(decreasing)) decreasing <- FALSE
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
results_table <- function(r, input_id, selected = NULL, sort_input = NULL, sort = NULL) {
  keys <- paste(r$family, r$fund_cnpj, sep = "|")
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
                     else format_share(r$net_assets_share[i])))
  })
  header <- lapply(seq_len(nrow(fund_sort_columns)), function(k) {
    col <- fund_sort_columns[k, ]
    active <- !is.null(sort) && identical(sort$by, col$by)
    arrow <- if (active) (if (isTRUE(sort$decreasing)) " ▼" else " ▲") else ""
    shiny::tags$th(class = paste("tm-sortable", if (active) "tm-sorted", if (col$by %in% c("count", "pl", "share")) "tm-num"),
                   `data-sort` = col$by, title = fund_sort_tips[[col$by]],
                   paste0(col$label, arrow))
  })
  shiny::tags$table(
    class = "tm-results", `data-input` = input_id, `data-sort-input` = sort_input,
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
field_labels <- function(fields, descriptions = NULL, table_name = NULL) {
  desc <- if (is.null(descriptions) || is.null(table_name)) rep(NA_character_, length(fields))
          else describe_fields(descriptions, table_name, fields)
  data.frame(field = fields, label = ifelse(is.na(desc), humanize_field(fields), desc),
             derived = is.na(desc), stringsAsFactors = FALSE)
}

# One report row: fields as a compact two-column grid (label above value).
ficha_grid <- function(r, labels) {
  items <- lapply(seq_len(nrow(labels)), function(k) {
    v <- r[[labels$field[k]]][1]
    shiny::div(class = "tm-ficha-item",
               shiny::div(class = if (labels$derived[k]) "tm-ficha-label tm-derived" else "tm-ficha-label",
                          `data-tip` = sprintf("%s\nCampo CVM: %s%s", labels$label[k], labels$field[k],
                                               if (labels$derived[k]) " (sem descrição no dicionário)" else ""),
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
                                  `data-tip` = sprintf("%s\nCampo CVM: %s%s", labels$label[k], f,
                                                       if (labels$derived[k]) " (sem descrição no dicionário)" else ""),
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
    tip <- sprintf("%s\nCampo CVM: %s%s", labels$label[k], f,
                   if (labels$derived[k]) " (sem descrição no dicionário)" else "")
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
      if (identical(family, "fip")) shiny::div(
        class = "tm-filter tm-filter-period", title = "Indica se o fundo é entidade de investimento (ENTID_INVEST, último informe que o publicou)",
        shiny::selectInput(ns("investment_entity"), NULL, width = "100%", selectize = FALSE,
                           choices = c("Entidade de investimento: todos" = "", "Entidade de investimento: sim" = "S",
                                       "Entidade de investimento: não" = "N", "Entidade de investimento: não informado" = "NA"))),
      shiny::div(class = "tm-filter tm-filter-period",
                 shiny::selectizeInput(ns("period_from"), NULL, choices = NULL, width = "100%",
                                       options = autocomplete_options("De (aaaa-mm)"))),
      shiny::div(class = "tm-filter tm-filter-period",
                 shiny::selectizeInput(ns("period_to"), NULL, choices = NULL, width = "100%",
                                       options = autocomplete_options("Até (aaaa-mm)"))),
      shiny::actionLink(ns("clear"), "Limpar", class = "tm-link tm-filter-clear",
                        title = "Limpar todos os filtros")),
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
       tables = fund_tables(root), urls = urls, report_rows = fund_rows_cache(root, urls),
       descriptions = fund_field_descriptions(root), investment_entity = fund_investment_entity(root))
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
    descriptions <- data$descriptions
    scope <- if (is.null(families)) unname(fund_family_labels) else families
    in_scope <- directory[directory$family %in% scope, , drop = FALSE]

    shiny::updateSelectizeInput(session, "fund_query", choices = fund_choices(master, in_scope),
                                selected = character(), server = TRUE)
    shiny::updateSelectizeInput(session, "administrator", choices = administrator_choices(master, in_scope),
                                selected = character(), server = TRUE)
    periods <- period_choices(in_scope)
    shiny::updateSelectizeInput(session, "period_from", choices = periods, selected = character())
    shiny::updateSelectizeInput(session, "period_to", choices = periods, selected = character())

    shiny::observeEvent(input$clear, {
      if (is.null(families)) shiny::updateCheckboxGroupInput(session, "family", selected = unname(fund_family_labels))
      for (field in c("fund_query", "administrator", "period_from", "period_to")) {
        shiny::updateSelectizeInput(session, field, selected = character())
      }
      shiny::updateSelectInput(session, "investment_entity", selected = "")
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
        if (!is.null(data$investment_entity)) out <- filter_investment_entity(out, data$investment_entity, input$investment_entity)
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
      if (!by %in% fund_sort_columns$by) return()
      sort_state(if (identical(s$by, by)) list(by = by, decreasing = !s$decreasing)
                 else list(by = by, decreasing = fund_sort_columns$decreasing[fund_sort_columns$by == by]))
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
    shiny::observeEvent(input$pick, picked(input$pick))
    # A new search selects its first fund, so the detail is never stale.
    shiny::observeEvent(results(), {
      sort_state(list(by = "pl", decreasing = TRUE))
      r <- sorted()
      picked(if (nrow(r)) paste(r$family[1], r$fund_cnpj[1], sep = "|") else NULL)
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
      results_table(r, ns("pick"), shiny::isolate(picked()), ns("sort_col"), sort_state())
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
        class = "tm-section tm-detail tm-pane",
        bslib::card_header(
          class = "tm-detail-head",
          shiny::div(class = "tm-eyebrow", sprintf("%s · %s", toupper(s$family), format_cnpj(i$fund_cnpj_original))),
          shiny::h2(class = "tm-detail-title", if (is.na(ent$display_name)) display_name(i$fund_name) else ent$display_name),
          shiny::div(class = "tm-detail-meta",
                     shiny::span(shiny::strong("Administrador: "),
                                 if (length(admins)) paste(admins, collapse = "; ") else "não publicado"),
                     shiny::span(shiny::strong("Informes: "),
                                 sprintf("%s a %s", substr(min(s$info$first_period), 1, 7),
                                         substr(max(s$info$last_period), 1, 7))),
                     if (isTRUE(ent$name_count > 1L))
                       shiny::span(shiny::strong("Denominações: "), ent$name_count),
                     if (s$family == "fip" && !is.null(data$investment_entity)) {
                       k <- match(s$cnpj, data$investment_entity$fund_cnpj)
                       v <- data$investment_entity$investment_entity[k]
                       shiny::span(shiny::strong("Entidade de investimento: "),
                                   if (is.na(v)) "não informado"
                                   else paste0(switch(v, S = "sim", N = "não", v), " (informe de ",
                                               data$investment_entity$investment_entity_period[k], ")"))
                     })),
        bslib::card_body(
          fillable = FALSE, class = "tm-detail-body",
          bslib::layout_columns(
            col_widths = c(8, 4), class = "tm-detail-tools",
            shiny::selectizeInput(ns("table"), NULL, width = "100%",
                                  choices = stats::setNames(t$table_name, sprintf(
                                    "%s  (%s–%s)", t$table_name, t$first_period, t$last_period)),
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
            bslib::nav_panel("Denominações", shiny::div(class = "tm-table-wrap", shiny::uiOutput(ns("names")))))))
    })

    output$names <- shiny::renderUI(name_timeline_ui(master, selected()$entity))

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
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(bslib::card_header("Tabelas consolidadas"),
                  bslib::card_body(class = "tm-table-wrap", shiny::tableOutput(ns("tables")))),
      bslib::card(bslib::card_header("Registros de qualidade"),
                  bslib::card_body(class = "tm-table-wrap", shiny::tableOutput(ns("quality")))))
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
    output$tables <- shiny::renderTable({
      data.frame(`Família` = toupper(tables$family), Tabela = tables$table_name,
                 Arquivos = tables$members, Linhas = format_count(tables$rows),
                 Layouts = tables$layouts, `Períodos` = paste(tables$first_period, "–",
                                                              tables$last_period),
                 check.names = FALSE)
    }, spacing = "s")
    output$quality <- shiny::renderTable({
      data.frame(`Família` = toupper(quality$family), Registro = quality$issue_type,
                 Quantidade = format_count(quality$records), check.names = FALSE)
    }, spacing = "s")
  })
}
