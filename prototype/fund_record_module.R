# FICHA tab: the report records of one fund (any type) on the whole width:
# Ficha (one period) and Série completa (every period). Same data and
# rendering as the detail of the fund tabs (report_card, wide_table and the
# rows cache in prototype/fund_search_module.R); here the fund is chosen in a
# single search box (CNPJ or name), largest funds first.

# Search choices: "family|CNPJ" -> "FIDC · 00.000.000/0000-00 — Name".
fund_record_choices <- function(data, ctx = NULL) {
  l <- fund_list(data$directory, data$master)
  if (!is.null(ctx$fund_pl)) l <- attach_fund_net_assets(l, ctx$fund_pl)
  pl <- if (is.null(l$net_assets)) rep(NA_real_, nrow(l)) else l$net_assets
  l <- l[order(-ifelse(is.na(pl), -Inf, pl), l$fund_name, method = "radix"), , drop = FALSE]
  stats::setNames(paste(l$family, l$fund_cnpj, sep = "|"),
                  sprintf("%s · %s — %s", toupper(l$family), l$cnpj_formatted, l$fund_name))
}

# First table shown for a family: the same rule as the fund tabs.
fund_record_default_table <- function(tables, family) {
  t <- tables$table_name[tables$family == family]
  main <- t[grepl("geral|tab_I$|fip$|fiagro$", t)]
  if (length(main)) main[1] else t[1]
}

fund_record_ui <- function(id) {
  ns <- shiny::NS(id)
  page <- shiny::div(
    class = "tm-page tm-fill-page tm-record-page",
    shiny::div(class = "tm-dash-head",
               shiny::div(shiny::span(class = "tm-eyebrow", "Fase 1.3 · Ficha do fundo"),
                          shiny::h1("Ficha e série completa")),
               shiny::div(class = "tm-dash-meta", "Valores originais dos informes da CVM; cada coluna cita o arquivo de origem")),
    shiny::div(
      class = "tm-filterbar tm-record-filters",
      shiny::div(class = "tm-filter-wide",
                 shiny::selectizeInput(ns("fund"), NULL, choices = NULL, width = "100%",
                                       options = list(placeholder = "Fundo: CNPJ (com ou sem máscara) ou nome",
                                                      maxOptions = 50))),
      shiny::div(class = "tm-filter-wide", shiny::selectizeInput(ns("table"), NULL, choices = NULL, width = "100%",
                                                                options = list(placeholder = "Tabela"))),
      shiny::div(shiny::selectizeInput(ns("period"), NULL, choices = NULL, width = "100%",
                                       options = list(placeholder = "Período")))),
    bslib::card(
      class = "tm-section tm-detail tm-pane tm-record",
      bslib::card_header(class = "tm-detail-head", shiny::uiOutput(ns("head"))),
      bslib::card_body(
        fillable = FALSE, class = "tm-detail-body",
        shiny::div(class = "tm-caption", shiny::textOutput(ns("summary"))),
        bslib::navset_underline(
          id = ns("view"),
          bslib::nav_panel("Ficha", shiny::div(class = "tm-table-wrap", shiny::uiOutput(ns("card")))),
          bslib::nav_panel("Série completa", shiny::div(class = "tm-table-wrap tm-tall", shiny::uiOutput(ns("rows"))))))))
  htmltools::bindFillRole(page, container = TRUE, item = TRUE)
}

fund_record_server <- function(id, root, data, ctx = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    choices <- fund_record_choices(data, ctx)
    report_rows <- if (is.null(data$report_rows)) fund_rows_cache(root, data$urls) else data$report_rows
    shiny::updateSelectizeInput(session, "fund", choices = choices, selected = choices[1], server = TRUE)

    fund <- shiny::reactive({
      shiny::req(input$fund)
      p <- strsplit(input$fund, "|", fixed = TRUE)[[1]]
      shiny::req(length(p) == 2L)
      list(family = p[1], cnpj = p[2], label = names(choices)[match(input$fund, choices)])
    })

    shiny::observeEvent(fund(), {
      f <- fund()
      t <- data$tables[data$tables$family == f$family, , drop = FALSE]
      keep <- if (identical(input$table, NULL) || !input$table %in% t$table_name)
                fund_record_default_table(data$tables, f$family) else input$table
      shiny::updateSelectizeInput(session, "table", selected = keep, choices = stats::setNames(
        t$table_name, sprintf("%s  (%s–%s)", fund_table_label(t$table_name), t$first_period, t$last_period)))
    })

    rows <- shiny::reactive({
      f <- fund()
      shiny::req(input$table, input$table %in% data$tables$table_name[data$tables$family == f$family])
      tryCatch(report_rows(f$family, input$table, f$cnpj),
               error = function(e) structure(data.frame(), error = conditionMessage(e)))
    })

    shiny::observe({
      r <- rows()
      p <- if (nrow(r)) rev(unique(row_periods(r))) else character()
      shiny::updateSelectizeInput(session, "period", choices = p, selected = p[1])
    })

    output$head <- shiny::renderUI({
      f <- fund()
      lab <- if (is.na(f$label)) paste(toupper(f$family), f$cnpj) else f$label
      parts <- strsplit(lab, " — ", fixed = TRUE)[[1]]
      shiny::tagList(shiny::div(class = "tm-eyebrow", parts[1]),
                     shiny::h2(class = "tm-detail-title", paste(parts[-1], collapse = " — ")))
    })

    output$summary <- shiny::renderText({
      r <- rows()
      if (!is.null(attr(r, "error"))) return(paste("Erro:", attr(r, "error")))
      if (!nrow(r)) return("Sem linhas nesta tabela para o fundo.")
      sprintf("%s linhas em %s períodos · valores originais da CVM, cada coluna cita o arquivo de origem",
              format_count(nrow(r)), format_count(length(unique(row_periods(r)))))
    })

    output$card <- shiny::renderUI({
      r <- rows()
      shiny::req(nrow(r) > 0L, input$period)
      r <- r[row_periods(r) == input$period, , drop = FALSE]
      if (nrow(r) == 0L) return(NULL)
      card <- report_card(r, data$descriptions, input$table)
      notes <- c(if (nrow(r) > fund_card_columns)
                   sprintf("Mostrando %d de %d linhas deste período; veja todas em Série completa.",
                           fund_card_columns, nrow(r)),
                 if (attr(card, "hidden") == 1) "1 campo vazio neste período oculto."
                 else if (attr(card, "hidden") > 1)
                   sprintf("%s campos vazios neste período ocultos.", format_count(attr(card, "hidden"))))
      shiny::tagList(if (length(notes)) shiny::div(class = "tm-caption", paste(notes, collapse = " ")), card)
    })

    output$rows <- shiny::renderUI({
      r <- rows()
      if (nrow(r) == 0L) return(shiny::div(class = "tm-empty", "Sem linhas nesta tabela para o fundo."))
      tab <- wide_table(r, data$descriptions, input$table)
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
