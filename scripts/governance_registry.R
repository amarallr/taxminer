# TaxMiner Governance registry command line (phase 02, req_0021).
# Run from the project root:
#   Rscript --vanilla scripts/governance_registry.R check
#   Rscript --vanilla scripts/governance_registry.R summary
#   Rscript --vanilla scripts/governance_registry.R trace --id=req_0021
#   Rscript --vanilla scripts/governance_registry.R add-request --summary="..." --classification=feature
#       --channel=claude_code --agent=claude_code [--requirements=req_0021] [--status=linked]
#   Rscript --vanilla scripts/governance_registry.R set --register=work_items --id=work_0033
#       --field=implementation_status --value=in_progress --actor=claude_code [--evidence=...]
# Prompt evolution (phase 06):
#   Rscript --vanilla scripts/governance_registry.R baseline --decision_id=decision_0047
#   Rscript --vanilla scripts/governance_registry.R propose-prompt --file=prompts/common_p08_governance_master.txt
#       --candidate=path --reason="..." --class=safe_operational --improvements="..." [--requirements=req_0021]
#   Rscript --vanilla scripts/governance_registry.R decide-prompt --id=prv_0004 --decision=approved
#       --approver=developer [--decision_id=decision_00NN]
#   Rscript --vanilla scripts/governance_registry.R add-plan --phase=... --summary="..." --reason="..."
#   Rscript --vanilla scripts/governance_registry.R prompt-report   (writes reports/governance/prompt_evolution.md)
# Agent integration (phase 04):
#   Rscript --vanilla scripts/governance_registry.R add-execution --agent=codex [--model=...] [--work_item=work_0035]
#       [--request=request_0007] [--state=running]
#   Rscript --vanilla scripts/governance_registry.R update-execution --id=exec_0001 --state=completed --actor=developer
#       [--outcome=...] [--input_tokens=N] [--output_tokens=N] [--cached_tokens=N] [--reported_cost=X]
#   Rscript --vanilla scripts/governance_registry.R reconcile [--max_hours=12]   (open executions without end -> unknown)
#   Rscript --vanilla scripts/governance_registry.R capability-report   (writes reports/governance/capability_matrix.md)
# Planning and context optimization (phase 03):
#   Rscript --vanilla scripts/governance_registry.R plan-report   (writes reports/governance/planning_report.md)
#   Rscript --vanilla scripts/governance_registry.R plan --id=req_0014
#   Rscript --vanilla scripts/governance_registry.R dedup --text="..." [--module=collect]
#   Rscript --vanilla scripts/governance_registry.R context --id=req_0021 [--budget=20000]
#   Rscript --vanilla scripts/governance_registry.R reconcile-requirements   (proposals only)
#   Rscript --vanilla scripts/governance_registry.R reconcile-requirements --apply=req_0001,req_0002
#       --decision_id=decision_00NN   (only proposals the developer approved, one by one)
# `check` also verifies the immutable layer (AGENTS.md, CLAUDE.md, Common P01, Common P08 section 12).
# Reads and writes docs/project_management/ and reports/governance/ under --root (default "."). Exit status 1 on
# integrity problems or invalid input.

source("src/common/governance_registry.R")
source("src/common/governance_prompts.R")
source("src/common/governance_agents.R")
source("src/common/governance_metrics.R")
source("src/common/governance_planning.R")

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
root <- opt("root", ".")
dir <- governance_pm_dir(root)

report_problems <- function() {
  p <- rbind(governance_check(governance_read(dir)), governance_immutable_check(root))
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
} else if (command == "baseline") {
  governance_record_baseline(root, opt("decision_id"), opt("actor", "developer"))
  cat("Baseline recorded\n")
  report_problems()
} else if (command == "propose-prompt") {
  id <- governance_propose_prompt(root, opt("file"), opt("candidate"), opt("reason"), opt("class"),
                                  opt("improvements"), opt("requirements", ""), opt("actor", "claude_code"))
  cat("Proposed", id, "- diff in reports/governance/", paste0(id, ".diff"), "\n")
  report_problems()
} else if (command == "decide-prompt") {
  governance_decide_prompt(root, opt("id"), opt("decision"), opt("approver"), opt("decision_id", ""))
  cat("Recorded", opt("decision"), "for", opt("id"), "\n")
  report_problems()
} else if (command == "add-plan") {
  cat("Recorded", governance_add_plan_revision(root, opt("phase"), opt("summary"), opt("reason"), opt("evidence", "")), "\n")
  report_problems()
} else if (command == "add-execution") {
  id <- governance_start_execution(dir, opt("agent"), opt("model", ""), opt("session", ""), opt("work_item", ""),
                                   opt("request", ""), opt("state", "running"), opt("evidence", "manual"))
  cat("Registered", id, "\n")
  report_problems()
} else if (command == "update-execution") {
  tokens <- list()
  for (f in c("input_tokens", "output_tokens", "cached_tokens", "reported_cost")) {
    if (!is.null(opts[[f]])) tokens[[f]] <- opts[[f]]
  }
  governance_update_execution(dir, opt("id"), opt("state"), opt("actor"), opts$outcome, tokens,
                              opt("evidence", ""))
  cat("Updated", opt("id"), "\n")
  report_problems()
} else if (command == "reconcile") {
  stale <- governance_reconcile_executions(dir, as.numeric(opt("max_hours", "12")))
  cat("Marked unknown:", if (length(stale)) paste(stale, collapse = " ") else "none", "\n")
  report_problems()
} else if (command == "capability-report") {
  out <- file.path(root, "reports", "governance", "capability_matrix.md")
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(governance_capability_report()), out, useBytes = TRUE)
  cat("Written", out, "\n")
} else if (command == "prompt-report") {
  out <- file.path(root, "reports", "governance", "prompt_evolution.md")
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(governance_prompt_report(root)), out, useBytes = TRUE)
  cat("Written", out, "\n")
} else if (command == "plan-report") {
  out <- file.path(root, "reports", "governance", "planning_report.md")
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(governance_planning_report(governance_read(dir))), out, useBytes = TRUE)
  cat("Written", out, "\n")
} else if (command == "plan") {
  p <- governance_plan_requirement(governance_read(dir), opt("id"))
  cat(sprintf("%s | status %s (items support: %s) | complexity %s | effort %s days (n=%d) | tokens %s | agent %s\n",
              opt("id"), p$requirement$status, p$status_supported, p$complexity$level,
              format(p$effort_days$value), p$effort_days$sample, format(p$tokens$value), p$agent$recommended))
  print(p$tasks, row.names = FALSE)
  if (length(p$risks)) cat("Risks:", paste(p$risks, collapse = "; "), "\n")
} else if (command == "dedup") {
  print(governance_dedup(governance_read(dir), opt("text"), opt("module", ""))[, 1:6], row.names = FALSE)
} else if (command == "context") {
  print(governance_context_pack(root, governance_read(dir), opt("id"), as.integer(opt("budget", "20000"))),
        row.names = FALSE)
} else if (command == "reconcile-requirements") {
  if (is.null(opts$apply)) {
    print(governance_reconcile_requirements(governance_read(dir))[, 1:9], row.names = FALSE)
  } else {
    t <- governance_apply_requirement_status(dir, strsplit(opt("apply"), ",", fixed = TRUE)[[1]], opt("decision_id"),
                                             opt("actor", "developer"))
    cat("Recorded", paste(t, collapse = " "), "\n")
    report_problems()
  }
} else {
  stop("Unknown command: ", command, call. = FALSE)
}
