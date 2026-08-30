# ===========================================================================
# mixing() — who interacts with whom, over time
# ===========================================================================

#' Mixing between vertex groups over time
#'
#' @description
#' How much each kind of vertex interacted with each other kind, in every time
#' bin. This is the question a temporal network answers that a static one
#' cannot: not whether high and low achievers mixed, but *when* they did, and
#' whether the pattern held or decayed.
#'
#' The grouping variable comes from the vertex attributes supplied to
#' [dynet()] through its `nodes` argument.
#'
#' @details
#' Each cell is a raw count of distinct active binary vertex dyads. Repeated,
#' overlapping, or split spells and edge weights do not multiply a dyad.
#' Retained self-loops count once. For directed networks, every ordered group
#' pair is reported and
#' \deqn{M_{ab}=\sum_{u:g(u)=a}\sum_{v:g(v)=b}Y_{uv}.}
#' The row and column margins are grouped outdegree and indegree, and the table
#' sum is the active directed edge count including retained loops.
#'
#' Undirected networks report one lexicographically canonical cell for each
#' unordered group pair, with display labels such as `"A -- B"`. A within-group
#' edge or loop contributes once to its diagonal cell. The group stub margin is
#' \deqn{d_a=2M_{aa}+\sum_{b\ne a}M_{\min(a,b),\max(a,b)},}
#' so the margins sum to twice the table total. These are unnormalized counts,
#' not Newman's mixing proportions.
#'
#' Missing attribute values are retained as a collision-safe explicit group
#' ordered after observed labels. Bounded and collapsed modes both use the
#' binary calendar union: a dyad active in two sessions at the same time counts
#' once. Separate mode returns session-local tables over the fixed group
#' universe. Every supported cell is emitted, including zeros.
#' Declared vertex activity first induces the endpoint-valid snapshot. The
#' complete group-cell universe remains fixed, but inactive vertices and
#' eligible isolates contribute no dyad.
#'
#' @param dn A temporal network from [dynet()] built with vertex attributes.
#' @param attribute Name of a column in the vertex table.
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
#'   `"all"` measures the whole observed period as one window, closed on the
#'   right so an event at the final instant is inside it; it cannot be combined
#'   with `step`, and under `sessions = "separate"` or discontinuous
#'   observation it gives one window per session or observed component.
#'
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn, so `plot = TRUE` saves the
#'   wrapping `plot()` call without changing what comes back. Use `plot()` on
#'   the result when the figure needs arguments of its own.
#' @return A `dynet_metric` at graph level with one row per time point and
#'   group pair. Directed `measure` labels use `"A -> B"`; undirected labels
#'   use `"A -- B"`. `value` is the active binary-dyad count, and the
#'   authoritative `from_group` and `to_group` columns identify the cell.
#'   Attributes record unit, pair-domain, normalization, weight, loop,
#'   missing-group, and session-aggregation conventions.
#'
#' @references
#' Newman, M. E. J. (2003). Mixing patterns in networks. *Physical Review E*,
#' 67, 026126. \doi{10.1103/PhysRevE.67.026126}
#'
#' Morris, M., Handcock, M. S., & Hunter, D. R. (2008). Specification of
#' exponential-family random graph models: terms and computational aspects.
#' *Journal of Statistical Software*, 24(4). \doi{10.18637/jss.v024.i04}
#'
#' @examples
#' dn <- dynet(forum_posts, thread = "thread", nodes = forum_people)
#' mixing(dn, attribute = "role")
#' plot(mixing(dn, attribute = "role"))
#'
#' @export
mixing <- function(dn, attribute,
                       sessions = c("bounded", "collapse", "separate"),
                       sample = NULL,
                       start = NULL, end = NULL,
                       step = NULL, window = NULL, plot = FALSE) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  window <- .legacy_sample(window, sample)
  spec <- .window_spec(dn, start, end, step, window)
  .check("`attribute` must be a single column name." =
              is.character(attribute) && length(attribute) == 1L)

  if (!attribute %in% names(dn$nodes)) {
    have <- setdiff(names(dn$nodes), "name")
    stop(errorCondition(
      sprintf("No vertex attribute %s. This network has %s. Supply attributes through dynet(nodes = ).",
              sQuote(attribute),
              if (length(have)) paste(have, collapse = ", ") else "no attributes"),
      class = "dynet_unknown_attribute", call = NULL))
  }

  raw_group <- as.character(dn$nodes[[attribute]])
  observed <- sort(unique(raw_group[!is.na(raw_group)]))
  candidates <- c(
    "(missing)", "(missing NA)",
    sprintf("(missing NA %d)", seq_len(length(observed) + 1L) + 1L)
  )
  missing_label <- candidates[which(!candidates %in% observed)[1L]]
  grp <- raw_group
  grp[is.na(grp)] <- missing_label
  levs <- c(observed, if (anyNA(raw_group)) missing_label)
  grp_id <- match(grp, levs)
  pair_ids <- expand.grid(from = seq_along(levs), to = seq_along(levs))
  if (!dn$directed) {
    pair_ids <- pair_ids[pair_ids$from <= pair_ids$to, , drop = FALSE]
  }
  pairs <- data.frame(
    from_group = levs[pair_ids$from], to_group = levs[pair_ids$to],
    stringsAsFactors = FALSE
  )

  # Counting is done on the same binary adjacency the other verbs use, so a
  # pair connected by two spells in one bin is one edge here as well.
  df <- .over_bins(dn, sessions, node_level = FALSE, spec = spec,
    snapshot = TRUE, fun = function(enc, act, bin, state) {
      a <- .adjacency(enc, act, dn$directed)
      stats::setNames(
        .mixing_counts(a, grp_id, pair_ids, dn$directed),
        seq_len(nrow(pair_ids))
      )
    })

  pair_index <- as.integer(df$measure)
  df$from_group <- pairs$from_group[pair_index]
  df$to_group <- pairs$to_group[pair_index]
  separator <- if (dn$directed) " -> " else " -- "
  display_group <- function(group) {
    needs_quote <- grepl(separator, group, fixed = TRUE) |
      grepl('"', group, fixed = TRUE) | grepl("\\", group, fixed = TRUE)
    group[needs_quote] <- encodeString(group[needs_quote], quote = '"')
    group
  }
  df$measure <- paste(
    display_group(df$from_group), display_group(df$to_group), sep = separator
  )

  out <- .metric(
    df, level = "graph", what = sprintf("Mixing by %s", attribute),
    dn = dn, spec = spec,
    note = "active binary-dyad counts between vertex groups per time bin"
  )
  attr(out, "unit") <- "active_binary_dyads"
  attr(out, "pair_domain") <- if (dn$directed) {
    "directed_ordered"
  } else {
    "undirected_unordered"
  }
  attr(out, "normalization") <- "none"
  attr(out, "weights") <- "ignored"
  attr(out, "loops") <- "retained_once"
  attr(out, "missing_group") <- "explicit_level"
  attr(out, "session_aggregation") <- if (identical(sessions, "separate")) {
    "session_local"
  } else {
    "binary_calendar_union"
  }
  attr(out, "vertex_population") <- "eligible_window_any_induced"
  attr(out, "vertex_window_rule") <- if (spec$window == 0) {
    "instant_exact"
  } else "any"
  attr(out, "edge_endpoint_rule") <- "induced_after_elementwise_union"
  attr(out, "vertex_observation") <- "component_intersection_non_destructive"
  attr(out, "session_vertex_aggregation") <- switch(
    sessions, collapse = "calendar_union", bounded = "session_induced_union",
    separate = "session_local"
  )
  .maybe_plot(out, plot)
}

#' Count active binary dyads by group pair
#'
#' Unlike path kernels, this reducer preserves a present diagonal as one
#' explicitly retained loop. An undirected within-group block contains each
#' ordinary edge twice and each loop once, so only its off-diagonal sum is
#' halved.
#'
#' @param a Numeric vertex adjacency matrix for one bin.
#' @param group Integer group index for each matrix vertex.
#' @param pairs Data frame of integer `from` and `to` group indices.
#' @param directed Whether group pairs are ordered.
#' @return Numeric vector of active binary-dyad counts, one per `pairs` row.
#' @examples
#' a <- matrix(c(1, 0, 2, 0), 2, 2)
#' Dynet:::.mixing_counts(a, c(1L, 2L), expand.grid(from = 1:2, to = 1:2), TRUE)
#' @noRd
.mixing_counts <- function(a, group, pairs, directed) {
  present <- (a > 0) * 1
  if (!directed) present <- pmax(present, t(present))
  vapply(seq_len(nrow(pairs)), function(index) {
    from <- group == pairs$from[index]
    to <- group == pairs$to[index]
    block <- present[from, to, drop = FALSE]
    if (directed || pairs$from[index] != pairs$to[index]) return(sum(block))
    loops <- sum(diag(block))
    (sum(block) - loops) / 2 + loops
  }, numeric(1L))
}

# ===========================================================================
# snapshots() — the network as a sequence of tidy edge tables
# ===========================================================================

#' The network sliced into snapshots
#'
#' @description
#' The edges alive in each time bin, as one tidy table. Useful for exporting a
#' slice, for feeding a layout routine, or for checking by eye what the metric
#' verbs are seeing.
#'
#' @param dn A temporal network from [dynet()].
#' @param at Optional numeric time, narrowing the result to the bins that
#'   cover it. With the default disjoint tiling that is one bin; with an
#'   overlapping `window` every bin containing the time is returned. A time
#'   outside every bin falls back to the nearest bin rather than an empty
#'   result, so `at` never returns zero rows on a nonempty network.
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
#'   `"all"` measures the whole observed period as one window, closed on the
#'   right so an event at the final instant is inside it; it cannot be combined
#'   with `step`, and under `sessions = "separate"` or discontinuous
#'   observation it gives one window per session or observed component.
#'
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn, so `plot = TRUE` saves the
#'   wrapping `plot()` call without changing what comes back. Use `plot()` on
#'   the result when the figure needs arguments of its own.
#' @return A `dynet_snapshot` data frame with one row per active edge per bin:
#'   `session` (when the network has sessions), `observation` (when
#'   observation is discontinuous, naming the observed component the bin falls
#'   in), `time`, `from`, `to`, `weight` and `n_spells`.
#'   [print()] shows a header and the first rows, [summary()] collapses to one
#'   row per bin, [plot()] draws how many ties each bin holds, and
#'   [as.data.frame()] returns the plain table. A pair
#'   joined by more than one spell in the same bin is one edge, with
#'   `n_spells` recording how many spells were collapsed -- so the edge counts
#'   here agree with those from [metrics()]. Eligible isolates have no
#'   synthetic edge row; use [dyn_centrality()] or [metrics()] when the
#'   eligible population itself is required.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' snapshots(dn, at = 3)
#'
#' @export
snapshots <- function(dn, at = NULL,
                          sessions = c("bounded", "collapse", "separate"),
                          sample = NULL,
                          start = NULL, end = NULL,
                          step = NULL, window = NULL, plot = FALSE) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  window <- .legacy_sample(window, sample)
  spec <- .window_spec(dn, start, end, step, window)
  at <- .as_time(at, dn, "at")

  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    grid <- .grid_for(enc, dn, spec)
    if (!is.null(at)) {
      # With overlapping windows more than one covers `at`; all of them are
      # returned, since each is a genuine measurement of that moment.
      k <- which(grid$lo <= at & grid$hi > at)
      if (length(k) == 0L) k <- which.min(abs(grid$lo - at))
      grid <- grid[k, , drop = FALSE]
    }
    do.call(rbind, lapply(seq_len(nrow(grid)), function(k) {
      state <- .snapshot_state(
        dn, enc, grid[k, , drop = FALSE], spec$window, sessions, label
      )
      act <- state$active
      if (!any(act)) return(NULL)
      key <- paste(enc$from[act], enc$to[act], sep = "\r")
      by_pair <- split(seq_len(sum(act)), key)
      ends <- do.call(rbind, strsplit(names(by_pair), "\r", fixed = TRUE))
      out <- data.frame(
        session = label, time = grid$time[k],
        from = enc$names[as.integer(ends[, 1L])],
        to   = enc$names[as.integer(ends[, 2L])],
        weight   = vapply(by_pair, function(i) sum(enc$weight[act][i]), numeric(1L)),
        n_spells = vapply(by_pair, length, integer(1L)),
        stringsAsFactors = FALSE)
      if ("observation" %in% names(grid)) {
        out <- cbind(
          out["session"], observation = grid$observation[k],
          out[setdiff(names(out), "session")]
        )
      }
      out
    }))
  }, parts, names(parts))

  out <- do.call(rbind, frames)
  if (is.null(out)) {
    out <- data.frame(session = character(), time = numeric(),
                      from = character(), to = character(), weight = numeric(),
                      n_spells = integer(), stringsAsFactors = FALSE)
  }
  if (is.null(dn$meta$sessions)) out$session <- NULL
  rownames(out) <- NULL
  attr(out, "vertex_population") <- "eligible_window_any_induced"
  attr(out, "vertex_window_rule") <- if (spec$window == 0) {
    "instant_exact"
  } else "any"
  attr(out, "edge_endpoint_rule") <- "induced_after_elementwise_union"
  attr(out, "vertex_observation") <- "component_intersection_non_destructive"
  attr(out, "session_vertex_aggregation") <- switch(
    sessions, collapse = "calendar_union", bounded = "session_induced_union",
    separate = "session_local"
  )
  attr(out, "time_unit") <- dn$meta$time_unit
  attr(out, "directed") <- dn$directed
  class(out) <- c("dynet_snapshot", "data.frame")
  .maybe_plot(out, plot)
}

#' Tidy table of snapshot edges
#'
#' @param x A `dynet_snapshot` from [snapshots()].
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param ... Ignored.
#' @return A plain `data.frame` with the same rows and columns.
#' @examples
#' head(as.data.frame(snapshots(dynet(school_contacts))))
#' @export
as.data.frame.dynet_snapshot <- function(x, row.names = NULL,
                                         optional = FALSE, ...) {
  out <- x
  attributes(out) <- attributes(out)[c("names", "row.names")]
  class(out) <- "data.frame"
  out
}

#' Print snapshot edges
#'
#' @param x A `dynet_snapshot` from [snapshots()].
#' @param n Number of rows to show.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @examples
#' snapshots(dynet(school_contacts), at = 3)
#' @export
print.dynet_snapshot <- function(x, n = 10L, ...) {
  flat <- as.data.frame(x)
  bins <- length(unique(flat$time))
  cat(sprintf("# Snapshot edges | %s bin%s | %s tie row%s | time in %s\n",
              bins, if (bins == 1L) "" else "s",
              nrow(flat), if (nrow(flat) == 1L) "" else "s",
              attr(x, "time_unit") %||% "step"))
  if (!nrow(flat)) {
    cat("# No tie is active in the requested window.\n")
    return(invisible(x))
  }
  print(utils::head(flat, n))
  if (nrow(flat) > n) {
    cat(sprintf("# %s more rows. summary() counts them by bin.\n",
                nrow(flat) - n))
  }
  invisible(x)
}

#' Summarise snapshot edges by time bin
#'
#' @param object A `dynet_snapshot` from [snapshots()].
#' @param ... Ignored.
#' @return A plain `data.frame` with one row per bin and columns `session`
#'   (when present), `time`, `ties`, `nodes` and `weight`.
#' @examples
#' summary(snapshots(dynet(school_contacts)))
#' @export
summary.dynet_snapshot <- function(object, ...) {
  flat <- as.data.frame(object)
  keys <- intersect(c("session", "time"), names(flat))
  if (!nrow(flat)) {
    return(data.frame(time = numeric(), ties = integer(), nodes = integer(),
                      weight = numeric()))
  }
  key <- interaction(flat[keys], drop = TRUE, lex.order = TRUE)
  parts <- split(seq_len(nrow(flat)), key)
  out <- do.call(rbind, lapply(parts, function(i) {
    head_row <- flat[i[[1L]], keys, drop = FALSE]
    cbind(head_row,
          data.frame(ties = length(i),
                     nodes = length(unique(c(flat$from[i], flat$to[i]))),
                     weight = sum(flat$weight[i])))
  }))
  out <- out[order(out$time), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Plot how many ties each snapshot holds
#'
#' @param x A `dynet_snapshot` from [snapshots()].
#' @param base_size Base font size.
#' @param palette Palette specification, as in [plot.dynet()].
#' @param ... Ignored.
#' @return A `ggplot` object.
#' @examples
#' plot(snapshots(dynet(school_contacts)))
#' @export
plot.dynet_snapshot <- function(x, base_size = 12, palette = "okabe", ...) {
  counts <- summary(x)
  if (!nrow(counts)) {
    stop(errorCondition(
      "There is nothing to draw: no tie is active in any requested window.",
      class = "dynet_empty_result", call = NULL))
  }
  unit <- attr(x, "time_unit") %||% "step"
  p <- ggplot2::ggplot(counts, ggplot2::aes(x = time, y = ties)) +
    ggplot2::geom_step(colour = .dyn_palette(palette, 1L), linewidth = 0.7) +
    ggplot2::labs(x = sprintf("time (%s)", unit), y = "ties in bin") +
    ggplot2::theme_minimal(base_size = base_size)
  if ("session" %in% names(counts)) {
    p <- p + ggplot2::facet_wrap(~session, scales = "free_x")
  }
  p
}
