# ===========================================================================
# Review 2026-09-05, findings 3, 4 and 14
# ===========================================================================

test_that("a degenerate spectrum gives NA under a classed warning, a certified one a Perron ray", {
  # Bin 1 is a directed path A -> B -> C: acyclic, spectral radius zero.
  # Bin 2 is the 3-cycle A -> B -> C -> A: strongly connected, unique ray.
  sp <- data.frame(from = c("A", "B", "A", "B", "C"), to = c("B", "C", "B", "C", "A"),
                   start = c(0, 0, 1, 1, 1), end = c(1, 1, 2, 2, 2))
  dn <- quiet_dynet(sp)
  expect_warning(
    got <- as.data.frame(dyn_centrality(dn, measure = "eigenvector", mode = "out")),
    class = "dynet_eigen_undefined")
  expect_true(all(is.na(got$value[got$time == 0])))
  cyc <- got$value[got$time == 1]
  expect_equal(cyc, c(1, 1, 1))
  # hub and authority on a bin whose A A' has a repeated top eigenvalue: two
  # disjoint arcs A -> B and C -> D.
  two <- quiet_dynet(data.frame(from = c("A", "C"), to = c("B", "D"), start = 0, end = 1))
  expect_warning(h <- as.data.frame(dyn_centrality(two, measure = "hub")),
                 class = "dynet_eigen_undefined")
  expect_true(all(is.na(h$value)))
})

test_that("a certified eigenvector satisfies its eigen-equation on a strongly connected snapshot", {
  set.seed(3)
  dn <- quiet_dynet(random_edges(n_v = 8L, n_e = 80L, span = 4, seed = 3L))
  got <- as.data.frame(dyn_centrality(dn, measure = "eigenvector", mode = "out", window = "all"))
  if (!anyNA(got$value)) {
    a <- as.data.frame(collapse_network(dn))
    who <- as.data.frame(dn, what = "nodes")$name
    A <- matrix(0, length(who), length(who), dimnames = list(who, who)); A[cbind(a$from, a$to)] <- 1
    v <- got$value[match(who, got$node)]
    rho <- max(Mod(eigen(A, only.values = TRUE)$values))
    expect_lt(max(abs(A %*% v - rho * v)), 1e-9)
  }
  succeed()
})

test_that("a weight column is picked up, with a message, unless named otherwise", {
  sp <- data.frame(from = c("A", "B"), to = c("B", "C"), start = c(0, 1), end = c(2, 3),
                   weight = c(5, 7), strength = c(1, 1))
  expect_message(dn <- dynet(sp), "Using column `weight`")
  expect_equal(sort(as.data.frame(dn)$weight), c(5, 7))
  explicit <- quiet_dynet(sp, weight = "strength")
  expect_equal(as.data.frame(explicit)$weight, c(1, 1))
  plain <- quiet_dynet(sp[, c("from", "to", "start", "end")])
  expect_equal(as.data.frame(plain)$weight, c(1, 1))
  bad <- transform(sp, weight = c("a", "b"))
  expect_error(dynet(bad), class = "dynet_bad_input")
})

test_that("point sampling on the default grid reaches the last observed instant", {
  ed <- data.frame(from = c("n0", "n1", "n0", "n2", "n3", "n1"), to = c("n1", "n2", "n2", "n3", "n0", "n3"),
                   time = c(0, 1, 2, 2, 3, 3))
  dn <- quiet_dynet(ed, time = "time")
  pts <- as.data.frame(metrics(dn, measure = "edges", window = 0))
  expect_equal(pts$time, 0:3)
  expect_equal(pts$value[pts$time == 3], 2)
  # an explicit end is still literal, and a positive window still stops at
  # the last window that opens inside the period
  expect_equal(as.data.frame(metrics(dn, measure = "edges", window = 0, end = 2))$time, 0:2)
  expect_equal(as.data.frame(metrics(dn, measure = "edges"))$time, 0:2)
  # and the default point grid equals the explicit one over the whole range
  explicit <- as.data.frame(metrics(dn, measure = "edges", window = 0, start = 0, end = 3))
  expect_equal(pts$value, explicit$value)
})
