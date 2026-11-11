# Validated Parquet publication shared by the data modules (financial_notes,
# investment_fund_reports). Requires arrow; the rollback convention matches
# write_validated_atomic in src/common/safe_io.R.

# Write a Parquet file through a neighbour temporary file, read it back and
# check rows and columns, then replace the destination keeping a rollback.
write_parquet_validated <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(".publish-", tmpdir = dirname(path), fileext = ".parquet")
  on.exit(unlink(temporary), add = TRUE)
  arrow::write_parquet(df, temporary, compression = "zstd")
  observed <- arrow::read_parquet(temporary, as_data_frame = FALSE)
  if (observed$num_rows != nrow(df) || !identical(names(observed), names(df))) {
    stop("Parquet differs after write: ", path, call. = FALSE)
  }
  backup <- paste0(path, ".rollback")
  if (file.exists(backup)) stop("Pending rollback kept for review: ", backup, call. = FALSE)
  existed <- file.exists(path)
  if (existed && !file.rename(path, backup)) stop("Destination locked: ", path, call. = FALSE)
  if (!file.rename(temporary, path)) {
    if (existed) file.rename(backup, path)
    stop("Publication failed; previous version kept: ", path, call. = FALSE)
  }
  if (existed) unlink(backup)
  invisible(path)
}
