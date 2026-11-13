# TaxMiner Governance phase 05 (req_0021): KPIs, filters, dashboard data and the
# Executive Command Center module (refresh every 150 s, incremental reads,
# failure handling, drill-down). Synthetic registers in temporary folders.
# Run from the project root:
#   Rscript -e "testthat::test_file('tests/testthat/test_governance_metrics.R')"

for (f in c("governance_registry.R", "governance_prompts.R", "governance_agents.R", "governance_metrics.R",
            "governance_views.R")) {
  source(testthat::test_path("..", "..", "src", "common", f))
}
source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "prototype", "charts.R"))
source(testthat::test_path("..", "..", "prototype", "governance_module.R"))

suppressWarnings(requireNamespace("shiny", quietly = TRUE))  # build-version notice only

csv <- function(dir, file, lines) writeLines(lines, file.path(dir, file))

# Two modules, three requirements, four work items, tests, an acceptance, two
# agents with executions (one with tokens and cost), a rework transition.
metrics_root <- function() {
  root <- tempfile("governance_metrics_")
  pm <- file.path(root, "docs", "project_management")
  dir.create(pm, recursive = TRUE)
  csv(pm, "requirements_register.csv", c(
    "requirement_id,module,description,source,priority,acceptance_criteria,status,owner,updated_at",
    "req_0001,common,Registry,synthetic,high,ok,in_progress,developer,2026-01-01T10:00:00-03:00",
    "req_0002,funds,Search,synthetic,medium,ok,planned,developer,2026-01-01T10:00:00-03:00",
    "req_0003,funds,Export,synthetic,high,ok,blocked,developer,2026-01-01T10:00:00-03:00"))
  w <- function(id, mod, req, pr, impl, test, acc) {
    paste(sprintf('"%s"', c(id, mod, req, "Title", "feature", pr, "claude_code", "", impl, test, acc, "not_released",
                            "not_applicable", "", "2026-01-02T10:00:00-03:00")), collapse = ",")
  }
  csv(pm, "work_items.csv", c(
    paste(sprintf('"%s"', governance_specs$work_items$columns), collapse = ","),
    w("work_0001", "common", "req_0001", "high", "implemented", "passed", "approved"),
    w("work_0002", "common", "req_0001", "high", "implemented", "passed", "pending"),
    w("work_0003", "funds", "req_0002", "medium", "implemented", "not_run", "pending"),
    w("work_0004", "funds", "req_0003", "high", "blocked", "not_run", "pending")))
  csv(pm, "test_register.csv", c(
    "test_id,work_item_id,level,environment,execution_timestamp,result,evidence_path,code_commit",
    "test_0001,work_0001,unit,r,2026-01-03T10:00:00-03:00,passed,tests/a.R,abc1234",
    "test_0002,work_0002,unit,r,2026-01-03T10:00:00-03:00,passed,tests/b.R,abc1234+uncommitted"))
  csv(pm, "acceptance_register.csv", c(
    "acceptance_id,work_item_id,criteria,reviewer,decision,decision_timestamp,evidence_path,notes",
    "acc_0001,work_0001,ok,developer,approved,2026-01-05T10:00:00-03:00,docs/x.md,"))
  csv(pm, "request_register.csv", c(
    "request_id,received_at,channel,agent,summary,classification,requirement_ids,status,updated_at",
    "request_0001,2026-01-01T09:00:00-03:00,claude_code,claude_code,Pedido A,feature,req_0001,linked,2026-01-01T09:00:00-03:00",
    "request_0002,2026-02-01T09:00:00-03:00,manual,codex,Pedido B,feature,req_0002,linked,2026-02-01T09:00:00-03:00"))
  csv(pm, "execution_register.csv", c(
    paste(governance_specs$executions$columns, collapse = ","),
    "exec_0001,work_0001,request_0001,claude_code,m1,s1,2026-01-02T10:00:00-03:00,2026-01-02T11:00:00-03:00,completed,1000,200,5000,0.50,0,,",
    "exec_0002,work_0002,,claude_code,m1,s2,2026-01-03T10:00:00-03:00,2026-01-03T10:30:00-03:00,failed,,,,,0,,",
    "exec_0003,work_0003,request_0002,codex,,,2026-02-02T10:00:00-03:00,,running,,,,,0,,"))
  csv(pm, "state_transitions.csv", c(
    "transition_id,entity_id,field,from_status,to_status,changed_at,actor,evidence",
    "trn_0001,work_0001,implementation_status,not_started,implemented,2026-01-01T10:00:00-03:00,claude_code,",
    "trn_0002,work_0001,acceptance_status,pending,approved,2026-01-05T10:00:00-03:00,developer,acc_0001",
    "trn_0003,work_0002,test_status,passed,failed,2026-01-03T12:00:00-03:00,claude_code,",
    "trn_0004,work_0002,test_status,failed,passed,2026-01-04T12:00:00-03:00,claude_code,",
    "trn_0005,exec_0003,state,,running,2026-02-02T10:00:00-03:00,codex,"))
  csv(pm, "risk_register.csv", c("risk_id,description,likelihood,impact,mitigation,owner,status",
                                 "risk_0001,Synthetic risk,possible,high,none,developer,open"))
  csv(pm, "prompt_revisions.csv", c(paste(governance_specs$prompt_revisions$columns, collapse = ","),
    "prv_0001,prompts/p.txt,1.1,1.0,2026-01-02T10:00:00-03:00,r,functional,x,req_0001,abc,ok,proposed,"))
  csv(pm, "decision_log.md", "# Decisions")
  root
}

kpi <- function(k, id) k$value[k$id == id]

test_that("the synthetic registers are valid", {
  expect_equal(nrow(governance_check(governance_read(file.path(metrics_root(), "docs", "project_management")))), 0L)
})

test_that("KPIs follow their formal definitions and unavailable ones are NA, not zero", {
  regs <- governance_read(file.path(metrics_root(), "docs", "project_management"))
  k <- governance_kpis(regs)
  expect_setequal(k$id, governance_kpi_definitions$id)
  expect_true(all(nzchar(k$definition)))
  expect_equal(c(kpi(k, "total_requests"), kpi(k, "total_requirements"), kpi(k, "planned"), kpi(k, "in_progress"),
                 kpi(k, "implemented"), kpi(k, "tested"), kpi(k, "accepted"), kpi(k, "blocked")),
               c(2, 3, 1, 1, 3, 2, 1, 2))
  expect_true(is.na(kpi(k, "overdue")))
  expect_equal(kpi(k, "rework_rate"), 1 / 2)                 # work_0002 went passed -> failed
  expect_equal(kpi(k, "test_coverage"), 2 / 3)               # work_0003 implemented without a passed test
  expect_equal(kpi(k, "token_consumption"), 1200)            # only exec_0001 reports tokens
  expect_equal(kpi(k, "cost_per_accepted"), 0.5)
  expect_equal(kpi(k, "average_cycle_time"), 4)              # 2026-01-01 -> 2026-01-05
  expect_equal(kpi(k, "agent_failure_rate"), 1 / 2)          # 1 failed of 2 ended
  expect_equal(kpi(k, "pending_human_decisions"), 2)         # work_0002 + prv_0001
  expect_equal(governance_format_kpi(NA, "count"), "indisponível")
  expect_equal(governance_format_kpi(1234567, "count"), "1.234.567")
  expect_equal(governance_format_kpi(0.6667, "pct"), "66,7%")
})

test_that("without executions, token and agent KPIs are unavailable", {
  regs <- governance_read(file.path(metrics_root(), "docs", "project_management"))
  regs$executions <- regs$executions[0, ]
  k <- governance_kpis(regs)
  expect_true(all(is.na(k$value[k$id %in% c("token_consumption", "cost_per_accepted", "agent_failure_rate")])))
  expect_match(k$note[k$id == "token_consumption"], "indisponível")
  expect_equal(nrow(governance_agent_performance(regs)), 0L)
})

test_that("filters select requirements and every related indicator follows them", {
  regs <- governance_read(file.path(metrics_root(), "docs", "project_management"))
  f <- governance_filter(regs, list(module = "funds"))
  expect_setequal(f$requirements$requirement_id, c("req_0002", "req_0003"))
  expect_setequal(f$work_items$work_item_id, c("work_0003", "work_0004"))
  expect_equal(f$requests$request_id, "request_0002")
  expect_equal(f$executions$execution_id, "exec_0003")
  expect_equal(f$transitions$transition_id, "trn_0005")
  expect_equal(nrow(f$tests), 0L)
  k <- governance_kpis(f)
  expect_equal(c(kpi(k, "total_requirements"), kpi(k, "implemented"), kpi(k, "blocked")), c(2, 1, 2))
  expect_true(is.na(kpi(k, "token_consumption")))
  a <- governance_filter(regs, list(agent = "codex"))
  expect_equal(a$executions$execution_id, "exec_0003")
  expect_equal(a$requests$request_id, "request_0002")
  p <- governance_filter(regs, list(from = as.Date("2026-02-01"), to = as.Date("2026-02-28")))
  expect_equal(p$requests$request_id, "request_0002")
  expect_equal(p$executions$execution_id, "exec_0003")
  expect_equal(nrow(p$tests), 0L)
  s <- governance_filter(regs, list(status = "blocked"))
  expect_equal(s$work_items$work_item_id, "work_0004")
  expect_identical(governance_filter(regs, list()), regs)
})

test_that("pipeline, delivery stages, agent performance, audit and graph", {
  regs <- governance_read(file.path(metrics_root(), "docs", "project_management"))
  expect_equal(governance_pipeline(regs)$status, c("planned", "in_progress", "blocked"))
  expect_equal(governance_delivery_stages(regs)$n, c(4, 3, 2, 1, 0))
  a <- governance_agent_performance(regs)
  expect_equal(a$agent, c("claude_code", "codex"))
  expect_equal(a$mean_minutes, c(45, NA))
  expect_equal(a$tokens, c(1200, NA))
  expect_equal(governance_audit(regs)$transition_id[1], "trn_0005")
  g <- governance_graph(regs, "work_0001")
  expect_true(all(c("req_0001", "test_0001", "acc_0001", "exec_0001", "commit:abc1234", "file:tests/a.R",
                    "request_0001") %in% g$nodes$id))
  expect_equal(g$nodes$id[g$nodes$focus], "work_0001")
  expect_true(all(c(g$edges$from, g$edges$to) %in% g$nodes$id))
  expect_false("commit:abc1234+uncommitted" %in% governance_graph(regs, "test_0002")$nodes$id)
})

test_that("freshness flags data older than two refresh intervals", {
  regs <- governance_read(file.path(metrics_root(), "docs", "project_management"))
  now <- as.POSIXct("2026-02-03 12:00:00", tz = "UTC")
  fr <- governance_freshness(regs, now - 100, 150, now)
  expect_false(fr$stale)
  expect_equal(format(fr$last_progress, "%Y-%m-%d %H:%M", tz = "UTC"), "2026-02-02 13:00")
  expect_true(governance_freshness(regs, now - 301, 150, now)$stale)
  expect_true(governance_freshness(regs, as.POSIXct(NA), 150, now)$stale)
  expect_false(governance_freshness(regs, now - 10000, 0, now)$stale)   # manual mode
})

test_that("the report export lists every KPI and the filters in force", {
  regs <- governance_read(file.path(metrics_root(), "docs", "project_management"))
  md <- governance_report_md(governance_filter(regs, list(module = "funds")), list(module = "funds", agent = NULL),
                             at = "2026-02-03T12:00:00-03:00")
  expect_true(any(grepl("Filtros: module = funds\\.", md)))
  expect_equal(sum(grepl("^\\| (Solicitações|Requisitos|Atrasados|Consumo de tokens) \\|", md)), 4L)
  expect_true(any(grepl("^\\| Atrasados \\| indisponível \\|", md)))
})

test_that("the dashboard refreshes every 150 s by default, re-reads only on change and keeps data on failure", {
  root <- metrics_root()
  pm <- file.path(root, "docs", "project_management")
  clock <- as.POSIXct("2026-02-03 12:00:00", tz = "UTC")
  shiny::testServer(governance_server, args = list(root = root, now = function() clock), {
    session$setInputs(interval = "150", agent = NULL, module = NULL, priority = NULL, status = NULL,
                      period = c(NA, NA))
    expect_equal(interval(), 150)
    expect_equal(state$reads, 1L)
    expect_equal(nrow(filtered()$requirements), 3L)
    # No change in the files: the poll does not re-read.
    session$elapse(150 * 1000)
    expect_equal(state$reads, 1L)
    # A new request appears: the next poll re-reads it.
    governance_add_request(pm, "Pedido C", "feature", "manual", "developer", "req_0001", "linked",
                           "2026-02-03T11:00:00-03:00")
    session$elapse(150 * 1000)
    expect_equal(state$reads, 2L)
    expect_equal(nrow(state$regs$requests), 3L)
    # Filters are kept across refreshes.
    session$setInputs(module = "funds")
    expect_equal(nrow(filtered()$requirements), 2L)
    session$setInputs(refresh = 1)
    expect_equal(state$reads, 3L)
    expect_equal(nrow(filtered()$requirements), 2L)
    # A failed read keeps the last data and reports the error.
    file.rename(pm, paste0(pm, "_moved"))
    session$setInputs(refresh = 2)
    expect_false(is.null(state$error))
    expect_equal(nrow(state$regs$requests), 3L)
    file.rename(paste0(pm, "_moved"), pm)
    session$setInputs(refresh = 3)
    expect_null(state$error)
    # Drill-down and drill-up.
    expect_equal(focus(), "req_0021")
    session$setInputs(pick = "work_0001")
    expect_equal(focus(), "work_0001")
    session$setInputs(query = "exec_0001", go = 1)
    expect_equal(focus(), "exec_0001")
    session$setInputs(query = "work_9999", go = 2)
    expect_equal(focus(), "exec_0001")
    session$setInputs(up = 1)
    expect_equal(focus(), "work_0001")
    expect_match(as.character(output$kpis$html), "indisponível")
  })
})
