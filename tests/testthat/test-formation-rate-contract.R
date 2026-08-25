.t03_value <- function(dn, sessions = "bounded", start = NULL, end = NULL,
                       step = 10, window = 10) {
  dyn_events(
    dn, measure = "formation_rate", sessions = sessions,
    start = start, end = end, step = step, window = window
  )$value
}

.t03_core_edges <- function() {
  data.frame(
    from = c("A", "A", "A", "B", "B", "C", "C", "C", "A"),
    to = c("B", "B", "C", "A", "C", "A", "A", "B", "A"),
    start = c(2, 8, 0, 3, 5, 5, 5, 4, 1),
    end = c(6, 10, 4, 7, 5, 9, 9, 8, 9),
    onset_unknown = c(FALSE, FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, TRUE, FALSE),
    weight = c(1, 2, 3, 4, 5, 6, 7, 8, 100)
  )
}

test_that("T03 literal ledger integrates keyed inactive exposure exactly", {
  edges <- .t03_core_edges()
  directed <- quiet_dynet(
    edges, loops = TRUE, onset_censored = "onset_unknown", weight = "weight",
    observation_start = 0, observation_end = 10
  )
  undirected <- quiet_dynet(
    edges, directed = FALSE, loops = TRUE,
    onset_censored = "onset_unknown", weight = "weight",
    observation_start = 0, observation_end = 10
  )

  directed_exposure <- c(
    `A->B` = 4, `A->C` = 6, `B->A` = 6,
    `B->C` = 10, `C->A` = 6, `C->B` = 6
  )
  undirected_exposure <- c(`A--B` = 3, `A--C` = 2, `B--C` = 6)
  expect_identical(directed_exposure, c(
    `A->B` = 4, `A->C` = 6, `B->A` = 6,
    `B->C` = 10, `C->A` = 6, `C->B` = 6
  ))
  expect_identical(undirected_exposure,
                   c(`A--B` = 3, `A--C` = 2, `B--C` = 6))

  bin <- data.frame(lo = 0, hi = 10, closed = TRUE)
  directed_ledger <- Dynet:::.formation_rate_ledger(
    directed, Dynet:::.encode(directed), bin, "collapse"
  )
  undirected_ledger <- Dynet:::.formation_rate_ledger(
    undirected, Dynet:::.encode(undirected), bin, "collapse"
  )
  expect_identical(names(directed_ledger),
                   c("formations", "inactive_exposure", "formation_rate"))
  expect_type(directed_ledger, "double")
  expect_equal(directed_ledger,
               c(formations = 4, inactive_exposure = 38,
                 formation_rate = 2 / 19))
  expect_equal(undirected_ledger,
               c(formations = 3, inactive_exposure = 11,
                 formation_rate = 3 / 11))
  expect_equal(unname(.t03_value(directed)), 2 / 19)
  expect_equal(unname(.t03_value(undirected)), 3 / 11)
  expect_equal(dyn_events(
    directed, measure = "formation", step = 10, window = 10
  )$value, 8)
})

test_that("T03 literal numerator is the frozen batch formation family", {
  edges <- .t03_core_edges()
  dn <- quiet_dynet(
    edges, loops = TRUE, onset_censored = "onset_unknown", weight = "weight",
    observation_start = 0, observation_end = 10
  )
  enc <- Dynet:::.encode(dn)
  expected <- list(`2` = 2L, `3` = 4L, `5` = 7L, `8` = 2L)
  actual <- lapply(as.numeric(names(expected)), function(time) {
    Dynet:::.transition_pair_ledger(
      dn, enc, time, "collapse"
    )$formations
  })
  names(actual) <- names(expected)
  expect_identical(actual, expected)
  expect_identical(
    vapply(actual, length, integer(1L)),
    c(`2` = 1L, `3` = 1L, `5` = 1L, `8` = 1L)
  )

  expect_identical(
    Dynet:::.transition_pair_ledger(dn, enc, 0, "collapse")$formations,
    integer()
  )
  expect_identical(
    Dynet:::.transition_pair_ledger(dn, enc, 4, "collapse")$formations,
    integer()
  )
})

test_that("T03 unions duplicates, overlaps, adjacency, and points", {
  edges <- data.frame(
    from = "A", to = "B",
    start = c(2, 2, 4, 8, 6), end = c(8, 5, 7, 9, 6)
  )
  dn <- quiet_dynet(
    edges, directed = FALSE, observation_start = 0, observation_end = 10
  )
  ledger <- Dynet:::.formation_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(ledger,
               c(formations = 1, inactive_exposure = 3,
                 formation_rate = 1 / 3))
  expect_equal(dyn_events(
    dn, measure = "formation", step = 10, window = 10
  )$value, 5)

  split <- quiet_dynet(
    data.frame(from = "A", to = "B", start = c(2, 5), end = c(5, 9)),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  unsplit <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 2, end = 9),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  expect_equal(.t03_value(split), .t03_value(unsplit))
})

test_that("T03 onset censoring changes confirmation but not state exposure", {
  edges <- data.frame(
    from = "A", to = "B", start = c(2, 4, 8, 8), end = c(4, 6, 9, 9),
    left = c(TRUE, FALSE, FALSE, TRUE),
    right = c(FALSE, FALSE, TRUE, FALSE)
  )
  dn <- quiet_dynet(
    edges, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  ledger <- Dynet:::.formation_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(ledger,
               c(formations = 1, inactive_exposure = 15,
                 formation_rate = 1 / 15))

  all_censored <- transform(edges, left = c(TRUE, FALSE, TRUE, TRUE))
  all_censored_dn <- quiet_dynet(
    all_censored, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t03_value(all_censored_dn), 0)

  one_known_at_two <- rbind(edges, transform(edges[1, ], left = FALSE))
  known_dn <- quiet_dynet(
    one_known_at_two, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t03_value(known_dn), 2 / 15)

  flipped_right <- transform(edges, right = !right)
  right_dn <- quiet_dynet(
    flipped_right, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t03_value(right_dn), 1 / 15)
})

test_that("T03 observation components and vertex changes cut exposure exactly", {
  edges <- data.frame(
    from = c("A", "A", "B"), to = c("B", "C", "A"),
    start = c(2, 6, 5), end = c(6, 9, 8)
  )
  activity <- data.frame(
    node = c("B", "C"), start = c(0, 2), end = c(7, 10)
  )
  dn <- quiet_dynet(
    edges, vertex_spells = activity,
    observation_spells = data.frame(start = c(0, 5), end = c(3, 10))
  )
  out <- dyn_events(
    dn, measure = "formation_rate", step = 10, window = 10
  )
  expect_identical(out$time, c(0, 5))
  expect_identical(out$observation, c(1L, 2L))
  expect_equal(out$value, c(1 / 9, 1 / 12))

  first <- Dynet:::.formation_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 3, closed = TRUE), "collapse"
  )
  second <- Dynet:::.formation_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 5, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(first,
               c(formations = 1, inactive_exposure = 9,
                 formation_rate = 1 / 9))
  expect_equal(second,
               c(formations = 1, inactive_exposure = 12,
                 formation_rate = 1 / 12))
  expect_equal((first[["formations"]] + second[["formations"]]) /
                 (first[["inactive_exposure"]] +
                    second[["inactive_exposure"]]), 2 / 21)
  expect_false(isTRUE(all.equal(mean(out$value), 2 / 21)))
})

test_that("T03 window ownership and additive ledgers are exact", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = c(1, 5), end = c(4, 9)),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  whole <- Dynet:::.formation_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 10, closed = TRUE), "collapse"
  )
  first <- Dynet:::.formation_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 5, closed = FALSE), "collapse"
  )
  second <- Dynet:::.formation_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 5, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(whole,
               c(formations = 2, inactive_exposure = 3,
                 formation_rate = 2 / 3))
  expect_equal(first,
               c(formations = 1, inactive_exposure = 2,
                 formation_rate = 1 / 2))
  expect_equal(second,
               c(formations = 1, inactive_exposure = 1,
                 formation_rate = 1))
  expect_equal(whole[["formations"]],
               first[["formations"]] + second[["formations"]])
  expect_equal(whole[["inactive_exposure"]],
               first[["inactive_exposure"]] + second[["inactive_exposure"]])

  first_public <- dyn_events(
    dn, measure = "formation_rate", start = 0, end = 0,
    step = 5, window = 5
  )
  second_public <- dyn_events(
    dn, measure = "formation_rate", start = 5, end = 5,
    step = 5, window = 5
  )
  expect_equal(first_public$value, 1 / 2)
  expect_equal(second_public$value, 1)
})

test_that("T03 session policies integrate union risk without cross-authorization", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(4, 0), end = c(8, 6), wave = c("s1", "s2")
  )
  dn <- quiet_dynet(
    edges, session = "wave", observation_start = 0, observation_end = 10
  )
  expect_equal(.t03_value(dn, "collapse"), 0)
  expect_equal(.t03_value(dn, "bounded"), 0)
  separate <- dyn_events(
    dn, measure = "formation_rate", sessions = "separate",
    step = 10, window = 10
  )
  expect_equal(separate$value[separate$session == "s1"], 1 / 16)
  expect_equal(separate$value[separate$session == "s2"], 0)

  permuted <- edges[c(2, 1), ]
  permuted$wave <- c("alpha", "omega")
  permuted_dn <- quiet_dynet(
    permuted, session = "wave", observation_start = 0, observation_end = 10
  )
  expect_equal(.t03_value(permuted_dn, "collapse"),
               .t03_value(dn, "collapse"))
  expect_equal(.t03_value(permuted_dn, "bounded"),
               .t03_value(dn, "bounded"))
  permuted_separate <- dyn_events(
    permuted_dn, measure = "formation_rate", sessions = "separate",
    step = 10, window = 10
  )
  expect_equal(sort(permuted_separate$value), sort(separate$value))

  cross_edges <- data.frame(
    from = c("A", "A"), to = c("B", "A"),
    start = c(2, -1), end = c(5, -1), wave = c("s1", "s2")
  )
  activity <- data.frame(
    node = c("A", "B"), start = 0, end = 10, session = "s2"
  )
  cross <- quiet_dynet(
    cross_edges, session = "wave", loops = TRUE,
    vertex_spells = activity, observation_start = 0, observation_end = 10
  )
  expect_equal(.t03_value(cross, "collapse"), 1 / 17)
  expect_equal(.t03_value(cross, "bounded"), 0)
  cross_separate <- dyn_events(
    cross, measure = "formation_rate", sessions = "separate",
    step = 10, window = 10
  )
  expect_true(is.na(cross_separate$value[cross_separate$session == "s1"]))
  expect_equal(cross_separate$value[cross_separate$session == "s2"], 0)
})

test_that("T03 defines positive zero and zero-exposure results", {
  absent <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  expect_equal(.t03_value(absent), 0)

  active <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 10),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t03_value(active)))

  boundary <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 10),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  boundary_ledger <- Dynet:::.formation_rate_ledger(
    boundary, Dynet:::.encode(boundary),
    data.frame(lo = 5, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(boundary_ledger[["formations"]], 1)
  expect_equal(boundary_ledger[["inactive_exposure"]], 0)
  expect_true(is.na(boundary_ledger[["formation_rate"]]))

  singleton <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 10),
    loops = TRUE, observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t03_value(singleton)))

  point_observation <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    observation_start = 5, observation_end = 5
  )
  expect_true(is.na(.t03_value(
    point_observation, step = 1, window = 1
  )))
})

test_that("T03 transformations preserve numerator and rescale inverse time", {
  edges <- .t03_core_edges()
  make <- function(data = edges, multiplier = 1, offset = 0,
                   labels = c("A", "B", "C"), directed = TRUE) {
    data$start <- data$start * multiplier + offset
    data$end <- data$end * multiplier + offset
    old <- c("A", "B", "C")
    data$from <- labels[match(data$from, old)]
    data$to <- labels[match(data$to, old)]
    quiet_dynet(
      data, directed = directed, loops = TRUE,
      onset_censored = "onset_unknown", weight = "weight",
      observation_start = offset, observation_end = 10 * multiplier + offset
    )
  }
  base <- .t03_value(make())
  expect_equal(.t03_value(make(edges[c(8, 2, 6, 1, 9, 4, 7, 3, 5), ])),
               base)
  expect_equal(.t03_value(make(labels = c("", "y", "z"))), base)
  scaled <- .t03_value(
    make(multiplier = 3, offset = 11), step = 30, window = 30
  )
  expect_equal(scaled, base / 3)

  reweighted <- edges
  reweighted$weight <- c(-100, 0, 1e6, 2, 4, 7, 9, 11, 13)
  expect_equal(.t03_value(make(reweighted)), base)

  transposed <- edges
  transposed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.t03_value(make(transposed)), base)

  undirected <- .t03_value(make(directed = FALSE))
  reversed <- edges
  reversed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.t03_value(make(reversed, directed = FALSE)), undirected)
})

test_that("T03 reports calendar inverse units", {
  origin <- as.Date("2026-01-01")
  dn <- quiet_dynet(
    data.frame(
      from = "A", to = "B", start = origin + 2, end = origin + 4
    ), directed = FALSE, time_unit = "days",
    observation_start = origin, observation_end = origin + 10
  )
  out <- dyn_events(
    dn, measure = "formation_rate", step = 10, window = 10
  )
  expect_equal(out$value, 1 / 8)
  expect_identical(attr(out, "transition_unit"), "per_days")

  clock <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  hourly <- quiet_dynet(
    data.frame(
      from = "A", to = "B", start = clock + 2 * 3600,
      end = clock + 4 * 3600
    ), directed = FALSE, time_unit = "hours",
    observation_start = clock, observation_end = clock + 10 * 3600
  )
  hourly_out <- dyn_events(
    hourly, measure = "formation_rate", step = 10, window = 10
  )
  expect_equal(hourly_out$value, 1 / 8)
  expect_identical(attr(hourly_out, "transition_unit"), "per_hours")
})

test_that("T03 enforces positive compatible windows and exposes metadata", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 2),
    observation_start = 0, observation_end = 3
  )
  expect_error(
    dyn_events(dn, measure = "formation_rate", window = 0),
    class = "dynet_rate_requires_positive_window"
  )
  expect_error(
    dyn_events(
      dn, measure = c("formation_fraction", "formation_rate"), window = 0
    ), class = "dynet_incompatible_transition_windows"
  )
  expect_error(
    dyn_events(
      dn, measure = c("dissolution_fraction", "formation_rate"), window = 1
    ), class = "dynet_incompatible_transition_windows"
  )

  single <- dyn_events(
    dn, measure = "formation_rate", start = 0, end = 0,
    step = 3, window = 3
  )
  expect_identical(names(single), c("time", "measure", "value"))
  expect_type(single$value, "double")
  expect_identical(attr(single, "what"), "Formation transition rate")
  expect_identical(Dynet:::.event_label("formation_rate"),
                   "Formation transition rate")
  expect_identical(attr(single, "measure_scope"),
                   c(formation_rate = "whole_window_exact"))
  expect_identical(attr(single, "event_identity"),
                   "binary_pair_union_transition")
  expect_identical(attr(single, "transition"), "inactive_to_active")
  expect_identical(
    attr(single, "transition_numerator"),
    "confirmed_pair_formations_in_window"
  )
  expect_identical(
    attr(single, "risk_set"),
    "integrated_eligible_inactive_nonloop_pair_time"
  )
  expect_identical(
    attr(single, "transition_denominator"),
    "integrated_eligible_inactive_nonloop_pair_time"
  )
  expect_identical(
    attr(single, "confirmation"),
    "at_least_one_uncensored_positive_raw_onset"
  )
  expect_identical(attr(single, "risk_clock"), "positive_observed_time")
  expect_identical(attr(single, "risk_integration"), "exact_change_point")
  expect_identical(attr(single, "batching"), "all_boundaries_at_timestamp")
  expect_identical(attr(single, "interval_state"),
                   "half_open_one_sided_limits")
  expect_identical(attr(single, "points"), "impulses_excluded")
  expect_identical(attr(single, "weights"), "ignored")
  expect_identical(attr(single, "window_rule"), "positive_window_only")
  expect_identical(attr(single, "transition_unit"), "per_step")
  expect_identical(attr(single, "opportunity_domain"),
                   "eligible_nonloop_ordered_pairs")
  expect_identical(attr(single, "transition_session_aggregation"),
                   "labels_erased_calendar_union")

  mixed <- dyn_events(
    dn, measure = c("formation", "formation_rate"), start = 0, end = 0,
    step = 3, window = 3
  )
  expect_identical(attr(mixed, "measure_scope"), c(
    formation = "raw_event_window", formation_rate = "whole_window_exact"
  ))
  expect_identical(attr(mixed, "event_identity"), c(
    formation = "uncensored_raw_spell_start",
    formation_rate = "binary_pair_union_transition"
  ))
  expect_identical(attr(mixed, "transition_numerator"), c(
    formation_rate = "confirmed_pair_formations_in_window"
  ))
  expect_identical(attr(mixed, "transition_denominator"), c(
    formation_rate = "integrated_eligible_inactive_nonloop_pair_time"
  ))
  expect_identical(attr(mixed, "transition_unit"), c(
    formation_rate = "per_step"
  ))
})
