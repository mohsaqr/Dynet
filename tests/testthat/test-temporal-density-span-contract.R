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
