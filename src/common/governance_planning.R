# TaxMiner Governance — planning and context optimization (phase 03, req_0021, work_0037).
# Deterministic planning engine over the governance registers (no LLM, no network):
# deduplication suggestions, decomposition and per-requirement plans, transparent
# prioritization, evidence-based estimates, requirement status reconciliation (P13),
# context packs for agents and replanning inputs. Base R only; source() has no side
# effects. Needs governance_registry.R and governance_prompts.R (governance_pm_dir).
#
# Rules (prompts/common_p08_governance_master.txt sections 6.3, 7, 8 and 14):
# - Deduplication only suggests; nothing is merged, and ambiguous cases go to a human.
# - Priorities are read, never changed; the ranking shows every component of its score.
# - Estimates come from recorded history with the sample size; below the minimum
#   sample they are NA ("indisponível"), never guessed. Tokens are never estimated
#   without reported executions.
# - Requirement statuses are only proposed here; governance_apply_requirement_status()
#   applies the ones a human approved, one by one, with the decision as evidence.
# - Context packs never include protected paths (.restricted/, .tmp/).

governance_stopwords <- c(
  "a", "o", "e", "de", "da", "do", "das", "dos", "em", "no", "na", "nos", "nas", "um", "uma", "para", "por",
  "com", "sem", "que", "ao", "aos", "as", "os", "se", "ou", "the", "and", "of", "to", "in", "on", "for", "with",
  "by", "an", "or", "is", "are", "be", "from", "at", "as", "its", "into", "each", "every", "all", "via", "per")

# Normalized word set of a text: lowercase ASCII, words of 3+ characters, no stopwords.
governance_terms <- function(text) {
  t <- tolower(iconv(enc2utf8(paste(text, collapse = " ")), "UTF-8", "ASCII//TRANSLIT", sub = ""))
  w <- unlist(strsplit(t, "[^a-z0-9_]+"))
  unique(w[nchar(w) >= 3L & !w %in% governance_stopwords])
}

governance_similarity <- function(a, b) {
  x <- governance_terms(a); y <- governance_terms(b)
  if (!length(x) || !length(y)) return(0)
  length(intersect(x, y)) / length(union(x, y))
}

# Deduplication (section 6.3): compares a candidate text with every requirement
# and work item. Returns the matches above `related`, most similar first, with a
# suggestion that always needs human review. Nothing is merged.
governance_dedup <- function(regs, text, module = "", duplicate = 0.6, related = 0.3) {
  q <- regs$requirements; w <- regs$work_items
  cand <- rbind(
    data.frame(id = q$requirement_id, module = q$module, priority = q$priority, status = q$status,
               text = q$description, stringsAsFactors = FALSE),
    data.frame(id = w$work_item_id, module = w$module, priority = w$priority, status = w$implementation_status,
               text = w$title, stringsAsFactors = FALSE))
  cand$similarity <- vapply(cand$text, function(t) governance_similarity(text, t), numeric(1), USE.NAMES = FALSE)
  cand <- cand[cand$similarity >= related, , drop = FALSE]
  cand <- cand[order(-cand$similarity, cand$id), , drop = FALSE]
  cand$suggestion <- ifelse(cand$similarity >= duplicate, "provável duplicata: revisar antes de criar",
                            "relacionado: verificar dependência, conflito ou reuso")
  if (nzchar(module)) cand$suggestion[cand$module != module] <- paste(cand$suggestion[cand$module != module],
                                                                    "(outro módulo)")
  cand$similarity <- round(cand$similarity, 2)
  rownames(cand) <- NULL
  cand[, c("id", "module", "priority", "status", "similarity", "suggestion", "text")]
}

# Near-duplicate pairs among registered requests (prompt deduplication).
governance_request_duplicates <- function(regs, threshold = 0.6) {
  r <- regs$requests
  out <- data.frame(request_a = character(), request_b = character(), similarity = numeric(),
                    stringsAsFactors = FALSE)
  n <- nrow(r)
  if (n < 2L) return(out)
  for (i in seq_len(n - 1L)) for (j in (i + 1L):n) {
    s <- governance_similarity(r$summary[i], r$summary[j])
    if (s >= threshold) out[nrow(out) + 1L, ] <- list(r$request_id[i], r$request_id[j], round(s, 2))
  }
  out
}

governance_split_ids <- function(x) {
  v <- trimws(unlist(strsplit(x[nzchar(x)], ";", fixed = TRUE)))
  v[nzchar(v)]
}

# Status a requirement's linked work items support (state machine, section 10).
# NA when there are no linked items: no evidence either way.
governance_derived_status <- function(items) {
  if (!nrow(items)) return(NA_character_)
  impl <- items$implementation_status; test <- items$test_status; acc <- items$acceptance_status
  if (any(impl == "blocked" | test == "blocked")) return("blocked")
  if (all(acc %in% c("approved", "not_applicable")) && any(acc == "approved")) return("accepted")
  if (all(impl == "implemented") && all(test %in% c("passed", "not_applicable"))) return("awaiting_acceptance")
  if (all(impl == "implemented")) return("implemented")
  if (any(impl %in% c("implemented", "in_progress"))) return("in_progress")
  "planned"
}

# Lifecycle position of a requirement status (section 10). "proposed" is the
# Common P01 name for a captured requirement.
governance_lifecycle <- c(captured = 1, proposed = 1, under_analysis = 2, planned = 3, awaiting_approval = 4,
                          approved = 5, in_progress = 6, blocked = 6, implemented = 7, under_testing = 8,
                          tested = 9, awaiting_acceptance = 10, accepted = 11)

# Reconciliation proposals (P13): one row per requirement whose recorded status
# differs from what its items support. `ambiguous` flags the cases a human must
# look at closely: a proposal that moves a status backwards, and "accepted",
# which older records used for "requirement agreed" rather than "delivery accepted".
governance_reconcile_requirements <- function(regs) {
  q <- regs$requirements; w <- regs$work_items
  rows <- lapply(seq_len(nrow(q)), function(i) {
    items <- w[w$requirement_id == q$requirement_id[i], , drop = FALSE]
    d <- governance_derived_status(items)
    cur <- q$status[i]
    if (is.na(d) || identical(d, cur) || cur %in% c("rejected", "cancelled")) return(NULL)
    back <- isTRUE(governance_lifecycle[d] < governance_lifecycle[cur])
    data.frame(requirement_id = q$requirement_id[i], current = cur, proposed = d,
               items = nrow(items),
               implemented = sum(items$implementation_status == "implemented"),
               tested = sum(items$test_status == "passed"),
               accepted = sum(items$acceptance_status == "approved"),
               ambiguous = back || cur == "accepted",
               note = if (cur == "accepted") "\"accepted\" registrado no sentido de requisito aprovado; confirmar o sentido"
                      else if (back) "a proposta recua o status; confirmar" else "",
               description = q$description[i], stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    out <- data.frame(requirement_id = character(), current = character(), proposed = character(),
                      items = integer(), implemented = integer(), tested = integer(), accepted = integer(),
                      ambiguous = logical(), note = character(), description = character(), stringsAsFactors = FALSE)
  }
  out
}

# Applies human-approved proposals, one requirement at a time. Each must still be a
# current proposal (the evidence may have changed since the report); the decision
# reference is stored as the transition evidence.
governance_apply_requirement_status <- function(dir, ids, decision_id, actor = "developer", at = governance_now()) {
  if (!grepl("^decision_[0-9]{4}$", decision_id)) stop("A decision_NNNN reference is required.", call. = FALSE)
  p <- governance_reconcile_requirements(governance_read(dir))
  missing <- setdiff(ids, p$requirement_id)
  if (length(missing)) stop("Not a current proposal: ", paste(missing, collapse = ", "), call. = FALSE)
  vapply(ids, function(id) {
    governance_set_field(dir, "requirements", id, "status", p$proposed[p$requirement_id == id], actor,
                         decision_id, at)
  }, character(1))
}

# Days from an item's first transition to its acceptance approval (NA when unmeasured).
governance_item_cycle_days <- function(regs) {
  tr <- regs$transitions
  w <- regs$work_items
  out <- vapply(w$work_item_id, function(id) {
    t <- tr[tr$entity_id == id, , drop = FALSE]
    a <- t[t$field == "acceptance_status" & t$to_status == "approved", , drop = FALSE]
    if (!nrow(a)) return(NA_real_)
    start <- min(governance_time(t$changed_at), na.rm = TRUE)
    end <- max(governance_time(a$changed_at), na.rm = TRUE)
    # Items whose first record is the acceptance itself (imported history) have no
    # measured cycle and stay out of the sample.
    if (!is.finite(start) || !is.finite(end) || start >= end) return(NA_real_)
    as.numeric(difftime(end, start, units = "days"))
  }, numeric(1))
  data.frame(work_item_id = w$work_item_id, type = w$type, days = out, stringsAsFactors = FALSE)
}

# Reported tokens per completed execution (NA when none were reported).
governance_execution_tokens <- function(regs) {
  e <- regs$executions
  if (!nrow(e)) return(numeric())
  e <- e[e$state == "completed" & nzchar(e$input_tokens) & nzchar(e$output_tokens), , drop = FALSE]
  as.numeric(e$input_tokens) + as.numeric(e$output_tokens)
}

# Plan for one requirement (section 7): tasks, dependencies, risks, acceptance
# criteria, recommended agent, complexity, estimates, checkpoints and tests.
governance_plan_requirement <- function(regs, id, min_sample = 3L) {
  q <- regs$requirements[regs$requirements$requirement_id == id, , drop = FALSE]
  if (nrow(q) != 1L) stop("Unknown requirement: ", id, call. = FALSE)
  w <- regs$work_items
  items <- w[w$requirement_id == id, , drop = FALSE]
  open <- items[items$acceptance_status != "approved", , drop = FALSE]
  deps <- setdiff(governance_split_ids(items$dependencies), items$work_item_id)
  dep_reqs <- unique(w$requirement_id[w$work_item_id %in% deps])
  blockers <- deps[deps %in% w$work_item_id[w$acceptance_status != "approved"]]
  files <- unique(governance_split_ids(items$evidence_links))
  score <- nrow(open) + length(deps) + length(files) / 3
  complexity <- if (!nrow(items)) "não decomposto" else if (!nrow(open)) "concluído" else if (score <= 2) "baixa" else if (score <= 5) "média" else "alta"
  # Comparable history only: accepted items of the same module (and type, when the
  # sample allows). Other modules never stand in.
  cyc <- governance_item_cycle_days(regs)
  cyc$module <- w$module[match(cyc$work_item_id, w$work_item_id)]
  cyc <- cyc[!is.na(cyc$days) & cyc$module == q$module, , drop = FALSE]
  same <- cyc[cyc$type %in% open$type, , drop = FALSE]
  basis <- if (nrow(same) >= min_sample) same else cyc
  effort <- if (!nrow(items)) NA_real_ else if (!nrow(open)) 0 else if (nrow(basis) >= min_sample) round(stats::median(basis$days) * nrow(open), 2) else NA_real_
  tok <- governance_execution_tokens(regs)
  tokens <- if (!nrow(items)) NA_real_ else if (!nrow(open)) 0 else if (length(tok) >= min_sample) round(stats::median(tok) * nrow(open)) else NA_real_
  e <- regs$executions
  done <- e[e$state == "completed" & e$work_item_id %in% w$work_item_id[w$module == q$module], , drop = FALSE]
  agent <- if (nrow(done)) names(sort(table(done$agent), decreasing = TRUE))[1] else
    if (nrow(items)) names(sort(table(items$owner), decreasing = TRUE))[1] else "developer"
  agent_basis <- if (nrow(done)) sprintf("%d execuções concluídas no módulo", nrow(done)) else
    if (nrow(items)) "responsável pelos itens do requisito (sem execuções registradas)" else "sem histórico"
  tests <- regs$tests[regs$tests$work_item_id %in% items$work_item_id, , drop = FALSE]
  strategy <- if (nrow(tests)) sprintf("manter os níveis já usados (%d testes registrados) e cobrir cada item aberto", nrow(tests)) else
    "unitário com dados sintéticos e integração; evidência registrada em test_register.csv"
  list(
    requirement = q,
    status_supported = governance_derived_status(items),
    tasks = open[, c("work_item_id", "title", "type", "priority", "implementation_status", "test_status",
                     "acceptance_status"), drop = FALSE],
    dependencies = list(items = deps, requirements = setdiff(dep_reqs, id), blocking = blockers),
    risks = c(if (length(blockers)) sprintf("depende de itens ainda não aceitos: %s", paste(blockers, collapse = ", ")),
              if (any(open$implementation_status == "blocked")) "há item bloqueado",
              if (any(open$test_status == "failed")) "há teste com falha",
              if (!nrow(items)) "sem itens de trabalho: requisito ainda não decomposto"),
    acceptance_criteria = q$acceptance_criteria,
    agent = list(recommended = agent, basis = agent_basis),
    complexity = list(level = complexity, score = round(score, 1),
                      basis = sprintf("%d itens abertos + %d dependências externas + %d arquivos de evidência / 3",
                                      nrow(open), length(deps), length(files))),
    effort_days = list(value = effort, sample = nrow(basis),
                       basis = "mediana do ciclo (primeira transição até o aceite) de itens aceitos do mesmo módulo x itens abertos"),
    tokens = list(value = tokens, sample = length(tok),
                  basis = "mediana de tokens informados por execução concluída x itens abertos"),
    checkpoints = c(sprintf("%s: implementado e testado", open$work_item_id), if (nrow(open)) "aceite humano do requisito"),
    test_strategy = strategy)
}

# Transparent ranking of the requirements still open (section 7). The recorded
# priority is only read. score = priority weight + items it unblocks + 1 if it is
# already under way - complexity penalty (alta 2, média 1).
governance_prioritize <- function(regs) {
  q <- regs$requirements; w <- regs$work_items
  weight <- c(high = 3, medium = 2, low = 1)
  rows <- lapply(q$requirement_id, function(id) {
    p <- governance_plan_requirement(regs, id)
    if (identical(p$status_supported, "accepted") || p$requirement$status %in% c("rejected", "cancelled")) return(NULL)
    mine <- w$work_item_id[w$requirement_id == id & w$acceptance_status != "approved"]
    unblocks <- sum(vapply(w$dependencies[w$requirement_id != id],
                           function(d) any(governance_split_ids(d) %in% mine), logical(1)))
    started <- as.numeric(any(w$implementation_status[w$requirement_id == id] %in% c("in_progress", "implemented")))
    penalty <- c("baixa" = 0, "média" = 1, "alta" = 2, "concluído" = 0, "não decomposto" = 0)[[p$complexity$level]]
    pw <- if (p$requirement$priority %in% names(weight)) weight[[p$requirement$priority]] else 0
    data.frame(requirement_id = id, module = p$requirement$module, priority = p$requirement$priority,
               priority_weight = pw, unblocks = unblocks, started = started, complexity = p$complexity$level,
               penalty = penalty, score = pw + unblocks + started - penalty,
               open_items = nrow(p$tasks), effort_days = p$effort_days$value, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) return(data.frame())
  out <- out[order(-out$score, out$requirement_id), , drop = FALSE]
  out$rank <- seq_len(nrow(out))
  rownames(out) <- NULL
  out
}

# A relative path an agent may read: inside the project, not protected.
governance_safe_path <- function(p) {
  nzchar(p) && !grepl("^([A-Za-z]:|/|\\\\|~)", p) && !grepl("(^|[/\\\\])\\.\\.([/\\\\]|$)", p) &&
    !grepl("(^|[/\\\\])\\.?(restricted|tmp)([/\\\\]|$)", p, ignore.case = TRUE)
}

# Context pack for an agent working on a requirement or work item (section 8):
# 1 register metadata, 2 validated summaries (paragraphs of handoff.md and
# project_status.md that cite the ID), 3 evidence files as excerpts (path and
# size; read incrementally), 4 complete files only on demand. Sources are added in
# tier order while they fit in `budget` characters. Sizes are characters: token
# counts are not estimated.
governance_context_pack <- function(root, regs, id, budget = 20000L) {
  tr <- governance_trace(regs, id)
  meta <- vapply(names(tr), function(n) {
    x <- tr[[n]]
    if (!nrow(x)) return("")
    paste(c(paste(names(x), collapse = ","), apply(x, 1, paste, collapse = ",")), collapse = "\n")
  }, character(1))
  rows <- data.frame(tier = 1L, source = paste0(names(tr), ": ", vapply(tr, nrow, integer(1)), " linha(s)"),
                     chars = nchar(meta), stringsAsFactors = FALSE)
  rows <- rows[rows$chars > 0, , drop = FALSE]
  pm <- governance_pm_dir(root)
  for (f in c("handoff.md", "project_status.md")) {
    p <- file.path(pm, f)
    if (!file.exists(p)) next
    txt <- readLines(p, warn = FALSE, encoding = "UTF-8")
    para <- cumsum(!nzchar(trimws(txt)))
    hit <- unique(para[grepl(id, txt, fixed = TRUE)])
    if (length(hit)) rows[nrow(rows) + 1L, ] <- list(2L, sprintf("%s: %d parágrafo(s) com %s", f, length(hit), id),
                                                     sum(nchar(txt[para %in% hit])))
  }
  w <- regs$work_items
  items <- w[w$requirement_id == id | w$work_item_id == id, , drop = FALSE]
  files <- unique(governance_split_ids(items$evidence_links))
  files <- files[vapply(files, governance_safe_path, logical(1))]
  for (f in files) {
    p <- file.path(root, f)
    if (file.exists(p) && !dir.exists(p)) rows[nrow(rows) + 1L, ] <- list(3L, f, as.integer(file.size(p)))
  }
  rows <- rows[order(rows$tier), , drop = FALSE]
  rows$included <- cumsum(rows$chars) <= budget
  rows$included[rows$tier == 1L] <- TRUE
  rownames(rows) <- NULL
  rows
}

# Replanning inputs since a time (section 14): what changed and must be weighed
# before the next step. Defaults to the last approved planning revision.
governance_replan_inputs <- function(regs, since = NULL) {
  pr <- regs$planning_revisions
  if (is.null(since)) {
    ap <- pr[pr$approval == "approved", , drop = FALSE]
    since <- if (nrow(ap)) max(ap$revised_at) else ""
  }
  t0 <- governance_time(since)
  after <- function(x) if (is.na(t0)) rep(TRUE, length(x)) else !is.na(governance_time(x)) & governance_time(x) > t0
  ex <- regs$executions
  tok <- governance_execution_tokens(list(executions = ex[after(ex$started_at), , drop = FALSE]))
  list(since = since,
       requests = regs$requests[after(regs$requests$received_at), c("request_id", "summary", "status"), drop = FALSE],
       failed_tests = regs$tests[regs$tests$result == "failed" & after(regs$tests$execution_timestamp), "test_id"],
       blocked_items = regs$work_items$work_item_id[regs$work_items$implementation_status == "blocked"],
       open_risks = regs$risks$risk_id[regs$risks$status == "open"],
       failed_executions = ex$execution_id[ex$state == "failed" & after(ex$started_at)],
       tokens = if (length(tok)) sum(tok) else NA_real_,
       pending_plans = pr$plan_id[pr$approval == "proposed"])
}

governance_md_table <- function(x) {
  if (!nrow(x)) return("Nenhum.")
  esc <- function(v) gsub("|", "\\|", gsub("\n", " ", as.character(v)), fixed = TRUE)
  c(paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("|", paste(rep(" --- ", ncol(x)), collapse = "|"), "|"),
    apply(x, 1, function(r) paste0("| ", paste(esc(ifelse(is.na(r), "indisponível", r)), collapse = " | "), " |")))
}

# Planning report (reports/governance/planning_report.md).
governance_planning_report <- function(regs, at = governance_now()) {
  pri <- governance_prioritize(regs)
  rec <- governance_reconcile_requirements(regs)
  rin <- governance_replan_inputs(regs)
  dup <- governance_request_duplicates(regs)
  fmt <- function(v) ifelse(is.na(v), NA, formatC(v, format = "f", digits = 2, big.mark = ".", decimal.mark = ","))
  plans <- unlist(lapply(head(pri$requirement_id, 5L), function(id) {
    p <- governance_plan_requirement(regs, id)
    c(sprintf("### %s — %s", id, substr(p$requirement$description, 1, 120)), "",
      sprintf("- Status registrado: `%s`; status que os itens sustentam: `%s`.", p$requirement$status,
              if (is.na(p$status_supported)) "sem itens" else p$status_supported),
      sprintf("- Complexidade: %s (pontuação %s = %s).", p$complexity$level, fmt(p$complexity$score), p$complexity$basis),
      sprintf("- Esforço estimado: %s (amostra de %d itens; %s).",
              if (is.na(p$effort_days$value)) "indisponível" else paste(fmt(p$effort_days$value), "dias"),
              p$effort_days$sample, p$effort_days$basis),
      sprintf("- Tokens estimados: %s (amostra de %d execuções).",
              if (is.na(p$tokens$value)) "indisponível" else format(p$tokens$value, big.mark = ".", decimal.mark = ","), p$tokens$sample),
      sprintf("- Agente recomendado: `%s` (%s).", p$agent$recommended, p$agent$basis),
      sprintf("- Dependências: %s.", if (length(p$dependencies$items)) paste(p$dependencies$items, collapse = ", ") else "nenhuma"),
      sprintf("- Riscos: %s.", if (length(p$risks)) paste(p$risks, collapse = "; ") else "nenhum identificado nos registros"),
      sprintf("- Estratégia de testes: %s.", p$test_strategy),
      "- Tarefas abertas:", "", governance_md_table(p$tasks[, c("work_item_id", "title", "implementation_status",
                                                             "test_status", "acceptance_status")]), "")
  }))
  c("# Planejamento — TaxMiner Governance", "",
    sprintf("Gerado em %s por `scripts/governance_registry.R plan-report`. Não editar à mão.", at), "",
    "Motor determinístico sobre os registros (Fase 03). Nada aqui altera prioridades ou status:",
    "as propostas de status só valem depois de aprovadas, uma a uma, pelo desenvolvedor.", "",
    "## Prioridade dos requisitos abertos", "",
    "Pontuação = peso da prioridade registrada (high 3, medium 2, low 1) + itens de outros requisitos que",
    "dependem deste + 1 se já iniciado − penalidade de complexidade (alta 2, média 1).", "",
    governance_md_table(transform(pri, effort_days = fmt(effort_days))[, c("rank", "requirement_id", "module", "priority",
                                                                      "priority_weight", "unblocks", "started",
                                                                      "complexity", "penalty", "score", "open_items",
                                                                      "effort_days")]), "",
    "## Plano dos cinco primeiros", "", plans,
    "## Reconciliação do status dos requisitos (P13, propostas)", "",
    "Cada linha precisa de aprovação humana própria. `ambiguous = TRUE` pede atenção especial.", "",
    governance_md_table(rec[, c("requirement_id", "current", "proposed", "items", "implemented", "tested", "accepted",
                                "ambiguous", "note")]), "",
    "## Entradas do replanejamento", "",
    sprintf("Desde a última revisão aprovada (%s):", if (nzchar(rin$since)) rin$since else "nenhuma"), "",
    sprintf("- Solicitações novas: %d.", nrow(rin$requests)),
    sprintf("- Testes com falha: %d.", length(rin$failed_tests)),
    sprintf("- Itens bloqueados: %s.", if (length(rin$blocked_items)) paste(rin$blocked_items, collapse = ", ") else "nenhum"),
    sprintf("- Riscos abertos: %d.", length(rin$open_risks)),
    sprintf("- Execuções com falha: %d.", length(rin$failed_executions)),
    sprintf("- Tokens informados: %s.", if (is.na(rin$tokens)) "indisponível" else format(rin$tokens, big.mark = ".", decimal.mark = ",")),
    sprintf("- Revisões de planejamento pendentes: %s.",
            if (length(rin$pending_plans)) paste(rin$pending_plans, collapse = ", ") else "nenhuma"), "",
    "## Solicitações possivelmente duplicadas", "",
    governance_md_table(dup))
}
