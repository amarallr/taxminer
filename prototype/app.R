# TaxMiner local Shiny application. Each source family is a separate area,
# enabled only when its dataset exists (docs/architecture.md, item 5).
# Run from the project root:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/run_prototype.R

repo <- if (dir.exists(file.path("..", "src"))) normalizePath("..") else normalizePath(".")
for (f in c("src/common/signatures.R", "src/common/safe_io.R", "src/common/parquet_io.R",
            "src/common/data_layout.R", "src/data/consolidate_fund_reports.R",
            "src/data/build_fund_metrics.R", "src/intelligence/search_fund_reports.R",
            "src/data/entity_resolution.R",
            "src/intelligence/fund_analytics.R", "src/intelligence/panorama_data.R", "prototype/charts.R",
            "prototype/fund_search_module.R", "prototype/fund_dashboard_module.R")) {
  source(file.path(repo, f), local = TRUE, encoding = "UTF-8")
}

data_dir <- resolve_data_dir()
fund_root <- source_data_root(data_dir, "investment_fund_reports")
fund_ready <- file.exists(fund_processed_paths(fund_root)$index)
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
}

unavailable <- function(text) {
  shiny::div(class = "tm-page", shiny::div(class = "alert alert-warning mt-4", text))
}

ui <- bslib::page_navbar(
  title = "TaxMiner", fillable = c("Panorama", "Administradores", "Fundos", toupper(family_tabs)), fluid = TRUE, lang = "pt-BR",
  navbar_options = bslib::navbar_options(bg = "#0b1f3a", theme = "dark"),
  theme = theme,
  header = shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "taxminer.css"), app_script,
                           shiny::tags$script(src = "panorama.js", defer = NA)),
  bslib::nav_panel(
    "Panorama",
    if (fund_ready) panorama_ui("panorama-data/")
    else unavailable("Fase 1.3 indisponível: rode a coleta e a consolidação dos fundos.")),
  bslib::nav_panel(
    "Administradores",
    if (fund_ready) fund_admin_ui("admins") else unavailable("Sem dados consolidados.")),
  bslib::nav_panel(
    "Fundos",
    if (fund_ready) fund_search_ui("funds")
    else unavailable("Fase 1.3 indisponível: rode a coleta e a consolidação dos fundos.")),
  !!!lapply(family_tabs, function(f) bslib::nav_panel(
    toupper(f),
    if (fund_ready) fund_search_ui(paste0("funds_", f), family = f)
    else unavailable("Sem dados consolidados."))),
  bslib::nav_panel(
    "Cobertura e qualidade",
    if (fund_ready) fund_coverage_ui("fund_coverage") else unavailable("Sem dados consolidados.")),
  bslib::nav_panel(
    "Sobre",
    shiny::div(class = "tm-page", shiny::div(
      class = "tm-hero tm-about",
      shiny::div(class = "tm-eyebrow", "Sobre o TaxMiner"),
      shiny::h1("Pesquisa em fontes públicas"),
      shiny::p(class = "tm-lede",
               "Dados públicos da CVM (dados.cvm.gov.br, licença ODbL), com valores como publicados.",
               "Os resultados são material de pesquisa, não conclusões fiscais. As Fases 1.1",
               "(Soluções de Consulta) e 1.2 (notas explicativas) ainda não têm área de busca.")),
      if (fund_ready) method_note(fund_ctx))))

server <- function(input, output, session) {
  if (fund_ready) {
    fund_search_server("funds", fund_root, fund_ctx, data = fund_data)
    lapply(family_tabs, function(f) fund_search_server(paste0("funds_", f), fund_root, fund_ctx,
                                                       data = fund_data, families = f))
    fund_admin_server("admins", fund_ctx)
    fund_coverage_server("fund_coverage", fund_root)
  }
}

shiny::shinyApp(ui, server)
