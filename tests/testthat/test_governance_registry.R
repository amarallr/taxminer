# TaxMiner Governance phase 02 (req_0021): registry integrity, IDs, transitions and
# request minimization. Synthetic registers in temporary folders; the real
# registers are only read (integrity and format round trip), never written.
# Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_governance_registry.R')"

source(testthat::test_path("..", "..", "src", "common", "governance_registry.R"))

real_dir <- testthat::test_path("..", "..", "docs", "project_management")

write_lines <- function(dir, file, lines) writeLines(lines, file.path(dir, file), useBytes = TRUE)

# Minimal synthetic registers: one requirement, two work items, one test, one acceptance.
synthetic_dir <- function() {
  dir <- tempfile("governance_")
  dir.create(dir)
  write_lines(dir, "requirements_register.csv", c(
    "requirement_id,module,description,source,priority,acceptance_criteria,status,owner,updated_at",
    "req_0001,common,Synthetic requirement,synthetic,high,Passes,proposed,developer,2026-01-01T10:00:00-03:00"))
  write_lines(dir, "work_items.csv", c(
    paste0('"work_item_id","module","requirement_id","title","type","priority","owner","dependencies",',
           '"implementation_status","test_status","acceptance_status","release_status","operations_status",',
           '"evidence_links","updated_at"'),
    paste0('"work_0001","common","req_0001","First, with a comma","feature","high","agent","","implemented",',
           '"passed","approved","not_released","not_started","a.R","2026-01-01T10:00:00-03:00"'),
    paste0('"work_0002","common","req_0001","Second","feature","high","agent","work_0001","not_started",',
           '"not_run","pending","not_released","not_started","","2026-01-01T10:00:00-03:00"')))
  write_lines(dir, "test_register.csv", c(
    "test_id,work_item_id,level,environment,execution_timestamp,result,evidence_path,code_commit",
    "test_0001,work_0001,unit,synthetic,2026-01-01T10:00:00-03:00,passed,a.R,abc1234"))
  write_lines(dir, "acceptance_register.csv", c(
    "acceptance_id,work_item_id,criteria,reviewer,decision,decision_timestamp,evidence_path,notes",
    "acc_0001,work_0001,Synthetic,developer,approved,2026-01-01T11:00:00-03:00,a.R,"))
  write_lines(dir, "risk_register.csv", c(
    "risk_id,description,likelihood,impact,mitigation,owner,status",
    "risk_0001,Synthetic,possible,low,None,developer,open"))
  dir
}

test_that("the real registers pass the integrity check", {
  p <- governance_check(governance_read(real_dir))
  expect_equal(nrow(p), 0L, info = paste(p$id, p$problem, collapse = "\n"))
})

test_that("rewriting the real registers reproduces them byte for byte (format kept)", {
  regs <- governance_read(real_dir)
  for (n in names(governance_specs)) {
    f <- file.path(real_dir, governance_specs[[n]]$file)
    if (!file.exists(f)) next
    original <- gsub("\r\n", "\n", readChar(f, file.size(f), useBytes = TRUE), fixed = TRUE)
    expect_identical(governance_format(regs[[n]], governance_specs[[n]]$quote), original, info = n)
  }
})

test_that("integrity check finds duplicated IDs, broken references, vocabulary and timestamps", {
  dir <- synthetic_dir()
  regs <- governance_read(dir)
  expect_equal(nrow(governance_check(regs)), 0L)
  regs$work_items$requirement_id[2] <- "req_0099"
  regs$work_items$dependencies[2] <- "work_0001;task_1"
  regs$tests <- rbind(regs$tests, regs$tests)
  regs$requirements$status <- "done"
  regs$acceptances$decision_timestamp <- "12/11/2026"
  p <- governance_check(regs)
  expect_true(any(grepl("req_0099' does not exist", p$problem)))
  expect_true(any(grepl("task_1' is not a valid reference", p$problem)))
  expect_true(any(p$register == "tests" & p$problem == "duplicated id"))
  expect_true(any(grepl("status: 'done' outside the vocabulary", p$problem)))
  expect_true(any(grepl("not ISO 8601", p$problem)))
})

test_that("an approved work item needs an approved acceptance row (Common P01)", {
  regs <- governance_read(synthetic_dir())
  regs$acceptances <- regs$acceptances[0, ]
  p <- governance_check(regs)
  expect_true(any(p$id == "work_0001" & grepl("without an approved row", p$problem)))
})

test_that("next IDs never reuse a number and keep four digits", {
  expect_equal(governance_next_id(character(), "request"), "request_0001")
  expect_equal(governance_next_id(c("trn_0001", "trn_0007", "trn_0003"), "trn"), "trn_0008")
})

test_that("a status change updates the register and appends a transition", {
  dir <- synthetic_dir()
  t <- governance_set_field(dir, "work_items", "work_0002", "implementation_status", "in_progress",
                            "claude_code", "test", at = "2026-01-02T09:00:00-03:00")
  expect_equal(t, "trn_0001")
  regs <- governance_read(dir)
  expect_equal(regs$work_items$implementation_status[2], "in_progress")
  expect_equal(regs$work_items$updated_at[2], "2026-01-02T09:00:00-03:00")
  expect_equal(regs$work_items$title[1], "First, with a comma")
  tr <- regs$transitions
  expect_equal(unlist(tr[1, c("entity_id", "field", "from_status", "to_status")], use.names = FALSE),
               c("work_0002", "implementation_status", "not_started", "in_progress"))
  expect_null(governance_set_field(dir, "work_items", "work_0002", "implementation_status", "in_progress", "x"))
  expect_equal(nrow(governance_read(dir)$transitions), 1L)
  expect_false(file.exists(file.path(dir, "work_items.csv.rollback")))
})

test_that("invalid changes are refused and leave the files untouched", {
  dir <- synthetic_dir()
  before <- readLines(file.path(dir, "work_items.csv"))
  expect_error(governance_set_field(dir, "work_items", "work_0002", "test_status", "green", "x"), "vocabulary")
  expect_error(governance_set_field(dir, "work_items", "work_0009", "test_status", "passed", "x"), "Unknown id")
  expect_error(governance_set_field(dir, "work_items", "work_0002", "work_item_id", "work_0003", "x"), "immutable")
  expect_error(governance_set_field(dir, "work_items", "work_0002", "requirement_id", "req_0042", "x"), "integrity")
  expect_error(governance_set_field(dir, "requirements", "req_0001", "description", "a, b", "x"), "comma")
  expect_identical(readLines(file.path(dir, "work_items.csv")), before)
  expect_false(file.exists(file.path(dir, "state_transitions.csv")))
})

test_that("requests get the next ID, a minimized summary and a first transition", {
  dir <- synthetic_dir()
  id <- governance_add_request(dir, "Add a filter, keep the layout", "feature", "claude_code", "claude_code",
                               "req_0001", "linked", received_at = "2026-01-03T08:00:00-03:00")
  expect_equal(id, "request_0001")
  rq <- governance_read(dir)$requests
  expect_equal(rq$summary, "Add a filter; keep the layout")
  expect_equal(rq$status, "linked")
  expect_equal(governance_read(dir)$transitions$entity_id, "request_0001")
  expect_equal(governance_add_request(dir, "Question about a chart", "question", "manual", "developer"), "request_0002")
})

test_that("request summaries refuse protected paths, e-mails, long and multi-line text", {
  dir <- synthetic_dir()
  expect_error(governance_add_request(dir, "read .restricted/file", "question", "manual", "dev"), "protected")
  expect_error(governance_add_request(dir, "see tmp/notes", "question", "manual", "dev"), "protected")
  expect_error(governance_add_request(dir, "mail someone@example.org", "question", "manual", "dev"), "e-mail")
  expect_error(governance_add_request(dir, strrep("a", 201), "question", "manual", "dev"), "200")
  expect_error(governance_add_request(dir, "two\nlines", "question", "manual", "dev"), "single line")
  expect_error(governance_add_request(dir, "unknown class", "wish", "manual", "dev"), "vocabulary")
  expect_error(governance_add_request(dir, "missing requirement", "feature", "manual", "dev", "req_0042"), "does not exist")
  expect_false(file.exists(file.path(dir, "request_register.csv")))
})

test_that("trace links a requirement to its work items, tests and acceptances", {
  regs <- governance_read(synthetic_dir())
  t <- governance_trace(regs, "req_0001")
  expect_setequal(names(t), c("requirements", "work_items"))
  t <- governance_trace(regs, "work_0001")
  expect_setequal(names(t), c("work_items", "tests", "acceptances"))
})

test_that("the summary counts work items per status dimension and pending decisions", {
  s <- governance_summary(governance_read(synthetic_dir()))
  expect_equal(as.integer(s$work_items$implementation_status[["implemented"]]), 1L)
  expect_equal(s$pending_human_decisions, 0L)
  expect_equal(s$open_risks, 1L)
})
