# Extraction of explanatory notes from CVM filing packages (financial_notes,
# MVP Phase 1.2, Data P03). Input: immutable packages from Collect P04
# (src/collect/download_financial_reports.R). The notes are the PDF that the
# company attaches to ENET group 412 ("Notas Explicativas"); it is embedded in
# base64 in the filing XML:
#   - recent layout: `{cd_cvm}{DFP|ITR}{dd-mm-yyyy}v{n}.xml` at the package root;
#   - legacy layout: a nested ZIP `{...}.dfp` / `{...}.itr` holding
#     `AnexoDocumento.xml`.
# Text comes from the PDF text layer (pdftools); no OCR. Image-only PDFs are
# reported as such. Requires pdftools, xml2 and base64enc.

notes_group_code <- "412"
management_report_group_code <- "1653"

# ---- Package reading -------------------------------------------------------

# Returns a data frame of PDF attachments: group, file name and raw bytes
# (list column), plus the package layout and the XML-level metadata.
read_package_attachments <- function(package_path) {
  work_dir <- tempfile("package_")
  dir.create(work_dir)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)
  members <- utils::unzip(package_path, list = TRUE)$Name
  recent_xml <- grep("^[0-9]+(DFP|ITR).*v[0-9]+\\.xml$", members, value = TRUE)
  legacy_zip <- grep("\\.(dfp|itr)$", members, value = TRUE, ignore.case = TRUE)
  if (length(recent_xml) > 0) {
    layout <- "recent_xml"
    utils::unzip(package_path, files = recent_xml[1], exdir = work_dir)
    xml_path <- file.path(work_dir, recent_xml[1])
  } else if (length(legacy_zip) > 0) {
    layout <- "legacy_nested_zip"
    utils::unzip(package_path, files = legacy_zip[1], exdir = work_dir)
    inner <- utils::unzip(file.path(work_dir, legacy_zip[1]), list = TRUE)$Name
    if (!"AnexoDocumento.xml" %in% inner) {
      return(list(layout = layout, attachments = empty_attachments(), metadata = list()))
    }
    utils::unzip(file.path(work_dir, legacy_zip[1]), files = "AnexoDocumento.xml",
                 exdir = work_dir)
    xml_path <- file.path(work_dir, "AnexoDocumento.xml")
  } else {
    return(list(layout = "unknown", attachments = empty_attachments(), metadata = list()))
  }
  doc <- xml2::read_xml(xml_path, options = c("HUGE", "NOBLANKS"))
  nodes <- xml2::xml_find_all(doc, "//*[ImagemObjetoArquivoPdf]")
  attachments <- empty_attachments()
  for (node in nodes) {
    field <- function(name) {
      value <- xml2::xml_text(xml2::xml_find_first(node, name))
      if (is.na(value)) NA_character_ else value
    }
    encoded <- field("ImagemObjetoArquivoPdf")
    if (is.na(encoded) || !nzchar(encoded)) next
    bytes <- base64enc::base64decode(encoded)
    attachments <- rbind(attachments, data.frame(
      group_code = field("NumeroGrupoRelacionado"),
      file_name = basename(gsub("\\\\", "/", field("NomeArquivoPdf"))),
      bytes = I(list(bytes)), stringsAsFactors = FALSE))
  }
  metadata <- list(
    reporting_period_start = xml_date(doc, "//DadosDFP/DtInicioUltimoExercicioSocial|//DadosITR/DtInicioTrimestreAtual"),
    company_name_xml = xml_value(doc, "//DadosEmpresa/RazaoSocialEmpresa"),
    company_cnpj_xml = xml_value(doc, "//DadosEmpresa/CnpjEmpresa")
  )
  list(layout = layout, attachments = attachments, metadata = metadata)
}

empty_attachments <- function() {
  data.frame(group_code = character(), file_name = character(),
             bytes = I(list()), stringsAsFactors = FALSE)
}

xml_value <- function(doc, xpath) {
  value <- xml2::xml_text(xml2::xml_find_first(doc, xpath))
  if (is.na(value) || !nzchar(value)) NA_character_ else value
}

xml_date <- function(doc, xpath) {
  value <- xml_value(doc, xpath)
  if (is.na(value)) return(NA_character_)
  parsed <- as.Date(value, format = "%d/%m/%Y")
  if (is.na(parsed)) NA_character_ else format(parsed)
}

# ---- Note segmentation ------------------------------------------------------

# Candidate note headings: "1. Contexto operacional", "Nota 3 - Caixa",
# "NOTA 12 – IMOBILIZADO", "4) Estoques". Sub-items (2.1) and table-of-
# contents lines ending in page numbers are excluded.
heading_pattern <- paste0(
  "^\\s*(?:nota(?:\\s+explicativa)?\\s*(?:n[ºo°.]\\s*)?)?",
  "([0-9]{1,2})(?![0-9.,][0-9])(?:\\s*[.)\\-–—:]\\s*|\\s+)",
  "([A-Za-zÀ-ÿ(\"“][^\\n]{2,140})$")

# Fallback for documents numbering notes in parentheses ("(5) CAIXA"). Table
# footnote markers use the same form, so this pattern is only tried when the
# main pattern finds no note set.
heading_pattern_parenthesized <-
  "^\\s*\\(([0-9]{1,2})\\)\\s*[.\\-–—:]?\\s*([A-Za-zÀ-ÿ\"“][^\\n]{2,140})$"

find_heading_candidates <- function(pages, pattern = heading_pattern) {
  out <- list()
  for (page in seq_along(pages)) {
    lines <- strsplit(pages[[page]], "\n", fixed = TRUE)[[1]]
    offsets <- cumsum(c(0, nchar(lines) + 1))[seq_along(lines)]
    hit <- regmatches(lines, regexec(pattern, lines, perl = TRUE, ignore.case = TRUE))
    for (i in which(lengths(hit) == 3)) {
      title <- trimws(gsub("\\s{2,}.*$", "", trimws(hit[[i]][3])))
      # Table-of-contents lines end with a page number after dot leaders or
      # a run of spaces.
      if (nchar(title) < 3 || grepl("([.…]{3,}|\\s{2,})\\s*[0-9]{1,3}\\s*$", hit[[i]][3])) next
      if (grepl("^[0-9]", title) || grepl("[,;]$", title)) next
      if (grepl("[a-z]", substr(title, 1, 1)) && !grepl("^nota", lines[i], ignore.case = TRUE)) next
      out[[length(out) + 1]] <- data.frame(page = page, line = i,
        offset = offsets[i], number = as.integer(hit[[i]][2]), title = title,
        stringsAsFactors = FALSE)
    }
  }
  if (length(out) == 0) {
    return(data.frame(page = integer(), line = integer(), offset = numeric(),
                      number = integer(), title = character()))
  }
  do.call(rbind, out)
}

# Select numbered note sequences 1, 2, 3, ... (gaps of up to two numbers
# allowed). A PDF may hold several note sets (individual and consolidated,
# BR GAAP and IFRS): a heading "1" followed shortly by "2" restarts the
# numbering and closes the previous set. A table of contents also forms a
# sequence but spans little text, so sets need at least `min_notes` headings
# each followed by 300 or more characters. Positions are 0-based offsets into
# the pages joined with "\n".
select_note_sets <- function(candidates, pages, min_notes = 5L) {
  empty <- candidates[0, , drop = FALSE]
  empty$position <- numeric(); empty$note_set <- integer()
  if (nrow(candidates) == 0) return(empty)
  page_offsets <- cumsum(c(0, nchar(pages) + 1))[seq_along(pages)]
  candidates$position <- page_offsets[candidates$page] + candidates$offset
  candidates <- candidates[order(candidates$position), , drop = FALSE]
  total <- sum(nchar(pages)) + length(pages)
  n <- nrow(candidates)
  restarts <- which(vapply(seq_len(n), function(k) {
    candidates$number[k] == 1L &&
      any(candidates$number[seq(k + 1L, length.out = min(10L, n - k))] == 2L)
  }, logical(1)))
  if (length(restarts) == 0) return(empty)
  # A jump in numbering (e.g. 7 -> 10, often a table row) is skipped when the
  # expected number appears later, before the jumped number's successor.
  exact_follows <- function(k, expected, jumped, limit) {
    later <- seq(k + 1L, length.out = n - k)
    later <- later[candidates$position[later] < limit]
    exact <- later[candidates$number[later] == expected]
    if (length(exact) == 0) return(FALSE)
    successor <- later[candidates$number[later] == jumped + 1L]
    length(successor) == 0 || min(exact) < min(successor)
  }
  build_set <- function(s, limit) {
    chosen <- s
    expected <- 2L
    for (k in seq(s + 1L, length.out = n - s)) {
      if (candidates$position[k] >= limit) break
      if (candidates$number[k] > expected &&
          exact_follows(k, expected, candidates$number[k], limit)) next
      if (candidates$number[k] >= expected && candidates$number[k] <= expected + 2L) {
        chosen <- c(chosen, k)
        expected <- candidates$number[k] + 1L
      }
    }
    chosen <- prefer_consistent_style(candidates, chosen, limit)
    end <- min(limit, total)
    spans <- diff(c(candidates$position[chosen], end))
    # A numbered list inside a note (often mixed case) can chain into the real
    # headings (often upper case); a set whose first heading breaks the
    # dominant style is not a real restart.
    upper <- candidates$title[chosen] == toupper(candidates$title[chosen])
    style_ok <- length(chosen) < 5 || abs(mean(upper) - 0.5) < 0.2 ||
      upper[1] == (mean(upper) > 0.5)
    list(chosen = chosen, end = end,
         valid = sum(spans >= 300) >= min_notes && style_ok)
  }
  # A numbered list inside a note ("1 ... 2 ...") looks like a restart and cuts
  # the surrounding set short. Scan left to right: while the set from the
  # current restart is invalid, treat the next restart as an inner list and
  # extend the limit. A restart that never yields a valid set is dropped.
  built <- list()
  i <- 1L
  while (i <= length(restarts)) {
    j <- i + 1L
    repeat {
      limit <- if (j <= length(restarts)) candidates$position[restarts[j]] else Inf
      b <- build_set(restarts[i], limit)
      if (b$valid || j > length(restarts)) break
      j <- j + 1L
    }
    if (b$valid) {
      built[[length(built) + 1L]] <- b
      i <- j
    } else {
      i <- i + 1L
    }
  }
  sets <- list()
  for (b in built) {
    set <- candidates[b$chosen, , drop = FALSE]
    set$end_position <- c(set$position[-1], b$end)
    sets[[length(sets) + 1L]] <- set
  }
  if (length(sets) == 0) return(empty)
  for (i in seq_along(sets)) sets[[i]]$note_set <- i
  do.call(rbind, sets)
}

# When most titles in a set share a style (e.g. upper case), replace an
# off-style heading by an on-style candidate with the same number located
# before the next chosen heading.
prefer_consistent_style <- function(candidates, chosen, limit) {
  is_upper <- function(x) x == toupper(x)
  styles <- is_upper(candidates$title[chosen])
  if (length(chosen) < 5 || mean(styles) < 0.7) return(chosen)
  for (j in which(!styles)) {
    upper_bound <- if (j < length(chosen)) candidates$position[chosen[j + 1L]] else limit
    # Never reach before the set's own first heading.
    lower_bound <- if (j > 1) candidates$position[chosen[j - 1L]] else candidates$position[chosen[1]] - 1
    alternatives <- which(candidates$number == candidates$number[chosen[j]] &
                            candidates$position > lower_bound &
                            candidates$position < upper_bound &
                            is_upper(candidates$title))
    if (length(alternatives) > 0) chosen[j] <- alternatives[1]
  }
  sort(unique(chosen))
}

detect_unit_scale <- function(text) {
  t <- tolower(text)
  if (grepl("em milh(õ|o)es de reais|r\\$ ?milh(õ|o)es", t)) return("millions")
  if (grepl("em milhares de reais|r\\$ ?mil\\b|em milhares de r\\$", t)) return("thousands")
  if (grepl("em reais\\b", t)) return("units")
  NA_character_
}

# Segment one notes PDF (raw bytes) into notes. Returns a list with status
# and a data frame of notes with page ranges and exact original text.
segment_notes_pdf <- function(pdf_bytes) {
  pdf_file <- tempfile(fileext = ".pdf")
  on.exit(unlink(pdf_file), add = TRUE)
  writeBin(pdf_bytes, pdf_file)
  pages <- tryCatch(suppressMessages(pdftools::pdf_text(pdf_file)), error = function(e) e)
  if (inherits(pages, "error")) {
    return(list(status = "pdf_unreadable", error = conditionMessage(pages),
                page_count = NA_integer_, notes = NULL))
  }
  if (sum(nchar(gsub("\\s", "", pages))) < 200 * max(1, length(pages) / 10)) {
    return(list(status = "image_only", error = "no usable text layer; OCR not approved",
                page_count = length(pages), notes = NULL))
  }
  candidates <- find_heading_candidates(pages)
  sets <- select_note_sets(candidates, pages)
  if (nrow(sets) == 0) {
    candidates <- find_heading_candidates(pages, heading_pattern_parenthesized)
    sets <- select_note_sets(candidates, pages)
  }
  if (nrow(sets) == 0) {
    return(list(status = "no_note_structure",
                error = "no numbered note sequence with at least five notes",
                page_count = length(pages), notes = NULL))
  }
  full_text <- paste(pages, collapse = "\n")
  page_starts <- cumsum(c(1, nchar(pages) + 1))[seq_along(pages)]
  starts <- sets$position + 1
  ends <- sets$end_position
  page_of <- function(pos) max(which(page_starts <= pos))
  notes <- data.frame(
    note_set = sets$note_set,
    note_number = as.character(sets$number),
    note_title = sets$title,
    note_text = substring(full_text, starts, ends),
    source_page_start = vapply(starts, page_of, numeric(1)),
    source_page_end = vapply(pmax(starts, ends), page_of, numeric(1)),
    stringsAsFactors = FALSE)
  # Scale stated in the note, else the document-level statement (often only in
  # page headers or the first pages); the source of the value is recorded.
  note_scale <- vapply(notes$note_text, detect_unit_scale, character(1), USE.NAMES = FALSE)
  document_scale <- detect_unit_scale(paste(pages, collapse = "\n"))
  notes$unit_scale <- ifelse(is.na(note_scale), document_scale, note_scale)
  notes$unit_scale_source <- ifelse(!is.na(note_scale), "note_text",
                                    ifelse(is.na(document_scale), NA_character_, "document_text"))
  gaps <- unlist(lapply(split(sets$number, sets$note_set), function(x) {
    setdiff(seq_len(max(x)), x)
  }))
  complete <- length(gaps) == 0 && all(table(sets$note_set) >= 8)
  list(status = if (complete) "extracted" else "extracted_partial",
       error = if (length(gaps) == 0) "" else
         paste("gaps in note numbering:", paste(gaps, collapse = ",")),
       page_count = length(pages), notes = notes,
       confidence = if (complete) "high" else if (nrow(sets) >= 5) "medium" else "low")
}

# ---- Report-level extraction -----------------------------------------------

# Extract one package: returns list(report = 1-row data frame,
# notes = data frame). `report` holds the catalog/manifest fields.
extract_package_notes <- function(package_path, report) {
  read <- tryCatch(read_package_attachments(package_path), error = function(e) e)
  base <- data.frame(
    report_id = report$report_id, source_document_id = report$source_document_id,
    report_type = report$report_type, cvm_code = report$cvm_code,
    company_cnpj = report$company_cnpj, company_name = report$company_name,
    reporting_period_start = NA_character_,
    reporting_period_end = report$reporting_period_end,
    filing_date = report$filing_date, publication_date = NA_character_,
    document_version = as.integer(report$document_version),
    source_url = report$source_url, package_sha256 = report$package_sha256,
    package_layout = NA_character_, notes_file_name = NA_character_,
    document_hash = NA_character_, page_count = NA_integer_, note_count = 0L,
    extraction_method = "pdf_text_layer_pdftools", extraction_status = NA_character_,
    extraction_error = "", confidence = NA_character_, stringsAsFactors = FALSE)
  if (inherits(read, "error")) {
    base$extraction_status <- "package_unreadable"
    base$extraction_error <- conditionMessage(read)
    return(list(report = base, notes = NULL))
  }
  base$package_layout <- read$layout
  if (!is.null(read$metadata$reporting_period_start)) {
    base$reporting_period_start <- read$metadata$reporting_period_start
  }
  notes_att <- read$attachments[read$attachments$group_code %in% notes_group_code, , drop = FALSE]
  if (nrow(notes_att) == 0) {
    base$extraction_status <- "notes_not_attached"
    base$extraction_error <- sprintf("no group %s attachment among %d", notes_group_code,
                                     nrow(read$attachments))
    return(list(report = base, notes = NULL))
  }
  bytes <- notes_att$bytes[[1]]
  base$notes_file_name <- notes_att$file_name[1]
  base$document_hash <- digest_sha256(bytes)
  if (nrow(notes_att) > 1) base$extraction_error <- "several notes attachments; first used"
  segmented <- segment_notes_pdf(bytes)
  base$page_count <- segmented$page_count
  base$extraction_status <- segmented$status
  base$extraction_error <- paste0(base$extraction_error, segmented$error)
  if (is.null(segmented$notes)) return(list(report = base, notes = NULL))
  base$confidence <- segmented$confidence
  base$note_count <- nrow(segmented$notes)
  notes <- segmented$notes
  notes$note_id <- sprintf("%s:s%d:n%s:%s", report$report_id, notes$note_set, notes$note_number,
                           substr(vapply(notes$note_text, digest_sha256_text, character(1)), 1, 12))
  notes$report_id <- report$report_id
  notes$note_sequence <- seq_len(nrow(notes))
  notes$document_hash <- base$document_hash
  notes$currency <- ifelse(is.na(notes$unit_scale), NA_character_, "BRL")
  notes$extraction_method <- base$extraction_method
  notes$extraction_status <- segmented$status
  notes$confidence <- segmented$confidence
  notes$language <- "pt"
  list(report = base, notes = notes[, c("note_id", "report_id", "note_sequence", "note_set", "note_number",
    "note_title", "note_text", "source_page_start", "source_page_end", "document_hash",
    "currency", "unit_scale", "unit_scale_source", "language", "extraction_method", "extraction_status",
    "confidence")])
}

digest_sha256 <- function(bytes) {
  file <- tempfile()
  on.exit(unlink(file))
  writeBin(bytes, file)
  as.character(tools::sha256sum(file))
}

digest_sha256_text <- function(text) digest_sha256(charToRaw(enc2utf8(text)))
