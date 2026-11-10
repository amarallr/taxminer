# Run from the RStudio console with the TaxMiner project open.
stopifnot(identical(Sys.getenv("RSTUDIO"), "1"))
stopifnot(file.exists("taxminer.Rproj"))
terminal_execute <- get(".rs.api.terminalExecute", mode = "function")
writeLines(
  c(paste("requested_at:", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    paste("rstudio:", Sys.getenv("RSTUDIO")),
    paste("working_directory:", getwd())),
  "reports/execution/rstudio_validation_dispatch.txt"
)
terminal_execute(
  "powershell.exe -NoProfile -File scripts/validate_rstudio_terminal.ps1",
  workingDir = getwd()
)
