# CI only: install locked packages that renv::restore cannot order. When a
# locked version has no Windows binary left on CRAN, renv builds it from source
# and reports a false cycle (seen for magrittr <-> testthat,
# curl <-> qpdf <-> pdftools and arrow <-> cpp11; shiny, bslib and otel are
# locked behind CRAN as well). This script installs those
# packages at their exact locked versions, in dependency order, outside the
# renv resolver: the CRAN binary when CRAN still offers that exact version,
# otherwise the locked source tarball. renv::restore then finds them in place
# and sets every other package to its locked version.
# Usage: Rscript scripts/ci_preinstall_locked.R

repos <- "https://cloud.r-project.org"
lib <- renv::paths$library()
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
lock <- renv::lockfile_read("renv.lock")
binaries <- utils::available.packages(repos = repos, type = "binary")

installed_version <- function(package) {
  tryCatch(as.character(utils::packageVersion(package, lib.loc = lib)), error = function(e) NA_character_)
}

# `deps` are build-time imports installed from binaries at any version first;
# renv::restore later sets their locked versions.
install_locked <- function(package, deps = character()) {
  version <- lock$Packages[[package]]$Version
  if (is.null(version)) stop("Not in renv.lock: ", package)
  missing <- deps[is.na(vapply(deps, installed_version, character(1)))]
  if (length(missing) > 0) {
    utils::install.packages(missing, lib = lib, repos = repos, type = "binary")
  }
  if (package %in% rownames(binaries) && identical(binaries[package, "Version"], version)) {
    utils::install.packages(package, lib = lib, repos = repos, type = "binary",
                            dependencies = FALSE)
  } else {
    urls <- sprintf(c("%1$s/src/contrib/Archive/%2$s/%2$s_%3$s.tar.gz",
                      "%1$s/src/contrib/%2$s_%3$s.tar.gz"), repos, package, version)
    for (url in urls) {
      # A missing URL only warns; the installed version decides success.
      tryCatch(utils::install.packages(url, repos = NULL, type = "source", lib = lib),
               error = function(e) message(conditionMessage(e)))
      if (identical(installed_version(package), version)) break
    }
  }
  if (!identical(installed_version(package), version)) {
    stop(sprintf("Could not install %s %s.", package, version))
  }
  message(sprintf("Installed %s %s", package, version))
}

install_locked("magrittr")
install_locked("curl")
install_locked("qpdf", deps = c("Rcpp", "askpass", "sys"))
install_locked("pdftools", deps = "Rcpp")
install_locked("cpp11")
install_locked("arrow", deps = c("assertthat", "bit64", "glue", "purrr", "R6", "rlang",
                                 "tidyselect", "vctrs"))
install_locked("otel")
install_locked("bslib", deps = c("base64enc", "cachem", "fastmap", "htmltools", "jquerylib",
                                 "jsonlite", "lifecycle", "memoise", "mime", "rlang", "sass"))
install_locked("shiny", deps = c("cli", "commonmark", "glue", "httpuv", "jsonlite", "later",
                                 "lifecycle", "mime", "promises", "R6", "rlang", "sourcetools",
                                 "withr", "xtable", "fontawesome", "cachem", "fastmap",
                                 "htmltools"))
