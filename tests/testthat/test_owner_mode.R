# Owner-only features (Governança tab, governance command line, installer generation):
# enabled only with TAXMINER_OWNER_MODE=1 in the owner's user profile.
source(testthat::test_path("..", "..", "src", "common", "owner_mode.R"))

with_owner <- function(value, code) {
  old <- Sys.getenv("TAXMINER_OWNER_MODE", unset = NA)
  on.exit(if (is.na(old)) Sys.unsetenv("TAXMINER_OWNER_MODE") else Sys.setenv(TAXMINER_OWNER_MODE = old))
  if (is.na(value)) Sys.unsetenv("TAXMINER_OWNER_MODE") else Sys.setenv(TAXMINER_OWNER_MODE = value)
  force(code)
}

test_that("owner mode needs exactly TAXMINER_OWNER_MODE=1", {
  expect_false(with_owner(NA, taxminer_owner_mode()))
  expect_false(with_owner("", taxminer_owner_mode()))
  expect_false(with_owner("true", taxminer_owner_mode()))
  expect_true(with_owner("1", taxminer_owner_mode()))
  expect_error(with_owner(NA, taxminer_require_owner("A governança")), "somente para o proprietário")
  expect_true(with_owner("1", taxminer_require_owner("A governança")))
})

test_that("the governance command line refuses to run without the owner flag", {
  root <- normalizePath(testthat::test_path("..", ".."))
  rscript <- file.path(R.home("bin"), "Rscript")
  old <- setwd(root); on.exit(setwd(old))
  out <- with_owner(NA, suppressWarnings(system2(rscript, c("--vanilla", "scripts/governance_registry.R", "summary"),
                                                 stdout = TRUE, stderr = TRUE)))
  expect_true(any(grepl("somente para o propriet", out)))
  expect_identical(attr(out, "status"), 1L)
})

test_that("the app shows the Governança tab only in owner mode", {
  app <- readLines(testthat::test_path("..", "..", "prototype", "app.R"), encoding = "UTF-8")
  expect_true(any(grepl('if (owner_mode) bslib::nav_panel("Governança"', app, fixed = TRUE)))
  expect_true(any(grepl("if (owner_mode) governance_server(", app, fixed = TRUE)))
  site <- readLines(testthat::test_path("..", "..", "site", "app", "index.html"), encoding = "UTF-8", warn = FALSE)
  expect_false(any(grepl("Governança", site, fixed = TRUE)))
})
