testthat::test_that("synthetic public metadata survives UTF-8 round trip", {
  fixture <- data.frame(
    document_id = c("synthetic_0001", "synthetic_0002"),
    original_document_type = c("Solução de Consulta", "Solução de Consulta"),
    stringsAsFactors = FALSE
  )
  serialized <- capture.output(utils::write.csv(fixture, row.names = FALSE))
  restored <- utils::read.csv(text = serialized, stringsAsFactors = FALSE)
  testthat::expect_identical(restored, fixture)
  testthat::expect_equal(anyDuplicated(restored$document_id), 0L)
})

testthat::test_that("project library and explicit dependency manifest are active", {
  project_library <- normalizePath(renv::paths$library(), winslash = "/")
  test_library <- normalizePath(find.package("testthat"), winslash = "/")
  testthat::expect_true(startsWith(test_library, paste0(project_library, "/")))
  testthat::expect_identical(renv::settings$snapshot.type(), "explicit")
  testthat::expect_false(renv::settings$use.cache())
})
