# Owner-only features (Governança tab, installer generation): enabled only on a
# machine where the owner set the user environment variable TAXMINER_OWNER_MODE=1.
# The variable lives in the owner's Windows user profile, never in the repository,
# the published page or any installer. Everyone else gets the features hidden or
# refused. Note: the code is public, so this is an access convention for the
# distributed app and scripts, not a protection of data that is already public.
taxminer_owner_mode <- function() identical(Sys.getenv("TAXMINER_OWNER_MODE"), "1")

# Stops owner-only scripts on any other machine.
taxminer_require_owner <- function(feature) {
  if (!taxminer_owner_mode()) {
    stop(sprintf("%s está disponível somente para o proprietário do projeto.", feature), call. = FALSE)
  }
  invisible(TRUE)
}
