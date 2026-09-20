# segregation() is Fransson's SID. It is the one measure here that needs a
# community assignment the package cannot produce, so most of this file is
# about refusing a partition it cannot trust.
#
# Reference values from a live teneto 0.5.3 run on 2026-09-20:
#   sid(G, communities=[0,0,1,1], calc='overtime') -> [0.5, 2.0, 0.5, -0.5]
# Note teneto's 'overtime' returns one value PER BIN, not one overall; that is
# this verb's scope = "pertime".

sid_fixture <- function() {
  quiet_dynet(
    data.frame(
      from = c("A", "B", "A", "C", "A", "B", "A"),
      to   = c("B", "C", "B", "D", "B", "C", "C"),
      time = c(0, 0, 1, 1, 2, 2, 3)
    ),
    format = "contact", directed = FALSE
  )
}

two_groups <- c(A = "a", B = "a", C = "b", D = "b")
SPEC_GRID <- list(start = 0, end = 3, window = 0)

# ---------------------------------------------------------------- error paths

test_that("a positional partition is refused", {
  # Matching communities to vertices by position is exactly the index-based
  # addressing this package exists to avoid.
  expect_error(segregation(sid_fixture(), communities = c("a", "a", "b", "b")),
               class = "dynet_bad_communities")
})

test_that("an unknown vertex name is refused", {
  bad <- c(A = "a", B = "a", C = "b", Z = "b")
  expect_error(segregation(sid_fixture(), communities = bad),
               class = "dynet_bad_communities")
})

test_that("an unassigned vertex is refused rather than dropped", {
  # Dropping it would change every other community's denominator, so the
  # answer would be silently wrong rather than absent.
  partial <- c(A = "a", B = "a", C = "b")
  expect_error(segregation(sid_fixture(), communities = partial),
               class = "dynet_bad_communities")
})

test_that("segregation refuses separate without sessions", {
  expect_error(
    segregation(sid_fixture(), communities = two_groups,
                sessions = "separate"),
    class = "dynet_no_sessions"
  )
})

# ------------------------------------------------------------------- warnings

test_that("a singleton community warns and yields NA", {
  singleton <- c(A = "a", B = "a", C = "b", D = "c")
  expect_warning(
    out <- segregation(sid_fixture(), communities = singleton,
                       start = 0, end = 3, window = 0),
    class = "dynet_singleton_community"
  )
  expect_true(all(is.na(as.data.frame(out)$value)))
})

# ---------------------------------------------------------------- equivalence

test_that("SID reproduces teneto's reference series", {
  out <- as.data.frame(do.call(
    segregation, c(list(sid_fixture(), communities = two_groups), SPEC_GRID)
  ))
  expect_equal(out$value, c(0.5, 2.0, 0.5, -0.5), tolerance = 1e-12)
})

test_that("the overall scope is the mean of the per-time series", {
  pertime <- as.data.frame(do.call(
    segregation, c(list(sid_fixture(), communities = two_groups), SPEC_GRID)
  ))
  overall <- as.data.frame(do.call(
    segregation,
    c(list(sid_fixture(), communities = two_groups, scope = "overall"),
      SPEC_GRID)
  ))
  expect_equal(overall$value, mean(pertime$value),
               tolerance = sqrt(.Machine$double.eps))
})

# ----------------------------------------------------------------- invariants

test_that("a fully within-community network scores above a fully crossing one", {
  within <- quiet_dynet(
    data.frame(from = c("A", "C"), to = c("B", "D"), time = c(0, 0)),
    format = "contact", directed = FALSE
  )
  crossing <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("C", "D"), time = c(0, 0)),
    format = "contact", directed = FALSE
  )
  w <- as.data.frame(segregation(within, communities = two_groups,
                                 start = 0, end = 0, window = 0))$value
  x <- as.data.frame(segregation(crossing, communities = two_groups,
                                 start = 0, end = 0, window = 0))$value
  expect_gt(w, x)
  expect_gt(w, 0)
  expect_lt(x, 0)
})

test_that("the value follows names, not positions, through a rename", {
  dn <- sid_fixture()
  before <- as.data.frame(do.call(
    segregation, c(list(dn, communities = two_groups), SPEC_GRID)
  ))
  renamed <- rename_nodes(dn, c(A = "w", B = "x", C = "y", D = "z"))
  after <- as.data.frame(do.call(
    segregation,
    c(list(renamed, communities = c(w = "a", x = "a", y = "b", z = "b")),
      SPEC_GRID)
  ))
  expect_equal(before$value, after$value)
})

test_that("relabelling the communities does not change the value", {
  dn <- sid_fixture()
  base <- as.data.frame(do.call(
    segregation, c(list(dn, communities = two_groups), SPEC_GRID)
  ))
  relabelled <- as.data.frame(do.call(
    segregation,
    c(list(dn, communities = c(A = "red", B = "red", C = "blue", D = "blue")),
      SPEC_GRID)
  ))
  expect_equal(base$value, relabelled$value)
})

test_that("a node-table column works as well as a named vector", {
  raw <- as.data.frame(sid_fixture())
  dn <- quiet_dynet(
    data.frame(from = raw$from, to = raw$to, time = raw$start),
    format = "contact", directed = FALSE,
    nodes = data.frame(name = c("A", "B", "C", "D"),
                       team = c("a", "a", "b", "b"))
  )
  by_column <- as.data.frame(do.call(
    segregation, c(list(dn, communities = "team"), SPEC_GRID)
  ))
  by_vector <- as.data.frame(do.call(
    segregation, c(list(dn, communities = two_groups), SPEC_GRID)
  ))
  expect_equal(by_column$value, by_vector$value)
})

# ------------------------------------------------------------------ structure

test_that("the result reports at graph level with its community metadata", {
  out <- do.call(segregation,
                 c(list(sid_fixture(), communities = two_groups), SPEC_GRID))
  expect_identical(attr(out, "level"), "graph")
  expect_identical(attr(out, "communities_n"), 2L)
  expect_identical(attr(out, "community_sizes"), c(a = 2L, b = 2L))
  expect_identical(attr(out, "singleton_rule"), "NA")
  expect_identical(names(as.data.frame(out)), c("time", "measure", "value"))
  expect_identical(unique(out$measure), "sid")
})
