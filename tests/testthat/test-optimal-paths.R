path_value <- function(paths, node) {
  as.data.frame(paths)[match(node, paths$node), , drop = FALSE]
}

optimal_routes <- function(paths, endpoint) {
  steps <- as.data.frame(paths, what = "steps")
  steps <- steps[steps$endpoint == endpoint, , drop = FALSE]
  split(steps, steps$path_id)
}

route_nodes <- function(routes) {
  unname(sort(vapply(routes, function(route) {
    paste(route$node, collapse = ">")
  }, character(1L))))
}

test_that("shortest-foremost paths count every equal optimal branch", {
  two <- data.frame(
    from = c("S", "S", "A", "B"), to = c("A", "B", "T", "T"),
    time = c(1, 1, 2, 2), stringsAsFactors = FALSE
  )
  paths <- dyn_paths(quiet_dynet(two), from = "S", start = 0, end = 2)
  target <- path_value(paths, "T")

  expect_equal(target$arrival_time, 2)
  expect_equal(target$n_hops, 2L)
  expect_equal(target$n_paths, 2)
  expect_identical(
    route_nodes(optimal_routes(paths, "T")),
    c("S>A>T", "S>B>T")
  )
  expect_identical(attr(paths, "criterion"), "foremost_then_shortest")
})

test_that("hop count breaks equal-arrival ties", {
  spells <- data.frame(
    from = c("S", "A", "S", "B", "C"),
    to = c("A", "T", "B", "C", "T"),
    time = c(1, 3, 1, 2, 3), stringsAsFactors = FALSE
  )
  paths <- dyn_paths(quiet_dynet(spells), from = "S", start = 0, end = 3)
  target <- path_value(paths, "T")
  expect_equal(target$arrival_time, 3)
  expect_equal(target$n_hops, 2L)
  expect_equal(target$n_paths, 1)
  expect_identical(route_nodes(optimal_routes(paths, "T")), "S>A>T")
})

test_that("endpoint optimization retains a later shorter prefix", {
  spells <- data.frame(
    from = c("S", "A", "S", "X"), to = c("A", "X", "X", "T"),
    time = c(1, 1, 2, 5), stringsAsFactors = FALSE
  )
  paths <- dyn_paths(quiet_dynet(spells), from = "S", start = 0, end = 5)
  expect_equal(path_value(paths, "X")$arrival_time, 1)
  expect_equal(path_value(paths, "X")$n_hops, 2L)
  expect_equal(path_value(paths, "T")$arrival_time, 5)
  expect_equal(path_value(paths, "T")$n_hops, 2L)

  target <- optimal_routes(paths, "T")[[1L]]
  expect_identical(target$node, c("S", "X", "T"))
  expect_equal(target$time, c(0, 2, 5))
})

test_that("recurrent contacts define distinct atom-sequence paths", {
  spells <- data.frame(
    from = c("S", "S", "A"), to = c("A", "A", "T"),
    time = c(1, 2, 5), stringsAsFactors = FALSE
  )
  paths <- dyn_paths(quiet_dynet(spells), from = "S", start = 0, end = 5)
  target <- path_value(paths, "T")
  expect_equal(target$n_hops, 2L)
  expect_equal(target$n_paths, 2)

  routes <- optimal_routes(paths, "T")
  expect_length(routes, 2L)
  expect_true(all(vapply(routes, function(route) {
    identical(route$node, c("S", "A", "T"))
  }, logical(1L))))
  expect_setequal(vapply(routes, function(route) route$time[[2L]], numeric(1L)),
                  c(1, 2))
})

test_that("duplicates and interval segmentation do not multiply paths", {
  point <- data.frame(
    from = c("S", "S", "A"), to = c("A", "A", "T"),
    time = c(1, 1, 2), stringsAsFactors = FALSE
  )
  expect_equal(path_value(dyn_paths(
    quiet_dynet(point), from = "S", start = 0, end = 2
  ), "T")$n_paths, 1)

  variants <- list(
    data.frame(from = c("S", "A"), to = c("A", "T"),
               start = c(0, 5), end = c(4, 5)),
    data.frame(from = c("S", "S", "A"), to = c("A", "A", "T"),
               start = c(0, 0, 5), end = c(4, 4, 5)),
    data.frame(from = c("S", "S", "A"), to = c("A", "A", "T"),
               start = c(0, 2, 5), end = c(2, 4, 5)),
    data.frame(from = c("S", "S", "A"), to = c("A", "A", "T"),
               start = c(0, 2, 5), end = c(3, 4, 5))
  )
  counts <- vapply(variants, function(spells) {
    path_value(dyn_paths(
      quiet_dynet(spells), from = "S", start = 0, end = 5
    ), "T")$n_paths
  }, numeric(1L))
  expect_equal(counts, rep(1, length(variants)))
})

test_that("simultaneous cycles cannot pad an optimal path", {
  spells <- data.frame(
    from = c("S", "S", "A", "B", "A", "B"),
    to = c("A", "B", "B", "A", "T", "T"),
    time = c(1, 1, 1, 1, 2, 2), stringsAsFactors = FALSE
  )
  paths <- dyn_paths(quiet_dynet(spells), from = "S", start = 0, end = 2)
  target <- path_value(paths, "T")
  expect_equal(target$n_hops, 2L)
  expect_equal(target$n_paths, 2)
  expect_identical(route_nodes(optimal_routes(paths, "T")),
                   c("S>A>T", "S>B>T"))
})

test_that("bounded sessions compete on arrival and then hops", {
  spells <- data.frame(
    from = c("S", "A", "S"), to = c("A", "T", "T"),
    time = c(1, 5, 5), session = c("s1", "s1", "s2"),
    stringsAsFactors = FALSE
  )
  paths <- dyn_paths(
    quiet_dynet(spells, session = "session"), from = "S", start = 0,
    end = 5, sessions = "bounded"
  )
  target <- path_value(paths, "T")
  expect_equal(target$n_hops, 1L)
  expect_equal(target$n_paths, 1)
  expect_identical(target$path_session, "s2")
  expect_equal(target$n_best_sessions, 1L)
})

test_that("equal full-cost sessions remain distinct bounded paths", {
  spells <- data.frame(
    from = c("S", "A", "S", "B"), to = c("A", "T", "B", "T"),
    time = c(1, 5, 1, 5), session = c("s1", "s1", "s2", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  bounded <- dyn_paths(dn, from = "S", start = 0, end = 5,
                       sessions = "bounded")
  target <- path_value(bounded, "T")
  expect_equal(target$n_paths, 2)
  expect_equal(target$n_best_sessions, 2L)
  expect_true(is.na(target$path_session))

  separate <- dyn_paths(dn, from = "S", start = 0, end = 5,
                        sessions = "separate")
  expect_equal(separate$n_paths[separate$node == "T"], c(1, 1))
})

test_that("backward unattained suprema have no maximizing path family", {
  interval <- quiet_dynet(data.frame(
    from = "A", to = "T", start = 0, end = 5
  ))
  paths <- dyn_paths(interval, from = "T", direction = "backward",
                     start = 0, end = 5)
  origin <- path_value(paths, "A")
  expect_true(origin$reachable)
  expect_false(origin$attained)
  expect_equal(origin$arrival_time, 5)
  expect_true(is.na(origin$n_hops))
  expect_equal(origin$n_paths, 0)
  expect_length(optimal_routes(paths, "A"), 0L)

  exact <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("T", "T"),
    start = c(0, 5), end = c(5, 5)
  ))
  exact_paths <- dyn_paths(exact, from = "T", direction = "backward",
                           start = 0, end = 5)
  exact_origin <- path_value(exact_paths, "A")
  expect_true(exact_origin$attained)
  expect_equal(exact_origin$n_hops, 1L)
  expect_equal(exact_origin$n_paths, 1)
})

test_that("an incoming contact can cap an unattained backward suffix", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "T"),
    start = c(4, 0), end = c(4, 5)
  ))
  paths <- dyn_paths(dn, from = "T", direction = "backward",
                     start = 0, end = 10)
  expect_false(path_value(paths, "B")$attained)
  expect_equal(path_value(paths, "B")$n_paths, 0)
  expect_true(path_value(paths, "A")$attained)
  expect_equal(path_value(paths, "A")$arrival_time, 4)
  expect_equal(path_value(paths, "A")$n_hops, 2L)
  expect_equal(path_value(paths, "A")$n_paths, 1)
  route <- optimal_routes(paths, "A")[[1L]]
  expect_identical(route$node, c("A", "B", "T"))
  expect_identical(route$attained, c(TRUE, FALSE, TRUE))
})

test_that("path summaries omit undefined hop optima without losing defined ones", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "C"), to = c("T", "T", "T"),
    start = c(0, 2, 4), end = c(5, 2, 4)
  ))
  paths <- dyn_paths(dn, from = "T", direction = "backward",
                     start = 0, end = 5)
  described <- summary(paths)
  expect_identical(
    described$value[described$property == "median hops"], "1"
  )
  expect_identical(
    described$value[described$property == "max hops"], "1"
  )
})

test_that("distinct canonical atoms can share one visible trace", {
  point_interval <- quiet_dynet(data.frame(
    from = c("S", "S", "A"), to = c("A", "A", "T"),
    start = c(1, 1, 2), end = c(1, 2, 2)
  ))
  paths <- dyn_paths(point_interval, from = "S", start = 0, end = 2)
  expect_equal(path_value(paths, "T")$n_paths, 2)

  recurrent_intervals <- quiet_dynet(data.frame(
    from = c("S", "S", "A"), to = c("A", "A", "T"),
    start = c(0, 2.1, 5), end = c(2, 4, 5)
  ))
  recurrent <- dyn_paths(recurrent_intervals, from = "S", start = 0, end = 5)
  expect_equal(path_value(recurrent, "T")$n_paths, 2)
})

test_that("path families are invariant to representation transformations", {
  spells <- data.frame(
    from = c("S", "S", "A"), to = c("A", "A", "T"), time = c(1, 2, 5)
  )
  query <- function(data, start, end, directed = TRUE) {
    out <- dyn_paths(quiet_dynet(data, directed = directed), from = "S",
                     start = start, end = end)
    path_value(out, "T")[c("arrival_time", "n_hops", "n_paths")]
  }
  base <- query(spells, 0, 5)
  permuted <- query(spells[c(3, 1, 2), ], 0, 5)
  translated <- transform(spells, time = time + 17)
  shifted <- query(translated, 17, 22)
  rename <- c(S = "Q", A = "M", T = "Z")
  renamed <- transform(spells, from = unname(rename[from]),
                       to = unname(rename[to]))
  renamed_result <- dyn_paths(quiet_dynet(renamed), from = "Q",
                              start = 0, end = 5)
  renamed_target <- path_value(renamed_result, "Z")

  expect_identical(base, permuted)
  expect_equal(shifted$arrival_time, base$arrival_time + 17)
  expect_equal(shifted$n_hops, base$n_hops)
  expect_equal(shifted$n_paths, base$n_paths)
  expect_equal(renamed_target$n_hops, base$n_hops)
  expect_equal(renamed_target$n_paths, base$n_paths)
})

test_that("empty and unreachable path families have exact counts", {
  paths <- dyn_paths(quiet_dynet(data.frame(
    from = c("S", "X"), to = c("A", "Y"), time = c(1, 1)
  )), from = "S", start = 0, end = 1)
  expect_equal(path_value(paths, "S")$n_paths, 1)
  expect_equal(path_value(paths, "S")$n_hops, 0L)
  expect_equal(path_value(paths, "Y")$n_paths, 0)
  expect_true(is.na(path_value(paths, "Y")$n_hops))
})

test_that("state helpers expose an acyclic exact-count search", {
  spells <- data.frame(
    from = c("S", "S", "A"), to = c("A", "A", "T"),
    time = c(1, 2, 5), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)
  enc <- Dynet:::.encode(dn)
  atoms <- Dynet:::.canonical_path_atoms(enc)
  expect_equal(nrow(as.data.frame(atoms[c("from", "to", "start", "end")])), 3L)
  expect_equal(Dynet:::.path_count_add(2^53 - 1, 1), 2^53)
  expect_error(Dynet:::.path_count_add(2^53, 1),
               class = "dynet_path_overflow")

  search <- Dynet:::.optimal_path_search(
    enc, match("S", enc$names), 0, "forward", upper = 5
  )
  expect_equal(length(search$state$vertex), 4L)
  expect_true(all(vapply(seq_along(search$state$pred_state)[-1L], function(id) {
    all(search$state$hops[id] ==
          search$state$hops[search$state$pred_state[[id]]] + 1L)
  }, logical(1L))))
  target <- match("T", enc$names)
  expect_equal(search$n_paths[[target]], 2)
  expect_equal(length(search$state$pred_state[[
    search$selected_states[[target]]
  ]]), 2L)

  bounded <- Dynet:::.optimal_bounded_search(
    dn, enc, match("S", enc$names), 0, "forward", FALSE, upper = 5
  )
  primary <- Dynet:::.optimal_paths_table(bounded, "collapse")
  expect_equal(primary$n_paths[primary$node == "T"], 2)
  routes <- Dynet:::.optimal_endpoint_routes(bounded, target)
  expect_length(routes, 2L)
  expect_length(Dynet:::.expand_optimal_state(
    bounded, bounded$selected_states[[target]]
  ), 2L)
  steps <- Dynet:::.optimal_steps(list(mode = "collapse", search = bounded))
  expect_equal(length(unique(steps$path_id[steps$endpoint == "T"])), 2L)
})

binary_diamonds <- function(k) {
  from <- to <- character()
  time <- numeric()
  merge <- "M0"
  for (stage in seq_len(k)) {
    left <- paste0("A", stage)
    right <- paste0("B", stage)
    next_merge <- paste0("M", stage)
    from <- c(from, merge, merge, left, right)
    to <- c(to, left, right, next_merge, next_merge)
    time <- c(time, rep(stage, 4L))
    merge <- next_merge
  }
  data.frame(from = from, to = to, time = time, stringsAsFactors = FALSE)
}

test_that("path counts remain exact through 2^53 and then error", {
  exact <- dyn_paths(
    quiet_dynet(binary_diamonds(53L)), from = "M0", start = 0, end = 53
  )
  expect_equal(path_value(exact, "M53")$n_hops, 106L)
  expect_identical(path_value(exact, "M53")$n_paths, 2^53)
  expect_error(
    dyn_paths(
      quiet_dynet(binary_diamonds(54L)), from = "M0", start = 0, end = 54
    ),
    class = "dynet_path_overflow"
  )
})

test_that("route expansion is guarded without invalidating compact counts", {
  compact <- dyn_paths(
    quiet_dynet(binary_diamonds(20L)), from = "M0", start = 0, end = 20
  )
  expect_equal(path_value(compact, "M20")$n_paths, 2^20)
  expect_error(as.data.frame(compact, what = "steps"),
               class = "dynet_path_expansion_too_large")
})

test_that("aggregate route expansion is guarded across endpoints", {
  compact <- dyn_paths(
    quiet_dynet(binary_diamonds(19L)), from = "M0", start = 0, end = 19
  )
  expect_true(max(compact$n_paths) < 1e6)
  expect_true(sum(compact$n_paths) > 1e6)
  expect_error(as.data.frame(compact, what = "steps"),
               class = "dynet_path_expansion_too_large")
})
