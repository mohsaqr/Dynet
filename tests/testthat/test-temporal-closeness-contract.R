closeness_values <- function(dn, ...) {
  result <- as.data.frame(dyn_centrality(
    dn, measure = "closeness", scope = "temporal", ...
  ))
  stats::setNames(result$value, result$node)
}

test_that("the temporal closeness reducer includes zero latency and excludes self", {
  trees <- list(
    list(arrival = c(0, 0, 2), source = 1L, origin = 0),
    list(arrival = c(Inf, 0, Inf), source = 2L, origin = 0),
    list(arrival = c(0, 0, 0), source = 3L, origin = 0)
  )
  expect_identical(Dynet:::.temporal_closeness_values(trees, 3L),
                   c(1, 0, Inf))

  extreme <- list(list(
    arrival = c(0, 1e308, 1e308), source = 1L, origin = 0
  ))
  expect_identical(Dynet:::.temporal_closeness_values(extreme, 3L), 1e-308)
})

test_that("zero-latency endpoints are included explicitly", {
  simultaneous <- quiet_dynet(data.frame(
    from = c("S", "A"), to = c("A", "B"), time = c(0, 0)
  ))
  value <- closeness_values(simultaneous, start = 0, end = 0)
  expect_identical(unname(value[c("S", "A", "B")]), c(Inf, Inf, 0))

  mixed <- quiet_dynet(data.frame(
    from = c("S", "S"), to = c("A", "B"), time = c(0, 2)
  ))
  mixed_value <- closeness_values(mixed, start = 0, end = 2)
  expect_equal(unname(mixed_value[c("S", "A", "B")]), c(1, 0, 0))
})

test_that("positive temporal closeness is inverse reachable mean latency", {
  chain <- quiet_dynet(data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"),
    time = c(1, 3, 6)
  ))
  value <- closeness_values(chain, start = 0, end = 6)
  expect_equal(unname(value[c("A", "B", "C", "D")]),
               c(3 / 10, 2 / 9, 1 / 6, 0))
})

test_that("partial reach, isolates, and singletons have literal values", {
  fork <- quiet_dynet(data.frame(
    from = c("S", "S", "A", "X"), to = c("A", "B", "T", "Y"),
    time = c(1, 3, 4, 10)
  ))
  value <- closeness_values(fork, start = 0, end = 4)
  expect_equal(unname(value[c("S", "A", "B", "T", "X", "Y")]),
               c(3 / 8, 1 / 4, 0, 0, 0, 0))

  singleton <- quiet_dynet(
    data.frame(from = "Q", to = "Q", time = 0), loops = TRUE
  )
  expect_identical(unname(closeness_values(
    singleton, start = 0, end = 0
  )), 0)
})

test_that("closeness accepts closed path bounds", {
  dn <- quiet_dynet(data.frame(
    from = c("S", "A", "S"), to = c("A", "B", "C"),
    time = c(1, 4, 7)
  ))
  early <- closeness_values(dn, start = 0, end = 5)
  late <- closeness_values(dn, start = 2, end = 5)
  full <- closeness_values(dn, start = 0, end = 7)
  expect_equal(unname(early[c("S", "A", "B", "C")]),
               c(2 / 5, 1 / 4, 0, 0))
  expect_equal(unname(late[c("S", "A", "B", "C")]),
               c(0, 1 / 2, 0, 0))
  expect_equal(unname(full[c("S", "A", "B", "C")]),
               c(1 / 4, 1 / 4, 0, 0))
})

test_that("positive traversal duration changes latency without ad hoc offsets", {
  dn <- quiet_dynet(data.frame(
    from = c("S", "A"), to = c("A", "B"), time = c(1, 3)
  ))
  zero <- closeness_values(dn, start = 0, end = 4, traversal_time = 0)
  delayed <- closeness_values(dn, start = 0, end = 4, traversal_time = 1)
  expect_equal(unname(zero[c("S", "A", "B")]), c(1 / 2, 1 / 3, 0))
  expect_equal(unname(delayed[c("S", "A", "B")]), c(1 / 3, 1 / 4, 0))
  expect_true(all(delayed[is.finite(delayed)] <= 1))
})

test_that("closeness inherits collapse, bounded, and separate session walls", {
  spells <- data.frame(
    from = c("S", "A"), to = c("A", "T"), time = c(1, 2),
    session = c("s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  collapsed <- closeness_values(
    dn, sessions = "collapse", start = 0, end = 2
  )
  bounded <- closeness_values(
    dn, sessions = "bounded", start = 0, end = 2
  )
  separate <- as.data.frame(dyn_centrality(
    dn, measure = "closeness", scope = "temporal",
    sessions = "separate", start = 0, end = 2
  ))
  expect_equal(unname(collapsed[c("S", "A", "T")]), c(2 / 3, 1 / 2, 0))
  expect_equal(unname(bounded[c("S", "A", "T")]), c(1, 1 / 2, 0))
  s1 <- separate[separate$session == "s1", ]
  s2 <- separate[separate$session == "s2", ]
  expect_equal(stats::setNames(s1$value, s1$node)[c("S", "A", "T")],
               c(S = 1, A = 0, T = 0))
  expect_equal(stats::setNames(s2$value, s2$node)[c("S", "A", "T")],
               c(S = 0, A = 1 / 2, T = 0))
})

test_that("tied paths and sessions count endpoints once", {
  tied <- data.frame(
    from = c("S", "A", "S", "B"), to = c("A", "T", "B", "T"),
    time = c(1, 4, 2, 4), session = c("s1", "s1", "s2", "s2")
  )
  dn <- quiet_dynet(tied, session = "session")
  bounded <- closeness_values(
    dn, sessions = "bounded", start = 0, end = 4
  )
  expect_equal(unname(bounded[["S"]]), 3 / 7)

  diamond <- quiet_dynet(data.frame(
    from = c("S", "S", "A", "B"), to = c("A", "B", "T", "T"),
    time = c(1, 1, 2, 2)
  ))
  paths <- dyn_paths(diamond, from = "S", start = 0, end = 2)
  expect_equal(paths$n_paths[paths$node == "T"], 2)
  expect_equal(unname(closeness_values(
    diamond, start = 0, end = 2
  )[["S"]]), 3 / 4)
})

test_that("later-prefix optimality does not weight latency closeness", {
  dn <- quiet_dynet(data.frame(
    from = c("S", "A", "S", "X"), to = c("A", "X", "X", "T"),
    time = c(1, 1, 2, 5)
  ))
  value <- closeness_values(dn, start = 0, end = 5)
  expect_equal(unname(value[c("S", "A", "X", "T")]),
               c(3 / 7, 1 / 3, 1 / 5, 0))
})

test_that("closeness translates and rescales with inverse-time units", {
  spells <- data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"), time = c(1, 3, 6)
  )
  base <- closeness_values(quiet_dynet(spells), start = 0, end = 6)
  shifted <- transform(spells, time = time + 17)
  translated <- closeness_values(
    quiet_dynet(shifted), start = 17, end = 23
  )
  scaled <- transform(spells, time = time * 3)
  stretched <- closeness_values(
    quiet_dynet(scaled), start = 0, end = 18
  )
  expect_equal(translated, base)
  expect_equal(stretched, base / 3)
})

test_that("temporal closeness publishes its mathematical metadata", {
  result <- dyn_centrality(
    quiet_dynet(data.frame(from = "A", to = "B", time = 1)),
    measure = "closeness", scope = "temporal", start = 0, end = 1
  )
  expect_identical(attr(result, "criterion"), "foremost_then_shortest")
  expect_identical(attr(result, "distance"), "forward_latency")
  expect_identical(attr(result, "normalization"),
                   "reachable_inverse_mean")

  mixed <- dyn_centrality(
    quiet_dynet(data.frame(from = "A", to = "B", time = 1)),
    measure = c("closeness", "reach"), scope = "temporal"
  )
  expect_null(attr(mixed, "distance"))
  expect_identical(
    attr(mixed, "measure_metadata")$closeness$distance,
    "forward_latency"
  )
})
