# Tests for the per-source-family data layout and its migration
# (src/common/data_layout.R). Synthetic folders in temporary directories only.
# Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_data_layout.R')"

source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "data_layout.R"))

new_data_dir <- function() {
  dir <- tempfile("taxminer_layout_")
  dir.create(dir)
  normalizePath(dir, winslash = "/")
}

touch <- function(path, text = "x") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(text, path)
  path
}

write_manifest <- function(path, raw_paths) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data.frame(source_id = seq_along(raw_paths), outcome = "downloaded",
                              raw_path = raw_paths), path, row.names = FALSE)
}

test_that("family roots are per family, with the legacy DFP root while it exists", {
  dir <- new_data_dir()
  expect_equal(source_data_root(dir, "investment_fund_reports"), file.path(dir, "investment_fund_reports"))
  expect_equal(source_data_root(dir, "financial_disclosures"), file.path(dir, "financial_disclosures"))
  touch(file.path(dir, "manifest.csv"))
  expect_equal(source_data_root(dir, "financial_disclosures"), dir)
  touch(file.path(dir, "financial_disclosures", "manifest.csv"))
  expect_equal(source_data_root(dir, "financial_disclosures"), file.path(dir, "financial_disclosures"))
  expect_error(source_data_root(dir, "unknown_family"))
  expect_error(resolve_data_dir(""), "TAXMINER_DATA_DIR")
  expect_error(resolve_data_dir("C:/Users/x/OneDrive - Org/data", must_work = FALSE), "OneDrive")
})

test_that("fund files and notes output move into their family folders", {
  dir <- new_data_dir()
  raw <- touch(file.path(dir, "raw", "investment_fund_reports", "fii", "inf_mensal", "f", "abc.zip"))
  write_manifest(file.path(dir, "investment_fund_reports", "manifests", "fii.csv"), raw)
  touch(file.path(dir, "processed", "financial_disclosures", "financial_notes", "part-1.parquet"))
  touch(file.path(dir, "extract_financial_notes.log"))
  touch(file.path(dir, "manifest.csv"))
  log <- organize_data_dir(dir)
  expect_true(file.exists(file.path(dir, "investment_fund_reports", "raw", "fii", "inf_mensal", "f", "abc.zip")))
  manifest <- utils::read.csv(file.path(dir, "investment_fund_reports", "manifests", "fii.csv"))
  expect_equal(manifest$raw_path, "raw/fii/inf_mensal/f/abc.zip")
  expect_true(file.exists(file.path(dir, "financial_disclosures", "processed", "financial_notes", "part-1.parquet")))
  expect_true(file.exists(file.path(dir, "financial_disclosures", "logs", "extract_financial_notes.log")))
  expect_false(dir.exists(file.path(dir, "raw")))
  expect_false(dir.exists(file.path(dir, "processed")))
  expect_true(file.exists(file.path(dir, "manifest.csv")))  # DFP untouched without `dfp`
  expect_length(organize_data_dir(dir), 0L)
})

test_that("the DFP migration refuses while the collection is active", {
  dir <- new_data_dir()
  touch(file.path(dir, "manifest.csv"))
  expect_error(organize_data_dir(dir, include_dfp = TRUE), "active")
  expect_error(organize_data_dir(dir, include_dfp = TRUE, collection_active = TRUE), "active")
  expect_true(file.exists(file.path(dir, "manifest.csv")))
})

test_that("the DFP collection moves with its manifest paths rewritten", {
  dir <- new_data_dir()
  package <- touch(file.path(dir, "raw", "dfp", "2025", "1.zip"))
  write_manifest(file.path(dir, "manifest.csv"), c(package, ""))
  touch(file.path(dir, "catalog.csv"))
  touch(file.path(dir, "index", "dfp_cia_aberta_2025.zip"))
  touch(file.path(dir, "collect_dfp.log"))
  organize_data_dir(dir, include_dfp = TRUE, collection_active = FALSE)
  root <- file.path(dir, "financial_disclosures")
  expect_equal(source_data_root(dir, "financial_disclosures"), root)
  manifest <- utils::read.csv(file.path(root, "manifest.csv"), colClasses = "character",
                              na.strings = character())
  expect_equal(manifest$raw_path, c(file.path(root, "raw", "dfp", "2025", "1.zip"), ""))
  expect_true(file.exists(manifest$raw_path[1]))
  expect_true(file.exists(file.path(root, "index", "dfp_cia_aberta_2025.zip")))
  expect_true(file.exists(file.path(root, "logs", "collect_dfp.log")))
  expect_false(file.exists(file.path(dir, "manifest.csv")))
  expect_false(dir.exists(file.path(dir, "raw")))
})

test_that("an existing destination is never overwritten", {
  dir <- new_data_dir()
  touch(file.path(dir, "processed", "financial_disclosures", "a.txt"))
  touch(file.path(dir, "financial_disclosures", "processed", "b.txt"))
  expect_error(organize_data_dir(dir), "already exists")
  expect_true(file.exists(file.path(dir, "processed", "financial_disclosures", "a.txt")))
})
