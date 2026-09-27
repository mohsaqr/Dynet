.path_arrivals <- function(paths, vertices) {
  result <- as.data.frame(paths)
  result$arrival_time[match(vertices, result$node)]
}

.reach_value <- function(result, vertex, measure_name = "forward_reach") {
  row <- subset(as.data.frame(result),
                node == vertex & measure == measure_name)
  row$value
}

test_that("arrival at an interval terminus cannot board it", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(5, 0), end = c(5, 5),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)
  paths <- paths(dn, from = "A", at = 0, sessions = "collapse")

  expect_equal(.path_arrivals(paths, c("A", "B", "C")), c(0, 5, NA))
  reach <- reachability(dn, direction = "forward", at = 0,
                            sessions = "collapse")
  expect_equal(.reach_value(reach, "A"), 0.5)
  centrality <- legacy_centrality(dn, measure = "reach", scope = "temporal",
                                  sessions = "collapse")
  expect_equal(.reach_value(centrality, "A", measure_name = "reach"), 0.5)

  enc <- .encode(dn)
  source <- match("A", enc$names)
  expect_equal(.temporal_bfs(enc, source, 0)$arrival, c(0, 5, Inf))
})

test_that("P01 does not change the current backward boundary convention", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 0), end = c(1, 0),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)
  paths <- paths(dn, from = "C", direction = "backward")

  expect_true(all(as.data.frame(paths)$reachable))
  expect_equal(.path_arrivals(paths, c("A", "B", "C")), c(0, 0, 1))
})

test_that("interval onset is included and waiting is allowed", {
  spell <- data.frame(
    from = "A", to = "B", start = 5, end = 10,
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spell)

  expect_equal(.path_arrivals(paths(dn, from = "A", at = 0), c("A", "B")),
               c(0, 5))
  expect_equal(.path_arrivals(paths(dn, from = "A", at = 5), c("A", "B")),
               c(5, 5))
  expect_equal(.path_arrivals(paths(dn, from = "A", at = 10), c("A", "B")),
               c(10, NA))
})

test_that("a long-open interval can be boarded after its onset", {
  spells <- data.frame(
    from = c("A", "Z"), to = c("B", "A"),
    start = c(0, 50), end = c(100, 51),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)
  paths <- paths(dn, from = "Z", at = 50)

  expect_equal(.path_arrivals(paths, c("Z", "A", "B")), c(50, 50, 50))
  expect_equal(as.data.frame(paths)$n_hops[
    match(c("Z", "A", "B"), as.data.frame(paths)$node)
  ], c(0L, 1L, 2L))
})

test_that("point events are traversable at their timestamp only", {
  event <- data.frame(
    from = "A", to = "B", start = 5, end = 5,
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(event)

  expect_equal(.path_arrivals(paths(dn, from = "A", at = 0), c("A", "B")),
               c(0, 5))
  expect_equal(.path_arrivals(paths(dn, from = "A", at = 5), c("A", "B")),
               c(5, 5))
  expect_equal(.path_arrivals(
    paths(dn, from = "A", at = 5 + 1e-6), c("A", "B")
  ), c(5 + 1e-6, NA))
})

test_that("simultaneous point events compose independently of row order", {
  chain <- data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"),
    start = 5, end = 5, stringsAsFactors = FALSE
  )
  permutations <- list(
    c(1, 2, 3), c(1, 3, 2), c(2, 1, 3),
    c(2, 3, 1), c(3, 1, 2), c(3, 2, 1)
  )
  results <- lapply(permutations, function(rows) {
    dn <- quiet_dynet(chain[rows, , drop = FALSE])
    as.data.frame(paths(dn, from = "A", at = 0))
  })

  invisible(lapply(results, function(paths) {
    expect_equal(paths$arrival_time[match(c("A", "B", "C", "D"), paths$node)],
                 c(0, 5, 5, 5))
    expect_equal(paths$n_hops[match(c("A", "B", "C", "D"), paths$node)],
                 c(0L, 1L, 2L, 3L))
  }))
})

test_that("a simultaneous cycle terminates without changing the source time", {
  cycle <- data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "A"),
    start = 5, end = 5, stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(cycle)

  expect_no_warning(paths <- paths(dn, from = "A", at = 0))
  expect_equal(.path_arrivals(paths, c("A", "B", "C")), c(0, 5, 5))
  reach <- reachability(dn, direction = "forward", at = 0)
  expect_equal(as.data.frame(reach)$value, rep(1, 3))
})

test_that("parallel, duplicate, and overlapping spells preserve reach", {
  spells <- data.frame(
    from = c("A", "A", "A"), to = c("B", "B", "B"),
    start = c(0, 1, 1), end = c(2, 4, 4),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)

  expect_equal(.path_arrivals(paths(dn, from = "A", at = 3), c("A", "B")),
               c(3, 3))
  expect_equal(.path_arrivals(paths(dn, from = "A", at = 4), c("A", "B")),
               c(4, NA))
  duplicate <- quiet_dynet(rbind(spells, spells))
  expect_equal(.path_arrivals(paths(dn, from = "A", at = 3), c("A", "B")),
               .path_arrivals(paths(duplicate, from = "A", at = 3),
                              c("A", "B")))
})

test_that("bounded sessions are traversal walls", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 2), end = c(3, 4), session = c("s1", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  bounded <- paths(dn, from = "A", at = 0, sessions = "bounded")
  collapsed <- paths(dn, from = "A", at = 0, sessions = "collapse")

  expect_equal(.path_arrivals(bounded, c("A", "B", "C")), c(0, 1, NA))
  expect_equal(.path_arrivals(collapsed, c("A", "B", "C")), c(0, 1, 2))
})

test_that("bounded session searches retain each spell's point-event flag", {
  spells <- data.frame(
    from = c("A", "B", "D"), to = c("B", "C", "E"),
    start = c(1, 1, 1), end = c(1, 2, 1),
    session = c("s1", "s1", "s2"), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- paths(dn, from = "A", at = 0, sessions = "bounded")

  expect_equal(.path_arrivals(paths, c("A", "B", "C", "D", "E")),
               c(0, 1, 1, NA, NA))
})

test_that("undirected traversal does not depend on input orientation", {
  first <- data.frame(
    from = c("B", "C"), to = c("A", "B"),
    start = c(1, 2), end = c(3, 4), stringsAsFactors = FALSE
  )
  second <- transform(first, from = first$to, to = first$from)
  left <- quiet_dynet(first, directed = FALSE)
  right <- quiet_dynet(second, directed = FALSE)

  expect_equal(.path_arrivals(paths(left, from = "A", at = 0),
                              c("A", "B", "C")), c(0, 1, 2))
  expect_equal(.path_arrivals(paths(left, from = "A", at = 0),
                              c("A", "B", "C")),
               .path_arrivals(paths(right, from = "A", at = 0),
                              c("A", "B", "C")))
})

test_that("path time translates and scales consistently", {
  base <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(2, 4), end = c(5, 4), stringsAsFactors = FALSE
  )
  translated <- transform(base, start = start + 10, end = end + 10)
  scaled <- transform(base, start = start * 3, end = end * 3)

  original <- as.data.frame(paths(quiet_dynet(base), from = "A", at = 1))
  shifted <- as.data.frame(
    paths(quiet_dynet(translated), from = "A", at = 11)
  )
  stretched <- as.data.frame(
    paths(quiet_dynet(scaled), from = "A", at = 3)
  )

  expect_equal(shifted$arrival_time, original$arrival_time + 10)
  expect_equal(shifted$latency, original$latency)
  expect_equal(stretched$arrival_time, original$arrival_time * 3)
  expect_equal(stretched$latency, original$latency * 3)
  expect_equal(stretched$n_hops, original$n_hops)
})

