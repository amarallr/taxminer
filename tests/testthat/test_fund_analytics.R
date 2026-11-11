# Phase 1.3 analytics tests: derived fund metrics (from synthetic CVM members
# consolidated into a temporary root), the analytics rules, the SVG/HTML chart
# helpers and the Administradores area. No network. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_fund_analytics.R')"

source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "parquet_io.R"))
source(testthat::test_path("..", "..", "src", "data", "consolidate_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "data", "build_fund_metrics.R"))
source(testthat::test_path("..", "..", "src", "intelligence", "search_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "data", "entity_resolution.R"))
source(testthat::test_path("..", "..", "src", "intelligence", "fund_analytics.R"))
source(testthat::test_path("..", "..", "prototype", "charts.R"))
source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"))
source(testthat::test_path("..", "..", "prototype", "fund_dashboard_module.R"))
source(testthat::test_path("helper_stored_zip.R"))

# --- Derived metrics from consolidated members -------------------------------

add_member_file <- function(root, family, dataset, file_name, members) {
  stem <- sub("\\.zip$", "", file_name)
  raw <- file.path(root, "raw", family, tolower(dataset), stem)
  dir.create(raw, recursive = TRUE, showWarnings = FALSE)
  zip <- write_stored_zip(file.path(raw, "v1.zip"), lapply(members, function(x) iconv(x, "UTF-8", "latin1")))
  sha <- as.character(tools::sha256sum(zip))
  final <- file.path(raw, paste0(substr(sha, 1, 12), ".zip"))
  file.rename(zip, final)
  manifest <- file.path(root, "manifests", paste0(family, ".csv"))
  row <- data.frame(source_id = sprintf("cvm:%s:%s:%s", family, tolower(dataset), file_name),
                    family = family, dataset = dataset, reference_period = "2026", file_name = file_name,
                    source_url = sprintf("https://dados.cvm.gov.br/dados/%s/%s", toupper(family), file_name),
                    outcome = "downloaded", file_sha256 = sha,
                    raw_path = substring(final, nchar(root) + 2L), retrieved_at = "2026-11-11T01:00:00")
  utils::write.table(row, manifest, sep = ",", row.names = FALSE, col.names = !file.exists(manifest),
                     append = file.exists(manifest), qmethod = "double")
}

lines <- function(...) paste0(c(...), collapse = "\n")

metrics_root <- function() {
  root <- tempfile("fund_metrics_")
  dir.create(file.path(root, "manifests"), recursive = TRUE)
  dir.create(file.path(root, "meta"))
  add_member_file(root, "fii", "INF_MENSAL", "inf_mensal_fii_2026.zip", list(
    "inf_mensal_fii_complemento_2026.csv" = lines(
      "CNPJ_Fundo_Classe;Data_Referencia;Versao;Patrimonio_Liquido;Valor_Ativo;Total_Numero_Cotistas",
      "00.332.266/0001-31;2026-01-31;1;1000.50;1200;10",
      "00.332.266/0001-31;2026-01-31;2;1100.25;1300;12",
      "00.332.266/0001-31;2026-02-28;1;1.234,56;1300;12",
      "11.222.333/0001-81;2026-01-31;1;500;600;5")))
  add_member_file(root, "fidc", "INF_MENSAL", "inf_mensal_fidc_202601.zip", list(
    "inf_mensal_fidc_tab_IV_202601.csv" = lines(
      "CNPJ_FUNDO_CLASSE;DT_COMPTC;TAB_IV_A_VL_PL",
      "60.701.190/0001-04;2026-01-31;2500"),
    "inf_mensal_fidc_tab_X_1_202601.csv" = lines(
      "CNPJ_FUNDO_CLASSE;DT_COMPTC;TAB_X_CLASSE_SERIE;TAB_X_NR_COTST",
      "60.701.190/0001-04;2026-01-31;Senior;7",
      "60.701.190/0001-04;2026-01-31;Subordinada;3")))
  add_member_file(root, "fip", "INF_TRIMESTRAL", "inf_trimestral_fip_2025.zip", list(
    "inf_trimestral_fip_2025.csv" = lines(
      "CNPJ_FUNDO;DENOM_SOCIAL;DT_COMPTC;VL_PATRIM_LIQ;NR_COTST",
      "33.000.167/0001-01;FIP PARTICIPAÇÕES;2025-12-31;900;",
      "33.000.167/0001-01;FIP PARTICIPAÇÕES;2099-03-31;950;")))
  consolidate_fund_reports(root, progress = FALSE)
  root
}

skip_if_not_installed("arrow")
root <- metrics_root()

test_that("CVM numbers parse with a dot decimal; anything else is NA, never zero", {
  expect_equal(parse_cvm_number(c("10", "-2.5", " 3 ", "1.234,56", "", NA, "abc")),
               c(10, -2.5, 3, NA, NA, NA, NA))
})

test_that("metrics keep the latest version, cite the row and count unparsed values", {
  m <- build_fund_metrics(root)
  fii <- m[m$family == "fii", ]
  jan <- fii[fii$fund_cnpj == "00332266000131" & fii$period == "2026-01-31", ]
  expect_equal(nrow(jan), 1L)
  expect_equal(jan$net_assets, 1100.25)
  expect_equal(jan$quotaholders, 12)
  expect_equal(jan$rows_in_period, 2L)
  expect_match(jan$source_file, "inf_mensal_fii_complemento_2026.csv")
  expect_true(is.na(fii$net_assets[fii$period == "2026-02-28"]))
  expect_equal(attr(m, "issues")$unparsed, 1L)
  expect_equal(attr(m, "issues")$resolved_rows, 1L)
  fidc <- m[m$family == "fidc", ]
  expect_equal(fidc$net_assets, 2500)
  expect_equal(fidc$quotaholders, 10)
  expect_true(all(is.na(m$quotaholders[m$family == "fip"])))
})

test_that("the metrics table is cached and reused while the inputs are unchanged", {
  first <- load_fund_metrics(root)
  expect_true(file.exists(metric_paths(root)$table))
  stamp <- file.mtime(metric_paths(root)$table)
  again <- load_fund_metrics(root)
  expect_equal(file.mtime(metric_paths(root)$table), stamp)
  expect_equal(nrow(again), nrow(first))
  expect_equal(attr(again, "issues")$unparsed, 1L)
})

# --- Analytics rules on synthetic metrics ------------------------------------

metric_rows <- function(family, cnpj, months, net_assets, quotaholders = NA_real_) {
  data.frame(family = family, fund_cnpj = cnpj, period = paste0(months, "-28"), net_assets = net_assets,
             total_assets = NA_real_, quotaholders = quotaholders, rows_in_period = 1L, table_name = "t",
             zip_sha256 = "z", source_file = "f.csv", source_line = 1L, stringsAsFactors = FALSE)
}
months <- sprintf("2025-%02d", 1:12)
synthetic <- rbind(
  metric_rows("fii", "A", c(months, "2026-01"), c(rep(100, 12), 130), 10),
  metric_rows("fii", "B", months, rep(50, 12), 5),
  metric_rows("fiagro", "A", "2025-12", 999),
  metric_rows("fip", "F", c("2025-03", "2025-06", "2025-10"), c(10, 20, 40)),
  metric_rows("fii", "C", "2030-01", 1))
m <- prepare_metrics(synthetic, today = as.Date("2026-11-11"))

test_that("future periods are dropped and quarterly FIP balances carry to the next report", {
  expect_equal(attr(m, "future_rows"), 1L)
  expect_false(any(m$fund_cnpj == "C"))
  fip <- m[m$family == "fip", ]
  expect_equal(fip$month[order(fip$month)],
               c("2025-03", "2025-04", "2025-05", "2025-06", "2025-07", "2025-08", "2025-09", "2025-10"))
  expect_equal(fip$net_assets[fip$month == "2025-05"], 10)
  expect_equal(fip$net_assets[fip$month == "2025-09"], 20)
  expect_true(all(fip$carried[!fip$month %in% c("2025-03", "2025-06", "2025-10")]))
  expect_equal(fip$period[fip$month == "2025-09"], "2025-06-28")
})

test_that("the latest month is incomplete when few funds have reported", {
  series <- family_monthly(m)
  complete <- complete_months(series)
  expect_equal(complete[["fii"]], "2025-12")
  expect_equal(complete[["fip"]], "2025-10")
  o <- family_overview(series, complete)
  expect_equal(o$latest_month[o$family == "fii"], "2026-01")
  expect_true(is.na(o$net_assets_change[o$family == "fii"]))
  expect_equal(pct_change(130, 100), 0.3)
  expect_true(is.na(pct_change(1, 0)))
  expect_equal(shift_month(c("2026-01", "2025-12"), -12), c("2025-01", "2024-12"))
})

test_that("the market snapshot counts each CNPJ once and the change is year on year", {
  complete <- c(fii = "2025-12", fiagro = "2025-12", fip = "2025-10")
  s <- market_snapshot(m, complete)
  expect_equal(sum(s$fund_cnpj == "A"), 1L)
  expect_equal(s$family[s$fund_cnpj == "A"], "fii")
  expect_equal(sum(s$net_assets), 100 + 50 + 40)
  expect_true(is.na(market_change(m, complete)))
})

test_that("administrators group by CNPJ, skip fund names in the field and measure concentration", {
  directory <- data.frame(
    family = c("fii", "fii", "fiagro", "fidc"), fund_cnpj = c("A", "B", "G", "D"),
    fund_name = c("FUNDO A", "FUNDO B", "FIAGRO G", "FIDC D"),
    administrator_name = c("BANCO X S.A.", "Banco X SA", "FIAGRO G", NA),
    administrator_cnpj = c("11.111.111/0001-11", "11111111000111", "11.111.111/0001-11", NA),
    first_period = "2025-01-01", last_period = "2025-12-28", stringsAsFactors = FALSE)
  admins <- fund_administrators(directory)
  expect_true(admins$name_is_fund[admins$fund_cnpj == "G"])
  expect_false(admins$administrator_name[admins$fund_cnpj == "G"] == "FIAGRO G")
  snapshot <- data.frame(family = c("fii", "fii", "fiagro", "fidc"), fund_cnpj = c("A", "B", "G", "D"),
                         net_assets = c(60, 20, 20, 100), quotaholders = NA_real_, period = "2025-12-28")
  r <- administrator_ranking(snapshot, admins)
  expect_equal(nrow(r), 2L)
  expect_equal(r$net_assets, c(100, 100))
  expect_equal(r$funds[r$key == entity_key("administrator", "11111111000111")], 3L)
  expect_equal(attr(r, "hhi"), 5000)
  expect_equal(hhi_label(attr(r, "hhi")), "alta concentração")
  expect_equal(hhi_label(1000), "baixa concentração")
  expect_equal(hhi_label(2000), "concentração moderada")
  expect_equal(hhi(c(1, 1, 1, 1)), 2500)
  funds <- snapshot_funds(snapshot, admins, administrator = entity_key("administrator", "11111111000111"))
  expect_equal(funds$fund_cnpj[1], "A")
  expect_setequal(funds$fund_cnpj, c("A", "B", "G"))
})

test_that("a fund profile uses its own reports and ranks it within its family", {
  snapshot <- market_snapshot(m, c(fii = "2025-12", fiagro = "2025-12", fip = "2025-10"))
  p <- fund_profile(m, snapshot, "fii", "A")
  expect_equal(p$last$month, "2026-01")
  expect_equal(p$net_assets_change, 0.3)
  expect_equal(p$rank, 1L)
  expect_equal(p$peers, 2L)
  fip <- fund_profile(m, snapshot, "fip", "F")
  expect_equal(nrow(fip$series), 3L)
  expect_null(fund_profile(m, snapshot, "fii", "nope"))
})

test_that("values are formatted the Brazilian way", {
  expect_equal(format_brl(c(2.6e12, 486.2e9, 1500, NA)), c("R$ 2,6 tri", "R$ 486,2 bi", "R$ 1,5 mil", "—"))
  expect_equal(format_pct(c(0.314, -0.133, NA)), c("+31,4%", "-13,3%", "—"))
  expect_equal(format_int(c(8303, NA)), c("8.303", "—"))
  expect_equal(month_label("2026-09"), "set/2026")
  expect_equal(axis_brl(4e11), "R$ 400 bi")
})

# --- Chart helpers -------------------------------------------------------------

test_that("line charts break at missing values and carry a tooltip per point", {
  svg <- as.character(svg_line_chart(c("2025-01", "2025-02", "2025-03", "2025-04"), c(1, NA, 3, 4),
                                     label = "Teste"))
  expect_match(svg, "^<svg class=\"tm-chart\"")
  expect_equal(lengths(regmatches(svg, gregexpr("class=\"tm-line\"", svg))), 2L)
  expect_equal(lengths(regmatches(svg, gregexpr("class=\"tm-hit\"", svg))), 4L)
  expect_match(svg, "data-tip=\"jan/2025&#10;R\\$ 1\"")
  expect_match(svg, "aria-label=\"Teste\"")
  expect_match(as.character(svg_line_chart(character(), numeric())), "Sem dados")
})

test_that("bar lists and share bars scale to the data and escape text", {
  html <- as.character(bar_list(c("A <b>", "B"), c(10, 5), c("10", "5"), keys = c("k1", "k2"),
                                input = "pick", selected = "k2"))
  expect_match(html, "width:100.00%")
  expect_match(html, "width:50.00%")
  expect_match(html, "A &lt;b&gt;")
  expect_match(html, "tm-pick tm-selected\" data-key=\"k2\"")
  share <- as.character(share_bar(c(75, 25), c("#111111", "#222222"), c("X", "Y"), c("75", "25")))
  expect_match(share, "flex-basis:75.000%")
  expect_match(share, "25,0%")
  expect_match(as.character(change_badge(-0.1)), "tm-down")
  expect_match(as.character(change_badge(NA)), "sem base")
})

# --- Administradores area --------------------------------------------------------

test_that("the Administradores area ranks, filters by family and shows the picked administrator", {
  directory <- data.frame(
    family = c("fii", "fidc", "fidc"), fund_cnpj = c("A", "D", "E"),
    fund_name = c("FUNDO A", "FIDC D", "FIDC E"),
    administrator_name = c("ADM UM", "ADM DOIS", "ADM UM"),
    administrator_cnpj = c("11111111000111", "22222222000122", "11111111000111"),
    first_period = "2025-01-01", last_period = "2025-12-28", stringsAsFactors = FALSE)
  rows <- rbind(metric_rows("fii", "A", months, rep(100, 12)), metric_rows("fidc", "D", months, rep(300, 12)),
                metric_rows("fidc", "E", months, rep(50, 12)))
  mm <- prepare_metrics(rows, today = as.Date("2026-11-11"))
  series <- family_monthly(mm)
  complete <- complete_months(series)
  snapshot <- market_snapshot(mm, complete)
  admins <- fund_administrators(directory)
  ctx <- list(m = mm, series = series, complete = complete, snapshot = snapshot, admins = admins,
              ranking = administrator_ranking(snapshot, admins))
  shiny::testServer(fund_admin_server, args = list(ctx = ctx), {
    session$setInputs(family = c("fii", "fidc", "fiagro"))
    expect_equal(ranking()$administrator_name, c("ADM DOIS", "ADM UM"))
    expect_equal(picked(), entity_key("administrator", "22222222000122"))
    expect_match(output$kpis$html, "R\\$ 450")
    session$setInputs(pick = entity_key("administrator", "11111111000111"))
    expect_match(output$detail$html, "ADM UM")
    expect_match(output$detail$html, "data-month=\"2025-06\"")
    expect_match(output$funds$html, "FIDC E")
    expect_match(output$funds$html, "mês de referência")
    # A month clicked on the chart lists the funds of that month.
    session$setInputs(month = "2025-06")
    expect_match(output$funds$html, "Fundos em jun/2025 \\(2\\)")
    expect_match(output$funds$html, "FUNDO A")
    session$setInputs(month_reset = 1)
    expect_match(output$funds$html, "mês de referência")
    session$setInputs(family = "fii")
    expect_equal(ranking()$administrator_name, "ADM UM")
    expect_equal(attr(ranking(), "total"), 100)
  })
})

# --- Panorama ---------------------------------------------------------------

test_that("the Panorama renders every family/administrator ranking for browser-side filtering", {
  directory <- data.frame(
    family = c("fii", "fidc", "fidc"), fund_cnpj = c("A", "D", "E"),
    fund_name = c("FUNDO A", "FIDC D", "FIDC E"),
    administrator_name = c("ADM UM", "ADM DOIS", "ADM UM"),
    administrator_cnpj = c("11111111000111", "22222222000122", "11111111000111"),
    first_period = "2025-01-01", last_period = "2025-12-28", stringsAsFactors = FALSE)
  rows <- rbind(metric_rows("fii", "A", months, rep(100, 12)), metric_rows("fidc", "D", months, rep(300, 12)),
                metric_rows("fidc", "E", months, rep(50, 12)))
  mm <- prepare_metrics(rows, today = as.Date("2026-11-11"))
  series <- family_monthly(mm)
  complete <- complete_months(series)
  snapshot <- market_snapshot(mm, complete)
  admins <- fund_administrators(directory)
  ctx <- list(m = mm, series = series, complete = complete, overview = family_overview(series, complete),
              snapshot = snapshot, admins = admins, ranking = administrator_ranking(snapshot, admins),
              market_change = market_change(mm, complete))
  html <- as.character(fund_overview_ui("overview", ctx, top = 20L))
  expect_match(html, "20 maiores administradores", fixed = TRUE)
  expect_match(html, "data-family=\"fidc\"", fixed = TRUE)
  # One admin list per family filter; the "all" list is the visible one.
  expect_match(html, "data-admins=\"all\">", fixed = TRUE)
  expect_match(html, "data-admins=\"fidc\" hidden>", fixed = TRUE)
  # Funds of ADM UM within FIDC: only E.
  pos <- regexpr(paste0("data-funds=\"fidc|", entity_key("administrator", "11111111000111"), "\""), html, fixed = TRUE)
  expect_gt(pos, 0)
  block <- substr(html, pos, pos + 1500)
  expect_match(block, "FIDC E", fixed = TRUE)
  expect_false(grepl("FIDC D", sub("data-funds=.*", "", substr(block, 40, nchar(block))), fixed = TRUE))
  expect_match(html, "data-funds=\"all|\">", fixed = TRUE)
})

# --- Published (static) dashboard data ---------------------------------------

test_that("the static JSON writers keep every digit and produce valid JSON", {
  source(testthat::test_path("..", "..", "prototype", "static_funds.R"), local = TRUE, encoding = "UTF-8")
  expect_equal(json_number(c(100, 0, 1.5, 120.1, NA, 1e9)), c("100", "0", "1.5", "120.1", "null", "1000000000"))
  expect_equal(json_number(c(65, 100, 0), 0L), c("65", "100", "0"))
  expect_equal(json_string(c("a \"b\" \\ c", NA)), c("\"a \\\"b\\\" \\\\ c\"", "null"))
  txt <- json_array(json_string("x"), json_number(1000), json_number(NA))
  expect_equal(txt, "[\"x\",1000,null]")
})
