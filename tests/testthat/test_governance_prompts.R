# TaxMiner Governance phase 06 (req_0021): immutable layer, prompt revisions with
# diffs, human-only approval, history report and planning revisions. Synthetic
# project roots in temporary folders; the real root is only read.
# Run from the project root:
#   Rscript -e "testthat::test_file('tests/testthat/test_governance_prompts.R')"

source(testthat::test_path("..", "..", "src", "common", "governance_registry.R"))
source(testthat::test_path("..", "..", "src", "common", "governance_prompts.R"))

real_root <- testthat::test_path("..", "..")

p08 <- c("# TAXMINER — COMMON P08", "Prompt Pack: 1.0 | Version: 1.0 | Status: synthetic", "",
         "# 11. DASHBOARD", "Atualizar a cada 150 segundos.", "",
         "# 12. SECURITY", "Não ler áreas protegidas.", "",
         "# 13. REFINEMENT", "Revisar ao fim de cada fase.")

synthetic_root <- function() {
  root <- tempfile("governance_root_")
  pm <- file.path(root, "docs", "project_management")
  dir.create(pm, recursive = TRUE)
  dir.create(file.path(root, "prompts"))
  writeLines("# Agents\nNever read protected areas.", file.path(root, "AGENTS.md"))
  writeLines("# Claude\nFollow AGENTS.md.", file.path(root, "CLAUDE.md"))
  writeLines("# COMMON P01\nLifecycle.", file.path(root, "prompts", "common_p01_lifecycle_management.txt"))
  writeLines(p08, file.path(root, "prompts", "common_p08_governance_master.txt"))
  writeLines(c("requirement_id,module,description,source,priority,acceptance_criteria,status,owner,updated_at",
               "req_0001,common,Synthetic,synthetic,high,Passes,approved,developer,2026-01-01T10:00:00-03:00"),
             file.path(pm, "requirements_register.csv"))
  writeLines(c("# Decisions", "", "## decision_0001 — 2026-01-01 — Baseline", "", "## decision_0002 — 2026-01-02 — Security change"),
             file.path(pm, "decision_log.md"))
  root
}

candidate <- function(root, lines) {
  f <- tempfile(fileext = ".txt")
  writeLines(lines, f)
  f
}

prompt_lines <- function(root) governance_read_text(file.path(root, "prompts", "common_p08_governance_master.txt"))

test_that("the real immutable layer matches its recorded baseline", {
  p <- governance_immutable_check(real_root)
  expect_equal(nrow(p), 0L, info = paste(p$id, p$problem, collapse = "\n"))
})

test_that("a baseline needs an existing decision and then detects any change", {
  root <- synthetic_root()
  expect_true(nrow(governance_immutable_check(root)) == 4L)
  expect_error(governance_record_baseline(root, "decision_0099"), "existing decision")
  governance_record_baseline(root, "decision_0001", at = "2026-01-03T10:00:00-03:00")
  expect_equal(nrow(governance_immutable_check(root)), 0L)
  rules <- governance_read(file.path(root, "docs", "project_management"))$immutable_rules
  expect_equal(rules$section, c("whole file", "whole file", "whole file", "section 12"))
  # Line endings and trailing blank lines do not count as changes.
  agents <- file.path(root, "AGENTS.md")
  writeBin(charToRaw("# Agents\r\nNever read protected areas.\r\n\r\n"), agents)
  expect_equal(nrow(governance_immutable_check(root)), 0L)
  writeLines("# Agents\nRead anything.", agents)
  p <- governance_immutable_check(root)
  expect_equal(p$id, "imm_0001")
  expect_match(p$problem, "without a recorded decision")
  # Outside section 12, Common P08 is not immutable.
  writeLines("# Agents\nNever read protected areas.", agents)
  lines <- prompt_lines(root)
  lines[5] <- "Atualizar a cada 60 segundos."
  writeLines(lines, file.path(root, "prompts", "common_p08_governance_master.txt"))
  expect_equal(nrow(governance_immutable_check(root)), 0L)
})

test_that("a re-baseline keeps unchanged rules and records transitions for changed ones", {
  root <- synthetic_root()
  governance_record_baseline(root, "decision_0001", at = "2026-01-03T10:00:00-03:00")
  writeLines("# Claude\nFollow AGENTS.md strictly.", file.path(root, "CLAUDE.md"))
  governance_record_baseline(root, "decision_0002", at = "2026-01-04T10:00:00-03:00")
  regs <- governance_read(file.path(root, "docs", "project_management"))
  expect_equal(regs$immutable_rules$decision, c("decision_0001", "decision_0002", "decision_0001", "decision_0001"))
  expect_equal(sum(regs$transitions$entity_id == "imm_0002"), 2L)
  expect_equal(nrow(governance_check(regs)), 0L)
})

test_that("a proposal keeps the candidate and a diff and starts as proposed", {
  root <- synthetic_root()
  governance_record_baseline(root, "decision_0001")
  lines <- prompt_lines(root)
  lines[2] <- "Prompt Pack: 1.0 | Version: 1.1 | Status: synthetic"
  lines[5] <- "Atualizar a cada 150 segundos, com indicador de dados desatualizados."
  id <- governance_propose_prompt(root, "prompts/common_p08_governance_master.txt", candidate(root, lines),
                                  "Clarify refresh", "functional", "stale-data indicator", "req_0001",
                                  at = "2026-01-05T10:00:00-03:00")
  expect_equal(id, "prv_0001")
  pr <- governance_read(file.path(root, "docs", "project_management"))$prompt_revisions
  expect_equal(unlist(pr[1, c("version", "previous_version", "approval", "approver")], use.names = FALSE),
               c("1.1", "1.0", "proposed", ""))
  diff <- readLines(file.path(root, "reports", "governance", "prv_0001.diff"))
  expect_true(any(grepl("^-Atualizar a cada 150 segundos\\.$", diff)))
  expect_true(any(grepl("^\\+Atualizar a cada 150 segundos, com indicador", diff)))
  expect_identical(prompt_lines(root)[5], "Atualizar a cada 150 segundos.")
  expect_error(governance_propose_prompt(root, "prompts/common_p08_governance_master.txt",
                                         candidate(root, prompt_lines(root)), "x", "functional", "x"), "identical")
  expect_error(governance_propose_prompt(root, "prompts/common_p08_governance_master.txt",
                                         candidate(root, lines), "x", "cosmetic", "x"), "Change class")
})

test_that("only a person approves; approval applies the candidate and rejection does not", {
  root <- synthetic_root()
  governance_record_baseline(root, "decision_0001")
  lines <- prompt_lines(root)
  lines[5] <- "Atualizar a cada 120 segundos."
  id <- governance_propose_prompt(root, "prompts/common_p08_governance_master.txt", candidate(root, lines),
                                  "Tune refresh", "safe_operational", "refresh", "req_0001")
  expect_error(governance_decide_prompt(root, id, "approved", "claude_code"), "agents cannot")
  expect_identical(prompt_lines(root)[5], "Atualizar a cada 150 segundos.")
  governance_decide_prompt(root, id, "approved", "developer")
  expect_identical(prompt_lines(root)[5], "Atualizar a cada 120 segundos.")
  expect_error(governance_decide_prompt(root, id, "rejected", "developer"), "already decided")
  lines[5] <- "Atualizar a cada 10 segundos."
  id2 <- governance_propose_prompt(root, "prompts/common_p08_governance_master.txt", candidate(root, lines),
                                   "Faster", "safe_operational", "refresh")
  governance_decide_prompt(root, id2, "rejected", "developer")
  expect_identical(prompt_lines(root)[5], "Atualizar a cada 120 segundos.")
  regs <- governance_read(file.path(root, "docs", "project_management"))
  expect_equal(regs$prompt_revisions$approval, c("approved", "rejected"))
  expect_true(all(c("proposed", "approved", "rejected") %in% regs$transitions$to_status))
  expect_equal(nrow(governance_check(regs)), 0L)
})

test_that("a revision is refused when the prompt changed after the proposal", {
  root <- synthetic_root()
  governance_record_baseline(root, "decision_0001")
  lines <- prompt_lines(root)
  lines[5] <- "Atualizar a cada 120 segundos."
  id <- governance_propose_prompt(root, "prompts/common_p08_governance_master.txt", candidate(root, lines),
                                  "Tune", "safe_operational", "refresh")
  other <- prompt_lines(root)
  other[11] <- "Revisar sempre."
  writeLines(other, file.path(root, "prompts", "common_p08_governance_master.txt"))
  expect_error(governance_decide_prompt(root, id, "approved", "developer"), "changed after the proposal")
  expect_identical(prompt_lines(root)[11], "Revisar sempre.")
})

test_that("changing the immutable section needs the security class and a decision, then re-baselines", {
  root <- synthetic_root()
  governance_record_baseline(root, "decision_0001")
  lines <- prompt_lines(root)
  lines[8] <- "Não ler, listar nem copiar áreas protegidas."
  expect_error(governance_propose_prompt(root, "prompts/common_p08_governance_master.txt", candidate(root, lines),
                                         "Stricter", "functional", "security"), "security_sensitive")
  id <- governance_propose_prompt(root, "prompts/common_p08_governance_master.txt", candidate(root, lines),
                                  "Stricter", "security_sensitive", "security")
  expect_error(governance_decide_prompt(root, id, "approved", "developer"), "existing decision")
  expect_error(governance_decide_prompt(root, id, "approved", "developer", "decision_0042"), "existing decision")
  expect_identical(prompt_lines(root)[8], "Não ler áreas protegidas.")
  governance_decide_prompt(root, id, "approved", "developer", "decision_0002")
  expect_identical(prompt_lines(root)[8], "Não ler, listar nem copiar áreas protegidas.")
  expect_equal(nrow(governance_immutable_check(root)), 0L)
  rules <- governance_read(file.path(root, "docs", "project_management"))$immutable_rules
  expect_equal(rules$decision[rules$rule_id == "imm_0004"], "decision_0002")
})

test_that("planning revisions are appended as proposed and the report lists the history", {
  root <- synthetic_root()
  governance_record_baseline(root, "decision_0001")
  expect_equal(governance_add_plan_revision(root, "phase_06", "Next phase 04", "Replanning"), "plan_0001")
  lines <- prompt_lines(root)
  lines[5] <- "Atualizar a cada 120 segundos."
  governance_propose_prompt(root, "prompts/common_p08_governance_master.txt", candidate(root, lines),
                            "Tune", "safe_operational", "refresh | faster")
  report <- governance_prompt_report(root)
  expect_true(any(grepl("^Intacta", report)))
  expect_true(any(grepl("^\\| prv_0001 \\|.*1\\.0 → 1\\.0.*refresh \\\\\\| faster.*proposed", report)))
  expect_true(any(grepl("Propostas pendentes: 1", report, fixed = TRUE)))
  expect_true(any(grepl("^\\| plan_0001 \\| phase_06 \\|", report)))
  writeLines("# Claude\nChanged.", file.path(root, "CLAUDE.md"))
  expect_true(any(grepl("Alterada sem decisão", governance_prompt_report(root))))
})
