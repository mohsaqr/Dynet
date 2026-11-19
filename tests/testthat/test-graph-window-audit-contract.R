# ===========================================================================
# metrics() defects found in the 2026-11-01 audit: temporal path measures on
# a window with no eligible vertex, and the closeness-centralisation relation
# to sna that the documentation used to misstate.
# ===========================================================================

gapped_presence <- function() {
  # Every vertex is absent between 4 and 9, so bins in that stretch have an
  # empty eligible set.
  quiet_dynet(
    data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"),
               start = c(0, 1, 10), end = c(2, 3, 12)),
    vertex_spells = data.frame(node = c("A", "B", "C"), start = c(0, 0, 9),
                               end = c(4, 4, 12))
  )
}

test_that("temporal path measures survive a window with no eligible vertex", {
  # .temporal_distances() built its matrix from an empty list and failed with
  # "'data' must be of a vector type" before any value was returned.
  dn <- gapped_presence()
  for (window in list(NULL, 0)) {
    got <- as.data.frame(metrics(
      dn, c("temporal_efficiency", "temporal_diameter", "active_nodes"),
      step = 2, window = window
    ))
    empty_bins <- got$time[got$measure == "active_nodes"] %in% c(4, 6)
    efficiency <- got$value[got$measure == "temporal_efficiency"]
    expect_true(all(is.na(efficiency[empty_bins])))
    expect_true(all(efficiency >= 0 & efficiency <= 1, na.rm = TRUE))
    expect_equal(efficiency[[1L]], 0.5)
  }
})

test_that("a negative traversal time is still dynet_bad_input", {
  expect_error(metrics(gapped_presence(), "temporal_efficiency",
                       traversal_time = -1),
               class = "dynet_bad_input")
})

test_that("closeness centralisation stays in [0, 1] on every bin", {
  dn <- quiet_dynet(random_edges(seed = 8L))
  got <- as.data.frame(metrics(dn, "centralization_closeness", step = 2))
  expect_true(all(got$value >= 0 & got$value <= 1, na.rm = TRUE))
})
