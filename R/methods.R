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
#' Temporal density is observed edge duration against the maximum duration
#' possible, and it is the honest figure for how much of the observation
#' window the network was actually connected for.
#'
#' @param object A temporal network from [dynet()].
#' @param ... Ignored.
#'
#' @return A `data.frame` with columns `property` and `value`, one row per
#'   property.
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
  possible_pairs <- if (object$directed) n * (n - 1) else n * (n - 1) / 2
  observed <- sum(e$end - e$start)
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
      format(round(if (possible_pairs > 0 && span > 0)
        observed / (possible_pairs * span) else NA_real_, 4)),
      if (is.null(m$sessions)) "none" else format(length(m$sessions)),
      {
        a <- setdiff(names(object$nodes), c("id", "label", "name", "x", "y"))
        if (length(a) == 0L) "none" else paste(a, collapse = ", ")
      }
    ),
    stringsAsFactors = FALSE
  )
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
