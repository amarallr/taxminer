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

unavailable <- function(text) shiny::div(class = "alert alert-warning", text)

ui <- shiny::navbarPage(
  "TaxMiner",
  shiny::tabPanel(
    "Fundos de investimento",
    if (fund_ready) fund_search_ui("funds")
    else unavailable("Fase 1.3 indisponível: rode a coleta e a consolidação dos fundos.")),
  shiny::tabPanel(
    "Fundos: cobertura",
    if (fund_ready) fund_coverage_ui("fund_coverage") else unavailable("Sem dados consolidados.")),
  shiny::tabPanel(
    "Sobre",
    shiny::p("Dados públicos da CVM (dados.cvm.gov.br, licença ODbL), com valores como",
             "publicados. Resultados são pesquisa, não conclusões fiscais."),
    shiny::p("Fases 1.1 (Soluções de Consulta) e 1.2 (notas explicativas) ainda sem área",
             "de busca.")))

server <- function(input, output, session) {
  if (fund_ready) {
    fund_search_server("funds", fund_root)
    fund_coverage_server("fund_coverage", fund_root)
  }
}

shiny::shinyApp(ui, server)
