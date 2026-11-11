# Shiny area for Phase 1.3 (investment fund reports). Presentation only: the
# search logic lives in src/intelligence/search_fund_reports.R.

fund_family_labels <- c(FII = "fii", FIDC = "fidc", FIP = "fip", FIAGRO = "fiagro")
fund_result_limit <- 500L

escape_html <- function(x) htmltools::htmlEscape(ifelse(is.na(x), "", as.character(x)))

format_count <- function(x) formatC(x, format = "d", big.mark = ".", decimal.mark = ",")

# Autocomplete settings: free text is kept, so partial values still filter.
autocomplete_options <- function(placeholder) {
  list(create = TRUE, createOnBlur = TRUE, persist = FALSE, maxItems = 1,
       maxOptions = 50, placeholder = placeholder)
}

# The fund field takes a CNPJ (full or initial digits) or part of a name.
fund_query_filters <- function(value, directory) {
  value <- trimws(if (is.null(value)) "" else value)
  if (!nzchar(value)) return(list(cnpj = NULL, name = NULL))
  stripped <- toupper(gsub("[^0-9A-Za-z]", "", value))
  if (stripped %in% toupper(gsub("[^0-9A-Za-z]", "", directory$fund_cnpj)) ||
      grepl("^[0-9./ -]+$", value)) {
    return(list(cnpj = value, name = NULL))
  }
  list(cnpj = NULL, name = value)
}

fund_choices <- function(directory) {
  d <- directory[!duplicated(paste(directory$family, directory$fund_cnpj)), , drop = FALSE]
  stats::setNames(d$fund_cnpj, sprintf("%s · %s (%s)", d$fund_cnpj_original, d$fund_name,
                                       toupper(d$family)))
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
fund_sort_options <- c("Nome" = "name", "Último período (recente primeiro)" = "last",
                       "CNPJ" = "cnpj", "Períodos publicados" = "count")
fund_card_columns <- 6L

# Published names such as "NA", "," or "0" carry no letters: shown as missing,
# sorted last, the stored value is unchanged.
has_name <- function(x) !is.na(x) & grepl("[[:alpha:]]", x) & x != "NA"
display_name <- function(x) ifelse(has_name(x), x, "(sem nome publicado)")

sort_directory <- function(r, by) {
  key <- switch(by,
    last = order(r$last_period, decreasing = TRUE, method = "radix"),
    cnpj = order(r$fund_cnpj, method = "radix"),
    count = order(r$period_count, decreasing = TRUE, method = "radix"),
    order(!has_name(r$fund_name), normalize_search_text(r$fund_name), method = "radix"))
  r[key, , drop = FALSE]
}

# Clickable results: each row sends "family|cnpj" to the `pick` input.
results_table <- function(r, input_id, selected = NULL) {
  header <- c("Fundo", "Informes", "Nº")
  keys <- paste(r$family, r$fund_cnpj, sep = "|")
  rows <- lapply(seq_len(nrow(r)), function(i) {
    shiny::tags$tr(
      `data-key` = keys[i], class = if (identical(keys[i], selected)) "tm-selected",
      shiny::tags$td(
        shiny::div(class = "tm-id",
                   shiny::span(class = paste0("tm-tag tm-tag-", r$family[i]), toupper(r$family[i])),
                   shiny::span(class = "tm-mono", r$fund_cnpj_original[i])),
        shiny::div(class = if (has_name(r$fund_name[i])) "tm-fund" else "tm-fund tm-muted",
                   display_name(r$fund_name[i])),
        shiny::div(class = "tm-admin", if (is.na(r$administrator_name[i])) "administrador não publicado"
                   else r$administrator_name[i])),
      shiny::tags$td(class = "tm-mono", substr(r$first_period[i], 1, 7), shiny::br(),
                     substr(r$last_period[i], 1, 7)),
      shiny::tags$td(class = "tm-num", r$period_count[i]))
  })
  shiny::tags$table(
    class = "tm-results", `data-input` = input_id,
    shiny::tags$thead(shiny::tags$tr(lapply(header, shiny::tags$th))),
    shiny::tags$tbody(rows))
}

# One column per report row of the chosen period, one line per CVM field.
report_card <- function(r) {
  r <- utils::head(r, fund_card_columns)
  fields <- setdiff(names(r), c("citation", "source_url", "zip_sha256", "source_file", "source_line",
                                "fund_cnpj_normalized", "reference_period", "layout_version"))
  cite <- lapply(seq_len(nrow(r)), function(i) {
    text <- r$citation[i]
    shiny::tags$th(if (is.na(r$source_url[i])) text
                   else shiny::tags$a(href = r$source_url[i], target = "_blank", rel = "noopener", text))
  })
  body <- lapply(fields, function(f) {
    shiny::tags$tr(shiny::tags$th(class = "tm-field", f),
                   lapply(r[[f]], function(v) shiny::tags$td(if (is.na(v) || !nzchar(v)) "—" else v)))
  })
  shiny::tags$table(
    class = "tm-card-table",
    shiny::tags$thead(shiny::tags$tr(shiny::tags$th(class = "tm-field", "Campo"), cite)),
    shiny::tags$tbody(body))
}

wide_table <- function(r) {
  shown <- r[, setdiff(names(r), c("source_url", "zip_sha256", "source_file", "source_line",
                                   "fund_cnpj_normalized")), drop = FALSE]
  shiny::tags$table(
    class = "tm-wide",
    shiny::tags$thead(shiny::tags$tr(lapply(names(shown), shiny::tags$th))),
    shiny::tags$tbody(lapply(seq_len(nrow(shown)), function(i) {
      shiny::tags$tr(lapply(names(shown), function(n) {
        v <- shown[[n]][i]
        if (n == "citation" && !is.na(r$source_url[i])) {
          shiny::tags$td(shiny::tags$a(href = r$source_url[i], target = "_blank", rel = "noopener", v))
        } else shiny::tags$td(if (is.na(v)) "" else v)
      }))
    })))
}

row_periods <- function(r) {
  p <- first_present(r, fund_period_columns)
  ifelse(is.na(p), "(sem período)", substr(p, 1, 10))
}

fund_search_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(
    class = "tm-page",
    shiny::tags$script(shiny::HTML(
      "$(document).on('click', 'table.tm-results tbody tr[data-key]', function() {
         var t = $(this).closest('table');
         t.find('tr.tm-selected').removeClass('tm-selected');
         $(this).addClass('tm-selected');
         Shiny.setInputValue(t.data('input'), $(this).data('key'), {priority: 'event'});
       });")),
    shiny::div(class = "tm-hero",
               shiny::div(class = "tm-eyebrow", "Fase 1.3 · Fundos de investimento"),
               shiny::h1("Informes de fundos da CVM"),
               shiny::p(class = "tm-lede",
                        "Filtre, clique em um fundo e leia os informes ao lado.",
                        "Valores como publicados pela CVM, com a citação do arquivo de origem.")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 260, title = "Filtros", open = list(desktop = "open", mobile = "closed"),
        shiny::checkboxGroupInput(ns("family"), "Família", choices = fund_family_labels,
                                  selected = unname(fund_family_labels), inline = TRUE),
        shiny::selectizeInput(ns("fund_query"), "Fundo (CNPJ ou nome)", choices = NULL,
                              options = autocomplete_options("Digite o CNPJ ou parte do nome")),
        shiny::selectizeInput(ns("administrator"), "Administrador", choices = NULL,
                              options = autocomplete_options("Nome ou CNPJ")),
        shiny::fluidRow(
          shiny::column(6, shiny::selectizeInput(ns("period_from"), "De", choices = NULL,
                                                 options = autocomplete_options("aaaa-mm"))),
          shiny::column(6, shiny::selectizeInput(ns("period_to"), "Até", choices = NULL,
                                                 options = autocomplete_options("aaaa-mm")))),
        shiny::actionButton(ns("search"), "Buscar", class = "btn-primary w-100"),
        shiny::actionLink(ns("clear"), "Limpar filtros", class = "tm-link"),
        shiny::p(class = "tm-footnote",
                 "O FIP não publica o administrador; o filtro de administrador não encontra fundos FIP.")),
      shiny::uiOutput(ns("kpis")),
      bslib::layout_columns(
        col_widths = bslib::breakpoints(sm = 12, xl = c(6, 6)), class = "tm-master-detail",
      bslib::card(
        class = "tm-section tm-pane",
        bslib::card_header(
          class = "tm-card-head",
          shiny::div(class = "tm-card-title", shiny::textOutput(ns("summary"), inline = TRUE)),
          shiny::div(class = "tm-card-tools",
                     shiny::selectInput(ns("sort"), NULL, choices = fund_sort_options, width = "260px"))),
        bslib::card_body(padding = 0, class = "tm-scroll", shiny::uiOutput(ns("funds"))),
        bslib::card_footer(class = "tm-pager",
                           shiny::actionLink(ns("prev"), "‹ Anterior"),
                           shiny::span(class = "tm-muted", shiny::textOutput(ns("page"), inline = TRUE)),
                           shiny::actionLink(ns("next_page"), "Próxima ›"))),
      shiny::div(class = "tm-pane-wrap", shiny::uiOutput(ns("detail")),
                 shiny::div(class = "tm-empty tm-hint", "Selecione um fundo na lista.")))
    )
  )
}

fund_search_server <- function(id, root) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    directory <- load_fund_directory(root)
    tables <- fund_tables(root)
    urls <- fund_source_urls(root)

    shiny::updateSelectizeInput(session, "fund_query", choices = fund_choices(directory),
                                selected = character(), server = TRUE)
    admins <- sort(unique(stats::na.omit(directory$administrator_name)))
    shiny::updateSelectizeInput(session, "administrator", choices = admins,
                                selected = character(), server = TRUE)
    periods <- period_choices(directory)
    shiny::updateSelectizeInput(session, "period_from", choices = periods, selected = character())
    shiny::updateSelectizeInput(session, "period_to", choices = periods, selected = character())

    shiny::observeEvent(input$clear, {
      shiny::updateCheckboxGroupInput(session, "family", selected = unname(fund_family_labels))
      for (field in c("fund_query", "administrator", "period_from", "period_to")) {
        shiny::updateSelectizeInput(session, field, selected = character())
      }
    })

    results <- shiny::eventReactive(input$search, {
      query <- fund_query_filters(input$fund_query, directory)
      tryCatch(
        search_fund_directory(directory, family = input$family, cnpj = query$cnpj,
                              name = query$name, administrator = input$administrator,
                              period_from = input$period_from, period_to = input$period_to),
        error = function(e) structure(directory[0, ], error = conditionMessage(e)))
    }, ignoreNULL = FALSE)

    sorted <- shiny::reactive({
      r <- results()
      if (nrow(r) == 0L) return(r)
      sort_directory(r, if (is.null(input$sort)) "name" else input$sort)
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
      r <- sorted()
      picked(if (nrow(r)) paste(r$family[1], r$fund_cnpj[1], sep = "|") else NULL)
    })

    output$kpis <- shiny::renderUI({
      r <- results()
      funds <- length(unique(paste(r$family, r$fund_cnpj)))
      span <- if (nrow(r)) sprintf("%s – %s", substr(min(r$first_period, na.rm = TRUE), 1, 7),
                                   substr(max(r$last_period, na.rm = TRUE), 1, 7)) else "—"
      admins <- length(unique(stats::na.omit(r$administrator_name)))
      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3), class = "tm-kpis",
        kpi("Fundos", format_count(funds)),
        kpi("Administradores", format_count(admins)),
        kpi("Famílias", length(unique(r$family))),
        kpi("Períodos", span))
    })

    output$summary <- shiny::renderText({
      r <- results()
      if (!is.null(attr(r, "error"))) return(paste("Erro:", attr(r, "error")))
      sprintf("%s entradas", format_count(nrow(r)))
    })

    output$page <- shiny::renderText(sprintf("Página %d de %d", page(), pages()))

    output$funds <- shiny::renderUI({
      r <- sorted()
      if (nrow(r) == 0L) return(shiny::div(class = "tm-empty", "Nenhum fundo com esses filtros."))
      first <- (page() - 1L) * fund_page_size + 1L
      r <- r[first:min(nrow(r), first + fund_page_size - 1L), , drop = FALSE]
      results_table(r, ns("pick"), shiny::isolate(picked()))
    })

    selected <- shiny::reactive({
      shiny::req(picked())
      parts <- strsplit(picked(), "|", fixed = TRUE)[[1]]
      info <- directory[directory$family == parts[1] & directory$fund_cnpj == parts[2], , drop = FALSE]
      info <- info[order(!has_name(info$fund_name), info$last_period, decreasing = c(FALSE, TRUE), method = "radix"), ]
      list(family = parts[1], cnpj = parts[2], info = info)
    })

    output$detail <- shiny::renderUI({
      s <- selected()
      i <- s$info[1, ]
      t <- tables[tables$family == s$family, , drop = FALSE]
      admins <- unique(stats::na.omit(s$info$administrator_name))
      bslib::card(
        class = "tm-section tm-detail tm-pane",
        bslib::card_header(
          class = "tm-detail-head",
          shiny::div(class = "tm-eyebrow", sprintf("%s · %s", toupper(s$family), i$fund_cnpj_original)),
          shiny::h2(class = "tm-detail-title", display_name(i$fund_name)),
          shiny::div(class = "tm-detail-meta",
                     shiny::span(shiny::strong("Administrador: "),
                                 if (length(admins)) paste(admins, collapse = "; ") else "não publicado"),
                     shiny::span(shiny::strong("Informes: "),
                                 sprintf("%s a %s", substr(min(s$info$first_period), 1, 7),
                                         substr(max(s$info$last_period), 1, 7))))),
        bslib::card_body(
          fillable = FALSE,
          bslib::layout_columns(
            col_widths = c(7, 5),
            shiny::selectizeInput(ns("table"), "Tabela do informe", width = "100%",
                                  choices = stats::setNames(t$table_name, sprintf(
                                    "%s  (%s–%s)", t$table_name, t$first_period, t$last_period)),
                                  selected = t$table_name[grepl("geral|tab_I$|fip$|fiagro$",
                                                                t$table_name)][1]),
            shiny::selectizeInput(ns("period"), "Período", choices = NULL, width = "100%")),
          shiny::div(class = "tm-caption", shiny::textOutput(ns("rows_summary"))),
          bslib::navset_underline(
            bslib::nav_panel("Ficha", shiny::div(class = "tm-table-wrap tm-tall", shiny::uiOutput(ns("card")))),
            bslib::nav_panel("Série completa",
                             shiny::div(class = "tm-table-wrap tm-tall", shiny::uiOutput(ns("rows")))))))
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
      shiny::tagList(
        if (nrow(r) > fund_card_columns) shiny::div(
          class = "tm-caption", sprintf("Mostrando %d de %d linhas deste período; veja todas em Série completa.",
                                        fund_card_columns, nrow(r))),
        report_card(r))
    })

    output$rows <- shiny::renderUI({
      r <- rows()
      if (nrow(r) == 0L) return(shiny::div(class = "tm-empty", "Sem linhas nesta tabela para o fundo."))
      wide_table(r)
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
