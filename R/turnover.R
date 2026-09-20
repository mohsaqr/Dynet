# ===========================================================================
# turnover()
# ===========================================================================
# Two whole-network dynamics summaries from Thompson, Brantefors & Fransson
# (2017). Volatility is how much the edge set changed from one slice to the
# next; fluctuability is whether the edge events were spread over many
# distinct pairs or concentrated on a few.
#
# events() cannot substitute for volatility: on a contact network a point
# contact registers as a formation and a dissolution in the same bin, so its
# counts do not describe a transition between slices.

#' Eligible non-loop pair count for a vertex universe
#' @param n Number of vertices.
#' @param directed Whether ordered pairs are the domain.
#' @return A single number: the size of the pair domain.
#' @examples
#' Dynet:::.pair_domain_size(4L, FALSE)
#' @noRd
.pair_domain_size <- function(n, directed) {
  if (n < 2L) return(0)
  if (directed) n * (n - 1L) else n * (n - 1L) / 2
}

#' Proportion Hamming distance between two binary layers
#'
#' The pair domain is the strict upper triangle when undirected and every
#' off-diagonal cell when directed, which is what makes this a proportion in
#' `[0, 1]` rather than the raw symmetric-matrix count
#' `cograph::layer_similarity(method = "hamming")` returns.
#'
#' @param before,after Binary adjacency matrices for adjacent bins.
#' @param directed Whether ordered pairs are the domain.
#' @return A single number in `[0, 1]`.
#' @examples
#' a <- matrix(c(0, 1, 1, 0), 2); b <- matrix(0, 2, 2)
#' Dynet:::.hamming_proportion(a, b, FALSE)
#' @noRd
.hamming_proportion <- function(before, after, directed) {
  n <- nrow(before)
  domain <- if (directed) {
    row(before) != col(before)
  } else {
    upper.tri(before)
  }
  # 0/1 entries compared as integers; no double equality anywhere.
  storage.mode(before) <- "integer"
  storage.mode(after) <- "integer"
  sum(before[domain] != after[domain]) / .pair_domain_size(n, directed)
}

#' Network turnover: volatility and fluctuability
#'
#' @description
#' `"volatility"` is the proportion of eligible pairs whose tie state changed
#' between one time bin and the next. `"fluctuability"` is the number of
#' distinct pairs ever active divided by the total number of pair-bin
#' activations, so it is low when the same few pairs recur and high when
#' activity is spread thin.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure `"volatility"`, the default, or `"fluctuability"`. Both may
#'   be asked for at once at `scope = "overall"`.
#' @param scope `"pertime"`, the default, for one row per transition, or
#'   `"overall"` for one row per measure. `"fluctuability"` is defined only at
#'   `"overall"`: it is a property of the whole observed series, and a per-bin
#'   value would be the constant 1 dressed up as data.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end,step,window The measurement grid, as in [snapshots()].
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn.
#'
#' @return A `dynet_metric` at `level = "graph"`. Under `scope = "pertime"` the
#'   columns are `time`, `measure` and `value`, one row per transition, where
#'   `time` is the **earlier** bin of the pair; the final bin opens no
#'   transition and contributes no row. Under `scope = "overall"` they are
#'   `measure` and `value`, one row per requested measure. A leading `session`
#'   column is present under `sessions = "separate"`. `volatility` lies in
#'   `[0, 1]` and `fluctuability` in `(0, 1]`, or is `NA_real_` when no pair is
#'   active anywhere in the grid. Print it, [summary()] it, [plot()] it, or
#'   take the plain frame with [as.data.frame()].
#'
#' @details
#' Volatility is the *proportion* Hamming distance over the eligible non-loop
#' pair domain: the strict upper triangle for an undirected network, every
#' ordered off-diagonal pair for a directed one. This is not the scale
#' `cograph::layer_similarity(method = "hamming")` uses, which is a raw count
#' over the full symmetric matrix and is therefore `2 * choose(n, 2)` times
#' larger on an undirected network.
#'
#' **Fluctuability is grid-dependent and comparable only across networks
#' measured on the same grid.** Its denominator sums per-bin active-pair
#' counts, so halving `step` roughly doubles it and roughly halves the result.
#' That is a property of the published definition rather than a defect; teneto's
#' own documentation concedes the measure is not normalised in a way that makes
#' comparisons across very different networks meaningful.
#'
#' Weights and spell counts are ignored throughout: a pair is tied in a bin or
#' it is not. Loops are excluded from the domain.
#'
#' @section Conditions:
#' Errors: `dynet_incompatible_scope` when `"fluctuability"` is asked for at
#' `scope = "pertime"`; `dynet_empty_result` when the grid yields fewer than two
#' bins, or when the network has fewer than two vertices and the pair domain is
#' empty; `dynet_no_sessions` when `sessions = "separate"` is asked of a network
#' with no session column; and `dynet_bad_input` when `dn` is not a `dynet`.
#'
#' @references
#' Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to
#' temporal network theory: applications to functional brain connectivity.
#' *Network Neuroscience*, 1(2), 69-99. \doi{10.1162/NETN_a_00011}
#'
#' Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
#' 519(3), 97-125. \doi{10.1016/j.physrep.2012.03.001}
#'
#' @seealso [persistence()] for the node-level view of what survived, and
#'   [events()] for raw formation and dissolution counts.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' churn <- turnover(dn)
#' churn
#'
#' summarised <- turnover(dn, measure = c("volatility", "fluctuability"),
#'                        scope = "overall")
#' summarised
#'
#' @export
turnover <- function(dn, measure = c("volatility", "fluctuability"),
                     scope = c("pertime", "overall"),
                     sessions = c("bounded", "collapse", "separate"),
                     start = NULL, end = NULL, step = NULL, window = NULL,
                     plot = FALSE) {
  scope <- match.arg(scope)
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  allowed <- c("volatility", "fluctuability")
  if (missing(measure)) measure <- "volatility"
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }
  if (identical(scope, "pertime") && "fluctuability" %in% measure) {
    stop(errorCondition(
      paste0("`fluctuability` is a property of the whole series and exists ",
             "only at scope = \"overall\"; a per-bin value would be the ",
             "constant 1."),
      class = c("dynet_incompatible_scope", "dynet_bad_input"), call = NULL))
  }
  domain <- .pair_domain_size(nrow(dn$nodes), dn$directed)
  if (domain == 0) {
    stop(errorCondition(
      "Turnover needs at least two vertices; the pair domain is empty.",
      class = "dynet_empty_result", call = NULL))
  }

  snaps <- as.data.frame(snapshots(dn, sessions = sessions, start = start,
                                   end = end, step = step, window = window))
  blocks <- if (identical(sessions, "separate") && "session" %in% names(snaps)) {
    split(snaps, snaps$session)
  } else {
    list(all = snaps)
  }

  frames <- Map(function(block, label) {
    times <- sort(unique(block$time))
    if (length(times) < 2L) {
      stop(errorCondition(
        paste0("Turnover needs at least two time bins; a single bin opens no ",
               "transition. Widen the range or lower `step`."),
        class = "dynet_empty_result", call = NULL))
    }
    layers <- lapply(.binary_layers(dn, block, times,
                                    symmetrise = !dn$directed),
                     function(m) {
                       diag(m) <- 0
                       m
                     })
    transitions <- seq_len(length(times) - 1L)
    # Computed once; `"overall"` is its mean, so the two scopes cannot drift.
    volatility <- vapply(transitions, function(k) {
      .hamming_proportion(layers[[k]], layers[[k + 1L]], dn$directed)
    }, numeric(1L))

    if (identical(scope, "pertime")) {
      return(data.frame(session = label, time = times[transitions],
                        measure = "volatility", value = volatility,
                        stringsAsFactors = FALSE))
    }

    rows <- lapply(measure, function(m) {
      value <- if (identical(m, "volatility")) {
        mean(volatility)
      } else {
        mask <- if (dn$directed) {
          row(layers[[1L]]) != col(layers[[1L]])
        } else upper.tri(layers[[1L]])
        active <- Reduce(`|`, lapply(layers, function(one) one[mask] > 0))
        activations <- sum(vapply(layers, function(one) sum(one[mask] > 0),
                                  numeric(1L)))
        # An empty series is genuinely 0/0. Say so rather than returning a
        # zero that reads as "activity was maximally concentrated".
        if (activations > 0) sum(active) / activations else NA_real_
      }
      data.frame(session = label, measure = m, value = value,
                 stringsAsFactors = FALSE)
    })
    do.call(rbind, rows)
  }, blocks, names(blocks))

  out <- .metric(
    do.call(rbind, frames), level = "graph",
    what = if (identical(scope, "pertime")) {
      "Turnover per transition"
    } else "Turnover over the series",
    dn = dn,
    note = "volatility 0 is a frozen network; fluctuability 1 repeats no pair"
  )
  attr(out, "distance") <- "hamming_proportion"
  attr(out, "opportunity_domain") <- if (dn$directed) {
    "eligible_nonloop_ordered_pairs"
  } else "eligible_nonloop_unordered_dyads"
  attr(out, "weights") <- "ignored"
  attr(out, "loops") <- "excluded"
  attr(out, "final_bin") <- "dropped"
  attr(out, "empty_series") <- "NA"
  .maybe_plot(out, plot)
}
