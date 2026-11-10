# Run from the project root with Rscript --vanilla scripts/inspect_environment.R.
# This diagnostic does not search the project or inspect credentials.
cat(R.version.string, "\n")
for (package_name in c("renv", "testthat", "here", "jsonlite")) {
  installed <- requireNamespace(package_name, quietly = TRUE)
  version <- if (installed) as.character(packageVersion(package_name)) else "not_installed"
  cat(package_name, version, "\n")
}
cat("rtools_on_path=", nzchar(Sys.which("make")), "\n", sep = "")
