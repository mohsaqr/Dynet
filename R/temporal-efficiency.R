# ===========================================================================
# Temporal efficiency and temporal diameter
# ===========================================================================
# metrics(measure = "efficiency") is Krackhardt efficiency and
# metrics(measure = "diameter") is the static geodesic diameter of a bin.
# Neither says whether information can actually traverse the network in time.
# These two do, by running an all-pairs time-respecting search inside each
# reporting window.
#
# The published temporal efficiency is mean(1 / d) -- Latora & Marchiori's
# efficiency with a temporal distance substituted (Tang et al. 2010 eq. 3).
# It is NOT 1 / mean(d), which is what teneto computes and what Dynet's own
# temporal closeness uses. Verified against a live teneto 0.5.3 run on
# 2026-09-20: on the four-node Stage 3 fixture teneto returns
# 0.823529411764706, which is exactly 1/mean(d), while mean(1/d) over the same
# finite entries is 0.9087301587301587. The divergence is real and this file
# implements the published definition, not teneto's.

#' Temporal distances from every source inside one reporting window
#'
#' One search per source, sharing a single set of path tables, because
#' re-encoding per source is what makes an all-pairs temporal search slow.
#' Each source is anchored at its own presence in the window, matching
#' `paths()` and `dyn_reachability()`.
#'
#' @param dn A `dynet` object.
#' @param enc Encoded edge list for this session block.
#' @param bin One row of the measurement grid, carrying `lo` and `hi`.
#' @param sessions The session policy in force.
#' @param label The session label of this block.
#' @param basis `"hops"` for contact count, `"latency"` for elapsed time.
#' @param traversal_time Duration charged per hop.
#' @param index Integer positions of the vertices eligible in this window.
#' @return A square numeric matrix over `index`, `Inf` where no journey exists
#'   and zero on the diagonal.
#' @noRd
.temporal_distances <- function(dn, enc, bin, sessions, label, basis,
                                traversal_time, index) {
  walk <- .undirect_or_reverse(enc, dn$directed, "forward")
  walk <- .prepare_path_encoding(
    dn, walk,
    session = if (identical(sessions, "separate")) label else NULL,
    erase_sessions = !identical(sessions, "separate")
  )
  prepared <- .path_search_tables(walk, traversal_time)
  activity <- walk$path_activity
  lower <- bin$lo
  upper <- bin$hi

  rows <- lapply(index, function(s) {
    t0 <- .presence_anchor(activity, s, "forward", lower, upper)
    if (is.na(t0)) return(rep(Inf, length(index)))
    search <- .optimal_path_search(
      walk, s, t0, "forward", lower = lower, upper = upper,
      traversal_time = traversal_time, prepared = prepared
    )
    reachable <- is.finite(search$arrival[index])
    value <- if (identical(basis, "hops")) {
      as.numeric(search$n_hops[index])
    } else {
      search$arrival[index] - search$origin
    }
    value[!reachable] <- Inf
    value[is.na(value)] <- Inf
    value
  })
  out <- matrix(unlist(rows), nrow = length(index), byrow = TRUE)
  diag(out) <- 0
  out
}

#' Temporal efficiency and diameter from a distance matrix
#'
#' @param d Square matrix of temporal distances, `Inf` where unreachable.
#' @param measure Which of the two measures are wanted.
#' @param basis The distance basis, for the zero-latency guard.
#' @return A list with the requested values and `connected`, whether every
#'   ordered pair was reachable.
#' @noRd
.temporal_path_summary <- function(d, measure, basis) {
  n <- nrow(d)
  off <- row(d) != col(d)
  if (n < 2L) {
    return(list(temporal_efficiency = NA_real_, temporal_diameter = NA_real_,
                connected = NA))
  }
  distances <- d[off]
  finite <- distances[is.finite(distances)]

  efficiency <- NULL
  if ("temporal_efficiency" %in% measure) {
    if (identical(basis, "latency") && any(finite == 0)) {
      # A multi-hop journey completed within one instant has latency exactly
      # zero, so its reciprocal is infinite. Inf is the honest limit --
      # instantaneous reach -- and clamping or dropping it would be the silent
      # failure the house rules forbid. Warn and return it.
      warning(warningCondition(
        paste0("Zero-latency reachable pairs make temporal efficiency ",
               "infinite; set a positive `traversal_time` or use ",
               "`basis = \"hops\"`."),
        class = "dynet_zero_latency"))
    }
    # 1/Inf is 0, so unreachable pairs contribute nothing and the measure is
    # defined on a disconnected network. This is mean(1/d), not 1/mean(d).
    efficiency <- sum(1 / distances) / (n * (n - 1L))
  }
  diameter <- NULL
  if ("temporal_diameter" %in% measure) {
    # The diameter of the *reachable part*. `connected` says whether that is
    # the whole network; a diameter reported without it is the classic
    # misleading number.
    diameter <- if (length(finite)) max(finite) else NA_real_
  }
  list(temporal_efficiency = efficiency %||% NA_real_,
       temporal_diameter = diameter %||% NA_real_,
       connected = all(is.finite(distances)))
}
