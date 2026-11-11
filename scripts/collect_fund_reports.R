# Collect P05 entry point (MVP Phase 1.3): discover and download the CVM
# investment fund report files (FII, FIDC, FIP, FIAGRO). Run from the project
# root:
#   Rscript --vanilla scripts/collect_fund_reports.R [scope] [max_files]
# scope: `sample` (latest period of each first-sample dataset; default) or
#        `history` (every listed period; re-checks the latest period of each
#        dataset because the CVM republishes it).
# The FII DFIN index (financial statement documents) is outside both scopes.
#
# Writes under <TAXMINER_DATA_DIR>/investment_fund_reports/ (outside the
# repository and OneDrive; layout in src/common/data_layout.R):
#   catalog.csv             current listing catalog
#   manifests/{family}.csv  append-only manifests (raw_path relative to this folder)
#   raw/{family}/...        immutable, content-addressed originals
# Reruns only fetch new or republished files.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
source("src/common/safe_io.R")
source("src/common/data_layout.R")
source("src/collect/discover_fund_reports.R")
source("src/collect/download_fund_reports.R")

root <- source_data_root(resolve_data_dir(), "investment_fund_reports")
dir.create(root, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
scope <- if (length(args) >= 1) args[1] else "sample"
if (!scope %in% c("sample", "history")) stop("scope must be `sample` or `history`.")
max_files <- if (length(args) >= 2) as.numeric(args[2]) else Inf

catalog <- discover_fund_reports()
failures <- attr(catalog, "listing_failures")
invisible(write_validated_atomic(catalog, file.path(root, "catalog.csv"), "csv"))
if (length(failures) > 0) message("Listing failures:\n", paste(failures, collapse = "\n"))

selected <- catalog[catalog$first_sample, , drop = FALSE]
if (identical(scope, "sample")) {
  group <- sub(":[^:]*$", "", selected$source_id)
  latest <- stats::ave(selected$reference_period, group, FUN = max)
  selected <- selected[selected$reference_period == latest, , drop = FALSE]
}
recorded <- download_fund_reports(selected, root, max_files = max_files,
                                  refresh_recent = if (identical(scope, "history")) 1L else 0L)
cat(sprintf("Scope %s: %d file(s) selected, %d recorded in this run.\n", scope, nrow(selected),
            nrow(recorded)))
if (nrow(recorded) > 0) print(table(recorded$family, recorded$outcome))
