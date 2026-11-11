# Phase 1.3 (work_0022) tests for the investment fund report search. Synthetic
# Latin-1 members are consolidated with Data P04 into a temporary root; no
# network. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_fund_reports_search.R')"

source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "parquet_io.R"))
source(testthat::test_path("..", "..", "src", "data", "consolidate_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "intelligence", "search_fund_reports.R"))
source(testthat::test_path("helper_stored_zip.R"))

latin1 <- function(x) iconv(x, "UTF-8", "latin1")

fii_geral <- paste0(c(
  "CNPJ_Fundo_Classe;Data_Referencia;Versao;Nome_Fundo_Classe;Nome_Administrador;CNPJ_Administrador",
  "00.332.266/0001-31;2026-01-31;1;FUNDO SÃO PAULO;ADMINISTRADORA ÁGIL S.A.;33.000.167/0001-01",
  "00.332.266/0001-31;2026-02-28;1;FUNDO SÃO PAULO;ADMINISTRADORA ÁGIL S.A.;33.000.167/0001-01",
  "00.332.266/0001-31;2026-03-31;1;FUNDO SÃO PAULO;OUTRA ADMINISTRADORA LTDA;60.701.190/0001-04",
  "11.111.111/1111-11;2026-01-31;1;CNPJ INVALIDO;ADMINISTRADORA ÁGIL S.A.;33.000.167/0001-01"),
  collapse = "\n")
fii_ativo <- paste0(c(
  "CNPJ_Fundo_Classe;Data_Referencia;Valor_Ativo;Campo_Vazio",
  "00.332.266/0001-31;2026-01-31;-1.234,56;",
  "00.332.266/0001-31;2026-03-31;0,00;",
  "60.701.190/0001-04;2026-01-31;99;"), collapse = "\n")
fidc_tab_i <- paste0(c(
  "CNPJ_FUNDO_CLASSE;DENOM_SOCIAL;DT_COMPTC;ADMIN;CNPJ_ADMIN",
  "60.701.190/0001-04;FIDC CRÉDITO;2025-12-31;ADMINISTRADORA ÁGIL S.A.;33.000.167/0001-01"),
  collapse = "\n")
fip_tri <- paste0(c(
  "CNPJ_FUNDO;DENOM_SOCIAL;DT_COMPTC",
  "33.000.167/0001-01;FIP PARTICIPAÇÕES;2023-12-31"), collapse = "\n")

add_file <- function(root, family, dataset, file_name, members) {
  stem <- sub("\\.zip$", "", file_name)
  raw <- file.path(root, "raw", family, tolower(dataset), stem)
  dir.create(raw, recursive = TRUE, showWarnings = FALSE)
  zip <- write_stored_zip(file.path(raw, "v1.zip"), lapply(members, latin1))
  sha <- as.character(tools::sha256sum(zip))
  final <- file.path(raw, paste0(substr(sha, 1, 12), ".zip"))
  file.rename(zip, final)
  manifest <- file.path(root, "manifests", paste0(family, ".csv"))
  row <- data.frame(source_id = sprintf("cvm:%s:%s:%s", family, tolower(dataset), file_name),
                    family = family, dataset = dataset, reference_period = "2026",
                    file_name = file_name,
                    source_url = sprintf("https://dados.cvm.gov.br/dados/%s/%s", toupper(family), file_name),
                    outcome = "downloaded", file_sha256 = sha,
                    raw_path = substring(final, nchar(root) + 2L), retrieved_at = "2026-11-11T01:00:00")
  utils::write.table(row, manifest, sep = ",", row.names = FALSE, col.names = !file.exists(manifest),
                     append = file.exists(manifest), qmethod = "double")
  sha
}

search_root <- function() {
  root <- tempfile("fund_search_")
  dir.create(file.path(root, "manifests"), recursive = TRUE)
  dir.create(file.path(root, "meta"))
  add_file(root, "fii", "INF_MENSAL", "inf_mensal_fii_2026.zip",
           list("inf_mensal_fii_geral_2026.csv" = fii_geral,
                "inf_mensal_fii_ativo_passivo_2026.csv" = fii_ativo))
  add_file(root, "fidc", "INF_MENSAL", "inf_mensal_fidc_202512.zip",
           list("inf_mensal_fidc_tab_I_202512.csv" = fidc_tab_i))
  add_file(root, "fip", "INF_TRIMESTRAL", "inf_trimestral_fip_2023.zip",
           list("inf_trimestral_fip_2023.csv" = fip_tri))
  consolidate_fund_reports(root, progress = FALSE)
  root
}

skip_if_not_installed("arrow")
root <- search_root()
directory <- load_fund_directory(root)

test_that("the directory keeps one entry per fund, name and administrator as published", {
  expect_equal(names(directory), fund_directory_columns)
  sp <- directory[directory$fund_cnpj == "00332266000131", ]
  expect_equal(nrow(sp), 2L)
  agil <- sp[sp$administrator_name == "ADMINISTRADORA ÁGIL S.A.", ]
  expect_equal(c(agil$first_period, agil$last_period, agil$period_count),
               c("2026-01-31", "2026-02-28", "2"))
  expect_equal(agil$fund_name, "FUNDO SÃO PAULO")
  # The citation points at the most recent row of that entry.
  expect_equal(c(agil$source_file, agil$source_line), c("inf_mensal_fii_geral_2026.csv", "3"))
  expect_equal(sort(unique(directory$family)), c("fidc", "fii", "fip"))
})

test_that("invalid CNPJ stays searchable by the published value", {
  bad <- directory[directory$fund_name == "CNPJ INVALIDO", ]
  expect_equal(bad$fund_cnpj, "11.111.111/1111-11")
  expect_equal(nrow(search_fund_directory(directory, cnpj = "11.111.111/1111-11")), 1L)
})

test_that("FIP has no administrator and FIDC uses DENOM_SOCIAL and ADMIN", {
  expect_true(is.na(directory$administrator_name[directory$family == "fip"]))
  fidc <- directory[directory$family == "fidc", ]
  expect_equal(c(fidc$fund_name, fidc$administrator_cnpj), c("FIDC CRÉDITO", "33.000.167/0001-01"))
})

test_that("filters combine and ignore case, accents and CNPJ punctuation", {
  expect_equal(nrow(search_fund_directory(directory, administrator = "administradora agil")), 3L)
  expect_equal(nrow(search_fund_directory(directory, administrator = "33000167")), 3L)
  expect_equal(nrow(search_fund_directory(directory, administrator = "agil", family = "fidc")), 1L)
  expect_equal(nrow(search_fund_directory(directory, cnpj = "00.332")), 2L)
  expect_equal(nrow(search_fund_directory(directory, name = "sao paulo", administrator = "outra")), 1L)
  expect_equal(nrow(search_fund_directory(directory, name = "participacoes")), 1L)
  expect_equal(nrow(search_fund_directory(directory)), nrow(directory))
  expect_equal(nrow(search_fund_directory(directory, name = "inexistente")), 0L)
})

test_that("period filters keep funds whose reports overlap the range", {
  expect_equal(sort(search_fund_directory(directory, period_to = "2025")$family), c("fidc", "fip"))
  hits <- search_fund_directory(directory, cnpj = "00332266000131", period_from = "2026-03")
  expect_equal(hits$administrator_name, "OUTRA ADMINISTRADORA LTDA")
  expect_equal(nrow(search_fund_directory(directory, period_from = "2026-02-15",
                                          period_to = "2026-02-20")), 1L)
  expect_equal(nrow(search_fund_directory(directory, period_from = "2027",
                                          period_to = "2027-12")), 0L)
  expect_error(search_fund_directory(directory, period_from = "02/2026"), "yyyy")
  expect_equal(period_bound("2026", upper = TRUE), "2026-12-31")
  expect_equal(period_bound("2026-02"), "2026-02-01")
  expect_true(is.na(period_bound("")))
})

test_that("report rows keep original values, drop empty columns and cite the source", {
  rows <- fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo", "00.332.266/0001-31")
  expect_equal(nrow(rows), 2L)
  expect_equal(rows$Valor_Ativo, c("-1.234,56", "0,00"))
  expect_false("Campo_Vazio" %in% names(rows))
  expect_equal(rows$source_line, 2:3)
  expect_equal(rows$source_url[1], "https://dados.cvm.gov.br/dados/FII/inf_mensal_fii_2026.zip")
  expect_match(rows$citation[1], "^CVM INF_MENSAL, inf_mensal_fii_ativo_passivo_2026.csv, linha 2, arquivo SHA-256 [0-9a-f]{12}$")
  expect_true("Campo_Vazio" %in% names(fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo",
                                                       "00332266000131", drop_empty = FALSE)))
  march <- fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo", "00332266000131",
                            period_from = "2026-03")
  expect_equal(march$Valor_Ativo, "0,00")
  expect_equal(nrow(fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo", "99999999000191")), 0L)
})

test_that("the directory cache is reused and rebuilt when a registry table changes", {
  paths <- fund_search_paths(root)
  expect_true(file.exists(paths$directory))
  stamp <- readRDS(paths$index)$built_at
  Sys.sleep(1.1)
  again <- load_fund_directory(root)
  expect_equal(readRDS(paths$index)$built_at, stamp)
  expect_equal(again, directory, ignore_attr = TRUE)
  index <- readRDS(fund_processed_paths(root)$index)
  index$output_sha256[index$table_name == "inf_mensal_fii_geral"] <- "changed"
  saveRDS(index, fund_processed_paths(root)$index)
  load_fund_directory(root)
  expect_false(identical(readRDS(paths$index)$built_at, stamp))
})

test_that("tables and quality summaries come from the consolidation outputs", {
  tables <- fund_tables(root, "fii")
  expect_equal(tables$table_name, c("inf_mensal_fii_ativo_passivo", "inf_mensal_fii_geral"))
  expect_equal(tables$rows, c(3L, 4L))
  expect_equal(nrow(fund_tables(root, "fiagro")), 0L)
  quality <- fund_quality_summary(root)
  expect_true(all(c("family", "issue_type", "records") %in% names(quality)))
  expect_true("invalid_cnpj" %in% quality$issue_type[quality$family == "fii"])
})

test_that("the Shiny area searches, lists rows with linked citations and reports bad input", {
  skip_if_not_installed("shiny")
  source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"), encoding = "UTF-8")
  shiny::testServer(fund_search_server, args = list(root = root), {
    session$setInputs(family = c("fii", "fidc", "fip"), cnpj = "00.332.266", name = "",
                      administrator = "", period_from = "", period_to = "", search = 1)
    expect_match(output$summary, "^2 entradas")
    session$setInputs(fund = "fii|00332266000131", table = "inf_mensal_fii_ativo_passivo")
    expect_match(output$rows_summary, "^2 linhas")
    expect_match(output$rows, "<a href=\"https://dados.cvm.gov.br/dados/FII/inf_mensal_fii_2026.zip\"",
                 fixed = TRUE)
    expect_match(output$rows, "-1.234,56", fixed = TRUE)
    session$setInputs(period_from = "13/2026", search = 2)
    expect_match(output$summary, "^Erro:")
  })
})
