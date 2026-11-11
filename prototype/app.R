# TaxMiner local Shiny application. Each source family is a separate area,
# enabled only when its dataset exists (docs/architecture.md, item 5).
# Run from the project root:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/run_prototype.R

repo <- if (dir.exists(file.path("..", "src"))) normalizePath("..") else normalizePath(".")
for (f in c("src/common/signatures.R", "src/common/safe_io.R", "src/common/parquet_io.R",
            "src/common/data_layout.R", "src/data/consolidate_fund_reports.R",
            "src/data/build_fund_metrics.R", "src/intelligence/search_fund_reports.R",
            "src/intelligence/fund_analytics.R", "prototype/charts.R",
            "prototype/fund_search_module.R", "prototype/fund_dashboard_module.R")) {
  source(file.path(repo, f), local = TRUE, encoding = "UTF-8")
}

data_dir <- resolve_data_dir()
fund_root <- source_data_root(data_dir, "investment_fund_reports")
fund_ready <- file.exists(fund_processed_paths(fund_root)$index)
# Derived metrics are rebuilt only when the consolidated tables change.
fund_ctx <- if (fund_ready) fund_analytics_context(fund_root) else NULL

# Shared behaviour: hover tooltips for every element with `data-tip`, and
# clickable rows (`.tm-pick`) that send their `data-key` to `data-input`.
app_script <- shiny::tags$script(shiny::HTML("
$(function() {
  var tip = $('<div>').addClass('tm-tooltip').attr('role', 'tooltip').appendTo('body');
  $(document).on('mouseenter', '[data-tip]', function() { tip.text($(this).attr('data-tip')).show(); })
    .on('mousemove', '[data-tip]', function(e) {
      var w = tip.outerWidth(), x = e.pageX + 14;
      if (x + w > $(window).scrollLeft() + $(window).width() - 8) x = e.pageX - w - 14;
      tip.css({left: x, top: e.pageY + 14});
    })
    .on('mouseleave', '[data-tip]', function() { tip.hide(); })
    .on('click', '.tm-pick[data-key]', function() {
      $(this).siblings('.tm-selected').removeClass('tm-selected');
      $(this).addClass('tm-selected');
      Shiny.setInputValue($(this).attr('data-input'), $(this).attr('data-key'), {priority: 'event'});
    });
});"))

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
  header = shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "taxminer.css"), app_script),
  bslib::nav_panel(
    "Panorama",
    if (fund_ready) fund_overview_ui("overview", fund_ctx)
    else unavailable("Fase 1.3 indisponível: rode a coleta e a consolidação dos fundos.")),
  bslib::nav_panel(
    "Fundos",
    if (fund_ready) fund_search_ui("funds")
    else unavailable("Fase 1.3 indisponível: rode a coleta e a consolidação dos fundos.")),
  bslib::nav_panel(
    "Administradores",
    if (fund_ready) fund_admin_ui("admins") else unavailable("Sem dados consolidados.")),
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
    fund_search_server("funds", fund_root, fund_ctx)
    fund_admin_server("admins", fund_ctx)
    fund_coverage_server("fund_coverage", fund_root)
  }
}

shiny::shinyApp(ui, server)
