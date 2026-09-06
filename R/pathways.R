# ===========================================================================
# Complete time-respecting routes, ranked by how often they are used
# ===========================================================================
# path_trajectories() returns the prefix TREE, which shows where routes
# diverge but spreads a route's frequency along its branch. This file answers
# the other question: which whole routes are used most. Every leaf of the tree
# is one complete route and its count is that route's frequency, so the work
# is to walk each leaf back to the root and tabulate.

#' Walk every leaf of a trajectory tree back to its root
#'
#' @param tree A `dynet_path_trajectories` data frame.
#' @return A list of two data frames. `routes` has one row per leaf, with
#'   `route`, `endpoint`, `count`, `n_hops` and `arrival_time`; `steps` has one
#'   row per vertex visited, with `route`, `step`, `vertex` and `time`.
#' @noRd
.trajectory_routes <- function(tree) {
  flat <- as.data.frame(tree)
  flat <- flat[flat$node != .PATH_ROOT, , drop = FALSE]
  if (!nrow(flat)) {
    return(list(
      routes = data.frame(
        route = character(), endpoint = character(), count = integer(),
        n_hops = integer(), arrival_time = numeric(), stringsAsFactors = FALSE),
      steps = data.frame(
        route = character(), step = integer(), vertex = character(),
        time = numeric(), stringsAsFactors = FALSE)
    ))
  }
  parent_of <- stats::setNames(flat$parent, flat$node)
  vertex_of <- stats::setNames(flat$vertex, flat$node)
  leaves <- flat[!flat$node %in% flat$parent, , drop = FALSE]

  time_of <- stats::setNames(flat$time, flat$node)
  sequences <- lapply(leaves$node, function(id) {
    vertices <- character(0)
    times <- numeric(0)
    # Ancestor chains are short (one element per hop) and each step depends on
    # the previous, so this walk cannot be vectorised.
    while (!is.na(id) && nzchar(id) && !identical(id, .PATH_ROOT)) {
      vertices <- c(vertex_of[[id]], vertices)
      times <- c(time_of[[id]], times)
      id <- parent_of[[id]]
    }
    list(vertex = vertices, time = times)
  })
  vertices <- lapply(sequences, function(s) s$vertex)
  routes <- data.frame(
    route = vapply(vertices, paste, character(1L), collapse = .PATH_JOIN),
    endpoint = vapply(vertices, function(v) v[[length(v)]], character(1L)),
    count = as.integer(leaves$count),
    n_hops = vapply(vertices, length, integer(1L)) - 1L,
    arrival_time = leaves$time,
    stringsAsFactors = FALSE
  )
  # The per-step detail is what makes a time-respecting drawing possible: a
  # route is not just a sequence of names, it is a sequence of ARRIVALS.
  steps <- do.call(rbind, lapply(seq_along(sequences), function(i) {
    one <- sequences[[i]]
    data.frame(
      route = routes$route[[i]], step = seq_along(one$vertex) - 1L,
      vertex = one$vertex, time = one$time,
      stringsAsFactors = FALSE
    )
  }))
  list(routes = routes, steps = steps)
}

#' Most frequent time-respecting routes
#'
#' `pathways()` reports whole journeys rather than per-vertex summaries: one
#' row per distinct route, ranked by how many optimal routes follow it. It
#' answers "which pathways does this network actually use", where
#' [path_trajectories()] answers "where do the routes diverge" and [paths()]
#' answers "who is reachable".
#'
#' The result is already ordered and already carries the share of the total,
#' so a caller never sorts or subsets it; `top` limits it in the call.
#'
#' Routes are keyed on their **vertex sequence**. The trajectory tree keys a
#' node on vertex *and* time, so one sequence realised through different
#' contacts appears there as several branches; those are one pathway here and
#' their counts are added. Under the foremost criterion this loses nothing:
#' only earliest-arrival routes survive to be counted, so duplicates of a
#' sequence necessarily share an arrival time, and a test asserts it.
#'
#' @param dn A temporal network from [dynet()].
#' @param from Optional source vertex. One name gives the routes leaving that
#'   vertex. The default pools every vertex, which is the network-wide
#'   question, and adds a `from` column naming each route's source.
#' @param top Optional number of routes to keep, most frequent first. The
#'   default keeps all of them.
#' @param min_hops Shortest route to report. Defaults to one, which drops the
#'   zero-hop route from a vertex to itself.
#' @param ... Passed to [paths()], so `start`, `end`, `at`, `direction`,
#'   `sessions` and `traversal_time` all apply.
#'
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn, so `plot = TRUE` saves the
#'   wrapping `plot()` call without changing what comes back. Use `plot()` on
#'   the result when the figure needs arguments of its own.
#' @return An object of class `dynet_pathways`, a data frame with one row per
#'   distinct route, most frequent first: `route`, the vertex sequence joined
#'   by arrows; `endpoint`, where it lands; `count`, how many optimal routes
#'   follow it; `share`, its fraction of the counted total; `n_hops`; and
#'   `arrival_time`. Pooling over every source adds `from` as the first
#'   column. Use `as.data.frame()` for a plain frame.
#'
#' @seealso [paths()] for reachability, [path_trajectories()] for the prefix
#'   tree those routes share.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' pathways(dn, from = "Ana")
#' pathways(dn, top = 5)
#'
#' @export
pathways <- function(dn, from = NULL, top = NULL, min_hops = 1L, ..., plot = FALSE) {
  .check_dynet(dn, "bounded")
  .check(
    "`top` must be one positive number, or NULL." =
      is.null(top) || (length(top) == 1L && is.numeric(top) &&
                         is.finite(top) && top >= 1),
    "`min_hops` must be one non-negative number." =
      length(min_hops) == 1L && is.numeric(min_hops) &&
        is.finite(min_hops) && min_hops >= 0
  )
  sources <- if (is.null(from)) dn$nodes$name else {
    unknown <- setdiff(as.character(from), dn$nodes$name)
    if (length(unknown)) {
      stop(errorCondition(
        sprintf("Unknown node(s): %s.", paste(unknown, collapse = ", ")),
        class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL))
    }
    as.character(from)
  }
  pooled <- is.null(from)

  parts <- lapply(sources, function(source) {
    found <- .trajectory_routes(path_trajectories(paths(dn, from = source, ...)))
    if (!nrow(found$routes)) return(NULL)
    list(routes = cbind(from = source, found$routes, stringsAsFactors = FALSE),
         steps = cbind(from = source, found$steps, stringsAsFactors = FALSE))
  })
  parts <- parts[!vapply(parts, is.null, logical(1L))]
  routes <- do.call(rbind, lapply(parts, `[[`, "routes"))
  step_detail <- do.call(rbind, lapply(parts, `[[`, "steps"))
  if (is.null(routes) || !nrow(routes)) {
    stop(errorCondition(
      "No route of the requested length was found.",
      class = "dynet_empty_result", call = NULL))
  }
  routes <- routes[routes$n_hops >= min_hops, , drop = FALSE]
  if (!nrow(routes)) {
    stop(errorCondition(
      sprintf("No route of at least %s hop(s) was found.", format(min_hops)),
      class = "dynet_empty_result", call = NULL))
  }

  # One sequence realised at several times is one pathway; add the counts.
  key <- paste(routes$from, routes$route, sep = "\r")
  merged <- lapply(split(seq_len(nrow(routes)), key), function(ix) {
    rows <- routes[ix, , drop = FALSE]
    data.frame(
      from = rows$from[[1L]], route = rows$route[[1L]],
      endpoint = rows$endpoint[[1L]], count = sum(rows$count),
      n_hops = rows$n_hops[[1L]], arrival_time = min(rows$arrival_time),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, merged)
  # Both the share and the reported total are over EVERY route, not over the
  # `top` that survive: a share that renormalised to the visible subset would
  # always sum to one and say nothing.
  counted <- sum(out$count)
  distinct <- nrow(out)
  out$share <- out$count / counted
  out <- out[order(-out$count, out$n_hops, out$route), , drop = FALSE]
  if (!is.null(top)) out <- utils::head(out, as.integer(top))
  front <- c(if (pooled) "from", "route", "endpoint", "count", "share",
             "n_hops", "arrival_time")
  out <- out[, front, drop = FALSE]
  rownames(out) <- NULL

  # Carry only the steps of the routes that survived, keyed the same way, so
  # `what = "steps"` and the plot always describe exactly what was returned.
  step_key <- if (pooled) {
    paste(step_detail$from, step_detail$route, sep = "\r")
  } else step_detail$route
  out_key <- if (pooled) paste(out$from, out$route, sep = "\r") else out$route
  step_detail <- step_detail[step_key %in% out_key, , drop = FALSE]
  # The routes were merged across duplicate leaves, so the steps must be too,
  # or a route merged from three leaves would carry three copies of every hop.
  # Duplicates of a sequence share their times (asserted in test), so keeping
  # the first occurrence of each (route, step) is lossless rather than a pick.
  step_detail <- step_detail[
    !duplicated(paste(step_key[step_key %in% out_key], step_detail$step,
                      sep = "\r")), , drop = FALSE]
  if (!pooled) step_detail$from <- NULL
  rownames(step_detail) <- NULL

  .maybe_plot(
    structure(out, class = c("dynet_pathways", "data.frame"),
              pooled = pooled, n_sources = length(sources),
              counted = counted, distinct = distinct, steps = step_detail),
    plot
  )
}

#' Tidy data frame of ranked pathways
#'
#' @param x A `dynet_pathways` result.
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param what `"routes"`, the default, gives one row per distinct route.
#'   `"steps"` gives one row per vertex visited -- `route`, `step`, `vertex`
#'   and the `time` the route reaches it, preceded by `from` when pooled --
#'   which is the per-hop timing the plot draws and the shape to use for any
#'   waiting-time analysis of your own.
#' @param ... Ignored.
#' @return A plain `data.frame` with the columns described in [pathways()],
#'   most frequent first, or the per-step table when `what = "steps"`.
#' @examples
#' as.data.frame(pathways(dynet(school_contacts), from = "Ana"))
#' as.data.frame(pathways(dynet(school_contacts), from = "Ana"),
#'               what = "steps")
#' @export
as.data.frame.dynet_pathways <- function(x, row.names = NULL, optional = FALSE,
                                         what = c("routes", "steps"), ...) {
  what <- match.arg(what)
  if (identical(what, "steps")) return(attr(x, "steps"))
  out <- x
  attributes(out) <- list(names = names(x), row.names = seq_len(nrow(x)),
                          class = "data.frame")
  out
}

#' Print ranked pathways
#'
#' @param x A `dynet_pathways` result.
#' @param n Number of routes to show. Defaults to twelve.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @examples
#' pathways(dynet(school_contacts), from = "Ana")
#' @export
print.dynet_pathways <- function(x, n = 12L, ...) {
  total <- attr(x, "distinct")
  cat(sprintf("# Time-respecting pathways (%d distinct route%s%s)\n",
              total, if (total == 1L) "" else "s",
              if (nrow(x) < total) sprintf(", showing %d", nrow(x)) else ""))
  cat(sprintf("# %d optimal route%s counted%s\n", attr(x, "counted"),
              if (attr(x, "counted") == 1L) "" else "s",
              if (isTRUE(attr(x, "pooled"))) {
                sprintf(", pooled over %d source vertices",
                        attr(x, "n_sources"))
              } else ""))
  print(utils::head(as.data.frame(x), n), row.names = FALSE)
  if (nrow(x) > n) {
    cat(sprintf("# %d more of the %d kept. Use top = to keep a different number.\n",
                nrow(x) - n, nrow(x)))
  }
  invisible(x)
}

#' Summarise ranked pathways
#'
#' @param object A `dynet_pathways` result.
#' @param ... Ignored.
#' @return A plain `data.frame`, one row per endpoint: `endpoint`, the number
#'   of distinct `routes` reaching it, their summed `count` and `share`, the
#'   `min_hops` of the shortest, and `first_arrival`, the earliest time any
#'   route lands there. Ordered by count.
#' @examples
#' summary(pathways(dynet(school_contacts), from = "Ana"))
#' @export
summary.dynet_pathways <- function(object, ...) {
  flat <- as.data.frame(object)
  parts <- lapply(split(seq_len(nrow(flat)), flat$endpoint), function(ix) {
    rows <- flat[ix, , drop = FALSE]
    data.frame(
      endpoint = rows$endpoint[[1L]], routes = nrow(rows),
      count = sum(rows$count), share = sum(rows$share),
      min_hops = min(rows$n_hops),
      first_arrival = min(rows$arrival_time),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, parts)
  out <- out[order(-out$count, out$endpoint), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Plot pathways on a time axis
#'
#' One row per route, drawn along real time: a point at each vertex placed at
#' the moment the route reaches it, joined by a segment. The horizontal gap
#' between two points is the waiting time at that vertex, so the drawing is
#' time-respecting in the way a bar of a route string is not -- a route that
#' waits is visibly slower than one that does not, and where routes arrive
#' relative to each other is read off the axis.
#'
#' Routes are ordered by frequency, most used at the top, with the count and
#' share to the right of each. Fill marks the endpoint, which the row already
#' names, so colour never carries a distinction alone.
#'
#' @param x A `dynet_pathways` result.
#' @param top Number of routes to draw, most frequent first. Defaults to
#'   twelve, which keeps the vertex labels legible.
#' @param labels Whether to name the vertex at each step. `TRUE` by default;
#'   turn it off for a dense figure where the shape is the point.
#' @param base_size Base font size, as in [ggplot2::theme_minimal()].
#' @param ... Ignored.
#' @return A `ggplot` object.
#' @examples
#' plot(pathways(dynet(school_contacts), from = "Ana"))
#' @export
plot.dynet_pathways <- function(x, top = 12L, labels = TRUE, base_size = 12,
                                ...) {
  .check(
    "`top` must be one positive number." =
      length(top) == 1L && is.numeric(top) && is.finite(top) && top >= 1,
    "`labels` must be one non-missing logical value." =
      is.logical(labels) && length(labels) == 1L && !is.na(labels),
    "`base_size` must be one positive number." =
      length(base_size) == 1L && is.numeric(base_size) &&
        is.finite(base_size) && base_size > 0
  )
  kept <- utils::head(as.data.frame(x), as.integer(top))
  steps <- attr(x, "steps")
  pooled <- isTRUE(attr(x, "pooled"))
  key <- function(frame) {
    if (pooled) paste(frame$from, frame$route, sep = "\r") else frame$route
  }
  drawn <- steps[key(steps) %in% key(kept), , drop = FALSE]

  # Rank is the y position: most frequent at the top, and the frame is already
  # ordered, so the factor simply locks that order in.
  order_key <- key(kept)
  drawn$rank <- factor(key(drawn), levels = rev(order_key))
  kept$rank <- factor(order_key, levels = rev(order_key))
  drawn$endpoint <- kept$endpoint[match(key(drawn), order_key)]

  span <- range(drawn$time)
  pad <- max(diff(span), 1) * 0.06
  kept$tip <- vapply(split(drawn$time, key(drawn)), max,
                     numeric(1L))[order_key]
  kept$note <- sprintf("n=%d  %.0f%%", kept$count, 100 * kept$share)

  plot <- ggplot2::ggplot() +
    ggplot2::geom_line(
      data = drawn,
      ggplot2::aes(x = time, y = rank, group = rank),
      colour = "grey65", linewidth = 0.7
    ) +
    ggplot2::geom_point(
      data = drawn,
      ggplot2::aes(x = time, y = rank, fill = endpoint),
      shape = 21, colour = "white", size = base_size * 0.30, stroke = 0.8
    ) +
    ggplot2::geom_text(
      data = kept,
      ggplot2::aes(x = tip + pad * 0.35, y = rank, label = note),
      hjust = 0, size = base_size * 0.24, colour = "grey30"
    ) +
    ggplot2::scale_fill_manual(
      values = .okabe_ito(length(unique(drawn$endpoint))), guide = "none"
    ) +
    ggplot2::scale_x_continuous(
      expand = ggplot2::expansion(mult = c(0.02, 0.14))
    ) +
    ggplot2::labs(
      x = sprintf("Time%s", if (!is.null(attr(x, "time_unit"))) {
        sprintf(" (%s)", attr(x, "time_unit"))
      } else ""),
      y = NULL,
      title = "Most frequent pathways, on the clock",
      subtitle = sprintf(
        "%d of %d distinct routes; a gap between points is waiting time",
        nrow(kept), attr(x, "distinct")
      )
    ) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_line(
        colour = "grey92", linewidth = 0.4),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_blank()
    )

  if (labels) {
    plot <- plot + ggplot2::geom_text(
      data = drawn,
      ggplot2::aes(x = time, y = rank, label = vertex),
      vjust = -1.15, size = base_size * 0.235, colour = "grey20"
    )
  }
  plot
}
