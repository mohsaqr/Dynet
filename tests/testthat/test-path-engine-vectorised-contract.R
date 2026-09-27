# The path search computes a parent's entries for all its atoms in one step.
# That is only sound if the element-wise time comparisons agree with the
# scalar ones pair by pair, and if the result does not depend on atom order.

test_that("element-wise time comparisons match the scalar ones pair by pair", {
  set.seed(42)
  a <- c(runif(200, -5, 5), 1.7e9 + runif(50), 0, -0, Inf, -Inf, NA, 0.3)
  b <- c(a[sample(length(a) - 6L)] + rnorm(length(a) - 6L, sd = 1e-12),
         0, 0, 1, Inf, 1, 0.1 + 0.1 + 0.1)
  scalar_eq <- vapply(seq_along(a), function(i) .time_eq(a[[i]], b[[i]]), logical(1L))
  scalar_leq <- vapply(seq_along(a), function(i) .time_leq(a[[i]], b[[i]]), logical(1L))
  expect_identical(.time_eq_each(a, b), scalar_eq)
  expect_identical(.time_leq_each(a, b), scalar_leq)
  expect_identical(.time_tol_each(a, 2), vapply(a, function(x) .time_tol(x, 2), numeric(1L)))
})

test_that("summed arrivals still compare equal after vectorising", {
  expect_true(.time_eq_each(0.1 + 0.1 + 0.1, 0.3))
  expect_true(.time_leq_each(0.1 + 0.2, 0.3))
})

test_that("forward and backward paths do not depend on input row order", {
  e <- random_edges(seed = 5L)
  shuffled <- e[rev(seq_len(nrow(e))), , drop = FALSE]
  a <- quiet_dynet(e)
  b <- quiet_dynet(shuffled)
  fwd_a <- as.data.frame(paths(a, from = "v1", traversal_time = 0.5))
  fwd_b <- as.data.frame(paths(b, from = "v1", traversal_time = 0.5))
  expect_equal(fwd_a, fwd_b)
  bwd_a <- as.data.frame(paths(a, from = "v1", direction = "backward"))
  bwd_b <- as.data.frame(paths(b, from = "v1", direction = "backward"))
  expect_equal(bwd_a, bwd_b)
})

test_that("temporal closeness is invariant to input row order", {
  e <- random_edges(seed = 9L)
  shuffled <- e[rev(seq_len(nrow(e))), , drop = FALSE]
  a <- path_centrality(quiet_dynet(e), measure = "closeness", traversal_time = 0.1)
  b <- path_centrality(quiet_dynet(shuffled), measure = "closeness", traversal_time = 0.1)
  expect_equal(as.data.frame(a), as.data.frame(b))
})

test_that("dominated forward states are dropped without changing counts", {
  # B is reached at 1 in one hop; the detour A -> C -> B arrives later with
  # more hops and must not appear. E is reached at 2 in two hops by two
  # equally optimal routes (via D and via F); the later B -> E does not count.
  e <- data.frame(
    from = c("A", "A", "C", "A", "D", "A", "F", "B"),
    to   = c("B", "C", "B", "D", "E", "F", "E", "E"),
    time = c(1, 0, 2, 1, 2, 1, 2, 3)
  )
  dn <- quiet_dynet(e, from = "from", to = "to", time = "time")
  reached <- paths(dn, from = "A")
  expect_identical(reached$arrival_time, c(0, 1, 0, 1, 2, 1))
  expect_identical(reached$n_hops, c(0L, 1L, 1L, 1L, 2L, 1L))
  expect_identical(reached$n_paths, c(1, 1, 1, 1, 2, 1))
})

test_that("a path from an unknown vertex raises a classed condition", {
  dn <- quiet_dynet(random_edges())
  expect_error(paths(dn, from = "nobody"), class = "dynet_unknown_vertex")
})
