# Data P03 (Phase 1.2) tests for the Parquet consolidation of notes. A fake
# extractor and a synthetic catalog/manifest in a temporary directory replace
# real filings; no network. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_financial_notes_parquet.R')"

source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "parquet_io.R"))
source(testthat::test_path("..", "..", "src", "data", "extract_financial_notes.R"))
source(testthat::test_path("..", "..", "src", "data", "consolidate_financial_notes.R"))
source(testthat::test_path("helper_stored_zip.R"))

synthetic_data_dir <- function(ids = c("900001", "900002", "900003"),
                               outcomes = c("downloaded", "downloaded", "unavailable")) {
  dir <- tempfile("taxminer_data_")
  raw <- file.path(dir, "raw", "dfp", "2025")
  dir.create(raw, recursive = TRUE)
  paths <- file.path(raw, paste0(ids, ".zip"))
  for (i in seq_along(ids)) writeLines(paste("synthetic package", ids[i]), paths[i])
  catalog <- data.frame(
    source_id = "cvm_open_data_dfp", report_id = sprintf("cvm:dfp:099999:2025-12-31:v%d", seq_along(ids)),
    source_document_id = ids, report_type = "DFP", source_category = "DFP", cvm_code = "099999",
    company_cnpj = "12345678000100", company_name = "Companhia Sintetica S.A.",
    reporting_period_end = "2025-12-31", document_version = "1", filing_date = "2026-03-01",
    source_url = sprintf("https://example.invalid/doc/%s", ids), index_year = "2025",
    stringsAsFactors = FALSE)
  manifest <- data.frame(source_document_id = ids, report_id = catalog$report_id,
                         outcome = outcomes, package_sha256 = sprintf("sha-%s-a", ids),
                         raw_path = paths, stringsAsFactors = FALSE)
  utils::write.csv(catalog, file.path(dir, "catalog.csv"), row.names = FALSE)
  utils::write.csv(manifest, file.path(dir, "manifest.csv"), row.names = FALSE)
  dir
}

# Materialize an Arrow dataset without dplyr.
collect_dataset <- function(ds) as.data.frame(ds$NewScan()$Finish()$ToTable())

# Fake extractor: two notes per package, or none for ids listed in `no_notes`.
fake_extractor <- function(no_notes = character(), calls = new.env()) {
  calls$ids <- character()
  function(package_path, report) {
    calls$ids <- c(calls$ids, report$source_document_id)
    base <- data.frame(report_id = report$report_id, source_document_id = report$source_document_id,
                       report_type = report$report_type, package_sha256 = report$package_sha256,
                       document_version = 1L, page_count = 10L, stringsAsFactors = FALSE)
    if (report$source_document_id %in% no_notes) {
      base$extraction_status <- "no_note_structure"; base$note_count <- 0L
      return(list(report = base, notes = NULL))
    }
    base$extraction_status <- "extracted"; base$note_count <- 2L
    notes <- data.frame(note_id = paste0(report$report_id, ":n", 1:2), report_id = report$report_id,
                        note_sequence = 1:2, note_set = 1L, note_number = c("1", "2"),
                        note_title = c("CONTEXTO OPERACIONAL", "CAIXA"),
                        note_text = c("Texto sintético um.", "Texto sintético dois."),
                        source_page_start = c(1, 2), source_page_end = c(1, 3),
                        unit_scale = "thousands", stringsAsFactors = FALSE)
    list(report = base, notes = notes)
  }
}

test_that("downloaded packages are written as Parquet parts with one schema", {
  skip_if_not_installed("arrow")
  dir <- synthetic_data_dir()
  touched <- consolidate_financial_notes(dir, extractor = fake_extractor(), signature = "sig-1",
                                         progress = FALSE)
  expect_equal(touched$source_document_id, c("900001", "900002"))
  notes <- collect_dataset(open_financial_notes(dir, "financial_notes"))
  expect_equal(nrow(notes), 4L)
  expect_equal(names(notes), names(financial_note_columns))
  expect_type(notes$source_page_end, "integer")
  expect_equal(unique(notes$company_cnpj), "12345678000100")
  reports <- collect_dataset(open_financial_notes(dir, "financial_reports"))
  expect_equal(sort(reports$source_document_id), c("900001", "900002"))
  expect_equal(unique(reports$extraction_signature), "sig-1")
})

test_that("reruns skip unchanged packages and reprocess on signature or hash change", {
  skip_if_not_installed("arrow")
  dir <- synthetic_data_dir()
  consolidate_financial_notes(dir, extractor = fake_extractor(), signature = "sig-1", progress = FALSE)
  calls <- new.env()
  expect_equal(nrow(consolidate_financial_notes(dir, extractor = fake_extractor(calls = calls),
                                                signature = "sig-1", progress = FALSE)), 0L)
  expect_length(calls$ids, 0L)
  manifest <- utils::read.csv(file.path(dir, "manifest.csv"), colClasses = "character")
  manifest$package_sha256[1] <- "sha-900001-b"
  utils::write.csv(manifest, file.path(dir, "manifest.csv"), row.names = FALSE)
  consolidate_financial_notes(dir, extractor = fake_extractor(calls = calls), signature = "sig-1",
                              progress = FALSE)
  expect_equal(calls$ids, "900001")
  consolidate_financial_notes(dir, extractor = fake_extractor(calls = calls), signature = "sig-2",
                              progress = FALSE)
  expect_equal(sort(calls$ids), c("900001", "900002"))
  index <- readRDS(financial_notes_paths(dir)$index)
  expect_equal(nrow(index), 2L)
  expect_equal(unique(index$extraction_signature), "sig-2")
})

test_that("max_reports bounds a run and a later run resumes", {
  skip_if_not_installed("arrow")
  dir <- synthetic_data_dir()
  first <- consolidate_financial_notes(dir, max_reports = 1, extractor = fake_extractor(),
                                       signature = "sig-1", progress = FALSE)
  expect_equal(first$source_document_id, "900001")
  second <- consolidate_financial_notes(dir, extractor = fake_extractor(), signature = "sig-1",
                                        progress = FALSE)
  expect_equal(second$source_document_id, "900002")
})

test_that("stale notes are removed when a reprocessed package yields none", {
  skip_if_not_installed("arrow")
  dir <- synthetic_data_dir()
  consolidate_financial_notes(dir, extractor = fake_extractor(), signature = "sig-1", progress = FALSE)
  part <- file.path(financial_notes_paths(dir)$notes, "part-900002.parquet")
  expect_true(file.exists(part))
  consolidate_financial_notes(dir, extractor = fake_extractor(no_notes = "900002"),
                              signature = "sig-2", progress = FALSE)
  expect_false(file.exists(part))
  index <- readRDS(financial_notes_paths(dir)$index)
  expect_equal(index$extraction_status[index$source_document_id == "900002"], "no_note_structure")
})

test_that("an extractor error is recorded and does not stop the run", {
  skip_if_not_installed("arrow")
  dir <- synthetic_data_dir()
  failing <- function(package_path, report) {
    if (report$source_document_id == "900001") stop("synthetic failure")
    fake_extractor()(package_path, report)
  }
  touched <- consolidate_financial_notes(dir, extractor = failing, signature = "sig-1", progress = FALSE)
  expect_equal(touched$extraction_status, c("extraction_failed", "extracted"))
  report <- arrow::read_parquet(file.path(financial_notes_paths(dir)$reports, "part-900001.parquet"))
  expect_match(report$extraction_error, "synthetic failure")
})

test_that("the extraction signature changes with the extraction logic", {
  original <- notes_extraction_signature()
  expect_match(original, "^[0-9a-f]{64}$")
  saved <- detect_unit_scale
  detect_unit_scale <<- function(text) NA_character_
  on.exit(detect_unit_scale <<- saved)
  expect_false(identical(original, notes_extraction_signature()))
})

test_that("catalog lines with names cut at an accent are repaired, not dropped", {
  dir <- synthetic_data_dir()
  path <- file.path(dir, "catalog.csv")
  lines <- readLines(path)
  lines[2] <- sub('"Companhia Sintetica S.A."', '"CPFL TRANSMISS', lines[2], fixed = TRUE)
  lines[3] <- sub('"Companhia Sintetica S.A."', '"', lines[3], fixed = TRUE)
  writeLines(lines, path)
  catalog <- read_catalog_tolerant(path)
  expect_equal(nrow(catalog), 3L)
  expect_equal(catalog$company_name, c("CPFL TRANSMISS", "", "Companhia Sintetica S.A."))
  expect_equal(catalog$reporting_period_end, rep("2025-12-31", 3))
  expect_equal(nrow(index_company_names(dir)), 0L)
})

test_that("company names come from the Latin-1 index when it is present", {
  dir <- synthetic_data_dir()
  dir.create(file.path(dir, "index"))
  csv <- iconv("CNPJ_CIA;DENOM_CIA;ID_DOC\n12.345.678/0001-00;RAÍZEN S.A.;900001\n",
               "UTF-8", "latin1")
  write_stored_zip(file.path(dir, "index", "dfp_cia_aberta_2025.zip"),
                   list("dfp_cia_aberta_2025.csv" = csv))
  reports <- downloaded_reports(dir)
  expect_equal(reports$company_name[reports$source_document_id == "900001"], "RAÍZEN S.A.")
  expect_equal(reports$company_name[reports$source_document_id == "900002"], "Companhia Sintetica S.A.")
})

test_that("outputs can go to a folder separate from the collection inputs", {
  skip_if_not_installed("arrow")
  dir <- synthetic_data_dir()
  out <- tempfile("notes_output_")
  consolidate_financial_notes(dir, extractor = fake_extractor(), signature = "sig-1",
                              progress = FALSE, output_dir = out)
  expect_true(file.exists(file.path(out, "processed", "financial_notes", "part-900001.parquet")))
  expect_false(dir.exists(file.path(dir, "processed")))
  expect_equal(nrow(collect_dataset(open_financial_notes(out, "financial_reports"))), 2L)
})
