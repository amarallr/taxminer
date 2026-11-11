# Data P03 entry point (MVP Phase 1.2): extract explanatory notes from the
# downloaded CVM filing packages and consolidate them in Parquet. Run from the
# project root:
#   Rscript --vanilla scripts/extract_financial_notes.R [max_reports] [force]
# e.g. Rscript --vanilla scripts/extract_financial_notes.R Inf
#
# Reads <TAXMINER_DATA_DIR>/{catalog.csv,manifest.csv,raw/} (never modified)
# and writes <TAXMINER_DATA_DIR>/processed/financial_disclosures/:
#   financial_reports/part-<id>.parquet  one row per filing package
#   financial_notes/part-<id>.parquet    one row per note
#   extraction_index.rds                 package hash + extraction signature
# Reruns skip unchanged packages, so the command is resumable and can run while
# the collection is still adding packages.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
for (pkg in c("arrow", "pdftools", "xml2", "base64enc")) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop("Missing declared dependency: ", pkg)
}
source("src/common/signatures.R")
source("src/common/safe_io.R")
source("src/data/extract_financial_notes.R")
source("src/data/consolidate_financial_notes.R")

data_dir <- Sys.getenv("TAXMINER_DATA_DIR")
if (!nzchar(data_dir)) stop("Set TAXMINER_DATA_DIR to a local folder outside OneDrive.")
data_dir <- normalizePath(data_dir, winslash = "/", mustWork = TRUE)
if (grepl("onedrive", data_dir, ignore.case = TRUE)) {
  stop("TAXMINER_DATA_DIR is inside OneDrive; choose a local folder outside it.")
}

args <- commandArgs(trailingOnly = TRUE)
max_reports <- if (length(args) >= 1) as.numeric(args[1]) else Inf
force <- length(args) >= 2 && identical(tolower(args[2]), "force")

started <- Sys.time()
touched <- consolidate_financial_notes(data_dir, max_reports = max_reports, force = force)
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))

cat(sprintf("Processed %d package(s) in %.0f s.\n", nrow(touched), elapsed))
if (nrow(touched) > 0) print(table(touched$extraction_status))
index <- readRDS(financial_notes_paths(data_dir)$index)
cat(sprintf("Index: %d package(s), %d note(s).\n", nrow(index), sum(index$note_count)))
print(table(index$extraction_status))
