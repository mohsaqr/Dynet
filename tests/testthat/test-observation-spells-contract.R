o02_fixture <- function(...) {
  quiet_dynet(data.frame(
    from = c("A", "B", "C", "D", "A", "C"),
    to = c("B", "C", "D", "A", "C", "A"),
    start = c(2, -1, 4, 5, 4, 6),
    end = c(8, 12, 6, 5, 4, 6)
  ), observation_spells = data.frame(
    start = c(6, 0), end = c(10, 4)
  ), ...)
}

test_that("O02 normalizes observation components exactly", {
  dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 12
  ), observation_spells = data.frame(
    start = c(10, 2, 0, 11, 5, 9, 9),
    end = c(12, 5, 3, 11, 7, 9, 9)
  ))
  expect_equal(as.data.frame(dn, what = "observations"), data.frame(
    observation = 1:3,
    start = c(0, 9, 10), end = c(7, 9, 12),
    duration = c(7, 0, 2), instant = c(FALSE, TRUE, FALSE)
  ))
  expect_equal(dn$meta$observation_duration, 9)
  expect_equal(unname(dn$meta$time_range), c(0, 12))
  expect_identical(dn$meta$observation_gap_waiting, "allowed")
  expect_identical(dn$meta$latency_clock, "calendar")

  adjacent <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 10
  ), observation_spells = data.frame(
    start = c(7, 0, 2, 1, 6), end = c(10, 2, 4, 3, 8)
  ))
  expect_equal(as.data.frame(adjacent, what = "observations")$start, c(0, 6))
  expect_equal(as.data.frame(adjacent, what = "observations")$end, c(4, 10))
})

test_that("O02 exposes exact fragments and administrative cuts", {
  observed <- as.data.frame(o02_fixture(), what = "observed_edges")
  expect_equal(
    observed[, c("raw_spell", "observation", "fragment", "from", "to",
                 "start", "end", "raw_start", "raw_end", "instant",
                 "left_observation_censored", "right_observation_censored")],
    data.frame(
      raw_spell = c(1L, 1L, 2L, 2L, 5L, 6L),
      observation = c(1L, 2L, 1L, 2L, 1L, 2L),
      fragment = c(1L, 2L, 1L, 2L, 1L, 1L),
      from = c("A", "A", "B", "B", "A", "C"),
      to = c("B", "B", "C", "C", "C", "A"),
      start = c(2, 6, 0, 6, 4, 6), end = c(4, 8, 4, 10, 4, 6),
      raw_start = c(2, 2, -1, -1, 4, 6),
      raw_end = c(8, 8, 12, 12, 4, 6),
      instant = c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE),
      left_observation_censored = c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE),
      right_observation_censored = c(TRUE, FALSE, TRUE, TRUE, FALSE, FALSE)
    )
  )
  expect_equal(nrow(as.data.frame(o02_fixture())), 6L)
})

test_that("O02 events, durations, and density use raw identities and observed risk", {
  dn <- o02_fixture()
  events <- as.data.frame(dyn_events(
    dn, measure = c("formation", "dissolution"), end = 10,
    step = 2, window = 0
  ))
  formation <- events$value[events$measure == "formation"]
  dissolution <- events$value[events$measure == "dissolution"]
  expect_equal(formation, c(0, 1, 2, 1, 0, 0))
  expect_equal(dissolution, c(0, 0, 1, 2, 1, 0))
  expect_equal(sum(formation), 4)
  expect_equal(sum(dissolution), 4)

  duration <- as.data.frame(dyn_durations(
    dn, measure = c("events", "total", "mean", "median", "first", "last")
  ))
  value <- function(pair, measure) duration$value[
    paste(duration$from, duration$to) == pair & duration$measure == measure
  ]
  expect_equal(value("A B", "events"), 1)
  expect_equal(value("A B", "total"), 4)
  expect_equal(value("A B", "mean"), 4)
  expect_equal(value("A B", "median"), 4)
  expect_equal(value("A B", "first"), 2)
  expect_equal(value("A B", "last"), 8)
  expect_equal(value("B C", "total"), 8)
  expect_equal(value("B C", "median"), 8)
  expect_equal(value("A C", "events"), 1)
  expect_equal(value("A C", "total"), 0)
  expect_equal(value("A C", "median"), 0)
  expect_equal(value("C A", "total"), 0)
  expect_false(any(paste(duration$from, duration$to) %in% c("C D", "D A")))
  expect_equal(Dynet:::.temporal_density(dn), 1 / 8)
  expect_equal(Dynet:::.temporal_density(o02_fixture(directed = FALSE)), 1 / 4)
})

test_that("O02 component grids omit gaps and qualify observations", {
  dn <- o02_fixture()
  bins <- as.data.frame(dn, what = "bins")
  expect_named(bins, c("observation", "bin", "lo", "hi", "time", "closed"))
  expect_equal(bins$observation, c(rep(1L, 4), rep(2L, 4)))
  expect_equal(bins$time, c(0:3, 6:9))
  expect_false(any(bins$time > 4 & bins$time < 6))
  expect_true(all(bins$closed[c(4, 8)]))

  explicit <- as.data.frame(dyn_events(
    dn, measure = "active", start = 1, end = 9, step = 2
  ))
  expect_equal(explicit$observation, c(1L, 1L, 2L, 2L))
  expect_equal(explicit$time, c(1, 3, 7, 9))
  expect_error(
    dyn_events(dn, start = 4.5, end = 5.5),
    class = "dynet_outside_observation"
  )
  expect_error(
    dyn_paths(dn, from = "A", start = 4.5, end = 5.5),
    class = "dynet_outside_observation"
  )

  phased <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 9
  ), observation_spells = data.frame(start = c(2, 6), end = c(4, 8)))
  phase_grid <- as.data.frame(dyn_events(
    phased, measure = "active", start = 1, end = 8, step = 2
  ))
  expect_equal(phase_grid$time, c(3, 7))
  expect_equal(phase_grid$observation, 1:2)
})

test_that("O02 gaps permit waiting but cannot be coalesced into traversal", {
  waiting <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    time = c(2, 7)
  ), observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  path <- as.data.frame(dyn_paths(waiting, from = "A", at = 0))
  expect_equal(path$arrival_time[path$node == "C"], 7)

  crossing <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(2, 3), end = c(8, 8)
  ), observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  enc <- Dynet:::.coalesce_traversal_intervals(Dynet:::.encode(crossing))
  expect_equal(enc$start[enc$from == 1L & enc$to == 2L], c(2, 6))
  expect_equal(enc$end[enc$from == 1L & enc$to == 2L], c(4, 8))
  path <- as.data.frame(dyn_paths(
    crossing, from = "A", at = 0, traversal_time = 3
  ))
  expect_false(path$reachable[path$node == "B"])
  later_component <- as.data.frame(dyn_paths(
    crossing, from = "A", at = 0, traversal_time = 5
  ))
  expect_false(later_component$reachable[later_component$node == "B"])
  backward <- as.data.frame(dyn_paths(
    crossing, from = "B", direction = "backward", at = 10,
    traversal_time = 5
  ))
  expect_false(backward$reachable[backward$node == "A"])

  delayed_point <- quiet_dynet(data.frame(
    from = "A", to = "B", time = 3
  ), observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  delayed <- as.data.frame(dyn_paths(
    delayed_point, from = "A", at = 0, traversal_time = 4
  ))
  expect_equal(delayed$arrival_time[delayed$node == "B"], 7)
})

test_that("O02 new pairs and burst gaps use observed evidence time", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "A", "C", "C", "C"),
    to = c("B", "B", "D", "D", "D"),
    time = c(5, 7, 2, 7, 8)
  ), observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  fresh <- as.data.frame(dyn_events(dn, measure = "new_pairs"))
  expect_equal(fresh$value[fresh$time == 7], 1)
  burst <- as.data.frame(dyn_burstiness(dn, measure = c("events", "mean_gap")))
  expect_equal(burst$value[burst$node == "C" & burst$measure == "events"], 3)
  expect_equal(burst$value[burst$node == "C" & burst$measure == "mean_gap"], 2)
  expect_equal(burst$value[burst$node == "A" & burst$measure == "events"], 1)
  expect_true(is.na(
    burst$value[burst$node == "A" & burst$measure == "mean_gap"]
  ))
})

test_that("O02 validates interface, supports calendar time, and crosses sessions", {
  raw <- data.frame(from = "A", to = "B", start = 0, end = 10)
  expect_error(dynet(
    raw, observation_start = 0,
    observation_spells = data.frame(start = 0, end = 10)
  ), class = "dynet_conflicting_observation")
  expect_error(dynet(raw, observation_spells = data.frame(start = 2, end = 1)),
               class = "dynet_bad_input")
  expect_error(dynet(raw, observation_spells = data.frame(start = 1)),
               class = "dynet_bad_input")

  dates <- data.frame(
    from = "A", to = "B",
    start = as.Date("2026-01-01"), end = as.Date("2026-01-11")
  )
  calendar <- quiet_dynet(dates, time_unit = "days", observation_spells = data.frame(
    start = as.Date(c("2026-01-02", "2026-01-07")),
    end = as.Date(c("2026-01-04", "2026-01-09"))
  ))
  expect_equal(as.data.frame(calendar, what = "observations")$start, c(1, 6))
  expect_equal(calendar$meta$observation_duration, 4)

  sessioned <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(2, 7),
    session = c("s1", "s2")
  ), session = "session",
  observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  separate <- as.data.frame(dyn_events(
    sessioned, measure = "active", sessions = "separate"
  ))
  expect_equal(unique(paste(separate$session, separate$observation)),
               c("s1 1", "s1 2", "s2 1", "s2 2"))
})

test_that("O02 point-only support retains events but has no exposure", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "A"), to = c("B", "C", "C"),
    time = c(2, 5, 7)
  ), observation_spells = data.frame(start = c(7, 2), end = c(7, 2)))
  observations <- as.data.frame(dn, what = "observations")
  expect_equal(observations$start, c(2, 7))
  expect_equal(dn$meta$observation_duration, 0)
  expect_true(is.na(Dynet:::.temporal_density(dn)))
  expect_equal(as.data.frame(dn, what = "bins")$time, c(2, 7))
  expect_equal(nrow(as.data.frame(dn, what = "observed_edges")), 2L)
  expect_equal(sum(as.data.frame(dyn_events(dn, measure = "formation"))$value), 2)
})

test_that("O02 new-pair history does not reset at gaps", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "A", "X", "X"), to = c("B", "B", "Y", "Y"),
    start = c(-1, 7, 5, 7), end = c(3, 7, 5, 7)
  ), observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  fresh <- as.data.frame(dyn_events(dn, measure = "new_pairs"))
  expect_equal(sum(fresh$value), 1)
  expect_equal(fresh$value[fresh$time == 7], 1)

  preactive_later <- quiet_dynet(data.frame(
    from = c("X", "X"), to = c("Y", "Y"),
    start = c(5, 8), end = c(7, 8)
  ), observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  expect_equal(sum(as.data.frame(dyn_events(
    preactive_later, measure = "new_pairs"
  ))$value), 0)
})

test_that("O02 session walls remain independent of observation gaps", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(2, 7),
    session = c("s1", "s2")
  ), session = "session",
  observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  collapsed <- as.data.frame(dyn_paths(
    dn, from = "A", at = 0, sessions = "collapse"
  ))
  bounded <- as.data.frame(dyn_paths(
    dn, from = "A", at = 0, sessions = "bounded"
  ))
  expect_true(collapsed$reachable[collapsed$node == "C"])
  expect_false(bounded$reachable[bounded$node == "C"])
})

test_that("O02 observations and fragments obey row, translation, and scale invariants", {
  raw <- data.frame(
    from = c("C", "A", "B"), to = c("A", "B", "C"),
    start = c(6, 2, -1), end = c(6, 8, 12)
  )
  support <- data.frame(start = c(6, 0), end = c(10, 4))
  base <- quiet_dynet(raw, observation_spells = support)
  permuted <- quiet_dynet(raw[c(3, 1, 2), ],
                          observation_spells = support[c(2, 1), ])
  semantic <- function(dn) {
    out <- as.data.frame(dn, what = "observed_edges")
    out <- out[, c("from", "to", "start", "end", "raw_start", "raw_end",
                   "instant", "left_observation_censored",
                   "right_observation_censored")]
    out[do.call(order, out), ]
  }
  expect_equal(semantic(permuted), semantic(base), ignore_attr = TRUE)
  expect_equal(Dynet:::.temporal_density(permuted),
               Dynet:::.temporal_density(base))

  shifted <- transform(raw, start = start + 17, end = end + 17)
  shifted_support <- transform(support, start = start + 17, end = end + 17)
  shifted_dn <- quiet_dynet(shifted, observation_spells = shifted_support)
  shifted_semantic <- semantic(shifted_dn)
  shifted_semantic$start <- shifted_semantic$start - 17
  shifted_semantic$end <- shifted_semantic$end - 17
  shifted_semantic$raw_start <- shifted_semantic$raw_start - 17
  shifted_semantic$raw_end <- shifted_semantic$raw_end - 17
  expect_equal(shifted_semantic, semantic(base), ignore_attr = TRUE)

  scaled <- transform(raw, start = start * 3, end = end * 3)
  scaled_support <- transform(support, start = start * 3, end = end * 3)
  scaled_dn <- quiet_dynet(scaled, observation_spells = scaled_support)
  expect_equal(scaled_dn$meta$observation_duration,
               3 * base$meta$observation_duration)
  expect_equal(Dynet:::.temporal_density(scaled_dn),
               Dynet:::.temporal_density(base))
})

test_that("O02 preserves weights and loops in the observed accessor", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("A", "B"),
    start = c(2, 2), end = c(8, 8), weight = c(4, 7)
  ), weight = "weight", loops = TRUE,
  observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  observed <- as.data.frame(dn, what = "observed_edges")
  expect_equal(observed$weight[observed$from == "A" & observed$to == "A"],
               c(4, 4))
  expect_equal(observed$weight[observed$to == "B"], c(7, 7))
  expect_equal(nrow(as.data.frame(dn)), 2L)
})

test_that("O02 rejects malformed and nonfinite observation spells", {
  raw <- data.frame(from = "A", to = "B", start = 0, end = 10)
  expect_error(dynet(raw, observation_spells = data.frame(
    start = 0, end = 2, session = "s1"
  )), class = "dynet_bad_input")
  expect_error(dynet(raw, observation_spells = data.frame(
    start = 0, end = Inf
  )), class = "dynet_bad_input")
  expect_error(dynet(raw, observation_spells = data.frame(
    start = as.Date("2026-01-01"), end = as.Date("2026-01-02")
  )), class = "dynet_bad_input")
})

test_that("O02 supports POSIX components and empty fixed public views", {
  timestamps <- as.POSIXct(c("2026-01-01 00:00:00", "2026-01-01 12:00:00"),
                           tz = "UTC")
  calendar <- quiet_dynet(data.frame(
    from = "A", to = "B", start = timestamps[1], end = timestamps[2]
  ), time_unit = "hours", observation_spells = data.frame(
    start = timestamps[1] + c(3600, 7 * 3600),
    end = timestamps[1] + c(3 * 3600, 9 * 3600)
  ))
  expect_equal(as.data.frame(calendar, what = "observations")$start, c(1, 7))
  expect_equal(calendar$meta$observation_duration, 4)

  empty <- quiet_dynet(data.frame(
    from = c("A", "C"), to = c("B", "B"), time = c(5, 5)
  ),
  observation_spells = data.frame(start = c(0, 6), end = c(4, 10)))
  expect_equal(nrow(as.data.frame(empty, what = "observed_edges")), 0L)
  expect_equal(nrow(as.data.frame(empty, what = "bins")), 8L)
  empty_path <- as.data.frame(dyn_paths(empty, from = "A", at = 0))
  expect_equal(empty_path$reachable, c(TRUE, FALSE, FALSE))

  singleton <- quiet_dynet(data.frame(
    from = "A", to = "A", time = 5
  ), nodes = data.frame(name = "A"), loops = TRUE,
  observation_spells = data.frame(start = c(2, 7), end = c(2, 7)))
  singleton_path <- as.data.frame(dyn_paths(singleton, from = "A"))
  expect_equal(singleton_path$reachable, TRUE)
  expect_equal(singleton_path$n_hops, 0L)
})
