if (!file.exists("taxminer.Rproj") || !file.exists("renv/activate.R")) {
  stop("Run from the project root after scripts/setup_environment.R.")
}
source(".Rprofile")
if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("The project testthat dependency is missing.")
}
cat("Environment: ", R.version.string, "\n", sep = "")
cat("testthat: ", as.character(packageVersion("testthat")), "\n", sep = "")
# Explicit test input; no root traversal or fixture discovery.
testthat::test_file("tests/testthat/test_environment.R", stop_on_failure = TRUE)
