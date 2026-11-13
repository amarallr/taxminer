# Governança — Executive Command Center (TaxMiner Governance phase 05, req_0021).
# Local app only: the governance registers are project records, not public data,
# so this page is not part of the published static site.
# Data: docs/project_management/ through src/common/governance_*.R (read-only;
# the page never starts executions or writes a register).
# Refresh: every 150 s by default (configurable); registers are re-read only when
# their files change; the last good data stays on screen if a read fails.

gov_kind_colors <- c(request = "#6b7480", requirement = "#051c2c", work_item = "#1f4fd1", execution = "#0f8b8d",
                     test = "#7a5195", acceptance = "#a0700b", commit = "#5b6573", evidence = "#9aa3ad",
                     risk = "#c62828", prompt_revision = "#1f4fd1", plan = "#1f4fd1", immutable_rule = "#1f4fd1",
                     other = "#9aa3ad")
gov_kind_labels <- c(request = "Solicitação", requirement = "Requisito", work_item = "Item de trabalho",
                     execution = "Execução", test = "Teste", acceptance = "Aceite", commit = "Commit",
                     evidence = "Evidência", risk = "Risco", prompt_revision = "Revisão de prompt",
                     plan = "Replanejamento", immutable_rule = "Regra imutável", other = "Outro")
gov_state_colors <- c(completed = "#2e7d32", running = "#1f4fd1", queued = "#c9d1da", paused = "#6b7480",
                      failed = "#c62828", interrupted = "#a0700b", unknown = "#9aa3ad")
gov_state_labels <- c(completed = "concluída", running = "rodando", queued = "na fila", paused = "pausada",
                      failed = "falhou", interrupted = "interrompida", unknown = "desconhecida")

gov_esc <- function(x) htmltools::htmlEscape(as.character(x), attribute = TRUE)
gov_br_int <- function(v) formatC(v, format = "d", big.mark = ".", decimal.mark = ",")
gov_fmt_time <- function(t) ifelse(is.na(t), "—", format(t, "%d/%m/%Y %H:%M", tz = "America/Sao_Paulo"))
gov_short <- function(x, n = 90L) ifelse(nchar(x) > n, paste0(substr(x, 1L, n - 1L), "…"), x)
gov_kind <- function(id) {
  p <- sub("_\\d+$", "", id)
  k <- c(request = "request", req = "requirement", work = "work_item", exec = "execution", test = "test",
         acc = "acceptance", risk = "risk", prv = "prompt_revision", plan = "plan", imm = "immutable_rule")[p]
  ifelse(is.na(k), "other", k)
}

# HTML table; `pick` names the column whose value drills down (clickable rows).
gov_table <- function(df, labels = names(df), pick = NULL, input = NULL, num = character(), empty = "Nada a mostrar.") {
  if (!nrow(df)) return(shiny::div(class = "tm-gov-empty", empty))
  head <- paste0("<tr>", paste0("<th", ifelse(names(df) %in% num, ' class="tm-num"', ""), ">", gov_esc(labels), "</th>",
                                collapse = ""), "</tr>")
  rows <- vapply(seq_len(nrow(df)), function(i) {
    cells <- paste0("<td", ifelse(names(df) %in% num, ' class="tm-num"', ""), ">",
                    gov_esc(unlist(df[i, ], use.names = FALSE)), "</td>", collapse = "")
    attrs <- if (!is.null(pick)) sprintf(' class="tm-pick" data-key="%s" data-input="%s"', gov_esc(df[[pick]][i]),
                                         gov_esc(input)) else ""
    paste0("<tr", attrs, ">", cells, "</tr>")
  }, character(1))
  shiny::div(class = "tm-gov-table-wrap", htmltools::HTML(paste0(
    '<table class="tm-card-table tm-gov-table"><thead>', head, "</thead><tbody>", paste(rows, collapse = ""),
    "</tbody></table>")))
}

gov_card <- function(title, ..., note = NULL, id = NULL) {
  shiny::div(class = "card tm-gov-card", id = id,
             shiny::div(class = "card-header tm-card-head", shiny::span(class = "tm-card-title", title),
                        if (!is.null(note)) shiny::span(class = "tm-gov-note", note)),
             shiny::div(class = "card-body", ...))
}

governance_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(class = "tm-page tm-gov",
    shiny::div(class = "tm-hero tm-gov-hero",
      shiny::div(class = "tm-eyebrow", "TaxMiner Governance"),
      shiny::h1("Governance — Executive Command Center"),
      shiny::p(class = "tm-lede", "Requisitos, entregas, execuções de agentes e trilha de auditoria, lidos dos",
               "registros em docs/project_management/. Indicador sem dado aparece como indisponível, nunca como zero."),
      shiny::uiOutput(ns("sync"))),
    shiny::div(class = "tm-gov-filters",
      # Empty range = whole history (NA start/end only raise a coercion notice).
      suppressWarnings(shiny::dateRangeInput(ns("period"), "Período", start = NA, end = NA, format = "dd/mm/yyyy",
                                             language = "pt-BR", separator = "a")),
      shiny::selectizeInput(ns("agent"), "Agente", choices = NULL, multiple = TRUE,
                            options = list(placeholder = "Todos")),
      shiny::selectizeInput(ns("module"), "Módulo", choices = NULL, multiple = TRUE,
                            options = list(placeholder = "Todos")),
      shiny::selectizeInput(ns("priority"), "Prioridade", choices = NULL, multiple = TRUE,
                            options = list(placeholder = "Todas")),
      shiny::selectizeInput(ns("status"), "Status do requisito", choices = NULL, multiple = TRUE,
                            options = list(placeholder = "Todos")),
      shiny::div(class = "tm-gov-search",
                 shiny::textInput(ns("query"), "Pesquisar ID", placeholder = "req_0021, work_0035…"),
                 shiny::actionButton(ns("go"), "Abrir", class = "btn-sm")),
      shiny::div(class = "tm-gov-actions",
                 shiny::selectInput(ns("interval"), "Atualização",
                                    choices = c("a cada 60 s" = 60, "a cada 150 s" = 150, "a cada 300 s" = 300,
                                                "manual" = 0), selected = 150),
                 shiny::actionButton(ns("refresh"), "Atualizar agora", class = "btn-sm"),
                 shiny::actionButton(ns("clear"), "Limpar filtros", class = "btn-sm btn-link"))),
    shiny::h2(class = "tm-gov-h2", "Executive Overview"),
    shiny::uiOutput(ns("kpis")),
    shiny::div(class = "tm-gov-grid",
      gov_card("Requirements Pipeline", shiny::uiOutput(ns("pipeline")), note = "requisitos por status; itens por etapa"),
      gov_card("Risks & Blockers", shiny::uiOutput(ns("risks")))),
    shiny::div(class = "tm-gov-grid",
      gov_card("Execution Timeline", shiny::uiOutput(ns("timeline"))),
      gov_card("Agent Performance", shiny::uiOutput(ns("agents")))),
    shiny::div(class = "tm-gov-grid",
      gov_card("Token Efficiency", shiny::uiOutput(ns("tokens"))),
      gov_card("Prompt Evolution", shiny::uiOutput(ns("prompts")))),
    gov_card("Traceability Graph", id = ns("trace"),
             shiny::div(class = "tm-gov-trace-bar", shiny::uiOutput(ns("crumbs"), inline = TRUE),
                        shiny::actionButton(ns("up"), "↑ Voltar", class = "btn-sm btn-link")),
             shiny::uiOutput(ns("graph")), shiny::uiOutput(ns("detail")),
             note = "clique num nó ou numa linha para detalhar; Voltar desfaz"),
    gov_card("Delivery Roadmap", shiny::uiOutput(ns("roadmap"))),
    gov_card("Audit Trail", shiny::uiOutput(ns("audit")),
             note = shiny::span("últimos 200 eventos · ",
                                shiny::downloadLink(ns("export_md"), "relatório (.md)"), " · ",
                                shiny::downloadLink(ns("export_csv"), "trilha (.csv)"))))
}

governance_server <- function(id, root, now = Sys.time) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    dir <- governance_pm_dir(root)
    state <- shiny::reactiveValues(regs = NULL, imm = NULL, sig = NULL, last_sync = as.POSIXct(NA), error = NULL,
                                   reads = 0L)
    # Re-reads only when the files changed (or when forced); a failure keeps the
    # last good data and is reported.
    load <- function(force = FALSE) {
      tryCatch({
        if (!file.exists(file.path(dir, governance_specs$requirements$file))) {
          stop("registros não encontrados em ", dir, call. = FALSE)
        }
        sig <- governance_signature(dir)
        if (force || !identical(sig, shiny::isolate(state$sig))) {
          regs <- governance_read(dir)
          state$imm <- tryCatch(governance_immutable_check(root), error = function(e) NULL)
          state$regs <- regs
          state$sig <- sig
          state$reads <- shiny::isolate(state$reads) + 1L
        }
        state$last_sync <- now()
        state$error <- NULL
      }, error = function(e) state$error <- conditionMessage(e))
    }
    load(TRUE)
    interval <- shiny::reactive({ v <- suppressWarnings(as.numeric(input$interval)); if (length(v) && !is.na(v)) v else 150 })
    shiny::observe({
      s <- interval()
      if (s > 0) shiny::invalidateLater(s * 1000)
      shiny::isolate(load())
    })
    shiny::observeEvent(input$refresh, load(TRUE), ignoreInit = TRUE)

    # Filter choices follow the data; selections are kept.
    shiny::observeEvent(state$regs, {
      ch <- governance_filter_choices(state$regs)
      for (n in c("agent", "module", "priority", "status")) {
        keep <- shiny::isolate(input[[n]])
        shiny::updateSelectizeInput(session, n, choices = union(ch[[n]], keep), selected = keep)
      }
    })
    shiny::observeEvent(input$clear, {
      for (n in c("agent", "module", "priority", "status")) shiny::updateSelectizeInput(session, n, selected = character())
      suppressWarnings(shiny::updateDateRangeInput(session, "period", start = NA, end = NA))
    })
    filters <- shiny::reactive(list(from = input$period[1], to = input$period[2], agent = input$agent,
                                    module = input$module, priority = input$priority, status = input$status))
    filtered <- shiny::reactive({ shiny::req(state$regs); governance_filter(state$regs, filters()) })

    output$sync <- shiny::renderUI({
      shiny::invalidateLater(30000)
      shiny::req(state$regs)
      fr <- governance_freshness(state$regs, state$last_sync, interval(), now())
      shiny::div(class = paste("tm-gov-sync", if (fr$stale || !is.null(state$error)) "tm-gov-stale"),
        shiny::span(`data-tip` = "Hora da última leitura bem-sucedida dos registros.",
                    "Última sincronização: ", gov_fmt_time(state$last_sync)),
        shiny::span(`data-tip` = "Horário da transição mais recente em state_transitions.csv: o último avanço real registrado.",
                    "Último progresso real: ", gov_fmt_time(fr$last_progress)),
        shiny::span(if (interval() > 0) sprintf("Atualização a cada %d s", as.integer(interval())) else "Atualização manual"),
        if (fr$stale) shiny::span(class = "tm-gov-flag", "Dados desatualizados"),
        if (!is.null(state$error)) shiny::span(class = "tm-gov-flag", paste("Falha na leitura; mantidos os últimos dados:", state$error)))
    })

    output$kpis <- shiny::renderUI({
      k <- governance_kpis(filtered())
      shiny::div(class = "tm-gov-kpis", lapply(seq_len(nrow(k)), function(i) {
        v <- governance_format_kpi(k$value[i], k$unit[i])
        if (k$unit[i] == "days" && !is.na(k$value[i]) && k$value[i] < 1) {
          v <- paste(formatC(24 * k$value[i], format = "f", digits = 1, decimal.mark = ","), "h")
        }
        shiny::div(class = paste("tm-kpi tm-gov-kpi", if (is.na(k$value[i])) "tm-gov-na"),
                   `data-tip` = paste0(k$label[i], "\n", k$definition[i], if (nzchar(k$note[i])) paste0("\n", k$note[i]) else ""),
                   shiny::div(class = "tm-kpi-value", v), shiny::div(class = "tm-kpi-label", k$label[i]),
                   if (nzchar(k$note[i])) shiny::div(class = "tm-kpi-note", k$note[i]))
      }))
    })

    output$pipeline <- shiny::renderUI({
      r <- filtered()
      p <- governance_pipeline(r)
      d <- governance_delivery_stages(r)
      shiny::tagList(
        shiny::div(class = "tm-gov-sub", "Requisitos por status (ciclo de vida)"),
        if (nrow(p)) bar_list(p$status, p$n, gov_br_int(p$n), colors = "#051c2c",
                              tips = sprintf("%s: %d requisito(s)", p$status, p$n))
        else shiny::div(class = "tm-gov-empty", "Nenhum requisito com os filtros atuais."),
        shiny::div(class = "tm-gov-sub", "Itens de trabalho por etapa (Implementado ≠ Testado ≠ Aceito ≠ Liberado)"),
        bar_list(d$stage, d$n, gov_br_int(d$n), colors = "#1f4fd1",
                 tips = sprintf("%s: %d de %d itens", d$stage, d$n, d$n[1])))
    })

    output$risks <- shiny::renderUI({
      r <- filtered()
      rk <- r$risks[r$risks$status == "open", c("risk_id", "description", "likelihood", "impact"), drop = FALSE]
      rk$description <- gov_short(rk$description, 110L)
      w <- r$work_items
      blocked <- w[w$implementation_status == "blocked" | w$test_status == "blocked" | w$release_status == "blocked",
                   c("work_item_id", "title"), drop = FALSE]
      blocked$title <- gov_short(blocked$title, 110L)
      imm <- state$imm
      shiny::tagList(
        shiny::div(class = "tm-gov-sub", sprintf("Riscos abertos (%d)", nrow(rk))),
        gov_table(utils::head(rk, 8L), c("Risco", "Descrição", "Probabilidade", "Impacto"), pick = "risk_id",
                  input = ns("pick"), empty = "Nenhum risco aberto."),
        shiny::div(class = "tm-gov-sub", sprintf("Itens bloqueados (%d)", nrow(blocked))),
        gov_table(blocked, c("Item", "Título"), pick = "work_item_id", input = ns("pick"), empty = "Nenhum item bloqueado."),
        shiny::div(class = "tm-gov-sub", "Camada imutável"),
        if (is.null(imm)) shiny::div(class = "tm-gov-empty", "indisponível")
        else if (!nrow(imm)) shiny::div(class = "tm-gov-ok", "Intacta: AGENTS.md, CLAUDE.md, Common P01 e seção 12 de Common P08 conferem com a linha de base.")
        else shiny::div(class = "tm-gov-flag", paste("Alterada sem decisão:", paste(imm$id, collapse = ", "))))
    })

    output$timeline <- shiny::renderUI({
      x <- filtered()$executions
      if (!nrow(x)) {
        return(shiny::div(class = "tm-gov-empty",
          "Nenhuma execução registrada no período. A captura automática do Claude Code não está instalada",
          "(depende de confirmação própria, regra P9); execuções entram por",
          shiny::code("scripts/governance_registry.R add-execution"), "."))
      }
      t0 <- governance_time(x$started_at)
      t1 <- governance_time(x$ended_at)
      open <- is.na(t1)
      t1[open] <- as.POSIXct(now())
      lo <- min(t0, na.rm = TRUE); hi <- max(t1, na.rm = TRUE)
      span <- max(as.numeric(difftime(hi, lo, units = "secs")), 60)
      agents <- sort(unique(x$agent))
      W <- 760; L <- 110; H <- 26 * length(agents) + 34
      px <- function(t) L + (W - L - 10) * as.numeric(difftime(t, lo, units = "secs")) / span
      lanes <- vapply(seq_along(agents), function(i) sprintf(
        '<text x="4" y="%.1f" class="tm-gov-axis">%s</text><line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="tm-gov-lane"/>',
        26 * i + 4, gov_esc(agents[i]), L, W - 10, 26 * i + 9, 26 * i + 9), character(1))
      bars <- vapply(seq_len(nrow(x)), function(i) {
        y <- 26 * match(x$agent[i], agents) - 6
        a <- px(t0[i]); b <- max(px(t1[i]), a + 4)
        tip <- sprintf("%s · %s\n%s → %s%s\nTokens: %s", x$execution_id[i], gov_state_labels[[x$state[i]]],
                       gov_fmt_time(t0[i]), if (open[i]) "em aberto" else gov_fmt_time(t1[i]),
                       if (nzchar(x$work_item_id[i])) paste0("\nItem: ", x$work_item_id[i]) else "",
                       if (nzchar(x$input_tokens[i])) paste(x$input_tokens[i], "entrada /", x$output_tokens[i], "saída") else "indisponível")
        sprintf('<g class="tm-pick tm-gov-bar" data-key="%s" data-input="%s" data-tip="%s"><rect x="%.1f" y="%.1f" width="%.1f" height="14" rx="3" fill="%s"/></g>',
                gov_esc(x$execution_id[i]), gov_esc(ns("pick")), gov_esc(tip), a, y, b - a, gov_state_colors[[x$state[i]]])
      }, character(1))
      axis <- sprintf('<text x="%d" y="%d" class="tm-gov-axis">%s</text><text x="%d" y="%d" class="tm-gov-axis" text-anchor="end">%s</text>',
                      L, H - 4, gov_fmt_time(lo), W - 10, H - 4, gov_fmt_time(hi))
      states <- intersect(names(gov_state_colors), unique(x$state))
      shiny::tagList(
        htmltools::HTML(sprintf('<svg class="tm-gov-svg" viewBox="0 0 %d %d" role="img" aria-label="Linha do tempo das execuções">%s%s%s</svg>',
                                W, H, paste(lanes, collapse = ""), paste(bars, collapse = ""), axis)),
        shiny::div(class = "tm-legend tm-gov-legend", lapply(states, function(s) shiny::div(class = "tm-legend-item",
          shiny::span(class = "tm-swatch", style = sprintf("background:%s", gov_state_colors[[s]])),
          shiny::span(class = "tm-legend-name", gov_state_labels[[s]]),
          shiny::span(class = "tm-legend-value", sum(x$state == s))))))
    })

    output$agents <- shiny::renderUI({
      a <- governance_agent_performance(filtered(), now())
      if (!nrow(a)) return(shiny::div(class = "tm-gov-empty", "Sem execuções no período: desempenho por agente indisponível."))
      pct <- function(v) ifelse(is.na(v), "indisponível", paste0(formatC(100 * v, format = "f", digits = 1, decimal.mark = ","), "%"))
      tab <- data.frame(agent = a$agent, n = gov_br_int(a$executions), ok = gov_br_int(a$completed), fail = gov_br_int(a$failed),
                        open = gov_br_int(a$open), rate = pct(a$failure_rate),
                        dur = ifelse(is.na(a$mean_minutes), "indisponível", paste(formatC(a$mean_minutes, format = "f", digits = 1, decimal.mark = ","), "min")),
                        tok = ifelse(is.na(a$tokens), "indisponível", formatC(a$tokens, format = "d", big.mark = ".", decimal.mark = ",")),
                        stringsAsFactors = FALSE)
      gov_table(tab, c("Agente", "Execuções", "Concluídas", "Falhas", "Abertas", "Taxa de falha", "Duração média", "Tokens"),
                num = c("n", "ok", "fail", "open", "rate", "dur", "tok"))
    })

    output$tokens <- shiny::renderUI({
      r <- filtered()
      k <- governance_kpis(r)
      x <- r$executions
      has <- nzchar(x$input_tokens) | nzchar(x$output_tokens)
      num <- function(v) sum(suppressWarnings(as.numeric(v)), na.rm = TRUE)
      kv <- function(id) governance_format_kpi(k$value[k$id == id], k$unit[k$id == id])
      accepted <- sum(r$work_items$acceptance_status == "approved")
      per <- if (any(has) && accepted) formatC((num(x$input_tokens[has]) + num(x$output_tokens[has])) / accepted, format = "d", big.mark = ".", decimal.mark = ",") else "indisponível"
      shiny::tagList(
        shiny::div(class = "tm-gov-mini",
          shiny::div(shiny::span(class = "tm-big", kv("token_consumption")), shiny::span("tokens (entrada + saída)")),
          shiny::div(shiny::span(class = "tm-big", if (any(has)) formatC(num(x$cached_tokens[has]), format = "d", big.mark = ".", decimal.mark = ",") else "indisponível"),
                     shiny::span("tokens em cache")),
          shiny::div(shiny::span(class = "tm-big", per), shiny::span("tokens por item aceito")),
          shiny::div(shiny::span(class = "tm-big", kv("cost_per_accepted")), shiny::span("custo por item aceito"))),
        shiny::p(class = "tm-gov-note", sprintf(
          "%d de %d execuções informam tokens. Contagens vêm só do que o agente informa; nada é estimado. A leitura dos tokens das transcrições do Claude Code está desligada até confirmação própria (P9).",
          sum(has), nrow(x))))
    })

    output$prompts <- shiny::renderUI({
      p <- state$regs$prompt_revisions
      p <- p[order(p$revision_id, decreasing = TRUE), , drop = FALSE]
      tab <- data.frame(id = p$revision_id, v = paste(p$previous_version, "→", p$version), at = substr(p$revised_at, 1L, 10L),
                        cls = p$change_class, ap = p$approval, imp = gov_short(p$improvements, 70L), stringsAsFactors = FALSE)
      shiny::tagList(
        shiny::div(class = "tm-gov-sub", sprintf("Prompt mestre: %d revisões (%d aprovadas, %d propostas, %d rejeitadas)",
                                                  nrow(p), sum(p$approval == "approved"), sum(p$approval == "proposed"),
                                                  sum(p$approval == "rejected"))),
        gov_table(tab, c("Revisão", "Versão", "Data", "Classe", "Decisão", "Melhorias"), pick = "id", input = ns("pick"),
                  empty = "Nenhuma revisão registrada."))
    })

    # Drill-down stack: the last element is the focus; Voltar pops it.
    stack <- shiny::reactiveVal("req_0021")
    known_id <- function(i) {
      r <- shiny::isolate(state$regs)
      any(vapply(names(governance_specs), function(n) i %in% r[[n]][[governance_specs[[n]]$id]], logical(1)))
    }
    push <- function(i) {
      i <- trimws(i)
      if (!nzchar(i)) return()
      if (!known_id(i)) {
        shiny::showNotification(sprintf("ID não encontrado: %s", i), type = "warning")
        return()
      }
      s <- stack()
      if (!identical(utils::tail(s, 1L), i)) stack(utils::tail(c(s, i), 20L))
    }
    shiny::observeEvent(input$pick, push(input$pick))
    shiny::observeEvent(input$go, push(input$query))
    shiny::observeEvent(input$up, { s <- stack(); if (length(s) > 1L) stack(utils::head(s, -1L)) })
    focus <- shiny::reactive(utils::tail(stack(), 1L))

    output$crumbs <- shiny::renderUI({
      s <- stack()
      shiny::span(class = "tm-gov-crumbs", paste(s, collapse = " › "))
    })

    output$graph <- shiny::renderUI({
      shiny::req(state$regs)
      g <- governance_graph(state$regs, focus())
      n <- g$nodes
      cols <- sort(unique(n$column))
      W <- 980; colw <- W / 5
      n$x <- 10 + (n$column - 1) * colw
      n$y <- stats::ave(seq_len(nrow(n)), n$column, FUN = seq_along) * 30 + 6
      H <- max(n$y) + 20
      pos <- function(i, what) n[[what]][match(i, n$id)]
      edges <- if (nrow(g$edges)) vapply(seq_len(nrow(g$edges)), function(k) {
        a <- g$edges$from[k]; b <- g$edges$to[k]
        x1 <- pos(a, "x") + colw - 30; y1 <- pos(a, "y"); x2 <- pos(b, "x"); y2 <- pos(b, "y")
        if (x2 < x1) { tmp <- x1; x1 <- pos(b, "x") + colw - 30; x2 <- pos(a, "x"); y1 <- pos(b, "y"); y2 <- pos(a, "y") }
        sprintf('<path class="tm-gov-edge" d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f"/>', x1, y1, (x1 + x2) / 2, y1, (x1 + x2) / 2, y2, x2, y2)
      }, character(1)) else character()
      nodes <- vapply(seq_len(nrow(n)), function(k) {
        clickable <- !n$kind[k] %in% c("commit", "evidence", "other")
        text <- gov_short(if (n$kind[k] %in% c("commit", "evidence")) n$label[k] else n$id[k], 26L)
        tip <- paste0(gov_kind_labels[[n$kind[k]]], ": ", n$id[k], if (nzchar(n$label[k]) && !n$kind[k] %in% c("commit", "evidence")) paste0("\n", gov_short(n$label[k], 160L)) else "")
        sprintf('<g class="tm-gov-node%s%s"%s data-tip="%s"><rect x="%.1f" y="%.1f" width="%.1f" height="22" rx="3" style="stroke:%s"/><circle cx="%.1f" cy="%.1f" r="4" fill="%s"/><text x="%.1f" y="%.1f">%s</text></g>',
                if (n$focus[k]) " tm-gov-focus" else "", if (clickable) " tm-pick" else "",
                if (clickable) sprintf(' data-key="%s" data-input="%s"', gov_esc(n$id[k]), gov_esc(ns("pick"))) else "",
                gov_esc(tip), n$x[k], n$y[k] - 11, colw - 30, gov_kind_colors[[n$kind[k]]], n$x[k] + 10, n$y[k],
                gov_kind_colors[[n$kind[k]]], n$x[k] + 20, n$y[k] + 4, gov_esc(text))
      }, character(1))
      heads <- c("Solicitações", "Requisitos", "Itens de trabalho", "Execuções · testes · aceites", "Commits · evidências")
      hd <- paste(sprintf('<text class="tm-gov-axis" x="%.1f" y="10">%s</text>', 10 + (0:4) * colw, heads), collapse = "")
      htmltools::HTML(sprintf('<div class="tm-gov-graph"><svg class="tm-gov-svg" viewBox="0 -8 %d %.0f" role="img" aria-label="Grafo de rastreabilidade de %s">%s%s%s</svg></div>',
                              W, H + 8, gov_esc(focus()), hd, paste(edges, collapse = ""), paste(nodes, collapse = "")))
    })

    output$detail <- shiny::renderUI({
      shiny::req(state$regs)
      i <- focus()
      r <- state$regs
      spec <- Filter(function(s) s$prefix == sub("_\\d+$", "", i), governance_specs)
      if (!length(spec)) return(NULL)
      tab <- r[[names(spec)[1]]]
      row <- tab[tab[[spec[[1]]$id]] == i, , drop = FALSE]
      if (!nrow(row)) return(NULL)
      fields <- data.frame(campo = names(row), valor = unlist(row[1, ], use.names = FALSE), stringsAsFactors = FALSE)
      fields <- fields[nzchar(fields$valor), , drop = FALSE]
      hist <- r$transitions[r$transitions$entity_id == i, c("transition_id", "changed_at", "field", "from_status", "to_status", "actor", "evidence"), drop = FALSE]
      shiny::div(class = "tm-gov-detail",
        shiny::div(shiny::div(class = "tm-gov-sub", sprintf("%s — %s", gov_kind_labels[[gov_kind(i)]], i)),
                   gov_table(fields, c("Campo", "Valor"))),
        shiny::div(shiny::div(class = "tm-gov-sub", sprintf("Histórico (%d transições)", nrow(hist))),
                   gov_table(hist, c("Transição", "Quando", "Campo", "De", "Para", "Quem", "Evidência"),
                             empty = "Sem transições registradas.")))
    })

    output$roadmap <- shiny::renderUI({
      r <- filtered()
      w <- r$work_items
      w <- w[order(w$acceptance_status == "approved", -as.integer(sub("work_", "", w$work_item_id))), , drop = FALSE]
      tab <- data.frame(id = w$work_item_id, req = w$requirement_id, title = gov_short(w$title, 80L),
                        impl = w$implementation_status, test = w$test_status, acc = w$acceptance_status,
                        rel = w$release_status, stringsAsFactors = FALSE)
      pl <- state$regs$planning_revisions
      pl <- pl[order(pl$plan_id, decreasing = TRUE), , drop = FALSE]
      shiny::tagList(
        if (nrow(pl)) shiny::div(class = "tm-gov-plan",
          shiny::span(class = "tm-gov-sub", sprintf("Plano vigente (%s, %s): ", pl$plan_id[1], pl$approval[1])),
          pl$summary[1]),
        gov_table(utils::head(tab, 40L), c("Item", "Requisito", "Título", "Implementação", "Teste", "Aceite", "Release"),
                  pick = "id", input = ns("pick"), empty = "Nenhum item com os filtros atuais."),
        if (nrow(tab) > 40L) shiny::div(class = "tm-gov-note", sprintf("Mostrando 40 de %d itens (pendentes primeiro).", nrow(tab))))
    })

    audit <- shiny::reactive(governance_audit(filtered(), 200L))
    output$audit <- shiny::renderUI({
      a <- audit()
      gov_table(a[, c("transition_id", "changed_at", "entity_id", "field", "from_status", "to_status", "actor", "evidence"), drop = FALSE],
                c("Transição", "Quando", "Registro", "Campo", "De", "Para", "Quem", "Evidência"),
                pick = "entity_id", input = ns("pick"), empty = "Nenhum evento no período.")
    })

    output$export_md <- shiny::downloadHandler(
      filename = function() sprintf("governanca_%s.md", format(now(), "%Y%m%d_%H%M")),
      content = function(file) writeLines(enc2utf8(governance_report_md(filtered(), filters())), file, useBytes = TRUE))
    output$export_csv <- shiny::downloadHandler(
      filename = function() sprintf("governanca_trilha_%s.csv", format(now(), "%Y%m%d_%H%M")),
      content = function(file) utils::write.csv(audit(), file, row.names = FALSE, fileEncoding = "UTF-8"))

    invisible(list(state = state, filtered = filtered, focus = focus, interval = interval))
  })
}
