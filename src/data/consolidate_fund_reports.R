# Consolidation of CVM investment fund report tables (investment_fund_reports,
# MVP Phase 1.3, Data P04). Reads the Collect P05 manifests and immutable raw
# files under the family root (<TAXMINER_DATA_DIR>/investment_fund_reports,
# src/common/data_layout.R) and writes one Parquet part per table and source
# file, current version only:
#   processed/{family}/{table_name}/part-{file stem}--{member stem}.parquet
#   processed/{family}/fund_quality_issues/part-{file stem}.parquet
#   processed/consolidation_index.rds   per member: hashes, layout, row counts
#
# - Members are read as Latin-1 and split on ';' without quote handling: the
#   published files carry literal quotes inside text and a constant field count.
# - CVM columns keep their published names and original text values; TaxMiner
#   adds lineage and identity columns (fund_report_columns).
# - Quality issues are records; no row is ever dropped or summed.
# - Reruns skip files whose SHA-256 and consolidation signature are unchanged.
# Requires arrow and src/common/{safe_io,signatures}.R.

fund_report_columns <- c("family", "dataset", "table_name", "layout_version", "reference_period",
                         "fund_cnpj_original", "fund_cnpj_normalized", "zip_sha256",
                         "source_file", "source_line")

fund_quality_columns <- c("family", "dataset", "table_name", "reference_period", "zip_sha256",
                          "source_file", "source_line", "issue_type", "detail", "row_count")

# Fund identifier columns by priority (compared case-insensitively). FII uses
# CNPJ_Fundo_Classe, FIDC and FIP from 2024 CNPJ_FUNDO_CLASSE, FIAGRO
# CNPJ_Classe, FIP up to 2023 CNPJ_FUNDO.
fund_identifier_columns <- c("CNPJ_Fundo_Classe", "CNPJ_Classe", "CNPJ_FUNDO")
fund_period_columns <- c("Data_Referencia", "DT_COMPTC")
fund_version_columns <- c("Versao", "VERSAO")

# Table name of a member: its file name without the period suffix, e.g.
# inf_mensal_fidc_tab_I_202610.csv -> inf_mensal_fidc_tab_I. It matches the
# META dictionary file meta_{table_name}.txt.
fund_table_name <- function(member) {
  sub("_[0-9]{4}([0-9]{2})?\\.csv$", "", basename(member), ignore.case = TRUE)
}

# CNPJ check digits for numeric and alphanumeric CNPJ (characters valued as
# their code minus 48, as in the alphanumeric CNPJ rule). Returns the
# normalized 14-character value, or NA when it is not a valid CNPJ.
normalize_cnpj <- function(x) {
  value <- toupper(gsub("[./[:space:]-]", "", x))
  # Numeric values that lost leading zeros are padded; validity still depends
  # on the check digits.
  short <- !is.na(value) & grepl("^[0-9]{11,13}$", value)
  value[short] <- paste0(strrep("0", 14L - nchar(value[short])), value[short])
  ok <- !is.na(value) & grepl("^[0-9A-Z]{12}[0-9]{2}$", value)
  check <- function(v) {
    chars <- utf8ToInt(v) - 48L
    dv <- function(digits, weights) {
      r <- sum(digits * weights) %% 11
      if (r < 2) 0L else 11L - r
    }
    w1 <- c(5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2)
    w2 <- c(6, w1)
    d1 <- dv(chars[1:12], w1)
    d2 <- dv(c(chars[1:12], d1), w2)
    all(c(d1, d2) == chars[13:14]) && !all(chars == chars[1])
  }
  ok[ok] <- vapply(value[ok], check, logical(1))
  ifelse(ok, value, NA_character_)
}

# Split ';'-separated lines into a character matrix with `width` columns.
# strsplit drops a trailing empty field, hence the appended separator.
split_fund_lines <- function(lines, width) {
  parts <- strsplit(paste0(lines, ";"), ";", fixed = TRUE)
  counts <- lengths(parts)
  values <- vapply(parts, function(p) {
    length(p) <- width
    p
  }, character(width))
  list(values = if (width == 1) matrix(values, ncol = 1) else t(values), counts = counts)
}

# Fields of each table from the META dictionaries stored in <root>/meta.
read_fund_dictionaries <- function(root) {
  files <- list.files(file.path(root, "meta"), pattern = "^meta_.*\\.(zip|txt)$", full.names = TRUE)
  fields <- list()
  for (path in files) {
    texts <- if (grepl("\\.zip$", path)) {
      members <- utils::unzip(path, list = TRUE)$Name
      stats::setNames(lapply(members, function(m) readLines(unz(path, m), warn = FALSE)), members)
    } else {
      stats::setNames(list(readLines(path, warn = FALSE)), basename(path))
    }
    for (member in names(texts)) {
      lines <- iconv(texts[[member]], "latin1", "UTF-8")
      table <- sub("^meta_", "", sub("\\.txt$", "", basename(member)))
      fields[[table]] <- trimws(sub("^Campo:", "", grep("^Campo:", lines, value = TRUE)))
    }
  }
  fields
}

new_quality <- function() {
  as.data.frame(stats::setNames(replicate(length(fund_quality_columns), character(),
                                          simplify = FALSE), fund_quality_columns))
}

# Read one member into a data frame of original text values plus lineage, and
# diagnose quality. `lines` are the raw (Latin-1) lines of the member.
read_fund_member <- function(lines, member, entry, dictionary = NULL) {
  lines <- sub("\r$", "", iconv(lines, "latin1", "UTF-8"))
  table_name <- fund_table_name(member)
  issues <- list()
  issue <- function(type, detail, line = NA_integer_, count = 1L) {
    issues[[length(issues) + 1L]] <<- data.frame(
      family = entry$family, dataset = entry$dataset, table_name = table_name,
      reference_period = entry$reference_period, zip_sha256 = entry$file_sha256,
      source_file = member, source_line = as.character(line), issue_type = type,
      detail = detail, row_count = as.character(count), stringsAsFactors = FALSE)
  }
  header <- strsplit(lines[1], ";", fixed = TRUE)[[1]]
  if (anyDuplicated(header)) {
    issue("duplicate_column", paste(unique(header[duplicated(header)]), collapse = ";"))
    header <- make.unique(header, sep = "__")
  }
  body <- lines[-1]
  body_line <- seq_along(body) + 1L
  keep <- nzchar(body)
  body <- body[keep]
  body_line <- body_line[keep]
  split <- split_fund_lines(body, length(header))
  values <- as.data.frame(split$values, stringsAsFactors = FALSE)
  names(values) <- header
  mismatch <- which(split$counts != length(header))
  for (i in mismatch) {
    issue("field_count_mismatch", sprintf("%d fields, header has %d", split$counts[i], length(header)),
          body_line[i])
  }
  duplicated_rows <- which(duplicated(body))
  for (i in duplicated_rows) issue("duplicate_row", "identical to an earlier line", body_line[i])

  lower <- tolower(header)
  id_col <- header[match(tolower(fund_identifier_columns), lower)]
  id_col <- id_col[!is.na(id_col)][1]
  cnpj <- if (is.na(id_col)) rep(NA_character_, nrow(values)) else values[[id_col]]
  if (is.na(id_col)) issue("missing_fund_identifier", "no fund CNPJ column in header", count = nrow(values))
  normalized <- normalize_cnpj(cnpj)
  if (!is.na(id_col)) {
    empty <- which(is.na(cnpj) | !nzchar(trimws(cnpj)))
    invalid <- setdiff(which(is.na(normalized)), empty)
    for (i in empty) issue("empty_fund_identifier", id_col, body_line[i])
    for (i in invalid) issue("invalid_cnpj", sprintf("%s=%s", id_col, cnpj[i]), body_line[i])
  }

  period_col <- header[match(tolower(fund_period_columns), lower)]
  period_col <- period_col[!is.na(period_col)][1]
  version_col <- header[match(tolower(fund_version_columns), lower)]
  version_col <- version_col[!is.na(version_col)][1]
  if (!is.na(period_col) && !is.na(id_col) && nrow(values) > 0) {
    key <- paste(ifelse(is.na(normalized), cnpj, normalized), values[[period_col]])
    repeated <- sum(duplicated(key) | duplicated(key, fromLast = TRUE))
    if (repeated > 0) {
      issue("repeated_fund_period", sprintf("%s + %s", id_col, period_col), count = repeated)
    }
    if (!is.na(version_col)) {
      versions <- tapply(values[[version_col]], key, function(v) length(unique(v)))
      resubmitted <- sum(versions > 1)
      if (resubmitted > 0) {
        issue("resubmitted_versions", sprintf("fund-periods with more than one %s", version_col),
              count = resubmitted)
      }
    }
  }
  if (!is.null(dictionary)) {
    extra <- setdiff(header, dictionary)
    absent <- setdiff(dictionary, header)
    if (length(extra) > 0) issue("column_not_in_dictionary", paste(extra, collapse = ";"),
                                 count = length(extra))
    if (length(absent) > 0) issue("dictionary_column_absent", paste(absent, collapse = ";"),
                                  count = length(absent))
  } else {
    issue("no_dictionary", sprintf("no META entry for %s", table_name))
  }

  layout <- substr(compute_signature_hash(header), 1, 12)
  n <- nrow(values)
  lineage <- data.frame(
    family = rep(entry$family, n), dataset = rep(entry$dataset, n),
    table_name = rep(table_name, n), layout_version = rep(layout, n),
    reference_period = rep(entry$reference_period, n), fund_cnpj_original = as.character(cnpj),
    fund_cnpj_normalized = as.character(normalized), zip_sha256 = rep(entry$file_sha256, n),
    source_file = rep(member, n), source_line = as.integer(body_line), stringsAsFactors = FALSE)
  clash <- intersect(names(values), fund_report_columns)
  if (length(clash) > 0) names(values)[match(clash, names(values))] <- paste0("cvm_", clash)
  list(rows = cbind(lineage, values), table_name = table_name, layout_version = layout,
       columns = header, quality = if (length(issues) > 0) do.call(rbind, issues) else new_quality())
}

# Latest downloaded version of each file, from every family manifest.
current_fund_files <- function(root) {
  manifests <- list.files(file.path(root, "manifests"), pattern = "\\.csv$", full.names = TRUE)
  rows <- lapply(manifests, function(path) {
    utils::read.csv(path, colClasses = "character", na.strings = character(), encoding = "UTF-8")
  })
  if (length(rows) == 0) return(NULL)
  all <- do.call(rbind, rows)
  all <- all[all$outcome == "downloaded" & nzchar(all$raw_path), , drop = FALSE]
  all <- all[order(all$source_id, all$retrieved_at), , drop = FALSE]
  all[!duplicated(all$source_id, fromLast = TRUE), , drop = FALSE]
}

fund_processed_paths <- function(root) {
  base <- file.path(root, "processed")
  list(base = base, index = file.path(base, "consolidation_index.rds"))
}

fund_consolidation_signature <- function() {
  compute_signature_hash(list(
    functions = transformation_signature(list(
      fund_table_name = fund_table_name, normalize_cnpj = normalize_cnpj,
      split_fund_lines = split_fund_lines, read_fund_member = read_fund_member,
      consolidate_fund_file = consolidate_fund_file)),
    columns = list(fund_report_columns, fund_quality_columns, fund_identifier_columns,
                   fund_period_columns, fund_version_columns)))
}

empty_fund_index <- function() {
  data.frame(source_id = character(), file_sha256 = character(), signature = character(),
             source_file = character(), table_name = character(), layout_version = character(),
             column_count = integer(), row_count = integer(), issue_count = integer(),
             output_path = character(), output_sha256 = character(), consolidated_at = character(),
             stringsAsFactors = FALSE)
}

# Consolidate one stored file (ZIP or CSV) into Parquet parts. Returns index rows.
consolidate_fund_file <- function(entry, root, dictionaries, signature) {
  path <- file.path(root, entry$raw_path)
  if (!identical(as.character(tools::sha256sum(path)), entry$file_sha256)) {
    stop("Stored file does not match its manifest hash: ", entry$raw_path, call. = FALSE)
  }
  is_zip <- grepl("\\.zip$", entry$file_name, ignore.case = TRUE)
  members <- if (is_zip) utils::unzip(path, list = TRUE)$Name else entry$file_name
  members <- members[grepl("\\.csv$", members, ignore.case = TRUE)]
  stem <- sub("\\.[A-Za-z]+$", "", entry$file_name)
  stamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  quality <- list()
  index <- list()
  for (member in members) {
    lines <- if (is_zip) readLines(unz(path, member), warn = FALSE) else
      readLines(path, warn = FALSE)
    table <- fund_table_name(member)
    result <- read_fund_member(lines, member, entry, dictionaries[[table]])
    rm(lines)
    # One part per member: yearly FIDC files hold one member per month and table.
    out <- file.path(root, "processed", entry$family, table,
                     sprintf("part-%s--%s.parquet", stem, sub("\\.csv$", "", basename(member),
                                                               ignore.case = TRUE)))
    write_parquet_validated(result$rows, out)
    row_count <- nrow(result$rows)
    result$rows <- NULL
    gc(verbose = FALSE)
    quality[[length(quality) + 1L]] <- result$quality
    index[[length(index) + 1L]] <- data.frame(
      source_id = entry$source_id, file_sha256 = entry$file_sha256, signature = signature,
      source_file = member, table_name = table, layout_version = result$layout_version,
      column_count = length(result$columns), row_count = row_count,
      issue_count = nrow(result$quality), output_path = substring(out, nchar(root) + 2L),
      output_sha256 = as.character(tools::sha256sum(out)), consolidated_at = stamp,
      stringsAsFactors = FALSE)
  }
  issues <- do.call(rbind, c(list(new_quality()), quality))
  issues_path <- file.path(root, "processed", entry$family, "fund_quality_issues",
                           sprintf("part-%s.parquet", stem))
  if (nrow(issues) > 0) write_parquet_validated(issues, issues_path) else unlink(issues_path)
  do.call(rbind, c(list(empty_fund_index()), index))
}

# Consolidate every current file that is new, changed or processed with another
# signature. Parts of tables that disappeared from a new version are removed.
consolidate_fund_reports <- function(root, families = NULL, max_files = Inf, force = FALSE,
                                     signature = fund_consolidation_signature(), progress = TRUE) {
  paths <- fund_processed_paths(root)
  index <- read_rds_recoverable(paths$index, is.data.frame)
  if (is.null(index)) index <- empty_fund_index()
  files <- current_fund_files(root)
  if (is.null(files)) return(empty_fund_index())
  if (!is.null(families)) files <- files[files$family %in% families, , drop = FALSE]
  done <- unique(paste(index$source_id, index$file_sha256, index$signature))
  pending <- files[force | !paste(files$source_id, files$file_sha256, signature) %in% done, ,
                   drop = FALSE]
  if (is.finite(max_files)) pending <- utils::head(pending, max_files)
  dictionaries <- read_fund_dictionaries(root)
  touched <- empty_fund_index()
  for (i in seq_len(nrow(pending))) {
    entry <- pending[i, , drop = FALSE]
    rows <- consolidate_fund_file(entry, root, dictionaries, signature)
    stale <- setdiff(index$output_path[index$source_id == entry$source_id], rows$output_path)
    unlink(file.path(root, stale))
    index <- rbind(index[index$source_id != entry$source_id, , drop = FALSE], rows)
    write_validated_atomic(index, paths$index, "rds")
    touched <- rbind(touched, rows)
    if (progress) {
      message(sprintf("[%d/%d] %s tables=%d rows=%d issues=%d", i, nrow(pending), entry$source_id,
                      nrow(rows), sum(rows$row_count), sum(rows$issue_count)))
    }
  }
  touched
}

# Read-only access to one consolidated table (all periods) as an Arrow dataset.
# Layouts differ by period, so the schemas of the parts are unified.
open_fund_table <- function(root, family, table_name) {
  arrow::open_dataset(file.path(fund_processed_paths(root)$base, family, table_name),
                      format = "parquet", unify_schemas = TRUE)
}
