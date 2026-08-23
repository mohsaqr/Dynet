# ===========================================================================
# dyn_metrics() — time-varying graph-level structure
# ===========================================================================

.graph_measures <- c(
  "density", "edges", "active_nodes", "isolates", "transitivity",
  "reciprocity", "components", "largest_component", "mean_distance",
  "diameter", "mutual", "asymmetric", "null", "assortativity",
  "centralization_degree", "centralization_betweenness",
  "centralization_closeness", "triads"
)

#' Time-varying graph-level structure
#'
#' @description
#' Graph properties measured on each time bin, returned as a time series. This
#' is where a temporal network earns its keep: a single density for the whole
#' course tells you nothing about a group that was dense in week two and
#' silent in week five.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure One or more of `"density"`, `"edges"`, `"active_nodes"`,
#'   `"isolates"`, `"transitivity"`, `"reciprocity"`, `"components"`,
#'   `"largest_component"`, `"mean_distance"`, `"diameter"`, `"mutual"`,
#'   `"asymmetric"`, `"null"`, `"assortativity"`,
#'   `"centralization_degree"`, `"centralization_betweenness"`,
#'   `"centralization_closeness"`, `"triads"`. `"triads"` expands to the
#'   sixteen triad classes.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param sample `"window"` or `"instant"`, as in [dyn_centrality()].
#'
#' @return A `dynet_metric` at graph level: one row per time point and
#'   measure, with columns `session` (when present), `time`, `measure` and
#'   `value`.
#'
#' @details
#' Density here counts realised edges against possible ones in each bin. A
#' second, genuinely temporal density -- observed edge duration against the
#' maximum possible duration -- is reported by [summary()] on the network
#' itself, because it describes the whole window rather than a bin.
#'
#' Triad census cost grows with the cube of the vertex count. On a network of
#' a few hundred vertices it is the slowest measure here by a wide margin.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' dyn_metrics(dn, measure = "density")
#' dyn_metrics(dn, measure = c("density", "reciprocity", "transitivity"))
#' plot(dyn_metrics(dn, measure = c("mutual", "asymmetric")))
#'
#' @export
dyn_metrics <- function(dn, measure = "density",
                        sessions = c("bounded", "collapse", "separate"),
                        sample = c("window", "instant")) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  sample <- match.arg(sample)
  .check("`measure` must be a character vector." = is.character(measure),
            "`measure` must name at least one measure." = length(measure) > 0L)

  bad <- setdiff(measure, .graph_measures)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(.graph_measures, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }
  if (!dn$directed) {
    dir_only <- intersect(measure, c("reciprocity", "mutual", "asymmetric", "null"))
    if (length(dir_only) > 0L) {
      stop(errorCondition(
        sprintf("%s needs a directed network; this one is undirected.",
                paste(sQuote(dir_only), collapse = ", ")),
        class = "dynet_needs_directed", call = NULL))
    }
  }

  df <- .over_bins(dn, sessions, node_level = FALSE, sample = sample,
    fun = function(enc, act, bin) {
      a <- .adjacency(enc, act, dn$directed)
      unlist(lapply(measure, function(m) .graph_measure(m, a, dn$directed)),
             use.names = TRUE)
    })

  .metric(df, level = "graph",
          what = if (length(measure) == 1L) .graph_label(measure) else "Graph structure",
          dn = dn)
}

#' Compute one graph-level measure
#' @param m Measure name.
#' @param a Adjacency matrix for the bin.
#' @param directed Whether the network is directed.
#' @return A named numeric vector; length one except for `"triads"`.
#' @keywords internal
.graph_measure <- function(m, a, directed) {
  b <- .binary(a, directed)
  n <- nrow(b)
  possible <- if (directed) n * (n - 1) else n * (n - 1) / 2
  n_edges <- if (directed) sum(b) else sum(b) / 2

  val <- switch(m,
    density      = if (possible > 0) n_edges / possible else 0,
    edges        = n_edges,
    active_nodes = sum(rowSums(b) + colSums(b) > 0),
    isolates     = sum(rowSums(b) + colSums(b) == 0),
    transitivity = .transitivity(a, directed),
    reciprocity  = .reciprocity(a),
    components   = .components(a, "weak")$count,
    largest_component = {
      memb <- .components(a, "weak")$membership
      max(tabulate(memb)) / max(1, n)
    },
    mean_distance = {
      reachable <- .offdiag_distances(a, directed)
      if (length(reachable) == 0L) NA_real_ else mean(reachable)
    },
    diameter = {
      reachable <- .offdiag_distances(a, directed)
      if (length(reachable) == 0L) NA_real_ else max(reachable)
    },
    mutual     = unname(.dyad_census(a)["mutual"]),
    asymmetric = unname(.dyad_census(a)["asymmetric"]),
    null       = unname(.dyad_census(a)["null"]),
    assortativity = .assortativity(a, directed),
    centralization_degree =
      .centralisation(if (directed) rowSums(b) + colSums(b) else rowSums(b),
                      .max_centralisation("degree", n, directed)),
    centralization_betweenness =
      .centralisation(.betweenness(a, directed),
                      .max_centralisation("betweenness", n, directed)),
    centralization_closeness =
      .centralisation(.closeness(a, directed),
                      .max_centralisation("closeness", n, directed)),
    triads = .triad_census(a)
  )

  if (identical(m, "triads")) {
    stats::setNames(val, paste0("triad_", names(val)))
  } else {
    stats::setNames(val, m)
  }
}

#' Finite off-diagonal geodesic distances
#'
#' The diagonal is excluded by position rather than by writing `NA` into it,
#' so no downstream call needs `na.rm`.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @return A numeric vector of the finite distances between distinct vertices.
#' @keywords internal
.offdiag_distances <- function(a, directed) {
  d <- .geodesic(a, directed)
  off <- d[row(d) != col(d)]
  off[is.finite(off)]
}

#' Theoretical maximum sum of centrality differences
#'
#' The denominator of Freeman centralisation, taken over the most centralised
#' graph of the same order.
#'
#' @param what `"degree"`, `"betweenness"` or `"closeness"`.
#' @param n Vertex count.
#' @param directed Whether the network is directed.
#' @return A single numeric value.
#' @keywords internal
.max_centralisation <- function(what, n, directed) {
  if (n < 3L) return(NA_real_)
  switch(what,
    degree      = if (directed) (n - 1) * (2 * n - 3) else (n - 1) * (n - 2),
    betweenness = if (directed) (n - 1)^2 * (n - 2) else (n - 1)^2 * (n - 2) / 2,
    closeness   = if (directed) (n - 1) * (n - 2) / (2 * n - 3) else
                    (n - 1) * (n - 2) / (2 * n - 3)
  )
}

#' Human-readable label for a graph measure
#' @param m Measure name.
#' @return A single character string.
#' @keywords internal
.graph_label <- function(m) {
  lookup <- c(density = "Density", edges = "Active edges",
              active_nodes = "Active vertices", isolates = "Isolates",
              transitivity = "Transitivity", reciprocity = "Reciprocity",
              components = "Components",
              largest_component = "Largest component share",
              mean_distance = "Mean geodesic distance", diameter = "Diameter",
              mutual = "Mutual dyads", asymmetric = "Asymmetric dyads",
              null = "Null dyads", assortativity = "Degree assortativity",
              centralization_degree = "Degree centralisation",
              centralization_betweenness = "Betweenness centralisation",
              centralization_closeness = "Closeness centralisation",
              triads = "Triad census")
  unname(lookup[m] %||% m)
}
