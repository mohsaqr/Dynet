# ===========================================================================
# Temporal null models
# ===========================================================================
# A measured value is not a finding until we know what an unstructured network
# would have shown. This file builds the reference distribution: a verb that
# produces surrogate networks, each destroying one specific kind of structure
# while holding the rest fixed.

#' Evaluate an expression under a seed, restoring the caller's stream
#'
#' @param seed `NULL` to use the ambient stream, or a single whole number.
#' @param code Expression to evaluate, forced once.
#' @return The value of `code`. When `seed` is not `NULL` the caller's
#'   `.Random.seed` is exactly as it was on entry, whether or not it existed.
#' @noRd
.with_seed <- function(seed, code) {
  if (is.null(seed)) return(code)
  .check(
    "`seed` must be a single whole number." =
      length(seed) == 1L && is.numeric(seed) && is.finite(seed) &&
        seed == trunc(seed)
  )
  # Assigning NULL is not the same as removing: a .Random.seed of NULL is a
  # corrupt object, so the absent case must restore absence.
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    old <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(assign(".Random.seed", old, envir = globalenv()),
            add = TRUE, after = FALSE)
  } else {
    on.exit(
      if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
        rm(".Random.seed", envir = globalenv())
      }, add = TRUE, after = FALSE)
  }
  set.seed(seed)
  code
}

# What each method holds fixed and what it destroys. This is the documentation
# as much as the implementation: a null model whose invariants are unstated is
# not a null model.
.null_preserves <- c(
  reversal  = "every spell duration; every pair; each pair's event count; the aggregate weighted adjacency; all degrees",
  times     = "the multiset of (start, end) pairs, so the activity profile and duration distribution exactly; the pair set; each pair's event count",
  timeline  = "each pair's whole event sequence intact, so per-link burstiness and memory; the pair set; the total event count",
  edges     = "the aggregate degree sequence, in and out separately when directed; every timeline; the number of distinct pairs",
  targets   = "each sender's event times and out-activity exactly",
  labels    = "everything structural: the surrogate is isomorphic to the original"
)
.null_destroys <- c(
  reversal  = "the arrow of time: every time-respecting path, all forward/backward asymmetry, causal ordering",
  times     = "which pair was active when, so all coupling between topology and timing, and each pair's burstiness",
  timeline  = "the attachment of a timeline to a pair, and each pair's event count",
  edges     = "topology above the degree sequence: clustering, triangles, community structure",
  targets   = "who was reached, so reciprocity, triadic closure and all path structure",
  labels    = "only the map from structure to vertex attributes; every structural measure is exactly invariant"
)

# The scopes each method can confine its shuffle to. A scope a method cannot
# honour is refused, never silently widened to the whole network.
.null_scopes <- list(
  times    = c("network", "sender", "session"),
  timeline = c("network", "sender", "session"),
  targets  = c("network", "sender", "session"),
  edges    = "network",
  labels   = "network",
  reversal = "network"
)

#' Build one surrogate network from a permuted spell table
#' @param dn The source network.
#' @param spells The modified spell table.
#' @param vertex_spells The surrogate's vertex activity: the source's, or the
#'   source's carried through the same transformation as the spells.
#' @param method The method label, recorded in the surrogate's metadata.
#' @param replicate Which replicate this is.
#' @return A `dynet` object.
#' @noRd
.rebuild_surrogate <- function(dn, spells, vertex_spells, method, replicate) {
  spells <- spells[order(spells$start, spells$end, spells$from, spells$to), ,
                   drop = FALSE]
  rownames(spells) <- NULL
  meta <- dn$meta
  meta$surrogate <- list(method = method, replicate = replicate)
  .as_netobject(spells, dn$nodes, dn$directed, dn$node_groups, meta,
                vertex_spells)
}

#' Key each spell by its pair, canonicalised when undirected
#' @param spells A spell table.
#' @param directed Whether the network is directed.
#' @return A character vector, one key per spell row.
#' @noRd
.pair_key <- function(spells, directed) {
  if (directed) return(paste(spells$from, spells$to, sep = "\r"))
  paste(pmin(spells$from, spells$to), pmax(spells$from, spells$to), sep = "\r")
}

#' The blocks of spell rows a shuffle is confined to
#' @param spells A spell table.
#' @param within `"network"`, `"sender"` or `"session"`.
#' @return A list of integer row-index vectors that partition the rows. A
#'   spell without a session forms its own block rather than being dropped.
#' @noRd
.null_scope <- function(spells, within) {
  n <- nrow(spells)
  key <- switch(within,
    network = rep("", n),
    sender = spells$from,
    session = ifelse(is.na(spells$session), "\r", as.character(spells$session))
  )
  unname(split(seq_len(n), key))
}

#' A permutation of row indices that never leaves its block
#' @param scope Blocks from `.null_scope()`.
#' @param n Number of rows.
#' @return An integer vector `o`: row `i` takes its value from row `o[i]`.
#' @noRd
.permute_within <- function(scope, n) {
  o <- seq_len(n)
  o[unlist(scope)] <- unlist(lapply(scope, function(idx) {
    idx[sample.int(length(idx))]
  }))
  o
}

#' Re-permute offending rows inside their blocks until none offends
#'
#' Each pass takes the offending rows of a block together with as many other
#' rows of the same block, chosen at random, and permutes the `columns` among
#' them. Every pass is a permutation within a block, so the multiset of
#' `columns` in every block is exactly what it was: the repair keeps the
#' invariant the method promises. The result is a feasible draw, not a
#' uniform draw from the feasible set.
#' @param spells A spell table.
#' @param offends A function of a spell table returning a logical vector,
#'   `TRUE` for a row that must move.
#' @param scope Blocks from `.null_scope()`.
#' @param columns The columns permuted together.
#' @param max_tries Cap on the passes.
#' @param done A function of a spell table, `TRUE` once the draw is
#'   acceptable. By default, once no row offends.
#' @return A list with the repaired `spells`, the number of offending rows
#'   met over all passes (`rejected`), how many still offend (`left`) and
#'   whether the draw is acceptable (`ok`).
#' @noRd
.repair_rows <- function(spells, offends, scope, columns, max_tries,
                         done = function(sp) !any(offends(sp))) {
  rejected <- 0L
  tries <- 0L
  bad <- which(offends(spells))
  ok <- done(spells)
  # Sequential by nature: each pass works on the rows the previous one left
  # offending, so the passes cannot be vectorised.
  while (!ok && tries < max_tries) {
    rejected <- rejected + length(bad)
    chosen <- lapply(scope, function(idx) {
      offending <- idx[idx %in% bad]
      if (!length(offending)) return(integer())
      others <- idx[!idx %in% bad]
      partners <- others[sample.int(length(others),
                                    min(length(offending), length(others)))]
      c(offending, partners)
    })
    rows <- unlist(chosen)
    donors <- unlist(lapply(chosen, function(r) r[sample.int(length(r))]))
    spells[rows, columns] <- spells[donors, columns, drop = FALSE]
    tries <- tries + 1L
    bad <- which(offends(spells))
    ok <- done(spells)
  }
  list(spells = spells, rejected = rejected, left = length(bad), ok = ok)
}

#' Is every surrogate spell feasible for both endpoints and the observation?
#' @param dn The source network.
#' @param spells A candidate spell table.
#' @param respect Which constraints to enforce.
#' @param vertex_spells The vertex activity the spells must respect.
#' @return A logical vector, one per spell row.
#' @noRd
.spell_feasible <- function(dn, spells, respect,
                            vertex_spells = dn$vertex_spells) {
  ok <- rep(TRUE, nrow(spells))
  if ("observation" %in% respect) {
    # Both ends of the spell must fall inside an observed component, or the
    # snapshot machinery would induce the event away and bias the null down.
    ok <- ok & .time_in_observation(dn, spells$start) &
      .time_in_observation(dn, spells$end)
  }
  if ("activity" %in% respect && !is.null(vertex_spells) &&
      nrow(vertex_spells) > 0L) {
    vs <- vertex_spells
    covers <- function(node, from, to) {
      vapply(seq_along(node), function(i) {
        rows <- vs[vs$node == node[[i]], , drop = FALSE]
        # dynet() records vertex_activity_default = "always_for_unlisted_nodes",
        # so a vertex with no declared spell is eligible throughout, not never.
        if (!nrow(rows)) return(TRUE)
        any(.time_leq(rows$start, from[[i]]) & .time_geq(rows$end, to[[i]]))
      }, logical(1L))
    }
    ok <- ok & covers(spells$from, spells$start, spells$end) &
      covers(spells$to, spells$start, spells$end)
  }
  ok
}

#' Double-edge swaps on the aggregate pair set, preserving every degree
#'
#' Maslov and Sneppen (2002). On an undirected network a pair is unordered,
#' so the second pair is read in a random orientation (both swap types are
#' reachable) and existence is tested on the canonical key; testing the
#' ordered key instead would let a swap create a pair that already exists in
#' the other orientation, merging two pairs and changing two degrees.
#' @param pairs Data frame of distinct pairs, `from` and `to`.
#' @param directed Whether the network is directed.
#' @param attempts Number of proposed swaps.
#' @return A list with the rewired `pairs` (canonical when undirected, in the
#'   input row order) and the number `accepted`.
#' @noRd
.swap_pairs <- function(pairs, directed, attempts) {
  m <- nrow(pairs)
  accepted <- 0L
  if (m < 2L) return(list(pairs = pairs, accepted = accepted))
  key <- function(a, b) {
    if (directed) paste(a, b, sep = "\r") else
      paste(pmin(a, b), pmax(a, b), sep = "\r")
  }
  existing <- new.env(parent = emptyenv())
  invisible(lapply(key(pairs$from, pairs$to), assign, value = TRUE,
                   envir = existing))
  # A Markov chain: each swap is proposed on the graph the previous swaps
  # left, so the proposals are sequential by nature and cannot be vectorised.
  for (i in seq_len(attempts)) {
    ij <- sample.int(m, 2L)
    a <- pairs$from[[ij[[1L]]]]
    b <- pairs$to[[ij[[1L]]]]
    cc <- pairs$from[[ij[[2L]]]]
    d <- pairs$to[[ij[[2L]]]]
    if (!directed && stats::runif(1L) < 0.5) {
      flip <- cc
      cc <- d
      d <- flip
    }
    if (a == d || cc == b) next
    k1 <- key(a, d)
    k2 <- key(cc, b)
    if (identical(k1, k2)) next
    if (exists(k1, envir = existing, inherits = FALSE)) next
    if (exists(k2, envir = existing, inherits = FALSE)) next
    rm(list = c(key(a, b), key(cc, d)), envir = existing)
    assign(k1, TRUE, envir = existing)
    assign(k2, TRUE, envir = existing)
    pairs$from[[ij[[1L]]]] <- a
    pairs$to[[ij[[1L]]]] <- d
    pairs$from[[ij[[2L]]]] <- cc
    pairs$to[[ij[[2L]]]] <- b
    accepted <- accepted + 1L
  }
  if (!directed) {
    lo <- pmin(pairs$from, pairs$to)
    pairs$to <- pmax(pairs$from, pairs$to)
    pairs$from <- lo
  }
  list(pairs = pairs, accepted = accepted)
}

#' Draw one surrogate spell table
#' @param dn The source network.
#' @param method Which null model.
#' @param within Scope a shuffle is confined to.
#' @param transpose Swap edge direction as well, for `"reversal"`.
#' @param swaps Double-edge swaps per distinct pair, for `"edges"`.
#' @param max_tries Iteration cap on the repair loops.
#' @return A list with the surrogate `spells`, its `vertex_spells` and the
#'   realised `acceptance`.
#' @noRd
.draw_surrogate <- function(dn, method, within, transpose, swaps, max_tries) {
  spells <- dn$spells
  vertex_spells <- dn$vertex_spells
  n <- nrow(spells)
  acceptance <- NA_real_
  scope <- .null_scope(spells, within)

  if (identical(method, "reversal")) {
    span <- dn$meta$time_range
    lo <- span[[1L]]
    hi <- span[[2L]]
    reflect <- function(tbl) {
      start <- lo + hi - tbl$end
      tbl$end <- lo + hi - tbl$start
      tbl$start <- start
      # A left-censored spell becomes right-censored under reflection;
      # forgetting this silently corrupts formation and dissolution.
      if (all(c("onset_censored", "terminus_censored") %in% names(tbl))) {
        onset <- tbl$onset_censored
        tbl$onset_censored <- tbl$terminus_censored
        tbl$terminus_censored <- onset
      }
      tbl
    }
    spells <- reflect(spells)
    # Vertex activity runs backwards with the ties, or the reversed network
    # would place every tie of a vertex outside its own presence.
    if (!is.null(vertex_spells) && nrow(vertex_spells) > 0L) {
      vertex_spells <- reflect(vertex_spells)
    }
    if (transpose && dn$directed) {
      from <- spells$from
      spells$from <- spells$to
      spells$to <- from
    }
  } else if (identical(method, "times")) {
    # start and end move as a pair; permuting them independently is the classic
    # error and manufactures negative durations.
    o <- .permute_within(scope, n)
    spells$start <- dn$spells$start[o]
    spells$end <- dn$spells$end[o]
  } else if (identical(method, "timeline")) {
    key <- .pair_key(spells, dn$directed)
    # Each pair's rows take the endpoints of the pair its timeline moved to.
    moves <- lapply(scope, function(idx) {
      groups <- split(idx, key[idx])
      target <- names(groups)[sample.int(length(groups))]
      list(rows = unlist(groups, use.names = FALSE),
           donors = rep(vapply(groups[target], `[[`, integer(1L), 1L),
                        lengths(groups)))
    })
    donor <- seq_len(n)
    donor[unlist(lapply(moves, `[[`, "rows"))] <-
      unlist(lapply(moves, `[[`, "donors"))
    spells$from <- dn$spells$from[donor]
    spells$to <- dn$spells$to[donor]
  } else if (identical(method, "edges")) {
    pairs <- unique(data.frame(from = spells$from, to = spells$to,
                               stringsAsFactors = FALSE))
    attempts <- max(1L, as.integer(swaps * nrow(pairs)))
    swapped <- .swap_pairs(pairs, dn$directed, attempts)
    acceptance <- swapped$accepted / attempts
    map <- match(paste(spells$from, spells$to, sep = "\r"),
                 paste(pairs$from, pairs$to, sep = "\r"))
    spells$from <- swapped$pairs$from[map]
    spells$to <- swapped$pairs$to[map]
  } else if (identical(method, "targets")) {
    o <- .permute_within(scope, n)
    spells$to <- dn$spells$to[o]
    # A permutation can put from == to, and the constructor drops self-loops,
    # so an unrepaired surrogate silently loses events. Repair inside the same
    # scope, so the targets of every block stay the block's own. A source that
    # carries self-loops keeps whatever the permutation gives.
    if (!any(dn$spells$from == dn$spells$to)) {
      repaired <- .repair_rows(spells, function(sp) sp$from == sp$to, scope,
                               "to", max_tries)
      if (!repaired$ok) {
        stop(errorCondition(sprintf(
          "Could not place %d surrogate events without a self-loop in %d tries.",
          repaired$left, max_tries),
          class = c("dynet_null_no_valid_draw", "dynet_bad_input"),
          call = NULL))
      }
      spells <- repaired$spells
    }
  } else if (identical(method, "labels")) {
    names_from <- dn$nodes$name
    map <- stats::setNames(sample(names_from), names_from)
    spells$from <- unname(map[spells$from])
    spells$to <- unname(map[spells$to])
    # A vertex's presence is part of the structure the surrogate keeps, so
    # it moves with the name.
    if (!is.null(vertex_spells) && nrow(vertex_spells) > 0L) {
      vertex_spells$node <- unname(map[vertex_spells$node])
    }
  }
  list(spells = spells, vertex_spells = vertex_spells, acceptance = acceptance)
}

#' Draw one surrogate that satisfies the declared constraints
#'
#' A surrogate may hold no more infeasible spells than the observed network
#' does: an observed spell outside its endpoints' activity is kept by
#' [dynet()] and induced away by the snapshot machinery, so demanding a fully
#' feasible surrogate of such a network would ask it to keep more events than
#' the observation did, and can be impossible while keeping what the method
#' holds fixed.
#'
#' `"times"` and `"targets"` move single rows, so infeasible rows are
#' re-permuted inside their block with `.repair_rows()`, which keeps the
#' method's invariant exactly. `"timeline"` and `"edges"` move whole pairs,
#' so an unacceptable draw is rejected and redrawn whole; rejection keeps the
#' invariant and, unlike a repair, is uniform over the acceptable draws.
#' `"labels"` and `"reversal"` carry vertex activity with them, so only the
#' observation constraint can bind, and only for `"reversal"`.
#' @param dn,method,within,transpose,swaps,max_tries As for `.draw_surrogate()`.
#' @param respect Constraints to enforce.
#' @return The draw, with `rejected`, the number of infeasible spells met.
#' @noRd
.constrained_surrogate <- function(dn, method, within, transpose, swaps,
                                   max_tries, respect) {
  got <- .draw_surrogate(dn, method, within, transpose, swaps, max_tries)
  if (identical(method, "labels")) {
    got$rejected <- 0L
    return(got)
  }
  if (identical(method, "reversal")) respect <- intersect(respect, "observation")
  allowed <- sum(!.spell_feasible(dn, dn$spells, respect))
  infeasible <- function(sp) !.spell_feasible(dn, sp, respect, got$vertex_spells)
  if (method %in% c("times", "targets")) {
    columns <- if (identical(method, "times")) c("start", "end") else "to"
    loops_banned <- identical(method, "targets") &&
      !any(dn$spells$from == dn$spells$to)
    loops <- function(sp) loops_banned & sp$from == sp$to
    repaired <- .repair_rows(
      got$spells, function(sp) infeasible(sp) | loops(sp),
      .null_scope(got$spells, within), columns, max_tries,
      done = function(sp) sum(infeasible(sp)) <= allowed && !any(loops(sp)))
    got$spells <- repaired$spells
    got$rejected <- repaired$rejected
    left <- if (repaired$ok) 0L else sum(infeasible(got$spells)) - allowed
  } else {
    rejected <- 0L
    tries <- 0L
    excess <- function(sp) max(0L, sum(infeasible(sp)) - allowed)
    left <- excess(got$spells)
    # Rejection sampling: each redraw replaces the whole surrogate, and the
    # loop stops at the first acceptable one, so it is sequential by nature.
    # Reversal is deterministic, so a redraw could never help.
    while (left && tries < max_tries && !identical(method, "reversal")) {
      rejected <- rejected + sum(infeasible(got$spells))
      got <- .draw_surrogate(dn, method, within, transpose, swaps, max_tries)
      left <- excess(got$spells)
      tries <- tries + 1L
    }
    got$rejected <- rejected
  }
  if (left > 0L) {
    stop(errorCondition(sprintf(paste0(
      "Could not place the surrogate spells inside the declared activity and ",
      "observation windows in %d tries: %d more lie outside them than the %d ",
      "of the observed network. `respect = \"none\"` draws without the ",
      "constraint, with the bias the documentation describes."),
      max_tries, left, allowed),
      class = c("dynet_null_no_valid_draw", "dynet_bad_input"), call = NULL))
  }
  got
}

#' Surrogate temporal networks from a null model
#'
#' @description
#' Produces networks that keep some of the observed structure and destroy the
#' rest, so that a measured value can be read against what an unstructured
#' network would have shown. Every measure in this package is a point estimate
#' until it is compared with a null; [significance()] does that comparison.
#'
#' Which structure each method holds fixed is the whole content of the choice,
#' so `print()` states it and the `@details` below tabulate it.
#'
#' @param dn A temporal network from [dynet()].
#' @param method The null model. `"times"` permutes event times across the
#'   network, `"timeline"` moves each pair's whole event sequence onto another
#'   pair, `"edges"` rewires the aggregate graph preserving degree,
#'   `"targets"` permutes who was reached, `"labels"` permutes vertex names,
#'   and `"reversal"` runs time backwards.
#' @param n Number of surrogates. Forced to one for `"reversal"`, which is
#'   deterministic.
#' @param within Scope a shuffle is confined to: the whole network, within each
#'   sender, or within each session. `"times"`, `"timeline"` and `"targets"`
#'   honour all three (`"timeline"` within a sender moves a pair's timeline
#'   only onto another pair of the same sender); `"edges"`, `"labels"` and
#'   `"reversal"` act on the whole network, and any other scope raises
#'   `dynet_null_bad_scope` rather than being silently widened.
#' @param transpose For `"reversal"` only, also swap edge direction.
#' @param swaps For `"edges"` only, double-edge swaps per distinct pair.
#' @param max_tries Iteration cap on the self-loop repair in `"targets"` and
#'   on the constraint repair or redraw under `respect`.
#' @param keep Retain the surrogate networks so [significance()] can reuse one
#'   set of replicates for many statistics, or drop them to save memory.
#' @param respect Constraints a surrogate must satisfy on a network that
#'   declares them: `"activity"` requires both endpoints eligible for the whole
#'   surrogate spell, `"observation"` requires the spell to lie inside an
#'   observed component, and `"none"` shuffles unconstrained. `"none"` on such
#'   a network gives a biased null. See Details for how each method meets the
#'   constraints without giving up what it holds fixed.
#' @param seed A single whole number for a reproducible draw, or `NULL`.
#' @return A `dynet_null` data frame with one row per surrogate spell per
#'   replicate and columns `replicate`, `from`, `to`, `start`, `end`,
#'   `duration` and `weight`, plus `session` when the network has sessions.
#'   The surrogate networks themselves are carried on the object and are
#'   reached through [significance()], never by hand.
#' @details
#' \describe{
#'   \item{`"reversal"`}{Preserves every spell duration, every pair, each
#'     pair's event count and all degrees. Destroys the arrow of time.}
#'   \item{`"times"`}{Preserves the multiset of start and end times, so the
#'     activity profile and duration distribution exactly. Destroys the
#'     coupling between topology and timing, and each pair's burstiness.}
#'   \item{`"timeline"`}{Preserves each pair's event sequence intact, so
#'     per-link burstiness and memory. Destroys which pair owns which
#'     timeline.}
#'   \item{`"edges"`}{Preserves the aggregate degree sequence, in and out
#'     separately when directed. Destroys topology above the degree sequence.}
#'   \item{`"targets"`}{Preserves each sender's event times. Destroys who was
#'     reached, so reciprocity and triadic closure.}
#'   \item{`"labels"`}{Preserves everything structural: the surrogate is
#'     isomorphic to the original. It is therefore a null for
#'     attribute-dependent quantities only, such as [mixing()]. Every
#'     structural measure is exactly invariant under it, which makes it a free
#'     correctness test rather than a weak null.}
#' }
#' On a network that declares vertex activity or observation spells, an
#' unconstrained shuffle can place an event while an endpoint is ineligible or
#' inside an unobserved gap, and the snapshot machinery would then induce it
#' away, biasing the null downward. `respect` enforces those constraints
#' without breaking what the method holds fixed: a surrogate may hold no more
#' infeasible spells than the observed network itself does (an observed spell
#' outside its endpoints' activity is kept and induced away the same way). `"times"` and `"targets"`
#' re-permute an infeasible spell together with randomly chosen spells of the
#' same scope, so the multiset of times (or of each scope's targets) is
#' exactly kept; the result is a feasible surrogate rather than a uniform draw
#' from the feasible set. `"timeline"` and `"edges"` move whole pairs, so an
#' infeasible surrogate is rejected and redrawn whole, which is uniform over
#' the feasible ones. `"labels"` and `"reversal"` carry vertex activity with
#' them (a permuted name keeps its presence; a reversed network has reversed
#' presence), so activity never binds them. When `max_tries` is exhausted,
#' `dynet_null_no_valid_draw` is raised. `summary()`
#' reports how many proposals were rejected so the constraint's bite is
#' visible.
#' @section Conditions:
#' Errors: `dynet_bad_input` for a malformed argument or a `transpose` or
#' `n > 1` that the method cannot use; `dynet_null_bad_scope` for a `within`
#' the method does not define; `dynet_no_sessions` for `within = "session"`
#' on a network without sessions; `dynet_null_no_valid_draw` when no
#' surrogate satisfying the constraints is found in `max_tries`. Every one
#' also carries `dynet_bad_input`. Warning: `dynet_null_poor_mixing` when
#' fewer than half the proposed rewirings of `"edges"` were accepted.
#' @examples
#' dn <- dynet(school_contacts)
#' randomise(dn, method = "times", n = 9, seed = 1)
#' randomise(dn, method = "reversal")
#' @seealso [significance()] to turn a null into an interval and a p-value.
#' @references
#' Gauvin, L., Genois, M., Karsai, M., Kivela, M., Takaguchi, T., Valdano, E.,
#' and Vestergaard, C. L. (2022). Randomized reference models for temporal
#' networks. *SIAM Review*, 64(4), 763-830.
#'
#' Holme, P., and Saramaki, J. (2012). Temporal networks. *Physics Reports*,
#' 519(3), 97-125.
#'
#' Maslov, S., and Sneppen, K. (2002). Specificity and stability in topology of
#' protein networks. *Science*, 296(5569), 910-913.
#' @export
randomise <- function(dn,
                      method = c("times", "timeline", "edges", "targets",
                                 "labels", "reversal"),
                      n = 99L,
                      within = c("network", "sender", "session"),
                      transpose = FALSE,
                      swaps = 10,
                      max_tries = 100L,
                      keep = c("networks", "spells"),
                      respect = c("activity", "observation"),
                      seed = NULL) {
  .check_dynet(dn)
  n_supplied <- !missing(n)
  method <- .match_choice(method)
  within <- .match_choice(within)
  keep <- .match_choice(keep)
  respect <- .match_choice(respect, c("activity", "observation", "none"),
                       several.ok = TRUE)
  if ("none" %in% respect) {
    if (length(respect) > 1L) {
      stop(errorCondition(
        "`respect = \"none\"` cannot be combined with a constraint.",
        class = "dynet_bad_input", call = NULL))
    }
    respect <- character(0)
  }
  .check(
    "`n` must be a single positive whole number." =
      length(n) == 1L && is.numeric(n) && is.finite(n) && n >= 1 &&
        n == trunc(n),
    "`transpose` must be TRUE or FALSE." =
      length(transpose) == 1L && is.logical(transpose) && !is.na(transpose),
    "`swaps` must be a single positive number." =
      length(swaps) == 1L && is.numeric(swaps) && is.finite(swaps) &&
        swaps > 0,
    "`max_tries` must be a single positive whole number." =
      length(max_tries) == 1L && is.numeric(max_tries) &&
        is.finite(max_tries) && max_tries >= 1
  )
  if (transpose && !identical(method, "reversal")) {
    stop(errorCondition(
      "`transpose` applies only to method = \"reversal\".",
      class = "dynet_bad_input", call = NULL))
  }
  if (identical(method, "reversal")) {
    # Deterministic, so one surrogate is the whole null. Silently use one when
    # the caller left the default alone; object only if they asked for more,
    # which would return identical copies.
    if (n_supplied && n > 1L) {
      stop(errorCondition(
        "Time reversal is deterministic, so `n` must be 1; more would return identical copies.",
        class = "dynet_bad_input", call = NULL))
    }
    n <- 1L
  }
  if (!within %in% .null_scopes[[method]]) {
    stop(errorCondition(sprintf(
      "`within = \"%s\"` is not defined for method = \"%s\", which shuffles the whole network only.",
      within, method),
      class = c("dynet_null_bad_scope", "dynet_bad_input"), call = NULL))
  }
  if (identical(within, "session") && is.null(dn$meta$sessions)) {
    stop(errorCondition(
      "`within = \"session\"` needs a network built with sessions.",
      class = c("dynet_no_sessions", "dynet_bad_input"), call = NULL))
  }
  constrained <- length(respect) > 0L &&
    (isTRUE(dn$meta$vertex_activity_supplied) ||
       (!is.null(dn$vertex_spells) && nrow(dn$vertex_spells) > 0L) ||
       isTRUE(dn$meta$observation_spells_explicit))
  n <- as.integer(n)

  draws <- .with_seed(seed, lapply(seq_len(n), function(i) {
    if (!constrained) {
      got <- .draw_surrogate(dn, method, within, transpose, swaps, max_tries)
      got$rejected <- 0L
      return(got)
    }
    .constrained_surrogate(dn, method, within, transpose, swaps, max_tries,
                           respect)
  }))
  rejected <- vapply(draws, function(d) as.integer(d$rejected), integer(1L))
  networks <- lapply(seq_len(n), function(i) {
    .rebuild_surrogate(dn, draws[[i]]$spells, draws[[i]]$vertex_spells,
                       method, i)
  })

  frames <- lapply(seq_len(n), function(i) {
    sp <- networks[[i]]$spells
    out <- data.frame(
      replicate = i, from = sp$from, to = sp$to, start = sp$start,
      end = sp$end, duration = sp$end - sp$start, weight = sp$weight,
      stringsAsFactors = FALSE
    )
    if (!is.null(sp$session) && !all(is.na(sp$session))) out$session <- sp$session
    out
  })
  out <- do.call(rbind, frames)
  rownames(out) <- NULL

  acceptance <- mean(vapply(draws, `[[`, numeric(1L), "acceptance"))
  # A rewiring that rarely accepts has barely moved, so the surrogate is close
  # to the original and the null is too narrow. Say so rather than let a
  # deceptively small p-value out.
  if (!is.na(acceptance) && acceptance < 0.5) {
    warning(warningCondition(sprintf(
      paste0("Only %.0f%% of proposed rewirings were accepted, so the ",
             "surrogates stay close to the observed network and the null ",
             "will be too narrow. Raise `swaps` or read the p-value as a ",
             "lower bound on the true one."), 100 * acceptance),
      class = "dynet_null_poor_mixing"))
  }

  structure(out,
    class = c("dynet_null", "data.frame"),
    method = method, n = n, within = within, transpose = transpose,
    seed = seed,
    preserves = unname(.null_preserves[[method]]),
    destroys = unname(.null_destroys[[method]]),
    acceptance = acceptance, respect = respect, rejected = rejected,
    networks = if (identical(keep, "networks")) networks else NULL,
    source = dn
  )
}

#' Print surrogate networks
#' @param x A `dynet_null` from [randomise()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet_null <- function(x, ...) {
  cat(sprintf("# %d surrogate network%s | method \"%s\"\n",
              attr(x, "n"), if (attr(x, "n") == 1L) "" else "s",
              attr(x, "method")))
  cat(sprintf("# holds fixed : %s\n", attr(x, "preserves")))
  cat(sprintf("# destroys    : %s\n", attr(x, "destroys")))
  acc <- attr(x, "acceptance")
  if (!is.na(acc)) {
    cat(sprintf("# rewiring acceptance: %.2f\n", acc))
  }
  df <- as.data.frame(x)
  print(utils::head(df, 6L))
  if (nrow(df) > 6L) {
    cat(sprintf("# %d more rows. significance() turns this into a p-value.\n",
                nrow(df) - 6L))
  }
  invisible(x)
}

#' Summarise surrogate networks
#' @param object A `dynet_null` from [randomise()].
#' @param ... Ignored.
#' @return A data frame with one row per replicate and columns `replicate`,
#'   `n_events`, `n_pairs`, `t_min`, `t_max`, `mean_duration` and `rejected`
#'   (the infeasible spells met while drawing that replicate under
#'   `respect`, zero when no constraint binds), so the conservation each
#'   method claims and the bite of the constraints are visible.
#' @export
summary.dynet_null <- function(object, ...) {
  df <- as.data.frame(object)
  parts <- split(df, df$replicate)
  out <- do.call(rbind, lapply(parts, function(p) data.frame(
    replicate = p$replicate[[1L]], n_events = nrow(p),
    n_pairs = length(unique(paste(p$from, p$to, sep = "\r"))),
    t_min = min(p$start), t_max = max(p$end),
    mean_duration = mean(p$duration), stringsAsFactors = FALSE
  )))
  rownames(out) <- NULL
  rejected <- attr(object, "rejected") %||% integer(attr(object, "n"))
  out$rejected <- as.integer(rejected[out$replicate])
  out
}

#' Coerce surrogate networks to a data frame
#' @param x A `dynet_null` from [randomise()].
#' @param row.names Passed to the data frame method.
#' @param optional Passed to the data frame method.
#' @param ... Ignored.
#' @return A base data frame, one row per surrogate spell per replicate.
#' @export
as.data.frame.dynet_null <- function(x, row.names = NULL, optional = FALSE,
                                     ...) {
  attributes(x) <- list(names = names(x), row.names = seq_len(nrow(x)),
                        class = "data.frame")
  x
}

#' Plot the surrogate activity profile against the observed one
#' @param x A `dynet_null` from [randomise()].
#' @param ... Ignored.
#' @return A `ggplot` object showing events per time bin for each surrogate
#'   with the observed profile overplotted.
#' @export
plot.dynet_null <- function(x, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop(errorCondition("Plotting needs ggplot2.",
                        class = c("dynet_missing_package", "dynet_bad_input"),
                        call = NULL))
  }
  df <- as.data.frame(x)
  dn <- attr(x, "source")
  breaks <- pretty(range(c(df$start, dn$spells$start)), 24)
  tally <- function(v, label, rep) {
    counts <- tabulate(findInterval(v, breaks, rightmost.closed = TRUE),
                       nbins = length(breaks))
    data.frame(time = breaks, events = counts, series = label,
               replicate = rep, stringsAsFactors = FALSE)
  }
  parts <- split(df$start, df$replicate)
  sur <- do.call(rbind, lapply(names(parts), function(r) {
    tally(parts[[r]], "surrogate", r)
  }))
  obs <- tally(dn$spells$start, "observed", "observed")
  ggplot2::ggplot() +
    ggplot2::geom_line(
      data = sur,
      ggplot2::aes(x = time, y = events, group = replicate),
      colour = "#999999", linewidth = 0.3, alpha = 0.5, linetype = "solid") +
    ggplot2::geom_line(
      data = obs, ggplot2::aes(x = time, y = events),
      colour = "#0072B2", linewidth = 0.9, linetype = "22") +
    ggplot2::annotate("text", x = max(obs$time), y = max(obs$events),
                      label = "observed", hjust = 1, vjust = -0.4,
                      colour = "#0072B2", size = 3.5) +
    ggplot2::labs(x = "time", y = "events per bin",
                  title = sprintf("Observed against %d surrogates (%s)",
                                  attr(x, "n"), attr(x, "method"))) +
    ggplot2::theme_minimal(base_size = 12)
}
