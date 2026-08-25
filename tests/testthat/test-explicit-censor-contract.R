o03_states <- function(duplicate = FALSE, ...) {
  from <- if (duplicate) rep("A", 4) else c("A", "C", "E", "G")
  to <- if (duplicate) rep("B", 4) else c("B", "D", "F", "H")
  quiet_dynet(data.frame(
    from = from, to = to, start = 0, end = 10,
    left = c(FALSE, TRUE, FALSE, TRUE),
    right = c(FALSE, FALSE, TRUE, TRUE)
  ), onset_censored = "left", terminus_censored = "right", ...)
}

o03_value <- function(result, measure) {
  frame <- as.data.frame(result)
  frame$value[frame$measure == measure]
}

test_that("O03 preserves four explicit raw censor states", {
  dn <- o03_states()
  raw <- as.data.frame(dn)
  expect_equal(raw$onset_censored, c(FALSE, TRUE, FALSE, TRUE))
  expect_equal(raw$terminus_censored, c(FALSE, FALSE, TRUE, TRUE))
  expect_equal(raw$start, rep(0, 4))
  expect_equal(raw$end, rep(10, 4))
  expect_identical(dn$meta$raw_censoring, "explicit")
  expect_equal(dn$meta$n_onset_censored, 2L)
  expect_equal(dn$meta$n_terminus_censored, 2L)
  expect_equal(dn$meta$n_both_censored, 1L)

  observed <- as.data.frame(dn, what = "observed_edges")
  expect_equal(observed$onset_censored, raw$onset_censored)
  expect_equal(observed$terminus_censored, raw$terminus_censored)
  expect_false(any(observed$left_observation_censored))
  expect_false(any(observed$right_observation_censored))
})

test_that("O03 censored numeric limits are not endpoint events", {
  dn <- o03_states()
  event_result <- dyn_events(
    dn, measure = c("formation", "dissolution", "active", "new_pairs"),
    start = 0, end = 10, step = 10, window = 0
  )
  events <- as.data.frame(event_result)
  at <- function(measure, time) events$value[
    events$measure == measure & events$time == time
  ]
  expect_equal(at("formation", 0), 2)
  expect_equal(at("formation", 10), 0)
  expect_equal(at("dissolution", 0), 0)
  expect_equal(at("dissolution", 10), 2)
  expect_equal(at("new_pairs", 0), 2)
  expect_equal(at("active", 5), numeric())

  active <- as.data.frame(dyn_events(
    dn, measure = "active", start = 5, end = 5, window = 0
  ))
  expect_equal(active$value, 4)
  expect_identical(attr(event_result, "raw_censoring"),
                   "known_endpoints_only")

  middle <- dyn_snapshots(dn, start = 5, end = 5, window = 0)
  expect_equal(nrow(middle), 4L)
  expect_equal(Dynet:::.temporal_density(dn), 1 / 14)
  paths <- as.data.frame(dyn_paths(dn, from = "C", at = 0))
  expect_true(paths$reachable[paths$node == "D"])
})

test_that("O03 left-censored evidence vetoes pair novelty", {
  duplicate <- o03_states(duplicate = TRUE)
  events <- as.data.frame(dyn_events(
    duplicate, measure = c("formation", "dissolution", "new_pairs"),
    start = 0, end = 10, step = 10, window = 0
  ))
  expect_equal(sum(events$value[events$measure == "formation"]), 2)
  expect_equal(sum(events$value[events$measure == "dissolution"]), 2)
  expect_equal(sum(events$value[events$measure == "new_pairs"]), 0)

  later <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(2, 7), end = c(6, 8),
    left = c(TRUE, FALSE)
  ), onset_censored = "left")
  later_events <- as.data.frame(dyn_events(
    later, measure = c("formation", "new_pairs")
  ))
  expect_equal(sum(later_events$value[later_events$measure == "formation"]), 1)
  expect_equal(sum(later_events$value[later_events$measure == "new_pairs"]), 0)

  bounded <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(-5, 7), end = c(-2, 8),
    left = c(TRUE, FALSE)
  ), onset_censored = "left", observation_start = 0, observation_end = 10)
  bounded_events <- as.data.frame(dyn_events(
    bounded, measure = "new_pairs"
  ))
  expect_equal(sum(bounded_events$value), 1)
})

test_that("O03 observation cuts remain orthogonal administrative state", {
  equal_bounds <- o03_states(observation_start = 0, observation_end = 10)
  equal_fragments <- as.data.frame(equal_bounds, what = "observed_edges")
  expect_false(any(equal_fragments$left_observation_censored))
  expect_false(any(equal_fragments$right_observation_censored))
  expect_equal(equal_fragments$onset_censored,
               c(FALSE, TRUE, FALSE, TRUE))
  equal_events <- as.data.frame(dyn_events(
    equal_bounds, measure = c("formation", "dissolution")
  ))
  expect_equal(sum(equal_events$value[equal_events$measure == "formation"]), 2)
  expect_equal(sum(equal_events$value[equal_events$measure == "dissolution"]), 2)

  continuous <- o03_states(
    observation_start = 2, observation_end = 8
  )
  raw <- as.data.frame(continuous)
  observed <- as.data.frame(continuous, what = "observed_edges")
  expect_equal(observed$start, rep(2, 4))
  expect_equal(observed$end, rep(8, 4))
  expect_true(all(observed$left_observation_censored))
  expect_true(all(observed$right_observation_censored))
  expect_equal(observed$onset_censored, raw$onset_censored)
  expect_equal(observed$terminus_censored, raw$terminus_censored)
  expect_equal(sum(as.data.frame(dyn_events(
    continuous, measure = c("formation", "dissolution")
  ))$value), 0)

  gaps <- o03_states(observation_spells = data.frame(
    start = c(0, 6), end = c(4, 10)
  ))
  fragments <- as.data.frame(gaps, what = "observed_edges")
  expect_equal(nrow(fragments), 8L)
  expect_equal(fragments$onset_censored,
               rep(c(FALSE, TRUE, FALSE, TRUE), each = 2))
  expect_equal(fragments$terminus_censored,
               rep(c(FALSE, FALSE, TRUE, TRUE), each = 2))
  expect_equal(fragments$left_observation_censored,
               rep(c(FALSE, TRUE), 4))
  expect_equal(fragments$right_observation_censored,
               rep(c(TRUE, FALSE), 4))
})

test_that("O03 duration filtering happens after raw-spell recombination", {
  duplicate <- o03_states(
    duplicate = TRUE,
    observation_spells = data.frame(start = c(0, 6), end = c(4, 10))
  )
  included <- dyn_durations(
    duplicate,
    measure = c("events", "total", "mean", "median", "first", "last"),
    censored = "include"
  )
  excluded <- dyn_durations(
    duplicate,
    measure = c("events", "total", "mean", "median", "first", "last"),
    censored = "exclude"
  )
  expect_equal(o03_value(included, "events"), 4)
  expect_equal(o03_value(included, "total"), 32)
  expect_equal(o03_value(included, "mean"), 8)
  expect_equal(o03_value(included, "median"), 8)
  expect_equal(o03_value(included, "first"), 0)
  expect_equal(o03_value(included, "last"), 10)
  expect_equal(o03_value(excluded, "events"), 1)
  expect_equal(o03_value(excluded, "total"), 8)
  expect_equal(attr(included, "raw_censoring"), "included")
  expect_equal(attr(excluded, "raw_censoring"), "excluded")
})

test_that("O03 burstiness uses only known observed onsets", {
  dn <- quiet_dynet(data.frame(
    from = rep("A", 5), to = paste0("v", 1:5),
    start = c(0, 1, 2, 5, 8), end = c(1, 2, 3, 6, 9),
    left = c(FALSE, TRUE, FALSE, TRUE, FALSE)
  ), onset_censored = "left")
  burst_result <- dyn_burstiness(
    dn, measure = c("events", "mean_gap", "burstiness")
  )
  burst <- as.data.frame(burst_result)
  expect_equal(burst$value[burst$node == "A" & burst$measure == "events"], 3)
  expect_equal(burst$value[burst$node == "A" & burst$measure == "mean_gap"], 4)
  expect_equal(
    burst$value[burst$node == "A" & burst$measure == "burstiness"], -1 / 3
  )
  expect_identical(attr(burst_result, "raw_censoring"),
                   "censored_onsets_excluded")
})

test_that("O03 validates flags and format without coercion", {
  base <- data.frame(from = "A", to = "B", start = 0, end = 1)
  expect_error(dynet(base, onset_censored = "missing"),
               class = "dynet_missing_column")
  expect_error(dynet(transform(base, left = 1), onset_censored = "left"),
               class = "dynet_bad_censor")
  expect_error(dynet(transform(base, left = NA), onset_censored = "left"),
               class = "dynet_bad_censor")
  expect_error(dynet(transform(base, left = "FALSE"), onset_censored = "left"),
               class = "dynet_bad_censor")
  shaped <- base
  shaped$left <- I(matrix(c(TRUE, FALSE), nrow = 1L))
  expect_error(dynet(shaped, onset_censored = "left"),
               class = "dynet_bad_censor")
  expect_error(dynet(data.frame(
    from = "A", to = "B", start = 0, end = 0, left = TRUE
  ), onset_censored = "left"), class = "dynet_bad_censor")
  expect_error(dynet(data.frame(
    from = "A", to = "B", time = 0, left = FALSE
  ), onset_censored = "left"), class = "dynet_incompatible_censor")
  expect_error(dynet(data.frame(
    from = "A", to = "B", time = 0, thread = "x", left = FALSE
  ), thread = "thread", onset_censored = "left"),
  class = "dynet_incompatible_censor")
  expect_error(dynet(data.frame(
    actor = c("A", "B"), group = "g", time = 0, left = FALSE
  ), actor = "actor", group = "group", onset_censored = "left"),
  class = "dynet_incompatible_censor")
})

test_that("O03 omitted and explicit all-false inputs remain distinguishable", {
  base <- data.frame(from = "A", to = "B", start = 0, end = 1)
  legacy <- quiet_dynet(base)
  explicit <- quiet_dynet(transform(base, left = FALSE),
                          onset_censored = "left")
  expect_false("onset_censored" %in% names(as.data.frame(legacy)))
  expect_false("terminus_censored" %in% names(as.data.frame(legacy)))
  expect_equal(as.data.frame(explicit)$onset_censored, FALSE)
  expect_equal(as.data.frame(explicit)$terminus_censored, FALSE)
  expect_identical(explicit$meta$raw_censoring_columns$onset, "left")
  expect_null(explicit$meta$raw_censoring_columns$terminus)
})

test_that("O03 sessions, loops, and weights preserve row-local flags", {
  sessioned <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"), start = 0, end = 10,
    session = c("s1", "s2"), left = c(TRUE, FALSE), weight = c(5, 7)
  ), session = "session", weight = "weight", onset_censored = "left")
  collapsed <- as.data.frame(dyn_events(
    sessioned, measure = c("formation", "new_pairs"), sessions = "collapse"
  ))
  separate <- as.data.frame(dyn_events(
    sessioned, measure = c("formation", "new_pairs"), sessions = "separate"
  ))
  expect_equal(sum(collapsed$value[collapsed$measure == "formation"]), 1)
  expect_equal(sum(collapsed$value[collapsed$measure == "new_pairs"]), 0)
  bounded <- as.data.frame(dyn_events(
    sessioned, measure = c("formation", "new_pairs"), sessions = "bounded"
  ))
  expect_equal(sum(bounded$value[bounded$measure == "formation"]), 1)
  expect_equal(sum(bounded$value[bounded$measure == "new_pairs"]), 0)
  expect_equal(as.numeric(tapply(
    separate$value[separate$measure == "formation"],
    separate$session[separate$measure == "formation"], sum
  )), c(0, 1))
  expect_equal(as.numeric(tapply(
    separate$value[separate$measure == "new_pairs"],
    separate$session[separate$measure == "new_pairs"], sum
  )), c(0, 1))
  expect_equal(as.data.frame(sessioned)$weight, c(5, 7))

  loop <- quiet_dynet(data.frame(
    from = "A", to = "A", start = 0, end = 1,
    right = TRUE, weight = 4
  ), loops = TRUE, weight = "weight", terminus_censored = "right")
  expect_equal(as.data.frame(loop)$terminus_censored, TRUE)
  expect_equal(as.data.frame(loop)$weight, 4)
  expect_equal(sum(as.data.frame(dyn_events(
    loop, measure = "dissolution"
  ))$value), 0)

  dropped <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("A", "B"), start = 0, end = 1,
    left = c(TRUE, FALSE)
  ), onset_censored = "left")
  expect_equal(nrow(as.data.frame(dropped)), 1L)
  expect_equal(dropped$meta$n_onset_censored, 0L)
})

test_that("O03 accepts known points and keeps them under complete-case duration", {
  point <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 2, end = 2,
    left = FALSE, right = FALSE
  ), onset_censored = "left", terminus_censored = "right")
  events <- as.data.frame(dyn_events(
    point, measure = c("formation", "dissolution")
  ))
  expect_equal(sum(events$value[events$measure == "formation"]), 1)
  expect_equal(sum(events$value[events$measure == "dissolution"]), 1)
  included <- as.data.frame(dyn_durations(
    point, measure = c("events", "total"), censored = "include"
  ))
  excluded <- as.data.frame(dyn_durations(
    point, measure = c("events", "total"), censored = "exclude"
  ))
  expect_equal(included$value, c(1, 0))
  expect_equal(excluded$value, c(1, 0))
})

test_that("O03 flags are invariant to row order, clocks, scaling, and transpose", {
  raw <- data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "A"),
    start = c(0, 2, 5), end = c(1, 4, 9),
    left = c(TRUE, FALSE, FALSE), right = c(FALSE, TRUE, FALSE)
  )
  base <- quiet_dynet(raw, onset_censored = "left",
                      terminus_censored = "right")
  permuted <- quiet_dynet(raw[c(3, 1, 2), ], onset_censored = "left",
                          terminus_censored = "right")
  keyed <- function(dn) {
    out <- as.data.frame(dn)
    out[order(out$from, out$to),
        c("from", "to", "onset_censored", "terminus_censored")]
  }
  expect_equal(keyed(permuted), keyed(base), ignore_attr = TRUE)

  shifted <- transform(raw, start = start + 17, end = end + 17)
  shifted_dn <- quiet_dynet(shifted, onset_censored = "left",
                            terminus_censored = "right")
  expect_equal(keyed(shifted_dn), keyed(base), ignore_attr = TRUE)
  scaled <- transform(raw, start = start * 3, end = end * 3)
  scaled_dn <- quiet_dynet(scaled, onset_censored = "left",
                           terminus_censored = "right")
  expect_equal(keyed(scaled_dn), keyed(base), ignore_attr = TRUE)
  expect_equal(o03_value(dyn_durations(scaled_dn, measure = "total"), "total"),
               3 * o03_value(dyn_durations(base, measure = "total"), "total"))

  transposed <- transform(raw, from = to, to = from)
  transposed_dn <- quiet_dynet(transposed, onset_censored = "left",
                               terminus_censored = "right")
  expected_transposed <- data.frame(
    from = c("A", "B", "C"), to = c("C", "A", "B"),
    onset_censored = c(FALSE, TRUE, FALSE),
    terminus_censored = c(FALSE, FALSE, TRUE)
  )
  expect_equal(keyed(transposed_dn), expected_transposed, ignore_attr = TRUE)

  renamed <- transform(
    raw,
    from = c(A = "z", B = "x", C = "y")[from],
    to = c(A = "z", B = "x", C = "y")[to]
  )
  renamed_dn <- quiet_dynet(renamed, onset_censored = "left",
                            terminus_censored = "right")
  expected_renamed <- data.frame(
    from = c("x", "y", "z"), to = c("y", "z", "x"),
    onset_censored = c(FALSE, FALSE, TRUE),
    terminus_censored = c(TRUE, FALSE, FALSE)
  )
  expect_equal(keyed(renamed_dn), expected_renamed, ignore_attr = TRUE)
})

test_that("O03 supports duration, Date, and POSIX interval clocks", {
  duration_dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 2, duration = 3, left = TRUE
  ), duration = "duration", onset_censored = "left")
  expect_equal(as.data.frame(duration_dn)$end, 5)
  expect_equal(as.data.frame(duration_dn)$onset_censored, TRUE)

  dates <- quiet_dynet(data.frame(
    from = "A", to = "B", start = as.Date("2026-01-01"),
    end = as.Date("2026-01-04"), right = TRUE
  ), time_unit = "days", terminus_censored = "right")
  expect_equal(as.data.frame(dates)$terminus_censored, TRUE)
  expect_equal(as.data.frame(dates)$end, 3)

  posix <- quiet_dynet(data.frame(
    from = "A", to = "B",
    start = as.POSIXct("2026-01-01 00:00:00", tz = "UTC"),
    end = as.POSIXct("2026-01-01 03:00:00", tz = "UTC"), left = TRUE
  ), time_unit = "hours", onset_censored = "left")
  expect_equal(as.data.frame(posix)$end, 3)
  expect_equal(as.data.frame(posix)$onset_censored, TRUE)
})
