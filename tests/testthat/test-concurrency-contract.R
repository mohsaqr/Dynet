concurrency <- function(dn, ...) {
  x <- metrics(dn, c("concurrent_nodes", "concurrent_share"), ...)
  as.data.frame(x)
}

test_that("ties in one window that never overlap are not concurrent", {
  dn <- dynet(data.frame(from = c("A", "A"), to = c("B", "C"),
                         start = c(0, 2), end = c(1, 3)))
  got <- concurrency(dn, step = 3, window = 3)
  expect_equal(got$value, c(0, 0))
})

test_that("overlapping ties make their shared vertex concurrent", {
  dn <- dynet(data.frame(from = c("A", "A"), to = c("B", "C"),
                         start = c(0, 1), end = c(2, 3)))
  got <- concurrency(dn, step = 3, window = 3)
  expect_equal(got$value, c(1, 1 / 3))
})

test_that("half-open spells meeting at a boundary do not overlap", {
  dn <- dynet(data.frame(from = c("A", "A"), to = c("B", "C"),
                         start = c(0, 1), end = c(1, 2)))
  expect_equal(concurrency(dn, step = 2, window = 2)$value, c(0, 0))
})

test_that("a point contact is concurrent only with relations active at it", {
  inside <- dynet(data.frame(from = c("A", "A"), to = c("B", "C"),
                             start = c(0, 1), end = c(2, 1)))
  expect_equal(concurrency(inside, step = 3, window = 3)$value[[1L]], 1)
  apart <- dynet(data.frame(from = c("A", "A"), to = c("B", "C"),
                            time = c(0, 1)))
  expect_equal(concurrency(apart, step = 2, window = 2)$value[[1L]], 0)
})

test_that("repeated or reciprocal ties to one partner are not concurrency", {
  dn <- dynet(data.frame(from = c("A", "B", "A"), to = c("B", "A", "B"),
                         start = c(0, 0.5, 1), end = c(2, 2, 3)))
  expect_equal(concurrency(dn, step = 3, window = 3)$value[[1L]], 0)
})

test_that("an overlap while the vertex is absent does not count", {
  dn <- dynet(
    data.frame(from = c("A", "A"), to = c("B", "C"),
               start = c(0, 1), end = c(2, 3)),
    vertex_spells = data.frame(node = c("A", "A"), start = c(0, 2),
                               end = c(1, 3))
  )
  expect_equal(concurrency(dn, step = 3, window = 3)$value[[1L]], 0)
})

test_that("point windows keep the exact instant reading", {
  dn <- dynet(data.frame(from = c("A", "A"), to = c("B", "C"),
                         start = c(0, 1), end = c(2, 3)))
  got <- as.data.frame(metrics(dn, "concurrent_nodes", start = 0, end = 3,
                               step = 0.5, window = 0))
  expect_equal(got$value, c(0, 0, 1, 1, 0, 0, 0))
})

test_that("the result records how concurrency was aggregated", {
  dn <- dynet(chain_edges())
  rolling <- metrics(dn, "concurrent_nodes", window = 2)
  instant <- metrics(dn, "concurrent_nodes", window = 0)
  expect_identical(attr(rolling, "concurrency_window_rule"),
                   "any_instant_in_window")
  expect_identical(attr(instant, "concurrency_window_rule"), "instant_exact")
  expect_identical(attr(rolling, "concurrency_rule"),
                   "at_least_two_distinct_neighbours_at_one_instant")
})

test_that("a malformed grid still raises the grid condition", {
  dn <- dynet(chain_edges())
  expect_error(metrics(dn, "concurrent_nodes", window = -1),
               class = "dynet_bad_input")
})

test_that("window concurrency lies between its instants and its union", {
  dn <- quiet_dynet(random_edges(seed = 7L))
  windows <- concurrency(dn, step = 5, window = 5)
  nodes <- windows$value[windows$measure == "concurrent_nodes"]
  times <- windows$time[windows$measure == "concurrent_nodes"]
  spell_table <- as.data.frame(dn)
  union_bound <- vapply(times, function(t0) {
    active <- spell_table$start < t0 + 5 & spell_table$end > t0
    ends <- c(spell_table$from[active], spell_table$to[active])
    partners <- c(spell_table$to[active], spell_table$from[active])
    counts <- tapply(partners, ends, function(p) length(unique(p)))
    sum(counts >= 2)
  }, numeric(1))
  expect_true(all(nodes <= union_bound))
  sampled <- vapply(times, function(t0) {
    point <- as.data.frame(metrics(dn, "concurrent_nodes", start = t0,
                                   end = t0 + 4.9, step = 0.7, window = 0))
    max(point$value)
  }, numeric(1))
  expect_true(all(nodes >= sampled))
})

test_that("concurrency does not depend on input row order", {
  edges <- random_edges(seed = 11L)
  shuffled <- edges[rev(seq_len(nrow(edges))), , drop = FALSE]
  a <- concurrency(quiet_dynet(edges), step = 4, window = 6)
  b <- concurrency(quiet_dynet(shuffled), step = 4, window = 6)
  expect_equal(a$value, b$value)
})
