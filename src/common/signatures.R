# Shared signatures (Common P07 stage 02, decision_0023). Base R only.
# Re-implemented from requirements, not copied. source() only defines
# functions: no network, no file access, no side effects.

# Serialization header bytes (format, writer R version, minimum R version)
# depend on the R that wrote them; they are dropped so that signatures depend
# only on content.
serialization_header_bytes <- 14L

sha256_raw <- function(bytes) {
  file <- tempfile("signature_")
  on.exit(unlink(file), add = TRUE)
  writeBin(bytes, file)
  unname(as.character(tools::sha256sum(file)))
}

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::calcular_hash_assinatura (P02-FUN-002)
# SHA-256 of a file (`file = TRUE`) or of an R object. Named lists are ordered
# by name and hashed element by element, so field order does not change the
# signature.
compute_signature_hash <- function(x, file = FALSE) {
  if (file) return(unname(as.character(tools::sha256sum(x))))
  if (is.list(x) && !is.data.frame(x)) {
    if (!is.null(names(x))) x <- x[order(names(x))]
    x <- vapply(x, compute_signature_hash, character(1))
  }
  bytes <- serialize(x, connection = NULL, xdr = TRUE, version = 2)
  sha256_raw(bytes[-seq_len(serialization_header_bytes)])
}

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::assinatura_codigo (P02-FUN-009, P07-RF-004)
# Content signature of an explicit list of files relative to `root` (no
# directory traversal, per AGENTS.md). Stable across commits and history
# rewrites because it depends only on paths and contents.
code_signature <- function(files, root = ".") {
  if (length(files) == 0) stop("code_signature needs an explicit file list.", call. = FALSE)
  paths <- vapply(files, function(f) validate_contained_path(root, f), character(1))
  if (any(!file.exists(paths))) {
    stop("Missing files: ", paste(files[!file.exists(paths)], collapse = ", "), call. = FALSE)
  }
  hashes <- as.list(unname(as.character(tools::sha256sum(paths))))
  names(hashes) <- gsub("\\\\", "/", files)
  compute_signature_hash(hashes)
}

# origin: reference_pipeline@595991b src/utils/p02_utilitarios.R::assinatura_transformacao (P02-FUN-012)
# Signature of the functions that influence a transformation: their formal
# arguments and deparsed bodies. Changing comments elsewhere in a file does not
# change it; changing the logic does.
transformation_signature <- function(functions) {
  if (!is.list(functions) || is.null(names(functions)) ||
      !all(vapply(functions, is.function, logical(1)))) {
    stop("transformation_signature needs a named list of functions.", call. = FALSE)
  }
  compute_signature_hash(lapply(functions, function(f) {
    list(arguments = deparse(formals(f), width.cutoff = 500L),
         body = deparse(body(f), width.cutoff = 500L))
  }))
}
