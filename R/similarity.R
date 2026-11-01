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
#' @param sessions How to treat sessions when the layers are built:
#'   `"bounded"` (the default) and `"collapse"` differ in whether a session
#'   wall gates a tie into its bin. Unlike [centrality_series()], `"separate"`
#'   adds no `session` column here: layers are keyed on time alone, so two
#'   session-local bins sharing a time are compared as one layer.
#' @param start,end First and last time to measure. Default to the observed
#'   range.
#' @param step How often to measure. Defaults to the interval the network was
#'   built with.
#' @param window How much time each measurement covers. Defaults to `step`.
#'   `window = "all"` measures the whole observed period as a single bin and so
#'   leaves nothing to compare; it raises `dynet_empty_result`, as does any
#'   other grid that yields fewer than two bins.
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn, so `plot = TRUE` saves the
#'   wrapping `plot()` call without changing what comes back. Use `plot()` on
#'   the result when the figure needs arguments of its own.
#' @return A `dynet_similarity` data frame with one row per ordered pair of
#'   time bins and columns `time`, `other`, `measure` and `value`. Every bin
#'   of the grid takes part, including a bin in which no tie is active. The
#'   diagonal is included and is one for every coefficient except
#'   `"hamming"`, where identical layers differ in nothing and score zero.
#'   `"pearson"` reaches one only to floating-point accuracy, so compare it
#'   with a tolerance rather than with `==`. The frame is returned invisibly
#'   when `plot = TRUE` has drawn the figure.
#'
#'   A bin with no tie has an empty edge set, and the ratios are then 0/0:
#'   `"jaccard"` is `NA` between two empty bins (and 0 between an empty and a
#'   non-empty one), while `"overlap"`, `"cosine"` and `"pearson"` are `NA`
#'   wherever an empty bin takes part, its own diagonal cell included.
#'   `"pearson"` is likewise `NA` for a complete layer, which has no variance.
#'   `"hamming"` is always defined.
#'
#' @details
#' Each bin is read as the vector of its eligible pairs: every ordered pair of
#' distinct vertices for a directed network, every unordered pair for an
#' undirected one. Loops are excluded, as in [turnover()] and
#' [persistence()], and a pair is tied in a bin or it is not. On that domain
#' `"hamming"` is the number of pairs whose tie state differs, and
#' `"pearson"` is the graph correlation of `sna::gcor()` with its default
#' `diag = FALSE`; `"hamming"` likewise equals `sna::hdist()`. Counting the
#' structurally empty diagonal, or both triangles of a symmetric matrix,
#' would inflate the Hamming count twofold and bias the correlation.
#'
#'   The coefficients come from cograph, which is a hard dependency of Dynet;
#'   a namespace that cannot be loaded raises `dynet_needs_cograph`.
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
  .check_dynet(dn, .match_choice(sessions))
  method <- .match_choice(method)
  if (!requireNamespace("cograph", quietly = TRUE)) {
    stop(errorCondition(
      "Layer similarity is computed by cograph. Install it with install.packages(\"cograph\").",
      class = c("dynet_needs_cograph", "dynet_bad_input"), call = NULL))
  }
  snaps <- as.data.frame(snapshots(dn, sessions = sessions, start = start,
                                   end = end, step = step, window = window))
  # The grid, not the snapshot rows, decides which bins exist: a bin with no
  # tie has no rows, and keying on the rows would silently drop it.
  bins <- .measure_bin_times(dn, sessions, start, end, step, window)
  times <- sort(unique(unlist(bins, use.names = FALSE)))
  if (length(times) < 2L) {
    stop(errorCondition(
      "Similarity needs at least two time bins; widen the range or lower `step`.",
      class = c("dynet_empty_result", "dynet_bad_input"), call = NULL))
  }
  cells <- lapply(.binary_layers(dn, snaps, times), .pair_cells,
                  directed = dn$directed)
  grid <- expand.grid(i = seq_along(times), j = seq_along(times))
  value <- vapply(seq_len(nrow(grid)), function(k) {
    one <- cells[[grid$i[[k]]]]
    two <- cells[[grid$j[[k]]]]
    # A layer with every cell equal has no variance, so Pearson's r is 0/0.
    # Say so directly instead of letting stats::cor() warn and return NA.
    if (identical(method, "pearson") &&
        (length(unique(one)) < 2L || length(unique(two)) < 2L)) {
      return(NA_real_)
    }
    cograph::layer_similarity(one, two, method = method)
  }, numeric(1L))
  out <- data.frame(time = times[grid$i], other = times[grid$j],
                    measure = method, value = value,
                    stringsAsFactors = FALSE, row.names = NULL)
  out <- out[order(out$time, out$other), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "time_unit") <- dn$meta$time_unit
  attr(out, "empty_bins") <- times[vapply(cells, function(v) !any(v > 0),
                                          logical(1L))]
  attr(out, "pair_domain") <- if (dn$directed) {
    "eligible_nonloop_ordered_pairs"
  } else "eligible_nonloop_unordered_dyads"
  class(out) <- c("dynet_similarity", "data.frame")
  .maybe_plot(out, plot)
}

#' Tidy table of time-bin similarity
#' @param x A result from [similarity()].
#' @param row.names,optional Ignored; present for compatibility with the
#'   generic.
#' @param ... Ignored.
#' @return A plain `data.frame`, one row per ordered pair of time bins, with
#'   columns `time`, `other`, `measure` and `value`.
#' @examples
#' dn <- dynet(school_contacts)
#' resemblance <- similarity(dn, step = 4, window = 4)
#' as.data.frame(resemblance)
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
#' @examples
#' dn <- dynet(school_contacts)
#' resemblance <- similarity(dn, step = 4, window = 4)
#' resemblance
#' @export
print.dynet_similarity <- function(x, ...) {
  bins <- length(unique(x$time))
  off <- x$value[x$time != x$other]
  defined <- off[!is.na(off)]
  cat(sprintf("# %s similarity across %d time bins\n", x$measure[[1L]], bins))
  if (length(defined)) {
    cat(sprintf("# off-diagonal mean %.3f, range %.3f to %.3f\n",
                mean(defined), min(defined), max(defined)))
  }
  if (length(defined) < length(off)) {
    cat(sprintf("# %d off-diagonal pair%s undefined (NA): a bin with no tie\n",
                length(off) - length(defined),
                if (length(off) - length(defined) == 1L) " is" else "s are"))
  }
  print(utils::head(as.data.frame(x), 10L), ...)
  if (nrow(x) > 10L) cat(sprintf("# %d more rows\n", nrow(x) - 10L))
  invisible(x)
}

#' Draw time-bin similarity as a heatmap
#' @param x A result from [similarity()].
#' @param base_size Base text size. Defaults to twelve.
#' @param ... Ignored.
#' @return A `ggplot` object. Drawing happens when that object is printed, so
#'   the plot is the return value here rather than a side effect.
#' @examples
#' dn <- dynet(school_contacts)
#' bin_similarity <- similarity(dn, step = 5, window = 5)
#' plot(bin_similarity)
#' @export
plot.dynet_similarity <- function(x, base_size = 12, ...) {
  ggplot2::ggplot(as.data.frame(x)) +
    ggplot2::geom_tile(ggplot2::aes(x = time, y = other, fill = value)) +
    ggplot2::scale_fill_gradient(low = .tint("#0072B2", 0.14), high = "#0072B2",
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
#' dn <- dynet(school_contacts)
#' bin_similarity <- similarity(dn, step = 5, window = 5)
#' summary(bin_similarity)
#' @export
summary.dynet_similarity <- function(object, ...) {
  flat <- as.data.frame(object)
  others <- flat[flat$time != flat$other, , drop = FALSE]
  parts <- lapply(sort(unique(flat$time)), function(t) {
    rows <- others[others$time == t, , drop = FALSE]
    # A bin with no comparable neighbour has nothing to reduce; NA is the
    # honest read, where min()/max() would warn and return Inf.
    has <- nrow(rows) > 0L
    data.frame(
      time = t,
      mean = mean(rows$value),
      min = if (has) min(rows$value) else NA_real_,
      max = if (has) max(rows$value) else NA_real_,
      nearest = if (has && any(!is.na(rows$value))) {
        rows$other[which.max(rows$value)]
      } else NA_real_
    )
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

#' Bin times of the measurement grid, empty bins included
#'
#' `snapshots()` returns one row per active pair, so a bin in which nothing is
#' tied leaves no row behind. Any verb that compares consecutive bins must take
#' its bins from the grid itself, or an empty bin vanishes and the bins either
#' side of it are silently treated as neighbours.
#'
#' @param dn A `dynet` object.
#' @param sessions The matched session mode.
#' @param start,end,step,window The grid arguments, as `snapshots()` takes them.
#' @return A named list of sorted numeric bin times, one element per block
#'   `snapshots()` measures: `all` unless `sessions = "separate"`, else one per
#'   session label.
#' @noRd
.measure_bin_times <- function(dn, sessions, start, end, step, window) {
  spec <- .window_spec(dn, start, end, step, window)
  lapply(.split_sessions(dn, sessions), function(enc) {
    sort(unique(.grid_for(enc, dn, spec)$time))
  })
}

#' Pair each block's grid bins with its snapshot rows
#'
#' @param snaps The tidy frame from `snapshots()`.
#' @param bins The list from `.measure_bin_times()`.
#' @param sessions The matched session mode.
#' @return A named list of `list(label, times, snaps)`, one per block.
#' @noRd
.measure_blocks <- function(snaps, bins, sessions) {
  separate <- identical(sessions, "separate") && "session" %in% names(snaps)
  Map(function(times, label) {
    rows <- if (separate) {
      snaps[snaps$session == label, , drop = FALSE]
    } else snaps
    list(label = label, times = times, snaps = rows)
  }, bins, names(bins))
}

#' The eligible pair cells of a layer, as a one-column matrix
#'
#' @param m A square binary layer.
#' @param directed Whether ordered pairs are the domain.
#' @return A one-column numeric matrix: the off-diagonal cells when directed,
#'   the strict upper triangle when not.
#' @noRd
.pair_cells <- function(m, directed) {
  mask <- if (directed) row(m) != col(m) else upper.tri(m)
  matrix(m[mask], ncol = 1L)
}

#' Binary adjacency layers, one per time bin
#'
#' Shared by `similarity()` and `persistence()` so the two read the same
#' network. A cell is 1 when the pair is tied in that bin, whatever its weight
#' or spell count: both measures are defined on the edge set, not on strength.
#'
#' @param dn A `dynet` object, for the vertex universe and directedness.
#' @param snaps The tidy frame from `snapshots()`, with `time`, `from`, `to`.
#' @param times Bin midpoints to build, in order.
#' @param symmetrise Whether to fold the matrix onto its transpose. Defaults to
#'   folding exactly when the network is undirected; `persistence()` passes
#'   `TRUE` regardless, because topological overlap is defined on undirected
#'   neighbourhoods.
#' @return A list of square numeric matrices, one per bin, with the full vertex
#'   universe as dimnames in `dn$nodes$name` order.
#' @examples
#' dn <- dynet(school_contacts)
#' snaps <- as.data.frame(snapshots(dn))
#' str(Dynet:::.binary_layers(dn, snaps, sort(unique(snaps$time))[1:2]))
#' @noRd
.binary_layers <- function(dn, snaps, times, symmetrise = !dn$directed) {
  nodes <- dn$nodes$name
  lapply(times, function(t) {
    at <- snaps[snaps$time == t, , drop = FALSE]
    m <- matrix(0, length(nodes), length(nodes),
                dimnames = list(nodes, nodes))
    if (nrow(at)) {
      m[cbind(match(at$from, nodes), match(at$to, nodes))] <- 1
    }
    if (symmetrise) m <- pmax(m, t(m))
    m
  })
}
