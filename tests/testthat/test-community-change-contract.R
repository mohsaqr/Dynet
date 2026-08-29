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

test_that("adjusted mutual information matches an independent implementation", {
  # MI and its hypergeometric expectation are the hard parts and are shared by
  # every normaliser, so they are checked against aricode in aricode's own
  # convention as well as against the frozen sklearn values in ours.
  a <- c(1, 1, 1, 2, 2, 2)
  b <- c(1, 1, 2, 2, 2, 2)
  # Frozen from sklearn.metrics.adjusted_mutual_info_score(average_method =
  # "arithmetic"), which is the normaliser this package uses.
  expect_equal(Dynet:::.compare_partitions(a, b, "ami"), 0.3552453213,
               tolerance = 1e-9)
  expect_equal(Dynet:::.expected_mutual_information(c(3, 3), c(2, 4), 6L),
               0.1273028, tolerance = 1e-6)

  skip_if_not_installed("aricode")
  set.seed(4)
  for (trial in seq_len(25L)) {
    x <- sample.int(4L, 60L, replace = TRUE)
    y <- sample.int(3L, 60L, replace = TRUE)
    ct <- Dynet:::.contingency(x, y)
    info <- Dynet:::.mutual_information(ct)
    expected <- Dynet:::.expected_mutual_information(ct$row, ct$col, ct$total)
    # aricode divides by the maximum entropy where this package divides by the
    # arithmetic mean. That is a convention, not an error, so the comparison
    # is made in aricode's convention.
    by_max <- (info$mi - expected) / (max(info$h1, info$h2) - expected)
    # Absolute, not relative: adjusted mutual information sits at zero for
    # unrelated partitions, so a relative tolerance there is meaningless. The
    # two implementations sum the hypergeometric term in different orders and
    # agree to about 1e-8.
    expect_lt(abs(by_max - aricode::AMI(x, y)), 1e-6)
  }

  # And on partitions with real structure, where the value is far from zero
  # and a relative comparison does mean something.
  planted <- rep(1:4, each = 25L)
  noisy <- planted
  set.seed(9)
  noisy[sample.int(100L, 20L)] <- sample.int(4L, 20L, replace = TRUE)
  ct <- Dynet:::.contingency(planted, noisy)
  info <- Dynet:::.mutual_information(ct)
  expected <- Dynet:::.expected_mutual_information(ct$row, ct$col, ct$total)
  expect_equal((info$mi - expected) / (max(info$h1, info$h2) - expected),
               aricode::AMI(planted, noisy), tolerance = 1e-7)
})

test_that("the expectation term survives sizes that overflow a factorial", {
  # Written in log space for exactly this reason: the hypergeometric
  # coefficients pass the largest double well before a few hundred elements.
  big <- Dynet:::.expected_mutual_information(rep(200L, 5L), rep(250L, 4L),
                                              1000L)
  expect_true(is.finite(big))
  expect_gt(big, 0)
})

test_that("adjustment moves unrelated partitions to zero and leaves agreement at one", {
  set.seed(20)
  draws <- vapply(seq_len(150L), function(i) {
    a <- sample.int(4L, 200L, replace = TRUE)
    b <- sample.int(4L, 200L, replace = TRUE)
    c(ami = Dynet:::.compare_partitions(a, b, "ami"),
      nmi = Dynet:::.compare_partitions(a, b, "nmi"))
  }, numeric(2L))
  expect_lt(abs(mean(draws["ami", ])), 0.02)
  expect_gt(mean(draws["nmi", ]), 0.005)
  same <- sample.int(3L, 30L, replace = TRUE)
  expect_equal(Dynet:::.compare_partitions(same, same, "ami"), 1)
})

test_that("iami is ami, because every comparison here is already an intersection", {
  set.seed(31)
  for (trial in seq_len(10L)) {
    a <- sample.int(4L, 40L, replace = TRUE)
    b <- sample.int(3L, 40L, replace = TRUE)
    expect_identical(Dynet:::.compare_partitions(a, b, "iami"),
                     Dynet:::.compare_partitions(a, b, "ami"))
  }
})

test_that("uami is ami over the union, with the absentees as their own community", {
  # The construction, asserted directly: widen both partitions to the union,
  # give each a virtual community for what it lacks, and take ami.
  nodes <- sprintf("n%d", 1:8)
  labels <- cbind(c(1, 1, 1, 1, 2, 2, 2, 2), c(1, 1, 1, 1, 2, 2, 2, 2))
  dimnames(labels) <- list(nodes, NULL)
  x <- hand_partition(labels)
  x$active[x$time == 1 & x$node %in% c("n1", "n5")] <- FALSE
  x$active[x$time == 0 & x$node %in% c("n4", "n8")] <- FALSE
  got <- as.data.frame(community_change(x, measure = "uami"))
  left <- c(n2 = "1", n3 = "1", n6 = "2", n7 = "2", n4 = "(absent)",
            n8 = "(absent)", n1 = "1", n5 = "2")
  right <- c(n2 = "1", n3 = "1", n6 = "2", n7 = "2", n4 = "1", n8 = "2",
             n1 = "(absent)", n5 = "(absent)")
  expect_equal(got$value[got$time == 1],
               Dynet:::.compare_partitions(left, right, "ami"),
               tolerance = sqrt(.Machine$double.eps))
})

test_that("a moving vertex set is what separates uami from iami", {
  # The point of the pair. The vertices that stayed kept their exact company,
  # so iami sees no change at all; but two left and two arrived, and uami
  # counts that as most of the structure turning over.
  nodes <- sprintf("n%d", 1:8)
  labels <- cbind(c(1, 1, 1, 1, 2, 2, 2, 2), c(1, 1, 1, 1, 2, 2, 2, 2))
  dimnames(labels) <- list(nodes, NULL)
  moving <- hand_partition(labels)
  moving$active[moving$time == 1 & moving$node %in% c("n1", "n5")] <- FALSE
  moving$active[moving$time == 0 & moving$node %in% c("n4", "n8")] <- FALSE
  got <- as.data.frame(community_change(moving,
                                        measure = c("ami", "iami", "uami")))
  value <- function(m) got$value[got$measure == m & got$time == 1]
  expect_equal(value("iami"), 1)
  expect_equal(value("ami"), 1)
  expect_lt(value("uami"), 0.5)

  # With a constant vertex set the union is the intersection and all three
  # must agree exactly.
  still <- hand_partition(labels)
  agreed <- as.data.frame(community_change(still,
                                           measure = c("ami", "iami", "uami")))
  at_one <- agreed$value[agreed$time == 1]
  expect_equal(at_one, rep(at_one[[1L]], 3L))
})

test_that("uami is defined where the intersection is too small for the rest", {
  # Two bins sharing one vertex: every intersection measure is undefined, but
  # the union still has something to say.
  nodes <- sprintf("n%d", 1:4)
  labels <- matrix(c(1L, 1L, 2L, 2L), 4L, 2L, dimnames = list(nodes, NULL))
  x <- hand_partition(labels)
  x$active[x$time == 1 & x$node %in% c("n2", "n3", "n4")] <- FALSE
  got <- as.data.frame(community_change(x, measure = c("ami", "uami")))
  expect_true(is.na(got$value[got$measure == "ami" & got$time == 1]))
  expect_false(is.na(got$value[got$measure == "uami" & got$time == 1]))
})
