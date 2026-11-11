# Static export of the fund dashboard for GitHub Pages (site/app/). Run from
# the project root after the fund consolidation:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/export_static_dashboard.R
# The page has the tabs of the local app that work without a server:
# Panorama, Administradores, Fundos and one tab per fund type (FIDC, FII, FIP,
# FIAGRO), built from aggregated public CVM data (ODbL); no raw files. The fund
# tabs read JSON files in the browser (prototype/static_funds.R,
# prototype/static/taxminer_static.js); the report rows (Ficha, Série completa)
# stay in the local app.
# Writes site/app/index.html, taxminer.css, taxminer_static.js, data/ and lib/.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
for (f in c("src/common/signatures.R", "src/common/safe_io.R", "src/common/parquet_io.R",
            "src/common/data_layout.R", "src/data/consolidate_fund_reports.R",
            "src/data/build_fund_metrics.R", "src/intelligence/search_fund_reports.R",
            "src/data/entity_resolution.R",
            "src/intelligence/fund_analytics.R", "prototype/charts.R",
            "prototype/fund_search_module.R", "prototype/fund_dashboard_module.R",
            "prototype/static_funds.R")) {
  source(f, encoding = "UTF-8")
}

out_dir <- file.path("site", "app")
detail_count <- 40L  # administrators with a pre-rendered detail panel
family_tabs <- c("fidc", "fii", "fip", "fiagro")

root <- source_data_root(resolve_data_dir(), "investment_fund_reports")
data <- fund_search_data(root, rules = load_entity_rules(file.path("config", "entity_name_rules.csv")))
ctx <- fund_analytics_context(root, master = data$master)
families <- unname(admin_families)
r <- ctx$ranking
keys <- r$key[seq_len(min(detail_count, nrow(r)))]
generated <- format(Sys.time(), "%Y-%m-%d %H:%M")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fund_files <- write_static_fund_data(out_dir, data, ctx, generated)
admin_files <- write_static_admin_months(out_dir, ctx, keys, families)

# Same one-screen layout as the app tab (fund_admin_ui); the 40 largest
# administrators have a detail panel and a per-month fund file.
admin_area <- htmltools::bindFillRole(shiny::div(
  class = "tm-page tm-fill-page tm-admin-page",
  shiny::div(class = "tm-dash-head",
             shiny::div(shiny::span(class = "tm-eyebrow", "Fase 1.3 · Administradores"),
                        shiny::h1("Concentração da administração fiduciária")),
             shiny::div(class = "tm-dash-meta",
                        sprintf("Participação no patrimônio de FII, FIDC e FIAGRO · clique em um dos %d maiores e em um mês do gráfico",
                                length(keys)))),
  admin_kpis_ui(r, families),
  bslib::layout_columns(
    col_widths = bslib::breakpoints(sm = 12, xl = c(5, 7)), class = "tm-master-detail",
    bslib::card(class = "tm-section tm-pane",
                bslib::card_header(class = "tm-card-head", sprintf("Ranking · %s administradores", format_int(nrow(r)))),
                bslib::card_body(class = "tm-scroll",
                                 admin_ranking_ui(r, input = "admin_pick", selected = keys[1],
                                                  keys = ifelse(r$key %in% keys, r$key, NA)))),
    shiny::div(class = "tm-pane-wrap",
               lapply(seq_along(keys), function(i) shiny::div(
                 `data-detail` = keys[i], hidden = if (i > 1) NA,
                 admin_detail_ui(ctx, r, keys[i], families, data_file = admin_files[i], top = 30L)))))),
  container = TRUE, item = TRUE)

about_area <- shiny::div(
  class = "tm-page",
  shiny::div(class = "tm-hero tm-about",
             shiny::div(class = "tm-eyebrow", "Sobre este painel"),
             shiny::h1("Versão publicada do painel de fundos"),
             shiny::p(class = "tm-lede",
                      sprintf("Gerado em %s a partir dos informes públicos da CVM", generated),
                      "(dados.cvm.gov.br, Open Database License — ODbL). Material de pesquisa, não conclusão fiscal.",
                      "As abas de fundos trazem lista, perfil e denominações; a ficha completa e a série de cada",
                      "informe rodam no app local do TaxMiner."),
             shiny::p(class = "tm-lede", shiny::strong("Não é um serviço oficial"),
                      " da Receita Federal do Brasil nem da CVM, e não tem vinculação institucional com esses órgãos."),
             shiny::p(shiny::tags$a(href = "https://github.com/amarallr/taxminer", "Código no GitHub"), " · ",
                      shiny::tags$a(href = "../", "Página do projeto"))),
  method_note(ctx))

page <- bslib::page_navbar(
  title = "TaxMiner", window_title = "TaxMiner · Painel de fundos",
  fillable = c("Panorama", "Administradores", "Fundos", toupper(family_tabs)), fluid = TRUE,
  navbar_options = bslib::navbar_options(bg = "#0b1f3a", theme = "dark"),
  theme = tm_theme(),
  header = shiny::tags$head(
    shiny::tags$meta(name = "description",
                     content = "Panorama de FII, FIDC, FIP e FIAGRO a partir dos informes públicos da CVM."),
    shiny::tags$link(rel = "stylesheet", href = "taxminer.css"), tm_app_script(),
    shiny::tags$script(src = "taxminer_static.js", defer = NA)),
  bslib::nav_panel("Panorama", fund_overview_ui("overview", ctx)),
  bslib::nav_panel("Administradores", admin_area),
  bslib::nav_panel("Fundos", static_funds_ui()),
  !!!lapply(family_tabs, function(f) bslib::nav_panel(toupper(f), static_funds_ui(f))),
  bslib::nav_panel("Sobre", about_area),
  bslib::nav_spacer(),
  bslib::nav_item(shiny::tags$a(class = "nav-link", href = "../", "Página do projeto")))

unlink(file.path(out_dir, "lib"), recursive = TRUE)  # generated folder, rebuilt below
htmltools::save_html(page, file.path(out_dir, "index.html"), libdir = "lib", lang = "pt-BR")
file.copy("prototype/www/taxminer.css", file.path(out_dir, "taxminer.css"), overwrite = TRUE)
file.copy("prototype/static/taxminer_static.js", file.path(out_dir, "taxminer_static.js"), overwrite = TRUE)
# The theme uses system fonts: the bundled web fonts and the source maps are
# never loaded by the page.
lib <- file.path(out_dir, "lib")
unlink(c(list.files(lib, pattern = "\\.map$", recursive = TRUE, full.names = TRUE),
         list.files(lib, pattern = "^font\\.css$", recursive = TRUE, full.names = TRUE),
         list.dirs(lib)[basename(list.dirs(lib)) == "fonts"]), recursive = TRUE)
size <- sum(file.info(list.files(out_dir, recursive = TRUE, full.names = TRUE))$size)
cat(sprintf("Static dashboard written to %s (%.1f MB, %d administrator panels, %d funds, %d series files).\n",
            out_dir, size / 1024^2, length(keys), fund_files$funds, fund_files$chunks))
