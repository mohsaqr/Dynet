observation_view_frame <- function(dn) {
  enc <- .encode(dn)
  keep <- enc$observed_activity
  data.frame(
    from = enc$names[enc$from[keep]], to = enc$names[enc$to[keep]],
    start = enc$start[keep], end = enc$end[keep],
    instant = enc$instant[keep], session = enc$session[keep],
    stringsAsFactors = FALSE
  )
}

test_that("observation bounds derive a clipped view without changing raw spells", {
  spells <- data.frame(
    from = paste0("v", seq_len(9L)), to = rep("z", 9L),
    start = c(-5, 2, 8, -4, 12, 0, 10, -2, 10),
    end = c(2, 5, 15, 15, 13, 0, 10, -1, 11),
    session = rep(c("one", "two", "one"), 3L),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(
    spells, session = "session", observation_start = 0,
    observation_end = 10
  )

  raw <- as.data.frame(dn)
  expect_equal(raw$start, spells$start[order(spells$start, spells$end,
                                             spells$from, spells$to)])
  expect_equal(raw$end, spells$end[order(spells$start, spells$end,
                                         spells$from, spells$to)])
  expect_identical(dn$meta$event_range, c(start = -5, end = 15))
  expect_identical(dn$meta$observation, c(start = 0, end = 10))
  expect_identical(dn$meta$time_range, c(start = 0, end = 10))

  view <- observation_view_frame(dn)
  view <- view[order(view$from), , drop = FALSE]
  expect_identical(view$from, paste0("v", c(1:4, 6:7)))
  expect_equal(view$start, c(0, 2, 8, 0, 0, 10))
  expect_equal(view$end, c(2, 5, 10, 10, 0, 10))
  expect_identical(view$instant,
                   c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE))
  expect_identical(view$session,
                   c("one", "two", "one", "one", "one", "one"))
  expect_true(all(paste0("v", 1:9) %in% dn$nodes$name))
})

test_that("positive spells never become boundary point events", {
  dn <- quiet_dynet(data.frame(
    from = c("left_touch", "right_touch", "cross", "point_start",
             "point_end"),
    to = "z", start = c(-2, 10, -1, 0, 10),
    end = c(0, 12, 11, 0, 10), stringsAsFactors = FALSE
  ), observation_start = 0, observation_end = 10)
  view <- observation_view_frame(dn)

  expect_identical(sort(view$from), c("cross", "point_end", "point_start"))
  expect_false(view$instant[view$from == "cross"])
  expect_true(all(view$instant[view$from %in% c("point_start", "point_end")]))

  enc <- .encode(dn)
  at_start <- .active(enc, 0, 0, last = FALSE, window = 0)
  at_end <- .active(enc, 10, 10, last = TRUE, window = 0)
  expect_identical(sort(enc$names[enc$from[at_start]]),
                   c("cross", "point_start"))
  expect_identical(enc$names[enc$from[at_end]], "point_end")

  endpoint_only <- enc$names[enc$from[!enc$observed_activity]]
  expect_identical(sort(endpoint_only), c("left_touch", "right_touch"))
  expect_true(all(!enc$instant[!enc$observed_activity]))
})

test_that("clipping does not fabricate endpoint events", {
  dn <- quiet_dynet(data.frame(
    from = c("left_touch", "left_clip", "inside", "right_clip",
             "right_touch"),
    to = "z", start = c(-2, -1, 2, 8, 10),
    end = c(0, 3, 4, 12, 12), stringsAsFactors = FALSE
  ), observation_start = 0, observation_end = 10, interval = 10)

  at_limits <- as.data.frame(dyn_events(
    dn, measure = c("formation", "dissolution"),
    start = 0, end = 10, step = 10, window = 0
  ))
  at_zero <- subset(at_limits, time == 0)
  at_ten <- subset(at_limits, time == 10)
  expect_identical(at_zero$value[at_zero$measure == "formation"], 0)
  expect_identical(at_zero$value[at_zero$measure == "dissolution"], 1)
  expect_identical(at_ten$value[at_ten$measure == "formation"], 1)
  expect_identical(at_ten$value[at_ten$measure == "dissolution"], 0)

  durations <- as.data.frame(dyn_durations(
    dn, measure = c("events", "total", "first", "last")
  ))
  expect_false(any(durations$from %in% c("left_touch", "right_touch")))
  totals <- subset(durations, measure == "total")
  expect_equal(stats::setNames(totals$value, totals$from)[
    c("inside", "left_clip", "right_clip")
  ], c(inside = 2, left_clip = 3, right_clip = 2))

  burst <- as.data.frame(dyn_burstiness(dn, measure = "events"))
  counts <- stats::setNames(burst$value, burst$node)
  expect_identical(counts[c("left_touch", "left_clip")],
                   c(left_touch = 0, left_clip = 0))
  expect_identical(counts[c("inside", "right_clip", "right_touch")],
                   c(inside = 1, right_clip = 1, right_touch = 1))
})

test_that("pre-observation activity suppresses a fabricated new-pair event", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "A", "B"), to = c("B", "B", "C"),
    start = c(-2, 4, -2), end = c(2, 5, -1), stringsAsFactors = FALSE
  ), observation_start = 0, observation_end = 6, interval = 6)
  events <- as.data.frame(dyn_events(
    dn, measure = c("formation", "new_pairs"),
    start = 0, end = 0, window = 6
  ))

  expect_identical(events$value[events$measure == "formation"], 1)
  expect_identical(events$value[events$measure == "new_pairs"], 0)
})

test_that("fully unobserved history does not suppress first observed evidence", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(-3, 2), end = c(-2, 3), stringsAsFactors = FALSE
  ), observation_start = 0, observation_end = 4, interval = 4)
  events <- as.data.frame(dyn_events(
    dn, measure = "new_pairs", start = 0, end = 0, window = 4
  ))
  expect_identical(events$value, 1)
})

test_that("event grids cannot recover endpoints outside observation", {
  dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = -2, end = 12
  ), observation_start = 0, observation_end = 10, interval = 2)
  broad <- as.data.frame(dyn_events(
    dn, measure = c("formation", "dissolution"),
    start = -2, end = 12, step = 2, window = 0
  ))

  expect_true(all(broad$time >= 0 & broad$time <= 10))
  expect_identical(broad$value, rep(0, nrow(broad)))
  expect_error(
    dyn_events(dn, start = -3, end = -2, window = 0),
    class = "dynet_outside_observation"
  )
})

test_that("explicit observation time controls exposure and the default grid", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "C"), to = c("B", "D"),
    start = c(-5, 12), end = c(15, 13), stringsAsFactors = FALSE
  ), observation_start = 0, observation_end = 10, interval = 2)

  expect_equal(.temporal_density(dn), 1 / 12)
  expect_equal(.grid_for(.encode(dn), dn)$time, c(0, 2, 4, 6, 8))
  expect_equal(observation_view_frame(dn)[c("start", "end")],
               data.frame(start = 0, end = 10))
})

test_that("one-sided observation bounds use the corresponding raw limit", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(-3, 4), end = c(2, 9), stringsAsFactors = FALSE
  )
  left <- quiet_dynet(spells, observation_start = 0)
  right <- quiet_dynet(spells, observation_end = 5)

  expect_identical(left$meta$observation, c(start = 0, end = 9))
  expect_identical(right$meta$observation, c(start = -3, end = 5))
  expect_equal(observation_view_frame(left)$start, c(0, 4))
  expect_equal(observation_view_frame(right)$end, c(2, 5))
})

test_that("an empty observed view retains fixed vertices and returns empty snapshots", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 1), end = c(1, 2), stringsAsFactors = FALSE
  ), observation_start = 5, observation_end = 7)
  enc <- .encode(dn)

  expect_length(enc$start, 0L)
  expect_identical(enc$names, c("A", "B", "C"))
  expect_equal(.grid_for(enc, dn)$time, c(5, 6))
  result <- as.data.frame(dyn_centrality(
    dn, measure = "degree", start = 5, end = 5, window = 0
  ))
  expect_identical(result$node, c("A", "B", "C"))
  expect_equal(result$value, c(0, 0, 0))
  expect_equal(nrow(as.data.frame(dyn_durations(dn, measure = "events"))), 0L)
})

test_that("empty observed sessions retain zero reach in every mode", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(-3, 8), end = c(-2, 9), session = c("one", "two"),
    stringsAsFactors = FALSE
  ), session = "session", observation_start = 0, observation_end = 4)

  for (mode in c("bounded", "collapse", "separate")) {
    # Session modes are independent public cases; no iteration depends on a
    # previous result.
    reach <- as.data.frame(dyn_reachability(
      dn, direction = "both", sessions = mode,
      measure = c("reach", "reach_count")
    ))
    expect_true(all(reach$value == 0))
    expect_true(all(reach$node %in% c("A", "B", "C")))
  }
  close <- as.data.frame(dyn_centrality(
    dn, measure = "closeness", scope = "temporal"
  ))
  expect_identical(close$value, c(0, 0, 0))

  for (direction in c("forward", "backward")) {
    # Directional empty-view paths are independent contract cases.
    paths <- dyn_paths(
      dn, from = "A", direction = direction, sessions = "bounded"
    )
    primary <- as.data.frame(paths)
    expect_identical(primary$reachable, primary$node == "A")
    expect_identical(primary$n_paths, c(1, 0, 0))
    expect_identical(primary$n_best_sessions, c(0L, 0L, 0L))
    steps <- as.data.frame(paths, what = "steps")
    expect_true(all(steps$node == "A"))
  }
})

test_that("observation bounds constrain each separate session on one calendar", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(-2, 8), end = c(-1, 9), session = c("early", "late"),
    stringsAsFactors = FALSE
  ), session = "session", observation_start = 0, observation_end = 4,
  interval = 2)
  parts <- .split_sessions(dn, "separate")

  expect_true(all(vapply(parts, function(enc) length(enc$start) == 0L,
                         logical(1L))))
  expect_true(all(vapply(parts, function(enc) {
    identical(.grid_for(enc, dn)$time, c(0, 2))
  }, logical(1L))))
})

test_that("calendar observation bounds use the construction origin and unit", {
  dates <- data.frame(
    from = "A", to = "B",
    start = as.Date("2026-01-01"), end = as.Date("2026-01-11")
  )
  by_date <- quiet_dynet(
    dates, time_unit = "days", observation_start = as.Date("2026-01-03"),
    observation_end = as.Date("2026-01-08")
  )
  expect_identical(by_date$meta$observation, c(start = 2, end = 7))
  expect_equal(observation_view_frame(by_date)[c("start", "end")],
               data.frame(start = 2, end = 7))

  clock <- as.POSIXct(c("2026-01-01 09:00", "2026-01-01 15:00"), tz = "UTC")
  by_clock <- quiet_dynet(
    data.frame(from = "A", to = "B", start = clock[1L], end = clock[2L]),
    time_unit = "hours", observation_start = clock[1L] + 3600,
    observation_end = clock[2L] - 3600
  )
  expect_identical(by_clock$meta$observation, c(start = 1, end = 5))
  expect_equal(observation_view_frame(by_clock)[c("start", "end")],
               data.frame(start = 1, end = 5))
})

test_that("a zero-span observation retains only its boundary contacts", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"),
    time = c(4, 5, 6), stringsAsFactors = FALSE
  ), observation_start = 5, observation_end = 5)

  view <- observation_view_frame(dn)
  expect_identical(view$from, "B")
  expect_identical(view$start, 5)
  expect_true(view$instant)
  expect_identical(.grid_for(.encode(dn), dn)$time, 5)
})

test_that("observation bounds are hard temporal-path horizons", {
  contact <- quiet_dynet(data.frame(
    from = "A", to = "B", time = 9
  ), observation_start = 0, observation_end = 10)
  zero <- as.data.frame(dyn_paths(contact, from = "A"))
  delayed <- as.data.frame(dyn_paths(
    contact, from = "A", traversal_time = 2
  ))
  expect_identical(zero$arrival[zero$node == "B"], 9)
  expect_true(is.na(delayed$arrival[delayed$node == "B"]))

  terminal <- quiet_dynet(data.frame(
    from = "A", to = "B", time = 10
  ), observation_start = 0, observation_end = 10)
  terminal_zero <- as.data.frame(dyn_paths(terminal, from = "A"))
  terminal_delayed <- as.data.frame(dyn_paths(
    terminal, from = "A", traversal_time = 1
  ))
  expect_identical(terminal_zero$arrival[terminal_zero$node == "B"], 10)
  expect_true(is.na(terminal_delayed$arrival[terminal_delayed$node == "B"]))
})

test_that("public paths and temporal closeness use the observation origin", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"),
    start = c(-2, 2, 6), end = c(3, 12, 7), stringsAsFactors = FALSE
  ), observation_start = 0, observation_end = 5,
  nodes = data.frame(name = c("A", "B", "C", "D")))
  paths <- as.data.frame(dyn_paths(dn, from = "A"))
  arrival <- stats::setNames(paths$arrival, paths$node)
  expect_identical(arrival[c("A", "B", "C")], c(A = 0, B = 0, C = 2))
  expect_true(is.na(arrival[["D"]]))

  latency <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 5, end = 6
  ), observation_start = 0, observation_end = 10)
  close <- as.data.frame(dyn_centrality(
    latency, measure = "closeness", scope = "temporal"
  ))
  expect_identical(close$value[close$node == "A"], 1 / 5)

  broad_paths <- dyn_paths(latency, from = "A", start = -2, end = 12)
  broad <- as.data.frame(broad_paths)
  expect_identical(attr(broad_paths, "origin"), 0)
  expect_identical(broad$arrival_time[broad$node == "B"], 5)
  expect_error(
    dyn_paths(latency, from = "A", start = -3, end = -2),
    class = "dynet_outside_observation"
  )
})

test_that("observation-bound validation is classed", {
  spells <- data.frame(from = "A", to = "B", start = 0, end = 10)
  expect_error(
    dynet(spells, observation_start = c(0, 1)), class = "dynet_bad_input"
  )
  expect_error(
    dynet(spells, observation_end = Inf), class = "dynet_bad_input"
  )
  expect_error(
    dynet(spells, observation_start = 8, observation_end = 2),
    class = "dynet_bad_input"
  )
  expect_error(
    dynet(spells, observation_start = as.Date("2026-01-01")),
    class = "dynet_bad_input"
  )
})

test_that("the observation-bound resolver is tested directly", {
  expect_identical(
    .observation_bounds(c(start = -2, end = 8), 0, "step", 1, NULL),
    c(start = 1, end = 8)
  )
  origin <- as.POSIXct("2026-01-01", tz = "UTC")
  expect_identical(
    .observation_bounds(
      c(start = 0, end = 10), origin, "days",
      as.Date("2026-01-03"), as.Date("2026-01-06")
    ),
    c(start = 2, end = 5)
  )
  explicit <- quiet_dynet(
    data.frame(from = "A", to = "B", start = -1, end = 2),
    observation_start = 0, observation_end = 4
  )
  expect_identical(
    .encoding_time_range(explicit, .encode(explicit)),
    c(start = 0, end = 4)
  )
})

test_that("clipping commutes with translation and positive scaling", {
  spells <- data.frame(
    from = c("A", "A", "B"), to = c("B", "C", "C"),
    start = c(-2, 2, 8), end = c(3, 7, 12), stringsAsFactors = FALSE
  )
  base <- quiet_dynet(spells, observation_start = 0, observation_end = 10)
  shifted <- quiet_dynet(
    transform(spells, start = start + 17, end = end + 17),
    observation_start = 17, observation_end = 27
  )
  scaled <- quiet_dynet(
    transform(spells, start = start * 3, end = end * 3),
    observation_start = 0, observation_end = 30
  )
  base_view <- observation_view_frame(base)
  shifted_view <- observation_view_frame(shifted)
  scaled_view <- observation_view_frame(scaled)

  expect_equal(shifted_view$start - 17, base_view$start)
  expect_equal(shifted_view$end - 17, base_view$end)
  expect_equal(scaled_view$start / 3, base_view$start)
  expect_equal(scaled_view$end / 3, base_view$end)
  expect_equal(.temporal_density(shifted), .temporal_density(base))
  expect_equal(.temporal_density(scaled), .temporal_density(base))
})

test_that("omitting observation bounds preserves the legacy object contract", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(1, 2), end = c(3, 4), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)

  expect_false("event_range" %in% names(dn$meta))
  expect_false("observation" %in% names(dn$meta))
  expect_identical(dn$meta$time_range, c(start = 1, end = 4))
  expect_identical(observation_view_frame(dn)$start, c(1, 2))
  expect_identical(observation_view_frame(dn)$end, c(3, 4))
})

test_that("observation clipping preserves raw weights and aggregate access", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(-2, 8), end = c(2, 12), weight = c(3, 7),
    stringsAsFactors = FALSE
  )
  raw <- quiet_dynet(spells, weight = "weight")
  observed <- quiet_dynet(
    spells, weight = "weight", observation_start = 0, observation_end = 5
  )

  expect_identical(as.data.frame(observed), as.data.frame(raw))
  expect_identical(
    as.data.frame(observed, what = "network"),
    as.data.frame(raw, what = "network")
  )
  expect_identical(observation_view_frame(observed)$start, 0)
  expect_identical(observation_view_frame(observed)$end, 2)
})
