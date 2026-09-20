# turnover() is volatility and fluctuability (Thompson et al. 2017). The trap
# this file guards is the scale of the Hamming distance: cograph's is a raw
# count over the full symmetric matrix, teneto's is a proportion over the pair
# domain, and they differ by a factor of 2 * choose(n, 2) when undirected.

teneto_fixture <- function() {
  quiet_dynet(
    data.frame(
      from = c("A", "B", "A", "C", "A", "B", "A"),
      to   = c("B", "C", "B", "D", "B", "C", "C"),
      time = c(0, 0, 1, 1, 2, 2, 3)
    ),
    format = "contact", directed = FALSE
  )
}

teneto_reference <- function() {
  source(test_path("fixtures", "teneto-turnover.R"), local = TRUE)$value
}

frozen_network <- function(n_bins) {
  quiet_dynet(
    data.frame(
      from = rep(c("A", "B", "C"), times = n_bins),
      to = rep(c("B", "C", "A"), times = n_bins),
      time = rep(seq_len(n_bins) - 1, each = 3L)
    ),
    format = "contact", directed = FALSE
  )
}

# ---------------------------------------------------------------- error paths

test_that("fluctuability is refused at per-time scope", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  expect_error(turnover(dn, measure = "fluctuability", scope = "pertime"),
               class = "dynet_incompatible_scope")
})

test_that("a single bin opens no transition", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 1),
                    format = "contact")
  expect_error(turnover(dn), class = "dynet_empty_result")
})

test_that("a one-vertex network has an empty pair domain", {
  dn <- quiet_dynet(data.frame(from = "A", to = "A", time = c(0, 1)),
                    format = "contact", loops = TRUE)
  expect_error(turnover(dn), class = "dynet_empty_result")
})

test_that("turnover refuses an unknown measure and a missing session column", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  expect_error(turnover(dn, measure = "churn"),
               class = "dynet_unknown_measure")
  expect_error(turnover(dn, sessions = "separate"),
               class = "dynet_no_sessions")
})

# ----------------------------------------------------------------- invariants

test_that("volatility stays in [0, 1] and fluctuability in (0, 1]", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  volatility <- as.data.frame(turnover(dn))
  expect_true(all(volatility$value >= 0 & volatility$value <= 1))
  fluct <- as.data.frame(turnover(dn, measure = "fluctuability",
                                  scope = "overall"))
  expect_true(fluct$value > 0 && fluct$value <= 1)
})

test_that("a frozen network has zero volatility and fluctuability 1/T", {
  for (n_bins in 2:6) {
    dn <- frozen_network(n_bins)
    grid <- list(start = 0, end = n_bins - 1, window = 0)
    volatility <- as.data.frame(do.call(turnover, c(list(dn), grid)))
    expect_equal(volatility$value, rep(0, nrow(volatility)),
                 info = paste("bins =", n_bins))
    fluct <- as.data.frame(do.call(turnover, c(
      list(dn, measure = "fluctuability", scope = "overall"), grid
    )))
    expect_equal(fluct$value, 1 / n_bins, tolerance = 1e-12,
                 info = paste("bins =", n_bins))
  }
})

test_that("overall volatility is exactly the mean of the per-time values", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  pertime <- as.data.frame(turnover(dn, scope = "pertime"))
  overall <- as.data.frame(turnover(dn, scope = "overall",
                                    measure = "volatility"))
  expect_equal(overall$value, mean(pertime$value),
               tolerance = sqrt(.Machine$double.eps))
})

test_that("both measures are dimensionless under a rescaling of time", {
  dn <- teneto_fixture()
  raw <- as.data.frame(dn)
  scaled <- quiet_dynet(
    data.frame(from = raw$from, to = raw$to, time = raw$start * 10),
    format = "contact", directed = FALSE
  )
  base <- as.data.frame(turnover(dn, measure = c("volatility",
                                                 "fluctuability"),
                                 scope = "overall",
                                 start = 0, end = 3, window = 0))
  wide <- as.data.frame(turnover(scaled, measure = c("volatility",
                                                     "fluctuability"),
                                 scope = "overall",
                                 start = 0, end = 30, window = 0))
  expect_equal(base$value, wide$value, tolerance = 1e-12)
})

test_that("volatility agrees with similarity's hamming, rescaled", {
  # similarity(method = "hamming") is a raw count over the full symmetric
  # matrix. Dividing by 2 * choose(n, 2) recovers the proportion. Reaching
  # into an off-diagonal like this is test-only work -- that a user would
  # otherwise have to do it is exactly why turnover() exists.
  dn <- teneto_fixture()
  grid <- list(start = 0, end = 3, window = 0)
  mine <- as.data.frame(do.call(turnover, c(list(dn), grid)))
  sim <- as.data.frame(do.call(similarity, c(list(dn, method = "hamming"),
                                             grid)))
  n <- nrow(dn$nodes)
  rescaled <- vapply(mine$time, function(t) {
    row <- sim[sim$time == t & sim$other == t + 1, , drop = FALSE]
    row$value / (2 * choose(n, 2))
  }, numeric(1L))
  expect_equal(mine$value, rescaled, tolerance = 1e-12)
})

# ---------------------------------------------------------------- equivalence

test_that("turnover reproduces teneto's volatility and fluctuability", {
  reference <- teneto_reference()
  dn <- teneto_fixture()
  grid <- list(start = 0, end = 3, window = 0)

  pertime <- as.data.frame(do.call(turnover, c(list(dn), grid)))
  expect_equal(pertime$value, reference$volatility_pertime, tolerance = 1e-12)

  overall <- as.data.frame(do.call(turnover, c(
    list(dn, measure = c("volatility", "fluctuability"), scope = "overall"),
    grid
  )))
  expect_equal(overall$value[overall$measure == "volatility"],
               reference$volatility_overall, tolerance = 1e-12)
  expect_equal(overall$value[overall$measure == "fluctuability"],
               reference$fluctuability, tolerance = 1e-12)
})

test_that("the final bin opens no transition", {
  out <- as.data.frame(turnover(teneto_fixture(), start = 0, end = 3,
                                window = 0))
  expect_identical(nrow(out), 3L)
  expect_false(3 %in% out$time)
})

# ------------------------------------------------------------------ structure

test_that("turnover reports at graph level with the documented attributes", {
  # school_contacts builds directed, so the undirected domain is asserted on
  # the fixture that is explicitly undirected.
  out <- turnover(quiet_dynet(school_contacts, format = "contact"))
  expect_identical(attr(out, "level"), "graph")
  expect_identical(attr(out, "distance"), "hamming_proportion")
  expect_identical(names(as.data.frame(out)), c("time", "measure", "value"))

  undirected <- turnover(teneto_fixture(), start = 0, end = 3, window = 0)
  expect_identical(attr(undirected, "opportunity_domain"),
                   "eligible_nonloop_unordered_dyads")
})

test_that("a directed network uses the ordered pair domain", {
  dn <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("B", "A"), time = c(0, 1)),
    format = "contact", directed = TRUE
  )
  out <- turnover(dn, start = 0, end = 1, window = 0)
  expect_identical(attr(out, "opportunity_domain"),
                   "eligible_nonloop_ordered_pairs")
  # A->B present then absent, B->A absent then present: 2 of 2 ordered pairs
  # changed.
  expect_equal(as.data.frame(out)$value, 1)
})
