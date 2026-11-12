# Downloads the "Empresas" files of the Receita Federal CNPJ open data
# (src/collect/collect_rfb_cnpj.R). Run from the project root:
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/collect_rfb_cnpj.R [yyyy-mm]
if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
for (f in c("src/common/signatures.R", "src/common/data_layout.R", "src/collect/download_fund_reports.R",
            "src/collect/collect_cvm_registries.R", "src/collect/collect_rfb_cnpj.R")) source(f, encoding = "UTF-8")
args <- commandArgs(trailingOnly = TRUE)
month <- collect_rfb_companies(cvm_registry_root(), month = if (length(args)) args[1] else NULL)
cat("Receita Federal CNPJ companies collected for", month, "\n")
