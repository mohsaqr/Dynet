# prova-verify-helper 1.3.0 (R). Source: prova reporters/verify-expect.R. A package keeps a copy as tests/equivalence/helper-verify.R; do not edit the copy (reporters/verify-vendor.sh refreshes it).
#
# Declared equivalence tests for Prova Verify (the standard: equivalence/STANDARD.md).
# Every comparison of a package with a reference goes through one verb that ASSERTS
# and RECORDS:
#
#   expect_reference(actual, expected, reference, covers, quantity, tolerance)
#   expect_reference(..., defect = "<what is wrong>")   a declared defect: recorded as a disagreement, job stays green
#   expect_known_difference(..., reason, agrees_with)   recorded, does not fail the test
#   expect_defect_error(expr, defect, covers, quantity)   a declared defect that raises an error
#   expect_differs(...)                      a negative control: must differ
#   expect_not_comparable(..., reason)       not defined on this input: recorded, not judged
#   skip_without_reference(package, python)  a recorded skip (an R package or a Python module)
#   reference_fixture(path, redistributable) a stored reference, with provenance
#   reference_data(path, redistributable)    an input data file of the test
#   verify_exports_check()                   verify.json against NAMESPACE
#   verify_tests()                             runs tests/equivalence, writes the capture
#   verify_rerun(file, reference)           one side's values (the re-run in Prova)
#
# Run by testthat alone the verbs only assert. Run by verify_tests() they also record
# every compared number in a capture (format `prova.verify-capture/1`, documented in
# reporters/verify-import-capture.mjs) under the folder PROVA_VERIFY_CAPTURE.
#
# Needs base R, testthat and jsonlite.

#' Version of this helper
#'
#' @return A length-one character vector, the version on the file's first line.
verify_helper_version <- function() "1.3.0"

.vx_kinds <- c("reference", "known_difference", "differs", "not_comparable")
.vx_measures <- c("absolute", "relative", "scaled")
.vx_authorities <- c("open-source", "commercial", "published", "certified", "independent", "internal")
.vx_counted <- setdiff(.vx_authorities, "internal")
.vx_provenance <- c("program", "version", "generated_by", "generated_at", "data")
# S3 methods of these generics return no numbers; verify.json need not list them.
.vx_display_generics <- c("print", "format", "plot", "autoplot", "toString", "str", "knit_print")

#' Whether names are functions as `verify.json` writes them
#'
#' `name()`, or an entry of a verb with a catalogue argument, `name(argument = value)`
#' (`centrality(measures = "onion")`), whose verb is `name()`.
#' @param x A character vector.
#' @return A logical vector.
.vx_is_entry <- function(x) grepl("\\(\\)$", x) | grepl("^[^(]+\\(.+\\)$", x)

#' The verb of an entry: `name()` of `name(argument = value)`; `name()` itself
#'
#' @param x A character vector of names written `name()` or `name(argument = value)`.
#' @return A character vector of the same length.
.vx_verb <- function(x) sub("^([^(]+)\\(.+\\)$", "\\1()", x)

#' The functions of `covers` that `exports.covered` does not list
#'
#' An entry `name(argument = value)` is listed when it is, or when its verb `name()` is.
#' @param covers The declared functions.
#' @param config The parsed `verify.json`.
#' @return A character vector.
.vx_unlisted <- function(covers, config) {
  covered <- as.character(unlist(config$exports$covered))
  covers[!(covers %in% covered | .vx_verb(covers) %in% covered)]
}

#' Fix Python's hash seed for the reference runs of this session
#'
#' A Python reference started from the tests (reticulate, or an interpreter run
#' with system2()) inherits `PYTHONHASHSEED=0`, so that a computation whose
#' result follows the order of a set or a dict is the same run after run. An
#' interpreter started with `-I` or `-E` ignores the variable. A value set by the
#' caller is kept. The variable is restored when the run ends.
#' @param envir The frame whose exit restores the variable.
#' @return The previous value, invisibly (`NA` when it was not set).
.vx_python_hash_seed <- function(envir = parent.frame()) {
  before <- Sys.getenv("PYTHONHASHSEED", unset = NA)
  if (is.na(before)) {
    Sys.setenv(PYTHONHASHSEED = "0")
    do.call(on.exit, list(quote(Sys.unsetenv("PYTHONHASHSEED")), add = TRUE, after = FALSE), envir = envir)
  }
  invisible(before)
}

#' Raise a classed error
#'
#' @param message The message.
#' @param class The condition class; `verify_error` is always added.
#' @return Never returns.
.vx_stop <- function(message, class) {
  stop(errorCondition(message, class = c(class, "verify_error"), call = NULL))
}

#' The recording state of a run started by verify_tests() or verify_rerun()
#'
#' @return An environment, or `NULL` when the tests are run by testthat alone.
.vx_state <- function() getOption("prova.verify.state")

#' The package root, when it can be known
#'
#' @return A path, or `NULL` (a test file run away from its package).
.vx_root <- function() {
  state <- .vx_state()
  if (!is.null(state) && !is.null(state$root)) return(state$root)
  candidates <- c(".", "..", file.path("..", ".."))
  found <- candidates[file.exists(file.path(candidates, "DESCRIPTION"))]
  if (length(found)) normalizePath(found[[1L]]) else NULL
}

#' A path as the capture writes it: from the package root, forward slashes
#'
#' @param path A path, absolute or relative to the working directory.
#' @return A length-one character vector.
.vx_relative <- function(path) {
  full <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- .vx_root()
  if (is.null(root)) return(full)
  root <- normalizePath(root, winslash = "/")
  if (startsWith(full, paste0(root, "/"))) substr(full, nchar(root) + 2L, nchar(full)) else full
}

#' Read `verify.json`
#'
#' Looked for beside the test file (testthat's working directory), then in
#' `tests/equivalence/` of the working directory.
#' @param path The file, or `NULL` to look for it.
#' @return The parsed file as a list, with `path`.
.vx_config <- function(path = NULL) {
  candidates <- c(path, "verify.json", file.path("tests", "equivalence", "verify.json"))
  found <- candidates[file.exists(candidates)]
  if (!length(found)) {
    .vx_stop("verify.json was not found beside the test file or in tests/equivalence/.", "verify_no_config")
  }
  config <- jsonlite::fromJSON(found[[1L]], simplifyVector = FALSE)
  config$path <- found[[1L]]
  config
}

#' The authority of a reference
#'
#' `published: <citation>` is `published` and `independent: <what>` is
#' `independent`; any other reference takes the authority `verify.json` gives it.
#' @param reference The reference's name.
#' @param config The parsed `verify.json`.
#' @param authority An authority given in the test, or `NULL`.
#' @return One of the six authorities.
.vx_authority <- function(reference, config, authority = NULL) {
  found <- authority %||%
    (if (startsWith(reference, "published:")) "published") %||%
    (if (startsWith(reference, "independent:")) "independent") %||%
    config$references[[reference]]$authority
  if (is.null(found)) {
    .vx_stop(sprintf("Reference `%s` is not in the `references` of %s; add it there with its authority.",
                         reference, config$path), "verify_unknown_reference")
  }
  if (!found %in% .vx_authorities) {
    .vx_stop(sprintf("Authority `%s` of reference `%s` is not one of: %s.", found, reference,
                         toString(.vx_authorities)), "verify_bad_authority")
  }
  found
}

# What has been learnt of Python modules in this session: module -> list(available, version).
.vx_python_seen <- new.env(parent = emptyenv())

#' The Python interpreter a reference is run with
#'
#' `RETICULATE_PYTHON` when it names an interpreter, else `python3` or `python`
#' on the PATH.
#' @return A path, or `""` when there is none.
.vx_python <- function() {
  given <- Sys.getenv("RETICULATE_PYTHON")
  if (nzchar(given) && file.exists(given)) return(given)
  found <- Sys.which(c("python3", "python"))
  found <- found[nzchar(found)]
  if (length(found)) unname(found[[1L]]) else ""
}

#' Whether a Python module can be imported, and its version
#'
#' Through reticulate when it is installed (the Python the test itself would
#' use), else by running the interpreter of `.vx_python()` once. The answer is
#' kept for the session.
#' @param module A Python module name.
#' @return A list: `available` (TRUE/FALSE), `version` (a string, `""` when the
#'   module states none), `python` (the interpreter asked, or `"reticulate"`).
.vx_python_module <- function(module) {
  stopifnot("`module` must be one Python module name" = is.character(module) && length(module) == 1L &&
              grepl("^[A-Za-z_][A-Za-z0-9_.]*$", module))
  if (!is.null(.vx_python_seen[[module]])) return(.vx_python_seen[[module]])
  quoted <- as.character(jsonlite::toJSON(module, auto_unbox = TRUE))
  found <- if (requireNamespace("reticulate", quietly = TRUE)) {
    available <- isTRUE(reticulate::py_module_available(module))
    version <- if (available) {
      reticulate::py_eval(sprintf("str(getattr(__import__('importlib').import_module(%s), '__version__', ''))", quoted))
    } else ""
    list(available = available, version = as.character(version), python = "reticulate")
  } else {
    python <- .vx_python()
    if (!nzchar(python)) {
      list(available = FALSE, version = "", python = "")
    } else {
      code <- paste(c(
        "import importlib, importlib.util, json",
        sprintf("name = %s", quoted),
        "try:",
        "    found = importlib.util.find_spec(name) is not None",
        "except (ImportError, ValueError):",
        "    found = False",
        "version = ''",
        "if found:",
        "    try:",
        "        version = str(getattr(importlib.import_module(name), '__version__', ''))",
        "    except ImportError:",
        "        found = False",
        "print(json.dumps({'available': found, 'version': version}))"), collapse = "\n")
      # system2() warns "had status 1" for an interpreter that fails; the status is read just below instead
      said <- suppressWarnings(system2(python, c("-c", shQuote(code)), stdout = TRUE, stderr = FALSE))
      answer <- if (length(said) && is.null(attr(said, "status"))) jsonlite::fromJSON(said[[length(said)]]) else list(available = FALSE, version = "")
      list(available = isTRUE(answer$available), version = as.character(answer$version %||% ""), python = python)
    }
  }
  assign(module, found, envir = .vx_python_seen)
  found
}

#' The installed version of a reference
#'
#' An R package's version; for a Python reference (`references$<name>$python`
#' in `verify.json` names its module, or the module was checked by
#' skip_without_reference(python = ) in this session) the module's version.
#' @param reference The reference's name.
#' @param config The parsed `verify.json` (`references$<name>$package` names the
#'   package when the reference's name is not the package's; `python` names a
#'   Python module; `version` states it for a program).
#' @return A version string, or `NULL`.
.vx_version <- function(reference, config) {
  entry <- config$references[[reference]]
  if (!is.null(entry$version)) return(as.character(entry$version))
  if (!is.null(entry$python)) {
    found <- .vx_python_module(entry$python)
    return(if (nzchar(found$version)) found$version)
  }
  package <- entry$package %||% reference
  if (grepl("^[A-Za-z][A-Za-z0-9.]*$", package) && nzchar(system.file(package = package))) {
    return(as.character(utils::packageVersion(package)))
  }
  checked <- .vx_python_seen[[reference]]
  if (!is.null(checked) && nzchar(checked$version)) checked$version
}

#' The name of the test_that() block a verb was called in
#'
#' @return The test's description. Raises `verify_outside_test` for a verb
#'   called outside any test_that().
.vx_test_name <- function() {
  inside <- vapply(seq_len(sys.nframe()), \(i) identical(sys.function(i), testthat::test_that), logical(1))
  if (!any(inside)) {
    .vx_stop("A declared comparison must be made inside test_that(), so that it belongs to a test.", "verify_outside_test")
  }
  # the innermost block: a test may itself be run from inside another test
  as.character(get("desc", envir = sys.frame(max(which(inside)))))[[1L]]
}

#' Flatten a value to keyed cells
#'
#' A number is one cell with an empty key. A vector's keys are its names (or
#' `key`, or `[i]`). A matrix's keys are `"<row>, <column>"` from its dimnames (or
#' `[i]`, `[j]`). A data frame has one cell per row and column of `columns`, keyed
#' `"<column>: <key columns joined by ', '>"`.
#' @param x A number, vector, matrix or data frame.
#' @param key For a data frame the key column(s); else explicit keys, or `NULL`.
#' @param columns For a data frame, the columns to flatten.
#' @param what `"actual"` or `"expected"`, for messages.
#' @return A data frame `key`, `number`, `text`, `numeric`, with attribute `named`
#'   (`FALSE` when the keys are positions).
.vx_flatten <- function(x, key = NULL, columns = NULL, what = "actual") {
  cells <- function(keys, values, named) {
    values <- if (is.factor(values)) as.character(values) else values
    is_number <- is.numeric(values)
    if (!is_number && !is.character(values) && !is.logical(values)) {
      .vx_stop(sprintf("`%s` holds values of type %s; compare numbers, text or TRUE/FALSE.", what, typeof(values)),
                   "verify_bad_input")
    }
    count <- length(values)
    structure(data.frame(key = as.character(keys), number = if (is_number) as.numeric(values) else rep(NA_real_, count),
                         text = if (is_number) rep(NA_character_, count) else as.character(values),
                         numeric = rep(is_number, count), stringsAsFactors = FALSE), named = named)
  }
  if (is.data.frame(x)) {
    if (is.null(key) || !all(key %in% names(x))) {
      .vx_stop(sprintf("`%s` is a data frame: `key` must name its key column(s); it has %s.", what, toString(names(x))),
                   "verify_bad_input")
    }
    columns <- columns %||% setdiff(names(x), key)
    absent <- setdiff(columns, names(x))
    if (length(absent)) {
      .vx_stop(sprintf("`%s` has no column %s.", what, toString(absent)), "verify_bad_input")
    }
    row_key <- do.call(paste, c(lapply(key, \(column) as.character(x[[column]])), sep = ", "))
    if (anyDuplicated(row_key)) {
      .vx_stop(sprintf("`%s` has duplicate keys (%s); `key` must identify a row.", what,
                           toString(utils::head(unique(row_key[duplicated(row_key)]), 3L))), "verify_bad_input")
    }
    parts <- lapply(columns, \(column) cells(paste0(column, ": ", row_key), x[[column]], TRUE))
    return(structure(do.call(rbind, parts), named = TRUE))
  }
  if (is.list(x)) {
    .vx_stop(sprintf("`%s` is a list; pass a number, a vector, a matrix or a data frame.", what), "verify_bad_input")
  }
  shape <- dim(x)
  if (length(shape) > 2L) {
    .vx_stop(sprintf("`%s` is an array of %d dimensions; pass a matrix or a data frame.", what, length(shape)),
                 "verify_bad_input")
  }
  if (!is.null(key)) {
    if (length(key) != length(x)) {
      .vx_stop(sprintf("`key` has %d labels for the %d values of `%s`.", length(key), length(x), what), "verify_bad_input")
    }
    return(cells(key, as.vector(x), TRUE))
  }
  if (length(shape) == 2L) {
    named <- !is.null(rownames(x)) && !is.null(colnames(x))
    rows <- rownames(x) %||% sprintf("[%d]", seq_len(shape[[1L]]))
    columns <- colnames(x) %||% sprintf("[%d]", seq_len(shape[[2L]]))
    return(cells(paste0(rows[as.vector(row(x))], ", ", columns[as.vector(col(x))]), as.vector(x), named))
  }
  if (!is.null(names(x))) return(cells(names(x), unname(x), TRUE))
  if (length(x) == 1L) return(cells("", x, FALSE))
  cells(sprintf("[%d]", seq_along(x)), x, FALSE)
}

#' The difference of two numbers in a measure
#'
#' `absolute`: |a - e|. `relative`: |a - e| / max(|a|, |e|), 0 when both are 0.
#' `scaled`: |a - e| / max(1, |e|).
#' @param actual,expected Numeric vectors of one length.
#' @param measure One of the three measures.
#' @return A numeric vector; `NA` where a value is missing.
.vx_difference <- function(actual, expected, measure) {
  same <- !is.na(actual) & !is.na(expected) & actual == expected
  gap <- abs(actual - expected)
  scale <- switch(measure, absolute = 1, relative = pmax(abs(actual), abs(expected)), scaled = pmax(1, abs(expected)))
  ifelse(same, 0, ifelse(is.infinite(gap), Inf, gap / scale))
}

#' Judge every cell of a comparison alone
#'
#' @param actual,expected Flattened values (`.vx_flatten()`).
#' @param tolerance,measure,kind As declared.
#' @return A data frame, one row per key: `key`, `actual`, `expected` (numbers),
#'   `actual_text`, `expected_text`, `difference`, `status`.
.vx_judge <- function(actual, expected, tolerance, measure, kind) {
  positional <- c(!attr(actual, "named"), !attr(expected, "named"))
  if (xor(positional[[1L]], positional[[2L]]) && nrow(actual) == nrow(expected)) {
    # one side has no names: its values are taken in the order of the other's keys
    if (positional[[1L]]) actual$key <- expected$key else expected$key <- actual$key
  }
  keys <- union(expected$key, actual$key)
  at_actual <- match(keys, actual$key)
  at_expected <- match(keys, expected$key)
  out <- data.frame(key = keys, actual = actual$number[at_actual], expected = expected$number[at_expected],
                    actual_text = actual$text[at_actual], expected_text = expected$text[at_expected],
                    stringsAsFactors = FALSE)
  absent <- is.na(at_actual) | is.na(at_expected)
  numbers <- !absent & actual$numeric[at_actual] & expected$numeric[at_expected]
  words <- !absent & !numbers
  # text and TRUE/FALSE: equal or not; a number against a word never agrees
  word_actual <- ifelse(is.na(out$actual_text), as.character(out$actual), out$actual_text)
  word_expected <- ifelse(is.na(out$expected_text), as.character(out$expected), out$expected_text)
  out$difference <- ifelse(numbers, .vx_difference(out$actual, out$expected, measure), NA_real_)
  one_missing <- absent | (numbers & xor(is.na(out$actual), is.na(out$expected))) |
    (words & xor(is.na(word_actual), is.na(word_expected)))
  both_missing <- !absent & ((numbers & is.na(out$actual) & is.na(out$expected)) |
                               (words & is.na(word_actual) & is.na(word_expected)))
  close <- ifelse(numbers, !is.na(out$difference) & out$difference <= tolerance,
                  !is.na(word_actual) & !is.na(word_expected) & word_actual == word_expected)
  out$status <- if (kind == "not_comparable") {
    rep("not_comparable", nrow(out))
  } else if (kind == "reference") {
    ifelse(both_missing, "not_comparable", ifelse(one_missing, "missing", ifelse(close, "agree", "disagree")))
  } else if (kind == "known_difference") {
    ifelse(both_missing, "not_comparable", ifelse(one_missing | !close, "known_difference", "agree"))
  } else {
    ifelse(both_missing | one_missing | close, "disagree", "agree")
  }
  out
}

#' The lines of a failure message: the numbers furthest outside the rule
#'
#' @param judged The table of `.vx_judge()`.
#' @param failing The statuses that fail.
#' @param tolerance,measure As declared.
#' @param label The quantity.
#' @return A length-one character vector.
.vx_worst <- function(judged, failing, tolerance, measure, label) {
  bad <- judged[judged$status %in% failing, , drop = FALSE]
  bad <- bad[order(-ifelse(is.na(bad$difference), Inf, bad$difference), bad$key), , drop = FALSE]
  shown <- utils::head(bad, 5L)
  value <- function(number, text) ifelse(is.na(text), format(number, digits = 15L), text)
  lines <- sprintf("  %s: actual %s, expected %s, %s difference %s (%s)",
                   ifelse(nzchar(shown$key), shown$key, label), value(shown$actual, shown$actual_text),
                   value(shown$expected, shown$expected_text), measure,
                   format(shown$difference, digits = 3L), shown$status)
  paste(c(sprintf("%s: %d of %d compared values are outside the rule (tolerance %s, %s). The worst:",
                  label, nrow(bad), nrow(judged), format(tolerance), measure), lines), collapse = "\n")
}

#' Assert and record one declared comparison
#'
#' @param kind `"reference"`, `"known_difference"`, `"differs"` or `"not_comparable"`.
#' @param reason Why a known difference exists, or why the quantity is not comparable.
#' @param agrees_with For a known difference: the convention or argument under which the two do agree.
#' @inheritParams expect_reference
#' @return `actual`, invisibly.
.vx_expect <- function(actual, expected, reference, covers, quantity, tolerance, measure, key, note, authority,
                           kind, reason = NULL, agrees_with = NULL, defect = NULL) {
  fixture <- if (inherits(reference, "verify_fixture")) attr(reference, "provenance")
  if (inherits(expected, "verify_fixture") && is.null(fixture)) fixture <- attr(expected, "provenance")
  name <- if (inherits(reference, "verify_fixture")) fixture$program else reference
  stopifnot(
    "`reference` must be one name, or the fixture read by reference_fixture()" = is.character(name) && length(name) == 1L && nzchar(name),
    "`covers` must name exported functions as `name()`, or an entry of one as `name(argument = value)`" = is.character(covers) && length(covers) >= 1L && all(.vx_is_entry(covers)),
    "`quantity` must be one non-empty string" = is.character(quantity) && length(quantity) == 1L && nzchar(quantity),
    "`tolerance` must be one non-negative number" = is.numeric(tolerance) && length(tolerance) == 1L && is.finite(tolerance) && tolerance >= 0,
    "`reason` must be one non-empty string" = !kind %in% c("known_difference", "not_comparable") || (is.character(reason) && length(reason) == 1L && nzchar(reason)),
    "`agrees_with` must be one non-empty string" = is.null(agrees_with) || (is.character(agrees_with) && length(agrees_with) == 1L && nzchar(agrees_with)),
    "`defect` must be one non-empty string describing the known defect" = is.null(defect) || (is.character(defect) && length(defect) == 1L && nzchar(defect)),
    "`note` must be one string" = is.null(note) || (is.character(note) && length(note) == 1L)
  )
  measure <- match.arg(measure, .vx_measures)
  config <- .vx_config()
  authority <- .vx_authority(name, config, authority)
  unlisted <- .vx_unlisted(covers, config)
  if (length(unlisted)) {
    .vx_stop(sprintf("`covers` names %s, which `exports.covered` of %s does not list.", toString(unlisted), config$path),
                 "verify_uncovered")
  }
  frame <- is.data.frame(expected)
  if (frame != is.data.frame(actual)) {
    .vx_stop("`actual` and `expected` must both be data frames, or neither.", "verify_bad_input")
  }
  flat_expected <- .vx_flatten(expected, key = key, what = "expected")
  flat_actual <- .vx_flatten(actual, key = key, columns = if (frame) setdiff(names(expected), key), what = "actual")
  judged <- .vx_judge(flat_actual, flat_expected, tolerance, measure, kind)
  failing <- if (kind %in% c("known_difference", "not_comparable")) character() else c("disagree", "missing")
  nothing <- nrow(judged) == 0L
  vanished <- kind == "known_difference" && !nothing && !any(judged$status == "known_difference")
  outside <- any(judged$status %in% failing)
  # a declared defect: the disagreement is recorded as it is and does not fail the test; once every number
  # agrees the marker is stale, and that fails
  stale <- !is.null(defect) && !nothing && !outside
  ok <- !nothing && !vanished && !stale && (!outside || !is.null(defect))
  message <- if (nothing) {
    sprintf("%s: nothing was compared (both values are empty).", quantity)
  } else if (vanished) {
    sprintf("%s: declared as a known difference from %s, but every value now agrees within %s (%s). Make it expect_reference().",
            quantity, name, format(tolerance), measure)
  } else if (stale) {
    sprintf("%s: the declared defect no longer shows (every value agrees with %s within %s, %s): remove `defect =`.",
            quantity, name, format(tolerance), measure)
  } else if (!ok) {
    .vx_worst(judged, failing, tolerance, measure, quantity)
  } else ""
  test <- .vx_test_name()
  state <- .vx_state()
  if (!is.null(state)) {
    state$blocks[[length(state$blocks) + 1L]] <- list(
      file = state$file, test = test, judged = judged, passed = ok,
      declared = list(covers = covers, reference = name, authority = authority, quantity = quantity,
                      tolerance = tolerance, measure = measure, kind = kind,
                      source = if (is.null(fixture)) "live" else "retained", reason = reason, agrees_with = agrees_with, defect = defect, note = note,
                      reference_version = if (is.null(fixture)) .vx_version(name, config) else fixture$version,
                      fixture = fixture$path))
  }
  testthat::expect(ok, message)
  invisible(actual)
}

#' Expect a result to agree with a reference, number by number
#'
#' Numbers, named vectors, matrices and data frames are flattened to keyed
#' numbers and each is judged alone against `tolerance`; a missing or extra key
#' fails; `NA` on both sides is not comparable, on one side a failure. One
#' testthat expectation, whose failure message lists the worst numbers. Under
#' verify_tests() every number is recorded for Prova Verify.
#'
#' @param actual The package's result: a number, a (named) vector, a matrix or a
#'   data frame.
#' @param expected The reference's result, of the same shape. For data frames
#'   the columns compared are the non-key columns of `expected`; `actual` may
#'   hold more.
#' @param reference What `expected` was computed by: a package (`"stats"`), a
#'   program (`"Latent GOLD 6.1"`), `"published: <citation>"`,
#'   `"independent: <what>"`, or the object returned by reference_fixture().
#' @param covers The exported function(s) whose result is checked, as `"name()"`.
#' @param quantity What the number is, in the reader's words.
#' @param tolerance The largest difference allowed, per number.
#' @param measure `"absolute"` (|a - e|), `"relative"` (|a - e| / max(|a|, |e|))
#'   or `"scaled"` (|a - e| / max(1, |e|)).
#' @param key For data frames, the key column(s). For vectors and matrices,
#'   optional explicit keys (one per value).
#' @param note A sentence for the reader, or `NULL`.
#' @param authority The reference's authority, when `verify.json` does not give it.
#' @param defect A short description of a known defect this comparison shows
#'   (`"G-squared negative when loops are declared impossible but present; FINDINGS.md"`),
#'   or `NULL`. With it the numbers outside the tolerance are recorded as
#'   disagreements and the test does not fail; it fails when every number
#'   agrees (the defect no longer shows: remove `defect =`).
#' @return `actual`, invisibly. Raises `verify_bad_input`,
#'   `verify_unknown_reference`, `verify_uncovered` or `verify_no_config` for a
#'   declaration that cannot be recorded.
expect_reference <- function(actual, expected, reference, covers, quantity, tolerance,
                             measure = c("absolute", "relative", "scaled"), key = NULL, note = NULL, authority = NULL,
                             defect = NULL) {
  .vx_expect(actual, expected, reference, covers, quantity, tolerance, measure, key, note, authority, kind = "reference",
                 defect = defect)
}

#' Record a difference from a reference that is known and explained
#'
#' Each number outside `tolerance` is recorded as a known difference with
#' `reason`; the test does not fail. It fails when no number differs any more
#' (the difference is gone: use expect_reference()).
#'
#' @inheritParams expect_reference
#' @param reason Why the two differ, in one or two sentences.
#' @param agrees_with Optional: the convention or argument under which the two
#'   do agree (`"cograph mode = 'in'"`); shown with the reason.
#' @return `actual`, invisibly.
expect_known_difference <- function(actual, expected, reference, covers, quantity, tolerance, reason,
                                    measure = c("absolute", "relative", "scaled"), key = NULL, note = NULL,
                                    authority = NULL, agrees_with = NULL) {
  .vx_expect(actual, expected, reference, covers, quantity, tolerance, measure, key, note, authority,
                 kind = "known_difference", reason = reason, agrees_with = agrees_with)
}

#' Record a quantity that is not defined on this input
#'
#' For a degenerate case (a tie, an eigenvector of a graph with no edge): both
#' values are recorded with `reason` and nothing is judged. The test does not
#' fail, and the comparison is no evidence for the function.
#'
#' @inheritParams expect_reference
#' @param reason Why the two values cannot be compared here.
#' @param tolerance Recorded only; nothing is judged by it.
#' @return `actual`, invisibly.
expect_not_comparable <- function(actual, expected, reference, covers, quantity, reason, tolerance = 0,
                                  measure = c("absolute", "relative", "scaled"), key = NULL, note = NULL,
                                  authority = NULL) {
  .vx_expect(actual, expected, reference, covers, quantity, tolerance, measure, key, note, authority,
                 kind = "not_comparable", reason = reason)
}

#' Expect a result to differ from a reference (a negative control)
#'
#' Every number must differ from its counterpart by more than `tolerance`.
#'
#' @inheritParams expect_reference
#' @return `actual`, invisibly.
expect_differs <- function(actual, expected, reference, covers, quantity, tolerance,
                           measure = c("absolute", "relative", "scaled"), key = NULL, note = NULL, authority = NULL) {
  .vx_expect(actual, expected, reference, covers, quantity, tolerance, measure, key, note, authority, kind = "differs")
}

#' Expect a call to raise an error that is a declared defect
#'
#' For a known defect of the package that shows as an error (the function
#' stops where it should return a result). While the call raises an error, one
#' row is recorded as a disagreement (kind `reference`, the error's message as
#' the package's value, the text of `defect`) and the test does not fail. When
#' the call returns without an error the test FAILS: the declared defect no
#' longer shows, and the call is to be compared with expect_reference().
#'
#' @param expr The call that raises the error.
#' @param defect A short description of the defect (`"lsa() stops on a sequence
#'   of length one; FINDINGS.md"`).
#' @param covers The exported function(s) the call checks, as `"name()"`.
#' @param quantity What the call should have returned, in the reader's words.
#' @param reference What the result should agree with: a reference of
#'   `verify.json`, `"published: ..."` or `"independent: ..."`.
#' @param note A sentence for the reader, or `NULL`.
#' @param authority The reference's authority, when `verify.json` does not give it.
#' @return The condition raised, invisibly (`NULL` when there was none).
expect_defect_error <- function(expr, defect, covers, quantity, reference = "independent: the call returns a result",
                                note = NULL, authority = NULL) {
  stopifnot(
    "`defect` must be one non-empty string describing the known defect" = is.character(defect) && length(defect) == 1L && nzchar(defect),
    "`covers` must name exported functions as `name()`, or an entry of one as `name(argument = value)`" = is.character(covers) && length(covers) >= 1L && all(.vx_is_entry(covers)),
    "`quantity` must be one non-empty string" = is.character(quantity) && length(quantity) == 1L && nzchar(quantity),
    "`reference` must be one name" = is.character(reference) && length(reference) == 1L && nzchar(reference),
    "`note` must be one string" = is.null(note) || (is.character(note) && length(note) == 1L)
  )
  config <- .vx_config()
  authority <- .vx_authority(reference, config, authority)
  unlisted <- .vx_unlisted(covers, config)
  if (length(unlisted)) {
    .vx_stop(sprintf("`covers` names %s, which `exports.covered` of %s does not list.", toString(unlisted), config$path),
             "verify_uncovered")
  }
  test <- .vx_test_name()
  # the call is evaluated here, once: an error is the defect showing, anything else is a result
  raised <- tryCatch({
    expr
    NULL
  }, error = \(condition) condition)
  if (is.null(raised)) {
    testthat::expect(FALSE, sprintf("%s: the declared defect no longer shows (the call returned without an error): remove expect_defect_error() and compare the result with expect_reference(). Declared: %s",
                                    quantity, defect))
    return(invisible(NULL))
  }
  said <- gsub("\\s+", " ", trimws(conditionMessage(raised)))
  text <- paste0("error: ", if (nchar(said) > 300L) paste0(substr(said, 1L, 299L), "\u2026") else said)
  state <- .vx_state()
  if (!is.null(state)) {
    judged <- data.frame(key = "", actual = NA_real_, expected = NA_real_, actual_text = text, expected_text = NA_character_,
                         difference = NA_real_, status = "disagree", stringsAsFactors = FALSE)
    state$blocks[[length(state$blocks) + 1L]] <- list(
      file = state$file, test = test, judged = judged, passed = TRUE, matcher = "expect_defect_error",
      declared = list(covers = covers, reference = reference, authority = authority, quantity = quantity,
                      tolerance = 0, measure = "absolute", kind = "reference", source = "live", defect = defect,
                      note = paste(c(sprintf("The call raised an error: %s", said), note), collapse = " "),
                      reference_version = .vx_version(reference, config)))
  }
  testthat::expect(TRUE, "")
  invisible(raised)
}

#' Skip a test whose reference is not installed, and record it
#'
#' @param package The reference R package(s) the test needs.
#' @param python The Python module(s) the test needs (imported through
#'   reticulate when it is installed, else by the interpreter in
#'   `RETICULATE_PYTHON` or `python3` / `python` on the PATH). A module found
#'   has its version recorded for a reference of that name.
#' @return `TRUE` invisibly when everything is there; else the test is skipped
#'   (a testthat skip naming what is missing).
skip_without_reference <- function(package = character(), python = character()) {
  stopifnot("`package` must be package names" = is.character(package),
            "`python` must be Python module names" = is.character(python) && all(grepl("^[A-Za-z_][A-Za-z0-9_.]*$", python)),
            "name at least one reference: `package` or `python`" = length(package) + length(python) >= 1L)
  absent <- package[!vapply(package, requireNamespace, logical(1), quietly = TRUE)]
  modules <- python[!vapply(python, \(module) .vx_python_module(module)$available, logical(1))]
  if (!length(absent) && !length(modules)) return(invisible(TRUE))
  state <- .vx_state()
  if (!is.null(state)) {
    state$skips[[length(state$skips) + 1L]] <- list(file = state$file, test = .vx_test_name(),
                                                    reference = c(absent, if (length(modules)) paste(modules, "(Python)")))
  }
  testthat::skip(paste(c(if (length(absent)) sprintf("reference package %s is not installed", toString(absent)),
                         if (length(modules)) sprintf("Python module %s is not available", toString(modules))), collapse = "; "))
}

#' Read a stored reference, refusing one without provenance
#'
#' The provenance is in the file (a JSON object's `provenance` field, or its
#' top-level fields) or in a sidecar `<file>.provenance.json`: `program`,
#' `version`, `generated_by` (the generating script, from the package root),
#' `generated_at`, `data` (`path` and `sha256` of the input, a list of them,
#' `"none"`, or `embedded = "<field>"` when the generator builds its input and
#' stores it in the fixture). The generator writes them; they are not typed.
#'
#' @param path The fixture: `.json`, `.csv` or `.rds`, relative to the test file.
#' @param redistributable `FALSE` for a fixture that may not be passed on (it is
#'   shown to the members of the product only, as are its input data files).
#' @return The fixture's content with class `verify_fixture`; pass it (or a part
#'   of it) as `expected` and the object itself as `reference`. Raises
#'   `verify_fixture_missing`, `verify_fixture_no_provenance` or
#'   `verify_fixture_stale` (its input data changed since it was generated).
reference_fixture <- function(path, redistributable = TRUE) {
  stopifnot("`path` must be one file path" = is.character(path) && length(path) == 1L,
            "`redistributable` must be TRUE or FALSE" = isTRUE(redistributable) || isFALSE(redistributable))
  if (!file.exists(path)) .vx_stop(sprintf("Fixture %s does not exist.", path), "verify_fixture_missing")
  type <- tolower(tools::file_ext(path))
  content <- switch(type,
    json = jsonlite::fromJSON(path, simplifyVector = TRUE),
    csv = utils::read.csv(path, stringsAsFactors = FALSE),
    rds = readRDS(path),
    .vx_stop(sprintf("Fixture %s is not a .json, .csv or .rds file.", path), "verify_bad_input"))
  sidecar <- paste0(path, ".provenance.json")
  provenance <- if (file.exists(sidecar)) {
    jsonlite::fromJSON(sidecar, simplifyVector = FALSE)
  } else if (type == "json" && is.list(content) && !is.data.frame(content)) {
    raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    raw$provenance %||% raw[intersect(names(raw), .vx_provenance)]
  } else list()
  absent <- setdiff(.vx_provenance, names(provenance))
  if (length(absent)) {
    .vx_stop(sprintf("Fixture %s states no %s; a stored reference carries program, version, generated_by, generated_at and data, in the file or in %s.",
                         path, toString(absent), basename(sidecar)), "verify_fixture_no_provenance")
  }
  # `data`: one { path, sha256 }, a list of them, "none", or { embedded: "<field>" } (the input is in the fixture)
  given <- provenance$data
  inputs <- if (!is.list(given)) list() else if (!is.null(given$path)) list(given) else Filter(\(input) is.list(input) && !is.null(input$path), given)
  root <- .vx_root()
  if (!is.null(root) && exists("sha256sum", envir = asNamespace("tools"), inherits = FALSE)) {
    hash <- get("sha256sum", envir = asNamespace("tools"))
    stale <- Filter(\(input) {
      file <- file.path(root, input$path)
      file.exists(file) && !identical(unname(hash(file)), input$sha256)
    }, inputs)
    if (length(stale)) {
      .vx_stop(sprintf("Fixture %s was generated from %s, which has changed since (its sha256 differs); generate the fixture again with %s.",
                           path, toString(vapply(stale, \(input) input$path, character(1))), provenance$generated_by),
                   "verify_fixture_stale")
    }
  }
  provenance$path <- .vx_relative(path)
  state <- .vx_state()
  if (!is.null(state)) {
    provenance$sidecar <- if (file.exists(sidecar)) .vx_relative(sidecar)
    provenance$inputs <- lapply(inputs, \(input) input$path)
    if (!redistributable) provenance$redistributable <- FALSE
    state$fixtures[[length(state$fixtures) + 1L]] <- c(list(file = state$file), provenance)
  }
  structure(content, provenance = provenance, class = c("verify_fixture", class(content)))
}

#' Declare an input data file of a test
#'
#' The file is attached to the case in Prova Verify, and sent with the test when
#' a reader runs it again.
#'
#' @param path A data file, relative to the test file (keep it under
#'   `tests/equivalence/`).
#' @param redistributable `FALSE` for data that may not be passed on (a
#'   licence, participants' records): the file is attached to the case and
#'   shown to the members of the product only.
#' @return `path`, so the call can sit inside the call that reads the file.
reference_data <- function(path, redistributable = TRUE) {
  stopifnot("`path` must be one file path" = is.character(path) && length(path) == 1L,
            "`redistributable` must be TRUE or FALSE" = isTRUE(redistributable) || isFALSE(redistributable))
  if (!file.exists(path)) .vx_stop(sprintf("Data file %s does not exist.", path), "verify_data_missing")
  state <- .vx_state()
  if (!is.null(state)) {
    state$data[[length(state$data) + 1L]] <- list(file = state$file, path = .vx_relative(path), redistributable = redistributable)
  }
  path
}

#' What NAMESPACE obliges `verify.json` to list
#'
#' Every `export()`, and every S3 method as `generic.class()` except methods of
#' the display generics (print, format, plot, autoplot, toString, str,
#' knit_print), which return no numbers.
#' @param root The package root.
#' @return A list: `required` and `optional` names, each written `name()`.
.vx_namespace <- function(root) {
  root <- normalizePath(root)
  parsed <- parseNamespaceFile(basename(root), dirname(root), mustExist = TRUE)
  if (length(parsed$exportPatterns)) {
    .vx_stop("NAMESPACE uses exportPattern(); the exports cannot be listed from it. Export by name.", "verify_export_pattern")
  }
  methods <- if (length(parsed$S3methods)) paste0(parsed$S3methods[, 1L], ".", parsed$S3methods[, 2L]) else character()
  display <- if (length(parsed$S3methods)) parsed$S3methods[, 1L] %in% .vx_display_generics else logical()
  list(required = paste0(unique(c(parsed$exports, parsed$exportMethods, methods[!display])), "()"),
       optional = paste0(unique(methods[display]), "()"))
}

#' Check `verify.json` against NAMESPACE
#'
#' Every export is in exactly one of `covered`, `not_numeric`, `not_yet`, and
#' nothing is listed that is not exported. An entry of a verb with a catalogue
#' argument, `name(argument = value)`, may be listed in any of them; it is
#' exported when its verb `name()` is, and it accounts for its verb.
#'
#' @param path The `verify.json` file.
#' @param root The package root (the folder of NAMESPACE).
#' @return A data frame, one row per listed export: `export`, `list`, `reason`.
#'   Raises `verify_exports_incomplete` naming every export in none of the
#'   lists, in two of them, or listed but not exported.
verify_exports_check <- function(path = file.path("tests", "equivalence", "verify.json"), root = ".") {
  config <- .vx_config(path)
  lists <- config$exports
  reasons <- c(lists$not_numeric, lists$not_yet)
  listed <- data.frame(
    export = c(as.character(unlist(lists$covered)), names(lists$not_numeric), names(lists$not_yet)),
    list = rep(c("covered", "not_numeric", "not_yet"), c(length(lists$covered), length(lists$not_numeric), length(lists$not_yet))),
    stringsAsFactors = FALSE)
  listed$reason <- vapply(seq_len(nrow(listed)), \(i) {
    if (listed$list[[i]] == "covered") "" else as.character(reasons[[listed$export[[i]]]])
  }, character(1))
  namespace <- .vx_namespace(root)
  problems <- c(
    sprintf("%s is exported and in none of the three lists", setdiff(namespace$required, c(listed$export, .vx_verb(listed$export)))),
    sprintf("%s is in two lists", unique(listed$export[duplicated(listed$export)])),
    sprintf("%s is listed but not exported", listed$export[!.vx_verb(listed$export) %in% c(namespace$required, namespace$optional)]),
    sprintf("%s is in a list with no reason", listed$export[listed$list != "covered" & !nzchar(listed$reason)]))
  if (length(problems)) {
    .vx_stop(paste(c(sprintf("%s does not match NAMESPACE:", path), paste0("  ", problems)), collapse = "\n"),
                 "verify_exports_incomplete")
  }
  listed
}

#' A number as the capture writes it
#'
#' @param number A numeric vector.
#' @param text The text the cell holds when it is not a number.
#' @return A list: numbers, or `"NA"`, `"NaN"`, `"Infinity"`, `"-Infinity"`, or the text.
.vx_encode <- function(number, text) {
  Map(\(value, word) {
    if (!is.na(word)) word
    else if (is.nan(value)) "NaN"
    else if (is.na(value)) "NA"
    else if (is.infinite(value)) (if (value > 0) "Infinity" else "-Infinity")
    else value
  }, number, text)
}

#' The capture entries of one recorded block, with unique quantities
#'
#' The quantity of a cell is `quantity` for a single number and
#' `"<quantity>: <key>"` otherwise; one compared twice with the same reference in
#' a file gets ` #2`.
#' @param block A recorded block.
#' @param seen An environment counting quantities per reference.
#' @return A list of capture comparisons.
.vx_entries <- function(block, seen) {
  judged <- block$judged
  declared <- Filter(Negate(is.null), block$declared)
  base <- ifelse(nzchar(judged$key), paste0(declared$quantity, ": ", judged$key), declared$quantity)
  # every `independent: ...` reference is one source and one side in Prova: its quantities are numbered together
  counted_as <- if (startsWith(declared$reference, "independent:")) "independent:" else declared$reference
  quantity <- vapply(base, \(label) {
    id <- paste0(counted_as, "\r", label)
    count <- (seen[[id]] %||% 0L) + 1L
    seen[[id]] <- count
    if (count > 1L) sprintf("%s #%d", label, count) else label
  }, character(1), USE.NAMES = FALSE)
  actual <- .vx_encode(judged$actual, judged$actual_text)
  expected <- .vx_encode(judged$expected, judged$expected_text)
  lapply(seq_len(nrow(judged)), \(i) {
    list(matcher = block$matcher %||% paste0("expect_", declared$kind),
         actual = actual[[i]], expected = expected[[i]], tolerance = declared$tolerance,
         label = quantity[[i]], passed = !judged$status[[i]] %in% c("disagree", "missing"),
         declared = c(list(covers = as.list(declared$covers)), declared[c("reference", "authority")], list(quantity = quantity[[i]]),
                      declared[setdiff(names(declared), c("covers", "reference", "authority", "quantity"))],
                      list(status = judged$status[[i]]),
                      if (!is.na(judged$difference[[i]])) list(difference = judged$difference[[i]])))
  })
}

#' A new recording state
#'
#' @param root The package root, or `NULL`.
#' @return An environment.
.vx_new_state <- function(root) {
  state <- new.env(parent = emptyenv())
  state$root <- root
  state$file <- NA_character_
  state$blocks <- list()
  state$skips <- list()
  state$fixtures <- list()
  state$data <- list()
  state
}

#' The package under test, from DESCRIPTION and .git
#'
#' @param root The package root.
#' @return A list: `name`, `version`, `commit` (when known).
.vx_library <- function(root) {
  fields <- read.dcf(file.path(root, "DESCRIPTION"), fields = c("Package", "Version"))[1L, ]
  head_file <- file.path(root, ".git", "HEAD")
  head <- if (file.exists(head_file)) trimws(readLines(head_file, n = 1L, warn = FALSE)) else ""
  ref_file <- file.path(root, ".git", sub("^ref: ", "", head))
  commit <- if (startsWith(head, "ref: ")) {
    if (file.exists(ref_file)) trimws(readLines(ref_file, n = 1L, warn = FALSE))
  } else if (nzchar(head)) head
  Filter(Negate(is.null), list(name = unname(fields[["Package"]]), version = unname(fields[["Version"]]), commit = commit))
}

#' The tests of one run file as capture entries
#'
#' @param results The `testthat_results` of the file.
#' @param blocks The blocks recorded while it ran.
#' @param skips The reference skips recorded while it ran.
#' @param seen The quantity counter of the file.
#' @return A list of capture tests.
.vx_tests <- function(results, blocks, skips, seen) {
  ran <- lapply(results, \(test) {
    classes <- vapply(test$results, \(outcome) class(outcome)[[1L]], character(1))
    failed <- classes %in% c("expectation_failure", "expectation_error")
    skipped <- classes == "expectation_skip"
    state <- if (any(failed)) "fail" else if (any(skipped)) "skip" else "pass"
    # code of a test file outside any test_that() is reported by testthat without a test name
    list(name = if (length(test$test) == 1L && nzchar(test$test)) test$test else "(code outside test_that())", state = state,
         message = if (any(failed | skipped)) conditionMessage(test$results[[which(failed | skipped)[[1L]]]]),
         assertions = sum(!skipped))
  })
  names_ran <- vapply(ran, \(test) test$name, character(1))
  block_test <- vapply(blocks, \(block) block$test, character(1))
  tests <- unique(c(names_ran, block_test))
  lapply(tests, \(name) {
    mine <- ran[names_ran == name]
    state <- if (!length(mine)) "fail" else if (any(vapply(mine, \(test) test$state == "fail", logical(1)))) "fail" else mine[[1L]]$state
    message <- unlist(lapply(mine, \(test) test$message))
    comparisons <- unlist(lapply(blocks[block_test == name], .vx_entries, seen = seen), recursive = FALSE)
    absent <- unique(unlist(lapply(Filter(\(skip) skip$test == name, skips), \(skip) skip$reference)))
    Filter(Negate(is.null), list(
      titles = list(), name = name, state = state,
      error = if (state == "fail" && length(message)) message[[1L]],
      skip_reason = if (state == "skip" && length(message)) sub("^Reason: ", "", message[[1L]]),
      missing_reference = if (length(absent)) as.list(absent),
      other_assertions = max(0L, sum(vapply(mine, \(test) test$assertions, integer(1))) - sum(block_test == name)),
      comparisons = comparisons %||% list()))
  })
}

#' Run the equivalence tests and write the capture
#'
#' Runs every `test*.R` of `path` with testthat, recording each declared
#' comparison, writes `<capture>/capture.json` (format `prova.verify-capture/1`),
#' checks `verify.json` against NAMESPACE, and checks that every `covered`
#' function has, in this run, a comparison of kind `reference` on an authority
#' that counts (not `internal`). A function whose only reference is not
#' installed where the job runs therefore belongs in `not_yet`.
#'
#' @param path The folder of the equivalence tests.
#' @param capture The folder the capture is written to (default: the
#'   environment variable `PROVA_VERIFY_CAPTURE`, else `.ci/verify-capture`).
#' @param lib Further library folders with reference packages, searched after
#'   the package's own library; the ones that do not exist are ignored.
#' @param filter A regular expression on the test file names, or `NULL`. A
#'   filtered run checks no coverage.
#' @param load How the package is attached before the tests: `"source"` (from
#'   its source with pkgload, exported functions only), `"installed"`
#'   (`library()`), or `"none"` (the test files attach what they need).
#' @return A data frame, one row per test file: `file`, `tests`, `failed`,
#'   `skipped`, `comparisons`, `agree`, `known_difference`, `disagree`,
#'   `not_comparable`, `declared_defects` (the disagreeing numbers that a
#'   `defect =` declares). Prints the number of declared defects and of new
#'   failures. Raises `verify_failed` after writing the capture when a test
#'   failed (a new disagreement, a stale defect marker, an error) or a check
#'   did not pass; declared defects alone do not.
verify_tests <- function(path = file.path("tests", "equivalence"),
                       capture = Sys.getenv("PROVA_VERIFY_CAPTURE", file.path(".ci", "verify-capture")),
                       lib = NULL, filter = NULL, load = c("source", "installed", "none")) {
  load <- match.arg(load)
  stopifnot("`path` must be the folder of the equivalence tests" = dir.exists(path),
            "run verify_tests() from the package root (no DESCRIPTION here)" = file.exists("DESCRIPTION"))
  root <- normalizePath(".")
  extra <- path.expand(lib %||% character())
  .libPaths(c(.libPaths(), extra[dir.exists(extra)]))
  files <- sort(list.files(path, "^test.*\\.[Rr]$", full.names = TRUE))
  if (!is.null(filter)) files <- files[grepl(filter, basename(files))]
  stopifnot("no test file to run" = length(files) > 0L)
  library_info <- .vx_library(root)
  # The package is attached as a reader has it (its exported functions and data), and testthat then sources
  # the helper files of the folder itself; with testthat's own load_package = "source" it would not.
  if (load == "source") {
    if (!requireNamespace("pkgload", quietly = TRUE)) .vx_stop("load = \"source\" needs the pkgload package.", "verify_no_pkgload")
    pkgload::load_all(root, export_all = FALSE, helpers = FALSE, quiet = TRUE)
  } else if (load == "installed") {
    library(library_info$name, character.only = TRUE)
  }
  state <- .vx_new_state(root)
  old <- options(prova.verify.state = state)
  on.exit(options(old), add = TRUE, after = FALSE)
  .vx_python_hash_seed()
  ran <- lapply(files, \(file) {
    state$file <- .vx_relative(file)
    state$blocks <- list()
    state$skips <- list()
    state$fixtures <- list()
    state$data <- list()
    # a file that cannot be read or stops outside its tests is a failed file, and the run goes on
    results <- tryCatch(
      testthat::test_file(file, reporter = "summary", load_package = "none",
                          stop_on_failure = FALSE, stop_on_warning = FALSE),
      error = \(condition) conditionMessage(condition))
    broken <- is.character(results)
    tests <- .vx_tests(if (broken) list() else results, state$blocks, state$skips, new.env(parent = emptyenv()))
    states <- vapply(tests, \(test) test$state, character(1))
    live <- Filter(\(block) block$declared$source == "live" && !is.null(block$declared$reference_version), state$blocks)
    live_names <- vapply(live, \(block) block$declared$reference, character(1))
    versions <- stats::setNames(lapply(live, \(block) block$declared$reference_version), live_names)[!duplicated(live_names)]
    fixtures <- lapply(state$fixtures, \(fixture) fixture[setdiff(names(fixture), "file")])
    reads <- unique(c(.vx_relative(file.path(path, "verify.json")),
                      vapply(list.files(path, "^helper.*\\.[Rr]$", full.names = TRUE), .vx_relative, character(1), USE.NAMES = FALSE),
                      unlist(lapply(fixtures, \(fixture) c(fixture$path, fixture$sidecar, fixture$generated_by, unlist(fixture$inputs)))),
                      vapply(state$data, \(entry) entry$path, character(1))))
    # files that may not be passed on: data declared so, and a fixture declared so with its input data
    withheld <- unique(c(vapply(Filter(\(entry) isFALSE(entry$redistributable), state$data), \(entry) entry$path, character(1)),
                         unlist(lapply(Filter(\(fixture) isFALSE(fixture$redistributable), fixtures), \(fixture) c(fixture$path, unlist(fixture$inputs))))))
    c(list(file = state$file, kind = "declared",
           state = if (broken || any(states == "fail")) "fail" else if (length(states) && all(states == "skip")) "skip" else "pass"),
      if (broken) list(error = results),
      list(reads = as.list(reads), packages = versions, fixtures = fixtures,
           data = as.list(unique(vapply(state$data, \(entry) entry$path, character(1))))),
      if (length(withheld)) list(not_redistributable = as.list(withheld)),
      list(tests = tests))
  })
  dir.create(capture, recursive = TRUE, showWarnings = FALSE)
  written <- list(format = "prova.verify-capture/1", library = library_info,
                  runner = list(name = "testthat", version = as.character(utils::packageVersion("testthat")),
                                helper = paste("prova-verify-helper", verify_helper_version())),
                  platform = sprintf("%s, %s", R.version.string, R.version$platform),
                  run_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), files = ran)
  jsonlite::write_json(written, file.path(capture, "capture.json"), auto_unbox = TRUE, digits = NA, null = "null", pretty = FALSE)

  comparisons <- unlist(lapply(ran, \(file) unlist(lapply(file$tests, \(test) test$comparisons), recursive = FALSE)), recursive = FALSE)
  count <- function(file, status) {
    sum(vapply(file$tests, \(test) sum(vapply(test$comparisons, \(entry) entry$declared$status == status, logical(1))), numeric(1)))
  }
  summary <- data.frame(
    file = vapply(ran, \(file) basename(file$file), character(1)),
    tests = vapply(ran, \(file) length(file$tests), integer(1)),
    failed = vapply(ran, \(file) sum(vapply(file$tests, \(test) test$state == "fail", logical(1))) + (file$state == "fail" && !length(file$tests)), numeric(1)),
    skipped = vapply(ran, \(file) sum(vapply(file$tests, \(test) test$state == "skip", logical(1))), integer(1)),
    comparisons = vapply(ran, \(file) sum(vapply(file$tests, \(test) length(test$comparisons), integer(1))), integer(1)),
    agree = vapply(ran, count, numeric(1), status = "agree"),
    known_difference = vapply(ran, count, numeric(1), status = "known_difference"),
    disagree = vapply(ran, \(file) count(file, "disagree") + count(file, "missing"), numeric(1)),
    not_comparable = vapply(ran, count, numeric(1), status = "not_comparable"),
    declared_defects = vapply(ran, \(file) sum(vapply(file$tests, \(test) sum(vapply(test$comparisons, \(entry) {
      !is.null(entry$declared$defect) && entry$declared$status %in% c("disagree", "missing")
    }, logical(1))), numeric(1))), numeric(1)),
    stringsAsFactors = FALSE)
  print(summary, row.names = FALSE)
  defects <- unique(unlist(lapply(comparisons, \(entry) {
    if (!is.null(entry$declared$defect) && entry$declared$status %in% c("disagree", "missing")) entry$declared$defect
  })))
  message(sprintf("verify: %d declared defect(s), %d new failure(s)", length(defects), sum(summary$failed)))
  if (length(defects)) message(paste0("  declared defect: ", defects, collapse = "\n"))
  message(sprintf("verify: capture written to %s (%d comparisons)", file.path(capture, "capture.json"), length(comparisons)))

  problems <- character()
  checked <- tryCatch(verify_exports_check(file.path(path, "verify.json"), root),
                      verify_error = \(condition) conditionMessage(condition))
  if (is.character(checked)) problems <- c(problems, checked)
  if (is.null(filter) && is.data.frame(checked)) {
    counted <- Filter(\(entry) entry$declared$authority %in% .vx_counted && entry$declared$kind == "reference", comparisons)
    evidenced <- unique(unlist(lapply(counted, \(entry) entry$declared$covers)))
    # evidence for an entry `name(argument = value)` is evidence for its verb `name()` too
    evidenced <- unique(c(evidenced, .vx_verb(evidenced)))
    skipped_tests <- sum(summary$skipped)
    bare <- setdiff(checked$export[checked$list == "covered"], evidenced)
    if (length(bare)) {
      problems <- c(problems, sprintf(
        "covered in verify.json but with no comparison on a counted authority in this run%s: %s",
        if (skipped_tests) sprintf(" (%d tests were skipped)", skipped_tests) else "", toString(bare)))
    }
  }
  if (sum(summary$failed)) problems <- c(sprintf("%d test(s) failed", sum(summary$failed)), problems)
  if (length(problems)) .vx_stop(paste(c("verify: not passed.", problems), collapse = "\n"), "verify_failed")
  invisible(summary)
}

#' The values one side of a test file computes
#'
#' Runs one test file of the equivalence tests in this R session and returns
#' the values it compared: the package's (`reference = NULL`) or those of one
#' reference. This is what Prova Verify's re-run reads; the package and
#' testthat must be installed.
#'
#' @param file The test file.
#' @param reference A reference's name as the test declares it, or `NULL` for
#'   the package's own values.
#' @param independent `TRUE` for the values of every `independent: ...`
#'   reference of the file (one side in Prova); `reference` is then left out.
#' @return A data frame, one row per compared value: `quantity`, `value`.
verify_rerun <- function(file, reference = NULL, independent = FALSE) {
  stopifnot("`file` must be one existing test file" = is.character(file) && length(file) == 1L && file.exists(file),
            "`reference` must be one name or NULL" = is.null(reference) || (is.character(reference) && length(reference) == 1L),
            "`independent` must be TRUE or FALSE, and TRUE only without `reference`" = (isTRUE(independent) && is.null(reference)) || isFALSE(independent))
  state <- .vx_new_state(NULL)
  state$file <- basename(file)
  old <- options(prova.verify.state = state)
  on.exit(options(old), add = TRUE, after = FALSE)
  .vx_python_hash_seed()
  testthat::test_file(file, reporter = "silent", load_package = "none", stop_on_failure = FALSE, stop_on_warning = FALSE)
  seen <- new.env(parent = emptyenv())
  entries <- unlist(lapply(state$blocks, .vx_entries, seen = seen), recursive = FALSE)
  ours <- is.null(reference) && !independent
  mine <- if (ours) entries else if (independent) Filter(\(entry) startsWith(entry$declared$reference, "independent:"), entries)
    else Filter(\(entry) identical(entry$declared$reference, reference), entries)
  values <- lapply(mine, \(entry) if (ours) entry$actual else entry$expected)
  numbers <- vapply(values, is.numeric, logical(1))
  data.frame(quantity = vapply(mine, \(entry) entry$declared$quantity, character(1)),
             value = if (all(numbers)) as.numeric(unlist(values)) else vapply(values, as.character, character(1)),
             stringsAsFactors = FALSE)
}
