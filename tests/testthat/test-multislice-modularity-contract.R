# Item 2: the Mucha et al. (2010) quality function. Its whole point is that
# the null is slice-local and that no null is subtracted from the coupling;
# the two calibrations below are what pin that.

crossover_network <- function() {
  nm <- LETTERS[1:8]
  clique <- function(v, t) {
    p <- t(utils::combn(v, 2L))
    data.frame(from = p[, 1L], to = p[, 2L], time = t, stringsAsFactors = FALSE)
  }
  dynet(rbind(clique(nm[1:4], 0), clique(nm[5:8], 0),
              clique(nm[1:3], 1), clique(nm[4:8], 1)),
        format = "contact", directed = FALSE,
        nodes = data.frame(name = nm),
        observation_start = 0, observation_end = 2)
}

crossover_partition <- function(labels) {
  data.frame(time = rep(0:1, each = 8L), node = rep(LETTERS[1:8], 2L),
             community = labels, stringsAsFactors = FALSE)
}

q_of <- function(dn, membership, ...) {
  out <- as.data.frame(multislice_modularity(dn, membership = membership,
                                             step = 1, window = 1, ...))
  stats::setNames(out$value, out$measure)
}

test_that("a membership frame missing its contract is refused", {
  dn <- crossover_network()
  expect_error(multislice_modularity(dn, membership = data.frame(node = "A")),
               class = "dynet_bad_input")
  expect_error(multislice_modularity(dn, gamma = -1), class = "dynet_bad_input")
  expect_error(multislice_modularity(dn, omega = -1), class = "dynet_bad_input")
  expect_error(multislice_modularity(dn, coupling = "chain"))
})

test_that("a membership naming a vertex the network does not have is refused", {
  # Vertices are addressed by name, so a typo must be caught rather than
  # silently dropping that vertex from the partition.
  dn <- crossover_network()
  bad <- crossover_partition(rep(1L, 16L))
  bad$node[[1L]] <- "Zebra"
  expect_error(multislice_modularity(dn, membership = bad, step = 1,
                                     window = 1),
               class = "dynet_unknown_node")
})

test_that("a membership that does not cover every state is refused", {
  dn <- crossover_network()
  partial <- crossover_partition(rep(1L, 16L))[1:8, ]
  expect_error(multislice_modularity(dn, membership = partial, step = 1,
                                     window = 1),
               class = "dynet_bad_input")
})

test_that("one slice with no coupling is Newman-Girvan modularity", {
  # Calibration one. With T = 1 the interlayer strength is zero, so 2mu is
  # the slice total and Q reduces exactly to the static definition.
  skip_if_not_installed("igraph")
  set.seed(7)
  n <- 12L
  nm <- sprintf("v%02d", seq_len(n))
  pairs <- t(utils::combn(n, 2L))
  keep <- stats::runif(nrow(pairs)) < 0.35
  edges <- pairs[keep, , drop = FALSE]
  group <- rep(1:3, each = 4L)
  dn <- dynet(data.frame(from = nm[edges[, 1L]], to = nm[edges[, 2L]],
                         time = 0),
              format = "contact", directed = FALSE,
              nodes = data.frame(name = nm),
              observation_start = 0, observation_end = 1)
  membership <- data.frame(time = 0, node = nm, community = group,
                           stringsAsFactors = FALSE)
  mine <- q_of(dn, membership, omega = 0)[["q"]]
  g <- igraph::graph_from_edgelist(cbind(nm[edges[, 1L]], nm[edges[, 2L]]),
                                   directed = FALSE)
  theirs <- igraph::modularity(g, membership = group[match(
    igraph::V(g)$name, nm)])
  expect_equal(mine, theirs, tolerance = sqrt(.Machine$double.eps))
})

test_that("no coupling makes Q the slice-weighted mean of static modularity", {
  # Calibration two, and the sharper of the pair: it pins the normaliser as
  # well as the null, because the weights are the slice totals.
  skip_if_not_installed("igraph")
  set.seed(11)
  n <- 12L
  nm <- sprintf("v%02d", seq_len(n))
  group <- rep(1:3, each = 4L)
  pairs <- t(utils::combn(n, 2L))
  draw <- function(p, t) {
    keep <- stats::runif(nrow(pairs)) < p
    data.frame(from = nm[pairs[keep, 1L]], to = nm[pairs[keep, 2L]], time = t,
               stringsAsFactors = FALSE)
  }
  dn <- dynet(rbind(draw(0.5, 0), draw(0.2, 1)), format = "contact",
              directed = FALSE, nodes = data.frame(name = nm),
              observation_start = 0, observation_end = 2)
  membership <- data.frame(time = rep(c(0, 1), each = n), node = rep(nm, 2L),
                           community = rep(group, 2L), stringsAsFactors = FALSE)
  mine <- q_of(dn, membership, omega = 0)[["q"]]
  supra <- Dynet:::.supra(projection(dn, step = 1, window = 1, omega = 0))
  per_slice <- vapply(supra$blocks[[1L]]$layers, function(a) {
    g <- igraph::graph_from_adjacency_matrix(a, mode = "undirected",
                                             weighted = TRUE)
    c(q = igraph::modularity(g, membership = group,
                             weights = igraph::E(g)$weight),
      total = sum(a))
  }, numeric(2L))
  weighted <- sum(per_slice["q", ] * per_slice["total", ]) /
    sum(per_slice["total", ])
  expect_equal(mine, weighted, tolerance = sqrt(.Machine$double.eps))
})

test_that("the parts of the decomposition sum to the whole", {
  dn <- crossover_network()
  for (omega in c(0, 0.5, 3)) {
    parts <- q_of(dn, crossover_partition(rep(c(1, 1, 1, 1, 2, 2, 2, 2), 2L)),
                  omega = omega)
    expect_equal(parts[["q_intra"]] + parts[["q_inter"]], parts[["q"]],
                 tolerance = sqrt(.Machine$double.eps))
  }
})

test_that("Q reads the partition, not the names its communities happen to carry", {
  dn <- crossover_network()
  base <- rep(c(1, 1, 1, 1, 2, 2, 2, 2), 2L)
  renamed <- ifelse(base == 1, 9, 3)
  expect_equal(q_of(dn, crossover_partition(base), omega = 1)[["q"]],
               q_of(dn, crossover_partition(renamed), omega = 1)[["q"]])
  lettered <- ifelse(base == 1, "left", "right")
  expect_equal(q_of(dn, crossover_partition(base), omega = 1)[["q"]],
               q_of(dn, crossover_partition(lettered), omega = 1)[["q"]])
})

test_that("one community for everything and no coupling scores exactly zero", {
  # With gamma = 1 the observed edges and their expectation cancel term for
  # term, which is the definition of the baseline.
  dn <- crossover_network()
  expect_equal(q_of(dn, crossover_partition(rep(1L, 16L)), omega = 0)[["q"]], 0,
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(q_of(dn, NULL, omega = 0)[["q"]], 0,
               tolerance = sqrt(.Machine$double.eps))
})

test_that("omega decides whether persistence beats tracking, at a fixed point", {
  # Eight vertices, two slices: two four-cliques, then a three-clique and a
  # five-clique as D defects. The persistent partition ignores the defection;
  # the switching one follows it. Which wins is the whole meaning of omega,
  # and the crossover sits between 2 and 2.5. Any change to the null or the
  # normaliser moves these numbers.
  dn <- crossover_network()
  persistent <- crossover_partition(rep(c(1, 1, 1, 1, 2, 2, 2, 2), 2L))
  switching <- crossover_partition(c(1, 1, 1, 1, 2, 2, 2, 2,
                                     1, 1, 1, 2, 2, 2, 2, 2))
  single <- crossover_partition(rep(1L, 16L))
  # Quoted to five decimals from an independent prototype written before this
  # implementation existed, so the tolerance is the fixture's precision.
  frozen <- data.frame(
    omega = c(0, 0.25, 1, 2, 2.5, 5),
    persistent = c(0.32615, 0.37607, 0.48951, 0.58912, 0.62564, 0.74083),
    switching = c(0.42462, 0.45798, 0.53380, 0.60038, 0.62479, 0.70178),
    single = c(0.00000, 0.07407, 0.24242, 0.39024, 0.44444, 0.61538))
  for (row in seq_len(nrow(frozen))) {
    omega <- frozen$omega[[row]]
    expect_equal(q_of(dn, persistent, omega = omega)[["q"]],
                 frozen$persistent[[row]], tolerance = 1e-4)
    expect_equal(q_of(dn, switching, omega = omega)[["q"]],
                 frozen$switching[[row]], tolerance = 1e-4)
    expect_equal(q_of(dn, single, omega = omega)[["q"]],
                 frozen$single[[row]], tolerance = 1e-4)
  }
  # Persistence is monotone in omega and overtakes tracking exactly once.
  expect_true(all(diff(frozen$persistent) > 0))
  ahead <- frozen$persistent > frozen$switching
  expect_identical(ahead, c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE))
})

test_that("an edgeless slice is counted, not divided by", {
  nm <- LETTERS[1:4]
  dn <- dynet(data.frame(from = c("A", "C"), to = c("B", "D"),
                         time = c(0, 0)),
              format = "contact", directed = FALSE,
              nodes = data.frame(name = nm),
              observation_start = 0, observation_end = 3)
  parts <- q_of(dn, NULL, omega = 1)
  expect_true(is.finite(parts[["q"]]))
  expect_false(is.nan(parts[["q"]]))
  expect_gte(parts[["n_empty_slices"]], 1)
})

test_that("a network with no edges and no coupling has no Q at all", {
  nm <- LETTERS[1:4]
  dn <- dynet(data.frame(from = "A", to = "B", time = 0), format = "contact",
              directed = FALSE, nodes = data.frame(name = nm),
              observation_start = 0, observation_end = 6)
  expect_error(
    multislice_modularity(dn, omega = 0, start = 3, end = 5, step = 1,
                          window = 1),
    class = "dynet_empty_result")
})

test_that("metadata records the choices Q depends on", {
  dn <- crossover_network()
  out <- multislice_modularity(dn, gamma = 1.5, omega = 0.25, step = 1,
                               window = 1)
  expect_identical(attr(out, "gamma"), 1.5)
  expect_identical(attr(out, "omega"), 0.25)
  expect_identical(attr(out, "coupling"), "ordinal")
  expect_false(attr(out, "symmetrised"))
})
