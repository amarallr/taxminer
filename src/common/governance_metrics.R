# TaxMiner Governance — KPIs and dashboard data (phase 05, req_0021).
# Pure functions over the registers read by governance_read() (and the
# immutable-layer check): filters, KPIs with formal definitions, pipeline,
# timeline, agent performance, traceability graph and audit trail.
# Requires src/common/governance_registry.R. source() only defines functions.
#
# Rules (prompt sections 8 and 11): a KPI that cannot be measured is NA
# ("indisponível") with the reason, never zero or an estimate.

# Formal definitions shown next to each KPI (tooltip) and in the exported report.
governance_kpi_definitions <- data.frame(
  id = c("total_requests", "total_requirements", "planned", "approved", "in_progress", "implemented", "tested",
         "accepted", "blocked", "overdue", "rework_rate", "test_coverage", "token_consumption",
         "cost_per_accepted", "average_cycle_time", "agent_failure_rate", "pending_human_decisions"),
  label = c("Solicitações", "Requisitos", "Planejados", "Aprovados", "Em andamento", "Implementados", "Testados",
            "Aceitos", "Bloqueados", "Atrasados", "Taxa de retrabalho", "Cobertura de testes",
            "Consumo de tokens", "Custo por requisito aceito", "Tempo médio de ciclo",
            "Taxa de falha de agente", "Decisões humanas pendentes"),
  definition = c(
    "Linhas de request_register.csv recebidas no período.",
    "Linhas de requirements_register.csv que passam pelos filtros.",
    "Requisitos com status planned.",
    "Requisitos com status approved.",
    "Requisitos com status in_progress.",
    "Itens de trabalho com implementation_status = implemented.",
    "Itens de trabalho com test_status = passed.",
    "Itens de trabalho com acceptance_status = approved (exige linha aprovada em acceptance_register.csv).",
    "Itens de trabalho com blocked em qualquer dimensão, mais requisitos com status blocked.",
    "Itens não concluídos com data-alvo vencida. O registro não tem datas-alvo: indisponível.",
    "Transições de volta (passed→failed, implemented→in_progress ou not_started, approved→rejected ou pending) ÷ itens de trabalho com alguma transição.",
    "Itens implementados com ao menos um teste passed em test_register.csv ÷ itens implementados. Não é cobertura de código.",
    "Soma de input_tokens + output_tokens das execuções que informam tokens (nunca estimados).",
    "Soma de reported_cost das execuções ÷ itens aceitos. Indisponível sem custo informado.",
    "Média, em dias, entre a primeira transição de um item e a aprovação do aceite, só para itens com as duas na trilha.",
    "Execuções failed ÷ execuções encerradas (failed, completed, interrupted).",
    "Itens implementados e testados com aceite pending, mais revisões de prompt e de planejamento proposed."),
  unit = c("count", "count", "count", "count", "count", "count", "count", "count", "count", "count", "pct", "pct",
           "count", "money", "days", "pct", "count"),
  stringsAsFactors = FALSE)

# Lifecycle order of the master prompt (section 10): "accepted" is the final state,
# after "awaiting_acceptance" (fixed in phase 03); "proposed" is the Common P01 name for captured.
governance_requirement_order <- c("captured", "proposed", "under_analysis", "planned", "awaiting_approval",
                                  "approved", "in_progress", "blocked", "implemented", "under_testing", "tested",
                                  "awaiting_acceptance", "accepted", "rejected", "cancelled")

# ISO 8601 with offset -> POSIXct (NA for empty or "unknown").
governance_time <- function(x) {
  x <- as.character(x)
  x <- sub("Z$", "+0000", sub("([+-]\\d{2}):(\\d{2})$", "\\1\\2", x))
  out <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC")
  short <- is.na(out) & grepl("T\\d{2}:\\d{2}[+-]", x)
  out[short] <- as.POSIXct(x[short], format = "%Y-%m-%dT%H:%M%z", tz = "UTC")
  out
}

# Values offered by the filters.
governance_filter_choices <- function(regs) {
  list(agent = sort(unique(c(regs$executions$agent, regs$requests$agent)[nzchar(c(regs$executions$agent, regs$requests$agent))])),
       module = sort(unique(c(regs$requirements$module, regs$work_items$module))),
       priority = sort(unique(c(regs$requirements$priority, regs$work_items$priority))),
       status = intersect(governance_requirement_order, unique(regs$requirements$status)))
}

# Applies the dashboard filters. `f` is a list with any of: from, to (Date),
# agent, module, priority, status (character vectors; empty = all). Module,
# priority and status select requirements; work items, tests, acceptances,
# executions and transitions follow the selected requirements. Period limits
# each register by its own timestamp. Risks and the prompt history are not
# filtered by requirement.
governance_filter <- function(regs, f = list()) {
  on <- function(v) !is.null(v) && length(v) && any(nzchar(v))
  in_period <- function(t) {
    d <- as.Date(governance_time(t), tz = "America/Sao_Paulo")
    keep <- rep(TRUE, length(t))
    if (!is.null(f$from) && !is.na(f$from)) keep <- keep & !is.na(d) & d >= as.Date(f$from)
    if (!is.null(f$to) && !is.na(f$to)) keep <- keep & !is.na(d) & d <= as.Date(f$to)
    keep
  }
  r <- regs
  rq <- r$requirements
  w <- r$work_items
  scoped <- on(f$module) || on(f$priority) || on(f$status)
  if (on(f$module)) {
    rq <- rq[rq$module %in% f$module, , drop = FALSE]
    w <- w[w$module %in% f$module, , drop = FALSE]
  }
  if (on(f$priority)) rq <- rq[rq$priority %in% f$priority, , drop = FALSE]
  if (on(f$status)) rq <- rq[rq$status %in% f$status, , drop = FALSE]
  if (scoped) w <- w[w$requirement_id %in% rq$requirement_id, , drop = FALSE]
  if (on(f$priority) && !on(f$status)) {
    # Work items carry their own priority; keep those that match too.
    w <- w[w$priority %in% f$priority | w$requirement_id %in% rq$requirement_id, , drop = FALSE]
  }
  r$requirements <- rq
  r$work_items <- w
  ids_w <- w$work_item_id
  r$tests <- r$tests[r$tests$work_item_id %in% ids_w & in_period(r$tests$execution_timestamp), , drop = FALSE]
  r$acceptances <- r$acceptances[r$acceptances$work_item_id %in% ids_w & in_period(r$acceptances$decision_timestamp), , drop = FALSE]
  q <- r$requests
  if (scoped) q <- q[vapply(q$requirement_ids, function(v) any(split_ids(v) %in% rq$requirement_id), logical(1)), , drop = FALSE]
  if (on(f$agent)) q <- q[q$agent %in% f$agent, , drop = FALSE]
  r$requests <- q[in_period(q$received_at), , drop = FALSE]
  x <- r$executions
  if (scoped) x <- x[x$work_item_id %in% ids_w | x$request_id %in% r$requests$request_id, , drop = FALSE]
  if (on(f$agent)) x <- x[x$agent %in% f$agent, , drop = FALSE]
  r$executions <- x[in_period(x$started_at), , drop = FALSE]
  tr <- r$transitions
  if (scoped || on(f$agent)) {
    keep_ids <- c(rq$requirement_id, ids_w, r$tests$test_id, r$acceptances$acceptance_id, r$requests$request_id,
                  r$executions$execution_id)
    tr <- tr[tr$entity_id %in% keep_ids, , drop = FALSE]
  }
  r$transitions <- tr[in_period(tr$changed_at), , drop = FALSE]
  r
}

# Backward moves counted as rework.
governance_rework_moves <- data.frame(
  field = c("test_status", "implementation_status", "implementation_status", "acceptance_status", "acceptance_status"),
  from = c("passed", "implemented", "implemented", "approved", "approved"),
  to = c("failed", "in_progress", "not_started", "rejected", "pending"),
  stringsAsFactors = FALSE)

# KPIs over (filtered) registers: id, label, value (NA = unavailable), unit, note.
governance_kpis <- function(regs) {
  rq <- regs$requirements
  w <- regs$work_items
  x <- regs$executions
  tr <- regs$transitions
  num <- function(v) suppressWarnings(as.numeric(v))
  val <- list(); note <- list()
  set <- function(id, v, n = "") { val[[id]] <<- v; note[[id]] <<- n }
  set("total_requests", nrow(regs$requests))
  set("total_requirements", nrow(rq))
  set("planned", sum(rq$status == "planned"))
  set("approved", sum(rq$status == "approved"))
  set("in_progress", sum(rq$status == "in_progress"))
  set("implemented", sum(w$implementation_status == "implemented"))
  set("tested", sum(w$test_status == "passed"))
  set("accepted", sum(w$acceptance_status == "approved"))
  dims <- c("implementation_status", "test_status", "release_status")
  set("blocked", sum(Reduce(`|`, lapply(dims, function(d) w[[d]] == "blocked"), rep(FALSE, nrow(w)))) +
        sum(rq$status == "blocked"))
  set("overdue", NA_real_, "indisponível: o registro não tem datas-alvo")
  wtr <- tr[tr$entity_id %in% w$work_item_id, , drop = FALSE]
  touched <- unique(wtr$entity_id)
  if (length(touched)) {
    back <- merge(wtr, governance_rework_moves, by.x = c("field", "from_status", "to_status"),
                  by.y = c("field", "from", "to"))
    set("rework_rate", length(unique(back$entity_id)) / length(touched),
        sprintf("%d de %d itens com trilha", length(unique(back$entity_id)), length(touched)))
  } else set("rework_rate", NA_real_, "indisponível: nenhum item com transições no período")
  impl <- w$work_item_id[w$implementation_status == "implemented"]
  if (length(impl)) {
    covered <- impl %in% regs$tests$work_item_id[regs$tests$result == "passed"]
    set("test_coverage", mean(covered), sprintf("%d de %d implementados", sum(covered), length(impl)))
  } else set("test_coverage", NA_real_, "indisponível: nenhum item implementado")
  has_tok <- nzchar(x$input_tokens) | nzchar(x$output_tokens)
  if (any(has_tok)) {
    set("token_consumption", sum(num(x$input_tokens[has_tok]), num(x$output_tokens[has_tok]), na.rm = TRUE),
        sprintf("%d de %d execuções informam tokens", sum(has_tok), nrow(x)))
  } else set("token_consumption", NA_real_, sprintf("indisponível: %d execuções, nenhuma informa tokens", nrow(x)))
  cost <- num(x$reported_cost[nzchar(x$reported_cost)])
  accepted <- sum(w$acceptance_status == "approved")
  if (length(cost) && accepted) set("cost_per_accepted", sum(cost) / accepted, sprintf("custo de %d execuções", length(cost)))
  else set("cost_per_accepted", NA_real_, "indisponível: nenhum custo informado")
  first <- tapply(governance_time(wtr$changed_at), wtr$entity_id, min)
  acc <- wtr[wtr$field == "acceptance_status" & wtr$to_status == "approved", , drop = FALSE]
  if (nrow(acc)) {
    done <- tapply(governance_time(acc$changed_at), acc$entity_id, max)
    days <- (as.numeric(done) - as.numeric(first[names(done)])) / 86400
    set("average_cycle_time", mean(days), sprintf("%d itens com início e aceite na trilha", length(days)))
  } else set("average_cycle_time", NA_real_, "indisponível: nenhum aceite com trilha no período")
  ended <- x$state %in% c("failed", "completed", "interrupted")
  if (any(ended)) set("agent_failure_rate", sum(x$state == "failed") / sum(ended), sprintf("%d execuções encerradas", sum(ended)))
  else set("agent_failure_rate", NA_real_, "indisponível: nenhuma execução encerrada")
  pend_w <- sum(w$acceptance_status == "pending" & w$implementation_status == "implemented" &
                  w$test_status %in% c("passed", "not_applicable"))
  pend_p <- sum(regs$prompt_revisions$approval == "proposed") + sum(regs$planning_revisions$approval == "proposed")
  set("pending_human_decisions", pend_w + pend_p, sprintf("%d aceites, %d revisões propostas", pend_w, pend_p))
  d <- governance_kpi_definitions
  d$value <- vapply(d$id, function(i) as.numeric(val[[i]]), numeric(1))
  d$note <- vapply(d$id, function(i) note[[i]], character(1))
  d
}

# Formats a KPI value in pt-BR; NA -> "indisponível".
governance_format_kpi <- function(value, unit) {
  if (is.na(value)) return("indisponível")
  br <- function(v, d) formatC(v, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
  switch(unit,
         pct = paste0(br(100 * value, 1), "%"),
         money = paste0("US$ ", br(value, 2)),
         days = paste(br(value, 1), "dias"),
         br(value, 0))
}

# Requirements pipeline: count per lifecycle status, in lifecycle order.
governance_pipeline <- function(regs) {
  s <- regs$requirements$status
  st <- c(intersect(governance_requirement_order, unique(s)), setdiff(unique(s), governance_requirement_order))
  data.frame(status = st, n = vapply(st, function(v) sum(s == v), integer(1)), stringsAsFactors = FALSE)
}

# Delivery stages of work items (Common P01 dimensions), cumulative.
governance_delivery_stages <- function(regs) {
  w <- regs$work_items
  data.frame(stage = c("Itens", "Implementados", "Testados", "Aceitos", "Liberados"),
             n = c(nrow(w), sum(w$implementation_status == "implemented"), sum(w$test_status == "passed"),
                   sum(w$acceptance_status == "approved"), sum(w$release_status == "released")),
             stringsAsFactors = FALSE)
}

# Per-agent performance over executions.
governance_agent_performance <- function(regs, now = Sys.time()) {
  x <- regs$executions
  if (!nrow(x)) {
    return(data.frame(agent = character(), executions = integer(), completed = integer(), failed = integer(),
                      open = integer(), failure_rate = numeric(), mean_minutes = numeric(), tokens = numeric(),
                      stringsAsFactors = FALSE))
  }
  num <- function(v) suppressWarnings(as.numeric(v))
  t0 <- governance_time(x$started_at)
  t1 <- governance_time(x$ended_at)
  minutes <- as.numeric(difftime(t1, t0, units = "mins"))
  do.call(rbind, lapply(sort(unique(x$agent)), function(a) {
    k <- x$agent == a
    ended <- k & x$state %in% c("failed", "completed", "interrupted")
    tok <- k & (nzchar(x$input_tokens) | nzchar(x$output_tokens))
    data.frame(agent = a, executions = sum(k), completed = sum(k & x$state == "completed"),
               failed = sum(k & x$state == "failed"), open = sum(k & x$state %in% c("queued", "running", "paused", "unknown")),
               failure_rate = if (any(ended)) sum(k & x$state == "failed") / sum(ended) else NA_real_,
               mean_minutes = if (any(ended & !is.na(minutes))) mean(minutes[ended & !is.na(minutes)]) else NA_real_,
               tokens = if (any(tok)) sum(num(x$input_tokens[tok]), num(x$output_tokens[tok]), na.rm = TRUE) else NA_real_,
               stringsAsFactors = FALSE)
  }))
}

# Traceability graph around one ID: nodes (id, kind, label, column) and edges
# (from, to). Columns: requests, requirements, work items, executions/tests/
# acceptances, commits and evidence. Two hops from the focus.
governance_graph <- function(regs, id) {
  nodes <- list(); edges <- list()
  kind_of <- function(i) {
    p <- sub("_\\d+$", "", i)
    switch(p, request = "request", req = "requirement", work = "work_item", exec = "execution", test = "test",
           acc = "acceptance", risk = "risk", prv = "prompt_revision", plan = "plan", imm = "immutable_rule",
           if (grepl("^commit:", i)) "commit" else if (grepl("^file:", i)) "evidence" else "other")
  }
  column <- c(request = 1, requirement = 2, work_item = 3, execution = 4, test = 4, acceptance = 4, commit = 5,
              evidence = 5, risk = 2, prompt_revision = 2, plan = 2, immutable_rule = 2, other = 5)
  label_of <- function(i) {
    find <- function(tab, key, col) { v <- tab[[col]][tab[[key]] == i]; if (length(v)) v[1] else "" }
    switch(kind_of(i),
           request = find(regs$requests, "request_id", "summary"),
           requirement = find(regs$requirements, "requirement_id", "description"),
           work_item = find(regs$work_items, "work_item_id", "title"),
           execution = paste(find(regs$executions, "execution_id", "agent"), find(regs$executions, "execution_id", "state")),
           test = find(regs$tests, "test_id", "result"),
           acceptance = find(regs$acceptances, "acceptance_id", "decision"),
           sub("^(commit|file):", "", i))
  }
  add_node <- function(i) if (is.null(nodes[[i]])) nodes[[i]] <<- i
  add_edge <- function(a, b) { add_node(a); add_node(b); edges[[length(edges) + 1L]] <<- c(a, b) }
  neighbours <- function(i) {
    out <- character()
    k <- kind_of(i)
    rq <- regs$requests; w <- regs$work_items; x <- regs$executions; t <- regs$tests; a <- regs$acceptances
    if (k == "request") {
      for (r in split_ids(rq$requirement_ids[rq$request_id == i])) add_edge(i, r)
      for (e in x$execution_id[x$request_id == i]) add_edge(i, e)
    } else if (k == "requirement") {
      for (q in rq$request_id[vapply(rq$requirement_ids, function(v) i %in% split_ids(v), logical(1))]) add_edge(q, i)
      for (wi in w$work_item_id[w$requirement_id == i]) add_edge(i, wi)
    } else if (k == "work_item") {
      for (r in w$requirement_id[w$work_item_id == i]) if (nzchar(r)) add_edge(r, i)
      for (e in x$execution_id[x$work_item_id == i]) add_edge(i, e)
      for (ti in t$test_id[t$work_item_id == i]) add_edge(i, ti)
      for (ai in a$acceptance_id[a$work_item_id == i]) add_edge(i, ai)
      ev <- head(split_ids(w$evidence_links[w$work_item_id == i]), 6L)
      for (f in ev) add_edge(i, paste0("file:", f))
    } else if (k == "test") {
      wi <- t$work_item_id[t$test_id == i]; if (length(wi)) add_edge(wi, i)
      cm <- sub("\\+.*$", "", t$code_commit[t$test_id == i])
      if (length(cm) && nzchar(cm) && cm != "unknown") add_edge(i, paste0("commit:", cm))
      ev <- t$evidence_path[t$test_id == i]; if (length(ev) && nzchar(ev)) add_edge(i, paste0("file:", ev))
    } else if (k == "acceptance") {
      wi <- a$work_item_id[a$acceptance_id == i]; if (length(wi)) add_edge(wi, i)
    } else if (k == "execution") {
      wi <- x$work_item_id[x$execution_id == i]; if (length(wi) && nzchar(wi)) add_edge(wi, i)
      q <- x$request_id[x$execution_id == i]; if (length(q) && nzchar(q)) add_edge(q, i)
    }
    unique(c(vapply(edges, `[`, "", 1), vapply(edges, `[`, "", 2)))
  }
  add_node(id)
  hop1 <- setdiff(neighbours(id), id)
  for (n in hop1) if (!grepl("^(commit|file):", n)) neighbours(n)
  ids <- names(nodes)
  k <- vapply(ids, kind_of, character(1))
  n <- data.frame(id = ids, kind = k, label = vapply(ids, label_of, character(1)), column = unname(column[k]),
                  focus = ids == id, stringsAsFactors = FALSE)
  e <- if (length(edges)) unique(as.data.frame(do.call(rbind, edges), stringsAsFactors = FALSE)) else
    data.frame(V1 = character(), V2 = character(), stringsAsFactors = FALSE)
  names(e) <- c("from", "to")
  list(nodes = n[order(n$column, n$id), , drop = FALSE], edges = e)
}

# Audit trail: transitions, newest first.
governance_audit <- function(regs, n = 200L) {
  tr <- regs$transitions
  if (!nrow(tr)) return(tr)
  o <- order(governance_time(tr$changed_at), tr$transition_id, decreasing = TRUE)
  utils::head(tr[o, , drop = FALSE], n)
}

# Freshness of the data: last real progress (newest transition) and whether the
# last successful synchronisation is older than two refresh intervals.
governance_freshness <- function(regs, last_sync, interval_s, now = Sys.time()) {
  t <- governance_time(regs$transitions$changed_at)
  progress <- if (length(t) && any(!is.na(t))) max(t, na.rm = TRUE) else as.POSIXct(NA)
  stale <- is.na(last_sync) || (interval_s > 0 && as.numeric(difftime(now, last_sync, units = "secs")) > 2 * interval_s)
  list(last_progress = progress, stale = stale)
}

# Signature of the register files (name, size, modification time): the
# dashboard re-reads the registers only when it changes.
governance_signature <- function(dir) {
  files <- file.path(dir, c(vapply(governance_specs, `[[`, "", "file"), "decision_log.md"))
  info <- file.info(files)
  paste(basename(files), info$size, format(info$mtime, "%Y%m%d%H%M%OS3"), collapse = "|")
}

# Markdown report of the KPIs and the filters in force (export).
governance_report_md <- function(regs, filters, at = governance_now()) {
  k <- governance_kpis(regs)
  fdesc <- vapply(names(filters), function(n) {
    v <- filters[[n]]
    if (is.null(v) || !length(v) || all(!nzchar(as.character(v))) || all(is.na(v))) return(NA_character_)
    paste0(n, " = ", paste(as.character(v), collapse = ", "))
  }, character(1))
  fdesc <- fdesc[!is.na(fdesc)]
  esc <- function(v) gsub("|", "\\|", v, fixed = TRUE)
  c("# TaxMiner Governance — relatório executivo", "",
    sprintf("Gerado em %s. Filtros: %s.", at, if (length(fdesc)) paste(fdesc, collapse = "; ") else "nenhum"), "",
    "| Indicador | Valor | Observação | Definição |", "| --- | --- | --- | --- |",
    sprintf("| %s | %s | %s | %s |", k$label, mapply(governance_format_kpi, k$value, k$unit), esc(k$note), esc(k$definition)),
    "", "## Funil de requisitos", "", "| Status | Requisitos |", "| --- | --- |",
    with(governance_pipeline(regs), sprintf("| %s | %d |", status, n)),
    "", "## Entrega dos itens de trabalho", "", "| Etapa | Itens |", "| --- | --- |",
    with(governance_delivery_stages(regs), sprintf("| %s | %d |", stage, n)))
}
