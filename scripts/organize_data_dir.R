# Move TAXMINER_DATA_DIR into the per-source-family layout of
# src/common/data_layout.R. Run from the project root:
#   Rscript --vanilla scripts/organize_data_dir.R          # funds and notes output
#   Rscript --vanilla scripts/organize_data_dir.R dfp      # also the DFP collection
# The `dfp` step refuses to run while the DFP collection is active (process in
# collect_dfp.pid alive, or collect_dfp.log written in the last 15 minutes).
# Nothing is deleted; only empty legacy folders are removed.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
source("src/common/safe_io.R")
source("src/common/data_layout.R")

data_dir <- resolve_data_dir()
include_dfp <- identical(commandArgs(trailingOnly = TRUE)[1], "dfp")

collection_active <- function(data_dir) {
  pid_file <- file.path(data_dir, "collect_dfp.pid")
  log_file <- file.path(data_dir, "collect_dfp.log")
  recent <- file.exists(log_file) &&
    difftime(Sys.time(), file.mtime(log_file), units = "mins") < 15
  alive <- FALSE
  if (file.exists(pid_file)) {
    pid <- trimws(readLines(pid_file, n = 1, warn = FALSE))
    if (grepl("^[0-9]+$", pid)) {
      out <- suppressWarnings(system2("tasklist", c("/FI", shQuote(paste("PID eq", pid)), "/NH"),
                                      stdout = TRUE, stderr = TRUE))
      alive <- any(grepl(sprintf("\\b%s\\b", pid), out))
    }
  }
  recent || alive
}

log <- organize_data_dir(data_dir, include_dfp = include_dfp,
                         collection_active = if (include_dfp) collection_active(data_dir) else TRUE)
if (length(log) == 0) cat("Nothing to move.\n") else cat(paste0(log, "\n"), sep = "")
