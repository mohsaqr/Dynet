# ===========================================================================
# Drawing a temporal network
# ===========================================================================

#' Draw a temporal network
#'
#' @description
#' Five views, each answering a different question.
#'
#' \describe{
#'   \item{`"events"`}{Every contact as a link drawn at the moment it fires,
#'     with actors on the vertical axis. A link leaves its source in the
#'     source's colour and arrives in the target's.}
#'   \item{`"timeline"`}{Edge activity as an intensity heatmap, one row per
#'     pair. This is the
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
#' @param node_size,node_shape,node_fill,node_border_color,node_border_width,node_alpha
#'   Node aesthetics, named as in `cograph::splot()`. `NULL` uses the view's
#'   own default. For the node-link views these are forwarded to splot.
#' @param edge_color,edge_alpha,edge_width,edge_width_range,edge_style Link
#'   aesthetics, named as in `cograph::splot()`. An `edge_color` overrides the
#'   source-to-target colour run with one colour.
#' @param curvature,curve_pivot Bow geometry, as in `cograph::splot()`.
#'   `curvature` is the base bow as a fraction of the column gap and `0` draws
#'   straight links; `curve_pivot` slides where the bow peaks.
#' @param label_size,label_color,label_fontface Axis label aesthetics, named as
#'   in `cograph::splot()`.
#' @param bins Number of equal time bins for `"timeline"` and `"events"`.
#'   `NULL` uses the network's own interval.
#' @param link Link glyph for `"events"`: `"hook"` (default), `"arc"`,
#'   `"chevron"`, `"wave"` or `"bracket"`.
#' @param time Time axis for `"events"`. `"bin"` groups onsets into equal
#'   windows and keeps duration honest, `"event"` gives one evenly spaced
#'   column per distinct onset, `"clock"` uses true positions.
#' @param aggregate For `"events"`, fold repeat firings of one pair inside one
#'   column into a single link. Binning merges distinct onsets, and without
#'   this they stack as parallel bows carrying no extra reading.
#' @param nest For `"events"`, which links are fanned apart. `"pair"` fans
#'   only links joining the same two rows in the same column; `"column"` fans
#'   every link sharing a column.
#' @param split For `"events"`, the share of each link that keeps its source
#'   colour before switching to its target's, so direction reads without
#'   arrowheads.
#' @param blend For `"events"`, fade between the two endpoint colours instead
#'   of switching at a boundary.
#' @param weight For `"events"`, scale alpha and width by how often the pair
#'   occurs across the network, so one-off links recede and habitual ones
#'   stand out.
#' @param type One of `"timeline"`, `"events"`, `"activity"`, `"network"`,
#'   `"snapshots"`,
#'   `"proximity"`.
#' @param at For `"network"`, the time to draw. `NULL` draws the whole window
#'   flattened.
#' @param step For `"layers"`, the width of each time slice. `NULL` uses the
#'   construction interval.
#' @param omega For `"layers"`, the weight on the identity arcs carrying a
#'   vertex between adjacent slices, that is, the interlayer coupling.
#' @param start,end Window the plot to `[start, end]` before drawing. Either
#'   may be `NULL`, which keeps that side of the observed range. Every view is
#'   windowed, and an empty window is an error rather than an empty panel.
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
plot.dynet <- function(x, type = c("timeline", "events", "activity", "network",
                                   "snapshots", "proximity", "layers",
                                   "heatmap", "stack"),
                       at = NULL, start = NULL, end = NULL, top = 40L,
                       step = NULL, omega = 1,
                       bins = NULL, link = c("hook", "arc", "chevron", "wave",
                                             "bracket"),
                       time = c("bin", "event", "clock"),
                       aggregate = TRUE, nest = c("pair", "column"),
                       split = 0.8, blend = FALSE, weight = TRUE,
                       node_size = NULL, node_shape = NULL, node_fill = NULL,
                       node_border_color = NULL, node_border_width = NULL,
                       node_alpha = NULL, edge_color = NULL, edge_alpha = NULL,
                       edge_width = NULL, edge_width_range = NULL,
                       edge_style = NULL, curvature = NULL, curve_pivot = NULL,
                       label_size = NULL, label_color = NULL,
                       label_fontface = NULL,
                       panels = 9L,
                       measure = "degree", phases = NULL, networks = TRUE,
                       events = TRUE, labels = TRUE, highlight = NULL,
                       slices = 120L, window = NULL, flow = 2L,
                       palette = "okabe", default_dist = 2, base_size = 12,
                       style = .dyn_style(), ...) {
  .check_dynet(x)
  type <- match.arg(type)
  .check_plot_dots(list(...), type)
  link <- match.arg(link)
  time <- match.arg(time)
  nest <- match.arg(nest)
  # Resolved once here so that an unusable palette is reported immediately,
  # rather than only when a view happens to need a colour from it.
  .dyn_palette(palette, 1L)
  x <- .clip_plot_range(x, start, end)
  # These names are `cograph::splot()`'s own. For the views that delegate they
  # must keep reaching splot, so anything the caller actually set is spliced
  # back into the forwarded dots rather than being swallowed here.
  aes_args <- Filter(Negate(is.null), list(
    node_size = node_size, node_shape = node_shape, node_fill = node_fill,
    node_border_color = node_border_color,
    node_border_width = node_border_width, node_alpha = node_alpha,
    edge_color = edge_color, edge_alpha = edge_alpha, edge_width = edge_width,
    edge_width_range = edge_width_range, edge_style = edge_style,
    curvature = curvature, curve_pivot = curve_pivot,
    label_size = label_size, label_color = label_color,
    label_fontface = label_fontface))
  switch(type,
    timeline   = .plot_timeline(x, top, bins, base_size),
    events     = .plot_events(x, link = link, time = time, bins = bins,
                              aggregate = aggregate, nest = nest,
                              split = split, blend = blend, weight = weight,
                              palette = palette, base_size = base_size,
                              aes = aes_args),
    activity   = .plot_activity(x, base_size),
    network    = do.call(.splot_network,
                         c(list(x, at, palette = palette), aes_args,
                           list(...))),
    snapshots  = do.call(.splot_snapshots,
                         c(list(x, panels, palette = palette), aes_args,
                           list(...))),
    layers     = .plot_layers(x, step = step, omega = omega,
                              palette = palette, labels = labels, ...),
    heatmap    = .plot_layer_heatmap(x, step = step, palette = palette, ...),
    stack      = .plot_layer_stack(x, step = step, palette = palette,
                                   labels = labels, ...),
    proximity  = .plot_proximity(x, measure = measure, phases = phases,
                                 networks = networks, events = events,
                                 labels = labels, default_dist = default_dist,
                                 slices = slices, window = window,
                                 flow = flow, highlight = highlight,
                                 palette = palette, style = style, ...)
  )
}


#' One weight matrix per time slice
#'
#' The three layer views all need the same thing: the network cut into slices,
#' every slice carrying the full vertex set so a vertex keeps its identity
#' across the stack. Built once here so the views cannot disagree about what a
#' slice is.
#'
#' @param x A `dynet` object.
#' @param step Width of each slice, or `NULL` for the construction interval.
#' @param prefix Prefix for the slice names.
#' @return A named list of square weight matrices, one per slice, sharing
#'   dimnames.
#' @keywords internal
.dyn_layer_matrices <- function(x, step, prefix = "t") {
  .check(
    "`step` must be one positive number or NULL." =
      is.null(step) || (length(step) == 1L && is.numeric(step) &&
                          is.finite(step) && step > 0)
  )
  long <- snapshots(x, step = step %||% x$meta$interval)
  vertices <- sort(unique(c(long$from, long$to)))
  blocks <- split(long, long$time)
  if (length(blocks) < 2L) {
    stop(errorCondition(
      "A layer view needs at least two time slices; reduce `step`.",
      class = "dynet_empty_result", call = NULL))
  }
  stats::setNames(lapply(blocks, function(block) {
    m <- matrix(0, length(vertices), length(vertices),
                dimnames = list(vertices, vertices))
    m[cbind(match(block$from, vertices), match(block$to, vertices))] <-
      block$weight
    m
  }), sprintf("%s%s", prefix, names(blocks)))
}

#' Draw the time slices as heatmap planes
#'
#' The matrix counterpart of [.plot_layers()]: each slice is a tilted heatmap
#' plane rather than a node-link diagram. Unlike the other two layer views
#' this returns a `ggplot`, because `cograph::plot_ml_heatmap()` does; the
#' caller prints it like any other ggplot view in this method.
#'
#' @param x A `dynet` object.
#' @param step Width of each slice, or `NULL` for the construction interval.
#' @param palette Palette specification, as in [plot.dynet()].
#' @param ... Passed to `cograph::plot_ml_heatmap()`.
#' @return A `ggplot` object.
#' @keywords internal
.plot_layer_heatmap <- function(x, step, palette, ...) {
  if (!requireNamespace("cograph", quietly = TRUE)) {
    stop(errorCondition("The heatmap view needs the cograph package.",
                        class = "dynet_missing_package", call = NULL))
  }
  layers <- .dyn_layer_matrices(x, step, prefix = "Slice ")
  # The ramp and legend title are defaults, not decisions: anything the caller
  # named reaches `plot_ml_heatmap()` unchanged instead of colliding with them.
  dots <- list(...)
  defaults <- list(colors = .dyn_heat_ramp(palette), legend_title = "Weight")
  do.call(cograph::plot_ml_heatmap,
          c(list(layers), utils::modifyList(defaults, dots)))
}

#' Draw the time slices as a projected node-link stack
#'
#' Delegates to `cograph::plot_temporal()`, which takes the tidy per-slice
#' edge list [snapshots()] already returns. Vertex colours are supplied as a
#' named vector so a vertex keeps one colour through the whole stack, which is
#' what makes it followable between planes.
#'
#' @param x A `dynet` object.
#' @param step Width of each slice, or `NULL` for the construction interval.
#' @param palette Palette specification, as in [plot.dynet()].
#' @param labels Whether to draw vertex labels.
#' @param ... Passed to `cograph::plot_temporal()`.
#' @return The `dynet` object, invisibly. Drawn to the current device.
#' @keywords internal
.plot_layer_stack <- function(x, step, palette, labels, ...) {
  if (!requireNamespace("cograph", quietly = TRUE)) {
    stop(errorCondition("The stack view needs the cograph package.",
                        class = "dynet_missing_package", call = NULL))
  }
  long <- snapshots(x, step = step %||% x$meta$interval)
  vertices <- sort(unique(c(long$from, long$to)))
  dots <- list(...)
  defaults <- list(
    time = "time",
    node_color = stats::setNames(.dyn_palette(palette, length(vertices)),
                                 vertices),
    show_labels = isTRUE(labels))
  do.call(cograph::plot_temporal,
          c(list(long), utils::modifyList(defaults, dots)))
  invisible(x)
}

#' A sequential ramp for the heatmap planes
#'
#' Okabe-Ito is a categorical palette; a matrix plane needs a continuous one.
#' White to the palette's blue keeps the family recognisable while staying
#' monotone in lightness.
#'
#' @param palette Palette specification, as in [plot.dynet()].
#' @return A character vector of colours defining the ramp.
#' @keywords internal
.dyn_heat_ramp <- function(palette) {
  c("#FFFFFF", .dyn_palette(palette, 2L))
}

#' Draw the time-sliced network as a multilayer stack
#'
#' Each time slice becomes a layer of one multilayer network, and a vertex
#' appears once per slice. `cograph::plot_mlna()` needs every row and column of
#' the supra-adjacency to carry a unique name, so the keys are
#' `slice_vertex`; the display labels are the bare vertex names, passed
#' separately, so no internal key reaches the page. Assembling that pairing is
#' the package's job, not the caller's.
#'
#' @param x A `dynet` object.
#' @param step Width of each slice, or `NULL` for the construction interval.
#' @param omega Interlayer coupling weight on the identity arcs.
#' @param palette Palette specification, as in [plot.dynet()].
#' @param labels Whether to draw vertex labels.
#' @param ... Passed to `cograph::plot_mlna()`.
#' @return The `dynet` object, invisibly. Drawn to the current device.
#' @keywords internal
.plot_layers <- function(x, step, omega, palette, labels, ...) {
  if (!requireNamespace("cograph", quietly = TRUE)) {
    stop(errorCondition("The layer view needs the cograph package.",
                        class = "dynet_missing_package", call = NULL))
  }
  .check(
    "`omega` must be one non-negative number." =
      length(omega) == 1L && is.numeric(omega) && is.finite(omega) && omega >= 0
  )
  layers <- .dyn_layer_matrices(x, step)
  slice_names <- names(layers)

  supra <- unclass(cograph::supra_adjacency(layers, omega = omega,
                                            coupling = "diagonal"))
  keys <- rownames(supra)
  # The key layout is `<slice>_<vertex>`: a slice's members are recovered by
  # prefix and the display label by stripping it. Both sides are built here
  # from the same construction, never matched by the caller.
  members <- stats::setNames(
    lapply(slice_names, function(nm) keys[startsWith(keys, paste0(nm, "_"))]),
    slice_names)
  display <- data.frame(
    label = keys,
    labels = sub("^[^_]+_", "", keys),
    stringsAsFactors = FALSE
  )
  dots <- list(...)
  defaults <- list(layer_list = members, nodes = display,
                   show_labels = isTRUE(labels))
  do.call(cograph::plot_mlna,
          c(list(supra), utils::modifyList(defaults, dots)))
  invisible(x)
}

#' Reject plot arguments that no view will ever read
#'
#' Everything in `...` reaches `cograph::splot()` for the node-link views and
#' nothing at all for the ggplot views, so a misspelled name would otherwise
#' be accepted in silence and the caller would be handed a picture that
#' ignored it. Names are checked against this method's own arguments plus, for
#' the views that delegate, `splot()`'s.
#'
#' @param dots The captured `...`.
#' @param type The plot type being drawn.
#' @return `TRUE`, invisibly.
#' @keywords internal
.check_plot_dots <- function(dots, type) {
  if (!length(dots)) return(invisible(TRUE))
  nm <- names(dots)
  if (is.null(nm) || any(!nzchar(nm))) {
    stop(errorCondition(
      "Every argument passed through `...` to plot() must be named.",
      class = "dynet_unknown_plot_arg", call = NULL))
  }
  known <- names(formals(plot.dynet))
  delegate <- switch(type, layers = "plot_mlna", heatmap = "plot_ml_heatmap",
                     stack = "plot_temporal", network = , snapshots = ,
                     proximity = "splot", NULL)
  delegates <- !is.null(delegate)
  if (delegates && requireNamespace("cograph", quietly = TRUE)) {
    known <- c(known, names(formals(getExportedValue("cograph", delegate))))
  }
  unknown <- setdiff(nm, setdiff(known, "..."))
  if (length(unknown)) {
    stop(errorCondition(
      sprintf(
        "%s %s %s not accepted by plot(type = \"%s\").%s",
        if (length(unknown) > 1L) "Arguments" else "Argument",
        paste(sQuote(unknown), collapse = ", "),
        if (length(unknown) > 1L) "are" else "is", type,
        if (delegates)
          " Drawing arguments are passed to cograph::splot()."
        else " This view takes no further drawing arguments."),
      class = "dynet_unknown_plot_arg", call = NULL))
  }
  invisible(TRUE)
}

#' Restrict a network to the window a plot was asked for
#'
#' @param x A `dynet` object.
#' @param start,end Optional bounds; `NULL` keeps the observed edge.
#' @return A `dynet` object covering the requested window.
#' @keywords internal
.clip_plot_range <- function(x, start, end) {
  if (is.null(start) && is.null(end)) return(x)
  span <- x$meta$time_range
  from <- if (is.null(start)) span[[1L]] else start
  to <- if (is.null(end)) span[[2L]] else end
  .check(
    "`start` must be one finite number." =
      is.null(start) || (length(start) == 1L && is.numeric(start) &&
                           is.finite(start)),
    "`end` must be one finite number." =
      is.null(end) || (length(end) == 1L && is.numeric(end) && is.finite(end)),
    "`start` must be earlier than `end`." = from < to
  )
  clipped <- .range_netobject(x, from, to)
  if (is.null(clipped)) {
    stop(errorCondition(
      sprintf("No edge or vertex is active between %s and %s.", from, to),
      class = "dynet_empty_result", call = NULL))
  }
  clipped
}


#' Trace one link glyph between two actors at one event column
#'
#' Every style is a polyline from `(x, y1)` to `(x, y2)` that bulges by `d`
#' into the gutter left of its own event column, so simultaneous links can be
#' nested rather than drawn on top of one another.
#'
#' @param style One of `"hook"`, `"arc"`, `"chevron"`, `"wave"`, `"bracket"`.
#' @param x Event position on the time axis.
#' @param y1,y2 Actor positions of the two endpoints.
#' @param d How far the glyph may bulge into the gutter.
#' @param n Vertices in the polyline.
#' @return A data frame of `x` and `y` polyline vertices.
#' @keywords internal
.link_path <- function(style, x, y1, y2, d, n = 60L, pivot = 0.5) {
  t <- seq(0, 1, length.out = n)
  y <- y1 + t * (y2 - y1)
  # `pivot` slides where the bow peaks, as splot's curve_pivot does. Only the
  # bulge is re-parameterised: shifting `t` for the y values as well would
  # merely re-space the vertices and leave the drawn curve identical.
  b <- if (isTRUE(all.equal(pivot, 0.5))) t else {
    pv <- min(max(pivot, 0.02), 0.98)
    ifelse(t < pv, 0.5 * t / pv, 0.5 + 0.5 * (t - pv) / (1 - pv))
  }
  mid <- y1 + pivot * (y2 - y1)
  out <- switch(style,
    # Flattened ends meet the node almost square-on, so an endpoint stays
    # readable where a circular arc would leave it at a slant.
    hook    = list(x = x - d * sin(pi * b)^2.2, y = y),
    arc     = list(x = x - d * sin(pi * b), y = y),
    chevron = list(x = c(x, x - d, x), y = c(y1, mid, y2)),
    wave    = list(x = x - d * sin(pi * b) * (0.55 + 0.45 * cos(3 * pi * b)),
                   y = y),
    bracket = list(x = c(x, x - d, x - d, x), y = c(y1, y1, y2, y2))
  )
  data.frame(x = out$x, y = out$y)
}

#' Union length of intervals clipped to one bin
#'
#' Overlapping spells for one pair count once, the same pairwise-union
#' convention `"temporal_density"` uses, so a bin can never report more
#' activity than its own width.
#'
#' @param s,e Spell starts and ends.
#' @param lo,hi Bin bounds.
#' @return The length of the clipped union.
#' @keywords internal
.union_len <- function(s, e, lo, hi) {
  s <- pmax(s, lo); e <- pmin(e, hi)
  ok <- e > s
  if (!any(ok)) return(0)
  s <- s[ok]; e <- e[ok]
  o <- order(s); s <- s[o]; e <- e[o]
  reach <- cummax(c(-Inf, utils::head(e, -1L)))
  block <- cumsum(s > reach)
  sum(tapply(e, block, max) - tapply(s, block, min))
}


#' Colour one link's polyline from its source into its target
#'
#' @param from_col,to_col Endpoint colours.
#' @param n Vertices in the polyline.
#' @param split Share of the run that keeps the source colour.
#' @param blend Fade between the two rather than switching at a boundary.
#' @return A character vector of `n` colours.
#' @keywords internal
.link_cols <- function(from_col, to_col, n, split = 0.8, blend = FALSE) {
  if (isTRUE(blend)) {
    ramp <- grDevices::colorRamp(c(from_col, to_col))
    at <- pmin(1, pmax(0, (seq(0, 1, length.out = n) - (1 - split)) / split))
    rgb <- ramp(at)
    return(grDevices::rgb(rgb[, 1L], rgb[, 2L], rgb[, 3L],
                          maxColorValue = 255))
  }
  cut <- max(1L, round(split * n))
  c(rep(from_col, cut), rep(to_col, n - cut))
}

#' Place event columns on the time axis
#' @param v Times to place.
#' @param time Axis rule.
#' @param span Observed range.
#' @param interval Bin width for `"bin"`.
#' @param stamps Distinct onsets for `"event"`.
#' @return Numeric positions.
#' @keywords internal
.event_place <- function(v, time, span, interval, stamps) {
  switch(time,
    clock = v,
    event = match(v, stamps),
    bin = span[[1L]] + (pmin(floor((v - span[[1L]]) / interval),
                             ceiling(diff(span) / interval) - 1L) + 0.5) *
            interval)
}

#' Draw contacts as links at the moment they fire
#'
#' @param x A `dynet` object.
#' @param link Glyph style.
#' @param time Axis rule.
#' @param bins Number of equal bins, or `NULL` for the network's interval.
#' @param aggregate Fold repeat firings of one pair inside one column.
#' @param nest Which links are fanned apart.
#' @param split,blend Source-to-target colour run.
#' @param weight Scale alpha and width by how usual the pair is.
#' @param palette Palette specification.
#' @param base_size Base text size.
#' @return A `ggplot` object.
#' @keywords internal
.plot_events <- function(x, link, time, bins, aggregate, nest, split, blend,
                         weight, palette, base_size, aes = list()) {
  .check(
    "`split` must be one number between 0 and 1." =
      length(split) == 1L && is.numeric(split) && is.finite(split) &&
        split >= 0 && split <= 1,
    "`bins` must be one positive whole number." =
      is.null(bins) || (length(bins) == 1L && is.finite(bins) && bins >= 1 &&
                          bins == as.integer(bins)),
    "`aggregate` must be TRUE or FALSE." =
      length(aggregate) == 1L && is.logical(aggregate) && !is.na(aggregate),
    "`blend` must be TRUE or FALSE." =
      length(blend) == 1L && is.logical(blend) && !is.na(blend),
    "`weight` must be TRUE or FALSE." =
      length(weight) == 1L && is.logical(weight) && !is.na(weight)
  )
  e <- as.data.frame(x)
  if (!nrow(e)) {
    stop(errorCondition("The network has no edge spell to draw.",
                        class = "dynet_empty_result", call = NULL))
  }
  nodes <- x$nodes$name
  lev <- rev(nodes)
  pal <- stats::setNames(.dyn_palette(palette, length(lev)), lev)
  e$yf <- match(e$from, lev)
  e$yt <- match(e$to, lev)
  loops <- e[e$from == e$to, , drop = FALSE]
  e <- e[e$from != e$to, , drop = FALSE]

  span <- x$meta$time_range
  interval <- if (is.null(bins)) x$meta$interval else diff(span) / bins
  stamps <- sort(unique(c(e$start, loops$start)))
  e$ev <- .event_place(e$start, time, span, interval, stamps)
  if (nrow(loops)) {
    loops$ev <- .event_place(loops$start, time, span, interval, stamps)
  }
  cols <- switch(time,
    event = seq_along(stamps),
    clock = stamps,
    bin = span[[1L]] + (seq_len(ceiling(diff(span) / interval)) - 0.5) *
            interval)
  gap <- if (length(cols) > 1L) min(diff(cols)) else 1

  # Usualness is a property of the ordered pair across the whole network, so
  # it is measured before any folding and reads the same in both modes.
  pair <- paste(e$from, e$to)
  e$freq <- as.integer(table(pair)[pair])
  drawn <- nrow(e)
  if (isTRUE(aggregate)) {
    e <- e[!duplicated(paste(e$from, e$to, e$ev)), , drop = FALSE]
  }
  folded <- drawn - nrow(e)
  e$id <- seq_len(nrow(e))

  # Only links joining the same two rows in the same column can overlap;
  # fanning every link in a column separates ties never in danger of it.
  slot <- if (identical(nest, "pair")) {
    paste(e$ev, pmin(e$yf, e$yt), pmax(e$yf, e$yt))
  } else as.character(e$ev)
  k <- ave(e$id, slot, FUN = seq_along)
  kmax <- ave(k, slot, FUN = max)
  # `curvature` is the base bow as a fraction of the column gap, following
  # splot where 0 draws a straight link.
  curvature <- aes$curvature %||% 0.18
  .check("`curvature` must be one non-negative number." =
           length(curvature) == 1L && is.numeric(curvature) &&
           is.finite(curvature) && curvature >= 0)
  e$d <- gap * if (identical(nest, "pair")) {
    curvature + (k - 1L) * 0.14     # small step: groups are size 1 or 2
  } else {
    curvature + (k - 1L) / pmax(kmax - 1L, 1L) * 0.62
  }

  width_range <- aes$edge_width_range %||% c(0.35, 1.4)
  style <- aes$edge_style %||% 1
  solid <- isTRUE(all.equal(style, 1)) || identical(style, "solid")

  n_pt <- 60L
  paths <- do.call(rbind, lapply(e$id, function(i) {
    r <- e[e$id == i, , drop = FALSE]
    hi <- max(r$yf, r$yt); lo <- min(r$yf, r$yt)
    pth <- .link_path(link, r$ev, hi, lo, r$d, n = n_pt,
                      pivot = aes$curve_pivot %||% 0.5)
    m <- nrow(pth)
    # The path always runs high to low so bows nest consistently. When the
    # source sits at the low end that traversal is target-first, so the run
    # is built target-first too and still arrives source-coloured.
    cl <- if (!is.null(aes$edge_color)) {
      rep(aes$edge_color[[1L]], m)
    } else if (!solid) {
      # ggplot cannot vary colour along a non-solid line, so a dashed link
      # takes its source's colour whole rather than the source-to-target run.
      rep(pal[[r$from]], m)
    } else if (r$yf >= r$yt) {
      .link_cols(pal[[r$from]], pal[[r$to]], m, split, blend)
    } else {
      .link_cols(pal[[r$to]], pal[[r$from]], m, 1 - split, blend)
    }
    data.frame(id = i, freq = r$freq, x = pth$x, y = pth$y, col = cl,
               stringsAsFactors = FALSE)
  }))

  grid <- expand.grid(ev = cols, y = seq_along(lev))
  plot <- ggplot2::ggplot() +
    ggplot2::geom_vline(data = data.frame(ev = cols),
                        ggplot2::aes(xintercept = ev), colour = "grey93",
                        linewidth = 0.2)
  plot <- plot + if (isTRUE(weight) && is.null(aes$edge_width)) {
    ggplot2::geom_path(
      data = paths,
      ggplot2::aes(x = x, y = y, group = id, colour = col, alpha = freq,
                   linewidth = freq), lineend = "butt", linetype = style)
  } else {
    ggplot2::geom_path(
      data = paths, ggplot2::aes(x = x, y = y, group = id, colour = col),
      linewidth = aes$edge_width %||% 0.7,
      alpha = aes$edge_alpha %||% 1, lineend = "butt", linetype = style)
  }
  plot <- plot +
    ggplot2::geom_point(
      data = grid, ggplot2::aes(x = ev, y = y),
      colour = aes$node_border_color %||% unname(pal)[grid$y],
      fill = aes$node_fill %||% unname(pal)[grid$y],
      shape = .node_shape(aes$node_shape %||% "circle"),
      stroke = aes$node_border_width %||% 0.5,
      alpha = aes$node_alpha %||% 1,
      size = aes$node_size %||% 2.2)
  if (nrow(loops)) {
    plot <- plot + ggplot2::geom_point(
      data = loops, ggplot2::aes(x = ev, y = yf), shape = 21, size = 3.1,
      stroke = 0.5, colour = "grey20", fill = NA)
  }
  breaks <- cols[unique(round(seq(1, length(cols),
                                  length.out = min(length(cols), 10L))))]
  plot +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_alpha_continuous(range = c(0.2, 0.95), guide = "none") +
    ggplot2::scale_linewidth_continuous(range = c(0.35, 1.4), guide = "none") +
    ggplot2::scale_y_continuous(breaks = seq_along(lev), labels = lev) +
    # Pad only as far as a link can bulge, and label real columns only, so
    # the gutter never becomes axis territory with times that do not exist.
    ggplot2::scale_x_continuous(
      breaks = breaks,
      expand = ggplot2::expansion(add = c(1.05 * gap, 0.35 * gap))) +
    ggplot2::labs(
      x = switch(time, event = "Time (event)",
                 clock = sprintf("Time (%s)", x$meta$time_unit),
                 bin = sprintf("Time (%s)", x$meta$time_unit)),
      y = NULL, title = "Contacts as they fire",
      subtitle = sprintf(
        "%d links over %d columns; source colour runs %d%% of each link%s",
        nrow(e), length(cols), round(100 * split),
        if (folded > 0L) sprintf("; %d repeat firings folded", folded) else
          "")) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = "grey45", size = 9),
      axis.text.y = ggplot2::element_text(
        size = aes$label_size %||% ggplot2::rel(1),
        colour = aes$label_color %||% "grey20",
        face = aes$label_fontface %||% "plain"))
}

#' Translate a splot shape name to a ggplot shape code
#' @param shape A splot shape name or a ggplot shape number.
#' @return An integer ggplot shape code.
#' @keywords internal
.node_shape <- function(shape) {
  if (is.numeric(shape)) return(as.integer(shape[[1L]]))
  codes <- c(circle = 21L, square = 22L, diamond = 23L, triangle = 24L,
             triangle_down = 25L)
  code <- codes[[match.arg(as.character(shape[[1L]]), names(codes))]]
  code
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
#' Edge activity over time as an intensity heatmap
#'
#' One row per vertex pair, time on the x axis, fill showing how much of each
#' bin the pair was active. Zero-duration contact data has no share to report,
#' so those fall back to a count of contacts in the bin.
#'
#' @param x A `dynet` object.
#' @param top Draw only the `top` busiest pairs.
#' @param bins Number of equal bins, or `NULL` for the network's own interval.
#' @param base_size Base text size.
#' @return A `ggplot` object.
#' @keywords internal
.plot_timeline <- function(x, top, bins, base_size) {
  e <- as.data.frame(x)
  if (!nrow(e)) {
    stop(errorCondition("The network has no edge spell to draw.",
                        class = "dynet_empty_result", call = NULL))
  }
  e$pair <- .pair_label(e$from, e$to, x$directed)
  busiest <- names(sort(table(e$pair), decreasing = TRUE))
  keep <- utils::head(busiest, top)
  dropped <- length(busiest) - length(keep)
  e <- e[e$pair %in% keep, , drop = FALSE]

  span <- range(c(e$start, e$end))
  width <- if (is.null(bins)) x$meta$interval else diff(span) / bins
  n_bin <- max(1L, ceiling(diff(span) / width))
  edges <- span[[1L]] + seq.int(0L, n_bin) * width
  mid <- utils::head(edges, -1L) + width / 2
  pointy <- all(e$end <= e$start)

  cell <- do.call(rbind, lapply(keep, function(p) {
    s <- e[e$pair == p, , drop = FALSE]
    value <- vapply(seq_len(n_bin), function(i) {
      lo <- edges[[i]]; hi <- edges[[i + 1L]]
      if (pointy) sum(s$start >= lo & s$start < hi)
      # The union cannot exceed the bin width; the division can leave a value
      # a rounding step above 1, which would fall outside the scale limits
      # and render as missing.
      else min(1, .union_len(s$start, s$end, lo, hi) / width)
    }, numeric(1L))
    data.frame(pair = p, time = mid, value = value, stringsAsFactors = FALSE)
  }))
  cell$pair <- factor(cell$pair, levels = rev(keep))
  cell <- cell[cell$value > 0, , drop = FALSE]

  ggplot2::ggplot(cell) +
    ggplot2::geom_tile(ggplot2::aes(x = time, y = pair, fill = value),
                       height = 0.8) +
    ggplot2::scale_fill_gradient(
      low = "#DCE9F5", high = "#0072B2",
      limits = if (pointy) NULL else c(0, 1),
      name = if (pointy) "Contacts in bin" else "Share of bin active") +
    ggplot2::labs(
      x = sprintf("Time (%s)", x$meta$time_unit), y = NULL,
      title = "Edge activity over time",
      subtitle = sprintf(
        "%d bins of %s%s", n_bin, format(width, digits = 3),
        if (dropped > 0L) sprintf("; %d busiest pairs shown, %d not drawn",
                                  length(keep), dropped) else "")) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = "grey45", size = 9),
      axis.text.y = ggplot2::element_text(size = ggplot2::rel(0.72)))
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
#' @return A `ggplot` object for current shortest-foremost results. The legacy
#'   `cograph` tree renderer remains only for older serialized results without
#'   criterion metadata, and draws to the active device.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' journeys <- paths(dn, from = "Ana")
#' plot(journeys)
#'
#' @export
plot.dynet_paths <- function(x, palette = "okabe", ...) {
  mode <- attr(x, "path_mode") %||% "collapse"
  # An endpoint-local optimal family is exactly what the trajectory tree
  # draws: a prefix tree that repeats a vertex reached under a different
  # temporal history, rather than one predecessor tree the criterion never
  # promised.
  if (!is.null(attr(x, "criterion"))) {
    return(plot_path_trajectories(x, ...))
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
