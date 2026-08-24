.bounded_forward_oracle <- function(spells, vertices, source, start, end,
                                    directed = TRUE) {
  if (!directed) {
    reversed <- transform(spells, from = spells$to, to = spells$from)
    spells <- rbind(spells, reversed)
  }
  enumerate <- function(vertex, time, visited) {
    arrival <- stats::setNames(rep(Inf, length(vertices)), vertices)
    arrival[[vertex]] <- time
    candidates <- subset(spells, from == vertex & !to %in% visited)
    if (nrow(candidates) == 0L) return(arrival)
    instant <- candidates$start == candidates$end
    next_time <- ifelse(instant, candidates$start,
                        pmax(time, candidates$start))
    usable <- ((instant & time <= candidates$start) |
      (!instant & next_time < candidates$end)) & next_time <= end
    candidates <- candidates[usable, , drop = FALSE]
    next_time <- next_time[usable]
    if (nrow(candidates) == 0L) return(arrival)
    branches <- Map(function(target, candidate) {
      enumerate(target, candidate, c(visited, target))
    }, candidates$to, next_time)
    Reduce(pmin, c(list(arrival), branches))
  }
  enumerate(source, start, source)
}

.bounded_backward_oracle <- function(spells, vertices, target, start, end,
                                     directed = TRUE) {
  if (!directed) {
    reversed <- transform(spells, from = spells$to, to = spells$from)
    spells <- rbind(spells, reversed)
  }
  enumerate <- function(vertex, bound, bound_attained, visited) {
    latest <- stats::setNames(rep(-Inf, length(vertices)), vertices)
    attained <- stats::setNames(rep(FALSE, length(vertices)), vertices)
    latest[[vertex]] <- bound
    attained[[vertex]] <- bound_attained
    candidates <- subset(spells, to == vertex & !from %in% visited)
    if (nrow(candidates) == 0L) {
      return(list(latest = latest, attained = attained))
    }
    feasible <- bound > candidates$start |
      (bound == candidates$start & bound_attained)
    candidates <- candidates[feasible, , drop = FALSE]
    if (nrow(candidates) == 0L) {
      return(list(latest = latest, attained = attained))
    }
    instant <- candidates$start == candidates$end
    next_bound <- ifelse(instant, candidates$start,
                         pmin(bound, candidates$end))
    next_attained <- ifelse(instant, TRUE,
                            bound < candidates$end & bound_attained)
    inside <- next_bound > start |
      (next_bound == start & next_attained)
    candidates <- candidates[inside, , drop = FALSE]
    next_bound <- next_bound[inside]
    next_attained <- next_attained[inside]
    if (nrow(candidates) == 0L) {
      return(list(latest = latest, attained = attained))
    }
    branches <- Map(function(predecessor, candidate, candidate_attained) {
      enumerate(predecessor, candidate, candidate_attained,
                c(visited, predecessor))
    }, candidates$from, next_bound, next_attained)
    states <- c(list(list(latest = latest, attained = attained)), branches)
    best <- Reduce(pmax, lapply(states, `[[`, "latest"))
    best_attained <- vapply(vertices, function(name) {
      any(vapply(states, function(state) {
        state$latest[[name]] == best[[name]] && state$attained[[name]]
      }, logical(1L)))
    }, logical(1L))
    list(latest = best, attained = best_attained)
  }
  enumerate(target, end, TRUE, target)
}

.bound_times <- function(paths, vertices) {
  result <- as.data.frame(paths)
  result$arrival_time[match(vertices, result$node)]
}

test_that("path windows resolve canonical bounds and compatibility aliases", {
  dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 2, end = 8
  ))

  expect_identical(.path_window(dn, "forward", at = 3),
                   list(start = 3, end = Inf))
  expect_identical(.path_window(dn, "backward", at = 7),
                   list(start = -Inf, end = 7))
  expect_identical(.path_window(dn, "forward", start = 3, end = 7),
                   list(start = 3, end = 7))
  expect_error(.path_window(dn, "forward", at = 3, end = 7),
               class = "dynet_bad_input")
  expect_error(.path_window(dn, "backward", start = 8, end = 7),
               class = "dynet_bad_input")
  expect_error(.path_window(dn, "forward", end = 1),
               class = "dynet_bad_input")
  expect_identical(.path_window(
    dn, "forward", end = 1, clamp_missing = TRUE
  ), list(start = 1, end = 1))
  expect_error(.path_window(dn, "backward", start = 9),
               class = "dynet_bad_input")
  expect_identical(.path_window(
    dn, "backward", start = 9, clamp_missing = TRUE
  ), list(start = 9, end = 9))
  expect_error(.path_window(dn, "sideways"), class = "simpleError")
})

test_that("canonical anchors preserve at and both-direction behavior", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 3), end = c(4, 6)
  )
  dn <- quiet_dynet(spells)
  expect_equal(
    as.data.frame(dyn_paths(dn, "A", at = 1)),
    as.data.frame(dyn_paths(dn, "A", start = 1))
  )
  expect_equal(
    as.data.frame(dyn_paths(dn, "C", at = 5, direction = "backward")),
    as.data.frame(dyn_paths(dn, "C", end = 5, direction = "backward"))
  )

  both <- as.data.frame(dyn_reachability(
    dn, direction = "both", start = 1, end = 5, sessions = "collapse"
  ))
  forward <- as.data.frame(dyn_reachability(
    dn, direction = "forward", start = 1, end = 5, sessions = "collapse"
  ))
  backward <- as.data.frame(dyn_reachability(
    dn, direction = "backward", start = 1, end = 5,
    sessions = "collapse"
  ))
  expect_equal(subset(both, measure == "forward_reach")$value,
               forward$value)
  expect_equal(subset(both, measure == "backward_reach")$value,
               backward$value)
})

test_that("the closed upper horizon preserves spell boundary semantics", {
  spells <- data.frame(
    from = c("Z", "A", "A", "A", "A", "A"),
    to = c("A", "B", "C", "D", "E", "F"),
    start = c(5, 5, 5, 0, 0, 6), end = c(5, 5, 7, 7, 5, 6)
  )
  dn <- quiet_dynet(spells)
  paths <- dyn_paths(dn, from = "Z", start = 0, end = 5,
                     sessions = "collapse")

  expect_equal(.bound_times(paths, c("Z", "A", "B", "C", "D", "E", "F")),
               c(0, 5, 5, 5, 5, NA, NA))
  enc <- .encode(dn)
  direct <- .temporal_bfs(enc, match("Z", enc$names), 0, upper = 5)
  expect_equal(direct$arrival[match(c("Z", "A", "B", "C", "D", "E", "F"),
                                    enc$names)],
               c(0, 5, 5, 5, 5, Inf, Inf))
  bounded <- .bfs_bounded(dn, enc, match("Z", enc$names), 0,
                          bounded = FALSE, upper = 5)
  expect_equal(bounded$arrival, direct$arrival)
})

test_that("a degenerate path window computes equal-time closure", {
  chain <- data.frame(
    from = c("A", "B"), to = c("B", "C"), start = 1, end = 1
  )
  results <- lapply(list(chain, chain[2:1, , drop = FALSE]), function(spells) {
    dyn_paths(quiet_dynet(spells), from = "A", start = 1, end = 1)
  })

  invisible(lapply(results, function(paths) {
    expect_equal(.bound_times(paths, c("A", "B", "C")), c(1, 1, 1))
  }))
})

test_that("the backward lower bound uses attainment, not only its number", {
  spells <- data.frame(
    from = c("A", "B", "C", "D", "E", "F"), to = "T",
    start = c(1, 2, 3, 0, 2, 0), end = c(1, 2, 3, 2, 4, 4)
  )
  dn <- quiet_dynet(spells)
  paths <- as.data.frame(dyn_paths(
    dn, from = "T", direction = "backward", start = 2, end = 5
  ))
  vertices <- c("T", "A", "B", "C", "D", "E", "F")
  rows <- match(vertices, paths$node)

  expect_equal(paths$arrival_time[rows], c(5, NA, 2, 3, NA, 4, 4))
  expect_identical(paths$attained[rows],
                   c(TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(paths$latency[rows], c(0, NA, 3, 2, NA, 1, 1))
  enc <- .encode(dn)
  target <- match("T", enc$names)
  direct <- .temporal_bfs_backward(enc, target, 5, lower = 2)
  bounded <- .bfs_backward_bounded(
    dn, enc, target, 5, bounded = FALSE, lower = 2
  )
  expect_equal(bounded$arrival, direct$arrival)
  expect_identical(bounded$attained, direct$attained)
})

test_that("an unattained lower-bound chain is excluded at every hop", {
  interval_chain <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 2), end = c(2, 4)
  )
  event_chain <- transform(interval_chain, start = c(2, 2), end = c(2, 4))
  interval <- as.data.frame(dyn_paths(
    quiet_dynet(interval_chain), from = "C", direction = "backward",
    start = 2, end = 5
  ))
  event <- as.data.frame(dyn_paths(
    quiet_dynet(event_chain), from = "C", direction = "backward",
    start = 2, end = 5
  ))

  expect_equal(interval$arrival_time[match(c("A", "B", "C"), interval$node)],
               c(NA, 4, 5))
  expect_equal(event$arrival_time[match(c("A", "B", "C"), event$node)],
               c(2, 4, 5))
  expect_true(event$attained[event$node == "A"])
})

test_that("path bounds are applied inside bounded session searches", {
  spells <- data.frame(
    from = c("A", "B", "A"), to = c("B", "C", "D"),
    start = c(2, 4, 6), end = c(2, 4, 6),
    session = c("s1", "s2", "s1")
  )
  dn <- quiet_dynet(spells, session = "session")
  bounded <- dyn_paths(dn, from = "A", start = 2, end = 5,
                       sessions = "bounded")
  collapsed <- dyn_paths(dn, from = "A", start = 2, end = 5,
                         sessions = "collapse")

  expect_equal(.bound_times(bounded, c("A", "B", "C", "D")),
               c(2, 2, NA, NA))
  expect_equal(.bound_times(collapsed, c("A", "B", "C", "D")),
               c(2, 2, 4, NA))
})

test_that("backward lower bounds apply inside each bounded session", {
  spells <- data.frame(
    from = c("A", "D"), to = c("B", "B"),
    start = c(0, 2), end = c(2, 2), session = c("s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- as.data.frame(dyn_paths(
    dn, from = "B", direction = "backward", start = 2, end = 5,
    sessions = "bounded"
  ))

  expect_equal(paths$arrival_time[match(c("A", "B", "D"), paths$node)],
               c(NA, 5, 2))
  enc <- .encode(dn)
  result <- .bfs_backward_bounded(
    dn, enc, match("B", enc$names), 5, bounded = TRUE, lower = 2
  )
  expect_equal(result$arrival[match(c("A", "B", "D"), enc$names)],
               c(-Inf, 5, 2))
})

test_that("bounded paths, reachability, and temporal reach agree", {
  spells <- data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"),
    start = c(2, 5, 6), end = c(2, 5, 6)
  )
  dn <- quiet_dynet(spells)
  reach <- as.data.frame(dyn_reachability(
    dn, direction = "forward", start = 0, end = 5,
    sessions = "collapse"
  ))
  centrality <- as.data.frame(dyn_centrality(
    dn, measure = "reach", scope = "temporal",
    start = 0, end = 5, sessions = "collapse"
  ))
  path_share <- vapply(c("A", "B", "C", "D"), function(source) {
    paths <- as.data.frame(dyn_paths(
      dn, from = source, start = 0, end = 5, sessions = "collapse"
    ))
    (sum(paths$reachable) - 1) / 3
  }, numeric(1L))

  expected <- c(A = 2 / 3, B = 1 / 3, C = 0, D = 0)
  expect_equal(stats::setNames(reach$value, reach$node), expected)
  expect_equal(stats::setNames(centrality$value, centrality$node), expected)
  expect_equal(stats::setNames(path_share, c("A", "B", "C", "D")),
               expected)
  expect_error(dyn_centrality(
    dn, measure = "closeness", scope = "temporal", start = 0, end = 5
  ), class = "dynet_bad_input")
  expect_error(dyn_centrality(
    dn, measure = c("reach", "betweenness"), scope = "temporal",
    start = 0, end = 5
  ), class = "dynet_bad_input")
})

test_that("backward reachability respects the common lower horizon", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 2), end = c(2, 4)
  )
  result <- as.data.frame(dyn_reachability(
    quiet_dynet(spells), direction = "backward", start = 2, end = 5,
    sessions = "collapse"
  ))

  expect_equal(stats::setNames(result$value, result$node),
               c(A = 0, B = 0, C = 0.5))
})

test_that("date path bounds equal their internal numeric offsets", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = as.Date(c("2024-01-02", "2024-01-04")),
    end = as.Date(c("2024-01-02", "2024-01-04"))
  )
  dn <- quiet_dynet(spells, time_unit = "days")
  dated <- dyn_paths(
    dn, from = "A", start = as.Date("2024-01-01"),
    end = as.Date("2024-01-02")
  )
  numeric <- dyn_paths(dn, from = "A", start = -1, end = 0)

  expect_equal(as.data.frame(dated), as.data.frame(numeric))
  expect_equal(.bound_times(dated, c("A", "B", "C")), c(-1, 0, NA))

  backward_dated <- dyn_paths(
    dn, from = "B", direction = "backward",
    start = as.Date("2024-01-01"), end = as.Date("2024-01-02")
  )
  backward_numeric <- dyn_paths(
    dn, from = "B", direction = "backward", start = -1, end = 0
  )
  expect_equal(as.data.frame(backward_dated),
               as.data.frame(backward_numeric))

  reach_dated <- dyn_reachability(
    dn, direction = "both", start = as.Date("2024-01-01"),
    end = as.Date("2024-01-02"), sessions = "collapse"
  )
  reach_numeric <- dyn_reachability(
    dn, direction = "both", start = -1, end = 0,
    sessions = "collapse"
  )
  expect_equal(as.data.frame(reach_dated), as.data.frame(reach_numeric))

  centrality_dated <- dyn_centrality(
    dn, measure = "reach", scope = "temporal",
    start = as.Date("2024-01-01"), end = as.Date("2024-01-02"),
    sessions = "collapse"
  )
  centrality_numeric <- dyn_centrality(
    dn, measure = "reach", scope = "temporal",
    start = -1, end = 0, sessions = "collapse"
  )
  expect_equal(as.data.frame(centrality_dated),
               as.data.frame(centrality_numeric))
  expect_error(dyn_paths(
    dn, from = "A", start = as.Date("2024-01-04"),
    end = as.Date("2024-01-02")
  ), class = "dynet_bad_input")
})

test_that("one-sided windows retain zero rows for non-overlapping sessions", {
  spells <- data.frame(
    from = c("A", "C"), to = c("B", "D"),
    start = c(2, 10), end = c(2, 10), session = c("early", "late")
  )
  dn <- quiet_dynet(spells, session = "session")
  forward <- as.data.frame(dyn_reachability(
    dn, direction = "forward", end = 5, sessions = "separate"
  ))
  backward <- as.data.frame(dyn_reachability(
    dn, direction = "backward", start = 5, sessions = "separate"
  ))
  centrality <- as.data.frame(dyn_centrality(
    dn, measure = "reach", scope = "temporal",
    end = 5, sessions = "separate"
  ))

  expect_true(all(subset(forward, session == "late")$value == 0))
  expect_true(all(subset(backward, session == "early")$value == 0))
  expect_true(all(subset(centrality, session == "late")$value == 0))
  expect_equal(subset(forward, session == "early" & node == "A")$value,
               1 / 3)
  expect_equal(subset(centrality, session == "early" & node == "A")$value,
               1 / 3)
})

test_that("invalid and conflicting path bounds are classed errors", {
  numeric <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 1
  ))

  expect_error(dyn_paths(numeric, "A", start = 2, end = 1),
               class = "dynet_bad_input")
  expect_error(dyn_paths(numeric, "A", end = -1),
               class = "dynet_bad_input")
  expect_error(dyn_paths(
    numeric, "B", direction = "backward", start = 2
  ), class = "dynet_bad_input")
  expect_error(dyn_paths(numeric, "A", at = 0, end = 1),
               class = "dynet_bad_input")
  expect_error(dyn_reachability(numeric, at = 0, start = 0),
               class = "dynet_bad_input")
  expect_error(dyn_paths(numeric, "A", start = c(0, 1)),
               class = "dynet_bad_input")
  expect_error(dyn_paths(numeric, "A", end = Inf),
               class = "dynet_bad_input")
  expect_error(dyn_paths(numeric, "A", start = as.Date("2024-01-01")),
               class = "dynet_bad_input")
})

test_that("bounded path results translate and scale with their window", {
  base <- data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"),
    start = c(2, 5, 7), end = c(4, 5, 9)
  )
  shifted <- transform(base, start = start + 10, end = end + 10)
  scaled <- transform(base, start = start * 2, end = end * 2)
  original <- as.data.frame(dyn_paths(
    quiet_dynet(base), "A", start = 1, end = 5
  ))
  translated <- as.data.frame(dyn_paths(
    quiet_dynet(shifted), "A", start = 11, end = 15
  ))
  stretched <- as.data.frame(dyn_paths(
    quiet_dynet(scaled), "A", start = 2, end = 10
  ))

  expect_equal(translated$arrival_time, original$arrival_time + 10)
  expect_equal(translated$latency, original$latency)
  expect_equal(stretched$arrival_time, original$arrival_time * 2)
  expect_equal(stretched$latency, original$latency * 2)
  expect_identical(translated$reachable, original$reachable)
  expect_identical(stretched$n_hops, original$n_hops)
})

test_that("bounded kernels agree with independent exhaustive journeys", {
  fixtures <- list(
    mixed = data.frame(
      from = c("A", "B", "A", "C"), to = c("B", "C", "C", "D"),
      start = c(0, 3, 4, 5), end = c(2, 3, 7, 8)
    ),
    boundary = data.frame(
      from = c("A", "B", "C", "A"), to = c("B", "C", "D", "C"),
      start = c(1, 0, 1, 0), end = c(1, 1, 1, 4)
    )
  )
  windows <- list(c(0, 0), c(0, 1), c(1, 5), c(3, 9))

  invisible(lapply(fixtures, function(spells) {
    vertices <- sort(unique(c(spells$from, spells$to)))
    invisible(lapply(c(TRUE, FALSE), function(directed) {
      dn <- quiet_dynet(spells, directed = directed)
      enc <- .encode(dn)
      if (!directed) enc <- .undirect_or_reverse(enc, FALSE, "forward")
      invisible(lapply(windows, function(window) {
        invisible(lapply(vertices, function(vertex) {
          forward <- .temporal_bfs(
            enc, match(vertex, enc$names), window[1L], upper = window[2L]
          )
          forward_oracle <- .bounded_forward_oracle(
            spells, vertices, vertex, window[1L], window[2L], directed
          )
          expect_equal(forward$arrival, unname(forward_oracle))

          backward <- .temporal_bfs_backward(
            enc, match(vertex, enc$names), window[2L], lower = window[1L]
          )
          backward_oracle <- .bounded_backward_oracle(
            spells, vertices, vertex, window[1L], window[2L], directed
          )
          expect_equal(backward$arrival,
                       unname(backward_oracle$latest))
          expect_identical(backward$attained,
                           unname(backward_oracle$attained))
        }))
      }))
    }))
  }))
})

test_that("interior bounded paths calibrate against tsna", {
  skip_if_not_installed("network")
  skip_if_not_installed("networkDynamic")
  skip_if_not_installed("tsna")

  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 3), end = c(4, 6)
  )
  vertices <- c("A", "B", "C")
  dn <- quiet_dynet(spells)
  base <- network::network.initialize(3L, directed = TRUE)
  network::set.vertex.attribute(base, "vertex.names", vertices)
  dynamic <- networkDynamic::networkDynamic(
    base,
    edge.spells = data.frame(
      onset = spells$start, terminus = spells$end,
      tail = match(spells$from, vertices), head = match(spells$to, vertices)
    ),
    start = 0, end = 7, verbose = FALSE
  )
  forward <- .bound_times(dyn_paths(
    dn, "A", start = 0, end = 5
  ), vertices)
  forward_tsna <- tsna::tPath(
    dynamic, v = 1L, direction = "fwd", type = "earliest.arrive",
    start = 0, end = 5.5
  )$tdist
  backward <- .bound_times(dyn_paths(
    dn, "C", direction = "backward", start = 0, end = 5
  ), vertices)
  backward_tsna <- tsna::tPath(
    dynamic, v = 3L, direction = "bkwd", type = "latest.depart",
    start = -0.5, end = 5
  )$tdist

  expect_equal(forward, as.numeric(forward_tsna))
  expect_equal(backward, as.numeric(5 - backward_tsna))
})
