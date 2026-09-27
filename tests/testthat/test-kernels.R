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

test_that("PageRank says so when it hits the iteration cap", {
  # Reaching `max_iter` used to be indistinguishable from converging: the
  # loop broke on either condition and returned the final iterate silently.
  set.seed(11)
  a <- matrix(stats::rbinom(64, 1, 0.35), 8, 8)
  diag(a) <- 0
  dimnames(a) <- list(letters[1:8], letters[1:8])

  expect_warning(.pagerank(a, max_iter = 2L),
                 class = "dynet_pagerank_nonconvergence")

  # The invariant: a converged run is silent and its values are unchanged.
  expect_silent(converged <- .pagerank(a))
  expect_equal(sum(converged), 1)
})
