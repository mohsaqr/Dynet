# ===========================================================================
# thread_clock = "relative": every thread on its own clock
# ===========================================================================

posts <- data.frame(
  from = c("A", "B", "C", "A", "B"), to = c("B", "A", "A", "C", "C"),
  time = c(10, 12, 15, 100, 103), thread = c("t1", "t1", "t1", "t2", "t2"),
  stringsAsFactors = FALSE
)

test_that("relative clock starts every thread at zero and ends at its span", {
  dn <- quiet_dynet(posts, thread = "thread", thread_clock = "relative")
  sp <- as.data.frame(dn)
  # The spell table is sorted by time, so compare by thread, not by position.
  expect_equal(as.numeric(tapply(sp$start, sp$thread, min)[c("t1", "t2")]), c(0, 0))
  expect_equal(unique(sp$end[sp$thread == "t1"]), 5)
  expect_equal(unique(sp$end[sp$thread == "t2"]), 3)
  expect_equal(sort(sp$start[sp$thread == "t1"]), c(0, 2, 5))
})

test_that("absolute is the default and differs from relative only by each thread's origin", {
  abs_ <- as.data.frame(quiet_dynet(posts, thread = "thread"))
  rel <- as.data.frame(quiet_dynet(posts, thread = "thread", thread_clock = "relative"))
  key <- function(d) paste(d$from, d$to, d$thread, d$duration)
  rel <- rel[match(key(abs_), key(rel)), ]
  origin <- tapply(abs_$start, abs_$thread, min)
  expect_equal(rel$start, abs_$start - as.numeric(origin[abs_$thread]))
  expect_equal(rel$end, abs_$end - as.numeric(origin[abs_$thread]))
  expect_equal(rel$duration, abs_$duration)
})

test_that("a relative clock without a thread column is a classed error", {
  expect_error(dynet(posts, time = "time", thread_clock = "relative"),
               class = "dynet_needs_thread")
})

test_that("durations are invariant to the clock choice", {
  a <- as.data.frame(durations(quiet_dynet(posts, thread = "thread"), unit = "pair", measure = "total"))
  b <- as.data.frame(durations(quiet_dynet(posts, thread = "thread", thread_clock = "relative"), unit = "pair", measure = "total"))
  expect_equal(b$value, a$value)
})
