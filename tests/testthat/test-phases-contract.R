# Item 7: regimes found by clustering the between-bin similarity.
#
# phasik, the direct oracle for this method, is not importable on any
# interpreter on this machine, so it is literature-only. What is pinned here
# is stronger where it matters: the contiguous partition is checked against
# brute-force enumeration, which is exact.

test_that("degenerate phase counts and grids are refused", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(phases(dn, k = 1, step = 2, window = 2),
               class = "dynet_bad_input")
  expect_error(phases(dn, k = 99, step = 2, window = 2),
               class = "dynet_bad_input")
  expect_error(phases(dn, method = "euclidean"))
  expect_error(phases(dn, linkage = "single"))
  expect_error(phases(dn, step = 12, window = 12),
               class = "dynet_empty_result")
})

test_that("the contiguous partition is the true optimum, by enumeration", {
  # Fisher's dynamic program against brute force over every contiguous cut
  # set. This is an exact oracle, and the strongest test in this item.
  brute <- function(d, k) {
    n <- nrow(d)
    square <- d^2
    cost <- function(i, j) {
      if (j == i) return(0)
      sum(square[i:j, i:j][lower.tri(diag(j - i + 1L))]) / (j - i + 1L)
    }
    cuts <- utils::combn(seq_len(n - 1L), k - 1L)
    min(vapply(seq_len(ncol(cuts)), function(c) {
      bounds <- c(0L, cuts[, c], n)
      sum(vapply(seq_len(k), function(s)
        cost(bounds[[s]] + 1L, bounds[[s + 1L]]), numeric(1L)))
    }, numeric(1L)))
  }
  set.seed(21)
  for (trial in seq_len(50L)) {
    n <- sample(4:10, 1L)
    d <- as.matrix(stats::dist(matrix(stats::runif(n * 3L), n, 3L)))
    for (k in 2:min(4L, n - 1L)) {
      expect_equal(Dynet:::.fisher_partition(d, k)$cost, brute(d, k),
                   tolerance = sqrt(.Machine$double.eps))
    }
  }
})

test_that("the silhouette matches an independent implementation", {
  skip_if_not_installed("cluster")
  set.seed(5)
  d <- as.matrix(stats::dist(matrix(stats::rnorm(20L), 10L, 2L)))
  group <- rep(1:2, each = 5L)
  expect_equal(Dynet:::.silhouette(d, group),
               as.vector(cluster::silhouette(group,
                                             stats::as.dist(d))[, "sil_width"]),
               tolerance = sqrt(.Machine$double.eps))
})

test_that("a singleton phase has no silhouette rather than a manufactured zero", {
  d <- as.matrix(stats::dist(c(0, 0.1, 0.2, 9)))
  width <- Dynet:::.silhouette(d, c(1L, 1L, 1L, 2L))
  expect_true(is.na(width[[4L]]))
  expect_false(anyNA(width[1:3]))
})

test_that("a planted regime change is found, for every method and linkage", {
  # Eight bins of one clique, then eight of a disjoint one. The boundary is
  # at bin 8 and there are two phases, whatever the distance.
  fixture <- planted_regime(bins = 8L)
  for (method in c("jaccard", "overlap", "hamming", "cosine", "pearson")) {
    got <- phases(fixture, k = 2, method = method, step = 1, window = 1)
    expect_identical(sum(got$boundary), 2L)
    expect_identical(got$time[got$boundary], c(0, 8))
    expect_identical(as.integer(table(got$phase)), c(8L, 8L))
  }
  for (linkage in c("ward.D2", "average", "complete")) {
    got <- phases(fixture, k = 2, linkage = linkage, contiguous = FALSE,
                  step = 1, window = 1)
    expect_identical(length(unique(got$phase)), 2L)
    expect_identical(got$phase[1:8], rep(got$phase[[1L]], 8L))
  }
})

test_that("the silhouette chooses two phases on a two-phase network", {
  fixture <- planted_regime(bins = 8L)
  got <- phases(fixture, step = 1, window = 1)
  expect_identical(unname(attr(got, "k")), 2L)
  profile <- as.data.frame(got, what = "profile")
  expect_identical(profile$k[[which.max(profile$silhouette_mean)]], 2L)
})

test_that("a contiguous phase is an unbroken stretch of time", {
  set.seed(44)
  for (trial in seq_len(30L)) {
    n <- sample(5:12, 1L)
    d <- as.matrix(stats::dist(matrix(stats::runif(n * 2L), n, 2L)))
    for (k in 2:min(4L, n - 1L)) {
      phase <- Dynet:::.fisher_partition(d, k)$phase
      expect_true(all(diff(phase) >= 0))
      expect_identical(length(unique(phase)), k)
    }
  }
})

test_that("more phases never cost more scatter", {
  fixture <- planted_regime(bins = 6L)
  profile <- as.data.frame(phases(fixture, step = 1, window = 1, k_max = 6L),
                           what = "profile")
  expect_true(all(diff(profile$within_ss) <= sqrt(.Machine$double.eps)))
})

test_that("nothing here is random, and the caller's stream is untouched", {
  dn <- dynet(school_contacts, format = "contact")
  set.seed(77)
  before <- .Random.seed
  first <- phases(dn, step = 2, window = 2)
  second <- phases(dn, step = 2, window = 2)
  expect_identical(as.data.frame(first), as.data.frame(second))
  expect_identical(.Random.seed, before)
})

test_that("the profile reports every k considered, so the choice is visible", {
  dn <- dynet(school_contacts, format = "contact")
  got <- phases(dn, step = 2, window = 2, k_max = 6L)
  profile <- as.data.frame(got, what = "profile")
  expect_identical(profile$k, 2:6)
  expect_false(anyNA(profile$silhouette_mean))
  blocks <- as.data.frame(got, what = "phases")
  expect_identical(sum(blocks$n_bins), nrow(got))
  expect_true(all(blocks$start <= blocks$end))
})

test_that("hamming is treated as a distance and the others as agreement", {
  # similarity() reports hamming as disagreement with a zero diagonal and
  # every other method as agreement with a one diagonal. Subtracting hamming
  # from one as well would silently invert the answer.
  fixture <- planted_regime(bins = 6L)
  hamming <- phases(fixture, k = 2, method = "hamming", step = 1, window = 1)
  jaccard <- phases(fixture, k = 2, method = "jaccard", step = 1, window = 1)
  expect_identical(hamming$phase, jaccard$phase)
  d_hamming <- attr(hamming, "blocks")[[1L]]$distance
  expect_true(all(diag(d_hamming) == 0))
  expect_true(all(d_hamming >= 0))
  d_jaccard <- attr(jaccard, "blocks")[[1L]]$distance
  expect_true(all(diag(d_jaccard) == 0))
})

test_that("cutree is what non-contiguous clustering uses", {
  dn <- dynet(school_contacts, format = "contact")
  got <- phases(dn, k = 3, contiguous = FALSE, linkage = "average", step = 2,
                window = 2)
  d <- attr(got, "blocks")[[1L]]$distance
  reference <- stats::cutree(stats::hclust(stats::as.dist(d),
                                           method = "average"), k = 3)
  expect_identical(unname(got$phase), unname(match(reference,
                                                   unique(reference))))
  expect_s3_class(plot(got), "ggplot")
})
