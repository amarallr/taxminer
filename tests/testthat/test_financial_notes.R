# Data P03 (Phase 1.2) tests for note segmentation with synthetic text only;
# no network and no real filing. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_financial_notes.R')"

source(testthat::test_path("..", "..", "src", "data", "extract_financial_notes.R"))

fixture_package <- testthat::test_path("..", "fixtures", "synthetic_filing_package.zip")

# Synthetic body text long enough (>= 300 characters) to count as a note.
filler <- function(label, n = 10L) {
  paste(rep(sprintf("Texto sintético da nota %s, sem dados reais.", label), n), collapse = " ")
}

# One page per heading: "{number}. {TITLE}" followed by filler text.
synthetic_pages <- function(numbers, titles = sprintf("TITULO SINTETICO %s", numbers)) {
  vapply(seq_along(numbers), function(i) {
    paste0(numbers[i], ". ", titles[i], "\n", filler(numbers[i]))
  }, character(1))
}

segment_pages <- function(pages) {
  select_note_sets(find_heading_candidates(pages), pages)
}

test_that("headings are found and sub-items, TOC lines and prose are excluded", {
  page <- paste(
    "1. CONTEXTO OPERACIONAL",
    "2.1 Base de preparação",
    "3. CAIXA E EQUIVALENTES ........................ 14",
    "4    ESTOQUES                                   22",
    "5 em milhares de reais, conforme abaixo",
    "Nota 6 - Imobilizado",
    "7) Intangível",
    sep = "\n")
  cand <- find_heading_candidates(page)
  expect_equal(cand$number, c(1L, 6L, 7L))
  expect_equal(cand$title, c("CONTEXTO OPERACIONAL", "Imobilizado", "Intangível"))
})

test_that("a complete numbered sequence becomes one note set", {
  pages <- synthetic_pages(1:6)
  sets <- segment_pages(pages)
  expect_equal(sets$number, 1:6)
  expect_true(all(sets$note_set == 1L))
  expect_true(all(sets$end_position > sets$position))
})

test_that("a short table of contents does not form a note set", {
  toc <- paste(sprintf("%d. TITULO SINTETICO %d", 1:6, 1:6), collapse = "\n")
  sets <- segment_pages(toc)
  expect_equal(nrow(sets), 0L)
})

test_that("individual and consolidated sets are split at the restart", {
  pages <- c(synthetic_pages(1:5), synthetic_pages(1:6))
  sets <- segment_pages(pages)
  expect_equal(as.vector(table(sets$note_set)), c(5L, 6L))
  expect_equal(sets$number[sets$note_set == 2L], 1:6)
})

test_that("a numbered list inside a note does not cut the surrounding set", {
  # Regression (2026-11-10): an inner list "1 ... 2 ..." in mixed case inside an
  # upper-case set used to look like a restart and left no valid set.
  pages <- synthetic_pages(1:7)
  pages[2] <- paste0(pages[2], "\n1. Primeiro item da lista\ncurto\n2. Segundo item da lista\ncurto")
  sets <- segment_pages(pages)
  expect_equal(sets$number, 1:7)
  expect_true(all(sets$note_set == 1L))
})

test_that("a jump caused by a table row is skipped when the expected number follows", {
  pages <- synthetic_pages(1:6)
  pages[3] <- paste0(pages[3], "\n10. LINHA DE TABELA SINTETICA")
  sets <- segment_pages(pages)
  expect_equal(sets$number, 1:6)
})

test_that("parenthesized numbering is read only by the fallback pattern", {
  pages <- vapply(1:6, function(i) {
    paste0("(", i, ") TITULO SINTETICO ", i, "\n", filler(i))
  }, character(1))
  expect_equal(nrow(segment_pages(pages)), 0L)
  cand <- find_heading_candidates(pages, heading_pattern_parenthesized)
  sets <- select_note_sets(cand, pages)
  expect_equal(sets$number, 1:6)
})

test_that("monetary scale statements are classified", {
  expect_equal(detect_unit_scale("Valores em milhares de reais"), "thousands")
  expect_equal(detect_unit_scale("(Em milhões de reais)"), "millions")
  expect_equal(detect_unit_scale("Valores expressos em reais"), "units")
  expect_true(is.na(detect_unit_scale("Sem indicação de escala")))
})

test_that("PDF attachments are decoded from a synthetic recent-layout package", {
  skip_if_not_installed("xml2")
  skip_if_not_installed("base64enc")
  result <- read_package_attachments(fixture_package)
  expect_equal(result$layout, "recent_xml")
  expect_equal(nrow(result$attachments), 1L)
  expect_equal(result$attachments$file_name, "Demonstracoes sinteticas.pdf")
  expect_equal(rawToChar(result$attachments$bytes[[1]][1:5]), "%PDF-")
  expect_equal(result$metadata$company_cnpj_xml, "12345678000100")
})
