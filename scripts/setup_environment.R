# Offline bootstrap from existing libraries; no project dependency discovery.
if (!file.exists("taxminer.Rproj") || !file.exists("DESCRIPTION")) {
  stop("Run this script from the TaxMiner project root.")
}
Sys.setenv(
  RENV_PATHS_ROOT = file.path(getwd(), ".local", "renv"),
  RENV_CONFIG_CACHE_ENABLED = "FALSE",
  RENV_CONFIG_SANDBOX_ENABLED = "FALSE",
  RENV_CONFIG_AUTO_SNAPSHOT = "FALSE",
  RENV_CONFIG_SYNCHRONIZED_CHECK = "FALSE"
)
options(repos = c(CRAN = "https://cloud.r-project.org"))
source_libraries <- .libPaths()
if (!requireNamespace("renv", quietly = TRUE)) {
  stop("renv is missing. Install an approved version in a project-local library first.")
}
installed <- installed.packages(lib.loc = source_libraries)
required <- c("renv", "testthat")
dependencies <- tools::package_dependencies(
  required, db = installed, which = c("Depends", "Imports", "LinkingTo"),
  recursive = TRUE
)
required <- unique(c(required, unlist(dependencies, use.names = FALSE)))
required <- setdiff(required, "R")
missing <- setdiff(required, rownames(installed))
if (length(missing)) {
  stop("Offline bootstrap unavailable; missing packages: ", paste(missing, collapse = ", "))
}
required <- required[is.na(installed[required, "Priority"])]
if (!file.exists("renv/settings.json")) {
  renv::init(
    bare = TRUE, restart = FALSE, load = FALSE,
    settings = list(snapshot.type = "explicit", use.cache = FALSE),
    repos = getOption("repos")
  )
}
project_library <- renv::paths$library()
renv::hydrate(
  packages = required, sources = source_libraries,
  library = project_library, prompt = FALSE
)
renv::snapshot(library = project_library, type = "explicit", prompt = FALSE)
cat("Offline setup complete. Run scripts/validate_environment.R next.\n")
