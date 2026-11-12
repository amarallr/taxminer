# TaxMiner Governance registry command line (phase 02, req_0021).
# Run from the project root:
#   Rscript --vanilla scripts/governance_registry.R check
#   Rscript --vanilla scripts/governance_registry.R summary
#   Rscript --vanilla scripts/governance_registry.R trace --id=req_0021
#   Rscript --vanilla scripts/governance_registry.R add-request --summary="..." --classification=feature
#       --channel=claude_code --agent=claude_code [--requirements=req_0021] [--status=linked]
#   Rscript --vanilla scripts/governance_registry.R set --register=work_items --id=work_0033
#       --field=implementation_status --value=in_progress --actor=claude_code [--evidence=...]
# Reads and writes only docs/project_management/ (override with --dir=). Exit status 1 on
# integrity problems or invalid input.

source("src/common/governance_registry.R")

args <- commandArgs(trailingOnly = TRUE)
command <- if (length(args)) args[1] else "check"
opts <- list()
for (a in args[-1]) {
  m <- regmatches(a, regexec("^--([a-z_]+)=(.*)$", a))[[1]]
  if (length(m) != 3L) stop("Unrecognized argument: ", a, call. = FALSE)
  opts[[m[2]]] <- m[3]
}
opt <- function(name, default = NULL) {
  v <- opts[[name]]
  if (is.null(v)) {
    if (is.null(default)) stop("Missing --", name, call. = FALSE)
    return(default)
  }
  v
}
dir <- opt("dir", "docs/project_management")

report_problems <- function() {
  p <- governance_check(governance_read(dir))
  if (nrow(p)) {
    cat(sprintf("%d integrity problem(s):\n", nrow(p)))
    print(p, row.names = FALSE)
    quit(status = 1L)
  }
  cat("Integrity: ok\n")
}

if (command == "check") {
  report_problems()
} else if (command == "summary") {
  s <- governance_summary(governance_read(dir))
  cat(sprintf("Requests: %d | acceptances: %d | open risks: %d | transitions: %d | pending human decisions: %d\n",
              s$requests, s$acceptances, s$open_risks, s$transitions, s$pending_human_decisions))
  cat("Requirements:", paste(names(s$requirements), s$requirements, collapse = ", "), "\n")
  for (d in names(s$work_items)) cat(d, ":", paste(names(s$work_items[[d]]), s$work_items[[d]], collapse = ", "), "\n")
  cat("Tests:", paste(names(s$tests), s$tests, collapse = ", "), "\n")
} else if (command == "trace") {
  t <- governance_trace(governance_read(dir), opt("id"))
  for (n in names(t)) {
    cat("\n==", governance_specs[[n]]$file, "\n")
    print(t[[n]][, intersect(names(t[[n]]), c(governance_specs[[n]]$id, "requirement_id", "work_item_id",
                                               "entity_id", "field", "to_status", "status", "title", "summary",
                                               "decision")), drop = FALSE], row.names = FALSE)
  }
} else if (command == "add-request") {
  id <- governance_add_request(dir, opt("summary"), opt("classification"), opt("channel", "manual"),
                               opt("agent", "developer"), opt("requirements", ""), opt("status", "captured"))
  cat("Registered", id, "\n")
  report_problems()
} else if (command == "set") {
  t <- governance_set_field(dir, opt("register"), opt("id"), opt("field"), opt("value"), opt("actor"),
                            opt("evidence", ""))
  cat(if (is.null(t)) "No change\n" else paste("Recorded", t, "\n"))
  report_problems()
} else {
  stop("Unknown command: ", command, call. = FALSE)
}
