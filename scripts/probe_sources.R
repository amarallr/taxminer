# Collect P01 source probe: small, rate-limited requests to official public
# sources. Run from the project root:
#   Rscript --vanilla scripts/probe_sources.R
# Uses the system curl executable (bundled with Windows 10+) so no new R
# dependency is needed. Responses go to reports/source_probes/<run_id>/ (local,
# ignored by Git) with a manifest of URL, status, size and SHA-256.
# It performs no bulk download and stops on 403/429 responses.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
if (!nzchar(Sys.which("curl"))) stop("curl executable not found on PATH.")

user_agent <- "TaxMiner-source-probe/0.1"
normas_delay_seconds <- 5
cvm_delay_seconds <- 10 # dados.cvm.gov.br robots.txt Crawl-Delay
run_id <- format(Sys.time(), "%Y%m%dT%H%M%S")
output_dir <- file.path("reports", "source_probes", run_id)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

normas_api <- "https://normas.receita.fazenda.gov.br/api"
act_types <- c(solucao_de_consulta = 72L, solucao_de_consulta_conjunta = 104L,
               solucao_de_consulta_interna = 75L, solucao_de_divergencia = 73L)

manifest <- data.frame()
stop_requested <- FALSE

fetch <- function(probe_id, url, delay, body = NULL, accept = "application/json") {
  if (stop_requested) return(invisible(NULL))
  Sys.sleep(delay)
  output_file <- file.path(output_dir, probe_id)
  args <- c("-sS", "-m", "60", "-A", shQuote(user_agent),
            "-H", shQuote(paste("Accept:", accept)),
            "-o", shQuote(output_file), "-w", shQuote("%{http_code}"))
  if (!is.null(body)) {
    body_file <- tempfile(fileext = ".json")
    writeLines(body, body_file, useBytes = TRUE)
    args <- c(args, "-X", "POST", "-H",
              shQuote("Content-Type: application/json; charset=UTF-8"),
              "--data-binary", shQuote(paste0("@", body_file)))
  }
  status <- suppressWarnings(system2("curl", c(args, shQuote(url)), stdout = TRUE))
  status <- as.integer(utils::tail(status, 1))
  size <- if (file.exists(output_file)) file.size(output_file) else 0
  sha256 <- if (size > 0) {
    as.character(tools::sha256sum(output_file))
  } else NA_character_
  row <- data.frame(
    probe_id = probe_id, method = if (is.null(body)) "GET" else "POST",
    url = url, request_body = if (is.null(body)) "" else body,
    http_status = status, bytes = size, sha256 = sha256,
    requested_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  manifest <<- rbind(manifest, row)
  cat(sprintf("%-40s %s %s bytes\n", probe_id, status, size))
  if (!is.na(status) && status %in% c(403L, 429L)) {
    cat("Access refused or rate-limited; stopping further probes.\n")
    stop_requested <<- TRUE
  }
  invisible(output_file)
}

search_body <- function(type_id, start = "", end = "", page_size = 1L) {
  jsonlite::toJSON(list(
    tipoPesquisa = "", termo = "", tipoData = "dataPublicacao",
    dataInicio = start, dataFim = end, anoAto = "", numeroAto = "",
    apenasAtosVigentes = FALSE, apenasAtosInternos = FALSE, publicado = TRUE,
    internet = TRUE, orgaosSelecionados = "",
    tiposAtosSelecionados = as.character(type_id), refino = setNames(list(), character()),
    skipAggregations = TRUE, paginacaoPaginaAtual = 1L,
    paginacaoQuantidadePorPagina = as.integer(page_size)
  ), auto_unbox = TRUE)
}

# 1. Normas: reference lists.
fetch("normas_act_types.json", paste0(normas_api, "/tipoAto/ativo"), normas_delay_seconds)
fetch("normas_organs.json", paste0(normas_api, "/orgao/ativo"), normas_delay_seconds)

# 2. Normas: totals per act type (all years) and per sampled year, page size 1.
count_rows <- list()
for (type_name in names(act_types)) {
  for (year in c(NA, 2005L, 2015L, 2024L, 2025L)) {
    period <- if (is.na(year)) c("", "") else
      c(sprintf("01/01/%d", year), sprintf("31/12/%d", year))
    probe_id <- sprintf("normas_count_%s_%s.json", type_name,
                        if (is.na(year)) "all" else year)
    file <- fetch(probe_id, paste0(normas_api, "/indexacao/ato/pesquisar"),
                  normas_delay_seconds, search_body(act_types[[type_name]], period[1], period[2]))
    total <- NA_real_
    if (!is.null(file) && file.exists(file) && file.size(file) > 0) {
      parsed <- tryCatch(jsonlite::fromJSON(file), error = function(e) NULL)
      if (!is.null(parsed$quantidadeTotal)) total <- parsed$quantidadeTotal
    }
    count_rows[[length(count_rows) + 1]] <- data.frame(
      act_type = type_name, publication_year = if (is.na(year)) "all" else as.character(year),
      reported_total = total
    )
  }
}
counts <- do.call(rbind, count_rows)

# 3. Normas: one page of acts (January 2024) to inspect fields.
fetch("normas_sample_sc_2024_01.json", paste0(normas_api, "/indexacao/ato/pesquisar"),
      normas_delay_seconds, search_body(72L, "01/01/2024", "31/01/2024", 20L))

# 4. Public act viewer API (observed in the viewer's JavaScript). Expected to
# refuse automated access; recorded, never retried with other headers.
fetch("normasinternet2_act_135832.json",
      "https://normasinternet2.receita.fazenda.gov.br/api/consulta-externa/ato/135832",
      normas_delay_seconds)
stop_requested <- FALSE # a refusal above concerns that host only

# 5. CVM open data (Phase 2): directory listings only, no ZIP downloads.
for (path in c("DFP/DADOS/", "ITR/DADOS/")) {
  fetch(paste0("cvm_listing_", tolower(sub("/DADOS/", "", path)), ".html"),
        paste0("https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/", path),
        cvm_delay_seconds, accept = "text/html")
}

utils::write.csv(manifest, file.path(output_dir, "manifest.csv"), row.names = FALSE)
utils::write.csv(counts, file.path(output_dir, "normas_counts.csv"), row.names = FALSE)
cat("\nReported totals (Normas search API):\n")
print(counts, row.names = FALSE)
cat("\nOutputs:", output_dir, "\n")
