# ===========================================================================
# Shared base-graphics panel style
# ===========================================================================
# Follows the panel contract used by tsn's R/plot-style.R, so a Dynet base
# panel and a tsn one sit side by side without looking like different tools.

#' Resolve the shared plot style
#'
#' Central style contract for Dynet's base-graphics panels: background, grid,
#' axis, frame and text colours plus a global size multiplier. Every plot that
#' uses it exposes it as a `style` argument.
#'
#' @param cex Global size multiplier for text.
#' @param grid Whether to draw the background grid.
#' @param background Panel background colour.
#' @param grid_color Grid line colour.
#' @param axis_color Axis tick and label colour.
#' @param text_color Title and emphasis colour.
#' @param frame_color Panel frame colour, or `NA` for no frame.
#' @return A named list of style constants.
#' @noRd
.dyn_style <- function(cex = 1, grid = TRUE, background = "#FFFFFF",
                       grid_color = "#ECEEF0", axis_color = "#6B7280",
                       text_color = "#1F2937", frame_color = "#D8DCE0") {
  .check(
    "`cex` must be a single positive number." =
      is.numeric(cex) && length(cex) == 1L && is.finite(cex) && cex > 0,
    "`grid` must be a single TRUE or FALSE." =
      is.logical(grid) && length(grid) == 1L && !is.na(grid)
  )
  list(cex = cex, grid = grid, background = background,
       grid_color = grid_color, axis_color = axis_color,
       text_color = text_color, frame_color = frame_color)
}

#' Pad a range so a series does not touch the panel edge
#' @param values Numeric vector.
#' @return A numeric vector of length two.
#' @noRd
.dyn_expand_range <- function(values) {
  finite <- values[is.finite(values)]
  if (length(finite) == 0L) return(c(-0.5, 0.5))
  limits <- range(finite)
  if (diff(limits) == 0) {
    padding <- if (limits[1L] == 0) 0.5 else abs(limits[1L]) * 0.04
    limits <- limits + c(-padding, padding)
  }
  limits + c(-1, 1) * diff(limits) * 0.04
}

#' Open a styled panel
#'
#' The empty panel everything else is drawn on: background fill, soft grid,
#' tick-only axes with horizontal y labels, a light frame and a left-aligned
#' title.
#'
#' @param xlim,ylim Axis limits.
#' @param main,xlab,ylab Panel labels.
#' @param style A style list from `.dyn_style()`.
#' @param x_axis,y_axis Whether to draw each axis.
#' @return `NULL`, invisibly.
#' @noRd
.dyn_panel <- function(xlim, ylim, main = "", xlab = "", ylab = "",
                       style = .dyn_style(), x_axis = TRUE, y_axis = TRUE) {
  graphics::plot(NA, type = "n", xlim = xlim, ylim = ylim, axes = FALSE,
                 ann = FALSE, xaxs = "i", yaxs = "i")
  limits <- graphics::par("usr")
  graphics::rect(limits[1L], limits[3L], limits[2L], limits[4L],
                 col = style$background, border = NA)
  if (style$grid) {
    graphics::abline(v = graphics::axTicks(1L), col = style$grid_color, lwd = 0.9)
    graphics::abline(h = graphics::axTicks(2L), col = style$grid_color, lwd = 0.9)
  }
  if (x_axis) {
    graphics::axis(1L, col = NA, col.ticks = style$axis_color,
                   col.axis = style$axis_color, cex.axis = 0.8 * style$cex,
                   tcl = -0.25, lwd.ticks = 0.8, padj = -0.6)
  }
  if (y_axis) {
    graphics::axis(2L, las = 1L, col = NA, col.ticks = style$axis_color,
                   col.axis = style$axis_color, cex.axis = 0.8 * style$cex,
                   tcl = -0.25, lwd.ticks = 0.8, hadj = 0.85)
  }
  if (!is.na(style$frame_color)) graphics::box(col = style$frame_color, lwd = 0.9)
  if (nzchar(main)) {
    graphics::title(main = main, adj = 0, line = 0.7, font.main = 2L,
                    cex.main = 0.95 * style$cex, col.main = style$text_color)
  }
  if (nzchar(xlab)) {
    graphics::title(xlab = xlab, line = 1.9, cex.lab = 0.85 * style$cex,
                    col.lab = style$axis_color)
  }
  if (nzchar(ylab)) {
    graphics::title(ylab = ylab, line = 2.8, cex.lab = 0.85 * style$cex,
                    col.lab = style$axis_color)
  }
  invisible(NULL)
}

#' Nudge labels apart so none overlaps its neighbour
#'
#' Direct labelling replaces a legend, but two vertices ending at the same
#' height would print on top of one another. Positions are pushed apart by the
#' minimum readable gap, keeping their order.
#'
#' @param y Numeric positions, in any order.
#' @param gap Minimum separation to enforce.
#' @return A numeric vector of adjusted positions, in the input order.
#' @noRd
.spread_labels <- function(y, gap) {
  ord <- order(y)
  v <- y[ord]
  n <- length(v)
  if (n > 1L) {
    # One upward pass then one downward pass settles the chain of collisions.
    i <- 2L
    while (i <= n) {
      if (v[i] - v[i - 1L] < gap) v[i] <- v[i - 1L] + gap
      i <- i + 1L
    }
    i <- n - 1L
    while (i >= 1L) {
      if (v[i + 1L] - v[i] < gap) v[i] <- v[i + 1L] - gap
      i <- i - 1L
    }
  }
  out <- numeric(n)
  out[ord] <- v
  out
}
