# Run only from the TaxMiner RStudio console with the project open.
stopifnot(identical(Sys.getenv("RSTUDIO"), "1"))
stopifnot(file.exists("taxminer.Rproj"))
stopifnot(dir.exists("reports/execution"))

terminal_execute <- get(".rs.api.terminalExecute", mode = "function")
terminal_execute(
  "powershell.exe -NoProfile -File scripts/smoke_test_agent_clis_rstudio.ps1",
  workingDir = getwd()
)
