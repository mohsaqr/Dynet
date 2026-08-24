# ===========================================================================
# Methods for the dynet object itself
# ===========================================================================

#' Tidy tables from a temporal network
#'
#' @param x A temporal network from [dynet()].
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param what `"edges"` for the edge spells, `"nodes"` for the vertex table,
#'   `"bins"` for the time grid the measure verbs use, `"network"` for the
#'   aggregate edge list cograph renders.
#' @param ... Ignored.
#'
#' @return A plain `data.frame`. For `"edges"`: one row per edge spell with
#'   `from`, `to` (vertex names, never indices), `start`, `end`, `duration`,
#'   `weight` and any session, thread or group label. For `"nodes"`: one row
#'   per vertex with `name` and any attributes supplied. For `"bins"`: one row
#'   per time bin with `bin`, `lo`, `hi` and `time`. For `"network"`: one row
#'   per vertex pair with `from`, `to` (again by name) and the summed
#'   `weight`.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' head(as.data.frame(dn))
#' as.data.frame(dn, what = "nodes")
#'
#' @export
as.data.frame.dynet <- function(x, row.names = NULL, optional = FALSE,
                                what = c("edges", "nodes", "bins",
                                         "network"), ...) {
  what <- match.arg(what)
  out <- switch(what,
    edges = {
      e <- x$spells
      e$duration <- e$end - e$start
      front <- c("from", "to", "start", "end", "duration", "weight")
      e <- e[, c(front, setdiff(names(e), front)), drop = FALSE]
      if (all(is.na(e$session))) e$session <- NULL
      e
    },
    nodes = {
      n <- x$nodes
      n[, setdiff(names(n), c("id", "label", "x", "y")), drop = FALSE]
    },
    bins  = .bins(x$meta$time_range[["start"]], x$meta$time_range[["end"]],
                  .window_spec(x)),
    network = {
      nm <- x$nodes$name
      data.frame(from = nm[x$edges$from], to = nm[x$edges$to],
                 weight = x$edges$weight, stringsAsFactors = FALSE)
    }
  )
  rownames(out) <- NULL
  out
}

#' Print a temporal network
#'
#' @param x A temporal network from [dynet()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet <- function(x, ...) {
  m <- x$meta
  cat(sprintf("# Temporal network (%s format, %s) | a cograph netobject\n",
              m$format, if (x$directed) "directed" else "undirected"))
  cat(sprintf("# %d vertices | %d edge spells | %d distinct pairs\n",
              nrow(x$nodes), nrow(x$spells), nrow(x$edges)))
  cat(sprintf("# observed from %s to %s %s, binned every %s\n",
              format(m$time_range[["start"]]), format(m$time_range[["end"]]),
              m$time_unit, format(m$interval)))
  if (!is.null(m$sessions)) {
    cat(sprintf("# %d sessions: %s\n", length(m$sessions),
                paste(utils::head(m$sessions, 5), collapse = ", ")))
  }
  attrs <- setdiff(names(x$nodes), c("id", "label", "name", "x", "y"))
  if (length(attrs) > 0L) {
    cat(sprintf("# vertex attributes: %s\n", paste(attrs, collapse = ", ")))
  }
  cat("\n")
  print(utils::head(as.data.frame(x), 6), row.names = FALSE)
  if (nrow(x$spells) > 6L) {
    cat(sprintf("# %d more spells. summary() describes the network; plot() draws it.\n",
                nrow(x$spells) - 6L))
  }
  invisible(x)
}

#' Describe a temporal network
#'
#' @description
#' A tidy description of the whole network, one row per property. Two
#' densities are reported and they answer different questions. Snapshot
#' density is the mean over time bins of realised against possible edges.
#' Temporal density is the proportion of all possible relational exposure
#' occupied during the observation window. Overlapping and duplicate spells
#' for the same ordered pair, or dyad in an undirected network, are unioned
#' before their duration is counted.
#'
#' @param object A temporal network from [dynet()].
#' @param ... Ignored.
#'
#' @return A `data.frame` with columns `property` and `value`, one row per
#'   property.
#'
#' @details
#' Let \eqn{A_q} be the union of the active intervals for relational
#' opportunity \eqn{q}, and let \eqn{T} be the stored observation span. Then
#' temporal density is
#' \deqn{\rho = \frac{\sum_q |A_q|}{M T},}
#' where \eqn{M = n(n-1)} for directed networks and
#' \eqn{M = n(n-1)/2} for undirected networks. Self-loops, weights, session
#' labels, and zero-duration contacts do not add exposure. A network with no
#' possible non-loop pair or a zero observation span has undefined temporal
#' density and reports `NA`.
#'
#' This is an occupancy definition. Unlike summing spell durations, it remains
#' in `[0, 1]` when the same relation has overlapping or duplicated spells.
#'
#' @references
#' Bender-deMoll, S., & Morris, M. (2025). *tsna: Tools for Temporal Social
#' Network Analysis*. R package version 0.3.6.
#'
#' Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
#' 519(3), 97-125.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' summary(dn)
#'
#' @export
summary.dynet <- function(object, ...) {
  m <- object$meta
  e <- object$spells
  n <- nrow(object$nodes)
  span <- m$time_range[["end"]] - m$time_range[["start"]]
  snap <- dyn_metrics(object, measure = "density", sessions = "collapse")

  data.frame(
    property = c("format", "directed", "vertices", "edge spells",
                 "distinct pairs", "time unit", "observed from", "observed to",
                 "span", "bin width", "time bins",
                 "mean snapshot density", "temporal density",
                 "sessions", "vertex attributes"),
    value = c(
      m$format,
      if (object$directed) "yes" else "no",
      format(n), format(nrow(e)),
      format(nrow(object$edges)),
      m$time_unit,
      format(m$time_range[["start"]]), format(m$time_range[["end"]]),
      format(span), format(m$interval),
      format(m$n_bins),
      format(round(mean(snap$value), 4)),
      format(round(.temporal_density(object), 4)),
      if (is.null(m$sessions)) "none" else format(length(m$sessions)),
      {
        a <- setdiff(names(object$nodes), c("id", "label", "name", "x", "y"))
        if (length(a) == 0L) "none" else paste(a, collapse = ", ")
      }
    ),
    stringsAsFactors = FALSE
  )
}

#' Union the duration of one relation's intervals
#'
#' @param start,end Numeric vectors containing parallel interval endpoints.
#' @return The total length covered by at least one positive-duration interval.
#' @examples
#' Dynet:::.union_duration(c(0, 2, 6), c(4, 7, 10))
#' @keywords internal
.union_duration <- function(start, end) {
  .check(
    "`start` and `end` must be numeric vectors." =
      is.numeric(start) && is.numeric(end),
    "`start` and `end` must have the same length." =
      length(start) == length(end),
    "Interval endpoints must be finite." =
      all(is.finite(start)) && all(is.finite(end)),
    "Every interval must end at or after it starts." = all(end >= start)
  )

  positive <- end > start
  if (!any(positive)) return(0)
  start <- start[positive]
  end <- end[positive]
  interval_order <- order(start, end)
  start <- start[interval_order]
  end <- end[interval_order]

  running_end <- cummax(end)
  begins_union <- c(TRUE, start[-1L] > running_end[-length(running_end)])
  union_start <- start[begins_union]
  start_index <- which(begins_union)
  end_index <- c(start_index[-1L] - 1L, length(running_end))

  sum(running_end[end_index] - union_start)
}

#' Temporal occupancy over every possible relation
#'
#' @param dn A temporal network from [dynet()].
#' @return A numeric scalar in `[0, 1]`, or `NA` when the denominator is zero.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.temporal_density(dn)
#' @keywords internal
.temporal_density <- function(dn) {
  .check_dynet(dn, sessions = "collapse")
  bounds <- dn$meta$time_range
  span <- bounds[["end"]] - bounds[["start"]]
  n <- nrow(dn$nodes)
  possible_pairs <- if (dn$directed) n * (n - 1L) else choose(n, 2L)
  if (possible_pairs == 0L || span <= 0) return(NA_real_)

  spells <- dn$spells
  spells <- spells[spells$from != spells$to, , drop = FALSE]
  if (nrow(spells) == 0L) return(0)

  start <- pmax(spells$start, bounds[["start"]])
  end <- pmin(spells$end, bounds[["end"]])
  positive <- end > start
  if (!any(positive)) return(0)
  spells <- spells[positive, , drop = FALSE]
  start <- start[positive]
  end <- end[positive]

  from_id <- match(spells$from, dn$nodes$name)
  to_id <- match(spells$to, dn$nodes$name)
  if (!dn$directed) {
    left <- pmin(from_id, to_id)
    right <- pmax(from_id, to_id)
    from_id <- left
    to_id <- right
  }
  pair <- (to_id - 1L) * n + from_id
  intervals <- split(seq_along(pair), pair)
  occupied <- sum(vapply(intervals, function(rows) {
    .union_duration(start[rows], end[rows])
  }, numeric(1L)))

  occupied / (possible_pairs * span)
}

#' Print time-respecting paths
#'
#' @param x A `dynet_paths` from [dyn_paths()].
#' @param n Number of rows to show.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet_paths <- function(x, n = 12L, ...) {
  cat(sprintf("# Time-respecting paths %s %s, from t = %s\n",
              if (identical(attr(x, "direction"), "forward")) "from" else "into",
              sQuote(attr(x, "source")), format(attr(x, "origin"))))
  cat(sprintf("# reaches %d of %d other vertices | time in %s\n",
              sum(x$reachable) - 1L, nrow(x) - 1L, attr(x, "time_unit")))
  print(utils::head(as.data.frame(x), n), row.names = FALSE)
  if (nrow(x) > n) {
    cat(sprintf("# %d more rows. summary() aggregates them; plot() draws the tree.\n",
                nrow(x) - n))
  }
  invisible(x)
}

#' Tidy data frame of time-respecting paths
#' @param x A `dynet_paths`.
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param ... Ignored.
#' @return A plain `data.frame`, one row per vertex.
#' @export
as.data.frame.dynet_paths <- function(x, row.names = NULL, optional = FALSE, ...) {
  attributes(x) <- list(names = names(x), row.names = seq_len(nrow(x)),
                        class = "data.frame")
  x
}

#' Summarise time-respecting paths
#'
#' @param object A `dynet_paths`.
#' @param ... Ignored.
#' @return A one-row-per-property `data.frame` with the reachable count, the
#'   reachable share, and the median and maximum latency and hop count.
#' @export
summary.dynet_paths <- function(object, ...) {
  r <- object$reachable & object$node != attr(object, "source")
  lat <- object$latency[r]
  hop <- object$n_hops[r]
  data.frame(
    property = c("source", "direction", "reachable", "reachable share",
                 "median latency", "max latency", "median hops", "max hops"),
    value = c(attr(object, "source"), attr(object, "direction"),
              format(sum(r)), format(round(sum(r) / (nrow(object) - 1), 3)),
              format(if (any(r)) stats::median(lat) else NA_real_),
              format(if (any(r)) max(lat) else NA_real_),
              format(if (any(r)) stats::median(hop) else NA_real_),
              format(if (any(r)) max(hop) else NA_real_)),
    stringsAsFactors = FALSE
  )
}
