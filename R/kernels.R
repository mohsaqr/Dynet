# ===========================================================================
# Graph kernels (internal). Pure base R matrix algebra, so that every
# measure works on a machine with no network packages installed.
# ===========================================================================

#' Binary adjacency with the diagonal removed for path computations
#' @param a Numeric adjacency matrix.
#' @param directed Whether to keep direction.
#' @return A binary numeric matrix.
#' @keywords internal
.binary <- function(a, directed = TRUE) {
  b <- (a > 0) * 1
  if (!directed) b <- pmax(b, t(b))
  diag(b) <- 0
  b
}

#' All-pairs geodesic distances
#'
#' Breadth-first distances found by repeated boolean matrix products, which
#' keeps the whole computation vectorised.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @return A numeric matrix of distances; `Inf` where no path exists.
#' @keywords internal
.geodesic <- function(a, directed = TRUE) {
  b <- .binary(a, directed)
  n <- nrow(b)
  d <- matrix(Inf, n, n, dimnames = dimnames(b))
  diag(d) <- 0
  reach <- b
  k <- 1L
  # Each pass extends the frontier by one hop; the dependency between passes
  # is sequential, so this cannot be vectorised further.
  while (k <= n) {
    fresh <- reach > 0 & is.infinite(d)
    if (!any(fresh)) break
    d[fresh] <- k
    k <- k + 1L
    reach <- (reach %*% b) > 0
  }
  d
}

#' Normalised closeness centrality
#'
#' The number of vertices a vertex can reach, divided by the total distance
#' to them. This matches `igraph::closeness(normalized = TRUE)` and stays
#' informative on a disconnected graph, which every snapshot of a temporal
#' network is. `sna::closeness()` instead sums over unreachable vertices too
#' and therefore collapses to zero for the whole graph as soon as one vertex
#' is unreachable.
#'
#' A vertex that reaches nothing is reported as zero rather than `NaN`, so
#' that averaging a closeness series does not silently propagate a missing
#' value.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @return A named numeric vector.
#' @keywords internal
.closeness <- function(a, directed = TRUE) {
  d <- .geodesic(a, directed)
  finite <- is.finite(d)
  diag(finite) <- FALSE
  tot <- rowSums(ifelse(finite, d, 0))
  n_reach <- rowSums(finite)
  out <- ifelse(tot > 0, n_reach / tot, 0)
  stats::setNames(out, rownames(a))
}

#' Betweenness centrality by Brandes' algorithm
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction. Undirected counts are halved,
#'   matching `sna::betweenness(gmode = "graph")`.
#' @return A named numeric vector.
#' @references Brandes, U. (2001). A faster algorithm for betweenness
#'   centrality. *Journal of Mathematical Sociology*, 25(2), 163-177.
#' @keywords internal
.betweenness <- function(a, directed = TRUE) {
  b <- .binary(a, directed)
  n <- nrow(b)
  if (n < 3L) return(stats::setNames(numeric(n), rownames(a)))
  total <- Reduce(`+`, lapply(seq_len(n), function(s) .brandes_source(b, s, n)))
  if (!directed) total <- total / 2
  stats::setNames(total, rownames(a))
}

#' One source's contribution to betweenness
#' @param b Binary adjacency matrix.
#' @param s Source vertex index.
#' @param n Vertex count.
#' @return A numeric vector of length `n`.
#' @keywords internal
.brandes_source <- function(b, s, n) {
  sigma <- numeric(n); sigma[s] <- 1
  dist  <- rep(-1L, n); dist[s] <- 0L
  levels <- list(s)
  frontier <- s
  depth <- 0L
  # Level-synchronous forward sweep. Levels depend on one another in order.
  while (length(frontier) > 0L) {
    nb <- which(colSums(b[frontier, , drop = FALSE]) > 0)
    nxt <- nb[dist[nb] < 0L]
    if (length(nxt) == 0L) break
    dist[nxt] <- depth + 1L
    sigma[nxt] <- as.vector(sigma[frontier] %*% b[frontier, nxt, drop = FALSE])
    levels[[length(levels) + 1L]] <- nxt
    frontier <- nxt
    depth <- depth + 1L
  }

  delta <- numeric(n)
  contrib <- numeric(n)
  # Backward accumulation, deepest level first; also strictly sequential.
  lvl <- length(levels)
  while (lvl > 1L) {
    cur  <- levels[[lvl]]
    prev <- levels[[lvl - 1L]]
    coef <- (1 + delta[cur]) / sigma[cur]
    delta[prev] <- delta[prev] +
      sigma[prev] * as.vector(b[prev, cur, drop = FALSE] %*% coef)
    contrib[cur] <- contrib[cur] + delta[cur]
    lvl <- lvl - 1L
  }
  contrib
}

#' Principal eigenvector centrality by power iteration
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction. Directed networks use the
#'   left eigenvector, so that a vertex is central when central vertices point
#'   at it.
#' @param tol,max_iter Convergence tolerance and iteration cap.
#' @return A named numeric vector scaled to a maximum of one.
#' @keywords internal
.eigen_centrality <- function(a, directed = TRUE, tol = 1e-12,
                              max_iter = 1000L) {
  m <- if (directed) t(a) else pmax(a, t(a))
  n <- nrow(m)
  if (n == 0L) return(numeric(0))
  if (all(m == 0)) return(stats::setNames(rep(0, n), rownames(a)))
  x <- rep(1 / n, n)
  it <- 0L
  # Power iteration: each step depends on the previous vector.
  repeat {
    y <- as.vector(m %*% x)
    nrm <- sqrt(sum(y^2))
    if (nrm == 0) return(stats::setNames(rep(0, n), rownames(a)))
    y <- y / nrm
    it <- it + 1L
    if (max(abs(y - x)) < tol || it >= max_iter) { x <- y; break }
    x <- y
  }
  if (it >= max_iter) {
    warning(warningCondition(
      sprintf("Eigenvector centrality did not converge in %d iterations.", max_iter),
      class = "dynet_no_converge"), call. = FALSE)
  }
  x <- abs(x)
  if (max(x) > 0) x <- x / max(x)
  stats::setNames(x, rownames(a))
}

#' PageRank by power iteration
#'
#' @param a Adjacency matrix.
#' @param damping Damping factor.
#' @param tol,max_iter Convergence tolerance and iteration cap.
#' @return A named numeric vector summing to one.
#' @keywords internal
.pagerank <- function(a, damping = 0.85, tol = 1e-12, max_iter = 1000L) {
  n <- nrow(a)
  if (n == 0L) return(numeric(0))
  out <- rowSums(a)
  dangling <- out == 0
  p <- a
  p[!dangling, ] <- p[!dangling, , drop = FALSE] / out[!dangling]
  tp <- t(p)
  x <- rep(1 / n, n)
  it <- 0L
  repeat {
    y <- damping * (as.vector(tp %*% x) + sum(x[dangling]) / n) + (1 - damping) / n
    it <- it + 1L
    if (max(abs(y - x)) < tol || it >= max_iter) { x <- y; break }
    x <- y
  }
  stats::setNames(x / sum(x), rownames(a))
}

#' Hub and authority scores
#' @param a Adjacency matrix.
#' @param which Either `"hub"` or `"authority"`.
#' @return A named numeric vector scaled to a maximum of one.
#' @keywords internal
.hits <- function(a, which = c("hub", "authority")) {
  which <- match.arg(which)
  m <- if (identical(which, "hub")) a %*% t(a) else t(a) %*% a
  .eigen_centrality(m, directed = FALSE)
}

#' k-core number of every vertex
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction. Cores use total degree.
#' @return A named numeric vector.
#' @keywords internal
.coreness <- function(a, directed = TRUE) {
  b <- .binary(a, directed = TRUE)
  # Total degree counts each direction separately, so a reciprocated pair
  # contributes two. This is igraph's mode = "all" convention.
  m <- if (directed) b + t(b) else .binary(a, directed = FALSE)
  n <- nrow(m)
  core <- rep(0, n)
  alive <- rep(TRUE, n)
  deg <- rowSums(m)
  k <- 0L
  # Peel the lowest-degree vertices repeatedly; each peel changes the degrees
  # the next peel sees.
  while (any(alive)) {
    k <- max(k, min(deg[alive]))
    peel <- alive & deg <= k
    if (!any(peel)) {
      k <- k + 1L
      next
    }
    core[peel] <- k
    alive[peel] <- FALSE
    if (!any(alive)) break
    deg <- rowSums(m[, alive, drop = FALSE])
    deg[!alive] <- Inf
  }
  stats::setNames(core, rownames(a))
}

#' Burt's constraint
#' @param a Adjacency matrix.
#' @return A named numeric vector; `NA` for isolates.
#' @keywords internal
.constraint <- function(a) {
  m <- a + t(a)
  diag(m) <- 0
  tot <- rowSums(m)
  p <- m / ifelse(tot > 0, tot, 1)
  indirect <- p %*% p
  diag(indirect) <- 0
  cij <- (p + indirect)^2
  cij[m == 0] <- 0
  diag(cij) <- 0
  out <- rowSums(cij)
  out[tot == 0] <- NA_real_
  stats::setNames(out, rownames(a))
}

#' Connected components
#' @param a Adjacency matrix.
#' @param mode `"weak"` ignores direction, `"strong"` requires mutual reach.
#' @return A list with `membership` (named integer vector) and `count`.
#' @keywords internal
.components <- function(a, mode = c("weak", "strong")) {
  mode <- match.arg(mode)
  reach <- is.finite(.geodesic(a, directed = identical(mode, "strong")))
  if (identical(mode, "strong")) reach <- reach & t(reach)
  key <- apply(reach, 1L, function(r) paste0(which(r), collapse = ","))
  memb <- match(key, unique(key))
  list(membership = stats::setNames(memb, rownames(a)),
       count = length(unique(memb)))
}

#' Directed and undirected transitivity
#'
#' Follows the `sna::gtrans()` convention of returning one when the graph has
#' no two-paths, rather than the `NaN` that `igraph` produces.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @return A single numeric value.
#' @keywords internal
.transitivity <- function(a, directed = TRUE) {
  b <- .binary(a, directed)
  two <- b %*% b
  diag(two) <- 0
  denom <- sum(two)
  if (denom == 0) return(1)
  sum(two * b) / denom
}

#' Dyad census
#' @param a Adjacency matrix.
#' @return A named numeric vector with `mutual`, `asymmetric` and `null`.
#' @keywords internal
.dyad_census <- function(a) {
  b <- .binary(a, directed = TRUE)
  n <- nrow(b)
  mut  <- sum(b * t(b)) / 2
  asym <- sum(abs(b - t(b))) / 2
  c(mutual = mut, asymmetric = asym, null = choose(n, 2) - mut - asym)
}

#' Edgewise reciprocity
#'
#' The share of edges whose reverse is also present. Empty graphs give zero,
#' matching `sna::grecip(measure = "edgewise")`.
#'
#' @param a Adjacency matrix.
#' @return A single numeric value.
#' @keywords internal
.reciprocity <- function(a) {
  b <- .binary(a, directed = TRUE)
  m <- sum(b)
  if (m == 0) return(0)
  sum(b * t(b)) / m
}

#' Degree assortativity
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @param values Optional numeric vertex values; degree is used when absent.
#' @return A single numeric value, `NA` when undefined.
#' @keywords internal
.assortativity <- function(a, directed = TRUE, values = NULL) {
  b <- .binary(a, directed)
  idx <- which(b > 0, arr.ind = TRUE)
  if (nrow(idx) < 2L) return(NA_real_)
  v <- values %||% (rowSums(b) + colSums(b))
  x <- v[idx[, 1L]]
  y <- v[idx[, 2L]]
  if (!directed) { x <- c(x, y); y <- c(y, x[seq_len(nrow(idx))]) }
  if (stats::sd(x) == 0 || stats::sd(y) == 0) return(NA_real_)
  stats::cor(x, y)
}

#' Freeman centralisation of a node-level score
#' @param scores Numeric vector of vertex scores.
#' @param max_score Theoretical maximum sum of differences for this graph size.
#' @return A single numeric value in `[0, 1]`, `NA` when the maximum is zero.
#' @keywords internal
.centralisation <- function(scores, max_score) {
  if (!is.finite(max_score) || max_score <= 0) return(NA_real_)
  sum(max(scores) - scores) / max_score
}

#' Triad census over all 16 isomorphism classes
#'
#' Cost grows with the cube of the vertex count; the computation is streamed
#' one first-vertex at a time so that memory stays bounded.
#'
#' @param a Adjacency matrix.
#' @return A named numeric vector of length 16 using the standard MAN labels.
#' @keywords internal
.triad_census <- function(a) {
  b <- .binary(a, directed = TRUE)
  n <- nrow(b)
  labels <- c("003", "012", "102", "021D", "021U", "021C", "111D", "111U",
              "030T", "030C", "201", "120D", "120U", "120C", "210", "300")
  out <- stats::setNames(numeric(16L), labels)
  if (n < 3L) return(out)

  counts <- vapply(seq_len(n - 2L), function(i) {
    rest <- seq.int(i + 1L, n)
    if (length(rest) < 2L) return(numeric(16L))
    pairs <- utils::combn(rest, 2L)
    j <- pairs[1L, ]; k <- pairs[2L, ]
    code <- .triad_code(b, rep(i, length(j)), j, k)
    tabulate(.triad_class[code + 1L], nbins = 16L)
  }, numeric(16L))
  out[] <- rowSums(counts)
  out
}

#' Six-bit dyad code for a batch of triples
#' @param b Binary adjacency matrix.
#' @param i,j,k Equal-length integer vectors of vertex indices.
#' @return An integer vector in `[0, 63]`.
#' @keywords internal
.triad_code <- function(b, i, j, k) {
  n <- nrow(b)
  g <- function(x, y) b[(y - 1L) * n + x]
  as.integer(g(i, j) + 2 * g(j, i) + 4 * g(i, k) + 8 * g(k, i) +
             16 * g(j, k) + 32 * g(k, j))
}

# Lookup from the 64 possible dyad codes to the 16 triad classes, in the
# canonical MAN ordering used by sna::triad.census() and igraph::triad_census().
.triad_class <- c(
  1L,  2L,  2L,  3L,  2L,  4L,  6L,  8L,  2L,  6L,  5L,  7L,  3L,  8L,  7L, 11L,
  2L,  6L,  4L,  8L,  5L,  9L,  9L, 13L,  6L, 10L,  9L, 14L,  7L, 14L, 12L, 15L,
  2L,  5L,  6L,  7L,  6L,  9L, 10L, 14L,  4L,  9L,  9L, 12L,  8L, 13L, 14L, 15L,
  3L,  7L,  8L, 11L,  7L, 12L, 14L, 15L,  8L, 14L, 13L, 15L, 11L, 15L, 15L, 16L
)
