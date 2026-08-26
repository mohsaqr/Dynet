.d04_measures <- c(
  "temporal_density", "observed_pair_density", "onset_intensity",
  "observed_pair_onset_intensity"
)

.d04_values <- function(dn, ...) {
  out <- metrics(dn, measure = .d04_measures, ...)
  stats::setNames(out$value, out$measure)
}

test_that("D04 literal directed and undirected ledgers distinguish four quantities", {
  edges <- data.frame(
    from = c("A", "A", "B", "A", "C", "A"),
    to = c("B", "B", "A", "C", "D", "A"),
    start = c(0, 2, 1, 5, 6, 0), end = c(4, 6, 3, 5, 10, 10),
    weight = c(1, 9, 4, 7, 3, 100)
  )
  directed <- quiet_dynet(
    edges, weight = "weight", loops = TRUE,
    observation_start = 0, observation_end = 10
  )
  undirected <- quiet_dynet(
    edges, directed = FALSE, weight = "weight", loops = TRUE,
    observation_start = 0, observation_end = 10
  )

  expect_equal(
    unname(.d04_values(directed, step = 10, window = 10)),
    c(1 / 10, 3 / 10, 1 / 24, 1 / 8)
  )
  expect_equal(
    unname(.d04_values(undirected, step = 10, window = 10)),
    c(1 / 6, 1 / 3, 1 / 12, 1 / 6)
  )
})

test_that("D04 integrates changing endpoint opportunity instead of fixed order", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "C"),
    start = c(0, 5), end = c(5, 10)
  )
  activity <- data.frame(
    node = c("B", "C"), start = c(0, 5), end = c(5, 10)
  )
  dn <- quiet_dynet(
    edges, vertex_spells = activity,
    observation_start = 0, observation_end = 10
  )
  expect_equal(
    unname(.d04_values(dn, step = 10, window = 10)),
    c(1 / 2, 1, 1 / 10, 1 / 5)
  )
})

test_that("D04 ever-observed cohort requires endpoint-valid observed evidence", {
  edges <- data.frame(from = "B", to = "C", start = 4.5, end = 5.5)
  activity <- data.frame(
    node = c("B", "B"), start = c(0, 6), end = c(4, 10)
  )
  dn <- quiet_dynet(
    edges, nodes = data.frame(name = c("B", "C")),
    vertex_spells = activity, observation_start = 0, observation_end = 10
  )
  got <- .d04_values(dn, step = 10, window = 10)
  expect_equal(unname(got[c("temporal_density", "onset_intensity")]), c(0, 0))
  expect_true(is.na(got[["observed_pair_density"]]))
  expect_true(is.na(got[["observed_pair_onset_intensity"]]))
})

test_that("D04 censoring suppresses only explicitly unknown onsets", {
  edges <- data.frame(
    from = "A", to = "B", start = c(0, 2, 4, 8), end = c(2, 5, 8, 10),
    left = c(FALSE, TRUE, FALSE, TRUE),
    right = c(FALSE, FALSE, TRUE, TRUE)
  )
  dn <- quiet_dynet(
    edges, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  expect_equal(
    unname(.d04_values(dn, step = 10, window = 10)),
    c(1 / 2, 1, 1 / 10, 1 / 5)
  )

  prevalent <- quiet_dynet(
    data.frame(from = "A", to = "B", start = -2, end = 12),
    observation_start = 0, observation_end = 10
  )
  expect_equal(
    unname(.d04_values(prevalent, step = 10, window = 10)),
    c(1 / 2, 1, 0, 0)
  )
})

test_that("D04 point contacts add onsets and cohort membership but no exposure", {
  point <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    observation_start = 0, observation_end = 10
  )
  expect_equal(
    unname(.d04_values(point, step = 10, window = 10)),
    c(0, 0, 1 / 20, 1 / 10)
  )

  punctual <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    observation_start = 5, observation_end = 5
  )
  expect_true(all(is.na(.d04_values(punctual, step = 1, window = 1))))

  coeligible_point <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 5, end = 5),
    vertex_spells = data.frame(node = c("A", "B"), start = 5, end = 5),
    observation_start = 0, observation_end = 10
  )
  expect_true(all(is.na(.d04_values(
    coeligible_point, step = 10, window = 10
  ))))
})

test_that("D04 excludes loops and defines empty observed-pair risk", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 10),
    vertex_spells = data.frame(node = "B", start = 0, end = 10),
    loops = TRUE,
    observation_start = 0, observation_end = 10
  )
  got <- .d04_values(dn, step = 10, window = 10)
  expect_equal(unname(got[c("temporal_density", "onset_intensity")]), c(0, 0))
  expect_true(is.na(got[["observed_pair_density"]]))
  expect_true(is.na(got[["observed_pair_onset_intensity"]]))
})

test_that("D04 ever-observed cohort is global rather than reset by a query window", {
  dn <- quiet_dynet(
    data.frame(
      from = c("A", "A"), to = c("B", "C"),
      start = c(0, 9), end = c(1, 10)
    ),
    observation_start = 0, observation_end = 10
  )
  out <- metrics(
    dn, measure = .d04_measures, start = 0, end = 5,
    step = 5, window = 5
  )
  expected <- c(1 / 30, 1 / 10, 1 / 30, 1 / 10)
  expect_equal(out$value[out$time == 0], expected)
  expect_equal(out$value[out$time == 5], expected)
})

test_that("D04 exact windows remain distinct from snapshot-any density", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    observation_start = 0, observation_end = 5
  )
  out <- metrics(
    dn, measure = c("density", .d04_measures), step = 5, window = 5
  )
  expect_equal(out$value, c(1 / 2, 1 / 10, 1 / 5, 1 / 10, 1 / 5))

  instant <- metrics(dn, measure = .d04_measures, window = 0)
  expect_true(all(is.na(instant$value)))
})

test_that("D04 raw-onset bins preserve half-open and final-closed boundaries", {
  dn <- quiet_dynet(
    data.frame(
      from = "A", to = "B", start = c(0, 5, 10), end = c(10, 5, 10)
    ),
    observation_start = 0, observation_end = 10
  )
  out <- metrics(dn, measure = .d04_measures, step = 5, window = 5)
  first <- stats::setNames(out$value[out$time == 0], out$measure[out$time == 0])
  last <- stats::setNames(out$value[out$time == 5], out$measure[out$time == 5])
  expect_equal(unname(first), c(1 / 2, 1, 1 / 10, 1 / 5))
  expect_equal(unname(last), c(1 / 2, 1, 1 / 5, 2 / 5))
})

test_that("D04 session policies union exposure but retain raw-onset identity", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 4), end = c(6, 10), wave = c("s1", "s2")
  )
  dn <- quiet_dynet(
    edges, session = "wave", observation_start = 0, observation_end = 10
  )
  expected <- c(1 / 2, 1, 1 / 10, 1 / 5)
  expect_equal(unname(.d04_values(
    dn, sessions = "collapse", step = 10, window = 10
  )), expected)
  expect_equal(unname(.d04_values(
    dn, sessions = "bounded", step = 10, window = 10
  )), expected)

  separate <- metrics(
    dn, measure = .d04_measures, sessions = "separate",
    step = 10, window = 10
  )
  expect_equal(separate$value[separate$session == "s1"],
               c(3 / 10, 3 / 5, 1 / 20, 1 / 10))
  expect_equal(separate$value[separate$session == "s2"],
               c(3 / 10, 3 / 5, 1 / 20, 1 / 10))
})

test_that("D04 bounded sessions forbid cross-label endpoint authorization", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "A"),
    start = c(0, 2), end = c(5, 2), wave = c("s1", "s2")
  )
  activity <- data.frame(
    node = c("A", "B"), start = 0, end = 5, session = "s2"
  )
  dn <- quiet_dynet(
    edges, session = "wave", loops = TRUE, vertex_spells = activity,
    observation_start = 0, observation_end = 5
  )
  expect_equal(unname(.d04_values(
    dn, sessions = "collapse", step = 5, window = 5
  )), c(1 / 2, 1, 1 / 10, 1 / 5))

  bounded <- .d04_values(dn, sessions = "bounded", step = 5, window = 5)
  expect_equal(unname(bounded[c("temporal_density", "onset_intensity")]),
               c(0, 0))
  expect_true(is.na(bounded[["observed_pair_density"]]))
  expect_true(is.na(bounded[["observed_pair_onset_intensity"]]))
})

test_that("D04 has the frozen transformations and representation invariants", {
  edges <- data.frame(
    from = c("A", "A", "B"), to = c("B", "B", "A"),
    start = c(0, 2, 5), end = c(4, 6, 7), weight = c(1, 9, 4)
  )
  make <- function(data = edges, multiplier = 1, offset = 0,
                   names = c("A", "B")) {
    data$start <- data$start * multiplier + offset
    data$end <- data$end * multiplier + offset
    data$from <- ifelse(data$from == "A", names[1], names[2])
    data$to <- ifelse(data$to == "A", names[1], names[2])
    quiet_dynet(
      data, weight = "weight", observation_start = offset,
      observation_end = 10 * multiplier + offset
    )
  }
  base <- .d04_values(make(), step = 10, window = 10)
  permuted <- .d04_values(make(edges[c(3, 1, 2), ]), step = 10, window = 10)
  renamed <- .d04_values(make(names = c("", "z")), step = 10, window = 10)
  scaled <- .d04_values(make(multiplier = 3, offset = 11),
                        step = 30, window = 30)
  expect_equal(permuted, base)
  expect_equal(renamed, base)
  expect_equal(unname(scaled[1:2]), unname(base[1:2]))
  expect_equal(unname(scaled[3:4]), unname(base[3:4] / 3))

  transposed <- edges
  transposed[c("from", "to")] <- edges[c("to", "from")]
  expect_equal(.d04_values(
    make(transposed), step = 10, window = 10
  ), base)

  duplicated <- rbind(edges, edges[1, ])
  duplicate_values <- .d04_values(
    quiet_dynet(
      duplicated, weight = "weight", observation_start = 0,
      observation_end = 10
    ), step = 10, window = 10
  )
  expect_equal(unname(duplicate_values[1:2]), unname(base[1:2]))
  expect_equal(unname(duplicate_values[3:4] - base[3:4]), c(1 / 20, 1 / 20))

  split <- rbind(
    transform(edges[1, ], end = 2), transform(edges[1, ], start = 2),
    edges[-1, ]
  )
  split_values <- .d04_values(
    quiet_dynet(
      split, weight = "weight", observation_start = 0, observation_end = 10
    ), step = 10, window = 10
  )
  expect_equal(unname(split_values[1:2]), unname(base[1:2]))
  expect_equal(unname(split_values[3:4] - base[3:4]), c(1 / 20, 1 / 20))

  undirected <- quiet_dynet(
    edges, directed = FALSE, weight = "weight",
    observation_start = 0, observation_end = 10
  )
  reversed <- edges
  reversed[c("from", "to")] <- edges[c("to", "from")]
  undirected_reversed <- quiet_dynet(
    reversed, directed = FALSE, weight = "weight",
    observation_start = 0, observation_end = 10
  )
  expect_equal(.d04_values(
    undirected_reversed, step = 10, window = 10
  ), .d04_values(undirected, step = 10, window = 10))
})

test_that("D04 mixed results expose measure-specific scope and quantity metadata", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 2),
    observation_start = 0, observation_end = 2
  )
  out <- metrics(
    dn, measure = c("density", .d04_measures), step = 2, window = 2
  )
  expect_identical(attr(out, "measure_scope"), stats::setNames(
    c("snapshot_any_union", rep("whole_window_exact", 4)),
    c("density", .d04_measures)
  ))
  expect_identical(attr(out, "pair_set_scope"),
                   "full_observed_history_no_window_or_gap_reset")
  expect_identical(attr(out, "risk_integration"), "exact_change_point")
  expect_identical(attr(out, "onset_identity"), "uncensored_raw_spell_start")
  expect_identical(attr(out, "instantaneous_exposure"), "zero")
  expect_identical(attr(out, "opportunity_domain"),
                   "eligible_nonloop_ordered_pairs")
  expect_identical(attr(out, "session_vertex_aggregation"), "calendar_union")
  expect_identical(attr(out, "vertex_population"), stats::setNames(
    c("eligible_window_any_induced", rep("eligible_at_time", 4)),
    c("density", .d04_measures)
  ))
  expect_identical(attr(out, "vertex_window_rule"), stats::setNames(
    c("any", rep("exact_change_point", 4)),
    c("density", .d04_measures)
  ))
  expect_identical(attr(out, "edge_endpoint_rule"), stats::setNames(
    c("induced_after_elementwise_union",
      rep("both_endpoints_eligible_at_time", 4)),
    c("density", .d04_measures)
  ))
})

test_that("D04 direct helpers expose pair, state, evidence, ledger, and ratio units", {
  edges <- data.frame(
    from = c("A", "A", "B", "A", "C", "A"),
    to = c("B", "B", "A", "C", "D", "A"),
    start = c(0, 2, 1, 5, 6, 0), end = c(4, 6, 3, 5, 10, 10)
  )
  dn <- quiet_dynet(
    edges, loops = TRUE, observation_start = 0, observation_end = 10
  )
  enc <- Dynet:::.encode(dn)
  opportunities <- Dynet:::.relational_opportunities(4, TRUE)
  expect_equal(nrow(opportunities), 12)
  expect_identical(
    Dynet:::.relational_pair_key(c(1L, 2L), c(2L, 1L), 4L, FALSE),
    c(2L, 2L)
  )
  state <- Dynet:::.temporal_pair_state(
    dn, enc, 2.5, "collapse", opportunities = opportunities
  )
  expect_equal(length(state$eligible), 12)
  expect_equal(length(state$occupied), 2)
  expect_identical(Dynet:::.temporal_exposure_changes(dn, enc, 0, 10),
                   c(0, 1, 2, 3, 4, 5, 6, 10))
  expect_equal(length(Dynet:::.ever_observed_pairs(
    dn, enc, "collapse"
  )), 4)
  ledger <- Dynet:::.temporal_edge_ledger(
    dn, enc, data.frame(lo = 0, hi = 10, closed = TRUE), "collapse"
  )
  expect_identical(unname(ledger), c(120, 12, 40, 5))
  expect_equal(
    unname(Dynet:::.temporal_edge_values(ledger)),
    c(1 / 10, 3 / 10, 1 / 24, 1 / 8)
  )
})

test_that("D04 pools observation components without bridging or averaging ratios", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 6),
    observation_spells = data.frame(start = c(0, 4), end = c(2, 6))
  )
  out <- metrics(dn, measure = .d04_measures, step = 2, window = 2)
  expect_identical(out$time, rep(c(0, 4), each = 4))
  expect_equal(out$value[out$time == 0], c(1 / 2, 1, 1 / 4, 1 / 2))
  expect_equal(out$value[out$time == 4], c(1 / 2, 1, 0, 0))
  expect_equal(Dynet:::.temporal_density(dn), 1 / 2)
})

test_that("D04 eligible raw endpoint evidence establishes the global cohort", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = -1, end = 0),
    observation_start = 0, observation_end = 2
  )
  expect_equal(
    unname(.d04_values(dn, step = 2, window = 2)),
    c(0, 0, 0, 0)
  )
  expect_true(Dynet:::.raw_endpoint_eligible(
    dn, Dynet:::.encode(dn), 1L, 0, "collapse"
  ))
})

test_that("D04 does not fabricate vertex eligibility at an observation touch", {
  dn <- quiet_dynet(
    data.frame(from = "F", to = "B", start = 2, end = 5),
    vertex_spells = data.frame(node = "F", start = 5, end = 9),
    observation_spells = data.frame(start = c(0, 6), end = c(5, 10))
  )
  out <- metrics(dn, measure = .d04_measures, step = 5, window = 5)
  second <- stats::setNames(
    out$value[out$time == 6], out$measure[out$time == 6]
  )
  expect_equal(unname(second[c("temporal_density", "onset_intensity")]),
               c(0, 0))
  expect_true(is.na(second[["observed_pair_density"]]))
  expect_true(is.na(second[["observed_pair_onset_intensity"]]))
})

test_that("D04 singleton opportunity-time is undefined for every variant", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 2),
    loops = TRUE, observation_start = 0, observation_end = 2
  )
  expect_true(all(is.na(.d04_values(dn, step = 2, window = 2))))
})

test_that("D04 pooled summary divides additive ledgers across unequal components", {
  dn <- quiet_dynet(
    data.frame(
      from = c("A", "A", "C"), to = c("B", "B", "C"),
      start = c(0, 4, -1), end = c(2, 5, -1)
    ), loops = TRUE,
    observation_spells = data.frame(start = c(0, 4), end = c(2, 8))
  )
  out <- metrics(dn, measure = "temporal_density", step = 4, window = 4)
  expect_equal(out$value, c(1 / 6, 1 / 24))
  ledger <- Dynet:::.temporal_risk_ledger(dn)
  expect_identical(unname(ledger), c(36, 3, 33))
  expect_equal(Dynet:::.temporal_density(dn), 1 / 12)
  expect_false(isTRUE(all.equal(mean(out$value), 1 / 12)))
})
