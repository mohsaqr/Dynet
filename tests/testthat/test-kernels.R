# Numerical equivalence of the base-R graph kernels against igraph and sna.

random_adj <- function(n, p, directed = TRUE, seed = 1L) {
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (!is.null(old)) assign(".Random.seed", old, globalenv()), add = TRUE)
  set.seed(seed)
  a <- matrix(stats::rbinom(n * n, 1L, p), n, n)
  diag(a) <- 0
  if (!directed) a[lower.tri(a)] <- t(a)[lower.tri(a)]
  dimnames(a) <- list(paste0("v", seq_len(n)), paste0("v", seq_len(n)))
  a
}

test_that("path-based kernels match igraph on directed and undirected graphs", {
  skip_if_not_installed("igraph")
  for (seed in 1:3) {
    for (directed in c(TRUE, FALSE)) {
      a <- random_adj(20L, 0.15, directed, seed)
      g <- igraph::graph_from_adjacency_matrix(
        a, mode = if (directed) "directed" else "undirected")

      expect_equal(unname(.geodesic(a, directed)),
                   unname(igraph::distances(g, mode = "out")))
      expect_equal(unname(.betweenness(a, directed)),
                   unname(igraph::betweenness(g, directed = directed)))

      close_ig <- suppressWarnings(
        igraph::closeness(g, mode = "out", normalized = TRUE))
      close_ig[is.nan(close_ig)] <- 0
      expect_equal(unname(.closeness(a, directed)), unname(close_ig))

      expect_equal(unname(.coreness(a, directed)),
                   unname(igraph::coreness(g, mode = "all")))
      expect_equal(unname(.pagerank(a)),
                   unname(igraph::page_rank(g)$vector), tolerance = 1e-6)
      expect_equal(.components(a, "weak")$count,
                   igraph::components(g, mode = "weak")$no)
      expect_equal(.components(a, "strong")$count,
                   igraph::components(g, mode = "strong")$no)
    }
  }
})

test_that("directed-only kernels match igraph", {
  skip_if_not_installed("igraph")
  a <- random_adj(18L, 0.2, TRUE, seed = 4L)
  g <- igraph::graph_from_adjacency_matrix(a, mode = "directed")
  expect_equal(unname(.constraint(a)), unname(igraph::constraint(g)))
  hits <- igraph::hits_scores(g)
  expect_equal(unname(.hits(a, "hub")), unname(hits$hub), tolerance = 1e-5)
  expect_equal(unname(.hits(a, "authority")), unname(hits$authority),
               tolerance = 1e-5)
})

test_that("census and structure kernels match sna", {
  skip_if_not_installed("sna")
  for (seed in 1:3) {
    a <- random_adj(16L, 0.18, TRUE, seed)
    expect_equal(unname(.dyad_census(a)), as.numeric(sna::dyad.census(a)))
    expect_equal(unname(.triad_census(a)), as.numeric(sna::triad.census(a)))
    expect_equal(.transitivity(a, TRUE), unname(sna::gtrans(a, mode = "digraph")))
    expect_equal(.reciprocity(a), unname(sna::grecip(a, measure = "edgewise")))
  }
})

test_that("eigenvector centrality matches igraph on undirected graphs", {
  skip_if_not_installed("igraph")
  a <- random_adj(20L, 0.2, FALSE, seed = 5L)
  g <- igraph::graph_from_adjacency_matrix(a, mode = "undirected")
  expect_equal(unname(.eigen_centrality(a, FALSE)),
               unname(igraph::eigen_centrality(g, directed = FALSE)$vector),
               tolerance = 1e-5)
})

test_that("census counts add up to the number of dyads and triples", {
  a <- random_adj(14L, 0.25, TRUE, seed = 6L)
  expect_equal(sum(.dyad_census(a)), choose(14, 2))
  expect_equal(sum(.triad_census(a)), choose(14, 3))
})

test_that("kernels handle empty and complete graphs without failing", {
  empty <- matrix(0, 5L, 5L, dimnames = list(letters[1:5], letters[1:5]))
  expect_equal(unname(.closeness(empty)), rep(0, 5L))
  expect_equal(unname(.betweenness(empty)), rep(0, 5L))
  expect_equal(.reciprocity(empty), 0)
  expect_equal(.transitivity(empty), 1)
  expect_equal(.components(empty, "weak")$count, 5L)

  full <- matrix(1, 5L, 5L, dimnames = dimnames(empty))
  diag(full) <- 0
  expect_equal(.reciprocity(full), 1)
  expect_equal(.transitivity(full), 1)
  expect_equal(.components(full, "weak")$count, 1L)
})

test_that("kernels are invariant to relabelling the vertices", {
  a <- random_adj(15L, 0.2, TRUE, seed = 7L)
  perm <- c(8:15, 1:7)
  b <- a[perm, perm]
  expect_equal(unname(.betweenness(b)), unname(.betweenness(a))[perm])
  expect_equal(unname(.closeness(b)), unname(.closeness(a))[perm])
  expect_equal(unname(.coreness(b)), unname(.coreness(a))[perm])
  expect_equal(.triad_census(b), .triad_census(a))
})
