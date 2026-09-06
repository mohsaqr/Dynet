# ===========================================================================
# Similarity between time bins
# ===========================================================================
# The coefficients themselves are cograph's, which Dynet already imports.
# This verb's job is to turn a temporal network into the sequence of binary
# layers cograph expects and to return the result as a tidy frame rather than
# a bare matrix.

#' Similarity between the networks at each pair of time points
#'
#' @description
#' Compares the edge set at every time bin with the edge set at every other,
#' giving the pairwise similarity matrix as a tidy frame. This answers how
#' much the network at one moment resembles the network at another, which no
#' single-bin measure reports and which the formation and dissolution
#' quantities in [events()] only address between neighbouring bins.
#'
#' Coefficients are computed by `cograph::layer_similarity()`.
#'
#' @param dn A temporal network from [dynet()].
#' @param method One of `"jaccard"` (the default), `"overlap"`, `"hamming"`,
#'   `"cosine"` or `"pearson"`.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end First and last time to measure. Default to the observed
#'   range.
#' @param step,window How often to measure and how much time each measurement
#'   covers. Default to the interval the network was built with. `window =
#'   "all"` is rejected here, because a similarity matrix of one bin against
#'   itself says nothing.
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn, so `plot = TRUE` saves the
#'   wrapping `plot()` call without changing what comes back. Use `plot()` on
#'   the result when the figure needs arguments of its own.
#' @return A `dynet_similarity` data frame with one row per ordered pair of
#'   time bins and columns `time`, `other`, `measure` and `value`. The
#'   diagonal is included and is one for every coefficient except
#'   `"hamming"`, where identical layers differ in nothing and score zero.
#'   `"pearson"` reaches one only to floating-point accuracy, so compare it
#'   with a tolerance rather than with `==`.
#' @examples
#' dn <- dynet(school_contacts)
#' similarity(dn)
#' similarity(dn, method = "cosine")
#' @seealso [snapshots()] for the networks being compared, [events()] for
#'   formation and dissolution between neighbouring bins.
#' @export
similarity <- function(dn, method = c("jaccard", "overlap", "hamming",
                                      "cosine", "pearson"),
                       sessions = c("bounded", "collapse", "separate"),
                       start = NULL, end = NULL, step = NULL, window = NULL, plot = FALSE) {
  .check_dynet(dn, match.arg(sessions))
  method <- match.arg(method)
  if (!requireNamespace("cograph", quietly = TRUE)) {
    stop(errorCondition(
      "Layer similarity is computed by cograph. Install it with install.packages(\"cograph\").",
      class = "dynet_needs_cograph", call = NULL))
  }
  snaps <- as.data.frame(snapshots(dn, sessions = sessions, start = start,
                                   end = end, step = step, window = window))
  times <- sort(unique(snaps$time))
  if (length(times) < 2L) {
    stop(errorCondition(
      "Similarity needs at least two time bins; widen the range or lower `step`.",
      class = "dynet_empty_result", call = NULL))
  }
  nodes <- dn$nodes$name
  layers <- lapply(times, function(t) {
    at <- snaps[snaps$time == t, , drop = FALSE]
    m <- matrix(0, length(nodes), length(nodes),
                dimnames = list(nodes, nodes))
    if (nrow(at)) {
      m[cbind(match(at$from, nodes), match(at$to, nodes))] <- 1
    }
    if (!dn$directed) m <- pmax(m, t(m))
    m
  })
  grid <- expand.grid(i = seq_along(times), j = seq_along(times))
  value <- vapply(seq_len(nrow(grid)), function(k) {
    cograph::layer_similarity(layers[[grid$i[[k]]]], layers[[grid$j[[k]]]],
                              method = method)
  }, numeric(1L))
  out <- data.frame(time = times[grid$i], other = times[grid$j],
                    measure = method, value = value,
                    stringsAsFactors = FALSE, row.names = NULL)
  out <- out[order(out$time, out$other), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "time_unit") <- dn$meta$time_unit
  class(out) <- c("dynet_similarity", "data.frame")
  .maybe_plot(out, plot)
}

#' Tidy table of time-bin similarity
#' @param x A result from [similarity()].
#' @param row.names,optional Ignored.
#' @param ... Ignored.
#' @return A plain data frame, one row per ordered pair of time bins.
#' @export
as.data.frame.dynet_similarity <- function(x, row.names = NULL,
                                           optional = FALSE, ...) {
  out <- x
  attr(out, "time_unit") <- NULL
  class(out) <- "data.frame"
  out
}

#' Print time-bin similarity
#' @param x A result from [similarity()].
#' @param ... Passed to the data frame print method.
#' @return `x`, invisibly.
#' @export
print.dynet_similarity <- function(x, ...) {
  bins <- length(unique(x$time))
  off <- x$value[x$time != x$other]
  cat(sprintf("# %s similarity across %d time bins\n", x$measure[[1L]], bins))
  cat(sprintf("# off-diagonal mean %.3f, range %.3f to %.3f\n",
              mean(off), min(off), max(off)))
  print(utils::head(as.data.frame(x), 10L), ...)
  if (nrow(x) > 10L) cat(sprintf("# %d more rows\n", nrow(x) - 10L))
  invisible(x)
}

#' Draw time-bin similarity as a heatmap
#' @param x A result from [similarity()].
#' @param base_size Base text size.
#' @param ... Ignored.
#' @return A `ggplot` object.
#' @export
plot.dynet_similarity <- function(x, base_size = 12, ...) {
  ggplot2::ggplot(as.data.frame(x)) +
    ggplot2::geom_tile(ggplot2::aes(x = time, y = other, fill = value)) +
    ggplot2::scale_fill_gradient(low = "#DCE9F5", high = "#0072B2",
                                 name = x$measure[[1L]]) +
    ggplot2::labs(
      x = sprintf("Time (%s)", attr(x, "time_unit")),
      y = sprintf("Time (%s)", attr(x, "time_unit")),
      title = sprintf("Network similarity between time bins (%s)",
                      x$measure[[1L]])) +
    ggplot2::coord_fixed() +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"))
}

#' Summarise snapshot similarity
#'
#' @param object A `dynet_similarity` result.
#' @param ... Ignored.
#' @return A plain `data.frame`, one row per bin: `time`, the `mean`, `min`
#'   and `max` similarity to every other bin, and `nearest`, the time of the
#'   most similar other bin. The self-comparison is excluded throughout, so a
#'   bin with no comparable neighbour reports `NaN` and `NA`.
#' @examples
#' summary(similarity(dynet(school_contacts), step = 5, window = 5))
#' @export
summary.dynet_similarity <- function(object, ...) {
  flat <- as.data.frame(object)
  others <- flat[flat$time != flat$other, , drop = FALSE]
  parts <- lapply(sort(unique(flat$time)), function(t) {
    rows <- others[others$time == t, , drop = FALSE]
    data.frame(
      time = t,
      mean = mean(rows$value), min = suppressWarnings(min(rows$value)),
      max = suppressWarnings(max(rows$value)),
      nearest = if (nrow(rows)) rows$other[which.max(rows$value)] else NA_real_
    )
  })
  out <- do.call(rbind, parts)
  # An empty min/max is -Inf/Inf from the base reducers; NA is the honest read.
  out$min[!is.finite(out$min)] <- NA_real_
  out$max[!is.finite(out$max)] <- NA_real_
  rownames(out) <- NULL
  out
}
