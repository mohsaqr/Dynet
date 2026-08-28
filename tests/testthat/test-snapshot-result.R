# snapshots() returns a result object with the four methods every result class
# carries, so the edges never have to be reached into to be seen or drawn.

test_that("snapshots carry their own class and the plain table is available", {
  dn <- dynet(school_contacts)
  s <- snapshots(dn)
  expect_s3_class(s, "dynet_snapshot")
  flat <- as.data.frame(s)
  expect_identical(class(flat), "data.frame")
  expect_identical(nrow(flat), nrow(s))
})

test_that("printing says what the table holds", {
  dn <- dynet(school_contacts)
  expect_output(print(snapshots(dn, at = 3)), "Snapshot edges")
  expect_output(print(snapshots(dn)), "more rows")
})

test_that("summary counts ties per bin and agrees with metrics", {
  dn <- dynet(school_contacts)
  counted <- summary(snapshots(dn))
  edges <- as.data.frame(metrics(dn, measure = "edges"))
  expect_equal(counted$ties[match(edges$time, counted$time)], edges$value)
})

test_that("summary of an empty snapshot is an empty table, not an error", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
  empty <- snapshots(dn, start = 50, end = 50, window = 1)
  expect_identical(nrow(as.data.frame(empty)), 0L)
  expect_identical(nrow(summary(empty)), 0L)
  expect_output(print(empty), "No tie is active")
})

test_that("plotting an empty snapshot refuses rather than drawing nothing", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
  expect_error(plot(snapshots(dn, start = 50, end = 50, window = 1)),
               class = "dynet_empty_result")
})

test_that("the plot is a ggplot of ties per bin", {
  dn <- dynet(school_contacts)
  expect_s3_class(plot(snapshots(dn)), "ggplot")
})
