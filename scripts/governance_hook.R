# TaxMiner Governance — Claude Code hook entry point (phase 04, req_0021).
# NOT INSTALLED. Installing it in .claude/settings*.json needs the developer's own
# confirmation (prompt rule P9); see docs/governance_plan.md section 17.
#
# Reads the hook input (JSON) from stdin and records it through
# src/common/governance_agents.R:
#   UserPromptSubmit -> request (minimized summary) + running execution
#   Stop / SessionEnd -> completes the session's open executions
# Prints nothing to stdout (UserPromptSubmit stdout would enter the agent
# context) and always exits 0, so a failure never blocks the session (risk R2);
# failures go to stderr.
#
# Options:
#   --root=.                      project root (default: current folder)
#   --tokens_decision=decision_N  enables transcript token reading (P9); without
#                                 it the transcript is never opened
#   --transcripts=DIR             folder transcripts must be under (with tokens_decision)

status <- tryCatch({
  source("src/common/governance_registry.R")
  source("src/common/governance_prompts.R")
  source("src/common/governance_agents.R")
  args <- commandArgs(trailingOnly = TRUE)
  opts <- list()
  for (a in args) {
    m <- regmatches(a, regexec("^--([a-z_]+)=(.*)$", a))[[1]]
    if (length(m) == 3L) opts[[m[2]]] <- m[3]
  }
  root <- if (is.null(opts$root)) "." else opts$root
  reader <- NULL
  if (!is.null(opts$tokens_decision) && !is.null(opts$transcripts)) {
    reader <- function(path) governance_transcript_tokens(root, path, opts$tokens_decision, opts$transcripts)
  }
  text <- readLines(file("stdin"), warn = FALSE, encoding = "UTF-8")
  governance_hook_safe(governance_pm_dir(root), text, token_reader = reader)
}, error = function(e) paste("error:", conditionMessage(e)))

if (startsWith(status, "error:")) message("governance hook: ", status)
quit(status = 0L, save = "no")
