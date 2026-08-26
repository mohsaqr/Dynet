node_tie_value <- function(x, node, measure, session = NULL) {
  frame <- as.data.frame(x)
  keep <- frame$node == node & frame$measure == measure
  if (!is.null(session)) keep <- keep & frame$session == session
  frame$value[keep]
}

test_that("D03 directed out, in, and all incidence is literal", {
  edges <- data.frame(
    from = c("A", "A", "A", "B", "D", "C", "B", "A"),
    to = c("B", "C", "B", "A", "A", "D", "C", "A"),
    start = c(0, 0, 2, 1, 6, 7, 3, 8),
    end = c(4, 4, 6, 5, 9, 10, 3, 10),
    weight = c(2, 50, -1, 4, 3, 8, 99, 7)
  )
  dn <- quiet_dynet(
    edges, weight = "weight", loops = TRUE,
    vertex_spells = data.frame(node = "E", start = 0, end = 10),
    observation_start = 0, observation_end = 10
  )
  expected <- list(
    out = rbind(A = c(4, 14, 8), B = c(2, 4, 4), C = c(1, 3, 3),
                D = c(1, 3, 3), E = c(0, 0, 0)),
    `in` = rbind(A = c(3, 9, 8), B = c(2, 8, 6), C = c(2, 4, 4),
                 D = c(1, 3, 3), E = c(0, 0, 0)),
    all = rbind(A = c(7, 23, 10), B = c(4, 12, 6), C = c(3, 7, 7),
                D = c(2, 6, 4), E = c(0, 0, 0))
  )
  invisible(lapply(c("out", "in", "all"), function(mode) {
    got <- durations(
      dn, unit = "node_ties", mode = mode,
      measure = c("events", "total", "union")
    )
    frame <- as.data.frame(got)
    expect_identical(names(frame), c("node", "measure", "value"))
    invisible(lapply(rownames(expected[[mode]]), function(node) {
      expect_equal(c(
        node_tie_value(got, node, "events"),
        node_tie_value(got, node, "total"),
        node_tie_value(got, node, "union")
      ), unname(expected[[mode]][node, ]))
      NULL
    }))
    NULL
  }))
})

test_that("D03 all is additive but incident union is calendar binary", {
  reciprocal <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("B", "A"),
               start = 0, end = 4),
    observation_start = 0, observation_end = 4
  )
  out <- durations(reciprocal, unit = "node_ties", mode = "out",
                       measure = c("events", "total", "union"))
  incoming <- durations(reciprocal, unit = "node_ties", mode = "in",
                            measure = c("events", "total", "union"))
  combined <- durations(reciprocal, unit = "node_ties", mode = "all",
                            measure = c("events", "total", "union"))
  invisible(lapply(c("A", "B"), function(node) {
    expect_equal(node_tie_value(out, node, "events"), 1)
    expect_equal(node_tie_value(incoming, node, "total"), 4)
    expect_equal(node_tie_value(combined, node, "events"), 2)
    expect_equal(node_tie_value(combined, node, "total"), 8)
    expect_equal(node_tie_value(combined, node, "union"), 4)
    NULL
  }))
  expect_equal(
    as.data.frame(combined)$value[as.data.frame(combined)$measure != "union"],
    as.data.frame(out)$value[as.data.frame(out)$measure != "union"] +
      as.data.frame(incoming)$value[as.data.frame(incoming)$measure != "union"]
  )
})

test_that("D03 undirected modes expose both endpoint stubs and double loops", {
  edges <- data.frame(
    from = c("A", "A", "A"), to = c("B", "C", "A"),
    start = c(0, 1, 2), end = c(4, 3, 5)
  )
  dn <- quiet_dynet(
    edges, directed = FALSE, loops = TRUE,
    vertex_spells = data.frame(node = "D", start = 0, end = 5),
    observation_start = 0, observation_end = 5
  )
  results <- lapply(c("out", "in", "all"), function(mode) durations(
    dn, unit = "node_ties", mode = mode,
    measure = c("events", "total", "union")
  ))
  expect_equal(as.data.frame(results[[1L]]), as.data.frame(results[[2L]]),
               ignore_attr = TRUE)
  expect_equal(as.data.frame(results[[2L]]), as.data.frame(results[[3L]]),
               ignore_attr = TRUE)
  got <- results[[1L]]
  expect_equal(c(node_tie_value(got, "A", "events"),
                 node_tie_value(got, "A", "total"),
                 node_tie_value(got, "A", "union")), c(4, 12, 5))
  expect_equal(c(node_tie_value(got, "B", "events"),
                 node_tie_value(got, "B", "total"),
                 node_tie_value(got, "B", "union")), c(1, 4, 4))
  expect_equal(c(node_tie_value(got, "C", "events"),
                 node_tie_value(got, "C", "total"),
                 node_tie_value(got, "C", "union")), c(1, 2, 2))
  expect_equal(as.data.frame(got)$value[as.data.frame(got)$node == "D"],
               c(0, 0, 0))
  expect_identical(attr(got, "requested_mode"), "out")
  expect_identical(attr(got, "mode"), "all")
})

test_that("D03 gaps fragment time without multiplying identities or points", {
  edges <- data.frame(
    from = c("A", "B", "A", "A", "B"),
    to = c("B", "A", "B", "B", "A"),
    start = c(1, 2, 4, 6, 5), end = c(9, 8, 4, 6, 5)
  )
  dn <- quiet_dynet(
    edges, observation_spells = data.frame(start = c(0, 6), end = c(4, 10))
  )
  out <- durations(dn, unit = "node_ties", mode = "out",
                       measure = c("events", "total", "union"))
  expect_equal(c(node_tie_value(out, "A", "events"),
                 node_tie_value(out, "A", "total"),
                 node_tie_value(out, "A", "union")), c(3, 6, 6))
  expect_equal(c(node_tie_value(out, "B", "events"),
                 node_tie_value(out, "B", "total"),
                 node_tie_value(out, "B", "union")), c(1, 4, 4))
  all <- durations(dn, unit = "node_ties", mode = "all",
                       measure = c("events", "total", "union"))
  expect_equal(c(node_tie_value(all, "A", "events"),
                 node_tie_value(all, "A", "total"),
                 node_tie_value(all, "A", "union")), c(4, 10, 6))
  expect_equal(c(node_tie_value(all, "B", "events"),
                 node_tie_value(all, "B", "total"),
                 node_tie_value(all, "B", "union")), c(4, 10, 6))
})

test_that("D03 reuses endpoint activity and raw edge censor semantics", {
  edges <- data.frame(
    from = c("A", "A", "B"), to = c("B", "C", "C"),
    start = c(0, 4, 5), end = c(10, 10, 9)
  )
  activity <- data.frame(
    node = c("A", "B"), start = c(0, 2), end = c(8, 6)
  )
  dn <- quiet_dynet(
    edges, vertex_spells = activity,
    observation_start = 0, observation_end = 10
  )
  out <- durations(dn, unit = "node_ties", mode = "out",
                       measure = c("events", "total", "union"))
  expect_equal(c(node_tie_value(out, "A", "events"),
                 node_tie_value(out, "A", "total"),
                 node_tie_value(out, "A", "union")), c(2, 8, 6))
  expect_equal(c(node_tie_value(out, "B", "events"),
                 node_tie_value(out, "B", "total"),
                 node_tie_value(out, "B", "union")), c(1, 1, 1))
  all_ties <- as.data.frame(durations(
    dn, unit = "node_ties", mode = "all", measure = "union"
  ))
  eligible <- as.data.frame(durations(
    dn, unit = "vertex_activity", measure = "union"
  ))
  expect_true(all(all_ties$value <= eligible$value))

  flagged_activity <- transform(
    activity, onset_censored = TRUE, terminus_censored = TRUE
  )
  flagged <- quiet_dynet(
    edges, vertex_spells = flagged_activity,
    observation_start = 0, observation_end = 10
  )
  expect_equal(as.data.frame(durations(
    flagged, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  )), as.data.frame(out), ignore_attr = TRUE)

  censor_edges <- data.frame(
    from = "A", to = "B", start = c(0, 2, 4, 8), end = c(2, 5, 8, 10),
    left = c(FALSE, TRUE, FALSE, TRUE),
    right = c(FALSE, FALSE, TRUE, TRUE)
  )
  censored <- quiet_dynet(
    censor_edges, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 10
  )
  included <- durations(
    censored, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  )
  excluded <- durations(
    censored, unit = "node_ties", mode = "out", censored = "exclude",
    measure = c("events", "total", "union")
  )
  expect_equal(c(node_tie_value(included, "A", "events"),
                 node_tie_value(included, "A", "total"),
                 node_tie_value(included, "A", "union")), c(4, 11, 10))
  expect_equal(c(node_tie_value(excluded, "A", "events"),
                 node_tie_value(excluded, "A", "total"),
                 node_tie_value(excluded, "A", "union")), c(1, 2, 2))
})

test_that("D03 session policies keep local authorization and union shared time", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 4), end = c(6, 10), wave = c("s1", "s2")
  )
  dn <- quiet_dynet(edges, session = "wave",
                    observation_start = 0, observation_end = 10)
  bounded <- durations(
    dn, unit = "node_ties", mode = "out", sessions = "bounded",
    measure = c("events", "total", "union")
  )
  collapsed <- durations(
    dn, unit = "node_ties", mode = "out", sessions = "collapse",
    measure = c("events", "total", "union")
  )
  expect_equal(as.data.frame(bounded), as.data.frame(collapsed),
               ignore_attr = TRUE)
  expect_equal(c(node_tie_value(bounded, "A", "events"),
                 node_tie_value(bounded, "A", "total"),
                 node_tie_value(bounded, "A", "union")), c(2, 12, 10))
  separate <- durations(
    dn, unit = "node_ties", mode = "out", sessions = "separate",
    measure = c("events", "total", "union")
  )
  expect_equal(c(node_tie_value(separate, "A", "events", "s1"),
                 node_tie_value(separate, "A", "total", "s1"),
                 node_tie_value(separate, "A", "union", "s1")), c(1, 6, 6))
  expect_equal(c(node_tie_value(separate, "A", "events", "s2"),
                 node_tie_value(separate, "A", "total", "s2"),
                 node_tie_value(separate, "A", "union", "s2")), c(1, 6, 6))
  expect_identical(attr(bounded, "session_aggregation"),
                   "session_local_then_union")
  expect_identical(attr(separate, "session_aggregation"), "session_local")

  authorization_edges <- data.frame(
    from = c("A", "C"), to = c("B", "D"), start = c(0, 0), end = c(5, 0),
    wave = c("s1", "s2")
  )
  authorization_activity <- data.frame(
    node = c("A", "B"), start = 0, end = 5, session = "s2"
  )
  authorization <- quiet_dynet(
    authorization_edges, session = "wave",
    vertex_spells = authorization_activity,
    observation_start = 0, observation_end = 5
  )
  collapse_auth <- durations(
    authorization, unit = "node_ties", mode = "out", sessions = "collapse"
  )
  bounded_auth <- durations(
    authorization, unit = "node_ties", mode = "out", sessions = "bounded"
  )
  expect_equal(node_tie_value(collapse_auth, "A", "events"), 1)
  expect_equal(node_tie_value(bounded_auth, "A", "events"), 0)
  expect_identical(attr(durations(
    authorization, unit = "node_ties", censored = "exclude"
  ), "raw_censoring"), "excluded")
})

test_that("D03 helper, defaults, metadata, validation and coordinates are exact", {
  edge <- data.frame(from = "A", to = "B", start = 0, end = 4)
  dn <- quiet_dynet(edge, observation_start = 0, observation_end = 4)
  fragments <- data.frame(
    from = c("A", "A", "A"), to = c("B", "B", "A"),
    raw_spell = c(1L, 1L, 2L), start = c(0, 3, 1), end = c(2, 4, 2),
    instant = FALSE
  )
  direct <- Dynet:::.node_tie_fragments(
    fragments, nodes = c("A", "B"), directed = TRUE, mode = "all"
  )
  expect_equal(direct$node, c("A", "A", "A", "A", "B", "B"))
  expect_identical(as.integer(table(direct$raw_spell)), c(4L, 2L))
  empty_direct <- Dynet:::.node_tie_fragments(
    fragments[FALSE, ], nodes = "A", directed = TRUE, mode = "out"
  )
  expect_identical(names(empty_direct),
                   c("node", "raw_spell", "stub", "start", "end", "instant"))
  expect_equal(nrow(empty_direct), 0L)
  expect_identical(vapply(empty_direct, typeof, character(1L)), c(
    node = "character", raw_spell = "integer", stub = "character",
    start = "double", end = "double", instant = "logical"
  ))

  default <- durations(dn, unit = "node_ties")
  expect_identical(unique(as.data.frame(default)$measure), c("events", "total"))
  expect_identical(attr(default, "duration_unit"), "node_ties")
  expect_identical(attr(default, "duration_quantity"), c("events", "total"))
  expect_identical(attr(default, "requested_mode"), "out")
  expect_identical(attr(default, "mode"), "out")
  expect_identical(attr(default, "incidence"), "raw_spell_endpoint_occurrence")
  expect_identical(attr(default, "loop_contribution"), "one_out_plus_one_in")
  expect_identical(attr(default, "occupancy"), "binary_incident_calendar_union")
  expect_identical(attr(default, "weights"), "ignored")
  expect_identical(attr(default, "vertex_rule"),
                   "both_endpoints_eligible_at_time")
  expect_identical(attr(default, "observation_rule"),
                   "positive_support_plus_genuine_points")
  expect_identical(attr(default, "raw_censoring"), "included")
  expect_identical(attr(default, "session_aggregation"), "labels_erased")
  expect_error(durations(dn, unit = "node_ties", measure = "mean"),
               class = "dynet_unknown_measure")
  expect_error(durations(dn, mode = "in"),
               class = "dynet_incompatible_duration_mode")

  coordinate_edges <- data.frame(
    from = c("A", "A", "B"), to = c("B", "C", "A"),
    start = c(0, 1, 2), end = c(4, 3, 4), weight = c(1, 9, -2)
  )
  coordinate <- quiet_dynet(
    coordinate_edges, weight = "weight",
    observation_start = 0, observation_end = 4
  )
  permuted <- quiet_dynet(
    coordinate_edges[c(3, 1, 2), ], weight = "weight",
    observation_start = 0, observation_end = 4
  )
  expect_equal(as.data.frame(durations(
    permuted, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  )), as.data.frame(durations(
    coordinate, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  )), ignore_attr = TRUE)
  renamed_edges <- transform(
    coordinate_edges, from = c("", "", "B"), to = c("B", "C", "")
  )
  renamed <- quiet_dynet(
    renamed_edges, weight = "weight", observation_start = 0, observation_end = 4
  )
  renamed_result <- as.data.frame(durations(
    renamed, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  ))
  coordinate_result <- as.data.frame(durations(
    coordinate, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  ))
  expect_equal(renamed_result$value, coordinate_result$value)

  transposed_edges <- transform(
    coordinate_edges, from = coordinate_edges$to, to = coordinate_edges$from
  )
  transposed <- quiet_dynet(
    transposed_edges, weight = "weight", observation_start = 0, observation_end = 4
  )
  expect_equal(as.data.frame(durations(
    coordinate, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  )), as.data.frame(durations(
    transposed, unit = "node_ties", mode = "in",
    measure = c("events", "total", "union")
  )), ignore_attr = TRUE)
  expect_equal(as.data.frame(durations(
    coordinate, unit = "node_ties", mode = "all",
    measure = c("events", "total", "union")
  )), as.data.frame(durations(
    transposed, unit = "node_ties", mode = "all",
    measure = c("events", "total", "union")
  )), ignore_attr = TRUE)
  affine <- quiet_dynet(
    transform(edge, start = 7 + 3 * start, end = 7 + 3 * end),
    observation_start = 7, observation_end = 19
  )
  transformed <- as.data.frame(durations(
    affine, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  ))
  reference <- as.data.frame(durations(
    dn, unit = "node_ties", mode = "out",
    measure = c("events", "total", "union")
  ))
  expected <- reference$value
  expected[reference$measure %in% c("total", "union")] <-
    3 * expected[reference$measure %in% c("total", "union")]
  expect_equal(transformed$value, expected)

  singleton <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 2), loops = TRUE,
    observation_start = 0, observation_end = 2
  )
  singleton_all <- durations(
    singleton, unit = "node_ties", mode = "all",
    measure = c("events", "total", "union")
  )
  expect_equal(as.data.frame(singleton_all)$value, c(2, 4, 2))
})
