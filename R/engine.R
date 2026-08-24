#' Validate arguments, raising a classed condition
#'
#' Used exactly like a named `.check()`: the name of each argument is the
#' message shown when it fails. Unlike `.check()` the error carries the
#' class `dynet_bad_input`, so a caller or a test can catch it precisely
#' rather than matching on message text.
#'
#' @param ... Named logical conditions.
#' @return `TRUE`, invisibly.
#' @keywords internal
.check <- function(...) {
  conds <- list(...)
  ok <- vapply(conds, isTRUE, logical(1L))
  if (all(ok)) return(invisible(TRUE))
  stop(errorCondition(paste(names(conds)[!ok], collapse = "\n"),
                      class = "dynet_bad_input", call = NULL))
}

# ===========================================================================
# Internal compute engine: encoding, time bins, activity, adjacency
# ===========================================================================
# Nothing in this file is exported. Vertex names are turned into integers
# here and turned back into names before any result leaves the package.

#' Validate a dynet object and its session argument
#' @param dn Object to check.
#' @param sessions Session handling mode.
#' @return The matched session mode, invisibly.
#' @keywords internal
.check_dynet <- function(dn, sessions = "bounded") {
  if (!inherits(dn, "dynet")) {
    stop(errorCondition(
      "`dn` must be a temporal network built with dynet().",
      class = "dynet_bad_input", call = NULL))
  }
  sessions <- match.arg(sessions, c("bounded", "collapse", "separate"))
  if (identical(sessions, "separate") && is.null(dn$meta$sessions)) {
    stop(errorCondition(
      "sessions = \"separate\" needs a session column; build the network with `session = `.",
      class = "dynet_no_sessions", call = NULL))
  }
  invisible(sessions)
}

#' Integer-encode a canonical edge frame against the vertex table
#'
#' @param dn A `dynet` object.
#' @param rows Optional row subset of the spell table.
#' @return A list with integer `from`/`to`, numeric `start`/`end`/`weight`,
#'   logical `instant`, and the vertex `names`.
#' @keywords internal
.encode <- function(dn, rows = NULL) {
  e <- if (is.null(rows)) dn$spells else dn$spells[rows, , drop = FALSE]
  nm <- dn$nodes$name
  list(
    from    = match(e$from, nm),
    to      = match(e$to, nm),
    start   = e$start,
    end     = e$end,
    weight  = e$weight,
    session = e$session,
    instant = e$end <= e$start,
    names   = nm,
    n       = length(nm)
  )
}


# ---------------------------------------------------------------------------
# The measurement grid: start, end, step, window
# ---------------------------------------------------------------------------
# Four arguments describe when a temporal network is measured, following the
# convention of `tsna::tSnaStats()`:
#
#   start   first measurement point          (tsna: start)
#   end     last measurement point           (tsna: end)
#   step    spacing between measurements     (tsna: time.interval)
#   window  width each measurement covers    (tsna: aggregate.dur)
#
# Separating `step` from `window` is what makes a rolling window expressible.
# `window == step` tiles the period into disjoint bins; `window > step` slides
# an overlapping window along it; `window == 0` samples the network at an
# instant, exactly as `tsna::tSnaStats(aggregate.dur = 0)` does.

#' Convert a user-supplied time to the network's internal numeric scale
#'
#' Times inside a `dynet` are numeric offsets from `dn$meta$origin`, measured
#' in `dn$meta$time_unit`. A network built from `Date` or `POSIXct` input may
#' therefore be addressed with a date, which is converted here; a network
#' built from plain numbers must be addressed with numbers.
#'
#' @param v The value supplied by the caller, or `NULL`.
#' @param dn A `dynet` object.
#' @param arg Argument name, used in the error message.
#' @return A single number, or `NULL` when `v` was `NULL`.
#' @keywords internal
.as_time <- function(v, dn, arg) {
  if (is.null(v)) return(NULL)
  if (length(v) != 1L) {
    stop(errorCondition(sprintf("`%s` must be a single time point.", arg),
                        class = "dynet_bad_input", call = NULL))
  }
  dated <- inherits(v, "Date") || inherits(v, "POSIXt")
  origin <- dn$meta$origin
  if (dated) {
    if (!inherits(origin, "POSIXt")) {
      stop(errorCondition(sprintf(
        "`%s` was given as a date, but this network's times are plain numbers.",
        arg), class = "dynet_bad_input", call = NULL))
    }
    secs <- as.numeric(as.POSIXct(v, tz = "UTC")) - as.numeric(origin)
    return(secs / .unit_seconds(dn$meta$time_unit))
  }
  if (!is.numeric(v) || !is.finite(v)) {
    stop(errorCondition(sprintf("`%s` must be a single finite number.", arg),
                        class = "dynet_bad_input", call = NULL))
  }
  as.numeric(v)
}

#' Resolve a per-hop traversal duration
#'
#' Numeric values are expressed in the network's stored time unit. A
#' `difftime` is converted for calendar networks; a numeric-step network has no
#' calendar unit with which to interpret it.
#'
#' @param value Requested traversal duration.
#' @param dn A `dynet` object.
#' @return One finite nonnegative numeric duration in network units.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.as_traversal_time(1, dn)
#' @keywords internal
.as_traversal_time <- function(value, dn) {
  if (inherits(value, "Date") || inherits(value, "POSIXt")) {
    stop(errorCondition(
      "`traversal_time` is a duration, not a date or date-time.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (inherits(value, "difftime")) {
    if (length(value) != 1L || is.na(value)) {
      stop(errorCondition(
        "`traversal_time` must be one finite nonnegative duration.",
        class = "dynet_bad_input", call = NULL
      ))
    }
    if (identical(dn$meta$time_unit, "step")) {
      stop(errorCondition(
        "A numeric-step network needs `traversal_time` in numeric steps, not `difftime`.",
        class = "dynet_bad_input", call = NULL
      ))
    }
    value <- as.numeric(value, units = "secs") /
      .unit_seconds(dn$meta$time_unit)
  }
  if (!is.numeric(value) || length(value) != 1L ||
      !is.finite(value) || value < 0) {
    stop(errorCondition(
      "`traversal_time` must be one finite nonnegative duration.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  as.numeric(value)
}

#' Resolve and validate the four measurement-grid arguments
#'
#' Called once at the top of every verb that measures over time, so the
#' contract is checked in one place rather than at each use.
#'
#' `start` and `end` are left `NULL` when the caller did not supply them, so
#' that each session can fall back to its own observed range; an explicit
#' value applies to every session alike.
#'
#' @param dn A `dynet` object.
#' @param start,end Measurement range, or `NULL` for the observed range.
#' @param step Spacing between measurements, or `NULL` for the network's
#'   construction interval.
#' @param window Width of each measurement, or `NULL` for `step`.
#' @return A list with `start`, `end`, `step` and `window`.
#' @keywords internal
.window_spec <- function(dn, start = NULL, end = NULL, step = NULL,
                         window = NULL) {
  start <- .as_time(start, dn, "start")
  end   <- .as_time(end,   dn, "end")
  step  <- step %||% dn$meta$interval
  .check(
    "`step` must be a single positive number." =
      is.numeric(step) && length(step) == 1L && is.finite(step) && step > 0,
    "`window` must be a single non-negative number." =
      is.null(window) || (is.numeric(window) && length(window) == 1L &&
                          is.finite(window) && window >= 0)
  )
  window <- as.numeric(window %||% step)
  if (!is.null(start) && !is.null(end) && end < start) {
    stop(errorCondition(
      sprintf("`end` (%s) is earlier than `start` (%s).", end, start),
      class = "dynet_bad_input", call = NULL))
  }
  list(start = start, end = end, step = as.numeric(step), window = window)
}

#' Translate the retired sampling argument to a window width
#'
#' `sample = "instant"` was the pre-0.3 spelling of `window = 0`. Keep it as
#' a deprecated bridge so existing analysis scripts do not fail merely because
#' the measurement-grid API became more expressive.
#'
#' @param window A window width supplied through the current API.
#' @param sample `NULL`, `"window"` or `"instant"`.
#' @return `window`, possibly translated to zero.
#' @keywords internal
.legacy_sample <- function(window = NULL, sample = NULL) {
  if (is.null(sample)) return(window)
  sample <- match.arg(sample, c("window", "instant"))
  warning("`sample` is deprecated; use `window = 0` for point sampling and a positive `window` for window sampling.",
          call. = FALSE)
  if (identical(sample, "instant")) {
    if (!is.null(window) && !isTRUE(all.equal(as.numeric(window), 0))) {
      stop(errorCondition(
        "`sample = \"instant\"` conflicts with a positive `window`.",
        class = "dynet_bad_input", call = NULL))
    }
    return(0)
  }
  if (!is.null(window) && is.numeric(window) && length(window) == 1L &&
      is.finite(window) && window == 0) {
    stop(errorCondition(
      "`sample = \"window\"` conflicts with `window = 0`.",
      class = "dynet_bad_input", call = NULL))
  }
  window
}

#' The last measurement point that still begins inside the observed period
#'
#' The default `end`. Chosen so that windows of width `step` tile the period
#' without a trailing window that opens at the very moment the data stop.
#'
#' @param t_min,t_max Observed time range.
#' @param step Spacing between measurements.
#' @return A single number.
#' @keywords internal
.default_end <- function(t_min, t_max, step) {
  span <- t_max - t_min
  n <- max(1L, as.integer(ceiling(span / step - 1e-9)))
  t_min + (n - 1L) * step
}

#' Build the measurement grid
#'
#' Measurements are taken at `start, start + step, ...` up to `end`, and each
#' one covers `[lo, hi)` with `hi = lo + window`. Windows overlap whenever
#' `window > step`, are disjoint when the two are equal, and degenerate to
#' sampling the network at a point when `window` is zero.
#'
#' On the default grid the final window is closed on the right, so an event
#' landing exactly on the last observed time is counted rather than silently
#' dropped. A grid whose `end` the caller supplied is taken literally instead,
#' as `tsna::tSnaStats()` does -- which is what makes a truncated range an
#' exact subset of the full series rather than an almost-subset.
#'
#' @param t_min,t_max Observed time range, used for whichever of `start` and
#'   `end` the caller left to the default.
#' @param spec A resolved grid from [.window_spec()].
#' @return A data frame with `bin`, `lo`, `hi`, `time` (the point at which the
#'   measurement is reported, which is the window's left edge) and `closed`
#'   (whether the window includes its right endpoint).
#' @keywords internal
.bins <- function(t_min, t_max, spec) {
  start <- spec$start %||% t_min
  end   <- spec$end   %||% .default_end(t_min, t_max, spec$step)
  # A grid whose end precedes its start still yields the single measurement
  # at `start`, so that a verb never returns zero rows for a valid network.
  lo <- if (end < start) start else seq(from = start, to = end, by = spec$step)
  closed <- rep(FALSE, length(lo))
  if (is.null(spec$end)) closed[length(lo)] <- TRUE
  data.frame(bin = seq_along(lo), lo = lo, hi = lo + spec$window, time = lo,
             closed = closed, stringsAsFactors = FALSE)
}

#' Which edges are active in a given window
#'
#' A spell counts when it overlaps the window at all, which loses no event.
#' A zero-width window (`spec$window == 0`) instead samples the network at the
#' window's time point, matching `tsna::tSnaStats(aggregate.dur = 0)`; an edge
#' that starts and ends between two sample points is invisible to it.
#'
#' Instantaneous events -- contact logs, and the final post of a thread --
#' belong to the window that contains them under either rule.
#'
#' @param enc Encoded edge list from [.encode()].
#' @param lo,hi Window boundaries.
#' @param last Whether the window is closed on the right.
#' @param window The window width, which selects the rule.
#' @return A logical vector, one element per edge.
#' @keywords internal
.active <- function(enc, lo, hi, last = FALSE, window = NULL) {
  inst <- enc$instant
  at_point <- is.numeric(window) && length(window) == 1L && window == 0
  in_bin <- if (last || at_point) {
    enc$start >= lo & enc$start <= hi
  } else {
    enc$start >= lo & enc$start < hi
  }
  out <- if (at_point) {
    enc$start <= lo & enc$end > lo
  } else {
    enc$start < hi & enc$end > lo
  }
  out[inst] <- in_bin[inst]
  out
}

#' Adjacency matrix for one set of active edges
#'
#' Multi-edges are collapsed by summing. With `weighted = TRUE` a cell holds
#' the summed edge weights; otherwise it holds the *number of active spells*
#' joining the pair, which every measure that wants presence rather than
#' volume reduces with [.binary()]. Diagonals are left untouched: if the
#' network was built with `loops = TRUE`, self-loops appear on the diagonal
#' exactly as recorded.
#'
#' @param enc Encoded edge list.
#' @param active Logical vector selecting active edges.
#' @param directed Whether to keep edge direction.
#' @param weighted Whether cells hold summed weights or spell counts.
#' @return A square numeric matrix with vertex names on both margins.
#' @keywords internal
.adjacency <- function(enc, active, directed, weighted = FALSE) {
  n <- enc$n
  a <- matrix(0, n, n, dimnames = list(enc$names, enc$names))
  if (!any(active)) return(a)
  i <- enc$from[active]
  j <- enc$to[active]
  w <- if (weighted) enc$weight[active] else rep(1, length(i))
  # tabulate() over the linear cell index is far faster than a loop and keeps
  # multi-edge accumulation exact.
  cell <- (j - 1L) * n + i
  agg <- tapply(w, cell, sum)
  a[as.integer(names(agg))] <- as.numeric(agg)
  if (!directed) {
    a <- a + t(a)
    if (!weighted) a[a > 0] <- 1
  }
  a
}

#' Split a network into per-session encodings
#'
#' @param dn A `dynet` object.
#' @param sessions Session mode.
#' @return A named list of encodings. Length one and named `"all"` unless
#'   `sessions = "separate"`.
#' @keywords internal
.split_sessions <- function(dn, sessions) {
  if (!identical(sessions, "separate")) {
    return(list(all = .encode(dn)))
  }
  idx <- split(seq_len(nrow(dn$spells)), dn$spells$session)
  lapply(idx, function(rows) .encode(dn, rows))
}

#' The time grid an encoding should be measured on
#' @param enc Encoded edge list.
#' @param dn The parent network, for the default grid.
#' @param spec A resolved grid from [.window_spec()]; the network's own
#'   construction interval is used when absent.
#' @return A data frame of windows from [.bins()].
#' @keywords internal
.grid_for <- function(enc, dn, spec = NULL) {
  spec <- spec %||% .window_spec(dn)
  .bins(min(enc$start), max(enc$end), spec)
}

#' Apply a function across every window of every session
#'
#' The workhorse behind every time-series verb. `fun` receives the encoding,
#' the active-edge mask and the window row, and returns either a single value
#' or a named vector of values; the result is stacked into one long frame.
#'
#' @param dn A `dynet` object.
#' @param sessions Session mode.
#' @param fun Function of `(enc, active, bin)`.
#' @param spec A resolved measurement grid from [.window_spec()].
#' @param node_level Whether `fun` returns one value per vertex.
#' @return A long data frame with `session`, `time`, optionally `node`, plus
#'   `measure` and `value`.
#' @keywords internal
.over_bins <- function(dn, sessions, fun, spec = NULL, node_level = FALSE) {
  spec  <- spec %||% .window_spec(dn)
  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    grid <- .grid_for(enc, dn, spec)
    n_bin <- nrow(grid)
    per_bin <- lapply(seq_len(n_bin), function(k) {
      act <- .active(enc, grid$lo[k], grid$hi[k], last = grid$closed[k],
                     window = spec$window)
      val <- fun(enc, act, grid[k, , drop = FALSE])
      if (node_level) {
        data.frame(session = label, time = grid$time[k],
                   node = enc$names, measure = rep(names(val), each = enc$n),
                   value = unlist(val, use.names = FALSE),
                   stringsAsFactors = FALSE)
      } else {
        data.frame(session = label, time = grid$time[k],
                   measure = names(val), value = unname(val),
                   stringsAsFactors = FALSE)
      }
    })
    do.call(rbind, per_bin)
  }, parts, names(parts))
  out <- do.call(rbind, frames)
  rownames(out) <- NULL
  out
}
