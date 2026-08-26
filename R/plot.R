# ===========================================================================
# Drawing a temporal network
# ===========================================================================

#' Draw a temporal network
#'
#' @description
#' Five views, each answering a different question.
#'
#' \describe{
#'   \item{`"timeline"`}{Every edge spell as a horizontal bar. This is the
#'     view a static network cannot give you: it shows at a glance whether the
#'     network was busy throughout or concentrated in a few bursts.}
#'   \item{`"activity"`}{Edges forming and dissolving over time.}
#'   \item{`"network"`}{The network as a node-link diagram, drawn by
#'     `cograph::splot()`. With no `at`, the whole window is flattened into one
#'     picture -- useful as a reference point, and as a reminder of how much it
#'     overstates, since every tie appears simultaneous. With `at`, only that
#'     time bin is drawn.}
#'   \item{`"snapshots"`}{Small multiples, one `cograph::splot()` per time
#'     bin, laid out on shared coordinates so positions are comparable across
#'     panels.}
#'   \item{`"proximity"`}{Vertices placed on a vertical line at each time
#'     point according to how close they are in the network, and joined
#'     through time. Clusters appear as bands of lines travelling together.}
#' }
#'
#' All node-link rendering is cograph's. A `dynet` object is a cograph
#' netobject, so `cograph::splot(dn)` works directly and every one of its
#' rendering arguments is available here through `...`.
#'
#' @param x A temporal network from [dynet()].
#' @param type One of `"timeline"`, `"activity"`, `"network"`, `"snapshots"`,
#'   `"proximity"`.
#' @param at For `"network"`, the time to draw. `NULL` draws the whole window
#'   flattened.
#' @param top For the timeline, draw only the `top` busiest vertex pairs.
#' @param panels For snapshots, the maximum number of panels to draw. Bins are
#'   sampled evenly across the window and the choice is reported.
#' @param measure For the proximity view, the node-level measure that line
#'   thickness follows. Any measure [dyn_centrality()] accepts.
#' @param phases For the proximity view, how many phases to split the window
#'   into for the network panels. `NULL` uses the network's sessions when it
#'   has them and three phases otherwise.
#' @param networks Whether the proximity view draws a network panel per phase.
#' @param events Whether the proximity view marks the times edges formed.
#' @param labels Whether the proximity view names each line at its right-hand
#'   end, in place of a legend.
#' @param highlight Vertex names to draw in colour in the proximity view, with
#'   the rest in grey.
#' @param slices How many times the proximity view measures the network across
#'   the window. Smoothness comes from measuring often, never from
#'   interpolation. `NULL` measures once per time bin.
#' @param palette Colours for vertices and lines: `"okabe"` (the default,
#'   nine colour-blind safe colours, recycled), `"extended"` (hue varied with
#'   lightness, about twelve distinct), `"many"` (packed for separation, any
#'   number, not colour-blind safe), your own vector of colours, or a function
#'   of `n` returning `n` colours.
#' @param flow How much to round the corners of each proximity line. Rounding
#'   only ever takes convex combinations of measurements, so it softens the
#'   joints without letting the curve overshoot one. `0` leaves them sharp.
#' @param window Width of each proximity slice. `NULL` uses a sixth of the
#'   observation window, or the bin width if that is wider: scaling is only
#'   meaningful on a slice whose network is connected, and over one narrow bin
#'   most vertices are isolated.
#' @param default_dist Distance assumed between vertices with no path between
#'   them, in the proximity view.
#' @param base_size Base font size for the ggplot views.
#' @param style A base-graphics style list from [.dyn_style()], used by the
#'   proximity view.
#' @param ... Passed to `cograph::splot()` for the network, snapshot and
#'   proximity views.
#'
#' @return For `"timeline"` and `"activity"`, a `ggplot` object. For
#'   `"network"`, `"snapshots"` and `"proximity"`, the figure is drawn on the
#'   current device and `x` is returned invisibly.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' plot(dn)
#' plot(dn, type = "proximity")
#' plot(dn, type = "proximity", measure = "betweenness", phases = 4)
#' plot(dn, type = "network", node_fill = "#56B4E9")
#'
#' @export
plot.dynet <- function(x, type = c("timeline", "activity", "network",
                                   "snapshots", "proximity"),
                       at = NULL, top = 40L, panels = 9L,
                       measure = "degree", phases = NULL, networks = TRUE,
                       events = TRUE, labels = TRUE, highlight = NULL,
                       slices = 120L, window = NULL, flow = 2L,
                       palette = "okabe", default_dist = 2, base_size = 12,
                       style = .dyn_style(), ...) {
  .check_dynet(x)
  type <- match.arg(type)
  # Resolved once here so that an unusable palette is reported immediately,
  # rather than only when a view happens to need a colour from it.
  .dyn_palette(palette, 1L)
  switch(type,
    timeline   = .plot_timeline(x, top, base_size),
    activity   = .plot_activity(x, base_size),
    network    = .splot_network(x, at, palette = palette, ...),
    snapshots  = .splot_snapshots(x, panels, palette = palette, ...),
    proximity  = .plot_proximity(x, measure = measure, phases = phases,
                                 networks = networks, events = events,
                                 labels = labels, default_dist = default_dist,
                                 slices = slices, window = window,
                                 flow = flow, highlight = highlight,
                                 palette = palette, style = style, ...)
  )
}

#' Require cograph, the renderer for every node-link view
#' @return `TRUE`, invisibly.
#' @keywords internal
.need_cograph <- function() {
  if (!requireNamespace("cograph", quietly = TRUE)) {
    stop(errorCondition(
      "Network drawing is done by cograph. Install it with install.packages(\"cograph\").",
      class = "dynet_needs_cograph", call = NULL))
  }
  invisible(TRUE)
}

#' Draw the network, or one bin of it, through cograph
#' @param x A `dynet` object.
#' @param at Time to draw, or `NULL` for the whole window.
#' @param palette Palette specification, as in [plot.dynet()].
#' @param ... Passed to `cograph::splot()`, overriding the defaults below.
#' @return `x`, invisibly.
#' @keywords internal
.splot_network <- function(x, at = NULL, palette = "okabe", ...) {
  .need_cograph()
  net <- if (is.null(at)) x else .bin_netobject(x, at)
  do.call(cograph::splot, c(list(net), .splot_args(net, list(...), palette)))
  invisible(x)
}

#' Dynet's rendering defaults, with anything the caller set taking precedence
#'
#' Colour is carried by the registered `"dynet"` theme (see
#' [.register_dynet_theme()]); everything the theme contract cannot express
#' is stated here. Two things make the extra layer necessary.
#'
#' First, `cograph::splot()` treats a directed netobject carrying no `$method`
#' as a transition network and applies its TNA look: a per-state colour ramp
#' and a numeric label on every edge. That is right for a transition matrix
#' and wrong here, where an edge weight is a count of meetings. The TNA block
#' also runs *before* the theme block and fills `node_fill`, which the theme
#' block then declines to overwrite -- so a theme alone cannot undo it and
#' `tna_styling = FALSE` is required.
#'
#' Second, a theme holds a single `node_fill`. Colouring vertices by their
#' partition needs a vector, so that is supplied here instead, and only when
#' there is a partition -- leaving a plain network free to take its fill from
#' whichever theme the caller asked for.
#'
#' Everything in `...` wins, which is the same delegation contract
#' `lagdynamics::plot_transitions()` uses.
#'
#' @param net The netobject about to be drawn.
#' @param user List of arguments supplied by the caller.
#' @param palette Palette specification, as in [plot.dynet()].
#' @return A list of arguments for `cograph::splot()`.
#' @keywords internal
.splot_args <- function(net, user, palette = "okabe") {
  defaults <- list(
    theme            = "dynet",
    tna_styling      = FALSE,
    psych_styling    = FALSE,
    node_size        = .node_size(nrow(net$nodes)),
    node_border_color = "white",
    arrow_size       = .arrow_size(nrow(net$nodes)),
    edge_labels      = FALSE,
    edge_label_style = "none",
    edge_color       = "#4A4A4A",
    edge_alpha       = 0.55,
    label_size       = 0.75
  )
  if (!is.null(net$nodes$groups)) defaults$node_fill <- .node_fill(net, palette)

  # A netobject that carries its own coordinates should keep them, but
  # `cograph::splot.netobject()` forwards only `x$weights` to the renderer and
  # drops `$nodes` on the way, so a layout stored by `cograph::set_layout()`
  # never arrives. Forward it explicitly. An object with no layout of its own
  # gets a spring layout.
  defaults$layout <- if (.has_layout(net)) {
    data.frame(x = net$nodes$x, y = net$nodes$y)
  } else {
    "spring"
  }

  args <- utils::modifyList(defaults, user)
  # Label colour follows whichever fill actually ends up being used, including
  # one the caller supplied. Okabe-Ito's ninth colour is black, and a black
  # label on it cannot be read.
  if (is.null(args$label_color)) {
    args$label_color <- .label_colour(.effective_fill(args))
  }
  args
}

#' The fill a panel will actually be drawn with
#'
#' Either the fill in the argument list, or the one the chosen theme supplies
#' when no fill was set.
#'
#' @param args Argument list destined for `cograph::splot()`.
#' @return A character vector of colours.
#' @keywords internal
.effective_fill <- function(args) {
  if (!is.null(args$node_fill)) return(args$node_fill)
  theme <- args$theme
  if (is.character(theme) && length(theme) == 1L &&
      requireNamespace("cograph", quietly = TRUE)) {
    th <- cograph::get_theme(theme)
    if (!is.null(th)) {
      fill <- try(th$get("node_fill"), silent = TRUE)
      if (!inherits(fill, "try-error") && !is.null(fill)) return(fill)
    }
  }
  "#FFFFFF"
}

#' Whether a netobject carries usable layout coordinates
#' @param net A netobject.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
.has_layout <- function(net) {
  x <- net$nodes$x
  !is.null(x) && !all(is.na(x))
}

#' Vertex radius that shrinks as the network grows
#' @param n Vertex count.
#' @return A single numeric size for `cograph::splot()`.
#' @keywords internal
.node_size <- function(n) max(2.5, min(8, 24 / sqrt(max(1L, n))))

#' Arrowhead size that shrinks as the network grows
#'
#' `cograph::splot()` defaults to `arrow_size = 1`, which on a busy network
#' gives heads wider than the edges they cap. Shrinking with vertex count
#' keeps direction legible without the arrowheads becoming the picture; the
#' floor stops them vanishing on a large network, the ceiling keeps a
#' four-vertex network from looking like a diagram of arrows.
#'
#' @param n Vertex count.
#' @return A single numeric size for `cograph::splot()`.
#' @keywords internal
.arrow_size <- function(n) max(0.35, min(0.75, 1.7 / sqrt(max(1L, n))))

#' Vertex fill colours, following the partition when there is one
#' cograph's own `palette_colorblind()` is an interpolated ramp, not the
#' Okabe-Ito set, so the partition colours come from [.dyn_palette()].
#'
#' @param net A netobject carrying a `groups` column.
#' @param palette Palette specification, as in [plot.dynet()].
#' @return A character vector of colours, one per vertex.
#' @keywords internal
.node_fill <- function(net, palette = "okabe") {
  g <- as.character(net$nodes$groups)
  lev <- sort(unique(g))
  unname(stats::setNames(.dyn_palette(palette, length(lev)), lev)[g])
}

#' Small multiples, one cograph panel per bin
#' @param x A `dynet` object.
#' @param panels Maximum number of panels.
#' @param palette Palette specification, as in [plot.dynet()].
#' @param ... Passed to `cograph::splot()`.
#' @return `x`, invisibly.
#' @keywords internal
.splot_snapshots <- function(x, panels = 9L, palette = "okabe", ...) {
  .need_cograph()
  grid <- as.data.frame(x, what = "bins")
  times <- grid$time
  if (length(times) > panels) {
    times <- times[round(seq(1, length(times), length.out = panels))]
    message(sprintf("Drawing %d of %d bins, evenly spaced across the window.",
                    length(times), nrow(grid)))
  }
  side <- ceiling(sqrt(length(times)))
  old <- graphics::par(mfrow = c(ceiling(length(times) / side), side),
                       mar = c(0.5, 0.5, 2, 0.5))
  on.exit(graphics::par(old), add = TRUE, after = FALSE)

  # A shared layout keeps a vertex in the same place across panels, so the
  # panels can be compared rather than merely counted. It is written onto each
  # bin's netobject, so every panel is a positioned network in its own right.
  coords <- cograph::layout_oval(x)
  invisible(lapply(times, function(t) {
    net <- .bin_netobject(x, t)
    position <- match(net$nodes$name, x$nodes$name)
    net <- cograph::set_layout(net, coords[position, , drop = FALSE])
    args <- .splot_args(net, utils::modifyList(
      list(title = sprintf("t = %s", format(t))), list(...)), palette)
    do.call(cograph::splot, c(list(net), args))
  }))
  invisible(x)
}

#' The netobject for a single time bin
#' @param x A `dynet` object.
#' @param at Time falling inside the wanted bin.
#' @return A `dynet` netobject holding the eligible vertices and active,
#'   endpoint-valid spells in that bin.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.bin_netobject(dn, 1)
#' @keywords internal
.bin_netobject <- function(x, at) {
  enc <- .encode(x)
  grid <- .grid_for(enc, x)
  k <- which(grid$lo <= at & grid$hi > at)
  if (length(k) == 0L && at == max(grid$hi) && isTRUE(grid$closed[nrow(grid)])) {
    k <- nrow(grid)
  }
  if (length(k) == 0L) {
    stop(errorCondition(
      sprintf("No vertex is observed at t = %s, so there is nothing to draw.",
              format(at)),
      class = "dynet_empty_result", call = NULL
    ))
  }
  state <- .snapshot_state(
    x, enc, grid[k, , drop = FALSE], grid$hi[k] - grid$lo[k],
    "bounded", "all"
  )
  raw_ids <- unique(enc$raw_spell[state$active])
  keep <- x$spells[x$spells$.raw_spell %in% raw_ids, , drop = FALSE]
  if (nrow(keep) == 0L && !any(state$eligible)) {
    stop(errorCondition(
      sprintf("No vertex is eligible at t = %s, so there is nothing to draw.",
              format(at)),
      class = "dynet_empty_result", call = NULL))
  }
  groups <- if ("groups" %in% names(x$nodes)) "groups" else NULL
  nodes <- x$nodes[state$eligible,
    setdiff(names(x$nodes), c("id", "label", "x", "y")), drop = FALSE
  ]
  vertex_spells <- x$vertex_spells[
    x$vertex_spells$node %in% nodes$name, , drop = FALSE
  ]
  .as_netobject(keep, nodes, x$directed, groups, x$meta, vertex_spells)
}

#' Timeline of edge spells
#' @param x A `dynet` object.
#' @param top Number of busiest pairs to draw.
#' @param base_size Base font size.
#' @return A `ggplot` object.
#' @keywords internal
.plot_timeline <- function(x, top, base_size) {
  e <- as.data.frame(x)
  e$pair <- paste(e$from, if (x$directed) "\u2192" else "\u2013", e$to)
  busiest <- names(sort(table(e$pair), decreasing = TRUE))
  keep <- utils::head(busiest, top)
  dropped <- length(busiest) - length(keep)
  e <- e[e$pair %in% keep, , drop = FALSE]
  e$pair <- factor(e$pair, levels = rev(keep))
  # Zero-length spells would be invisible as segments, so give them a tick.
  tick <- diff(range(c(e$start, e$end))) / 300
  e$end_draw <- ifelse(e$end - e$start < tick, e$start + tick, e$end)

  sub <- if (dropped > 0L) {
    sprintf("%d busiest pairs shown; %d further pairs not drawn", length(keep), dropped)
  } else NULL

  ggplot2::ggplot(e) +
    ggplot2::geom_segment(
      ggplot2::aes(x = start, xend = end_draw, y = pair, yend = pair),
      linewidth = 2.2, colour = .okabe_ito(5L)[5L], alpha = 0.85) +
    ggplot2::labs(x = sprintf("Time (%s)", x$meta$time_unit), y = NULL,
                  title = "Edge spells over time", subtitle = sub) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
}

#' Formation and dissolution over time
#' @param x A `dynet` object.
#' @param base_size Base font size.
#' @return A `ggplot` object.
#' @keywords internal
.plot_activity <- function(x, base_size) {
  plot(events(x, measure = c("formation", "dissolution", "active")),
       base_size = base_size) +
    ggplot2::labs(title = "Edges forming, dissolving and active")
}

#' Plot time-respecting paths when a valid renderer exists
#'
#' @description
#' Rendering endpoint-local shortest-foremost families is not currently
#' supported. Such paths need not share prefix-optimal routes, so they do not
#' form one predecessor tree. Inspect their compact counts and expanded steps
#' instead.
#'
#' All P08 shortest-foremost results raise a `dynet_unsupported_plot`
#' condition, regardless of session mode. This keeps rendering from implying
#' a prefix-compatible tree that the endpoint-local criterion does not define.
#'
#' @param x A `dynet_paths` from [paths()].
#' @param palette Palette specification, as in [plot.dynet()]. Vertices are
#'   coloured by how many hops they are from the source.
#' @param ... Passed to `cograph::splot()`.
#'
#' @return For current shortest-foremost results, a classed
#'   `dynet_unsupported_plot` condition. The legacy tree renderer remains only
#'   for older serialized results without criterion metadata.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' paths <- paths(dn, from = "Ana")
#' try(plot(paths), silent = TRUE)
#'
#' @export
plot.dynet_paths <- function(x, palette = "okabe", ...) {
  mode <- attr(x, "path_mode") %||% "collapse"
  if (!is.null(attr(x, "criterion"))) {
    stop(errorCondition(
      "Shortest-foremost paths are endpoint-local and do not necessarily form one predecessor tree. Inspect `as.data.frame(x, what = \"steps\")` until optimal-family rendering is implemented.",
      class = "dynet_unsupported_plot", call = NULL
    ))
  }
  if (!identical(mode, "collapse")) {
    stop(errorCondition(
      "Bounded or separate session paths do not form one predecessor tree. Plot a collapsed path result until session-aware rendering is implemented.",
      class = "dynet_unsupported_plot", call = NULL
    ))
  }
  .need_cograph()
  .dyn_palette(palette, 1L)
  all_nodes <- x$node
  tree_previous <- attr(x, "tree_previous")
  previous_name <- ifelse(
    is.na(tree_previous), NA_character_, all_nodes[tree_previous]
  )
  df <- as.data.frame(x)
  previous_name <- previous_name[df$reachable]
  df <- df[df$reachable, , drop = FALSE]
  if (nrow(df) <= 1L) {
    stop(errorCondition(
      sprintf("%s reaches no other vertex, so there is no tree to draw.",
              sQuote(attr(x, "source"))),
      class = "dynet_empty_result", call = NULL))
  }

  nm <- df$node
  n <- length(nm)
  parent <- match(previous_name, nm)
  child  <- seq_len(n)
  has_parent <- !is.na(parent)

  w <- matrix(0, n, n, dimnames = list(nm, nm))
  w[cbind(parent[has_parent], child[has_parent])] <- 1
  idx <- which(w > 0, arr.ind = TRUE)

  net <- structure(list(
    nodes = data.frame(id = seq_len(n), label = nm, name = nm,
                       x = NA_real_, y = NA_real_,
                       groups = as.character(df$n_hops),
                       arrival_time = df$arrival_time, n_hops = df$n_hops,
                       stringsAsFactors = FALSE),
    edges = data.frame(from = idx[, 1L], to = idx[, 2L], weight = 1,
                       row.names = NULL),
    directed = TRUE, weights = w, data = NULL,
    meta = list(source = "dynet", type = "temporal_path"),
    node_groups = data.frame(node = nm, group = as.character(df$n_hops),
                             stringsAsFactors = FALSE)
  ), class = c("netobject", "cograph_network"))

  # The tree carries its own layout, rather than being handed one at draw
  # time: cograph reads coordinates from $nodes$x and $nodes$y and skips
  # layout computation when they are present, so splot(net) alone is enough.
  net <- cograph::set_layout(net, .layout_temporal(net))

  crowding <- max(table(df$n_hops))
  args <- .splot_args(net, utils::modifyList(
    list(node_size = max(3, min(6, 12 / crowding)),
         # Every edge in a tree carries the same weight, so width would encode
         # nothing; keep it thin and uniform and let position do the work.
         edge_width = 0.7, edge_width_range = c(0.7, 0.7),
         edge_alpha = 0.75, label_size = 0.7),
    list(...)))
  do.call(cograph::splot, c(list(net), args))
  invisible(x)
}

#' Rescale a vector to the interval minus one to one
#' @param v Numeric vector.
#' @return A numeric vector of the same length.
#' @keywords internal
.rescale <- function(v) {
  rng <- range(v, finite = TRUE)
  if (!is.finite(diff(rng)) || diff(rng) == 0) return(rep(0, length(v)))
  2 * (v - rng[1L]) / diff(rng) - 1
}

#' Small offsets that separate vertices sharing a value
#' @param v Numeric vector of grouping values.
#' @return A numeric vector of offsets spanning most of one unit band.
#' @keywords internal
.jitter_within <- function(v) {
  spread <- stats::ave(v, v,
                       FUN = function(g) seq_along(g) / (length(g) + 1) - 0.5)
  spread * 1.8
}
