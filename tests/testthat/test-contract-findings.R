# ===========================================================================
# Review 2026-09-05, findings 5, 9 and 12: conditions in the editing verbs,
# classed conditions, and stable tie positions on undirected networks
# ===========================================================================

log <- data.frame(from = c("A", "B", "C", "D"), to = c("B", "C", "A", "A"),
                  start = c(0, 0, 1, 2), end = c(3, 1, 4, 3), grp = c("x", "y", "x", "y"),
                  stringsAsFactors = FALSE)

test_that("remove_ties, remove_arcs and update_ties take a condition on the spell table", {
  dn <- quiet_dynet(log)
  by_cond <- as.data.frame(remove_ties(dn, ties = duration > 2))
  by_mask <- as.data.frame(remove_ties(dn, ties = as.data.frame(dn)$duration > 2))
  expect_identical(by_cond, by_mask)
  expect_true(all(by_cond$duration <= 2))
  expect_identical(as.data.frame(remove_arcs(dn, ties = grp == "x")),
                   as.data.frame(remove_ties(dn, ties = grp == "x")))
  up <- as.data.frame(update_ties(dn, ties = grp == "y", data = data.frame(weight = 9)))
  expect_equal(up$weight[up$grp == "y"], c(9, 9))
  expect_equal(up$weight[up$grp == "x"], c(1, 1))
  # positions and masks still work, and a bad selector is classed
  expect_equal(nrow(as.data.frame(remove_ties(dn, ties = 1:2))), 2L)
  expect_error(remove_ties(dn, ties = 99), class = "dynet_bad_input")
})

test_that("an undirected tie keeps its row position through an edit", {
  und <- quiet_dynet(data.frame(from = c("B", "A", "C", "A"), to = c("A", "C", "B", "B"),
                                start = c(1, 1, 1, 1), end = c(2, 2, 2, 2), stringsAsFactors = FALSE),
                     directed = FALSE)
  before <- as.data.frame(und)
  after <- as.data.frame(update_ties(und, ties = 1:2, data = data.frame(weight = c(99, 98))))
  expect_identical(paste(after$from, after$to), paste(before$from, before$to))
  expect_equal(after$weight[1:2], c(99, 98))
  expect_equal(after$weight[-(1:2)], before$weight[-(1:2)])
})

test_that("deprecations, duplicate nodes and singular kernels are classed conditions", {
  dn <- quiet_dynet(log)
  expect_warning(metrics(dn, measure = "edges", sample = "instant"), class = "dynet_deprecated")
  expect_warning(centrality_series(dn, measure = "indegree"), class = "dynet_deprecated")
  expect_warning(dynet(log, nodes = data.frame(name = c("A", "A", "B", "C", "D"))),
                 class = "dynet_duplicate_nodes")
  # Bonacich power at exponent 1 on a 2-cycle: I - A is singular.
  cyc <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "A"), start = 0, end = 1))
  expect_warning(pw <- as.data.frame(centrality_series(cyc, measure = "power", exponent = 1)),
                 class = "dynet_kernel_singular")
  expect_true(all(is.na(pw$value)))
  # information centrality on a disconnected undirected snapshot
  dis <- quiet_dynet(data.frame(from = c("A", "C"), to = c("B", "D"), start = 0, end = 1), directed = FALSE)
  expect_warning(inf <- as.data.frame(centrality_series(dis, measure = "information")),
                 class = "dynet_kernel_singular")
  expect_true(all(is.na(inf$value)))
})
