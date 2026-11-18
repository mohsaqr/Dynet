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
