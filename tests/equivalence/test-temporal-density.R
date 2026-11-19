# metrics(measure = "temporal_density"): the share of dyad-time during which a tie is active, on the bundled
# school_contacts spells. Against tsna::tEdgeDensity(mode = "duration", agg.unit = "dyad"), run live.

vertices <- sort(unique(c(school_contacts$from, school_contacts$to)))

test_that("temporal density over the whole period equals tsna::tEdgeDensity()", {
  skip_without_reference("tsna")
  skip_without_reference("networkDynamic")
  # No net.obs.period: tsna then divides by the span from the first to the last change time, 0 to 21.52,
  # which is the period dynet() takes as observed.
  theirs <- tsna::tEdgeDensity(ref_network_dynamic(school_contacts), mode = "duration", agg.unit = "dyad")
  ours <- as.data.frame(metrics(dynet(school_contacts), measure = "temporal_density", window = "all"))
  expect_reference(ours$value, theirs, reference = "tsna", covers = "metrics()",
                   quantity = "temporal density, whole period", tolerance = 1e-12)
})

test_that("temporal density in bins of 7 equals tsna::tEdgeDensity() on each bin's clipped spells", {
  skip_without_reference("tsna")
  skip_without_reference("networkDynamic")
  last <- max(school_contacts$end)
  onsets <- seq(0, last, by = 7)
  theirs <- vapply(onsets, \(lo) {
    hi <- min(lo + 7, last)
    clipped <- ref_network_dynamic(ref_clip(school_contacts, lo, hi), vertices = vertices, observed = c(lo, hi))
    tsna::tEdgeDensity(clipped, mode = "duration", agg.unit = "dyad")
  }, numeric(1L))
  ours <- as.data.frame(metrics(dynet(school_contacts), measure = "temporal_density", step = 7, window = 7))
  expect_reference(subset(ours, select = c(time, value)), data.frame(time = onsets, value = theirs),
                   reference = "tsna", covers = c("metrics()", "as.data.frame.dynet_metric()"),
                   quantity = "temporal density, bins of 7", tolerance = 1e-12, key = "time")
})

test_that("temporal density equals occupied ordered-pair time over all ordered-pair time, written out", {
  # The definition: within [lo, hi], each ordered pair's spells are clipped and their union measured (overlaps
  # counted once); the sum over pairs is divided by n (n - 1) (hi - lo).
  pair_slots <- length(vertices) * (length(vertices) - 1)
  density <- function(lo, hi) {
    inside <- ref_clip(school_contacts, lo, hi)
    occupied <- vapply(split(inside, paste(inside$from, inside$to)),
                       \(pair) ref_union_length(pair$start, pair$end), numeric(1))
    sum(occupied) / (pair_slots * (hi - lo))
  }
  last <- max(school_contacts$end)
  onsets <- seq(0, last, by = 7)
  by_definition <- "independent: union of each pair's clipped spells over pair-time, base R"
  whole <- as.data.frame(metrics(dynet(school_contacts), measure = "temporal_density", window = "all"))
  expect_reference(whole$value, density(0, last), reference = by_definition, covers = "metrics()",
                   quantity = "temporal density, whole period", tolerance = 1e-12)
  bins <- as.data.frame(metrics(dynet(school_contacts), measure = "temporal_density", step = 7, window = 7))
  expected <- data.frame(time = onsets, value = vapply(onsets, \(lo) density(lo, min(lo + 7, last)), numeric(1)))
  expect_reference(subset(bins, select = c(time, value)), expected, reference = by_definition, covers = "metrics()",
                   quantity = "temporal density, bins of 7", tolerance = 1e-12, key = "time")
})
