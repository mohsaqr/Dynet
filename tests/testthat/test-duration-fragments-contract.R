# durations() builds spells between vertices without declared activity in one
# vectorised step and clips only spells touching a declared vertex. These
# tests pin that the two routes agree and that mixing them keeps row order.

partial_activity <- function() {
  data.frame(node = c("v1", "v2", "v3"), start = c(0, 4, 2), end = c(12, 18, 9))
}

test_that("a spell between undeclared vertices is its own fragment", {
  e <- random_edges()
  dn <- quiet_dynet(e)
  spell <- durations(dn, unit = "spell", measure = "duration")
  expect_equal(sort(spell$value), sort(e$end - e$start))
  expect_identical(nrow(spell), nrow(e))
})

test_that("free pairs are unaffected by other vertices' declared activity", {
  e <- random_edges()
  plain <- as.data.frame(durations(quiet_dynet(e), measure = c("events", "total")))
  mixed <- as.data.frame(durations(
    quiet_dynet(e, vertex_spells = partial_activity()),
    measure = c("events", "total")
  ))
  declared <- partial_activity()$node
  free_plain <- subset(plain, !from %in% declared & !to %in% declared)
  free_mixed <- subset(mixed, !from %in% declared & !to %in% declared)
  rownames(free_plain) <- rownames(free_mixed) <- NULL
  expect_gt(nrow(free_mixed), 0L)
  expect_equal(free_mixed, free_plain)
})

test_that("pair total equals the sum of its spell durations with mixed routes", {
  dn <- quiet_dynet(random_edges(), vertex_spells = partial_activity())
  spell <- as.data.frame(durations(dn, unit = "spell", measure = "duration"))
  pair <- as.data.frame(durations(dn, unit = "pair", measure = "total"))
  summed <- aggregate(value ~ from + to, data = spell, FUN = sum)
  both <- merge(pair, summed, by = c("from", "to"), suffixes = c("_pair", "_spell"))
  expect_identical(nrow(both), nrow(pair))
  expect_equal(both$value_pair, both$value_spell)
})

test_that("pair durations are invariant to the order of the input rows", {
  e <- random_edges(seed = 3L)
  shuffled <- e[rev(seq_len(nrow(e))), , drop = FALSE]
  measures <- c("events", "total", "union", "mean", "median", "first", "last")
  a <- durations(quiet_dynet(e, vertex_spells = partial_activity()),
                 measure = measures)
  b <- durations(quiet_dynet(shuffled, vertex_spells = partial_activity()),
                 measure = measures)
  expect_equal(as.data.frame(a), as.data.frame(b))
})

test_that("an unknown duration measure raises a classed condition", {
  dn <- quiet_dynet(random_edges(), vertex_spells = partial_activity())
  expect_error(durations(dn, unit = "spell", measure = "total"),
               class = "dynet_unknown_measure")
  expect_error(durations(dn, measure = "nonsense"),
               class = "dynet_unknown_measure")
})
