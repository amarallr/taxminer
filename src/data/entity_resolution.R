# Entity resolution for registered entities (funds and administrators):
# identity, denomination and text are kept apart.
#
#   identity      entity_id from the canonical CNPJ (src/data/consolidate_fund_reports.R
#                 normalize_cnpj: check digits, numeric and alphanumeric CNPJ)
#   denomination  name_id: one per group of textually equivalent names of an entity
#   text          original_name exactly as published (never changed)
#
# Equivalence is deterministic and comes only from the versioned dictionary
# config/entity_name_rules.csv. Similar but not equivalent names stay apart
# and go to the review table. No LLM takes part.
#
# Catalogs (processed/master/ under the fund root, docs/entity_resolution.md):
#   entities, entity_names, name_history, name_review, name_collisions, quality
#
# Requires src/common/{signatures,safe_io,parquet_io}.R,
# src/data/consolidate_fund_reports.R and src/intelligence/search_fund_reports.R
# (normalize_search_text, load_fund_directory).

entity_rule_columns <- c("rule_id", "pattern", "replacement", "rule_type", "context", "rule_version",
                         "validation_status", "rationale")
entity_types <- c("fund", "administrator")
fund_type_acronyms <- c("FII", "FIDC", "FIP", "FIAGRO")

# --- CNPJ --------------------------------------------------------------------

# Letters and digits only, upper case; NA stays NA.
cnpj_digits <- function(x) {
  out <- toupper(gsub("[^0-9A-Za-z]", "", x))
  out[is.na(x)] <- NA_character_
  out
}

# 00.000.000/0000-00 for valid CNPJs (numeric or alphanumeric); anything else
# is returned as published, so an invalid value is never disguised.
format_cnpj <- function(x) {
  canon <- normalize_cnpj(x)
  out <- ifelse(is.na(x), NA_character_, trimws(x))
  ok <- !is.na(canon)
  out[ok] <- sprintf("%s.%s.%s/%s-%s", substr(canon[ok], 1, 2), substr(canon[ok], 3, 5),
                     substr(canon[ok], 6, 8), substr(canon[ok], 9, 12), substr(canon[ok], 13, 14))
  out
}

cnpj_status <- function(x) {
  ifelse(is.na(x) | !nzchar(trimws(ifelse(is.na(x), "", x))), "missing",
         ifelse(is.na(normalize_cnpj(x)), "invalid_check_digits", "valid_check_digits"))
}

# Entity identity: the canonical CNPJ when valid; otherwise the published
# characters (an invalid CNPJ is its own entity, flagged, never guessed);
# without any CNPJ, the folded name (flagged as a weak key).
entity_key <- function(type, cnpj, name = NA_character_) {
  canon <- normalize_cnpj(cnpj)
  raw <- cnpj_digits(cnpj)
  folded <- fold_entity_name(name)
  out <- ifelse(!is.na(canon), paste0(type, ":", canon),
                ifelse(!is.na(raw) & nchar(raw) >= 11L, paste0(type, ":raw:", raw),
                       ifelse(nzchar(folded), paste0(type, ":name:", folded), NA_character_)))
  unname(out)
}

# --- Names -------------------------------------------------------------------

load_entity_rules <- function(path = file.path("config", "entity_name_rules.csv")) {
  rules <- utils::read.csv(path, colClasses = "character", na.strings = character(), encoding = "UTF-8",
                           check.names = FALSE)
  missing <- setdiff(entity_rule_columns, names(rules))
  if (length(missing)) stop("entity_name_rules.csv lacks columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(rules$rule_id)) stop("entity_name_rules.csv has duplicated rule_id.", call. = FALSE)
  bad <- rules$rule_type != "structural" & (!nzchar(rules$pattern) | !nzchar(rules$replacement))
  if (any(bad)) stop("rules without pattern or replacement: ", paste(rules$rule_id[bad], collapse = ", "), call. = FALSE)
  if (!all(rules$context %in% c("all", entity_types))) stop("unknown rule context.", call. = FALSE)
  rules[, entity_rule_columns]
}

# Version of the dictionary: hash of its active rules (any change is a new version).
entity_rules_version <- function(rules) {
  substr(compute_signature_hash(rules[rules$validation_status == "active", entity_rule_columns]), 1, 12)
}

rule_active <- function(rules, id) any(rules$rule_id == id & rules$validation_status == "active")

# Comparison form (struct_fold, struct_acronym_join): upper case, no accents
# or combining marks, punctuation as space, spelled-out acronyms joined.
fold_entity_name <- function(x, rules = NULL) {
  x <- normalize_search_text(x)
  x <- gsub("[̀-ͯ]", "", x, perl = TRUE)
  x <- gsub("[^0-9A-Z]+", " ", x, perl = TRUE)
  x <- gsub("\\s+", " ", trimws(x))
  if (is.null(rules) || rule_active(rules, "struct_acronym_join")) {
    # Runs of two or more one-letter words: "S A" -> "SA", "C C V M" -> "CCVM".
    x <- vapply(strsplit(x, " ", fixed = TRUE), function(w) {
      if (length(w) < 2L) return(paste(w, collapse = " "))
      single <- nchar(w) == 1L & grepl("[A-Z]", w)
      run <- cumsum(c(TRUE, !(single[-1] & single[-length(single)])))
      paste(vapply(split(w, run), function(p) if (length(p) > 1L) paste(p, collapse = "") else p,
                   character(1)), collapse = " ")
    }, character(1))
  }
  x[is.na(x)] <- ""
  unname(x)
}

# Normalized denomination of each name for an entity type: dictionary rules
# applied to the folded text, longest pattern first. Returns the normalized
# name, the comparison key and the rules applied.
normalize_entity_name <- function(x, type, rules) {
  folded <- fold_entity_name(x, rules)
  use <- rules[rules$validation_status == "active" & rules$rule_type != "structural" &
                 rules$context %in% c("all", type), , drop = FALSE]
  use <- use[order(-nchar(use$pattern), use$rule_id), , drop = FALSE]
  out <- folded
  applied <- rep("", length(out))
  for (k in seq_len(nrow(use))) {
    re <- paste0("(^| )", use$pattern[k], "(?= |$)")
    hit <- grepl(re, out, perl = TRUE)
    if (!any(hit)) next
    out[hit] <- gsub(re, paste0("\\1", use$replacement[k]), out[hit], perl = TRUE)
    applied[hit] <- paste0(applied[hit], ifelse(nzchar(applied[hit]), ";", ""), use$rule_id[k])
  }
  out <- gsub("\\s+", " ", trimws(out))
  tokens <- strsplit(out, " ", fixed = TRUE)
  key <- vapply(tokens, function(w) {
    if (type == "fund" && rule_active(rules, "struct_redundant_type_acronym")) {
      w <- w[!(w %in% fund_type_acronyms & duplicated(w))]
    }
    if (rule_active(rules, "struct_token_order")) w <- sort(w, method = "radix")
    paste(w, collapse = " ")
  }, character(1))
  data.frame(folded = folded, normalized = out, key = unname(key), rules_applied = applied,
             stringsAsFactors = FALSE)
}

# Deterministic short id (two FNV-1a 32-bit hashes; exact in doubles).
stable_id <- function(x) {
  fnv <- function(s, h) {
    for (b in as.integer(charToRaw(enc2utf8(s)))) {
      lo <- h %% 256
      h <- h - lo + bitwXor(as.integer(lo), b)
      h <- ((h %% 256) * 16777216 + h * 403) %% 4294967296
    }
    sprintf("%04x%04x", as.integer(h %/% 65536), as.integer(h %% 65536))
  }
  unname(vapply(x, function(s) paste0(fnv(s, 2166136261), fnv(s, 3735928559)), character(1)))
}

# --- Observations ------------------------------------------------------------

# One observation per entity, published name, CNPJ value and source family,
# from the fund directory (which aggregates the consolidated tables and cites
# the latest report). Administrator names equal to the fund name are a known
# CVM data error (FIAGRO): they are left out and counted.
entity_observations <- function(directory) {
  d <- directory
  fund <- data.frame(entity_type = "fund", cnpj_original = d$fund_cnpj_original, name = d$fund_name,
                     source = d$family, first_period = d$first_period, last_period = d$last_period,
                     period_count = d$period_count, source_file = d$source_file,
                     source_line = d$source_line, stringsAsFactors = FALSE)
  same <- !is.na(d$administrator_name) &
    normalize_search_text(d$administrator_name) == normalize_search_text(d$fund_name)
  admin <- data.frame(entity_type = "administrator", cnpj_original = d$administrator_cnpj,
                      name = ifelse(same, NA_character_, d$administrator_name),
                      source = d$family, first_period = d$first_period, last_period = d$last_period,
                      period_count = d$period_count, source_file = d$source_file,
                      source_line = d$source_line, stringsAsFactors = FALSE)
  admin <- admin[!(is.na(admin$cnpj_original) & is.na(admin$name)), , drop = FALSE]
  obs <- rbind(fund, admin)
  obs$name <- ifelse(is.na(obs$name), NA_character_, gsub("\\s+", " ", trimws(obs$name)))
  structure(obs, admin_name_is_fund = sum(same))
}

# --- Catalogs ----------------------------------------------------------------

safe_min <- function(v) { v <- v[!is.na(v)]; if (length(v)) min(v) else NA_character_ }
safe_max <- function(v) { v <- v[!is.na(v)]; if (length(v)) max(v) else NA_character_ }

build_entity_master <- function(directory, rules, built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")) {
  obs <- entity_observations(directory)
  version <- entity_rules_version(rules)
  obs$entity_id <- entity_key(obs$entity_type, obs$cnpj_original, obs$name)
  unkeyed <- sum(is.na(obs$entity_id))
  obs <- obs[!is.na(obs$entity_id), , drop = FALSE]
  named <- !is.na(obs$name) & nzchar(obs$name)

  # Normalization per type (the dictionary context decides which rules apply).
  obs$normalized <- NA_character_; obs$key <- NA_character_; obs$rules_applied <- ""
  for (type in entity_types) {
    i <- which(obs$entity_type == type & named)
    if (!length(i)) next
    u <- unique(obs$name[i])
    n <- normalize_entity_name(u, type, rules)
    m <- match(obs$name[i], u)
    obs$normalized[i] <- n$normalized[m]; obs$key[i] <- n$key[m]; obs$rules_applied[i] <- n$rules_applied[m]
  }
  obs$name_id <- ifelse(named, paste0(obs$entity_id, "#", stable_id(paste(obs$entity_id, obs$key))), NA_character_)

  # Name history: one row per entity, denomination, published text and source.
  hkey <- paste(obs$entity_id, obs$name_id, obs$name, obs$source, sep = "\r")
  latest <- order(hkey, obs$last_period, obs$source_file, obs$source_line, decreasing = TRUE,
                  na.last = TRUE, method = "radix")
  latest <- latest[!duplicated(hkey[latest])]
  history <- data.frame(
    entity_id = obs$entity_id[latest], name_id = obs$name_id[latest], original_name = obs$name[latest],
    source = obs$source[latest],
    first_observed_period = as.character(tapply(obs$first_period, hkey, safe_min)[hkey[latest]]),
    last_observed_period = as.character(tapply(obs$last_period, hkey, safe_max)[hkey[latest]]),
    observed_periods = as.integer(tapply(obs$period_count, hkey, sum, na.rm = TRUE)[hkey[latest]]),
    valid_from = NA_character_, valid_to = NA_character_,
    source_file = obs$source_file[latest], source_line = as.integer(obs$source_line[latest]),
    stringsAsFactors = FALSE)
  history <- history[!is.na(history$name_id), , drop = FALSE]
  history <- history[order(history$entity_id, history$first_observed_period, history$original_name,
                           history$source, method = "radix"), ]

  # Denominations: groups of equivalent names of an entity.
  h <- history
  okey <- paste(obs$entity_id, obs$name, sep = "\r")
  h$normalized <- obs$normalized[match(paste(h$entity_id, h$original_name, sep = "\r"), okey)]
  h$key <- obs$key[match(h$name_id, obs$name_id)]
  # Display: the shortest published form (equivalent by construction), then the latest.
  pick <- order(h$name_id, nchar(h$original_name), -rank(h$last_observed_period, ties.method = "first"),
                h$original_name, method = "radix")
  pick <- pick[!duplicated(h$name_id[pick])]
  rules_by_name <- tapply(obs$rules_applied[named], obs$name_id[named], function(v) {
    v <- unique(unlist(strsplit(v[nzchar(v)], ";", fixed = TRUE)))
    paste(sort(v), collapse = ";")
  })
  variants <- tapply(h$original_name, h$name_id, function(v) length(unique(v)))
  names_cat <- data.frame(
    name_id = h$name_id[pick], entity_id = h$entity_id[pick],
    entity_type = sub(":.*$", "", h$entity_id[pick]),
    cnpj_canonical = NA_character_,
    normalized_name = h$normalized[pick], comparison_key = h$key[pick],
    display_name = h$original_name[pick],
    normalization_criteria = unname(rules_by_name[h$name_id[pick]]),
    rule_version = version,
    variant_count = as.integer(variants[h$name_id[pick]]),
    first_observed_period = as.character(tapply(h$first_observed_period, h$name_id, safe_min)[h$name_id[pick]]),
    last_observed_period = as.character(tapply(h$last_observed_period, h$name_id, safe_max)[h$name_id[pick]]),
    stringsAsFactors = FALSE)
  names_cat$normalization_criteria[is.na(names_cat$normalization_criteria)] <- ""
  names_cat$validation_status <- ifelse(names_cat$variant_count > 1L, "rule_equivalence", "single_form")

  # Entities: identity only; the display name is the latest denomination.
  ent_ids <- sort(unique(obs$entity_id), method = "radix")
  first_cnpj <- obs$cnpj_original[match(ent_ids, obs$entity_id)]
  canon <- normalize_cnpj(first_cnpj)
  latest_name <- names_cat[order(names_cat$entity_id, names_cat$last_observed_period, names_cat$variant_count,
                                 decreasing = c(FALSE, TRUE, TRUE), method = "radix"), ]
  latest_name <- latest_name[!duplicated(latest_name$entity_id), ]
  sources <- tapply(obs$source, obs$entity_id, function(v) paste(sort(unique(v)), collapse = ";"))
  entities <- data.frame(
    entity_id = ent_ids, entity_type = sub(":.*$", "", ent_ids),
    cnpj_canonical = canon, cnpj_formatted = format_cnpj(first_cnpj),
    cnpj_original = first_cnpj, registration_status = cnpj_status(first_cnpj),
    key_basis = ifelse(!is.na(canon), "cnpj", ifelse(grepl(":raw:", ent_ids, fixed = TRUE), "invalid_cnpj", "name_only")),
    display_name = latest_name$display_name[match(ent_ids, latest_name$entity_id)],
    current_name_id = latest_name$name_id[match(ent_ids, latest_name$entity_id)],
    name_count = as.integer(table(factor(names_cat$entity_id, levels = ent_ids))),
    reference_source = paste0("CVM informes: ", unname(sources[ent_ids])),
    first_observed_period = as.character(tapply(obs$first_period, obs$entity_id, safe_min)[ent_ids]),
    last_observed_period = as.character(tapply(obs$last_period, obs$entity_id, safe_max)[ent_ids]),
    updated_at = built_at, stringsAsFactors = FALSE)
  names_cat$cnpj_canonical <- entities$cnpj_canonical[match(names_cat$entity_id, entities$entity_id)]
  names_cat <- names_cat[order(names_cat$entity_id, names_cat$first_observed_period, names_cat$name_id,
                               method = "radix"), ]

  review <- entity_name_review(names_cat)
  names_cat$needs_review <- names_cat$name_id %in% c(review$name_id_a, review$name_id_b)
  collisions <- entity_name_collisions(names_cat)
  rownames(entities) <- rownames(names_cat) <- rownames(history) <- NULL
  master <- list(entities = entities, entity_names = names_cat, name_history = history,
                 name_review = review, name_collisions = collisions, rule_version = version)
  master$quality <- entity_quality_report(master, obs, unkeyed, attr(obs, "admin_name_is_fund"))
  master
}

# Pairs of different denominations of one entity that look alike but are not
# equivalent under the dictionary: kept apart, listed for human review.
entity_name_review <- function(names_cat, max_distance = 0.15) {
  multi <- names(which(table(names_cat$entity_id) > 1L))
  rows <- lapply(multi, function(e) {
    n <- names_cat[names_cat$entity_id == e, , drop = FALSE]
    pairs <- utils::combn(nrow(n), 2L)
    out <- lapply(seq_len(ncol(pairs)), function(j) {
      a <- n[pairs[1, j], ]; b <- n[pairs[2, j], ]
      ta <- strsplit(a$comparison_key, " ", fixed = TRUE)[[1]]
      tb <- strsplit(b$comparison_key, " ", fixed = TRUE)[[1]]
      d <- as.numeric(utils::adist(a$normalized_name, b$normalized_name)) /
        max(nchar(a$normalized_name), nchar(b$normalized_name), 1)
      reason <- if (all(ta %in% tb) || all(tb %in% ta)) "token_subset"
                else if (d <= max_distance) "near_spelling" else NA_character_
      if (is.na(reason)) return(NULL)
      data.frame(entity_id = e, name_id_a = a$name_id, name_a = a$display_name,
                 name_id_b = b$name_id, name_b = b$display_name, reason = reason,
                 distance = round(d, 3), status = "pending_review", stringsAsFactors = FALSE)
    })
    do.call(rbind, out)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) out <- data.frame(entity_id = character(), name_id_a = character(), name_a = character(),
                                      name_id_b = character(), name_b = character(), reason = character(),
                                      distance = numeric(), status = character(), stringsAsFactors = FALSE)
  out
}

# Same comparison key under different entities of a type (homonyms): never
# merged, reported.
entity_name_collisions <- function(names_cat) {
  k <- paste(names_cat$entity_type, names_cat$comparison_key)
  n <- tapply(names_cat$entity_id, k, function(v) length(unique(v)))
  hit <- names(n)[n > 1L]
  d <- names_cat[k %in% hit, c("entity_type", "comparison_key", "entity_id", "display_name")]
  d <- d[order(d$entity_type, d$comparison_key, d$entity_id, method = "radix"), ]
  rownames(d) <- NULL
  d
}

entity_quality_report <- function(master, obs, unkeyed, admin_name_is_fund) {
  e <- master$entities; n <- master$entity_names; h <- master$name_history; r <- master$name_review
  per_type <- function(df, type) df[df$entity_type == type, , drop = FALSE]
  metric <- function(name, value, note) data.frame(metric = name, value = as.numeric(value), note = note,
                                                   stringsAsFactors = FALSE)
  raw_names <- tapply(h$original_name, h$entity_id, function(v) length(unique(v)))
  overlap <- vapply(split(h, h$entity_id), function(x) {
    x <- x[!duplicated(x$name_id), ]
    if (nrow(x) < 2L) return(0L)
    o <- outer(x$first_observed_period, x$last_observed_period, "<=") &
      outer(x$last_observed_period, x$first_observed_period, ">=")
    as.integer(sum(o[upper.tri(o)]) > 0L)
  }, integer(1))
  rbind(
    metric("observations", nrow(obs), "entity/name/CNPJ/source rows from the fund directory"),
    metric("observations_without_key", unkeyed, "no CNPJ and no name: left out"),
    metric("administrator_name_is_fund_name", admin_name_is_fund, "administrator name equal to the fund name: name dropped, CNPJ kept"),
    do.call(rbind, lapply(entity_types, function(t) rbind(
      metric(paste0(t, "_entities"), nrow(per_type(e, t)), "distinct identities"),
      metric(paste0(t, "_invalid_cnpj"), sum(per_type(e, t)$key_basis == "invalid_cnpj"), "CNPJ fails check digits: own entity, flagged"),
      metric(paste0(t, "_name_only_key"), sum(per_type(e, t)$key_basis == "name_only"), "no CNPJ: weak key by name"),
      metric(paste0(t, "_with_several_published_names"), sum(raw_names[per_type(e, t)$entity_id] > 1L, na.rm = TRUE), "published texts > 1"),
      metric(paste0(t, "_with_several_denominations"), sum(per_type(e, t)$name_count > 1L), "after equivalence: significantly different names"),
      metric(paste0(t, "_names_merged_by_rules"), sum(per_type(n, t)$variant_count - 1L), "published texts absorbed into an equivalent denomination")))),
    metric("review_token_subset", sum(r$reason == "token_subset"), "one denomination contains the other: pending review"),
    metric("review_near_spelling", sum(r$reason == "near_spelling"), "small spelling distance: pending review"),
    metric("homonym_groups", length(unique(paste(master$name_collisions$entity_type, master$name_collisions$comparison_key))),
           "same denomination under different CNPJs: not merged"),
    metric("names_with_encoding_damage", sum(grepl("�|[A-Za-z]\\?[A-Za-z]", h$original_name)), "replacement character in the published text"),
    metric("entities_with_overlapping_denominations", sum(overlap), "two denominations observed in overlapping periods"),
    metric("fund_entities_in_several_families", sum(grepl(";", per_type(e, "fund")$reference_source)), "same CNPJ reported in more than one family"),
    metric("duplicated_entity_ids", anyDuplicated(e$entity_id) > 0, "must be 0"),
    metric("duplicated_name_ids", anyDuplicated(n$name_id) > 0, "must be 0"),
    metric("history_rows_without_denomination", sum(!h$name_id %in% n$name_id), "must be 0"))
}

# --- Storage -----------------------------------------------------------------

entity_master_paths <- function(root) {
  base <- file.path(fund_processed_paths(root)$base, "master")
  tables <- c("entities", "entity_names", "name_history", "name_review", "name_collisions", "quality")
  c(list(base = base, index = file.path(base, "entity_master_index.rds")),
    stats::setNames(as.list(file.path(base, paste0(tables, ".parquet"))), tables))
}

entity_master_signature <- function(directory_signature, rules) {
  compute_signature_hash(list(
    directory = directory_signature, rules = rules,
    functions = transformation_signature(list(
      cnpj_digits = cnpj_digits, format_cnpj = format_cnpj, cnpj_status = cnpj_status,
      entity_key = entity_key, fold_entity_name = fold_entity_name,
      normalize_entity_name = normalize_entity_name, stable_id = stable_id,
      entity_observations = entity_observations, build_entity_master = build_entity_master,
      entity_name_review = entity_name_review, entity_name_collisions = entity_name_collisions,
      entity_quality_report = entity_quality_report, normalize_cnpj = normalize_cnpj,
      normalize_search_text = normalize_search_text))))
}

# Catalogs cached next to the consolidated tables; rebuilt only when the
# directory, the dictionary or this code change (idempotent).
load_entity_master <- function(root, directory = load_fund_directory(root),
                               rules = load_entity_rules(), rebuild = FALSE) {
  paths <- entity_master_paths(root)
  signature <- entity_master_signature(fund_directory_signature(root), rules)
  cached <- if (file.exists(paths$index)) read_rds_recoverable(paths$index, is.list) else NULL
  tables <- c("entities", "entity_names", "name_history", "name_review", "name_collisions", "quality")
  if (!rebuild && identical(cached$signature, signature) && all(file.exists(unlist(paths[tables])))) {
    master <- lapply(stats::setNames(tables, tables), function(t) as.data.frame(arrow::read_parquet(paths[[t]])))
    master$rule_version <- cached$rule_version
    return(master)
  }
  master <- build_entity_master(directory, rules)
  dir.create(paths$base, recursive = TRUE, showWarnings = FALSE)
  for (t in tables) write_parquet_validated(master[[t]], paths[[t]])
  write_validated_atomic(list(signature = signature, rule_version = master$rule_version,
                              built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
                         paths$index, format = "rds")
  master
}

# --- Queries -----------------------------------------------------------------

# Any selected option (entity_id or name_id) resolves to entity ids, deduplicated.
resolve_entity_ids <- function(values) {
  values <- values[!is.na(values) & nzchar(values)]
  unique(sub("#.*$", "", values))
}

# Canonical (or published) CNPJs of the selected entities: the query value.
entity_cnpjs <- function(master, values) {
  ids <- resolve_entity_ids(values)
  e <- master$entities[master$entities$entity_id %in% ids, , drop = FALSE]
  unique(ifelse(is.na(e$cnpj_canonical), e$cnpj_original, e$cnpj_canonical))
}

# Entities of a type whose CNPJ (with or without mask, prefix) or any name
# (published, normalized, abbreviated, historical) matches the text.
match_entities <- function(master, type, text, rules = NULL) {
  text <- trimws(if (is.null(text)) "" else text)
  if (!nzchar(text)) return(character())
  e <- master$entities[master$entities$entity_type == type, , drop = FALSE]
  hits <- character()
  digits <- cnpj_digits(text)
  if (grepl("^[0-9./ -]+$", text) && nchar(digits) >= 4L) {
    hits <- e$entity_id[startsWith(ifelse(is.na(e$cnpj_canonical), cnpj_digits(e$cnpj_original), e$cnpj_canonical), digits)]
  }
  h <- master$name_history[startsWith(master$name_history$entity_id, paste0(type, ":")), , drop = FALSE]
  n <- master$entity_names[master$entity_names$entity_type == type, , drop = FALSE]
  q <- fold_entity_name(text)
  qn <- if (!is.null(rules)) normalize_entity_name(text, type, rules)$normalized else q
  if (nzchar(q)) {
    hits <- c(hits,
              h$entity_id[grepl(q, fold_entity_name(h$original_name), fixed = TRUE)],
              n$entity_id[grepl(qn, n$normalized_name, fixed = TRUE) | grepl(q, n$normalized_name, fixed = TRUE)])
  }
  unique(hits)
}

# Separate analytical view (not a filter): every denomination of an entity
# with the periods and sources in which it was observed.
entity_name_timeline <- function(master, entity_id) {
  h <- master$name_history[master$name_history$entity_id == entity_id, , drop = FALSE]
  n <- master$entity_names[match(h$name_id, master$entity_names$name_id), ]
  out <- data.frame(name_id = h$name_id, denomination = n$display_name, normalized_name = n$normalized_name,
                    original_name = h$original_name, source = h$source,
                    first_observed_period = h$first_observed_period, last_observed_period = h$last_observed_period,
                    observed_periods = h$observed_periods, needs_review = n$needs_review,
                    source_file = h$source_file, source_line = h$source_line, stringsAsFactors = FALSE)
  out <- out[order(out$first_observed_period, out$source, out$original_name, method = "radix"), ]
  rownames(out) <- NULL
  out
}
