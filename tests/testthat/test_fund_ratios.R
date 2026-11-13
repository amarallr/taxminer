source_project_file <- function(...) source(file.path(testthat::test_path("..", ".."), ...), local = FALSE)
source_project_file("src", "intelligence", "fund_ratios.R")

rules <- data.frame(
  family = "fidc",
  table_name = c("t1", "t1", "t1", "t1", "t2|t1"),
  numerator = c("^TOTAL$", "^ITEM_", "^ITEM_B$", "^PCT_", "^CAP$"),
  denominator_table = c("t0", "t1", "t1", "", "same_row"),
  denominator = c("PL", "TOTAL", "ITEM_A+ITEM_B", "", "sum(^ITEM_)"),
  kind = c("over_pl", "share_of_total", "analytic", "keep", "analytic"),
  label_pt = c("Total / PL", "{item} / Total", "B / (A + B)", "{item}", "Cap / itens"),
  note = "", stringsAsFactors = FALSE)

test_that("the ratio plan takes the first base rule and adds analytic ratios", {
  plan <- fund_ratio_plan(rules, "t1", c("TOTAL", "ITEM_A", "ITEM_B", "PCT_X", "OTHER", "CAP"))
  expect_equal(plan$key, c("r:TOTAL", "r:ITEM_A", "r:ITEM_B", "a:ITEM_B/ITEM_A+ITEM_B", "a:CAP/sum(^ITEM_)"))
  expect_equal(plan$den_table[plan$key == "a:CAP/sum(^ITEM_)"], "t1")
  expect_equal(fund_ratio_tables(plan, "t1"), "t0")
  expect_equal(fund_ratio_label("{item} / Total", "Item A"), "Item A / Total")
  expect_true(fund_ratio_linear("share_of_total"))
  expect_false(fund_ratio_linear("over_pl"))
})

test_that("ratios divide per fund and leave out invalid denominators", {
  plan <- fund_ratio_plan(rules, "t1", c("TOTAL", "ITEM_A", "ITEM_B", "CAP"))
  vals <- list(
    t1 = list(TOTAL = c(f1 = 100, f2 = 50, f3 = 10, f4 = 0),
              ITEM_A = c(f1 = 60, f2 = 50, f4 = 0),
              ITEM_B = c(f1 = 40, f3 = 10),
              CAP = c(f1 = 20, f2 = 5)),
    t0 = list(PL = c(f1 = 200, f2 = -1, f3 = 20)))
  out <- fund_ratio_values(plan, "t1", vals)
  # Total / PL: f2 has negative PL and f4 no PL.
  expect_equal(out$values[["r:TOTAL"]], c(f1 = 0.5, f3 = 0.5))
  expect_equal(out$excluded[["r:TOTAL"]], 2L)
  # Shares of the total add up to 1 (f4 has total 0: left out).
  expect_equal(out$values[["r:ITEM_A"]], c(f1 = 0.6, f2 = 1))
  expect_equal(out$values[["r:ITEM_B"]], c(f1 = 0.4, f3 = 1))
  expect_equal(out$excluded[["r:ITEM_A"]], 1L)
  # Sum of terms: a fund needs at least one of them (missing terms count as zero).
  expect_equal(out$values[["a:ITEM_B/ITEM_A+ITEM_B"]], c(f1 = 0.4, f3 = 1))
  expect_equal(out$values[["a:CAP/sum(^ITEM_)"]], c(f1 = 0.2, f2 = 0.1))
})

test_that("the project rules are valid and serialize for the published panel", {
  r <- fund_ratio_rules(file.path(testthat::test_path("..", ".."), "config", "metric_ratio_rules.csv"))
  expect_true(nrow(r) > 50)
  expect_true(all(r$kind %in% fund_ratio_kinds))
  expect_true(all(nzchar(r$denominator[r$kind != "keep"])))
  for (p in r$numerator) expect_silent(grepl(p, "X", perl = TRUE))
  j <- jsonlite::fromJSON(fund_ratio_rules_json(r), simplifyVector = FALSE)
  expect_equal(length(j), nrow(r))
  expect_equal(j[[1]][[5]], r$kind[1])
})
