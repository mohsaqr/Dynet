# ===========================================================================
# Column detection and time parsing (internal)
# ===========================================================================

# Alias sets, checked case-insensitively after stripping non-alphanumerics.
# Order within a set is priority order.
.dynet_aliases <- list(
  from     = c("from", "source", "sender", "tail", "ego", "actor1", "node1",
               "sourceid", "fromid", "i"),
  to       = c("to", "target", "receiver", "head", "alter", "actor2", "node2",
               "targetid", "toid", "j"),
  start    = c("start", "onset", "begin", "starttime", "startdate", "tstart",
               "fromtime"),
  end      = c("end", "terminus", "finish", "endtime", "enddate", "tend",
               "totime", "stop"),
  duration = c("duration", "dur", "elapsed", "length", "lasted"),
  time     = c("time", "timestamp", "datetime", "date", "when", "t", "occurred",
               "createdat", "posttime"),
  thread   = c("thread", "threadid", "discussion", "discussiontitle", "topic",
               "conversation", "parent", "postid", "root"),
  session  = c("session", "period", "wave", "phase", "cohort", "course"),
  group    = c("group", "event", "context", "room", "class", "meeting",
               "venue", "team", "channel"),
  actor    = c("actor", "person", "member", "student", "participant", "user",
               "id", "name")
)

#' Normalise a column name for alias matching
#' @param x Character vector of column names.
#' @return Character vector, lower-cased with non-alphanumerics removed.
#' @noRd
.norm_name <- function(x) {
  gsub("[^a-z0-9]", "", tolower(x))
}

#' Find the first column matching an alias set
#'
#' @param data Data frame to search.
#' @param role Name of an entry in `.dynet_aliases`.
#' @param exclude Character vector of column names already claimed.
#' @return The matching column name, or `NULL`.
#' @noRd
.match_column <- function(data, role, exclude = character()) {
  aliases <- .dynet_aliases[[role]]
  cand <- setdiff(names(data), exclude)
  normed <- .norm_name(cand)
  hit <- match(aliases, normed)
  hit <- hit[!is.na(hit)]
  if (length(hit) == 0L) NULL else cand[hit[1L]]
}

#' Resolve one column, preferring an explicit user-supplied name
#'
#' @param data Data frame to search.
#' @param given Character column name supplied by the user, or `NULL`.
#' @param role Name of an entry in `.dynet_aliases`.
#' @param exclude Character vector of column names already claimed.
#' @param arg Argument name to quote in error messages.
#' @return The resolved column name, or `NULL` when nothing matches.
#' @noRd
.resolve_column <- function(data, given, role, exclude = character(),
                            arg = role) {
  if (!is.null(given)) {
    if (!is.character(given) || length(given) != 1L) {
      stop(errorCondition(
        sprintf("`%s` must be a single column name.", arg),
        class = "dynet_bad_input", call = NULL
      ))
    }
    if (!given %in% names(data)) {
      stop(errorCondition(
        sprintf("Column `%s` (given as `%s`) is not in the data. Available: %s",
                given, arg, paste(names(data), collapse = ", ")),
        class = "dynet_missing_column", call = NULL
      ))
    }
    return(given)
  }
  .match_column(data, role, exclude)
}

# ---------------------------------------------------------------------------
# Time parsing
# ---------------------------------------------------------------------------

# Formats attempted for character time columns, in priority order.
.dynet_time_formats <- c(
  "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d",
  "%Y/%m/%d %H:%M:%S", "%Y/%m/%d %H:%M", "%Y/%m/%d",
  "%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M", "%d/%m/%Y",
  "%m/%d/%Y %H:%M:%S", "%m/%d/%Y %H:%M", "%m/%d/%Y",
  "%d-%m-%Y %H:%M:%S", "%d-%m-%Y %H:%M", "%d-%m-%Y",
  "%d %b %Y %H:%M", "%d %B %Y %H:%M", "%d %b %Y", "%d %B %Y"
)

#' Number of seconds in one unit of `time_unit`
#' @param time_unit One of "seconds", "minutes", "hours", "days", "weeks".
#' @return A single numeric.
#' @noRd
.unit_seconds <- function(time_unit) {
  switch(time_unit,
    seconds = 1,
    minutes = 60,
    hours   = 3600,
    days    = 86400,
    weeks   = 604800
  )
}

#' Parse a time column to numeric offsets from a common origin
#'
#' Numeric columns pass through unchanged and carry the unit `"step"`.
#' `Date`, `POSIXct` and character columns are converted to elapsed time
#' since `origin`, expressed in `time_unit`.
#'
#' @param x A numeric, `Date`, `POSIXct`, factor or character vector.
#' @param time_unit One of "auto", "seconds", "minutes", "hours", "days",
#'   "weeks". Ignored for numeric input.
#' @param origin Numeric or date-time origin. `NULL` uses `min(x)`.
#' @return A list with `values` (numeric), `unit` (character) and
#'   `origin` (the value mapped to zero).
#' @noRd
.parse_time <- function(x, time_unit = "auto", origin = NULL) {
  if (is.factor(x)) x <- as.character(x)

  if (is.numeric(x)) {
    if (anyNA(x)) {
      stop(errorCondition("Time columns must not contain NA values.",
                          class = "dynet_bad_input", call = NULL))
    }
    return(list(values = as.numeric(x), unit = "step", origin = 0))
  }

  if (is.character(x)) {
    parsed <- .parse_datetime_strings(x)
  } else if (inherits(x, "POSIXct") || inherits(x, "Date")) {
    parsed <- as.POSIXct(x, tz = "UTC")
  } else {
    stop(errorCondition(
      sprintf("Time column has unsupported type <%s>. Supply numeric, Date, POSIXct or character times.",
              paste(class(x), collapse = "/")),
      class = "dynet_bad_input", call = NULL
    ))
  }

  if (anyNA(parsed)) {
    stop(errorCondition("Time columns must not contain NA values.",
                        class = "dynet_bad_input", call = NULL))
  }

  span <- as.numeric(difftime(max(parsed), min(parsed), units = "secs"))
  unit <- if (identical(time_unit, "auto")) .auto_unit(span) else time_unit
  o <- if (is.null(origin)) min(parsed) else as.POSIXct(origin, tz = "UTC")

  list(
    values = as.numeric(difftime(parsed, o, units = "secs")) /
      .unit_seconds(unit),
    unit   = unit,
    origin = o
  )
}

#' Choose a readable time unit for an observed span
#'
#' Deliberately coarse and deterministic: anything spanning more than three
#' days is reported in days, which is the unit almost all behavioural and
#' educational logs are interpreted in. `"weeks"` is never chosen
#' automatically but may be requested explicitly.
#'
#' @param span_seconds Numeric span in seconds.
#' @return One of "seconds", "minutes", "hours", "days".
#' @noRd
.auto_unit <- function(span_seconds) {
  if (!is.finite(span_seconds) || span_seconds <= 0) return("seconds")
  if (span_seconds < 2 * 60) "seconds"
  else if (span_seconds < 3 * 3600) "minutes"
  else if (span_seconds < 3 * 86400) "hours"
  else "days"
}

#' Parse character date-times against a list of candidate formats
#'
#' The format that parses the most values without producing `NA` wins.
#'
#' @param x Character vector.
#' @return A `POSIXct` vector.
#' @noRd
.parse_datetime_strings <- function(x) {
  trial <- lapply(.dynet_time_formats, function(fmt) {
    as.POSIXct(x, format = fmt, tz = "UTC")
  })
  n_ok <- vapply(trial, function(p) sum(!is.na(p)), integer(1L))
  best <- which.max(n_ok)
  if (n_ok[best] == 0L) {
    stop(errorCondition(
      sprintf("Could not parse time strings such as '%s'. Supply numeric, Date or POSIXct times instead.",
              x[1L]),
      class = "dynet_unparsed_time", call = NULL
    ))
  }
  trial[[best]]
}
