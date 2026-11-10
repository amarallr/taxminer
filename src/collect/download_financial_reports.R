# Resumable download of CVM filing packages (RAD/ENET) with an append-only
# manifest. Raw packages are immutable: an existing file is never overwritten.
# Polite access: fixed delay between requests (10 s by default), retry with
# backoff only for timeouts and 5xx, immediate stop on 403/429.

manifest_columns <- c("source_document_id", "report_id", "source_url", "outcome",
                      "http_status", "bytes", "package_sha256", "member_count",
                      "member_sha256", "raw_path", "attempts", "error",
                      "retrieved_at")

# Outcomes that end processing of a package. `failed` (network errors, busy
# service, truncated or non-ZIP responses after all attempts) is retried on the
# next run; `refused` stops the run.
terminal_outcomes <- c("downloaded", "unavailable")

curl_fetch <- function(url, output_file, user_agent, timeout_seconds = 300,
                       max_bytes = 200e6) {
  args <- c("-sS", "-L", "--max-redirs", "3", "-m", timeout_seconds,
            "-A", shQuote(user_agent),
            "--max-filesize", format(max_bytes, scientific = FALSE),
            "-o", shQuote(output_file), "-w", shQuote("%{http_code}"), shQuote(url))
  result <- suppressWarnings(system2("curl", args, stdout = TRUE, stderr = TRUE))
  exit_code <- attr(result, "status")
  status <- suppressWarnings(as.integer(utils::tail(result, 1)))
  if (is.na(status)) status <- 0L
  # A transfer cut mid-way (e.g. connection reset) still reports HTTP 200.
  if (!is.null(exit_code) && exit_code != 0L) {
    return(list(status = 0L, error = paste(c(sprintf("curl exit %d", exit_code),
                                                utils::head(result, -1)), collapse = " ")))
  }
  list(status = status, error = "")
}

# A complete package: ZIP signature and a readable central directory.
is_valid_package <- function(path) {
  is_zip_file(path) &&
    !inherits(tryCatch(utils::unzip(path, list = TRUE), error = function(e) e), "error")
}

is_zip_file <- function(path) {
  if (!file.exists(path) || file.size(path) < 4) return(FALSE)
  identical(readBin(path, "raw", 4), as.raw(c(0x50, 0x4b, 0x03, 0x04)))
}

# SHA-256 of each member: the package ZIP changes on every download (a
# generated PDF name carries a timestamp) while the members do not.
member_checksums <- function(zip_path) {
  listing <- utils::unzip(zip_path, list = TRUE)
  work_dir <- tempfile("members_")
  dir.create(work_dir)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)
  utils::unzip(zip_path, exdir = work_dir, junkpaths = TRUE)
  files <- file.path(work_dir, basename(listing$Name))
  sums <- vapply(files, function(f) {
    if (file.exists(f)) as.character(tools::sha256sum(f)) else NA_character_
  }, character(1))
  paste(sprintf("%s=%s", basename(listing$Name), sums), collapse = ";")
}

read_manifest <- function(manifest_path) {
  if (!file.exists(manifest_path)) {
    return(as.data.frame(setNames(replicate(length(manifest_columns), character(),
                                            simplify = FALSE), manifest_columns)))
  }
  utils::read.csv(manifest_path, colClasses = "character", encoding = "UTF-8")
}

append_manifest <- function(manifest_path, row) {
  row <- row[manifest_columns]
  exists <- file.exists(manifest_path)
  utils::write.table(row, manifest_path, sep = ",", row.names = FALSE,
                     col.names = !exists, append = exists, qmethod = "double",
                     fileEncoding = "UTF-8")
}

raw_package_path <- function(raw_dir, report) {
  file.path(raw_dir, tolower(report$report_type),
            substr(report$reporting_period_end, 1, 4),
            sprintf("%s.zip", report$source_document_id))
}

download_one_report <- function(report, raw_dir, fetcher, user_agent,
                                max_attempts = 3, backoff_seconds = 30) {
  row <- as.list(setNames(rep("", length(manifest_columns)), manifest_columns))
  row$source_document_id <- report$source_document_id
  row$report_id <- report$report_id
  row$source_url <- report$source_url
  target <- raw_package_path(raw_dir, report)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(target) && !is_valid_package(target)) {
    # Never keep an unreadable package in the raw store: quarantine and refetch.
    quarantine <- file.path(dirname(raw_dir), "quarantine")
    dir.create(quarantine, recursive = TRUE, showWarnings = FALSE)
    file.rename(target, file.path(quarantine, sprintf("%s_%s.zip", report$source_document_id,
                                                      format(Sys.time(), "%Y%m%dT%H%M%S"))))
  }
  if (file.exists(target)) {
    # Immutable original already present (e.g. manifest lost): record, don't refetch.
    row$outcome <- "downloaded"
    row$error <- "already_present"
  } else {
    partial <- paste0(target, ".part")
    attempt <- 0L
    repeat {
      attempt <- attempt + 1L
      unlink(partial)
      response <- fetcher(report$source_url, partial, user_agent)
      row$http_status <- response$status
      if (response$status == 200L && is_valid_package(partial)) {
        row$outcome <- "downloaded"
        row$error <- ""
        break
      }
      if (response$status %in% c(403L, 429L)) {
        row$outcome <- "refused"
      } else if (response$status %in% c(404L, 410L)) {
        row$outcome <- "unavailable"
      } else if (response$status == 200L) {
        # The source answers "service unavailable/busy" with HTTP 200 and a
        # short text body, and sometimes cuts packages short.
        row$outcome <- "failed"
        row$error <- if (is_zip_file(partial)) "truncated or corrupted ZIP" else
          paste("non-ZIP response:", substr(paste(readLines(partial, n = 2, warn = FALSE),
                                                  collapse = " "), 1, 160))
      } else {
        row$outcome <- "failed"
        row$error <- if (nzchar(response$error)) response$error else
          paste("http", response$status)
      }
      retryable <- identical(row$outcome, "failed")
      if (!retryable || attempt >= max_attempts) break
      Sys.sleep(backoff_seconds * 2^(attempt - 1L))
    }
    row$attempts <- attempt
    if (identical(row$outcome, "downloaded")) file.rename(partial, target)
    unlink(partial)
  }
  if (identical(row$outcome, "downloaded")) {
    checks <- tryCatch(list(
      package = as.character(tools::sha256sum(target)),
      count = nrow(utils::unzip(target, list = TRUE)),
      members = member_checksums(target)
    ), error = function(e) e)
    if (inherits(checks, "error")) {
      # Only a pre-existing file can reach here; keep it but flag it for review.
      row$outcome <- "failed"
      row$error <- paste("stored package unreadable:", conditionMessage(checks))
    } else {
      row$bytes <- file.size(target)
      row$package_sha256 <- checks$package
      row$member_count <- checks$count
      row$member_sha256 <- checks$members
      row$raw_path <- target
    }
  }
  row$retrieved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  as.data.frame(row, stringsAsFactors = FALSE)
}

# Download every catalog row that has no terminal outcome yet. Returns the
# rows recorded in this run. Stops early on 403/429 or when `max_reports` or
# `min_free_gb` is reached.
download_financial_reports <- function(catalog, raw_dir, manifest_path,
                                       fetcher = curl_fetch,
                                       user_agent = "TaxMiner-collector/0.1",
                                       delay_seconds = 10, max_reports = Inf,
                                       min_free_gb = 20, free_gb = NULL,
                                       backoff_seconds = 30, log = message) {
  done <- read_manifest(manifest_path)
  done_ids <- done$source_document_id[done$outcome %in% terminal_outcomes]
  pending <- catalog[!catalog$source_document_id %in% done_ids, , drop = FALSE]
  log(sprintf("Catalog %d, already terminal %d, pending %d", nrow(catalog),
              length(unique(done_ids)), nrow(pending)))
  recorded <- list()
  for (i in seq_len(min(nrow(pending), max_reports))) {
    if (!is.null(free_gb) && free_gb() < min_free_gb) {
      log("Free disk space below threshold; stopping.")
      break
    }
    if (i > 1) Sys.sleep(delay_seconds)
    row <- download_one_report(pending[i, ], raw_dir, fetcher, user_agent,
                               backoff_seconds = backoff_seconds)
    append_manifest(manifest_path, row)
    recorded[[length(recorded) + 1]] <- row
    log(sprintf("[%d/%d] %s %s %s", i, nrow(pending), row$source_document_id,
                row$outcome, row$http_status))
    if (identical(row$outcome, "refused")) {
      log("Access refused or rate-limited; stopping without retry.")
      break
    }
  }
  if (length(recorded) == 0) return(read_manifest(tempfile())[0, ])
  do.call(rbind, recorded)
}
