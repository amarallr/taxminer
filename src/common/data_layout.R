# Local data layout: one folder per source family under TAXMINER_DATA_DIR
# (outside the repository and OneDrive). Base R only.
#
#   <TAXMINER_DATA_DIR>/
#     tax_consultation_decisions/   Phase 1.1
#     financial_disclosures/        Phase 1.2: catalog.csv, manifest.csv, index/,
#                                   raw/, quarantine/, processed/, logs/
#     investment_fund_reports/      Phase 1.3: catalog.csv, manifests/, meta/,
#                                   raw/, processed/, logs/
#
# The DFP collection started before this layout and keeps its files directly
# under TAXMINER_DATA_DIR until scripts/organize_data_dir.R migrates them; while
# that legacy manifest exists, the financial_disclosures inputs resolve there.

source_families <- c("tax_consultation_decisions", "financial_disclosures",
                     "investment_fund_reports")

source_data_root <- function(data_dir, family) {
  family <- match.arg(family, source_families)
  root <- file.path(data_dir, family)
  legacy <- identical(family, "financial_disclosures") &&
    !file.exists(file.path(root, "manifest.csv")) &&
    file.exists(file.path(data_dir, "manifest.csv"))
  if (legacy) data_dir else root
}

# Resolve TAXMINER_DATA_DIR for entry scripts: required, existing, outside OneDrive.
resolve_data_dir <- function(value = Sys.getenv("TAXMINER_DATA_DIR"), must_work = TRUE) {
  if (!nzchar(value)) stop("Set TAXMINER_DATA_DIR to a local folder outside OneDrive.", call. = FALSE)
  value <- normalizePath(value, winslash = "/", mustWork = must_work)
  if (grepl("onedrive", value, ignore.case = TRUE)) {
    stop("TAXMINER_DATA_DIR is inside OneDrive; choose a local folder outside it.", call. = FALSE)
  }
  value
}

# Move a file or directory, creating the destination parent. Refuses to
# overwrite an existing destination. Returns TRUE when something moved.
move_into_layout <- function(from, to) {
  if (!file.exists(from)) return(FALSE)
  if (file.exists(to)) stop("Destination already exists: ", to, call. = FALSE)
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  if (!file.rename(from, to)) stop("Could not move ", from, " to ", to, call. = FALSE)
  TRUE
}

# Rewrite the raw_path column of a CSV manifest, replacing the `old` prefix by
# `new`, through a validated atomic write. Returns the number of rows changed.
rewrite_manifest_prefix <- function(path, old, new) {
  if (!file.exists(path)) return(0L)
  manifest <- utils::read.csv(path, colClasses = "character", na.strings = character(),
                              encoding = "UTF-8", check.names = FALSE)
  hit <- startsWith(manifest$raw_path, old)
  if (!any(hit)) return(0L)
  manifest$raw_path[hit] <- paste0(new, substring(manifest$raw_path[hit], nchar(old) + 1L))
  write_validated_atomic(manifest, path, "csv",
                         validator = function(x) nrow(x) == nrow(manifest))
  sum(hit)
}

# Move the files written before the per-family layout into it:
# - investment fund raw files and manifest paths (relative to the family root);
# - the Parquet output and log of the notes extraction;
# - with `include_dfp`, the legacy DFP collection (catalog, manifest, index,
#   raw packages, quarantine, logs), rewriting the manifest raw paths. This part
#   refuses to run while `collection_active` is TRUE.
# Never deletes data; leaves empty legacy folders removed. Returns a log.
organize_data_dir <- function(data_dir, include_dfp = FALSE, collection_active = TRUE) {
  data_dir <- normalizePath(data_dir, winslash = "/", mustWork = TRUE)
  log <- character()
  note <- function(...) log <<- c(log, sprintf(...))
  funds <- file.path(data_dir, "investment_fund_reports")
  legacy_fund_raw <- file.path(data_dir, "raw", "investment_fund_reports")
  for (family in list.files(legacy_fund_raw)) {
    move_into_layout(file.path(legacy_fund_raw, family), file.path(funds, "raw", family))
    note("moved raw/investment_fund_reports/%s -> investment_fund_reports/raw/%s", family, family)
  }
  for (manifest in list.files(file.path(funds, "manifests"), pattern = "\\.csv$", full.names = TRUE)) {
    changed <- rewrite_manifest_prefix(manifest, paste0(legacy_fund_raw, "/"), "raw/")
    if (changed > 0) note("relative raw_path in %s: %d row(s)", basename(manifest), changed)
  }
  disclosures <- file.path(data_dir, "financial_disclosures")
  if (move_into_layout(file.path(data_dir, "processed", "financial_disclosures"),
                       file.path(disclosures, "processed"))) {
    note("moved processed/financial_disclosures -> financial_disclosures/processed")
  }
  if (move_into_layout(file.path(data_dir, "extract_financial_notes.log"),
                       file.path(disclosures, "logs", "extract_financial_notes.log"))) {
    note("moved extract_financial_notes.log -> financial_disclosures/logs/")
  }
  if (include_dfp) {
    if (!identical(collection_active, FALSE)) {
      stop("The DFP collection looks active; migrate its files only after it stops.", call. = FALSE)
    }
    legacy_raw <- file.path(data_dir, "raw")
    for (item in c("catalog.csv", "manifest.csv", "index", "quarantine")) {
      if (move_into_layout(file.path(data_dir, item), file.path(disclosures, item))) {
        note("moved %s -> financial_disclosures/%s", item, item)
      }
    }
    for (form in setdiff(list.files(legacy_raw), "investment_fund_reports")) {
      move_into_layout(file.path(legacy_raw, form), file.path(disclosures, "raw", form))
      note("moved raw/%s -> financial_disclosures/raw/%s", form, form)
    }
    for (item in c("collect_dfp.log", "collect_dfp.out.log", "collect_dfp.pid")) {
      if (move_into_layout(file.path(data_dir, item), file.path(disclosures, "logs", item))) {
        note("moved %s -> financial_disclosures/logs/", item)
      }
    }
    changed <- rewrite_manifest_prefix(file.path(disclosures, "manifest.csv"),
                                       paste0(legacy_raw, "/"), paste0(disclosures, "/raw/"))
    if (changed > 0) note("raw_path rewritten in financial_disclosures/manifest.csv: %d row(s)", changed)
  }
  for (empty in file.path(data_dir, c("raw/investment_fund_reports", "raw", "processed"))) {
    if (dir.exists(empty) && length(list.files(empty, all.files = TRUE, no.. = TRUE)) == 0) {
      unlink(empty, recursive = TRUE)  # empty: checked above
      if (!dir.exists(empty)) note("removed empty %s", substring(empty, nchar(data_dir) + 2L))
    }
  }
  log
}
