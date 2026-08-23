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

#' Build the time-bin grid for a set of edges
#'
#' Bins are half-open `[lo, hi)` and evenly spaced. The last bin is closed on
#' the right so that an event landing exactly on the final time point is
#' counted rather than silently dropped.
#'
#' @param t_min,t_max Numeric time range.
#' @param interval Bin width.
#' @return A data frame with `bin`, `lo`, `hi` and `time` (the bin midpoint
#'   used as the reported time stamp).
#' @keywords internal
.bins <- function(t_min, t_max, interval) {
  span <- t_max - t_min
  n <- max(1L, as.integer(ceiling(span / interval - 1e-9)))
  lo <- t_min + (seq_len(n) - 1L) * interval
  hi <- lo + interval
  data.frame(bin = seq_len(n), lo = lo, hi = hi, time = lo,
             stringsAsFactors = FALSE)
}

#' Which edges are active in a given bin
#'
#' Two sampling conventions are supported. `"window"` counts an edge whose
#' spell overlaps the bin at all, which loses no event. `"instant"` samples
#' the network at the bin's left edge, matching the point-in-time convention
#' used by `tsna::tSnaStats()` with `aggregate.dur = 0`; an edge that starts
#' and ends between two sample points is invisible to it.
#'
#' Instantaneous events (contact logs, and the final post of a thread) belong
#' to the bin that contains them under either convention.
#'
#' @param enc Encoded edge list from [.encode()].
#' @param lo,hi Bin boundaries.
#' @param last Whether this is the final bin, which is closed on the right.
#' @param sample Either `"window"` or `"instant"`.
#' @return A logical vector, one element per edge.
#' @keywords internal
.active <- function(enc, lo, hi, last = FALSE, sample = "window") {
  inst <- enc$instant
  in_bin <- if (last) {
    enc$start >= lo & enc$start <= hi
  } else {
    enc$start >= lo & enc$start < hi
  }
  out <- if (identical(sample, "instant")) {
    enc$start <= lo & enc$end > lo
  } else {
    enc$start < hi & enc$end > lo
  }
  out[inst] <- in_bin[inst]
  out
}

#' Adjacency matrix for one set of active edges
#'
#' Multi-edges are collapsed by summing weights. Diagonals are left untouched:
#' if the network was built with `loops = TRUE`, self-loops appear on the
#' diagonal exactly as recorded.
#'
#' @param enc Encoded edge list.
#' @param active Logical vector selecting active edges.
#' @param directed Whether to keep edge direction.
#' @param weighted Whether cells hold summed weights or a zero/one indicator.
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
#' @param dn The parent network, for the bin width.
#' @return A data frame of bins from [.bins()].
#' @keywords internal
.grid_for <- function(enc, dn) {
  .bins(min(enc$start), max(enc$end), dn$meta$interval)
}

#' Apply a function across every bin of every session
#'
#' The workhorse behind every time-series verb. `fun` receives the encoding,
#' the active-edge mask and the bin row, and returns either a single value or
#' a named vector of values; the result is stacked into one long frame.
#'
#' @param dn A `dynet` object.
#' @param sessions Session mode.
#' @param fun Function of `(enc, active, bin)`.
#' @param sample Sampling convention passed to [.active()].
#' @param node_level Whether `fun` returns one value per vertex.
#' @return A long data frame with `session`, `time`, optionally `node`, plus
#'   `measure` and `value`.
#' @keywords internal
.over_bins <- function(dn, sessions, fun, sample = "window",
                       node_level = FALSE) {
  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    grid <- .grid_for(enc, dn)
    n_bin <- nrow(grid)
    per_bin <- lapply(seq_len(n_bin), function(k) {
      act <- .active(enc, grid$lo[k], grid$hi[k], last = k == n_bin,
                     sample = sample)
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
