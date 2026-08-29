# ===========================================================================
# The proximity timeline
# ===========================================================================

#' Measure the network at a series of time slices
#'
#' Each slice covers a window of real time. Its geodesic distances are reduced
#' to one dimension by classical scaling, so vertices that are interacting sit
#' near one another, and the node-level measure that drives line thickness is
#' read off the same window -- position and thickness therefore always describe
#' the same moment.
#'
#' Slices may be closer together than they are wide, in which case consecutive
#' windows overlap and share most of their edges. That is what makes the
#' trajectories smooth: every drawn point is a real measurement of a real
#' window, and nothing between two measurements is invented.
#'
#' @param x A `dynet` object.
#' @param measure Node-level measure to read off each slice.
#' @param slices Number of slices across the observation window, or `NULL` to
#'   use the network's own time bins.
#' @param window Width of each slice. `NULL` uses `.default_window()`.
#' @param default_dist Distance assumed between vertices with no path between
#'   them.
#' @return A list with `pos` and `weight` (both vertices-by-slices matrices),
#'   `times`, `window` and `names`.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.proximity_slices(dn, slices = 5)
#' @noRd
.proximity_slices <- function(x, measure = "degree", slices = 120L,
                              window = NULL, default_dist = 2) {
  enc <- .encode(x)
  rng <- x$meta$time_range
  w <- window %||% .default_window(x)

  if (is.null(slices)) {
    grid <- .grid_for(enc, x, .window_spec(x, window = w))
    lo <- grid$lo; hi <- grid$hi; times <- grid$time
    closed <- grid$closed
  } else {
    times <- seq(rng[["start"]], rng[["end"]], length.out = slices)
    lo <- times - w / 2
    hi <- times + w / 2
    closed <- seq_along(times) == length(times)
    observations <- .observation_table(x)
    if (!is.null(observations)) {
      component <- vapply(times, function(one) {
        hit <- which(one >= observations$start & one <= observations$end)
        if (length(hit)) hit[1L] else NA_integer_
      }, integer(1L))
      observed <- !is.na(component)
      lo[observed] <- pmax(
        lo[observed], observations$start[component[observed]]
      )
      hi[observed] <- pmin(
        hi[observed], observations$end[component[observed]]
      )
      lo[!observed] <- times[!observed]
      hi[!observed] <- times[!observed]
      closed <- rep(FALSE, length(times))
      closed[observed] <-
        hi[observed] == observations$end[component[observed]]
    }
  }
  n_slice <- length(times)

  measured <- lapply(seq_len(n_slice), function(k) {
    bin <- data.frame(
      lo = lo[k], hi = hi[k], time = times[k], closed = closed[k]
    )
    state <- .snapshot_state(x, enc, bin, w, "bounded", "all")
    full <- .adjacency(enc, state$active, x$directed)
    a <- full[state$index, state$index, drop = FALSE]
    pos <- rep(NA_real_, enc$n)
    weight <- rep(NA_real_, enc$n)
    if (length(state$index)) {
      pos[state$index] <- .slice_position(
        a, default_dist, length(state$index), times[k]
      )
      weight[state$index] <- .snapshot_measure(
        measure, a, x$directed, 0.85
      )
    }
    list(pos = pos, w = weight)
  })

  # Classical scaling fixes neither sign nor scale. Standardising makes one
  # slice's vertical distances comparable with another's; flipping each slice
  # to agree with the one before stops the lines zig-zagging for reasons that
  # have nothing to do with the data.
  aligned <- Reduce(function(prev, cur) {
    shared <- is.finite(prev) & is.finite(cur)
    if (sum(shared) < 2L || stats::sd(cur[shared]) == 0 ||
        stats::sd(prev[shared]) == 0) return(cur)
    if (stats::cor(prev[shared], cur[shared]) < 0) -cur else cur
  }, lapply(measured, `[[`, "pos"), accumulate = TRUE)

  list(pos    = matrix(unlist(aligned, use.names = FALSE), nrow = enc$n),
       weight = matrix(unlist(lapply(measured, `[[`, "w"), use.names = FALSE),
                       nrow = enc$n),
       times  = times, window = w, names = enc$names)
}

#' Default width for a proximity slice
#'
#' A sixth of the observation window, or the bin width if that is wider.
#' Scaling is only meaningful on a slice whose network is connected: measured
#' over one narrow bin most vertices are isolated, their placement is
#' arbitrary, and the trajectories jump for no reason in the data. A sixth of
#' the window is wide enough for that to stop being the dominant effect while
#' still resolving change within the observation period.
#'
#' @param x A `dynet` object.
#' @return A single positive number.
#' @noRd
.default_window <- function(x) {
  rng <- x$meta$time_range
  max(x$meta$interval, (rng[["end"]] - rng[["start"]]) / 6)
}

#' One slice's standardised one-dimensional positions
#' @param a Adjacency matrix for the slice.
#' @param default_dist Distance assumed between unreachable vertices.
#' @param n Vertex count.
#' @param at The slice's time, for the warning message.
#' @return A numeric vector of length `n`.
#' @noRd
.slice_position <- function(a, default_dist, n, at) {
  d <- .geodesic(a, directed = FALSE)
  joined <- d[is.finite(d)]
  d[!is.finite(d)] <- if (length(joined) == 0L) default_dist else
    max(default_dist, max(joined) + 1)
  if (all(d == 0)) return(rep(0, n))
  fit <- tryCatch(stats::cmdscale(stats::as.dist(d), k = 1L),
    error = function(e) {
      warning(warningCondition(
        sprintf("Scaling failed for the slice at t = %s (%s); its vertices are placed at zero.",
                format(at), conditionMessage(e)),
        class = "dynet_scaling_failed"), call. = FALSE)
      NULL
    })
  if (is.null(fit) || length(fit) != n) return(rep(0, n))
  v <- as.numeric(fit)
  spread <- stats::sd(v)
  if (spread > 0) v / spread else v
}

#' A netobject for one span of time
#' @param x A `dynet` object.
#' @param from,to Time bounds; edges overlapping the span are kept.
#' @return A `dynet` netobject containing eligible vertices and endpoint-valid
#'   edges, or `NULL` when the eligible set is empty.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.range_netobject(dn, 0, 2)
#' @noRd
.range_netobject <- function(x, from, to) {
  enc <- .encode(x)
  width <- to - from
  state <- .snapshot_state(
    x, enc,
    data.frame(lo = from, hi = to, time = from, closed = TRUE),
    width, "bounded", "all"
  )
  raw_ids <- unique(enc$raw_spell[state$active])
  keep <- x$spells$.raw_spell %in% raw_ids
  if (!any(keep) && !isTRUE(x$meta$vertex_activity == "explicit")) return(NULL)
  if (!any(state$eligible)) return(NULL)
  groups <- if ("groups" %in% names(x$nodes)) "groups" else NULL
  nodes <- x$nodes[state$eligible,
    setdiff(names(x$nodes), c("id", "label", "x", "y")), drop = FALSE
  ]
  vertex_spells <- x$vertex_spells[
    x$vertex_spells$node %in% nodes$name, , drop = FALSE
  ]
  .as_netobject(x$spells[keep, , drop = FALSE], nodes, x$directed, groups,
                x$meta, vertex_spells)
}

#' Split the observation window into phases
#' @param x A `dynet` object.
#' @param phases Requested number of phases, or `NULL` to use sessions when
#'   the network has them and three otherwise.
#' @return A data frame with `label`, `from` and `to`.
#' @noRd
.phase_table <- function(x, phases = NULL) {
  rng <- x$meta$time_range
  if (is.null(phases) && !is.null(x$meta$sessions)) {
    bounds <- lapply(x$meta$sessions, function(s) {
      rows <- x$spells$session == s
      c(from = min(x$spells$start[rows]), to = max(x$spells$end[rows]))
    })
    return(data.frame(label = x$meta$sessions,
                      from = vapply(bounds, `[[`, numeric(1L), "from"),
                      to   = vapply(bounds, `[[`, numeric(1L), "to"),
                      stringsAsFactors = FALSE))
  }
  k <- phases %||% 3L
  cuts <- seq(rng[["start"]], rng[["end"]], length.out = k + 1L)
  data.frame(label = sprintf("Phase %d", seq_len(k)),
             from = cuts[-(k + 1L)], to = cuts[-1L],
             stringsAsFactors = FALSE)
}

#' Draw the proximity timeline
#'
#' @param x A `dynet` object.
#' @param measure Node-level measure driving line thickness.
#' @param phases Number of phases, or `NULL`.
#' @param networks Whether to draw a network panel per phase.
#' @param events Whether to mark times when edges formed.
#' @param labels Whether to name each line at its right-hand end.
#' @param default_dist Distance assumed between unreachable vertices.
#' @param slices How many times to measure the network across the window.
#'   Smoothness comes from measuring often, never from interpolation: nothing
#'   is drawn between two measurements. `NULL` measures once per time bin.
#' @param window Width of each slice. `NULL` uses `.default_window()`.
#'   When slices are closer together than they are wide the windows overlap,
#'   which is what makes consecutive positions move gradually.
#' @param flow Corner-cutting passes applied to each line, or `0` for sharp
#'   joints. Rounding only ever takes convex combinations of measurements, so
#'   it cannot overshoot one.
#' @param palette Palette specification, as in [plot.dynet()].
#' @param highlight Vertex names to draw in colour, the rest in grey.
#' @param style A style list from `.dyn_style()`.
#' @param ... Passed to `cograph::splot()` for the network panels.
#' @return `x`, invisibly.
#' @noRd
.plot_proximity <- function(x, measure = "degree", phases = NULL,
                            networks = TRUE, events = TRUE, labels = TRUE,
                            default_dist = 2, slices = 120L, window = NULL,
                            flow = 2L, palette = "okabe", highlight = NULL,
                            style = .dyn_style(), ...) {
  if (networks) .need_cograph()
  # The measure is read straight off each slice rather than through
  # dyn_centrality(), so it has to be validated here.
  if (!measure %in% .node_measures || length(measure) != 1L) {
    stop(errorCondition(
      sprintf("`measure` must be one of %s.",
              paste(.node_measures, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }
  if (!x$directed && measure %in% c("indegree", "outdegree", "hub", "authority")) {
    stop(errorCondition(
      sprintf("%s needs a directed network; this one is undirected.",
              sQuote(measure)),
      class = "dynet_needs_directed", call = NULL))
  }
  .check(
    "`slices` must be NULL or a single number of at least two." =
      is.null(slices) || (is.numeric(slices) && length(slices) == 1L &&
                            is.finite(slices) && slices >= 2),
    "`window` must be NULL or a single positive number." =
      is.null(window) || (is.numeric(window) && length(window) == 1L &&
                            is.finite(window) && window > 0),
    "`flow` must be a single non-negative whole number." =
      is.numeric(flow) && length(flow) == 1L && is.finite(flow) && flow >= 0
  )
  prox <- .proximity_slices(x, measure = measure, slices = slices,
                            window = window, default_dist = default_dist)
  n <- length(prox$names)
  weight <- prox$weight
  phase_tbl <- .phase_table(x, phases)

  # The palette holds nine colours and repeats beyond that. Every line is
  # named at its right-hand end, which is what identifies it -- no distinction
  # rests on colour alone. Line type is deliberately not used as the second
  # channel: base graphics scales dash length by line width, so a dashed line
  # breaks up exactly where it is thin, and thin here means low activity, not
  # absent data.
  cols <- .dyn_palette(palette, n)
  faded <- grDevices::adjustcolor(cols, alpha.f = 0.85)
  if (!is.null(highlight)) {
    off <- !prox$names %in% highlight
    faded[off] <- "#C9CDD2"
  }

  # ---- figure scaffold -----------------------------------------------------
  n_panel <- nrow(phase_tbl)
  spec <- if (networks) {
    rbind(rep(1L, n_panel), rep(2L, n_panel), 2L + seq_len(n_panel))
  } else {
    rbind(1L, 2L)
  }
  heights <- if (networks) c(3.0, 0.95, 1.9) else c(3.0, 0.95)
  # Room on the right for the direct labels, sized to the longest name.
  right <- if (labels) {
    max(4.5, min(11, 1.1 + 0.52 * max(nchar(prox$names))))
  } else 1.2
  .check_device(right, heights)
  old <- cograph::panel_layout(spec, mar = c(0.3, 4.4, 1.2, right),
                               heights = heights)
  on.exit(graphics::par(old), add = TRUE, after = FALSE)

  # ---- the timeline --------------------------------------------------------
  xlim <- range(prox$times)
  ylim <- .dyn_expand_range(as.numeric(prox$pos))
  .dyn_panel(xlim, ylim, ylab = "Approximate distance among vertices",
             style = style, x_axis = FALSE)

  if (events) .draw_event_marks(x, ylim, style)

  drawn <- lapply(seq_len(n), function(i) {
    .draw_proximity_line(prox$times, prox$pos[i, ], weight[i, ], faded[i],
                         flow = as.integer(flow))
  })
  if (labels) {
    ends <- vapply(drawn, function(d) {
      if (length(d$y)) d$y[length(d$y)] else NA_real_
    }, numeric(1L))
    present <- is.finite(ends)
    if (any(present)) {
      .draw_end_labels(
        prox$names[present], ends[present], faded[present], xlim, ylim, style
      )
    }
  }

  # ---- the phase strip -----------------------------------------------------
  # The time axis is drawn here rather than under the timeline, so its labels
  # do not collide with the strip.
  graphics::par(mar = c(3.0, 4.4, 0.2, right))
  .draw_phase_strip(phase_tbl, xlim, style,
                    xlab = sprintf("Time (%s)", x$meta$time_unit))

  # ---- one network per phase ----------------------------------------------
  if (networks) {
    graphics::par(mar = c(0.4, 0.4, 1.6, 0.4))
    fills <- stats::setNames(faded, prox$names)
    invisible(lapply(seq_len(n_panel), function(k) {
      net <- .range_netobject(x, phase_tbl$from[k], phase_tbl$to[k])
      if (is.null(net)) {
        .dyn_panel(c(0, 1), c(0, 1), main = phase_tbl$label[k], style = style,
                   x_axis = FALSE, y_axis = FALSE)
        graphics::text(0.5, 0.5, "no active edge", col = style$axis_color,
                       cex = 0.8 * style$cex)
        return(NULL)
      }
      args <- .splot_args(net, utils::modifyList(list(
        node_fill = unname(fills[net$nodes$name]),
        title = phase_tbl$label[k], label_size = 0.6,
        layout = "oval"), list(...)), palette)
      do.call(cograph::splot, c(list(net), args))
    }))
  }
  invisible(x)
}

#' Refuse to draw when the device is too small for the panels
#'
#' Base graphics reports this as "figure margins too large", which does not
#' say what to do about it.
#'
#' @param right Right margin in lines.
#' @param heights Relative panel heights passed to the layout.
#' @return `NULL`, invisibly.
#' @noRd
.check_device <- function(right, heights) {
  din <- graphics::par("din")
  line <- graphics::par("csi")
  # Width: both margins plus a plot area worth having. Height: the phase strip
  # is the binding constraint, because its own margins must fit inside its
  # share of the figure.
  need_w <- (4.4 + right + 8) * line
  need_h <- (3.0 + 0.2 + 1.4) * line / (heights[2L] / sum(heights))
  if (din[1L] < need_w || din[2L] < need_h) {
    stop(errorCondition(
      sprintf("The device is %.1f by %.1f inches; this figure needs about %.1f by %.1f. Enlarge the device%s.",
              din[1L], din[2L], need_w, need_h,
              if (right > 1.5) ", or set labels = FALSE" else ""),
      class = "dynet_device_too_small", call = NULL))
  }
  invisible(NULL)
}

#' Round the corners of a polyline by cutting them
#'
#' Chaikin's corner-cutting. Each pass replaces every vertex with two points a
#' quarter and three quarters of the way along its adjacent edges, and repeats.
#'
#' Every point it produces is a convex combination of measured points, so the
#' curve can never leave the corridor the polyline already occupies: it cannot
#' overshoot a measurement, and it cannot invent an excursion. That is what
#' separates it from interpolating a spline through the same points, which is
#' free to travel anywhere between them -- an `fmm` or `natural` spline through
#' evenly spaced slices overshoots the pair it is joining by around one
#' standard deviation, and even a monotone Hermite spline by about half of one.
#'
#' @param m A matrix whose rows are points and whose columns are the
#'   quantities to round together.
#' @param passes Number of corner-cutting passes.
#' @return A matrix with the same columns and more rows.
#' @references Chaikin, G. M. (1974). An algorithm for high-speed curve
#'   generation. *Computer Graphics and Image Processing*, 3(4), 346-349.
#' @noRd
.chaikin <- function(m, passes = 2L) {
  pass <- 0L
  # Each pass reads the polyline the previous one produced.
  while (pass < passes && nrow(m) >= 3L) {
    n <- nrow(m)
    a <- m[-n, , drop = FALSE]
    b <- m[-1L, , drop = FALSE]
    cut <- matrix(NA_real_, nrow = 2L * (n - 1L), ncol = ncol(m))
    cut[seq(1L, 2L * (n - 1L), by = 2L), ] <- 0.75 * a + 0.25 * b
    cut[seq(2L, 2L * (n - 1L), by = 2L), ] <- 0.25 * a + 0.75 * b
    m <- rbind(m[1L, , drop = FALSE], cut, m[n, , drop = FALSE])
    pass <- pass + 1L
  }
  m
}

#' Draw one vertex's trajectory, thickness following its activity
#'
#' The line joins measurements and nothing else. Corners are rounded by
#' cutting them, which keeps the curve inside the corridor the measurements
#' already define; no interpolating curve is fitted through them.
#'
#' Lines are solid. A dash pattern would fight the thickness encoding: base
#' graphics scales dash length by line width, so a dashed line disintegrates
#' precisely where it is thinnest, making low activity look like missing data.
#'
#' @param times Slice times.
#' @param pos Positions, one per slice.
#' @param w Measure values, one per slice.
#' @param col Line colour.
#' @param flow Corner-cutting passes, or `0` to leave the joints sharp.
#' @return A list with the drawn `x` and `y`.
#' @examples
#' file <- tempfile(fileext = ".pdf")
#' grDevices::pdf(file)
#' graphics::plot.new()
#' Dynet:::.draw_proximity_line(1:3, c(0, NA, 1), c(1, NA, 2), "black", 0)
#' grDevices::dev.off()
#' unlink(file)
#' @noRd
.draw_proximity_line <- function(times, pos, w, col, flow = 2L) {
  present <- is.finite(times) & is.finite(pos)
  if (!any(present)) return(list(x = numeric(), y = numeric()))
  lwd <- rep(1.6, length(w))
  valued <- present & is.finite(w)
  if (any(valued)) {
    span <- diff(range(w[valued]))
    if (span > 0) lwd[valued] <- 0.5 + 4.2 *
      (w[valued] - min(w[valued])) / span
  }
  index <- which(present)
  run <- cumsum(c(TRUE, diff(index) != 1L))
  paths <- lapply(split(index, run), function(i) {
    path <- cbind(times[i], pos[i], lwd[i])
    if (flow > 0L) path <- .chaikin(path, flow)
    m <- nrow(path)
    if (m > 1L) {
      graphics::segments(
        path[-m, 1L], path[-m, 2L], path[-1L, 1L], path[-1L, 2L],
        col = col, lwd = path[-m, 3L], lend = 0L
      )
    }
    path
  })
  path <- do.call(rbind, paths)
  list(x = path[, 1L], y = path[, 2L])
}

#' Mark the times at which edges formed
#' @param x A `dynet` object.
#' @param ylim Panel limits.
#' @param style A style list.
#' @return `NULL`, invisibly.
#' @noRd
.draw_event_marks <- function(x, ylim, style) {
  ev <- as.data.frame(events(x, measure = "formation",
                                 sessions = "collapse"))
  ev <- ev[ev$value > 0, , drop = FALSE]
  if (nrow(ev) == 0L) return(invisible(NULL))
  intensity <- ev$value / max(ev$value)
  # adjustcolor() takes one alpha for a vector of colours, not one alpha each,
  # so the per-event transparency has to be built a colour at a time.
  cols <- vapply(intensity, function(a) {
    grDevices::adjustcolor("#D55E00", alpha.f = 0.06 + 0.16 * a)
  }, character(1L))
  graphics::segments(ev$time, ylim[1L], ev$time, ylim[2L],
                     col = cols, lwd = 0.5 + 0.9 * intensity)
  invisible(NULL)
}

#' Name each line at its right-hand end, in place of a legend
#' @param names Vertex names.
#' @param ends Final position of each line.
#' @param cols Line colours.
#' @param xlim,ylim Panel limits.
#' @param style A style list.
#' @return `NULL`, invisibly.
#' @noRd
.draw_end_labels <- function(names, ends, cols, xlim, ylim, style) {
  gap <- diff(ylim) * 0.045
  at <- .spread_labels(ends, gap)
  graphics::segments(xlim[2L], ends, xlim[2L] + diff(xlim) * 0.015, at,
                     col = cols, lwd = 0.7, xpd = NA)
  graphics::text(xlim[2L] + diff(xlim) * 0.025, at, labels = names,
                 col = cols, adj = c(0, 0.5), cex = 0.72 * style$cex, xpd = NA)
  invisible(NULL)
}

#' Draw the phase strip beneath the timeline
#' @param phase_tbl A phase table from `.phase_table()`.
#' @param xlim Panel limits.
#' @param style A style list.
#' @param xlab Axis label.
#' @return `NULL`, invisibly.
#' @noRd
.draw_phase_strip <- function(phase_tbl, xlim, style, xlab = "") {
  graphics::plot(NA, type = "n", xlim = xlim, ylim = c(0, 1), axes = FALSE,
                 ann = FALSE, xaxs = "i", yaxs = "i")
  graphics::rect(phase_tbl$from, 0.34, phase_tbl$to, 1,
                 col = "#E8EAED", border = "#FFFFFF", lwd = 1.4)
  graphics::text((phase_tbl$from + phase_tbl$to) / 2, 0.67,
                 labels = phase_tbl$label, cex = 0.7 * style$cex,
                 col = style$text_color)
  graphics::axis(1L, col = NA, col.ticks = style$axis_color,
                 col.axis = style$axis_color, cex.axis = 0.8 * style$cex,
                 tcl = -0.25, lwd.ticks = 0.8, padj = -1.1, line = -0.6)
  if (nzchar(xlab)) {
    graphics::title(xlab = xlab, line = 1.7, cex.lab = 0.85 * style$cex,
                    col.lab = style$axis_color)
  }
  invisible(NULL)
}
