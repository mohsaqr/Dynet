# ===========================================================================
# metrics() — time-varying graph-level structure
# ===========================================================================

.graph_measures <- c(
  "density", "edges", "active_nodes", "isolates", "transitivity",
  "reciprocity", "components", "components_strong",
  "largest_component", "mean_distance",
  "diameter", "mutual", "asymmetric", "null", "assortativity",
  "centralization_degree", "centralization_betweenness",
  "centralization_closeness", "triads",
  "connectedness", "efficiency", "hierarchy", "lubness",
  "degree_mean", "degree_variance", "degree_min", "degree_max",
  "mean_degree", "indegree_1_5", "outdegree_1_5", "triangles",
  "concurrent_nodes", "concurrent_share", "in_2stars", "out_2stars",
  "two_paths",
  "temporal_density", "observed_pair_density", "onset_intensity",
  "observed_pair_onset_intensity"
)

.temporal_graph_measures <- c(
  "temporal_density", "observed_pair_density", "onset_intensity",
  "observed_pair_onset_intensity"
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
#'   `"components_strong"`, `"largest_component"`, `"mean_distance"`,
#'   `"diameter"`, `"mutual"`,
#'   `"asymmetric"`, `"null"`, `"assortativity"`,
#'   `"centralization_degree"`, `"centralization_betweenness"`,
#'   `"centralization_closeness"`, `"triads"`, `"connectedness"`,
#'   `"efficiency"`, `"hierarchy"`, `"lubness"`. `"triads"` expands to the
#'   sixteen triad classes; the last four are Krackhardt's indices of
#'   hierarchy. Lightweight structural summaries are `"degree_mean"`,
#'   `"degree_variance"`, `"degree_min"`, `"degree_max"`,
#'   `"mean_degree"`, `"indegree_1_5"`, `"outdegree_1_5"`, `"triangles"`,
#'   `"concurrent_nodes"`, `"concurrent_share"`, `"in_2stars"`,
#'   `"out_2stars"`, and `"two_paths"`. Exact window-integrated quantities are `"temporal_density"`,
#'   `"observed_pair_density"`, `"onset_intensity"`, and
#'   `"observed_pair_onset_intensity"`.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param sample Deprecated. `"instant"` is equivalent to `window = 0`;
#'   `"window"` uses the current positive/default window.
#' @param start,end First and last time at which to measure. Default to the
#'   observed range. A network built from dates may be addressed with dates.
#' @param step How often to measure. Defaults to the interval the network was
#'   built with.
#' @param window How much time each measurement covers. Defaults to `step`,
#'   which tiles the period into disjoint bins. A larger value slides an
#'   overlapping window; `0` samples the network at each point in time.
#'
#' @return A `dynet_metric` at graph level: one row per time point and
#'   measure, with columns `session` (when present), `time`, `measure` and
#'   `value`.
#'
#' @details
#' `"density"` counts the any-time union of realised edges against eligible
#' possible edges in each bin. The four temporal selectors instead integrate
#' exact state over positive observed time inside every reporting window.
#' `"temporal_density"` is binary occupied pair-time divided by all eligible
#' nonloop ordered-pair time (directed) or dyad time (undirected).
#' `"observed_pair_density"` uses the same numerator but restricts opportunity
#' to pairs having endpoint-valid evidence anywhere in the complete stored
#' history. That cohort is not reset by reporting windows or observation gaps.
#' [summary()] reports the first quantity over the pooled full history.
#'
#' If `Y[r](t)` is exact simultaneous endpoint eligibility, `E[r](t)` is
#' binary edge presence, and `H` is the ever-observed pair set, the exposure
#' ledgers are `R = sum(r) integral(Y[r](t) dt)`,
#' `O = sum(r) integral(Y[r](t) E[r](t) dt)`, and
#' `R_H = sum(r in H) integral(Y[r](t) dt)`. The two occupancies are `O/R`
#' and `O/R_H` and lie in `[0, 1]`. Loops, weights, duplicates, and censor
#' flags cannot multiply occupancy.
#'
#' `"onset_intensity"` and `"observed_pair_onset_intensity"` divide the
#' number of known raw spell starts by `R` and `R_H`. Each nonloop raw row,
#' including a point contact, contributes once when its start is observed,
#' not onset-censored, and has exactly eligible endpoints. Termini are not
#' events; overlaps and duplicates remain distinct onsets. Intensities are
#' nonnegative, unbounded, and measured in inverse network time. A zero
#' denominator gives `NA` for every temporal selector, even when a point event
#' exists. A positive denominator with a zero numerator gives zero. Therefore
#' `window = 0` makes all four temporal selectors undefined while snapshot
#' measures retain their exact point-state meanings.
#'
#' `step` and `window` are separate on purpose: `step` is how often you look,
#' `window` is how much of the timeline each look takes in. A seven-day window
#' stepped one day at a time smooths a noisy series without giving up daily
#' resolution. They match `time.interval` and `aggregate.dur` in
#' `tsna::tSnaStats()`.
#'
#' When vertex activity was declared in [dynet()], every measure is computed
#' on the endpoint-induced eligible vertex set for the window. Positive
#' windows independently use the any-time vertex and edge unions before
#' induction; `window = 0` evaluates the exact state. Density and census
#' opportunities, components, isolate counts, largest-component shares, and
#' Freeman denominators therefore use eligible rather than fixed order.
#'
#' Krackhardt's four indices -- `"connectedness"`, `"efficiency"`,
#' `"hierarchy"` and `"lubness"` -- describe how far a directed network
#' departs from a pure out-tree. `"hierarchy"` and `"lubness"` are undefined
#' on some graphs (no connected pair, no component of three) and report `NaN`
#' rather than a number that would mislead.
#'
#' Triad census cost grows with the cube of the vertex count. On a network of
#' a few hundred vertices it is the slowest measure here by a wide margin.
#'
#' The lightweight structural selectors use the binary, loop-free induced
#' snapshot. Directed total degree is in-degree plus out-degree;
#' `"degree_variance"` is the sample variance across eligible vertices.
#' `"mean_degree"` is the mean out-degree for a directed graph (identically,
#' the mean in-degree) and the ordinary mean degree for an undirected graph;
#' this matches ERGM's `meandeg` statistic. `"indegree_1_5"` and
#' `"outdegree_1_5"` sum the corresponding vertex degrees raised to 1.5.
#' Directed `"triangles"` is the sum of cyclic and transitive triples, while
#' an undirected triangle is counted once.
#' A concurrent vertex has at least two distinct neighbours, so a reciprocal
#' dyad still supplies only one neighbour. `"in_2stars"` and `"out_2stars"`
#' sum `choose(degree, 2)` over directed in- and out-degrees. Directed
#' `"two_paths"` counts ordered `i -> j -> k` paths with `i != k`;
#' undirected two-paths count each unordered wedge once. Empty eligible
#' snapshots return zero for all selectors.
#'
#' @references
#' Freeman, L. C. (1979). Centrality in social networks: conceptual
#' clarification. *Social Networks*, 1, 215-239.
#' \doi{10.1016/0378-8733(78)90021-7}
#'
#' Butts, C. T., Leslie-Cook, A., Krivitsky, P. N., & Bender-deMoll, S.
#' (2024). *networkDynamic: Dynamic Extensions for Network Objects*, version
#' 0.11.5. \doi{10.32614/CRAN.package.networkDynamic}
#'
#' Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
#' 519(3), 97-125. \doi{10.1016/j.physrep.2012.03.001}
#'
#' Latapy, M., Viard, T., & Magnien, C. (2018). Stream graphs and link streams
#' for the modeling of interactions over time. *Social Network Analysis and
#' Mining*, 8, 61. \doi{10.1007/s13278-018-0537-7}
#'
#' Andersen, P. K., & Gill, R. D. (1982). Cox's regression model for counting
#' processes: a large sample study. *Annals of Statistics*, 10, 1100-1120.
#' \doi{10.1214/aos/1176345976}
#'
#' @examples
#' dn <- dynet(school_contacts)
#' metrics(dn, measure = "density")
#' metrics(dn, measure = c("density", "reciprocity", "transitivity"))
#' metrics(dn, measure = "density", step = 1, window = 3)
#' plot(metrics(dn, measure = c("mutual", "asymmetric")))
#'
#' @export
metrics <- function(dn, measure = "density",
                        sessions = c("bounded", "collapse", "separate"),
                        sample = NULL,
                        start = NULL, end = NULL,
                        step = NULL, window = NULL) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  window <- .legacy_sample(window, sample)
  spec <- .window_spec(dn, start, end, step, window)
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
    dir_only <- intersect(measure, c(
      "reciprocity", "mutual", "asymmetric", "null",
      "in_2stars", "out_2stars", "indegree_1_5", "outdegree_1_5"
    ))
    if (length(dir_only) > 0L) {
      stop(errorCondition(
        sprintf("%s needs a directed network; this one is undirected.",
                paste(sQuote(dir_only), collapse = ", ")),
        class = "dynet_needs_directed", call = NULL))
    }
  }

  df <- .over_bins(dn, sessions, node_level = FALSE, spec = spec,
    snapshot = TRUE, fun = function(enc, act, bin, state) {
      full <- .adjacency(enc, act, dn$directed)
      a <- full[state$index, state$index, drop = FALSE]
      temporal <- intersect(measure, .temporal_graph_measures)
      temporal_values <- if (length(temporal)) {
        label <- if (identical(sessions, "separate")) {
          as.character(enc$raw_event_session[[1L]])
        } else "all"
        .temporal_edge_values(.temporal_edge_ledger(
          dn, enc, bin, sessions, label
        ))
      } else numeric()
      unlist(lapply(measure, function(m) {
        if (m %in% .temporal_graph_measures) {
          stats::setNames(unname(temporal_values[[m]]), m)
        } else .graph_measure(m, a, dn$directed)
      }), use.names = TRUE)
    })

  out <- .metric(
    df, level = "graph",
    what = if (length(measure) == 1L) .graph_label(measure) else "Graph structure",
    dn = dn, spec = spec
  )
  has_temporal <- any(measure %in% .temporal_graph_measures)
  has_snapshot <- any(!measure %in% .temporal_graph_measures)
  if (has_temporal && has_snapshot) {
    attr(out, "vertex_population") <- stats::setNames(
      ifelse(measure %in% .temporal_graph_measures,
             "eligible_at_time", "eligible_window_any_induced"), measure
    )
    attr(out, "vertex_window_rule") <- stats::setNames(
      ifelse(measure %in% .temporal_graph_measures, "exact_change_point",
             if (spec$window == 0) "instant_exact" else "any"), measure
    )
    attr(out, "edge_endpoint_rule") <- stats::setNames(
      ifelse(measure %in% .temporal_graph_measures,
             "both_endpoints_eligible_at_time",
             "induced_after_elementwise_union"), measure
    )
  } else if (has_temporal) {
    attr(out, "vertex_population") <- "eligible_at_time"
    attr(out, "vertex_window_rule") <- "exact_change_point"
    attr(out, "edge_endpoint_rule") <- "both_endpoints_eligible_at_time"
  } else {
    attr(out, "vertex_population") <- "eligible_window_any_induced"
    attr(out, "vertex_window_rule") <- if (spec$window == 0) {
      "instant_exact"
    } else "any"
    attr(out, "edge_endpoint_rule") <- "induced_after_elementwise_union"
  }
  attr(out, "opportunity_domain") <- if (dn$directed) {
    "eligible_nonloop_ordered_pairs"
  } else "eligible_nonloop_unordered_dyads"
  attr(out, "vertex_observation") <- "component_intersection_non_destructive"
  attr(out, "measure_scope") <- stats::setNames(
    ifelse(measure %in% .temporal_graph_measures,
           "whole_window_exact", "snapshot_any_union"),
    measure
  )
  effective_sessions <- if (identical(sessions, "bounded") &&
                            is.null(dn$meta$sessions)) "collapse" else sessions
  attr(out, "session_vertex_aggregation") <- switch(
    effective_sessions,
    collapse = "calendar_union", bounded = "session_induced_union",
    separate = "session_local"
  )
  if (has_temporal) {
    attr(out, "temporal_numerator") <- stats::setNames(
      c(
        temporal_density = "binary_occupied_pair_time",
        observed_pair_density = "binary_occupied_pair_time",
        onset_intensity = "known_raw_onsets",
        observed_pair_onset_intensity = "known_raw_onsets"
      )[intersect(measure, .temporal_graph_measures)],
      intersect(measure, .temporal_graph_measures)
    )
    attr(out, "temporal_denominator") <- stats::setNames(
      c(
        temporal_density = "all_eligible_pair_time",
        observed_pair_density = "ever_observed_eligible_pair_time",
        onset_intensity = "all_eligible_pair_time",
        observed_pair_onset_intensity = "ever_observed_eligible_pair_time"
      )[intersect(measure, .temporal_graph_measures)],
      intersect(measure, .temporal_graph_measures)
    )
    attr(out, "pair_set_scope") <-
      "full_observed_history_no_window_or_gap_reset"
    attr(out, "risk_clock") <- "positive_observed_time"
    attr(out, "risk_integration") <- "exact_change_point"
    attr(out, "occupancy") <- "binary_pair_calendar_union"
    attr(out, "onset_identity") <- "uncensored_raw_spell_start"
    attr(out, "onset_eligibility") <- "exact_not_two_sided"
    attr(out, "instantaneous_exposure") <- "zero"
    attr(out, "weights") <- "ignored"
    attr(out, "loops") <- "excluded"
    attr(out, "temporal_session_aggregation") <- switch(
      effective_sessions, collapse = "labels_erased_calendar_union",
      bounded = "session_local_then_calendar_union",
      separate = "session_local"
    )
    attr(out, "temporal_unit") <- stats::setNames(
      c(
        temporal_density = "probability",
        observed_pair_density = "probability",
        onset_intensity = paste0("per_", dn$meta$time_unit),
        observed_pair_onset_intensity = paste0("per_", dn$meta$time_unit)
      )[intersect(measure, .temporal_graph_measures)],
      intersect(measure, .temporal_graph_measures)
    )
  }
  lightweight <- intersect(measure, c(
    "degree_mean", "degree_variance", "degree_min", "degree_max",
    "mean_degree", "indegree_1_5", "outdegree_1_5", "triangles",
    "concurrent_nodes", "concurrent_share", "in_2stars", "out_2stars",
    "two_paths"
  ))
  if (length(lightweight)) {
    attr(out, "structural_binary") <- TRUE
    attr(out, "structural_loops") <- "excluded"
    attr(out, "concurrency_rule") <- "at_least_two_distinct_neighbours"
    attr(out, "degree_rule") <- if (dn$directed) {
      "incoming_plus_outgoing_arcs"
    } else "distinct_neighbours"
    attr(out, "two_path_rule") <- if (dn$directed) {
      "ordered_distinct_endpoints"
    } else "unordered_distinct_endpoints"
  }
  out
}

#' Compute one graph-level measure
#' @param m Measure name.
#' @param a Adjacency matrix for the bin.
#' @param directed Whether the network is directed.
#' @return A named numeric vector; length one except for `"triads"`.
#' @examples
#' a <- matrix(c(0, 1, 0, 0), 2, 2)
#' Dynet:::.graph_measure("density", a, directed = TRUE)
#' @keywords internal
.graph_measure <- function(m, a, directed) {
  b <- .binary(a, directed)
  n <- nrow(b)
  if (n == 0L) {
    empty <- switch(m,
      density = 0, edges = 0, active_nodes = 0, isolates = 0,
      transitivity = 1, reciprocity = 0, components = 0,
      components_strong = 0, largest_component = 0,
      mean_distance = NA_real_, diameter = NA_real_, mutual = 0,
      asymmetric = 0, null = 0, assortativity = NA_real_,
      centralization_degree = NA_real_,
      centralization_betweenness = NA_real_,
      centralization_closeness = NA_real_,
      triads = stats::setNames(
        rep(0, 16),
        c("003", "012", "102", "021D", "021U", "021C", "111D", "111U",
          "030T", "030C", "201", "120D", "120U", "120C", "210", "300")
      ),
      connectedness = 1, efficiency = 0, hierarchy = NaN, lubness = NaN,
      degree_mean = 0, degree_variance = 0, degree_min = 0,
      degree_max = 0, mean_degree = 0, indegree_1_5 = 0,
      outdegree_1_5 = 0, triangles = 0,
      concurrent_nodes = 0, concurrent_share = 0,
      in_2stars = 0, out_2stars = 0, two_paths = 0
    )
    if (identical(m, "triads")) {
      return(stats::setNames(empty, paste0("triad_", names(empty))))
    }
    return(stats::setNames(empty, m))
  }
  possible <- if (directed) n * (n - 1) else n * (n - 1) / 2
  n_edges <- if (directed) sum(b) else sum(b) / 2

  val <- switch(m,
    density      = if (possible > 0) n_edges / possible else 0,
    edges        = n_edges,
    active_nodes = sum(rowSums(b) + colSums(b) > 0),
    isolates     = sum(rowSums(b) + colSums(b) == 0),
    transitivity = .transitivity(a, directed),
    reciprocity  = .reciprocity(a),
    components        = .components(a, "weak")$count,
    components_strong = .components(a, "strong")$count,
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
      # Direction is read outward here, as igraph and sna do; the matching
      # denominator is the one for out-closeness.
      .centralisation(.closeness(a, directed, "out"),
                      .max_centralisation("closeness", n, directed)),
    triads = .triad_census(a),
    connectedness = .connectedness(a),
    efficiency    = .efficiency(a, directed),
    hierarchy     = .krackhardt_hierarchy(a),
    lubness       = .lubness(a),
    degree_mean = mean(.margin(b, directed, "all")),
    degree_variance = if (n > 1L) stats::var(.margin(b, directed, "all")) else 0,
    degree_min = min(.margin(b, directed, "all")),
    degree_max = max(.margin(b, directed, "all")),
    mean_degree = if (directed) mean(rowSums(b)) else mean(rowSums(b)),
    indegree_1_5 = sum(colSums(b)^1.5),
    outdegree_1_5 = sum(rowSums(b)^1.5),
    triangles = if (directed) {
      sum(diag(b %*% b %*% b)) / 3 + sum(b * (b %*% b))
    } else {
      sum(diag(b %*% b %*% b)) / 6
    },
    concurrent_nodes = sum(rowSums(pmax(b, t(b))) >= 2L),
    concurrent_share = mean(rowSums(pmax(b, t(b))) >= 2L),
    in_2stars = sum(choose(colSums(b), 2)),
    out_2stars = sum(choose(rowSums(b), 2)),
    two_paths = if (directed) {
      sum((b %*% b)[row(b) != col(b)])
    } else {
      sum(choose(rowSums(b), 2))
    }
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
#' @return A single numeric value; `NA` below three vertices, where the most
#'   centralised graph is not defined.
#' @keywords internal
.max_centralisation <- function(what, n, directed) {
  if (n < 3L) return(NA_real_)
  # Degree and betweenness use the standard Freeman maxima. Closeness uses
  # Dynet's disconnected-graph score (reachable vertices / reachable distance),
  # whose maxima are a single directed arc and an isolated undirected dyad.
  switch(what,
    degree      = if (directed) (n - 1) * (2 * n - 4) else (n - 1) * (n - 2),
    betweenness = if (directed) (n - 1)^2 * (n - 2) else (n - 1)^2 * (n - 2) / 2,
    closeness   = if (directed) n - 1 else n - 2
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
              components_strong = "Strong components",
              largest_component = "Largest component share",
              mean_distance = "Mean geodesic distance", diameter = "Diameter",
              mutual = "Mutual dyads", asymmetric = "Asymmetric dyads",
              null = "Null dyads", assortativity = "Degree assortativity",
              centralization_degree = "Degree centralisation",
              centralization_betweenness = "Betweenness centralisation",
              centralization_closeness = "Closeness centralisation",
              mean_degree = "Mean degree",
              indegree_1_5 = "In-degree to power 1.5",
              outdegree_1_5 = "Out-degree to power 1.5",
              triangles = "Triangles",
              triads = "Triad census",
              connectedness = "Krackhardt connectedness",
              efficiency = "Krackhardt efficiency",
              hierarchy = "Krackhardt hierarchy",
              lubness = "Krackhardt LUBness",
              degree_mean = "Mean degree",
              degree_variance = "Degree variance",
              degree_min = "Minimum degree", degree_max = "Maximum degree",
              concurrent_nodes = "Concurrent vertices",
              concurrent_share = "Concurrent vertex share",
              in_2stars = "In-2-stars", out_2stars = "Out-2-stars",
              two_paths = "Two-paths",
              temporal_density = "Temporal density",
              observed_pair_density = "Observed-pair temporal density",
              onset_intensity = "Edge-onset intensity",
              observed_pair_onset_intensity =
                "Observed-pair edge-onset intensity")
  unname(lookup[m] %||% m)
}
