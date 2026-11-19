# multislice_modularity(): the quality function of Mucha et al. (2010) for a partition of the windows of a
# temporal network into communities. On the bundled school_contacts spells in windows of 7, with a fixed
# membership table. References: the quality function written out in base R, and igraph's modularity() of each
# slice when the slices are not coupled.

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
  expect_reference(ours, theirs, reference = "igraph", covers = "multislice_modularity()",
                   quantity = "omega = 0", tolerance = 1e-12, key = "measure")
})
