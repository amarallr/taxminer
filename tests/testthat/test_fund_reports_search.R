# Phase 1.3 (work_0022) tests for the investment fund report search. Synthetic
# Latin-1 members are consolidated with Data P04 into a temporary root; no
# network. Run from the project root:
#   Rscript --vanilla -e "testthat::test_file('tests/testthat/test_fund_reports_search.R')"

source(testthat::test_path("..", "..", "src", "common", "signatures.R"))
source(testthat::test_path("..", "..", "src", "common", "safe_io.R"))
source(testthat::test_path("..", "..", "src", "common", "parquet_io.R"))
source(testthat::test_path("..", "..", "src", "data", "consolidate_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "intelligence", "search_fund_reports.R"))
source(testthat::test_path("..", "..", "src", "data", "entity_resolution.R"))
source(testthat::test_path("helper_stored_zip.R"))
rules <- load_entity_rules(testthat::test_path("..", "..", "config", "entity_name_rules.csv"))

latin1 <- function(x) iconv(x, "UTF-8", "latin1")

fii_geral <- paste0(c(
  "CNPJ_Fundo_Classe;Data_Referencia;Versao;Nome_Fundo_Classe;Nome_Administrador;CNPJ_Administrador",
  "00.332.266/0001-31;2026-01-31;1;FUNDO SÃO PAULO;ADMINISTRADORA ÁGIL S.A.;33.000.167/0001-01",
  "00.332.266/0001-31;2026-02-28;1;FUNDO SÃO PAULO;ADMINISTRADORA ÁGIL S.A.;33.000.167/0001-01",
  "00.332.266/0001-31;2026-03-31;1;FUNDO SÃO PAULO;OUTRA ADMINISTRADORA LTDA;60.701.190/0001-04",
  "11.111.111/1111-11;2026-01-31;1;CNPJ INVALIDO;ADMINISTRADORA ÁGIL S.A.;33.000.167/0001-01"),
  collapse = "\n")
fii_ativo <- paste0(c(
  "CNPJ_Fundo_Classe;Data_Referencia;Valor_Ativo;Campo_Vazio",
  "00.332.266/0001-31;2026-01-31;-1.234,56;",
  "00.332.266/0001-31;2026-03-31;0,00;",
  "60.701.190/0001-04;2026-01-31;99;"), collapse = "\n")
fidc_tab_i <- paste0(c(
  "CNPJ_FUNDO_CLASSE;DENOM_SOCIAL;DT_COMPTC;ADMIN;CNPJ_ADMIN",
  "60.701.190/0001-04;FIDC CRÉDITO;2025-12-31;ADMINISTRADORA ÁGIL S.A.;33.000.167/0001-01"),
  collapse = "\n")
fip_tri <- paste0(c(
  "CNPJ_FUNDO;DENOM_SOCIAL;DT_COMPTC",
  "33.000.167/0001-01;FIP PARTICIPAÇÕES;2023-12-31"), collapse = "\n")

add_file <- function(root, family, dataset, file_name, members) {
  stem <- sub("\\.zip$", "", file_name)
  raw <- file.path(root, "raw", family, tolower(dataset), stem)
  dir.create(raw, recursive = TRUE, showWarnings = FALSE)
  zip <- write_stored_zip(file.path(raw, "v1.zip"), lapply(members, latin1))
  sha <- as.character(tools::sha256sum(zip))
  final <- file.path(raw, paste0(substr(sha, 1, 12), ".zip"))
  file.rename(zip, final)
  manifest <- file.path(root, "manifests", paste0(family, ".csv"))
  row <- data.frame(source_id = sprintf("cvm:%s:%s:%s", family, tolower(dataset), file_name),
                    family = family, dataset = dataset, reference_period = "2026",
                    file_name = file_name,
                    source_url = sprintf("https://dados.cvm.gov.br/dados/%s/%s", toupper(family), file_name),
                    outcome = "downloaded", file_sha256 = sha,
                    raw_path = substring(final, nchar(root) + 2L), retrieved_at = "2026-11-11T01:00:00")
  utils::write.table(row, manifest, sep = ",", row.names = FALSE, col.names = !file.exists(manifest),
                     append = file.exists(manifest), qmethod = "double")
  sha
}

search_root <- function() {
  root <- tempfile("fund_search_")
  dir.create(file.path(root, "manifests"), recursive = TRUE)
  dir.create(file.path(root, "meta"))
  add_file(root, "fii", "INF_MENSAL", "inf_mensal_fii_2026.zip",
           list("inf_mensal_fii_geral_2026.csv" = fii_geral,
                "inf_mensal_fii_ativo_passivo_2026.csv" = fii_ativo))
  add_file(root, "fidc", "INF_MENSAL", "inf_mensal_fidc_202512.zip",
           list("inf_mensal_fidc_tab_I_202512.csv" = fidc_tab_i))
  add_file(root, "fip", "INF_TRIMESTRAL", "inf_trimestral_fip_2023.zip",
           list("inf_trimestral_fip_2023.csv" = fip_tri))
  consolidate_fund_reports(root, progress = FALSE)
  root
}

skip_if_not_installed("arrow")
root <- search_root()
directory <- load_fund_directory(root)
master <- load_entity_master(root, directory, rules)

test_that("the directory keeps one entry per fund, name and administrator as published", {
  expect_equal(names(directory), fund_directory_columns)
  sp <- directory[directory$fund_cnpj == "00332266000131", ]
  expect_equal(nrow(sp), 2L)
  agil <- sp[sp$administrator_name == "ADMINISTRADORA ÁGIL S.A.", ]
  expect_equal(c(agil$first_period, agil$last_period, agil$period_count),
               c("2026-01-31", "2026-02-28", "2"))
  expect_equal(agil$fund_name, "FUNDO SÃO PAULO")
  # The citation points at the most recent row of that entry.
  expect_equal(c(agil$source_file, agil$source_line), c("inf_mensal_fii_geral_2026.csv", "3"))
  expect_equal(sort(unique(directory$family)), c("fidc", "fii", "fip"))
})

test_that("invalid CNPJ stays searchable by the published value", {
  bad <- directory[directory$fund_name == "CNPJ INVALIDO", ]
  expect_equal(bad$fund_cnpj, "11.111.111/1111-11")
  expect_equal(nrow(search_fund_directory(directory, cnpj = "11.111.111/1111-11")), 1L)
})

test_that("FIP has no administrator and FIDC uses DENOM_SOCIAL and ADMIN", {
  expect_true(is.na(directory$administrator_name[directory$family == "fip"]))
  fidc <- directory[directory$family == "fidc", ]
  expect_equal(c(fidc$fund_name, fidc$administrator_cnpj), c("FIDC CRÉDITO", "33.000.167/0001-01"))
})

test_that("filters combine and ignore case, accents and CNPJ punctuation", {
  expect_equal(nrow(search_fund_directory(directory, administrator = "administradora agil")), 3L)
  expect_equal(nrow(search_fund_directory(directory, administrator = "33000167")), 3L)
  expect_equal(nrow(search_fund_directory(directory, administrator = "agil", family = "fidc")), 1L)
  expect_equal(nrow(search_fund_directory(directory, cnpj = "00.332")), 2L)
  expect_equal(nrow(search_fund_directory(directory, name = "sao paulo", administrator = "outra")), 1L)
  expect_equal(nrow(search_fund_directory(directory, name = "participacoes")), 1L)
  expect_equal(nrow(search_fund_directory(directory)), nrow(directory))
  expect_equal(nrow(search_fund_directory(directory, name = "inexistente")), 0L)
})

test_that("period filters keep funds whose reports overlap the range", {
  expect_equal(sort(search_fund_directory(directory, period_to = "2025")$family), c("fidc", "fip"))
  hits <- search_fund_directory(directory, cnpj = "00332266000131", period_from = "2026-03")
  expect_equal(hits$administrator_name, "OUTRA ADMINISTRADORA LTDA")
  expect_equal(nrow(search_fund_directory(directory, period_from = "2026-02-15",
                                          period_to = "2026-02-20")), 1L)
  expect_equal(nrow(search_fund_directory(directory, period_from = "2027",
                                          period_to = "2027-12")), 0L)
  expect_error(search_fund_directory(directory, period_from = "02/2026"), "yyyy")
  expect_equal(period_bound("2026", upper = TRUE), "2026-12-31")
  expect_equal(period_bound("2026-02"), "2026-02-01")
  expect_true(is.na(period_bound("")))
})

test_that("report rows keep original values, drop empty columns and cite the source", {
  rows <- fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo", "00.332.266/0001-31")
  expect_equal(nrow(rows), 2L)
  expect_equal(rows$Valor_Ativo, c("-1.234,56", "0,00"))
  expect_false("Campo_Vazio" %in% names(rows))
  expect_equal(rows$source_line, 2:3)
  expect_equal(rows$source_url[1], "https://dados.cvm.gov.br/dados/FII/inf_mensal_fii_2026.zip")
  expect_match(rows$citation[1], "^CVM INF_MENSAL, inf_mensal_fii_ativo_passivo_2026.csv, linha 2, arquivo SHA-256 [0-9a-f]{12}$")
  expect_true("Campo_Vazio" %in% names(fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo",
                                                       "00332266000131", drop_empty = FALSE)))
  march <- fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo", "00332266000131",
                            period_from = "2026-03")
  expect_equal(march$Valor_Ativo, "0,00")
  expect_equal(nrow(fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo", "99999999000191")), 0L)
})

test_that("the rows cache returns the same rows and forgets the oldest query", {
  cached <- fund_rows_cache(root, fund_source_urls(root), size = 1L)
  direct <- fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo", "00.332.266/0001-31")
  expect_identical(cached("fii", "inf_mensal_fii_ativo_passivo", "00.332.266/0001-31"), direct)
  expect_identical(cached("fii", "inf_mensal_fii_ativo_passivo", "00.332.266/0001-31"), direct)
  march <- cached("fii", "inf_mensal_fii_ativo_passivo", "00332266000131", period_from = "2026-03")
  expect_equal(march$Valor_Ativo, "0,00")
  expect_identical(cached("fii", "inf_mensal_fii_ativo_passivo", "00.332.266/0001-31"), direct)
  expect_equal(environment(cached)$order, "fii|inf_mensal_fii_ativo_passivo|00.332.266/0001-31||")
})

test_that("the directory cache is reused and rebuilt when a registry table changes", {
  paths <- fund_search_paths(root)
  expect_true(file.exists(paths$directory))
  stamp <- readRDS(paths$index)$built_at
  Sys.sleep(1.1)
  again <- load_fund_directory(root)
  expect_equal(readRDS(paths$index)$built_at, stamp)
  expect_equal(again, directory, ignore_attr = TRUE)
  index <- readRDS(fund_processed_paths(root)$index)
  index$output_sha256[index$table_name == "inf_mensal_fii_geral"] <- "changed"
  saveRDS(index, fund_processed_paths(root)$index)
  load_fund_directory(root)
  expect_false(identical(readRDS(paths$index)$built_at, stamp))
})

test_that("tables and quality summaries come from the consolidation outputs", {
  tables <- fund_tables(root, "fii")
  expect_equal(tables$table_name, c("inf_mensal_fii_ativo_passivo", "inf_mensal_fii_geral"))
  expect_equal(tables$rows, c(3L, 4L))
  expect_equal(nrow(fund_tables(root, "fiagro")), 0L)
  quality <- fund_quality_summary(root)
  expect_true(all(c("family", "issue_type", "records") %in% names(quality)))
  expect_true("invalid_cnpj" %in% quality$issue_type[quality$family == "fii"])
})

test_that("the Shiny area searches, lists rows with linked citations and reports bad input", {
  skip_if_not_installed("shiny")
  source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"), encoding = "UTF-8")
  data <- fund_search_data(root, rules = rules)
  shiny::testServer(fund_search_server, args = list(root = root, data = data), {
    # Free text: CNPJ prefix with mask. One line per fund, even with two administrators.
    session$setInputs(family = c("fii", "fidc", "fip"), fund_query = "00.332.266",
                      administrator = character(), period_from = "", period_to = "")
    expect_match(output$summary, "^1 fundo$")
    expect_match(as.character(output$kpis$html), "<b>1</b>\\s*fundos")
    expect_match(as.character(output$kpis$html), "<b>2</b>\\s*administradores")
    # Administrator by catalog option: its value is a denomination id resolved to the CNPJ.
    outra <- master$entity_names$name_id[master$entity_names$entity_id == "administrator:60701190000104"]
    session$setInputs(fund_query = "são paulo", administrator = outra)
    expect_match(output$summary, "^1 fundo$")
    session$setInputs(fund_query = "00.332.266", administrator = character())
    expect_match(output$funds$html, "data-key=\"fii|00332266000131\"", fixed = TRUE)
    expect_match(output$page, "^Página 1 de 1")
    # Sorting by header click: a new column takes its default direction
    # (Informes: most recent first), the same column again reverses it.
    expect_match(output$funds$html, "data-sort=\"name\"", fixed = TRUE)
    session$setInputs(sort_col = "last")
    expect_match(output$funds$html, "Informes ▼", fixed = TRUE)
    session$setInputs(sort_col = "last")
    expect_match(output$funds$html, "Informes ▲", fixed = TRUE)
    session$setInputs(pick = "fii|00332266000131", table = "inf_mensal_fii_ativo_passivo")
    expect_match(output$detail$html, "FUNDO SÃO PAULO", fixed = TRUE)
    expect_match(output$detail$html, "FII · 00.332.266/0001-31", fixed = TRUE)
    expect_match(output$names$html, "FUNDO SÃO PAULO", fixed = TRUE)
    expect_match(output$rows_summary, "^2 linhas em 2 períodos")
    expect_match(output$rows$html, "<a href=\"https://dados.cvm.gov.br/dados/FII/inf_mensal_fii_2026.zip\"",
                 fixed = TRUE)
    expect_match(output$rows$html, "-1.234,56", fixed = TRUE)
    session$setInputs(period = "2026-03-31")
    expect_match(output$card$html, "0,00", fixed = TRUE)
    expect_false(grepl("-1.234,56", output$card$html, fixed = TRUE))
    session$setInputs(period_from = "13/2026")
    expect_match(output$summary, "^Erro:")
  })
})

test_that("a family tab only lists that family", {
  skip_if_not_installed("shiny")
  source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"), encoding = "UTF-8")
  data <- fund_search_data(root, rules = rules)
  shiny::testServer(fund_search_server, args = list(root = root, data = data, families = "fidc"), {
    session$setInputs(fund_query = character(), administrator = character(), period_from = "", period_to = "")
    expect_match(output$summary, "^1 fundo$")
    expect_match(output$funds$html, "FIDC CRÉDITO", fixed = TRUE)
    expect_false(grepl("FUNDO SÃO PAULO", output$funds$html, fixed = TRUE))
  })
})

test_that("the fund field reads a CNPJ (with or without mask) or a name, and choices cover every fund", {
  skip_if_not_installed("shiny")
  source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"), encoding = "UTF-8")
  d <- annotate_directory_entities(directory)
  expect_equal(resolve_entity_query("00.332.266/0001-31", master, "fund"), "fund:00332266000131")
  expect_equal(resolve_entity_query("00332266000131", master, "fund"), "fund:00332266000131")
  expect_equal(resolve_entity_query("00332", master, "fund"), "fund:00332266000131")
  expect_equal(resolve_entity_query("11.111.111/1111-11", master, "fund"), "fund:raw:11111111111111")
  expect_equal(resolve_entity_query("fidc crédito", master, "fund"), "fund:60701190000104")
  expect_null(resolve_entity_query("  ", master, "fund"))
  expect_null(resolve_entity_query(character(), master, "fund"))
  choices <- fund_choices(master, d)
  expect_equal(length(unique(sub("#.*$", "", choices))), length(unique(d$fund_entity)))
  expect_true("00.332.266/0001-31 — FUNDO SÃO PAULO" %in% names(choices))
  admins <- administrator_choices(master, d)
  expect_true(any(grepl("^33.000.167/0001-01 — ADMINISTRADORA ÁGIL S.A. \\(3 fundos\\)$", names(admins))))
  periods <- period_choices(directory)
  expect_true(all(c("2023", "2026-03", "2025-12") %in% periods))
  expect_equal(periods[1], "2026-03")
})

test_that("placeholder fund names are shown as missing and sorted last", {
  skip_if_not_installed("shiny")
  source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"), encoding = "UTF-8")
  expect_equal(has_name(c("NA", ",", "0", NA, "FUNDO A")), c(FALSE, FALSE, FALSE, FALSE, TRUE))
  expect_equal(display_name(c(".", "FUNDO A")), c("(sem nome publicado)", "FUNDO A"))
  r <- data.frame(fund_name = c("NA", "B FUNDO", ",", "a fundo"), last_period = "2026-01-31",
                  fund_cnpj = "1", period_count = 1L)
  expect_equal(sort_directory(r, "name")$fund_name[1:2], c("a fundo", "B FUNDO"))
})

test_that("the full series table formats values like the card and stays fast", {
  x <- c(NA, "", "0", "12", "1234", "-1234567.5", "1.234,56", "007", "-05", "abc", "1e5", "1.234", "S")
  for (field in c("TAB_I_VL_ATIVO", "CNPJ_FUNDO")) {
    one <- lapply(x, display_value, field = field)
    all <- display_values(x, field)
    expect_identical(all$text, vapply(one, `[[`, "", "text"))
    expect_identical(all$num, vapply(one, `[[`, TRUE, "num"))
  }
  # Transposed: one line per field (Ficha labels), one column per period,
  # most recent first; fields empty in every period are hidden.
  r <- data.frame(citation = c("CVM <a&b>", "CVM 2"), source_url = c("https://x/1.zip", NA),
                  DT_COMPTC = c("2013-01-31", "2013-02-28"), reference_period = "2013", layout_version = "v1",
                  TAB_I_VL_ATIVO = c("1234.5", ""), TAB_I_VL_VAZIO = NA_character_, stringsAsFactors = FALSE)
  tab <- wide_table(r)
  h <- as.character(tab)
  # Same label as the Ficha for the field.
  expect_match(h, paste0('<th class="tm-field tm-derived" data-tip="', field_labels("TAB_I_VL_ATIVO")$label,
                         "\nCampo CVM: TAB_I_VL_ATIVO (sem descrição no dicionário)\">",
                         field_labels("TAB_I_VL_ATIVO")$label, "</th>"), fixed = TRUE)
  expect_equal(attr(tab, "hidden"), 1L)
  expect_false(grepl("TAB_I_VL_VAZIO\\b[^\"]*</th>", h))
  expect_match(h, '<th class="tm-col-period" title="CVM 2">2013-02</th><th class="tm-col-period" title="CVM &lt;a&amp;b&gt;"><a href="https://x/1.zip"', fixed = TRUE)
  expect_match(h, '<td>—</td><td class="tm-num">1.234,5</td></tr>', fixed = TRUE)
  expect_false(grepl("reference_period|layout_version|>2013<", h))
  big <- r[rep(1:2, 100), ]
  big[paste0("TAB_I_VL_", 1:80)] <- "123456.78"
  expect_lt(system.time(wide_table(big))[["elapsed"]], 5)
})

test_that("CNPJ and CPF fields are shown with their masks only when valid", {
  expect_equal(format_cpf(c("52998224725", "529.982.247-25", "12345678900", "11111111111", NA, "abc")),
               c("529.982.247-25", "529.982.247-25", "12345678900", "11111111111", NA, "abc"))
  mixed <- "TAB_I2B1_CPF_CNPJ_CEDENTE_1"
  expect_equal(format_tax_id(c("11222333000181", "9195235000150", "52998224725", "11222333000180"), mixed),
               c("11.222.333/0001-81", "09.195.235/0001-50", "529.982.247-25", "11222333000180"))
  expect_equal(format_tax_id("52998224725", "CPF_GESTOR"), "529.982.247-25")
  expect_equal(format_tax_id("11222333000181", "VL_ATIVO"), "11222333000181")
  expect_equal(display_value("11222333000181", "CNPJ_ADMIN")$text, "11.222.333/0001-81")
  expect_equal(display_values(c("11222333000181", "", NA), "CNPJ_ADMIN")$text, c("11.222.333/0001-81", "—", "—"))
})

test_that("the published fund records carry the series of the app, formatted the same way", {
  skip_if_not_installed("jsonlite")
  source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"), encoding = "UTF-8")
  source(testthat::test_path("..", "..", "src", "intelligence", "panorama_data.R"), encoding = "UTF-8")
  source(testthat::test_path("..", "..", "prototype", "static_funds.R"), encoding = "UTF-8")
  out <- tempfile("site")
  data <- list(urls = fund_source_urls(root), descriptions = fund_field_descriptions(root))
  res <- write_static_fichas(out, root, data, tables = list(fii = "inf_mensal_fii_ativo_passivo"))
  expect_equal(res$funds, 2L)
  f <- jsonlite::fromJSON(file.path(out, "data", "fichas", "fii", "00332266000131.json"), simplifyVector = FALSE)
  x <- f$t[[1]]
  expect_equal(x$n, "inf_mensal_fii_ativo_passivo")
  # Most recent period first, citing the CVM file and line.
  expect_equal(vapply(x$c, function(c) c[[1]], ""), c("2026-03", "2026-01"))
  expect_equal(x$c[[2]][[4]], 2L)
  urls <- jsonlite::fromJSON(file.path(out, "data", "fichas", "urls.json"))
  expect_equal(urls[x$c[[1]][[6]] + 1L], "https://dados.cvm.gov.br/dados/FII/inf_mensal_fii_2026.zip")
  codes <- vapply(x$f, function(y) y[[2]], "")
  expect_false("Campo_Vazio" %in% codes)
  v <- x$f[[match("Valor_Ativo", codes)]]
  expect_equal(unlist(v[[5]]), c("0,00", "-1.234,56"))
  expect_equal(v[[4]], "11")
  # Same text as the Série completa of the app.
  rows <- fund_report_rows(root, "fii", "inf_mensal_fii_ativo_passivo", "00332266000131")
  expect_match(as.character(wide_table(rows)), "-1.234,56", fixed = TRUE)
  expect_equal(unlist(x$f[[match("fund_cnpj_original", codes)]][[5]]), c("00.332.266/0001-31", "00.332.266/0001-31"))
})

test_that("other tables go gzip compressed, one file per fund, with an index", {
  source(testthat::test_path("..", "..", "prototype", "static_funds.R"), encoding = "UTF-8")
  out <- tempfile("site")
  data <- list(urls = fund_source_urls(root), descriptions = fund_field_descriptions(root))
  res <- write_static_ficha_extras(out, root, data,
                                   tables = list(fii = c("inf_mensal_fii_ativo_passivo", "tabela_ausente", "inf_mensal_fii_geral")))
  dir <- file.path(out, "data", "fichas_x", "fii")
  expect_true(file.exists(file.path(dir, "00332266000131.json.gz")))
  raw <- readBin(file.path(dir, "00332266000131.json.gz"), "raw", 2L)
  expect_equal(raw, as.raw(c(0x1f, 0x8b)))  # gzip, decompressed by the browser
  f <- jsonlite::fromJSON(gzfile(file.path(dir, "00332266000131.json.gz")), simplifyVector = FALSE)
  names_in <- vapply(f$t, function(x) x$n, "")
  expect_true("inf_mensal_fii_ativo_passivo" %in% names_in)
  x <- f$t[[match("inf_mensal_fii_ativo_passivo", names_in)]]
  # Same objects as the main files.
  main <- tempfile("site")
  write_static_fichas(main, root, data, tables = list(fii = "inf_mensal_fii_ativo_passivo"))
  y <- jsonlite::fromJSON(file.path(main, "data", "fichas", "fii", "00332266000131.json"), simplifyVector = FALSE)$t[[1]]
  expect_identical(x, y)
  ix <- jsonlite::fromJSON(gzfile(file.path(dir, "index.json.gz")), simplifyVector = FALSE)
  expect_equal(unlist(ix$tables), c("inf_mensal_fii_ativo_passivo", "tabela_ausente", "inf_mensal_fii_geral"))
  e <- ix$funds[["00332266000131"]][[1]]
  expect_equal(e[[1]], 0L)                   # table index
  expect_equal(c(e[[2]], e[[3]]), c("2026-01", "2026-03"))
  expect_equal(e[[4]], 2L)                   # rows
  expect_equal(res$funds, length(ix$funds))
})

test_that("table pickers show the report section, not the CVM file name", {
  expect_equal(fund_table_label("inf_mensal_fidc_tab_I"), "I – Aplicações")
  expect_equal(fund_table_label("inf_mensal_fidc_tab_X_6"), "X.6 – Desempenho esperado (benchmark) e realizado")
  expect_equal(fund_table_label("tabela_nova"), "tabela_nova")
  expect_true(all(paste0("inf_mensal_fidc_tab_", c("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "X_1",
                                                   "X_1_1", "X_2", "X_3", "X_4", "X_5", "X_6", "X_7")) %in% names(fund_table_labels)))
  source(testthat::test_path("..", "..", "prototype", "static_funds.R"), encoding = "UTF-8")
  expect_true(all(unlist(static_ficha_extra_tables) %in% names(fund_table_labels)))
})

test_that("the Ficha tab opens any fund with its Ficha and Série completa", {
  source(testthat::test_path("..", "..", "prototype", "fund_search_module.R"), encoding = "UTF-8")
  source(testthat::test_path("..", "..", "src", "intelligence", "fund_analytics.R"), encoding = "UTF-8")
  source(testthat::test_path("..", "..", "prototype", "fund_record_module.R"), encoding = "UTF-8")
  data <- fund_search_data(root, rules = rules)
  choices <- fund_record_choices(data)
  expect_true("fii|00332266000131" %in% choices)
  expect_match(names(choices)[choices == "fii|00332266000131"], "^FII · 00.332.266/0001-31 — ")
  expect_equal(fund_record_default_table(data$tables, "fii"), "inf_mensal_fii_geral")
  shiny::testServer(fund_record_server, args = list(root = root, data = data), {
    session$setInputs(fund = "fii|00332266000131", table = "inf_mensal_fii_ativo_passivo")
    expect_equal(nrow(rows()), 2L)
    expect_match(output$summary, "2 linhas em 2 períodos")
    session$setInputs(period = "2026-01-31")
    expect_match(output$card$html, "-1.234,56", fixed = TRUE)
    expect_match(output$rows$html, "tm-series")
  })
})

test_that("FIPs filter by the latest published investment entity indicator", {
  rows <- data.frame(
    fund_cnpj_normalized = c("11", "11", "22", "33", NA),
    ENTID_INVEST = c("S", " n ", "", "N", "S"),
    DT_COMPTC = c("2023-12-31", "2025-08-31", "2025-08-31", "2020-03-31", "2025-08-31"),
    stringsAsFactors = FALSE)
  e <- latest_investment_entity(rows)
  expect_equal(e$fund_cnpj, c("11", "33"))           # 22 never published a value
  expect_equal(e$investment_entity, c("N", "N"))     # most recent period wins, trimmed
  expect_equal(e$investment_entity_period, c("2025-08", "2020-03"))
  funds <- data.frame(family = c("fip", "fip", "fip", "fidc"), fund_cnpj = c("11", "22", "33", "44"))
  expect_equal(filter_investment_entity(funds, e, "N")$fund_cnpj, c("11", "33", "44"))
  expect_equal(filter_investment_entity(funds, e, "S")$fund_cnpj, "44")
  expect_equal(filter_investment_entity(funds, e, "NA")$fund_cnpj, c("22", "44"))
  expect_equal(nrow(filter_investment_entity(funds, e, "")), 4L)
  expect_equal(nrow(fund_investment_entity(root)), 0L)  # fixture FIP has no ENTID_INVEST column
})

test_that("fund characteristics keep the latest published value and say when the report lacks the field", {
  rows <- data.frame(
    fund_cnpj_normalized = c("11", "11", "22", "33"),
    value = c("Fechado", " Aberto ", "", "s"),
    DT_COMPTC = c("2023-12-31", "2025-08-31", "2025-08-31", "2020-03-31"),
    stringsAsFactors = FALSE)
  l <- latest_attribute(rows)
  expect_equal(l$fund_cnpj, c("11", "33"))
  expect_equal(l$value, c("Aberto", "S"))      # trimmed; S/N upper-cased, other text as published
  expect_equal(l$period, c("2025-08", "2020-03"))
  a <- data.frame(family = c("fidc", "fidc", "fii"), fund_cnpj = c("11", "11", "44"),
                  attribute = c("condominium", "single_interest", "exclusive"),
                  value = c("Aberto", "N", "Sim"), period = c("2025-08", "2025-08", "2024-12"),
                  stringsAsFactors = FALSE)
  expect_equal(fund_attribute_text(a, "fidc", "11", "condominium")$text, "aberto")
  expect_equal(fund_attribute_text(a, "fidc", "11", "single_interest")$text, "não")
  expect_equal(fund_attribute_text(a, "fii", "44", "exclusive")$text, "sim")
  expect_equal(fund_attribute_text(a, "fidc", "11", "exclusive")$text, "não informado")
  expect_equal(fund_attribute_text(a, "fii", "44", "condominium")$text, "não consta do informe")
  expect_setequal(fund_attribute_families("investment_entity"), "fip")
  expect_equal(nrow(fund_attributes(root, fund_attribute_specs[0, ])), 0L)
  source(testthat::test_path("..", "..", "src", "intelligence", "panorama_data.R"), encoding = "UTF-8")
  source(testthat::test_path("..", "..", "prototype", "static_funds.R"), encoding = "UTF-8")
  expect_equal(static_fund_traits(a, c("fidc", "fip"), c("11", "11")),
               c('[["Aberto","2025-08"],null,null,["N","2025-08"],null]',
                 "[null,null,null,null,null]"))
  meta <- jsonlite::fromJSON(static_traits_meta())
  expect_equal(meta$order, static_trait_order)
  expect_equal(meta$columns$fidc$single_interest, "COTST_INTERESSE")
})
