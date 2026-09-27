.backward_times <- function(paths, vertices) {
  result <- as.data.frame(paths)
  result$arrival_time[match(vertices, result$node)]
}

.backward_latency <- function(paths, vertices) {
  result <- as.data.frame(paths)
  result$latency[match(vertices, result$node)]
}

.backward_reach_value <- function(result, vertex) {
  row <- subset(as.data.frame(result),
                node == vertex & measure == "backward_reach")
  row$value
}

test_that("explicit backward anchors use the original calendar", {
  spell <- data.frame(
    from = "A", to = "B", start = 2, end = 8,
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spell)
  anchors <- c(1, 2, 6, 8, 10)
  expected_a <- c(NA, 2, 6, 8, 8)
  expected_latency <- c(NA, 0, 0, 0, 2)

  invisible(Map(function(anchor, latest, latency) {
    paths <- paths(dn, from = "B", at = anchor,
                       direction = "backward")
    expect_equal(.backward_times(paths, c("A", "B")), c(latest, anchor))
    expect_equal(.backward_latency(paths, c("A", "B")), c(latency, 0))
    expect_equal(attr(paths, "origin"), anchor)
  }, anchors, expected_a, expected_latency))
})

test_that("backward boundary state prevents false point-event propagation", {
  false_chain <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 0), end = c(1, 1), stringsAsFactors = FALSE
  )
  valid_chain <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 0), end = c(1, 0), stringsAsFactors = FALSE
  )

  false_paths <- paths(
    quiet_dynet(false_chain), from = "C", at = 1, direction = "backward"
  )
  valid_paths <- paths(
    quiet_dynet(valid_chain), from = "C", at = 0, direction = "backward"
  )

  expect_equal(.backward_times(false_paths, c("A", "B", "C")),
               c(NA, 1, 1))
  expect_identical(
    as.data.frame(false_paths)$attained[match(
      c("A", "B", "C"), as.data.frame(false_paths)$node
    )],
    c(FALSE, FALSE, TRUE)
  )
  expect_equal(.backward_times(valid_paths, c("A", "B", "C")),
               c(0, 0, 0))
  expect_true(all(as.data.frame(valid_paths)$attained))
})

test_that("backward chronological chains return latest-departure suprema", {
  chain <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 3), end = c(4, 6), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(chain)
  at_five <- paths(dn, from = "C", at = 5, direction = "backward")
  at_three <- paths(dn, from = "C", at = 3, direction = "backward")

  expect_equal(.backward_times(at_five, c("A", "B", "C")), c(4, 5, 5))
  expect_equal(.backward_latency(at_five, c("A", "B", "C")), c(1, 0, 0))
  expect_equal(.backward_times(at_three, c("A", "B", "C")), c(3, 3, 3))
})

test_that("backward traversal does not flatten impossible chronology", {
  impossible <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(5, 1), end = c(6, 2), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(impossible)
  paths <- paths(dn, from = "C", at = 6, direction = "backward")

  expect_equal(.backward_times(paths, c("A", "B", "C")), c(NA, 2, 6))
})

test_that("the direct backward kernel retains attainment state", {
  false_chain <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 0), end = c(1, 1), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(false_chain)
  enc <- .encode(dn)
  target <- match("C", enc$names)
  result <- .temporal_bfs_backward(enc, target, deadline = 1)

  expect_equal(result$arrival, c(-Inf, 1, 1))
  expect_identical(result$attained, c(FALSE, FALSE, TRUE))
})

test_that("interval and event optima expose distinct attainment states", {
  interval <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 1
  ))
  event <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 1, end = 1
  ))
  interval_paths <- as.data.frame(paths(
    interval, from = "B", at = 1, direction = "backward"
  ))
  event_paths <- as.data.frame(paths(
    event, from = "B", at = 1, direction = "backward"
  ))

  expect_equal(interval_paths$arrival_time, event_paths$arrival_time)
  expect_identical(interval_paths$attained, c(FALSE, TRUE))
  expect_identical(event_paths$attained, c(TRUE, TRUE))
})

test_that("bounded session ties prefer an attained latest departure", {
  spells <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 1), end = c(1, 1), session = c("interval", "event")
  )
  paths <- as.data.frame(paths(
    quiet_dynet(spells, session = "session"),
    from = "B", at = 1, direction = "backward", sessions = "bounded"
  ))

  expect_equal(paths$arrival_time, c(1, 1))
  expect_identical(paths$attained, c(TRUE, TRUE))
})

test_that("backward reach uses the explicit anchor as a deadline", {
  chain <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 3), end = c(4, 6), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(chain)
  backward <- reachability(dn, direction = "backward", at = 5,
                               sessions = "collapse")
  both <- reachability(dn, direction = "both", at = 5,
                           sessions = "collapse")
  forward <- reachability(dn, direction = "forward", at = 5,
                              sessions = "collapse")

  expect_equal(vapply(c("A", "B", "C"), function(vertex) {
    .backward_reach_value(backward, vertex)
  }, numeric(1L)), c(A = 0, B = 0.5, C = 1))
  expect_equal(subset(as.data.frame(both), measure == "backward_reach")$value,
               as.data.frame(backward)$value)
  expect_equal(subset(as.data.frame(both), measure == "forward_reach")$value,
               as.data.frame(forward)$value)
})

test_that("backward session walls respect the explicit deadline", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 3), end = c(4, 6), session = c("s1", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  bounded <- paths(dn, from = "C", at = 5, direction = "backward",
                       sessions = "bounded")
  collapsed <- paths(dn, from = "C", at = 5, direction = "backward",
                         sessions = "collapse")

  expect_equal(.backward_times(bounded, c("A", "B", "C")), c(NA, 5, 5))
  expect_equal(.backward_times(collapsed, c("A", "B", "C")), c(4, 5, 5))
})

test_that("undirected backward paths ignore stored endpoint orientation", {
  first <- data.frame(
    from = c("B", "C"), to = c("A", "B"),
    start = c(2, 4), end = c(8, 9), stringsAsFactors = FALSE
  )
  second <- transform(first, from = first$to, to = first$from)
  left <- quiet_dynet(first, directed = FALSE)
  right <- quiet_dynet(second, directed = FALSE)

  left_paths <- paths(left, from = "C", at = 7, direction = "backward")
  right_paths <- paths(right, from = "C", at = 7, direction = "backward")
  expect_equal(.backward_times(left_paths, c("A", "B", "C")), c(7, 7, 7))
  expect_equal(.backward_times(left_paths, c("A", "B", "C")),
               .backward_times(right_paths, c("A", "B", "C")))

  late <- paths(left, from = "C", at = 10, direction = "backward")
  expect_equal(.backward_times(late, c("A", "B", "C")), c(8, 9, 10))
})

test_that("backward times translate and scale with their anchor", {
  base <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 3), end = c(4, 6), stringsAsFactors = FALSE
  )
  translated <- transform(base, start = start + 10, end = end + 10)
  scaled <- transform(base, start = start * 2, end = end * 2)

  original <- paths(quiet_dynet(base), from = "C", at = 5,
                        direction = "backward")
  shifted <- paths(quiet_dynet(translated), from = "C", at = 15,
                       direction = "backward")
  stretched <- paths(quiet_dynet(scaled), from = "C", at = 10,
                         direction = "backward")

  expect_equal(.backward_times(shifted, c("A", "B", "C")),
               .backward_times(original, c("A", "B", "C")) + 10)
  expect_equal(.backward_latency(shifted, c("A", "B", "C")),
               .backward_latency(original, c("A", "B", "C")))
  expect_equal(.backward_times(stretched, c("A", "B", "C")),
               .backward_times(original, c("A", "B", "C")) * 2)
  expect_equal(.backward_latency(stretched, c("A", "B", "C")),
               .backward_latency(original, c("A", "B", "C")) * 2)
})

test_that("date anchors are converted before backward traversal", {
  spell <- data.frame(
    from = "A", to = "B",
    start = as.Date("2024-01-02"), end = as.Date("2024-01-08"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spell, time_unit = "days")
  paths <- paths(dn, from = "B", at = as.Date("2024-01-06"),
                     direction = "backward")

  expect_equal(.backward_times(paths, c("A", "B")), c(4, 4))
  expect_equal(attr(paths, "origin"), 4)
})

test_that("default backward anchors still use the observed end", {
  spell <- data.frame(
    from = "A", to = "B", start = 2, end = 8,
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spell)

  expect_equal(as.data.frame(paths(dn, from = "B", direction = "backward")),
               as.data.frame(paths(dn, from = "B", at = 8,
                                       direction = "backward")))
})

