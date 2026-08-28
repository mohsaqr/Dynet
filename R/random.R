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
#' @keywords internal
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

#' Build one surrogate network from a permuted spell table
#' @param dn The source network.
#' @param spells The modified spell table.
#' @param method The method label, recorded in the surrogate's metadata.
#' @param replicate Which replicate this is.
#' @return A `dynet` object.
#' @keywords internal
.rebuild_surrogate <- function(dn, spells, method, replicate) {
  spells <- spells[order(spells$start, spells$end, spells$from, spells$to), ,
                   drop = FALSE]
  rownames(spells) <- NULL
  meta <- dn$meta
  meta$surrogate <- list(method = method, replicate = replicate)
  .as_netobject(spells, dn$nodes, dn$directed, dn$node_groups, meta,
                dn$vertex_spells)
}

#' Key each spell by its pair, canonicalised when undirected
#' @param spells A spell table.
#' @param directed Whether the network is directed.
#' @return A character vector, one key per spell row.
#' @keywords internal
.pair_key <- function(spells, directed) {
  if (directed) return(paste(spells$from, spells$to, sep = "\r"))
  paste(pmin(spells$from, spells$to), pmax(spells$from, spells$to), sep = "\r")
}

#' Is every surrogate spell feasible for both endpoints and the observation?
#' @param dn The source network.
#' @param spells A candidate spell table.
#' @param respect Which constraints to enforce.
#' @return A logical vector, one per spell row.
#' @keywords internal
.spell_feasible <- function(dn, spells, respect) {
  ok <- rep(TRUE, nrow(spells))
  if ("observation" %in% respect) {
    # Both ends of the spell must fall inside an observed component, or the
    # snapshot machinery would induce the event away and bias the null down.
    ok <- ok & .time_in_observation(dn, spells$start) &
      .time_in_observation(dn, spells$end)
  }
  if ("activity" %in% respect && !is.null(dn$vertex_spells) &&
      nrow(dn$vertex_spells) > 0L) {
    vs <- dn$vertex_spells
    covers <- function(node, from, to) {
      vapply(seq_along(node), function(i) {
        rows <- vs[vs$node == node[[i]], , drop = FALSE]
        # dynet() records vertex_activity_default = "always_for_unlisted_nodes",
        # so a vertex with no declared spell is eligible throughout, not never.
        if (!nrow(rows)) return(TRUE)
        any(rows$start <= from[[i]] & rows$end >= to[[i]])
      }, logical(1L))
    }
    ok <- ok & covers(spells$from, spells$start, spells$end) &
      covers(spells$to, spells$start, spells$end)
  }
  ok
}

#' Draw one surrogate spell table
#' @param dn The source network.
#' @param method Which null model.
#' @param within Scope a shuffle is confined to.
#' @param transpose Swap edge direction as well, for `"reversal"`.
#' @param swaps Double-edge swaps per distinct pair, for `"edges"`.
#' @param max_tries Iteration cap on the repair loops.
#' @return A list with the surrogate `spells` and the realised `acceptance`.
#' @keywords internal
.draw_surrogate <- function(dn, method, within, transpose, swaps, max_tries) {
  spells <- dn$spells
  n <- nrow(spells)
  acceptance <- NA_real_
  blocks <- if (identical(within, "session") && !is.null(spells$session)) {
    split(seq_len(n), spells$session)
  } else list(seq_len(n))

  if (identical(method, "reversal")) {
    span <- dn$meta$time_range
    lo <- span[[1L]]
    hi <- span[[2L]]
    start <- lo + hi - spells$end
    end <- lo + hi - spells$start
    spells$start <- start
    spells$end <- end
    # A left-censored spell becomes right-censored under reflection; forgetting
    # this silently corrupts formation and dissolution on the surrogate.
    onset <- spells$onset_censored
    spells$onset_censored <- spells$terminus_censored
    spells$terminus_censored <- onset
    if (transpose && dn$directed) {
      from <- spells$from
      spells$from <- spells$to
      spells$to <- from
    }
  } else if (identical(method, "times")) {
    # start and end move as a pair; permuting them independently is the classic
    # error and manufactures negative durations.
    for (idx in blocks) {
      o <- idx[sample.int(length(idx))]
      spells$start[idx] <- dn$spells$start[o]
      spells$end[idx] <- dn$spells$end[o]
    }
  } else if (identical(method, "timeline")) {
    key <- .pair_key(spells, dn$directed)
    groups <- split(seq_len(n), key)
    labels <- names(groups)
    target <- labels[sample.int(length(labels))]
    for (i in seq_along(groups)) {
      rows <- groups[[i]]
      donor <- groups[[target[[i]]]][[1L]]
      spells$from[rows] <- dn$spells$from[[donor]]
      spells$to[rows] <- dn$spells$to[[donor]]
    }
  } else if (identical(method, "edges")) {
    pairs <- unique(data.frame(from = spells$from, to = spells$to,
                               stringsAsFactors = FALSE))
    m <- nrow(pairs)
    accepted <- 0L
    attempts <- max(1L, as.integer(swaps * m))
    if (m >= 2L) {
      existing <- new.env(parent = emptyenv())
      for (i in seq_len(m)) assign(paste(pairs$from[[i]], pairs$to[[i]],
                                         sep = "\r"), TRUE, envir = existing)
      for (i in seq_len(attempts)) {
        ij <- sample.int(m, 2L)
        a <- pairs$from[[ij[[1L]]]]; b <- pairs$to[[ij[[1L]]]]
        cc <- pairs$from[[ij[[2L]]]]; d <- pairs$to[[ij[[2L]]]]
        if (a == d || cc == b) next
        k1 <- paste(a, d, sep = "\r"); k2 <- paste(cc, b, sep = "\r")
        if (exists(k1, envir = existing, inherits = FALSE)) next
        if (exists(k2, envir = existing, inherits = FALSE)) next
        rm(list = c(paste(a, b, sep = "\r"), paste(cc, d, sep = "\r")),
           envir = existing)
        assign(k1, TRUE, envir = existing); assign(k2, TRUE, envir = existing)
        pairs$to[[ij[[1L]]]] <- d; pairs$to[[ij[[2L]]]] <- b
        accepted <- accepted + 1L
      }
    }
    acceptance <- accepted / attempts
    old <- unique(data.frame(from = dn$spells$from, to = dn$spells$to,
                             stringsAsFactors = FALSE))
    map <- match(paste(spells$from, spells$to, sep = "\r"),
                 paste(old$from, old$to, sep = "\r"))
    spells$from <- pairs$from[map]
    spells$to <- pairs$to[map]
  } else if (identical(method, "targets")) {
    scope <- if (identical(within, "sender")) {
      split(seq_len(n), spells$from)
    } else blocks
    for (idx in scope) {
      o <- idx[sample.int(length(idx))]
      spells$to[idx] <- dn$spells$to[o]
    }
    # A permutation can put from == to, and the constructor drops self-loops,
    # so an unrepaired surrogate silently loses events. Repair, do not let the
    # constructor eat them.
    tries <- 0L
    repeat {
      bad <- which(spells$from == spells$to)
      if (!length(bad) || tries >= max_tries) break
      donor <- sample.int(n, length(bad))
      swap <- spells$to[bad]
      spells$to[bad] <- spells$to[donor]
      spells$to[donor] <- swap
      tries <- tries + 1L
    }
    if (any(spells$from == spells$to)) {
      stop(errorCondition(sprintf(
        "Could not place %d surrogate events without a self-loop in %d tries.",
        sum(spells$from == spells$to), max_tries),
        class = "dynet_null_no_valid_draw", call = NULL))
    }
  } else if (identical(method, "labels")) {
    names_from <- dn$nodes$name
    perm <- sample(names_from)
    map <- stats::setNames(perm, names_from)
    spells$from <- unname(map[spells$from])
    spells$to <- unname(map[spells$to])
  }
  list(spells = spells, acceptance = acceptance)
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
#'   sender, or within each session.
#' @param transpose For `"reversal"` only, also swap edge direction.
#' @param swaps For `"edges"` only, double-edge swaps per distinct pair.
#' @param max_tries Iteration cap on the self-loop repair in `"targets"`.
#' @param keep Retain the surrogate networks so [significance()] can reuse one
#'   set of replicates for many statistics, or drop them to save memory.
#' @param respect Constraints a surrogate must satisfy on a network that
#'   declares them: `"activity"` requires both endpoints eligible for the whole
#'   surrogate spell, `"observation"` requires the spell to lie inside an
#'   observed component, and `"none"` shuffles unconstrained. Constrained draws
#'   are feasible, not uniform over the feasible set, and `"none"` on such a
#'   network gives a biased null.
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
#' away, biasing the null downward. `respect` enforces those constraints by
#' rejecting and redrawing infeasible spells. The result is a feasible
#' surrogate rather than a uniform draw from the feasible set; `summary()`
#' reports how many proposals were rejected so the constraint's bite is
#' visible.
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
  method <- match.arg(method)
  within <- match.arg(within)
  keep <- match.arg(keep)
  respect <- match.arg(respect, c("activity", "observation", "none"),
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
  if (identical(within, "session") && is.null(dn$meta$sessions)) {
    stop(errorCondition(
      "`within = \"session\"` needs a network built with sessions.",
      class = "dynet_no_sessions", call = NULL))
  }
  constrained <- length(respect) > 0L &&
    (isTRUE(dn$meta$vertex_activity_supplied) ||
       (!is.null(dn$vertex_spells) && nrow(dn$vertex_spells) > 0L) ||
       isTRUE(dn$meta$observation_spells_explicit))
  n <- as.integer(n)
  rejected <- integer(n)

  draws <- .with_seed(seed, lapply(seq_len(n), function(i) {
    got <- .draw_surrogate(dn, method, within, transpose, swaps, max_tries)
    if (!constrained) return(got)
    # Rejection then repair: propose, keep the feasible rows, redraw the rest.
    # This yields a feasible surrogate, NOT a uniform draw from the feasible
    # set, and the docs say so rather than overclaiming.
    tries <- 0L
    repeat {
      feasible <- .spell_feasible(dn, got$spells, respect)
      if (all(feasible) || tries >= max_tries) break
      rejected[[i]] <<- rejected[[i]] + sum(!feasible)
      retry <- .draw_surrogate(dn, method, within, transpose, swaps, max_tries)
      got$spells[!feasible, ] <- retry$spells[!feasible, ]
      tries <- tries + 1L
    }
    if (!all(.spell_feasible(dn, got$spells, respect))) {
      stop(errorCondition(sprintf(
        "Could not place %d surrogate spells inside the declared activity and observation windows in %d tries.",
        sum(!.spell_feasible(dn, got$spells, respect)), max_tries),
        class = "dynet_null_no_valid_draw", call = NULL))
    }
    got
  }))
  networks <- lapply(seq_len(n), function(i) {
    .rebuild_surrogate(dn, draws[[i]]$spells, method, i)
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
#'   `n_events`, `n_pairs`, `t_min`, `t_max` and `mean_duration`, so the
#'   conservation each method claims is visible.
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
                        class = "dynet_missing_package", call = NULL))
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
  both <- rbind(sur, obs)
  ggplot2::ggplot(
    both, ggplot2::aes(x = .data_time(both), y = both$events)) +
    ggplot2::geom_line(
      data = sur,
      ggplot2::aes(x = sur$time, y = sur$events, group = sur$replicate),
      colour = "#999999", linewidth = 0.3, alpha = 0.5, linetype = "solid") +
    ggplot2::geom_line(
      data = obs, ggplot2::aes(x = obs$time, y = obs$events),
      colour = "#0072B2", linewidth = 0.9, linetype = "22") +
    ggplot2::annotate("text", x = max(obs$time), y = max(obs$events),
                      label = "observed", hjust = 1, vjust = -0.4,
                      colour = "#0072B2", size = 3.5) +
    ggplot2::labs(x = "time", y = "events per bin",
                  title = sprintf("Observed against %d surrogates (%s)",
                                  attr(x, "n"), attr(x, "method"))) +
    ggplot2::theme_minimal(base_size = 12)
}

#' Identity helper so the plot method reads a column without NSE
#' @param d A data frame.
#' @return The `time` column.
#' @keywords internal
.data_time <- function(d) d$time
