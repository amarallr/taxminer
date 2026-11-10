# Project-scoped paths; no user/global configuration changes.
Sys.setenv(
  RENV_PATHS_ROOT = file.path(getwd(), ".local", "renv"),
  RENV_CONFIG_CACHE_ENABLED = "FALSE",
  RENV_CONFIG_SANDBOX_ENABLED = "FALSE",
  RENV_CONFIG_AUTO_SNAPSHOT = "FALSE",
  RENV_CONFIG_SYNCHRONIZED_CHECK = "FALSE"
)
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
} else {
  message("Project dependencies are not initialized. See README.md.")
}
