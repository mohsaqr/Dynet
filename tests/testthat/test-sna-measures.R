# ===========================================================================
# The measures Dynet gained to cover `tsna::tSnaStats()`.
# Reference values are computed here with `sna` where the conventions agree,
# and stated as literals where they do not.
# ===========================================================================

test_that("Krackhardt's indices take known values on the shapes they describe", {
  # A perfect out-tree: connected, efficient, wholly hierarchical, and every
  # pair has the root as a least upper bound.
  tree <- matrix(0, 7, 7)
  tree[1, 2:3] <- 1; tree[2, 4:5] <- 1; tree[3, 6:7] <- 1
  expect_equal(.connectedness(tree), 1)
  expect_equal(.efficiency(tree, TRUE), 1)
  expect_equal(.krackhardt_hierarchy(tree), 1)
  expect_equal(.lubness(tree), 1)

  # A directed cycle: connected, but reachability is symmetric throughout, so
  # there is no hierarchy at all.
  cyc <- matrix(0, 5, 5)
  cyc[cbind(1:5, c(2:5, 1))] <- 1
  expect_equal(.connectedness(cyc), 1)
  expect_equal(.krackhardt_hierarchy(cyc), 0)

  # Two disjoint pairs: each component contributes its two ordered pairs out
  # of the twelve in the graph, and no component holds three vertices, so
  # LUBness has nothing to measure.
  split <- matrix(0, 4, 4); split[1, 2] <- 1; split[3, 4] <- 1
  expect_equal(.connectedness(split), 4 / 12)
  expect_true(is.nan(.lubness(split)))
})

test_that("the new measures reach the public verbs", {
  dn <- quiet_dynet(random_edges(seed = 30L), interval = 4)
  # Bonacich power hits a singular `I - beta A` on some blocks; that is now a
  # classed warning rather than a silent NA (review 2026-09-05, finding 9).
  expect_warning(
    node <- as.data.frame(centrality_series(dn,
      measure = c("power", "harary", "information", "load", "flow_betweenness"))),
    class = "dynet_kernel_singular")
  expect_setequal(unique(node$measure),
                  c("power", "harary", "information", "load",
                    "flow_betweenness"))
  # Bonacich power is NA where `I - beta A` is singular, which is documented;
  # nothing else may go missing.
  finite_only <- node$value[node$measure != "power"]
  expect_true(all(is.finite(finite_only)))

  graph <- as.data.frame(metrics(dn,
    measure = c("connectedness", "efficiency", "hierarchy", "lubness",
                "components_strong")))
  expect_setequal(unique(graph$measure),
                  c("connectedness", "efficiency", "hierarchy", "lubness",
                    "components_strong"))
  conn <- graph$value[graph$measure == "connectedness"]
  expect_true(all(conn >= 0 & conn <= 1))
  # Strong components can never be fewer than weak ones.
  weak <- as.data.frame(metrics(dn, measure = "components"))$value
  expect_true(all(graph$value[graph$measure == "components_strong"] >= weak))
})

test_that("closeness centralisation stays bounded on disconnected graphs", {
  for (directed in c(TRUE, FALSE)) {
    a <- matrix(0, 5, 5)
    a[1, 2] <- 1
    if (!directed) a[2, 1] <- 1
    got <- .graph_measure("centralization_closeness", a, directed)
    expect_gte(unname(got), 0)
    expect_lte(unname(got), 1)
    expect_equal(unname(got), 1)
  }
})

test_that("undefined and empty spectral fixtures are explicit", {
  empty <- matrix(0, 4, 4)
  expect_equal(unname(.bonacich_power(empty)), rep(0, 4))

  # Two disconnected dyads make the information matrix singular. Returning
  # NA is safer than sna's error and makes the undefined snapshot explicit.
  split <- matrix(0, 4, 4)
  split[1, 2] <- split[2, 1] <- 1
  split[3, 4] <- split[4, 3] <- 1
  expect_true(all(is.na(.information(split))))
})

test_that("an edge counts once however many spells produced it", {
  # Two spells join A and B inside the same bin; a third pair joins once. No
  # centrality may read the repetition as extra structure -- that is what
  # `strength` is for.
  sp <- data.frame(from = c("A", "A", "B"), to = c("B", "B", "C"),
                   start = c(0, 0.2, 0.4), end = c(0.5, 0.6, 0.8),
                   stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, interval = 2)
  once <- data.frame(from = c("A", "B"), to = c("B", "C"),
                     start = c(0, 0.4), end = c(0.5, 0.8),
                     stringsAsFactors = FALSE)
  dn1 <- quiet_dynet(once, interval = 2)

  ms <- c("degree", "closeness", "betweenness", "eigenvector", "pagerank",
          "coreness", "power", "harary", "information", "load")
  twice <- as.data.frame(centrality_series(dn, measure = ms))
  single <- as.data.frame(centrality_series(dn1, measure = ms))
  expect_equal(twice$value, single$value)

  # Strength is the exception, and must see the repetition.
  s2 <- as.data.frame(centrality_series(dn, measure = "strength"))
  s1 <- as.data.frame(centrality_series(dn1, measure = "strength"))
  expect_gt(sum(s2$value), sum(s1$value))
})

test_that("max flow is symmetric on an undirected graph and honours cuts", {
  # A bottleneck: two triangles joined by a single edge carries one unit.
  a <- matrix(0, 6, 6)
  for (e in list(c(1,2), c(2,3), c(1,3), c(4,5), c(5,6), c(4,6), c(3,4))) {
    a[e[1], e[2]] <- 1; a[e[2], e[1]] <- 1
  }
  expect_equal(.max_flow(a, 1, 6), 1)
  expect_equal(.max_flow(a, 6, 1), 1)
  expect_equal(.max_flow(a, 1, 2), 2)
  # No path, no flow.
  b <- matrix(0, 3, 3); b[1, 2] <- 1
  expect_equal(.max_flow(b, 1, 3), 0)
  expect_equal(.max_flow(b, 2, 1), 0)
})
