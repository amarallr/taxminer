# Downloads the CVM fund, fund/class and listed company registries
# (src/collect/collect_cvm_registries.R). Run from the project root:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/collect_cvm_registries.R
if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
for (f in c("src/common/signatures.R", "src/common/data_layout.R", "src/collect/download_fund_reports.R",
            "src/collect/collect_cvm_registries.R")) source(f, encoding = "UTF-8")
rows <- collect_cvm_registries()
print(rows[, c("file_name", "outcome", "http_status", "bytes", "raw_path")], row.names = FALSE)
