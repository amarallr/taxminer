# Collect P04 entry point: historical backfill and incremental refresh of CVM
# filing packages (DFP/ITR) for financial_disclosures. Run from the project root:
#   Rscript --vanilla scripts/collect_financial_reports.R [forms] [years] [max_reports]
# e.g. Rscript --vanilla scripts/collect_financial_reports.R dfp,itr 2010-2026 Inf
#
# Storage: set TAXMINER_DATA_DIR to a local folder outside OneDrive (raw
# packages are large and must not be synchronized or published). Layout:
#   <root>/index/       yearly open-data ZIPs (index + statements, ODbL)
#   <root>/raw/         immutable filing packages <form>/<year>/<id_doc>.zip
#   <root>/manifest.csv append-only outcomes, one row per attempt
#   <root>/catalog.csv  current discovery catalog
# where <root> is <TAXMINER_DATA_DIR>/financial_disclosures, or
# <TAXMINER_DATA_DIR> itself while the legacy layout of the first DFP
# collection is in place (src/common/data_layout.R; migrated by
# scripts/organize_data_dir.R).
# Reruns skip packages with a terminal outcome, so the command is resumable.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
if (!nzchar(Sys.which("curl"))) stop("curl executable not found on PATH.")
source("src/common/data_layout.R")
source("src/collect/discover_financial_reports.R")
source("src/collect/download_financial_reports.R")

data_dir <- source_data_root(resolve_data_dir(must_work = FALSE), "financial_disclosures")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
forms <- if (length(args) >= 1) strsplit(args[1], ",")[[1]] else cvm_forms
years <- if (length(args) >= 2) {
  bounds <- as.integer(strsplit(args[2], "-")[[1]])
  seq(bounds[1], bounds[length(bounds)])
} else 2010:as.integer(format(Sys.Date(), "%Y"))
max_reports <- if (length(args) >= 3) as.numeric(args[3]) else Inf

user_agent <- "TaxMiner-collector/0.1"
delay_seconds <- 10 # dados.cvm.gov.br Crawl-Delay; applied to RAD as well
index_dir <- file.path(data_dir, "index")
raw_dir <- file.path(data_dir, "raw")
dir.create(index_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

free_gb <- function() {
  drive <- substr(data_dir, 1, 1)
  out <- system2("powershell", c("-NoProfile", "-Command",
                                 shQuote(sprintf("(Get-PSDrive %s).Free", drive))),
                 stdout = TRUE)
  as.numeric(utils::tail(out, 1)) / 1024^3
}

# 1. Index ZIPs: download missing years; refresh the two most recent years,
# which the source updates weekly with resubmissions.
current_year <- as.integer(format(Sys.Date(), "%Y"))
for (form in forms) for (year in years) {
  target <- file.path(index_dir, sprintf("%s_cia_aberta_%d.zip", form, year))
  stale <- file.exists(target) && year >= current_year - 1 &&
    difftime(Sys.time(), file.mtime(target), units = "days") > 7
  if (file.exists(target) && !stale) next
  Sys.sleep(delay_seconds)
  partial <- paste0(target, ".part")
  response <- curl_fetch(cvm_index_zip_url(form, year), partial, user_agent)
  if (response$status == 200L && is_zip_file(partial)) {
    file.rename(partial, target)
    message(sprintf("index %s %d downloaded", form, year))
  } else {
    unlink(partial)
    message(sprintf("index %s %d not available (http %s)", form, year, response$status))
    if (response$status %in% c(403L, 429L)) stop("Access refused; stopping.")
  }
}

# 2. Catalog.
catalog <- build_financial_report_catalog(index_dir, forms, years)
utils::write.csv(catalog, file.path(data_dir, "catalog.csv"), row.names = FALSE,
                 fileEncoding = "UTF-8")
message(sprintf("Catalog: %d filing packages", nrow(catalog)))

# 3. Packages.
recorded <- download_financial_reports(
  catalog, raw_dir, file.path(data_dir, "manifest.csv"),
  user_agent = user_agent, delay_seconds = delay_seconds,
  max_reports = max_reports, min_free_gb = 20, free_gb = free_gb
)
if (nrow(recorded) > 0) print(table(recorded$outcome))
