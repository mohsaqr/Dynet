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

test_that("`at` one ulp from a bin edge selects the bins of that edge", {
  # 7 * (1 / 24) is one ulp below 7 / 24, the boundary the spells carry. A
  # bare `<` put it inside the half-open bin [5/24, 7/24) that ends there.
  h <- 1 / 24
  dn <- quiet_dynet(data.frame(from = c("A", "B", "C"), to = c("B", "C", "D"),
                               start = c(0, 6, 3) / 24, end = c(5, 7, 9) / 24))
  exact <- as.data.frame(snapshots(dn, at = 7 / 24, step = h, window = 2 * h))
  near <- as.data.frame(snapshots(dn, at = 7 * h, step = h, window = 2 * h))
  expect_identical(near, exact)
  expect_equal(unique(exact$time), c(6, 7) / 24)
})

test_that("every bin returned for `at` covers it", {
  dn <- quiet_dynet(random_edges(seed = 5L))
  grid <- as.data.frame(metrics(dn, measure = "edges", step = 1, window = 3))
  for (at in c(2, 2.5, 7.25, 11)) {
    got <- unique(as.data.frame(snapshots(dn, at = at, step = 1,
                                          window = 3))$time)
    covering <- grid$time[grid$time <= at & grid$time + 3 > at]
    # A covering bin with no active tie has no snapshot row.
    expect_true(all(got %in% covering), info = at)
  }
})

test_that("a malformed `at` is dynet_bad_input", {
  dn <- quiet_dynet(chain_edges())
  expect_error(snapshots(dn, at = c(1, 2)), class = "dynet_bad_input")
})
