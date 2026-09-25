# ===========================================================================
# dynet_metric — the one tidy result class every verb returns
# ===========================================================================

#' Wrap a long data frame as a temporal measure
#'
#' @param df Long data frame with `measure` and `value` and, depending on
#'   `level`, `time`, `node`, `session` or edge endpoints.
#' @param level One of `"node"`, `"graph"` or `"edge"`, naming what a row is
#'   about. Only these three are produced; the value is carried on the result
#'   and read back by the print, summary and plot methods.
#' @param what Short human name of the quantity, used in printing.
#' @param dn The network the measure came from.
#' @param note Optional single line shown under the header.
#' @param spec The resolved measurement grid from `.window_spec()`, when the
#'   measure was taken on one.
#' @param mode The direction convention used, when it applied.
#' @param traversal_time Per-hop traversal duration for temporal paths.
#' @return An object of class `c("dynet_metric", "data.frame")`.
#' @noRd
.metric <- function(df, level, what, dn, note = NULL, spec = NULL,
                    mode = NULL, traversal_time = NULL) {
  # A session column that is entirely absent of sessions is noise; drop it.
  if ("session" %in% names(df) && all(is.na(df$session) | df$session == "all")) {
    df$session <- NULL
  }
  front <- intersect(c("session", "time", "node", "vertex_spell", "implicit",
                       "from", "to", "raw_spell", "measure", "value"),
                     names(df))
  df <- df[, c(front, setdiff(names(df), front)), drop = FALSE]
  rownames(df) <- NULL
  structure(df,
    class     = c("dynet_metric", "data.frame"),
    level     = level,
    what      = what,
    note      = note,
    time_unit = dn$meta$time_unit,
    interval  = dn$meta$interval,
    step      = spec$step,
    window    = spec$window,
    mode      = mode,
    traversal_time = traversal_time,
    n_nodes   = nrow(dn$nodes),
    nodes     = dn$nodes$name,
    directed  = dn$directed,
    net_format = dn$meta$format
  )
}
#' Rank vertices by their mean measured value
#'
#' A vertex outside its activity spell, or a bin the grid never defined,
#' contributes a missing value rather than a measured zero. `sort()` drops
#' those silently, which made `top =` return fewer vertices than asked for --
#' and none at all when every vertex had one undefined bin. Rank over the
#' defined values only, exactly as `summary.dynet_metric()` does, and keep a
#' vertex with nothing defined in the ordering, last, so the count stays
#' honest.
#' @param value Numeric measured values.
#' @param node Vertex name for each value.
#' @return A named numeric vector of mean values, largest first, with
#'   `NA_real_` entries last. One element per distinct vertex.
#' @noRd
.node_rank <- function(value, node) {
  means <- vapply(split(value, node), function(v) {
    defined <- v[!is.na(v)]
    if (length(defined)) mean(defined) else NA_real_
  }, numeric(1L))
  sort(means, decreasing = TRUE, na.last = TRUE)
}


#' Tidy data frame of a temporal measure
#'
#' @param x A `dynet_metric` produced by any measurement verb.
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param layout `"long"` gives one row per observation, which is the default
#'   and the shape every other verb expects. `"wide"` spreads time across
#'   columns, giving one row per vertex (or per measure for graph-level
#'   quantities), which is convenient for exporting a table. A measure with
#'   no time axis, such as reachability, is spread by measure instead: one
#'   row per vertex with one column per measure.
#' @param what `"values"`, the default, gives the measured values.
#'   `"diagnostics"` gives the record a prestige computation keeps when it
#'   cannot produce a value, which is what the accompanying warning refers to:
#'   one row per reporting block that was undefined, infeasible or
#'   nonconverged, with `session`, `time`, `stage`, `status` and `reason`,
#'   the solver's `iterations` and `residual`, the `balance_*` family for the
#'   row-column scaling step, and `spectral_radius`, `eigenspace_dimension`
#'   and `eigen_residual` for the eigen step. A result with nothing to report
#'   gives a zero-row frame of those same columns rather than `NULL`.
#' @param top Keep only the `top` vertices with the largest mean value, and
#'   order the result from largest to smallest. A single positive number;
#'   `NULL`, the default, keeps every row in the measure's own order. It
#'   selects vertices, so it applies to `what = "values"` on a measure that
#'   has a `node` column; anything else raises a `dynet_bad_input` error.
#' @param ... Ignored.
#'
#' @return A plain `data.frame`. Long layout carries `measure` and `value`
#'   with one row per observation, alongside whichever columns say what was
#'   measured: `session` when the network has sessions, `time` for anything
#'   measured on a grid of bins, `node` for a vertex-level quantity, `from`
#'   and `to` for a pair-level one, `raw_spell` for per-spell edge durations
#'   and `vertex_spell` with `implicit` for per-spell vertex durations from
#'   [durations()], and `from_group` and `to_group` for [mixing()]. A
#'   graph-level series carries `time`, `measure` and `value` alone.
#'
#'   Wide layout puts the identifying columns first and spreads what varies
#'   across the rest. A measure taken on a grid of bins spreads time: one
#'   column per bin, named `t` followed by the bin's time, leaving one row per
#'   vertex and measure. A measure with no time axis, such as reachability,
#'   spreads the measures instead: one column per measure, leaving one row per
#'   vertex. A measure with no time axis and only one measure is already wide
#'   and comes back unchanged.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' degree <- centrality_series(dn, measure = "degree")
#' as.data.frame(degree)
#' as.data.frame(degree, layout = "wide")
#' as.data.frame(degree, top = 5)
#' as.data.frame(degree, what = "diagnostics")
#'
#' @export
as.data.frame.dynet_metric <- function(x, row.names = NULL, optional = FALSE,
                                       layout = c("long", "wide"),
                                       what = c("values", "diagnostics"),
                                       top = NULL, ...) {
  layout <- match.arg(layout)
  if (!is.null(top)) {
    .check("`top` must be one positive number." =
             length(top) == 1L && is.numeric(top) && is.finite(top) && top >= 1)
    frame <- as.data.frame(x, layout = "long", what = what)
    if (!"node" %in% names(frame)) {
      stop(errorCondition("`top` selects vertices, so it needs a node-level measure.",
                          class = "dynet_bad_input", call = NULL))
    }
    rank <- .node_rank(frame$value, frame$node)
    keep <- names(rank)[seq_len(min(top, length(rank)))]
    trimmed <- x[frame$node %in% keep, , drop = FALSE]
    attributes(trimmed) <- c(attributes(trimmed),
                             attributes(x)[setdiff(names(attributes(x)),
                                                   names(attributes(trimmed)))])
    class(trimmed) <- class(x)
    out <- as.data.frame(trimmed, layout = layout, what = what)
    out <- out[order(match(out$node, keep)), , drop = FALSE]
    rownames(out) <- NULL
    return(out)
  }
  what <- match.arg(what)
  if (identical(what, "diagnostics")) {
    found <- attr(x, "prestige_diagnostics")
    if (is.null(found)) {
      # A typed empty frame rather than NULL, so a caller can bind, count or
      # print the result without first testing whether anything was recorded.
      # The schema mirrors the single builder in `.prestige_values()`; a test
      # asserts the two agree, so this cannot drift away from it silently.
      return(data.frame(
        session = character(), time = numeric(), stage = character(),
        status = character(), reason = character(), iterations = integer(),
        residual = numeric(), balance_status = character(),
        balance_reason = character(), balance_iterations = integer(),
        balance_residual = numeric(), spectral_radius = numeric(),
        eigenspace_dimension = integer(), eigen_residual = numeric(),
        stringsAsFactors = FALSE
      ))
    }
    rownames(found) <- NULL
    return(found)
  }
  df <- x
  attributes(df) <- list(names = names(x), row.names = seq_len(nrow(x)),
                         class = "data.frame")
  if (identical(layout, "long")) return(df)
  if (!"time" %in% names(df)) {
    # No time axis: one column per measure instead.
    if (length(unique(df$measure)) < 2L) return(df)
    id_cols <- intersect(c("session", "node", "from", "to"), names(df))
    wide <- stats::reshape(
      df[, c(id_cols, "measure", "value"), drop = FALSE],
      idvar = id_cols, timevar = "measure", direction = "wide", sep = "_"
    )
    names(wide) <- sub("^value_", "", names(wide))
    rownames(wide) <- NULL
    return(wide)
  }

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
#' @examples
#' dn <- dynet(school_contacts)
#' degree <- centrality_series(dn, step = 4, window = 4)
#' degree
#' print(degree, n = 4)
#' @export
print.dynet_metric <- function(x, n = 12L, ...) {
  what <- attr(x, "what")
  lvl  <- attr(x, "level")
  unit <- attr(x, "time_unit")
  meas <- unique(x$measure)
  # A fragment left by head()/tail() still describes the series it came from,
  # so the header counts come from the record rather than the retained rows.
  frag <- attr(x, "fragment")
  n_distinct <- function(column) {
    if (is.null(frag)) length(unique(x[[column]])) else frag$counts[[column]]
  }

  cat(sprintf("# %s (%s-level)\n", what, lvl))
  bits <- character()
  if ("node" %in% names(x)) {
    bits <- c(bits, sprintf("%d vertices", n_distinct("node")))
  }
  if ("time" %in% names(x)) {
    step   <- attr(x, "step")   %||% attr(x, "interval")
    window <- attr(x, "window") %||% step
    # Naming the window only when it differs from the step keeps the common
    # case short and makes a rolling window impossible to miss.
    shape <- if (window == 0) {
      sprintf("step %s, sampled at each point", format(step))
    } else if (isTRUE(all.equal(window, step))) {
      sprintf("%s per bin", format(step))
    } else {
      sprintf("step %s, window %s (rolling)", format(step), format(window))
    }
    bits <- c(bits, sprintf("%d time points, %s",
                            n_distinct("time"), shape))
  }
  if (!is.null(attr(x, "mode"))) {
    bits <- c(bits, sprintf("mode %s", attr(x, "mode")))
  }
  traversal_time <- attr(x, "traversal_time")
  if (!is.null(traversal_time) && traversal_time > 0) {
    bits <- c(bits, sprintf("traversal %s %s per hop",
                            format(traversal_time), unit))
  }
  if ("session" %in% names(x)) {
    bits <- c(bits, sprintf("%d sessions", n_distinct("session")))
  }
  bits <- c(bits, sprintf("time in %s", unit))
  cat("# ", paste(bits, collapse = " | "), "\n", sep = "")
  if (length(meas) > 1L) {
    cat("# measures: ", paste(meas, collapse = ", "), "\n", sep = "")
  }
  if (!is.null(frag)) {
    cat(sprintf("# %s %d of %d rows\n", frag$side, nrow(x), frag$counts$rows))
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

#' Record that a measure has been truncated
#'
#' `head()` and `tail()` keep the measure's class, so the print method would
#' otherwise recompute its header from the retained rows and report a fragment
#' as if it were the whole series. This stores the source counts once, and
#' keeps the first record when a fragment is truncated again.
#'
#' @param x The source `dynet_metric`.
#' @param out The truncated object.
#' @param side `"first"` or `"last"`.
#' @return `out`, carrying a `fragment` attribute.
#' @noRd
.metric_fragment <- function(x, out, side) {
  attr(out, "fragment") <- attr(x, "fragment") %||% list(
    side = side,
    counts = list(
      rows = nrow(x),
      time = length(unique(x$time)),
      node = length(unique(x$node)),
      session = length(unique(x$session))
    )
  )
  out
}

#' First rows of a temporal measure
#'
#' Truncates the rows without rewriting what the measure is. The printed
#' header still describes the series the rows came from, and a `first n of N
#' rows` line records the truncation.
#'
#' @param x A `dynet_metric`.
#' @param n Number of rows to keep. Defaults to six.
#' @param ... Passed to the default method.
#' @return A `dynet_metric` with at most `n` rows, carrying the source counts
#'   so its header stays true to the series.
#' @examples
#' dn <- dynet(school_contacts)
#' degree <- centrality_series(dn, step = 4, window = 4)
#' head(degree)
#' @export
head.dynet_metric <- function(x, n = 6L, ...) {
  .metric_fragment(x, NextMethod(), "first")
}

#' Last rows of a temporal measure
#'
#' The counterpart of [head.dynet_metric()]; the header still describes the
#' series and a `last n of N rows` line records the truncation.
#'
#' @param x A `dynet_metric`.
#' @param n Number of rows to keep. Defaults to six.
#' @param ... Passed to the default method.
#' @return A `dynet_metric` with at most `n` rows, carrying the source counts
#'   so its header stays true to the series.
#' @examples
#' dn <- dynet(school_contacts)
#' degree <- centrality_series(dn, step = 4, window = 4)
#' tail(degree)
#' @export
tail.dynet_metric <- function(x, n = 6L, ...) {
  .metric_fragment(x, NextMethod(), "last")
}

#' Summarise a temporal measure
#'
#' Collapses the time dimension. Node-level measures are summarised one row
#' per vertex and measure; graph-level measures one row per measure. The peak
#' time is reported alongside, because when a quantity peaked is usually the
#' question a temporal network is being asked.
#'
#' @param object A `dynet_metric`.
#' @param by Grouping for the summary: `"node"`, `"time"` or `"measure"`. The
#'   default, `NULL`, groups by `"node"` when the measure has a `node` column
#'   and by `"measure"` otherwise. A `session` column, when the measure has
#'   one, and `measure` itself are always part of the grouping as well. A
#'   grouping the measure has no column for -- `"node"` on a graph-level
#'   series, say -- is dropped rather than raising, leaving the grouping the
#'   measure does carry.
#' @param ... Ignored.
#'
#' @return A `data.frame` with the grouping columns plus `n`, `mean`, `sd`,
#'   `min`, `max` and, when time is available, `peak_time`. `n` counts the
#'   measured values the statistics were computed from, so a vertex that was
#'   inactive for part of the calendar reports fewer than the number of time
#'   points.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' degree <- centrality_series(dn, measure = "degree")
#' summary(degree)
#' summary(degree, by = "time")
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
      # Count what the statistics actually used. A vertex outside its
      # activity spell contributes a missing value, not a measured zero, and
      # reporting the row count here would advertise observations that no
      # mean or sd was computed from.
      out$n    <- length(ok)
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

#' Which rows of a metric frame does `highlight` select?
#'
#' A series is highlighted when its grouping value (vertex or measure name) is
#' named, or, for a mixing table carrying `from_group` and `to_group`, when
#' either endpoint group is named. `NULL` highlights everything. A `highlight`
#' that matches no series is a mistake and is reported as one.
#'
#' @param df The plain data frame of a `dynet_metric`, with a `.grp` column.
#' @param highlight Character vector or `NULL`.
#' @return Logical vector, one entry per row of `df`.
#' @noRd
.highlight_rows <- function(df, highlight) {
  if (is.null(highlight)) return(rep(TRUE, nrow(df)))
  stopifnot("`highlight` must be a character vector" = is.character(highlight))
  hit <- df$.grp %in% highlight
  if (all(c("from_group", "to_group") %in% names(df))) {
    hit <- hit | df$from_group %in% highlight | df$to_group %in% highlight
  }
  if (!any(hit)) {
    stop(errorCondition(
      sprintf("`highlight` matches no series: %s.",
              paste(sQuote(highlight), collapse = ", ")),
      class = c("dynet_unknown_highlight", "dynet_bad_input"), call = NULL))
  }
  hit
}

#' Plot a temporal measure
#'
#' Draws the quantity against time. Node-level measures are drawn as one line
#' per vertex; graph-level measures as one line per measure. Distinctions are
#' carried by colour and line type together, never by colour alone.
#'
#' A measure with no time axis, such as reachability or [durations()], has no
#' trajectory to draw and is shown as a bar panel instead, one bar per vertex
#' or pair and one facet per measure. `type` and `highlight` have nothing to
#' act on there and are ignored.
#'
#' @param x A `dynet_metric`.
#' @param type `"line"` for trajectories over time, `"heatmap"` for a
#'   vertex-by-time tile plot, `"ridge"` for small multiples per measure.
#'   Ignored for a measure with no time axis.
#' @param highlight Optional character vector naming the series to draw in
#'   colour, with everything else in grey: vertex names for a node-level
#'   measure, measure names for a graph-level one. For a [mixing()] result a
#'   group name selects every flow into or out of that group, so
#'   `highlight = "Teacher"` colours the teacher rows and columns of the mixing
#'   table. A name that matches nothing raises an error of class
#'   `dynet_unknown_highlight`. Ignored for a measure with no time axis.
#' @param top How many rows to draw. For a measure taken over time, the `top`
#'   vertices with the largest mean value; `NULL`, the default, draws every
#'   vertex. For a measure with no time axis, the `top` rows with the largest
#'   absolute value, defaulting to `30`, with a subtitle naming how many of
#'   how many are shown.
#' @param palette Colours for the series: `"okabe"` (the default),
#'   `"extended"`, `"many"`, your own vector of colours, or a function of `n`.
#' @param base_size Base font size.
#' @param ... Ignored.
#'
#' @return A `ggplot` object. Drawing happens when that object is printed, so
#'   the plot is the return value here rather than a side effect.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' degree <- centrality_series(dn, measure = "degree")
#' plot(degree, top = 5)
#' plot(degree, palette = "extended")
#'
#' @export
plot.dynet_metric <- function(x, type = c("line", "heatmap", "ridge"),
                              highlight = NULL, top = NULL,
                              palette = "okabe", base_size = 12, ...) {
  type <- match.arg(type)
  .dyn_palette(palette, 1L)
  df <- as.data.frame(x)
  if (!"time" %in% names(df)) {
    return(.plot_no_time(df, x, base_size, top = top %||% 30L,
                         palette = palette))
  }
  has_node <- "node" %in% names(df)

  if (has_node && !is.null(top)) {
    rank <- .node_rank(df$value, df$node)
    keep <- names(rank)[seq_len(min(top, length(rank)))]
    df <- df[df$node %in% keep, , drop = FALSE]
  }

  if (identical(type, "heatmap")) return(.plot_heatmap(df, x, has_node, base_size))

  grp <- if (has_node) "node" else "measure"
  df$.grp <- df[[grp]]
  df$.hl <- .highlight_rows(df, highlight)
  n_hl <- length(unique(df$.grp[df$.hl]))

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
      ggplot2::scale_colour_manual(values = .dyn_palette(palette, n_hl),
                                   name = NULL) +
      ggplot2::scale_linetype_manual(values = rep(1:6, length.out = n_hl),
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

#' Strip label for a measure name
#' @param measure Character measure names such as `forward_reach_count`.
#' @return The names with underscores as spaces.
#' @noRd
.measure_strip <- function(measure) gsub("_", " ", measure, fixed = TRUE)

#' Heatmap panel for a temporal measure
#' @param df Long data frame.
#' @param x The originating metric, for labels.
#' @param has_node Whether the measure is node-level.
#' @param base_size Base font size.
#' @return A `ggplot` object.
#' @noRd
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
#' @noRd
.finite_median <- function(v) {
  v <- v[is.finite(v)]
  if (length(v) == 0L) 0 else stats::median(v)
}

#' Label a vertex pair for a plot
#'
#' Deliberately ASCII. The arrow and en dash this replaced render as
#' `mbcsToSbcs` warnings and substituted glyphs on the `pdf()` and
#' `postscript()` devices, which is the path `R CMD check` takes to build the
#' manual, and they fail outright under a non-UTF-8 locale. The device is only
#' known when a plot is drawn, not when it is built, so there is no honest
#' place to choose the prettier glyph.
#'
#' @param from,to Endpoint labels.
#' @param directed Whether the pair is ordered.
#' @return A character vector of pair labels.
#' @noRd
.pair_label <- function(from, to, directed) {
  paste(from, if (isTRUE(directed)) "->" else "-", to)
}

#' Bar panel for a measure with no time dimension
#' @param df Long data frame.
#' @param x The originating metric, for labels.
#' @param base_size Base font size.
#' @param top Largest number of rows to draw, ranked by the largest absolute
#'   value each row reaches. A row holding an infinite value ranks first.
#' @param palette Palette specification, as in [plot.dynet()].
#' @return A `ggplot` object.
#' @noRd
.plot_no_time <- function(df, x, base_size, top = 30L, palette = "okabe") {
  df$.row <- if ("node" %in% names(df)) {
    df$node
  } else if (all(c("from", "to") %in% names(df))) {
    .pair_label(df$from, df$to, isTRUE(attr(x, "directed")))
  } else {
    df$measure
  }

  sub <- NULL
  n_row <- length(unique(df$.row))
  if (n_row > top) {
    rank <- vapply(split(abs(df$value), df$.row), function(v) {
      if (any(is.infinite(v))) return(Inf)
      v <- v[is.finite(v)]
      if (length(v) == 0L) 0 else max(v)
    }, numeric(1L))
    keep <- names(sort(rank, decreasing = TRUE))[seq_len(top)]
    df <- df[df$.row %in% keep, , drop = FALSE]
    sub <- sprintf("%d largest of %d shown", top, n_row)
  }

  # A node-level result colours each bar by its vertex, in the network's own
  # order, so the bar carries the same colour the vertex has in every other
  # view; the axis label names it, so colour is never the only channel. Pair
  # and graph-level results have no vertex to follow and take one colour.
  by_node <- "node" %in% names(df)
  vertices <- attr(x, "nodes") %||% sort(unique(df$.row))
  fill_scale <- if (by_node) {
    ggplot2::scale_fill_manual(values = .vertex_colours(vertices, palette),
                               guide = "none")
  } else NULL
  ggplot2::ggplot(df, ggplot2::aes(x = value,
                                   y = stats::reorder(.row, value))) +
    (if (by_node) ggplot2::geom_col(ggplot2::aes(fill = .row), width = 0.7)
     else ggplot2::geom_col(fill = .dyn_palette(palette, 1L), width = 0.7)) +
    fill_scale +
    ggplot2::facet_wrap(~measure, scales = "free_x",
                        labeller = ggplot2::as_labeller(.measure_strip)) +
    ggplot2::labs(x = attr(x, "what"), y = NULL, subtitle = sub) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
}
