integrated <- function(dn, ...) {
  x <- metrics(dn, c("temporal_density", "onset_intensity"), ...)
  as.data.frame(x)
}

test_that("a window past the data's end adds no pair-time", {
  dn <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                         start = c(0, 2), end = c(2, 3)))
  got <- integrated(dn, step = 2, window = 2)
  density <- got$value[got$measure == "temporal_density"]
  # Six ordered pairs. The last window is cut at 3, where the data end:
  # one pair-day occupied out of six, not out of twelve.
  expect_equal(density, c(2 / 12, 1 / 6))
})

test_that("tiled windows pool to the whole-period temporal density", {
  dn <- quiet_dynet(school_contacts)
  bins <- integrated(dn, step = 7, window = 7)
  whole <- integrated(dn, window = "all")
  lengths <- pmin(bins$time + 7, 21.52) - bins$time
  density <- bins$measure == "temporal_density"
  pooled <- sum(bins$value[density] * lengths[density]) /
    sum(lengths[density])
  expect_equal(pooled, whole$value[whole$measure == "temporal_density"])
})

test_that("an explicit observation period is still honoured in full", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", start = 0, end = 2),
                    observation_start = 0, observation_end = 8)
  got <- integrated(dn, step = 4, window = 4)
  expect_equal(got$value[got$measure == "temporal_density"], c(2 / 8, 0))
})

test_that("a malformed grid still raises the grid condition", {
  dn <- quiet_dynet(chain_edges())
  expect_error(metrics(dn, "temporal_density", window = -1),
               class = "dynet_bad_input")
})

test_that("tiled and whole-period temporal density reproduce tsna::tEdgeDensity", {
  # Reference values produced on 2026-11-01 with tsna 0.3.6: tEdgeDensity(nd,
  # agg.unit = "dyad") on the whole network with no net.obs.period (tsna then
  # divides by the first-to-last change-time span, 0 to 21.52), and on each
  # bin's spells clipped to [t, min(t + 7, 21.52)] with that interval as
  # net.obs.period. They are pinned rather than recomputed so the test does
  # not need tsna; local_testing_and_equivalence holds the live comparison.
  dn <- quiet_dynet(school_contacts)
  whole <- as.data.frame(metrics(dn, "temporal_density", window = "all"))
  expect_equal(whole$value, 0.028544875199150, tolerance = 1e-12)
  bins <- as.data.frame(metrics(dn, "temporal_density", step = 7, window = 7))
  expect_equal(bins$time, c(0, 7, 14, 21))
  expect_equal(bins$value, c(0.024285714285714, 0.038602825745683,
                             0.023524332810047, 0.018068469991547),
               tolerance = 1e-12)
})

test_that("a grid extended past the data's end changes no bin's density", {
  # Invariant: exposure stops at the observed span (1 to 5 here), so asking
  # for a later `end` adds bins but leaves every shared bin unchanged, and a
  # bin wholly past the data has zero exposure and so no density at all.
  dn <- quiet_dynet(chain_edges())
  base <- integrated(dn, step = 1, window = 2)
  longer <- integrated(dn, step = 1, window = 2, end = 8)
  shared <- merge(base, longer, by = c("time", "measure"))
  expect_equal(shared$value.x, shared$value.y)
  past <- longer$time >= 5
  expect_true(any(past))
  expect_true(all(is.na(longer$value[past])))
  expect_true(all(longer$value[!past] >= 0))
})
