# Discovery of CVM investment fund report files (investment_fund_reports,
# MVP Phase 1.3, Collect P05 step 01). The CVM open-data portal publishes the
# files in nginx autoindex listings; this module parses those listings into a
# catalog of files with listing timestamp and approximate size. Independent of
# the financial_disclosures and tax_consultation_decisions collectors.
# Base R only; the HTTP fetch is injected so tests run without network.

fund_report_base_url <- "https://dados.cvm.gov.br/dados/"

# Registry mirrored in config/investment_fund_report_sources.yml. `listings`
# are directories relative to the base URL; FIDC keeps older months in HIST/.
fund_report_sources <- data.frame(
  source_id = c("cvm_fii_inf_mensal", "cvm_fii_inf_trimestral", "cvm_fii_inf_anual",
                "cvm_fii_dfin", "cvm_fidc_inf_mensal", "cvm_fip_inf_trimestral",
                "cvm_fip_inf_quadrimestral", "cvm_fiagro_inf_mensal"),
  family = c("fii", "fii", "fii", "fii", "fidc", "fip", "fip", "fiagro"),
  dataset = c("INF_MENSAL", "INF_TRIMESTRAL", "INF_ANUAL", "DFIN", "INF_MENSAL",
              "INF_TRIMESTRAL", "INF_QUADRIMESTRAL", "INF_MENSAL"),
  listings = c("FII/DOC/INF_MENSAL/DADOS/", "FII/DOC/INF_TRIMESTRAL/DADOS/",
               "FII/DOC/INF_ANUAL/DADOS/", "FII/DOC/DFIN/DADOS/",
               "FIDC/DOC/INF_MENSAL/DADOS/;FIDC/DOC/INF_MENSAL/DADOS/HIST/",
               "FIP/DOC/INF_TRIMESTRAL/DADOS/", "FIP/DOC/INF_QUADRIMESTRAL/DADOS/",
               "FIAGRO/DOC/INF_MENSAL/DADOS/"),
  # DFIN indexes FII financial statement documents: outside the first sample.
  first_sample = c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE),
  stringsAsFactors = FALSE)

fund_catalog_columns <- c("source_id", "family", "dataset", "reference_period", "file_name",
                          "source_url", "listing_last_modified", "listing_size",
                          "file_format", "first_sample", "listed_at")

# Listing timestamps look like "24-Oct-2021 22:46" (English month names,
# server time). Parsed without locale dependence; returned as ISO text.
parse_listing_timestamp <- function(x) {
  months <- c(Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8,
              Sep = 9, Oct = 10, Nov = 11, Dec = 12)
  parts <- regmatches(x, regexec("^([0-9]{2})-([A-Za-z]{3})-([0-9]{4}) ([0-9]{2}:[0-9]{2})$", x))
  vapply(parts, function(p) {
    if (length(p) != 5 || is.na(months[p[3]])) return(NA_character_)
    sprintf("%s-%02d-%sT%s", p[4], months[[p[3]]], p[2], p[5])
  }, character(1))
}

# Parse an nginx autoindex page into file rows (directories are skipped).
parse_autoindex <- function(html, listing_url) {
  lines <- unlist(strsplit(paste(html, collapse = "\n"), "\n", fixed = TRUE))
  pattern <- '<a href="([^"/?#]+)">[^<]*</a>\\s+([0-9]{2}-[A-Za-z]{3}-[0-9]{4} [0-9]{2}:[0-9]{2})\\s+(\\S+)'
  hits <- regmatches(lines, regexec(pattern, lines))
  hits <- hits[lengths(hits) == 4]
  if (length(hits) == 0) {
    return(data.frame(file_name = character(), source_url = character(),
                      listing_last_modified = character(), listing_size = character(),
                      stringsAsFactors = FALSE))
  }
  names <- vapply(hits, `[`, character(1), 2)
  data.frame(file_name = utils::URLdecode(names),
             source_url = paste0(listing_url, names),
             listing_last_modified = parse_listing_timestamp(vapply(hits, `[`, character(1), 3)),
             listing_size = vapply(hits, `[`, character(1), 4),
             stringsAsFactors = FALSE)
}

# Reference period from a CVM file name: the trailing yyyy or yyyymm.
fund_reference_period <- function(file_name) {
  period <- sub("^.*_([0-9]{4}|[0-9]{6})\\.[A-Za-z]+$", "\\1", file_name)
  ifelse(grepl("^[0-9]{4}([0-9]{2})?$", period),
         ifelse(nchar(period) == 6, paste0(substr(period, 1, 4), "-", substr(period, 5, 6)), period),
         NA_character_)
}

# Fetch a listing page as text. Returns list(status, text, error).
fetch_listing_curl <- function(url, user_agent = "TaxMiner-collector/0.1", timeout_seconds = 60) {
  out <- tempfile("listing_", fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  args <- c("-sS", "-L", "--max-redirs", "3", "-m", timeout_seconds, "-A", shQuote(user_agent),
            "--max-filesize", "5000000", "-o", shQuote(out), "-w", shQuote("%{http_code}"),
            shQuote(url))
  result <- suppressWarnings(system2("curl", args, stdout = TRUE, stderr = TRUE))
  exit_code <- attr(result, "status")
  status <- suppressWarnings(as.integer(utils::tail(result, 1)))
  if (!is.null(exit_code) && exit_code != 0L) {
    return(list(status = 0L, text = "", error = paste(result, collapse = " ")))
  }
  text <- if (file.exists(out)) readLines(out, warn = FALSE, encoding = "UTF-8") else ""
  list(status = if (is.na(status)) 0L else status, text = text, error = "")
}

# Build the catalog of published files for the given sources. Waits
# `delay_seconds` between listing requests (CVM Crawl-Delay is 10 s) and stops
# immediately on 403/429. Only names matching *_{yyyy|yyyymm}.{zip|csv} count.
discover_fund_reports <- function(sources = fund_report_sources, fetcher = fetch_listing_curl,
                                  delay_seconds = 10, base_url = fund_report_base_url,
                                  log = message) {
  rows <- list()
  failures <- character()
  first <- TRUE
  for (i in seq_len(nrow(sources))) {
    source <- sources[i, , drop = FALSE]
    for (listing in strsplit(source$listings, ";", fixed = TRUE)[[1]]) {
      if (!first) Sys.sleep(delay_seconds)
      first <- FALSE
      url <- paste0(base_url, listing)
      response <- fetcher(url)
      if (response$status %in% c(403L, 429L)) {
        stop(sprintf("Access refused (%d) at %s; stopping without retry.", response$status, url),
             call. = FALSE)
      }
      if (response$status != 200L) {
        failures <- c(failures, sprintf("%s: http %d %s", url, response$status, response$error))
        log(sprintf("Listing failed: %s (%d)", url, response$status))
        next
      }
      files <- parse_autoindex(response$text, url)
      files <- files[grepl("_([0-9]{4}|[0-9]{6})\\.(zip|csv)$", files$file_name, ignore.case = TRUE), ,
                     drop = FALSE]
      log(sprintf("%s %s: %d file(s)", source$source_id, listing, nrow(files)))
      if (nrow(files) == 0) next
      files$source_id <- sprintf("cvm:%s:%s:%s", source$family, tolower(source$dataset),
                                 files$file_name)
      files$family <- source$family
      files$dataset <- source$dataset
      files$reference_period <- fund_reference_period(files$file_name)
      files$file_format <- tolower(sub("^.*\\.", "", files$file_name))
      files$first_sample <- source$first_sample
      files$listed_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
      rows[[length(rows) + 1L]] <- files[, fund_catalog_columns]
    }
  }
  catalog <- if (length(rows) > 0) do.call(rbind, rows) else
    as.data.frame(setNames(replicate(length(fund_catalog_columns), character(), simplify = FALSE),
                           fund_catalog_columns))
  attr(catalog, "listing_failures") <- failures
  catalog
}
