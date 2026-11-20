# temporal_communities(): a multislice Louvain search (Mucha et al. 2010). Its moves are drawn on the package's own
# stream (seeds = replays it), and GenLouvain or multinet's glouvain find their own optima, so the partition itself
# has no reference. What holds for any draw is checked from the definition: the result is a partition of the
# node-time states (every vertex labelled exactly once in every window), and the quality it reports equals Mucha
# et al.'s multislice modularity of that partition, written out in base R, and its community sizes are counts of
# the membership table. Several seed sets and couplings.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
onsets <- c(0, 7, 14, 21)
network <- dynet(school_contacts)
seed_sets <- list(1:3, 4:6, 7:9)
couplings <- c(0.5, 1, 2)

#' The layers the quality function reads: per window, spells per ordered pair, symmetrised as (W + W') / 2
weighted_layers <- function() {
  lapply(onsets, \(lo) {
    inside <- subset(spells, start < lo + 7 & end > lo)
    counts <- unclass(table(factor(inside$from, people), factor(inside$to, people)))
    (counts + t(counts)) / 2
  })
}

#' Mucha et al.'s multislice modularity of a membership table, ordinal coupling, gamma = 1
mucha_q <- function(membership, omega) {
  layers <- weighted_layers()
  labels <- lapply(onsets, \(t) {
    one <- subset(membership, time == t)
    one$community[match(people, one$node)]
  })
  intra <- sum(vapply(seq_along(layers), \(s) {
    a <- layers[[s]]
    k <- rowSums(a)
    sum((a - outer(k, k) / sum(a)) * outer(labels[[s]], labels[[s]], `==`))
  }, numeric(1)))
  inter <- 2 * omega * sum(vapply(seq_len(length(layers) - 1L), \(s) sum(labels[[s]] == labels[[s + 1L]]),
                                  numeric(1)))
  two_mu <- sum(vapply(layers, sum, numeric(1))) + 2 * omega * length(people) * (length(layers) - 1L)
  (intra + inter) / two_mu
}

runs <- function() {
  grid <- expand.grid(set = seq_along(seed_sets), omega = couplings)
  lapply(seq_len(nrow(grid)), \(i) {
    found <- temporal_communities(network, omega = grid$omega[[i]], seeds = seed_sets[[grid$set[[i]]]], step = 7,
                                  window = 7)
    list(case = sprintf("seeds %s, omega %s", paste(range(seed_sets[[grid$set[[i]]]]), collapse = "-"),
                        grid$omega[[i]]),
         omega = grid$omega[[i]], found = found, membership = as.data.frame(found))
  })
}

test_that("every vertex carries exactly one label in every window", {
  rows <- do.call(rbind, lapply(runs(), \(run) {
    states <- table(factor(run$membership$node, people), factor(run$membership$time, onsets))
    labelled <- !is.na(run$membership$community)
    data.frame(case = run$case, labels_per_state_min = min(states), labels_per_state_max = max(states),
               unlabelled = sum(!labelled))
  }))
  expect_reference(rows, transform(rows, labels_per_state_min = 1, labels_per_state_max = 1, unlabelled = 0),
                   reference = "independent: a partition of the node-time states (definition)",
                   covers = c("temporal_communities()", "as.data.frame.dynet_communities()"),
                   quantity = "states labelled once", tolerance = 0, key = "case")
})

test_that("the reported quality equals Mucha et al.'s multislice modularity of the reported partition", {
  rows <- lapply(runs(), \(run) {
    best <- subset(as.data.frame(run$found, what = "runs"), best)
    list(ours = data.frame(case = run$case, q = best$q[[1L]]),
         theirs = data.frame(case = run$case, q = mucha_q(run$membership, run$omega)))
  })
  # Sums of a few hundred products of small rationals.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "independent: Mucha et al. (2010) multislice modularity, base R",
                   covers = "temporal_communities()", quantity = "best run's q", tolerance = 1e-12, key = "case")
})

test_that("summary() gives each community's states, vertices, first and last window and bins from the membership", {
  rows <- lapply(runs(), \(run) {
    m <- run$membership
    parts <- split(m, m$community)
    theirs <- do.call(rbind, lapply(names(parts), \(k) {
      one <- parts[[k]]
      data.frame(case = run$case, community = as.integer(k), n_states = nrow(one),
                 n_nodes = length(unique(one$node)), first_time = min(one$time), last_time = max(one$time),
                 n_bins = length(unique(one$time)))
    }))
    list(ours = transform(summary(run$found), case = run$case), theirs = theirs)
  })
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "independent: counts of the membership table",
                   covers = "summary.dynet_communities()", quantity = "community sizes", tolerance = 0,
                   key = c("case", "community"))
})
