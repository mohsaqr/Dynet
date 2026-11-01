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
  verbs <- list(metrics = metrics, centrality_series = centrality_series,
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

# ---------------------------------------------------------------------------
# Regressions from the 2026-11-01 audit
# ---------------------------------------------------------------------------

test_that("a seed or an unknown correction is refused, not ignored", {
  dn <- dynet(school_contacts, format = "contact")
  null <- randomise(dn, method = "times", n = 9, seed = 1)
  expect_error(significance(null, statistic = metrics, measure = "density",
                            seed = 5),
               class = "dynet_bad_input")
  expect_error(significance(dn, statistic = metrics, measure = "density",
                            n = 9, seed = 1, p_adjust = "nonsense"),
               class = "dynet_bad_input")
})

test_that("a foreign error is raised and a package refusal is counted", {
  dn <- dynet(school_contacts, format = "contact")
  null <- randomise(dn, method = "times", n = 8, seed = 1)
  broken <- function(dn, ...) {
    if (!is.null(dn$meta$surrogate)) stop("boom")
    metrics(dn, measure = "density", window = "all")
  }
  expect_error(significance(null, statistic = broken),
               class = "dynet_statistic_failed")
  refusing <- function(dn, ...) {
    if (isTRUE(dn$meta$surrogate$replicate %% 2 == 0)) {
      stop(errorCondition("no bins",
                          class = c("dynet_empty_result", "dynet_bad_input")))
    }
    metrics(dn, measure = "density", window = "all")
  }
  expect_warning(s <- significance(null, statistic = refusing),
                 class = "dynet_null_incomplete")
  expect_identical(as.data.frame(s)$n_null, 4)
})

test_that("the null distribution is a tidy table that reproduces the summary", {
  dn <- dynet(school_contacts, format = "contact")
  s <- suppressWarnings(significance(
    dn, statistic = metrics, measure = c("density", "reciprocity"),
    n = 19, seed = 1))
  result <- as.data.frame(s)
  null <- as.data.frame(s, what = "null")
  expect_identical(names(null), c("time", "measure", "replicate", "value"))
  expect_identical(nrow(null), nrow(result) * 19L)
  means <- aggregate(value ~ time + measure, data = null, FUN = mean)
  both <- merge(means, result, by = c("time", "measure"))
  expect_equal(both$value, both$null_mean)
  expect_identical(as.data.frame(s, what = "result"), result)
})

test_that("a planted signal is detected in the documented direction only", {
  # Every pair fires eight times within one time unit and twice at random over
  # a hundred, so its burstiness is far above what time shuffling leaves.
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (!is.null(old)) assign(".Random.seed", old, globalenv()),
          add = TRUE)
  set.seed(11)
  planted <- do.call(rbind, lapply(1:10, function(i) {
    centre <- stats::runif(1, 0, 100)
    data.frame(from = paste0("v", i), to = paste0("v", i %% 10 + 1),
               time = round(sort(c(centre + stats::runif(8, 0, 1),
                                   stats::runif(2, 0, 100))), 3))
  }))
  dn <- quiet_dynet(planted, format = "contact")
  greater <- as.data.frame(suppressWarnings(significance(
    dn, statistic = burstiness, measure = "burstiness", n = 199, seed = 1,
    alternative = "greater")))
  less <- as.data.frame(suppressWarnings(significance(
    dn, statistic = burstiness, measure = "burstiness", n = 199, seed = 1,
    alternative = "less")))
  expect_true(all(greater$z > 0))
  expect_lt(stats::median(greater$p), 0.1)
  expect_gt(min(less$p), 0.5)
  # Aggregate density over the whole window is invariant under time
  # shuffling, so its p-value is exactly one whatever the seed.
  invariant <- as.data.frame(significance(
    dn, statistic = metrics, measure = "density", window = "all", n = 49,
    seed = 3))
  expect_identical(invariant$p, 1)
  expect_true(is.na(invariant$z))
})

test_that("the plots build without data-masking warnings", {
  skip_if_not_installed("ggplot2")
  dn <- dynet(school_contacts, format = "contact")
  s <- suppressWarnings(significance(dn, statistic = metrics,
                                     measure = "density", n = 19, seed = 1))
  for (type in c("null", "series", "z")) {
    expect_no_warning(ggplot2::ggplot_build(plot(s, type = type)))
  }
  null <- randomise(dn, method = "times", n = 3, seed = 1)
  expect_no_warning(ggplot2::ggplot_build(plot(null)))
})
