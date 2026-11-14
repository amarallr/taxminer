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
source(testthat::test_path("..", "..", "src", "intelligence", "fund_ratios.R"))
source(testthat::test_path("..", "..", "prototype", "charts.R"))
source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"))
source(testthat::test_path("..", "..", "prototype", "fund_dashboard_module.R"))
source(testthat::test_path("..", "..", "src", "intelligence", "panorama_data.R"))
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
  # Same screens through the old queries and through the precomputed index.
  for (fast in c(FALSE, TRUE)) {
  if (fast) ctx$admin_idx <- admin_index(mm, snapshot, admins)
  shiny::testServer(fund_admin_server, args = list(ctx = ctx), {
    session$setInputs(family = c("fii", "fidc", "fiagro"))
    expect_equal(ranking()$administrator_name, c("ADM DOIS", "ADM UM"))
    expect_equal(picked(), entity_key("administrator", "22222222000122"))
    expect_match(output$kpis$html, "R\\$ 450")
    session$setInputs(pick = entity_key("administrator", "11111111000111"))
    expect_match(output$detail$html, "ADM UM")
    expect_match(output$chart$html, "data-month=\"2025-06\"")
    expect_false(grepl("tm-line-part", output$chart$html))
    # A fund picked in the list is drawn on the chart, on the same axis.
    k <- regmatches(output$funds$html, regexpr("data-fund-key=\"[^\"]+\"", output$funds$html))
    fund_sel(sub("^data-fund-key=\"([^\"]+)\"$", "\\1", k)); session$flushReact()
    expect_match(output$chart$html, "tm-line-part")
    expect_match(output$chart$html, "do total")
    fund_sel("fii|00000000000000"); session$flushReact()  # not a fund of this administrator: no line
    expect_false(grepl("tm-line-part", output$chart$html))
    expect_match(output$funds$html, "FIDC E")
    expect_match(output$funds$html, "· 33,3%", fixed = TRUE)
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
  }
  idx <- admin_index(mm, snapshot, admins); um <- entity_key("administrator", "11111111000111")
  fam <- c("fii", "fidc", "fiagro")
  expect_equal(admin_series(mm, idx, fam, um, complete), administrator_series(mm, admins, um, complete), ignore_attr = TRUE)
  expect_equal(admin_month_funds(mm, idx, admins, fam, um, "2025-06")$fund_name,
               administrator_month_funds(mm, admins, um, "2025-06")$fund_name)
  expect_equal(admin_snapshot_funds(idx, "fidc", um)$fund_cnpj, "E")
})

# --- Panorama (cross-filtering) -------------------------------------------------
# Synthetic fixture: fund D changes administrator in 2025-07 (ADM UM until
# June, ADM DOIS from July); E is in FIDC and, with the same CNPJ, in FII.

panorama_fixture <- function() {
  directory <- data.frame(
    family = c("fii", "fidc", "fidc", "fidc", "fii"), fund_cnpj = c("A", "D", "D", "E", "E"),
    fund_name = c("FUNDO A", "FIDC D", "FIDC D NOVO", "FIDC E", "FII E"),
    administrator_name = c("ADM UM", "ADM UM", "ADM DOIS", "ADM UM", "ADM UM"),
    administrator_cnpj = c("11111111000111", "11111111000111", "22222222000122", "11111111000111", "11111111000111"),
    first_period = c("2025-01-28", "2025-01-28", "2025-07-28", "2025-01-28", "2025-01-28"),
    last_period = c("2025-12-28", "2025-06-28", "2025-12-28", "2025-12-28", "2025-12-28"),
    stringsAsFactors = FALSE)
  rows <- rbind(metric_rows("fii", "A", months, rep(100, 12), 10), metric_rows("fidc", "D", months, rep(300, 12)),
                metric_rows("fidc", "E", months, rep(50, 12)), metric_rows("fii", "E", months, rep(7, 12)))
  mm <- prepare_metrics(rows, today = as.Date("2026-11-11"))
  series <- family_monthly(mm)
  complete <- complete_months(series)
  list(directory = directory, ctx = list(m = mm, series = series, complete = complete, today = as.Date("2026-11-11")))
}

test_that("the Panorama facts carry the administrator of each month (historical link)", {
  fx <- panorama_fixture()
  facts <- panorama_facts(fx$ctx$m, fx$directory)
  um <- entity_key("administrator", "11111111000111"); dois <- entity_key("administrator", "22222222000122")
  d <- facts[facts$fund_cnpj == "D", ]
  expect_equal(d$admin[d$month == "2025-06"], um)
  expect_equal(d$admin[d$month == "2025-07"], dois)
  expect_equal(d$admin[d$month == "2025-12"], dois)
  # One row per family, fund and month: no duplicated net assets.
  expect_equal(anyDuplicated(paste(facts$family, facts$fund_cnpj, facts$month)), 0L)
  expect_equal(sum(facts$net_assets[facts$month == "2025-12"]), 100 + 300 + 50 + 7)
})

test_that("the Panorama data package is valid JSON with consistent dictionaries", {
  fx <- panorama_fixture()
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  out <- write_panorama_data(dir, fx$ctx, fx$directory, generated = "2026-11-11 00:00", selectable = 3L)
  files <- list.files(dir, pattern = "\\.json$", recursive = TRUE, full.names = TRUE)
  for (f in files) expect_silent(jsonlite::fromJSON(f, simplifyVector = FALSE))
  index <- jsonlite::fromJSON(file.path(dir, "index.json"), simplifyVector = FALSE)
  expect_equal(length(index$funds), 4L)  # A (FII), E (FII), D (FIDC), E (FIDC)
  expect_equal(unlist(index$months), c("2025-10", "2025-11", "2025-12"))
  dec <- jsonlite::fromJSON(file.path(dir, "months", "2025-12.json"), simplifyVector = FALSE)$rows
  expect_equal(sum(vapply(dec, function(r) r[[3]], numeric(1))), 457)
  # D's administrator in December is ADM DOIS; in June it is ADM UM.
  admin_of <- function(month) {
    rows <- jsonlite::fromJSON(file.path(dir, "months", paste0(month, ".json")), simplifyVector = FALSE)$rows
    d <- which(vapply(index$funds, function(f) f[[4]] == "D", logical(1))) - 1L
    r <- Filter(function(x) x[[1]] == d, rows)[[1]]
    index$admins[[r[[2]] + 1L]][[1]]
  }
  expect_equal(admin_of("2025-12"), entity_key("administrator", "22222222000122"))
  sa <- jsonlite::fromJSON(file.path(dir, "series_admin.json"), simplifyVector = FALSE)
  expect_true(all(names(sa) %in% as.character(seq_along(index$admins) - 1L)))
  expect_gt(out$chunks, 0L)
})

test_that("the Panorama engine cross-filters every component from one state (Node)", {
  node <- Sys.which("node")
  if (!nzchar(node)) node <- file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "TaxMiner", "node-v26.13.0-win-x64", "node.exe")
  skip_if_not(file.exists(node), "Node.js not available")
  script <- testthat::test_path("panorama_engine_test.js")
  engine <- normalizePath(testthat::test_path("..", "..", "prototype", "www", "panorama.js"), winslash = "/")
  out <- suppressWarnings(system2(node, c(shQuote(script), shQuote(engine)), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  expect_true(is.null(status) || status == 0L, info = paste(out, collapse = "\n"))
  expect_match(paste(out, collapse = "\n"), "all engine checks passed")
})

# --- Published (static) dashboard data ---------------------------------------

test_that("the static JSON writers keep every digit and produce valid JSON", {
  source(testthat::test_path("..", "..", "src", "intelligence", "panorama_data.R"), local = TRUE, encoding = "UTF-8")
  expect_equal(json_number(c(100, 0, 1.5, 120.1, NA, 1e9)), c("100", "0", "1.5", "120.1", "null", "1000000000"))
  expect_equal(json_number(c(65, 100, 0), 0L), c("65", "100", "0"))
  expect_equal(json_string(c("a \"b\" \\ c", NA)), c("\"a \\\"b\\\" \\\\ c\"", "null"))
  txt <- json_array(json_string("x"), json_number(1000), json_number(NA))
  expect_equal(txt, "[\"x\",1000,null]")
})

# --- PL and share in the fund lists --------------------------------------------

test_that("fund lists take the PL of the reference month and the share of the family total", {
  rows <- rbind(metric_rows("fii", "A", months, rep(100, 12)), metric_rows("fii", "B", months, rep(300, 12)),
                metric_rows("fii", "OLD", "2025-03", 50), metric_rows("fidc", "D", months, rep(80, 12)))
  mm <- prepare_metrics(rows, today = as.Date("2026-11-11"))
  snap <- market_snapshot(mm, complete_months(family_monthly(mm)))
  pl <- fund_net_assets(mm, snap)
  a <- pl[pl$fund_cnpj == "A", ]
  expect_equal(a$net_assets, 100)
  expect_equal(a$net_assets_month, "2025-12")
  expect_equal(a$net_assets_share, 0.25)          # 100 of 400 in FII
  expect_equal(pl$net_assets_share[pl$fund_cnpj == "D"], 1)
  old <- pl[pl$fund_cnpj == "OLD", ]               # ended fund: last report, no share
  expect_equal(old$net_assets, 50)
  expect_true(is.na(old$net_assets_share))
  # Shares of one family add up to 100% (no duplicated rows).
  expect_equal(sum(pl$net_assets_share[pl$family == "fii"], na.rm = TRUE), 1)
  listed <- attach_fund_net_assets(data.frame(family = c("fii", "fidc"), fund_cnpj = c("B", "X")), pl)
  expect_equal(listed$net_assets, c(300, NA))
  html <- as.character(results_table(transform(listed, fund_name = "F", fund_cnpj_original = fund_cnpj,
                                               first_period = "2025-01-01", last_period = "2025-12-01",
                                               period_count = 12L, administrator_name = NA_character_), "pick"))
  expect_match(html, "75,00%", fixed = TRUE)
  expect_match(html, "R$ 300", fixed = TRUE)
  expect_equal(format_share(c(0.00001, 0, NA)), c("< 0,01%", "0,00%", "—"))
})

test_that("the Sobre tab shows the version from the VERSION file", {
  dir <- withr::local_tempdir()
  expect_null(version_label(dir))
  writeLines("1.2.3", file.path(dir, "VERSION"))
  at <- as.POSIXct("2026-11-11 15:42:59", tz = "UTC")
  expect_match(as.character(version_label(dir, at)), ">v.1.2.3 · 2026-11-11 15:42 +00:00</div>", fixed = TRUE)
  expect_match(as.character(version_label(dir, "2026-01-02 03:04")), ">v.1.2.3 · 2026-01-02 03:04<", fixed = TRUE)
  expect_match(as.character(version_label(dir, "2026-01-02 03:04", commit = "3cbb696+")),
               ">v.1.2.3 · 2026-01-02 03:04 · 3cbb696+<", fixed = TRUE)
  expect_identical(git_commit_label(dir), "")
  expect_match(readLines(testthat::test_path("..", "..", "VERSION"), n = 1L), "^[0-9]+[.][0-9]+[.][0-9]+$")
})

test_that("negative values are marked for red (Node)", {
  node <- Sys.which("node")
  if (!nzchar(node)) node <- file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "TaxMiner", "node-v26.13.0-win-x64", "node.exe")
  skip_if_not(file.exists(node), "Node.js not available")
  js <- as.character(tm_app_script())
  re <- regmatches(js, regexpr("var NEG = /[^\n]*/;", js))
  expect_length(re, 1L)
  f <- tempfile(fileext = ".js")
  writeLines(c(re, "var s = ['-1.234,56', ' -3,2%', 'R$ -1,2 bi', '\u22125', '0,00', 'R$ 1,2 bi', '—', '-', 'Provisão (-)', '12-31'];",
               "console.log(s.map(function (x) { return NEG.test(x) ? 1 : 0; }).join(''));"), f)
  expect_equal(system2(node, f, stdout = TRUE), "1111000000")
})

test_that("FIDC cedentes keep CPF and CNPJ as published, one line per position", {
  source(testthat::test_path("..", "..", "src", "intelligence", "cedente_data.R"), encoding = "UTF-8")
  df <- data.frame(
    fund_cnpj_normalized = c("11111111000111", "11111111000111", "11111111000111", "22222222000122"),
    DT_COMPTC = c("2025-01-31", "2025-01-31", "2025-02-28", "2025-02-28"),
    source_file = "f.csv", source_line = 1:4,
    TAB_I2A12_CPF_CNPJ_CEDENTE_1 = c("6018364000185", "33000167000101", "52998224725", "0"),
    TAB_I2A12_PR_CEDENTE_1 = c("10", "93.53", "189,72", ""),
    TAB_I2A12_CPF_CNPJ_CEDENTE_2 = c(NA, "123", "", "33.000.167/0001-01"),
    TAB_I2A12_PR_CEDENTE_2 = c(NA, "5", "", "1.5"),
    stringsAsFactors = FALSE)
  r <- fidc_cedente_rows(df)
  # Fund 1 reported twice in 2025-01: the last line wins; "0" is not a cedente.
  expect_equal(nrow(r), 4L)
  expect_equal(r$cedente[r$month == "2025-01"], c("33.000.167/0001-01", "123"))
  expect_equal(r$type[r$month == "2025-01"], c("PJ", "?"))
  expect_equal(r$cedente[r$month == "2025-02" & r$fund_cnpj == "11111111000111"], "529.982.247-25")
  expect_equal(r$share[r$cedente == "529.982.247-25"], "189,72")   # as published
  expect_equal(cedente_share_number(c("93.53", "189,72", "1.234,5", NA)), c(93.53, 189.72, 1234.5, NA))
  dir <- tempfile("ced")
  funds <- data.frame(fund_cnpj = c("11111111000111", "22222222000122"), fund_name = c("FIDC UM", "FIDC DOIS"))
  out <- write_cedente_data(dir, r, funds, reference = "2025-01")
  expect_equal(out$months, 2L)
  idx <- jsonlite::fromJSON(file.path(dir, "index.json"), simplifyVector = FALSE)
  expect_equal(idx$reference, "2025-01")
  expect_equal(unlist(idx$months), c("2025-02", "2025-01"))
  ced <- vapply(idx$cedentes, function(x) x[[1]], "")
  k <- match("33.000.167/0001-01", ced)
  expect_equal(idx$cedentes[[k]][[6]], 2L)                       # months with the cedente
  feb <- jsonlite::fromJSON(file.path(dir, "months", "2025-02.json"), simplifyVector = FALSE)$rows
  expect_length(feb, 2L)
  expect_true(all(vapply(feb, function(x) x[[5]], "") %in% c("189,72", "1.5")))
  # Names from the CVM registries: exact CNPJ, else the same CNPJ root; CPFs never.
  source(testthat::test_path("..", "..", "src", "data", "cvm_registry_names.R"), encoding = "UTF-8")
  registry <- data.frame(cnpj = c("33000167000101", "52998224000199"), name = c("PETROLEO BRASILEIRO S.A.", "OUTRA S.A."),
                         source = c("cia", "fund"), stringsAsFactors = FALSE)
  r2 <- rbind(r, transform(r[1, ], cedente = "33.000.167/0099-55"))
  write_cedente_data(dir, r2, funds, reference = "2025-01", registry = registry)
  idx <- jsonlite::fromJSON(file.path(dir, "index.json"), simplifyVector = FALSE)
  by <- stats::setNames(idx$cedentes, vapply(idx$cedentes, function(x) x[[1]], ""))
  expect_equal(by[["33.000.167/0001-01"]][[3]], "PETROLEO BRASILEIRO S.A.")
  expect_equal(by[["33.000.167/0001-01"]][[7]], "Cadastro de companhias abertas (CVM)")
  expect_equal(by[["33.000.167/0099-55"]][[3]], "PETROLEO BRASILEIRO S.A.")
  expect_match(by[["33.000.167/0099-55"]][[7]], "pela raiz do CNPJ (33.000.167/0001-01)", fixed = TRUE)
  expect_null(by[["529.982.247-25"]][[3]])                      # a CPF is not matched by root
  # Receita Federal companies (by root) come after the exact CVM name and
  # before the CVM root match.
  companies <- data.frame(root = c("33000167", "52998224"), name = c("RAZAO RFB PETROBRAS", "RAZAO RFB OUTRA"),
                          month = "2026-10", stringsAsFactors = FALSE)
  write_cedente_data(dir, r2, funds, reference = "2025-01", registry = registry, companies = companies)
  idx <- jsonlite::fromJSON(file.path(dir, "index.json"), simplifyVector = FALSE)
  by <- stats::setNames(idx$cedentes, vapply(idx$cedentes, function(x) x[[1]], ""))
  expect_equal(by[["33.000.167/0001-01"]][[3]], "PETROLEO BRASILEIRO S.A.")
  expect_equal(by[["33.000.167/0099-55"]][[3]], "RAZAO RFB PETROBRAS")
  expect_match(by[["33.000.167/0099-55"]][[7]], "Receita Federal (dados abertos, 2026-10)", fixed = TRUE)
})

test_that("Receita Federal company names are read from the zips keeping only the requested roots", {
  for (f in c("collect_rfb_cnpj.R")) source(testthat::test_path("..", "..", "src", "collect", f), encoding = "UTF-8")
  source(testthat::test_path("..", "..", "src", "data", "rfb_company_names.R"), encoding = "UTF-8")
  root <- tempfile("rfb"); month <- "2026-10"
  dir <- file.path(root, "raw", "rfb_cnpj", month); dir.create(dir, recursive = TRUE)
  lines <- c('"33000167";"PETRÓLEO BRASILEIRO S.A. PETROBRAS";"2038";"10";"205431960490,52";"05";""',
             '"11111111";"OUTRA LTDA";"2062";"49";"1000,00";"01";""',
             '"52998224";"FULANO DE TAL 52998224725";"2135";"50";"5000,00";"01";""')
  for (i in 0:9) {
    body <- iconv(paste0(paste(if (i == 3) lines else lines[2], collapse = "\r\n"), "\r\n"), "UTF-8", "latin1")
    write_stored_zip(file.path(dir, sprintf("Empresas%d.zip", i)), stats::setNames(list(body), sprintf("K%d.EMPRECSV", i)))
  }
  for (i in 0:9) append_rfb_manifest(root, data.frame(month = month, file_name = sprintf("Empresas%d.zip", i), source_url = "u",
                                                     outcome = "downloaded", http_status = "200", bytes = "1", file_sha256 = "x",
                                                     raw_path = "r", error = "", retrieved_at = "t"))
  expect_equal(rfb_companies_month(root), month)
  n <- build_rfb_company_names(root, c("33000167", "52998224", "99999999"))
  expect_equal(n$root, c("33000167", "52998224"))
  expect_equal(n$name[1], "PETRÓLEO BRASILEIRO S.A. PETROBRAS")      # Latin-1 read as UTF-8, kept as published
  expect_equal(unique(n$month), month)
  expect_true(rfb_refused(429L) && rfb_refused(403L) && rfb_refused(401L) && !rfb_refused(200L))
})

test_that("CVM registry names keep the published name by source priority", {
  source(testthat::test_path("..", "..", "src", "data", "cvm_registry_names.R"), encoding = "UTF-8")
  d <- tempfile("reg"); dir.create(d)
  latin <- function(lines, path) writeBin(iconv(paste0(paste(lines, collapse = "\r\n"), "\r\n"), "UTF-8", "latin1", toRaw = TRUE)[[1]], path)
  latin(c("CNPJ_CIA;DENOM_SOCIAL", "33.000.167/0001-01;PETRÓLEO BRASILEIRO S.A."), file.path(d, "cia.csv"))
  latin(c("CNPJ_FUNDO;DENOM_SOCIAL;CNPJ_ADMIN;ADMIN;PF_PJ_GESTOR;CPF_CNPJ_GESTOR;GESTOR;CNPJ_AUDITOR;AUDITOR;CNPJ_CUSTODIANTE;CUSTODIANTE;CNPJ_CONTROLADOR;CONTROLADOR",
          "11.111.111/0001-11;FUNDO \"ALFA\";33.000.167/0001-01;OUTRO NOME;PF;123.456.789-09;PESSOA;;;;;;",
          "22.222.222/0001-22;FUNDO BETA;44.444.444/0001-44;ADMINISTRADORA;PJ;55.555.555/0001-55;GESTORA;;;;;;"),
        file.path(d, "cad.csv"))
  files <- c(cad_fi.csv = file.path(d, "cad.csv"), registro_fundo_classe.zip = NA, cad_cia_aberta.csv = file.path(d, "cia.csv"))
  n <- build_cvm_registry_names(files)
  expect_equal(n$name[n$cnpj == "33000167000101"], "PETRÓLEO BRASILEIRO S.A.")   # company register first, accents kept
  expect_equal(n$source[n$cnpj == "33000167000101"], "cia")
  expect_equal(n$name[n$cnpj == "11111111000111"], "FUNDO \"ALFA\"")             # stray quote kept as published
  expect_equal(n$source[n$cnpj == "55555555000155"], "provider")
  expect_false("12345678909" %in% sub("^000", "", n$cnpj))                         # natural-person manager left out
  expect_equal(anyDuplicated(n$cnpj), 0L)
})

test_that("the loading bar waits, stays a minimum time, follows real progress and is in both versions", {
  node <- Sys.which("node")
  if (!nzchar(node)) node <- file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "TaxMiner", "node-v26.13.0-win-x64", "node.exe")
  skip_if_not(file.exists(node), "Node.js not available")
  root <- testthat::test_path("..", "..")
  out <- suppressWarnings(system2(node, c(shQuote(testthat::test_path("loadbar_test.js")),
                                          shQuote(file.path(root, "prototype", "www", "loadbar.js"))),
                                  stdout = TRUE, stderr = TRUE))
  expect_equal(tail(out, 1), "ok")
  # Loaded by the app header and by the published page, before the other scripts.
  expect_match(paste(readLines(file.path(root, "prototype", "app.R"), encoding = "UTF-8"), collapse = "\n"),
               "loadbar.js\", defer = NA),\\s+shiny::tags\\$script\\(src = \"panorama.js\"")
  export <- paste(readLines(file.path(root, "scripts", "export_static_dashboard.R"), encoding = "UTF-8"), collapse = "\n")
  expect_match(export, "src = \"loadbar.js\"", fixed = TRUE)
  expect_match(export, "prototype/www/loadbar.js", fixed = TRUE)
})

test_that("return distribution: mean, deviation, last month, values outside the scale counted", {
  months <- sprintf("2025-%02d", 1:12)
  v <- c(1, 1.2, 0.8, 1.1, 0.9, 1, 1.05, 0.95, 1.1, 0.9, 1, 500)
  d <- fund_return_distribution(v, months)
  expect_equal(d$n, 12L)
  expect_equal(d$mean, mean(v))
  expect_equal(d$last, 500); expect_equal(d$last_month, "2025-12")
  expect_equal(sum(d$counts), 12L)  # winsorized values sit in the edge bars
  expect_null(fund_return_distribution(1:5, months[1:5]))
  expect_equal(parse_return_number(c("1.5E-4", "0.3", "x", NA)), c(0.00015, 0.3, NA, NA))
  svg <- fund_return_svg(d)
  expect_match(svg, "^<svg")
  expect_false(grepl("[0-9][eE][-+][0-9]", svg))
  expect_match(fund_return_caption(d), "12 meses (jan/2025 a dez/2025)", fixed = TRUE)
  expect_equal(format_return_pct(c(0.000012, NA)), c("0,00%", "—"))
})

test_that("latest quotaholders per fund skip carried months", {
  m <- data.frame(family = "fip", fund_cnpj = "1", month = c("2025-01", "2025-02", "2025-03"),
                  quotaholders = c(10, 12, 12), carried = c(FALSE, FALSE, TRUE), stringsAsFactors = FALSE)
  h <- fund_latest_quotaholders(m)
  expect_equal(h$month, "2025-02"); expect_equal(h$quotaholders, 12)
  r <- attach_fund_quotaholders(data.frame(family = c("fip", "fii"), fund_cnpj = c("1", "1")), h)
  expect_equal(r$quotaholders, c(12, NA))
})

test_that("Distribuições place the fund among the funds of its family at the chosen date", {
  # Percentiles: share of funds below; ties take the middle; outside = 0 or 100.
  s <- fund_peer_summary(1:100)
  expect_equal(s$n, 100L); expect_equal(s$q[51], 50.5); expect_equal(sum(s$counts), 100L)
  expect_equal(fund_peer_percentile(s, 50.5), 50)
  expect_equal(fund_peer_percentile(s, 1), 0); expect_equal(fund_peer_percentile(s, 0), 0)
  expect_equal(fund_peer_percentile(s, 101), 100)
  expect_equal(fund_peer_percentile(fund_peer_summary(c(rep(0, 50), 1:50)), 0), 24.5)
  expect_null(fund_peer_summary(1:5))
  expect_null(fund_peer_summary(rep(3, 10)))
  # One value per fund: the median of its rows.
  expect_equal(fund_median_by(c(1, 2, 4, 9), c("a", "b", "b", "c"))[c("a", "b", "c")], c(a = 1, b = 3, c = 9))
  # Numbers as in the Ficha: CVM decimals use "."; codes and zero-padded values are not numbers.
  expect_equal(fund_numeric_values(c("12.345", "1.2E-3", "1.234.567", "007", "abc", "", NA), "VL_X"),
               c(12.345, 0.0012, 1234567, NA, NA, NA, NA))
  expect_true(all(is.na(fund_numeric_values("11222333000181", "CNPJ_ADMIN"))))
  expect_equal(display_value("12.345")$text, "12,345")
  # Matrix: one chart per field the fund has at the date, with the hint.
  r <- data.frame(fund_cnpj_normalized = as.character(1:8), DT_COMPTC = "2026-01-31",
                  VL_PL = as.character(c(10, 20, 30, 40, 50, 60, 70, 80)), stringsAsFactors = FALSE)
  peers <- fund_peer_summaries(r)
  expect_equal(attr(peers, "funds"), 8L); expect_named(peers, "VL_PL")
  ui <- as.character(fund_distribution_matrix_ui(r[7, ], NULL, "t", "2026-01-31", peers, "fidc"))
  expect_match(ui, "percentil 86")
  expect_match(ui, "P25 27,50 · mediana 45,00 · P75 62,50")
  expect_match(ui, "8 fundos FIDC")
  expect_match(fund_distribution_matrix_ui(r[7, ], NULL, "t", "2026-01-31", list(), "fidc") |> as.character(),
               "Nenhum campo numérico")
})

test_that("distributions are drawn on a log scale with original labels", {
  expect_false(is.na(fund_display_scale(1:100)))
  expect_true(is.na(fund_display_scale(c(1, 2, 1, 2))))
  skew <- c(rep(c(0, 1, 2, 3, 5), 40), 1e6, 5e6, 2e7, 1e8)
  c <- fund_display_scale(skew)
  expect_true(is.finite(c) && c > 0)
  expect_equal(fund_scale_inv(fund_scale_fwd(c(-50, 0, 7, 1e8), c), c), c(-50, 0, 7, 1e8))
  s <- fund_peer_summary(skew)
  expect_equal(s$scale, c); expect_equal(s$q[51], 2)
  svg <- fund_distribution_svg(c(s, list(last = 3)), 200, 64, format_compact_number)
  expect_match(svg, "escala log")
  expect_match(svg, ">0,00<")                  # lower label in original values
  expect_false(grepl("e[+-][0-9]", svg))       # never scientific notation
  d <- fund_return_distribution(c(rep(1, 20), 1.1, 0.9, 1.2, 0.8, 300), sprintf("2024-%02d", 1:25))
  expect_false(is.na(d$scale))
  expect_equal(d$mean, mean(c(rep(1, 20), 1.1, 0.9, 1.2, 0.8, 300)))
})

test_that("the dashed line of a peer distribution is the median, aligned with z = 0", {
  skew <- c(rep(c(0, 1, 2, 3, 5), 40), 1e6, 5e6, 2e7, 1e8)
  s <- fund_peer_summary(skew)
  expect_true(!is.null(s$rs) && s$rs > 0)
  d <- c(s, list(last = 3, zmed = fund_scale_fwd(s$q[51], s$scale)))
  svg <- fund_distribution_svg(d, 220, 62, format_compact_number, TRUE)
  x_mean <- as.numeric(sub('.*class="tm-rd-mean" x1="([-0-9.]+)".*', "\\1", svg))
  x_z0 <- as.numeric(sub('.*class="tm-rd-ztick tm-rd-z0" x1="([-0-9.]+)".*', "\\1", svg))
  expect_equal(x_mean, x_z0)
  expect_match(svg, ">2,00<")                  # middle label is the median in original values
  # Without zmed (own monthly returns) the dashed line stays at the curve centre.
  own <- fund_distribution_svg(c(s, list(last = 3)), 220, 62, format_compact_number, TRUE)
  expect_false(grepl("tm-rd-z0", own))
})

test_that("distribution charts are winsorized at 2.5% on each side; statistics stay original", {
  v <- c(1:97, 1000, 2000, 5000)
  w <- fund_winsorize(v)
  expect_equal(w$lo, unname(quantile(v, 0.025))); expect_equal(w$hi, unname(quantile(v, 0.975)))
  expect_equal(w$clamped, sum(v < w$lo | v > w$hi))
  s <- fund_peer_summary(v)
  expect_equal(sum(s$counts), 100L)            # every fund is drawn (extremes at the edge bars)
  expect_equal(s$outside, w$clamped)
  expect_equal(s$mean, mean(v)); expect_equal(s$q[101], 5000)
  expect_equal(fund_scale_inv(s$hi, s$scale), w$hi)
  d <- fund_return_distribution(c(rep(1, 30), 0.5, 2, 300), sprintf("m%02d", 1:33))
  expect_equal(sum(d$counts), 33L); expect_equal(d$mean, mean(c(rep(1, 30), 0.5, 2, 300)))
})

test_that("robust z places the fund among its peers without being pulled by extremes", {
  v <- c(1:99, 1e6)
  s <- fund_peer_summary(v)
  expect_true(is.finite(s$rs) && s$rs > 0)
  typ <- fund_peer_robust(s, 50); expect_equal(typ$level, "típico"); expect_false(typ$tukey)
  ext <- fund_peer_robust(s, 1e6); expect_equal(ext$level, "extremo"); expect_true(ext$z > 3.5); expect_true(ext$tukey)
  low <- fund_peer_robust(s, -5000); expect_true(low$z < 0)
  expect_equal(fund_peer_z_text(2.04), "+2,0"); expect_equal(fund_peer_z_text(-3.96), "-4,0")
  # Half the funds at zero: MAD = 0, falls back to IQR / 1.349 or the deviation.
  s0 <- fund_peer_summary(c(rep(0, 60), 1:40))
  expect_true(is.finite(s0$rs) && s0$rs > 0)
  # Matrix: highlights panel, cells from the most atypical, previous competência.
  r <- data.frame(fund_cnpj_normalized = as.character(1:10), DT_COMPTC = "2026-02-28",
                  VL_A = as.character(c(1:9, 500)), VL_B = as.character(1:10), stringsAsFactors = FALSE)
  prev <- transform(r, DT_COMPTC = "2026-01-31", VL_A = as.character(1:10))
  ui <- as.character(fund_distribution_matrix_ui(rbind(prev[10, ], r[10, ]), NULL, "t", "2026-02-28",
                                                 fund_peer_summaries(r), "fidc", fund_peer_summaries(prev), "2026-01-31"))
  expect_match(ui, "Destaques estatísticos")
  expect_match(ui, "comparação com 2026-01-31")
  expect_lt(regexpr("VL_A", ui), regexpr("VL_B", ui))   # the atypical field comes first
  expect_match(ui, "tm-z-delta")
})

test_that("Distribuições in mode Relativo show shares, ratios over another table and the left-out funds", {
  rules <- data.frame(family = "fidc", table_name = c("tA", "tA", "tA"),
                      numerator = c("^VL_TOTAL$", "^VL_ITEM_", "^VL_ITEM_B$"),
                      denominator_table = c("tPL", "tA", "tA"), denominator = c("VL_PL", "VL_TOTAL", "VL_ITEM_A+VL_ITEM_B"),
                      kind = c("over_pl", "share_of_total", "analytic"),
                      label_pt = c("Total / PL", "{item} / Total", "B / (A + B)"), note = "", stringsAsFactors = FALSE)
  n <- 10
  a <- data.frame(fund_cnpj_normalized = as.character(1:n), DT_COMPTC = "2026-02-28",
                  VL_TOTAL = as.character(seq(100, 1000, 100)), VL_ITEM_A = as.character(seq(100, 1000, 100) * c(0.6, 0.5, 0.7, 0.6, 0.55, 0.65, 0.6, 0.62, 0.58, 0.9)),
                  VL_ITEM_B = as.character(seq(100, 1000, 100) * c(0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.1)),
                  VL_OTHER = as.character(1:n), stringsAsFactors = FALSE)
  pl <- data.frame(fund_cnpj_normalized = as.character(1:n), DT_COMPTC = "2026-02-28",
                   VL_PL = as.character(c(80, 150, 240, 300, 520, 700, 650, 900, 1000, -5)), stringsAsFactors = FALSE)
  plan <- fund_ratio_plan(rules, "tA", fund_distribution_fields(names(a)))
  vals <- fund_ratio_inputs(plan, "tA", "2026-02-28", a, function(dt, sp) pl)
  peers <- fund_peer_summaries(a)
  peers <- structure(c(peers, fund_peer_ratio_summaries(plan, "tA", vals)), funds = n, plan = plan)
  expect_equal(peers[["r:VL_TOTAL"]]$n, 9L)            # fund 10 has PL < 0
  expect_equal(peers[["r:VL_TOTAL"]]$excluded, 1L)
  expect_true(is.na(peers[["r:VL_ITEM_A"]]$scale))      # shares on a linear scale
  rows_of <- function(tn) if (tn == "tPL") pl[1, ] else NULL
  ui <- as.character(fund_distribution_matrix_ui(a[1, ], NULL, "tA", "2026-02-28", peers, "fidc", mode = "rel", rows_of = rows_of))
  expect_match(ui, "Total / PL")
  expect_match(ui, "Valor relativo")
  expect_match(ui, "60,0%")                              # VL_ITEM_A / VL_TOTAL of fund 1
  expect_match(ui, "1 fundos com o campo ficaram fora")
  expect_match(ui, "Valores relativos")
  ua <- as.character(fund_distribution_matrix_ui(a[1, ], NULL, "tA", "2026-02-28", peers, "fidc", mode = "abs", rows_of = rows_of))
  expect_false(grepl("Valor relativo", ua))
  expect_match(ua, "Valores absolutos")
  expect_equal(fund_ratio_pct(c(0.123, 1.5, 0.0004, NA)), c("12,3%", "150%", "0,04%", "—"))
})

test_that("robust z stays readable when most funds share one value (shares at 0%)", {
  v <- c(rep(0, 95), 0.2, 0.4, 0.5, 0.6, 0.98)
  s <- fund_peer_summary(v, linear = TRUE)
  expect_equal(stats::mad(v), 0)
  expect_equal(s$rs, max(1.253314 * mean(abs(v - stats::median(v))), fund_peer_share_floor))
  z <- fund_peer_robust(s, 0.98)$z
  expect_true(z > 3.5 && z < 50)                       # extreme, not hundreds
  expect_equal(fund_peer_robust_scale(rep(0, 10), floor = 0.01), 0.01)
  expect_true(is.na(fund_peer_robust_scale(rep(0, 10))))
})

test_that("FIDC X.4 distributions break by operation type (TAB_X_TP_OPER)", {
  r <- data.frame(fund_cnpj_normalized = rep(c("1", "2"), each = 3),
                  TAB_X_TP_OPER = rep(c("Captações no Mês", "Resgates no Mês", ""), 2),
                  TAB_X_VL_TOTAL = c("100", "5", "7", "200", "9", "8"), stringsAsFactors = FALSE)
  s <- fund_peer_split(r)
  expect_setequal(grep("^TAB_X_VL_TOTAL", names(s), value = TRUE),
                  c("TAB_X_VL_TOTAL|Captações no Mês", "TAB_X_VL_TOTAL|Resgates no Mês"))
  v <- fund_peer_values(s)
  # One value per fund and type; never a median that mixes captações and resgates.
  expect_equal(unname(v[["TAB_X_VL_TOTAL|Captações no Mês"]][c("1", "2")]), c(100, 200))
  expect_equal(unname(v[["TAB_X_VL_TOTAL|Resgates no Mês"]][c("1", "2")]), c(5, 9))
  expect_equal(field_labels("TAB_X_VL_TOTAL|Resgates no Mês")$label, "Tab x vl total · Resgates no Mês")
  # The over-PL rule of the field applies to each type.
  rules <- data.frame(family = "fidc", table_name = "inf_mensal_fidc_tab_X_4", numerator = "^TAB_X_VL_TOTAL$",
                      denominator_table = "inf_mensal_fidc_tab_IV", denominator = "TAB_IV_A_VL_PL", kind = "over_pl",
                      label_pt = "{item} / PL", note = "", stringsAsFactors = FALSE)
  plan <- fund_ratio_plan(rules, "inf_mensal_fidc_tab_X_4", names(v))
  expect_setequal(plan$key, c("r:TAB_X_VL_TOTAL|Captações no Mês", "r:TAB_X_VL_TOTAL|Resgates no Mês"))
  # Tables without the type column are unchanged.
  expect_identical(fund_peer_split(r[, -2]), r[, -2])
})
