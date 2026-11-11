# Analytical areas of Phase 1.3: market overview (Panorama) and administrator
# concentration. Presentation only: the numbers come from
# src/data/build_fund_metrics.R and src/intelligence/fund_analytics.R.

# Everything the analytical areas share, computed once per app start.
fund_analytics_context <- function(root, directory = load_fund_directory(root), today = Sys.Date()) {
  metrics <- load_fund_metrics(root)
  m <- prepare_metrics(metrics, today)
  series <- family_monthly(m)
  complete <- complete_months(series)
  snapshot <- market_snapshot(m, complete)
  admins <- fund_administrators(directory)
  list(m = m, series = series, complete = complete, overview = family_overview(series, complete),
       snapshot = snapshot, admins = admins, ranking = administrator_ranking(snapshot, admins),
       market_change = market_change(m, complete), issues = attr(metrics, "issues"),
       future_rows = attr(m, "future_rows"), today = today)
}

admin_families <- c(FII = "fii", FIDC = "fidc", FIAGRO = "fiagro")

family_tag <- function(family) {
  shiny::span(class = paste0("tm-tag tm-tag-", family), toupper(family))
}

method_note <- function(ctx) {
  shiny::div(
    class = "tm-method",
    shiny::div(class = "tm-eyebrow", "Metodologia"),
    shiny::tags$ul(
      shiny::tags$li("Fonte: informes da CVM (dados.cvm.gov.br, ODbL). Patrimônio líquido como publicado: ",
                     "FII e FIAGRO no informe mensal, FIDC na tabela IV, FIP no informe trimestral/quadrimestral."),
      shiny::tags$li("Cada família é mostrada no seu último mês completo (fundos que reportaram ≥ 90% da mediana ",
                     "dos seis meses anteriores); meses ainda em entrega aparecem como “em entrega”."),
      shiny::tags$li("Reapresentações: vale a maior versão, depois o arquivo mais recente. Valores não numéricos ",
                     "ficam vazios (nunca zero)", sprintf(" — %s neste carregamento;", format_int(ctx$issues$unparsed)),
                     sprintf(" %s períodos futuros descartados.", format_int(ctx$future_rows))),
      shiny::tags$li("Totais do mercado contam cada CNPJ uma vez por mês. Cotistas são posições somadas por fundo: ",
                     "um investidor em dois fundos conta duas vezes."),
      shiny::tags$li("O FIP informa a cada três ou quatro meses: entre dois informes vale o último patrimônio ",
                     "publicado (até três meses), para que a soma mensal não oscile com o calendário de entrega."),
      shiny::tags$li("Variações comparam com o mesmo mês um ano antes. O FIAGRO tem informe próprio desde 2025; ",
                     "parte do seu crescimento é migração de fundos antes reportados como FII."),
      shiny::tags$li("Concentração (HHI) sobre participações em %: < 1.500 baixa, 1.500–2.500 moderada, > 2.500 alta. ",
                     "Administradores agrupados pelo CNPJ. O FIP não publica administrador e fica fora."),
      shiny::tags$li("Em alguns informes FIAGRO o campo de administrador traz o nome do fundo, com o CNPJ do ",
                     "administrador correto; nesses casos o nome vem dos demais informes desse CNPJ.")))
}

family_panel <- function(ctx, family) {
  o <- ctx$overview[ctx$overview$family == family, ]
  d <- ctx$series[ctx$series$family == family & ctx$series$month <= ctx$complete[[family]], ]
  color <- fund_family_colors[[family]]
  tips <- sprintf("%s\nPL %s\n%s fundos", month_label(d$month), format_brl(d$net_assets), format_int(d$funds))
  pending <- o$latest_month > o$month
  shiny::div(
    class = "tm-family",
    shiny::div(class = "tm-family-head",
               shiny::span(class = "tm-swatch", style = sprintf("background:%s", color)),
               shiny::span(class = "tm-family-code", toupper(family)),
               shiny::span(class = "tm-family-name", fund_family_names[[family]]),
               shiny::span(class = "tm-family-month",
                           `data-tip` = if (pending) sprintf("Último mês completo.\n%s ainda em entrega (não exibido).",
                                                             month_label(o$latest_month)),
                           month_label(o$month), if (pending) " ⓘ")),
    shiny::div(class = "tm-family-figures",
               shiny::div(shiny::div(class = "tm-big", format_brl(o$net_assets)),
                          change_badge(o$net_assets_change)),
               shiny::div(class = "tm-family-side",
                          shiny::div(shiny::strong(format_int(o$funds)), " fundos",
                                     if (!is.na(o$funds_change)) shiny::span(
                                       class = "tm-muted-sm", sprintf(" (%s%s em 12m)",
                                                                      if (o$funds_change > 0) "+" else "",
                                                                      format_int(o$funds_change)))),
                          shiny::div(if (is.na(o$quotaholders)) shiny::span(class = "tm-muted-sm", "cotistas não publicados")
                                     else shiny::tagList(shiny::strong(axis_int(o$quotaholders)), " cotistas")))),
    chart_key(color, "Patrimônio líquido (eixo esq.)", "Fundos (eixo dir.)"),
    shiny::div(class = "tm-chart-box",
               svg_line_chart(d$month, d$net_assets, color, tips = tips, width = 360, height = 150,
                              values2 = d$funds,
                              label = sprintf("Patrimônio líquido e número de fundos %s por mês", toupper(family)))))
}

# Panorama: one landscape screen, no scrolling (grid in taxminer.css,
# `.tm-dash`). Rankings show the top 6; the methodology is in the Sobre tab.
fund_overview_ui <- function(id, ctx, top = 6L) {
  s <- ctx$snapshot
  r <- ctx$ranking
  o <- ctx$overview
  total <- sum(s$net_assets, na.rm = TRUE)
  top_funds <- utils::head(snapshot_funds(s, ctx$admins), top)
  top_admins <- utils::head(r, top)
  months <- unique(month_label(ctx$complete[fund_family_order[fund_family_order %in% names(ctx$complete)]]))
  shiny::div(
    class = "tm-dash",
    shiny::div(class = "tm-dash-head",
               shiny::div(shiny::span(class = "tm-eyebrow", "Panorama · Fase 1.3"),
                          shiny::h1("Fundos estruturados no Brasil")),
               shiny::div(class = "tm-dash-meta",
                          sprintf("FII, FIDC, FIP e FIAGRO · informes à CVM · referência %s (último mês completo)",
                                  paste(months, collapse = " / ")),
                          shiny::tags$a(href = "#", class = "tm-link tm-goto", `data-tab` = "Sobre",
                                        "Metodologia e fontes"))),
    shiny::div(class = "tm-dash-kpis",
               kpi("Patrimônio líquido", format_brl(total), change_badge(ctx$market_change)),
               kpi("Fundos", format_int(nrow(s)), "com informe no mês de referência"),
               kpi("Cotistas", axis_int(sum(s$quotaholders, na.rm = TRUE)), "posições; FIP não publica"),
               kpi("Administradores", format_int(nrow(r)), "FII, FIDC e FIAGRO"),
               kpi("Concentração (HHI)", format_int(round(attr(r, "hhi"))),
                   sprintf("%s · 5 maiores: %s", hhi_label(attr(r, "hhi")),
                           format_pct(r$cumulative_share[min(5, nrow(r))], sign = FALSE)))),
    shiny::div(class = "tm-dash-share",
               shiny::div(class = "tm-dash-label", "Composição do patrimônio"),
               share_bar(o$net_assets, fund_family_colors[o$family],
                         paste(toupper(o$family), "·", fund_family_names[o$family]), format_brl(o$net_assets))),
    shiny::div(class = "tm-dash-families", lapply(o$family, function(f) family_panel(ctx, f))),
    shiny::div(
      class = "tm-dash-rank",
      shiny::div(class = "tm-dash-card",
                 shiny::div(class = "tm-dash-card-head", "Maiores administradores",
                            shiny::span(class = "tm-head-note", sprintf("HHI %s · %s", format_int(round(attr(r, "hhi"))),
                                                                        hhi_label(attr(r, "hhi"))))),
                 bar_list(top_admins$administrator_name, top_admins$net_assets,
                          sprintf("%s · %s", format_brl(top_admins$net_assets), format_pct(top_admins$share, sign = FALSE)),
                          colors = "#0b1f3a", rank = top_admins$rank,
                          sub = sprintf("%s fundos · %s", format_int(top_admins$funds), top_admins$families),
                          tips = sprintf("%s\nParticipação %s · acumulada %s", top_admins$administrator_name,
                                         format_pct(top_admins$share, sign = FALSE),
                                         format_pct(top_admins$cumulative_share, sign = FALSE)))),
      shiny::div(class = "tm-dash-card",
                 shiny::div(class = "tm-dash-card-head", "Maiores fundos",
                            shiny::span(class = "tm-head-note", "cor = família")),
                 bar_list(display_name(top_funds$fund_name), top_funds$net_assets, format_brl(top_funds$net_assets),
                          colors = unname(fund_family_colors[top_funds$family]), rank = seq_len(nrow(top_funds)),
                          sub = sprintf("%s · %s · %s", toupper(top_funds$family), top_funds$fund_cnpj,
                                        ifelse(is.na(top_funds$administrator_name), "administrador não publicado",
                                               top_funds$administrator_name)),
                          tips = sprintf("%s\n%s · referência %s", display_name(top_funds$fund_name),
                                         format_brl(top_funds$net_assets),
                                         month_label(substr(top_funds$period, 1, 7)))))))
}

fund_admin_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(
    class = "tm-page",
    shiny::div(class = "tm-hero",
               shiny::div(class = "tm-eyebrow", "Fase 1.3 · Administradores"),
               shiny::h1("Concentração da administração fiduciária"),
               shiny::p(class = "tm-lede",
                        "Participação de cada administrador no patrimônio de FII, FIDC e FIAGRO no mês de referência.",
                        "Clique em um administrador para ver a série e os fundos.")),
    shiny::div(class = "tm-toolbar",
               shiny::checkboxGroupInput(ns("family"), NULL, choices = admin_families,
                                         selected = unname(admin_families), inline = TRUE),
               shiny::selectizeInput(ns("find"), NULL, choices = NULL, width = "360px",
                                     options = list(placeholder = "Buscar administrador (nome ou CNPJ)",
                                                    maxOptions = 50))),
    shiny::uiOutput(ns("kpis")),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, xl = c(5, 7)), class = "tm-master-detail",
      bslib::card(class = "tm-section tm-pane",
                  bslib::card_header(shiny::textOutput(ns("list_title"), inline = TRUE)),
                  bslib::card_body(class = "tm-scroll", shiny::uiOutput(ns("ranking")))),
      shiny::div(class = "tm-pane-wrap", shiny::uiOutput(ns("detail")))))
}

fund_admin_server <- function(id, ctx) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    families <- shiny::reactive({
      f <- intersect(input$family, admin_families)
      if (length(f)) f else unname(admin_families)
    })
    ranking <- shiny::reactive(administrator_ranking(ctx$snapshot, ctx$admins, families()))
    picked <- shiny::reactiveVal(NULL)

    shiny::observe({
      r <- ranking()
      shiny::updateSelectizeInput(session, "find", server = TRUE, selected = character(),
                                  choices = stats::setNames(r$key, sprintf("%s · %s", r$administrator_name,
                                                                            ifelse(is.na(r$administrator_cnpj), "sem CNPJ",
                                                                                   r$administrator_cnpj))))
      if (is.null(shiny::isolate(picked())) || !shiny::isolate(picked()) %in% r$key) picked(r$key[1])
    })
    shiny::observeEvent(input$pick, picked(input$pick))
    shiny::observeEvent(input$find, if (nzchar(input$find)) picked(input$find))

    output$kpis <- shiny::renderUI(admin_kpis_ui(ranking(), families()))

    output$list_title <- shiny::renderText(sprintf("Ranking · %s administradores", format_int(nrow(ranking()))))

    output$ranking <- shiny::renderUI({
      r <- ranking()
      bar_list(r$administrator_name, r$net_assets,
               sprintf("%s · %s", format_brl(r$net_assets), format_pct(r$share, sign = FALSE)),
               colors = "#0b1f3a", rank = r$rank, keys = r$key, input = ns("pick"),
               selected = shiny::isolate(picked()),
               sub = sprintf("%s fundos · %s", format_int(r$funds), r$families),
               tips = sprintf("%s\nAcumulado até aqui: %s", r$administrator_name,
                              format_pct(r$cumulative_share, sign = FALSE)))
    })

    output$detail <- shiny::renderUI({
      r <- ranking()
      shiny::req(picked(), picked() %in% r$key)
      admin_detail_ui(ctx, r, picked(), families())
    })
  })
}

admin_kpis_ui <- function(r, families) {
  h <- attr(r, "hhi")
  share_at <- function(n) format_pct(r$cumulative_share[min(n, nrow(r))], sign = FALSE)
  shiny::div(
    class = "tm-kpi-row",
    kpi("Patrimônio administrado", format_brl(attr(r, "total")), paste(toupper(families), collapse = " · ")),
    kpi("Administradores", format_int(nrow(r))),
    kpi("HHI", format_int(round(h)), hhi_label(h)),
    kpi("Participação dos maiores", share_at(5), sprintf("5 maiores · 10 maiores: %s", share_at(10))))
}

# Detail card of one administrator (`key` from administrator_key()) within ranking `r`.
admin_detail_ui <- function(ctx, r, key, families) {
  a <- r[r$key == key, ]
  admins <- ctx$admins[ctx$admins$family %in% families, , drop = FALSE]
  funds <- snapshot_funds(ctx$snapshot, admins, families, administrator = a$key)
  by_family <- tapply(funds$net_assets, factor(funds$family, levels = fund_family_order), sum, na.rm = TRUE)
  by_family <- by_family[!is.na(by_family) & by_family > 0]
  s <- administrator_series(ctx$m, admins, a$key, ctx$complete)
  top <- utils::head(funds, 15)
  bslib::card(
    class = "tm-section tm-detail tm-pane",
    bslib::card_header(
      class = "tm-detail-head",
      shiny::div(class = "tm-eyebrow", sprintf("#%d de %d · %s", a$rank, nrow(r),
                                               if (is.na(a$administrator_cnpj)) "sem CNPJ" else a$administrator_cnpj)),
      shiny::h2(class = "tm-detail-title", a$administrator_name),
      shiny::div(class = "tm-detail-meta",
                 shiny::span(shiny::strong("Patrimônio: "), format_brl(a$net_assets)),
                 shiny::span(shiny::strong("Participação: "), format_pct(a$share, sign = FALSE)),
                 shiny::span(shiny::strong("Fundos: "), format_int(a$funds)))),
    bslib::card_body(
      fillable = FALSE,
      if (length(by_family)) share_bar(as.numeric(by_family), fund_family_colors[names(by_family)],
                                       paste(toupper(names(by_family)), "·", fund_family_names[names(by_family)]),
                                       format_brl(as.numeric(by_family))),
      shiny::div(class = "tm-subhead", "Patrimônio dos fundos atuais, mês a mês"),
      svg_line_chart(s$month, s$net_assets, "#0b1f3a",
                     tips = sprintf("%s\nPL %s\n%s fundos", month_label(s$month), format_brl(s$net_assets),
                                    format_int(s$funds)),
                     label = "Patrimônio administrado por mês", height = 210),
      shiny::div(class = "tm-caption", "Série dos fundos que o administrador tem hoje (carteira atual retroagida)."),
      shiny::div(class = "tm-subhead", sprintf("Maiores fundos (%d de %d)", nrow(top), nrow(funds))),
      bar_list(display_name(top$fund_name), top$net_assets, format_brl(top$net_assets),
               colors = unname(fund_family_colors[top$family]),
               sub = sprintf("%s · %s", toupper(top$family), top$fund_cnpj),
               tips = sprintf("%s\n%s do administrador", display_name(top$fund_name),
                              format_pct(top$net_assets / a$net_assets, sign = FALSE)))))
}

# Profile of one fund (used by the fund search detail).
fund_profile_ui <- function(ctx, family, cnpj) {
  p <- fund_profile(ctx$m, ctx$snapshot, family, cnpj)
  if (is.null(p)) return(shiny::div(class = "tm-empty", "Sem patrimônio publicado para este fundo."))
  d <- p$series
  color <- fund_family_colors[[family]]
  rank_text <- if (is.na(p$rank)) "—" else sprintf("#%s de %s", format_int(p$rank), format_int(p$peers))
  shiny::tagList(
    bslib::layout_columns(
      col_widths = c(6, 6, 6, 6), class = "tm-kpis tm-kpis-sm",
      kpi("Patrimônio líquido", format_brl(p$last$net_assets), month_label(p$last$month)),
      kpi("Variação 12 meses", format_pct(p$net_assets_change), "mesmo mês, ano anterior"),
      kpi("Cotistas", format_int(p$last$quotaholders)),
      kpi(sprintf("Posição entre %s", toupper(family)), rank_text,
          if (is.na(p$percentile)) NULL else sprintf("maior que %s dos fundos", format_pct(p$percentile, 0, sign = FALSE)))),
    shiny::div(class = "tm-subhead", "Patrimônio líquido"),
    svg_line_chart(d$month, d$net_assets, color, label = "Patrimônio líquido do fundo", height = 180,
                   tips = sprintf("%s\nPL %s\nFonte: %s, linha %s", month_label(d$month), format_brl(d$net_assets),
                                  d$source_file, d$source_line)),
    if (any(!is.na(d$quotaholders))) shiny::tagList(
      shiny::div(class = "tm-subhead", "Cotistas"),
      svg_line_chart(d$month, d$quotaholders, color, format_value = axis_int, format_tip = format_int,
                     area = FALSE, label = "Número de cotistas do fundo", height = 150)),
    shiny::div(class = "tm-caption", "Valores do informe de cada período (versão mais recente). Passe o mouse para ver o arquivo de origem."))
}
