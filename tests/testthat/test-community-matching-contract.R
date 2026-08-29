# Item 4: making a community label mean the same group in every bin.
#
# The end-to-end matching pipeline has no external oracle reachable here:
# tnetwork, whose longitudinal_similarity would be the natural one, is not
# importable on any interpreter on this machine. The pipeline is therefore
# pinned by planted fixtures; only the assignment step has an exact oracle.

test_that("input without the contract, or an impossible threshold, is refused", {
  expect_error(match_communities(data.frame(a = 1)), class = "dynet_bad_input")
  x <- hand_partition(matrix(1L, 3L, 3L, dimnames = list(LETTERS[1:3], NULL)))
  expect_error(match_communities(x, threshold = -1), class = "dynet_bad_input")
  expect_error(match_communities(x, overlap = "jaccard", threshold = 2),
               class = "dynet_bad_input")
  expect_error(match_communities(x, method = "auction"))
})

test_that("the assignment reaches the optimum an independent solver reaches", {
  # The optimal total is unique even when the assignment achieving it is not,
  # so this is an exact oracle rather than a comparison of ties.
  skip_if_not_installed("clue")
  set.seed(42)
  for (trial in seq_len(200L)) {
    rows <- sample.int(8L, 1L)
    cols <- sample.int(8L, 1L)
    weight <- matrix(round(stats::runif(rows * cols, 0, 20)), rows, cols)
    got <- Dynet:::.assign_max(weight)
    mine <- sum(weight[cbind(seq_len(rows), got)[!is.na(got), , drop = FALSE]])
    square <- matrix(0, max(rows, cols), max(rows, cols))
    square[seq_len(rows), seq_len(cols)] <- weight
    reference <- clue::solve_LSAP(square, maximum = TRUE)
    theirs <- sum(square[cbind(seq_len(nrow(square)), as.integer(reference))])
    expect_equal(mine, theirs)
  }
})

test_that("the assignment handles degenerate shapes without inventing matches", {
  expect_identical(Dynet:::.assign_max(matrix(0, 0L, 3L)), integer(0))
  expect_identical(Dynet:::.assign_max(matrix(5, 1L, 1L)), 1L)
  # More rows than columns: some row must go unmatched rather than share.
  got <- Dynet:::.assign_max(matrix(c(9, 1, 5), 3L, 1L))
  expect_identical(sum(!is.na(got)), 1L)
  expect_identical(which(!is.na(got)), 1L)
})

test_that("pure relabelling is undone, from several permutation seeds", {
  # The defining property. Constant membership, labels shuffled within each
  # bin: after matching, nothing changed, so flexibility is exactly zero.
  nodes <- sprintf("n%d", 1:9)
  truth <- matrix(rep(rep(1:3, each = 3L), 5L), 9L, 5L,
                  dimnames = list(nodes, NULL))
  for (seed in 1:5) {
    set.seed(seed)
    scrambled <- truth
    for (bin in seq_len(ncol(truth))) {
      key <- sample(1:3)
      scrambled[, bin] <- key[truth[, bin]]
    }
    matched <- match_communities(hand_partition(scrambled))
    flex <- as.data.frame(community_trajectory(matched,
                                               measure = "flexibility"))
    expect_true(all(flex$value == 0))
  }
})

test_that("matching an already matched partition changes nothing", {
  nodes <- sprintf("n%d", 1:6)
  set.seed(8)
  labels <- matrix(sample(1:2, 24L, replace = TRUE), 6L, 4L,
                   dimnames = list(nodes, NULL))
  once <- match_communities(hand_partition(labels))
  twice <- match_communities(once)
  expect_identical(once$community, twice$community)
  expect_identical(once$community_raw, twice$community_raw)
  expect_identical(once$event, twice$event)
})

test_that("the optimal assignment does not depend on the order of the rows", {
  # This is precisely what fails for method = "greedy", which is offered only
  # for comparability with the published greedy pipelines and is exempt.
  nodes <- sprintf("n%d", 1:8)
  set.seed(15)
  labels <- matrix(sample(1:3, 32L, replace = TRUE), 8L, 4L,
                   dimnames = list(nodes, NULL))
  x <- hand_partition(labels)
  straight <- match_communities(x)
  shuffled <- x[sample(nrow(x)), ]
  attributes(shuffled) <- utils::modifyList(
    attributes(x)[setdiff(names(attributes(x)), c("row.names"))],
    list(row.names = seq_len(nrow(x))))
  scrambled <- match_communities(shuffled)
  key <- function(y) {
    df <- as.data.frame(y)
    df <- df[order(df$time, df$node), ]
    unname(match(df$community, unique(df$community)))
  }
  expect_identical(key(straight), key(scrambled))
})

test_that("a planted split is reported as a split, and the larger part inherits", {
  nodes <- sprintf("n%d", 1:8)
  labels <- cbind(rep(1L, 8L), rep(1L, 8L), rep(1L, 8L),
                  c(rep(1L, 5L), rep(2L, 3L)),
                  c(rep(1L, 5L), rep(2L, 3L)))
  dimnames(labels) <- list(nodes, NULL)
  matched <- match_communities(hand_partition(labels))
  events <- as.data.frame(matched, what = "events")
  at_split <- events[events$time == 3, ]
  expect_true(any(at_split$event == "split"))
  # The larger fragment keeps the original label.
  kept <- at_split$community[at_split$size == max(at_split$size)]
  expect_identical(kept, events$community[events$time == 2])
})

test_that("a dissolved community and a later unrelated one never share a label", {
  nodes <- sprintf("n%d", 1:6)
  # Two communities to bin 2, then one of them empties; a fresh disjoint one
  # appears at bin 4.
  labels <- cbind(c(1L, 1L, 1L, 2L, 2L, 2L),
                  c(1L, 1L, 1L, 2L, 2L, 2L),
                  rep(1L, 6L), rep(1L, 6L),
                  c(rep(1L, 3L), rep(3L, 3L)))
  dimnames(labels) <- list(nodes, NULL)
  matched <- match_communities(hand_partition(labels))
  events <- as.data.frame(matched, what = "events")
  expect_true(any(events$event == "dissolve"))
  early <- unique(matched$community[matched$time == 0])
  late <- setdiff(unique(matched$community[matched$time == 4]),
                  unique(matched$community[matched$time == 3]))
  expect_length(intersect(early[!early %in%
                                 matched$community[matched$time == 3]], late),
                0L)
})

test_that("a community that goes quiet is not read as dissolving", {
  # Overlaps count only vertices active in both bins, so inactivity is
  # silence, not departure.
  nodes <- sprintf("n%d", 1:6)
  labels <- matrix(rep(c(1L, 1L, 1L, 2L, 2L, 2L), 3L), 6L, 3L,
                   dimnames = list(nodes, NULL))
  x <- hand_partition(labels)
  x$active[x$time == 1 & x$node %in% c("n4", "n5", "n6")] <- FALSE
  matched <- match_communities(x)
  events <- as.data.frame(matched, what = "events")
  expect_false(any(events$event == "dissolve"))
  expect_identical(length(unique(matched$community)), 2L)
})

test_that("the optimal assignment beats greedy where they can differ", {
  # Ten vertices. Bin 0 splits 6 / 4; bin 1 splits 9 / 1, with one vertex of
  # the first group left alone. Greedy takes the single largest overlap
  # (0.500) and then has nothing left for the second group, total 0.500. The
  # optimum pairs both (0.167 + 0.444 = 0.611), and the two therefore hand out
  # different labels. This is not a tie: greedy is simply worse here.
  nodes <- sprintf("n%02d", 1:10)
  labels <- t(rbind(c(1, 1, 1, 1, 1, 1, 2, 2, 2, 2),
                    c(1, 1, 1, 1, 1, 2, 1, 1, 1, 1)))
  dimnames(labels) <- list(nodes, NULL)
  x <- hand_partition(labels)
  weight <- Dynet:::.community_overlap(labels[, 1L], labels[, 2L],
                                       rep(TRUE, 10L), "jaccard")
  optimal <- Dynet:::.assign_max(weight)
  greedy <- Dynet:::.assign_greedy(weight)
  expect_gt(sum(weight[cbind(seq_len(2L), optimal)]),
            sum(weight[cbind(seq_len(2L), greedy)], na.rm = TRUE))

  hungarian <- match_communities(x)
  loose <- match_communities(x, method = "greedy")
  keeps <- function(y) {
    y$community[y$node == "n06" & y$time == 1] ==
      y$community[y$node == "n01" & y$time == 0]
  }
  expect_true(keeps(hungarian))
  expect_false(keeps(loose))
})

test_that("greedy and hungarian agree when the assignment is unambiguous", {
  nodes <- sprintf("n%d", 1:6)
  labels <- matrix(rep(c(1L, 1L, 1L, 2L, 2L, 2L), 4L), 6L, 4L,
                   dimnames = list(nodes, NULL))
  expect_identical(match_communities(hand_partition(labels))$community,
                   match_communities(hand_partition(labels),
                                     method = "greedy")$community)
})

test_that("the events table describes every community in every bin", {
  dn <- dynet(school_contacts, format = "contact")
  loose <- temporal_communities(dn, omega = 0, step = 5, window = 5,
                                seeds = 1:5)
  events <- as.data.frame(loose, what = "events")
  expect_true(all(c("time", "community", "event", "size", "overlap",
                    "matched_from") %in% names(events)))
  expect_true(all(events$event %in% c("born", "persist", "split", "merge",
                                      "dissolve")))
  expect_true(all(loose$event[loose$time == min(loose$time)] == "born"))
})
