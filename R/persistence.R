# ===========================================================================
# persistence()
# ===========================================================================
# Did this vertex keep the same neighbours from one slice to the next? That is
# topological overlap (Tang et al. 2010), and averaging it twice -- over
# transitions, then over vertices -- gives the temporal correlation
# coefficient. It needs no temporal paths, only consecutive slice comparison.
#
# This is NOT `similarity()`. That verb compares whole edge sets between every
# pair of bins and returns a bin x bin table; this compares one vertex's
# neighbourhood between adjacent bins only. A network whose vertices swap all
# their partners at every step but keep their degrees scores 0 here while
# `similarity(method = "jaccard")` can be anything at all.

#' Topological overlap between consecutive layers
#'
#' @param before,after Binary symmetric adjacency matrices for adjacent bins.
#' @return A numeric vector, one value per vertex, in matrix row order.
#' @examples
#' a <- matrix(c(0, 1, 1, 0), 2)
#' Dynet:::.topological_overlap(a, a)
#' @noRd
.topological_overlap <- function(before, after) {
  numerator <- rowSums(before * after)
  denominator <- sqrt(rowSums(before) * rowSums(after))
  # A vertex isolated in either slice gives 0/0. This is the common case, not
  # an edge case, and the convention -- shared with teneto -- is zero, read as
  # "no persistence". It is a decision, so it is written as one rather than
  # produced by letting NaN through and mopping up afterwards.
  ifelse(denominator > 0, numerator / denominator, 0)
}

#' Neighbourhood persistence between consecutive time bins
#'
#' @description
#' Topological overlap: the share of a vertex's ties that survive from one time
#' bin to the next, normalised by the geometric mean of its degrees in the two
#' bins. Averaged over a vertex's transitions it is that vertex's persistence;
#' averaged again over vertices it is the network's temporal correlation
#' coefficient (Tang et al., 2010).
#'
#' @param dn A temporal network from [dynet()].
#' @param scope `"pertime"`, the default, for one row per vertex per transition;
#'   `"node"` for each vertex's mean over its transitions; `"overall"` for the
#'   temporal correlation coefficient, one number per session.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end,step,window The measurement grid, as in [snapshots()]. A
#'   transition is a consecutive pair of bins on that grid, so the grid decides
#'   what "persisted" means; widening `step` makes persistence easier.
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn.
#'
#' @return A `dynet_metric`. Under `scope = "pertime"` it is `level = "node"`
#'   with columns `time`, `node`, `measure` and `value`, one row per vertex per
#'   transition, where `time` is the **earlier** bin of the pair; the final bin
#'   opens no transition and so contributes no rows at all, rather than a row
#'   whose value is structurally undefined. Under `scope = "node"` it is
#'   `level = "node"` with `node`, `measure` and `value`, one row per vertex.
#'   Under `scope = "overall"` it is `level = "graph"` with `measure` and
#'   `value`, one row per session. A leading `session` column is present under
#'   `sessions = "separate"`. `measure` is `"topological_overlap"`,
#'   `"average_topological_overlap"` and `"temporal_correlation"` respectively,
#'   and `value` lies in `[0, 1]` at every scope. Print it, [summary()] it,
#'   [plot()] it, or take the plain frame with [as.data.frame()].
#'
#' @details
#' The measure is defined on undirected neighbourhoods, so a directed network
#' is read as a contact network here: each layer is folded onto its transpose
#' before the overlap is taken. Weights and spell counts are ignored -- a pair
#' is tied in a bin or it is not -- and loops are excluded.
#'
#' A vertex isolated in either bin of a transition scores zero rather than a
#' missing value. That is a substantive claim, not an arithmetic accident: the
#' ratio is genuinely 0/0, and zero is the convention teneto uses. A reader who
#' wants isolation and genuine turnover distinguished should read the degree
#' alongside, which [dyn_centrality()] gives.
#'
#' @section Conditions:
#' Errors: `dynet_empty_result` when the grid yields fewer than two bins, since
#' a single bin opens no transition and the measure is undefined;
#' `dynet_no_sessions` when `sessions = "separate"` is asked of a network with
#' no session column; and `dynet_bad_input` when `dn` is not a `dynet`.
#'
#' @references
#' Tang, J., Scellato, S., Musolesi, M., Mascolo, C., & Latora, V. (2010).
#' Small-world behavior in time-varying graphs. *Physical Review E*, 81(5),
#' 055101(R). \doi{10.1103/PhysRevE.81.055101}
#'
#' Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora, V.
#' (2013). Graph metrics for temporal networks. In P. Holme & J. Saramaki
#' (Eds.), *Temporal Networks* (pp. 15-40). Springer.
#' \doi{10.1007/978-3-642-36461-7_2}
#'
#' Clauset, A., & Eagle, N. (2007). Persistence and periodicity in a dynamic
#' proximity network. *DIMACS Workshop on Computational Methods for Dynamic
#' Interaction Networks*.
#'
#' @seealso [similarity()], which compares whole edge sets between every pair
#'   of bins and answers a different question, and [turnover()] for the
#'   complementary view of what changed.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' kept <- persistence(dn)
#' kept
#'
#' per_node <- persistence(dn, scope = "node")
#' per_node
#'
#' overall <- persistence(dn, scope = "overall")
#' overall
#'
#' @export
persistence <- function(dn, scope = c("pertime", "node", "overall"),
                        sessions = c("bounded", "collapse", "separate"),
                        start = NULL, end = NULL, step = NULL, window = NULL,
                        plot = FALSE) {
  scope <- match.arg(scope)
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)

  snaps <- as.data.frame(snapshots(dn, sessions = sessions, start = start,
                                   end = end, step = step, window = window))
  blocks <- if (identical(sessions, "separate") && "session" %in% names(snaps)) {
    split(snaps, snaps$session)
  } else {
    list(all = snaps)
  }

  per_block <- Map(function(block, label) {
    times <- sort(unique(block$time))
    if (length(times) < 2L) {
      stop(errorCondition(
        paste0("Persistence needs at least two time bins; a single bin opens ",
               "no transition. Widen the range or lower `step`."),
        class = "dynet_empty_result", call = NULL))
    }
    # Always symmetrise: the published definition is for undirected graphs.
    layers <- lapply(.binary_layers(dn, block, times, symmetrise = TRUE),
                     function(m) {
                       diag(m) <- 0
                       m
                     })
    transitions <- seq_len(length(times) - 1L)
    overlap <- lapply(transitions, function(k) {
      .topological_overlap(layers[[k]], layers[[k + 1L]])
    })
    list(label = label, times = times[transitions], overlap = overlap)
  }, blocks, names(blocks))

  nodes <- dn$nodes$name
  frames <- lapply(per_block, function(one) {
    # One computation feeds all three scopes, so they cannot disagree.
    per_node <- rowMeans(matrix(unlist(one$overlap), nrow = length(nodes)))
    switch(scope,
      pertime = data.frame(
        session = one$label,
        time = rep(one$times, each = length(nodes)),
        node = rep(nodes, times = length(one$times)),
        measure = "topological_overlap",
        value = unlist(one$overlap, use.names = FALSE),
        stringsAsFactors = FALSE
      ),
      node = data.frame(
        session = one$label, node = nodes,
        measure = "average_topological_overlap", value = per_node,
        stringsAsFactors = FALSE
      ),
      overall = data.frame(
        session = one$label, measure = "temporal_correlation",
        value = mean(per_node), stringsAsFactors = FALSE
      )
    )
  })

  out <- .metric(
    do.call(rbind, frames),
    level = if (identical(scope, "overall")) "graph" else "node",
    what = switch(scope,
      pertime = "Neighbourhood persistence per transition",
      node = "Neighbourhood persistence per vertex",
      overall = "Temporal correlation coefficient"),
    dn = dn,
    note = "1 keeps every neighbour, 0 keeps none; an isolated vertex scores 0"
  )
  attr(out, "overlap_normalisation") <- "geometric_mean_of_degrees"
  attr(out, "empty_neighbourhood") <- "zero"
  attr(out, "weights") <- "ignored"
  attr(out, "loops") <- "excluded"
  attr(out, "final_bin") <- "dropped"
  .maybe_plot(out, plot)
}
