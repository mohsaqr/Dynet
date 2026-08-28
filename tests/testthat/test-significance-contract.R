test_that("significance rejects a statistic that breaks the column contract", {
  dn <- dynet(school_contacts, format = "contact")
  not_a_measure <- function(dn, ...) data.frame(node = "A", count = 1L)
  expect_error(significance(dn, statistic = not_a_measure, n = 9, seed = 1),
               class = "dynet_bad_statistic")
  expect_error(significance(dn, statistic = "metrics", n = 9, seed = 1),
               class = "dynet_bad_input")
})

test_that("settings cannot be respecified against pre-drawn surrogates", {
  dn <- dynet(school_contacts, format = "contact")
  null <- randomise(dn, method = "times", n = 9, seed = 1)
  expect_error(
    significance(null, statistic = metrics, measure = "density", n = 50),
    class = "dynet_bad_input")
  expect_error(
    significance(null, statistic = metrics, measure = "density",
                 method = "edges"),
    class = "dynet_bad_input")
})

test_that("surrogates dropped to save memory cannot be tested against", {
  dn <- dynet(school_contacts, format = "contact")
  null <- randomise(dn, method = "times", n = 9, seed = 1, keep = "spells")
  expect_error(significance(null, statistic = metrics, measure = "density"),
               class = "dynet_bad_input")
})

test_that("the p-value matches a longhand count on the stored draws", {
  # Recompute p from the draws by hand rather than trusting the vectorised
  # path that produced it.
  dn <- dynet(school_contacts, format = "contact")
  s <- suppressWarnings(significance(dn, statistic = metrics,
                                     measure = "density", n = 99, seed = 1,
                                     alternative = "greater"))
  df <- as.data.frame(s)
  draws <- attr(s, "draws")
  for (i in seq_len(nrow(df))) {
    v <- draws[i, ]
    v <- v[is.finite(v)]
    tol <- sqrt(.Machine$double.eps) * max(1, abs(df$observed[[i]]))
    hits <- sum(v >= df$observed[[i]] - tol)
    expect_equal(df$p[[i]], (1 + hits) / (1 + length(v)))
  }
})

test_that("a p-value never reaches zero and never exceeds one", {
  dn <- dynet(school_contacts, format = "contact")
  for (alt in c("two.sided", "greater", "less")) {
    s <- suppressWarnings(significance(dn, statistic = metrics,
                                       measure = "density", n = 99, seed = 1,
                                       alternative = alt))
    df <- as.data.frame(s)
    expect_true(all(df$p >= 1 / (df$n_null + 1) - 1e-12), info = alt)
    expect_true(all(df$p <= 1), info = alt)
  }
})

test_that("a label null gives p exactly one for every structural measure", {
  # Every surrogate is isomorphic, so the null has no spread. This single
  # assertion catches key-alignment bugs, NA-versus-zero imputation bugs and
  # the double-comparison tolerance all at once.
  dn <- dynet(school_contacts, format = "contact")
  s <- suppressWarnings(significance(
    dn, statistic = metrics,
    measure = c("density", "transitivity", "reciprocity"),
    method = "labels", n = 49, seed = 1))
  df <- as.data.frame(s)
  expect_true(all(abs(df$p - 1) < 1e-12))
  expect_true(all(df$null_sd < 1e-12))
  expect_true(all(is.na(df$z)))
  expect_equal(df$observed, df$null_mean)
})

test_that("significance wraps every measurement verb including pshifts", {
  # pshifts() could not be wrapped before its count column became
  # measure/value; this is the test that pins the fix.
  dn <- dynet(school_contacts, format = "contact")
  null <- randomise(dn, method = "times", n = 9, seed = 1)
  verbs <- list(metrics = metrics, dyn_centrality = dyn_centrality,
                events = events, burstiness = burstiness,
                durations = durations, pshifts = pshifts)
  for (nm in names(verbs)) {
    s <- suppressWarnings(significance(null, statistic = verbs[[nm]]))
    expect_s3_class(s, "dynet_significance")
    expect_true(all(c("observed", "p", "p_adj", "n_null") %in% names(s)),
                info = nm)
    expect_gt(nrow(as.data.frame(s)), 0L)
  }
})

test_that("the reported interval and correction are the ones asked for", {
  dn <- dynet(school_contacts, format = "contact")
  s <- suppressWarnings(significance(dn, statistic = metrics,
                                     measure = "density", n = 99, seed = 1,
                                     conf_level = 0.9, p_adjust = "bonferroni"))
  df <- as.data.frame(s)
  draws <- attr(s, "draws")
  for (i in seq_len(nrow(df))) {
    v <- draws[i, ][is.finite(draws[i, ])]
    q <- unname(stats::quantile(v, c(0.05, 0.95), type = 7, names = FALSE))
    expect_equal(c(df$null_lo[[i]], df$null_hi[[i]]), q)
  }
  expect_equal(df$p_adj, stats::p.adjust(df$p, method = "bonferroni"))
  expect_true(all(df$null_lo <= df$null_hi))
})

test_that("the same seed recovers the same p-value", {
  dn <- dynet(school_contacts, format = "contact")
  a <- suppressWarnings(significance(dn, statistic = metrics,
                                     measure = "density", n = 99, seed = 7))
  b <- suppressWarnings(significance(dn, statistic = metrics,
                                     measure = "density", n = 99, seed = 7))
  expect_identical(as.data.frame(a), as.data.frame(b))
})

test_that("independent seeds agree within Monte-Carlo error", {
  skip_on_cran()
  dn <- dynet(school_contacts, format = "contact")
  # Burstiness is continuous, so its null has few ties and the Monte-Carlo
  # bound is the thing that actually governs the spread. Density is NOT usable
  # here; see the discreteness test below for why.
  runs <- lapply(c(1, 2, 3), function(s) {
    as.data.frame(suppressWarnings(significance(
      dn, statistic = burstiness, measure = "burstiness", n = 199, seed = s)))
  })
  for (i in seq_len(nrow(runs[[1L]]))) {
    p <- vapply(runs, function(r) r$p[[i]], numeric(1L))
    mcse <- max(vapply(runs, function(r) r$p_mcse[[i]], numeric(1L)))
    expect_lt(max(p) - min(p), 6 * mcse + 0.05)
  }
})

test_that("a tie-dominated p-value is flagged and does not stabilise with n", {
  skip_on_cran()
  dn <- dynet(school_contacts, format = "contact")
  # Density is a count over a fixed pair set, so most of the null mass can sit
  # exactly on the observed value. Measured behaviour: the spread across seeds
  # does not shrink when n rises fivefold, which is why n_ties exists.
  spread <- function(n) {
    ps <- lapply(1:3, function(s) as.data.frame(suppressWarnings(significance(
      dn, statistic = metrics, measure = "density", n = n, seed = s)))$p)
    max(apply(do.call(cbind, ps), 1L, function(r) max(r) - min(r)))
  }
  small <- spread(99)
  large <- spread(499)
  expect_gt(small, 0.2)
  expect_gt(large, 0.2)

  # And the diagnostic that explains it is present and large.
  d <- as.data.frame(suppressWarnings(significance(
    dn, statistic = metrics, measure = "density", n = 99, seed = 1)))
  expect_true("n_ties" %in% names(d))
  expect_gt(max(d$n_ties / d$n_null), 0.5)
  expect_true(all(d$n_ties <= d$n_null))
})

test_that("significance ships the four result methods", {
  dn <- dynet(school_contacts, format = "contact")
  s <- suppressWarnings(significance(dn, statistic = metrics,
                                     measure = "density", n = 49, seed = 1))
  expect_s3_class(s, "dynet_significance")
  expect_s3_class(as.data.frame(s), "data.frame")
  expect_true(all(c("measure", "tested", "significant", "median_z") %in%
                    names(summary(s))))
  expect_output(print(s), "null holds fixed")
  skip_if_not_installed("ggplot2")
  expect_s3_class(plot(s), "ggplot")
})
