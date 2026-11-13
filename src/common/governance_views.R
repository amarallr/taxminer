# Governance views (Governança tab): pending work, acceptances, requirements and
# dependencies as plain tables in Portuguese, derived only from the registers in
# docs/project_management/ (read-only; nothing is inferred beyond the recorded states).
# Requires src/common/governance_registry.R.

# Portuguese labels of the register states.
governance_state_labels <- list(
  implementation_status = c(not_started = "não iniciado", in_progress = "em desenvolvimento", implemented = "implementado",
                            blocked = "bloqueado"),
  test_status = c(not_run = "não testado", passed = "aprovado nos testes", failed = "reprovado nos testes",
                  not_applicable = "não se aplica", blocked = "bloqueado"),
  acceptance_status = c(pending = "pendente", approved = "aceito", rejected = "recusado"),
  release_status = c(not_released = "não liberado", released = "liberado", blocked = "bloqueado"),
  requirement = c(proposed = "proposto", planned = "planejado", in_progress = "em andamento", accepted = "aceito",
                  blocked = "bloqueado", rejected = "recusado", superseded = "substituído"),
  request = c(captured = "registrado, sem requisito", linked = "ligado a requisito", answered = "atendido"),
  decision = c(approved = "aceito", rejected = "recusado", pending = "pendente"))

governance_label <- function(group, value) {
  l <- unname(governance_state_labels[[group]][value])
  ifelse(is.na(l), value, l)
}

# Situation of each work item, from its states (the first rule that applies).
# tone: wait (awaiting the developer), dev (agent working), todo (not started),
# block (blocked), done (accepted).
governance_item_situation <- function(w) {
  impl <- w$implementation_status; test <- w$test_status; acc <- w$acceptance_status
  n <- nrow(w)
  situation <- character(n); next_step <- character(n); tone <- character(n); who <- character(n)
  for (i in seq_len(n)) {
    s <- if (acc[i] == "approved") c("Aceito", "Liberação, se houver versão nova", "done", "Você (versão)")
      else if (acc[i] == "rejected") c("Recusado no aceite", "Corrigir e reapresentar", "block", "Agente")
      else if (impl[i] == "blocked" || test[i] == "blocked") c("Bloqueado", "Remover o bloqueio", "block", "Ver riscos")
      else if (impl[i] == "implemented" && test[i] %in% c("passed", "not_applicable")) c("Implementado e testado", "Seu aceite", "wait", "Você")
      else if (impl[i] == "implemented" && test[i] == "failed") c("Implementado; testes falharam", "Corrigir", "block", "Agente")
      else if (impl[i] == "implemented") c("Implementado, sem teste", "Testar", "dev", "Agente")
      else if (impl[i] == "in_progress") c("Em desenvolvimento", "Concluir e testar", "dev", "Agente")
      else c("Não iniciado", "Autorização e implementação", "todo", "Você (autorização)")
    situation[i] <- s[1]; next_step[i] <- s[2]; tone[i] <- s[3]; who[i] <- s[4]
  }
  data.frame(situation = situation, next_step = next_step, tone = tone, who = who, stringsAsFactors = FALSE)
}

governance_split_ids <- function(x) {
  v <- trimws(unlist(strsplit(x, "[;, ]+")))
  v[nzchar(v)]
}

# Dependencies of each item that are not accepted yet ("work_0038 (não iniciado)").
governance_open_dependencies <- function(w) {
  vapply(seq_len(nrow(w)), function(i) {
    deps <- governance_split_ids(w$dependencies[i])
    if (!length(deps)) return("")
    j <- match(deps, w$work_item_id)
    open <- is.na(j) | w$acceptance_status[pmax(j, 1L)] != "approved"
    open[is.na(j)] <- TRUE
    if (!any(open)) return("")
    sit <- governance_item_situation(w[j[open & !is.na(j)], , drop = FALSE])$situation
    lab <- deps[open]
    lab[!is.na(j[open])] <- paste0(lab[!is.na(j[open])], " (", tolower(sit), ")")
    paste(lab, collapse = "; ")
  }, character(1))
}

# Pending work: items not accepted, plus requests captured without a requirement.
# Ordered: awaiting the developer, in development, blocked, not started, requests.
governance_pending_view <- function(regs) {
  w <- regs$work_items
  w <- w[w$acceptance_status != "approved", , drop = FALSE]
  s <- governance_item_situation(w)
  deps <- governance_open_dependencies(regs$work_items)[match(w$work_item_id, regs$work_items$work_item_id)]
  depends <- ifelse(nzchar(deps), paste(s$who, "·", deps), s$who)
  depends[s$tone == "todo" & nzchar(deps)] <- paste("Itens:", deps[s$tone == "todo" & nzchar(deps)])
  items <- data.frame(id = w$work_item_id, title = w$title, requirement = w$requirement_id, situation = s$situation,
                      tone = s$tone, next_step = s$next_step, depends = depends, priority = w$priority,
                      stringsAsFactors = FALSE)
  q <- regs$requests
  q <- q[q$status == "captured", , drop = FALSE]
  reqs <- data.frame(id = q$request_id, title = q$summary, requirement = ifelse(nzchar(q$requirement_ids), q$requirement_ids, "—"),
                     situation = rep("Pedido registrado, sem requisito", nrow(q)), tone = rep("todo", nrow(q)),
                     next_step = rep("Planejar (requisito e itens)", nrow(q)), depends = rep("Você", nrow(q)),
                     priority = rep("", nrow(q)), stringsAsFactors = FALSE)
  out <- rbind(items, reqs)
  rank <- c(wait = 1L, dev = 2L, block = 3L, todo = 4L)
  out <- out[order(rank[out$tone], out$priority != "high", out$id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Acceptances with the requirement of their item, newest first.
governance_acceptance_view <- function(regs) {
  a <- regs$acceptances
  w <- regs$work_items
  out <- data.frame(id = a$acceptance_id, criteria = a$criteria, item = a$work_item_id,
                    requirement = w$requirement_id[match(a$work_item_id, w$work_item_id)],
                    decision = a$decision, at = a$decision_timestamp, reviewer = a$reviewer,
                    stringsAsFactors = FALSE)
  out$requirement[is.na(out$requirement)] <- "—"
  out <- out[order(out$at, out$id, decreasing = TRUE), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Requirements with their items: total, accepted, awaiting the developer, open.
governance_requirement_view <- function(regs) {
  r <- regs$requirements
  w <- regs$work_items
  s <- governance_item_situation(w)
  count <- function(id, cond) sum(w$requirement_id == id & cond)
  out <- data.frame(
    id = r$requirement_id, description = r$description, module = r$module, priority = r$priority, status = r$status,
    items = vapply(r$requirement_id, function(id) count(id, TRUE), integer(1)),
    accepted = vapply(r$requirement_id, function(id) count(id, w$acceptance_status == "approved"), integer(1)),
    waiting = vapply(r$requirement_id, function(id) count(id, s$tone == "wait"), integer(1)),
    open = vapply(r$requirement_id, function(id) count(id, s$tone %in% c("dev", "todo", "block")), integer(1)),
    stringsAsFactors = FALSE)
  rownames(out) <- NULL
  out
}

# Items with dependencies: each dependency with its situation, and whether the item can start.
governance_dependency_view <- function(regs) {
  w <- regs$work_items
  has <- nzchar(trimws(w$dependencies))
  w2 <- w[has, , drop = FALSE]
  if (!nrow(w2)) return(data.frame(id = character(), title = character(), situation = character(), tone = character(),
                                   depends = character(), ready = character(), stringsAsFactors = FALSE))
  s <- governance_item_situation(w2)
  all_s <- governance_item_situation(w)
  depends <- vapply(w2$dependencies, function(d) {
    ids <- governance_split_ids(d)
    j <- match(ids, w$work_item_id)
    paste(ifelse(is.na(j), paste0(ids, " (não encontrado)"), paste0(ids, " (", tolower(all_s$situation[pmax(j, 1L)]), ")")),
          collapse = "; ")
  }, character(1), USE.NAMES = FALSE)
  open <- governance_open_dependencies(w)[has]
  ready <- ifelse(s$tone == "done", "concluído", ifelse(nzchar(open), "aguarda dependências", "dependências atendidas"))
  out <- data.frame(id = w2$work_item_id, title = w2$title, situation = s$situation, tone = s$tone, depends = depends,
                    ready = ready, stringsAsFactors = FALSE)
  out <- out[order(out$tone == "done", out$id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Risk likelihood and impact in Portuguese.
governance_state_labels$risk <- c(likely = "provável", possible = "possível", observed = "observado", unknown = "desconhecido",
                                  low = "baixo", medium = "médio", high = "alto")

# Portuguese texts of the registers (config/governance_texts_pt.csv: id, field,
# text). The registers stay as recorded (the audit source); the Governança tab
# shows the Portuguese text of each free-text field when there is one and the
# recorded text otherwise. State codes are never replaced (the views compare them).
governance_texts_path <- function(root) file.path(root, "config", "governance_texts_pt.csv")

governance_texts_read <- function(path) {
  if (!file.exists(path)) return(data.frame(id = character(), field = character(), text = character()))
  utils::read.csv(path, colClasses = "character", na.strings = character(), encoding = "UTF-8",
                  stringsAsFactors = FALSE)
}

governance_localize <- function(regs, texts) {
  if (is.null(texts) || !nrow(texts)) return(regs)
  for (name in names(regs)) {
    spec <- governance_specs[[name]]
    x <- regs[[name]]
    if (is.null(spec) || !is.data.frame(x) || !nrow(x)) next
    for (field in intersect(unique(texts$field), names(x))) {
      t <- texts[texts$field == field, , drop = FALSE]
      k <- match(x[[spec$id]], t$id)
      x[[field]][!is.na(k)] <- t$text[k[!is.na(k)]]
    }
    regs[[name]] <- x
  }
  regs
}

# Register fields and recorded codes in Portuguese for the detail and audit
# tables (unknown names and values pass through).
governance_field_labels <- c(
  work_item_id = "item", requirement_id = "requisito", acceptance_id = "aceite", request_id = "pedido",
  risk_id = "risco", test_id = "teste", plan_id = "plano", revision_id = "revisão", transition_id = "transição",
  execution_id = "execução", module = "módulo", title = "título", type = "tipo", priority = "prioridade",
  owner = "responsável", dependencies = "dependências", implementation_status = "implementação",
  test_status = "teste", acceptance_status = "aceite", release_status = "liberação", operations_status = "operação",
  evidence_links = "evidências", updated_at = "atualizado em", description = "descrição", source = "origem",
  acceptance_criteria = "critérios de aceite", status = "status", criteria = "critério", reviewer = "revisor",
  decision = "decisão", decision_timestamp = "data da decisão", evidence_path = "evidência", notes = "observações",
  likelihood = "probabilidade", impact = "impacto", mitigation = "mitigação", received_at = "recebido em",
  channel = "canal", agent = "agente", summary = "resumo", classification = "classificação",
  requirement_ids = "requisitos", level = "nível", environment = "ambiente", execution_timestamp = "executado em",
  result = "resultado", code_commit = "commit", revised_at = "revisado em", phase = "fase", reason = "motivo",
  approval = "aprovação", evidence = "evidência", prompt_file = "arquivo do prompt", version = "versão",
  previous_version = "versão anterior", change_class = "classe da mudança", improvements = "melhorias",
  affected_requirements = "requisitos afetados", base_commit = "commit base", validation = "validação",
  approver = "aprovador", entity_id = "registro", field = "campo", from_status = "de", to_status = "para",
  changed_at = "quando", actor = "quem")

governance_value_labels <- c(
  high = "alta", medium = "média", low = "baixa",  # priority (risk levels use governance_label("risk", ...))
  unlist(unname(governance_state_labels[c("implementation_status", "test_status", "acceptance_status",
                                          "release_status", "requirement", "risk")])),
  approved = "aceito", rejected = "recusado", proposed = "proposto", passed = "aprovado", failed = "falhou",
  skipped = "ignorado", not_applicable = "não se aplica", not_started = "não iniciado", open = "aberto",
  mitigated = "mitigado", closed = "encerrado", captured = "registrado", linked = "ligado a requisito",
  answered = "atendido", under_analysis = "em análise", developer = "desenvolvedor", feature = "funcionalidade",
  analysis = "análise", milestone = "marco", bug = "correção", refactoring = "refatoração", performance = "desempenho",
  security = "segurança", documentation = "documentação", unit = "unitário", integration = "integração",
  local = "local", queued = "na fila", running = "em execução", paused = "pausado", completed = "concluído",
  interrupted = "interrompido", in_progress = "em andamento", common = "comum", data = "dados",
  intelligence = "inteligência", collect = "coleta", high = "alta", medium = "média", low = "baixa",
  claude_code = "Claude Code", codex = "Codex")

governance_field_label <- function(x) { l <- unname(governance_field_labels[x]); ifelse(is.na(l), x, l) }
governance_value_label <- function(x) { l <- unname(governance_value_labels[x]); ifelse(is.na(l) | !nzchar(x), x, l) }
