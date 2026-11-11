# Data P03 entry point (MVP Phase 1.2): extract explanatory notes from the
# downloaded CVM filing packages and consolidate them in Parquet. Run from the
# project root:
#   Rscript --vanilla scripts/extract_financial_notes.R [max_reports] [force]
# e.g. Rscript --vanilla scripts/extract_financial_notes.R Inf
#
# Reads the financial_disclosures data root (catalog.csv, manifest.csv,
# index/, raw/; never modified) and writes
# <TAXMINER_DATA_DIR>/financial_disclosures/processed/ (layout in
# src/common/data_layout.R):
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
source("src/common/parquet_io.R")
source("src/common/data_layout.R")
source("src/data/extract_financial_notes.R")
source("src/data/consolidate_financial_notes.R")

data_dir <- resolve_data_dir()
input_dir <- source_data_root(data_dir, "financial_disclosures")
output_dir <- file.path(data_dir, "financial_disclosures")

args <- commandArgs(trailingOnly = TRUE)
max_reports <- if (length(args) >= 1) as.numeric(args[1]) else Inf
force <- length(args) >= 2 && identical(tolower(args[2]), "force")

started <- Sys.time()
touched <- consolidate_financial_notes(input_dir, max_reports = max_reports, force = force,
                                       output_dir = output_dir)
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))

cat(sprintf("Processed %d package(s) in %.0f s.\n", nrow(touched), elapsed))
if (nrow(touched) > 0) print(table(touched$extraction_status))
index <- readRDS(financial_notes_paths(output_dir)$index)
cat(sprintf("Index: %d package(s), %d note(s).\n", nrow(index), sum(index$note_count)))
print(table(index$extraction_status))
