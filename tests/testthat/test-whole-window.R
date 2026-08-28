# `window = "all"` measures the whole observed period as a single window,
# closed on the right so the last instant is inside it.

test_that("one window covers the period", {
  dn <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                         start = c(0, 3), end = c(1, 5)))
  whole <- as.data.frame(metrics(dn, measure = "edges", window = "all"))
  expect_identical(nrow(whole), 1L)
  expect_identical(whole$value, 2)
  expect_identical(whole$time, 0)
})

test_that("the whole window is closed on the right", {
  # A contact at the last observed instant sits exactly on the right edge.
  # A half-open window drops it, which is what forced callers to pad `window`
  # by hand; the same event must survive when the period is measured whole.
  dn <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"), time = c(0, 5)),
              format = "contact")
  whole <- as.data.frame(metrics(dn, measure = "edges", window = "all"))
  expect_identical(whole$value, 2)
  expect_identical(
    as.data.frame(events(dn, "formation", window = "all"))$value, 2)
})

test_that("aggregate density equals the static density of the union network", {
  dn <- dynet(school_contacts)
  pairs <- nrow(as.data.frame(dn, what = "network"))
  n <- nrow(as.data.frame(dn, what = "nodes"))
  possible <- if (dn$directed) n * (n - 1) else n * (n - 1) / 2
  got <- as.data.frame(metrics(dn, measure = "density", window = "all"))
  expect_equal(got$value, pairs / possible)
})

test_that("degree over the whole window is the aggregate degree", {
  dn <- dynet(data.frame(from = c("A", "A", "B"), to = c("B", "C", "C"),
                         start = c(0, 2, 4), end = c(1, 3, 5)))
  got <- as.data.frame(dyn_centrality(dn, measure = "degree", window = "all"))
  expect_equal(got$value[got$node == "A"], 2)
  expect_equal(got$value[got$node == "B"], 2)
  expect_equal(got$value[got$node == "C"], 2)
})

test_that("every session gets its own whole window", {
  dn <- dynet(data.frame(from = c("A", "B", "A"), to = c("B", "C", "C"),
                         start = c(0, 10, 20), end = c(1, 11, 21),
                         session = c("s1", "s1", "s2")),
              session = "session")
  got <- as.data.frame(metrics(dn, measure = "edges", sessions = "separate",
                               window = "all"))
  expect_identical(nrow(got), 2L)
  expect_identical(sort(got$session), c("s1", "s2"))
  expect_identical(got$value[got$session == "s1"], 2)
})

test_that("discontinuous observation gets one window per component", {
  # Unobserved gaps are never measured across, so "all" is per component.
  dn <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                         start = c(0, 10), end = c(1, 11)),
              observation_spells = data.frame(start = c(0, 10), end = c(2, 12)))
  got <- as.data.frame(metrics(dn, measure = "edges", window = "all"))
  expect_identical(nrow(got), 2L)
  expect_identical(got$value, c(1, 1))
})

test_that("a whole window is invariant to how the period is otherwise binned", {
  dn <- dynet(school_contacts)
  first <- as.data.frame(metrics(dn, measure = "edges", window = "all"))
  second <- as.data.frame(metrics(dn, measure = "edges", window = "all",
                                  start = 0))
  expect_equal(first$value, second$value)
})

test_that("`step` with a whole window is refused rather than ignored", {
  dn <- dynet(school_contacts)
  expect_error(metrics(dn, measure = "density", step = 1, window = "all"),
               class = "dynet_bad_input")
})

test_that("only \"all\" is accepted as a non-numeric window", {
  dn <- dynet(school_contacts)
  expect_error(metrics(dn, measure = "density", window = "everything"))
  expect_error(metrics(dn, measure = "density", window = c("all", "all")))
})

test_that("the whole window reaches every verb that takes one", {
  dn <- dynet(school_contacts)
  expect_identical(nrow(as.data.frame(events(dn, "formation", window = "all"))), 1L)
  expect_gt(nrow(as.data.frame(snapshots(dn, window = "all"))), 0L)
  expect_gt(nrow(as.data.frame(projection(dn, window = "all"))), 0L)
})
