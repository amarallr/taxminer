# Start the local TaxMiner Shiny application (prototype/).
#   TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/run_prototype.R [port]
# Listens on 127.0.0.1 only.

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args)) as.integer(args[1]) else 8765L
shiny::runApp("prototype", host = "127.0.0.1", port = port, launch.browser = interactive())
