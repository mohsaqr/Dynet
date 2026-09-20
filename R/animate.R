# ===========================================================================
# animate() — the measurement grid as an animation
# ===========================================================================

# The layouts a name can ask for. A coordinate table is accepted as well.
.animation_layouts_named <- c("spring", "relaxed", "circle", "oval", "groups")

# File extensions the verb can write, and which encoder each one needs.
.animation_formats <- c(gif = "gifski", mp4 = "av", webm = "av")

# How a tie is drawn during a transition between two bins. Colour and line
# type carry the same distinction, so it survives a monochrome print and a
# colour-vision deficiency alike. The colours are Okabe-Ito.
.tie_state_colours <- c(forming = "#009E73", persisting = "#4A4A4A",
  dissolving = "#D55E00")
.tie_state_styles <- c(forming = "dotted", persisting = "solid",
  dissolving = "dashed")

#' Evaluate an expression under a seed, leaving the caller's RNG untouched
#' @param seed A seed, or `NULL` to draw from the current random state.
#' @param expr Expression to evaluate.
#' @return The value of `expr`.
#' @noRd
.with_seed <- function(seed, expr) {
  if (is.null(seed)) return(expr)
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = globalenv()) else NULL
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  }, add = TRUE, after = FALSE)
  set.seed(seed)
  expr
}

#' Edge table of a weight matrix, in the order cograph draws it
#'
#' Mirrors the rule `.as_netobject()` uses, which is also the order
#' `cograph::splot()` derives from the weights matrix it is handed: column
#' major over the positive cells, and for an undirected network only the
#' cells with `from <= to`. Every per-edge vector the animation passes to
#' `splot()` (widths, alphas, colours, line types) is aligned to this order,
#' and `test-animate-contract.R` pins the agreement.
#' @param w A square numeric weight matrix.
#' @param directed Whether the network is directed.
#' @return A data frame with `from`, `to` (integer positions) and `weight`.
#' @noRd
.matrix_edges <- function(w, directed) {
  idx <- which(w > 0, arr.ind = TRUE)
  if (!directed) idx <- idx[idx[, 1L] <= idx[, 2L], , drop = FALSE]
  data.frame(from = as.integer(idx[, 1L]), to = as.integer(idx[, 2L]),
    weight = as.numeric(w[idx]), row.names = NULL)
}

#' The union of every frame, as one netobject
#'
#' Weights are summed over the frames, so a pair that met in many bins pulls
#' harder in the layout than one that met once.
#' @param frames List of frame netobjects over the same vertex set.
#' @return A netobject whose `weights` and `edges` describe the union.
#' @noRd
.union_netobject <- function(frames) {
  net <- frames[[1L]]
  net$weights <- Reduce(`+`, lapply(frames, function(f) f$weights))
  net$edges <- .matrix_edges(net$weights, net$directed)
  net
}

#' Validate a caller-supplied coordinate table
#' @param x A `dynet` object.
#' @param layout A data frame with `name` (or `node`), `x` and `y`.
#' @return A data frame of `x` and `y`, one row per vertex of `x` in
#'   `x$nodes` order. Raises `dynet_missing_column` when a column is absent
#'   and `dynet_unknown_node` when the table does not name every vertex
#'   exactly once.
#' @noRd
.custom_layout <- function(x, layout) {
  key <- intersect(c("name", "node"), names(layout))
  if (!length(key) || !all(c("x", "y") %in% names(layout))) {
    stop(errorCondition(
      "A layout table needs the columns `name` (or `node`), `x` and `y`.",
      class = c("dynet_missing_column", "dynet_bad_input"), call = NULL))
  }
  given <- as.character(layout[[key[[1L]]]])
  unknown <- setdiff(given, x$nodes$name)
  absent <- setdiff(x$nodes$name, given)
  if (length(unknown) || length(absent) || anyDuplicated(given)) {
    stop(errorCondition(
      sprintf(paste(
        "A layout table must name every vertex exactly once.",
        "Not in the network: %s. Missing: %s. Repeated: %s."),
      .or_none(unknown), .or_none(absent), .or_none(given[duplicated(given)])),
      class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL))
  }
  coords <- data.frame(x = as.numeric(layout$x), y = as.numeric(layout$y))
  if (!all(is.finite(coords$x)) || !all(is.finite(coords$y))) {
    stop(errorCondition(
      "Layout coordinates `x` and `y` must be finite numbers.",
      class = "dynet_bad_input", call = NULL))
  }
  coords[match(x$nodes$name, given), , drop = FALSE]
}

#' Comma-separated names, or "none"
#' @param x Character vector.
#' @return One string.
#' @noRd
.or_none <- function(x) {
  if (!length(x)) "none" else paste(sQuote(unique(x)), collapse = ", ")
}

#' The partition layout, which needs a partition
#' @param x A `dynet` object built with `groups = `.
#' @return A data frame of `x` and `y`. Raises `dynet_unknown_attribute` when
#'   the network has no partition.
#' @noRd
.group_layout <- function(x) {
  if (is.null(x$nodes$groups)) {
    stop(errorCondition(
      "`layout = \"groups\"` needs a partition. Build the network with `groups = ` naming a vertex attribute.",
      class = c("dynet_unknown_attribute", "dynet_bad_input"), call = NULL))
  }
  as.data.frame(cograph::layout_groups(x, groups = x$nodes$groups))
}

#' Smooth a sequence of layouts across time
#'
#' A centred triangular kernel over one bin on each side, `(1, 2, 1) / 4`,
#' with the ends held. Each smoothed step is a convex combination of raw
#' steps, so the largest frame-to-frame move can only shrink; the
#' `max_displacement` guarantee survives. Measured on `school_contacts`
#' (22 bins), it halved the direction reversals between consecutive moves
#' (0.184 to 0.085) while the separation between adjacent and non-adjacent
#' pairs fell by two per cent; blending the *input* networks instead, or
#' anchoring harder, cost far more structure for less smoothness.
#' @param positions List of coordinate data frames, one per bin.
#' @return A list of the same shape.
#' @noRd
.smooth_positions <- function(positions) {
  n <- length(positions)
  if (n < 3L) return(positions)
  held <- function(k) positions[[min(max(k, 1L), n)]]
  lapply(seq_len(n), function(k) {
    (held(k - 1L) + 2 * positions[[k]] + held(k + 1L)) / 4
  })
}

#' Fold a spring layout forward through the frames
#' @param frames List of frame netobjects.
#' @param max_displacement,anchor_strength Passed to
#'   `cograph::layout_spring()`.
#' @param layout_args Further arguments for `cograph::layout_spring()`.
#' @return A list of coordinate data frames, one per frame, smoothed by
#'   `.smooth_positions()`.
#' @noRd
.relaxed_layouts <- function(frames, max_displacement, anchor_strength,
                             layout_args = list()) {
  positions <- vector("list", length(frames))
  previous <- NULL
  # A fold, not a map: each frame's layout is seeded with the one before it,
  # which is the whole point of a relaxed layout, so this cannot be vectorised.
  for (k in seq_along(frames)) {
    previous <- as.data.frame(do.call(cograph::layout_spring, c(
      list(frames[[k]], initial = previous,
           max_displacement = if (is.null(previous)) NULL else max_displacement,
           anchor_strength = if (is.null(previous)) 0 else anchor_strength),
      layout_args
    )))
    positions[[k]] <- previous
  }
  .smooth_positions(positions)
}

#' Positions for every frame of an animation
#'
#' Every named layout but `"relaxed"` is computed once and reused, so a vertex
#' never moves and the frames can be read against one another. `"spring"`
#' lays out the union of every frame, so the picture shows the structure of
#' the whole period; `"circle"` and `"oval"` are rings; `"groups"` places
#' each partition on its own ring. `"relaxed"` re-runs
#' `cograph::layout_spring()` per frame, seeded with the previous frame's
#' coordinates and constrained by `max_displacement` and `anchor_strength`,
#' then smooths the trajectories, so the structure of each moment shows
#' through while vertices drift rather than jump. Every frame is laid out
#' over the whole vertex set, not the vertices active in it, or a vertex
#' would change place whenever its neighbours came and went.
#' @param x A `dynet` object.
#' @param frames List of frame netobjects, each holding every vertex.
#' @param layout One of `.animation_layouts_named`, or a coordinate table.
#' @param max_displacement,anchor_strength Passed to
#'   `cograph::layout_spring()` for `"relaxed"`; ignored otherwise.
#' @param seed Seed for the spring layouts, or `NULL` for the current state.
#' @param layout_args Further arguments for `cograph::layout_spring()`, used
#'   by `"spring"` and `"relaxed"`.
#' @return A list of coordinate data frames, one per frame, each with one row
#'   per vertex of `x` in `x$nodes` order.
#' @noRd
.animation_layouts <- function(x, frames, layout, max_displacement,
                               anchor_strength, seed, layout_args = list()) {
  n_frames <- length(frames)
  if (is.data.frame(layout)) {
    return(rep(list(.custom_layout(x, layout)), n_frames))
  }
  if (identical(layout, "relaxed")) {
    return(.with_seed(seed, .relaxed_layouts(frames, max_displacement,
                                             anchor_strength, layout_args)))
  }
  fixed <- switch(layout,
    spring = .with_seed(seed, as.data.frame(do.call(
      cograph::layout_spring,
      c(list(.union_netobject(frames)), layout_args)))),
    circle = as.data.frame(cograph::layout_circle(x)),
    oval = as.data.frame(cograph::layout_oval(x)),
    groups = .group_layout(x)
  )
  rep(list(fixed), n_frames)
}

#' Which vertices are present in each bin
#' @param x A `dynet` object.
#' @param enc Encoded network.
#' @param bins Grid rows to describe.
#' @param window Window width.
#' @param sessions Session treatment.
#' @return A logical matrix, one row per bin and one column per vertex of `x`.
#' @noRd
.frame_presence <- function(x, enc, bins, window, sessions) {
  eligible <- lapply(seq_len(nrow(bins)), function(k) {
    .snapshot_state(x, enc, bins[k, , drop = FALSE], window, sessions,
      "all")$eligible
  })
  matrix(unlist(eligible), nrow = nrow(bins), byrow = TRUE)
}

#' Rows of a node-level measure table placed on the animation's bins
#' @param tbl A data frame with `time`, `node` and `value`.
#' @param dn A `dynet` object.
#' @param bins The drawable bins.
#' @return A numeric matrix, one row per bin and one column per vertex, `NA`
#'   where no row lands. Raises `dynet_bad_input` when no time point of the
#'   table falls on a bin, and warns with class `dynet_partial_measure` when
#'   some bins receive no row.
#' @noRd
.place_measure_rows <- function(tbl, dn, bins) {
  row <- vapply(tbl$time, function(t) {
    hit <- which(abs(bins$time - t) <= .time_tol(t, bins$time))
    if (length(hit)) hit[[1L]] else NA_integer_
  }, integer(1L))
  col <- match(tbl$node, dn$nodes$name)
  keep <- !is.na(row) & !is.na(col)
  if (!any(keep)) {
    stop(errorCondition(
      "No time point of `measure` falls on a bin of the animation's grid; compute it with the same `start`, `end`, `step` and `window`, or with `window = \"all\"` for one value per vertex.",
      class = "dynet_bad_input", call = NULL))
  }
  unmatched <- setdiff(seq_len(nrow(bins)), row[keep])
  if (length(unmatched)) {
    warning(warningCondition(
      sprintf("%d of %d bins have no value in `measure`; their vertices take the smallest size.",
              length(unmatched), nrow(bins)),
      class = "dynet_partial_measure", call = NULL))
  }
  out <- matrix(NA_real_, nrow(bins), nrow(dn$nodes))
  out[cbind(row[keep], col[keep])] <- tbl$value[keep]
  out
}

#' One value per vertex, repeated over every bin
#' @param value Numeric vector in `dn$nodes` order.
#' @param n_bins Number of bins.
#' @return A numeric matrix, one row per bin.
#' @noRd
.constant_measure <- function(value, n_bins) {
  matrix(as.numeric(value), n_bins, length(value), byrow = TRUE)
}

#' The node measure an animation sizes vertices by, as a bins-by-vertices matrix
#'
#' Three forms of `measure` are accepted. A measure name that
#' [dyn_centrality()] offers is computed on the animation's own grid. A
#' node-level `dynet_metric` is matched by vertex, and by time when it holds
#' more than one time point; one computed with `window = "all"` therefore
#' gives every vertex one value for the whole animation. The name of a
#' numeric vertex attribute gives every vertex the attribute's value.
#' @param dn A `dynet` object.
#' @param measure A measure name, a `dynet_metric`, or an attribute name.
#' @param bins The drawable bins of the grid.
#' @param sessions,start,end,step,window As given to [animate()].
#' @return A list with `values`, a numeric matrix with one row per bin and
#'   one column per vertex (`NA` where undefined), and `label`, the text the
#'   key names the measure by. Raises `dynet_unknown_measure` for a name that
#'   is neither a measure nor a numeric vertex attribute, and
#'   `dynet_bad_input` for a `dynet_metric` that is not node-level, holds
#'   several values for one vertex and time, or lands on none of the bins.
#' @noRd
.animation_measure <- function(dn, measure, bins, sessions, start, end, step,
                               window) {
  n_bins <- nrow(bins)
  if (inherits(measure, "dynet_metric")) {
    tbl <- as.data.frame(measure)
    label <- attr(measure, "what") %||% "measure"
    if (!identical(attr(measure, "level"), "node") ||
        !all(c("node", "value") %in% names(tbl))) {
      stop(errorCondition(
        "`measure` must be a node-level result, one row per vertex and time.",
        class = "dynet_bad_input", call = NULL))
    }
    if (is.null(tbl$time)) tbl$time <- bins$time[[1L]]
    if (anyDuplicated(paste(tbl$node, format(tbl$time, digits = 15L)))) {
      stop(errorCondition(
        "`measure` holds several values for one vertex and time; compute it with `sessions = \"bounded\"` or `\"collapse\"`.",
        class = "dynet_bad_input", call = NULL))
    }
    if (length(unique(tbl$time)) == 1L) {
      col <- match(tbl$node, dn$nodes$name)
      value <- rep(NA_real_, nrow(dn$nodes))
      value[col[!is.na(col)]] <- tbl$value[!is.na(col)]
      return(list(values = .constant_measure(value, n_bins),
                  label = sprintf("%s over the whole period", label)))
    }
    return(list(values = .place_measure_rows(tbl, dn, bins), label = label))
  }
  if (measure %in% .node_measures) {
    values <- dyn_centrality(dn, measure = measure, sessions = sessions,
                             start = start, end = end, step = step,
                             window = window)
    return(list(values = .place_measure_rows(as.data.frame(values), dn, bins),
                label = measure))
  }
  if (measure %in% setdiff(names(dn$nodes), c("id", "label", "name", "x", "y"))) {
    value <- dn$nodes[[measure]]
    if (!is.numeric(value) || !any(is.finite(value))) {
      stop(errorCondition(
        sprintf("Vertex attribute %s must be numeric to size vertices by.",
                sQuote(measure)),
        class = c("dynet_unknown_measure", "dynet_bad_input"), call = NULL))
    }
    return(list(values = .constant_measure(value, n_bins), label = measure))
  }
  stop(errorCondition(
    sprintf("`measure = %s` is neither a measure dyn_centrality() offers nor a numeric vertex attribute.",
            sQuote(measure)),
    class = c("dynet_unknown_measure", "dynet_bad_input"), call = NULL))
}

#' The rendered-frame schedule for a grid
#'
#' Each bin gets `tween` frames. Frame `j` of bin `k` (counting from 0) sits
#' at phase `j / tween` of the transition from bin `k` to bin `k + 1`; the
#' last bin has no successor and is held. Positions and sizes ease along the
#' transition with the smoothstep curve, so a state dwells at each end
#' rather than starting to move the instant it appears.
#' @param bins The drawable bins.
#' @param tween Frames per bin.
#' @param ease `"dwell"` for the smoothstep curve, `"continuous"` for a
#'   linear one.
#' @return A data frame with one row per rendered frame: `frame`, `bin`,
#'   `next_bin`, `phase` (linear, in `[0, 1)`), `eased` (`phase` through the
#'   easing curve) and `time` (the timeline marker, linear in phase).
#' @noRd
.frame_schedule <- function(bins, tween, ease = c("dwell", "continuous")) {
  ease <- match.arg(ease)
  n_bins <- nrow(bins)
  bin <- rep(seq_len(n_bins), each = tween)
  phase <- rep(seq_len(tween) - 1L, times = n_bins) / tween
  next_bin <- pmin(bin + 1L, n_bins)
  phase[bin == n_bins] <- 0
  data.frame(
    frame = seq_along(bin),
    bin = bin,
    next_bin = next_bin,
    phase = phase,
    eased = if (identical(ease, "dwell")) phase^2 * (3 - 2 * phase) else phase,
    time = bins$time[bin] + phase * (bins$time[next_bin] - bins$time[bin])
  )
}

#' The ties drawn during the transition between two bins
#'
#' The union of both bins' ties. A tie in both is `persisting`; one only in
#' the later bin is `forming`; one only in the earlier bin is `dissolving`.
#' @param before,after Weight matrices of the two bins.
#' @param directed Whether the network is directed.
#' @return A data frame in the order `.matrix_edges()` defines, with `from`,
#'   `to`, `before`, `after` (the weights, 0 when absent) and `state`.
#' @noRd
.transition_edges <- function(before, after, directed) {
  edges <- .matrix_edges(pmax(before, after), directed)
  cell <- cbind(edges$from, edges$to)
  edges$before <- as.numeric(before[cell])
  edges$after <- as.numeric(after[cell])
  edges$state <- ifelse(
    edges$before > 0 & edges$after > 0, "persisting",
    ifelse(edges$after > 0, "forming", "dissolving")
  )
  edges$weight <- NULL
  edges
}

#' A weight matrix holding given values at given cells
#' @param edges A data frame with `from` and `to`.
#' @param value Values, one per row of `edges`, all positive.
#' @param n Number of vertices.
#' @param directed Whether to mirror each cell.
#' @return An `n` by `n` numeric matrix.
#' @noRd
.transition_matrix <- function(edges, value, n, directed) {
  w <- matrix(0, n, n)
  w[cbind(edges$from, edges$to)] <- value
  if (!directed) w[cbind(edges$to, edges$from)] <- value
  w
}

#' A point on the Catmull-Rom spline through four consecutive bin positions
#'
#' The curve passes through `p1` at `f = 0` and `p2` at `f = 1`, with the
#' velocity at each end set by the neighbouring bins, so a vertex moving
#' through several bins follows one continuous path rather than a chain of
#' straight runs that stop at every bin.
#' @param p0,p1,p2,p3 Coordinate data frames of four consecutive bins; the
#'   ends of the sequence repeat their last bin.
#' @param f Position along the segment from `p1` to `p2`, in `[0, 1]`.
#' @return A coordinate data frame.
#' @references Catmull, E. and Rom, R. (1974). A class of local
#'   interpolating splines. In *Computer Aided Geometric Design*, 317-326.
#' @noRd
.catmull_rom <- function(p0, p1, p2, p3, f) {
  0.5 * (2 * p1 +
           (p2 - p0) * f +
           (2 * p0 - 5 * p1 + 4 * p2 - p3) * f^2 +
           (3 * p1 - p0 - 3 * p2 + p3) * f^3)
}

#' Hold every inactive vertex within the frame of the active ones
#'
#' In a relaxed layout a vertex with no tie in the bin has nothing to hold
#' it, so repulsion pushes it outward, and because the picture is scaled to
#' the outermost vertex the connected part shrinks. On the 449-author
#' co-authorship film 40 to 100 per cent of the ten outermost vertices per
#' bin were absent or idle, and the box they set was 1.2 to 1.75 times the
#' box of the rest. The frame is therefore the bounding box of the active
#' vertices, and every other vertex is held at its border.
#' @param pos A coordinate data frame with `x` and `y`.
#' @param active Logical, one per row: present and with a tie in the bin.
#' @return `pos` with inactive rows clamped into the active box. Unchanged
#'   when no vertex is active.
#' @noRd
.frame_to_active <- function(pos, active) {
  if (!any(active)) return(pos)
  pos$x <- pmin(pmax(pos$x, min(pos$x[active])), max(pos$x[active]))
  pos$y <- pmin(pmax(pos$y, min(pos$y[active])), max(pos$y[active]))
  pos
}

#' Where an absent vertex waits: the edge of the layout, in its own direction
#'
#' Each vertex is pushed from the centre of the layout's bounding box along
#' the ray through its own position until it meets the box, so it arrives
#' from, and leaves towards, the side it sits on. The box is the layout's
#' own, so parked vertices never widen it and the picture keeps its scale.
#' @param pos A coordinate data frame with `x` and `y`.
#' @return A data frame of the same shape.
#' @noRd
.park_positions <- function(pos) {
  lo <- c(min(pos$x), min(pos$y))
  hi <- c(max(pos$x), max(pos$y))
  centre <- (lo + hi) / 2
  dx <- pos$x - centre[[1L]]
  dy <- pos$y - centre[[2L]]
  at_centre <- abs(dx) < 1e-12 & abs(dy) < 1e-12
  dx[at_centre] <- 1
  dy[at_centre] <- 0
  reach <- function(d, low, high, mid) {
    ifelse(abs(d) < 1e-12, Inf, (ifelse(d > 0, high, low) - mid) / d)
  }
  t <- pmin(reach(dx, lo[[1L]], hi[[1L]], centre[[1L]]),
            reach(dy, lo[[2L]], hi[[2L]], centre[[2L]]))
  t[!is.finite(t)] <- 0
  data.frame(x = centre[[1L]] + t * dx, y = centre[[2L]] + t * dy)
}

#' Map values onto an output range with one fixed scale
#' @param v Values.
#' @param from The input range, a length-two vector.
#' @param to The output range, a length-two vector.
#' @return Numbers in `to`; the midpoint of `to` when `from` is degenerate.
#' @noRd
.scale_to <- function(v, from, to) {
  span <- from[[2L]] - from[[1L]]
  if (!is.finite(span) || span <= 0) return(rep(mean(to), length(v)))
  to[[1L]] + (v - from[[1L]]) / span * (to[[2L]] - to[[1L]])
}

#' Map a measure onto node radii so that area follows the measure
#'
#' A circle's size is read by area, so the radius follows the square root of
#' the value's position in its range. With a linear radius, most vertices of
#' a skewed measure sit at the bottom of the scale: on a 449-author
#' co-authorship network, 77 per cent of author-years were drawn within 15
#' per cent of the smallest radius; with the square root, 23 per cent.
#' @param v Values, `NA` already replaced.
#' @param from The value range.
#' @param to The radius range.
#' @return Radii in `to`; the midpoint of `to` when `from` is degenerate.
#' @noRd
.size_scale <- function(v, from, to) {
  span <- from[[2L]] - from[[1L]]
  if (!is.finite(span) || span <= 0) return(rep(mean(to), length(v)))
  to[[1L]] + sqrt(pmin(1, pmax(0, (v - from[[1L]]) / span))) * (to[[2L]] - to[[1L]])
}

#' Colours with an alpha channel applied per element
#' @param colours Character vector R can parse as colours.
#' @param alpha Numeric in `[0, 1]`, recycled against `colours`.
#' @return A character vector of `#RRGGBBAA` colours.
#' @noRd
.with_alpha <- function(colours, alpha) {
  rgb <- t(grDevices::col2rgb(colours))
  alpha <- rep_len(alpha, nrow(rgb))
  grDevices::rgb(rgb[, 1L], rgb[, 2L], rgb[, 3L],
    alpha = pmin(1, pmax(0, alpha)) * 255, maxColorValue = 255)
}

#' Which encoder a file path asks for
#' @param file The output path.
#' @return The extension, lower case. Raises `dynet_unknown_format` for an
#'   extension the verb cannot write, and `dynet_needs_gifski` or
#'   `dynet_needs_av` when the encoder that extension needs is not installed.
#' @noRd
.animation_format <- function(file) {
  ext <- tolower(tools::file_ext(file))
  if (!ext %in% names(.animation_formats)) {
    stop(errorCondition(
      sprintf("`file` must end in %s; %s does not.",
        paste0(".", names(.animation_formats), collapse = ", "),
        sQuote(basename(file))),
      class = c("dynet_unknown_format", "dynet_bad_input"), call = NULL))
  }
  encoder <- .animation_formats[[ext]]
  if (!requireNamespace(encoder, quietly = TRUE)) {
    stop(errorCondition(
      sprintf("Writing a .%s file needs the %s package.", ext, encoder),
      class = c(paste0("dynet_needs_", encoder), "dynet_bad_input"),
      call = NULL))
  }
  ext
}

#' Encode rendered frames into the output file
#' @param png_files Frame paths, in order.
#' @param file Output path.
#' @param format Extension from `.animation_format()`.
#' @param fps,loop,width,height As given to [animate()].
#' @return `file`, invisibly.
#' @noRd
.encode_animation <- function(png_files, file, format, fps, loop, width,
                              height) {
  if (identical(format, "gif")) {
    gifski::gifski(png_files, gif_file = file, width = width, height = height,
      delay = 1 / fps, loop = loop, progress = FALSE)
  } else {
    av::av_encode_video(png_files, output = file, framerate = fps,
      verbose = FALSE)
  }
  invisible(file)
}

#' Draw one frame into a file
#' @param path PNG path.
#' @param width,height,res Device size.
#' @param draw A function of no arguments that draws.
#' @return `path`, invisibly.
#' @noRd
.write_frame <- function(path, width, height, res, draw) {
  grDevices::png(path, width = width, height = height, res = res)
  on.exit(grDevices::dev.off(), add = TRUE)
  draw()
  invisible(path)
}

#' The timeline strip under a frame
#'
#' A track spanning the grid with each bin's start as a tick, filled up to
#' the current time, with a marker at it; the axis is labelled in the
#' network's time unit. Above the track, left, what node size follows and
#' that a faded vertex is absent; below it, the line type and colour of each
#' tie state.
#' @param span The grid's time range.
#' @param ticks Bin starts.
#' @param now The current time.
#' @param unit The time unit, or `NULL`.
#' @param key Character vector of key entries beyond the tie states, may be
#'   empty.
#' @param tie_states Whether the tie-state key is drawn.
#' @return `NULL`, invisibly.
#' @noRd
.draw_timeline <- function(span, ticks, now, unit, key, tie_states) {
  old <- graphics::par(mar = c(0.2, 1.2, 0.2, 1.2), xpd = NA)
  on.exit(graphics::par(old), add = TRUE, after = FALSE)
  graphics::plot(NA, xlim = span, ylim = c(0, 1), axes = FALSE, ann = FALSE,
    xaxs = "i", yaxs = "i")
  graphics::rect(span[[1L]], 0.62, span[[2L]], 0.86, col = "#E4E4E4",
    border = NA)
  graphics::rect(span[[1L]], 0.62, now, 0.86, col = "#0072B2", border = NA)
  graphics::segments(ticks, 0.62, ticks, 0.86, col = "#FFFFFF", lwd = 1)
  graphics::segments(now, 0.55, now, 0.93, col = "#000000", lwd = 1.5)
  graphics::points(now, 0.74, pch = 21, bg = "#000000", col = "#FFFFFF",
    cex = 1.3)
  at <- pretty(span, n = 6)
  at <- at[at >= span[[1L]] & at <= span[[2L]]]
  graphics::text(at, 0.47, labels = format(at), cex = 0.65, adj = c(0.5, 1))
  if (!is.null(unit)) {
    graphics::text(span[[2L]], 0.95, labels = unit, cex = 0.65,
      adj = c(1, 0), col = "#333333")
  }
  if (length(key)) {
    graphics::text(span[[1L]], 0.95, labels = paste(key, collapse = "   "),
      cex = 0.65, adj = c(0, 0), col = "#333333")
  }
  if (tie_states) {
    graphics::legend(
      x = mean(span), y = 0.3, xjust = 0.5, yjust = 1, horiz = TRUE,
      legend = names(.tie_state_styles), bty = "n", cex = 0.65,
      seg.len = 2.2, lwd = 2, lty = c(3, 1, 2),
      col = unname(.tie_state_colours), text.col = "#333333"
    )
  }
  invisible(NULL)
}

#' Animate a temporal network over its measurement grid
#'
#' Draws the network bin by bin over the measurement grid and writes the
#' frames to an animated GIF or a video. The grid is the same four arguments
#' every measuring verb takes, so an animation shows exactly what
#' [snapshots()] tabulates and what `plot(dn, type = "snapshots")` draws as a
#' filmstrip, with the bins joined by motion.
#'
#' @details
#' **Frames.** Each bin is drawn `tween` times. Between one bin and the next
#' the vertices glide to their new positions, a tie that is about to appear
#' fades in and one that is about to vanish fades out, and a vertex whose
#' measure changes grows or shrinks. Under `ease = "dwell"`, the default,
#' the motion follows the smoothstep curve, so each bin holds still before
#' it starts to change and the bins can be read one by one. Under
#' `ease = "continuous"` nothing holds still: positions follow a Catmull-Rom
#' spline through the bins, so a vertex moving across several bins traces
#' one smooth path, and fades are linear. `tween = 1` gives one frame per
#' bin with hard cuts. A film that feels episodic usually has a grid whose
#' bins do not overlap; a sliding window, `step` smaller than `window`,
#' smooths the data itself, since a tie then persists across several bins.
#'
#' **Layouts.** Under every layout but `"relaxed"` a vertex keeps one position
#' for the whole animation, so the only thing that moves is the ties; those
#' are the layouts to read structure from. `"spring"`, the default, lays out
#' the union of every frame once with `cograph::layout_spring()`, so pairs
#' that met often sit close. `"circle"` and `"oval"` are rings, in vertex
#' order. `"groups"` puts each partition on its own ring and needs a network
#' built with `groups = `. `"relaxed"` lays each frame out again, seeded from
#' the previous one and held near it by `max_displacement` and
#' `anchor_strength`, then smooths every vertex's path with a centred
#' triangular kernel over one bin each side; clusters can form and dissolve
#' without vertices jumping, and no vertex moves further than
#' `max_displacement` between consecutive bins. Each relaxed frame is framed
#' by its active vertices: a vertex that is absent or has no tie in the bin
#' is held at the border of that frame rather than drifting outward under
#' repulsion, which would shrink the picture. `layout_args` tunes the spring
#' layout for both. A data frame with columns `name` (or `node`), `x` and
#' `y` fixes the positions yourself.
#'
#' **What is drawn.** Tie width follows weight on one scale fixed across the
#' whole animation, so a tie of the same weight has the same width in a quiet
#' frame and a busy one. With `tie_states = TRUE` a tie forming during a
#' transition is dotted and green, one persisting is solid and grey, and one
#' dissolving is dashed and vermilion, so the distinction survives without
#' colour. With `measure` given, node size follows that measure, again on
#' one scale across every frame, with the area of the circle proportional to
#' the measure's position in its range; see the argument for the three forms
#' it takes.
#'
#' **Absence and idleness.** A vertex that is not present in a bin, under
#' declared vertex activity or observation bounds, is drawn as `absent`
#' says: faded in place, parked out of sight at the edge of the layout and
#' gliding in when it arrives and out when it leaves, or hidden in place. A
#' network built without vertex activity has every vertex present in every
#' bin; `set_vertex_spells(dn, "ties")` declares each vertex present from
#' its first tie to its last. A vertex that is present but has no tie in a
#' bin is drawn as `isolates` says. With `timeline = TRUE` a strip under the
#' network shows the grid with a marker at the current time and the key to
#' the drawing.
#'
#' **Files.** The extension of `file` chooses the encoder: `.gif` is written
#' by the gifski package, `.mp4` and `.webm` by the av package. A video needs
#' even pixel dimensions. Writing the file is the point of the verb, but the
#' tidy bin table is still what comes back, so the animation can be described
#' without opening it.
#'
#' @param dn A temporal network from [dynet()].
#' @param start,end,step,window The measurement grid, as in [snapshots()].
#'   `NULL`, the default, takes each from the network's own observation
#'   window and bin width.
#' @param sessions How to treat sessions, as in [dyn_centrality()]: `"bounded"`
#'   (the default) or `"collapse"`. An animation draws calendar bins, so
#'   `"separate"` is not offered.
#' @param layout `"spring"` (the default), `"relaxed"`, `"circle"`, `"oval"`
#'   or `"groups"`, or a data frame of coordinates. See details.
#' @param measure What node size follows. `NULL`, the default, keeps every
#'   vertex the same size. The name of a snapshot node measure from
#'   [dyn_centrality()], such as `"degree"` or `"betweenness"`, computes it on
#'   the animation's own grid, so a vertex grows and shrinks bin by bin. A
#'   node-level result of [dyn_centrality()] is matched by vertex and time;
#'   one computed with `window = "all"` holds a single value per vertex, so
#'   every vertex keeps one size for the whole film, for instance its degree
#'   over the whole period. The name of a numeric vertex attribute supplied
#'   through `dynet(nodes = )` does the same with the attribute's values,
#'   which is how a two-tier size (a circle of interest against everyone
#'   else) is drawn.
#' @param tween Frames drawn per bin. One positive whole number, `6` by
#'   default.
#' @param fps Frames per second. One positive number, `12` by default.
#' @param file Path to write to, ending in `.gif`, `.mp4` or `.webm`. Defaults
#'   to a GIF in the session's temporary directory; nothing is written to the
#'   working directory unless the path says so.
#' @param loop For a GIF: `TRUE`, the default, repeats for ever; `FALSE` plays
#'   once; a positive whole number repeats that many times. Ignored for a
#'   video.
#' @param width,height Frame size in pixels, `800` by default. A video needs
#'   both to be even.
#' @param res Resolution passed to [grDevices::png()], `120` by default.
#' @param palette Palette specification, as in [plot.dynet()]. `"okabe"` by
#'   default.
#' @param tie_states Whether to draw forming, persisting and dissolving ties
#'   differently. `TRUE` by default.
#' @param timeline Whether to draw the timeline strip. `TRUE` by default.
#' @param absent How a vertex is drawn in a bin where it is not present.
#'   `"fade"`, the default, keeps it in place at a quarter of its opacity;
#'   `"away"` parks it, invisible, at the edge of the layout on its own side
#'   and glides it in over the transition in which it arrives and out over
#'   the one in which it leaves, opaque for most of the glide and, with
#'   `tie_states = TRUE`, wearing a thick ring in the forming colour on the
#'   way in and the dissolving colour on the way out; `"hide"` keeps it in
#'   place, invisible.
#' @param isolates How a vertex that is present but has no tie in a bin is
#'   drawn. `"fade"`, the default, at a third of its opacity; `"show"` at
#'   full opacity; `"hide"` invisible.
#' @param ease `"dwell"`, the default, holds each bin still before it
#'   changes; `"continuous"` keeps everything moving, with positions on a
#'   spline through the bins and linear fades. See details.
#' @param max_displacement How far a vertex may move between bins under
#'   `layout = "relaxed"`, in layout units. `0.08` by default; ignored
#'   otherwise.
#' @param anchor_strength How strongly a vertex is pulled back towards its
#'   previous position under `layout = "relaxed"`. `1` by default; ignored
#'   otherwise.
#' @param layout_args A named list of further arguments for
#'   `cograph::layout_spring()`, used by `layout = "spring"` and
#'   `"relaxed"`: `repulsion`, `attraction`, `area`, `gravity`, `iterations`
#'   or `cooling`. Empty by default. A larger `repulsion` opens a dense
#'   core.
#' @param seed Seed for the spring layouts, so `"spring"` and `"relaxed"` are
#'   reproducible; `42` by default. Under a seed the caller's random state is
#'   restored on exit. `NULL` draws from the current random state instead and
#'   leaves it advanced, which is what makes successive unseeded calls differ.
#' @param ... Passed to `cograph::splot()` for every frame, so the whole
#'   drawing surface of [plot.dynet()]'s network view is available. `labels`
#'   may also be the name of a vertex attribute supplied through
#'   `dynet(nodes = )`, such as a short form of each name, which is then
#'   drawn in place of the vertex names; `label` itself is reserved by the
#'   node table, so give the attribute another name. Seven arguments are read
#'   as the animation's baselines rather than passed on:
#'   `edge_width_range` (the widths the weight scale maps onto,
#'   `c(0.5, 3.5)` by default), `edge_alpha` (`0.6`), `edge_color` (the
#'   colour of a tie when `tie_states = FALSE`), `node_size` (the size a
#'   vertex has without a measure) and `node_size_range` (the smallest and
#'   largest radius a measure maps onto; by default 0.55 and 1.8 times
#'   `node_size`), `node_alpha` (`1`) and `node_border_color` (`"white"`),
#'   the last two being what `absent` and `isolates` fade from.
#'
#' @return An object of class `"dynet_animation"`: a tidy data frame with one
#'   row per bin and columns `bin`, `frame` (the first rendered frame of the
#'   bin), `time` (the bin's label on the network's time scale),
#'   `window_start` and `window_end` (its bounds), `nodes` (vertices present),
#'   `idle` (of those, vertices with no tie), `ties` (ties drawn), `forming` (ties not active in the previous bin, `NA`
#'   for the first), `dissolving` (ties not active in the next bin, `NA` for
#'   the last), and `file` (the same on every row). These are counts of what
#'   the picture shows, not the risk-set accounting of [events()]. The
#'   rendered-frame schedule is available through
#'   `as.data.frame(x, what = "frames")`. Returned invisibly, since writing
#'   the file is the verb's purpose.
#'
#' @section Conditions:
#' Raises `dynet_unknown_format` for a `file` extension other than `.gif`,
#' `.mp4` or `.webm`; `dynet_needs_gifski` or `dynet_needs_av` when the
#' encoder that extension needs is not installed; `dynet_needs_cograph` when
#' cograph is not; `dynet_empty_result` when the grid holds no bin that can be
#' drawn; `dynet_unknown_attribute` for `layout = "groups"` on a network
#' without a partition or a `labels` naming no vertex attribute;
#' `dynet_missing_column` and `dynet_unknown_node` for a
#' coordinate table that is incomplete; `dynet_unknown_measure` for a
#' `measure` that is neither a measure [dyn_centrality()] offers nor a
#' numeric vertex attribute, and whatever [dyn_centrality()] raises for one it
#' refuses; `dynet_bad_input` for a [dyn_centrality()] result that is not
#' node-level or lands on none of the bins, and a warning of class
#' `dynet_partial_measure` when it lands on only some; and `dynet_bad_input` for a non-positive
#' `fps`, `tween`, `width`, `height` or `res`, an odd video size, a `loop`
#' that is neither logical nor a positive whole number, or a negative
#' `max_displacement` or `anchor_strength`.
#'
#' @seealso [snapshots()] for the same grid as a table, [plot.dynet()] with
#'   `type = "snapshots"` for it as a static filmstrip, and [dyn_centrality()]
#'   for the measures node size can follow.
#'
#' @examples
#' if (requireNamespace("gifski", quietly = TRUE) &&
#'   requireNamespace("cograph", quietly = TRUE)) {
#'   dn <- dynet(school_contacts)
#'   frames <- animate(dn, step = 4, window = 4, tween = 2)
#'   frames
#'   summary(frames)
#' }
#' \donttest{
#' if (requireNamespace("av", quietly = TRUE) &&
#'   requireNamespace("cograph", quietly = TRUE)) {
#'   dn <- dynet(school_contacts)
#'   video <- animate(dn, step = 2, window = 4, measure = "degree",
#'     layout = "relaxed",
#'     file = tempfile(fileext = ".mp4"))
#'   summary(video)
#' }
#' }
#' @export
animate <- function(dn, start = NULL, end = NULL, step = NULL,
                    window = NULL,
                    sessions = c("bounded", "collapse"),
                    layout = "spring", measure = NULL,
                    tween = 6L, fps = 12,
                    file = tempfile(fileext = ".gif"),
                    loop = TRUE, width = 800L, height = 800L, res = 120,
                    palette = "okabe", tie_states = TRUE, timeline = TRUE,
                    absent = c("fade", "away", "hide"),
                    isolates = c("fade", "show", "hide"),
                    ease = c("dwell", "continuous"),
                    max_displacement = 0.08, anchor_strength = 1,
                    layout_args = list(), seed = 42L, ...) {
  sessions <- match.arg(sessions)
  absent <- match.arg(absent)
  isolates <- match.arg(isolates)
  ease <- match.arg(ease)
  .check_dynet(dn, sessions)
  .need_cograph()
  if (!is.data.frame(layout)) {
    layout <- match.arg(layout, .animation_layouts_named)
  }
  positive_scalar <- function(value) {
    is.numeric(value) && length(value) == 1L && is.finite(value) && value > 0
  }
  whole <- function(value) {
    positive_scalar(value) && isTRUE(all.equal(value, round(value)))
  }
  flag <- function(value) isTRUE(value) || isFALSE(value)
  .check(
    "`file` must be one non-missing file path." =
      is.character(file) && length(file) == 1L && !is.na(file) && nzchar(file),
    "`measure` must be NULL, one name, or a dyn_centrality() result." =
      is.null(measure) || inherits(measure, "dynet_metric") ||
        (is.character(measure) && length(measure) == 1L && !is.na(measure)),
    "`tween` must be one positive whole number." = whole(tween),
    "`fps` must be one positive number." = positive_scalar(fps),
    "`loop` must be TRUE, FALSE or one positive whole number." =
      flag(loop) || whole(loop),
    "`width` must be one positive whole number." = whole(width),
    "`height` must be one positive whole number." = whole(height),
    "`res` must be one positive number." = positive_scalar(res),
    "`tie_states` must be TRUE or FALSE." = flag(tie_states),
    "`timeline` must be TRUE or FALSE." = flag(timeline),
    "`max_displacement` must be one non-negative number." =
      is.numeric(max_displacement) && length(max_displacement) == 1L &&
        is.finite(max_displacement) && max_displacement >= 0,
    "`anchor_strength` must be one non-negative number." =
      is.numeric(anchor_strength) && length(anchor_strength) == 1L &&
        is.finite(anchor_strength) && anchor_strength >= 0,
    "`layout_args` must be a list of named arguments." =
      is.list(layout_args) && (!length(layout_args) ||
                                 !is.null(names(layout_args))),
    "`seed` must be NULL or one number." =
      is.null(seed) || (is.numeric(seed) && length(seed) == 1L &&
        is.finite(seed))
  )
  format <- .animation_format(file)
  tween <- as.integer(tween)
  width <- as.integer(width)
  height <- as.integer(height)
  if (!identical(format, "gif") && (width %% 2L != 0L || height %% 2L != 0L)) {
    stop(errorCondition(
      sprintf("A .%s video needs even `width` and `height`; %d by %d is not.",
        format, width, height),
      class = "dynet_bad_input", call = NULL))
  }

  spec <- .window_spec(dn, start, end, step, window)
  enc <- .encode(dn)
  grid <- .grid_for(enc, dn, spec)
  if (nrow(grid) == 0L) {
    stop(errorCondition(
      "The measurement grid holds no bin, so there is nothing to animate.",
      class = "dynet_empty_result", call = NULL
    ))
  }

  # A bin with neither an active spell nor an eligible vertex cannot be drawn.
  # Skipping it silently would make the animation lie about its own timeline,
  # so the skipped bins are counted and reported.
  built <- lapply(seq_len(nrow(grid)), function(k) {
    tryCatch(
      .frame_netobject(dn, enc, grid[k, , drop = FALSE], spec$window,
        all_vertices = TRUE, label = format(grid$time[k]),
        sessions = sessions),
      dynet_empty_result = function(e) NULL
    )
  })
  drawable <- !vapply(built, is.null, logical(1L))
  if (!any(drawable)) {
    stop(errorCondition(
      "No bin of the measurement grid holds a vertex to draw.",
      class = "dynet_empty_result", call = NULL
    ))
  }
  if (any(!drawable)) {
    message(sprintf(
      "Skipping %d of %d bins that hold no vertex to draw.",
      sum(!drawable), length(drawable)
    ))
  }
  frames <- built[drawable]
  bins <- grid[drawable, , drop = FALSE]
  n_bins <- length(frames)
  n_vertices <- nrow(dn$nodes)
  directed <- isTRUE(dn$directed)

  present <- .frame_presence(dn, enc, bins, spec$window, sessions)
  connected <- matrix(unlist(lapply(frames, function(net) {
    tabulate(c(net$edges$from, net$edges$to), n_vertices) > 0L
  })), nrow = n_bins, byrow = TRUE)
  idle <- present & !connected
  positions <- .animation_layouts(dn, frames, layout, max_displacement,
                                  anchor_strength, seed, layout_args)
  if (identical(layout, "relaxed")) {
    positions <- lapply(seq_len(n_bins), function(k) {
      .frame_to_active(positions[[k]], present[k, ] & connected[k, ])
    })
  }
  parked <- if (identical(absent, "away")) lapply(positions, .park_positions)
  absent_floor <- switch(absent, fade = 0.25, away = 0, hide = 0)
  idle_floor <- switch(isolates, show = 1, fade = 0.35, hide = 0)
  measured <- if (is.null(measure)) NULL else {
    .animation_measure(dn, measure, bins, sessions, start, end, step, window)
  }
  values <- measured$values

  # One transition table per bin; the last bin transitions to itself.
  transitions <- lapply(seq_len(n_bins), function(k) {
    .transition_edges(frames[[k]]$weights,
      frames[[min(k + 1L, n_bins)]]$weights, directed)
  })
  weights_seen <- unlist(lapply(frames, function(net) net$edges$weight))
  weight_range <- if (length(weights_seen)) range(weights_seen) else c(0, 0)
  # `NA` is the value dyn_centrality() reports for a vertex absent from a
  # bin, so it is expected here and sits at the bottom of the size scale.
  value_range <- if (is.null(values) || all(is.na(values))) c(0, 0) else {
    range(values, na.rm = TRUE)
  }

  # Baselines read from `...`; everything else in `...` goes to splot().
  dots <- list(...)
  if (is.character(dots$labels) && length(dots$labels) == 1L) {
    if (!dots$labels %in% names(dn$nodes) || identical(dots$labels, "label")) {
      stop(errorCondition(
        sprintf("`labels = %s` names no vertex attribute. Supply it through `nodes = ` when building the network, under a name other than `label`.",
                sQuote(dots$labels)),
        class = c("dynet_unknown_attribute", "dynet_bad_input"), call = NULL))
    }
    dots$labels <- as.character(dn$nodes[[dots$labels]])
  }
  width_range <- dots$edge_width_range %||% c(0.5, 3.5)
  base_alpha <- dots$edge_alpha %||% 0.6
  base_colour <- dots$edge_color %||% .tie_state_colours[["persisting"]]
  base_node_alpha <- dots$node_alpha %||% 1
  base_border <- dots$node_border_color %||% "white"
  base_size <- dots$node_size %||% .node_size(n_vertices)
  size_range <- dots$node_size_range %||% (base_size * c(0.55, 1.8))
  .check(
    "`node_size_range` must be two increasing positive numbers." =
      is.numeric(size_range) && length(size_range) == 2L &&
        all(is.finite(size_range)) && size_range[[1L]] > 0 &&
        size_range[[2L]] > size_range[[1L]]
  )
  dots[c("edge_width_range", "edge_alpha", "edge_color", "node_size",
         "node_size_range", "node_alpha", "node_border_color")] <- NULL

  schedule <- .frame_schedule(bins, tween, ease)
  span <- c(min(bins$lo), max(bins$hi))
  key <- character()
  if (!is.null(measure)) {
    key <- c(key, sprintf("node size: %s (%s to %s)", measured$label,
      format(value_range[[1L]], digits = 3),
      format(value_range[[2L]], digits = 3)))
  }
  if (!all(present) && identical(absent, "fade")) {
    key <- c(key, "faded: absent")
  }
  if (any(idle) && identical(isolates, "fade")) key <- c(key, "pale: no tie")
  if (!all(present) && identical(absent, "away") && tie_states) {
    key <- c(key, "ring: arriving (green), leaving (vermilion)")
  }
  strip_share <- 0.16

  draw_frame <- function(i) {
    k <- schedule$bin[[i]]
    k2 <- schedule$next_bin[[i]]
    s <- schedule$eased[[i]]
    label_bin <- if (schedule$phase[[i]] < 0.5) k else k2

    # An absent vertex waits where `absent` says: in place, or parked at
    # the edge of the layout, from where it glides in when it arrives.
    where <- function(j) {
      j <- min(max(j, 1L), n_bins)
      here <- positions[[j]]
      if (is.null(parked)) return(here)
      gone <- !present[j, ]
      here[gone, ] <- parked[[j]][gone, , drop = FALSE]
      here
    }
    coords <- if (identical(ease, "continuous")) {
      .catmull_rom(where(k - 1L), where(k), where(k2), where(k2 + 1L), s)
    } else {
      where(k) * (1 - s) + where(k2) * s
    }
    edges <- transitions[[k]]
    persisting <- edges$state == "persisting"
    forming <- edges$state == "forming"
    weight <- ifelse(persisting, edges$before + s * (edges$after - edges$before),
      ifelse(forming, edges$after, edges$before))
    alpha <- base_alpha * ifelse(persisting, 1, ifelse(forming, s, 1 - s))
    colour <- if (tie_states) unname(.tie_state_colours[edges$state]) else {
      rep(base_colour, nrow(edges))
    }
    style <- if (tie_states) unname(.tie_state_styles[edges$state]) else {
      rep("solid", nrow(edges))
    }
    arriving <- !present[k, ] & present[k2, ]
    leaving <- present[k, ] & !present[k2, ]
    # A vertex that glides in must be seen while it moves, so under "away"
    # it becomes opaque over the first third of the transition and one that
    # glides out stays opaque until the last third. In place, the fade
    # follows the eased motion.
    presence <- if (identical(absent, "away")) {
      ifelse(arriving, pmin(1, s / 0.35),
             ifelse(leaving, 1 - pmax(0, (s - 0.65) / 0.35), present[k, ]))
    } else {
      present[k, ] * (1 - s) + present[k2, ] * s
    }
    idleness <- idle[k, ] * (1 - s) + idle[k2, ] * s
    visibility <- (absent_floor + (1 - absent_floor) * presence) *
      (1 - (1 - idle_floor) * idleness)
    size <- if (is.null(values)) rep(base_size, n_vertices) else {
      before <- values[k, ]
      after <- values[k2, ]
      before[is.na(before)] <- value_range[[1L]]
      after[is.na(after)] <- value_range[[1L]]
      .size_scale(before * (1 - s) + after * s, value_range, size_range)
    }

    # While it glides, a vertex wears a ring in the tie-state colours, so an
    # arrival reads like a forming tie and a departure like a dissolving one.
    moving <- identical(absent, "away") & (arriving | leaving)
    border_colour <- rep_len(base_border, n_vertices)
    if (tie_states) {
      border_colour[moving & arriving] <- .tie_state_colours[["forming"]]
      border_colour[moving & leaving] <- .tie_state_colours[["dissolving"]]
    }

    net <- frames[[k]]
    net$weights <- .transition_matrix(edges, weight, n_vertices, directed)
    net$edges <- data.frame(from = edges$from, to = edges$to, weight = weight)
    net <- cograph::set_layout(net, coords)
    args <- .splot_args(net, utils::modifyList(list(
      title = sprintf("t = %s", format(bins$time[[label_bin]], digits = 4L)),
      directed = directed,
      edge_width = .scale_to(weight, weight_range, width_range),
      edge_alpha = alpha,
      edge_color = colour,
      edge_style = style,
      node_size = size,
      node_alpha = base_node_alpha * visibility,
      node_border_color = .with_alpha(border_colour, visibility),
      node_border_width = ifelse(moving, 3, 1),
      # Weights are rounded to `weight_digits` before the edge set is derived
      # from the matrix; a coarse rounding could drop a small weight and
      # misalign every per-edge vector above.
      weight_digits = 8L
    ), dots), palette)
    if (is.null(dots$label_color)) {
      args$label_color <- .with_alpha(rep_len(args$label_color, n_vertices),
                                      visibility)
    }
    function() {
      if (timeline) {
        graphics::layout(matrix(1:2, ncol = 1L), heights = c(1, strip_share))
      }
      do.call(cograph::splot, c(list(net), args))
      if (timeline) {
        .draw_timeline(span, bins$lo, schedule$time[[i]], dn$meta$time_unit,
          key, tie_states)
      }
    }
  }

  scratch <- tempfile("dynet_frames_")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  png_files <- file.path(scratch, sprintf("frame_%05d.png", schedule$frame))
  if (nrow(schedule) > 120L) {
    message(sprintf("Rendering %d frames.", nrow(schedule)))
  }
  invisible(lapply(schedule$frame, function(i) {
    .write_frame(png_files[[i]], width, height, res, draw_frame(i))
  }))
  .encode_animation(png_files, file, format, fps, loop, width, height)

  counted <- function(state, k) sum(transitions[[k]]$state == state)
  forming <- c(NA_integer_, vapply(seq_len(n_bins)[-1L], function(k) {
    counted("forming", k - 1L)
  }, integer(1L)))
  dissolving <- vapply(seq_len(n_bins), function(k) {
    if (k == n_bins) NA_integer_ else counted("dissolving", k)
  }, integer(1L))

  out <- data.frame(
    bin = seq_len(n_bins),
    frame = as.integer((seq_len(n_bins) - 1L) * tween + 1L),
    time = bins$time,
    window_start = bins$lo,
    window_end = bins$hi,
    nodes = as.integer(rowSums(present)),
    idle = as.integer(rowSums(idle)),
    ties = vapply(frames, function(net) nrow(net$edges), integer(1L)),
    forming = forming,
    dissolving = dissolving,
    file = file,
    stringsAsFactors = FALSE
  )
  attr(out, "layout") <- if (is.data.frame(layout)) "custom" else layout
  attr(out, "fps") <- fps
  attr(out, "tween") <- tween
  attr(out, "ease") <- ease
  attr(out, "format") <- format
  attr(out, "measure") <- measured$label
  attr(out, "frames") <- schedule[c("frame", "bin", "phase", "time")]
  attr(out, "time_unit") <- dn$meta$time_unit
  class(out) <- c("dynet_animation", "data.frame")
  invisible(out)
}

#' Print an animation's bin table
#'
#' @param x A `dynet_animation` from [animate()].
#' @param n Largest number of bins to list, `12` by default.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @examples
#' if (requireNamespace("gifski", quietly = TRUE) &&
#'   requireNamespace("cograph", quietly = TRUE)) {
#'   dn <- dynet(school_contacts)
#'   frames <- animate(dn, step = 6, window = 6, tween = 2)
#'   print(frames, n = 3)
#' }
#' @export
print.dynet_animation <- function(x, n = 12L, ...) {
  unit <- attr(x, "time_unit")
  rendered <- nrow(attr(x, "frames"))
  cat(sprintf("# Animation of %d bin%s in %d frame%s at %g fps | %s layout | %s%s\n",
    nrow(x), if (nrow(x) == 1L) "" else "s",
    rendered, if (rendered == 1L) "" else "s",
    attr(x, "fps"), attr(x, "layout"), attr(x, "format"),
    if (is.null(unit)) "" else sprintf(" | time in %s", unit)))
  measure <- attr(x, "measure")
  if (!is.null(measure)) cat(sprintf("# node size follows %s\n", measure))
  cat(sprintf("# %s\n", x$file[[1L]]))
  shown <- utils::head(as.data.frame(x), n)
  print(shown[setdiff(names(shown), "file")], row.names = FALSE)
  if (nrow(x) > n) {
    cat(sprintf("# %d more bin%s.\n", nrow(x) - n,
      if (nrow(x) - n == 1L) "" else "s"))
  }
  invisible(x)
}

#' Summarise an animation
#'
#' @param object A `dynet_animation` from [animate()].
#' @param ... Ignored.
#' @return A one-row plain `data.frame` with `bins`, `frames`, `fps`,
#'   `seconds`, `tween`, `ease`, `layout`, `format`, `measure` (what node
#'   size follows, `NA` when it is constant), `first_time`, `last_time`,
#'   `min_ties`, `max_ties`, `turnover` (over the bins after the first that
#'   hold a tie, the median share of a bin's ties that were not active in the
#'   bin before: near 0 the film flows, near 1 every bin is a new picture;
#'   `NA` with a single bin) and `file`.
#' @examples
#' if (requireNamespace("gifski", quietly = TRUE) &&
#'   requireNamespace("cograph", quietly = TRUE)) {
#'   dn <- dynet(school_contacts)
#'   frames <- animate(dn, step = 6, window = 6, tween = 2)
#'   summary(frames)
#' }
#' @export
summary.dynet_animation <- function(object, ...) {
  rendered <- nrow(attr(object, "frames"))
  # Turnover: over the bins after the first that hold a tie, the median share
  # of a bin's ties that were not active in the bin before. Near 0 the film
  # flows, near 1 every bin is a new picture.
  later <- object[-1L, , drop = FALSE]
  later <- later[later$ties > 0 & !is.na(later$forming), , drop = FALSE]
  turnover <- if (nrow(later)) stats::median(later$forming / later$ties) else {
    NA_real_
  }
  data.frame(
    bins = nrow(object),
    frames = rendered,
    fps = attr(object, "fps"),
    seconds = rendered / attr(object, "fps"),
    tween = attr(object, "tween"),
    ease = attr(object, "ease"),
    layout = attr(object, "layout"),
    format = attr(object, "format"),
    measure = attr(object, "measure") %||% NA_character_,
    first_time = min(object$time),
    last_time = max(object$time),
    min_ties = min(object$ties),
    max_ties = max(object$ties),
    turnover = turnover,
    file = object$file[[1L]],
    stringsAsFactors = FALSE
  )
}

#' Coerce an animation to a data frame
#'
#' @param x A `dynet_animation` from [animate()].
#' @param row.names,optional As in [base::as.data.frame()].
#' @param what `"bins"`, the default, for one row per bin with the columns
#'   [animate()] documents; `"frames"` for one row per rendered frame,
#'   with `frame`, `bin` (the bin the frame belongs to), `phase` (how far
#'   along the transition to the next bin, in `[0, 1)`) and `time` (where the
#'   timeline marker stands).
#' @param ... Ignored.
#' @return A plain `data.frame`.
#' @examples
#' if (requireNamespace("gifski", quietly = TRUE) &&
#'   requireNamespace("cograph", quietly = TRUE)) {
#'   dn <- dynet(school_contacts)
#'   frames <- animate(dn, step = 6, window = 6, tween = 2)
#'   as.data.frame(frames)
#'   as.data.frame(frames, what = "frames")
#' }
#' @export
as.data.frame.dynet_animation <- function(x, row.names = NULL,
                                          optional = FALSE,
                                          what = c("bins", "frames"), ...) {
  what <- match.arg(what)
  if (identical(what, "frames")) {
    out <- attr(x, "frames")
    rownames(out) <- NULL
    return(out)
  }
  out <- x
  attributes(out) <- list(names = names(x), row.names = seq_len(nrow(x)),
    class = "data.frame")
  out
}
