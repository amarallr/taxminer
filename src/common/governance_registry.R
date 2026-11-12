# TaxMiner Governance — requirements registry (phase 02, req_0021, decision_0044).
# Reads, validates and updates the governance records in docs/project_management/
# (Common P01 registers plus the governance registers). Base R only.
# source() only defines functions: no file access, no network, no side effects.
#
# Rules (prompts/common_p08_governance_master.txt v1.1, prompts/common_p01_lifecycle_management.txt):
# - IDs are lowercase_snake, unique, immutable and never renumbered.
# - Every status change goes through governance_set_field(), which also appends a
#   row to state_transitions.csv; nothing is ever deleted.
# - A request keeps only a short, minimized summary: no protected path names, no
#   e-mail addresses, no line breaks (risk_0018).
# - Registers are rewritten in their own format (all fields quoted in
#   work_items.csv, unquoted elsewhere), checked by reading them back, and
#   replaced atomically.

# Register specifications: file, ID column and prefix, foreign keys
# (column -> prefixes it may reference; ";" separates several IDs) and
# controlled vocabularies.
governance_specs <- list(
  requirements = list(file = "requirements_register.csv", id = "requirement_id", prefix = "req",
                      columns = c("requirement_id", "module", "description", "source", "priority",
                                  "acceptance_criteria", "status", "owner", "updated_at"),
                      vocab = list(status = c("proposed", "accepted", "captured", "under_analysis", "planned",
                                              "awaiting_approval", "approved", "in_progress", "blocked",
                                              "implemented", "under_testing", "tested", "awaiting_acceptance",
                                              "rejected", "cancelled")),
                      times = "updated_at", quote = FALSE),
  work_items = list(file = "work_items.csv", id = "work_item_id", prefix = "work",
                    columns = c("work_item_id", "module", "requirement_id", "title", "type", "priority", "owner",
                                "dependencies", "implementation_status", "test_status", "acceptance_status",
                                "release_status", "operations_status", "evidence_links", "updated_at"),
                    refs = list(requirement_id = "req", dependencies = "work"),
                    vocab = list(implementation_status = c("not_started", "in_progress", "implemented", "blocked"),
                                 test_status = c("not_run", "passed", "failed", "blocked", "not_applicable"),
                                 acceptance_status = c("pending", "approved", "rejected", "not_applicable"),
                                 release_status = c("not_released", "approved_for_release", "released",
                                                    "rolled_back", "blocked"),
                                 operations_status = c("not_started", "healthy", "degraded", "failed",
                                                       "not_applicable")),
                    times = "updated_at", quote = TRUE),
  tests = list(file = "test_register.csv", id = "test_id", prefix = "test",
               columns = c("test_id", "work_item_id", "level", "environment", "execution_timestamp", "result",
                           "evidence_path", "code_commit"),
               refs = list(work_item_id = "work"),
               vocab = list(result = c("passed", "failed", "blocked", "skipped")),
               times = "execution_timestamp", quote = FALSE),
  acceptances = list(file = "acceptance_register.csv", id = "acceptance_id", prefix = "acc",
                     columns = c("acceptance_id", "work_item_id", "criteria", "reviewer", "decision",
                                 "decision_timestamp", "evidence_path", "notes"),
                     refs = list(work_item_id = "work"),
                     vocab = list(decision = c("approved", "rejected")),
                     times = "decision_timestamp", quote = FALSE),
  risks = list(file = "risk_register.csv", id = "risk_id", prefix = "risk",
               columns = c("risk_id", "description", "likelihood", "impact", "mitigation", "owner", "status"),
               vocab = list(status = c("open", "mitigated", "accepted", "closed")), quote = FALSE),
  requests = list(file = "request_register.csv", id = "request_id", prefix = "request",
                  columns = c("request_id", "received_at", "channel", "agent", "summary", "classification",
                              "requirement_ids", "status", "updated_at"),
                  refs = list(requirement_ids = "req"),
                  vocab = list(classification = c("feature", "bug", "refactoring", "performance", "security",
                                                  "documentation", "data_engineering", "analytics", "ui_ux",
                                                  "testing", "research", "question", "operational_command",
                                                  "architecture", "technical_debt"),
                               status = c("captured", "under_analysis", "linked", "answered", "rejected",
                                          "cancelled"),
                               channel = c("claude_code", "codex", "github_copilot", "gemini_cli", "manual")),
                  times = c("received_at", "updated_at"), quote = FALSE),
  transitions = list(file = "state_transitions.csv", id = "transition_id", prefix = "trn",
                     columns = c("transition_id", "entity_id", "field", "from_status", "to_status", "changed_at",
                                 "actor", "evidence"),
                     refs = list(entity_id = c("req", "work", "test", "acc", "risk", "request", "prv", "plan", "imm")),
                     times = "changed_at", quote = FALSE),
  prompt_revisions = list(file = "prompt_revisions.csv", id = "revision_id", prefix = "prv",
                          columns = c("revision_id", "prompt_file", "version", "previous_version", "revised_at",
                                      "reason", "change_class", "improvements", "affected_requirements",
                                      "base_commit", "validation", "approval", "approver"),
                          refs = list(affected_requirements = "req"),
                          vocab = list(approval = c("proposed", "approved", "rejected")),
                          times = "revised_at", quote = FALSE),
  planning_revisions = list(file = "planning_revisions.csv", id = "plan_id", prefix = "plan",
                            columns = c("plan_id", "revised_at", "phase", "summary", "reason", "approval", "evidence"),
                            vocab = list(approval = c("proposed", "approved", "rejected")),
                            times = "revised_at", quote = FALSE),
  # Fingerprints of the immutable layer (phase 06, src/common/governance_prompts.R).
  immutable_rules = list(file = "immutable_rules.csv", id = "rule_id", prefix = "imm",
                         columns = c("rule_id", "file", "section", "sha256", "recorded_at", "decision"),
                         times = "recorded_at", quote = FALSE)
)

# Reads every register as character columns ("" for empty). Missing optional
# registers become empty tables with the expected columns.
governance_read <- function(dir) {
  lapply(governance_specs, function(spec) {
    path <- file.path(dir, spec$file)
    if (!file.exists(path)) {
      return(as.data.frame(stats::setNames(replicate(length(spec$columns), character(), simplify = FALSE),
                                           spec$columns), stringsAsFactors = FALSE))
    }
    utils::read.csv(path, colClasses = "character", na.strings = character(), check.names = FALSE,
                    encoding = "UTF-8", stringsAsFactors = FALSE)
  })
}

split_ids <- function(x) {
  out <- trimws(unlist(strsplit(x, ";", fixed = TRUE), use.names = FALSE))
  out[nzchar(out)]
}

# ISO 8601 date-time with offset (or "unknown", accepted in old test rows).
is_iso_timestamp <- function(x) {
  x == "unknown" | grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}(:\\d{2})?([+-]\\d{2}:\\d{2}|Z)$", x)
}

# Integrity check: returns a data frame register/id/problem (zero rows = ok).
governance_check <- function(regs) {
  problems <- list()
  add <- function(register, id, problem) {
    problems[[length(problems) + 1L]] <<- data.frame(register = register, id = id, problem = problem,
                                                     stringsAsFactors = FALSE)
  }
  known <- unlist(lapply(names(governance_specs), function(n) regs[[n]][[governance_specs[[n]]$id]]),
                  use.names = FALSE)
  for (n in names(governance_specs)) {
    spec <- governance_specs[[n]]
    x <- regs[[n]]
    missing_cols <- setdiff(spec$columns, names(x))
    if (length(missing_cols)) {
      add(n, "", paste("missing columns:", paste(missing_cols, collapse = " ")))
      next
    }
    ids <- x[[spec$id]]
    for (i in ids[duplicated(ids)]) add(n, i, "duplicated id")
    for (i in ids[!grepl(sprintf("^%s_\\d{4}$", spec$prefix), ids)]) add(n, i, "id outside the pattern")
    for (col in names(spec$refs)) {
      pattern <- sprintf("^(%s)_\\d{4}$", paste(spec$refs[[col]], collapse = "|"))
      for (k in seq_len(nrow(x))) {
        for (ref in split_ids(x[[col]][k])) {
          if (!grepl(pattern, ref)) add(n, ids[k], sprintf("%s: '%s' is not a valid reference", col, ref))
          else if (!ref %in% known) add(n, ids[k], sprintf("%s: '%s' does not exist", col, ref))
        }
      }
    }
    for (col in names(spec$vocab)) {
      bad <- !x[[col]] %in% spec$vocab[[col]]
      for (k in which(bad)) add(n, ids[k], sprintf("%s: '%s' outside the vocabulary", col, x[[col]][k]))
    }
    for (col in spec$times) {
      v <- x[[col]]
      for (k in which(nzchar(v) & !is_iso_timestamp(v))) add(n, ids[k], sprintf("%s: '%s' is not ISO 8601", col, v[k]))
    }
  }
  # Common P01: an approved work item needs an approved acceptance row.
  w <- regs$work_items
  a <- regs$acceptances
  if (all(c("acceptance_status", "work_item_id") %in% names(w)) && "decision" %in% names(a)) {
    approved_rows <- a$work_item_id[a$decision == "approved"]
    for (i in w$work_item_id[w$acceptance_status == "approved" & !w$work_item_id %in% approved_rows]) {
      add("work_items", i, "acceptance approved without an approved row in acceptance_register.csv")
    }
  }
  if (!length(problems)) {
    return(data.frame(register = character(), id = character(), problem = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, problems)
}

# Next free ID for a prefix, never reusing a number.
governance_next_id <- function(ids, prefix) {
  n <- suppressWarnings(as.integer(sub(sprintf("^%s_", prefix), "", ids[grepl(sprintf("^%s_\\d+$", prefix), ids)])))
  sprintf("%s_%04d", prefix, if (length(n)) max(n) + 1L else 1L)
}

# Minimized summary of a request (risk_0018): one line, at most 200 characters,
# no protected path names and no e-mail addresses.
governance_check_summary <- function(summary) {
  if (length(summary) != 1L || is.na(summary) || !nzchar(trimws(summary))) stop("Summary is empty.", call. = FALSE)
  if (grepl("[\r\n]", summary)) stop("Summary must be a single line.", call. = FALSE)
  if (nchar(summary) > 200L) stop("Summary longer than 200 characters; record a short summary.", call. = FALSE)
  if (grepl("(^|[^A-Za-z0-9_])\\.?(restricted|tmp)[/\\\\]", summary, ignore.case = TRUE)) {
    stop("Summary mentions a protected area path.", call. = FALSE)
  }
  if (grepl("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", summary)) {
    stop("Summary contains an e-mail address.", call. = FALSE)
  }
  trimws(summary)
}

# Text of a register in its own format: every field quoted (quote = TRUE) or no
# quoting at all, in which case a value with a comma, quote or line break is refused.
governance_format <- function(x, quote) {
  cells <- as.matrix(x)
  cells[is.na(cells)] <- ""
  if (quote) {
    esc <- function(v) paste0('"', gsub('"', '""', v, fixed = TRUE), '"')
    lines <- c(paste(esc(names(x)), collapse = ","), apply(cells, 1L, function(r) paste(esc(r), collapse = ",")))
  } else {
    if (any(grepl("[,\"\r\n]", cells))) stop("A value has a comma, quote or line break; use ';' instead.", call. = FALSE)
    lines <- c(paste(names(x), collapse = ","), if (nrow(x)) apply(cells, 1L, paste, collapse = ","))
  }
  paste0(paste(lines, collapse = "\n"), "\n")
}

# Writes a register atomically: temporary file in the same folder, read back and
# compared, previous version kept as .rollback until the rename succeeds.
governance_write <- function(dir, name, x) {
  spec <- governance_specs[[name]]
  path <- file.path(dir, spec$file)
  temporary <- tempfile(".governance-", tmpdir = dir)
  on.exit(unlink(temporary), add = TRUE)
  text <- charToRaw(enc2utf8(governance_format(x, spec$quote)))
  con <- file(temporary, open = "wb")
  writeBin(text, con)
  close(con)
  back <- utils::read.csv(temporary, colClasses = "character", na.strings = character(), check.names = FALSE,
                          encoding = "UTF-8", stringsAsFactors = FALSE)
  y <- x
  y[] <- lapply(y, function(v) { v[is.na(v)] <- ""; as.character(v) })
  if (!identical(unname(as.list(back)), unname(as.list(y))) || !identical(names(back), names(x))) {
    stop("Register differs after write: ", spec$file, call. = FALSE)
  }
  backup <- paste0(path, ".rollback")
  if (file.exists(backup)) stop("Pending rollback kept for review: ", backup, call. = FALSE)
  existed <- file.exists(path)
  if (existed && !file.rename(path, backup)) stop("Register locked: ", path, call. = FALSE)
  if (!file.rename(temporary, path)) {
    if (existed) file.rename(backup, path)
    stop("Register not replaced; previous version kept: ", path, call. = FALSE)
  }
  if (existed) unlink(backup)
  invisible(path)
}

governance_now <- function() {
  x <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  sub("(\\d{2})(\\d{2})$", "\\1:\\2", x)
}

# Appends a state transition (the audit trail); returns its ID.
governance_record_transition <- function(dir, entity_id, field, from, to, actor, evidence = "",
                                         at = governance_now()) {
  regs <- governance_read(dir)
  tr <- regs$transitions
  id <- governance_next_id(tr$transition_id, "trn")
  row <- data.frame(transition_id = id, entity_id = entity_id, field = field, from_status = from,
                    to_status = to, changed_at = at, actor = actor, evidence = evidence, stringsAsFactors = FALSE)
  governance_write(dir, "transitions", rbind(tr, row[names(tr)]))
  id
}

# Changes one field of one record and records the transition. Refuses unknown
# IDs, values outside the vocabulary and changes of the ID itself.
governance_set_field <- function(dir, name, id, field, value, actor, evidence = "", at = governance_now()) {
  spec <- governance_specs[[name]]
  if (is.null(spec)) stop("Unknown register: ", name, call. = FALSE)
  if (identical(field, spec$id)) stop("IDs are immutable.", call. = FALSE)
  regs <- governance_read(dir)
  x <- regs[[name]]
  k <- which(x[[spec$id]] == id)
  if (length(k) != 1L) stop("Unknown id in ", spec$file, ": ", id, call. = FALSE)
  if (!field %in% names(x)) stop("Unknown field: ", field, call. = FALSE)
  if (!is.null(spec$vocab[[field]]) && !value %in% spec$vocab[[field]]) {
    stop(sprintf("'%s' is outside the vocabulary of %s.", value, field), call. = FALSE)
  }
  from <- x[[field]][k]
  if (identical(from, value)) return(invisible(NULL))
  x[[field]][k] <- value
  if ("updated_at" %in% names(x)) x$updated_at[k] <- at
  regs[[name]] <- x
  problems <- governance_check(regs)
  if (nrow(problems)) stop("Change would break integrity: ", problems$problem[1], call. = FALSE)
  governance_write(dir, name, x)
  invisible(governance_record_transition(dir, id, field, from, value, actor, evidence, at))
}

# Registers a request with a minimized summary; returns its ID.
governance_add_request <- function(dir, summary, classification, channel, agent, requirement_ids = "",
                                   status = "captured", received_at = governance_now()) {
  summary <- governance_check_summary(summary)
  regs <- governance_read(dir)
  rq <- regs$requests
  id <- governance_next_id(rq$request_id, "request")
  row <- data.frame(request_id = id, received_at = received_at, channel = channel, agent = agent,
                    summary = gsub(",", ";", summary, fixed = TRUE), classification = classification,
                    requirement_ids = requirement_ids, status = status, updated_at = received_at,
                    stringsAsFactors = FALSE)
  regs$requests <- rbind(rq, row[names(rq)])
  problems <- governance_check(regs)
  problems <- problems[problems$register == "requests" & problems$id == id, , drop = FALSE]
  if (nrow(problems)) stop("Invalid request: ", paste(problems$problem, collapse = "; "), call. = FALSE)
  governance_write(dir, "requests", regs$requests)
  governance_record_transition(dir, id, "status", "", status, agent, "request_register.csv", received_at)
  id
}

# Traceability of one ID: the records that cite it and the records it cites.
governance_trace <- function(regs, id) {
  out <- list()
  for (n in names(governance_specs)) {
    spec <- governance_specs[[n]]
    x <- regs[[n]]
    if (!nrow(x)) next
    self <- x[[spec$id]] == id
    cites <- Reduce(`|`, lapply(names(spec$refs), function(col) vapply(x[[col]], function(v) id %in% split_ids(v), logical(1))),
                    rep(FALSE, nrow(x)))
    if (any(self | cites)) out[[n]] <- x[self | cites, , drop = FALSE]
  }
  out
}

# Counts used by the reports and, later, by the dashboard.
governance_summary <- function(regs) {
  w <- regs$work_items
  dims <- c("implementation_status", "test_status", "acceptance_status", "release_status", "operations_status")
  list(
    requests = nrow(regs$requests),
    requirements = table(regs$requirements$status),
    work_items = lapply(stats::setNames(dims, dims), function(d) table(w[[d]])),
    tests = table(regs$tests$result),
    acceptances = nrow(regs$acceptances),
    open_risks = sum(regs$risks$status == "open"),
    transitions = nrow(regs$transitions),
    pending_human_decisions = sum(w$acceptance_status == "pending" & w$implementation_status == "implemented" &
                                    w$test_status %in% c("passed", "not_applicable"))
  )
}
