# Shiny area for Phase 1.3 (investment fund reports). Presentation only: the
# search logic lives in src/intelligence/search_fund_reports.R.

fund_family_labels <- c(FII = "fii", FIDC = "fidc", FIP = "fip", FIAGRO = "fiagro")
fund_result_limit <- 500L

escape_html <- function(x) htmltools::htmlEscape(ifelse(is.na(x), "", as.character(x)))

fund_search_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      width = 3,
      shiny::checkboxGroupInput(ns("family"), "Família", choices = fund_family_labels,
                                selected = unname(fund_family_labels)),
      shiny::textInput(ns("cnpj"), "CNPJ do fundo (início ou completo)"),
      shiny::textInput(ns("name"), "Nome do fundo contém"),
      shiny::textInput(ns("administrator"), "Administrador (nome ou CNPJ)"),
      shiny::textInput(ns("period_from"), "Período de", placeholder = "aaaa ou aaaa-mm"),
      shiny::textInput(ns("period_to"), "Período até", placeholder = "aaaa ou aaaa-mm"),
      shiny::actionButton(ns("search"), "Buscar", class = "btn-primary"),
      shiny::helpText("O FIP não publica o administrador nos informes; o filtro de",
                      "administrador não encontra fundos FIP.")
    ),
    shiny::mainPanel(
      width = 9,
      shiny::textOutput(ns("summary")),
      shiny::div(style = "max-height: 360px; overflow: auto;", shiny::tableOutput(ns("funds"))),
      shiny::hr(),
      shiny::fluidRow(
        shiny::column(6, shiny::selectInput(ns("fund"), "Fundo", choices = NULL, width = "100%")),
        shiny::column(6, shiny::selectInput(ns("table"), "Tabela do informe", choices = NULL,
                                            width = "100%"))
      ),
      shiny::textOutput(ns("rows_summary")),
      shiny::div(style = "overflow: auto;", shiny::tableOutput(ns("rows")))
    )
  )
}

fund_search_server <- function(id, root) {
  shiny::moduleServer(id, function(input, output, session) {
    directory <- load_fund_directory(root)
    tables <- fund_tables(root)
    urls <- fund_source_urls(root)

    results <- shiny::eventReactive(input$search, {
      tryCatch(
        search_fund_directory(directory, family = input$family, cnpj = input$cnpj,
                              administrator = input$administrator, name = input$name,
                              period_from = input$period_from, period_to = input$period_to),
        error = function(e) structure(directory[0, ], error = conditionMessage(e)))
    }, ignoreNULL = FALSE)

    output$summary <- shiny::renderText({
      r <- results()
      if (!is.null(attr(r, "error"))) return(paste("Erro:", attr(r, "error")))
      shown <- min(nrow(r), fund_result_limit)
      sprintf("%d entradas encontradas (fundo, nome e administrador como publicados)%s.",
              nrow(r), if (nrow(r) > shown) sprintf("; mostrando as %d primeiras", shown) else "")
    })

    output$funds <- shiny::renderTable({
      r <- utils::head(results(), fund_result_limit)
      data.frame(`Família` = toupper(r$family), CNPJ = r$fund_cnpj_original, Nome = r$fund_name,
                 Administrador = r$administrator_name, `CNPJ adm.` = r$administrator_cnpj,
                 `Primeiro período` = r$first_period, `Último período` = r$last_period,
                 `Períodos` = r$period_count, check.names = FALSE)
    }, striped = TRUE, spacing = "xs", na = "")

    shiny::observe({
      r <- utils::head(results(), fund_result_limit)
      keep <- !duplicated(paste(r$family, r$fund_cnpj))
      r <- r[keep, , drop = FALSE]
      choices <- stats::setNames(paste(r$family, r$fund_cnpj, sep = "|"),
                                 sprintf("%s · %s · %s", toupper(r$family), r$fund_cnpj_original,
                                         r$fund_name))
      shiny::updateSelectInput(session, "fund", choices = choices)
    })

    selected <- shiny::reactive({
      shiny::req(input$fund)
      parts <- strsplit(input$fund, "|", fixed = TRUE)[[1]]
      list(family = parts[1], cnpj = parts[2])
    })

    shiny::observe({
      family <- selected()$family
      t <- tables[tables$family == family, , drop = FALSE]
      shiny::updateSelectInput(session, "table", choices = stats::setNames(
        t$table_name, sprintf("%s (%s–%s)", t$table_name, t$first_period, t$last_period)))
    })

    rows <- shiny::reactive({
      shiny::req(input$table)
      s <- selected()
      shiny::req(input$table %in% tables$table_name[tables$family == s$family])
      tryCatch(fund_report_rows(root, s$family, input$table, s$cnpj,
                                period_from = input$period_from, period_to = input$period_to,
                                urls = urls),
               error = function(e) structure(data.frame(), error = conditionMessage(e)))
    })

    output$rows_summary <- shiny::renderText({
      r <- rows()
      if (!is.null(attr(r, "error"))) return(paste("Erro:", attr(r, "error")))
      sprintf("%d linhas do informe, valores originais da CVM; cada linha cita o arquivo de origem.",
              nrow(r))
    })

    output$rows <- shiny::renderTable({
      r <- rows()
      if (nrow(r) == 0L) return(NULL)
      link <- ifelse(is.na(r$source_url), escape_html(r$citation),
                     sprintf('<a href="%s" target="_blank" rel="noopener">%s</a>',
                             escape_html(r$source_url), escape_html(r$citation)))
      shown <- r[, setdiff(names(r), c("citation", "source_url", "zip_sha256", "source_file",
                                       "source_line", "fund_cnpj_normalized")), drop = FALSE]
      shown[] <- lapply(shown, escape_html)
      cbind(`Citação` = link, shown)
    }, sanitize.text.function = function(x) x, striped = TRUE, spacing = "xs")
  })
}

fund_coverage_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Tabelas consolidadas"),
    shiny::tableOutput(ns("tables")),
    shiny::h4("Registros de qualidade da consolidação"),
    shiny::helpText("Nenhuma linha é descartada; os registros apontam duplicatas, versões",
                    "reapresentadas e diferenças frente aos dicionários da CVM."),
    shiny::tableOutput(ns("quality"))
  )
}

fund_coverage_server <- function(id, root) {
  shiny::moduleServer(id, function(input, output, session) {
    output$tables <- shiny::renderTable(fund_tables(root), striped = TRUE, spacing = "xs")
    output$quality <- shiny::renderTable(fund_quality_summary(root), striped = TRUE,
                                         spacing = "xs", digits = 0)
  })
}
