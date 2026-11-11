# Collect P05 (Phase 1.3) tests for discovery and download of CVM investment
# fund report files. Synthetic listings, ZIPs and CSVs in temporary
# directories; fetchers are injected; no network. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_fund_reports_collection.R')"

source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "collect", "discover_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "collect", "download_fund_reports.R"))
source(testthat::test_path("helper_stored_zip.R"))

autoindex <- function(rows) {
  c("<html><head><title>Index of /dados/X/</title></head><body>",
    '<pre><a href="../">../</a>',
    '<a href="HIST/">HIST/</a>                                              07-Nov-2026 15:38       -',
    sprintf('<a href="%s">%s</a>                            %s    %s', rows$name, rows$name,
            rows$stamp, rows$size),
    "</pre></body></html>")
}

test_that("autoindex listings become file rows with ISO timestamps", {
  html <- autoindex(data.frame(name = c("inf_mensal_fii_2016.zip", "inf_mensal_fidc_202610.zip"),
                               stamp = c("24-Oct-2021 22:46", "07-Nov-2026 11:33"),
                               size = c("57K", "3M")))
  files <- parse_autoindex(html, "https://example.invalid/dados/X/")
  expect_equal(files$file_name, c("inf_mensal_fii_2016.zip", "inf_mensal_fidc_202610.zip"))
  expect_equal(files$listing_last_modified, c("2021-10-24T22:46", "2026-11-07T11:33"))
  expect_equal(files$source_url[2], "https://example.invalid/dados/X/inf_mensal_fidc_202610.zip")
  expect_equal(files$listing_size, c("57K", "3M"))
  expect_equal(nrow(parse_autoindex("<html>no files</html>", "u")), 0L)
  expect_equal(fund_reference_period(c("inf_mensal_fidc_202610.zip", "inf_trimestral_fip_2023.csv",
                                       "meta_dfin_fii.txt")), c("2026-10", "2023", NA))
})

test_that("discovery covers every listing, keeps failures and stops on 403/429", {
  sources <- fund_report_sources[fund_report_sources$family %in% c("fidc", "fip"), ]
  calls <- character()
  fetcher <- function(url) {
    calls <<- c(calls, url)
    if (grepl("INF_QUADRIMESTRAL", url)) return(list(status = 500L, text = "", error = "busy"))
    name <- if (grepl("HIST", url)) "inf_mensal_fidc_2024.zip" else
      if (grepl("FIDC", url)) "inf_mensal_fidc_202610.zip" else "inf_trimestral_fip_2023.csv"
    list(status = 200L, text = autoindex(data.frame(name = c(name, "leiame.txt"),
                                                    stamp = "07-Nov-2026 11:33", size = "3M")),
         error = "")
  }
  catalog <- discover_fund_reports(sources, fetcher, delay_seconds = 0, log = function(...) NULL)
  expect_length(calls, 4L)
  expect_equal(sort(catalog$source_id),
               c("cvm:fidc:inf_mensal:inf_mensal_fidc_2024.zip",
                 "cvm:fidc:inf_mensal:inf_mensal_fidc_202610.zip",
                 "cvm:fip:inf_trimestral:inf_trimestral_fip_2023.csv"))
  expect_match(attr(catalog, "listing_failures"), "INF_QUADRIMESTRAL.*500")
  refused <- function(url) list(status = 429L, text = "", error = "")
  expect_error(discover_fund_reports(sources, refused, delay_seconds = 0, log = function(...) NULL),
               "refused \\(429\\)")
})

# Catalog of synthetic entries and a fetcher serving bytes from a list.
fund_entry <- function(name, stamp = "2026-11-07T11:33", family = "fidc", dataset = "INF_MENSAL") {
  data.frame(source_id = sprintf("cvm:%s:%s:%s", family, tolower(dataset), name), family = family,
             dataset = dataset, reference_period = fund_reference_period(name), file_name = name,
             source_url = paste0("https://example.invalid/", name), listing_last_modified = stamp,
             listing_size = "1K", file_format = sub("^.*\\.", "", name), first_sample = TRUE,
             listed_at = "2026-11-11T03:00:00-0300", stringsAsFactors = FALSE)
}

serving <- function(files, status = list(), calls = new.env()) {
  calls$urls <- character()
  function(url, output_file, user_agent) {
    calls$urls <- c(calls$urls, url)
    name <- basename(url)
    if (!is.null(status[[name]])) return(list(status = status[[name]], error = ""))
    content <- files[[name]]
    if (is.character(content) && file.exists(content[1])) file.copy(content, output_file) else
      writeBin(content, output_file)
    list(status = 200L, error = "")
  }
}

zip_bytes <- function(members) {
  path <- write_stored_zip(tempfile(fileext = ".zip"), members)
  readBin(path, "raw", file.size(path))
}

quiet <- function(...) NULL

test_that("ZIP and CSV files are stored by content with per-member hashes", {
  dir <- tempfile("fund_data_")
  catalog <- rbind(fund_entry("inf_mensal_fidc_202610.zip"),
                   fund_entry("inf_trimestral_fip_2023.csv", family = "fip", dataset = "INF_TRIMESTRAL"))
  files <- list("inf_mensal_fidc_202610.zip" = zip_bytes(list(
                  "inf_mensal_fidc_tab_I_202610.csv" = "CNPJ_FUNDO_CLASSE;DT_COMPTC\n1;2026-10-31\n")),
                "inf_trimestral_fip_2023.csv" = charToRaw("CNPJ_FUNDO;DT_COMPTC\n1;2023-12-31\n"))
  rows <- download_fund_reports(catalog, dir, serving(files), delay_seconds = 0, log = quiet)
  expect_equal(rows$outcome, c("downloaded", "downloaded"))
  expect_true(all(file.exists(file.path(dir, rows$raw_path))))
  expect_match(rows$raw_path[1], "^raw/fidc/inf_mensal/inf_mensal_fidc_202610/[0-9a-f]{12}\\.zip$")
  expect_match(rows$member_sha256[1], "^inf_mensal_fidc_tab_I_202610.csv=[0-9a-f]{64}$")
  expect_equal(rows$member_count, c("1", "1"))
  expect_true(file.exists(fund_manifest_path(dir, "fidc")))
  expect_true(file.exists(fund_manifest_path(dir, "fip")))
})

test_that("reruns skip unchanged listings; republished files become new versions", {
  dir <- tempfile("fund_data_")
  name <- "inf_mensal_fidc_202610.zip"
  v1 <- zip_bytes(list("a.csv" = "CNPJ_FUNDO_CLASSE;DT_COMPTC\n1;2026-10-31\n"))
  download_fund_reports(fund_entry(name), dir, serving(setNames(list(v1), name)),
                        delay_seconds = 0, log = quiet)
  calls <- new.env()
  again <- download_fund_reports(fund_entry(name), dir, serving(setNames(list(v1), name), calls = calls),
                                 delay_seconds = 0, log = quiet)
  expect_equal(nrow(again), 0L)
  expect_length(calls$urls, 0L)
  same <- download_fund_reports(fund_entry(name, stamp = "2026-11-08T09:00"), dir,
                                serving(setNames(list(v1), name)), delay_seconds = 0, log = quiet)
  expect_equal(same$error, "unchanged_content")
  v2 <- zip_bytes(list("a.csv" = "CNPJ_FUNDO_CLASSE;DT_COMPTC\n2;2026-10-31\n"))
  newer <- download_fund_reports(fund_entry(name, stamp = "2026-11-09T09:00"), dir,
                                 serving(setNames(list(v2), name)), delay_seconds = 0, log = quiet)
  expect_equal(newer$outcome, "downloaded")
  versions <- list.files(dirname(file.path(dir, newer$raw_path)), pattern = "\\.zip$")
  expect_length(versions, 2L)
  expect_equal(nrow(read_fund_manifest(fund_manifest_path(dir, "fidc"))), 3L)
})

test_that("refresh_recent re-fetches only the latest period of each dataset", {
  dir <- tempfile("fund_data_")
  catalog <- rbind(fund_entry("inf_mensal_fidc_202609.zip"), fund_entry("inf_mensal_fidc_202610.zip"))
  bytes <- zip_bytes(list("a.csv" = "X;Y\n1;2\n"))
  files <- list("inf_mensal_fidc_202609.zip" = bytes, "inf_mensal_fidc_202610.zip" = bytes)
  download_fund_reports(catalog, dir, serving(files), delay_seconds = 0, log = quiet)
  calls <- new.env()
  download_fund_reports(catalog, dir, serving(files, calls = calls), delay_seconds = 0,
                        refresh_recent = 1L, log = quiet)
  expect_equal(basename(calls$urls), "inf_mensal_fidc_202610.zip")
})

test_that("bad content is rejected and retried; unsafe ZIPs never reach the raw store", {
  dir <- tempfile("fund_data_")
  good <- zip_bytes(list("a.csv" = "X;Y\n1;2\n"))
  files <- list("inf_mensal_fidc_202608.zip" = good[1:40],
                "inf_mensal_fidc_202609.zip" = zip_bytes(list("../evil.csv" = "X;Y\n")),
                "inf_mensal_fidc_202610.zip" = charToRaw("<html>Servico indisponivel</html>"),
                "inf_trimestral_fip_2023.csv" = charToRaw("<!DOCTYPE html><html></html>"))
  catalog <- rbind(fund_entry("inf_mensal_fidc_202608.zip"), fund_entry("inf_mensal_fidc_202609.zip"),
                   fund_entry("inf_mensal_fidc_202610.zip"),
                   fund_entry("inf_trimestral_fip_2023.csv", family = "fip", dataset = "INF_TRIMESTRAL"))
  calls <- new.env()
  rows <- download_fund_reports(catalog, dir, serving(files, calls = calls), delay_seconds = 0,
                                backoff_seconds = 0, log = quiet)
  expect_equal(rows$outcome, rep("invalid_content", 4))
  expect_equal(rows$attempts, rep("3", 4))
  expect_match(rows$error[2], "Unsafe")
  expect_match(rows$error[3], "non-ZIP")
  expect_length(calls$urls, 12L)
  stored <- list.files(file.path(dir, "raw"), recursive = TRUE)
  expect_length(stored, 0L)
  expect_equal(nrow(pending_fund_files(catalog, dir)), 4L)
})

test_that("404 is terminal and 403/429 stop the run immediately", {
  dir <- tempfile("fund_data_")
  catalog <- rbind(fund_entry("inf_mensal_fidc_202608.zip"), fund_entry("inf_mensal_fidc_202609.zip"),
                   fund_entry("inf_mensal_fidc_202610.zip"))
  bytes <- zip_bytes(list("a.csv" = "X;Y\n1;2\n"))
  fetcher <- serving(list("inf_mensal_fidc_202610.zip" = bytes),
                     status = list("inf_mensal_fidc_202608.zip" = 404L,
                                   "inf_mensal_fidc_202609.zip" = 429L))
  rows <- download_fund_reports(catalog, dir, fetcher, delay_seconds = 0, log = quiet)
  expect_equal(rows$outcome, c("unavailable", "refused"))
  expect_equal(rows$attempts, c("1", "1"))
  expect_equal(basename(pending_fund_files(catalog, dir)$source_url),
               c("inf_mensal_fidc_202609.zip", "inf_mensal_fidc_202610.zip"))
})
