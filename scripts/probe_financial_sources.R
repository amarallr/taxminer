# Collect P04 step 00 source probe (Phase 2, financial_disclosures): small,
# rate-limited requests to CVM public sources. Run from the project root:
#   Rscript --vanilla scripts/probe_financial_sources.R
# Uses the system curl executable, as scripts/probe_sources.R does. Responses go
# to reports/source_probes/<run_id>_cvm/ (local, ignored by Git) with a manifest
# of URL, status, size and SHA-256. It downloads the smallest yearly DFP index
# ZIP and one filing document only, and stops on 403/429 responses.

if (!file.exists("taxminer.Rproj")) stop("Run from the TaxMiner project root.")
if (!nzchar(Sys.which("curl"))) stop("curl executable not found on PATH.")

user_agent <- "TaxMiner-source-probe/0.1"
cvm_delay_seconds <- 10 # dados.cvm.gov.br robots.txt Crawl-Delay
rad_delay_seconds <- 10 # no robots.txt on www.rad.cvm.gov.br; same courtesy delay
run_id <- paste0(format(Sys.time(), "%Y%m%dT%H%M%S"), "_cvm")
output_dir <- file.path("reports", "source_probes", run_id)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cvm_data <- "https://dados.cvm.gov.br/dados/CIA_ABERTA"
manifest <- data.frame()
stop_requested <- FALSE

fetch <- function(probe_id, url, delay, accept = "*/*", max_bytes = 60e6) {
  if (stop_requested) return(invisible(NULL))
  Sys.sleep(delay)
  output_file <- file.path(output_dir, probe_id)
  header_file <- paste0(output_file, ".headers")
  args <- c("-sS", "-m", "300", "-A", shQuote(user_agent),
            "-H", shQuote(paste("Accept:", accept)),
            "--max-filesize", format(max_bytes, scientific = FALSE),
            "-D", shQuote(header_file), "-o", shQuote(output_file),
            "-w", shQuote("%{http_code}|%{content_type}"), shQuote(url))
  result <- suppressWarnings(system2("curl", args, stdout = TRUE))
  parts <- strsplit(utils::tail(result, 1), "|", fixed = TRUE)[[1]]
  status <- as.integer(parts[1])
  size <- if (file.exists(output_file)) file.size(output_file) else 0
  row <- data.frame(
    probe_id = probe_id, url = url, http_status = status,
    content_type = if (length(parts) > 1) parts[2] else NA_character_,
    bytes = size,
    sha256 = if (size > 0) as.character(tools::sha256sum(output_file)) else NA_character_,
    requested_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  manifest <<- rbind(manifest, row)
  cat(sprintf("%-36s %s %s bytes\n", probe_id, status, size))
  if (!is.na(status) && status %in% c(403L, 429L)) {
    cat("Access refused or rate-limited; stopping further probes.\n")
    stop_requested <<- TRUE
  }
  invisible(output_file)
}

# 1. Directory listings and the company register (CNPJ, CVM code, status).
fetch("cvm_robots.txt", "https://dados.cvm.gov.br/robots.txt", cvm_delay_seconds, "text/plain")
for (path in c("DOC/DFP/DADOS/", "DOC/ITR/DADOS/", "CAD/DADOS/")) {
  fetch(paste0("listing_", gsub("/", "_", tolower(path)), ".html"),
        paste0(cvm_data, "/", path), cvm_delay_seconds, "text/html")
}
fetch("cad_cia_aberta.csv", paste0(cvm_data, "/CAD/DADOS/cad_cia_aberta.csv"),
      cvm_delay_seconds, "text/csv")

# 2. Smallest yearly DFP ZIP (current year): index of filings and statements.
dfp_zip <- fetch("dfp_cia_aberta_2026.zip",
                 paste0(cvm_data, "/DOC/DFP/DADOS/dfp_cia_aberta_2026.zip"),
                 cvm_delay_seconds, "application/zip")
zip_members <- character()
first_link <- NA_character_
if (!is.null(dfp_zip) && file.exists(dfp_zip) && file.size(dfp_zip) > 0) {
  zip_members <- utils::unzip(dfp_zip, list = TRUE)$Name
  index <- utils::read.csv2(unz(dfp_zip, "dfp_cia_aberta_2026.csv"),
                            fileEncoding = "latin1", colClasses = "character")
  first_link <- sub("^http://", "https://", index$LINK_DOC[1])
}

# 3. One filing document from the official RAD/ENET download link (the index
# uses http://, which redirects to https://).
filing_members <- character()
attachment_names <- character()
if (!is.na(first_link)) {
  filing <- fetch("rad_filing_first_index_row.zip", first_link, rad_delay_seconds)
  if (!is.null(filing) && file.exists(filing) && file.size(filing) > 0) {
    filing_list <- tryCatch(utils::unzip(filing, list = TRUE), error = function(e) NULL)
    if (!is.null(filing_list)) {
      filing_members <- sprintf("%s (%s bytes)", filing_list$Name, filing_list$Length)
      xml_name <- grep("^[0-9]+(DFP|ITR).*\\.xml$", filing_list$Name, value = TRUE)[1]
      if (!is.na(xml_name)) {
        xml_text <- paste(readLines(unz(filing, xml_name), warn = FALSE,
                                    encoding = "UTF-8"), collapse = "\n")
        attachment_names <- regmatches(
          xml_text, gregexpr("(?<=<NomeArquivoPdf>)[^<]*", xml_text, perl = TRUE))[[1]]
      }
    }
  }
}

utils::write.csv(manifest, file.path(output_dir, "manifest.csv"), row.names = FALSE)
writeLines(c("dfp_2026_zip_members:", zip_members, "",
             "first_index_link:", first_link, "",
             "filing_members:", filing_members, "",
             "xml_pdf_attachments:", attachment_names),
           file.path(output_dir, "structure.txt"), useBytes = TRUE)
cat("\nDFP 2026 ZIP members:", length(zip_members), "\n")
cat("Filing members:\n"); cat(paste(" ", filing_members), sep = "\n")
cat("PDF attachments in XML:", length(attachment_names), "\n")
cat("Outputs:", output_dir, "\n")
