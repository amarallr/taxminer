# Common P07 stage 02 tests for src/common/ (decision_0023). Synthetic inputs in
# temporary directories only; no network. Source test IDs are kept as
# `origin` in each description. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_common_primitives.R')"

source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "execution_policy.R"))
source(testthat::test_path("helper_stored_zip.R"))

fixture_package <- testthat::test_path("..", "fixtures", "synthetic_filing_package.zip")

new_root <- function() {
  root <- tempfile("common_root_")
  dir.create(root)
  root
}


test_that("contained paths accept relative children and reject escapes (origin P02-TST-001)", {
  root <- new_root()
  expect_equal(validate_contained_path(root, "state/a.rds"), file.path(normalizePath(root, winslash = "/"), "state/a.rds"))
  for (bad in c("../outside.rds", "a/../../b", "/etc/passwd", "C:/x", "", NA_character_)) {
    expect_error(validate_contained_path(root, bad), "relative|root")
  }
})

test_that("validated atomic write publishes RDS and CSV and keeps no backup (origin P02-TST-003)", {
  root <- new_root()
  rds <- file.path(root, "state", "x.rds")
  out <- write_validated_atomic(list(a = 1, b = "dois"), rds)
  expect_equal(readRDS(rds), list(a = 1, b = "dois"))
  expect_equal(out$sha256, compute_signature_hash(rds, file = TRUE))
  expect_false(file.exists(paste0(rds, ".rollback")))
  csv <- file.path(root, "table.csv")
  write_validated_atomic(data.frame(id = c("1", "2"), value = c("á", "b")), csv, "csv")
  expect_equal(read.csv(csv, colClasses = "character", encoding = "UTF-8")$value, c("á", "b"))
})

test_that("a rejected or failed publication keeps the previous version (origin P02-TST-004)", {
  root <- new_root()
  path <- file.path(root, "x.rds")
  write_validated_atomic(list(version = 1), path)
  expect_error(write_validated_atomic(list(version = 2), path,
                                      validator = function(x) x$version < 2), "rejected")
  expect_equal(readRDS(path)$version, 1)
  calls <- 0L
  failing_rename <- function(from, to) {
    calls <<- calls + 1L
    if (calls == 2L) FALSE else file.rename(from, to)
  }
  expect_error(write_validated_atomic(list(version = 3), path, rename = failing_rename),
               "previous version kept")
  expect_equal(readRDS(path)$version, 1)
  expect_false(file.exists(paste0(path, ".rollback")))
})

test_that("an interrupted replacement is recovered from its rollback (origin P02-TST-011)", {
  root <- new_root()
  path <- file.path(root, "x.rds")
  saveRDS(list(version = 1), paste0(path, ".rollback"))
  writeBin(as.raw(1:3), path)  # half-written destination
  expect_true(recover_from_rollback(path))
  expect_equal(readRDS(path)$version, 1)
  expect_length(list.files(root, pattern = "interrupted"), 1L)
  writeBin(as.raw(1:3), paste0(path, ".rollback"))
  expect_error(recover_from_rollback(path), "Invalid rollback")
  expect_true(file.exists(paste0(path, ".rollback")))
})

test_that("a corrupt RDS is preserved and never read as success (origin P02-TST-012)", {
  root <- new_root()
  path <- file.path(root, "manifest.rds")
  expect_null(read_rds_recoverable(path))
  writeBin(as.raw(c(0x1f, 0x8b, 0, 1)), path)
  expect_warning(result <- read_rds_recoverable(path), "rebuild")
  expect_null(result)
  expect_false(file.exists(path))
  expect_length(list.files(root, pattern = "corrupt"), 1L)
})

test_that("signatures are deterministic and order-insensitive for named lists (origin P02-TST-013)", {
  expect_equal(compute_signature_hash(list(a = 1, b = 2)), compute_signature_hash(list(b = 2, a = 1)))
  expect_false(identical(compute_signature_hash(list(a = 1)), compute_signature_hash(list(a = 2))))
  expect_match(compute_signature_hash("x"), "^[0-9a-f]{64}$")
  root <- new_root()
  writeLines("a <- 1", file.path(root, "a.R"))
  before <- code_signature("a.R", root)
  writeLines("a <- 2", file.path(root, "a.R"))
  expect_false(identical(before, code_signature("a.R", root)))
  expect_error(code_signature(character(), root), "explicit")
  f1 <- function(x) {
    x + 1
  }
  f2 <- function(x) {
    # comments are not part of the logic
    x + 1
  }
  f3 <- function(x) {
    x + 2
  }
  expect_equal(transformation_signature(list(f = f1)), transformation_signature(list(f = f2)))
  expect_false(identical(transformation_signature(list(f = f1)), transformation_signature(list(f = f3))))
})

test_that("execution policy separates checkpoint reuse from downloads (origin P02-TST-005)", {
  expect_equal(resolve_execution_policy(), list(download = FALSE, reuse_checkpoint = TRUE))
  expect_equal(resolve_execution_policy(TRUE, TRUE, FALSE), list(download = TRUE, reuse_checkpoint = TRUE))
  expect_equal(resolve_execution_policy(TRUE, FALSE, TRUE), list(download = TRUE, reuse_checkpoint = FALSE))
  expect_equal(resolve_execution_policy(FALSE, FALSE, FALSE), list(download = FALSE, reuse_checkpoint = FALSE))
  expect_error(resolve_execution_policy(NA), "TRUE/FALSE")
  expect_error(resolve_execution_policy("yes"), "TRUE/FALSE")
})

test_that("attempts are recorded as in_progress and then finished (origin P02-TST-013)", {
  root <- new_root()
  finish <- record_attempt("collect_sample", list(limit = 5), "state", root)
  last <- readRDS(file.path(root, "state", "last_attempt.rds"))
  expect_equal(last$status, "in_progress")
  expect_equal(last$pid, Sys.getpid())
  finish("failed", reason = "synthetic interruption")
  last <- readRDS(file.path(root, "state", "last_attempt.rds"))
  expect_equal(last$status, "failed")
  expect_equal(last$reason, "synthetic interruption")
  expect_false(is.na(last$finished_at))
  expect_length(list.files(file.path(root, "state", "attempts")), 1L)
  expect_error(record_attempt("x", list(), "../outside", root), "relative|root")
})

test_that("ZIP archives are checked for limits, unsafe names and integrity (origin P05_01-TST-001)", {
  members <- validate_zip_archive(fixture_package)
  expect_equal(nrow(members), 2L)
  expect_match(members$sha256, "^[0-9a-f]{64}$")
  dir <- new_root()
  ok <- write_stored_zip(file.path(dir, "ok.zip"), list("a.csv" = "id;valor\n1;2\n"))
  expect_equal(validate_zip_archive(ok)$name, "a.csv")
  traversal <- write_stored_zip(file.path(dir, "t.zip"), list("../evil.csv" = "x"))
  expect_error(validate_zip_archive(traversal), "Unsafe")
  duplicate <- write_stored_zip(file.path(dir, "d.zip"), list("A.csv" = "x", "a.csv" = "y"))
  expect_error(validate_zip_archive(duplicate), "Unsafe|duplicate")
  nested <- write_stored_zip(file.path(dir, "n.zip"), list("sub/a.csv" = "x"))
  expect_error(validate_zip_archive(nested), "Unsafe")
  expect_equal(validate_zip_archive(nested, allow_subdirectories = TRUE)$name, "sub/a.csv")
  expect_error(validate_zip_archive(ok, max_members = 0L), "limits")
  truncated <- file.path(dir, "cut.zip")
  writeBin(readBin(fixture_package, "raw", 200), truncated)
  expect_error(validate_zip_archive(truncated), "Unreadable|failed|Incomplete")
})
