# Collect P04 tests with public and synthetic fixtures only; no network access.
# Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_financial_collection.R')"

source(testthat::test_path("..", "..", "src", "collect", "discover_financial_reports.R"))
source(testthat::test_path("..", "..", "src", "collect", "download_financial_reports.R"))

fixture_index <- testthat::test_path("..", "fixtures", "cvm_dfp_index_sample.csv")
fixture_package <- testthat::test_path("..", "fixtures", "synthetic_filing_package.zip")

synthetic_catalog <- function(ids) {
  data.frame(source_id = "cvm_open_data_dfp",
             report_id = sprintf("cvm:dfp:099999:2025-12-31:v%d", seq_along(ids)),
             source_document_id = ids, report_type = "DFP",
             source_category = "DFP", cvm_code = "099999",
             company_cnpj = "12345678000100", company_name = "Companhia Sintetica S.A.",
             reporting_period_end = "2025-12-31", document_version = seq_along(ids),
             filing_date = "2026-03-01",
             source_url = sprintf("https://example.invalid/doc/%s", ids),
             stringsAsFactors = FALSE)
}

fake_fetcher <- function(statuses) {
  calls <- 0L
  function(url, output_file, user_agent) {
    calls <<- calls + 1L
    status <- statuses[[min(calls, length(statuses))]]
    if (status == 200L) file.copy(fixture_package, output_file, overwrite = TRUE)
    if (status == -1L) {
      writeLines("The HTTP service ... is unavailable.", output_file); status <- 200L
    }
    list(status = status, error = "")
  }
}

test_that("index rows become stable report identities", {
  catalog <- parse_cvm_index(fixture_index, "dfp", encoding = "UTF-8")
  expect_equal(nrow(catalog), 3)
  expect_equal(catalog$report_id[1], "cvm:dfp:025496:2026-03-31:v1")
  expect_equal(catalog$company_cnpj[1], "02635522000195")
  expect_true(all(startsWith(catalog$source_url, "https://www.rad.cvm.gov.br/")))
  expect_equal(cvm_index_zip_url("itr", 2024),
               "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/ITR/DADOS/itr_cia_aberta_2024.zip")
})

test_that("missing index columns fail loudly", {
  expect_error(normalize_cvm_index(data.frame(CNPJ_CIA = "x"), "dfp"), "columns missing")
})

test_that("download records checksums per member and is resumable", {
  work <- tempfile("collect_"); dir.create(work)
  manifest <- file.path(work, "manifest.csv")
  catalog <- synthetic_catalog(c("1001", "1002"))
  first <- download_financial_reports(catalog, file.path(work, "raw"), manifest,
                                      fetcher = fake_fetcher(list(200L)),
                                      delay_seconds = 0, log = function(...) NULL)
  expect_equal(first$outcome, c("downloaded", "downloaded"))
  expect_equal(as.integer(first$member_count), c(2L, 2L))
  expect_match(first$member_sha256[1], "^099999DFP31-12-2025v1\\.xml=[0-9a-f]{64};")
  expect_true(file.exists(file.path(work, "raw", "dfp", "2025", "1001.zip")))
  second <- download_financial_reports(catalog, file.path(work, "raw"), manifest,
                                       fetcher = fake_fetcher(list(500L)),
                                       delay_seconds = 0, log = function(...) NULL)
  expect_equal(nrow(second), 0)
  expect_equal(nrow(read_manifest(manifest)), 2)
})

test_that("refusal stops the run and busy-service text is never stored", {
  work <- tempfile("collect_"); dir.create(work)
  manifest <- file.path(work, "manifest.csv")
  refused <- download_financial_reports(synthetic_catalog(c("2001", "2002")),
                                        file.path(work, "raw"), manifest,
                                        fetcher = fake_fetcher(list(403L)),
                                        delay_seconds = 0, log = function(...) NULL)
  expect_equal(refused$outcome, "refused")
  html <- download_financial_reports(synthetic_catalog("3001"), file.path(work, "raw"),
                                     manifest, fetcher = fake_fetcher(list(-1L)),
                                     delay_seconds = 0, backoff_seconds = 0,
                                     log = function(...) NULL)
  expect_equal(html$outcome, "failed")
  expect_match(html$error, "non-ZIP response")
  expect_equal(html$attempts, 3L)
  expect_false(file.exists(file.path(work, "raw", "dfp", "2025", "3001.zip")))
})

test_that("server errors are retried, then recorded as failed and retried next run", {
  work <- tempfile("collect_"); dir.create(work)
  manifest <- file.path(work, "manifest.csv")
  failed <- download_financial_reports(synthetic_catalog("4001"), file.path(work, "raw"),
                                       manifest, fetcher = fake_fetcher(list(503L)),
                                       delay_seconds = 0, backoff_seconds = 0,
                                       log = function(...) NULL)
  expect_equal(failed$outcome, "failed")
  expect_equal(failed$attempts, 3L)
  retried <- download_financial_reports(synthetic_catalog("4001"), file.path(work, "raw"),
                                        manifest, fetcher = fake_fetcher(list(200L)),
                                        delay_seconds = 0, log = function(...) NULL)
  expect_equal(retried$outcome, "downloaded")
})

test_that("busy service is retried within the run", {
  work <- tempfile("collect_"); dir.create(work)
  row <- download_financial_reports(synthetic_catalog("6001"), file.path(work, "raw"),
                                    file.path(work, "manifest.csv"),
                                    fetcher = fake_fetcher(list(-1L, 200L)),
                                    delay_seconds = 0, backoff_seconds = 0,
                                    log = function(...) NULL)
  expect_equal(row$outcome, "downloaded")
  expect_equal(row$attempts, 2L)
})

test_that("truncated packages are rejected and stored ones quarantined", {
  work <- tempfile("collect_"); dir.create(work)
  broken <- function(url, output_file, user_agent) {
    writeBin(c(as.raw(c(0x50, 0x4b, 0x03, 0x04)), as.raw(rep(0, 20))), output_file)
    list(status = 200L, error = "")
  }
  row <- download_financial_reports(synthetic_catalog("5001"), file.path(work, "raw"),
                                    file.path(work, "manifest.csv"), fetcher = broken,
                                    delay_seconds = 0, backoff_seconds = 0,
                                    log = function(...) NULL)
  expect_equal(row$outcome, "failed")
  expect_match(row$error, "truncated")
  expect_false(file.exists(file.path(work, "raw", "dfp", "2025", "5001.zip")))
  stored <- file.path(work, "raw", "dfp", "2025", "5002.zip")
  writeBin(as.raw(c(0x50, 0x4b, 0x03, 0x04, 0, 0)), stored)
  again <- download_financial_reports(synthetic_catalog("5002"), file.path(work, "raw"),
                                      file.path(work, "manifest.csv"),
                                      fetcher = fake_fetcher(list(200L)),
                                      delay_seconds = 0, log = function(...) NULL)
  expect_equal(again$outcome, "downloaded")
  expect_length(list.files(file.path(work, "quarantine")), 1)
})
