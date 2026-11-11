# Resumable download of CVM investment fund report files (investment_fund_reports,
# MVP Phase 1.3, Collect P05 step 02) with one append-only manifest per
# subfamily. Independent of the financial_disclosures collector.
#
# Raw files are immutable and content-addressed:
#   <root>/raw/{family}/{dataset}/{file stem}/{sha256_12}.{ext}
# where <root> is <TAXMINER_DATA_DIR>/investment_fund_reports (src/common/data_layout.R);
# manifests store raw_path relative to <root>, so the folder can be moved.
# The CVM republishes files under the same name; a new listing timestamp makes
# the file pending again, and different content becomes a new version beside
# the old one. Identical content is recorded without a second copy.
# Polite access: fixed delay between requests (10 s, CVM Crawl-Delay), retry
# with backoff only for timeouts, network errors and 5xx, immediate stop on
# 403/429. Requires src/common/safe_io.R (validate_zip_archive).

fund_manifest_columns <- c("source_id", "family", "dataset", "reference_period", "file_name",
                           "source_url", "listing_last_modified", "listing_size", "outcome",
                           "http_status", "bytes", "file_sha256", "member_count",
                           "member_sha256", "raw_path", "attempts", "error", "retrieved_at")

# `downloaded` and `unavailable` end processing of a listed version; `failed`
# and `invalid_content` are retried on the next run; `refused` stops the run.
fund_terminal_outcomes <- c("downloaded", "unavailable")

fund_curl_fetch <- function(url, output_file, user_agent, timeout_seconds = 900,
                            max_bytes = 2e9) {
  args <- c("-sS", "-L", "--max-redirs", "3", "-m", timeout_seconds,
            "-A", shQuote(user_agent), "--max-filesize", format(max_bytes, scientific = FALSE),
            "-o", shQuote(output_file), "-w", shQuote("%{http_code}"), shQuote(url))
  result <- suppressWarnings(system2("curl", args, stdout = TRUE, stderr = TRUE))
  exit_code <- attr(result, "status")
  status <- suppressWarnings(as.integer(utils::tail(result, 1)))
  if (!is.null(exit_code) && exit_code != 0L) {
    return(list(status = 0L, error = paste(c(sprintf("curl exit %d", exit_code),
                                               utils::head(result, -1)), collapse = " ")))
  }
  list(status = if (is.na(status)) 0L else status, error = "")
}

fund_manifest_path <- function(root, family) {
  file.path(root, "manifests", paste0(family, ".csv"))
}

read_fund_manifest <- function(path) {
  if (!file.exists(path)) {
    return(as.data.frame(setNames(replicate(length(fund_manifest_columns), character(),
                                            simplify = FALSE), fund_manifest_columns)))
  }
  utils::read.csv(path, colClasses = "character", na.strings = character(), encoding = "UTF-8")
}

append_fund_manifest <- function(path, row) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  exists <- file.exists(path)
  utils::write.table(row[fund_manifest_columns], path, sep = ",", row.names = FALSE,
                     col.names = !exists, append = exists, qmethod = "double",
                     fileEncoding = "UTF-8")
}

# Content checks before a file enters the raw store. Returns
# list(ok, error, member_count, member_sha256).
check_fund_file <- function(path, file_format, max_members = 256L, max_bytes = 8 * 1024^3) {
  if (!file.exists(path) || file.size(path) == 0) {
    return(list(ok = FALSE, error = "empty response"))
  }
  head_bytes <- readBin(path, "raw", 512)
  if (identical(file_format, "zip")) {
    if (!identical(head_bytes[1:4], as.raw(c(0x50, 0x4b, 0x03, 0x04)))) {
      text <- rawToChar(head_bytes[head_bytes != as.raw(0)])
      return(list(ok = FALSE, error = paste("non-ZIP response:", substr(gsub("\\s+", " ", text), 1, 120))))
    }
    members <- tryCatch(validate_zip_archive(path, max_members = max_members, max_bytes = max_bytes),
                        error = function(e) e)
    if (inherits(members, "error")) return(list(ok = FALSE, error = conditionMessage(members)))
    return(list(ok = TRUE, error = "", member_count = nrow(members),
                member_sha256 = paste(sprintf("%s=%s", members$name, members$sha256), collapse = ";")))
  }
  # CSV: the published files are ';'-separated with a header line; an HTML page
  # (error or portal page) is rejected.
  first <- rawToChar(head_bytes[head_bytes != as.raw(0)])
  if (grepl("<html|<!doctype", first, ignore.case = TRUE) || !grepl(";", first, fixed = TRUE)) {
    return(list(ok = FALSE, error = "response is not a ';'-separated CSV"))
  }
  list(ok = TRUE, error = "", member_count = 1L,
       member_sha256 = sprintf("%s=%s", basename(path), as.character(tools::sha256sum(path))))
}

fund_raw_dir <- function(root, entry) {
  file.path(root, "raw", entry$family, tolower(entry$dataset),
            sub("\\.[A-Za-z]+$", "", entry$file_name))
}

download_one_fund_file <- function(entry, root, fetcher, user_agent, max_attempts = 3,
                                   backoff_seconds = 30) {
  row <- as.list(setNames(rep("", length(fund_manifest_columns)), fund_manifest_columns))
  for (col in intersect(names(entry), fund_manifest_columns)) row[[col]] <- as.character(entry[[col]])
  target_dir <- fund_raw_dir(root, entry)
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  partial <- tempfile(".download-", tmpdir = target_dir, fileext = ".part")
  on.exit(unlink(partial), add = TRUE)
  attempt <- 0L
  repeat {
    attempt <- attempt + 1L
    unlink(partial)
    response <- fetcher(entry$source_url, partial, user_agent)
    row$http_status <- response$status
    check <- NULL
    if (response$status == 200L) {
      check <- check_fund_file(partial, entry$file_format)
      if (isTRUE(check$ok)) {
        row$outcome <- "downloaded"
        row$error <- ""
        break
      }
      row$outcome <- "invalid_content"
      row$error <- check$error
    } else if (response$status %in% c(403L, 429L)) {
      row$outcome <- "refused"
    } else if (response$status %in% c(404L, 410L)) {
      row$outcome <- "unavailable"
    } else {
      row$outcome <- "failed"
      row$error <- if (nzchar(response$error)) response$error else paste("http", response$status)
    }
    # Truncated transfers and busy pages arrive as HTTP 200 with bad content.
    retryable <- row$outcome %in% c("failed", "invalid_content")
    if (!retryable || attempt >= max_attempts) break
    Sys.sleep(backoff_seconds * 2^(attempt - 1L))
  }
  row$attempts <- attempt
  if (identical(row$outcome, "downloaded")) {
    sha <- as.character(tools::sha256sum(partial))
    target <- file.path(target_dir, sprintf("%s.%s", substr(sha, 1, 12), entry$file_format))
    if (file.exists(target)) {
      if (!identical(as.character(tools::sha256sum(target)), sha)) {
        stop("Raw file differs from its content address: ", target, call. = FALSE)
      }
      row$error <- "unchanged_content"
    } else if (!file.rename(partial, target)) {
      row$outcome <- "failed"
      row$error <- "could not move the download into the raw store"
    }
    if (identical(row$outcome, "downloaded")) {
      row$bytes <- file.size(target)
      row$file_sha256 <- sha
      row$member_count <- check$member_count
      row$member_sha256 <- check$member_sha256
      row$raw_path <- substring(target, nchar(root) + 2L)
    }
  }
  row$retrieved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  # Text columns, as read back from the manifest.
  as.data.frame(lapply(row, as.character), stringsAsFactors = FALSE)
}

# Catalog rows still to fetch: no terminal manifest row for the same URL and
# listing timestamp. `refresh_recent` re-fetches the latest `n` periods of each
# source even when unchanged in the listing (the CVM republishes them).
pending_fund_files <- function(catalog, root, refresh_recent = 0L) {
  done <- do.call(rbind, lapply(unique(catalog$family), function(f) {
    read_fund_manifest(fund_manifest_path(root, f))
  }))
  key <- paste(catalog$source_url, catalog$listing_last_modified)
  done_key <- if (is.null(done) || nrow(done) == 0) character() else
    paste(done$source_url, done$listing_last_modified)[done$outcome %in% fund_terminal_outcomes]
  pending <- !key %in% done_key
  if (refresh_recent > 0) {
    group <- sub(":[^:]*$", "", catalog$source_id)
    rank <- stats::ave(catalog$reference_period, group,
                       FUN = function(p) rank(-xtfrm(p), ties.method = "first"))
    pending <- pending | as.integer(rank) <= refresh_recent
  }
  catalog[pending, , drop = FALSE]
}

# Download the pending files of `catalog` (already filtered by the caller to
# the families, datasets and periods wanted). Returns the rows recorded.
download_fund_reports <- function(catalog, root, fetcher = fund_curl_fetch,
                                  user_agent = "TaxMiner-collector/0.1", delay_seconds = 10,
                                  max_files = Inf, refresh_recent = 0L, backoff_seconds = 30,
                                  log = message) {
  pending <- pending_fund_files(catalog, root, refresh_recent)
  pending <- pending[order(pending$family, pending$dataset, pending$reference_period), , drop = FALSE]
  log(sprintf("Catalog %d, pending %d", nrow(catalog), nrow(pending)))
  recorded <- list()
  for (i in seq_len(min(nrow(pending), max_files))) {
    if (i > 1) Sys.sleep(delay_seconds)
    entry <- pending[i, , drop = FALSE]
    row <- download_one_fund_file(entry, root, fetcher, user_agent,
                                  backoff_seconds = backoff_seconds)
    append_fund_manifest(fund_manifest_path(root, entry$family), row)
    recorded[[length(recorded) + 1L]] <- row
    log(sprintf("[%d/%d] %s %s %s %s", i, nrow(pending), entry$source_id, row$outcome,
                row$http_status, row$error))
    if (identical(row$outcome, "refused")) {
      log("Access refused or rate-limited; stopping without retry.")
      break
    }
  }
  if (length(recorded) == 0) return(read_fund_manifest(tempfile())[0, ])
  do.call(rbind, recorded)
}
