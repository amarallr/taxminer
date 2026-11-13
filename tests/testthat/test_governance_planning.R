# TaxMiner Governance phase 03 (req_0021, work_0037): deduplication, reconciliation
# of requirement statuses (proposals only; human-approved application), planning,
# prioritization, estimates, context packs and replanning. Synthetic registers in
# temporary folders. Run from the project root:
#   Rscript -e "testthat::test_file('tests/testthat/test_governance_planning.R')"

for (f in c("governance_registry.R", "governance_prompts.R", "governance_agents.R", "governance_metrics.R",
            "governance_planning.R")) {
  source(testthat::test_path("..", "..", "src", "common", f))
}

csv <- function(dir, file, lines) writeLines(lines, file.path(dir, file))

# Five requirements: req_0001 with every item accepted (still "proposed"),
# req_0002 implemented and tested awaiting acceptance, req_0003 recorded as
# "accepted" with an open item (ambiguous), req_0004 not started and depended on
# by req_0002, req_0005 without items. Three accepted items with measured cycles
# of 2, 4 and 6 days; one imported item accepted without earlier history.
planning_root <- function() {
  root <- tempfile("governance_planning_")
  pm <- file.path(root, "docs", "project_management")
  dir.create(pm, recursive = TRUE)
  csv(pm, "requirements_register.csv", c(
    "requirement_id,module,description,source,priority,acceptance_criteria,status,owner,updated_at",
    "req_0001,common,Reproducible local environment and protected boundaries,s,high,ok,proposed,developer,2026-01-01T10:00:00-03:00",
    "req_0002,funds,Search investment fund reports by name and CNPJ,s,high,ok,proposed,developer,2026-01-01T10:00:00-03:00",
    "req_0003,common,Source specific architecture,s,medium,ok,accepted,developer,2026-01-01T10:00:00-03:00",
    "req_0004,funds,Consolidate fund reports into Parquet,s,medium,ok,proposed,developer,2026-01-01T10:00:00-03:00",
    "req_0005,common,Execution policy registry,s,low,ok,proposed,developer,2026-01-01T10:00:00-03:00"))
  w <- function(id, mod, req, impl, test, acc, deps = "", ev = "", owner = "claude_code") {
    paste(sprintf('"%s"', c(id, mod, req, paste("Item", id), "feature", "high", owner, deps, impl, test, acc,
                            "not_released", "not_applicable", ev, "2026-01-02T10:00:00-03:00")), collapse = ",")
  }
  csv(pm, "work_items.csv", c(
    paste(sprintf('"%s"', governance_specs$work_items$columns), collapse = ","),
    w("work_0001", "common", "req_0001", "implemented", "passed", "approved", ev = "src/a.R;.restricted/x.csv;../out.R"),
    w("work_0002", "common", "req_0001", "implemented", "passed", "approved"),
    w("work_0003", "funds", "req_0002", "implemented", "passed", "pending", deps = "work_0006"),
    w("work_0004", "common", "req_0003", "implemented", "passed", "approved"),
    w("work_0005", "common", "req_0003", "in_progress", "not_run", "pending", owner = "codex"),
    w("work_0006", "funds", "req_0004", "not_started", "not_run", "pending")))
  csv(pm, "test_register.csv", c(
    "test_id,work_item_id,level,environment,execution_timestamp,result,evidence_path,code_commit",
    "test_0001,work_0003,unit,r,2026-01-03T10:00:00-03:00,passed,tests/a.R,abc1234"))
  csv(pm, "acceptance_register.csv", c(
    "acceptance_id,work_item_id,criteria,reviewer,decision,decision_timestamp,evidence_path,notes",
    "acc_0001,work_0001,ok,developer,approved,2026-01-03T10:00:00-03:00,docs/x.md,",
    "acc_0002,work_0002,ok,developer,approved,2026-01-05T10:00:00-03:00,docs/x.md,",
    "acc_0003,work_0004,ok,developer,approved,2026-01-07T10:00:00-03:00,docs/x.md,"))
  csv(pm, "request_register.csv", c(
    "request_id,received_at,channel,agent,summary,classification,requirement_ids,status,updated_at",
    "request_0001,2026-01-01T09:00:00-03:00,manual,developer,Aprovar a Fase 04 e seguir,operational_command,,answered,2026-01-01T09:00:00-03:00",
    "request_0002,2026-03-01T09:00:00-03:00,manual,developer,Aprovar a Fase 04 e seguir agora,operational_command,,answered,2026-03-01T09:00:00-03:00",
    "request_0003,2026-03-02T09:00:00-03:00,manual,developer,Gerar instalador,feature,,captured,2026-03-02T09:00:00-03:00"))
  csv(pm, "state_transitions.csv", c(
    "transition_id,entity_id,field,from_status,to_status,changed_at,actor,evidence",
    "trn_0001,work_0001,implementation_status,not_started,implemented,2026-01-01T10:00:00-03:00,claude_code,",
    "trn_0002,work_0001,acceptance_status,pending,approved,2026-01-03T10:00:00-03:00,developer,",
    "trn_0003,work_0002,implementation_status,not_started,implemented,2026-01-01T10:00:00-03:00,claude_code,",
    "trn_0004,work_0002,acceptance_status,pending,approved,2026-01-05T10:00:00-03:00,developer,",
    "trn_0005,work_0004,implementation_status,not_started,implemented,2026-01-01T10:00:00-03:00,claude_code,",
    "trn_0006,work_0004,acceptance_status,pending,approved,2026-01-07T10:00:00-03:00,developer,"))
  csv(pm, "risk_register.csv", c("risk_id,description,likelihood,impact,mitigation,owner,status",
                                 "risk_0001,Synthetic,possible,high,none,developer,open"))
  csv(pm, "planning_revisions.csv", c(paste(governance_specs$planning_revisions$columns, collapse = ","),
    "plan_0001,2026-02-01T10:00:00-03:00,p,s,r,approved,e"))
  csv(pm, "decision_log.md", "# Decisions")
  csv(pm, "handoff.md", c("# Handoff", "", "req_0002 depende de req_0004.", "", "Outro parágrafo."))
  dir.create(file.path(root, "src"))
  writeLines(strrep("x", 500), file.path(root, "src", "a.R"))
  root
}
pm_of <- function(root) file.path(root, "docs", "project_management")

test_that("the synthetic registers are valid", {
  expect_equal(nrow(governance_check(governance_read(pm_of(planning_root())))), 0L)
})

test_that("deduplication suggests and never merges; requests near-duplicates are paired", {
  root <- planning_root(); regs <- governance_read(pm_of(root))
  before <- unname(tools::md5sum(list.files(pm_of(root), full.names = TRUE)))
  d <- governance_dedup(regs, "Search fund reports by CNPJ and name", module = "funds")
  expect_equal(d$id[1], "req_0002")
  expect_match(d$suggestion[1], "provável duplicata")
  expect_true(all(d$similarity >= 0.3))
  expect_equal(nrow(governance_dedup(regs, "Completely unrelated wording here")), 0L)
  expect_match(governance_dedup(regs, "Search fund reports by CNPJ and name", module = "common")$suggestion[1],
               "outro módulo")
  p <- governance_request_duplicates(regs)
  expect_equal(nrow(p), 1L)
  expect_equal(c(p$request_a, p$request_b), c("request_0001", "request_0002"))
  expect_identical(unname(tools::md5sum(list.files(pm_of(root), full.names = TRUE))), before)
})

test_that("status reconciliation proposes from item evidence and flags ambiguity", {
  regs <- governance_read(pm_of(planning_root()))
  r <- governance_reconcile_requirements(regs)
  got <- setNames(r$proposed, r$requirement_id)
  expect_equal(got[["req_0001"]], "accepted")
  expect_equal(got[["req_0002"]], "awaiting_acceptance")
  expect_equal(got[["req_0003"]], "in_progress")
  expect_equal(got[["req_0004"]], "planned")
  expect_false("req_0005" %in% r$requirement_id)          # no items: no evidence either way
  expect_true(r$ambiguous[r$requirement_id == "req_0003"])
  expect_false(any(r$ambiguous[r$requirement_id != "req_0003"]))
  expect_equal(governance_derived_status(regs$work_items[0, ]), NA_character_)
})

test_that("only human-approved proposals are applied, with the decision as evidence", {
  root <- planning_root(); dir <- pm_of(root)
  expect_error(governance_apply_requirement_status(dir, "req_0001", "approved"), "decision_NNNN")
  expect_error(governance_apply_requirement_status(dir, "req_0005", "decision_0001"), "Not a current proposal")
  governance_apply_requirement_status(dir, "req_0001", "decision_0001", at = "2026-03-03T10:00:00-03:00")
  regs <- governance_read(dir)
  expect_equal(regs$requirements$status[regs$requirements$requirement_id == "req_0001"], "accepted")
  expect_equal(regs$requirements$status[regs$requirements$requirement_id == "req_0002"], "proposed")
  t <- regs$transitions[regs$transitions$entity_id == "req_0001", ]
  expect_equal(c(t$from_status, t$to_status, t$evidence, t$actor), c("proposed", "accepted", "decision_0001", "developer"))
  expect_error(governance_apply_requirement_status(dir, "req_0001", "decision_0002"), "Not a current proposal")
  expect_equal(nrow(governance_check(regs)), 0L)
})

test_that("plans carry tasks, dependencies, risks and evidence-based estimates", {
  regs <- governance_read(pm_of(planning_root()))
  p <- governance_plan_requirement(regs, "req_0002")
  expect_equal(p$tasks$work_item_id, "work_0003")
  expect_equal(p$dependencies$items, "work_0006")
  expect_equal(p$dependencies$requirements, "req_0004")
  expect_match(paste(p$risks, collapse = " "), "work_0006")
  expect_true(is.na(p$effort_days$value))                # no accepted history in module funds
  c3 <- governance_plan_requirement(regs, "req_0003")
  expect_equal(c3$effort_days$sample, 3L)                # module common; imported acceptances stay out
  expect_equal(c3$effort_days$value, 4)                  # median of 2, 4, 6 days x 1 open item
  expect_equal(c3$agent$recommended, "claude_code")
  expect_true(is.na(p$tokens$value))                     # no reported executions: never estimated
  expect_equal(p$agent$recommended, "claude_code")
  expect_match(p$test_strategy, "1 testes")
  expect_true(is.na(governance_plan_requirement(regs, "req_0003", min_sample = 4L)$effort_days$value))
  q <- governance_plan_requirement(regs, "req_0005")
  expect_equal(nrow(q$tasks), 0L)
  expect_equal(q$complexity$level, "não decomposto")
  expect_true(is.na(q$effort_days$value))
  expect_match(paste(q$risks, collapse = " "), "não decomposto")
  expect_error(governance_plan_requirement(regs, "req_0099"), "Unknown requirement")
})

test_that("prioritization is transparent, excludes delivered requirements and changes nothing", {
  root <- planning_root(); regs <- governance_read(pm_of(root))
  before <- regs$requirements$priority
  p <- governance_prioritize(regs)
  expect_false("req_0001" %in% p$requirement_id)          # every item accepted
  expect_equal(p$score, p$priority_weight + p$unblocks + p$started - p$penalty)
  expect_equal(p$unblocks[p$requirement_id == "req_0004"], 1)
  expect_equal(p$rank, seq_len(nrow(p)))
  expect_true(all(diff(p$score) <= 0))
  expect_identical(governance_read(pm_of(root))$requirements$priority, before)
})

test_that("context packs follow the tiers, the budget and the protected-path rule", {
  root <- planning_root(); regs <- governance_read(pm_of(root))
  k <- governance_context_pack(root, regs, "req_0001", budget = 100000L)
  expect_equal(k$tier, sort(k$tier))
  expect_true("src/a.R" %in% k$source)
  expect_false(any(grepl("restricted|\\.\\.", k$source)))
  expect_true(all(k$included))
  small <- governance_context_pack(root, regs, "req_0001", budget = 10L)
  expect_true(all(small$included[small$tier == 1L]))
  expect_false(any(small$included[small$tier > 1L]))
  h <- governance_context_pack(root, regs, "req_0002")
  expect_true(any(grepl("^handoff.md: 1 parágrafo", h$source)))
  expect_false(governance_safe_path("C:/x.R")); expect_false(governance_safe_path("tmp/a"))
  expect_false(governance_safe_path("a/../../b")); expect_true(governance_safe_path("src/common/x.R"))
})

test_that("replanning inputs start at the last approved revision and the report renders", {
  regs <- governance_read(pm_of(planning_root()))
  r <- governance_replan_inputs(regs)
  expect_equal(r$since, "2026-02-01T10:00:00-03:00")
  expect_equal(r$requests$request_id, c("request_0002", "request_0003"))
  expect_equal(r$open_risks, "risk_0001")
  expect_true(is.na(r$tokens))
  md <- governance_planning_report(regs, at = "2026-03-03T10:00:00-03:00")
  expect_true(any(grepl("^## Prioridade dos requisitos abertos", md)))
  expect_true(any(grepl("^## Reconciliação do status", md)))
  expect_true(any(grepl("Tokens informados: indisponível", md, fixed = TRUE)))
  expect_true(any(grepl("| req_0003 | accepted | in_progress |", md, fixed = TRUE)))
})
