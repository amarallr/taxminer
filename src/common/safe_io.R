# Shared safe input/output primitives (Common P07 stage 02, decision_0023).
# Base R only. Re-implemented from requirements, not copied; provenance is
# recorded per function as required by prompts/common_p07_new_data_sources.txt.
# source() only defines functions: no network, no file access, no side effects.
# Requires src/common/signatures.R for compute_signature_hash().

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::validar_destino (P02-FUN-006)
# Returns `root/path` when `path` is relative and resolves inside `root`.
# Rejects empty, absolute, drive-letter and parent (`..`) paths, and paths
# whose nearest existing ancestor resolves outside `root` (for example through
# a link). Comparison ignores case on Windows only.
validate_contained_path <- function(root, path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) ||
      grepl("^[A-Za-z]:|^[/\\\\]|(^|[/\\\\])\\.\\.([/\\\\]|$)", path)) {
    stop("Path must be relative and stay inside the root: ", path, call. = FALSE)
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  target <- file.path(root, path)
  ancestor <- target
  while (!file.exists(ancestor)) ancestor <- dirname(ancestor)
  resolved <- normalizePath(ancestor, winslash = "/", mustWork = TRUE)
  fold <- if (.Platform$OS.type == "windows") tolower else identity
  if (!identical(fold(resolved), fold(root)) &&
      !startsWith(fold(resolved), paste0(fold(root), "/"))) {
    stop("Path resolves outside the root: ", path, call. = FALSE)
  }
  target
}

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::recuperar_rollback (P02-FUN-007, P02-RF-008)
# If `path.rollback` exists (a replacement was interrupted), validate it and
# restore it; an interrupted destination is preserved as `path.interrupted-*`.
# An invalid backup stops without deleting anything. Returns TRUE when it
# restored a backup.
recover_from_rollback <- function(path, validator = function(p) { readRDS(p); TRUE }) {
  backup <- paste0(path, ".rollback")
  if (!file.exists(backup)) return(invisible(FALSE))
  valid <- tryCatch(isTRUE(validator(backup)), error = function(e) FALSE)
  if (!valid) stop("Invalid rollback file kept for review: ", backup, call. = FALSE)
  if (file.exists(path)) {
    kept <- tempfile(paste0(basename(path), ".interrupted-"), tmpdir = dirname(path))
    if (!file.rename(path, kept)) stop("Destination locked during recovery: ", path, call. = FALSE)
  }
  if (!file.rename(backup, path)) stop("Could not restore rollback: ", backup, call. = FALSE)
  invisible(TRUE)
}

read_back <- function(path, format) {
  if (format == "rds") readRDS(path) else
    utils::read.csv(path, colClasses = "character", na.strings = character(),
                    check.names = FALSE, encoding = "UTF-8")
}

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::gravar_validado_atomico (P02-FUN-001, P02-RF-002, P02-RF-003)
# Writes `object` to a temporary file next to `path`, reads it back and checks
# it (RDS: same signature; CSV: same columns and row count; then the optional
# `validator` on the re-read object). Only then the previous version is moved
# to `path.rollback`, the new file is renamed into place and the backup is
# removed. A failed rename restores the previous version. Cross-file atomicity
# is not promised (OneDrive and Windows renames can fail).
write_validated_atomic <- function(object, path, format = c("rds", "csv"),
                                   validator = NULL, rename = file.rename) {
  format <- match.arg(format)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  recover_from_rollback(path, function(p) {
    is.null(validator) || isTRUE(validator(read_back(p, format)))
  })
  temporary <- tempfile(".publish-", tmpdir = dirname(path))
  on.exit(unlink(temporary), add = TRUE)
  if (format == "rds") {
    saveRDS(object, temporary, version = 2)
    observed <- readRDS(temporary)
    if (!identical(compute_signature_hash(object), compute_signature_hash(observed))) {
      stop("RDS content changed on write: ", path, call. = FALSE)
    }
  } else {
    utils::write.csv(object, temporary, row.names = FALSE, na = "", fileEncoding = "UTF-8")
    observed <- read_back(temporary, "csv")
    if (nrow(observed) != nrow(object) || !identical(names(observed), names(object))) {
      stop("CSV differs after write: ", path, call. = FALSE)
    }
  }
  if (!is.null(validator) && !isTRUE(validator(observed))) {
    stop("Validator rejected the new version: ", path, call. = FALSE)
  }
  backup <- paste0(path, ".rollback")
  if (file.exists(backup)) stop("Pending rollback kept for review: ", backup, call. = FALSE)
  existed <- file.exists(path)
  if (existed && !rename(path, backup)) stop("Destination locked: ", path, call. = FALSE)
  if (!rename(temporary, path)) {
    if (existed) file.rename(backup, path)
    stop("Publication failed; previous version kept: ", path, call. = FALSE)
  }
  if (existed) unlink(backup)
  list(path = path, sha256 = unname(as.character(tools::sha256sum(path))))
}

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::ler_rds_recuperavel (P02-FUN-008, P02-RF-008)
# Reads an RDS state file after recovering an interrupted replacement. A
# missing file returns NULL; an unreadable or invalid file is never treated as
# success: it is preserved as `path.corrupt-*`, a warning is raised and NULL is
# returned so that the caller rebuilds it.
read_rds_recoverable <- function(path, validator = is.list) {
  recover_from_rollback(path, function(p) isTRUE(validator(readRDS(p))))
  if (!file.exists(path)) return(NULL)
  observed <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(observed) || !isTRUE(validator(observed))) {
    kept <- tempfile(paste0(basename(path), ".corrupt-"), tmpdir = dirname(path))
    if (!file.rename(path, kept)) stop("Corrupt RDS is locked: ", path, call. = FALSE)
    warning("Invalid RDS preserved for review; rebuild required: ", basename(path), call. = FALSE)
    return(NULL)
  }
  observed
}

# origin: reference_pipeline@595991b src/download/p05_01_download_fidc.R::validar_zip_fidc (P05_01-FUN-004)
# Checks a ZIP before use: non-empty, at most `max_members` members and
# `max_bytes` uncompressed bytes, no absolute, drive-letter or parent paths, no
# duplicate names (case-insensitive) and, unless allowed, no subdirectories.
# Extracts into a temporary directory to verify sizes (and CRC, through
# unzip warnings promoted to errors). Returns members with SHA-256.
validate_zip_archive <- function(path, max_members = 256L, max_bytes = 1024^3,
                                 allow_subdirectories = FALSE) {
  if (!file.exists(path) || file.info(path)$size <= 0) {
    stop("ZIP is missing or empty: ", path, call. = FALSE)
  }
  old <- options(warn = 2)
  on.exit(options(old), add = TRUE)
  members <- tryCatch(utils::unzip(path, list = TRUE),
                      error = function(e) stop("Unreadable ZIP: ", path, call. = FALSE))
  members <- members[!grepl("/$", members$Name), , drop = FALSE]
  if (nrow(members) == 0 || nrow(members) > max_members || sum(members$Length) > max_bytes) {
    stop("ZIP outside member or size limits: ", path, call. = FALSE)
  }
  names <- members$Name
  unsafe <- grepl("^[A-Za-z]:|^[/\\\\]|(^|[/\\\\])\\.\\.([/\\\\]|$)", names) |
    (!allow_subdirectories & grepl("[/\\\\]", names))
  if (any(unsafe) || anyDuplicated(tolower(names))) {
    stop("Unsafe or duplicate ZIP member names: ", path, call. = FALSE)
  }
  area <- tempfile("zip_check_")
  dir.create(area)
  on.exit(unlink(area, recursive = TRUE), add = TRUE)
  tryCatch(utils::unzip(path, exdir = area),
           error = function(e) stop("ZIP extraction failed: ", path, call. = FALSE))
  extracted <- file.path(area, names)
  if (any(!file.exists(extracted)) || any(file.info(extracted)$size != members$Length)) {
    stop("Incomplete ZIP: ", path, call. = FALSE)
  }
  data.frame(name = names, bytes = members$Length,
             sha256 = unname(as.character(tools::sha256sum(extracted))),
             stringsAsFactors = FALSE)
}
