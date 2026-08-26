.t04_value <- function(dn, sessions = "bounded", start = NULL, end = NULL,
                       step = 10, window = 10) {
  events(
    dn, measure = "dissolution_rate", sessions = sessions,
    start = start, end = end, step = step, window = window
  )$value
}

.t04_core_edges <- function() {
  data.frame(
    from = c("A", "A", "A", "B", "B", "C", "C", "C", "A"),
    to = c("B", "B", "C", "A", "C", "A", "A", "B", "A"),
    start = c(0, 4, 0, 1, 5, 2, 2, 3, 0),
    end = c(2, 8, 10, 5, 5, 6, 6, 7, 10),
    terminus_unknown = c(FALSE, FALSE, FALSE, FALSE, FALSE,
                         FALSE, FALSE, TRUE, FALSE),
    weight = c(1, 2, 3, 4, 5, 6, 7, 8, 100)
  )
}

test_that("T04 literal ledger integrates keyed active exposure exactly", {
  edges <- .t04_core_edges()
  directed <- quiet_dynet(
    edges, loops = TRUE, terminus_censored = "terminus_unknown",
    weight = "weight", observation_start = 0, observation_end = 10
  )
  undirected <- quiet_dynet(
    edges, directed = FALSE, loops = TRUE,
    terminus_censored = "terminus_unknown", weight = "weight",
    observation_start = 0, observation_end = 10
  )

  directed_exposure <- c(
    `A->B` = 6, `A->C` = 10, `B->A` = 4,
    `B->C` = 0, `C->A` = 4, `C->B` = 4
  )
  undirected_exposure <- c(`A--B` = 8, `A--C` = 10, `B--C` = 4)
  expect_identical(directed_exposure, c(
    `A->B` = 6, `A->C` = 10, `B->A` = 4,
    `B->C` = 0, `C->A` = 4, `C->B` = 4
  ))
  expect_identical(undirected_exposure,
                   c(`A--B` = 8, `A--C` = 10, `B--C` = 4))

  bin <- data.frame(lo = 0, hi = 10, closed = TRUE)
  directed_ledger <- Dynet:::.dissolution_rate_ledger(
    directed, Dynet:::.encode(directed), bin, "collapse"
  )
  undirected_ledger <- Dynet:::.dissolution_rate_ledger(
    undirected, Dynet:::.encode(undirected), bin, "collapse"
  )
  expect_identical(names(directed_ledger),
                   c("dissolutions", "active_exposure", "dissolution_rate"))
  expect_type(directed_ledger, "double")
  expect_equal(directed_ledger,
               c(dissolutions = 4, active_exposure = 28,
                 dissolution_rate = 1 / 7))
  expect_equal(undirected_ledger,
               c(dissolutions = 1, active_exposure = 22,
                 dissolution_rate = 1 / 22))
  expect_equal(unname(.t04_value(directed)), 1 / 7)
  expect_equal(unname(.t04_value(undirected)), 1 / 22)
  expect_equal(events(
    directed, measure = "dissolution", step = 10, window = 10
  )$value, 8)
})

test_that("T04 literal numerator is the frozen batch dissolution family", {
  edges <- .t04_core_edges()
  dn <- quiet_dynet(
    edges, loops = TRUE, terminus_censored = "terminus_unknown",
    weight = "weight", observation_start = 0, observation_end = 10
  )
  enc <- Dynet:::.encode(dn)
  expected <- list(`2` = 2L, `5` = 4L, `6` = 7L, `8` = 2L)
  actual <- lapply(as.numeric(names(expected)), function(time) {
    Dynet:::.transition_pair_ledger(
      dn, enc, time, "collapse"
    )$dissolutions
  })
  names(actual) <- names(expected)
  expect_identical(actual, expected)
  expect_identical(
    vapply(actual, length, integer(1L)),
    c(`2` = 1L, `5` = 1L, `6` = 1L, `8` = 1L)
  )
  expect_identical(
    Dynet:::.transition_pair_ledger(dn, enc, 7, "collapse")$dissolutions,
    integer()
  )
  expect_identical(
    Dynet:::.transition_pair_ledger(dn, enc, 10, "collapse")$dissolutions,
    integer()
  )
})

test_that("T04 unions duplicates, overlaps, adjacency, and points", {
  edges <- data.frame(
    from = "A", to = "B",
    start = c(1, 1, 3, 8, 6), end = c(8, 5, 7, 9, 6)
  )
  dn <- quiet_dynet(
    edges, directed = FALSE, observation_start = 0, observation_end = 10
  )
  ledger <- Dynet:::.dissolution_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(ledger,
               c(dissolutions = 1, active_exposure = 8,
                 dissolution_rate = 1 / 8))
  expect_equal(events(
    dn, measure = "dissolution", step = 10, window = 10
  )$value, 5)

  split <- quiet_dynet(
    data.frame(from = "A", to = "B", start = c(1, 5), end = c(5, 9)),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  unsplit <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 9),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  expect_equal(.t04_value(split), .t04_value(unsplit))
})

test_that("T04 terminus censoring changes confirmation but not state exposure", {
  edges <- data.frame(
    from = "A", to = "B", start = c(1, 3, 7, 7), end = c(3, 5, 9, 9),
    left = c(TRUE, FALSE, TRUE, FALSE),
    right = c(FALSE, TRUE, FALSE, TRUE)
  )
  dn <- quiet_dynet(
    edges, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  ledger <- Dynet:::.dissolution_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(ledger,
               c(dissolutions = 1, active_exposure = 6,
                 dissolution_rate = 1 / 6))

  all_censored <- transform(edges, right = TRUE)
  all_censored_dn <- quiet_dynet(
    all_censored, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t04_value(all_censored_dn), 0)

  known_duplicate <- rbind(edges, transform(edges[3, ], right = FALSE))
  duplicate_dn <- quiet_dynet(
    known_duplicate, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t04_value(duplicate_dn), 1 / 6)

  flipped_left <- transform(edges, left = !left)
  left_dn <- quiet_dynet(
    flipped_left, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t04_value(left_dn), 1 / 6)
})

test_that("T04 observation components and vertex changes cut exposure exactly", {
  edges <- data.frame(
    from = c("A", "A", "B"), to = c("B", "C", "A"),
    start = c(0, 5, 5), end = c(2, 8, 7)
  )
  activity <- data.frame(
    node = c("B", "C"), start = c(0, 2), end = c(7, 10)
  )
  dn <- quiet_dynet(
    edges, vertex_spells = activity,
    observation_spells = data.frame(start = c(0, 5), end = c(3, 10))
  )
  out <- events(
    dn, measure = "dissolution_rate", step = 10, window = 10
  )
  expect_identical(out$time, c(0, 5))
  expect_identical(out$observation, c(1L, 2L))
  expect_equal(out$value, c(1 / 2, 1 / 5))

  first <- Dynet:::.dissolution_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 3, closed = TRUE), "collapse"
  )
  second <- Dynet:::.dissolution_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 5, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(first,
               c(dissolutions = 1, active_exposure = 2,
                 dissolution_rate = 1 / 2))
  expect_equal(second,
               c(dissolutions = 1, active_exposure = 5,
                 dissolution_rate = 1 / 5))
  expect_equal((first[["dissolutions"]] + second[["dissolutions"]]) /
                 (first[["active_exposure"]] + second[["active_exposure"]]),
               2 / 7)
  expect_false(isTRUE(all.equal(mean(out$value), 2 / 7)))
})

test_that("T04 window ownership and additive ledgers are exact", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = c(1, 5), end = c(4, 9)),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  whole <- Dynet:::.dissolution_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 10, closed = TRUE), "collapse"
  )
  first <- Dynet:::.dissolution_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 0, hi = 5, closed = FALSE), "collapse"
  )
  second <- Dynet:::.dissolution_rate_ledger(
    dn, Dynet:::.encode(dn),
    data.frame(lo = 5, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(whole,
               c(dissolutions = 2, active_exposure = 7,
                 dissolution_rate = 2 / 7))
  expect_equal(first,
               c(dissolutions = 1, active_exposure = 3,
                 dissolution_rate = 1 / 3))
  expect_equal(second,
               c(dissolutions = 1, active_exposure = 4,
                 dissolution_rate = 1 / 4))
  expect_equal(whole[["dissolutions"]],
               first[["dissolutions"]] + second[["dissolutions"]])
  expect_equal(whole[["active_exposure"]],
               first[["active_exposure"]] + second[["active_exposure"]])

  first_public <- events(
    dn, measure = "dissolution_rate", start = 0, end = 0,
    step = 5, window = 5
  )
  second_public <- events(
    dn, measure = "dissolution_rate", start = 5, end = 5,
    step = 5, window = 5
  )
  expect_equal(first_public$value, 1 / 3)
  expect_equal(second_public$value, 1 / 4)

  boundary <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 5),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  default_bins <- events(
    boundary, measure = "dissolution_rate", step = 5, window = 5
  )
  expect_equal(default_bins$value[[1L]], 0)
  expect_true(is.na(default_bins$value[[2L]]))
})

test_that("T04 session policies integrate active union without cross-authorization", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 0), end = c(5, 10), wave = c("s1", "s2")
  )
  dn <- quiet_dynet(
    edges, session = "wave", observation_start = 0, observation_end = 10
  )
  expect_equal(.t04_value(dn, "collapse"), 0)
  expect_equal(.t04_value(dn, "bounded"), 0)
  separate <- events(
    dn, measure = "dissolution_rate", sessions = "separate",
    step = 10, window = 10
  )
  expect_equal(separate$value[separate$session == "s1"], 1 / 5)
  expect_equal(separate$value[separate$session == "s2"], 0)

  permuted <- edges[c(2, 1), ]
  permuted$wave <- c("alpha", "omega")
  permuted_dn <- quiet_dynet(
    permuted, session = "wave", observation_start = 0, observation_end = 10
  )
  expect_equal(.t04_value(permuted_dn, "collapse"),
               .t04_value(dn, "collapse"))
  expect_equal(.t04_value(permuted_dn, "bounded"),
               .t04_value(dn, "bounded"))
  permuted_separate <- events(
    permuted_dn, measure = "dissolution_rate", sessions = "separate",
    step = 10, window = 10
  )
  expect_equal(sort(permuted_separate$value), sort(separate$value))

  cross_edges <- data.frame(
    from = c("A", "B"), to = c("B", "A"),
    start = c(2, 0), end = c(5, 10), wave = c("s1", "s2")
  )
  activity <- data.frame(
    node = c("A", "B"), start = 0, end = 10, session = "s2"
  )
  cross <- quiet_dynet(
    cross_edges, session = "wave", vertex_spells = activity,
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t04_value(cross, "collapse"), 1 / 13)
  expect_equal(.t04_value(cross, "bounded"), 0)
  cross_separate <- events(
    cross, measure = "dissolution_rate", sessions = "separate",
    step = 10, window = 10
  )
  expect_true(is.na(cross_separate$value[cross_separate$session == "s1"]))
  expect_equal(cross_separate$value[cross_separate$session == "s2"], 0)
})

test_that("T04 defines positive zero and zero-exposure results", {
  absent <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t04_value(absent)))

  active <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 10),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  expect_equal(.t04_value(active), 0)

  boundary <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 5),
    directed = FALSE, observation_start = 0, observation_end = 10
  )
  boundary_ledger <- Dynet:::.dissolution_rate_ledger(
    boundary, Dynet:::.encode(boundary),
    data.frame(lo = 5, hi = 10, closed = TRUE), "collapse"
  )
  expect_equal(boundary_ledger[["dissolutions"]], 1)
  expect_equal(boundary_ledger[["active_exposure"]], 0)
  expect_true(is.na(boundary_ledger[["dissolution_rate"]]))

  singleton <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 5),
    loops = TRUE, observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t04_value(singleton)))

  point_observation <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    observation_start = 5, observation_end = 5
  )
  expect_true(is.na(.t04_value(
    point_observation, step = 1, window = 1
  )))
})

test_that("T04 transformations preserve numerator and rescale inverse time", {
  edges <- .t04_core_edges()
  make <- function(data = edges, multiplier = 1, offset = 0,
                   labels = c("A", "B", "C"), directed = TRUE) {
    data$start <- data$start * multiplier + offset
    data$end <- data$end * multiplier + offset
    old <- c("A", "B", "C")
    data$from <- labels[match(data$from, old)]
    data$to <- labels[match(data$to, old)]
    quiet_dynet(
      data, directed = directed, loops = TRUE,
      terminus_censored = "terminus_unknown", weight = "weight",
      observation_start = offset, observation_end = 10 * multiplier + offset
    )
  }
  base <- .t04_value(make())
  expect_equal(.t04_value(make(edges[c(8, 2, 6, 1, 9, 4, 7, 3, 5), ])),
               base)
  expect_equal(.t04_value(make(labels = c("", "y", "z"))), base)
  scaled <- .t04_value(
    make(multiplier = 3, offset = 11), step = 30, window = 30
  )
  expect_equal(scaled, base / 3)

  reweighted <- edges
  reweighted$weight <- c(-100, 0, 1e6, 2, 4, 7, 9, 11, 13)
  expect_equal(.t04_value(make(reweighted)), base)

  transposed <- edges
  transposed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.t04_value(make(transposed)), base)

  undirected <- .t04_value(make(directed = FALSE))
  reversed <- edges
  reversed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.t04_value(make(reversed, directed = FALSE)), undirected)
})

test_that("T04 reports calendar inverse units", {
  origin <- as.Date("2026-01-01")
  dn <- quiet_dynet(
    data.frame(
      from = "A", to = "B", start = origin + 2, end = origin + 4
    ), directed = FALSE, time_unit = "days",
    observation_start = origin, observation_end = origin + 10
  )
  out <- events(
    dn, measure = "dissolution_rate", step = 10, window = 10
  )
  expect_equal(out$value, 1 / 2)
  expect_identical(attr(out, "transition_unit"), "per_days")

  clock <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  hourly <- quiet_dynet(
    data.frame(
      from = "A", to = "B", start = clock + 2 * 3600,
      end = clock + 4 * 3600
    ), directed = FALSE, time_unit = "hours",
    observation_start = clock, observation_end = clock + 10 * 3600
  )
  hourly_out <- events(
    hourly, measure = "dissolution_rate", step = 10, window = 10
  )
  expect_equal(hourly_out$value, 1 / 2)
  expect_identical(attr(hourly_out, "transition_unit"), "per_hours")
})

test_that("T04 enforces positive compatible windows and exposes metadata", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 2),
    observation_start = 0, observation_end = 3
  )
  expect_error(
    events(dn, measure = "dissolution_rate", window = 0),
    class = "dynet_rate_requires_positive_window"
  )
  expect_error(
    events(
      dn, measure = c("dissolution_fraction", "dissolution_rate"), window = 0
    ), class = "dynet_incompatible_transition_windows"
  )
  expect_error(
    events(
      dn, measure = c("formation_fraction", "dissolution_rate"), window = 1
    ), class = "dynet_incompatible_transition_windows"
  )

  single <- events(
    dn, measure = "dissolution_rate", start = 0, end = 0,
    step = 3, window = 3
  )
  expect_identical(names(single), c("time", "measure", "value"))
  expect_type(single$value, "double")
  expect_identical(attr(single, "what"), "Dissolution transition rate")
  expect_identical(Dynet:::.event_label("dissolution_rate"),
                   "Dissolution transition rate")
  expect_identical(attr(single, "measure_scope"),
                   c(dissolution_rate = "whole_window_exact"))
  expect_identical(attr(single, "event_identity"),
                   "binary_pair_union_transition")
  expect_identical(attr(single, "transition"), "active_to_inactive")
  expect_identical(
    attr(single, "transition_numerator"),
    "confirmed_pair_dissolutions_in_window"
  )
  expect_identical(
    attr(single, "risk_set"),
    "integrated_eligible_active_nonloop_pair_time"
  )
  expect_identical(
    attr(single, "transition_denominator"),
    "integrated_eligible_active_nonloop_pair_time"
  )
  expect_identical(
    attr(single, "confirmation"),
    "at_least_one_uncensored_positive_raw_terminus"
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

  mixed <- events(
    dn, measure = c("formation_rate", "dissolution_rate"),
    start = 0, end = 0, step = 3, window = 3
  )
  expect_identical(attr(mixed, "measure_scope"), c(
    formation_rate = "whole_window_exact",
    dissolution_rate = "whole_window_exact"
  ))
  expect_identical(attr(mixed, "event_identity"), c(
    formation_rate = "binary_pair_union_transition",
    dissolution_rate = "binary_pair_union_transition"
  ))
  expect_identical(attr(mixed, "transition"), c(
    formation_rate = "inactive_to_active",
    dissolution_rate = "active_to_inactive"
  ))
  expect_identical(attr(mixed, "risk_set"), c(
    formation_rate = "integrated_eligible_inactive_nonloop_pair_time",
    dissolution_rate = "integrated_eligible_active_nonloop_pair_time"
  ))
  expect_identical(attr(mixed, "confirmation"), c(
    formation_rate = "at_least_one_uncensored_positive_raw_onset",
    dissolution_rate = "at_least_one_uncensored_positive_raw_terminus"
  ))
  expect_identical(attr(mixed, "transition_numerator"), c(
    formation_rate = "confirmed_pair_formations_in_window",
    dissolution_rate = "confirmed_pair_dissolutions_in_window"
  ))
  expect_identical(attr(mixed, "transition_denominator"), c(
    formation_rate = "integrated_eligible_inactive_nonloop_pair_time",
    dissolution_rate = "integrated_eligible_active_nonloop_pair_time"
  ))
  expect_identical(attr(mixed, "transition_unit"), c(
    formation_rate = "per_step", dissolution_rate = "per_step"
  ))
})
