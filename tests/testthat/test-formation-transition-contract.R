.t01_value <- function(dn, time, sessions = "bounded") {
  events(
    dn, measure = "formation_fraction", sessions = sessions,
    start = time, end = time, step = 1, window = 0
  )$value
}

test_that("T01 literal batch counts confirmed pair formations rather than starts", {
  edges <- data.frame(
    from = c("A", "A", "A", "A", "B", "C", "C"),
    to = c("B", "B", "C", "C", "C", "A", "B"),
    start = c(0, 1, 1, 1, .5, 1, 1),
    end = c(1, 2, 2, 2, 1.5, 1, 2),
    onset_unknown = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE)
  )
  directed <- quiet_dynet(
    edges, onset_censored = "onset_unknown",
    observation_start = 0, observation_end = 3
  )
  undirected <- quiet_dynet(
    edges, directed = FALSE, onset_censored = "onset_unknown",
    observation_start = 0, observation_end = 3
  )

  expect_equal(.t01_value(directed, 1), 1 / 4)
  expect_equal(.t01_value(undirected, 1), 1)
  expect_equal(events(
    directed, measure = "formation", start = 1, end = 1, window = 0
  )$value, 4)
})

test_that("T01 direct ledger exposes exact one-sided pair sets", {
  edges <- data.frame(
    from = c("A", "A", "A", "A", "B", "C", "C"),
    to = c("B", "B", "C", "C", "C", "A", "B"),
    start = c(0, 1, 1, 1, .5, 1, 1),
    end = c(1, 2, 2, 2, 1.5, 1, 2),
    onset_unknown = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE)
  )
  dn <- quiet_dynet(
    edges, onset_censored = "onset_unknown",
    observation_start = 0, observation_end = 3
  )
  ledger <- Dynet:::.transition_pair_ledger(
    dn, Dynet:::.encode(dn), 1, "collapse"
  )
  expect_identical(ledger$eligible_before, c(2L, 3L, 4L, 6L, 7L, 8L))
  expect_identical(ledger$eligible_after, c(2L, 3L, 4L, 6L, 7L, 8L))
  expect_identical(ledger$two_sided, c(2L, 3L, 4L, 6L, 7L, 8L))
  expect_identical(ledger$active_before, c(2L, 6L))
  expect_identical(ledger$active_after, c(2L, 3L, 6L, 8L))
  expect_identical(ledger$formation_risk, c(3L, 4L, 7L, 8L))
  expect_identical(ledger$formations, 3L)
  expect_identical(ledger$counts,
                   c(formation_risk = 4L, formations = 1L))

  undirected <- quiet_dynet(
    edges, directed = FALSE, onset_censored = "onset_unknown",
    observation_start = 0, observation_end = 3
  )
  undirected_ledger <- Dynet:::.transition_pair_ledger(
    undirected, Dynet:::.encode(undirected), 1, "collapse"
  )
  expect_identical(undirected_ledger$active_before, c(2L, 6L))
  expect_identical(undirected_ledger$active_after, c(2L, 3L, 6L))
  expect_identical(undirected_ledger$formation_risk, 3L)
  expect_identical(undirected_ledger$formations, 3L)

  expect_false(Dynet:::.one_sided_observation(dn, 0, "before"))
  expect_true(Dynet:::.one_sided_observation(dn, 0, "after"))
  expect_true(Dynet:::.one_sided_observation(dn, 3, "before"))
  expect_false(Dynet:::.one_sided_observation(dn, 3, "after"))

  activity_dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 3),
    vertex_spells = data.frame(node = "B", start = 1, end = 2),
    observation_start = 0, observation_end = 3
  )
  activity <- Dynet:::.encode_vertex_activity(activity_dn)
  expect_identical(
    Dynet:::.one_sided_vertex_eligibility(activity, 1, "before"),
    c(TRUE, FALSE)
  )
  expect_identical(
    Dynet:::.one_sided_vertex_eligibility(activity, 1, "after"),
    c(TRUE, TRUE)
  )
  expect_identical(
    Dynet:::.one_sided_vertex_eligibility(activity, 2, "before"),
    c(TRUE, TRUE)
  )
  expect_identical(
    Dynet:::.one_sided_vertex_eligibility(activity, 2, "after"),
    c(TRUE, FALSE)
  )
})

test_that("T01 distinguishes first, recurrent, dissolution, and non-change times", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 5), end = c(2, 8)
  )
  directed <- quiet_dynet(
    edges, observation_start = -1, observation_end = 10
  )
  values <- vapply(c(0, 1, 2, 5), function(time) {
    .t01_value(directed, time)
  }, numeric(1L))
  expect_equal(values, c(1 / 2, 0, 0, 1 / 2))

  undirected <- quiet_dynet(
    edges, directed = FALSE, observation_start = -1, observation_end = 10
  )
  expect_equal(.t01_value(undirected, 0), 1)
  expect_true(is.na(.t01_value(undirected, 1)))
  expect_true(is.na(.t01_value(undirected, 2)))
  expect_equal(.t01_value(undirected, 5), 1)
})

test_that("T01 unions overlaps, duplicates, adjacent replacements, and points", {
  overlap <- quiet_dynet(
    data.frame(
      from = "A", to = "B", start = c(0, 2, 2, 2),
      end = c(7, 5, 6, 2)
    ), observation_start = 0, observation_end = 8
  )
  expect_equal(.t01_value(overlap, 2), 0)

  adjacent <- quiet_dynet(
    data.frame(from = "A", to = "B", start = c(0, 2), end = c(2, 4)),
    observation_start = 0, observation_end = 4
  )
  expect_equal(.t01_value(adjacent, 2), 0)

  duplicate <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = c(7, 8, 9)),
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(duplicate, 5), 1 / 2)

  point <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(point, 5), 0)
})

test_that("T01 confirmation uses onset censoring only", {
  censored <- data.frame(
    from = "A", to = "B", start = 5, end = 8,
    left = TRUE, right = FALSE
  )
  only <- quiet_dynet(
    censored, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(only, 5), 0)

  mixed <- rbind(censored, transform(censored, left = FALSE))
  mixed_dn <- quiet_dynet(
    mixed, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(mixed_dn, 5), 1 / 2)

  right_only <- transform(censored, left = FALSE, right = TRUE)
  right_dn <- quiet_dynet(
    right_only, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(right_dn, 5), 1 / 2)
})

test_that("T01 defines empty, full, loop, and singleton risk", {
  absent_complete <- expand.grid(
    from = c("A", "B", "C"), to = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )
  absent_complete <- absent_complete[
    absent_complete$from != absent_complete$to, , drop = FALSE
  ]
  absent_complete$start <- 5
  absent_complete$end <- 8
  all_form <- quiet_dynet(
    absent_complete, observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(all_form, 5), 1)

  full <- transform(absent_complete, start = 0, end = 8)
  full <- rbind(full, transform(absent_complete[1, ], start = 5, end = 7))
  full_dn <- quiet_dynet(full, observation_start = 0, observation_end = 10)
  expect_true(is.na(.t01_value(full_dn, 5)))

  loop <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 5, end = 8),
    vertex_spells = data.frame(node = "B", start = 0, end = 10),
    loops = TRUE, observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(loop, 5), 0)

  singleton <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 5, end = 8),
    loops = TRUE, observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t01_value(singleton, 5)))
})

test_that("T01 excludes vertex and observation boundary pseudo-transitions", {
  entry <- quiet_dynet(
    data.frame(
      from = c("A", "C"), to = c("B", "C"),
      start = c(5, -1), end = c(8, -1)
    ), loops = TRUE,
    vertex_spells = data.frame(node = "B", start = 5, end = 10),
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(entry, 5), 0)

  exit <- quiet_dynet(
    data.frame(
      from = c("A", "C"), to = c("B", "C"),
      start = c(5, -1), end = c(8, -1)
    ), loops = TRUE,
    vertex_spells = data.frame(node = "B", start = 0, end = 5),
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(exit, 5), 0)

  gap <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 4, end = 8),
    observation_spells = data.frame(start = c(0, 6), end = c(4, 10))
  )
  expect_true(is.na(.t01_value(gap, 4)))
  expect_true(is.na(.t01_value(gap, 6)))

  outer <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 10),
    observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t01_value(outer, 0)))
  expect_true(is.na(.t01_value(outer, 10)))

  point_observation <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    observation_start = 5, observation_end = 5
  )
  expect_true(is.na(.t01_value(point_observation, 5)))
})

test_that("T01 bounded union state masks local formation without cross-authorization", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 5), end = c(10, 9), wave = c("s1", "s2")
  )
  dn <- quiet_dynet(
    edges, session = "wave", observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(dn, 5, "collapse"), 0)
  expect_equal(.t01_value(dn, 5, "bounded"), 0)
  separate <- events(
    dn, measure = "formation_fraction", sessions = "separate",
    start = 5, end = 5, window = 0
  )
  expect_equal(separate$value[separate$session == "s1"], 0)
  expect_equal(separate$value[separate$session == "s2"], 1 / 2)

  permuted_edges <- edges[c(2, 1), ]
  permuted_edges$wave <- c("alpha", "omega")
  permuted <- quiet_dynet(
    permuted_edges, session = "wave",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(permuted, 5, "collapse"),
               .t01_value(dn, 5, "collapse"))
  expect_equal(.t01_value(permuted, 5, "bounded"),
               .t01_value(dn, 5, "bounded"))
  permuted_separate <- events(
    permuted, measure = "formation_fraction", sessions = "separate",
    start = 5, end = 5, window = 0
  )
  expect_equal(
    sort(permuted_separate$value), sort(separate$value)
  )

  cross_edges <- data.frame(
    from = c("A", "A"), to = c("B", "A"),
    start = c(5, 1), end = c(8, 1), wave = c("s1", "s2")
  )
  activity <- data.frame(
    node = c("A", "B"), start = 0, end = 10, session = "s2"
  )
  cross <- quiet_dynet(
    cross_edges, session = "wave", loops = TRUE,
    vertex_spells = activity, observation_start = 0, observation_end = 10
  )
  expect_equal(.t01_value(cross, 5, "collapse"), 1 / 2)
  expect_equal(.t01_value(cross, 5, "bounded"), 0)
  cross_separate <- events(
    cross, measure = "formation_fraction", sessions = "separate",
    start = 5, end = 5, window = 0
  )
  expect_true(is.na(cross_separate$value[cross_separate$session == "s1"]))
  expect_equal(cross_separate$value[cross_separate$session == "s2"], 0)
})

test_that("T01 transformations preserve fraction and pair-state identity", {
  edges <- data.frame(
    from = c("A", "A", "B", "C"), to = c("B", "C", "A", "B"),
    start = c(5, 5, 2, 0), end = c(9, 8, 8, 5), weight = c(1, 9, 3, 4)
  )
  make <- function(data = edges, multiplier = 1, offset = 0,
                   labels = c("A", "B", "C"), directed = TRUE) {
    data$start <- data$start * multiplier + offset
    data$end <- data$end * multiplier + offset
    old <- c("A", "B", "C")
    data$from <- labels[match(data$from, old)]
    data$to <- labels[match(data$to, old)]
    quiet_dynet(
      data, directed = directed, weight = "weight",
      observation_start = offset, observation_end = 10 * multiplier + offset
    )
  }
  base <- .t01_value(make(), 5)
  expect_equal(.t01_value(make(edges[c(4, 2, 1, 3), ]), 5), base)
  expect_equal(.t01_value(make(labels = c("", "y", "z")), 5), base)
  expect_equal(.t01_value(make(multiplier = 3, offset = 11), 26), base)
  reweighted <- edges
  reweighted$weight <- c(-100, 0, 1e6, 2)
  expect_equal(.t01_value(make(reweighted), 5), base)

  transposed <- edges
  transposed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.t01_value(make(transposed), 5), base)

  undirected <- .t01_value(make(directed = FALSE), 5)
  reversed <- edges
  reversed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.t01_value(make(reversed, directed = FALSE), 5), undirected)
})

test_that("T01 enforces exact-time use and exposes typed metadata", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 2),
    observation_start = 0, observation_end = 3
  )
  expect_error(
    events(dn, measure = "formation_fraction"),
    class = "dynet_transition_requires_instant"
  )
  expect_error(
    events(
      dn, measure = c("formation", "formation_fraction"), window = 1
    ), class = "dynet_transition_requires_instant"
  )

  out <- events(
    dn, measure = c("formation", "formation_fraction"),
    start = 1, end = 1, window = 0
  )
  expect_identical(names(out), c("time", "measure", "value"))
  expect_identical(out$measure, c("formation", "formation_fraction"))
  expect_type(out$value, "double")
  expect_equal(out$value, c(1, 1 / 2))
  expect_identical(attr(out, "measure_scope"), stats::setNames(
    c("raw_event_at_time", "binary_pair_transition_at_time"),
    c("formation", "formation_fraction")
  ))
  expect_identical(attr(out, "event_identity"), stats::setNames(
    c("uncensored_raw_spell_start", "binary_pair_union_transition"),
    c("formation", "formation_fraction")
  ))
  expect_identical(attr(out, "risk_set"),
                   "two_sided_eligible_inactive_prestate_nonloop_pairs")
  expect_identical(attr(out, "transition_grid"),
                   "requested_exact_times_not_auto_change_points")
  expect_identical(attr(out, "window_rule"), "exact_time_only")
  expect_identical(attr(out, "opportunity_domain"),
                   "eligible_nonloop_ordered_pairs")
  expect_identical(attr(out, "transition"), "inactive_to_active")
  expect_identical(attr(out, "batching"), "all_boundaries_at_timestamp")
  expect_identical(attr(out, "interval_state"), "half_open_one_sided_limits")
  expect_identical(
    attr(out, "confirmation"),
    "at_least_one_uncensored_positive_raw_onset"
  )
  expect_identical(attr(out, "points"), "impulses_excluded")
  expect_identical(attr(out, "weights"), "ignored")
  expect_identical(attr(out, "transition_unit"), "probability")
  expect_identical(
    attr(out, "transition_session_aggregation"),
    "labels_erased_calendar_union"
  )

  undirected <- quiet_dynet(
    data.frame(from = "B", to = "A", start = 1, end = 2),
    directed = FALSE, observation_start = 0, observation_end = 3
  )
  undirected_out <- events(
    undirected, measure = "formation_fraction",
    start = 1, end = 1, window = 0
  )
  expect_identical(attr(undirected_out, "opportunity_domain"),
                   "eligible_nonloop_unordered_dyads")

  sessioned <- quiet_dynet(
    data.frame(
      from = c("A", "A"), to = c("B", "B"), start = c(0, 1),
      end = c(3, 2), wave = c("s1", "s2")
    ), session = "wave", observation_start = 0, observation_end = 3
  )
  bounded <- events(
    sessioned, measure = "formation_fraction", sessions = "bounded",
    start = 1, end = 1, window = 0
  )
  separate <- events(
    sessioned, measure = "formation_fraction", sessions = "separate",
    start = 1, end = 1, window = 0
  )
  expect_identical(
    attr(bounded, "transition_session_aggregation"),
    "session_local_then_calendar_union"
  )
  expect_identical(attr(separate, "transition_session_aggregation"),
                   "session_local")
  single <- events(
    dn, measure = "formation_fraction", start = 1, end = 1, window = 0
  )
  expect_identical(attr(single, "what"), "Formation transition fraction")
  expect_identical(Dynet:::.event_label("formation_fraction"),
                   "Formation transition fraction")
})
