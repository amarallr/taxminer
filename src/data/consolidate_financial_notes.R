# Parquet consolidation of explanatory notes (financial_notes, MVP Phase 1.2,
# Data P03). Reads the Collect P04 catalog, manifest and index under the
# financial_disclosures data root (`data_dir`), extracts each downloaded
# package once and writes one Parquet part per package under `output_dir`
# (normally <TAXMINER_DATA_DIR>/financial_disclosures; src/common/data_layout.R):
#   processed/financial_reports/part-{source_document_id}.parquet
#   processed/financial_notes/part-{source_document_id}.parquet
# An extraction index (RDS, written with src/common/safe_io.R) records the
# package SHA-256 and the extraction signature, so reruns skip unchanged
# packages and reprocess when the package or the extraction logic changes.
# The raw packages are only read. Requires arrow and the modules
# src/common/{signatures,safe_io,parquet_io}.R and src/data/extract_financial_notes.R.

financial_report_columns <- c(
  report_id = "character", source_document_id = "character", report_type = "character",
  cvm_code = "character", company_cnpj = "character", company_name = "character",
  reporting_period_start = "character", reporting_period_end = "character",
  filing_date = "character", publication_date = "character", document_version = "integer",
  source_url = "character", package_sha256 = "character", package_layout = "character",
  notes_file_name = "character", document_hash = "character", page_count = "integer",
  note_count = "integer", extraction_method = "character", extraction_status = "character",
  extraction_error = "character", confidence = "character",
  extraction_signature = "character", extracted_at = "character")

financial_note_columns <- c(
  note_id = "character", report_id = "character", source_document_id = "character",
  report_type = "character", cvm_code = "character", company_cnpj = "character",
  reporting_period_end = "character", note_sequence = "integer", note_set = "integer",
  note_number = "character", note_title = "character", note_text = "character",
  source_page_start = "integer", source_page_end = "integer", document_hash = "character",
  currency = "character", unit_scale = "character", unit_scale_source = "character",
  language = "character", extraction_method = "character", extraction_status = "character",
  confidence = "character", extraction_signature = "character")

# Signature of everything that changes the extracted content: the extraction
# functions and the heading patterns.
notes_extraction_signature <- function() {
  compute_signature_hash(list(
    functions = transformation_signature(list(
      read_package_attachments = read_package_attachments,
      find_heading_candidates = find_heading_candidates,
      select_note_sets = select_note_sets,
      prefer_consistent_style = prefer_consistent_style,
      detect_unit_scale = detect_unit_scale,
      segment_notes_pdf = segment_notes_pdf,
      extract_package_notes = extract_package_notes)),
    patterns = list(heading_pattern, heading_pattern_parenthesized),
    notes_group = notes_group_code))
}

# Coerce a data frame to the declared column set and types, so that every
# Parquet part shares one schema.
conform_columns <- function(df, columns) {
  out <- lapply(names(columns), function(col) {
    value <- if (col %in% names(df)) df[[col]] else rep(NA, nrow(df))
    switch(columns[[col]], integer = as.integer(value), as.character(value))
  })
  names(out) <- names(columns)
  as.data.frame(out, stringsAsFactors = FALSE)
}

# Catalog reader tolerant to a known collector defect: the open-data index was
# decoded as UTF-8 instead of Latin-1, so company names were cut at the first
# accented letter together with their closing quote ("RA,"2026-03-31",...).
# Such lines get the quote back before parsing; names are then corrected from
# the index files by index_company_names().
read_catalog_tolerant <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  quotes <- nchar(gsub('[^"]', "", lines))
  broken <- quotes %% 2 == 1
  lines[broken] <- sub('(,"[^"]*),("[0-9]{4}-[0-9]{2}-[0-9]{2}",)', '\\1",\\2',
                       lines[broken])
  utils::read.csv(text = lines, colClasses = "character", na.strings = character(),
                  encoding = "UTF-8")
}

# Company names by document id, read from the CVM open-data index ZIPs under
# <data_dir>/index with explicit Latin-1 decoding.
index_company_names <- function(data_dir) {
  zips <- list.files(file.path(data_dir, "index"), pattern = "^(dfp|itr)_cia_aberta_[0-9]{4}\\.zip$",
                     full.names = TRUE)
  rows <- lapply(zips, function(zip) {
    member <- sub("\\.zip$", ".csv", basename(zip))
    lines <- iconv(readLines(unz(zip, member), warn = FALSE), "latin1", "UTF-8")
    index <- utils::read.csv2(text = lines, colClasses = "character", check.names = FALSE,
                              encoding = "UTF-8")
    index[, c("ID_DOC", "DENOM_CIA")]
  })
  names <- do.call(rbind, c(list(data.frame(ID_DOC = character(), DENOM_CIA = character())), rows))
  names[!duplicated(names$ID_DOC, fromLast = TRUE), , drop = FALSE]
}

# Downloaded packages to process: the latest manifest row per document with
# outcome `downloaded` and an existing raw file, joined with the catalog.
downloaded_reports <- function(data_dir) {
  manifest <- utils::read.csv(file.path(data_dir, "manifest.csv"), colClasses = "character",
                              na.strings = character(), encoding = "UTF-8")
  manifest <- manifest[!duplicated(manifest$source_document_id, fromLast = TRUE), , drop = FALSE]
  manifest <- manifest[manifest$outcome == "downloaded" & file.exists(manifest$raw_path), , drop = FALSE]
  catalog <- read_catalog_tolerant(file.path(data_dir, "catalog.csv"))
  catalog <- catalog[!duplicated(catalog$source_document_id), , drop = FALSE]
  names <- index_company_names(data_dir)
  found <- match(catalog$source_document_id, names$ID_DOC)
  catalog$company_name[!is.na(found)] <- names$DENOM_CIA[found[!is.na(found)]]
  merge(catalog, manifest[, c("source_document_id", "package_sha256", "raw_path")],
        by = "source_document_id")
}

financial_notes_paths <- function(output_dir) {
  base <- file.path(output_dir, "processed")
  list(base = base,
       reports = file.path(base, "financial_reports"),
       notes = file.path(base, "financial_notes"),
       index = file.path(base, "extraction_index.rds"))
}

empty_extraction_index <- function() {
  data.frame(source_document_id = character(), package_sha256 = character(),
             extraction_signature = character(), extraction_status = character(),
             note_count = integer(), extracted_at = character(), stringsAsFactors = FALSE)
}

# Extract and write Parquet parts for packages that are new, changed, or were
# extracted with a different signature. `extractor` is injectable for tests.
# Returns the rows of the extraction index touched in this run.
consolidate_financial_notes <- function(data_dir, max_reports = Inf, force = FALSE,
                                        extractor = extract_package_notes,
                                        signature = notes_extraction_signature(),
                                        progress = TRUE, output_dir = data_dir) {
  paths <- financial_notes_paths(output_dir)
  index <- read_rds_recoverable(paths$index, is.data.frame)
  if (is.null(index)) index <- empty_extraction_index()
  reports <- downloaded_reports(data_dir)
  key <- paste(reports$source_document_id, reports$package_sha256, signature)
  done <- paste(index$source_document_id, index$package_sha256, index$extraction_signature)
  pending <- reports[force | !key %in% done, , drop = FALSE]
  pending <- pending[order(pending$source_document_id), , drop = FALSE]
  if (is.finite(max_reports)) pending <- utils::head(pending, max_reports)
  touched <- empty_extraction_index()
  for (i in seq_len(nrow(pending))) {
    row <- pending[i, , drop = FALSE]
    id <- row$source_document_id
    stamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    result <- tryCatch(extractor(row$raw_path, row), error = function(e) e)
    if (inherits(result, "error")) {
      report <- row
      report$extraction_status <- "extraction_failed"
      report$extraction_error <- conditionMessage(result)
      result <- list(report = report, notes = NULL)
    }
    report <- result$report
    report$extraction_signature <- signature
    report$extracted_at <- stamp
    notes_path <- file.path(paths$notes, sprintf("part-%s.parquet", id))
    if (!is.null(result$notes) && nrow(result$notes) > 0) {
      notes <- result$notes
      for (col in c("source_document_id", "report_type", "cvm_code", "company_cnpj",
                    "reporting_period_end")) notes[[col]] <- row[[col]]
      notes$extraction_signature <- signature
      write_parquet_validated(conform_columns(notes, financial_note_columns), notes_path)
    } else if (file.exists(notes_path)) {
      unlink(notes_path)  # stale notes from an earlier extraction
    }
    write_parquet_validated(conform_columns(report, financial_report_columns),
                            file.path(paths$reports, sprintf("part-%s.parquet", id)))
    entry <- data.frame(source_document_id = id, package_sha256 = row$package_sha256,
                        extraction_signature = signature,
                        extraction_status = as.character(report$extraction_status),
                        note_count = as.integer(report$note_count %||% 0L),
                        extracted_at = stamp, stringsAsFactors = FALSE)
    index <- rbind(index[index$source_document_id != id, , drop = FALSE], entry)
    write_validated_atomic(index, paths$index, "rds")
    touched <- rbind(touched, entry)
    if (progress) {
      message(sprintf("[%d/%d] %s %s notes=%d", i, nrow(pending), id,
                      entry$extraction_status, entry$note_count))
    }
  }
  touched
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x[1])) y else x

# Read-only access to the consolidated tables as Arrow datasets.
open_financial_notes <- function(output_dir, table = c("financial_notes", "financial_reports")) {
  table <- match.arg(table)
  arrow::open_dataset(file.path(financial_notes_paths(output_dir)$base, table), format = "parquet")
}
