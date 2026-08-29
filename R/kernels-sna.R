# ===========================================================================
# Kernels for the measures `sna` provides through `tsna::tSnaStats()`.
# Pure base R, like the rest of R/kernels.R. Names follow cograph's where
# cograph already has the measure, so the two packages agree.
# ===========================================================================

#' Bonacich power centrality
#'
#' `c = rowSums((I - beta A)^-1 A)`, scaled so the sum of squares equals the
#' vertex count. Matches `sna::bonpow()`.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @param exponent The attenuation factor `beta`. Positive rewards being
#'   connected to well-connected others; negative rewards the opposite, which
#'   is the bargaining reading.
#' @return A named numeric vector; `NA` throughout when `I - beta A` is
#'   singular, which happens when the exponent hits an eigenvalue's reciprocal.
#' @references Bonacich, P. (1987). Power and centrality: a family of
#'   measures. *American Journal of Sociology*, 92(5), 1170-1182.
#' @noRd
.bonacich_power <- function(a, directed = TRUE, exponent = 1) {
  b <- .binary(a, directed)
  n <- nrow(b)
  nm <- rownames(a)
  if (n == 0L) return(stats::setNames(numeric(0), nm))
  m <- diag(1, n) - exponent * b
  ev <- tryCatch(rowSums(solve(m) %*% b),
                 error = function(e) rep(NA_real_, n))
  ss <- sum(ev^2)
  # sna scales to sum of squares n; an all-zero vector has no scale to take.
  if (isTRUE(is.finite(ss)) && ss > 0) ev <- ev * sqrt(n / ss)
  stats::setNames(ev, nm)
}

#' Diffusion degree centrality
#'
#' Sums a vertex's selected degree and the selected degrees of its distinct
#' one-step neighbours, then applies a scalar multiplier. This is the binary,
#' loop-free definition used by `centiserve::diffusion.degree()` under matching
#' direction and loop conventions.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @param mode One of `"all"`, `"out"`, or `"in"`.
#' @param lambda Nonnegative multiplier.
#' @return A named numeric vector.
#' @noRd
.diffusion_degree <- function(a, directed = TRUE,
                              mode = c("all", "out", "in"), lambda = 1) {
  mode <- match.arg(mode)
  b <- .binary(a, directed)
  degree <- .margin(b, directed, mode)
  neighbourhood <- if (!directed) {
    b
  } else switch(mode, out = b, `in` = t(b), all = pmax(b, t(b)))
  value <- lambda * (degree + as.numeric(neighbourhood %*% degree))
  stats::setNames(value, rownames(a))
}

#' Harary graph centrality
#'
#' The reciprocal of eccentricity: one over the distance to the furthest
#' reachable vertex. A vertex that cannot reach everything scores zero, since
#' its eccentricity is infinite. Matches `sna::graphcent()`.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @param mode `"out"` measures reach outward, `"in"` inward, `"all"` ignores
#'   direction.
#' @return A named numeric vector.
#' @references Hage, P., & Harary, F. (1995). Eccentricity and centrality in
#'   networks. *Social Networks*, 17(1), 57-63.
#' @noRd
.harary <- function(a, directed = TRUE, mode = c("all", "out", "in")) {
  mode <- match.arg(mode)
  if (directed && identical(mode, "in")) a <- t(a)
  d <- .geodesic(a, directed && !identical(mode, "all"))
  ecc <- apply(d, 1L, max)
  stats::setNames(ifelse(is.finite(ecc) & ecc > 0, 1 / ecc, 0), rownames(a))
}

#' Stephenson and Zelen information centrality
#'
#' The harmonic mean length of all paths ending at a vertex, computed from the
#' inverse of the matrix whose off-diagonal is `1 - x` and whose diagonal is
#' `1 + degree`. Isolates score zero. Matches `sna::infocent()`.
#'
#' @param a Adjacency matrix.
#' @return A named numeric vector.
#' @references Stephenson, K., & Zelen, M. (1989). Rethinking centrality.
#'   *Social Networks*, 11(1), 1-37.
#' @noRd
.information <- function(a) {
  # Information centrality is defined on an undirected graph; a directed one
  # is symmetrised weakly, as sna does.
  m <- .binary(a, directed = FALSE)
  n <- nrow(m)
  cent <- stats::setNames(numeric(n), rownames(a))
  if (n == 0L) return(cent)
  keep <- rowSums(m) > 0
  if (!any(keep)) return(cent)
  mk <- m[keep, keep, drop = FALSE]
  amat <- 1 - mk
  diag(amat) <- 1 + rowSums(mk)
  cn <- tryCatch(solve(amat), error = function(e) NULL)
  if (is.null(cn)) return(stats::setNames(rep(NA_real_, n), rownames(a)))
  tr <- sum(diag(cn))
  r <- rowSums(cn)
  # The denominator uses the full vertex count, isolates included.
  cent[keep] <- 1 / (diag(cn) + (tr - 2 * r) / n)
  cent
}

#' Goh load centrality
#'
#' How much passes through a vertex when every ordered pair sends one unit
#' along its shortest paths and the unit splits *equally* at every branch --
#' unlike betweenness, which splits it in proportion to the number of paths.
#'
#' Verified against `networkx.load_centrality()`, not against
#' `sna::loadcent()`. The two are different quantities: sna also credits a
#' vertex for the paths it starts and ends, so its values run higher, and the
#' gap is not a constant offset once shortest paths branch. Goh's definition,
#' which counts only relayed load, is the one implemented here.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction. Undirected graphs still count
#'   ordered source-target pairs, matching NetworkX's unnormalised definition.
#' @return A named numeric vector.
#' @references Goh, K.-I., Kahng, B., & Kim, D. (2001). Universal behavior of
#'   load distribution in scale-free networks. *Physical Review Letters*,
#'   87(27), 278701.
#' @noRd
.load <- function(a, directed = TRUE) {
  b <- .binary(a, directed)
  n <- nrow(b)
  if (n < 3L) return(stats::setNames(numeric(n), rownames(a)))
  total <- Reduce(`+`, lapply(seq_len(n), function(s) .load_source(b, s, n)))
  stats::setNames(total, rownames(a))
}

#' One source's contribution to load centrality
#' @param b Binary adjacency matrix.
#' @param s Source vertex index.
#' @param n Vertex count.
#' @return A numeric vector of length `n`.
#' @noRd
.load_source <- function(b, s, n) {
  dist <- rep(-1L, n); dist[s] <- 0L
  frontier <- s
  k <- 0L
  # Breadth-first layering; each pass depends on the last, so this cannot be
  # collapsed into a single vectorised step.
  while (length(frontier) > 0L) {
    k <- k + 1L
    nxt <- which(colSums(b[frontier, , drop = FALSE]) > 0 & dist < 0L)
    dist[nxt] <- k
    frontier <- nxt
  }
  load <- rep(1, n)
  reached <- which(dist > 0L)
  if (length(reached) == 0L) return(numeric(n))
  # Furthest first, so a vertex hands its load back before receiving more.
  for (v in reached[order(dist[reached], decreasing = TRUE)]) {
    preds <- which(b[, v] > 0 & dist == dist[v] - 1L)
    if (length(preds) > 0L) load[preds] <- load[preds] + load[v] / length(preds)
  }
  out <- load - 1
  out[s] <- 0
  out[dist < 0L] <- 0
  out
}

#' Maximum flow between two vertices, by Edmonds and Karp
#'
#' @param cap Capacity matrix.
#' @param s,t Source and sink vertex indices.
#' @return A single number.
#' @noRd
.max_flow <- function(cap, s, t) {
  n <- nrow(cap)
  if (n < 2L || s == t) return(0)
  resid <- cap
  flow <- 0
  repeat {
    prev <- integer(n); prev[s] <- s
    queue <- s; head <- 1L
    # Shortest augmenting path first, which is what bounds Edmonds-Karp.
    while (head <= length(queue) && prev[t] == 0L) {
      u <- queue[head]; head <- head + 1L
      nxt <- which(resid[u, ] > 0 & prev == 0L)
      if (length(nxt) > 0L) {
        prev[nxt] <- u
        queue <- c(queue, nxt)
      }
    }
    if (prev[t] == 0L) break
    path <- t; v <- t
    while (v != s) { v <- prev[v]; path <- c(v, path) }
    fwd <- cbind(path[-length(path)], path[-1L])
    bottleneck <- min(resid[fwd])
    resid[fwd] <- resid[fwd] - bottleneck
    bwd <- cbind(path[-1L], path[-length(path)])
    resid[bwd] <- resid[bwd] + bottleneck
    flow <- flow + bottleneck
  }
  flow
}

#' Freeman flow betweenness
#'
#' How much of the network's total maximum flow disappears when a vertex is
#' removed. This uses only max-flow *values*, which are unique, rather than a
#' flow decomposition, which is not -- so the result is well defined.
#' Matches `sna::flowbet(cmode = "rawflow")`.
#'
#' Cost grows with the cube of the vertex count times the cost of one max-flow
#' computation. It is by a wide margin the most expensive measure here.
#'
#' @param a Adjacency matrix, used as capacities.
#' @param directed Whether to respect direction.
#' @return A named numeric vector.
#' @references Freeman, L. C., Borgatti, S. P., & White, D. R. (1991).
#'   Centrality in valued graphs. *Social Networks*, 13(2), 141-154.
#' @noRd
.flow_betweenness <- function(a, directed = TRUE) {
  cap <- .binary(a, directed)
  n <- nrow(cap)
  if (n < 3L) return(stats::setNames(numeric(n), rownames(a)))
  full <- matrix(0, n, n)
  for (j in seq_len(n)) {
    for (k in seq_len(n)) {
      if (j != k && (directed || j < k)) full[j, k] <- .max_flow(cap, j, k)
    }
  }
  flo <- vapply(seq_len(n), function(i) {
    sub <- cap[-i, -i, drop = FALSE]
    idx <- seq_len(n)[-i]
    pairs <- which(full > 0, arr.ind = TRUE)
    pairs <- pairs[pairs[, 1L] != i & pairs[, 2L] != i, , drop = FALSE]
    if (nrow(pairs) == 0L) return(0)
    sum(vapply(seq_len(nrow(pairs)), function(p) {
      j <- pairs[p, 1L]; k <- pairs[p, 2L]
      full[j, k] - .max_flow(sub, match(j, idx), match(k, idx))
    }, numeric(1L)))
  }, numeric(1L))
  stats::setNames(flo, rownames(a))
}

# ---------------------------------------------------------------------------
# Krackhardt's four graph-level indices of hierarchy
# ---------------------------------------------------------------------------

#' Krackhardt connectedness
#'
#' The share of vertex pairs that are weakly connected. One for a graph in a
#' single component, zero for a graph with no edges at all.
#'
#' @param a Adjacency matrix.
#' @return A single number.
#' @references Krackhardt, D. (1994). Graph theoretical dimensions of informal
#'   organizations. In *Computational Organization Theory* (pp. 89-111).
#' @noRd
.connectedness <- function(a) {
  n <- nrow(a)
  if (n <= 1L) return(1)
  sizes <- tabulate(.components(a, "weak")$membership)
  sum(sizes * (sizes - 1)) / (n * (n - 1))
}

#' Krackhardt efficiency
#'
#' One minus the share of edges beyond the minimum needed to hold each
#' component together.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @return A single number; `NaN` when no component admits a surplus edge.
#' @noRd
.efficiency <- function(a, directed = TRUE) {
  b <- .binary(a, directed)
  sizes <- tabulate(.components(a, "weak")$membership)
  required <- sum(sizes - 1)
  possible <- sum(sizes * (sizes - 1) - (sizes - 1))
  if (possible == 0) return(NaN)
  1 - (sum(b) - required) / possible
}

#' Krackhardt hierarchy
#'
#' One minus the share of connected pairs that reach each other both ways. A
#' perfect out-tree scores one; a graph whose reachability is symmetric
#' throughout scores zero.
#'
#' @param a Adjacency matrix.
#' @return A single number; `NaN` when no pair is connected at all.
#' @noRd
.krackhardt_hierarchy <- function(a) {
  reach <- is.finite(.geodesic(a, directed = TRUE))
  upper <- upper.tri(reach)
  mutual <- sum((reach & t(reach))[upper])
  connected <- sum((reach | t(reach))[upper])
  if (connected == 0) return(NaN)
  1 - mutual / connected
}

#' Krackhardt least-upper-boundedness
#'
#' The share of vertex pairs that have a least upper bound: a vertex reaching
#' both, which in turn reaches every other vertex reaching both. Undefined,
#' and reported as `NaN`, when no weak component holds three vertices.
#' Matches `sna::lubness()`.
#'
#' @param a Adjacency matrix.
#' @return A single number.
#' @noRd
.lubness <- function(a) {
  reach <- is.finite(.geodesic(a, directed = TRUE))
  memb <- .components(a, "weak")$membership
  parts <- split(seq_along(memb), memb)
  parts <- parts[lengths(parts) > 2L]
  if (length(parts) == 0L) return(NaN)
  violations <- sum(vapply(parts, function(vi) .lub_violations(reach, vi),
                           numeric(1L)))
  worst <- sum(vapply(parts, function(vi)
    (length(vi) - 1) * (length(vi) - 2) / 2, numeric(1L)))
  1 - violations / worst
}

#' Pairs inside one component that have no least upper bound
#' @param reach Logical reachability matrix.
#' @param vi Vertex indices of the component.
#' @return A single number.
#' @noRd
.lub_violations <- function(reach, vi) {
  r <- reach[vi, vi, drop = FALSE]
  pairs <- utils::combn(length(vi), 2L)
  sum(vapply(seq_len(ncol(pairs)), function(p) {
    bounds <- which(r[, pairs[1L, p]] & r[, pairs[2L, p]])
    if (length(bounds) == 0L) return(1)
    # A least upper bound is an upper bound that reaches every upper bound.
    if (any(vapply(bounds, function(l) all(r[l, bounds]), logical(1L)))) 0 else 1
  }, numeric(1L)))
}
