.t02_value <- function(dn, time, sessions = "bounded") {
  dyn_events(
    dn, measure = "dissolution_fraction", sessions = sessions,
    start = time, end = time, step = 1, window = 0
  )$value
}

test_that("T02 literal batch counts confirmed pair dissolutions rather than termini", {
  edges <- data.frame(
    from = c("A", "A", "A", "A", "B", "B", "B", "C", "C", "A"),
    to = c("B", "B", "C", "C", "A", "A", "C", "A", "B", "A"),
    start = c(0, 1, 0, 0, 0, 0, .5, 1, 0, 0),
    end = c(1, 2, 1, 1, 2, 1, 1.5, 1, 1, 1),
    terminus_unknown = c(
      FALSE, FALSE, FALSE, FALSE, FALSE,
      FALSE, FALSE, FALSE, TRUE, FALSE
    )
  )
  directed <- quiet_dynet(
    edges, loops = TRUE, terminus_censored = "terminus_unknown",
    observation_start = 0, observation_end = 3
  )
  undirected <- quiet_dynet(
    edges, directed = FALSE, loops = TRUE,
    terminus_censored = "terminus_unknown",
    observation_start = 0, observation_end = 3
  )

  expect_equal(.t02_value(directed, 1), 1 / 5)
  expect_equal(.t02_value(undirected, 1), 1 / 3)
  expect_equal(dyn_events(
    directed, measure = "dissolution", start = 1, end = 1, window = 0
  )$value, 6)
})

test_that("T02 direct ledger exposes exact one-sided pair sets and counts", {
  edges <- data.frame(
    from = c("A", "A", "A", "A", "B", "B", "B", "C", "C", "A"),
    to = c("B", "B", "C", "C", "A", "A", "C", "A", "B", "A"),
    start = c(0, 1, 0, 0, 0, 0, .5, 1, 0, 0),
    end = c(1, 2, 1, 1, 2, 1, 1.5, 1, 1, 1),
    right = c(FALSE, FALSE, FALSE, FALSE, FALSE,
              FALSE, FALSE, FALSE, TRUE, FALSE)
  )
  dn <- quiet_dynet(
    edges, loops = TRUE, terminus_censored = "right",
    observation_start = 0, observation_end = 3
  )
  ledger <- Dynet:::.transition_pair_ledger(
    dn, Dynet:::.encode(dn), 1, "collapse"
  )
  expect_identical(ledger$eligible_before, c(2L, 3L, 4L, 6L, 7L, 8L))
  expect_identical(ledger$eligible_after, c(2L, 3L, 4L, 6L, 7L, 8L))
  expect_identical(ledger$two_sided, c(2L, 3L, 4L, 6L, 7L, 8L))
  expect_identical(ledger$active_before, c(2L, 3L, 4L, 6L, 8L))
  expect_identical(ledger$active_after, c(2L, 4L, 6L))
  expect_identical(ledger$terminus_confirmation, c(2L, 3L, 4L))
  expect_identical(ledger$dissolution_risk, c(2L, 3L, 4L, 6L, 8L))
  expect_identical(ledger$dissolutions, 3L)
  expect_identical(
    ledger$dissolution_counts,
    c(dissolution_risk = 5L, dissolutions = 1L)
  )
  expect_identical(
    ledger$counts,
    c(formation_risk = 1L, formations = 0L)
  )

  undirected <- quiet_dynet(
    edges, directed = FALSE, loops = TRUE, terminus_censored = "right",
    observation_start = 0, observation_end = 3
  )
  undirected_ledger <- Dynet:::.transition_pair_ledger(
    undirected, Dynet:::.encode(undirected), 1, "collapse"
  )
  expect_identical(undirected_ledger$active_before, c(2L, 3L, 6L))
  expect_identical(undirected_ledger$active_after, c(2L, 6L))
  expect_identical(undirected_ledger$terminus_confirmation, c(2L, 3L))
  expect_identical(undirected_ledger$dissolution_risk, c(2L, 3L, 6L))
  expect_identical(undirected_ledger$dissolutions, 3L)
  expect_identical(
    undirected_ledger$dissolution_counts,
    c(dissolution_risk = 3L, dissolutions = 1L)
  )
})

test_that("T02 distinguishes stable, recurrent, formation, and dissolution times", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 5), end = c(2, 8)
  )
  directed <- quiet_dynet(
    edges, observation_start = -1, observation_end = 10
  )
  values <- vapply(c(1, 2, 5, 8), function(time) {
    .t02_value(directed, time)
  }, numeric(1L))
  expect_equal(values[c(1, 2, 4)], c(0, 1, 1))
  expect_true(is.na(values[[3L]]))

  undirected <- quiet_dynet(
    edges, directed = FALSE, observation_start = -1, observation_end = 10
  )
  undirected_values <- vapply(c(1, 2, 5, 8), function(time) {
    .t02_value(undirected, time)
  }, numeric(1L))
  expect_equal(undirected_values[c(1, 2, 4)], c(0, 1, 1))
  expect_true(is.na(undirected_values[[3L]]))
})

test_that("T02 unions overlap, adjacent replacement, duplicates, and points", {
  overlap <- quiet_dynet(
    data.frame(
      from = "A", to = "B", start = c(0, 0, 2, 2),
      end = c(7, 2, 6, 2)
    ), observation_start = 0, observation_end = 8
  )
  expect_equal(.t02_value(overlap, 2), 0)

  adjacent <- quiet_dynet(
    data.frame(from = "A", to = "B", start = c(0, 2), end = c(2, 4)),
    observation_start = 0, observation_end = 4
  )
  expect_equal(.t02_value(adjacent, 2), 0)

  duplicate <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = rep(5, 3)),
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(duplicate, 5), 1)

  point <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t02_value(point, 5)))
})

test_that("T02 confirmation uses terminus censoring only", {
  censored <- data.frame(
    from = "A", to = "B", start = 0, end = 5,
    left = FALSE, right = TRUE
  )
  only <- quiet_dynet(
    censored, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(only, 5), 0)

  mixed <- rbind(censored, transform(censored, right = FALSE))
  mixed_dn <- quiet_dynet(
    mixed, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(mixed_dn, 5), 1)

  left_only <- transform(censored, left = TRUE, right = FALSE)
  left_dn <- quiet_dynet(
    left_only, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(left_dn, 5), 1)

  masked <- rbind(
    transform(censored, start = 0, end = 8, right = FALSE),
    transform(censored, start = 1, end = 5, right = FALSE)
  )
  masked_dn <- quiet_dynet(
    masked, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(masked_dn, 5), 0)
})

test_that("T02 defines full, stable, loop, point, and singleton risk", {
  complete <- expand.grid(
    from = c("A", "B", "C"), to = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )
  complete <- complete[complete$from != complete$to, , drop = FALSE]
  complete$start <- 0
  complete$end <- 5
  all_end <- quiet_dynet(
    complete, observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(all_end, 5), 1)

  stable <- transform(complete, end = 8)
  stable_dn <- quiet_dynet(stable, observation_start = 0, observation_end = 10)
  expect_equal(.t02_value(stable_dn, 5), 0)

  loop <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 5),
    vertex_spells = data.frame(node = "B", start = 0, end = 10),
    loops = TRUE, observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t02_value(loop, 5)))

  loop_with_risk <- quiet_dynet(
    data.frame(
      from = c("A", "A"), to = c("A", "B"),
      start = c(0, 0), end = c(5, 8)
    ), loops = TRUE, observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(loop_with_risk, 5), 0)

  singleton <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 5),
    loops = TRUE, observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t02_value(singleton, 5)))
})

test_that("T02 excludes vertex and observation boundary pseudo-dissolutions", {
  exit <- quiet_dynet(
    data.frame(
      from = c("A", "A"), to = c("B", "C"),
      start = c(0, 0), end = c(5, 8)
    ),
    vertex_spells = data.frame(node = "B", start = 0, end = 5),
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(exit, 5), 0)

  entry <- quiet_dynet(
    data.frame(
      from = c("A", "A"), to = c("B", "C"),
      start = c(0, 0), end = c(5, 8)
    ),
    vertex_spells = data.frame(node = "B", start = 5, end = 10),
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(entry, 5), 0)

  gap <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 4),
    observation_spells = data.frame(start = c(0, 6), end = c(4, 10))
  )
  expect_true(is.na(.t02_value(gap, 4)))
  expect_true(is.na(.t02_value(gap, 6)))

  outer <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 10),
    observation_start = 0, observation_end = 10
  )
  expect_true(is.na(.t02_value(outer, 0)))
  expect_true(is.na(.t02_value(outer, 10)))

  adjacent_observation <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 5),
    observation_spells = data.frame(start = c(0, 5), end = c(5, 10))
  )
  expect_equal(.t02_value(adjacent_observation, 5), 1)

  point_observation <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    observation_start = 5, observation_end = 5
  )
  expect_true(is.na(.t02_value(point_observation, 5)))
})

test_that("T02 session modes use frozen union-state and authorization rules", {
  masked_edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 0), end = c(5, 10), wave = c("s1", "s2")
  )
  masked <- quiet_dynet(
    masked_edges, session = "wave", observation_start = 0,
    observation_end = 10
  )
  expect_equal(.t02_value(masked, 5, "collapse"), 0)
  expect_equal(.t02_value(masked, 5, "bounded"), 0)
  separate <- dyn_events(
    masked, measure = "dissolution_fraction", sessions = "separate",
    start = 5, end = 5, window = 0
  )
  expect_equal(separate$value[separate$session == "s1"], 1)
  expect_equal(separate$value[separate$session == "s2"], 0)

  permuted_edges <- masked_edges[c(2, 1), ]
  permuted_edges$wave <- c("alpha", "omega")
  permuted <- quiet_dynet(
    permuted_edges, session = "wave", observation_start = 0,
    observation_end = 10
  )
  expect_equal(.t02_value(permuted, 5, "collapse"),
               .t02_value(masked, 5, "collapse"))
  expect_equal(.t02_value(permuted, 5, "bounded"),
               .t02_value(masked, 5, "bounded"))
  permuted_separate <- dyn_events(
    permuted, measure = "dissolution_fraction", sessions = "separate",
    start = 5, end = 5, window = 0
  )
  expect_equal(sort(permuted_separate$value), sort(separate$value))

  both_end <- transform(masked_edges, end = 5)
  both <- quiet_dynet(
    both_end, session = "wave", observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(both, 5, "collapse"), 1)
  expect_equal(.t02_value(both, 5, "bounded"), 1)
  both_separate <- dyn_events(
    both, measure = "dissolution_fraction", sessions = "separate",
    start = 5, end = 5, window = 0
  )
  expect_equal(both_separate$value, c(1, 1))

  cross_edges <- data.frame(
    from = c("A", "B"), to = c("B", "A"),
    start = 0, end = c(5, 10), wave = c("s1", "s2")
  )
  activity <- data.frame(
    node = c("A", "B"), start = 0, end = 10, session = "s2"
  )
  cross <- quiet_dynet(
    cross_edges, session = "wave", vertex_spells = activity,
    observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(cross, 5, "collapse"), 1 / 2)
  expect_equal(.t02_value(cross, 5, "bounded"), 0)
  cross_separate <- dyn_events(
    cross, measure = "dissolution_fraction", sessions = "separate",
    start = 5, end = 5, window = 0
  )
  expect_true(is.na(cross_separate$value[cross_separate$session == "s1"]))
  expect_equal(cross_separate$value[cross_separate$session == "s2"], 0)

  handoff <- quiet_dynet(
    data.frame(
      from = c("A", "A"), to = c("B", "B"),
      start = c(0, 5), end = c(5, 9), wave = c("s1", "s2")
    ), session = "wave", observation_start = 0, observation_end = 10
  )
  expect_equal(.t02_value(handoff, 5, "collapse"), 0)
  expect_equal(.t02_value(handoff, 5, "bounded"), 0)
})

test_that("T02 transformations preserve fraction and pair-state identity", {
  edges <- data.frame(
    from = c("A", "A", "B", "C"), to = c("B", "C", "A", "B"),
    start = c(0, 0, 0, 2), end = c(5, 5, 8, 8),
    weight = c(1, 9, 3, 4)
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
  base <- .t02_value(make(), 5)
  expect_equal(base, 1 / 2)
  expect_equal(.t02_value(make(edges[c(4, 2, 1, 3), ]), 5), base)
  expect_equal(.t02_value(make(labels = c("", "y", "z")), 5), base)
  expect_equal(.t02_value(make(multiplier = 3, offset = 11), 26), base)
  reweighted <- edges
  reweighted$weight <- c(-100, 0, 1e6, 2)
  expect_equal(.t02_value(make(reweighted), 5), base)

  transposed <- edges
  transposed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.t02_value(make(transposed), 5), base)

  undirected <- .t02_value(make(directed = FALSE), 5)
  reversed <- edges
  reversed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.t02_value(make(reversed, directed = FALSE), 5), undirected)
})

test_that("T02 reflection swaps confirmed dissolution and formation sets", {
  edges <- data.frame(
    from = "A", to = "B", start = 0, end = 1,
    terminus_unknown = FALSE
  )
  original <- quiet_dynet(
    edges, terminus_censored = "terminus_unknown",
    observation_start = 0, observation_end = 2
  )
  reflected_edges <- data.frame(
    from = edges$from, to = edges$to,
    start = 2 - edges$end, end = 2 - edges$start,
    onset_unknown = edges$terminus_unknown
  )
  reflected <- quiet_dynet(
    reflected_edges, onset_censored = "onset_unknown",
    observation_start = 0, observation_end = 2
  )
  left <- Dynet:::.transition_pair_ledger(
    original, Dynet:::.encode(original), 1, "collapse"
  )
  right <- Dynet:::.transition_pair_ledger(
    reflected, Dynet:::.encode(reflected), 1, "collapse"
  )
  expect_identical(left$dissolutions, right$formations)
  expect_equal(.t02_value(original, 1), 1)
  expect_equal(
    dyn_events(reflected, "formation_fraction", start = 1,
               end = 1, window = 0)$value, 1 / 2
  )
})

test_that("T02 empty ledger fields retain typed zero-opportunity schema", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 1),
    loops = TRUE, observation_start = 0, observation_end = 2
  )
  ledger <- Dynet:::.transition_pair_ledger(
    dn, Dynet:::.encode(dn), 1, "collapse"
  )
  lapply(c(
    "eligible_before", "eligible_after", "two_sided", "active_before",
    "active_after", "formation_risk", "formations",
    "onset_confirmation", "terminus_confirmation", "dissolution_risk",
    "dissolutions"
  ), function(field) {
    expect_identical(ledger[[field]], integer())
  })
  expect_identical(ledger$counts,
                   c(formation_risk = 0L, formations = 0L))
  expect_identical(ledger$dissolution_counts,
                   c(dissolution_risk = 0L, dissolutions = 0L))
})

test_that("T02 enforces exact-time use and exposes typed metadata", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 2),
    observation_start = 0, observation_end = 3
  )
  expect_error(
    dyn_events(dn, measure = "dissolution_fraction"),
    class = "dynet_transition_requires_instant"
  )
  expect_error(
    dyn_events(
      dn, measure = c("dissolution", "dissolution_fraction"), window = 1
    ), class = "dynet_transition_requires_instant"
  )

  out <- dyn_events(
    dn, measure = c("dissolution", "dissolution_fraction"),
    start = 2, end = 2, window = 0
  )
  expect_identical(names(out), c("time", "measure", "value"))
  expect_identical(out$measure, c("dissolution", "dissolution_fraction"))
  expect_type(out$value, "double")
  expect_equal(out$value, c(1, 1))
  expect_identical(attr(out, "measure_scope"), stats::setNames(
    c("raw_event_at_time", "binary_pair_transition_at_time"),
    c("dissolution", "dissolution_fraction")
  ))
  expect_identical(attr(out, "event_identity"), stats::setNames(
    c("uncensored_raw_spell_terminus", "binary_pair_union_transition"),
    c("dissolution", "dissolution_fraction")
  ))
  expect_identical(
    attr(out, "risk_set"),
    "two_sided_eligible_active_prestate_nonloop_pairs"
  )
  expect_identical(attr(out, "transition"), "active_to_inactive")
  expect_identical(
    attr(out, "confirmation"),
    "at_least_one_uncensored_positive_raw_terminus"
  )
  expect_identical(attr(out, "transition_grid"),
                   "requested_exact_times_not_auto_change_points")
  expect_identical(attr(out, "window_rule"), "exact_time_only")
  expect_identical(attr(out, "opportunity_domain"),
                   "eligible_nonloop_ordered_pairs")
  expect_identical(attr(out, "batching"), "all_boundaries_at_timestamp")
  expect_identical(attr(out, "interval_state"),
                   "half_open_one_sided_limits")
  expect_identical(attr(out, "points"), "impulses_excluded")
  expect_identical(attr(out, "weights"), "ignored")
  expect_identical(attr(out, "transition_unit"), "probability")
  expect_identical(attr(out, "transition_session_aggregation"),
                   "labels_erased_calendar_union")

  mixed <- dyn_events(
    dn, measure = c("formation_fraction", "dissolution_fraction"),
    start = 2, end = 2, window = 0
  )
  expect_identical(attr(mixed, "transition"), c(
    formation_fraction = "inactive_to_active",
    dissolution_fraction = "active_to_inactive"
  ))
  expect_identical(attr(mixed, "risk_set"), c(
    formation_fraction =
      "two_sided_eligible_inactive_prestate_nonloop_pairs",
    dissolution_fraction =
      "two_sided_eligible_active_prestate_nonloop_pairs"
  ))
  expect_identical(attr(mixed, "confirmation"), c(
    formation_fraction = "at_least_one_uncensored_positive_raw_onset",
    dissolution_fraction = "at_least_one_uncensored_positive_raw_terminus"
  ))

  single <- dyn_events(
    dn, measure = "dissolution_fraction", start = 2, end = 2, window = 0
  )
  expect_identical(attr(single, "what"), "Dissolution transition fraction")
  expect_identical(Dynet:::.event_label("dissolution_fraction"),
                   "Dissolution transition fraction")
})
