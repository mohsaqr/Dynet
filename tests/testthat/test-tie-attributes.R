# ===========================================================================
# dynet() keeps the log's other columns as tie attributes
# ===========================================================================

log_interval <- data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"),
                           start = c(0, 1, 2), end = c(2, 3, 4),
                           grp = c("x", "y", "x"), score = c(1.5, 2.5, 3.5),
                           stringsAsFactors = FALSE)
log_contact <- data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"),
                          time = c(0, 1, 2), grp = c("x", "y", "x"),
                          thread = c("t1", "t1", "t2"), stringsAsFactors = FALSE)

test_that("interval, contact and threaded logs keep their extra columns, row for row", {
  for (dn in list(quiet_dynet(log_interval),
                  quiet_dynet(log_contact, time = "time"),
                  quiet_dynet(log_contact, thread = "thread"))) {
    sp <- as.data.frame(dn)
    expect_true("grp" %in% names(sp))
    expect_identical(sp$grp[match(c("A", "B", "C"), sp$from)], c("x", "y", "x"))
  }
  expect_equal(as.data.frame(quiet_dynet(log_interval))$score[order(as.data.frame(quiet_dynet(log_interval))$from)], c(1.5, 2.5, 3.5))
})

test_that("a selection can name the attribute directly", {
  dn <- quiet_dynet(log_contact, time = "time")
  sub <- induce_subgraph(dn, ties = grp == "x")
  expect_equal(nrow(as.data.frame(sub)), 2L)
  expect_setequal(as.data.frame(sub)$from, c("A", "C"))
})

test_that("consumed and canonical columns are not duplicated as attributes", {
  dn <- quiet_dynet(transform(log_interval, weight = c(2, 3, 4)), weight = "weight")
  sp <- as.data.frame(dn)
  expect_equal(sum(names(sp) == "weight"), 1L)
  expect_equal(sort(sp$weight), c(2, 3, 4))
  expect_false("start" %in% setdiff(names(sp), c("from", "to", "start", "end", "duration", "weight", "grp", "score")))
})

test_that("co-presence logs keep no attributes and a list column is a classed error", {
  cp <- data.frame(student = c("s1", "s2", "s3"), seminar = "w1", note = c("a", "b", "c"))
  expect_false("note" %in% names(as.data.frame(quiet_dynet(cp, actor = "student", group = "seminar"))))
  bad <- log_interval; bad$blob <- list(1, 2, 3)
  expect_error(dynet(bad), class = "dynet_bad_tie_attribute")
})

test_that("attributes change no measurement", {
  with_attr <- quiet_dynet(log_interval)
  plain <- quiet_dynet(log_interval[, c("from", "to", "start", "end")])
  expect_equal(as.data.frame(metrics(with_attr, measure = "density"))$value,
               as.data.frame(metrics(plain, measure = "density"))$value)
  expect_equal(as.data.frame(paths(with_attr, from = "A"))$latency,
               as.data.frame(paths(plain, from = "A"))$latency)
})
