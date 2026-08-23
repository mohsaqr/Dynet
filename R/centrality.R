# ===========================================================================
# dyn_centrality() — time-varying vertex centrality
# ===========================================================================

.node_measures <- c("degree", "indegree", "outdegree", "strength",
                    "closeness", "betweenness", "eigenvector", "pagerank",
                    "hub", "authority", "coreness", "constraint")

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
#' @param measure One or more of `"degree"`, `"indegree"`, `"outdegree"`,
#'   `"strength"`, `"closeness"`, `"betweenness"`, `"eigenvector"`,
#'   `"pagerank"`, `"hub"`, `"authority"`, `"coreness"`, `"constraint"` for
#'   snapshot scope; `"closeness"`, `"betweenness"` or `"reach"` for temporal
#'   scope.
#' @param scope `"snapshot"` for a value per time bin, `"temporal"` for one
#'   value per vertex computed on time-respecting paths.
#' @param sessions How to treat sessions: `"bounded"` keeps paths inside a
#'   session, `"collapse"` ignores sessions, `"separate"` reports each session
#'   on its own rows.
#' @param sample `"window"` counts an edge whose spell overlaps the bin at
#'   all; `"instant"` samples the network at the bin's left edge, matching
#'   `tsna`. `"window"` is the default because it cannot miss a short event.
#' @param damping Damping factor for PageRank.
#'
#' @return A `dynet_metric`: a tidy data frame with one row per vertex, time
#'   point and measure. Columns are `session` (only when the network has
#'   sessions), `time` (snapshot scope only), `node`, `measure` and `value`.
#'   Print it, [summary()] it, [plot()] it, or take the plain frame with
#'   [as.data.frame()].
#'
#' @details
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
#' summary(dyn_centrality(dn, measure = "degree"))
#'
#' @export
dyn_centrality <- function(dn,
                           measure = "degree",
                           scope = c("snapshot", "temporal"),
                           sessions = c("bounded", "collapse", "separate"),
                           sample = c("window", "instant"),
                           damping = 0.85) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  scope  <- match.arg(scope)
  sample <- match.arg(sample)
  .check(
    "`measure` must be a character vector." = is.character(measure),
    "`measure` must name at least one measure." = length(measure) > 0L,
    "`damping` must be a single number strictly between zero and one." =
      is.numeric(damping) && length(damping) == 1L && damping > 0 && damping < 1
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
    return(.temporal_centrality(dn, measure, sessions))
  }

  df <- .over_bins(dn, sessions, node_level = TRUE, sample = sample,
    fun = function(enc, act, bin) {
      a <- .adjacency(enc, act, dn$directed,
                      weighted = "strength" %in% measure)
      stats::setNames(lapply(measure, function(m)
        .snapshot_measure(m, a, dn$directed, damping)), measure)
    })

  .metric(df, level = "node",
          what = if (length(measure) == 1L) .measure_label(measure) else "Centrality",
          dn = dn)
}

#' Compute one snapshot centrality measure
#' @param m Measure name.
#' @param a Adjacency matrix for the bin.
#' @param directed Whether the network is directed.
#' @param damping PageRank damping factor.
#' @return A numeric vector, one value per vertex.
#' @keywords internal
.snapshot_measure <- function(m, a, directed, damping) {
  b <- .binary(a, directed)
  switch(m,
    degree      = if (directed) rowSums(b) + colSums(b) else rowSums(b),
    indegree    = colSums(b),
    outdegree   = rowSums(b),
    strength    = if (directed) rowSums(a) + colSums(a) else rowSums(a),
    closeness   = .closeness(a, directed),
    betweenness = .betweenness(a, directed),
    eigenvector = .eigen_centrality(a, directed),
    pagerank    = .pagerank(b, damping),
    hub         = .hits(b, "hub"),
    authority   = .hits(b, "authority"),
    coreness    = .coreness(a, directed),
    constraint  = .constraint(b)
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
        inner <- unlist(lapply(targets, function(t) {
          path <- .trace(tr$previous, tr$source, t)
          if (length(path) > 2L) path[-c(1L, length(path))] else integer(0)
        }), use.names = FALSE)
        tabulate(inner, nbins = n)
      })
      Reduce(`+`, hits, accumulate = FALSE)
    }
  )
}
