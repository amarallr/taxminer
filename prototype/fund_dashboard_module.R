# Analytical areas of Phase 1.3: market overview (Panorama) and administrator
# concentration. Presentation only: the numbers come from
# src/data/build_fund_metrics.R and src/intelligence/fund_analytics.R.

# Everything the analytical areas share, computed once per app start.
fund_analytics_context <- function(root, directory = load_fund_directory(root), today = Sys.Date(),
                                   master = load_entity_master(root, directory)) {
  metrics <- load_fund_metrics(root)
  m <- prepare_metrics(metrics, today)
  series <- family_monthly(m)
  complete <- complete_months(series)
  snapshot <- market_snapshot(m, complete)
  admins <- fund_administrators(directory, master)
  list(m = m, series = series, complete = complete, overview = family_overview(series, complete),
       snapshot = snapshot, admins = admins, ranking = administrator_ranking(snapshot, admins),
       admin_idx = admin_index(m, snapshot, admins),
       fund_pl = fund_net_assets(m, snapshot),
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

# Version, build time and commit shown under "Sobre" (app and published page):
# the VERSION file at the project root, when the page was generated (export
# time for the published page, start time for the local app) and the commit
# short hash, as "v.1.0.1 · 2026-11-11 15:42 · 3cbb696". The local app passes
# git_commit_label(); the Pages workflow appends the deployed commit to the
# published page. Nothing is shown when VERSION is missing.
version_label <- function(repo = ".", generated = Sys.time(), commit = "") {
  f <- file.path(repo, "VERSION")
  v <- if (file.exists(f)) trimws(readLines(f, n = 1L, warn = FALSE, encoding = "UTF-8")) else ""
  if (!length(v) || !nzchar(v)) return(NULL)
  when <- if (inherits(generated, "POSIXt")) format(generated, "%Y-%m-%d %H:%M") else as.character(generated)
  hash <- if (length(commit) && !is.na(commit[1]) && nzchar(commit[1])) paste0(" · ", commit[1]) else ""
  shiny::div(class = "tm-version", title = "Versão, data/hora de geração e commit desta página",
             paste0("v.", v, " · ", when, hash))
}

# Short hash of the checked-out commit, with "+" when tracked files have
# uncommitted changes; "" when git or the repository is unavailable.
git_commit_label <- function(repo = ".") {
  git <- function(...) tryCatch(suppressWarnings(system2("git", c("-C", shQuote(repo), ...),
                                                         stdout = TRUE, stderr = FALSE)),
                                error = function(e) character())
  h <- git("rev-parse", "--short", "HEAD")
  if (!length(h) || !grepl("^[0-9a-f]{4,40}$", h[1])) return("")
  dirty <- git("status", "--porcelain", "--untracked-files=no")
  paste0(h[1], if (length(dirty)) "+" else "")
}

# Panorama: one landscape screen, no page scrolling (grid in taxminer.css,
# `.tm-dash`). Rendered in the browser by www/panorama.js from the data
# package of src/intelligence/panorama_data.R (`base` = its URL): a central
# filter state (competência, tipos, administradores, fundos) drives every KPI,
# panel and ranking, in the app and on the published page alike.
panorama_ui <- function(base) {
  page <- shiny::div(class = "tm-dash", `data-base` = base,
                     shiny::div(class = "tm-empty", "Carregando o Panorama…"))
  htmltools::bindFillRole(page, item = TRUE)
}

fund_admin_ui <- function(id) {
  ns <- shiny::NS(id)
  # One screen (fillable nav panel): ranking and detail scroll inside their cards.
  page <- shiny::div(
    class = "tm-page tm-fill-page tm-admin-page",
    shiny::div(class = "tm-dash-head",
               shiny::div(shiny::span(class = "tm-eyebrow", "Fase 1.3 · Administradores"),
                          shiny::h1("Concentração da administração fiduciária")),
               shiny::div(class = "tm-dash-meta",
                          "Participação no patrimônio de FII, FIDC e FIAGRO no mês de referência · clique em um administrador, em um mês do gráfico e em um fundo para abri-lo na aba Ficha")),
    shiny::div(class = "tm-filterbar",
               shiny::div(class = "tm-filter-family",
                          shiny::checkboxGroupInput(ns("family"), NULL, choices = admin_families,
                                                    selected = unname(admin_families), inline = TRUE)),
               shiny::div(class = "tm-filter-wide",
                          shiny::selectizeInput(ns("find"), NULL, choices = NULL, width = "100%",
                                                options = list(placeholder = "Buscar administrador (nome ou CNPJ)",
                                                               maxOptions = 50)))),
    shiny::uiOutput(ns("kpis")),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, xl = c(5, 7)), class = "tm-master-detail",
      bslib::card(class = "tm-section tm-pane",
                  bslib::card_header(class = "tm-card-head", shiny::textOutput(ns("list_title"), inline = TRUE)),
                  bslib::card_body(class = "tm-scroll", shiny::uiOutput(ns("ranking")))),
      shiny::div(class = "tm-pane-wrap", shiny::uiOutput(ns("detail")))))
  htmltools::bindFillRole(page, container = TRUE, item = TRUE)
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
    month <- shiny::reactiveVal(NULL)

    shiny::observe({
      r <- ranking()
      shiny::updateSelectizeInput(session, "find", server = TRUE, selected = character(),
                                  choices = stats::setNames(r$key, sprintf("%s · %s", r$administrator_name,
                                                                            ifelse(is.na(r$administrator_cnpj), "sem CNPJ",
                                                                                   format_cnpj(r$administrator_cnpj)))))
      if (is.null(shiny::isolate(picked())) || !shiny::isolate(picked()) %in% r$key) picked(r$key[1])
    })
    shiny::observeEvent(input$pick, picked(input$pick))
    shiny::observeEvent(input$find, if (nzchar(input$find)) picked(input$find))
    # A new administrator or family filter goes back to the reference month.
    shiny::observeEvent(list(picked(), families()), month(NULL))
    shiny::observeEvent(input$month, month(input$month))
    shiny::observeEvent(input$month_reset, month(NULL))

    output$kpis <- shiny::renderUI(admin_kpis_ui(ranking(), families()))

    output$list_title <- shiny::renderText(sprintf("Ranking · %s administradores", format_int(nrow(ranking()))))

    output$ranking <- shiny::renderUI({
      admin_ranking_ui(ranking(), input = ns("pick"), selected = shiny::isolate(picked()))
    })

    output$detail <- shiny::renderUI({
      r <- ranking()
      shiny::req(picked(), picked() %in% r$key)
      admin_detail_ui(ctx, r, picked(), families(), month_input = ns("month"),
                      funds = shiny::uiOutput(ns("funds")))
    })

    output$funds <- shiny::renderUI({
      r <- ranking()
      shiny::req(picked(), picked() %in% r$key)
      admin_funds_ui(ctx, r, picked(), families(), month(), reset = ns("month_reset"), fund_selected = fund_sel())
    })

    # Current fund of the app ("family|CNPJ"): its administrator and the fund in the list.
    fund_sel <- shiny::reactiveVal(NULL)
    list(show = function(value) {
      p <- strsplit(value, "|", fixed = TRUE)[[1]]
      s <- if (is.null(ctx$admin_idx)) NULL else ctx$admin_idx$snapshot
      if (length(p) != 2L || is.null(s)) return(invisible())
      hit <- unique(s$key[s$family == p[1] & s$fund_cnpj == p[2]])
      hit <- hit[hit %in% shiny::isolate(ranking())$key]
      if (!length(hit)) return(invisible())
      picked(hit[1]); month(NULL); fund_sel(value)
      # The ranking is not redrawn (its scroll is kept): the row is marked in the browser.
      session$sendCustomMessage("tm-pick-row", list(input = ns("pick"), key = hit[1]))
    })
  })
}

admin_ranking_ui <- function(r, input, selected = NULL, keys = r$key) {
  bar_list(r$administrator_name, r$net_assets,
           sprintf("%s · %s", format_brl(r$net_assets), format_pct(r$share, sign = FALSE)),
           colors = "#0b1f3a", rank = r$rank, keys = keys, input = input, selected = selected,
           sub = sprintf("%s fundos · %s", format_int(r$funds), r$families),
           tips = sprintf("%s\nAcumulado até aqui: %s", r$administrator_name,
                          format_pct(r$cumulative_share, sign = FALSE)))
}

admin_kpis_ui <- function(r, families) {
  h <- attr(r, "hhi")
  share_at <- function(n) format_pct(r$cumulative_share[min(n, nrow(r))], sign = FALSE)
  shiny::div(
    class = "tm-kpi-row tm-kpis-sm",
    kpi("Patrimônio administrado", format_brl(attr(r, "total")), paste(toupper(families), collapse = " · ")),
    kpi("Administradores", format_int(nrow(r))),
    kpi("HHI", format_int(round(h)), hhi_label(h)),
    kpi("Participação dos maiores", share_at(5), sprintf("5 maiores · 10 maiores: %s", share_at(10))))
}

# Fund rows of the detail card: the reference-month snapshot (month = NULL)
# or the funds behind one point of the chart. `reset` is the Shiny input that
# goes back to the reference month; `top` keeps only the largest funds of the
# reference month (static page).
admin_funds_ui <- function(ctx, r, key, families, month = NULL, reset = NULL, top = NULL, fund_selected = NULL) {
  a <- r[r$key == key, ]
  admins <- ctx$admins[ctx$admins$family %in% families, , drop = FALSE]
  idx <- ctx$admin_idx
  if (is.null(month)) {
    f <- if (is.null(idx)) snapshot_funds(ctx$snapshot, admins, families, administrator = key)
         else admin_snapshot_funds(idx, families, key)
    f$carried <- FALSE
    title <- sprintf("Fundos no mês de referência (%s)", format_int(nrow(f)))
    if (!is.null(top) && nrow(f) > top) {
      title <- sprintf("Maiores fundos no mês de referência (%d de %s)", top, format_int(nrow(f)))
      f <- f[seq_len(top), , drop = FALSE]
    }
    note <- "clique em um mês do gráfico para ver os fundos daquela competência"
    total <- a$net_assets
  } else {
    f <- if (is.null(idx)) administrator_month_funds(ctx$m, admins, key, month)
         else admin_month_funds(ctx$m, idx, ctx$admins, families, key, month)
    title <- sprintf("Fundos em %s (%s) · %s", month_label(month), format_int(nrow(f)),
                     format_brl(sum(f$net_assets, na.rm = TRUE)))
    note <- if (any(f$carried)) "* valor repetido do último informe" else NULL
    total <- sum(f$net_assets, na.rm = TRUE)
  }
  names <- display_name(f$fund_name)
  shiny::tagList(
    shiny::div(class = "tm-subhead tm-funds-head", shiny::span(title),
               if (!is.null(note)) shiny::span(class = "tm-head-note", note),
               if (!is.null(month) && !is.null(reset))
                 shiny::tags$a(href = "#", class = "tm-month-reset",
                               onclick = sprintf("Shiny.setInputValue('%s', Date.now(), {priority: 'event'}); return false;", reset),
                               "voltar ao mês de referência")),
    if (!nrow(f)) shiny::div(class = "tm-empty", "Sem fundos neste mês.")
    else bar_list(paste0(names, ifelse(f$carried, " *", "")), f$net_assets,
                  # PL and share of the administrator's total, as in the Panorama lists.
                  paste(format_brl(f$net_assets), "·",
                        format_pct(if (isTRUE(total > 0)) f$net_assets / total else NA_real_, sign = FALSE)),
                  colors = unname(fund_family_colors[f$family]),
                  sub = sprintf("%s · %s", toupper(f$family), format_cnpj(f$fund_cnpj)),
                  fund_keys = paste(f$family, f$fund_cnpj, sep = "|"), fund_selected = fund_selected,
                  tips = sprintf("%s\n%s do total", names, format_pct(f$net_assets / total, sign = FALSE))))
}

# Detail card of one administrator (`key` from administrator_key()) within
# ranking `r`. `funds` is the fund list area (a Shiny output in the app, the
# reference month on the static page); `month_input` names the Shiny input
# that receives a month clicked on the chart; `data_file` is the static page's
# per-month fund file (prototype/static_funds.R).
admin_detail_ui <- function(ctx, r, key, families, month_input = NULL, funds = NULL, data_file = NULL, top = NULL) {
  a <- r[r$key == key, ]
  admins <- ctx$admins[ctx$admins$family %in% families, , drop = FALSE]
  idx <- ctx$admin_idx
  sf <- if (is.null(idx)) snapshot_funds(ctx$snapshot, admins, families, administrator = a$key)
        else admin_snapshot_funds(idx, families, a$key)
  by_family <- tapply(sf$net_assets, factor(sf$family, levels = fund_family_order), sum, na.rm = TRUE)
  by_family <- by_family[!is.na(by_family) & by_family > 0]
  s <- if (is.null(idx)) administrator_series(ctx$m, admins, a$key, ctx$complete)
       else admin_series(ctx$m, idx, families, a$key, ctx$complete)
  if (is.null(funds)) funds <- admin_funds_ui(ctx, r, key, families, top = top)
  bslib::card(
    class = "tm-section tm-detail tm-pane tm-admin-detail",
    bslib::card_header(
      class = "tm-detail-head",
      shiny::div(class = "tm-eyebrow", sprintf("#%d de %d · %s", a$rank, nrow(r),
                                               if (is.na(a$administrator_cnpj)) "sem CNPJ" else format_cnpj(a$administrator_cnpj))),
      shiny::h2(class = "tm-detail-title", a$administrator_name),
      shiny::div(class = "tm-detail-meta",
                 shiny::span(shiny::strong("Patrimônio: "), format_brl(a$net_assets)),
                 shiny::span(shiny::strong("Participação: "), format_pct(a$share, sign = FALSE)),
                 shiny::span(shiny::strong("Fundos: "), format_int(a$funds)))),
    shiny::div(
      class = "tm-admin-body", `data-month-input` = if (is.null(month_input)) "" else month_input,
      `data-admin` = key, `data-admin-file` = data_file,
      shiny::div(
        class = "tm-admin-top",
        if (length(by_family)) share_bar(as.numeric(by_family), fund_family_colors[names(by_family)],
                                         paste(toupper(names(by_family)), "·", fund_family_names[names(by_family)]),
                                         format_brl(as.numeric(by_family))),
        shiny::div(class = "tm-subhead", "Patrimônio dos fundos atuais, mês a mês ",
                   shiny::span(class = "tm-head-note", "carteira atual retroagida · clique em um mês")),
        svg_line_chart(s$month, s$net_assets, "#0b1f3a",
                       tips = sprintf("%s\nPL %s\n%s fundos\nClique para listar os fundos", month_label(s$month),
                                      format_brl(s$net_assets), format_int(s$funds)),
                       label = "Patrimônio administrado por mês", width = 760, height = 120, pick = TRUE)),
      shiny::div(class = "tm-admin-funds", funds)))
}

# Profile of one fund (used by the fund search detail).
fund_profile_ui <- function(ctx, family, cnpj) {
  p <- fund_profile(ctx$m, ctx$snapshot, family, cnpj)
  if (is.null(p)) return(shiny::div(class = "tm-empty", "Sem patrimônio publicado para este fundo."))
  d <- p$series
  color <- fund_family_colors[[family]]
  rank_text <- if (is.na(p$rank)) "—" else sprintf("#%s de %s", format_int(p$rank), format_int(p$peers))
  has_holders <- any(!is.na(d$quotaholders))
  # Compact: four KPIs across, the two charts side by side (fits the detail pane).
  shiny::tagList(
    shiny::div(
      class = "tm-kpi-row tm-kpis-sm",
      kpi("Patrimônio líquido", format_brl(p$last$net_assets), month_label(p$last$month)),
      kpi("Variação 12 meses", format_pct(p$net_assets_change), "mesmo mês, ano anterior"),
      kpi("Cotistas", format_int(p$last$quotaholders)),
      kpi(sprintf("Posição entre %s", toupper(family)), rank_text,
          if (is.na(p$percentile)) NULL else sprintf("maior que %s dos fundos", format_pct(p$percentile, 0, sign = FALSE)))),
    # One chart: net assets on the left axis, quotaholders (dashed) on the right.
    shiny::div(
      class = "tm-profile-charts tm-one",
      shiny::div(
        shiny::div(class = "tm-subhead tm-subhead-key",
                   shiny::span(if (has_holders) "Patrimônio líquido e cotistas" else "Patrimônio líquido"),
                   if (has_holders) chart_key(color, "Patrimônio líquido (eixo esquerdo)", "Cotistas (eixo direito)")),
        svg_line_chart(d$month, d$net_assets, color, height = 180, width = 760,
                       label = if (has_holders) "Patrimônio líquido (eixo esquerdo) e número de cotistas (eixo direito) do fundo"
                               else "Patrimônio líquido do fundo",
                       values2 = if (has_holders) d$quotaholders,
                       tips = sprintf("%s\nPL %s%s\nFonte: %s, linha %s", month_label(d$month), format_brl(d$net_assets),
                                      ifelse(is.na(d$quotaholders), "", paste0("\nCotistas ", format_int(d$quotaholders))),
                                      d$source_file, d$source_line)))),
    shiny::div(class = "tm-caption", "Valores do informe de cada período (versão mais recente). Passe o mouse para ver o arquivo de origem."))
}
