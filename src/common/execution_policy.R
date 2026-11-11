# Shared execution policy and attempt registry (Common P07 stage 02,
# decision_0023). Base R only. Re-implemented from requirements, not copied.
# source() only defines functions. Requires src/common/safe_io.R.

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::resolver_politica_execucao (P02-FUN-003, P02-RF-006)
# Pure policy: reusing checkpoints never forces a download by itself.
# - download: refresh requested or reprocessing forced;
# - reuse_checkpoint: checkpoints enabled and reprocessing not forced.
resolve_execution_policy <- function(use_checkpoints = TRUE, refresh_downloads = FALSE,
                                     force_reprocessing = FALSE) {
  flags <- list(use_checkpoints, refresh_downloads, force_reprocessing)
  if (!all(vapply(flags, function(v) is.logical(v) && length(v) == 1L && !is.na(v), logical(1)))) {
    stop("Execution policy flags must be single TRUE/FALSE values.", call. = FALSE)
  }
  list(download = refresh_downloads || force_reprocessing,
       reuse_checkpoint = use_checkpoints && !force_reprocessing)
}

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::registrar_tentativa (P02-FUN-013)
# Records an attempt of `stage` as `attempts/{id}.rds` and `last_attempt.rds`
# under `state_dir` (relative to `root`), with status `in_progress`. Returns a
# function `finish(status, reason, details)` that records the final status
# (`completed` or `failed`). An attempt left `in_progress` reveals an abrupt
# stop. The configuration is stored as given; it must not contain secrets.
record_attempt <- function(stage, config, state_dir, root = ".") {
  id <- basename(tempfile(sprintf("%s-%d-", stage, Sys.getpid())))
  attempt <- list(attempt_id = id, stage = stage, pid = Sys.getpid(),
                  started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                  finished_at = NA_character_, status = "in_progress",
                  reason = NA_character_, details = NULL, config = config)
  targets <- c(validate_contained_path(root, file.path(state_dir, "attempts", paste0(id, ".rds"))),
               validate_contained_path(root, file.path(state_dir, "last_attempt.rds")))
  persist <- function() for (target in targets) write_validated_atomic(attempt, target, "rds")
  persist()
  function(status = c("completed", "failed"), reason = NA_character_, details = NULL) {
    attempt$status <<- match.arg(status)
    attempt$reason <<- reason
    attempt$details <<- details
    attempt$finished_at <<- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    persist()
    invisible(attempt)
  }
}
