# Governance views (Governança tab): pending work, acceptances, requirements and
# dependencies, from synthetic in-memory registers. Run from the project root:
#   Rscript -e "testthat::test_file('tests/testthat/test_governance_views.R')"

source(testthat::test_path("..", "..", "src", "common", "governance_views.R"))

views_regs <- function() {
  w <- function(id, req, deps, impl, test, acc, pr = "high") data.frame(
    work_item_id = id, requirement_id = req, title = paste("Item", id), priority = pr, dependencies = deps,
    implementation_status = impl, test_status = test, acceptance_status = acc, release_status = "not_released",
    stringsAsFactors = FALSE)
  list(
    work_items = rbind(
      w("work_0001", "req_0001", "", "implemented", "passed", "approved"),
      w("work_0002", "req_0001", "work_0001", "implemented", "passed", "pending"),
      w("work_0003", "req_0002", "work_0002", "not_started", "not_run", "pending"),
      w("work_0004", "req_0002", "", "in_progress", "not_run", "pending", "medium"),
      w("work_0005", "req_0002", "work_0009", "blocked", "not_run", "pending"),
      w("work_0006", "req_0002", "", "implemented", "not_run", "pending")),
    requests = data.frame(request_id = c("request_0001", "request_0002"), summary = c("Instalador", "Feito"),
                          requirement_ids = c("", "req_0001"), status = c("captured", "answered"),
                          stringsAsFactors = FALSE),
    acceptances = data.frame(acceptance_id = c("acc_0001", "acc_0002"), work_item_id = c("work_0001", "work_0404"),
                             criteria = c("Critério A", "Critério B"), reviewer = "developer",
                             decision = c("approved", "rejected"),
                             decision_timestamp = c("2026-01-02T10:00:00-03:00", "2026-01-03T10:00:00-03:00"),
                             stringsAsFactors = FALSE),
    requirements = data.frame(requirement_id = c("req_0001", "req_0002", "req_0003"),
                              description = c("A", "B", "C"), module = "common", priority = "high",
                              status = c("in_progress", "proposed", "accepted"), stringsAsFactors = FALSE))
}

test_that("each item gets one situation, next step and owner from its recorded states", {
  s <- governance_item_situation(views_regs()$work_items)
  expect_equal(s$situation, c("Aceito", "Implementado e testado", "Não iniciado", "Em desenvolvimento", "Bloqueado",
                              "Implementado, sem teste"))
  expect_equal(s$tone, c("done", "wait", "todo", "dev", "block", "dev"))
  expect_equal(s$next_step[2], "Seu aceite")
  expect_equal(s$who[2], "Você")
})

test_that("pending work lists unaccepted items and captured requests, awaiting the developer first", {
  p <- governance_pending_view(views_regs())
  expect_false("work_0001" %in% p$id)
  expect_equal(p$id[1], "work_0002")
  expect_equal(p$tone, c("wait", "dev", "dev", "block", "todo", "todo"))
  expect_equal(utils::tail(p$id, 1), "request_0001")
  expect_equal(p$situation[p$id == "request_0001"], "Pedido registrado, sem requisito")
  # Open dependencies are named with their situation; missing ones are flagged.
  expect_equal(p$depends[p$id == "work_0003"], "Itens: work_0002 (implementado e testado)")
  expect_match(p$depends[p$id == "work_0005"], "work_0009", fixed = TRUE)
  expect_equal(p$depends[p$id == "work_0002"], "Você")
})

test_that("acceptances carry the requirement of their item, newest first", {
  a <- governance_acceptance_view(views_regs())
  expect_equal(a$id, c("acc_0002", "acc_0001"))
  expect_equal(a$requirement, c("—", "req_0001"))
})

test_that("requirements count accepted, waiting and open items", {
  q <- governance_requirement_view(views_regs())
  expect_equal(q$items, c(2L, 4L, 0L))
  expect_equal(q$accepted, c(1L, 0L, 0L))
  expect_equal(q$waiting, c(1L, 0L, 0L))
  expect_equal(q$open, c(0L, 4L, 0L))
})

test_that("dependencies show the situation of each one and whether the item can go on", {
  d <- governance_dependency_view(views_regs())
  expect_setequal(d$id, c("work_0002", "work_0003", "work_0005"))
  expect_equal(d$ready[d$id == "work_0002"], "dependências atendidas")
  expect_equal(d$ready[d$id == "work_0003"], "aguarda dependências")
  expect_equal(d$depends[d$id == "work_0005"], "work_0009 (não encontrado)")
  expect_equal(d$depends[d$id == "work_0002"], "work_0001 (aceito)")
})

test_that("labels are in Portuguese and unknown values pass through", {
  expect_equal(governance_label("requirement", c("proposed", "novo")), c("proposto", "novo"))
  expect_equal(governance_label("risk", "observed"), "observado")
})
