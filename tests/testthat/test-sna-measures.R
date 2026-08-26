# ===========================================================================
# The measures Dynet gained to cover `tsna::tSnaStats()`.
# Reference values are computed here with `sna` where the conventions agree,
# and stated as literals where they do not.
# ===========================================================================

skip_if_no_sna <- function() skip_if_not_installed("sna")

random_matrix <- function(n, p = 0.3, seed = 1L) {
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (!is.null(old)) assign(".Random.seed", old, globalenv()), add = TRUE)
  set.seed(seed)
  a <- matrix(stats::rbinom(n * n, 1, p), n, n)
  diag(a) <- 0
  dimnames(a) <- list(paste0("v", seq_len(n)), paste0("v", seq_len(n)))
  a
}

test_that("the new kernels match sna on a range of graphs", {
  skip_if_no_sna()
  # Fixed sizes and seeds: the graphs must be the same on every run.
  sizes <- c(5L, 6L, 8L, 9L, 11L, 12L)
  for (k in seq_along(sizes)) {
    a <- random_matrix(sizes[k], seed = 40L + k)
    # sna::bonpow stops when `I - beta A` is singular; Dynet reports NA for
    # that vertex set instead of failing, so the reference is only compared
    # where it exists.
    ref_power <- tryCatch(suppressWarnings(as.numeric(sna::bonpow(a))),
                          error = function(e) NULL)
    if (is.null(ref_power)) {
      expect_true(all(is.na(.bonacich_power(a, TRUE))))
    } else {
      expect_equal(unname(.bonacich_power(a, TRUE)), ref_power)
    }
    expect_equal(unname(.harary(a, TRUE, "out")),
                 as.numeric(sna::graphcent(a, gmode = "digraph")))
    expect_equal(unname(.information(a)),
                 as.numeric(suppressWarnings(sna::infocent(a))))
    expect_equal(unname(.flow_betweenness(a, TRUE)),
                 as.numeric(sna::flowbet(a, gmode = "digraph")))
    expect_equal(.connectedness(a), sna::connectedness(a))
    expect_equal(.efficiency(a, TRUE), sna::efficiency(a))
    expect_equal(.krackhardt_hierarchy(a),
                 sna::hierarchy(a, measure = "krackhardt"))
    expect_equal(.lubness(a), suppressWarnings(sna::lubness(a)))
  }
})

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
  node <- as.data.frame(dyn_centrality(dn,
    measure = c("power", "harary", "information", "load", "flow_betweenness")))
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

test_that("load centrality follows Goh, not sna", {
  # A directed path: with no branching, load equals betweenness exactly.
  path <- matrix(0, 6, 6)
  path[cbind(1:5, 2:6)] <- 1
  dimnames(path) <- list(paste0("v", 1:6), paste0("v", 1:6))
  expect_equal(unname(.load(path, TRUE)), c(0, 4, 6, 6, 4, 0))
  expect_equal(unname(.load(path, TRUE)), unname(.betweenness(path, TRUE)))

  skip_if_no_sna()
  # sna also credits a vertex for the paths it starts and ends, so its values
  # are strictly larger here. This is a convention difference, not a bug.
  expect_true(all(sna::loadcent(path, gmode = "digraph") >
                  unname(.load(path, TRUE))))

  # The definition counts ordered pairs on an undirected graph too. The centre
  # relays 1 -> 3 and 3 -> 1, hence load two rather than one.
  undirected <- matrix(0, 3, 3)
  undirected[1, 2] <- undirected[2, 1] <- 1
  undirected[2, 3] <- undirected[3, 2] <- 1
  expect_equal(unname(.load(undirected, FALSE)), c(0, 2, 0))
})

test_that("centralisation denominators match each score convention", {
  skip_if_not_installed("igraph")
  for (n in c(5L, 8L, 12L)) {
    expect_equal(.max_centralisation("degree", n, TRUE),
                 igraph::centr_degree_tmax(igraph::make_empty_graph(n, TRUE),
                                           mode = "all", loops = FALSE))
    expect_equal(.max_centralisation("degree", n, FALSE),
                 igraph::centr_degree_tmax(igraph::make_empty_graph(n, FALSE),
                                           mode = "all", loops = FALSE))
    expect_equal(.max_centralisation("betweenness", n, TRUE),
                 igraph::centr_betw_tmax(igraph::make_empty_graph(n, TRUE),
                                         directed = TRUE))
    # Dynet's closeness remains informative on disconnected graphs. Its
    # maxima are a single directed arc and an isolated undirected dyad.
    expect_equal(.max_centralisation("closeness", n, TRUE), n - 1)
    expect_equal(.max_centralisation("closeness", n, FALSE), n - 2)
  }
  expect_true(is.na(.max_centralisation("degree", 2L, TRUE)))
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
  twice <- as.data.frame(dyn_centrality(dn, measure = ms))
  single <- as.data.frame(dyn_centrality(dn1, measure = ms))
  expect_equal(twice$value, single$value)

  # Strength is the exception, and must see the repetition.
  s2 <- as.data.frame(dyn_centrality(dn, measure = "strength"))
  s1 <- as.data.frame(dyn_centrality(dn1, measure = "strength"))
  expect_gt(sum(s2$value), sum(s1$value))
})

test_that("eigenvector direction follows mode", {
  # Reversing the graph swaps the two directed modes. This holds whatever the
  # graph, so it pins the plumbing without depending on a well-posed spectrum.
  a <- random_matrix(9L, seed = 55L)
  expect_equal(unname(.eigen_centrality(a, TRUE, "out")),
               unname(.eigen_centrality(t(a), TRUE, "in")))
  expect_equal(unname(.eigen_centrality(a, TRUE, "all")),
               unname(.eigen_centrality(t(a), TRUE, "all")))

  # On a strongly connected graph, "out" is sna's convention and "in" is
  # igraph's. The direct eigensolver also remains stable on periodic graphs;
  # the fixed graph keeps the two external comparisons reproducible.
  skip_if_no_sna()
  skip_if_not_installed("igraph")
  g <- matrix(c(0, 1, 0, 1, 1, 1,
                0, 0, 1, 1, 1, 0,
                0, 1, 0, 1, 0, 1,
                0, 0, 0, 0, 1, 1,
                1, 1, 1, 0, 0, 0,
                0, 0, 1, 0, 0, 0), 6, 6, byrow = TRUE,
              dimnames = list(paste0("v", 1:6), paste0("v", 1:6)))
  expect_equal(.components(g, "strong")$count, 1L)
  spectrum <- sort(Mod(eigen(g)$values), decreasing = TRUE)
  expect_gt(spectrum[1] - spectrum[2], 0.25)

  unit <- function(x) { x <- abs(x); x / sqrt(sum(x^2)) }
  expect_equal(unit(unname(.eigen_centrality(g, TRUE, "out"))),
               unit(as.numeric(sna::evcent(g, gmode = "digraph"))),
               tolerance = 1e-6)
  gi <- igraph::graph_from_adjacency_matrix(g, mode = "directed")
  expect_equal(unit(unname(.eigen_centrality(g, TRUE, "in"))),
               unname(unit(igraph::eigen_centrality(gi,
                                                    directed = TRUE)$vector)),
               tolerance = 1e-6)
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
