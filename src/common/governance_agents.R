# TaxMiner Governance — agent integration layer (phase 04, req_0021, decision_0048).
# Read-only adapters: they record what agents report; they never dispatch tasks
# (AGENTS.md forbids running another assistant without an explicit request).
# Requires src/common/governance_registry.R and src/common/governance_prompts.R.
# source() only defines functions: no file access, no network, no side effects.
#
# Rules:
# - Executions follow the state machine in governance_execution_moves; every
#   change of state is a row in state_transitions.csv.
# - Token counts are copied from what an agent reports, never estimated: empty
#   means "unavailable" and is never read as zero.
# - The Claude Code hook adapter keeps only a minimized summary of a prompt
#   (one line, at most 160 characters, e-mail addresses and protected paths
#   redacted) and never fails the agent session.
# - Transcript token reading (governance_transcript_tokens) needs a recorded
#   developer decision (P9) and keeps only the numeric fields of "usage".

governance_execution_states <- governance_specs$executions$vocab$state

# Allowed moves of the execution state machine (prompt section 10). Terminal
# states (failed, completed, interrupted) have no way out.
governance_execution_moves <- list(
  queued = c("running", "interrupted", "unknown"),
  running = c("paused", "failed", "completed", "interrupted", "unknown"),
  paused = c("running", "failed", "interrupted", "unknown"),
  unknown = c("running", "failed", "completed", "interrupted"),
  failed = character(),
  completed = character(),
  interrupted = character()
)

governance_capabilities <- c("request_capture", "task_dispatch", "execution_status", "logs", "metrics",
                             "cancellation", "resume", "artifact_tracking")

# Declared capabilities of each adapter (prompt section 9). Levels:
#   implemented  - adapter in this repository, covered by tests;
#   documented   - documented by the vendor, not exercised here;
#   manual       - only by manual entry (scripts/governance_registry.R add-execution);
#   not_used     - available but deliberately not used (task dispatch, AGENTS.md);
#   unavailable  - no known documented mechanism;
#   to_verify    - not confirmed.
governance_adapter_matrix <- function() {
  row <- function(agent, command, ...) {
    v <- c(...)
    data.frame(agent = agent, command = command, capability = names(v), level = unname(v),
               stringsAsFactors = FALSE)
  }
  rbind(
    row("claude_code", "claude",
        request_capture = "implemented", task_dispatch = "not_used", execution_status = "implemented",
        logs = "documented", metrics = "implemented", cancellation = "unavailable", resume = "documented",
        artifact_tracking = "manual"),
    row("codex", "codex",
        request_capture = "manual", task_dispatch = "not_used", execution_status = "documented",
        logs = "to_verify", metrics = "to_verify", cancellation = "unavailable", resume = "to_verify",
        artifact_tracking = "manual"),
    row("github_copilot", "gh",
        request_capture = "manual", task_dispatch = "not_used", execution_status = "manual",
        logs = "unavailable", metrics = "unavailable", cancellation = "unavailable", resume = "unavailable",
        artifact_tracking = "manual"),
    row("gemini_cli", "gemini",
        request_capture = "manual", task_dispatch = "not_used", execution_status = "to_verify",
        logs = "to_verify", metrics = "to_verify", cancellation = "unavailable", resume = "to_verify",
        artifact_tracking = "manual")
  )
}

# Presence of each agent command on PATH. Nothing is executed: running another
# assistant, even for --version, is outside the read-only boundary.
governance_probe_agents <- function(which = Sys.which) {
  m <- unique(governance_adapter_matrix()[, c("agent", "command")])
  found <- vapply(m$command, function(cmd) nzchar(which(cmd)[[1]]), logical(1))
  data.frame(agent = m$agent, command = m$command, on_path = unname(found), stringsAsFactors = FALSE)
}

# Markdown report of the capability matrix and the PATH probe.
governance_capability_report <- function(probe = governance_probe_agents(), at = governance_now()) {
  m <- governance_adapter_matrix()
  agents <- unique(m$agent)
  cell <- function(a, cap) m$level[m$agent == a & m$capability == cap]
  c("# Matriz de capacidades dos agentes", "",
    sprintf("Gerada em %s por `scripts/governance_registry.R capability-report`.", at), "",
    "Níveis: `implemented` (adaptador neste repositório, com testes); `documented` (documentado pelo",
    "fornecedor, não exercitado aqui); `manual` (só por registro manual); `not_used` (existe, mas não é",
    "usado: despacho de tarefas, vedado pelo `AGENTS.md`); `unavailable` (sem mecanismo documentado",
    "conhecido); `to_verify` (não confirmado).", "",
    paste0("| Capacidade | ", paste(agents, collapse = " | "), " |"),
    paste0("| --- |", strrep(" --- |", length(agents))),
    vapply(governance_capabilities, function(cap) {
      paste0("| ", cap, " | ", paste(vapply(agents, cell, character(1), cap = cap), collapse = " | "), " |")
    }, character(1)),
    "", "## Comandos no PATH", "",
    "Só a presença do comando é verificada; nenhum agente é executado.", "",
    "| Agente | Comando | No PATH |", "| --- | --- | --- |",
    sprintf("| %s | `%s` | %s |", probe$agent, probe$command, ifelse(probe$on_path, "sim", "não")))
}

# Token or count field: empty (unavailable) or a non-negative integer.
governance_count <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x[1]) || identical(as.character(x[1]), "")) return("")
  v <- as.character(x[1])
  if (!grepl("^\\d+$", v)) stop("Counts must be non-negative integers or empty: ", v, call. = FALSE)
  v
}

# Opens an execution (state running unless given); returns its ID.
governance_start_execution <- function(dir, agent, model = "", session = "", work_item_id = "", request_id = "",
                                       state = "running", evidence = "", at = governance_now()) {
  if (!state %in% c("queued", "running")) stop("An execution starts as queued or running.", call. = FALSE)
  regs <- governance_read(dir)
  x <- regs$executions
  id <- governance_next_id(x$execution_id, "exec")
  row <- data.frame(execution_id = id, work_item_id = work_item_id, request_id = request_id, agent = agent,
                    model = model, session = session, started_at = at, ended_at = "", state = state,
                    input_tokens = "", output_tokens = "", cached_tokens = "", reported_cost = "",
                    retries = "0", outcome = "", evidence = evidence, stringsAsFactors = FALSE)
  regs$executions <- rbind(x, row[governance_specs$executions$columns])
  p <- governance_check(regs)
  p <- p[p$register == "executions" & p$id == id, , drop = FALSE]
  if (nrow(p)) stop("Invalid execution: ", paste(p$problem, collapse = "; "), call. = FALSE)
  governance_write(dir, "executions", regs$executions)
  governance_record_transition(dir, id, "state", "", state, agent, evidence, at)
  id
}

# Moves an execution along the state machine; terminal states record ended_at.
# Token fields are only filled when given (never estimated).
governance_update_execution <- function(dir, id, state, actor, outcome = NULL, tokens = list(), evidence = "",
                                        at = governance_now()) {
  regs <- governance_read(dir)
  x <- regs$executions
  k <- which(x$execution_id == id)
  if (length(k) != 1L) stop("Unknown execution: ", id, call. = FALSE)
  from <- x$state[k]
  if (!state %in% governance_execution_states) stop("Unknown execution state: ", state, call. = FALSE)
  if (!identical(from, state) && !state %in% governance_execution_moves[[from]]) {
    stop(sprintf("Execution %s cannot move from %s to %s.", id, from, state), call. = FALSE)
  }
  if (identical(from, "paused") && identical(state, "running")) x$retries[k] <- as.character(as.integer(x$retries[k]) + 1L)
  for (f in intersect(names(tokens), c("input_tokens", "output_tokens", "cached_tokens", "reported_cost"))) {
    v <- if (f == "reported_cost") as.character(tokens[[f]]) else governance_count(tokens[[f]])
    if (f == "reported_cost" && nzchar(v) && !grepl("^\\d+(\\.\\d+)?$", v)) stop("Invalid cost: ", v, call. = FALSE)
    x[[f]][k] <- v
  }
  if (!is.null(outcome)) x$outcome[k] <- gsub("[,\"\r\n]+", ";", outcome)
  x$state[k] <- state
  if (state %in% c("failed", "completed", "interrupted")) x$ended_at[k] <- at
  if (nzchar(evidence)) x$evidence[k] <- evidence
  regs$executions <- x
  p <- governance_check(regs)
  p <- p[p$register == "executions", , drop = FALSE]
  if (nrow(p)) stop("Change would break integrity: ", p$problem[1], call. = FALSE)
  governance_write(dir, "executions", x)
  if (!identical(from, state)) governance_record_transition(dir, id, "state", from, state, actor, evidence, at)
  invisible(id)
}

# Failure handling: executions still running or paused after max_hours have
# no end event (session closed, crash, hook off); they become "unknown", which
# is reported and never counted as completed.
governance_reconcile_executions <- function(dir, max_hours = 12, actor = "governance", at = governance_now()) {
  x <- governance_read(dir)$executions
  open <- x$state %in% c("queued", "running", "paused")
  if (!any(open)) return(character())
  t0 <- as.POSIXct(sub("([+-]\\d{2}):(\\d{2})$", "\\1\\2", x$started_at), format = "%Y-%m-%dT%H:%M:%S%z")
  t1 <- as.POSIXct(sub("([+-]\\d{2}):(\\d{2})$", "\\1\\2", at), format = "%Y-%m-%dT%H:%M:%S%z")
  stale <- x$execution_id[open & !is.na(t0) & difftime(t1, t0, units = "hours") > max_hours]
  for (id in stale) {
    governance_update_execution(dir, id, "unknown", actor,
                                outcome = sprintf("sem evento de fim em %s h", format(max_hours)), at = at)
  }
  stale
}

# Minimized summary of a prompt captured by a hook (risk_0018): first non-empty
# line, whitespace collapsed, e-mail addresses and protected paths redacted,
# commas replaced, at most 160 characters.
governance_minimize_prompt <- function(text) {
  if (is.null(text) || !length(text) || is.na(text[1])) return("(solicitação vazia)")
  lines <- trimws(strsplit(as.character(text[1]), "[\r\n]+")[[1]])
  lines <- lines[nzchar(lines)]
  if (!length(lines)) return("(solicitação vazia)")
  s <- gsub("[[:space:]]+", " ", lines[1])
  s <- gsub("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "[e-mail]", s)
  s <- gsub("[^ ]*\\.?(restricted|tmp)[/\\\\][^ ]*", "[área protegida]", s, ignore.case = TRUE)
  s <- gsub("(^|[^A-Za-z0-9_])\\.?(restricted|tmp)[/\\\\]", "\\1[área protegida]", s, ignore.case = TRUE)
  s <- gsub("[,\"]", ";", s)
  if (nchar(s) > 160L) s <- paste0(substr(s, 1L, 157L), "...")
  if (length(lines) > 1L && nchar(s) <= 150L) s <- paste(s, "(+)")
  s
}

# Session identifier kept in the register: only [A-Za-z0-9_-], at most 64 characters.
governance_session_id <- function(x) {
  s <- gsub("[^A-Za-z0-9_-]", "", if (is.null(x)) "" else as.character(x[1]))
  substr(s, 1L, 64L)
}

# Claude Code hook adapter. `event` is the parsed hook input (a list with
# hook_event_name, session_id and, for UserPromptSubmit, prompt). Only the
# fields named here are read; cwd and transcript_path are ignored.
#   UserPromptSubmit: captures the request and opens a running execution;
#   Stop / SessionEnd: completes the open executions of the session;
#   anything else: ignored.
# `token_reader` (NULL = off) is a function(transcript_path) returning the
# session's cumulative counts (governance_transcript_tokens); the execution
# being closed receives the cumulative counts minus those already recorded for
# earlier executions of the same session. It is used only when the developer
# enabled it (P9); otherwise transcript_path is not read.
# Returns a short status string.
governance_hook_event <- function(dir, event, model = "", at = governance_now(), token_reader = NULL) {
  name <- if (is.null(event$hook_event_name)) "" else as.character(event$hook_event_name)
  session <- governance_session_id(event$session_id)
  if (name == "UserPromptSubmit") {
    rq <- governance_add_request(dir, governance_minimize_prompt(event$prompt), "unclassified", "claude_code",
                                 "claude_code", received_at = at)
    ex <- governance_start_execution(dir, "claude_code", model = model, session = session, request_id = rq,
                                     evidence = "hook:UserPromptSubmit", at = at)
    return(paste("captured", rq, ex))
  }
  if (name %in% c("Stop", "SessionEnd")) {
    x <- governance_read(dir)$executions
    mine <- x$session == session & nzchar(session)
    open <- x$execution_id[mine & x$state %in% c("running", "paused", "unknown")]
    tokens <- list()
    if (!is.null(token_reader) && length(open) && !is.null(event$transcript_path)) {
      total <- token_reader(as.character(event$transcript_path))
      done <- mine & !x$execution_id %in% open
      for (f in c("input_tokens", "output_tokens", "cached_tokens")) {
        if (!nzchar(total[[f]])) next
        prior <- sum(suppressWarnings(as.numeric(x[[f]][done])), na.rm = TRUE)
        tokens[[f]] <- format(max(0, as.numeric(total[[f]]) - prior), scientific = FALSE, trim = TRUE)
      }
      if (!nzchar(model) && nzchar(total$model)) model <- total$model
    }
    for (i in seq_along(open)) {
      last <- i == length(open)
      governance_update_execution(dir, open[i], "completed", "claude_code",
                                  outcome = if (last && length(tokens)) "tokens: transcrição (diferença na sessão)",
                                  tokens = if (last) tokens else list(), evidence = paste0("hook:", name), at = at)
    }
    if (nzchar(model) && length(open)) {
      y <- governance_read(dir)$executions
      y$model[y$execution_id %in% open & !nzchar(y$model)] <- gsub("[^A-Za-z0-9._;-]", "", model)
      governance_write(dir, "executions", y)
    }
    return(paste("closed", length(open)))
  }
  "ignored"
}

# Runs the hook adapter on raw stdin text and never raises: a failure is
# returned as text so the hook script can exit 0 (risk R2).
governance_hook_safe <- function(dir, text, model = "", at = governance_now(), token_reader = NULL) {
  tryCatch({
    event <- jsonlite::fromJSON(paste(text, collapse = "\n"), simplifyVector = FALSE)
    if (!is.list(event) || is.null(names(event))) stop("hook input is not a JSON object")
    governance_hook_event(dir, event, model, at, token_reader)
  }, error = function(e) paste("error:", conditionMessage(e)))
}

# Token counts reported in a Claude Code transcript (JSON lines). Requires a
# developer decision recorded in decision_log.md (P9). Only the numeric fields
# of each "usage" object are kept; message text is never stored or returned.
# The same API response may repeat on several lines, so lines are de-duplicated
# by requestId (or message id) when present. Returns a list of counts as
# strings, "" when no usage was found (unavailable, never zero).
governance_transcript_tokens <- function(root, path, decision_id, allowed_dir) {
  if (!governance_decision_exists(root, decision_id)) {
    stop("Reading transcripts needs an existing decision in decision_log.md (P9).", call. = FALSE)
  }
  full <- normalizePath(path, winslash = "/", mustWork = TRUE)
  base <- normalizePath(allowed_dir, winslash = "/", mustWork = TRUE)
  if (!startsWith(tolower(full), paste0(tolower(base), "/")) || !grepl("\\.jsonl$", full)) {
    stop("Transcript outside the allowed folder or not .jsonl.", call. = FALSE)
  }
  if (grepl("(^|/)\\.?(restricted|tmp)(/|$)", full, ignore.case = TRUE)) stop("Protected path.", call. = FALSE)
  fields <- c(input_tokens = "input_tokens", output_tokens = "output_tokens",
              cache_read = "cache_read_input_tokens", cache_creation = "cache_creation_input_tokens")
  totals <- stats::setNames(numeric(length(fields)), names(fields))
  seen <- character()
  found <- FALSE
  model <- character()
  con <- file(full, open = "r", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  repeat {
    lines <- readLines(con, n = 500L, warn = FALSE)
    if (!length(lines)) break
    for (line in lines) {
      u <- regmatches(line, regexpr("\"usage\"\\s*:\\s*\\{[^{}]*\\}", line))
      if (!length(u)) next
      key <- regmatches(line, regexpr("\"requestId\"\\s*:\\s*\"[A-Za-z0-9_-]+\"", line))
      if (!length(key)) key <- regmatches(line, regexpr("\"id\"\\s*:\\s*\"msg_[A-Za-z0-9_-]+\"", line))
      if (length(key)) {
        if (key %in% seen) next
        seen <- c(seen, key)
      }
      m <- regmatches(line, regexpr("\"model\"\\s*:\\s*\"[A-Za-z0-9._-]+\"", line))
      if (length(m)) model <- union(model, sub(".*\"([^\"]+)\"$", "\\1", m))
      for (f in names(fields)) {
        v <- regmatches(u, regexpr(sprintf("\"%s\"\\s*:\\s*\\d+", fields[[f]]), u))
        if (length(v)) totals[[f]] <- totals[[f]] + as.numeric(sub(".*:\\s*", "", v))
      }
      found <- TRUE
    }
  }
  fmt <- function(v) if (found) format(v, scientific = FALSE, trim = TRUE) else ""
  list(input_tokens = fmt(totals[["input_tokens"]] + totals[["cache_creation"]]),
       output_tokens = fmt(totals[["output_tokens"]]),
       cached_tokens = fmt(totals[["cache_read"]]),
       responses = if (found) length(seen) else 0L,
       model = paste(model, collapse = ";"))
}

# Execution summary for reports and, later, the dashboard. Token totals use
# only executions that report them; the count of those without stays visible.
governance_execution_summary <- function(regs) {
  x <- regs$executions
  num <- function(v) suppressWarnings(as.numeric(v))
  with_tokens <- nzchar(x$input_tokens) | nzchar(x$output_tokens)
  list(
    executions = nrow(x),
    states = table(factor(x$state, levels = governance_execution_states)),
    by_agent = table(x$agent),
    with_tokens = sum(with_tokens),
    without_tokens = sum(!with_tokens),
    input_tokens = if (any(with_tokens)) sum(num(x$input_tokens[with_tokens]), na.rm = TRUE) else NA_real_,
    output_tokens = if (any(with_tokens)) sum(num(x$output_tokens[with_tokens]), na.rm = TRUE) else NA_real_,
    open = sum(x$state %in% c("queued", "running", "paused")),
    unknown = sum(x$state == "unknown")
  )
}
