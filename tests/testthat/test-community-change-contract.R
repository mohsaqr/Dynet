# Item 5: label-invariant comparison of consecutive partitions.

change_of <- function(x, ...) as.data.frame(community_change(x, ...))

test_that("input without the contract, or an unknown measure, is refused", {
  expect_error(community_change(data.frame(x = 1)), class = "dynet_bad_input")
  x <- hand_partition(matrix(1L, 3L, 3L, dimnames = list(LETTERS[1:3], NULL)))
  expect_error(community_change(x, measure = "cosine"),
               class = "dynet_unknown_measure")
  expect_error(community_change(x, against = "later"))
})

test_that("every statistic matches igraph on the reference pair", {
  # a = c(1,1,1,2,2,2) against b = c(1,1,2,2,2,2). These five values pin every
  # normalisation choice: which mean NMI divides by, which units VI is in,
  # whether split-join is counted once or twice, and the ARI correction.
  skip_if_not_installed("igraph")
  a <- c(1, 1, 1, 2, 2, 2)
  b <- c(1, 1, 2, 2, 2, 2)
  expect_equal(Dynet:::.compare_partitions(a, b, "vi"),
               igraph::compare(a, b, method = "vi"),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(Dynet:::.compare_partitions(a, b, "nmi"),
               igraph::compare(a, b, method = "nmi"),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(Dynet:::.compare_partitions(a, b, "split_join"),
               igraph::compare(a, b, method = "split.join"),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(Dynet:::.compare_partitions(a, b, "ari"),
               igraph::compare(a, b, method = "adjusted.rand"),
               tolerance = sqrt(.Machine$double.eps))
  # Frozen so a change is visible even without igraph installed.
  expect_equal(Dynet:::.compare_partitions(a, b, "vi"), 0.6931472,
               tolerance = 1e-6)
  expect_equal(Dynet:::.compare_partitions(a, b, "nmi"), 0.478704,
               tolerance = 1e-6)
  expect_equal(Dynet:::.compare_partitions(a, b, "ari"), 0.3243243,
               tolerance = 1e-6)
  expect_equal(Dynet:::.compare_partitions(a, b, "jaccard"), 4 / 9,
               tolerance = 1e-9)
})

test_that("the omega index coincides with ARI on disjoint partitions", {
  # A published identity, and therefore a check on both. The omega index is
  # shipped because it is what multinet reports and because it generalises to
  # overlapping communities, which this package does not yet produce.
  set.seed(3)
  for (trial in seq_len(20L)) {
    a <- sample(1:4, 40L, replace = TRUE)
    b <- sample(1:3, 40L, replace = TRUE)
    expect_equal(Dynet:::.compare_partitions(a, b, "omega_index"),
                 Dynet:::.compare_partitions(a, b, "ari"),
                 tolerance = sqrt(.Machine$double.eps))
  }
})

test_that("a partition compared with itself is perfect agreement", {
  set.seed(6)
  a <- sample(1:3, 30L, replace = TRUE)
  expect_equal(Dynet:::.compare_partitions(a, a, "nmi"), 1)
  expect_equal(Dynet:::.compare_partitions(a, a, "ari"), 1)
  expect_equal(Dynet:::.compare_partitions(a, a, "jaccard"), 1)
  expect_equal(Dynet:::.compare_partitions(a, a, "omega_index"), 1)
  expect_equal(Dynet:::.compare_partitions(a, a, "vi"), 0)
  expect_equal(Dynet:::.compare_partitions(a, a, "split_join"), 0)
})

test_that("relabelling either partition changes nothing, from five seeds", {
  # This is the property that makes match_communities() unnecessary here, and
  # it is worth asserting because the opposite is widely assumed.
  base_a <- rep(1:3, each = 10L)
  base_b <- rep(1:2, each = 15L)
  reference <- vapply(c("nmi", "ari", "vi", "split_join", "jaccard",
                        "omega_index"),
                      function(m) Dynet:::.compare_partitions(base_a, base_b, m),
                      numeric(1L))
  for (seed in 1:5) {
    set.seed(seed)
    a <- sample(1:3)[base_a]
    b <- sample(1:2)[base_b]
    got <- vapply(names(reference),
                  function(m) Dynet:::.compare_partitions(a, b, m),
                  numeric(1L))
    expect_equal(got, reference)
  }
})

test_that("ARI sits at chance for unrelated partitions and NMI does not", {
  # The reason both are shipped. NMI is not chance-corrected, so unrelated
  # partitions score well above zero on it.
  set.seed(20)
  draws <- vapply(seq_len(200L), function(i) {
    a <- sample(1:4, 200L, replace = TRUE)
    b <- sample(1:4, 200L, replace = TRUE)
    c(ari = Dynet:::.compare_partitions(a, b, "ari"),
      nmi = Dynet:::.compare_partitions(a, b, "nmi"))
  }, numeric(2L))
  expect_lt(abs(mean(draws["ari", ])), 0.02)
  expect_gt(mean(draws["nmi", ]), 0.005)
})

test_that("the first bin has no predecessor, and says so", {
  dn <- dynet(school_contacts, format = "contact")
  found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
  got <- change_of(found, measure = "ari")
  expect_true(is.na(got$value[[1L]]))
  expect_false(anyNA(got$value[-1L]))
  first <- change_of(found, measure = "ari", against = "first")
  expect_equal(first$value[[1L]], 1)
})

test_that("comparing every pair is symmetric", {
  dn <- dynet(school_contacts, format = "contact")
  found <- temporal_communities(dn, omega = 0.2, step = 2, window = 2,
                                seeds = 1:5)
  got <- change_of(found, measure = c("ari", "nmi"), against = "all")
  mirrored <- merge(got, got, by.x = c("time", "other", "measure"),
                    by.y = c("other", "time", "measure"))
  expect_identical(nrow(mirrored), nrow(got))
  expect_equal(mirrored$value.x, mirrored$value.y)
})

test_that("a bin sharing fewer than two vertices is undefined, not zero", {
  nodes <- sprintf("n%d", 1:4)
  labels <- matrix(c(1L, 1L, 2L, 2L), 4L, 3L, dimnames = list(nodes, NULL))
  x <- hand_partition(labels)
  x$active[x$time == 1 & x$node != "n1"] <- FALSE
  got <- change_of(x, measure = "ari")
  expect_true(is.na(got$value[got$time == 1]))
  expect_false(is.nan(got$value[got$time == 1]))
})

test_that("the result records how many vertices each comparison could use", {
  dn <- dynet(school_contacts, format = "contact")
  found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
  out <- community_change(found, measure = "ari")
  expect_length(attr(out, "n_compared"), length(unique(found$time)))
  expect_identical(attr(out, "against"), "previous")
})
