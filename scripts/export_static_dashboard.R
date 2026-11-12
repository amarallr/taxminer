# Static export of the fund dashboard for GitHub Pages (site/app/). Run from
# the project root after the fund consolidation:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/export_static_dashboard.R
# The page has the tabs of the local app that work without a server:
# Panorama, Administradores, Fundos and one tab per fund type (FIDC, FII, FIP,
# FIAGRO), built from aggregated public CVM data (ODbL); no raw files. The fund
# tabs read JSON files in the browser (prototype/static_funds.R,
# prototype/static/taxminer_static.js); Ficha and Série completa read one file
# per fund with the main report tables (write_static_fichas) and, for FIDC,
# one gzip file per fund with the other tables (write_static_ficha_extras);
# the other FII, FIP and FIAGRO tables stay in the local app.
# Writes site/app/index.html, taxminer.css, taxminer_static.js, data/ and lib/.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
for (f in c("src/common/signatures.R", "src/common/safe_io.R", "src/common/parquet_io.R",
            "src/common/data_layout.R", "src/data/consolidate_fund_reports.R",
            "src/data/build_fund_metrics.R", "src/intelligence/search_fund_reports.R",
            "src/data/entity_resolution.R",
            "src/intelligence/fund_analytics.R", "src/intelligence/panorama_data.R",
            "src/intelligence/cedente_data.R", "prototype/charts.R",
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
# TAXMINER_KEEP_FICHAS=1 keeps data/fichas/ as is (the slowest part, it reads
# every main report table); use it only when the consolidation did not change.
fichas <- if (nzchar(Sys.getenv("TAXMINER_KEEP_FICHAS")) && dir.exists(file.path(out_dir, "data", "fichas"))) {
  list(funds = length(list.files(file.path(out_dir, "data", "fichas"), pattern = "\\.json$", recursive = TRUE)) - 1L)
} else write_static_fichas(out_dir, root, data)
# Other FIDC tables, gzip compressed, read only when chosen (data/fichas_x/).
# TAXMINER_KEEP_FICHAS_X=1 keeps them as they are.
fichas_x <- if (nzchar(Sys.getenv("TAXMINER_KEEP_FICHAS_X")) && dir.exists(file.path(out_dir, "data", "fichas_x"))) {
  list(funds = length(list.files(file.path(out_dir, "data", "fichas_x"), pattern = "\\.json\\.gz$", recursive = TRUE)) - 1L)
} else write_static_ficha_extras(out_dir, root, data)
admin_files <- write_static_admin_months(out_dir, ctx, keys, families)
cedentes <- write_cedente_data(file.path(out_dir, "data", "cedentes"), read_fidc_cedentes(root),
                               cedente_funds(data), data$master, unname(ctx$complete["fidc"]))
panorama <- write_panorama_data(file.path(out_dir, "data", "panorama"), ctx, data$directory, data$master, generated)

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
             version_label(".", generated),
             shiny::h1("Versão publicada do painel de fundos"),
             shiny::p(class = "tm-lede",
                      sprintf("Gerado em %s a partir dos informes públicos da CVM", generated),
                      "(dados.cvm.gov.br, Open Database License — ODbL). Material de pesquisa, não conclusão fiscal.",
                      "As abas de fundos trazem lista, perfil, ficha, série completa e denominações das tabelas",
                      "principais de cada tipo; as demais tabelas dos informes ficam no app local do TaxMiner."),
             shiny::p(class = "tm-lede", shiny::strong("Não é um serviço oficial"),
                      " da Receita Federal do Brasil nem da CVM, e não tem vinculação institucional com esses órgãos."),
             shiny::p(shiny::tags$a(href = "https://github.com/amarallr/taxminer", "Código no GitHub"), " · ",
                      shiny::tags$a(href = "../", "Página do projeto"))),
  method_note(ctx))

page <- bslib::page_navbar(
  title = "TaxMiner", window_title = "TaxMiner · Painel de fundos",
  fillable = c("Panorama", "Administradores", "Fundos", toupper(family_tabs), "Cedentes", "Ficha"), fluid = TRUE,
  navbar_options = bslib::navbar_options(bg = "#0b1f3a", theme = "dark"),
  theme = tm_theme(),
  header = shiny::tags$head(
    shiny::tags$meta(name = "description",
                     content = "Panorama de FII, FIDC, FIP e FIAGRO a partir dos informes públicos da CVM."),
    shiny::tags$link(rel = "stylesheet", href = "taxminer.css"), tm_app_script(),
    shiny::tags$script(src = "panorama.js", defer = NA), shiny::tags$script(src = "taxminer_static.js", defer = NA),
    shiny::tags$script(src = "cedentes.js", defer = NA)),
  bslib::nav_panel("Panorama", panorama_ui("data/panorama/")),
  bslib::nav_panel("Administradores", admin_area),
  bslib::nav_panel("Fundos", static_funds_ui()),
  !!!unlist(lapply(family_tabs, function(f) c(
    list(bslib::nav_panel(toupper(f), static_funds_ui(f))),
    if (f == "fidc") list(bslib::nav_panel("Cedentes", cedentes_ui("data/cedentes/"))))), recursive = FALSE),
  bslib::nav_panel("Ficha", static_record_ui()),
  bslib::nav_panel("Sobre", about_area),
  bslib::nav_spacer(),
  bslib::nav_item(shiny::tags$a(class = "nav-link", href = "../", "Página do projeto")))

unlink(file.path(out_dir, "lib"), recursive = TRUE)  # generated folder, rebuilt below
htmltools::save_html(page, file.path(out_dir, "index.html"), libdir = "lib", lang = "pt-BR")
file.copy("prototype/www/taxminer.css", file.path(out_dir, "taxminer.css"), overwrite = TRUE)
file.copy("prototype/static/taxminer_static.js", file.path(out_dir, "taxminer_static.js"), overwrite = TRUE)
file.copy("prototype/www/panorama.js", file.path(out_dir, "panorama.js"), overwrite = TRUE)
file.copy("prototype/www/cedentes.js", file.path(out_dir, "cedentes.js"), overwrite = TRUE)
# The theme uses system fonts: the bundled web fonts and the source maps are
# never loaded by the page.
lib <- file.path(out_dir, "lib")
unlink(c(list.files(lib, pattern = "\\.map$", recursive = TRUE, full.names = TRUE),
         list.files(lib, pattern = "^font\\.css$", recursive = TRUE, full.names = TRUE),
         list.dirs(lib)[basename(list.dirs(lib)) == "fonts"]), recursive = TRUE)
size <- sum(file.info(list.files(out_dir, recursive = TRUE, full.names = TRUE))$size)
cat(sprintf("Static dashboard written to %s (%.1f MB, %d administrator panels, %d funds, %d Panorama months, %d series files, %d fund records, %d with other FIDC tables, %d cedentes).\n",
            out_dir, size / 1024^2, length(keys), fund_files$funds, panorama$months, panorama$chunks, fichas$funds, fichas_x$funds,
            cedentes$cedentes))
