if (!file.exists("taxminer.Rproj") || !file.exists("renv/activate.R")) {
  stop("Run from the project root after scripts/setup_environment.R.")
}
if (.Platform$OS.type == "windows") {
  current_ctype <- Sys.getlocale("LC_CTYPE")
  if (identical(current_ctype, "C") || grepl("^C\\.UTF-8$", current_ctype, ignore.case = TRUE)) {
    normalized_ctype <- Sys.setlocale("LC_CTYPE", "English_United States.utf8")
    if (is.na(normalized_ctype)) {
      stop("Windows R could not set a UTF-8 LC_CTYPE for environment validation.")
    }
  }
  cat("LC_CTYPE: ", Sys.getlocale("LC_CTYPE"), "\n", sep = "")
}
source(".Rprofile")
if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("The project testthat dependency is missing.")
}
cat("Environment: ", R.version.string, "\n", sep = "")
cat("testthat: ", as.character(packageVersion("testthat")), "\n", sep = "")
# Explicit test input; no root traversal or fixture discovery.
testthat::test_file("tests/testthat/test_environment.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test_financial_collection.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test_financial_notes.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test_common_primitives.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test_financial_notes_parquet.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test_fund_reports_collection.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test_data_layout.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test_fund_reports_consolidation.R", stop_on_failure = TRUE)
