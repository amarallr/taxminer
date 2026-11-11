# TaxMiner local Shiny application. Each source family is a separate area,
# enabled only when its dataset exists (docs/architecture.md, item 5).
# Run from the project root:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/run_prototype.R

repo <- if (dir.exists(file.path("..", "src"))) normalizePath("..") else normalizePath(".")
for (f in c("src/common/signatures.R", "src/common/safe_io.R", "src/common/parquet_io.R",
            "src/common/data_layout.R", "src/data/consolidate_fund_reports.R",
            "src/intelligence/search_fund_reports.R", "prototype/fund_search_module.R")) {
  source(file.path(repo, f), local = TRUE, encoding = "UTF-8")
}

data_dir <- resolve_data_dir()
fund_root <- source_data_root(data_dir, "investment_fund_reports")
fund_ready <- file.exists(fund_processed_paths(fund_root)$index)

theme <- bslib::bs_theme(
  version = 5, bg = "#ffffff", fg = "#1c2430", primary = "#0b1f3a", secondary = "#5b6573",
  base_font = bslib::font_collection("Segoe UI", "Helvetica Neue", "Arial", "sans-serif"),
  heading_font = bslib::font_collection("Georgia", "Times New Roman", "serif"),
  "border-radius" = "2px")

unavailable <- function(text) {
  shiny::div(class = "tm-page", shiny::div(class = "alert alert-warning mt-4", text))
}

ui <- bslib::page_navbar(
  title = "TaxMiner", fillable = FALSE, fluid = TRUE,
  navbar_options = bslib::navbar_options(bg = "#0b1f3a", theme = "dark"),
  theme = theme,
  header = shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "taxminer.css")),
  bslib::nav_panel(
    "Fundos de investimento",
    if (fund_ready) fund_search_ui("funds")
    else unavailable("Fase 1.3 indisponível: rode a coleta e a consolidação dos fundos.")),
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
               "(Soluções de Consulta) e 1.2 (notas explicativas) ainda não têm área de busca.")))))

server <- function(input, output, session) {
  if (fund_ready) {
    fund_search_server("funds", fund_root)
    fund_coverage_server("fund_coverage", fund_root)
  }
}

shiny::shinyApp(ui, server)
