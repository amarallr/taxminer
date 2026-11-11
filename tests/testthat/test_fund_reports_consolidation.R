# Data P04 (Phase 1.3) tests for the consolidation of CVM investment fund
# report tables. Synthetic Latin-1 members, ZIPs, manifests and META
# dictionaries in temporary directories; no network. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_fund_reports_consolidation.R')"

source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "parquet_io.R"))
source(testthat::test_path("..", "..", "src", "data", "consolidate_fund_reports.R"))
source(testthat::test_path("helper_stored_zip.R"))

latin1 <- function(x) iconv(x, "UTF-8", "latin1")

geral_v1 <- paste0(c(
  "CNPJ_Fundo_Classe;Data_Referencia;Versao;Nome_Fundo_Classe",
  "00.332.266/0001-31;2026-01-01;1;FUNDO SÃO PAULO \"EDIFÍCIO A\"",
  "00.332.266/0001-31;2026-01-01;2;FUNDO SÃO PAULO \"EDIFÍCIO A\"",
  "11.111.111/1111-11;2026-01-01;1;INVALIDO",
  ";2026-01-01;1;SEM CNPJ",
  "33.000.167/0001-01;2026-01-01;1;EXTRA;CAMPO",
  "33.000.167/0001-01;2026-01-01;1;EXTRA;CAMPO"), collapse = "\n")

# A family root with one FII file (ZIP), a manifest row and a META dictionary.
fund_root <- function(members = list("inf_mensal_fii_geral_2026.csv" = latin1(geral_v1)),
                      meta = c("CNPJ_Fundo_Classe", "Data_Referencia", "Versao",
                               "Nome_Fundo_Classe", "Campo_Ausente")) {
  root <- tempfile("fund_root_")
  raw <- file.path(root, "raw", "fii", "inf_mensal", "inf_mensal_fii_2026")
  dir.create(raw, recursive = TRUE)
  zip <- write_stored_zip(file.path(raw, "v1.zip"), members)
  sha <- as.character(tools::sha256sum(zip))
  final <- file.path(raw, paste0(substr(sha, 1, 12), ".zip"))
  file.rename(zip, final)
  dir.create(file.path(root, "manifests"))
  dir.create(file.path(root, "meta"))
  writeLines(latin1(paste0("Campo: ", meta, "\n   Descrição : x")),
             file.path(root, "meta", "meta_inf_mensal_fii_geral.txt"))
  add_manifest_row(root, "cvm:fii:inf_mensal:inf_mensal_fii_2026.zip", final, sha, "2026-11-11T01:00:00")
  root
}

add_manifest_row <- function(root, source_id, path, sha, retrieved_at) {
  manifest <- file.path(root, "manifests", "fii.csv")
  row <- data.frame(source_id = source_id, family = "fii", dataset = "INF_MENSAL",
                    reference_period = "2026", file_name = "inf_mensal_fii_2026.zip",
                    outcome = "downloaded", file_sha256 = sha,
                    raw_path = substring(path, nchar(root) + 2L), retrieved_at = retrieved_at)
  utils::write.table(row, manifest, sep = ",", row.names = FALSE, col.names = !file.exists(manifest),
                     append = file.exists(manifest), qmethod = "double")
}

read_table <- function(root, family, table) {
  ds <- open_fund_table(root, family, table)
  as.data.frame(ds$NewScan()$Finish()$ToTable())
}

test_that("CNPJ check digits accept numeric and alphanumeric CNPJ and reject the rest", {
  expect_equal(normalize_cnpj(c("00.332.266/0001-31", "332266000131", "12ABC34501DE35")),
               c("00332266000131", "00332266000131", "12ABC34501DE35"))
  expect_equal(normalize_cnpj(c("11.111.111/1111-11", "00.332.266/0001-32", "", NA, "abc")),
               rep(NA_character_, 5))
})

test_that("table names follow the member file and match the META dictionaries", {
  expect_equal(fund_table_name(c("inf_mensal_fidc_tab_I_202610.csv", "inf_mensal_fiagro_202505.csv",
                                 "inf_trimestral_fip_2023.csv", "inf_anual_fii_geral_2026.csv")),
               c("inf_mensal_fidc_tab_I", "inf_mensal_fiagro", "inf_trimestral_fip",
                 "inf_anual_fii_geral"))
})

test_that("members keep every row, original text and lineage", {
  skip_if_not_installed("arrow")
  root <- fund_root()
  touched <- consolidate_fund_reports(root, progress = FALSE)
  expect_equal(touched$row_count, 6L)
  rows <- read_table(root, "fii", "inf_mensal_fii_geral")
  expect_equal(nrow(rows), 6L)
  expect_equal(rows$source_line, 2:7)
  expect_equal(rows$Nome_Fundo_Classe[1], "FUNDO SÃO PAULO \"EDIFÍCIO A\"")
  expect_equal(rows$fund_cnpj_normalized[1:3], c("00332266000131", "00332266000131", NA))
  expect_equal(rows$fund_cnpj_original[4], "")
  expect_equal(unique(rows$zip_sha256), touched$file_sha256)
  expect_equal(unique(rows$source_file), "inf_mensal_fii_geral_2026.csv")
  expect_match(unique(rows$layout_version), "^[0-9a-f]{12}$")
})

test_that("quality issues are recorded as rows, never by dropping data", {
  skip_if_not_installed("arrow")
  root <- fund_root()
  consolidate_fund_reports(root, progress = FALSE)
  issues <- read_table(root, "fii", "fund_quality_issues")
  by_type <- table(issues$issue_type)
  expect_equal(as.integer(by_type[c("invalid_cnpj", "empty_fund_identifier", "field_count_mismatch",
                                    "duplicate_row", "resubmitted_versions",
                                    "repeated_fund_period", "dictionary_column_absent")]),
               c(1L, 1L, 2L, 1L, 1L, 1L, 1L))
  expect_equal(issues$source_line[issues$issue_type == "invalid_cnpj"], "4")
  expect_equal(issues$detail[issues$issue_type == "dictionary_column_absent"], "Campo_Ausente")
  expect_equal(issues$row_count[issues$issue_type == "repeated_fund_period"], "4")
})

test_that("reruns skip unchanged files; a new version replaces the parts", {
  skip_if_not_installed("arrow")
  root <- fund_root()
  consolidate_fund_reports(root, signature = "sig-1", progress = FALSE)
  expect_equal(nrow(consolidate_fund_reports(root, signature = "sig-1", progress = FALSE)), 0L)
  expect_equal(nrow(consolidate_fund_reports(root, signature = "sig-2", progress = FALSE)), 1L)
  # Republished file: one table removed, another added.
  raw <- file.path(root, "raw", "fii", "inf_mensal", "inf_mensal_fii_2026")
  zip <- write_stored_zip(file.path(raw, "v2.zip"), list(
    "inf_mensal_fii_complemento_2026.csv" = "CNPJ_Fundo_Classe;Data_Referencia\n00.332.266/0001-31;2026-02-01\n"))
  sha <- as.character(tools::sha256sum(zip))
  add_manifest_row(root, "cvm:fii:inf_mensal:inf_mensal_fii_2026.zip", zip, sha, "2026-11-12T01:00:00")
  touched <- consolidate_fund_reports(root, signature = "sig-2", progress = FALSE)
  expect_equal(touched$table_name, "inf_mensal_fii_complemento")
  expect_false(file.exists(file.path(root, "processed", "fii", "inf_mensal_fii_geral",
                                     "part-inf_mensal_fii_2026--inf_mensal_fii_geral_2026.parquet")))
  index <- readRDS(fund_processed_paths(root)$index)
  expect_equal(index$file_sha256, sha)
  issues <- read_table(root, "fii", "fund_quality_issues")
  expect_equal(unique(issues$issue_type), "no_dictionary")
})

test_that("layouts that change across periods are unified when reading a table", {
  skip_if_not_installed("arrow")
  root <- fund_root()
  consolidate_fund_reports(root, progress = FALSE)
  raw <- file.path(root, "raw", "fii", "inf_mensal", "inf_mensal_fii_2025")
  dir.create(raw, recursive = TRUE)
  path <- write_stored_zip(file.path(raw, "a.zip"), list(
    "inf_mensal_fii_geral_2025.csv" = "CNPJ_Fundo_Classe;Data_Referencia;Coluna_Antiga\n00.332.266/0001-31;2025-01-01;x\n"))
  sha <- as.character(tools::sha256sum(path))
  manifest <- file.path(root, "manifests", "fii.csv")
  row <- data.frame(source_id = "cvm:fii:inf_mensal:inf_mensal_fii_2025.zip", family = "fii",
                    dataset = "INF_MENSAL", reference_period = "2025",
                    file_name = "inf_mensal_fii_2025.zip", outcome = "downloaded", file_sha256 = sha,
                    raw_path = substring(path, nchar(root) + 2L), retrieved_at = "2026-11-11T02:00:00")
  utils::write.table(row, manifest, sep = ",", row.names = FALSE, col.names = FALSE, append = TRUE,
                     qmethod = "double")
  consolidate_fund_reports(root, progress = FALSE)
  rows <- read_table(root, "fii", "inf_mensal_fii_geral")
  expect_equal(nrow(rows), 7L)
  expect_true(all(c("Coluna_Antiga", "Nome_Fundo_Classe") %in% names(rows)))
  expect_length(unique(rows$layout_version), 2L)
})

test_that("a stored file that no longer matches its hash stops the run", {
  root <- fund_root()
  stored <- list.files(file.path(root, "raw"), recursive = TRUE, full.names = TRUE)
  writeBin(as.raw(1:10), stored)
  expect_error(consolidate_fund_reports(root, progress = FALSE), "does not match")
})

test_that("yearly files with one member per month keep every month", {
  skip_if_not_installed("arrow")
  root <- fund_root(members = list(
    "inf_mensal_fii_geral_202401.csv" = "CNPJ_Fundo_Classe;Data_Referencia\n00.332.266/0001-31;2024-01-01\n",
    "inf_mensal_fii_geral_202402.csv" = "CNPJ_Fundo_Classe;Data_Referencia\n00.332.266/0001-31;2024-02-01\n"))
  touched <- consolidate_fund_reports(root, progress = FALSE)
  expect_equal(touched$row_count, c(1L, 1L))
  expect_length(unique(touched$output_path), 2L)
  rows <- read_table(root, "fii", "inf_mensal_fii_geral")
  expect_equal(sort(rows$Data_Referencia), c("2024-01-01", "2024-02-01"))
})
