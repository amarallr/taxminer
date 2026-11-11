# Data P04 entry point (MVP Phase 1.3): consolidate the collected CVM
# investment fund report tables in Parquet. Run from the project root:
#   Rscript --vanilla scripts/consolidate_fund_reports.R [families] [force]
# e.g. Rscript --vanilla scripts/consolidate_fund_reports.R fii,fidc
#
# Reads <TAXMINER_DATA_DIR>/investment_fund_reports/{manifests,raw,meta}
# (never modified) and writes .../investment_fund_reports/processed/:
#   {family}/{table_name}/part-<file>.parquet       original CVM columns + lineage
#   {family}/fund_quality_issues/part-<file>.parquet quality issue records
#   consolidation_index.rds                          hashes, layouts, row counts
# Reruns skip files whose hash and consolidation logic are unchanged.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
if (!requireNamespace("arrow", quietly = TRUE)) stop("Missing declared dependency: arrow")
source("src/common/signatures.R")
source("src/common/safe_io.R")
source("src/common/parquet_io.R")
source("src/common/data_layout.R")
source("src/data/consolidate_fund_reports.R")

root <- source_data_root(resolve_data_dir(), "investment_fund_reports")
args <- commandArgs(trailingOnly = TRUE)
families <- if (length(args) >= 1 && !identical(args[1], "all")) strsplit(args[1], ",")[[1]] else NULL
force <- length(args) >= 2 && identical(tolower(args[2]), "force")

started <- Sys.time()
touched <- consolidate_fund_reports(root, families = families, force = force)
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
cat(sprintf("Consolidated %d member(s) from %d file(s) in %.0f s.\n", nrow(touched),
            length(unique(touched$source_id)), elapsed))

index <- readRDS(fund_processed_paths(root)$index)
index$family <- sub("^cvm:([^:]+):.*$", "\\1", index$source_id)
index$files <- 1L
summary <- stats::aggregate(cbind(files, row_count, issue_count) ~ family + table_name,
                            data = index, FUN = sum)
summary$layouts <- stats::aggregate(layout_version ~ family + table_name, data = index,
                                    FUN = function(x) length(unique(x)))$layout_version
print(summary, row.names = FALSE)
