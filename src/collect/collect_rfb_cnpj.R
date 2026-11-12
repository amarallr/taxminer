# Receita Federal CNPJ open data (Dados Abertos do CNPJ, public), used only to
# name CNPJs that the CVM reports publish without a name (FIDC cedentes). Only
# the "Empresas" files are collected: one line per company (CNPJ root, the
# first 8 digits) with its corporate name (razão social), legal nature and
# size. Official distribution: the public share of arquivos.receitafederal.gov.br
# (folder Dados/Cadastros/CNPJ/{yyyy-mm}/), read through its public WebDAV
# address with the share token as user name and no password, as the share
# itself offers; nothing is bypassed.
#
# Raw files are kept as published: <root>/raw/rfb_cnpj/{yyyy-mm}/EmpresasN.zip,
# root = <TAXMINER_DATA_DIR>/investment_fund_reports/registries (same root as
# src/collect/collect_cvm_registries.R), with an append-only manifest at
# <root>/manifests/rfb_cnpj.csv. A file already downloaded for the month is not
# requested again. Polite access: generic user agent, one file at a time,
# fixed delay, immediate stop on 401/403/429.

rfb_cnpj_share <- list(host = "https://arquivos.receitafederal.gov.br", token = "gn672Ad4CF8N6TK",
                       folder = "Dados/Cadastros/CNPJ")

rfb_cnpj_url <- function(path) {
  sprintf("%s/public.php/webdav/%s/%s", rfb_cnpj_share$host, rfb_cnpj_share$folder, path)
}

# curl with the public share token; returns list(status, error).
rfb_curl <- function(url, output_file, user_agent, method = "GET", timeout_seconds = 3600) {
  args <- c("-sS", "-m", timeout_seconds, "-A", shQuote(user_agent), "-u", shQuote(paste0(rfb_cnpj_share$token, ":")),
            if (method != "GET") c("-X", method, "-H", shQuote("Depth: 1")),
            "-o", shQuote(output_file), "-w", shQuote("%{http_code}"), shQuote(url))
  result <- suppressWarnings(system2("curl", args, stdout = TRUE, stderr = TRUE))
  exit_code <- attr(result, "status")
  status <- suppressWarnings(as.integer(utils::tail(result, 1)))
  if (!is.null(exit_code) && exit_code != 0L) {
    return(list(status = 0L, error = paste(c(sprintf("curl exit %d", exit_code), utils::head(result, -1)), collapse = " ")))
  }
  list(status = if (is.na(status)) 0L else status, error = "")
}

rfb_refused <- function(status) status %in% c(401L, 403L, 429L)

# Months published (yyyy-mm folders), most recent last.
rfb_cnpj_months <- function(user_agent = "TaxMiner-collector/0.1") {
  out <- tempfile(fileext = ".xml"); on.exit(unlink(out))
  r <- rfb_curl(rfb_cnpj_url(""), out, user_agent, method = "PROPFIND", timeout_seconds = 120)
  if (rfb_refused(r$status)) stop(sprintf("Receita Federal answered %d: stopping.", r$status))
  if (r$status != 207L) stop(sprintf("Could not list the CNPJ folder (HTTP %d) %s", r$status, r$error))
  x <- paste(readLines(out, warn = FALSE), collapse = "")
  sort(unique(regmatches(x, gregexpr("(?<=/CNPJ/)[0-9]{4}-[0-9]{2}(?=/)", x, perl = TRUE))[[1]]))
}

rfb_manifest_columns <- c("month", "file_name", "source_url", "outcome", "http_status", "bytes",
                          "file_sha256", "raw_path", "error", "retrieved_at")

read_rfb_manifest <- function(root) {
  path <- file.path(root, "manifests", "rfb_cnpj.csv")
  if (!file.exists(path)) {
    return(as.data.frame(setNames(replicate(length(rfb_manifest_columns), character(), simplify = FALSE),
                                  rfb_manifest_columns)))
  }
  utils::read.csv(path, colClasses = "character", na.strings = character(), encoding = "UTF-8")
}

append_rfb_manifest <- function(root, row) {
  path <- file.path(root, "manifests", "rfb_cnpj.csv")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  exists <- file.exists(path)
  utils::write.table(row[rfb_manifest_columns], path, sep = ",", row.names = FALSE, col.names = !exists,
                     append = exists, qmethod = "double", fileEncoding = "UTF-8")
}

# Downloads Empresas0..9.zip of `month` (default: the most recent folder).
collect_rfb_companies <- function(root, month = NULL, user_agent = "TaxMiner-collector/0.1",
                                  delay_seconds = 10, files = sprintf("Empresas%d.zip", 0:9)) {
  if (is.null(month)) month <- utils::tail(rfb_cnpj_months(user_agent), 1)
  done <- read_rfb_manifest(root)
  done <- done$file_name[done$month == month & done$outcome == "downloaded"]
  dir <- file.path(root, "raw", "rfb_cnpj", month)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  for (i in seq_along(files)) {
    f <- files[i]
    if (f %in% done) { message(f, ": already downloaded"); next }
    Sys.sleep(delay_seconds)
    url <- rfb_cnpj_url(paste0(month, "/", f))
    partial <- file.path(dir, paste0(".", f, ".part"))
    r <- rfb_curl(url, partial, user_agent)
    row <- data.frame(month = month, file_name = f, source_url = url, outcome = "failed",
                      http_status = as.character(r$status), bytes = "", file_sha256 = "", raw_path = "",
                      error = r$error, retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                      stringsAsFactors = FALSE)
    if (rfb_refused(r$status)) {
      row$outcome <- "refused"; append_rfb_manifest(root, row); unlink(partial)
      stop(sprintf("Receita Federal answered %d for %s: stopping (never retried or bypassed).", r$status, f))
    }
    ok <- r$status == 200L && file.exists(partial) &&
      !inherits(try(utils::unzip(partial, list = TRUE), silent = TRUE), "try-error")
    if (ok) {
      dest <- file.path(dir, f)
      file.rename(partial, dest)
      row$outcome <- "downloaded"; row$bytes <- as.character(file.info(dest)$size)
      row$file_sha256 <- compute_signature_hash(dest, file = TRUE)
      row$raw_path <- file.path("raw", "rfb_cnpj", month, f)
    } else {
      if (r$status == 200L) row$outcome <- "invalid_content"
      unlink(partial)
    }
    append_rfb_manifest(root, row)
    message(sprintf("%s: %s (HTTP %d, %s bytes)", f, row$outcome, r$status, row$bytes))
  }
  invisible(month)
}
