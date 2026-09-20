# ===========================================================================
# segregation()
# ===========================================================================
# Fransson's segregation-integration difference (SID): is the network, at this
# moment, more internally clustered or more cross-cluster connected than the
# community sizes would imply?
#
# This is the one measure in the package that cannot be computed from a bare
# `dynet`. It needs a community assignment, and Dynet has no temporal
# community detection on this branch, so the partition must come from
# somewhere else. The API makes that visible rather than inventing a default.

#' Resolve a community argument to a factor over the vertex table
#'
#' @param dn A `dynet` object.
#' @param communities A named vector over vertex names, or the name of a
#'   column in `dn$nodes`.
#' @return A factor, one entry per vertex, in `dn$nodes$name` order.
#' @noRd
.resolve_communities <- function(dn, communities) {
  nodes <- dn$nodes$name
  bad <- function(message) {
    stop(errorCondition(message,
                        class = c("dynet_bad_communities", "dynet_bad_input"),
                        call = NULL))
  }
  if (is.character(communities) && length(communities) == 1L &&
      is.null(names(communities)) && communities %in% names(dn$nodes)) {
    values <- dn$nodes[[communities]]
  } else {
    if (is.null(names(communities))) {
      bad(paste0("`communities` must be named by vertex, or name a column of ",
                 "the node table. A positional vector cannot be matched to ",
                 "vertices safely."))
    }
    unknown <- setdiff(names(communities), nodes)
    if (length(unknown)) {
      bad(sprintf("Not vertices of this network: %s.",
                  paste(sQuote(unknown), collapse = ", ")))
    }
    values <- communities[match(nodes, names(communities))]
  }
  if (anyNA(values)) {
    # Dropping an unassigned vertex would change every N_a denominator, so the
    # answer would be silently wrong rather than absent.
    bad(sprintf("Every vertex needs a community; missing for %s.",
                paste(sQuote(nodes[is.na(values)]), collapse = ", ")))
  }
  factor(as.character(values))
}

#' Segregation-integration difference for one binary layer
#'
#' @param a Binary adjacency matrix for the bin, loops already cleared.
#' @param group Factor of community membership, in matrix row order.
#' @param undirected Whether `a` is symmetric, so internal edges count twice.
#' @return A single number, or `NA_real_` when any community is a singleton.
#' @noRd
.sid_layer <- function(a, group, undirected) {
  levels_seen <- levels(group)
  sizes <- table(group)
  if (any(sizes < 2L)) return(NA_real_)
  contributions <- vapply(levels_seen, function(one) {
    inside <- group == one
    n_a <- sum(inside)
    within <- sum(a[inside, inside, drop = FALSE])
    if (undirected) within <- within / 2
    between <- sum(vapply(setdiff(levels_seen, one), function(other) {
      outside <- group == other
      sum(a[inside, outside, drop = FALSE]) / (n_a * sum(outside))
    }, numeric(1L)))
    2 / (n_a * (n_a - 1L)) * within - between
  }, numeric(1L))
  sum(contributions)
}

#' Segregation-integration difference over time
#'
#' @description
#' Fransson's SID: for each time bin, how much more tied a network's
#' communities are internally than to each other, both normalised by the
#' number of pairs available. Positive means segregation exceeds integration.
#'
#' @param dn A temporal network from [dynet()].
#' @param communities Either a vector **named by vertex name**, or a single
#'   string naming a column of the node table, as [mixing()] takes. A
#'   positional vector is refused: matching a partition to vertices by
#'   position is exactly the index-based addressing this package avoids.
#' @param scope `"pertime"`, the default, for one row per bin, or `"overall"`
#'   for the mean over bins.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end,step,window The measurement grid, as in [snapshots()].
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn.
#'
#' @return A `dynet_metric` at `level = "graph"` with columns `time` (under
#'   `scope = "pertime"`), `measure`, which is the constant `"sid"`, and
#'   `value`. A leading `session` column is present under
#'   `sessions = "separate"`. **The value is signed and unbounded**: it is a
#'   difference of two normalised sums, not a proportion, so there is no range
#'   to check it against. Print it, [summary()] it, [plot()] it, or take the
#'   plain frame with [as.data.frame()].
#'
#' @details
#' A community of one vertex makes the within-community normaliser
#' `2 / (N_a (N_a - 1))` a division by zero. Rather than drop the vertex,
#' which would change every other community's denominator, the bin returns
#' `NA_real_` and a `dynet_singleton_community` warning names the offending
#' community.
#'
#' The measure is defined on undirected networks, and a directed one is read
#' by folding each layer onto its transpose, as [persistence()] does. Weights
#' and spell counts are ignored: a pair is tied in a bin or it is not.
#'
#' @section Conditions:
#' Errors: `dynet_bad_communities` when the partition is unnamed, names a
#' vertex the network does not have, or leaves a vertex unassigned;
#' `dynet_no_sessions` under `sessions = "separate"` without a session column;
#' `dynet_bad_input` when `dn` is not a `dynet`. Warns with
#' `dynet_singleton_community` when a community has one member.
#'
#' @references
#' Fransson, P., Thompson, W. H., Skiold, B., et al. (2018). Brain network
#' segregation and integration during an epoch-related working memory fMRI
#' experiment. *NeuroImage*, 178, 147-161.
#' \doi{10.1016/j.neuroimage.2018.05.040}
#'
#' Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to
#' temporal network theory. *Network Neuroscience*, 1(2), 69-99.
#' \doi{10.1162/NETN_a_00011}
#'
#' @seealso [mixing()] for who ties to whom by attribute, and [persistence()]
#'   for whether those ties survive.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' groups <- stats::setNames(
#'   rep(c("a", "b"), length.out = nrow(dn$nodes)), dn$nodes$name
#' )
#' sid <- segregation(dn, communities = groups)
#' sid
#'
#' @export
segregation <- function(dn, communities, scope = c("pertime", "overall"),
                        sessions = c("bounded", "collapse", "separate"),
                        start = NULL, end = NULL, step = NULL, window = NULL,
                        plot = FALSE) {
  scope <- match.arg(scope)
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  group <- .resolve_communities(dn, communities)

  snaps <- as.data.frame(snapshots(dn, sessions = sessions, start = start,
                                   end = end, step = step, window = window))
  blocks <- if (identical(sessions, "separate") && "session" %in% names(snaps)) {
    split(snaps, snaps$session)
  } else {
    list(all = snaps)
  }
  sizes <- table(group)
  if (any(sizes < 2L)) {
    warning(warningCondition(
      sprintf(paste0("Community %s has one member, so the within-community ",
                     "normaliser is undefined and every value is NA."),
              paste(sQuote(names(sizes)[sizes < 2L]), collapse = ", ")),
      class = "dynet_singleton_community"))
  }

  frames <- Map(function(block, label) {
    times <- sort(unique(block$time))
    layers <- lapply(.binary_layers(dn, block, times, symmetrise = TRUE),
                     function(m) {
                       diag(m) <- 0
                       m
                     })
    value <- vapply(layers, .sid_layer, numeric(1L), group = group,
                    undirected = TRUE)
    if (identical(scope, "pertime")) {
      data.frame(session = label, time = times, measure = "sid", value = value,
                 stringsAsFactors = FALSE)
    } else {
      data.frame(session = label, measure = "sid", value = mean(value),
                 stringsAsFactors = FALSE)
    }
  }, blocks, names(blocks))

  out <- .metric(
    do.call(rbind, frames), level = "graph",
    what = "Segregation-integration difference", dn = dn,
    note = "positive is more segregated than integrated; signed and unbounded"
  )
  attr(out, "communities_n") <- length(levels(group))
  attr(out, "community_sizes") <- stats::setNames(as.integer(sizes),
                                                  names(sizes))
  attr(out, "strength") <- "binary_row_sums"
  attr(out, "weights") <- "ignored"
  attr(out, "loops") <- "excluded"
  attr(out, "singleton_rule") <- "NA"
  .maybe_plot(out, plot)
}
