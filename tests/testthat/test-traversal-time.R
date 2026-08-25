traversal_rows <- function(x, nodes) {
  out <- as.data.frame(x)
  out[match(nodes, out$node), , drop = FALSE]
}

traversal_forward_oracle <- function(spells, vertices, source, start, end,
                                     traversal_time) {
  enumerate <- function(vertex, ready, visited) {
    arrival <- stats::setNames(rep(Inf, length(vertices)), vertices)
    arrival[[vertex]] <- ready
    candidates <- subset(spells, from == vertex & !to %in% visited)
    if (nrow(candidates) == 0L) return(arrival)

    instant <- candidates$start == candidates$end
    entry <- pmax(ready, candidates$start)
    completion <- ifelse(
      instant,
      candidates$start + traversal_time,
      entry + traversal_time
    )
    usable <- ((instant & ready <= candidates$start) |
      (!instant & entry < candidates$end &
         completion <= candidates$end)) & completion <= end
    candidates <- candidates[usable, , drop = FALSE]
    completion <- completion[usable]
    if (nrow(candidates) == 0L) return(arrival)

    branches <- Map(function(target, candidate) {
      enumerate(target, candidate, c(visited, target))
    }, candidates$to, completion)
    Reduce(pmin, c(list(arrival), branches))
  }

  enumerate(source, start, source)
}

traversal_backward_oracle <- function(spells, vertices, target, start, end,
                                      traversal_time) {
  enumerate <- function(vertex, bound, bound_attained, visited) {
    latest <- stats::setNames(rep(-Inf, length(vertices)), vertices)
    attained <- stats::setNames(rep(FALSE, length(vertices)), vertices)
    latest[[vertex]] <- bound
    attained[[vertex]] <- bound_attained
    candidates <- subset(spells, to == vertex & !from %in% visited)
    if (nrow(candidates) == 0L) {
      return(list(latest = latest, attained = attained))
    }

    instant <- candidates$start == candidates$end
    edge_bound <- pmin(bound, candidates$end)
    candidate <- edge_bound - traversal_time
    candidate_attained <-
      (traversal_time > 0 | edge_bound < candidates$end) &
      (edge_bound < bound | bound_attained)
    point_completion <- candidates$start + traversal_time
    point_usable <- instant &
      (point_completion < bound |
         (point_completion == bound & bound_attained))
    interval_usable <- !instant &
      (candidate > candidates$start |
         (candidate == candidates$start & candidate_attained))
    candidate[point_usable] <- candidates$start[point_usable]
    candidate_attained[point_usable] <- TRUE
    usable <- (point_usable | interval_usable) &
      (candidate > start | (candidate == start & candidate_attained))
    candidates <- candidates[usable, , drop = FALSE]
    candidate <- candidate[usable]
    candidate_attained <- candidate_attained[usable]
    if (nrow(candidates) == 0L) {
      return(list(latest = latest, attained = attained))
    }

    branches <- Map(function(predecessor, value, is_attained) {
      enumerate(predecessor, value, is_attained,
                c(visited, predecessor))
    }, candidates$from, candidate, candidate_attained)
    states <- c(list(list(latest = latest, attained = attained)), branches)
    best <- Reduce(pmax, lapply(states, `[[`, "latest"))
    best_attained <- vapply(vertices, function(node) {
      any(vapply(states, function(state) {
        state$latest[[node]] == best[[node]] && state$attained[[node]]
      }, logical(1L)))
    }, logical(1L))
    list(latest = best, attained = best_attained)
  }

  enumerate(target, end, TRUE, target)
}

test_that("positive traversal fits exactly inside intervals and query bounds", {
  spells <- data.frame(
    from = "A", to = "B", start = 2, end = 5,
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)
  exact <- dyn_paths(
    dn, from = "A", start = 2, end = 5, traversal_time = 3
  )
  rows <- traversal_rows(exact, c("A", "B"))

  expect_equal(rows$arrival_time, c(2, 5))
  expect_equal(rows$latency, c(0, 3))
  expect_equal(rows$n_hops, c(0L, 1L))
  expect_true(all(rows$attained))
  expect_equal(attr(exact, "traversal_time"), 3)

  too_long <- dyn_paths(
    dn, from = "A", start = 2, end = 5, traversal_time = 3.1
  )
  expect_false(traversal_rows(too_long, "B")$reachable)

  at_terminus <- dyn_paths(
    dn, from = "A", start = 5, end = 6, traversal_time = 0
  )
  expect_false(traversal_rows(at_terminus, "B")$reachable)

  horizon <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 10
  ))
  reaches_end <- dyn_paths(
    horizon, from = "A", start = 3, end = 5, traversal_time = 2
  )
  misses_end <- dyn_paths(
    horizon, from = "A", start = 3, end = 5, traversal_time = 2.1
  )
  expect_equal(traversal_rows(reaches_end, "B")$arrival_time, 5)
  expect_false(traversal_rows(misses_end, "B")$reachable)
})

test_that("traversal time is charged once per hop after waiting", {
  chain <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 4), end = c(4, 7), stringsAsFactors = FALSE
  ))
  paths <- dyn_paths(
    chain, from = "A", start = 0, end = 7, traversal_time = 3
  )
  rows <- traversal_rows(paths, c("A", "B", "C"))
  expect_equal(rows$arrival_time, c(0, 4, 7))
  expect_equal(rows$latency, c(0, 4, 7))
  expect_equal(rows$n_hops, c(0L, 1L, 2L))

  waiting <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(2, 8), end = c(6, 12), stringsAsFactors = FALSE
  ))
  waited <- dyn_paths(
    waiting, from = "A", start = 0, end = 10, traversal_time = 2
  )
  expect_equal(
    traversal_rows(waited, c("A", "B", "C"))$arrival_time,
    c(0, 4, 10)
  )
})

test_that("continuous interval activity is invariant to spell segmentation", {
  unsplit <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 4
  ))
  touching <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 2), end = c(2, 4)
  ))
  overlapping <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 2), end = c(2.5, 4)
  ))
  gap <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 2.1), end = c(2, 4)
  ))
  query <- function(dn) dyn_paths(
    dn, from = "A", start = 1, end = 3, traversal_time = 2
  )

  expect_equal(traversal_rows(query(unsplit), "B")$arrival_time, 3)
  expect_equal(traversal_rows(query(touching), "B")$arrival_time, 3)
  expect_equal(traversal_rows(query(overlapping), "B")$arrival_time, 3)
  expect_false(traversal_rows(query(gap), "B")$reachable)
})

test_that("the traversal interval union helper preserves gaps and points", {
  dn <- quiet_dynet(data.frame(
    from = rep("A", 4), to = rep("B", 4),
    start = c(0, 2, 3, 5), end = c(2, 4, 3, 6),
    stringsAsFactors = FALSE
  ))
  merged <- .coalesce_traversal_intervals(.encode(dn))

  expect_equal(merged$start, c(0, 3, 5))
  expect_equal(merged$end, c(4, 3, 6))
  expect_identical(merged$instant, c(FALSE, TRUE, FALSE))

  no_points <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 2), end = c(2, 4), stringsAsFactors = FALSE
  ))
  expect_no_error(.coalesce_traversal_intervals(.encode(no_points)))
})

test_that("point events trigger a delayed arrival", {
  point <- quiet_dynet(data.frame(
    from = "A", to = "B", time = 5, stringsAsFactors = FALSE
  ))
  exact <- dyn_paths(
    point, from = "A", start = 0, end = 7, traversal_time = 2
  )
  too_early <- dyn_paths(
    point, from = "A", start = 0, end = 6, traversal_time = 2
  )
  expect_equal(traversal_rows(exact, "B")$arrival_time, 7)
  expect_false(traversal_rows(too_early, "B")$reachable)

  simultaneous <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(5, 5),
    stringsAsFactors = FALSE
  ))
  delayed <- dyn_paths(
    simultaneous, from = "A", start = 0, end = 10,
    traversal_time = 2
  )
  immediate <- dyn_paths(
    simultaneous, from = "A", start = 0, end = 10,
    traversal_time = 0
  )
  expect_equal(traversal_rows(delayed, "B")$arrival_time, 7)
  expect_false(traversal_rows(delayed, "C")$reachable)
  expect_equal(traversal_rows(immediate, "C")$arrival_time, 5)

  triggered <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(5, 7), end = c(5, 10), stringsAsFactors = FALSE
  ))
  continued <- dyn_paths(
    triggered, from = "A", start = 0, end = 9,
    traversal_time = 2
  )
  expect_equal(
    traversal_rows(continued, c("A", "B", "C"))$arrival_time,
    c(0, 7, 9)
  )
})

test_that("backward duration is the exact original-time dual", {
  interval <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 2, end = 5,
    stringsAsFactors = FALSE
  ))
  positive <- dyn_paths(
    interval, from = "B", direction = "backward",
    start = 2, end = 5, traversal_time = 3
  )
  zero <- dyn_paths(
    interval, from = "B", direction = "backward",
    start = 2, end = 5, traversal_time = 0
  )
  expect_equal(traversal_rows(positive, "A")$arrival_time, 2)
  expect_true(traversal_rows(positive, "A")$attained)
  expect_equal(traversal_rows(positive, "A")$latency, 3)
  expect_equal(traversal_rows(zero, "A")$arrival_time, 5)
  expect_false(traversal_rows(zero, "A")$attained)

  chain <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 4), end = c(4, 8), stringsAsFactors = FALSE
  ))
  backward <- dyn_paths(
    chain, from = "C", direction = "backward",
    start = 0, end = 7, traversal_time = 3
  )
  rows <- traversal_rows(backward, c("A", "B", "C"))
  expect_equal(rows$arrival_time, c(1, 4, 7))
  expect_true(all(rows$attained))
  expect_equal(rows$n_hops, c(2L, 1L, 0L))

  point <- quiet_dynet(data.frame(from = "A", to = "B", time = 5))
  point_ok <- dyn_paths(
    point, from = "B", direction = "backward", end = 7,
    traversal_time = 2
  )
  point_late <- dyn_paths(
    point, from = "B", direction = "backward", end = 6,
    traversal_time = 2
  )
  expect_equal(traversal_rows(point_ok, "A")$arrival_time, 5)
  expect_true(traversal_rows(point_ok, "A")$attained)
  expect_false(traversal_rows(point_late, "A")$reachable)

  excluded <- dyn_paths(
    interval, from = "B", direction = "backward",
    start = 2 + 1e-6, end = 5, traversal_time = 3
  )
  expect_false(traversal_rows(excluded, "A")$reachable)
})

test_that("direct traversal kernels implement duration and attainment", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 4), end = c(4, 8), stringsAsFactors = FALSE
  ))
  enc <- .encode(dn)
  nodes <- match(c("A", "B", "C"), enc$names)

  forward <- .temporal_bfs(
    enc, source = match("A", enc$names), t0 = 0, upper = 7,
    traversal_time = 3
  )
  expect_equal(forward$arrival[nodes], c(0, 4, 7))

  backward <- .temporal_bfs_backward(
    enc, target = match("C", enc$names), deadline = 7, lower = 0,
    traversal_time = 3
  )
  expect_equal(backward$arrival[nodes], c(1, 4, 7))
  expect_identical(backward$attained[nodes], rep(TRUE, 3L))
})

test_that("duration respects bounded and separate session paths", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 4), end = c(4, 8), session = c("s1", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  collapsed <- dyn_paths(
    dn, from = "A", start = 0, end = 8,
    sessions = "collapse", traversal_time = 2
  )
  bounded <- dyn_paths(
    dn, from = "A", start = 0, end = 8,
    sessions = "bounded", traversal_time = 2
  )
  separate <- dyn_paths(
    dn, from = "A", start = 0, end = 8,
    sessions = "separate", traversal_time = 2
  )
  expect_equal(
    traversal_rows(collapsed, c("A", "B", "C"))$arrival_time,
    c(0, 2, 6)
  )
  expect_false(traversal_rows(bounded, "C")$reachable)
  s2 <- as.data.frame(separate)
  s2 <- s2[s2$session == "s2" & s2$node == "C", , drop = FALSE]
  expect_false(s2$reachable)

  tied_spells <- data.frame(
    from = c("S", "S", "A"), to = c("T", "A", "T"),
    start = c(3, 0, 3), end = c(5, 2, 5),
    session = c("s1", "s2", "s2"), stringsAsFactors = FALSE
  )
  tied_dn <- quiet_dynet(tied_spells, session = "session")
  tied <- dyn_paths(
    tied_dn, from = "S", start = 0, end = 5,
    sessions = "bounded", traversal_time = 2
  )
  target <- traversal_rows(tied, "T")
  expect_equal(target$arrival_time, 5)
  expect_equal(target$n_best_sessions, 1L)
  expect_identical(target$path_session, "s1")
  expect_equal(target$n_hops, 1L)
  expect_equal(target$n_paths, 1)
})

test_that("interval unions cross labels only in collapse mode", {
  spells <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 2), end = c(2, 4), session = c("s1", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  collapsed <- dyn_paths(
    dn, from = "A", start = 1, end = 3,
    sessions = "collapse", traversal_time = 2
  )
  bounded <- dyn_paths(
    dn, from = "A", start = 1, end = 3,
    sessions = "bounded", traversal_time = 2
  )
  separate <- as.data.frame(dyn_paths(
    dn, from = "A", start = 1, end = 3,
    sessions = "separate", traversal_time = 2
  ))

  expect_equal(traversal_rows(collapsed, "B")$arrival_time, 3)
  expect_false(traversal_rows(bounded, "B")$reachable)
  expect_false(any(separate$reachable[separate$node == "B"]))
})

test_that("backward duration cannot assemble a path across sessions", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 4), end = c(4, 8), session = c("s1", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  collapsed <- dyn_paths(
    dn, from = "C", direction = "backward", start = 0, end = 8,
    sessions = "collapse", traversal_time = 2
  )
  bounded <- dyn_paths(
    dn, from = "C", direction = "backward", start = 0, end = 8,
    sessions = "bounded", traversal_time = 2
  )
  separate <- dyn_paths(
    dn, from = "C", direction = "backward", start = 0, end = 8,
    sessions = "separate", traversal_time = 2
  )

  expect_equal(
    traversal_rows(collapsed, c("A", "B", "C"))$arrival_time,
    c(2, 6, 8)
  )
  expect_false(traversal_rows(bounded, "A")$reachable)
  blocks <- as.data.frame(separate)
  expect_false(blocks$reachable[blocks$session == "s1" & blocks$node == "A"])
  expect_false(blocks$reachable[blocks$session == "s2" & blocks$node == "A"])

  enc <- .encode(dn)
  direct <- .bfs_backward_bounded(
    dn, enc, target = match("C", enc$names), deadline = 8,
    bounded = TRUE, lower = 0, traversal_time = 2
  )
  expect_false(is.finite(direct$arrival[match("A", enc$names)]))
})

test_that("path, reachability, and temporal reach share duration semantics", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 2), end = c(2, 4), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)
  reach_result <- dyn_reachability(
    dn, direction = "forward", start = 0, end = 4,
    traversal_time = 2
  )
  centrality_result <- dyn_centrality(
    dn, measure = "reach", scope = "temporal", start = 0, end = 4,
    traversal_time = 2
  )
  reach <- as.data.frame(reach_result)
  centrality <- as.data.frame(centrality_result)
  expect_equal(reach$value[match(centrality$node, reach$node)], centrality$value)
  expect_equal(attr(reach_result, "traversal_time"), 2)
  expect_equal(attr(centrality_result, "traversal_time"), 2)

  paths <- dyn_paths(
    dn, from = "A", start = 0, end = 4, traversal_time = 2
  )
  expect_equal(
    reach$value[reach$node == "A"],
    (sum(paths$reachable) - 1) / (nrow(paths) - 1)
  )

  shown <- c(
    capture.output(print(paths)),
    capture.output(print(reach_result)),
    capture.output(print(centrality_result))
  )
  expect_equal(sum(grepl("traversal 2 step per hop", shown, fixed = TRUE)), 3L)
})

test_that("path kernels agree with exhaustive vertex-simple journeys", {
  spells <- data.frame(
    from = c("A", "B", "A", "D"), to = c("B", "C", "D", "C"),
    start = c(1, 4, 2, 4), end = c(4, 7, 2, 8),
    stringsAsFactors = FALSE
  )
  vertices <- c("A", "B", "C", "D")
  dn <- quiet_dynet(spells)

  invisible(lapply(c(0, 1, 3), function(duration) {
    invisible(lapply(vertices, function(source) {
      expected <- traversal_forward_oracle(
        spells, vertices, source, start = 0, end = 7,
        traversal_time = duration
      )
      actual <- dyn_paths(
        dn, from = source, start = 0, end = 7,
        traversal_time = duration
      )
      observed <- traversal_rows(actual, vertices)$arrival_time
      expect_equal(
        observed,
        unname(ifelse(is.finite(expected), expected, NA_real_))
      )
    }))

    invisible(lapply(vertices, function(target) {
      expected <- traversal_backward_oracle(
        spells, vertices, target, start = 0, end = 7,
        traversal_time = duration
      )
      actual <- dyn_paths(
        dn, from = target, direction = "backward", start = 0, end = 7,
        traversal_time = duration
      )
      observed <- traversal_rows(actual, vertices)
      expect_equal(
        observed$arrival_time,
        unname(ifelse(
          is.finite(expected$latest), expected$latest, NA_real_
        ))
      )
      expect_identical(observed$attained, unname(expected$attained))
    }))
  }))
})

test_that("increasing traversal duration cannot improve temporal paths", {
  spells <- data.frame(
    from = c("A", "B", "A", "C"), to = c("B", "C", "C", "D"),
    start = c(0, 3, 5, 8), end = c(4, 7, 9, 12),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)
  durations <- c(0, 1, 2, 3)
  forward <- lapply(durations, function(duration) {
    traversal_rows(dyn_paths(
      dn, from = "A", start = 0, end = 12,
      traversal_time = duration
    ), c("A", "B", "C", "D"))
  })
  backward <- lapply(durations, function(duration) {
    traversal_rows(dyn_paths(
      dn, from = "D", direction = "backward", start = 0, end = 12,
      traversal_time = duration
    ), c("A", "B", "C", "D"))
  })

  forward_reach <- vapply(forward, function(result) {
    sum(result$reachable)
  }, integer(1L))
  backward_reach <- vapply(backward, function(result) {
    sum(result$reachable)
  }, integer(1L))
  expect_true(all(diff(forward_reach) <= 0))
  expect_true(all(diff(backward_reach) <= 0))

  forward_times <- vapply(forward, function(result) {
    result$arrival_time[result$node == "D"]
  }, numeric(1L))
  backward_times <- vapply(backward, function(result) {
    result$arrival_time[result$node == "A"]
  }, numeric(1L))
  expect_true(all(diff(forward_times[is.finite(forward_times)]) >= 0))
  expect_true(all(diff(backward_times[is.finite(backward_times)]) <= 0))
})

test_that("duration respects orientation, translation, and scaling", {
  base <- data.frame(
    from = c("B", "C"), to = c("A", "B"),
    start = c(1, 5), end = c(5, 9), stringsAsFactors = FALSE
  )
  reversed <- transform(base, from = base$to, to = base$from)
  translated <- transform(base, start = start + 10, end = end + 10)
  scaled <- transform(base, start = start * 2, end = end * 2)
  query <- function(spells, start, end, duration) {
    traversal_rows(dyn_paths(
      quiet_dynet(spells, directed = FALSE), from = "A",
      start = start, end = end, traversal_time = duration
    ), c("A", "B", "C"))
  }

  original <- query(base, 0, 9, 3)
  reoriented <- query(reversed, 0, 9, 3)
  shifted <- query(translated, 10, 19, 3)
  stretched <- query(scaled, 0, 18, 6)
  expect_equal(original$arrival_time, c(0, 4, 8))
  expect_equal(reoriented$arrival_time, original$arrival_time)
  expect_equal(shifted$arrival_time, original$arrival_time + 10)
  expect_equal(shifted$latency, original$latency)
  expect_equal(stretched$arrival_time, original$arrival_time * 2)
  expect_equal(stretched$latency, original$latency * 2)
})

test_that("zero traversal preserves the established path result", {
  dn <- quiet_dynet(random_edges(seed = 44L))
  implicit <- dyn_paths(dn, from = "v1", start = 0, end = 20)
  explicit <- dyn_paths(
    dn, from = "v1", start = 0, end = 20, traversal_time = 0
  )
  expect_identical(as.data.frame(implicit), as.data.frame(explicit))
  expect_identical(
    as.data.frame(implicit, what = "steps"),
    as.data.frame(explicit, what = "steps")
  )
  expect_identical(attr(implicit, "traversal_time"), 0)
  expect_identical(attr(explicit, "traversal_time"), 0)

  backward_implicit <- dyn_paths(
    dn, from = "v2", direction = "backward", start = 0, end = 20
  )
  backward_explicit <- dyn_paths(
    dn, from = "v2", direction = "backward", start = 0, end = 20,
    traversal_time = 0
  )
  expect_identical(
    as.data.frame(backward_implicit), as.data.frame(backward_explicit)
  )
  expect_identical(
    as.data.frame(backward_implicit, what = "steps"),
    as.data.frame(backward_explicit, what = "steps")
  )

  reach_implicit <- dyn_reachability(
    dn, direction = "both", start = 0, end = 20
  )
  reach_explicit <- dyn_reachability(
    dn, direction = "both", start = 0, end = 20,
    traversal_time = 0
  )
  centrality_implicit <- dyn_centrality(
    dn, measure = "reach", scope = "temporal", start = 0, end = 20
  )
  centrality_explicit <- dyn_centrality(
    dn, measure = "reach", scope = "temporal", start = 0, end = 20,
    traversal_time = 0
  )
  expect_identical(as.data.frame(reach_implicit),
                   as.data.frame(reach_explicit))
  expect_identical(as.data.frame(centrality_implicit),
                   as.data.frame(centrality_explicit))
})

test_that("traversal duration validates units and centrality scope", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 1))
  bad <- list(-1, Inf, NA_real_, c(1, 2), "one")
  invisible(lapply(bad, function(value) {
    expect_error(
      dyn_paths(dn, from = "A", traversal_time = value),
      class = "dynet_bad_input"
    )
  }))
  expect_error(
    dyn_paths(dn, from = "A", traversal_time = as.difftime(1, units = "days")),
    class = "dynet_bad_input"
  )
  expect_error(
    dyn_centrality(dn, traversal_time = 1),
    class = "dynet_bad_input"
  )
  expect_error(
    dyn_paths(dn, from = "A", traversal_time = as.Date("2026-01-01")),
    class = "dynet_bad_input"
  )
  expect_error(
    dyn_paths(
      dn, from = "A",
      traversal_time = as.POSIXct("2026-01-01", tz = "UTC")
    ),
    class = "dynet_bad_input"
  )

  calendar <- quiet_dynet(data.frame(
    from = "A", to = "B",
    start = as.Date("2026-01-01"), end = as.Date("2026-01-04")
  ), time_unit = "days")
  paths <- dyn_paths(
    calendar, from = "A", start = as.Date("2026-01-01"),
    end = as.Date("2026-01-04"),
    traversal_time = as.difftime(72, units = "hours")
  )
  expect_equal(traversal_rows(paths, "B")$arrival_time, 3)
  expect_equal(attr(paths, "traversal_time"), 3)
  expect_equal(
    .as_traversal_time(as.difftime(72, units = "hours"), calendar),
    3
  )
})

test_that("interior interval duration agrees with tsna", {
  skip_if_not_installed("tsna")
  skip_if_not_installed("networkDynamic")
  skip_if_not_installed("network")

  spells <- data.frame(
    from = "A", to = "B", start = 2, end = 6,
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)
  ours <- dyn_paths(
    dn, from = "A", start = 0, end = 8, traversal_time = 3
  )

  base <- network::network.initialize(2L, directed = TRUE)
  network::set.vertex.attribute(base, "vertex.names", c("A", "B"))
  nd <- networkDynamic::networkDynamic(
    base,
    edge.spells = data.frame(onset = 2, terminus = 6, tail = 1, head = 2),
    verbose = FALSE
  )
  theirs <- tsna::tPath(
    nd, v = 1, start = 0, end = 8, graph.step.time = 3
  )
  expect_equal(traversal_rows(ours, "B")$arrival_time, theirs$tdist[2])
})
