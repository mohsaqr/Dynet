# ===========================================================================
# Graph kernels (internal). Pure base R matrix algebra, so that every
# measure works on a machine with no network packages installed.
# ===========================================================================

#' Binary adjacency with the diagonal removed for path computations
#' @param a Numeric adjacency matrix.
#' @param directed Whether to keep direction.
#' @return A binary numeric matrix.
#' @noRd
.binary <- function(a, directed = TRUE) {
  b <- (a > 0) * 1
  if (!directed) b <- pmax(b, t(b))
  diag(b) <- 0
  b
}

#' Sum a matrix along the margin a mode asks for
#'
#' The single place direction is interpreted. `"out"` sums each row, `"in"`
#' sums each column, and `"all"` sums both -- so a reciprocated pair counts
#' twice, which is `igraph`'s and `cograph`'s convention. On an undirected
#' network the three coincide and the row sums are returned.
#'
#' @param m A square numeric matrix.
#' @param directed Whether the network is directed.
#' @param mode One of `"all"`, `"out"`, `"in"`.
#' @return A numeric vector, one value per vertex.
#' @noRd
.margin <- function(m, directed, mode = c("all", "out", "in")) {
  mode <- match.arg(mode)
  if (!directed) return(rowSums(m))
  switch(mode,
    all  = rowSums(m) + colSums(m),
    out  = rowSums(m),
    `in` = colSums(m))
}

#' All-pairs geodesic distances
#'
#' Breadth-first distances found by repeated boolean matrix products, which
#' keeps the whole computation vectorised.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @return A numeric matrix of distances; `Inf` where no path exists.
#' @noRd
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
#' `C(i) = r(i) / sum_{j reachable from i} d(i, j)`, where `r(i)` is the
#' number of vertices `i` reaches.
#'
#' @param a Adjacency matrix. Binarised by `.geodesic()`, so every arc is one
#'   hop and edge weights do not shorten a path; the igraph agreement above is
#'   therefore with an unweighted `igraph::closeness()`.
#' @param directed Whether to respect direction.
#' @param mode `"out"` counts distance from the vertex, `"in"` distance to it,
#'   `"all"` ignores direction. `"all"` is the default.
#' @return A named numeric vector; zero for a vertex that reaches nothing.
#' @references Freeman, L. C. (1979). Centrality in social networks: conceptual
#'   clarification. *Social Networks*, 1(3), 215-239.
#' @noRd
.closeness <- function(a, directed = TRUE, mode = c("all", "out", "in")) {
  mode <- match.arg(mode)
  # "in" on `a` is "out" on its transpose, and "all" is the undirected graph,
  # so one geodesic routine serves all three modes.
  if (directed && identical(mode, "in")) a <- t(a)
  d <- .geodesic(a, directed && !identical(mode, "all"))
  finite <- is.finite(d)
  diag(finite) <- FALSE
  tot <- rowSums(ifelse(finite, d, 0))
  n_reach <- rowSums(finite)
  out <- ifelse(tot > 0, n_reach / tot, 0)
  stats::setNames(out, rownames(a))
}

#' Betweenness centrality by Brandes' algorithm
#'
#' `B(v) = sum_{s != v != t} sigma_st(v) / sigma_st`, where `sigma_st` counts
#' the shortest paths from `s` to `t` and `sigma_st(v)` those passing through
#' `v`. Accumulated one source at a time, which is what makes Brandes linear
#' in the edge count per source rather than quadratic.
#'
#' @param a Adjacency matrix. Binarised before use, so edge weights do not
#'   shorten a path.
#' @param directed Whether to respect direction. Undirected counts are halved,
#'   matching `sna::betweenness(gmode = "graph")`.
#' @return A named numeric vector; zero throughout on fewer than three
#'   vertices.
#' @references Brandes, U. (2001). A faster algorithm for betweenness
#'   centrality. *Journal of Mathematical Sociology*, 25(2), 163-177.
#' @noRd
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
#' @noRd
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

#' Principal eigenvector centrality
#'
#' The non-negative solution of `A x = rho x` at the Perron root
#' `rho = max |eigenvalue|`, scaled so `max(x) = 1`.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction. `FALSE` symmetrises with
#'   `pmax(a, t(a))`. `TRUE` respects direction only when `mode` asks it to.
#' @param mode Which direction the score is read along. `"in"` uses the left
#'   eigenvector, so a vertex is central when central vertices point at it
#'   (igraph's convention); `"out"` uses the right eigenvector
#'   (`sna::evcent`'s); `"all"`, the default, symmetrises and so gives the
#'   undirected answer even when `directed = TRUE`.
#' @param tol Relative tolerance, scaled by the matrix magnitude, for the
#'   three decisions the certification makes: whether the Perron root is
#'   effectively zero, which singular values count as the null space of
#'   `A - rho I`, and which loadings are snapped to zero before the
#'   non-negativity check.
#' @param max_iter Unused. Retained from the former power-iteration
#'   implementation; no caller in the package names it.
#' @return A named numeric vector scaled to a maximum of one. When the answer
#'   is not defined -- the eigensolve failed, the spectral radius is zero
#'   (an acyclic snapshot), the Perron eigenspace is not one-dimensional (two
#'   components of equal weight), or the leading vector is not sign-constant
#'   -- an all-`NA` vector carrying `attr(, "undefined") = TRUE` is returned
#'   instead, so the calling verb can report the fact once. Two shapes return
#'   early and are not flagged: a zero-vertex matrix gives an unnamed
#'   `numeric(0)`, and an edgeless one a named vector of zeros, which is the
#'   defined answer rather than a missing one.
#' @references Bonacich, P. (1972). Factoring and weighting approaches to
#'   status scores and clique identification. *Journal of Mathematical
#'   Sociology*, 2(1), 113-120.
#' @noRd
.eigen_centrality <- function(a, directed = TRUE, mode = c("all", "out", "in"),
                              tol = 1e-12, max_iter = 1000L) {
  mode <- match.arg(mode)
  # `a` is taken as given -- .hits() passes a co-citation matrix through here,
  # so this must not binarise. Callers that want presence rather than volume
  # reduce with .binary() first.
  # "in" scores a vertex by who points at it (igraph's convention), "out" by
  # who it points at (sna::evcent's), "all" ignores direction.
  m <- if (!directed || identical(mode, "all")) pmax(a, t(a)) else
    switch(mode, `in` = t(a), out = a)
  n <- nrow(m)
  if (n == 0L) return(numeric(0))
  if (all(m == 0)) return(stats::setNames(rep(0, n), rownames(a)))
  # A plain power iteration oscillates on bipartite and periodic graphs because
  # -rho can have the same modulus as the Perron root. A direct eigensolve
  # selects the non-negative matrix's largest real eigenvalue instead, and the
  # result is certified the way eigenvector prestige is: the Perron root must
  # be positive and its eigenspace one-dimensional. A snapshot whose spectral
  # radius is zero (acyclic), or whose Perron root is repeated (two components
  # of equal weight), has no single answer, and returns NA rather than one
  # basis vector of the eigenspace chosen by the solver.
  scale <- max(1, max(abs(m)))
  spectrum <- tryCatch(eigen(m, only.values = TRUE)$values,
                       error = function(e) NULL)
  undefined <- structure(stats::setNames(rep(NA_real_, n), rownames(a)),
                         undefined = TRUE)
  if (is.null(spectrum) || any(!is.finite(spectrum))) return(undefined)
  radius <- max(Mod(spectrum))
  if (radius <= tol * scale) return(undefined)
  shifted <- m - diag(radius, n)
  decomposition <- tryCatch(svd(shifted, nu = 0L, nv = n),
                            error = function(e) NULL)
  if (is.null(decomposition) || any(!is.finite(decomposition$d))) return(undefined)
  null <- which(decomposition$d <= tol * max(1, radius, decomposition$d))
  if (length(null) != 1L) return(undefined)
  x <- decomposition$v[, null]
  if (sum(x) < 0) x <- -x
  x[abs(x) <= tol * max(1, abs(x))] <- 0
  if (any(x < 0)) return(undefined)
  if (max(x) > 0) x <- x / max(x)
  stats::setNames(x, rownames(a))
}

#' PageRank by power iteration
#'
#' `x = d (P' x + (1/n) sum_{dangling} x) + (1 - d) / n`, iterated to a fixed
#' point, where `P` is the row-normalised adjacency and a dangling vertex
#' spreads its mass uniformly. Matches `igraph::page_rank()` at the same
#' damping.
#'
#' @param a Adjacency matrix.
#' @param damping Damping factor `d`.
#' @param tol,max_iter Convergence tolerance on the maximum absolute change,
#'   and the iteration cap. The cap is not reported when it is hit.
#' @return A named numeric vector summing to one.
#' @references Brin, S., & Page, L. (1998). The anatomy of a large-scale
#'   hypertextual web search engine. *Computer Networks and ISDN Systems*,
#'   30(1-7), 107-117.
#' @noRd
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
  converged <- FALSE
  repeat {
    y <- damping * (as.vector(tp %*% x) + sum(x[dangling]) / n) + (1 - damping) / n
    it <- it + 1L
    change <- max(abs(y - x))
    x <- y
    converged <- change < tol
    if (converged || it >= max_iter) break
  }
  # Reaching the iteration cap used to be indistinguishable from converging.
  # The final iterate is still returned -- it is the best estimate available
  # -- but the caller is told that it is not a converged one.
  if (!converged) {
    warning(warningCondition(sprintf(
      "PageRank did not converge in %d iterations; the last change was %.3g against a tolerance of %.3g, and the final iterate is reported.",
      max_iter, change, tol
    ), class = "dynet_pagerank_nonconvergence", call = NULL))
  }
  stats::setNames(x / sum(x), rownames(a))
}

#' Hub and authority scores
#'
#' The principal eigenvector of `A A'` for hubs and of `A' A` for
#' authorities. Matches `igraph::hub_score()` and
#' `igraph::authority_score()`.
#'
#' @param a Adjacency matrix.
#' @param which Either `"hub"` or `"authority"`.
#' @return A named numeric vector scaled to a maximum of one, or the
#'   `undefined`-flagged all-`NA` vector `.eigen_centrality()` returns when the
#'   leading eigenvector is not determined.
#' @references Kleinberg, J. M. (1999). Authoritative sources in a hyperlinked
#'   environment. *Journal of the ACM*, 46(5), 604-632.
#' @noRd
.hits <- function(a, which = c("hub", "authority")) {
  which <- match.arg(which)
  m <- if (identical(which, "hub")) a %*% t(a) else t(a) %*% a
  .eigen_centrality(m, directed = FALSE)
}

#' k-core number of every vertex
#'
#' The largest `k` such that the vertex survives repeated removal of every
#' vertex of degree below `k`. Matches `igraph::coreness()` under the matching
#' mode.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @param mode Which degree the peeling uses: `"all"`, `"out"` or `"in"`.
#' @return A named numeric vector.
#' @references Seidman, S. B. (1983). Network structure and minimum degree.
#'   *Social Networks*, 5(3), 269-287.
#' @noRd
.coreness <- function(a, directed = TRUE, mode = c("all", "out", "in")) {
  mode <- match.arg(mode)
  b <- .binary(a, directed = TRUE)
  # "all" counts each direction separately, so a reciprocated pair contributes
  # two -- igraph's convention. The other modes peel on one margin, which the
  # transpose supplies for "in".
  m <- if (!directed) .binary(a, directed = FALSE) else
    switch(mode, all = b + t(b), out = b, `in` = t(b))
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
#'
#' `C(i) = sum_{j in N(i)} (p_ij + sum_q p_iq p_qj)^2`, where `p_ij` is `i`'s
#' proportional investment in `j` computed on the symmetrised, loop-free
#' network. Matches `igraph::constraint()` on both directed and undirected
#' input.
#'
#' @param a Adjacency matrix.
#' @return A named numeric vector; `NA` for isolates.
#' @references Burt, R. S. (1992). *Structural holes: the social structure of
#'   competition*. Harvard University Press.
#' @noRd
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
#' @noRd
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
#' The share of two-paths that are closed: `sum_ij (A^2)_ij A_ij / sum_ij
#' (A^2)_ij` off the diagonal, on the binarised network. This is the "weak"
#' convention, and it matches `sna::gtrans(measure = "weak")`.
#'
#' Follows the `sna::gtrans()` convention of returning one when the graph has
#' no two-paths, rather than the `NaN` that `igraph` produces.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @return A single numeric value.
#' @noRd
.transitivity <- function(a, directed = TRUE) {
  b <- .binary(a, directed)
  two <- b %*% b
  diag(two) <- 0
  denom <- sum(two)
  if (denom == 0) return(1)
  sum(two * b) / denom
}

#' Dyad census
#'
#' Counts of the three dyad states over all `choose(n, 2)` unordered pairs.
#' Matches `sna::dyad.census()`.
#'
#' @param a Adjacency matrix.
#' @return A named numeric vector with `mutual`, `asymmetric` and `null`.
#' @references Holland, P. W., & Leinhardt, S. (1970). A method for detecting
#'   structure in sociometric data. *American Journal of Sociology*, 76(3),
#'   492-513.
#' @noRd
.dyad_census <- function(a) {
  b <- .binary(a, directed = TRUE)
  n <- nrow(b)
  mut  <- sum(b * t(b)) / 2
  asym <- sum(abs(b - t(b))) / 2
  c(mutual = mut, asymmetric = asym, null = choose(n, 2) - mut - asym)
}

#' Edgewise reciprocity
#'
#' `sum_ij B_ij B_ji / sum_ij B_ij` on the binarised network: the share of
#' arcs whose reverse is also present. Matches
#' `sna::grecip(measure = "edgewise")` on any graph carrying at least one arc.
#' A graph with no arcs at all is reported as zero here, where `sna::grecip()`
#' divides by zero and returns `NaN`.
#'
#' @param a Adjacency matrix.
#' @return A single numeric value in `[0, 1]`.
#' @noRd
.reciprocity <- function(a) {
  b <- .binary(a, directed = TRUE)
  m <- sum(b)
  if (m == 0) return(0)
  sum(b * t(b)) / m
}

#' Degree assortativity
#'
#' The Pearson correlation of the two endpoint values over the edge list. The
#' default value is **total** degree, `rowSums(A) + colSums(A)`, on both
#' endpoints. On an undirected network this matches
#' `igraph::assortativity_degree()`; on a directed one it does not, because
#' igraph correlates the source's out-degree against the target's in-degree
#' while this correlates total degree on both sides.
#'
#' @param a Adjacency matrix.
#' @param directed Whether to respect direction.
#' @param values Optional numeric vertex values; total degree is used when
#'   absent.
#' @return A single numeric value, `NA` when fewer than two edges remain or
#'   either endpoint series is constant.
#' @references Newman, M. E. J. (2002). Assortative mixing in networks.
#'   *Physical Review Letters*, 89(20), 208701.
#' @noRd
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
#'
#' `sum_i (max(c) - c_i) / max_score`, where `max_score` is the same sum for
#' the most centralised graph of this size.
#'
#' @param scores Numeric vector of vertex scores.
#' @param max_score Theoretical maximum sum of differences for this graph size.
#' @return A single numeric value in `[0, 1]`, `NA` when the maximum is zero.
#' @references Freeman, L. C. (1979). Centrality in social networks: conceptual
#'   clarification. *Social Networks*, 1(3), 215-239.
#' @noRd
.centralisation <- function(scores, max_score) {
  if (!is.finite(max_score) || max_score <= 0) return(NA_real_)
  sum(max(scores) - scores) / max_score
}

#' Triad census over all 16 isomorphism classes
#'
#' Every triple is reduced to the six-bit code of its three dyads and looked up
#' in `.triad_class`. Matches `sna::triad.census()` and
#' `igraph::triad_census()`.
#'
#' Cost grows with the cube of the vertex count; the computation is streamed
#' one first-vertex at a time so that memory stays bounded.
#'
#' @param a Adjacency matrix.
#' @return A named numeric vector of length 16 using the standard MAN labels.
#' @references Holland, P. W., & Leinhardt, S. (1970). A method for detecting
#'   structure in sociometric data. *American Journal of Sociology*, 76(3),
#'   492-513.
#' @noRd
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
#' @noRd
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
