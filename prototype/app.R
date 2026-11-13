# TaxMiner local Shiny application. Each source family is a separate area,
# enabled only when its dataset exists (docs/architecture.md, item 5).
# Run from the project root:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/run_prototype.R

repo <- if (dir.exists(file.path("..", "src"))) normalizePath("..") else normalizePath(".")
for (f in c("src/common/signatures.R", "src/common/safe_io.R", "src/common/parquet_io.R",
            "src/common/data_layout.R", "src/data/consolidate_fund_reports.R",
            "src/data/build_fund_metrics.R", "src/intelligence/search_fund_reports.R",
            "src/data/entity_resolution.R",
            "src/intelligence/fund_analytics.R", "src/intelligence/panorama_data.R",
            "src/intelligence/cedente_data.R", "src/collect/download_fund_reports.R",
            "src/collect/collect_cvm_registries.R", "src/data/cvm_registry_names.R",
            "src/collect/collect_rfb_cnpj.R", "src/data/rfb_company_names.R", "prototype/charts.R",
            "prototype/fund_search_module.R", "prototype/fund_dashboard_module.R",
            "prototype/fund_record_module.R", "src/common/governance_registry.R",
            "src/common/governance_prompts.R", "src/common/governance_agents.R",
            "src/common/governance_metrics.R", "src/common/governance_views.R", "prototype/governance_module.R",
            "src/common/owner_mode.R")) {
  source(file.path(repo, f), local = TRUE, encoding = "UTF-8")
}

data_dir <- resolve_data_dir()
fund_root <- source_data_root(data_dir, "investment_fund_reports")
fund_ready <- file.exists(fund_processed_paths(fund_root)$index)
# Owner-only tabs (src/common/owner_mode.R): TAXMINER_OWNER_MODE=1 in the owner's user profile.
owner_mode <- taxminer_owner_mode()
# Shared once by every fund tab: directory, entity catalogs (processed/master),
# tables and dictionaries. Derived metrics and catalogs are rebuilt only when
# their inputs change.
fund_data <- if (fund_ready) {
  fund_search_data(fund_root, rules = load_entity_rules(file.path(repo, "config", "entity_name_rules.csv")))
} else NULL
fund_ctx <- if (fund_ready) fund_analytics_context(fund_root, master = fund_data$master) else NULL
# One tab per fund type, after Fundos.
family_tabs <- c("fidc", "fii", "fip", "fiagro")

# Tooltips and clickable rows (prototype/charts.R).
app_script <- tm_app_script()

theme <- tm_theme()

# Panorama data package (processed/metrics/panorama, rebuilt only when its
# inputs change), read by www/panorama.js.
if (fund_ready) {
  shiny::addResourcePath("panorama-data", load_panorama_data(fund_root, fund_ctx, fund_data$directory, fund_data$master))
  # FIDC cedentes (processed/metrics/cedentes), read by www/cedentes.js.
  # Names of cedentes without a catalog entity: CVM registries
  # (scripts/collect_cvm_registries.R), when collected.
  shiny::addResourcePath("cedentes-data", load_cedente_data(fund_root, fund_data, unname(fund_ctx$complete["fidc"]),
                                                            registry = load_cvm_registry_names(cvm_registry_root(data_dir)),
                                                            rfb_root = cvm_registry_root(data_dir)))
}

unavailable <- function(text) {
  shiny::div(class = "tm-page", shiny::div(class = "alert alert-warning mt-4", text))
}

ui <- bslib::page_navbar(
  id = "nav", title = tm_brand(), window_title = "TaxMiner", fillable = c("Panorama", "Administradores", "Fundos", "Ficha"), fluid = TRUE, lang = "pt-BR",
  navbar_options = bslib::navbar_options(bg = "#0b1f3a", theme = "dark"),
  theme = theme,
  header = shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "taxminer.css"), app_script,
                           shiny::tags$script(src = "loadbar.js", defer = NA),
                           shiny::tags$script(src = "panorama.js", defer = NA),
                           shiny::tags$script(src = "cedentes.js", defer = NA)),
  bslib::nav_panel(
    "Panorama",
    if (fund_ready) panorama_ui("panorama-data/")
    else unavailable("Fase 1.3 indisponível: rode a coleta e a consolidação dos fundos.")),
  bslib::nav_panel(
    "Administradores",
    if (fund_ready) fund_admin_ui("admins") else unavailable("Sem dados consolidados.")),
  # Fundos: all funds and one sub tab per fund type; Cedentes inside FIDC
  # (tm_fund_tabs in prototype/charts.R, shared with the published page).
  bslib::nav_panel(
    "Fundos",
    if (fund_ready) tm_fund_tabs(
      fund_search_ui("funds"),
      stats::setNames(lapply(family_tabs, function(f) fund_search_ui(paste0("funds_", f), family = f)), family_tabs),
      cedentes_ui("cedentes-data/"))
    else unavailable("Fase 1.3 indisponível: rode a coleta e a consolidação dos fundos.")),
  # Ficha and Série completa of any fund on the whole width.
  bslib::nav_panel(
    "Ficha",
    if (fund_ready) fund_record_ui("record") else unavailable("Sem dados consolidados.")),
  bslib::nav_panel(
    "Cobertura e qualidade",
    if (fund_ready) fund_coverage_ui("fund_coverage") else unavailable("Sem dados consolidados.")),
  # Governance records of the project: owner only (taxminer_owner_mode(); never in the
  # published page or in any installer).
  if (owner_mode) bslib::nav_panel("Governança", governance_ui("governance")),
  bslib::nav_panel(
    "Sobre",
    shiny::div(class = "tm-page", shiny::div(
      class = "tm-hero tm-about",
      shiny::div(class = "tm-eyebrow", "Sobre o TaxMiner"),
      version_label(repo, commit = git_commit_label(repo)),
      shiny::h1("Pesquisa em fontes públicas"),
      shiny::p(class = "tm-lede",
               "Dados públicos da CVM (dados.cvm.gov.br, licença ODbL), com valores como publicados.",
               "Os resultados são material de pesquisa, não conclusões fiscais. As Fases 1.1",
               "(Soluções de Consulta) e 1.2 (notas explicativas) ainda não têm área de busca.")),
      if (fund_ready) method_note(fund_ctx))))

server <- function(input, output, session) {
  if (owner_mode) governance_server("governance", repo)
  if (fund_ready) {
    tabs <- list(Fundos = fund_search_server("funds", fund_root, fund_ctx, data = fund_data))
    for (f in family_tabs) tabs[[toupper(f)]] <- fund_search_server(paste0("funds_", f), fund_root, fund_ctx,
                                                                   data = fund_data, families = f)
    record <- fund_record_server("record", fund_root, fund_data, fund_ctx)
    admin <- fund_admin_server("admins", fund_ctx)
    # Current fund ("family|CNPJ"): the last fund the user selected in any tab.
    # Every tab shows it when opened: the fund tabs, FICHA and Administradores
    # here; Panorama and Cedentes in the browser (window.tmCurrent, kept in
    # step by the message tm-current and the input current_fund).
    current <- shiny::reactiveVal(NULL)
    set_current <- function(value) {
      if (is.null(value) || !nzchar(value) || identical(value, shiny::isolate(current()))) return()
      current(value)
      session$sendCustomMessage("tm-current", value)
    }
    shiny::observeEvent(input$current_fund, current(input$current_fund))
    lapply(names(tabs), function(t) shiny::observeEvent(tabs[[t]]$chosen(), set_current(tabs[[t]]$chosen())))
    shiny::observeEvent(record$fund(), if (identical(input$nav, "Ficha")) set_current(record$fund()))
    # Visible area: the top tab, or inside Fundos the sub tab ("Todos" is the
    # all-funds list, keyed "Fundos"; "Fundos FIDC" is the FIDC list).
    active_tab <- shiny::reactive({
      if (!identical(input$nav, "Fundos")) return(input$nav)
      sub <- input$fund_nav
      if (is.null(sub) || identical(sub, "Todos")) return("Fundos")
      if (identical(sub, "FIDC") && identical(input$fidc_nav, "Cedentes")) return("Cedentes")
      sub
    })
    shiny::observeEvent(active_tab(), {
      value <- shiny::isolate(current())
      tab <- active_tab()
      if (is.null(value) || is.null(tab)) return()
      if (identical(tab, "Ficha")) record$open(value)
      else if (tab %in% names(tabs)) tabs[[tab]]$show(value)
      else if (identical(tab, "Administradores")) admin$show(value)
    })
    fund_coverage_server("fund_coverage", fund_root)
  }
}

shiny::shinyApp(ui, server)
