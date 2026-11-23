# multislice_modularity(): the quality function of Mucha et al. (2010) for a partition of the windows of a
# temporal network into communities. On the bundled school_contacts spells in windows of 7, with a fixed
# membership table. References: the quality function written out in base R, igraph's modularity() of each
# slice when the slices are not coupled, and multinet's modularity_ml() for coupled slices (categorical coupling,
# seeded random layers; at the end of the file).

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
network <- dynet(school_contacts)
onsets <- c(0, 7, 14, 21)

#' A membership table: three communities by name order, the last two swapping two members from the third bin on
fixed_membership <- function() {
  base <- rep(1:3, length.out = length(people))
  later <- base
  later[c(1L, 2L)] <- later[c(2L, 1L)]
  data.frame(time = rep(onsets, each = length(people)), node = rep(people, length(onsets)),
             community = c(base, base, later, later))
}

#' The layers multislice_modularity() reads: per window, spell counts per ordered pair, symmetrised as (W + W') / 2
weighted_layers <- function() {
  lapply(onsets, \(lo) {
    inside <- subset(spells, start < lo + 7 & end > lo)
    counts <- unclass(table(factor(inside$from, people), factor(inside$to, people)))
    (counts + t(counts)) / 2
  })
}

test_that("multislice modularity equals Mucha et al.'s quality function written out", {
  layers <- weighted_layers()
  membership <- fixed_membership()
  labels <- split(membership$community, membership$time)
  omega <- 1
  intra <- sum(vapply(seq_along(layers), \(s) {
    a <- layers[[s]]
    k <- rowSums(a)
    same <- outer(labels[[s]], labels[[s]], `==`)
    sum((a - outer(k, k) / sum(a)) * same)
  }, numeric(1)))
  # Ordinal coupling: each state is joined to itself in the next and the previous slice.
  inter <- 2 * omega * sum(vapply(seq_len(length(layers) - 1L), \(s) sum(labels[[s]] == labels[[s + 1L]]), numeric(1)))
  two_mu <- sum(vapply(layers, sum, numeric(1))) + 2 * omega * length(people) * (length(layers) - 1L)
  theirs <- data.frame(measure = c("q", "q_intra", "q_inter", "two_mu", "n_communities", "n_empty_slices"),
                       value = c((intra + inter) / two_mu, intra / two_mu, inter / two_mu, two_mu,
                                 length(unique(membership$community)), sum(vapply(layers, sum, numeric(1)) == 0)))
  ours <- as.data.frame(multislice_modularity(network, membership = membership, omega = omega, step = 7, window = 7))
  # Sums of a few hundred products of small rationals.
  expect_reference(ours, theirs, reference = "independent: Mucha et al. (2010) multislice modularity, base R",
                   covers = c("multislice_modularity()", "as.data.frame.dynet_modularity()"),
                   quantity = "omega = 1, ordinal coupling", tolerance = 1e-12, key = "measure")
})

test_that("multislice modularity without coupling is the weighted mean of igraph's modularity of each slice", {
  skip_without_reference("igraph")
  layers <- weighted_layers()
  membership <- fixed_membership()
  labels <- split(membership$community, membership$time)
  per_slice <- vapply(seq_along(layers), \(s) {
    graph <- igraph::graph_from_adjacency_matrix(layers[[s]], mode = "undirected", weighted = TRUE, diag = TRUE)
    c(q = igraph::modularity(graph, membership = labels[[s]], weights = igraph::E(graph)$weight),
      total = sum(layers[[s]]))
  }, numeric(2))
  theirs <- data.frame(measure = "q", value = sum(per_slice["q", ] * per_slice["total", ]) / sum(per_slice["total", ]))
  ours <- subset(as.data.frame(multislice_modularity(network, membership = membership, omega = 0, step = 7,
                                                     window = 7)), measure == "q")
  expect_reference(ours, theirs, reference = "igraph",
                   covers = c("multislice_modularity()", "as.data.frame.dynet_modularity()"),
                   quantity = "omega = 0", tolerance = 1e-12, key = "measure")
})

# Coupled slices against an outside implementation: multinet's modularity_ml() (uunet), the generalised
# modularity of a multilayer partition with every vertex coupled to itself in every other layer, that is
# Dynet's coupling = "categorical". multinet takes unweighted undirected layers, so the input is seeded random
# undirected ties per window, each listed in both directions (Dynet averages a slice with its transpose: weight 1).
# A probe on ci (2026-11-23) found that modularity_ml() leaves the i = j terms of the null model (k_is^2 / 2m_s)
# out of the sum, which Mucha et al. (2010, eq. 1) and Dynet keep, and that it ignores gamma. The coupling term
# does not involve the null model, so it is compared as a reference: multinet's value at omega minus its value at
# omega = 0 rescaled to the larger denominator, (Q(omega) 2mu(omega) - Q(0) 2mu(0)) / 2mu(omega), with
# 2mu(omega) = sum of 2m_s + omega n T (T - 1) from the data. The total is declared a known difference.

coupled_case <- function(seed, n = 12L, windows = 4L, density = 0.25) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
          add = TRUE)
  set.seed(seed)
  nodes <- sprintf("n%02d", seq_len(n))
  pairs <- subset(expand.grid(from = nodes, to = nodes, stringsAsFactors = FALSE), from < to)
  ties <- do.call(rbind, lapply(seq_len(windows) - 1L, \(w) {
    kept <- pairs[stats::runif(nrow(pairs)) < density, ]
    data.frame(from = kept$from, to = kept$to, start = 7 * w + 1, end = 7 * w + 2, window = w)
  }))
  membership <- data.frame(time = rep(7 * (seq_len(windows) - 1L), each = n), node = rep(nodes, windows),
                           community = sample(3L, n * windows, replace = TRUE))
  list(nodes = nodes, windows = windows, ties = ties, membership = membership)
}

multinet_quality <- function(case, omega) {
  layered <- multinet::ml_empty()
  layers <- sprintf("w%d", seq_len(case$windows) - 1L)
  multinet::add_layers_ml(layered, layers, directed = FALSE)
  multinet::add_vertices_ml(layered, data.frame(actor = rep(case$nodes, case$windows),
                                               layer = rep(layers, each = length(case$nodes))))
  multinet::add_edges_ml(layered, data.frame(actor1 = case$ties$from, layer1 = layers[case$ties$window + 1L],
                                            actor2 = case$ties$to, layer2 = layers[case$ties$window + 1L]))
  multinet::modularity_ml(layered, data.frame(actor = case$membership$node,
                                              layer = layers[case$membership$time / 7 + 1L],
                                              cid = case$membership$community - 1L), omega = omega)
}

test_that("the coupling term at omega > 0 equals multinet::modularity_ml()'s; the total differs by the i = j terms", {
  skip_without_reference("multinet")
  grid <- expand.grid(seed = c(11L, 12L, 13L), omega = c(0.5, 1, 2))
  rows <- lapply(seq_len(nrow(grid)), \(i) {
    case <- coupled_case(grid$seed[[i]])
    omega <- grid$omega[[i]]
    both_ways <- with(case$ties, data.frame(from = c(from, to), to = c(to, from), start = c(start, start),
                                            end = c(end, end)))
    network <- dynet(both_ways, observation_start = 0, observation_end = 7 * case$windows)
    ours <- as.data.frame(multislice_modularity(network, membership = case$membership, omega = omega,
                                                coupling = "categorical", step = 7, window = 7))
    two_m <- 2 * nrow(case$ties)
    two_mu <- two_m + omega * length(case$nodes) * case$windows * (case$windows - 1L)
    label <- sprintf("seed %d, omega %g", grid$seed[[i]], omega)
    list(ours = data.frame(case = label, measure = ours$measure, value = ours$value),
         inter = data.frame(case = label, measure = "q_inter",
                            value = (multinet_quality(case, omega) * two_mu - multinet_quality(case, 0) * two_m) / two_mu),
         total = data.frame(case = label, measure = "q", value = multinet_quality(case, omega)))
  })
  stack <- \(part) do.call(rbind, lapply(rows, `[[`, part))
  ours <- stack("ours")
  # Sums of a few hundred terms of small rationals.
  expect_reference(subset(ours, measure == "q_inter"), stack("inter"), reference = "multinet",
                   covers = c("multislice_modularity()", "as.data.frame.dynet_modularity()"),
                   quantity = "coupling term, categorical coupling", tolerance = 1e-12, key = c("case", "measure"))
  expect_known_difference(subset(ours, measure == "q"), stack("total"), reference = "multinet",
                          covers = "multislice_modularity()", quantity = "multislice modularity, categorical coupling",
                          tolerance = 1e-12, key = c("case", "measure"),
                          reason = paste("multinet's modularity_ml() leaves the i = j terms of the null model",
                                         "(k_is^2 / 2m_s) out of the sum; Mucha et al. (2010, eq. 1) and Dynet keep them."),
                          agrees_with = "the quality function of Mucha et al. (2010) without its i = j null-model terms")
})
