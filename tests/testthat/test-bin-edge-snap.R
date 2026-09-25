# ===========================================================================
# Window edges are snapped onto the data's own boundaries, so a sub-unit
# `step` on a date-converted network places events in the same bins as the
# integer-time twin does (review 2026-09-05, finding 13).
# ===========================================================================

hourly_pair <- function(seed = 4L) {
  set.seed(seed)
  n <- 10L; k <- 120L
  nm <- sprintf("v%02d", seq_len(n))
  i <- sample.int(n, k, TRUE); j <- sample.int(n, k, TRUE); j[i == j] <- (j[i == j] %% n) + 1L
  s <- sample(0:99, k, TRUE); e <- s + sample(1:5, k, TRUE)
  hours <- data.frame(from = nm[i], to = nm[j], start = s, end = e,
                      stringsAsFactors = FALSE)
  origin <- as.POSIXct("2024-01-01", tz = "UTC")
  stamps <- transform(hours, start = origin + start * 3600, end = origin + end * 3600)
  list(hours = quiet_dynet(hours), stamps = quiet_dynet(stamps))
}

test_that("a spell ending exactly at a window's start is not inside it", {
  # Window edges built as k * (1/24) fall one ulp below the exact k/24 that
  # the spells carry; without snapping the first spell leaks into bin 5.
  dn <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                               start = c(0, 6) / 24, end = c(5, 7) / 24))
  got <- as.data.frame(metrics(dn, measure = "edges", step = 1 / 24,
                               window = 1 / 24, start = 0, end = 6 / 24))
  expect_equal(got$value, c(1, 1, 1, 1, 1, 0, 1))
  expect_equal(got$time, (0:6) / 24)
})

test_that("integer hours and POSIXct hours give identical hourly series", {
  p <- hourly_pair()
  expect_identical(p$stamps$meta$time_unit, "days")
  h <- 1 / 24
  for (measure in c("edges", "density", "components")) {
    a <- as.data.frame(metrics(p$hours, measure = measure))
    b <- as.data.frame(metrics(p$stamps, measure = measure, step = h, window = h))
    expect_equal(b$value, a$value, info = measure)
    expect_equal(b$time * 24, a$time)
  }
  a <- as.data.frame(centrality_series(p$hours, measure = "degree"))
  b <- as.data.frame(centrality_series(p$stamps, measure = "degree", step = h, window = h))
  expect_equal(b$value, a$value)
  a <- as.data.frame(events(p$hours))
  b <- as.data.frame(events(p$stamps, step = h, window = h))
  expect_equal(b$value, a$value)
  sa <- as.data.frame(snapshots(p$hours)); sb <- as.data.frame(snapshots(p$stamps, step = h, window = h))
  expect_equal(paste(round(sb$time * 24), sb$from, sb$to), paste(sa$time, sa$from, sa$to))
})

test_that("snapping is idempotent and leaves edges with no boundary nearby alone", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", start = 5 / 24, end = 6 / 24))
  enc <- Dynet:::.encode(dn)
  grid <- data.frame(bin = 1:3, lo = c(5 * (1 / 24), 0.3, 6 * (1 / 24)),
                     hi = c(6 * (1 / 24), 0.4, 7 * (1 / 24)),
                     time = c(5 * (1 / 24), 0.3, 6 * (1 / 24)), closed = FALSE)
  once <- Dynet:::.snap_grid(grid, enc, dn)
  expect_identical(once$lo[1], 5 / 24)
  expect_identical(once$hi[1], 6 / 24)
  expect_identical(once$lo[2], 0.3)
  expect_identical(once$hi[2], 0.4)
  expect_identical(Dynet:::.snap_grid(once, enc, dn), once)
  expect_identical(once$time, once$lo)
})

test_that("a grid on integer data is unchanged by snapping", {
  dn <- quiet_dynet(random_edges(seed = 7L))
  before <- as.data.frame(metrics(dn, measure = "edges"))
  expect_equal(before$time, seq(dn$meta$time_range[["start"]],
                                by = 1, length.out = nrow(before)))
})
