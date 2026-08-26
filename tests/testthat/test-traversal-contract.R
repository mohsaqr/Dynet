.path_arrivals <- function(paths, vertices) {
  result <- as.data.frame(paths)
  result$arrival_time[match(vertices, result$node)]
}

.reach_value <- function(result, vertex, measure_name = "forward_reach") {
  row <- subset(as.data.frame(result),
                node == vertex & measure == measure_name)
  row$value
}

.journey_oracle <- function(spells, vertices, source, at,
                            directed = TRUE,
                            sessions = c("collapse", "bounded")) {
  sessions <- match.arg(sessions)
  stopifnot(
    is.data.frame(spells),
    length(vertices) <= 6L,
    source %in% vertices,
    is.numeric(at),
    length(at) == 1L
  )
  if (!"session" %in% names(spells)) spells$session <- NA_character_
  if (!directed) {
    reverse_spells <- transform(spells, from = spells$to, to = spells$from)
    spells <- rbind(spells, reverse_spells)
  }

  enumerate <- function(vertex, time, visited, fixed_session = NULL) {
    arrivals <- stats::setNames(rep(Inf, length(vertices)), vertices)
    arrivals[[vertex]] <- time
    candidates <- subset(spells, from == vertex & !to %in% visited)
    if (identical(sessions, "bounded") && !is.null(fixed_session)) {
      candidates <- subset(candidates, session == fixed_session)
    }
    if (nrow(candidates) == 0L) return(arrivals)

    instant <- candidates$start == candidates$end
    next_time <- ifelse(instant, candidates$start,
                        pmax(time, candidates$start))
    usable <- (instant & time <= candidates$start) |
      (!instant & next_time < candidates$end)
    candidates <- candidates[usable, , drop = FALSE]
    next_time <- next_time[usable]
    if (nrow(candidates) == 0L) return(arrivals)

    branches <- Map(function(target, arrival, session) {
      journey_session <- if (identical(sessions, "bounded") &&
                             is.null(fixed_session)) session else fixed_session
      enumerate(target, arrival, c(visited, target), journey_session)
    }, candidates$to, next_time, candidates$session)
    Reduce(function(left, right) pmin(left, right),
           c(list(arrivals), branches))
  }

  enumerate(source, at, source)
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
  reach <- dyn_reachability(dn, direction = "forward", at = 0,
                            sessions = "collapse")
  expect_equal(.reach_value(reach, "A"), 0.5)
  centrality <- dyn_centrality(dn, measure = "reach", scope = "temporal",
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
  reach <- dyn_reachability(dn, direction = "forward", at = 0)
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

test_that("path traversal agrees with exhaustive vertex-simple journeys", {
  fixtures <- list(
    mixed = data.frame(
      from = c("A", "B", "A", "C"), to = c("B", "C", "C", "D"),
      start = c(0, 3, 4, 5), end = c(2, 3, 7, 8),
      stringsAsFactors = FALSE
    ),
    chronology = data.frame(
      from = c("A", "B", "C"), to = c("B", "C", "A"),
      start = c(5, 1, 7), end = c(6, 2, 7),
      stringsAsFactors = FALSE
    ),
    equal_time = data.frame(
      from = c("A", "B", "C", "A"), to = c("B", "C", "A", "C"),
      start = c(5, 5, 5, 1), end = c(5, 5, 5, 6),
      stringsAsFactors = FALSE
    ),
    overlap = data.frame(
      from = c("A", "A", "B", "C"), to = c("B", "B", "C", "D"),
      start = c(0, 2, 4, 4), end = c(3, 6, 4, 9),
      stringsAsFactors = FALSE
    )
  )

  cases <- unlist(lapply(names(fixtures), function(name) {
    spells <- fixtures[[name]]
    vertices <- sort(unique(c(spells$from, spells$to)))
    unlist(lapply(c(TRUE, FALSE), function(directed) {
      lapply(vertices, function(source) list(
        name = name, spells = spells, vertices = vertices,
        directed = directed, source = source, at = 0
      ))
    }), recursive = FALSE)
  }), recursive = FALSE)

  invisible(lapply(cases, function(case) {
    dn <- quiet_dynet(case$spells, directed = case$directed)
    ours <- .path_arrivals(
      paths(dn, from = case$source, at = case$at, sessions = "collapse"),
      case$vertices
    )
    oracle <- .journey_oracle(
      case$spells, case$vertices, case$source, case$at,
      directed = case$directed, sessions = "collapse"
    )
    oracle[is.infinite(oracle)] <- NA_real_
    expect_equal(ours, unname(oracle),
                 info = sprintf("%s/%s/%s", case$name,
                                if (case$directed) "directed" else "undirected",
                                case$source))
  }))
})

test_that("matching boundary cases agree with networkDynamic and tsna", {
  skip_if_not_installed("network")
  skip_if_not_installed("networkDynamic")
  skip_if_not_installed("tsna")

  compare_case <- function(spells) {
    vertices <- sort(unique(c(spells$from, spells$to)))
    dn <- quiet_dynet(spells)
    base <- network::network.initialize(length(vertices), directed = TRUE)
    network::set.vertex.attribute(base, "vertex.names", vertices)
    nd <- networkDynamic::networkDynamic(
      base,
      edge.spells = data.frame(
        onset = spells$start, terminus = spells$end,
        tail = match(spells$from, vertices), head = match(spells$to, vertices)
      ),
      start = min(c(0, spells$start)), end = max(spells$end), verbose = FALSE
    )
    ours <- .path_arrivals(paths(dn, from = "A", at = 0), vertices)
    theirs <- tsna::tPath(nd, v = match("A", vertices), start = 0,
                          direction = "fwd")$tdist
    theirs[is.infinite(theirs)] <- NA_real_
    expect_equal(ours, as.numeric(theirs))
  }

  propagated_terminus <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(5, 0), end = c(5, 5), stringsAsFactors = FALSE
  )
  simultaneous_events <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = 5, end = 5, stringsAsFactors = FALSE
  )

  compare_case(propagated_terminus)
  compare_case(simultaneous_events)
})
