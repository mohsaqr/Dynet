# ===========================================================================
# Methods for the dynet object itself
# ===========================================================================

#' Tidy tables from a temporal network
#'
#' @param x A temporal network from [dynet()].
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param what `"edges"` for raw edge spells, `"observed_edges"` for derived
#'   observation fragments, `"observations"` for canonical observed support,
#'   `"vertex_spells"` for canonical declared vertex activity, `"nodes"` for
#'   the vertex table, `"bins"` for the measurement grid, or `"network"` for
#'   the aggregate edge list cograph renders.
#' @param measure Optional centrality measures to annotate the vertex table
#'   with, valid only for `what = "nodes"`. Each becomes one column holding the
#'   value over the whole observed period, so the vertex table can be filtered
#'   or ranked without a second call. Any measure [dyn_centrality()] accepts at
#'   snapshot scope is allowed, plus `"indegree"` and `"outdegree"`.
#' @param sessions,start,end Passed to [dyn_centrality()] when `measure` is
#'   given, and ignored otherwise.
#' @param ... Ignored.
#'
#' @return A plain `data.frame`. `"edges"` returns one unchanged raw spell.
#'   Explicit interval censor columns are retained as `onset_censored` and
#'   `terminus_censored` on raw edges and copied unchanged to fragments.
#'   `"observations"` returns canonical `observation`, `start`, `end`,
#'   `duration`, and `instant` components. `"observed_edges"` returns derived
#'   fragments with `raw_spell`, `observation`, `fragment`, raw and observed
#'   endpoints, and strict left/right administrative censor flags in addition
#'   to edge identity, weight, and session. `"vertex_spells"` returns maximal
#'   declared activity components with stable IDs, half-open positive spells,
#'   exact points, sessions, and explicit raw censor state. Undeclared vertices
#'   are implicit static and do not receive synthetic rows. `"nodes"` returns
#'   names and supplied attributes; `"bins"` returns measurement windows
#'   (component-qualified for discontinuous observation); and `"network"`
#'   returns aggregate named pairs with summed weight.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' head(as.data.frame(dn))
#' as.data.frame(dn, what = "nodes")
#' as.data.frame(dn, what = "vertex_spells")
#'
#' # Annotate the vertex table so it can be filtered without a second call.
#' busy <- as.data.frame(dn, what = "nodes",
#'                       measure = c("degree", "indegree", "outdegree"))
#' subset(busy, degree > 15)
#'
#' @export
as.data.frame.dynet <- function(x, row.names = NULL, optional = FALSE,
                                what = c("edges", "nodes", "bins",
                                         "network", "observations",
                                         "observed_edges",
                                         "vertex_spells"),
                                measure = NULL,
                                sessions = c("bounded", "collapse",
                                             "separate"),
                                start = NULL, end = NULL, ...) {
  what <- match.arg(what)
  if (!is.null(measure) && !identical(what, "nodes")) {
    stop(errorCondition(
      sprintf("`measure` annotates the vertex table; it has no meaning for `what = \"%s\"`.",
              what),
      class = "dynet_bad_input", call = NULL))
  }
  out <- switch(what,
    edges = {
      e <- x$spells
      e$duration <- e$end - e$start
      front <- c("from", "to", "start", "end", "duration", "weight")
      e <- e[, c(front, setdiff(names(e), front)), drop = FALSE]
      e$.raw_spell <- NULL
      if (!identical(x$meta$raw_censoring, "explicit")) {
        e$onset_censored <- NULL
        e$terminus_censored <- NULL
      }
      if (all(is.na(e$session))) e$session <- NULL
      e
    },
    observed_edges = {
      e <- .observed_fragments(x)
      e$duration <- e$end - e$start
      if (!identical(x$meta$raw_censoring, "explicit")) {
        e$onset_censored <- NULL
        e$terminus_censored <- NULL
      }
      if (all(is.na(e$session))) e$session <- NULL
      e
    },
    observations = {
      e <- .observation_table(x)
      if (is.null(e)) {
        bounds <- x$meta$time_range
        e <- data.frame(
          observation = 1L, start = bounds[["start"]], end = bounds[["end"]],
          duration = bounds[["end"]] - bounds[["start"]],
          instant = bounds[["start"]] == bounds[["end"]]
        )
      }
      e
    },
    vertex_spells = x$vertex_spells %||% .empty_vertex_spells(),
    nodes = {
      n <- x$nodes
      n <- n[, setdiff(names(n), c("id", "label", "x", "y")), drop = FALSE]
      if (is.null(measure)) n else
        .annotate_nodes(x, n, measure, match.arg(sessions), start, end)
    },
    bins  = .grid_for(.encode(x), x, .window_spec(x)),
    network = {
      nm <- x$nodes$name
      data.frame(from = nm[x$edges$from], to = nm[x$edges$to],
                 weight = x$edges$weight, stringsAsFactors = FALSE)
    }
  )
  rownames(out) <- NULL
  out
}

#' Widen whole-period centrality onto the vertex table
#'
#' One column per measure, valued over a single window covering the observed
#' period, so a caller can rank or filter vertices with `subset()` instead of
#' reshaping a long measure frame by hand. `"indegree"` and `"outdegree"` are
#' spellings of `degree` under `mode`, which the measure vocabulary does not
#' otherwise expose at node level.
#'
#' @param dn A `dynet` object.
#' @param nodes The plain vertex table to annotate.
#' @param measure Character vector of measures.
#' @param sessions Session mode.
#' @param start,end Optional measurement bounds.
#' @return `nodes` with one added column per measure, and a leading `session`
#'   column when sessions are reported separately.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.annotate_nodes(dn, as.data.frame(dn, what = "nodes"),
#'                         "degree", "bounded", NULL, NULL)
#' @keywords internal
.annotate_nodes <- function(dn, nodes, measure, sessions, start, end) {
  .check("`measure` must be a character vector of measure names." =
           is.character(measure) && length(measure) && !anyNA(measure))
  measure <- unique(measure)
  modes <- c(indegree = "in", outdegree = "out")
  columns <- lapply(measure, function(m) {
    directed_degree <- m %in% names(modes)
    long <- as.data.frame(dyn_centrality(
      dn, measure = if (directed_degree) "degree" else m,
      mode = if (directed_degree) modes[[m]] else "all",
      sessions = sessions, start = start, end = end, window = "all"
    ))
    keys <- intersect(c("session", "node"), names(long))
    out <- long[, c(keys, "value"), drop = FALSE]
    names(out)[match("value", names(out))] <- m
    out
  })
  wide <- Reduce(function(a, b)
    merge(a, b, by = intersect(names(a), names(b)), all = TRUE, sort = FALSE),
    columns)
  out <- merge(nodes, wide, by.x = "name", by.y = "node", all.x = TRUE,
               sort = FALSE)
  front <- intersect(c("session", "name"), names(out))
  out <- out[, c(front, setdiff(names(out), front)), drop = FALSE]
  key <- if ("session" %in% names(out)) order(out$session, out$name) else
    order(match(out$name, nodes$name))
  out <- out[key, , drop = FALSE]
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
#' Let \eqn{Y_q(t)} indicate that both endpoints of relational opportunity
#' \eqn{q} are eligible at positive observed time \eqn{t}, and let
#' \eqn{E_q(t)} indicate binary union edge activity. Temporal density is
#' \deqn{\rho = \frac{\sum_q \int Y_q(t)E_q(t)dt}
#'                         {\sum_q \int Y_q(t)dt}.}
#' Directed opportunities are ordered; undirected opportunities are unordered.
#' The integrals are evaluated exactly over observation, vertex, and edge change
#' points. Self-loops, weights, session labels, duplicate spells, genuine
#' points, and observation gaps do not add exposure. A network with no positive
#' time containing two coeligible distinct vertices has undefined temporal
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
#' Latapy, M., Viard, T., & Magnien, C. (2018). Stream graphs and link streams
#' for the modeling of interactions over time. *Social Network Analysis and
#' Mining*, 8, 61.
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
  snap <- metrics(object, measure = "density", sessions = "collapse")

  out <- data.frame(
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
  attr(out, "vertex_population") <- "eligible_at_time"
  attr(out, "opportunity_domain") <- if (object$directed) {
    "eligible_nonloop_ordered_pairs"
  } else {
    "eligible_nonloop_unordered_dyads"
  }
  attr(out, "risk_clock") <- "positive_observed_time"
  attr(out, "occupancy") <- "binary_pair_union"
  attr(out, "risk_integration") <- "exact_change_point"
  attr(out, "instantaneous_exposure") <- "zero"
  attr(out, "session_aggregation") <-
    "calendar_union_after_session_erasure"
  out
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

#' Enumerate nonloop relational opportunities
#' @param n Number of vertices.
#' @param directed Whether opportunities are ordered.
#' @return A data frame with integer `from`, `to`, and collision-free `key`.
#' @examples
#' Dynet:::.relational_opportunities(3, directed = TRUE)
#' @keywords internal
.relational_opportunities <- function(n, directed) {
  if (n < 2L) {
    return(data.frame(from = integer(), to = integer(), key = integer()))
  }
  pairs <- expand.grid(
    from = seq_len(n), to = seq_len(n), KEEP.OUT.ATTRS = FALSE
  )
  pairs <- if (directed) {
    pairs[pairs$from != pairs$to, , drop = FALSE]
  } else pairs[pairs$from < pairs$to, , drop = FALSE]
  pairs$key <- (pairs$from - 1L) * n + pairs$to
  rownames(pairs) <- NULL
  pairs
}

#' Encode a relational pair without string concatenation
#' @param from,to Integer endpoint vectors.
#' @param n Fixed vertex count.
#' @param directed Whether endpoint order is meaningful.
#' @return Integer pair keys matching [.relational_opportunities()].
#' @examples
#' Dynet:::.relational_pair_key(c(1L, 2L), c(2L, 1L), 2L, FALSE)
#' @keywords internal
.relational_pair_key <- function(from, to, n, directed) {
  if (!directed) {
    left <- pmin(from, to)
    to <- pmax(from, to)
    from <- left
  }
  (from - 1L) * n + to
}

#' Exact eligible and occupied pair state
#' @param dn Parent temporal network.
#' @param enc Encoded session block.
#' @param time Numeric instant strictly inside an exposure cell.
#' @param sessions Session aggregation policy.
#' @param label Session label for a separate block.
#' @param opportunities Pre-enumerated nonloop pair table.
#' @return Lists of eligible and occupied integer pair keys.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.temporal_pair_state(dn, Dynet:::.encode(dn), 1, "collapse")
#' @keywords internal
.temporal_pair_state <- function(dn, enc, time,
                                 sessions = c("bounded", "collapse", "separate"),
                                 label = "all",
                                 opportunities = NULL) {
  sessions <- match.arg(sessions)
  opportunities <- opportunities %||%
    .relational_opportunities(enc$n, dn$directed)
  empty <- list(eligible = integer(), occupied = integer())
  if (!nrow(opportunities) || !.time_in_observation(dn, time)) return(empty)
  activity <- .encode_vertex_activity(dn, enc$names)
  point <- data.frame(lo = time, hi = time, closed = TRUE, time = time)
  has_sessions <- !is.null(dn$meta$sessions)
  scopes <- if (identical(sessions, "collapse") || !has_sessions) {
    list(list(session = NULL, erase = TRUE, rows = rep(TRUE, length(enc$start))))
  } else if (identical(sessions, "separate")) {
    list(list(session = label, erase = FALSE,
              rows = enc$session == label))
  } else lapply(dn$meta$sessions, function(one) list(
    session = one, erase = FALSE, rows = enc$session == one
  ))

  eligible_keys <- lapply(scopes, function(scope) {
    eligible <- .vertex_eligibility(
      activity, point, 0, session = scope$session,
      erase_sessions = scope$erase
    )
    opportunities$key[
      eligible[opportunities$from] & eligible[opportunities$to]
    ]
  })
  raw_active <- .active(enc, time, time, last = TRUE, window = 0) &
    !enc$instant & enc$from != enc$to
  occupied_keys <- lapply(scopes, function(scope) {
    eligible <- .vertex_eligibility(
      activity, point, 0, session = scope$session,
      erase_sessions = scope$erase
    )
    rows <- which(raw_active & scope$rows &
                    eligible[enc$from] & eligible[enc$to])
    unique(.relational_pair_key(
      enc$from[rows], enc$to[rows], enc$n, dn$directed
    ))
  })
  list(
    eligible = sort(unique(unlist(eligible_keys, use.names = FALSE))),
    occupied = sort(unique(unlist(occupied_keys, use.names = FALSE)))
  )
}

#' Test exact endpoint eligibility for raw edge evidence
#' @param dn Parent temporal network.
#' @param enc Encoded session block.
#' @param rows Raw-event indices.
#' @param time Raw start or terminus times aligned with `rows`.
#' @param sessions Session aggregation policy.
#' @param label Session label for a separate block.
#' @return Logical vector, one value per raw event.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.raw_endpoint_eligible(dn, Dynet:::.encode(dn), 1L, 0,
#'                                "collapse")
#' @keywords internal
.raw_endpoint_eligible <- function(dn, enc, rows, time,
                                   sessions = c("bounded", "collapse", "separate"),
                                   label = "all") {
  sessions <- match.arg(sessions)
  if (!length(rows)) return(logical())
  activity <- .encode_vertex_activity(dn, enc$names)
  has_sessions <- !is.null(dn$meta$sessions)
  vapply(seq_along(rows), function(index) {
    row <- rows[[index]]
    at <- time[[index]]
    if (!.time_in_observation(dn, at)) return(FALSE)
    point <- data.frame(lo = at, hi = at, closed = TRUE, time = at)
    if (identical(sessions, "collapse") || !has_sessions) {
      eligible <- .vertex_eligibility(
        activity, point, 0, erase_sessions = TRUE
      )
    } else {
      edge_session <- if (identical(sessions, "separate")) {
        label
      } else enc$raw_event_session[[row]]
      eligible <- .vertex_eligibility(
        activity, point, 0, session = edge_session,
        erase_sessions = FALSE
      )
    }
    eligible[enc$raw_from[[row]]] && eligible[enc$raw_to[[row]]]
  }, logical(1L))
}

#' Exposure change points inside a reporting window
#' @param dn Parent temporal network.
#' @param enc Encoded session block.
#' @param lo,hi Reporting limits.
#' @return Sorted unique change points clipped to `[lo, hi]`.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.temporal_exposure_changes(dn, Dynet:::.encode(dn), 0, 2)
#' @keywords internal
.temporal_exposure_changes <- function(dn, enc, lo, hi) {
  activity <- .encode_vertex_activity(dn, enc$names)
  observations <- .observation_table(dn)
  change <- c(lo, hi, enc$start[enc$observed_activity],
              enc$end[enc$observed_activity], activity$start, activity$end)
  if (!is.null(observations)) {
    change <- c(change, observations$start, observations$end)
  }
  sort(unique(pmax(lo, pmin(hi, change[is.finite(change)]))))
}

#' Pairs with endpoint-valid evidence anywhere in stored history
#' @param dn Parent temporal network.
#' @param enc Encoded session block.
#' @param sessions Session aggregation policy.
#' @param label Session label for a separate block.
#' @return Sorted collision-free integer pair keys.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.ever_observed_pairs(dn, Dynet:::.encode(dn), "collapse")
#' @keywords internal
.ever_observed_pairs <- function(dn, enc,
                                 sessions = c("bounded", "collapse", "separate"),
                                 label = "all") {
  sessions <- match.arg(sessions)
  opportunities <- .relational_opportunities(enc$n, dn$directed)
  if (!nrow(opportunities)) return(integer())
  bounds <- dn$meta$time_range
  change <- .temporal_exposure_changes(
    dn, enc, bounds[["start"]], bounds[["end"]]
  )
  positive <- if (length(change) < 2L) integer() else {
    width <- diff(change)
    midpoint <- change[-length(change)] + width / 2
    states <- lapply(midpoint[width > 0], function(time) {
      .temporal_pair_state(
        dn, enc, time, sessions, label, opportunities
      )$occupied
    })
    unique(unlist(states, use.names = FALSE))
  }
  raw <- which(enc$raw_from != enc$raw_to)
  endpoint_keys <- lapply(c("raw_event_start", "raw_event_end"), function(field) {
    time <- enc[[field]][raw]
    keep <- .raw_endpoint_eligible(dn, enc, raw, time, sessions, label)
    .relational_pair_key(
      enc$raw_from[raw[keep]], enc$raw_to[raw[keep]], enc$n, dn$directed
    )
  })
  sort(unique(c(positive, unlist(endpoint_keys, use.names = FALSE))))
}

#' Integrate temporal edge opportunity, occupancy, and raw onsets
#' @param dn Parent temporal network.
#' @param enc Encoded session block.
#' @param bin One reporting-window row with `lo`, `hi`, and `closed`.
#' @param sessions Session aggregation policy.
#' @param label Session label for a separate block.
#' @param cohort Optional precomputed ever-observed pair keys.
#' @return Named `risk`, `occupied`, `observed_risk`, and `onsets` values.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.temporal_edge_ledger(
#'   dn, Dynet:::.encode(dn), data.frame(lo = 0, hi = 2, closed = TRUE),
#'   "collapse"
#' )
#' @keywords internal
.temporal_edge_ledger <- function(dn, enc, bin,
                                  sessions = c("bounded", "collapse", "separate"),
                                  label = "all", cohort = NULL) {
  sessions <- match.arg(sessions)
  opportunities <- .relational_opportunities(enc$n, dn$directed)
  cohort <- cohort %||% .ever_observed_pairs(dn, enc, sessions, label)
  lo <- bin$lo[[1L]]
  hi <- bin$hi[[1L]]
  change <- .temporal_exposure_changes(dn, enc, lo, hi)
  totals <- c(risk = 0, occupied = 0, observed_risk = 0)
  if (hi > lo && length(change) >= 2L) {
    width <- diff(change)
    midpoint <- change[-length(change)] + width / 2
    cells <- vapply(seq_along(midpoint), function(index) {
      if (width[[index]] <= 0) {
        return(c(risk = 0, occupied = 0, observed_risk = 0))
      }
      state <- .temporal_pair_state(
        dn, enc, midpoint[[index]], sessions, label, opportunities
      )
      c(
        risk = length(state$eligible), occupied = length(state$occupied),
        observed_risk = sum(state$eligible %in% cohort)
      )
    }, numeric(3L))
    totals <- rowSums(sweep(cells, 2L, width, `*`))
  }
  raw <- which(
    enc$raw_from != enc$raw_to & !enc$raw_event_onset_censored &
      .time_in_observation(dn, enc$raw_event_start)
  )
  within <- if (isTRUE(bin$closed[[1L]])) {
    enc$raw_event_start[raw] >= lo & enc$raw_event_start[raw] <= hi
  } else {
    enc$raw_event_start[raw] >= lo & enc$raw_event_start[raw] < hi
  }
  raw <- raw[within]
  onsets <- sum(.raw_endpoint_eligible(
    dn, enc, raw, enc$raw_event_start[raw], sessions, label
  ))
  c(totals, onsets = onsets)
}

#' Convert a temporal edge ledger to named public quantities
#' @param ledger Named output from [.temporal_edge_ledger()].
#' @return The four D04 graph measures, with `NA` for a zero denominator.
#' @examples
#' Dynet:::.temporal_edge_values(c(
#'   risk = 2, occupied = 1, observed_risk = 1, onsets = 1
#' ))
#' @keywords internal
.temporal_edge_values <- function(ledger) {
  ratio <- function(numerator, denominator) {
    if (denominator <= 0) NA_real_ else unname(numerator / denominator)
  }
  c(
    temporal_density = ratio(ledger[["occupied"]], ledger[["risk"]]),
    observed_pair_density = ratio(
      ledger[["occupied"]], ledger[["observed_risk"]]
    ),
    onset_intensity = ratio(ledger[["onsets"]], ledger[["risk"]]),
    observed_pair_onset_intensity = ratio(
      ledger[["onsets"]], ledger[["observed_risk"]]
    )
  )
}

#' Integrate eligible relational risk and occupancy
#' @param dn A temporal network from [dynet()].
#' @return Named `risk`, `occupied`, and `empty` pair-time values.
#' @keywords internal
.temporal_risk_ledger <- function(dn) {
  .check_dynet(dn, sessions = "collapse")
  enc <- .encode(dn)
  bounds <- dn$meta$time_range
  ledger <- .temporal_edge_ledger(
    dn, enc,
    data.frame(lo = bounds[["start"]], hi = bounds[["end"]], closed = TRUE),
    sessions = "collapse", label = "all", cohort = integer()
  )
  c(
    risk = ledger[["risk"]], occupied = ledger[["occupied"]],
    empty = ledger[["risk"]] - ledger[["occupied"]]
  )
}

#' Temporal occupancy over every eligible relation
#'
#' @param dn A temporal network from [dynet()].
#' @return A numeric scalar in `[0, 1]`, or `NA` when the denominator is zero.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.temporal_density(dn)
#' @keywords internal
.temporal_density <- function(dn) {
  ledger <- .temporal_risk_ledger(dn)
  if (ledger[["risk"]] <= 0) return(NA_real_)
  unname(ledger[["occupied"]] / ledger[["risk"]])
}

#' Print time-respecting paths
#'
#' @param x A `dynet_paths` from [paths()].
#' @param n Number of rows to show.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet_paths <- function(x, n = 12L, ...) {
  mode <- attr(x, "path_mode") %||% "collapse"
  if (identical(mode, "separate")) {
    eligible <- x$node != attr(x, "source")
    cat(sprintf("# Time-respecting paths %s %s, separately by session\n",
                if (identical(attr(x, "direction"), "forward")) "from" else "into",
                sQuote(attr(x, "source"))))
    cat(sprintf("# reaches %d of %d session-vertex opportunities | time in %s\n",
                sum(x$reachable & eligible), sum(eligible),
                attr(x, "time_unit")))
  } else {
    if (identical(attr(x, "criterion"), "latest_departure")) {
      cat(sprintf("# Latest departures from %s reaching each vertex by t = %s\n",
                  sQuote(attr(x, "source")), format(attr(x, "deadline"))))
    } else {
      cat(sprintf("# Time-respecting paths %s %s, from t = %s\n",
                  if (identical(attr(x, "direction"), "forward")) "from" else "into",
                  sQuote(attr(x, "source")), format(attr(x, "origin"))))
    }
    cat(sprintf("# reaches %d of %d other vertices | time in %s\n",
                sum(x$reachable) - 1L, nrow(x) - 1L,
                attr(x, "time_unit")))
    if (identical(mode, "bounded")) {
      cat("# routes are endpoint-specific session-integral optima, not one predecessor tree\n")
    }
  }
  traversal_time <- attr(x, "traversal_time") %||% 0
  if (traversal_time > 0) {
    cat(sprintf("# traversal %s %s per hop\n",
                format(traversal_time), attr(x, "time_unit")))
  }
  print(utils::head(as.data.frame(x), n), row.names = FALSE)
  if (nrow(x) > n) {
    suffix <- if (identical(mode, "collapse")) {
      "summary() aggregates them; plot() draws the tree."
    } else {
      "summary() aggregates them; the steps table gives complete routes."
    }
    cat(sprintf("# %d more rows. %s\n", nrow(x) - n, suffix))
  }
  invisible(x)
}

#' Tidy data frame of time-respecting paths
#' @param x A `dynet_paths`.
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param what `"paths"` for the endpoint summary or `"steps"` for the tidy
#'   reconstructed optimal routes. The latter includes endpoint-local
#'   `path_id` values for tied contact sequences.
#' @param ... Ignored.
#' @return A plain `data.frame`, one row per endpoint for `"paths"` or one row
#'   per route step for `"steps"`.
#' @export
as.data.frame.dynet_paths <- function(x, row.names = NULL, optional = FALSE,
                                      what = c("paths", "steps"), ...) {
  what <- match.arg(what)
  if (identical(what, "steps")) {
    descriptor <- attr(x, "optimal_search")
    out <- if (is.null(descriptor)) attr(x, "steps") else
      .optimal_steps(descriptor)
    rownames(out) <- NULL
    return(out)
  }
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
#'   Separate mode adds `session` and reports each session independently.
#' @export
summary.dynet_paths <- function(object, ...) {
  summarize_block <- function(block) {
    r <- block$reachable & block$node != attr(object, "source")
    lat <- block$latency[r]
    hop <- block$n_hops[r]
    hop <- hop[!is.na(hop)]
    data.frame(
      property = c("source", "direction", "reachable", "reachable share",
                   "median latency", "max latency", "median hops", "max hops"),
      value = c(attr(object, "source"), attr(object, "direction"),
                format(sum(r)),
                format(round(sum(r) / (nrow(block) - 1), 3)),
                format(if (any(r)) stats::median(lat) else NA_real_),
                format(if (any(r)) max(lat) else NA_real_),
                format(if (length(hop)) stats::median(hop) else NA_real_),
                format(if (length(hop)) max(hop) else NA_real_)),
      stringsAsFactors = FALSE
    )
  }
  if (!identical(attr(object, "path_mode"), "separate")) {
    return(summarize_block(object))
  }
  blocks <- split(as.data.frame(object), object$session)
  out <- Map(function(block, label) {
    data.frame(session = label, summarize_block(block),
               stringsAsFactors = FALSE)
  }, blocks, names(blocks))
  result <- do.call(rbind, out)
  rownames(result) <- NULL
  result
}
