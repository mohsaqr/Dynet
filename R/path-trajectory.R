# ===========================================================================
# Trajectory trees for optimal temporal path families
# ===========================================================================
# The tree construction, leaf placement, cosine-smoothed branch geometry and
# node placement in this file are ported from the `transitiontrees` package
# (version 0.1.2, Mohammed Saqr and Sonsoles Lopez-Pernas), namely its
# `.trajectory_data()`, `plot_trajectories()`, `.ct_horizontal_layout()`,
# `.ct_horizontal_edge_paths()` and `.plot_horizontal()` internals. Nodes are
# drawn in the horizontal phylogram's circular style: a count-sized point with
# its label set below, rather than the trajectory tree's capsule. The port is
# used here with the permission of the copyright holder. The visual grammar is
# retained; the palette, labelling and the temporal measures are Dynet's.
#
# The adaptation is that a tree node is a *temporal* route prefix, not a
# state prefix. A named vertex reached at a different time is a different
# node, so two optimal routes over the same vertex sequence that differ only
# in when a hop fires remain two branches rather than collapsing into one.

.PATH_ROOT <- "(start)"
.PATH_JOIN <- " -> "
.PATH_UNIT <- "\r"

#' Split route steps into one token sequence per optimal route
#'
#' Each route becomes a character vector of tokens. A token carries the
#' vertex, its attained time and, when present, the session, so that routes
#' are never merged across a distinction the path result draws.
#'
#' @param x A result from [paths()].
#' @return A list of character vectors, one per optimal route.
#' @keywords internal
.path_route_sequences <- function(x) {
  steps <- as.data.frame(x, what = "steps")
  if (!nrow(steps)) {
    stop(errorCondition("The path result has no route steps to draw.",
                        class = "dynet_empty_result", call = NULL))
  }
  identity_cols <- intersect(
    c("session", "endpoint", "path_id", "path_session"), names(steps)
  )
  keys <- lapply(steps[identity_cols], \(value) {
    value <- as.character(value)
    value[is.na(value)] <- "<missing>"
    value
  })
  route <- do.call(paste, c(keys, sep = .PATH_UNIT))

  session <- if ("session" %in% names(steps)) as.character(steps$session) else
    rep("", nrow(steps))
  token <- paste(steps$node, .path_time_token(steps$time), session,
                 sep = .PATH_UNIT)

  # Backward routes are reported from the reached vertex towards the queried
  # target, so reverse them: every tree grows away from the queried vertex.
  backward <- identical(attr(x, "direction"), "backward")
  order_by <- if (backward) -steps$step else steps$step
  parts <- split(data.frame(order_by = order_by, token = token,
                            stringsAsFactors = FALSE), route)
  unname(lapply(parts, \(one) one$token[order(one$order_by)]))
}

#' Format an attained time as a stable token component
#' @param time Numeric vector of attained times.
#' @return A character vector.
#' @keywords internal
.path_time_token <- function(time) {
  out <- sprintf("%.12g", time)
  out[is.na(time)] <- "NA"
  out
}

#' Render a route prefix as a readable pathway
#'
#' Tree nodes are keyed on internal tokens that carry the vertex, its
#' attained time and any session. This turns such a key into the pathway a
#' reader sees, as `vertex@time` steps joined by arrows.
#'
#' @param node Character vector of prefix keys.
#' @return A character vector of readable pathways.
#' @keywords internal
.path_display_path <- function(node) {
  vapply(node, \(one) {
    if (is.na(one)) return(NA_character_)
    if (identical(one, .PATH_ROOT)) return(.PATH_ROOT)
    units <- strsplit(one, .PATH_JOIN, fixed = TRUE)[[1L]]
    parts <- .path_token_parts(units)
    # The stamp reuses the key's own formatting, so a display pathway stays a
    # faithful one-to-one rendering of the node key it replaces.
    step <- sprintf("%s@%s", parts$vertex, .path_time_token(parts$time))
    step <- ifelse(is.na(parts$session), step,
                   sprintf("%s[%s]", step, parts$session))
    paste(step, collapse = .PATH_JOIN)
  }, character(1L), USE.NAMES = FALSE)
}

#' Split a route token back into vertex, time and session
#' @param token Character vector of route tokens.
#' @return A data frame with `vertex`, `time` and `session` columns.
#' @keywords internal
.path_token_parts <- function(token) {
  parts <- strsplit(token, .PATH_UNIT, fixed = TRUE)
  pick <- function(index) vapply(parts, \(one) {
    if (length(one) < index) NA_character_ else one[[index]]
  }, character(1L))
  time <- suppressWarnings(as.numeric(pick(2L)))
  session <- pick(3L)
  data.frame(vertex = pick(1L), time = time,
             session = ifelse(is.na(session) | !nzchar(session), NA_character_,
                              session),
             stringsAsFactors = FALSE)
}

#' Build a counted prefix tree from token sequences
#'
#' A direct port of the `transitiontrees` forward trajectory tree: every
#' prefix occurring at least `min_count` times becomes a node joined to its
#' one-shorter prefix, and any prefix whose parent did not survive the count
#' filter is dropped so the tree stays connected to the root.
#'
#' @param sequences A list of character vectors of tokens.
#' @param min_count Minimum prefix frequency to retain.
#' @return A data frame with `node`, `parent`, `depth`, `count` and `last`.
#' @keywords internal
.path_prefix_tree <- function(sequences, min_count = 1L) {
  .check(
    "`sequences` must be a list of character vectors." =
      is.list(sequences) && all(vapply(sequences, is.character, logical(1L))),
    "`min_count` must be one positive whole number." =
      length(min_count) == 1L && !is.na(min_count) && is.finite(min_count) &&
        min_count >= 1 && min_count == as.integer(min_count)
  )
  min_count <- as.integer(min_count)
  if (!length(sequences)) {
    stop(errorCondition("The path result has no route steps to draw.",
                        class = "dynet_empty_result", call = NULL))
  }

  prefixes <- unlist(lapply(sequences, \(one)
    vapply(seq_along(one),
           \(k) paste(one[seq_len(k)], collapse = .PATH_JOIN),
           character(1L))), use.names = FALSE)
  counts <- table(prefixes)
  keep <- names(counts)[counts >= min_count]
  if (!length(keep)) {
    stop(errorCondition(
      sprintf("No route prefix occurs at least %d times; lower `min_count`.",
              min_count),
      class = "dynet_empty_result", call = NULL))
  }

  split_prefix <- strsplit(keep, .PATH_JOIN, fixed = TRUE)
  parent_of <- vapply(split_prefix, \(m) {
    if (length(m) == 1L) .PATH_ROOT else
      paste(m[-length(m)], collapse = .PATH_JOIN)
  }, character(1L))
  last_of <- vapply(split_prefix, \(m) m[[length(m)]], character(1L))

  node <- c(.PATH_ROOT, keep)
  depth <- c(0L, lengths(split_prefix))
  count <- c(length(sequences), as.integer(counts[keep]))
  parent <- c(NA_character_, parent_of)
  last <- c(NA_character_, last_of)

  # Keep the tree connected: drop any prefix whose parent was filtered out.
  ok <- node == .PATH_ROOT | parent %in% node
  data.frame(node = node[ok], parent = parent[ok], depth = depth[ok],
             count = count[ok], last = last[ok],
             stringsAsFactors = FALSE, row.names = NULL)
}

#' Place tree nodes on a depth-by-branch grid
#'
#' Leaves are stacked in depth-first order and every parent is centred on its
#' children, the placement used by the `transitiontrees` trajectory tree and
#' horizontal phylogram. The stack is reversed so the first route reads at
#' the top of the canvas.
#'
#' @param tree A data frame from [.path_prefix_tree()].
#' @return `tree` with an added numeric `branch` column.
#' @keywords internal
.path_tree_branches <- function(tree) {
  children <- split(tree$node[tree$node != .PATH_ROOT],
                    tree$parent[tree$node != .PATH_ROOT])
  placed <- new.env(hash = TRUE, parent = emptyenv())
  leaf <- 0
  place <- function(nd) {
    kids <- children[[nd]]
    value <- if (is.null(kids)) {
      leaf <<- leaf + 1
      leaf
    } else {
      mean(vapply(kids, place, numeric(1L)))
    }
    assign(nd, value, envir = placed)
    value
  }
  place(.PATH_ROOT)
  branch <- vapply(tree$node, \(nd) get(nd, envir = placed), numeric(1L))
  tree$branch <- unname(leaf + 1 - branch)
  tree
}

#' Trace cosine-smoothed branch polylines between placed nodes
#'
#' Ported from the `transitiontrees` smoothed edge geometry: a cosine
#' smoothstep carries each branch from parent to child so it leaves and
#' arrives along the depth axis rather than as a right-angle elbow.
#'
#' @param layout A placed tree with `node`, `x`, `y` and `count` columns.
#' @param n_pt Number of vertices per branch polyline.
#' @return A data frame with `edge`, `x`, `y` and `count` columns.
#' @keywords internal
.path_tree_edges <- function(layout, n_pt = 40L) {
  child <- layout[!is.na(layout$parent), , drop = FALSE]
  if (!nrow(child)) {
    return(data.frame(edge = integer(), x = numeric(), y = numeric(),
                      count = numeric(), stringsAsFactors = FALSE))
  }
  at <- match(child$parent, layout$node)
  phase <- seq(0, 1, length.out = n_pt)
  ease <- (1 - cos(pi * phase)) / 2
  rows <- lapply(seq_len(nrow(child)), \(i) data.frame(
    edge = i,
    x = layout$x[at[i]] + phase * (child$x[i] - layout$x[at[i]]),
    y = layout$y[at[i]] + ease * (child$y[i] - layout$y[at[i]]),
    count = child$count[i], stringsAsFactors = FALSE
  ))
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Optimal temporal routes as a counted trajectory tree
#'
#' @description
#' Turns the optimal route family returned by [paths()] into a tidy
#' prefix tree. Every row is one tree node: a route prefix reaching `vertex`
#' at `time`, used by `count` optimal routes. A named vertex reached through
#' a different temporal history is a separate row, so branches never create
#' the misleading crossings of a path-union graph and two routes that differ
#' only in when a hop fires stay separate.
#'
#' Forward routes grow away from the queried source. Backward routes are
#' reversed, so the queried target is the root and possible senders branch
#' away from it.
#'
#' @param x A result from [paths()].
#' @param min_count Keep only branches used by at least this many optimal
#'   routes. The default of `1` keeps the complete family; a higher value is
#'   the caller's explicit pruning.
#' @return A `dynet_path_trajectories` data frame with one row per tree node
#'   and columns `node`, `parent`, `depth`, `count`, `probability`, `vertex`,
#'   `time`, `session` and `branch`. `depth` is the hop number from the
#'   queried vertex, `probability` is the branching fraction of the parent's
#'   routes that continue along this branch, and `branch` is the node's
#'   placement across the tree.
#' @examples
#' dn <- dynet(school_contacts)
#' paths <- paths(dn, from = "Ana")
#' path_trajectories(paths)
#' @seealso [plot_path_trajectories()] to draw the tree, [path_network()] for
#'   the route union as a network.
#' @export
path_trajectories <- function(x, min_count = 1L) {
  if (!inherits(x, "dynet_paths")) {
    stop(errorCondition("`x` must be a result from `paths()`.",
                        class = "dynet_bad_input", call = NULL))
  }
  tree <- .path_prefix_tree(.path_route_sequences(x), min_count = min_count)
  tree <- .path_tree_branches(tree)

  # Every route in a path family starts at the queried vertex, so the
  # synthetic root usually has a single child and is pure clutter: it spends a
  # hop of canvas and pushes the anchor to hop 1 when it is hop 0. Drop it
  # there and let the anchor be the root. It is kept only when it genuinely
  # branches, as under `sessions = "separate"`, where it carries one subtree
  # per session.
  root_children <- tree$node[tree$parent %in% .PATH_ROOT]
  if (length(root_children) == 1L) {
    tree <- tree[tree$node != .PATH_ROOT, , drop = FALSE]
    tree$parent[tree$node == root_children] <- NA_character_
    tree$depth <- tree$depth - 1L
  }

  parts <- .path_token_parts(tree$last)
  at_parent <- match(tree$parent, tree$node)
  probability <- tree$count / tree$count[at_parent]

  out <- data.frame(
    node = .path_display_path(tree$node),
    parent = .path_display_path(tree$parent), depth = tree$depth,
    count = tree$count, probability = unname(probability),
    vertex = parts$vertex, time = parts$time, session = parts$session,
    branch = tree$branch, stringsAsFactors = FALSE, row.names = NULL
  )
  attr(out, "direction") <- attr(x, "direction") %||% "forward"
  attr(out, "anchor") <- attr(x, "source")
  attr(out, "min_count") <- as.integer(min_count)
  class(out) <- c("dynet_path_trajectories", "data.frame")
  out
}

#' Tidy table of a temporal trajectory tree
#' @param x A result from [path_trajectories()].
#' @param row.names,optional Ignored.
#' @param ... Ignored.
#' @return A plain data frame with one row per tree node.
#' @export
as.data.frame.dynet_path_trajectories <- function(
    x, row.names = NULL, optional = FALSE, ...) {
  out <- x
  attr(out, "direction") <- NULL
  attr(out, "anchor") <- NULL
  attr(out, "min_count") <- NULL
  class(out) <- "data.frame"
  out
}

#' Print a temporal trajectory tree
#' @param x A result from [path_trajectories()].
#' @param ... Passed to the data frame print method.
#' @return `x`, invisibly.
#' @export
print.dynet_path_trajectories <- function(x, ...) {
  cat(sprintf("# %s temporal trajectory tree %s %s\n",
              tools::toTitleCase(attr(x, "direction")),
              if (identical(attr(x, "direction"), "backward")) "to" else "from",
              attr(x, "anchor")))
  cat(sprintf("# %d nodes, %d hops deep, %d routes\n",
              nrow(x), max(x$depth), x$count[[1L]]))
  print(as.data.frame(x), ...)
  invisible(x)
}

#' Draw optimal temporal paths as a trajectory tree
#'
#' @description
#' Draws the optimal route family returned by [paths()] using the
#' trajectory-tree grammar ported from the `transitiontrees` package: leaves
#' stacked in depth-first order, parents centred on their children, branches
#' carried by a cosine smoothstep, and capsule node glyphs. Branch width
#' always shows how many optimal routes use a branch; node fill shows the
#' chosen `measure`, and every node also prints its value, so nothing is
#' encoded by colour alone.
#'
#' Forward paths grow away from the queried source. Backward paths are
#' flipped so the queried target is the root and possible senders branch away
#' from it. A named vertex repeats whenever it is reached under a different
#' temporal history.
#'
#' @param x A result from [paths()] or from [path_trajectories()].
#' @param measure Node fill. `"frequency"` is the number of optimal routes
#'   through the branch, `"time"` is the attained time at the node, and
#'   `"predictability"` is the branching fraction of the parent's routes that
#'   continue along the branch.
#' @param orientation `"horizontal"` grows the tree left to right with hop
#'   number on the x axis; `"vertical"` grows it top to bottom.
#' @param min_count Draw only branches used by at least this many optimal
#'   routes. Ignored when `x` is already a [path_trajectories()] result.
#' @param base_size Base text size.
#' @return A `ggplot` object.
#' @examples
#' dn <- dynet(school_contacts)
#' paths <- paths(dn, from = "Ana")
#' plot_path_trajectories(paths)
#' plot_path_trajectories(paths, measure = "time", orientation = "vertical")
#' @seealso [path_trajectories()] for the tidy tree behind the plot.
#' @export
plot_path_trajectories <- function(
    x, measure = c("frequency", "time", "predictability"),
    orientation = c("horizontal", "vertical"), min_count = 1L,
    base_size = 11) {
  measure <- match.arg(measure)
  orientation <- match.arg(orientation)
  .check("`base_size` must be one positive number." =
           length(base_size) == 1L && is.numeric(base_size) &&
           is.finite(base_size) && base_size > 0)
  tree <- if (inherits(x, "dynet_path_trajectories")) x else
    path_trajectories(x, min_count = min_count)

  is_root <- tree$node == .PATH_ROOT
  body <- tree[!is_root, , drop = FALSE]
  if (!nrow(body)) {
    stop(errorCondition("The trajectory tree has no route branch to draw.",
                        class = "dynet_empty_result", call = NULL))
  }

  fill_value <- switch(measure,
    frequency = body$count,
    time = body$time,
    predictability = body$probability
  )
  value_label <- switch(measure,
    frequency = sprintf("n=%d", body$count),
    time = sprintf("t=%s", ifelse(
      is.na(body$time), "?",
      formatC(body$time, digits = 4, format = "fg", width = 1L))),
    predictability = sprintf("%.0f%%", 100 * body$probability)
  )
  legend <- switch(measure,
    frequency = "Optimal routes",
    time = "Attained time",
    predictability = "P(branch | history)"
  )

  # Depth-by-branch coordinates. Leaves are rescaled onto [0, 1] across the
  # branch axis, the normalisation the horizontal phylogram's label-clearance
  # constants below are written against.
  layout <- tree
  span <- diff(range(layout$branch))
  across <- if (span > 0) (layout$branch - min(layout$branch)) / span else
    rep(0.5, nrow(layout))
  if (identical(orientation, "horizontal")) {
    layout$x <- layout$depth
    layout$y <- across
  } else {
    layout$x <- across
    layout$y <- -layout$depth
  }
  layout$fill_value <- NA_real_
  layout$fill_value[!is_root] <- fill_value
  edges <- .path_tree_edges(layout)

  body_layout <- layout[!is_root, , drop = FALSE]
  root_layout <- layout[is_root, , drop = FALSE]

  point_size_range <- c(4, 14)
  edge_size_range <- c(0.3, 2.5)

  # Per-node label clearance, ported from the horizontal phylogram: the size
  # aesthetic maps count to area, so a large hub needs its label pushed
  # further below the glyph than a small leaf. The offset is expressed in
  # fractions of the label axis, which is unit-spanned when the tree is drawn
  # horizontally and hop-spanned when it is drawn vertically.
  counts <- body_layout$count
  count_range <- if (nrow(body_layout)) range(counts) else c(0, 0)
  point_size <- if (nrow(body_layout) && diff(count_range) > 0) {
    point_size_range[[1L]] +
      sqrt((counts - count_range[[1L]]) / diff(count_range)) *
        diff(point_size_range)
  } else rep(mean(point_size_range), nrow(body_layout))
  label_span <- max(diff(range(layout$y)), 1)
  body_layout$label_y <- body_layout$y -
    (0.012 + point_size * 0.0035) * label_span

  body_layout$label <- paste(
    gsub("_", " ", body_layout$vertex, fixed = TRUE), value_label, sep = "\n"
  )

  limits <- if (identical(measure, "predictability")) c(0, 1) else NULL
  ramp <- if (identical(measure, "time")) c("#FBE6D4", "#D55E00") else
    c("#DCE9F5", "#0072B2")

  direction <- attr(tree, "direction") %||% "forward"
  anchor_word <- if (identical(direction, "backward")) "to" else "from"
  hop_axis <- sprintf("Hop %s %s", anchor_word, attr(tree, "anchor"))

  plot <- ggplot2::ggplot() +
    ggplot2::geom_path(
      data = edges,
      ggplot2::aes(x = x, y = y, group = edge, linewidth = count),
      colour = "grey60", lineend = "round", linejoin = "round"
    ) +
    ggplot2::geom_point(
      data = body_layout,
      ggplot2::aes(x = x, y = y, size = count, fill = fill_value),
      shape = 21, colour = "grey25", stroke = 0.2, na.rm = TRUE
    ) +
    ggplot2::geom_text(
      data = body_layout,
      ggplot2::aes(x = x, y = label_y, label = label),
      hjust = 0.5, vjust = 1, size = 2.5, lineheight = 0.9,
      colour = "grey20", na.rm = TRUE
    ) +
    ggplot2::geom_point(
      data = root_layout, ggplot2::aes(x = x, y = y),
      shape = 16, size = max(point_size_range) * 0.85, colour = "grey15"
    ) +
    ggplot2::geom_text(
      data = root_layout, ggplot2::aes(x = x, y = y), label = .PATH_ROOT,
      hjust = 1, nudge_x = -0.14, size = 3, colour = "grey25",
      fontface = "bold"
    ) +
    ggplot2::scale_size_continuous(range = point_size_range,
                                   name = "Optimal routes") +
    ggplot2::scale_linewidth_continuous(range = edge_size_range,
                                        guide = "none") +
    # Node size already carries the route count, so a frequency fill would
    # print the same legend twice; keep the fill guide only when it says
    # something size does not.
    ggplot2::scale_fill_gradient(
      low = ramp[[1L]], high = ramp[[2L]], limits = limits, name = legend,
      guide = if (identical(measure, "frequency")) "none" else "colourbar") +
    ggplot2::labs(
      title = sprintf("%s temporal path trajectories %s %s",
                      tools::toTitleCase(direction), anchor_word,
                      attr(tree, "anchor")),
      subtitle = paste(
        "Node size and branch width are the number of optimal routes;",
        "a repeated vertex was reached under a different temporal history"
      )
    ) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = "grey35", size = 9),
      plot.margin = ggplot2::margin(8, 12, 8, 12)
    )

  hops <- seq_len(max(layout$depth) + 1L) - 1L
  if (identical(orientation, "horizontal")) {
    plot +
      ggplot2::scale_x_continuous(
        breaks = hops, expand = ggplot2::expansion(mult = c(0.17, 0.32))) +
      ggplot2::labs(x = hop_axis, y = NULL) +
      ggplot2::theme(axis.text.y = ggplot2::element_blank(),
                     axis.ticks.y = ggplot2::element_blank())
  } else {
    plot +
      ggplot2::scale_y_continuous(
        breaks = -hops, labels = hops,
        expand = ggplot2::expansion(mult = c(0.17, 0.10))) +
      ggplot2::labs(x = NULL, y = hop_axis) +
      ggplot2::theme(axis.text.x = ggplot2::element_blank(),
                     axis.ticks.x = ggplot2::element_blank())
  }
}
