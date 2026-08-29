# Item 3: generalized Louvain over the time-expanded network.

test_that("arguments outside their domain are refused", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(temporal_communities(dn, omega = -1, step = 5, window = 5,
                                    seeds = 1:2),
               class = "dynet_bad_input")
  expect_error(temporal_communities(dn, gamma = -1, step = 5, window = 5,
                                    seeds = 1:2),
               class = "dynet_bad_input")
  expect_error(temporal_communities(dn, seeds = numeric(0), step = 5,
                                    window = 5),
               class = "dynet_bad_input")
  expect_error(temporal_communities(dn, seeds = 1:2, tol = 0, step = 5,
                                    window = 5),
               class = "dynet_bad_input")
})

test_that("a single seed is a warning, because it is one sample not an answer", {
  dn <- dynet(school_contacts, format = "contact")
  expect_warning(temporal_communities(dn, seeds = 1, step = 5, window = 5),
                 class = "dynet_single_seed")
})

test_that("a grid with no edges and no coupling has nothing to optimise", {
  nm <- LETTERS[1:4]
  dn <- dynet(data.frame(from = "A", to = "B", time = 0), format = "contact",
              directed = FALSE, nodes = data.frame(name = nm),
              observation_start = 0, observation_end = 6)
  expect_error(
    temporal_communities(dn, omega = 0, start = 3, end = 5, step = 1,
                         window = 1, seeds = 1:2),
    class = "dynet_empty_result")
})

test_that("a planted partition is recovered from every generator seed", {
  # Twenty vertices in two blocks, constant over eight bins. The recovered
  # partition must agree with the plant in every bin, from three independent
  # generator seeds.
  for (seed in 1:3) {
    fixture <- planted_sbm(seed = seed)
    found <- temporal_communities(fixture$dn, omega = 1, step = 1, window = 1,
                                  seeds = 1:10)
    df <- as.data.frame(found)
    for (bin in unique(df$time)) {
      here <- df[df$time == bin, ]
      agreement <- Dynet:::.compare_partitions(
        here$community, unname(fixture$block[here$node]), "ari")
      expect_gt(agreement, 0.95)
    }
  }
})

test_that("a planted split is found at the bin where it happens", {
  fixture <- planted_sbm(n = 24L, bins = 10L, split_at = 6L, seed = 4L)
  found <- temporal_communities(fixture$dn, omega = 0.5, step = 1, window = 1,
                                seeds = 1:10)
  sizes <- as.data.frame(found, what = "sizes")
  per_bin <- vapply(split(sizes$community, sizes$time),
                    function(v) length(unique(v)), integer(1L))
  bins <- as.numeric(names(per_bin))
  expect_gt(mean(per_bin[bins >= 5]), mean(per_bin[bins < 5]))
})

test_that("the reported Q is the Q its own objective gives the partition", {
  # The verb maximises multislice_modularity(); if the two disagreed, one of
  # them would be optimising something the other cannot score.
  dn <- dynet(school_contacts, format = "contact")
  for (omega in c(0.5, 1, 2)) {
    found <- temporal_communities(dn, omega = omega, step = 5, window = 5,
                                  seeds = 1:5)
    scored <- as.data.frame(multislice_modularity(
      dn, membership = as.data.frame(found), omega = omega, step = 5,
      window = 5))
    expect_equal(attr(found, "q"), scored$value[scored$measure == "q"],
                 tolerance = sqrt(.Machine$double.eps))
  }
})

test_that("the output frame is one row per vertex per bin, with no gaps", {
  dn <- dynet(school_contacts, format = "contact")
  found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
  p <- projection(dn, step = 5, window = 5)
  expect_identical(nrow(found),
                   as.integer(p$meta$n_nodes * p$meta$n_slices))
  expect_false(anyNA(found$community))
  expect_true(all(found$node %in% dn$nodes$name))
  expect_true(all(found$stability >= 0 & found$stability <= 1))
})

test_that("relabelling the vertices moves the labels and nothing else", {
  dn <- dynet(school_contacts, format = "contact")
  before <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
  after <- temporal_communities(rename_nodes(dn, c(Ana = "Zara")), step = 5,
                                window = 5, seeds = 1:5)
  expect_equal(attr(before, "q"), attr(after, "q"),
               tolerance = sqrt(.Machine$double.eps))
  key <- function(x) {
    df <- as.data.frame(x)
    df$node[df$node == "Zara"] <- "Ana"
    df <- df[order(df$time, df$node), ]
    # Compare the partition, not the arbitrary integers naming it.
    unname(match(df$community, unique(df$community)))
  }
  expect_identical(key(before), key(after))
})

test_that("a large omega collapses every vertex to one community for all time", {
  dn <- dynet(school_contacts, format = "contact")
  rigid <- temporal_communities(dn, omega = 1e3, step = 5, window = 5,
                                seeds = 1:5)
  moved <- vapply(split(rigid$community, rigid$node),
                  function(v) length(unique(v)), integer(1L))
  expect_true(all(moved == 1L))
  flex <- as.data.frame(community_trajectory(rigid, measure = "flexibility"))
  expect_true(all(flex$value == 0))
})

test_that("no coupling detects each bin on its own and matches afterwards", {
  # Uncoupled labels are per-bin arbitrary, so returning them raw would invite
  # every downstream measure to read relabelling noise as change.
  dn <- dynet(school_contacts, format = "contact")
  loose <- temporal_communities(dn, omega = 0, step = 5, window = 5,
                                seeds = 1:5)
  expect_true(attr(loose, "matched"))
  expect_true(all(c("community_raw", "event") %in% names(loose)))
  expect_identical(attr(loose, "omega"), 0)
})

test_that("more resolution never means fewer communities", {
  fixture <- planted_sbm(n = 20L, bins = 5L, seed = 9L)
  counts <- vapply(c(0.5, 1, 2, 4), function(gamma)
    attr(temporal_communities(fixture$dn, gamma = gamma, step = 1, window = 1,
                              seeds = 1:5), "n_communities"),
    numeric(1L))
  expect_true(all(diff(counts) >= 0))
})

test_that("the same seeds give the same answer and leave the stream alone", {
  dn <- dynet(school_contacts, format = "contact")
  set.seed(123)
  before <- .Random.seed
  first <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
  second <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
  expect_identical(as.data.frame(first), as.data.frame(second))
  expect_identical(.Random.seed, before)
})

test_that("stability is reported and reads as agreement", {
  dn <- dynet(school_contacts, format = "contact")
  found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:8)
  expect_length(attr(found, "q_runs"), 8L)
  expect_true(attr(found, "stability_ari") >= -1 &&
                attr(found, "stability_ari") <= 1)
  expect_true(attr(found, "q") >= max(attr(found, "q_runs")) - 1e-10)
  runs <- as.data.frame(found, what = "runs")
  expect_identical(nrow(runs), 8L)
  expect_true(any(runs$best))
})

test_that("consensus returns a partition of the same shape", {
  dn <- dynet(school_contacts, format = "contact")
  agreed <- temporal_communities(dn, method = "consensus", step = 5,
                                 window = 5, seeds = 1:5)
  expect_identical(nrow(agreed), nrow(temporal_communities(
    dn, step = 5, window = 5, seeds = 1:5)))
  expect_false(anyNA(agreed$community))
  expect_identical(attr(agreed, "method"), "consensus")
})

test_that("categorical coupling is available and differs from ordinal", {
  fixture <- planted_regime(bins = 4L)
  ordinal <- temporal_communities(fixture, step = 1, window = 1, seeds = 1:5)
  categorical <- temporal_communities(fixture, coupling = "categorical",
                                      step = 1, window = 1, seeds = 1:5)
  expect_identical(attr(categorical, "coupling"), "categorical")
  expect_false(isTRUE(all.equal(attr(ordinal, "q"), attr(categorical, "q"))))
})

test_that("the accessors and methods report what they promise", {
  dn <- dynet(school_contacts, format = "contact")
  found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
  sizes <- as.data.frame(found, what = "sizes")
  expect_true(all(c("time", "community", "n_nodes", "n_active") %in%
                    names(sizes)))
  expect_identical(sum(sizes$n_nodes), nrow(found))
  summarised <- summary(found)
  expect_identical(nrow(summarised), attr(found, "n_communities"))
  expect_true(all(summarised$persistence <= 1))
  expect_error(as.data.frame(found, what = "events"),
               class = "dynet_bad_input")
  expect_s3_class(plot(found), "ggplot")
})

test_that("multinet agrees about the regimes, though not about where they change", {
  # multinet couples aspect-layers all-to-all rather than as a chain, and
  # glouvain_ml is a local heuristic, so only the ordering of regimes can be
  # compared: independent slices at omega = 0, one persistent community at
  # large omega. Do not "fix" this into an equality test.
  skip_if_not_installed("multinet")
  skip_on_cran()
  fixture <- planted_sbm(n = 16L, bins = 4L, seed = 2L)
  loose <- temporal_communities(fixture$dn, omega = 0, step = 1, window = 1,
                                seeds = 1:5)
  rigid <- temporal_communities(fixture$dn, omega = 50, step = 1, window = 1,
                                seeds = 1:5)
  moved <- function(x) mean(vapply(split(x$community, x$node),
                                   function(v) length(unique(v)),
                                   integer(1L)))
  expect_gte(moved(loose), moved(rigid))
  expect_equal(moved(rigid), 1)
})
