# TaxMiner Governance phase 04 (req_0021): execution register, state machine,
# capability matrix, Claude Code hook adapter and transcript token reader.
# Synthetic roots, hook inputs and transcripts only: no real transcript is read
# and no hook is installed (P9).
# Run from the project root:
#   Rscript -e "testthat::test_file('tests/testthat/test_governance_agents.R')"

source(testthat::test_path("..", "..", "src", "common", "governance_registry.R"))
source(testthat::test_path("..", "..", "src", "common", "governance_prompts.R"))
source(testthat::test_path("..", "..", "src", "common", "governance_agents.R"))

agents_root <- function() {
  root <- tempfile("governance_agents_")
  pm <- file.path(root, "docs", "project_management")
  dir.create(pm, recursive = TRUE)
  writeLines(c("requirement_id,module,description,source,priority,acceptance_criteria,status,owner,updated_at",
               "req_0001,common,Synthetic,synthetic,high,Passes,approved,developer,2026-01-01T10:00:00-03:00"),
             file.path(pm, "requirements_register.csv"))
  writeLines(c("# Decisions", "", "## decision_0001 — 2026-01-01 — Token reading authorized"),
             file.path(pm, "decision_log.md"))
  root
}
pm_dir <- function(root) file.path(root, "docs", "project_management")
t0 <- "2026-01-05T10:00:00-03:00"
t1 <- "2026-01-05T10:20:00-03:00"

synthetic_transcript <- function(dir, lines) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(dir, "session.jsonl")
  writeLines(lines, f)
  f
}
usage_line <- function(req, input, output, cache_read = 0, cache_creation = 0, text = "conteúdo sigiloso") {
  sprintf(paste0('{"type":"assistant","requestId":"%s","message":{"id":"msg_%s","model":"claude-synthetic-1",',
                 '"content":[{"type":"text","text":"%s"}],"usage":{"input_tokens":%d,"cache_creation_input_tokens":%d,',
                 '"cache_read_input_tokens":%d,"output_tokens":%d}}}'), req, req, text, input, cache_creation,
          cache_read, output)
}

test_that("executions follow the state machine and record every transition", {
  dir <- pm_dir(agents_root())
  id <- governance_start_execution(dir, "codex", model = "synthetic", at = t0)
  expect_equal(id, "exec_0001")
  governance_update_execution(dir, id, "paused", "developer", at = t0)
  governance_update_execution(dir, id, "running", "developer", at = t0)
  governance_update_execution(dir, id, "completed", "developer", outcome = "ok, done",
                              tokens = list(input_tokens = 120, output_tokens = "30"), at = t1)
  regs <- governance_read(dir)
  x <- regs$executions
  expect_equal(unlist(x[1, c("state", "ended_at", "retries", "input_tokens", "output_tokens", "cached_tokens", "outcome")],
                      use.names = FALSE), c("completed", t1, "1", "120", "30", "", "ok; done"))
  expect_equal(regs$transitions$to_status[regs$transitions$entity_id == id],
               c("running", "paused", "running", "completed"))
  expect_error(governance_update_execution(dir, id, "running", "developer"), "cannot move from completed")
  expect_error(governance_update_execution(dir, id, "sleeping", "developer"), "Unknown execution state")
  expect_error(governance_start_execution(dir, "codex", state = "completed"), "queued or running")
  expect_error(governance_start_execution(dir, "chatgpt"), "outside the vocabulary")
  expect_error(governance_start_execution(dir, "codex", work_item_id = "work_0099"), "does not exist")
  expect_equal(nrow(governance_check(governance_read(dir))), 0L)
})

test_that("token counts are never estimated: empty stays unavailable and bad values are refused", {
  dir <- pm_dir(agents_root())
  id <- governance_start_execution(dir, "developer", at = t0)
  expect_error(governance_update_execution(dir, id, "completed", "developer", tokens = list(input_tokens = "about 100")),
               "non-negative integers")
  expect_error(governance_update_execution(dir, id, "completed", "developer", tokens = list(output_tokens = -1)),
               "non-negative integers")
  governance_update_execution(dir, id, "completed", "developer", at = t1)
  s <- governance_execution_summary(governance_read(dir))
  expect_equal(c(s$executions, s$with_tokens, s$without_tokens), c(1L, 0L, 1L))
  expect_true(is.na(s$input_tokens))
  regs <- governance_read(dir)
  regs$executions$input_tokens <- "12.5"
  expect_match(governance_check(regs)$problem, "is not a count")
})

test_that("executions without an end event become unknown after the limit", {
  dir <- pm_dir(agents_root())
  old <- governance_start_execution(dir, "claude_code", at = "2026-01-05T08:00:00-03:00")
  new <- governance_start_execution(dir, "claude_code", at = "2026-01-05T19:00:00-03:00")
  expect_equal(governance_reconcile_executions(dir, 12, at = "2026-01-05T21:00:00-03:00"), old)
  x <- governance_read(dir)$executions
  expect_equal(x$state, c("unknown", "running"))
  expect_equal(x$ended_at[1], "")
  expect_equal(governance_execution_summary(governance_read(dir))$unknown, 1L)
})

test_that("a captured prompt is minimized: one line, short, no e-mail, no protected path", {
  long <- paste(rep("palavra", 60), collapse = " ")
  expect_lte(nchar(governance_minimize_prompt(long)), 160L)
  s <- governance_minimize_prompt("ler .restricted/plan.xlsx e C:\\x\\tmp\\a.csv, avisar fulano@exemplo.gov.br\nsegunda linha")
  expect_false(grepl("restricted|tmp|@|,|\n", s))
  expect_match(s, "\\[área protegida\\]")
  expect_match(s, "\\[e-mail\\]")
  expect_match(s, "\\(\\+\\)$")
  expect_equal(governance_minimize_prompt("  \n "), "(solicitação vazia)")
  expect_identical(governance_check_summary(s), s)
})

test_that("the hook adapter captures a request, opens and closes the session execution", {
  root <- agents_root()
  dir <- pm_dir(root)
  submit <- '{"hook_event_name":"UserPromptSubmit","session_id":"abc-123","cwd":"C:/x","transcript_path":"C:/t.jsonl","prompt":"corrigir o filtro, sem acessar .tmp/arquivo"}'
  status <- governance_hook_safe(dir, submit, at = t0)
  expect_equal(status, "captured request_0001 exec_0001")
  regs <- governance_read(dir)
  expect_equal(unlist(regs$requests[1, c("channel", "classification", "status")], use.names = FALSE),
               c("claude_code", "unclassified", "captured"))
  expect_false(grepl("tmp", regs$requests$summary))
  expect_equal(unlist(regs$executions[1, c("session", "request_id", "state", "input_tokens")], use.names = FALSE),
               c("abc-123", "request_0001", "running", ""))
  expect_equal(governance_hook_safe(dir, '{"hook_event_name":"Stop","session_id":"other"}', at = t1), "closed 0")
  expect_equal(governance_hook_safe(dir, '{"hook_event_name":"Stop","session_id":"abc-123"}', at = t1), "closed 1")
  x <- governance_read(dir)$executions
  expect_equal(unlist(x[1, c("state", "ended_at", "input_tokens", "evidence")], use.names = FALSE),
               c("completed", t1, "", "hook:Stop"))
  expect_equal(governance_hook_safe(dir, '{"hook_event_name":"PostToolUse","session_id":"abc-123"}'), "ignored")
  expect_equal(nrow(governance_check(governance_read(dir))), 0L)
})

test_that("the hook adapter never raises on bad input", {
  dir <- pm_dir(agents_root())
  expect_match(governance_hook_safe(dir, "not json"), "^error:")
  expect_match(governance_hook_safe(dir, "[1,2]"), "^error:")
  expect_match(suppressWarnings(governance_hook_safe(file.path(tempdir(), "missing_dir"), '{"hook_event_name":"UserPromptSubmit","prompt":"x"}')),
               "^error:")
  expect_equal(nrow(governance_read(dir)$requests), 0L)
})

test_that("the hook script exits 0 and prints nothing to stdout", {
  root <- agents_root()
  rscript <- file.path(R.home("bin"), "Rscript")
  script <- normalizePath(testthat::test_path("..", "..", "scripts", "governance_hook.R"))
  project <- normalizePath(testthat::test_path("..", ".."))
  input <- tempfile(fileext = ".json")
  writeLines('{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"pedido sintético"}', input)
  out <- withr::with_dir(project, system2(rscript, c("--vanilla", shQuote(script), paste0("--root=", root)),
                                          stdin = input, stdout = TRUE, stderr = FALSE))
  expect_equal(length(out), 0L)
  expect_null(attr(out, "status"))
  expect_equal(governance_read(pm_dir(root))$requests$summary, "pedido sintético")
  writeLines("garbage", input)
  out <- withr::with_dir(project, system2(rscript, c("--vanilla", shQuote(script), paste0("--root=", root)),
                                          stdin = input, stdout = TRUE, stderr = FALSE))
  expect_equal(length(out), 0L)
  expect_null(attr(out, "status"))
})

test_that("transcript token reading needs a decision and an allowed folder, and keeps only numbers", {
  root <- agents_root()
  allowed <- file.path(root, "transcripts")
  f <- synthetic_transcript(allowed, c(
    '{"type":"user","message":{"content":"pergunta sigilosa"}}',
    usage_line("req_a", 100, 20, cache_read = 1000, cache_creation = 50),
    usage_line("req_a", 100, 20, cache_read = 1000, cache_creation = 50),
    usage_line("req_b", 10, 5, cache_read = 2000)))
  expect_error(governance_transcript_tokens(root, f, "decision_0099", allowed), "P9")
  expect_error(governance_transcript_tokens(root, f, "", allowed), "P9")
  outside <- synthetic_transcript(file.path(root, "elsewhere"), usage_line("req_c", 1, 1))
  expect_error(governance_transcript_tokens(root, outside, "decision_0001", allowed), "outside the allowed")
  tok <- governance_transcript_tokens(root, f, "decision_0001", allowed)
  expect_equal(tok[c("input_tokens", "output_tokens", "cached_tokens", "model")],
               list(input_tokens = "160", output_tokens = "25", cached_tokens = "3000", model = "claude-synthetic-1"))
  expect_equal(tok$responses, 2L)
  expect_false(any(grepl("sigilos", unlist(tok))))
  empty <- synthetic_transcript(file.path(allowed, "empty"), '{"type":"user","message":{"content":"x"}}')
  expect_equal(governance_transcript_tokens(root, empty, "decision_0001", allowed)$input_tokens, "")
})

test_that("with token reading enabled, Stop records the turn's share of the session counts", {
  root <- agents_root()
  dir <- pm_dir(root)
  allowed <- file.path(root, "transcripts")
  f <- synthetic_transcript(allowed, usage_line("req_a", 100, 20, cache_read = 1000))
  reader <- function(path) governance_transcript_tokens(root, path, "decision_0001", allowed)
  ev <- function(name) sprintf('{"hook_event_name":"%s","session_id":"s9","prompt":"p","transcript_path":"%s"}',
                               name, normalizePath(f, winslash = "/"))
  governance_hook_safe(dir, ev("UserPromptSubmit"), at = t0, token_reader = reader)
  expect_equal(governance_hook_safe(dir, ev("Stop"), at = t1, token_reader = reader), "closed 1")
  writeLines(c(usage_line("req_a", 100, 20, cache_read = 1000), usage_line("req_b", 30, 7, cache_read = 500)), f)
  governance_hook_safe(dir, ev("UserPromptSubmit"), at = t1, token_reader = reader)
  governance_hook_safe(dir, ev("Stop"), at = t1, token_reader = reader)
  x <- governance_read(dir)$executions
  expect_equal(x$input_tokens, c("100", "30"))
  expect_equal(x$output_tokens, c("20", "7"))
  expect_equal(x$cached_tokens, c("1000", "500"))
  expect_equal(x$model, c("claude-synthetic-1", "claude-synthetic-1"))
  expect_equal(nrow(governance_check(governance_read(dir))), 0L)
})

test_that("the capability matrix declares every capability and never dispatches tasks", {
  m <- governance_adapter_matrix()
  expect_setequal(unique(m$agent), c("claude_code", "codex", "github_copilot", "gemini_cli"))
  expect_true(all(table(m$agent) == length(governance_capabilities)))
  expect_true(all(m$level[m$capability == "task_dispatch"] == "not_used"))
  expect_true(all(m$level %in% c("implemented", "documented", "manual", "not_used", "unavailable", "to_verify")))
  probe <- governance_probe_agents(which = function(cmd) if (cmd == "codex") "C:/bin/codex.exe" else "")
  expect_equal(probe$on_path, c(FALSE, TRUE, FALSE, FALSE))
  r <- governance_capability_report(probe, at = t0)
  expect_true(any(grepl("^\\| task_dispatch \\| not_used \\| not_used \\| not_used \\| not_used \\|$", r)))
  expect_true(any(grepl("^\\| codex \\| `codex` \\| sim \\|$", r)))
})
