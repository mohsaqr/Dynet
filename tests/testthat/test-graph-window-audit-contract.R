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

test_that("closeness centralisation is sna's rescaled by the two maxima", {
  # sna::centralization(a, sna::closeness) on the whole-period union of
  # school_contacts, produced 2026-11-01 with sna 2.8: 0.106681485009658
  # (digraph) and 0.117613017429194 (graph). Both snapshots are connected.
  # Dynet's maximum is n - 1 (directed) or n - 2 (undirected) against sna's
  # (n - 1)^2 / n and (n - 1)(n - 2) / (2n - 3), so with n = 14 the ratios
  # are 13/14 and 13/25.
  directed <- quiet_dynet(school_contacts)
  undirected <- quiet_dynet(school_contacts, directed = FALSE)
  d <- as.data.frame(metrics(directed, "centralization_closeness",
                             window = "all"))
  u <- as.data.frame(metrics(undirected, "centralization_closeness",
                             window = "all"))
  expect_equal(d$value, 0.106681485009658 * 13 / 14, tolerance = 1e-12)
  expect_equal(u$value, 0.117613017429194 * 13 / 25, tolerance = 1e-12)
})

test_that("closeness centralisation stays in [0, 1] on every bin", {
  dn <- quiet_dynet(random_edges(seed = 8L))
  got <- as.data.frame(metrics(dn, "centralization_closeness", step = 2))
  expect_true(all(got$value >= 0 & got$value <= 1, na.rm = TRUE))
})
