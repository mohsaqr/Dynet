# ===========================================================================
# dynet_metric — the one tidy result class every verb returns
# ===========================================================================

#' Wrap a long data frame as a temporal measure
#'
#' @param df Long data frame with `measure` and `value` and, depending on
#'   `level`, `time`, `node`, `session` or edge endpoints.
#' @param level One of `"node"`, `"graph"`, `"edge"` or `"path"`.
#' @param what Short human name of the quantity, used in printing.
#' @param dn The network the measure came from.
#' @param note Optional single line shown under the header.
#' @return An object of class `c("dynet_metric", "data.frame")`.
#' @keywords internal
.metric <- function(df, level, what, dn, note = NULL) {
  # A session column that is entirely absent of sessions is noise; drop it.
  if ("session" %in% names(df) && all(is.na(df$session) | df$session == "all")) {
    df$session <- NULL
  }
  front <- intersect(c("session", "time", "node", "from", "to", "measure",
                       "value"), names(df))
  df <- df[, c(front, setdiff(names(df), front)), drop = FALSE]
  rownames(df) <- NULL
  structure(df,
    class     = c("dynet_metric", "data.frame"),
    level     = level,
    what      = what,
    note      = note,
    time_unit = dn$meta$time_unit,
    interval  = dn$meta$interval,
    n_nodes   = nrow(dn$nodes),
    directed  = dn$directed,
    net_format = dn$meta$format
  )
}

#' Tidy data frame of a temporal measure
#'
#' @param x A `dynet_metric` produced by any measurement verb.
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param layout `"long"` gives one row per observation, which is the default
#'   and the shape every other verb expects. `"wide"` spreads time across
#'   columns, giving one row per vertex (or per measure for graph-level
#'   quantities), which is convenient for exporting a table.
#' @param ... Ignored.
#'
#' @return A plain `data.frame`. In long layout the columns are `session`
#'   (only when the network has sessions), `time`, `node` (node-level
#'   measures only), `measure` and `value`, one row per observation. In wide
#'   layout the first columns identify the row and the remaining columns are
#'   time points.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' as.data.frame(dyn_centrality(dn, measure = "degree"))
#' as.data.frame(dyn_centrality(dn, measure = "degree"), layout = "wide")
#'
#' @export
as.data.frame.dynet_metric <- function(x, row.names = NULL, optional = FALSE,
                                       layout = c("long", "wide"), ...) {
  layout <- match.arg(layout)
  df <- x
  attributes(df) <- list(names = names(x), row.names = seq_len(nrow(x)),
                         class = "data.frame")
  if (identical(layout, "long")) return(df)
  if (!"time" %in% names(df)) return(df)

  id_cols <- intersect(c("session", "node", "from", "to", "measure"), names(df))
  wide <- stats::reshape(
    df[, c(id_cols, "time", "value"), drop = FALSE],
    idvar = id_cols, timevar = "time", direction = "wide", sep = "_"
  )
  names(wide) <- sub("^value_", "t", names(wide))
  rownames(wide) <- NULL
  wide
}

#' Print a temporal measure
#'
#' @param x A `dynet_metric`.
#' @param n Number of rows to show. Defaults to twelve.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet_metric <- function(x, n = 12L, ...) {
  what <- attr(x, "what")
  lvl  <- attr(x, "level")
  unit <- attr(x, "time_unit")
  meas <- unique(x$measure)

  cat(sprintf("# %s (%s-level)\n", what, lvl))
  bits <- character()
  if ("node" %in% names(x)) {
    bits <- c(bits, sprintf("%d vertices", length(unique(x$node))))
  }
  if ("time" %in% names(x)) {
    bits <- c(bits, sprintf("%d time points, %s per bin",
                            length(unique(x$time)),
                            format(attr(x, "interval"))))
  }
  if ("session" %in% names(x)) {
    bits <- c(bits, sprintf("%d sessions", length(unique(x$session))))
  }
  bits <- c(bits, sprintf("time in %s", unit))
  cat("# ", paste(bits, collapse = " | "), "\n", sep = "")
  if (length(meas) > 1L) {
    cat("# measures: ", paste(meas, collapse = ", "), "\n", sep = "")
  }
  if (!is.null(attr(x, "note"))) cat("# ", attr(x, "note"), "\n", sep = "")

  body <- as.data.frame(x)
  print(utils::head(body, n), row.names = FALSE)
  if (nrow(body) > n) {
    cat(sprintf("# %d more rows. summary() aggregates them; plot() draws them.\n",
                nrow(body) - n))
  }
  invisible(x)
}

#' Summarise a temporal measure
#'
#' Collapses the time dimension. Node-level measures are summarised one row
#' per vertex and measure; graph-level measures one row per measure. The peak
#' time is reported alongside, because when a quantity peaked is usually the
#' question a temporal network is being asked.
#'
#' @param object A `dynet_metric`.
#' @param by Grouping for the summary: `"node"` (the default for node-level
#'   measures), `"time"`, or `"measure"`.
#' @param ... Ignored.
#'
#' @return A `data.frame` with the grouping columns plus `n`, `mean`, `sd`,
#'   `min`, `max` and, when time is available, `peak_time`.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' summary(dyn_centrality(dn, measure = "degree"))
#' summary(dyn_centrality(dn, measure = "degree"), by = "time")
#'
#' @export
summary.dynet_metric <- function(object, by = NULL, ...) {
  df <- as.data.frame(object)
  if (is.null(by)) by <- if ("node" %in% names(df)) "node" else "measure"
  by <- match.arg(by, c("node", "time", "measure"))
  keys <- intersect(unique(c("session", by, "measure")), names(df))
  key_tbl <- df[, keys, drop = FALSE]
  has_time <- "time" %in% names(df) && !identical(by, "time")

  rows <- lapply(split(seq_len(nrow(df)), do.call(paste, c(key_tbl, sep = "\r"))),
    function(i) {
      v <- df$value[i]
      ok <- v[!is.na(v)]
      out <- key_tbl[i[1L], , drop = FALSE]
      out$n    <- length(v)
      out$mean <- if (length(ok)) mean(ok) else NA_real_
      out$sd   <- if (length(ok) > 1L) stats::sd(ok) else NA_real_
      out$min  <- if (length(ok)) min(ok) else NA_real_
      out$max  <- if (length(ok)) max(ok) else NA_real_
      if (has_time) {
        out$peak_time <- if (length(ok)) df$time[i][which.max(v)] else NA_real_
      }
      out
    })

  out <- do.call(rbind, rows)
  out <- out[do.call(order, out[keys]), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Plot a temporal measure
#'
#' Draws the quantity against time. Node-level measures are drawn as one line
#' per vertex; graph-level measures as one line per measure. Distinctions are
#' carried by colour and line type together, never by colour alone.
#'
#' @param x A `dynet_metric`.
#' @param type `"line"` for trajectories over time, `"heatmap"` for a
#'   vertex-by-time tile plot, `"ridge"` for small multiples per measure.
#' @param highlight Optional character vector of vertex names to draw in
#'   colour, with everything else in grey. Useful when there are many
#'   vertices.
#' @param top Draw only the `top` vertices by mean value. `NULL` draws all.
#' @param palette Colours for the series: `"okabe"` (the default),
#'   `"extended"`, `"many"`, your own vector of colours, or a function of `n`.
#' @param base_size Base font size.
#' @param ... Ignored.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' plot(dyn_centrality(dn, measure = "degree"), top = 5)
#' plot(dyn_centrality(dn, measure = "degree"), palette = "extended")
#'
#' @export
plot.dynet_metric <- function(x, type = c("line", "heatmap", "ridge"),
                              highlight = NULL, top = NULL,
                              palette = "okabe", base_size = 12, ...) {
  type <- match.arg(type)
  .dyn_palette(palette, 1L)
  df <- as.data.frame(x)
  if (!"time" %in% names(df)) {
    return(.plot_no_time(df, x, base_size, palette = palette))
  }
  has_node <- "node" %in% names(df)

  if (has_node && !is.null(top)) {
    keep <- names(sort(vapply(split(df$value, df$node), mean, numeric(1L)),
                       decreasing = TRUE))[seq_len(min(top, length(unique(df$node))))]
    df <- df[df$node %in% keep, , drop = FALSE]
  }

  if (identical(type, "heatmap")) return(.plot_heatmap(df, x, has_node, base_size))

  grp <- if (has_node) "node" else "measure"
  df$.grp <- df[[grp]]
  df$.hl <- if (is.null(highlight)) TRUE else df$.grp %in% highlight

  n_grp <- length(unique(df$.grp))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = time, y = value, group = .grp))

  if (is.null(highlight)) {
    p <- p +
      ggplot2::geom_line(ggplot2::aes(colour = .grp, linetype = .grp),
                         linewidth = 0.6) +
      ggplot2::scale_colour_manual(values = .dyn_palette(palette, n_grp), name = NULL) +
      ggplot2::scale_linetype_manual(values = rep(1:6, length.out = n_grp),
                                     name = NULL)
  } else {
    p <- p +
      ggplot2::geom_line(data = df[!df$.hl, , drop = FALSE],
                         colour = "grey80", linewidth = 0.4) +
      ggplot2::geom_line(data = df[df$.hl, , drop = FALSE],
                         ggplot2::aes(colour = .grp, linetype = .grp),
                         linewidth = 0.8) +
      ggplot2::scale_colour_manual(values = .dyn_palette(palette, length(highlight)),
                                   name = NULL) +
      ggplot2::scale_linetype_manual(values = rep(1:6, length.out = length(highlight)),
                                     name = NULL)
  }

  facets <- character()
  if (has_node && length(unique(df$measure)) > 1L) facets <- "measure"
  if (identical(type, "ridge")) facets <- "measure"
  if (length(facets) > 0L) {
    p <- p + ggplot2::facet_wrap(stats::as.formula(paste("~", facets)),
                                 scales = "free_y")
  }
  if ("session" %in% names(df)) {
    p <- p + ggplot2::facet_wrap(~session, scales = "free_x")
  }

  p +
    ggplot2::labs(x = sprintf("Time (%s)", attr(x, "time_unit")),
                  y = attr(x, "what")) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

#' Heatmap panel for a temporal measure
#' @param df Long data frame.
#' @param x The originating metric, for labels.
#' @param has_node Whether the measure is node-level.
#' @param base_size Base font size.
#' @return A `ggplot` object.
#' @keywords internal
.plot_heatmap <- function(df, x, has_node, base_size) {
  df$.row <- if (has_node) df$node else df$measure
  ggplot2::ggplot(df, ggplot2::aes(x = time, y = stats::reorder(.row, value),
                                   fill = value)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_gradient2(low = "#D33F6A", mid = "white",
                                  high = "#4A6FE3",
                                  midpoint = .finite_median(df$value),
                                  name = attr(x, "what")) +
    ggplot2::labs(x = sprintf("Time (%s)", attr(x, "time_unit")), y = NULL) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid = ggplot2::element_blank())
}

#' Median of the finite values, or zero when there are none
#' @param v Numeric vector.
#' @return A single numeric value.
#' @keywords internal
.finite_median <- function(v) {
  v <- v[is.finite(v)]
  if (length(v) == 0L) 0 else stats::median(v)
}

#' Bar panel for a measure with no time dimension
#' @param df Long data frame.
#' @param x The originating metric, for labels.
#' @param base_size Base font size.
#' @param top Largest number of rows to draw.
#' @param palette Palette specification, as in [plot.dynet()].
#' @return A `ggplot` object.
#' @keywords internal
.plot_no_time <- function(df, x, base_size, top = 30L, palette = "okabe") {
  df$.row <- if ("node" %in% names(df)) {
    df$node
  } else if (all(c("from", "to") %in% names(df))) {
    paste(df$from, if (isTRUE(attr(x, "directed"))) "\u2192" else "\u2013", df$to)
  } else {
    df$measure
  }

  sub <- NULL
  n_row <- length(unique(df$.row))
  if (n_row > top) {
    rank <- vapply(split(abs(df$value), df$.row), function(v) {
      v <- v[is.finite(v)]
      if (length(v) == 0L) 0 else max(v)
    }, numeric(1L))
    keep <- names(sort(rank, decreasing = TRUE))[seq_len(top)]
    df <- df[df$.row %in% keep, , drop = FALSE]
    sub <- sprintf("%d largest of %d shown", top, n_row)
  }

  ggplot2::ggplot(df, ggplot2::aes(x = value,
                                   y = stats::reorder(.row, value))) +
    ggplot2::geom_col(fill = .dyn_palette(palette, 1L), width = 0.7) +
    ggplot2::facet_wrap(~measure, scales = "free_x") +
    ggplot2::labs(x = attr(x, "what"), y = NULL, subtitle = sub) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
}
