# CI only: install locked packages that renv::restore cannot order. When a
# locked version has no Windows binary left on CRAN, renv builds it from source
# and reports a false cycle (seen for magrittr <-> testthat and
# curl <-> qpdf <-> pdftools). This script installs those packages from their
# exact locked source tarballs, in dependency order, outside the renv resolver;
# renv::restore then finds them already at the locked versions.
# Usage: Rscript scripts/ci_preinstall_locked.R

repos <- "https://cloud.r-project.org"
lib <- renv::paths$library()
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
lock <- renv::lockfile_read("renv.lock")

install_locked_source <- function(package) {
  version <- lock$Packages[[package]]$Version
  if (is.null(version)) stop("Not in renv.lock: ", package)
  urls <- sprintf(c("%1$s/src/contrib/Archive/%2$s/%2$s_%3$s.tar.gz",
                    "%1$s/src/contrib/%2$s_%3$s.tar.gz"), repos, package, version)
  for (url in urls) {
    # A missing URL only warns; the installed version decides success.
    tryCatch(utils::install.packages(url, repos = NULL, type = "source", lib = lib),
             error = function(e) message(conditionMessage(e)))
    installed <- tryCatch(as.character(utils::packageVersion(package, lib.loc = lib)),
                          error = function(e) NA_character_)
    if (identical(installed, version)) {
      message(sprintf("Installed %s %s from %s", package, version, url))
      return(invisible(TRUE))
    }
  }
  stop(sprintf("Could not install %s %s from source.", package, version))
}

# magrittr has no compiled dependencies.
install_locked_source("magrittr")
# Build-time imports of qpdf and pdftools; renv::restore later sets their locked
# versions.
utils::install.packages(c("Rcpp", "askpass", "sys"), lib = lib, repos = repos, type = "binary")
for (package in c("curl", "qpdf", "pdftools")) install_locked_source(package)
