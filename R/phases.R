# ===========================================================================
# Temporal phases: regimes found by clustering the between-bin similarity
#
# This rides on similarity(), which already returns the bin-by-bin matrix and
# already plots it. Nothing here is stochastic: hclust is deterministic and
# the contiguous partition is solved exactly, so unlike temporal_communities()
# no seeding is needed and none is offered.
# ===========================================================================

#' Turn a similarity frame into a square distance matrix
#'
#' @param s A `dynet_similarity` frame for one block.
#' @param method The similarity method used, which decides the conversion.
#' @param possible Number of vertex pairs that could carry a tie, used to put
#'   the Hamming count on the unit scale.
#' @return A symmetric numeric matrix with the bin times as dimnames.
#' @keywords internal
.similarity_distance <- function(s, method, possible) {
  times <- sort(unique(c(s$time, s$other)))
  d <- matrix(0, length(times), length(times),
              dimnames = list(format(times), format(times)))
  d[cbind(match(s$time, times), match(s$other, times))] <- s$value
  # Every method but Hamming reports agreement, whose diagonal is one;
  # Hamming already reports disagreement, whose diagonal is zero. Subtracting
  # it from one as well would invert the result and look entirely plausible.
  d <- if (identical(method, "hamming")) {
    if (possible > 0) d / possible else d
  } else {
    1 - d
  }
  d <- (d + t(d)) / 2
  diag(d) <- 0
  d
}

#' Optimal partition of a series into contiguous segments
#'
#' Fisher's (1958) dynamic program. Unlike cutting a dendrogram, this is
#' globally optimal and deterministic, and it cannot return a phase that
#' stops and starts again.
#'
#' @param d A symmetric distance matrix over bins in time order.
#' @param k Number of segments.
#' @return A list with `phase` (integer segment label per bin) and `cost`
#'   (the achieved total within-segment cost).
#' @examples
#' d <- as.matrix(dist(c(0, 0.1, 5, 5.2)))
#' Dynet:::.fisher_partition(d, 2L)$phase
#' @keywords internal
.fisher_partition <- function(d, k) {
  n <- nrow(d)
  square <- d^2
  # cost[i, j] is the within-segment scatter of bins i..j: the sum of squared
  # distances inside it over its size, which is the Ward criterion.
  cost <- matrix(Inf, n, n)
  for (i in seq_len(n)) {                     # running sum, so incremental
    running <- 0
    cost[i, i] <- 0
    for (j in seq.int(i, n)) {
      if (j > i) {
        running <- running + sum(square[seq.int(i, j - 1L), j])
        cost[i, j] <- running / (j - i + 1L)
      }
    }
  }
  best <- matrix(Inf, k, n)
  cut <- matrix(0L, k, n)
  best[1L, ] <- cost[1L, ]
  # Segment count by segment count: each row needs the row below it.
  for (segments in seq_len(k)[-1L]) {
    for (j in seq.int(segments, n)) {
      starts <- seq.int(segments, j)
      total <- best[segments - 1L, starts - 1L] + cost[cbind(starts, j)]
      pick <- which.min(total)
      best[segments, j] <- total[[pick]]
      cut[segments, j] <- starts[[pick]]
    }
  }
  phase <- integer(n)
  right <- n
  # Walk the recorded cut points back from the end.
  for (segments in rev(seq_len(k))) {
    left <- if (segments == 1L) 1L else cut[segments, right]
    phase[seq.int(left, right)] <- segments
    right <- left - 1L
  }
  list(phase = phase, cost = best[k, n])
}

#' Silhouette width of every point under a partition
#'
#' Rousseeuw (1987), computed straight from the distance matrix. A point in a
#' singleton cluster has no within-cluster distance to average, so its width
#' is `NA` rather than a manufactured zero.
#'
#' @param d A symmetric distance matrix.
#' @param phase Integer cluster label per point.
#' @return A numeric vector of widths, one per point.
#' @examples
#' d <- as.matrix(dist(c(0, 0.1, 5, 5.2)))
#' Dynet:::.silhouette(d, c(1L, 1L, 2L, 2L))
#' @keywords internal
.silhouette <- function(d, phase) {
  clusters <- sort(unique(phase))
  vapply(seq_along(phase), function(i) {
    mine <- phase[[i]]
    inside <- which(phase == mine & seq_along(phase) != i)
    if (!length(inside)) return(NA_real_)
    a <- mean(d[i, inside])
    others <- clusters[clusters != mine]
    if (!length(others)) return(NA_real_)
    b <- min(vapply(others, function(other) mean(d[i, phase == other]),
                    numeric(1L)))
    if (max(a, b) <= 0) 0 else (b - a) / max(a, b)
  }, numeric(1L))
}

#' Detect temporal phases by clustering the between-bin similarity
#'
#' @description
#' A similarity heatmap invites the question "so how many regimes are there,
#' and where does each begin". This answers it: cluster the bins by how alike
#' their networks are, and report the blocks.
#'
#' It is the other way of thinking about temporal structure from
#' [temporal_communities()]. That one asks which vertices group together and
#' lets the grouping change over time; this one asks which *moments* group
#' together and does not look at vertices at all.
#'
#' @param dn A temporal network from [dynet()].
#' @param k Number of phases. `NULL` chooses it by the silhouette maximum over
#'   `2:k_max` and reports the whole profile, so the choice is visible and its
#'   sensitivity checkable.
#' @param method How to compare two bins, passed to [similarity()].
#' @param linkage Agglomeration method for [stats::hclust()], used only when
#'   `contiguous = FALSE`.
#' @param contiguous `TRUE`, the default and the temporally meaningful choice,
#'   forces each phase to be an unbroken stretch of time and solves that
#'   partition exactly. `FALSE` lets a phase recur, which is what cyclic data
#'   such as weekday-and-weekend needs.
#' @param k_max Largest number of phases to consider when `k` is `NULL`.
#' @param sessions How to treat sessions.
#' @param start,end First and last bin times.
#' @param step Spacing between bin starts.
#' @param window Width represented by each bin.
#'
#' @return A `dynet_phases` frame, one row per time bin: `session` (only when
#'   the network has sessions), `time`, `phase`, `boundary` (is this the first
#'   bin of its phase) and `silhouette` (this bin's width under the chosen
#'   `k`). Print it, [plot()] it, or take the plain frame with
#'   [as.data.frame()], which also serves `what = "profile"` for the
#'   \eqn{k}-by-\eqn{k} sensitivity table and `what = "phases"` for one row
#'   per phase.
#'
#' @details
#' The distance between two bins is `1 - similarity` for every method except
#' `"hamming"`, which already reports disagreement and is instead divided by
#' the number of vertex pairs that could carry a tie. Getting that one
#' backwards would silently invert the answer, so it is handled explicitly.
#' `"pearson"` similarity can be negative, so its distance runs in
#' \eqn{[0, 2]} rather than \eqn{[0, 1]}; that is a valid distance, but do not
#' expect the unit scale.
#'
#' With `contiguous = TRUE` the bins are partitioned by Fisher's (1958)
#' dynamic program, which minimises total within-phase scatter over all
#' contiguous partitions. That is exact and deterministic. Cutting a
#' dendrogram is neither: it is a greedy agglomeration and it can put bin 3
#' and bin 40 in a phase that bin 20 is not in, which is not a regime.
#'
#' **Nothing here is random.** [temporal_communities()] needs seeds because
#' modularity maximisation is a heuristic on a near-degenerate landscape; this
#' verb needs none because both of its steps are exact. Two calls return
#' identical results and the caller's random stream is never touched. The
#' difference is deliberate.
#'
#' For the Bayesian changepoint approach to the same question -- a different
#' paradigm, with MCMC and its own diagnostics -- see the `NetworkChange`
#' package, which this deliberately does not reimplement.
#'
#' @references
#' Fisher, W. D. (1958). On grouping for maximum homogeneity. *Journal of the
#' American Statistical Association*, 53(284), 789-798.
#'
#' Rousseeuw, P. J. (1987). Silhouettes: a graphical aid to the interpretation
#' and validation of cluster analysis. *Journal of Computational and Applied
#' Mathematics*, 20, 53-65.
#'
#' Murtagh, F., & Legendre, P. (2014). Ward's hierarchical agglomerative
#' clustering method: which algorithms implement Ward's criterion? *Journal of
#' Classification*, 31, 274-295.
#'
#' Lucas, M., Morris, A., Townsend-Teague, A., Tichit, L., Habermann, B. H., &
#' Barrat, A. (2023). Inferring cell cycle phases from a partially temporal
#' network of protein interactions. *Cell Reports Methods*, 3(3), 100397.
#'
#' Park, J. H., & Sohn, Y. (2020). Detecting structural changes in
#' longitudinal network data. *Bayesian Analysis*, 15(1), 133-157.
#'
#' @seealso [similarity()], whose matrix this clusters, and
#'   [temporal_communities()] for the vertex-side question.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' phases(dn, step = 2, window = 2)
#' as.data.frame(phases(dn, step = 2, window = 2), what = "profile")
#'
#' @export
phases <- function(dn, k = NULL,
                   method = c("jaccard", "overlap", "hamming", "cosine",
                              "pearson"),
                   linkage = c("ward.D2", "average", "complete"),
                   contiguous = TRUE, k_max = 10L,
                   sessions = c("bounded", "collapse", "separate"),
                   start = NULL, end = NULL, step = NULL, window = NULL) {
  method <- match.arg(method)
  linkage <- match.arg(linkage)
  sessions <- match.arg(sessions)
  .check(
    "`contiguous` must be a single non-missing logical value." =
      is.logical(contiguous) && length(contiguous) == 1L && !is.na(contiguous),
    "`k_max` must be a single whole number of at least two." =
      is.numeric(k_max) && length(k_max) == 1L && is.finite(k_max) &&
        k_max >= 2,
    "`k` must be NULL or a single whole number." =
      is.null(k) || (is.numeric(k) && length(k) == 1L && is.finite(k) &&
                       k == trunc(k))
  )
  if (!is.null(k) && k < 2) {
    stop(errorCondition(
      "`k` must be at least two: one phase is the whole series, which is the absence of phase structure rather than a detection of it.",
      class = "dynet_bad_input", call = NULL))
  }
  s <- similarity(dn, method = method, sessions = sessions, start = start,
                  end = end, step = step, window = window)
  frame <- as.data.frame(s)
  blocked <- "session" %in% names(frame)
  keys <- if (blocked) as.character(frame$session) else rep("", nrow(frame))
  n_nodes <- nrow(dn$nodes)
  possible <- if (dn$directed) n_nodes * (n_nodes - 1L) else
    n_nodes * (n_nodes - 1L) / 2L
  results <- lapply(unique(keys), function(block) {
    d <- .similarity_distance(frame[keys == block, , drop = FALSE], method,
                              possible)
    times <- sort(unique(c(frame$time[keys == block],
                           frame$other[keys == block])))
    n_bins <- length(times)
    if (n_bins < 3L) {
      stop(errorCondition(sprintf(
        "Phase detection needs at least three bins to have anything to divide; this grid has %d. Use a smaller `step`.",
        n_bins), class = "dynet_empty_result", call = NULL))
    }
    if (!is.null(k) && k >= n_bins) {
      stop(errorCondition(sprintf(
        "`k = %d` is not fewer than the %d bins available, so every bin would be its own phase.",
        k, n_bins), class = "dynet_bad_input", call = NULL))
    }
    split_at <- function(size) {
      if (contiguous) {
        .fisher_partition(d, size)$phase
      } else {
        # Relabelled in order of first appearance so a non-contiguous phase
        # is still numbered left to right.
        raw <- stats::cutree(stats::hclust(stats::as.dist(d),
                                           method = linkage), k = size)
        match(raw, unique(raw))
      }
    }
    candidates <- seq.int(2L, min(k_max, n_bins - 1L))
    profile <- do.call(rbind, lapply(candidates, function(size) {
      phase <- split_at(size)
      width <- .silhouette(d, phase)
      data.frame(session = block, k = size,
                 silhouette_mean = mean(width[!is.na(width)]),
                 within_ss = if (contiguous) {
                   .fisher_partition(d, size)$cost
                 } else {
                   sum(vapply(split(seq_along(phase), phase), function(idx)
                     if (length(idx) < 2L) 0 else
                       sum(d[idx, idx]^2) / (2 * length(idx)), numeric(1L)))
                 },
                 n_singletons = sum(is.na(width)),
                 stringsAsFactors = FALSE)
    }))
    chosen <- k %||% profile$k[[which.max(profile$silhouette_mean)]]
    phase <- split_at(chosen)
    list(session = block, times = times, phase = phase,
         silhouette = .silhouette(d, phase), profile = profile, k = chosen,
         distance = d)
  })
  df <- do.call(rbind, lapply(results, function(r) data.frame(
    session = r$session, time = r$times, phase = r$phase,
    boundary = c(TRUE, r$phase[-1L] != r$phase[-length(r$phase)]),
    silhouette = r$silhouette, stringsAsFactors = FALSE)))
  if (!blocked) df$session <- NULL
  rownames(df) <- NULL
  structure(df, class = c("dynet_phases", "data.frame"),
            method = method, linkage = linkage, contiguous = contiguous,
            k = vapply(results, function(r) as.integer(r$k), integer(1L)),
            blocks = results, blocked = blocked,
            time_unit = dn$meta$time_unit)
}

#' Print detected temporal phases
#'
#' @param x A `dynet_phases` frame.
#' @param ... Ignored.
#' @return `x`, invisibly. Called for the printed output.
#' @export
print.dynet_phases <- function(x, ...) {
  blocks <- attr(x, "blocks")
  cat(sprintf("# Temporal phases: %s over %d bins | %s distance, %s\n",
              paste(attr(x, "k"), collapse = ", "), nrow(x),
              attr(x, "method"),
              if (isTRUE(attr(x, "contiguous"))) "contiguous (exact)" else
                sprintf("%s linkage, recurrence allowed",
                        attr(x, "linkage"))))
  starts <- x$time[x$boundary]
  cat(sprintf("# phases begin at %s (%s)\n",
              paste(format(starts), collapse = ", "), attr(x, "time_unit")))
  width <- x$silhouette[!is.na(x$silhouette)]
  if (length(width)) {
    cat(sprintf("# mean silhouette %.3f%s\n", mean(width),
                if (mean(width) < 0.25)
                  "  <- weak separation; the phases may not be real" else ""))
  }
  print(as.data.frame(x), row.names = FALSE)
  invisible(x)
}

#' Tidy data frame of detected temporal phases
#'
#' @param x A `dynet_phases` frame.
#' @param row.names,optional Ignored, for method consistency.
#' @param what `"bins"` for one row per time bin, `"profile"` for the
#'   sensitivity table over every `k` considered, or `"phases"` for one row
#'   per phase.
#' @param ... Ignored.
#' @return A plain data frame.
#' @export
as.data.frame.dynet_phases <- function(x, row.names = NULL, optional = FALSE,
                                       what = c("bins", "profile", "phases"),
                                       ...) {
  what <- match.arg(what)
  blocked <- isTRUE(attr(x, "blocked"))
  if (identical(what, "bins")) {
    plain <- as.data.frame(unclass(x)[names(x)], stringsAsFactors = FALSE)
    rownames(plain) <- NULL
    return(plain)
  }
  out <- do.call(rbind, lapply(attr(x, "blocks"), function(r) {
    if (identical(what, "profile")) return(r$profile)
    do.call(rbind, lapply(sort(unique(r$phase)), function(id) {
      inside <- which(r$phase == id)
      data.frame(
        session = r$session, phase = id,
        start = min(r$times[inside]), end = max(r$times[inside]),
        n_bins = length(inside),
        cohesion = if (length(inside) < 2L) NA_real_ else
          1 - mean(r$distance[inside, inside][lower.tri(diag(length(inside)))]),
        stringsAsFactors = FALSE)
    }))
  }))
  if (!blocked) out$session <- NULL
  rownames(out) <- NULL
  out
}

#' Draw detected phases over the between-bin similarity heatmap
#'
#' @description
#' The heatmap [plot.dynet_similarity()] draws, with the phase blocks outlined
#' on it, so the reader can see whether the blocks the algorithm found are the
#' blocks the eye finds.
#'
#' @param x A `dynet_phases` frame.
#' @param base_size Base text size.
#' @param ... Ignored.
#' @return A `ggplot` object.
#' @export
plot.dynet_phases <- function(x, base_size = 12, ...) {
  block <- attr(x, "blocks")[[1L]]
  d <- block$distance
  times <- block$times
  grid <- expand.grid(time = times, other = times)
  grid$value <- as.vector(d)
  spans <- do.call(rbind, lapply(sort(unique(block$phase)), function(id) {
    inside <- which(block$phase == id)
    width <- if (length(times) > 1L) min(diff(times)) else 1
    data.frame(phase = id,
               low = min(times[inside]) - width / 2,
               high = max(times[inside]) + width / 2,
               mid = stats::median(times[inside]))
  }))
  ggplot2::ggplot(grid) +
    ggplot2::geom_tile(ggplot2::aes(x = time, y = other, fill = value)) +
    ggplot2::geom_rect(
      data = spans,
      ggplot2::aes(xmin = low, xmax = high, ymin = low, ymax = high),
      fill = NA, colour = "#D55E00", linewidth = 0.7, inherit.aes = FALSE) +
    ggplot2::geom_text(
      data = spans, ggplot2::aes(x = mid, y = mid, label = phase),
      colour = "#D55E00", fontface = "bold", size = base_size / 2.6,
      inherit.aes = FALSE) +
    ggplot2::scale_fill_gradient(low = "#0072B2", high = "#DCE9F5",
                                 name = "distance") +
    ggplot2::labs(
      x = sprintf("Time (%s)", attr(x, "time_unit")),
      y = sprintf("Time (%s)", attr(x, "time_unit")),
      title = "Temporal phases",
      subtitle = sprintf("%s distance, %s", attr(x, "method"),
                         if (isTRUE(attr(x, "contiguous")))
                           "contiguous partition (exact)" else
                             sprintf("%s linkage", attr(x, "linkage")))) +
    ggplot2::coord_fixed() +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold"))
}
