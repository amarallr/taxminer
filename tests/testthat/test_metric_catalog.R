# Metric catalog tests (explorador multimétrico, ETAPA 02): static checks, layout
# availability, dictionary review of layout changes and the series resolver, all on
# synthetic data. No network, no real data. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_metric_catalog.R')"

source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "parquet_io.R"))
source(testthat::test_path("..", "..", "src", "data", "consolidate_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "data", "build_fund_metrics.R"))
source(testthat::test_path("..", "..", "src", "data", "metric_catalog.R"))

config_dir <- testthat::test_path("..", "..", "config")

metric_row <- function(id, ..., family = sub("\\..*$", "", id)) {
  r <- list(metric_id = id, display_name = id, description = id, family = family, category = "c", unit = "BRL",
            nature = "stock", granularity = "fund", aggregation = "latest_version", value_type = "declared",
            formula = "", is_default = "FALSE", notes = "")
  r[names(list(...))] <- list(...)
  as.data.frame(r, stringsAsFactors = FALSE)
}
mapping_row <- function(id, table, field, ...) {
  r <- list(metric_id = id, table_name = table, field = field, valid_from = "", valid_to = "", filter_field = "",
            filter_value = "", class_key = "", transform = "cvm_number", equivalence = "same_field",
            evidence = "", periodicity = "monthly")
  r[names(list(...))] <- list(...)
  as.data.frame(r, stringsAsFactors = FALSE)
}

# The ICVM 555 -> FIF case: the same form item (I.2.c.5) under another column and
# another CVM description from 2020-11.
fif_maps <- function(equivalence, evidence = "") rbind(
  mapping_row("fidc.cotas_fundos", "tab_I", "TAB_I2C5_VL_COTA_FUNDO_ICVM555", valid_to = "2020-10"),
  mapping_row("fidc.cotas_fundos", "tab_I", "TAB_I2C5_VL_COTA_FIF", valid_from = "2020-11",
              equivalence = equivalence, evidence = evidence))
fif_rows <- function() list(
  data.frame(fund_cnpj = "1", period = c("2020-09-30", "2020-10-31", "2020-11-30"), version = 1,
             source_file = "a.csv", source_line = c("2", "3", "4"),
             TAB_I2C5_VL_COTA_FUNDO_ICVM555 = c("10", "11", "99"), stringsAsFactors = FALSE),
  data.frame(fund_cnpj = "1", period = c("2020-10-31", "2020-11-30", "2020-12-31"), version = 1,
             source_file = "b.csv", source_line = c("2", "3", "4"),
             TAB_I2C5_VL_COTA_FIF = c("77", "12", "13"), stringsAsFactors = FALSE))

test_that("the project catalog passes every static check", {
  cat_ <- metric_catalog_read(config_dir)
  expect_equal(nrow(metric_catalog_check(cat_)), 0L)
  expect_true(all(cat_$catalog$is_default[cat_$catalog$value_type == "derived"] == "FALSE"))
})

test_that("default metrics read the same columns as the current Ficha", {
  cat_ <- metric_catalog_read(config_dir)
  m <- cat_$mappings
  expect_equal(m$field[m$metric_id == "fidc.patrimonio_liquido"], fund_metric_sources$fidc$net_assets)
  expect_equal(m$table_name[m$metric_id == "fidc.cotistas"], fund_metric_sources$fidc$class_table)
  expect_equal(m$class_key[m$metric_id == "fidc.cotistas"], fund_metric_sources$fidc$class_key)
  for (f in c("fii", "fiagro", "fip")) {
    expect_true(all(m$field[m$metric_id == paste0(f, ".patrimonio_liquido")] == fund_metric_sources[[f]]$net_assets))
    expect_true(all(m$field[m$metric_id == paste0(f, ".cotistas")] == fund_metric_sources[[f]]$quotaholders))
    expect_setequal(m$table_name[m$metric_id == paste0(f, ".cotistas")], fund_metric_sources[[f]]$table)
  }
  defaults <- cat_$catalog$metric_id[cat_$catalog$is_default == "TRUE"]
  expect_setequal(defaults, paste0(rep(c("fidc", "fii", "fiagro", "fip"), each = 2), c(".patrimonio_liquido", ".cotistas")))
})

test_that("static checks catch semantic mistakes", {
  catalog <- rbind(
    metric_row("fidc.a"), metric_row("fidc.a"),
    metric_row("fidc.rent", unit = "pct", nature = "rate", granularity = "class_series",
               aggregation = "sum_classes_same_period"),
    metric_row("fidc.flow", nature = "flow"),
    metric_row("fidc.bad_ref", value_type = "derived", formula = "fidc.nao_existe / fidc.a", unit = "ratio"),
    metric_row("fidc.parens", value_type = "derived", formula = "(fidc.a / fidc.flow", unit = "ratio"),
    metric_row("fidc.mix", value_type = "derived", formula = "fidc.a + fidc.flow"),
    metric_row("fidc.no_div", value_type = "derived", formula = "fidc.a + fidc.a", unit = "ratio"),
    metric_row("fidc.call", value_type = "derived", formula = "system(fidc.a)"),
    metric_row("fii.other", value_type = "derived", formula = "fidc.a / fidc.a", unit = "ratio"),
    metric_row("fidc.orphan_decl"))
  mappings <- rbind(
    mapping_row("fidc.a", "t", "A"),
    mapping_row("fidc.rent", "t", "R", class_key = "K"),
    mapping_row("fidc.flow", "t", "F", valid_to = "2020-12"),
    mapping_row("fidc.flow", "t", "F2", valid_from = "2020-06"),
    mapping_row("fidc.nada", "t", "X"),
    mapping_row("fidc.a", "t", "A", valid_from = "2021-13", filter_field = "TP"))
  p <- metric_catalog_check(list(catalog = catalog, mappings = mappings))
  has <- function(id, text) any(p$metric_id == id & grepl(text, p$problem, fixed = TRUE))
  expect_true(has("fidc.a", "duplicado"))
  expect_true(has("fidc.rent", "taxa não pode ser somada"))
  expect_true(has("fidc.bad_ref", "métrica inexistente"))
  expect_true(has("fidc.parens", "parênteses"))
  expect_true(has("fidc.mix", "estoque com fluxo"))
  expect_true(has("fidc.no_div", "razão exige divisão"))
  expect_true(has("fidc.call", "função não permitida"))
  expect_true(has("fii.other", "outra família"))
  expect_true(has("fidc.orphan_decl", "sem mapeamento"))
  expect_true(has("fidc.nada", "métrica inexistente"))
  expect_true(has("fidc.flow", "sobrepostos"))
  expect_true(has("fidc.flow", "exige proven ou not_proven"))
  expect_true(has("fidc.a", "AAAA-MM"))
  expect_true(has("fidc.a", "filter_field e filter_value"))
})

test_that("a proven equivalence needs evidence; a field change needs an explicit equivalence", {
  catalog <- metric_row("fidc.cotas_fundos")
  p <- metric_catalog_check(list(catalog = catalog, mappings = fif_maps("proven")))
  expect_true(any(grepl("exige evidência", p$problem)))
  p <- metric_catalog_check(list(catalog = catalog, mappings = fif_maps("same_field")))
  expect_true(any(grepl("exige proven ou not_proven", p$problem)))
  expect_equal(nrow(metric_catalog_check(list(catalog = catalog, mappings = fif_maps("not_proven")))), 0L)
})

test_that("two layouts feed one series only with proven equivalence; otherwise a discontinuity", {
  metric <- metric_row("fidc.cotas_fundos")
  split <- metric_series_from_rows(metric, fif_maps("not_proven"), fif_rows())
  # Each mapping only inside its window: the 2020-11 value of the old column and the
  # 2020-10 value of the new one are dropped.
  expect_equal(split$period, c("2020-09-30", "2020-10-31", "2020-11-30", "2020-12-31"))
  expect_equal(split$value, c(10, 11, 12, 13))
  expect_equal(split$segment, c(1L, 1L, 2L, 2L))
  expect_equal(split$field, rep(c("TAB_I2C5_VL_COTA_FUNDO_ICVM555", "TAB_I2C5_VL_COTA_FIF"), each = 2))
  expect_equal(split$source_file, rep(c("a.csv", "b.csv"), each = 2))
  joined <- metric_series_from_rows(metric, fif_maps("proven", "documento"), fif_rows())
  expect_equal(unique(joined$segment), 1L)
})

test_that("the dictionary decides whether a declared equivalence holds", {
  cat_ <- list(catalog = metric_row("fidc.cotas_fundos"), mappings = fif_maps("proven", "mesmo item I.2.c.5"))
  d <- data.frame(table_name = "tab_I", field = c("TAB_I2C5_VL_COTA_FUNDO_ICVM555", "TAB_I2C5_VL_COTA_FIF"),
                  description = c("Cotas de Fundos da ICVM 555", "Classes de Cotas dos FIF - Anexo I da RCVM 175"),
                  stringsAsFactors = FALSE)
  expect_equal(metric_equivalence_review(cat_, d)$verdict, "descrições diferentes: não comprovada")
  d$description[2] <- d$description[1]
  expect_equal(metric_equivalence_review(cat_, d)$verdict, "comprovada pelo dicionário")
  cat_$mappings$equivalence[2] <- "not_proven"
  expect_equal(metric_equivalence_review(cat_, d)$verdict, "descontinuidade declarada")
  expect_equal(metric_equivalence_review(cat_, d[0, ])$verdict, "descontinuidade declarada")
})

test_that("latest version, filter and class sum follow the current Ficha rules", {
  metric <- metric_row("fidc.captacoes", nature = "flow", granularity = "class_series",
                       aggregation = "sum_classes_same_period")
  maps <- mapping_row("fidc.captacoes", "tab_X_4", "TAB_X_VL_TOTAL", filter_field = "TAB_X_TP_OPER",
                      filter_value = "Captações no Mês", class_key = "TAB_X_CLASSE_SERIE")
  rows <- list(data.frame(
    fund_cnpj = "1", period = "2024-01-31", version = c(1, 2, 1, 1),
    source_file = "x.csv", source_line = c("2", "3", "4", "5"),
    TAB_X_TP_OPER = c("Captações no Mês", "Captações no Mês", "Captações no Mês", "Resgates no Mês"),
    TAB_X_CLASSE_SERIE = c("Sênior", "Sênior", "Subordinada", "Sênior"),
    TAB_X_VL_TOTAL = c("100", "150", "50.5", "999"), stringsAsFactors = FALSE))
  s <- metric_series_from_rows(metric, maps, rows)
  expect_equal(nrow(s), 1L)
  expect_equal(s$value, 200.5)
  expect_equal(s$classes, 2L)
  rate <- metric_row("fidc.rent", unit = "pct", nature = "rate", granularity = "class_series", aggregation = "none")
  r <- metric_series_from_rows(rate, mapping_row("fidc.rent", "tab_X_4", "TAB_X_VL_TOTAL",
                                                 class_key = "TAB_X_CLASSE_SERIE"), rows)
  expect_equal(nrow(r), 2L)
  expect_setequal(r$class, c("Sênior", "Subordinada"))
  # Unparsable values stay NA, never zero.
  rows[[1]]$TAB_X_VL_TOTAL[3] <- "1,5"
  expect_equal(metric_series_from_rows(metric, maps, rows)$value, 150)
})

test_that("availability reports gaps per layout and the worst operand for derived metrics", {
  m2 <- function(y, mo) y * 12L + mo - 1L
  layouts <- list(
    files = data.frame(table_name = "t", layout_version = c("v1", "v1", "v2", "v2"), source_file = paste0("f", 1:4),
                       period_start = c(m2(2020, 9), m2(2020, 10), m2(2020, 11), m2(2020, 12)),
                       period_end = c(m2(2020, 9), m2(2020, 10), m2(2020, 11), m2(2020, 12)),
                       stringsAsFactors = FALSE),
    columns = list("t|v1" = c("A", "OLD"), "t|v2" = c("A", "NEW")))
  catalog <- rbind(metric_row("fidc.a"), metric_row("fidc.old"), metric_row("fidc.cotas"),
                   metric_row("fidc.ratio", value_type = "derived", formula = "fidc.old / fidc.a", unit = "ratio"),
                   metric_row("fidc.none"))
  mappings <- rbind(mapping_row("fidc.a", "t", "A"), mapping_row("fidc.old", "t", "OLD"),
                    mapping_row("fidc.cotas", "t", "OLD", valid_to = "2020-10"),
                    mapping_row("fidc.cotas", "t", "NEW", valid_from = "2020-11", equivalence = "not_proven"),
                    mapping_row("fidc.none", "t", "ZZZ"))
  av <- metric_availability(list(catalog = catalog, mappings = mappings), layouts)
  st <- stats::setNames(av$metrics$status, av$metrics$metric_id)
  expect_equal(unname(st["fidc.a"]), "disponível")
  expect_equal(unname(st["fidc.old"]), "com lacunas")
  expect_equal(av$mappings$gaps[av$mappings$metric_id == "fidc.old"], "2020-11 2020-12")
  expect_equal(unname(st["fidc.cotas"]), "descontínua")
  expect_equal(av$metrics$discontinuities[av$metrics$metric_id == "fidc.cotas"], "2020-11")
  expect_equal(unname(st["fidc.ratio"]), "com lacunas")
  expect_equal(unname(st["fidc.none"]), "indisponível")
})

test_that("the matrix shows the physical field of each metric per CVM table", {
  cat_ <- metric_catalog_read(config_dir)
  mat <- metric_table_matrix(cat_)
  expect_equal(mat["fidc.patrimonio_liquido", "inf_mensal_fidc_tab_IV"], "TAB_IV_A_VL_PL")
  expect_equal(mat["fip.cotistas", "inf_quadrimestral_fip"], "NR_COTST")
  expect_false("fidc.dc_sobre_pl" %in% rownames(mat))
})
