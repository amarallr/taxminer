# Entity resolution (work_0028): identity by CNPJ, equivalent names merged by
# the versioned dictionary, different names kept, whole CNPJ history on any
# selection. Synthetic directory rows only; no network, no data directory.
# Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_entity_resolution.R')"

source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "parquet_io.R"))
source(testthat::test_path("..", "..", "src", "data", "consolidate_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "intelligence", "search_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "data", "entity_resolution.R"))

rules_path <- testthat::test_path("..", "..", "config", "entity_name_rules.csv")
rules <- load_entity_rules(rules_path)

# Synthetic directory: fund 00.332.266/0001-31 had two significantly different
# names (XYZ, then ABC), each published in short and long form; one fund
# changed only by the RL suffix; one administrator name has a typo.
row <- function(family, cnpj, name, admin, admin_cnpj, first, last, n) {
  data.frame(family = family, fund_cnpj = ifelse(is.na(normalize_cnpj(cnpj)), cnpj, normalize_cnpj(cnpj)),
             fund_cnpj_original = cnpj, fund_name = name, administrator_name = admin,
             administrator_cnpj = admin_cnpj, first_period = first, last_period = last, period_count = n,
             zip_sha256 = "sha", source_file = paste0(family, ".csv"), source_line = 2L,
             stringsAsFactors = FALSE)
}
directory <- rbind(
  row("fidc", "00.332.266/0001-31", "FIDC XYZ", "BANCO ÁGIL S.A.", "33.000.167/0001-01", "2020-01-01", "2020-12-01", 12L),
  row("fidc", "00332266000131", "Fundo de Investimento em Direitos Creditórios XYZ", "Banco Agil SA", "33000167000101", "2021-01-01", "2021-12-01", 12L),
  row("fidc", "00.332.266/0001-31", "FIDC ABC", "BANCO ÁGIL S.A.", "33.000.167/0001-01", "2022-01-01", "2022-12-01", 12L),
  row("fidc", "00.332.266/0001-31", "FUNDO DE INVESTIMENTO EM DIREITOS CREDITORIOS ABC", "BANCO AGIL SOCIEDADE ANONIMA", "33.000.167/0001-01", "2023-01-01", "2023-06-01", 6L),
  row("fii", "60.701.190/0001-04", "SUNO CRI FII", "OUTRA INVESTIMENTOS DTVM LTDA", "62.418.140/0001-31", "2023-01-01", "2024-12-01", 24L),
  row("fii", "60.701.190/0001-04", "SUNO CRI FII RL", "OUTRA INVETIMENTOS DTVM LTDA", "62.418.140/0001-31", "2025-01-01", "2025-06-01", 6L),
  row("fii", "11.111.111/1111-11", "CNPJ INVALIDO FII", "OUTRA INVESTIMENTOS DTVM LTDA", "62.418.140/0001-31", "2025-01-01", "2025-03-01", 3L),
  row("fiagro", "60.701.190/0001-04", "SUNO CRI FIAGRO", "SUNO CRI FIAGRO", "62.418.140/0001-31", "2025-07-01", "2025-09-01", 3L))
directory$fund_period_count <- ave(directory$period_count, directory$family, directory$fund_cnpj, FUN = sum)
master <- build_entity_master(directory, rules, built_at = "2026-11-11T00:00:00-0300")
fund1 <- "fund:00332266000131"

test_that("CNPJs are text, keep leading zeros, are masked and validated (1, 2)", {
  expect_equal(format_cnpj(c("00332266000131", "00.332.266/0001-31", "332266000131")),
               rep("00.332.266/0001-31", 3))
  expect_type(master$entities$cnpj_canonical, "character")
  expect_equal(master$entities$cnpj_canonical[master$entities$entity_id == fund1], "00332266000131")
  expect_equal(format_cnpj("11.111.111/1111-11"), "11.111.111/1111-11")  # invalid: shown as published
  expect_equal(cnpj_status(c("00.332.266/0001-31", "11.111.111/1111-11", NA)),
               c("valid_check_digits", "invalid_check_digits", "missing"))
  # Alphanumeric CNPJ: the check digits found for a 12-character base are accepted and masked.
  base <- "12ABC345DE01"
  dv <- sprintf("%02d", 0:99)[!is.na(normalize_cnpj(paste0(base, sprintf("%02d", 0:99))))]
  expect_length(dv, 1L)
  expect_equal(format_cnpj(paste0(base, dv)), sprintf("12.ABC.345/DE01-%s", dv))
  expect_equal(entity_key("fund", "11.111.111/1111-11"), "fund:raw:11111111111111")
})

test_that("equivalent names merge; significantly different names stay (3, 4)", {
  n <- master$entity_names[master$entity_names$entity_id == fund1, ]
  expect_equal(nrow(n), 2L)
  expect_setequal(n$normalized_name, c("FIDC XYZ", "FIDC ABC"))
  expect_equal(n$variant_count, c(2L, 2L))
  expect_equal(n$display_name[n$normalized_name == "FIDC XYZ"], "FIDC XYZ")
  expect_true(all(n$validation_status == "rule_equivalence"))
  expect_match(n$normalization_criteria[n$normalized_name == "FIDC ABC"], "fund_fidc")
  # Originals are preserved in the history, untouched.
  h <- master$name_history[master$name_history$entity_id == fund1, ]
  expect_setequal(h$original_name, directory$fund_name[1:4])
  # Administrator: S.A., SA and Sociedade Anônima are the same denomination.
  a <- master$entity_names[master$entity_names$entity_id == "administrator:33000167000101", ]
  expect_equal(nrow(a), 1L)
  expect_equal(a$normalized_name, "BANCO AGIL SA")
})

test_that("each denomination is its own option, with the masked CNPJ (5)", {
  skip_if_not_installed("shiny")
  source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"), encoding = "UTF-8")
  d <- annotate_directory_entities(directory)
  choices <- fund_choices(master, d)
  mine <- choices[startsWith(choices, fund1)]
  expect_length(mine, 2L)
  expect_setequal(names(mine), c("00.332.266/0001-31 — FIDC XYZ", "00.332.266/0001-31 — FIDC ABC"))
  expect_false(anyDuplicated(choices) > 0)
})

test_that("any denomination returns the whole CNPJ history, without duplicates (6, 7, 9)", {
  d <- annotate_directory_entities(directory)
  ids <- master$entity_names$name_id[master$entity_names$entity_id == fund1]
  by_xyz <- search_fund_entities(d, funds = resolve_entity_query(ids[1], master, "fund"))
  by_abc <- search_fund_entities(d, funds = resolve_entity_query(ids[2], master, "fund"))
  both <- search_fund_entities(d, funds = resolve_entity_query(ids, master, "fund"))
  expect_identical(by_xyz, by_abc)
  expect_identical(both, by_xyz)
  expect_equal(nrow(by_xyz), 4L)
  l <- fund_list(both, master)
  expect_equal(nrow(l), 1L)
  expect_equal(c(l$first_period, l$last_period), c("2020-01-01", "2023-06-01"))
  expect_equal(l$period_count, 42L)
  expect_equal(l$name_count, 2L)
  expect_equal(l$cnpj_formatted, "00.332.266/0001-31")
  # Administrator selected by any spelling returns all of its funds.
  admin <- resolve_entity_query("banco agil sociedade anonima", master, "administrator", rules)
  expect_equal(admin, "administrator:33000167000101")
  expect_equal(nrow(search_fund_entities(d, administrators = admin)), 4L)
})

test_that("joining the catalogs never multiplies financial rows (8, 10)", {
  snapshot <- data.frame(fund_cnpj = c("00332266000131", "60701190000104"), net_assets = c(100.5, 200.25))
  snapshot$entity_id <- entity_key("fund", snapshot$fund_cnpj)
  joined <- merge(snapshot, master$entities[, c("entity_id", "display_name")], by = "entity_id")
  expect_equal(nrow(joined), nrow(snapshot))
  expect_equal(sum(joined$net_assets), sum(snapshot$net_assets))
  expect_false(anyDuplicated(master$entities$entity_id) > 0)
  expect_false(anyDuplicated(master$entity_names$name_id) > 0)
  expect_true(all(master$name_history$name_id %in% master$entity_names$name_id))
  expect_true(all(master$entity_names$entity_id %in% master$entities$entity_id))
  # Same CNPJ as fund and as administrator: different entity types, never mixed.
  expect_true("fund:60701190000104" %in% master$entities$entity_id)
  expect_false("administrator:60701190000104" %in% master$entities$entity_id)
  q <- master$quality
  expect_equal(q$value[q$metric %in% c("duplicated_entity_ids", "duplicated_name_ids",
                                       "history_rows_without_denomination")], c(0, 0, 0))
  expect_equal(q$value[q$metric == "administrator_name_is_fund_name"], 1)
})

test_that("family lists add up to the general list (11)", {
  d <- annotate_directory_entities(directory)
  general <- fund_list(search_fund_entities(d), master)
  parts <- do.call(rbind, lapply(unique(d$family), function(f) fund_list(search_fund_entities(d, family = f), master)))
  key <- function(x) sort(paste(x$family, x$fund_entity, x$period_count))
  expect_equal(key(parts), key(general))
  # The same CNPJ under two families is one entity with both sources.
  e <- master$entities[master$entities$entity_id == "fund:60701190000104", ]
  expect_equal(e$reference_source, "CVM informes: fiagro;fii")
})

test_that("building is idempotent and the rule version is reproducible (12, 13)", {
  again <- build_entity_master(directory[rev(seq_len(nrow(directory))), ], rules, built_at = "2026-11-11T00:00:00-0300")
  for (t in c("entities", "entity_names", "name_history", "name_review", "quality")) {
    expect_identical(again[[t]], master[[t]], info = t)
  }
  expect_identical(entity_rules_version(load_entity_rules(rules_path)), master$rule_version)
  changed <- rules
  changed$validation_status[changed$rule_id == "fund_fidc"] <- "retired"
  m2 <- build_entity_master(directory, changed)
  expect_false(identical(m2$rule_version, master$rule_version))
  expect_equal(sum(m2$entity_names$entity_id == fund1), 4L)
  # Cached catalogs: written once, read back identical.
  root <- tempfile("entity_master_")
  dir.create(file.path(root, "processed"), recursive = TRUE)
  # The directory signature needs consolidated tables; a fixed value stands in.
  original <- fund_directory_signature
  assign("fund_directory_signature", function(root) "fixed", envir = environment(load_entity_master))
  on.exit(assign("fund_directory_signature", original, envir = environment(load_entity_master)), add = TRUE)
  first <- load_entity_master(root, directory, rules)
  second <- load_entity_master(root, directory, rules)
  expect_identical(second$entity_names, first$entity_names)
  expect_identical(second$rule_version, first$rule_version)
})

test_that("ambiguous names stay apart and go to review; spelling slips are not merged (14)", {
  n <- master$entity_names[master$entity_names$entity_id == "fund:60701190000104", ]
  expect_setequal(n$normalized_name, c("SUNO CRI FII", "SUNO CRI FII RL", "SUNO CRI FIAGRO"))
  r <- master$name_review[master$name_review$entity_id == "fund:60701190000104", ]
  expect_true(any(r$reason == "token_subset" & grepl("SUNO CRI FII", r$name_a) & grepl("RL", r$name_b)))
  a <- master$entity_names[master$entity_names$entity_id == "administrator:62418140000131", ]
  expect_equal(nrow(a), 2L)  # INVESTIMENTOS vs INVETIMENTOS: not merged
  ra <- master$name_review[master$name_review$entity_id == "administrator:62418140000131", ]
  expect_equal(ra$reason, "near_spelling")
  expect_true(all(master$entity_names$needs_review[master$entity_names$entity_id == "administrator:62418140000131"]))
})

test_that("search finds current, former, normalized and abbreviated names (15)", {
  expect_equal(match_entities(master, "fund", "Fundo de Investimento em Direitos Creditórios XYZ"), fund1)
  expect_equal(match_entities(master, "fund", "fidc xyz", rules), fund1)
  expect_equal(match_entities(master, "fund", "FUNDO DE INVESTIMENTO EM DIREITOS CREDITORIOS ABC", rules), fund1)
  expect_equal(match_entities(master, "fund", "00.332.266/0001-31"), fund1)
  expect_equal(match_entities(master, "fund", "00332266"), fund1)
  expect_length(match_entities(master, "fund", "inexistente"), 0L)
  t <- entity_name_timeline(master, fund1)
  expect_equal(t$original_name[1], "FIDC XYZ")
  expect_equal(t$first_observed_period, sort(t$first_observed_period))
  expect_true(all(is.na(master$name_history$valid_from)))  # observation is not legal validity
})
