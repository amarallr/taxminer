# Static export of the fund dashboard for GitHub Pages (site/app/). Run from
# the project root after the fund consolidation:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/export_static_dashboard.R
# The page is the Panorama and Administradores areas of the local app, built
# from aggregated public CVM data (ODbL); no server and no raw files. The full
# fund search over the report rows stays in the local app.
# Writes site/app/index.html, site/app/taxminer.css and site/app/lib/.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
for (f in c("src/common/signatures.R", "src/common/safe_io.R", "src/common/parquet_io.R",
            "src/common/data_layout.R", "src/data/consolidate_fund_reports.R",
            "src/data/build_fund_metrics.R", "src/intelligence/search_fund_reports.R",
            "src/intelligence/fund_analytics.R", "prototype/charts.R",
            "prototype/fund_search_module.R", "prototype/fund_dashboard_module.R")) {
  source(f, encoding = "UTF-8")
}

out_dir <- file.path("site", "app")
detail_count <- 40L  # administrators with a pre-rendered detail panel

root <- source_data_root(resolve_data_dir(), "investment_fund_reports")
ctx <- fund_analytics_context(root)
families <- unname(admin_families)
r <- ctx$ranking
keys <- r$key[seq_len(min(detail_count, nrow(r)))]
generated <- format(Sys.time(), "%Y-%m-%d %H:%M")

admin_area <- shiny::div(
  class = "tm-page",
  shiny::div(class = "tm-hero",
             shiny::div(class = "tm-eyebrow", "Fase 1.3 · Administradores"),
             shiny::h1("Concentração da administração fiduciária"),
             shiny::p(class = "tm-lede",
                      "Participação de cada administrador no patrimônio de FII, FIDC e FIAGRO no mês de referência.",
                      sprintf("Clique em um dos %d maiores para ver a série e os fundos.", length(keys)))),
  admin_kpis_ui(r, families),
  bslib::layout_columns(
    col_widths = bslib::breakpoints(sm = 12, xl = c(5, 7)), class = "tm-master-detail",
    bslib::card(class = "tm-section tm-pane",
                bslib::card_header(sprintf("Ranking · %s administradores", format_int(nrow(r)))),
                bslib::card_body(class = "tm-scroll", bar_list(
                  r$administrator_name, r$net_assets,
                  sprintf("%s · %s", format_brl(r$net_assets), format_pct(r$share, sign = FALSE)),
                  colors = "#0b1f3a", rank = r$rank, keys = ifelse(r$key %in% keys, r$key, NA),
                  input = "admin_pick", selected = keys[1],
                  sub = sprintf("%s fundos · %s", format_int(r$funds), r$families),
                  tips = sprintf("%s\nAcumulado até aqui: %s", r$administrator_name,
                                 format_pct(r$cumulative_share, sign = FALSE))))),
    shiny::div(class = "tm-pane-wrap",
               lapply(keys, function(k) shiny::div(`data-detail` = k, hidden = if (k != keys[1]) NA,
                                                   admin_detail_ui(ctx, r, k, families))))))

about_area <- shiny::div(
  class = "tm-page",
  shiny::div(class = "tm-hero tm-about",
             shiny::div(class = "tm-eyebrow", "Sobre este painel"),
             shiny::h1("Versão publicada do painel de fundos"),
             shiny::p(class = "tm-lede",
                      sprintf("Gerado em %s a partir dos informes públicos da CVM", generated),
                      "(dados.cvm.gov.br, Open Database License — ODbL). Material de pesquisa, não conclusão fiscal.",
                      "A busca completa nos informes de cada fundo roda no app local do TaxMiner."),
             shiny::p(class = "tm-lede", shiny::strong("Não é um serviço oficial"),
                      " da Receita Federal do Brasil nem da CVM, e não tem vinculação institucional com esses órgãos."),
             shiny::p(shiny::tags$a(href = "https://github.com/amarallr/taxminer", "Código no GitHub"), " · ",
                      shiny::tags$a(href = "../", "Página do projeto"))),
  method_note(ctx))

page <- bslib::page_navbar(
  title = "TaxMiner", window_title = "TaxMiner · Painel de fundos", fillable = "Panorama", fluid = TRUE,
  navbar_options = bslib::navbar_options(bg = "#0b1f3a", theme = "dark"),
  theme = tm_theme(),
  header = shiny::tags$head(
    shiny::tags$meta(name = "description",
                     content = "Panorama de FII, FIDC, FIP e FIAGRO a partir dos informes públicos da CVM."),
    shiny::tags$link(rel = "stylesheet", href = "taxminer.css"), tm_app_script()),
  bslib::nav_panel("Panorama", fund_overview_ui("overview", ctx)),
  bslib::nav_panel("Administradores", admin_area),
  bslib::nav_panel("Sobre", about_area),
  bslib::nav_spacer(),
  bslib::nav_item(shiny::tags$a(class = "nav-link", href = "../", "Página do projeto")))

unlink(file.path(out_dir, "lib"), recursive = TRUE)  # generated folder, rebuilt below
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
htmltools::save_html(page, file.path(out_dir, "index.html"), libdir = "lib", lang = "pt-BR")
file.copy("prototype/www/taxminer.css", file.path(out_dir, "taxminer.css"), overwrite = TRUE)
# The theme uses system fonts: the bundled web fonts and the source maps are
# never loaded by the page.
lib <- file.path(out_dir, "lib")
unlink(c(list.files(lib, pattern = "\\.map$", recursive = TRUE, full.names = TRUE),
         list.files(lib, pattern = "^font\\.css$", recursive = TRUE, full.names = TRUE),
         list.dirs(lib)[basename(list.dirs(lib)) == "fonts"]), recursive = TRUE)
size <- sum(file.info(list.files(out_dir, recursive = TRUE, full.names = TRUE))$size)
cat(sprintf("Static dashboard written to %s (%.1f MB, %d administrator panels).\n",
            out_dir, size / 1024^2, length(keys)))
