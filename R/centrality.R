# ===========================================================================
# dyn_centrality() — time-varying vertex centrality
# ===========================================================================

.node_measures <- c("degree", "indegree", "outdegree", "strength",
                    "closeness", "betweenness",
                    "eigenvector", "pagerank", "hub", "authority",
                    "coreness", "constraint", "power", "harary",
                    "information", "load", "flow_betweenness")

# The measures for which "out" and "in" mean something. Every other measure
# has a single directional definition and ignores `mode`, as in igraph.
.mode_aware_measures <- c("degree", "indegree", "outdegree", "strength",
                          "closeness", "coreness", "harary", "eigenvector")

.temporal_measures <- c("closeness", "betweenness", "reach")

#' Time-varying vertex centrality
#'
#' @description
#' Centrality for every vertex at every time point. Ask for several measures
#' in one call and they arrive stacked in a single tidy frame, one row per
#' vertex, time point and measure.
#'
#' Two scopes answer two different questions. `"snapshot"` measures the
#' network as it stands in each time bin, so the result is a trajectory of
#' ordinary centrality. `"temporal"` measures the vertex against
#' time-respecting paths across the whole observation window, which is the
#' quantity that has no counterpart in a static network: it cannot run
#' backwards in time, so it is never inflated the way a flattened network is.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure One or more of `"degree"`, `"strength"`, `"closeness"`,
#'   `"betweenness"`, `"eigenvector"`, `"pagerank"`, `"hub"`, `"authority"`,
#'   `"coreness"`, `"constraint"`, `"power"`, `"harary"`, `"information"`,
#'   `"load"` or `"flow_betweenness"` for snapshot scope; `"closeness"`,
#'   `"betweenness"` or `"reach"` for temporal scope.
#' @param scope `"snapshot"` for a value per time bin, `"temporal"` for one
#'   value per vertex computed on time-respecting paths.
#' @param mode Which edges count on a directed network: `"all"` both
#'   directions, `"out"` outgoing only, `"in"` incoming only. Applies to
#'   `"degree"`, `"strength"`, `"closeness"`, `"coreness"`, `"harary"` and
#'   `"eigenvector"`; the remaining measures have a single directional
#'   definition and ignore it. Ignored
#'   entirely on an undirected network. In-degree is therefore
#'   `mode = "in"`. The old `"indegree"` and `"outdegree"` measure names
#'   remain as deprecated aliases.
#' @param sessions How to treat sessions: `"bounded"` keeps paths inside a
#'   session, `"collapse"` ignores sessions, `"separate"` reports each session
#'   on its own rows.
#' @param sample Deprecated. `"instant"` is equivalent to `window = 0`;
#'   `"window"` uses the current positive/default window.
#' @param start,end First and last time at which to measure. Default to the
#'   observed range. A network built from dates may be addressed with dates.
#' @param step How often to measure. Defaults to the interval the network was
#'   built with.
#' @param window How much time each measurement covers. Defaults to `step`,
#'   which tiles the period into disjoint bins. A larger value slides an
#'   overlapping window; `0` samples the network at each point in time.
#' @param damping Damping factor for PageRank.
#' @param exponent Attenuation factor for Bonacich `"power"`. Positive rewards
#'   being connected to well-connected others; negative rewards the opposite,
#'   which is the bargaining reading.
#'
#' @return A `dynet_metric`: a tidy data frame with one row per vertex, time
#'   point and measure. Columns are `session` (only when the network has
#'   sessions), `time` (snapshot scope only), `node`, `measure` and `value`.
#'   Print it, [summary()] it, [plot()] it, or take the plain frame with
#'   [as.data.frame()].
#'
#' @details
#' `step` and `window` are separate on purpose. `step` is how often you look;
#' `window` is how much of the timeline each look takes in. Setting them equal
#' partitions the period; setting `window` larger than `step` is a rolling
#' window, which keeps the resolution of the smaller step while smoothing over
#' the noise of a sparse bin. The arguments match `tsna::tSnaStats()`, where
#' they are called `time.interval` and `aggregate.dur`.
#'
#' `"eigenvector"` is uniquely determined when the Perron eigenvalue has a
#' one-dimensional eigenspace; strong connectivity is a sufficient condition.
#' Disconnected snapshots with equally dominant components can have more than
#' one correct eigenvector, so read the result as a within-snapshot ranking
#' rather than an automatically comparable number across the whole series.
#'
#' Temporal betweenness counts how many earliest-arrival paths pass through a
#' vertex, taken over one path per source-target pair. It is not averaged over
#' all equally-early paths, so it is a count on the earliest-arrival tree
#' rather than the Brandes quantity.
#'
#' @references
#' Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora, V.
#' (2013). Graph metrics for temporal networks. In *Temporal Networks*
#' (pp. 15-40). Springer.
#'
#' @examples
#' dn <- dynet(school_contacts)
#'
#' dyn_centrality(dn, measure = "degree")
#' dyn_centrality(dn, measure = c("degree", "betweenness"))
#' dyn_centrality(dn, measure = "closeness", scope = "temporal")
#'
#' # A seven-day window, stepped one day at a time.
#' dyn_centrality(dn, measure = "degree", step = 1, window = 7)
#'
#' summary(dyn_centrality(dn, measure = "degree"))
#'
#' @export
dyn_centrality <- function(dn,
                           measure = "degree",
                           scope = c("snapshot", "temporal"),
                           sessions = c("bounded", "collapse", "separate"),
                           sample = NULL,
                           damping = 0.85,
                           mode = c("all", "out", "in"),
                           start = NULL, end = NULL,
                           step = NULL, window = NULL,
                           exponent = 1) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  scope <- match.arg(scope)
  mode  <- match.arg(mode)
  window <- .legacy_sample(window, sample)
  spec  <- .window_spec(dn, start, end, step, window)
  .check(
    "`measure` must be a character vector." = is.character(measure),
    "`measure` must name at least one measure." = length(measure) > 0L,
    "`damping` must be a single number strictly between zero and one." =
      is.numeric(damping) && length(damping) == 1L && damping > 0 && damping < 1,
    "`exponent` must be a single finite number." =
      is.numeric(exponent) && length(exponent) == 1L && is.finite(exponent)
  )

  allowed <- if (identical(scope, "temporal")) .temporal_measures else .node_measures
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s for scope \"%s\". Available: %s",
              paste(sQuote(bad), collapse = ", "), scope,
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }
  retired <- intersect(measure, c("indegree", "outdegree"))
  if (length(retired) > 0L) {
    warning(sprintf(
      "%s deprecated; use `measure = \"degree\"` with %s.",
      paste(sQuote(retired), collapse = " and "),
      paste(sprintf("`mode = \"%s\"`", sub("degree$", "", retired)),
            collapse = " and ")),
      call. = FALSE)
  }
  if (!dn$directed) {
    undirected_only <- intersect(measure,
                                 c("indegree", "outdegree", "hub", "authority"))
    if (length(undirected_only) > 0L) {
      stop(errorCondition(
        sprintf("%s needs a directed network; this one is undirected.",
                paste(sQuote(undirected_only), collapse = ", ")),
        class = "dynet_needs_directed", call = NULL))
    }
  }

  if (identical(scope, "temporal")) {
    if (!identical(mode, "all")) {
      stop(errorCondition(
        "`mode` has no meaning for `scope = \"temporal\"`; temporal paths use the network's recorded direction.",
        class = "dynet_bad_input", call = NULL))
    }
    grid_args <- c("start", "end", "step", "window")
    given <- grid_args[!vapply(list(start, end, step, window), is.null,
                               logical(1L))]
    if (length(given) > 0L) {
      stop(errorCondition(sprintf(
        "%s %s no meaning for scope = \"temporal\", which measures time-respecting paths across the whole window rather than a grid of snapshots.",
        paste(sQuote(given), collapse = ", "),
        if (length(given) == 1L) "has" else "have"),
        class = "dynet_bad_input", call = NULL))
    }
    return(.temporal_centrality(dn, measure, sessions))
  }

  df <- .over_bins(dn, sessions, node_level = TRUE, spec = spec,
    fun = function(enc, act, bin) {
      a <- .adjacency(enc, act, dn$directed,
                      weighted = "strength" %in% measure)
      stats::setNames(lapply(measure, function(m)
        .snapshot_measure(m, a, dn$directed, damping, mode, exponent)),
        measure)
    })

  .metric(df, level = "node",
          what = if (length(measure) == 1L) .measure_label(measure) else "Centrality",
          dn = dn, spec = spec,
          mode = if (!identical(mode, "all") && dn$directed &&
                     any(measure %in% .mode_aware_measures)) mode else NULL)
}

#' Compute one snapshot centrality measure
#' @param m Measure name.
#' @param a Adjacency matrix for the bin.
#' @param directed Whether the network is directed.
#' @param damping PageRank damping factor.
#' @param mode Which edges count: `"all"`, `"out"` or `"in"`.
#' @param exponent Attenuation factor for Bonacich power.
#' @return A numeric vector, one value per vertex.
#' @keywords internal
.snapshot_measure <- function(m, a, directed, damping, mode = "all",
                              exponent = 1) {
  b <- .binary(a, directed)
  degree_b <- (a > 0) * 1
  if (!directed) {
    degree_b <- pmax(degree_b, t(degree_b))
    # An undirected loop contributes two stubs, as in igraph and cograph.
    diag(degree_b) <- 2 * (diag(a) > 0)
  }
  switch(m,
    degree      = .margin(degree_b, directed, mode),
    indegree    = .margin(degree_b, directed, "in"),
    outdegree   = .margin(degree_b, directed, "out"),
    strength    = .margin(a, directed, mode),
    closeness   = .closeness(a, directed, mode),
    betweenness = .betweenness(a, directed),
    # `b`, not `a`: an edge counts once however many spells produced it, as
    # for every other centrality here. Volume is what `strength` is for.
    eigenvector = .eigen_centrality(b, directed, mode),
    pagerank    = .pagerank(b, damping),
    hub         = .hits(b, "hub"),
    authority   = .hits(b, "authority"),
    coreness    = .coreness(a, directed, mode),
    constraint  = .constraint(b),
    power       = .bonacich_power(a, directed, exponent),
    harary      = .harary(a, directed, mode),
    information = .information(a),
    load        = .load(a, directed),
    flow_betweenness = .flow_betweenness(a, directed)
  )
}

#' Human-readable label for a measure name
#' @param m Measure name.
#' @return A single character string.
#' @keywords internal
.measure_label <- function(m) {
  lookup <- c(degree = "Degree", indegree = "In-degree",
              outdegree = "Out-degree", strength = "Strength",
              closeness = "Closeness", betweenness = "Betweenness",
              eigenvector = "Eigenvector centrality", pagerank = "PageRank",
              hub = "Hub score", authority = "Authority score",
              coreness = "Coreness", constraint = "Burt's constraint",
              power = "Bonacich power", harary = "Harary graph centrality",
              information = "Information centrality", load = "Load centrality",
              flow_betweenness = "Flow betweenness",
              reach = "Reachability")
  unname(lookup[m] %||% m)
}

#' Vertex centrality over time-respecting paths
#' @param dn A `dynet` object.
#' @param measure One or more of "closeness", "betweenness", "reach".
#' @param sessions Session mode.
#' @return A `dynet_metric` at node level with no time column.
#' @keywords internal
.temporal_centrality <- function(dn, measure, sessions) {
  parts <- .split_sessions(dn, sessions)
  bounded <- identical(sessions, "bounded")
  frames <- Map(function(enc, label) {
    walk <- .undirect_or_reverse(enc, dn$directed, "forward")
    t0 <- min(enc$start)
    trees <- lapply(seq_len(enc$n), function(s)
      .bfs_bounded(dn, walk, s, t0, bounded))
    vals <- stats::setNames(lapply(measure, function(m)
      .temporal_measure(m, trees, enc)), measure)
    data.frame(session = label, node = enc$names,
               measure = rep(measure, each = enc$n),
               value = unlist(vals, use.names = FALSE),
               stringsAsFactors = FALSE)
  }, parts, names(parts))
  df <- do.call(rbind, frames)

  .metric(df, level = "node",
          what = if (length(measure) == 1L) .measure_label(measure) else "Temporal centrality",
          dn = dn,
          note = "computed on time-respecting paths across the whole window")
}

#' Reduce a set of earliest-arrival trees to one temporal measure
#' @param m Measure name.
#' @param trees List of BFS results, one per source.
#' @param enc Encoded edge list.
#' @return A numeric vector, one value per vertex.
#' @keywords internal
.temporal_measure <- function(m, trees, enc) {
  n <- enc$n
  switch(m,
    reach = vapply(trees, function(tr) sum(is.finite(tr$arrival)) - 1, numeric(1L)) / (n - 1),
    closeness = vapply(trees, function(tr) {
      lat <- tr$arrival - tr$origin
      ok <- is.finite(lat) & lat > 0
      if (!any(ok)) return(0)
      sum(ok) / sum(lat[ok])
    }, numeric(1L)),
    betweenness = {
      # Every intermediate vertex on an earliest-arrival path earns one count.
      hits <- lapply(trees, function(tr) {
        targets <- which(is.finite(tr$arrival) & seq_len(n) != tr$source)
        inner <- as.integer(unlist(lapply(targets, function(t) {
          path <- .trace(tr$previous, tr$source, t)
          if (length(path) > 2L) path[-c(1L, length(path))] else integer(0)
        }), use.names = FALSE))
        tabulate(inner, nbins = n)
      })
      Reduce(`+`, hits, accumulate = FALSE)
    }
  )
}
