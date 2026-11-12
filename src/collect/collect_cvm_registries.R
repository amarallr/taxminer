# CVM registries (public, dados.cvm.gov.br, ODbL): fund register (cad_fi.csv),
# fund/class register under CVM Resolution 175 (registro_fundo_classe.zip) and
# listed company register (cad_cia_aberta.csv). Used to name the CNPJs that the
# reports publish without a name (FIDC cedentes). Separate from the report
# collectors: it never touches their manifests or raw files.
#
# Raw files are immutable and content-addressed:
#   <root>/raw/{file stem}/{sha256_12}.{ext},
# root = <TAXMINER_DATA_DIR>/investment_fund_reports/registries
# with an append-only manifest at <root>/manifests/registries.csv. A file whose
# content did not change is recorded without a second copy.
# Polite access: generic user agent, fixed delay between requests, immediate
# stop on 403/429 (never bypassed). Requires src/collect/download_fund_reports.R
# (fund_curl_fetch), src/common/signatures.R and src/common/data_layout.R.

cvm_registry_files <- data.frame(
  file_name = c("cad_fi.csv", "registro_fundo_classe.zip", "cad_cia_aberta.csv"),
  source_url = c("https://dados.cvm.gov.br/dados/FI/CAD/DADOS/cad_fi.csv",
                 "https://dados.cvm.gov.br/dados/FI/CAD/DADOS/registro_fundo_classe.zip",
                 "https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/cad_cia_aberta.csv"),
  stringsAsFactors = FALSE)

cvm_registry_manifest_columns <- c("file_name", "source_url", "outcome", "http_status", "bytes",
                                   "file_sha256", "raw_path", "error", "retrieved_at")

cvm_registry_root <- function(data_dir = resolve_data_dir()) {
  file.path(source_data_root(data_dir, "investment_fund_reports"), "registries")
}

cvm_registry_manifest <- function(root) {
  path <- file.path(root, "manifests", "registries.csv")
  if (!file.exists(path)) {
    return(as.data.frame(setNames(replicate(length(cvm_registry_manifest_columns), character(), simplify = FALSE),
                                  cvm_registry_manifest_columns)))
  }
  utils::read.csv(path, colClasses = "character", na.strings = character(), encoding = "UTF-8")
}

append_cvm_registry_manifest <- function(root, row) {
  path <- file.path(root, "manifests", "registries.csv")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  exists <- file.exists(path)
  utils::write.table(row[cvm_registry_manifest_columns], path, sep = ",", row.names = FALSE,
                     col.names = !exists, append = exists, qmethod = "double", fileEncoding = "UTF-8")
}

# Minimal content check: a zip must open, a csv must have a ';' header.
cvm_registry_valid <- function(path, file_name) {
  if (!file.exists(path) || file.info(path)$size < 100) return(FALSE)
  if (grepl("\\.zip$", file_name)) {
    return(!inherits(try(utils::unzip(path, list = TRUE), silent = TRUE), "try-error"))
  }
  grepl(";", readLines(path, n = 1L, warn = FALSE, encoding = "latin1"))
}

# Downloads each registry once per run. Returns the manifest rows written.
collect_cvm_registries <- function(root = cvm_registry_root(), fetcher = fund_curl_fetch,
                                   user_agent = "TaxMiner-collector/0.1", delay_seconds = 10,
                                   files = cvm_registry_files) {
  dir.create(file.path(root, "raw"), recursive = TRUE, showWarnings = FALSE)
  out <- list()
  for (i in seq_len(nrow(files))) {
    if (i > 1) Sys.sleep(delay_seconds)
    f <- files[i, ]
    stem <- tools::file_path_sans_ext(f$file_name); ext <- tools::file_ext(f$file_name)
    partial <- file.path(root, "raw", paste0(".", f$file_name, ".part"))
    response <- fetcher(f$source_url, partial, user_agent)
    row <- data.frame(file_name = f$file_name, source_url = f$source_url, outcome = "failed",
                      http_status = as.character(response$status), bytes = "", file_sha256 = "", raw_path = "",
                      error = response$error, retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                      stringsAsFactors = FALSE)
    if (response$status %in% c(403L, 429L)) {
      row$outcome <- "refused"; append_cvm_registry_manifest(root, row); unlink(partial)
      stop(sprintf("CVM answered %d for %s: stopping (access is never retried or bypassed).",
                   response$status, f$file_name))
    }
    if (response$status == 200L && cvm_registry_valid(partial, f$file_name)) {
      sha <- compute_signature_hash(partial, file = TRUE)
      rel <- file.path("raw", stem, paste0(substr(sha, 1, 12), ".", ext))
      dest <- file.path(root, rel)
      dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
      if (file.exists(dest)) unlink(partial) else file.rename(partial, dest)
      row$outcome <- "downloaded"; row$bytes <- as.character(file.info(dest)$size)
      row$file_sha256 <- sha; row$raw_path <- rel
    } else {
      if (response$status == 200L) row$outcome <- "invalid_content"
      unlink(partial)
    }
    append_cvm_registry_manifest(root, row)
    out[[i]] <- row
  }
  do.call(rbind, out)
}

# Latest downloaded raw file of each registry (absolute paths, NA if none).
latest_cvm_registry_files <- function(root = cvm_registry_root()) {
  m <- cvm_registry_manifest(root)
  m <- m[m$outcome == "downloaded", , drop = FALSE]
  m <- m[order(m$retrieved_at, decreasing = TRUE), , drop = FALSE]
  k <- match(cvm_registry_files$file_name, m$file_name)
  stats::setNames(ifelse(is.na(k), NA_character_, file.path(root, m$raw_path[k])), cvm_registry_files$file_name)
}
