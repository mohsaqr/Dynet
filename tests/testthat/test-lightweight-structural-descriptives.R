test_that("literal directed structural descriptives are exact", {
  a <- matrix(0, 4, 4)
  a[cbind(c(1, 1, 2, 3), c(2, 3, 3, 1))] <- 1

  expected <- c(
    degree_mean = 2, degree_variance = 2,
    degree_min = 0, degree_max = 3,
    mean_degree = 1,
    indegree_1_5 = 2 + 2^1.5,
    outdegree_1_5 = 2 + 2^1.5,
    triangles = 2,
    concurrent_nodes = 3, concurrent_share = 0.75,
    in_2stars = 1, out_2stars = 1, two_paths = 3
  )
  got <- vapply(names(expected), function(m) {
    unname(Dynet:::.graph_measure(m, a, directed = TRUE))
  }, numeric(1))
  expect_equal(got, expected)
})

test_that("undirected descriptives use distinct neighbours", {
  a <- matrix(0, 4, 4)
  a[cbind(c(1, 2), c(2, 3))] <- 1
  a <- pmax(a, t(a))

  expect_equal(Dynet:::.graph_measure("degree_mean", a, FALSE),
               c(degree_mean = 1))
  expect_equal(Dynet:::.graph_measure("concurrent_nodes", a, FALSE),
               c(concurrent_nodes = 1))
  expect_equal(Dynet:::.graph_measure("concurrent_share", a, FALSE),
               c(concurrent_share = 0.25))
  expect_equal(Dynet:::.graph_measure("two_paths", a, FALSE),
               c(two_paths = 1))
})

test_that("directed star selectors reject undirected input", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1),
              directed = FALSE)
  expect_error(dyn_metrics(dn, "in_2stars"), class = "dynet_needs_directed")
  expect_error(dyn_metrics(dn, "out_2stars"), class = "dynet_needs_directed")
  expect_error(dyn_metrics(dn, "indegree_1_5"), class = "dynet_needs_directed")
  expect_error(dyn_metrics(dn, "outdegree_1_5"), class = "dynet_needs_directed")
})

test_that("new descriptives integrate with the tidy metric surface", {
  dn <- dynet(data.frame(
    from = c("A", "A", "B", "C"),
    to = c("B", "C", "C", "A"),
    start = 0, end = 1
  ), nodes = data.frame(name = c("A", "B", "C", "D")))
  measures <- c(
    "degree_mean", "degree_variance", "degree_min", "degree_max",
    "mean_degree", "indegree_1_5", "outdegree_1_5", "triangles",
    "concurrent_nodes", "concurrent_share", "in_2stars", "out_2stars",
    "two_paths"
  )
  got <- as.data.frame(dyn_metrics(dn, measures, start = 0, end = 1,
                                   step = 1, window = 1))
  first <- got[got$time == 0, ]
  expect_identical(first$measure, measures)
  expect_equal(first$value, c(
    8 / 3, 1 / 3, 2, 3, 4 / 3,
    2 + 2^1.5, 2 + 2^1.5, 2,
    3, 1, 1, 1, 3
  ))
  expect_true(all(got$value[got$time == 1] == 0))
})

test_that("empty eligible snapshots have typed neutral summaries", {
  a <- matrix(numeric(), 0, 0)
  zero <- c(
    "degree_mean", "degree_variance", "degree_min", "degree_max",
    "mean_degree", "indegree_1_5", "outdegree_1_5", "triangles",
    "concurrent_nodes", "concurrent_share", "in_2stars", "out_2stars",
    "two_paths"
  )
  expect_identical(vapply(zero, function(m) {
    unname(Dynet:::.graph_measure(m, a, TRUE))
  }, numeric(1)), setNames(rep(0, length(zero)), zero))
})

test_that("undirected triangles are counted once", {
  a <- matrix(0, 3, 3)
  a[cbind(c(1, 2, 3), c(2, 3, 1))] <- 1
  a <- pmax(a, t(a))
  expect_equal(Dynet:::.graph_measure("triangles", a, FALSE),
               c(triangles = 1))
  expect_equal(Dynet:::.graph_measure("mean_degree", a, FALSE),
               c(mean_degree = 2))
})
