# TaxMiner Governance — prompt evolution (phase 06, req_0021, decision_0047).
# Versioning of the master prompt, protection of the immutable layer, proposals
# with verifiable diffs, human approval, history report and planning revisions.
# Requires src/common/governance_registry.R. Base R plus the local git binary
# (only `git diff --no-index` and `git rev-parse`); no network.
# source() only defines functions: no file access, no side effects.
#
# Rules (prompts/common_p08_governance_master.txt, sections 5 and 13):
# - Layer A (immutable): AGENTS.md, CLAUDE.md, Common P01 and section 12 of
#   Common P08. Their SHA-256 fingerprints live in immutable_rules.csv; a
#   change is accepted only when a recorded decision re-baselines them.
# - A prompt revision is first proposed: the candidate text and its diff are
#   kept under reports/governance/ and the revision row starts as `proposed`.
# - Only a person approves (agents cannot), and nothing is applied
#   automatically. Applying checks that the prompt did not change since the
#   proposal; a revision touching the immutable layer needs the
#   security_sensitive class and a decision.

governance_agents <- c("claude_code", "codex", "gemini_cli", "github_copilot")

# Immutable layer: whole files, or the lines from a start heading up to (not
# including) an end heading.
governance_immutable_sources <- data.frame(
  rule_id = c("imm_0001", "imm_0002", "imm_0003", "imm_0004"),
  file = c("AGENTS.md", "CLAUDE.md", "prompts/common_p01_lifecycle_management.txt",
           "prompts/common_p08_governance_master.txt"),
  start = c("", "", "", "^# 12\\. "),
  end = c("", "", "", "^# 13\\. "),
  stringsAsFactors = FALSE)

governance_pm_dir <- function(root) file.path(root, "docs", "project_management")

# Text with LF line ends and no trailing blank lines, so checkout settings do
# not change fingerprints.
governance_read_text <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  while (length(lines) && !nzchar(trimws(lines[length(lines)]))) lines <- lines[-length(lines)]
  lines
}

governance_section <- function(lines, start, end) {
  if (!nzchar(start)) return(lines)
  i <- grep(start, lines)
  if (length(i) != 1L) stop("Section heading not found once: ", start, call. = FALSE)
  j <- grep(end, lines)
  j <- j[j > i]
  if (!length(j)) stop("Section end not found: ", end, call. = FALSE)
  lines[i:(j[1] - 1L)]
}

governance_sha256 <- function(lines) {
  f <- tempfile()
  on.exit(unlink(f))
  con <- file(f, open = "wb")
  writeBin(charToRaw(enc2utf8(paste(lines, collapse = "\n"))), con)
  close(con)
  unname(as.character(tools::sha256sum(f)))
}

# Current fingerprints of the immutable layer.
governance_fingerprints <- function(root, sources = governance_immutable_sources) {
  sources$sha256 <- vapply(seq_len(nrow(sources)), function(k) {
    path <- file.path(root, sources$file[k])
    if (!file.exists(path)) return(NA_character_)
    governance_sha256(governance_section(governance_read_text(path), sources$start[k], sources$end[k]))
  }, character(1))
  sources
}

governance_decision_exists <- function(root, decision_id) {
  path <- file.path(governance_pm_dir(root), "decision_log.md")
  file.exists(path) && grepl("^decision_\\d{4}$", decision_id) &&
    any(grepl(paste0("^## ", decision_id, " "), readLines(path, encoding = "UTF-8", warn = FALSE)))
}

# Compares the immutable layer with its baseline; zero rows = intact.
governance_immutable_check <- function(root) {
  base <- governance_read(governance_pm_dir(root))$immutable_rules
  now <- governance_fingerprints(root)
  out <- data.frame(register = character(), id = character(), problem = character(), stringsAsFactors = FALSE)
  add <- function(id, problem) out[nrow(out) + 1L, ] <<- c("immutable_rules", id, problem)
  for (k in seq_len(nrow(now))) {
    b <- base[base$rule_id == now$rule_id[k], , drop = FALSE]
    if (!nrow(b)) add(now$rule_id[k], paste("no baseline for", now$file[k]))
    else if (is.na(now$sha256[k])) add(now$rule_id[k], paste("file missing:", now$file[k]))
    else if (!identical(b$sha256, now$sha256[k])) {
      add(now$rule_id[k], paste("immutable rule changed without a recorded decision:", now$file[k]))
    }
  }
  out
}

# Records the current fingerprints as the baseline, citing a decision that
# must already exist in decision_log.md; changed fingerprints become transitions.
governance_record_baseline <- function(root, decision_id, actor = "developer", at = governance_now()) {
  if (!governance_decision_exists(root, decision_id)) {
    stop("A baseline needs an existing decision in decision_log.md: ", decision_id, call. = FALSE)
  }
  dir <- governance_pm_dir(root)
  old <- governance_read(dir)$immutable_rules
  now <- governance_fingerprints(root)
  if (anyNA(now$sha256)) stop("Immutable file missing: ", paste(now$file[is.na(now$sha256)], collapse = ", "), call. = FALSE)
  section <- ifelse(nzchar(now$start), paste("section", gsub("\\D", "", now$start)), "whole file")
  new <- data.frame(rule_id = now$rule_id, file = now$file, section = section, sha256 = now$sha256,
                    recorded_at = at, decision = decision_id, stringsAsFactors = FALSE)
  # Unchanged rules keep the date and decision of their baseline.
  m <- match(new$rule_id, old$rule_id)
  same <- !is.na(m) & old$sha256[m] == new$sha256
  same[is.na(same)] <- FALSE
  new$recorded_at[same] <- old$recorded_at[m[same]]
  new$decision[same] <- old$decision[m[same]]
  governance_write(dir, "immutable_rules", new)
  for (k in seq_len(nrow(new))) {
    prev <- old$sha256[old$rule_id == new$rule_id[k]]
    prev <- if (length(prev)) prev else ""
    if (!identical(prev, new$sha256[k])) {
      governance_record_transition(dir, new$rule_id[k], "sha256", substr(prev, 1, 12), substr(new$sha256[k], 1, 12),
                                   actor, decision_id, at)
    }
  }
  invisible(new)
}

governance_git <- function(root, args) {
  out <- suppressWarnings(tryCatch(system2("git", c("-C", shQuote(root), args), stdout = TRUE, stderr = FALSE),
                                   error = function(e) character()))
  out
}

governance_prompt_version <- function(lines) {
  v <- regmatches(lines, regexpr("\\| Version: [0-9]+\\.[0-9]+", lines))
  if (length(v)) sub("^\\| Version: ", "", v[1]) else ""
}

# Proposes a new version of a prompt. Keeps the candidate and its unified diff
# under reports/governance/, appends a `proposed` revision and its transition.
governance_propose_prompt <- function(root, prompt_file, candidate_path, reason, change_class, improvements,
                                      requirements = "", actor = "claude_code", at = governance_now()) {
  dir <- governance_pm_dir(root)
  current_path <- file.path(root, prompt_file)
  if (!file.exists(current_path) || !file.exists(candidate_path)) stop("Prompt or candidate not found.", call. = FALSE)
  current <- governance_read_text(current_path)
  candidate <- governance_read_text(candidate_path)
  if (identical(current, candidate)) stop("Candidate is identical to the current prompt.", call. = FALSE)
  classes <- split_ids(change_class)
  allowed <- c("safe_operational", "functional", "architectural", "security_sensitive")
  if (!length(classes) || !all(classes %in% allowed)) stop("Change class must be among: ", paste(allowed, collapse = ", "), call. = FALSE)
  touches <- governance_touches_immutable(prompt_file, current, candidate)
  if (touches && !"security_sensitive" %in% classes) {
    stop("The candidate changes the immutable layer; class security_sensitive is required.", call. = FALSE)
  }
  regs <- governance_read(dir)
  id <- governance_next_id(regs$prompt_revisions$revision_id, "prv")
  out_dir <- file.path(root, "reports", "governance")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  kept <- file.path(out_dir, paste0(id, ".candidate.txt"))
  base_copy <- tempfile(fileext = ".txt")
  on.exit(unlink(base_copy), add = TRUE)
  writeLines(enc2utf8(candidate), kept, useBytes = TRUE)
  writeLines(enc2utf8(current), base_copy, useBytes = TRUE)
  diff <- governance_git(root, c("diff", "--no-index", "--unified=3", "--", shQuote(base_copy), shQuote(kept)))
  diff <- diff[!grepl("^(diff --git|index |--- |\\+\\+\\+ )", diff)]
  writeLines(c(paste0("--- ", prompt_file, " (current)"), paste0("+++ ", prompt_file, " (", id, ")"), diff),
             file.path(out_dir, paste0(id, ".diff")), useBytes = TRUE)
  head <- governance_git(root, c("rev-parse", "--short", "HEAD"))
  row <- data.frame(revision_id = id, prompt_file = prompt_file, version = governance_prompt_version(candidate),
                    previous_version = governance_prompt_version(current), revised_at = at,
                    reason = reason, change_class = paste(classes, collapse = ";"),
                    improvements = improvements, affected_requirements = requirements,
                    base_commit = if (length(head)) head[1] else "",
                    validation = sprintf("base_sha256=%s;candidate=reports/governance/%s.candidate.txt;diff=reports/governance/%s.diff%s",
                                         governance_sha256(current), id, id, if (touches) ";touches_immutable_layer" else ""),
                    approval = "proposed", approver = "", stringsAsFactors = FALSE)
  pr <- rbind(regs$prompt_revisions, row[names(regs$prompt_revisions)])
  regs$prompt_revisions <- pr
  p <- governance_check(regs)
  p <- p[p$id == id, , drop = FALSE]
  if (nrow(p)) stop("Invalid revision: ", paste(p$problem, collapse = "; "), call. = FALSE)
  governance_write(dir, "prompt_revisions", pr)
  governance_record_transition(dir, id, "approval", "", "proposed", actor, paste0("reports/governance/", id, ".diff"), at)
  id
}

governance_touches_immutable <- function(prompt_file, current, candidate) {
  src <- governance_immutable_sources[governance_immutable_sources$file == prompt_file, , drop = FALSE]
  if (!nrow(src)) return(FALSE)
  any(vapply(seq_len(nrow(src)), function(k) {
    !identical(governance_section(current, src$start[k], src$end[k]),
               governance_section(candidate, src$start[k], src$end[k]))
  }, logical(1)))
}

# Approves (and applies) or rejects a proposed revision. Only a person decides;
# the prompt must be unchanged since the proposal; a revision touching the
# immutable layer needs an existing decision, which re-baselines the layer.
governance_decide_prompt <- function(root, revision_id, decision, approver, decision_id = "", at = governance_now()) {
  if (!decision %in% c("approved", "rejected")) stop("Decision must be approved or rejected.", call. = FALSE)
  if (!nzchar(approver) || approver %in% governance_agents) {
    stop("Only a person approves or rejects a prompt revision; agents cannot.", call. = FALSE)
  }
  dir <- governance_pm_dir(root)
  pr <- governance_read(dir)$prompt_revisions
  k <- which(pr$revision_id == revision_id)
  if (length(k) != 1L) stop("Unknown revision: ", revision_id, call. = FALSE)
  if (pr$approval[k] != "proposed") stop("Revision already decided: ", pr$approval[k], call. = FALSE)
  touches <- grepl("touches_immutable_layer", pr$validation[k], fixed = TRUE)
  if (decision == "approved") {
    if (touches && !governance_decision_exists(root, decision_id)) {
      stop("This revision changes the immutable layer: cite an existing decision.", call. = FALSE)
    }
    base <- sub("^base_sha256=([0-9a-f]+).*$", "\\1", pr$validation[k])
    target <- file.path(root, pr$prompt_file[k])
    if (!identical(governance_sha256(governance_read_text(target)), base)) {
      stop("The prompt changed after the proposal; propose the revision again.", call. = FALSE)
    }
    candidate <- governance_read_text(file.path(root, "reports", "governance", paste0(revision_id, ".candidate.txt")))
    text <- charToRaw(enc2utf8(paste(candidate, collapse = "\n")))
    con <- file(target, open = "wb")
    writeBin(text, con)
    close(con)
  }
  pr$approver[k] <- approver
  governance_write(dir, "prompt_revisions", pr)
  governance_set_field(dir, "prompt_revisions", revision_id, "approval", decision, approver,
                       if (nzchar(decision_id)) decision_id else "prompt_revisions.csv", at)
  if (decision == "approved" && touches) governance_record_baseline(root, decision_id, approver, at)
  invisible(decision)
}

# Persistent replanning: appends a `proposed` planning revision.
governance_add_plan_revision <- function(root, phase, summary, reason, evidence = "", at = governance_now()) {
  dir <- governance_pm_dir(root)
  p <- governance_read(dir)$planning_revisions
  id <- governance_next_id(p$plan_id, "plan")
  row <- data.frame(plan_id = id, revised_at = at, phase = phase, summary = summary, reason = reason,
                    approval = "proposed", evidence = evidence, stringsAsFactors = FALSE)
  governance_write(dir, "planning_revisions", rbind(p, row[names(p)]))
  governance_record_transition(dir, id, "approval", "", "proposed", "claude_code", "planning_revisions.csv", at)
  id
}

# Markdown history of prompt versions and planning revisions.
governance_prompt_report <- function(root) {
  regs <- governance_read(governance_pm_dir(root))
  pr <- regs$prompt_revisions
  imm <- governance_immutable_check(root)
  esc <- function(x) gsub("|", "\\|", x, fixed = TRUE)
  rows <- if (nrow(pr)) sprintf("| %s | %s | %s → %s | %s | %s | %s | %s |", pr$revision_id, esc(pr$prompt_file),
                                ifelse(nzchar(pr$previous_version), pr$previous_version, "—"), pr$version,
                                esc(pr$change_class), esc(pr$improvements), pr$approval,
                                ifelse(nzchar(pr$approver), pr$approver, "—")) else character()
  pl <- regs$planning_revisions
  plan_rows <- if (nrow(pl)) sprintf("| %s | %s | %s | %s |", pl$plan_id, pl$phase, esc(pl$summary), pl$approval) else character()
  c("# Evolução do prompt mestre", "",
    sprintf("Gerado em %s por `scripts/governance_registry.R prompt-report`. Não editar à mão.", governance_now()), "",
    "## Camada imutável", "",
    if (nrow(imm)) c("**Alterada sem decisão registrada:**", "", paste("-", imm$id, imm$problem)) else
      "Intacta: as impressões SHA-256 conferem com `immutable_rules.csv`.", "",
    "## Revisões do prompt", "",
    "| Revisão | Arquivo | Versão | Classe | Melhorias | Situação | Aprovador |",
    "| --- | --- | --- | --- | --- | --- | --- |", rows, "",
    sprintf("Propostas pendentes: %d. Aprovadas: %d. Rejeitadas: %d.", sum(pr$approval == "proposed"),
            sum(pr$approval == "approved"), sum(pr$approval == "rejected")), "",
    "## Revisões do planejamento", "",
    "| Revisão | Fase | Resumo | Situação |", "| --- | --- | --- | --- |", plan_rows)
}
