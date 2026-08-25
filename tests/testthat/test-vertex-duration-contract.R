vertex_duration_value <- function(x, node, measure, session = NULL) {
  frame <- as.data.frame(x)
  keep <- frame$node == node & frame$measure == measure
  if (!is.null(session)) keep <- keep & frame$session == session
  frame$value[keep]
}

test_that("D02 returns literal canonical spell and fixed vertex quantities", {
  edges <- data.frame(from = "A", to = "B", start = 0, end = 10)
  nodes <- data.frame(name = LETTERS[1:5])
  activity <- data.frame(
    node = c(rep("B", 7), "C", "C", "D", "D", "D", "E"),
    start = c(0, 2, 6, 3, 7, 8, 10, 1, 5, 2, 2, 9, 11),
    end = c(4, 6, 7, 3, 7, 10, 10, 3, 8, 2, 2, 9, 12)
  )
  dn <- quiet_dynet(edges, nodes = nodes, vertex_spells = activity,
                    observation_start = 0, observation_end = 10)
  measures <- c("events", "total", "union", "mean", "median", "first", "last")
  got <- as.data.frame(dyn_durations(
    dn, unit = "vertex_activity", measure = measures
  ))
  expect_identical(names(got), c("node", "measure", "value"))
  expected <- data.frame(
    node = LETTERS[1:5],
    events = c(1, 4, 2, 2, 0),
    total = c(10, 9, 5, 0, 0),
    union = c(10, 9, 5, 0, 0),
    mean = c(10, 2.25, 2.5, 0, NA),
    median = c(10, 1, 2.5, 0, NA),
    first = c(0, 0, 1, 2, NA),
    last = c(10, 10, 8, 9, NA)
  )
  expected_long <- do.call(rbind, lapply(seq_len(nrow(expected)), function(i) {
    data.frame(
      node = expected$node[i], measure = measures,
      value = as.numeric(expected[i, measures]), stringsAsFactors = FALSE
    )
  }))
  expected_long <- expected_long[order(expected_long$measure,
                                       expected_long$node), ]
  rownames(expected_long) <- NULL
  expect_equal(got, expected_long, ignore_attr = TRUE)

  spells <- as.data.frame(dyn_durations(
    dn, unit = "vertex_spell", measure = c("duration", "first", "last")
  ))
  expect_identical(names(spells),
                   c("node", "vertex_spell", "implicit", "measure", "value"))
  durations <- spells[spells$measure == "duration", ]
  expect_equal(durations$value, c(10, 7, 0, 2, 0, 2, 3, 0, 0))
  expect_identical(durations$implicit,
                   c(TRUE, rep(FALSE, 8)))
  expect_true(is.na(durations$vertex_spell[1]))
  expect_equal(durations$vertex_spell[-1], 1:8)
  expect_false("E" %in% durations$node)
})

test_that("D02 recombines observation fragments and preserves genuine points", {
  edges <- data.frame(from = "A", to = "P", start = 0, end = 10)
  nodes <- data.frame(name = c("A", "P", "Q", "R", "S"))
  activity <- data.frame(
    node = c("P", "Q", "Q", "R", "R", "R", "S"),
    start = c(2, 2, 6, 4, 5, 6, 4),
    end = c(8, 4, 8, 4, 5, 6, 6)
  )
  dn <- quiet_dynet(
    edges, nodes = nodes, vertex_spells = activity,
    observation_spells = data.frame(start = c(0, 6), end = c(4, 10))
  )
  got <- dyn_durations(
    dn, unit = "vertex_activity",
    measure = c("events", "total", "union", "mean", "median", "first", "last")
  )
  expect_equal(vertex_duration_value(got, "A", "events"), 1)
  expect_equal(vertex_duration_value(got, "A", "total"), 8)
  expect_equal(vertex_duration_value(got, "P", "events"), 1)
  expect_equal(vertex_duration_value(got, "P", "total"), 4)
  expect_equal(vertex_duration_value(got, "P", "first"), 2)
  expect_equal(vertex_duration_value(got, "P", "last"), 8)
  expect_equal(vertex_duration_value(got, "Q", "events"), 2)
  expect_equal(vertex_duration_value(got, "Q", "mean"), 2)
  expect_equal(vertex_duration_value(got, "R", "events"), 2)
  expect_equal(vertex_duration_value(got, "R", "union"), 0)
  expect_equal(vertex_duration_value(got, "R", "first"), 4)
  expect_equal(vertex_duration_value(got, "R", "last"), 6)
  expect_equal(vertex_duration_value(got, "S", "events"), 0)
  expect_true(is.na(vertex_duration_value(got, "S", "first")))

  direct <- Dynet:::.vertex_duration_fragments(dn, censored = "include")
  p <- direct[direct$node == "P", ]
  expect_equal(p$start, c(2, 6))
  expect_equal(p$end, c(4, 8))
  expect_identical(unique(p$vertex_spell), 1L)
  blocks <- Dynet:::.vertex_duration_blocks(dn, "bounded", "include")
  expect_identical(names(blocks), "all")
  expect_equal(blocks$all, direct, ignore_attr = TRUE)
})

test_that("D02 canonical vertex censor exclusion removes whole identities", {
  activity <- data.frame(
    node = c("U", "L", "R", "B"), start = 0, end = 4,
    onset_censored = c(FALSE, TRUE, FALSE, TRUE),
    terminus_censored = c(FALSE, FALSE, TRUE, TRUE)
  )
  dn <- quiet_dynet(
    data.frame(from = "U", to = "L", start = 0, end = 4),
    nodes = data.frame(name = c("U", "L", "R", "B")),
    vertex_spells = activity, observation_start = 0, observation_end = 4
  )
  included <- dyn_durations(
    dn, unit = "vertex_activity", measure = c("events", "total"),
    censored = "include"
  )
  expect_equal(as.data.frame(included)$value, rep(c(1, 4), each = 4))
  excluded <- dyn_durations(
    dn, unit = "vertex_activity", measure = c("events", "total", "first"),
    censored = "exclude"
  )
  expect_equal(vertex_duration_value(excluded, "U", "events"), 1)
  expect_equal(vertex_duration_value(excluded, "L", "events"), 0)
  expect_equal(vertex_duration_value(excluded, "R", "total"), 0)
  expect_true(is.na(vertex_duration_value(excluded, "B", "first")))
  spell <- as.data.frame(dyn_durations(
    dn, unit = "vertex_spell", censored = "exclude"
  ))
  expect_identical(spell$node, "U")
})

test_that("D02 session policies pool identities and union the shared calendar", {
  edges <- data.frame(
    from = c("B", "B", "D", "D"), to = c("C", "C", "B", "B"),
    start = c(0, 0, 0, 0), end = c(10, 10, 0, 0),
    wave = c("s1", "s2", "s1", "s2")
  )
  activity <- data.frame(
    node = c("B", "B", "C"), start = c(0, 4, 0), end = c(6, 10, 3),
    session = c("s1", "s2", "s1")
  )
  dn <- quiet_dynet(
    edges, nodes = data.frame(name = c("B", "C", "D")), session = "wave",
    vertex_spells = activity, observation_start = 0, observation_end = 10
  )
  measures <- c("events", "total", "union", "mean", "median", "first", "last")
  collapsed <- dyn_durations(
    dn, unit = "vertex_activity", measure = measures, sessions = "collapse"
  )
  bounded <- dyn_durations(
    dn, unit = "vertex_activity", measure = measures, sessions = "bounded"
  )
  expect_equal(as.data.frame(bounded), as.data.frame(collapsed),
               ignore_attr = TRUE)
  expect_equal(vertex_duration_value(bounded, "B", "events"), 2)
  expect_equal(vertex_duration_value(bounded, "B", "total"), 12)
  expect_equal(vertex_duration_value(bounded, "B", "union"), 10)
  expect_equal(vertex_duration_value(bounded, "D", "total"), 10)

  separate <- dyn_durations(
    dn, unit = "vertex_activity", measure = measures, sessions = "separate"
  )
  expect_equal(vertex_duration_value(separate, "B", "total", "s1"), 6)
  expect_equal(vertex_duration_value(separate, "B", "total", "s2"), 6)
  expect_equal(vertex_duration_value(separate, "C", "events", "s1"), 1)
  expect_equal(vertex_duration_value(separate, "C", "events", "s2"), 0)
  expect_equal(vertex_duration_value(separate, "D", "union", "s1"), 10)
  expect_equal(vertex_duration_value(separate, "D", "union", "s2"), 10)
})

test_that("D02 has typed zero, point, default and validation behavior", {
  edge <- data.frame(from = "A", to = "B", start = 5, end = 5)
  point <- quiet_dynet(
    edge, nodes = data.frame(name = c("A", "B", "C")),
    vertex_spells = data.frame(node = c("A", "C"), start = c(5, 6),
                               end = c(5, 7)),
    observation_start = 5, observation_end = 5
  )
  got <- dyn_durations(
    point, unit = "vertex_activity",
    measure = c("events", "total", "union", "mean", "first", "last")
  )
  expect_equal(vertex_duration_value(got, "A", "events"), 1)
  expect_equal(vertex_duration_value(got, "A", "total"), 0)
  expect_equal(vertex_duration_value(got, "A", "first"), 5)
  expect_equal(vertex_duration_value(got, "B", "events"), 1)
  expect_equal(vertex_duration_value(got, "B", "mean"), 0)
  expect_equal(vertex_duration_value(got, "C", "events"), 0)
  expect_true(is.na(vertex_duration_value(got, "C", "last")))
  empty_spells <- as.data.frame(dyn_durations(
    point, unit = "vertex_spell", censored = "exclude"
  ))
  expect_identical(names(empty_spells),
                   c("node", "vertex_spell", "implicit", "measure", "value"))

  expect_identical(
    attr(dyn_durations(point, unit = "vertex_activity"), "duration_unit"),
    "vertex_activity"
  )
  expect_identical(
    unique(as.data.frame(dyn_durations(
      point, unit = "vertex_activity"
    ))$measure), c("events", "total", "union")
  )
  expect_error(dyn_durations(point, unit = "vertex_activity",
                             measure = "duration"),
               class = "dynet_unknown_measure")
  expect_error(dyn_durations(point, unit = "vertex_spell", measure = "union"),
               class = "dynet_unknown_measure")

  truly_empty <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    vertex_spells = data.frame(node = c("A", "B"), start = 2, end = 3),
    observation_start = 0, observation_end = 1
  )
  empty <- as.data.frame(dyn_durations(truly_empty, unit = "vertex_spell"))
  expect_identical(names(empty),
                   c("node", "vertex_spell", "implicit", "measure", "value"))
  expect_equal(nrow(empty), 0L)

  singleton <- quiet_dynet(
    data.frame(from = "A", to = "A", start = 0, end = 0), loops = TRUE,
    observation_start = 0, observation_end = 5
  )
  singleton_result <- dyn_durations(
    singleton, unit = "vertex_activity", measure = c("events", "total", "union")
  )
  expect_equal(as.data.frame(singleton_result)$value, c(1, 5, 5))
})

test_that("D02 is invariant to edge rows and equivariant to node and time coordinates", {
  edges <- data.frame(
    from = c("A", "B"), to = c("B", "A"), start = c(0, 1), end = c(4, 3)
  )
  activity <- data.frame(node = c("A", "A", "B"),
                         start = c(0, 3, 1), end = c(2, 4, 3))
  measures <- c("events", "total", "union", "mean", "median", "first", "last")
  base <- quiet_dynet(edges, vertex_spells = activity,
                      observation_start = 0, observation_end = 4)
  reference <- as.data.frame(dyn_durations(
    base, unit = "vertex_activity", measure = measures
  ))
  permuted <- quiet_dynet(edges[2:1, ], vertex_spells = activity[3:1, ],
                          observation_start = 0, observation_end = 4)
  expect_equal(as.data.frame(dyn_durations(
    permuted, unit = "vertex_activity", measure = measures
  )), reference, ignore_attr = TRUE)

  renamed_edges <- transform(edges,
                             from = c("X", "Y"), to = c("Y", "X"))
  renamed_activity <- transform(activity, node = c("X", "X", "Y"))
  renamed <- quiet_dynet(renamed_edges, vertex_spells = renamed_activity,
                         observation_start = 0, observation_end = 4)
  relabeled <- as.data.frame(dyn_durations(
    renamed, unit = "vertex_activity", measure = measures
  ))
  expect_equal(relabeled$value, reference$value)

  affine_edges <- transform(edges, start = 7 + 3 * start, end = 7 + 3 * end)
  affine_activity <- transform(
    activity, start = 7 + 3 * start, end = 7 + 3 * end
  )
  affine <- quiet_dynet(affine_edges, vertex_spells = affine_activity,
                        observation_start = 7, observation_end = 19)
  transformed <- as.data.frame(dyn_durations(
    affine, unit = "vertex_activity", measure = measures
  ))
  expected <- reference$value
  expected[reference$measure %in% c("total", "union", "mean", "median")] <-
    3 * expected[reference$measure %in% c("total", "union", "mean", "median")]
  expected[reference$measure %in% c("first", "last")] <-
    7 + 3 * expected[reference$measure %in% c("first", "last")]
  expect_equal(transformed$value, expected)

  base_spell <- as.data.frame(dyn_durations(
    base, unit = "vertex_spell", measure = c("duration", "first", "last")
  ))
  permuted_spell <- as.data.frame(dyn_durations(
    permuted, unit = "vertex_spell", measure = c("duration", "first", "last")
  ))
  expect_equal(permuted_spell, base_spell, ignore_attr = TRUE)
  renamed_spell <- as.data.frame(dyn_durations(
    renamed, unit = "vertex_spell", measure = c("duration", "first", "last")
  ))
  expect_equal(renamed_spell$vertex_spell, base_spell$vertex_spell)
  expect_equal(renamed_spell$value, base_spell$value)
  affine_spell <- as.data.frame(dyn_durations(
    affine, unit = "vertex_spell", measure = c("duration", "first", "last")
  ))
  spell_expected <- base_spell$value
  spell_expected[base_spell$measure == "duration"] <-
    3 * spell_expected[base_spell$measure == "duration"]
  spell_expected[base_spell$measure %in% c("first", "last")] <-
    7 + 3 * spell_expected[base_spell$measure %in% c("first", "last")]
  expect_equal(affine_spell$vertex_spell, base_spell$vertex_spell)
  expect_equal(affine_spell$value, spell_expected)
})

test_that("D02 global schedules repeat locally and metadata is explicit", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"), start = 0, end = 5,
    wave = c("s1", "s2")
  )
  dn <- quiet_dynet(
    edges, session = "wave",
    vertex_spells = data.frame(node = "A", start = 1, end = 4),
    observation_start = 0, observation_end = 5
  )
  separate <- dyn_durations(
    dn, unit = "vertex_activity", sessions = "separate",
    measure = c("events", "total", "union")
  )
  expect_equal(vertex_duration_value(separate, "A", "events", "s1"), 1)
  expect_equal(vertex_duration_value(separate, "A", "events", "s2"), 1)
  expect_equal(vertex_duration_value(separate, "A", "total", "s1"), 3)
  expect_equal(vertex_duration_value(separate, "A", "total", "s2"), 3)
  expect_equal(vertex_duration_value(separate, "B", "union", "s1"), 5)
  expect_equal(vertex_duration_value(separate, "B", "union", "s2"), 5)
  spell <- as.data.frame(dyn_durations(
    dn, unit = "vertex_spell", sessions = "separate"
  ))
  expect_identical(spell$vertex_spell[spell$node == "A"], c(1L, 1L))

  expect_identical(attr(separate, "duration_quantity"),
                   c("events", "total", "union"))
  expect_identical(attr(separate, "activity_identity"),
                   "canonical_v01_component_plus_implicit_static")
  expect_identical(attr(separate, "activity_aggregation"),
                   "spell_sum_and_vertex_union")
  expect_identical(attr(separate, "observation_rule"),
                   "positive_support_plus_genuine_points")
  expect_identical(attr(separate, "vertex_censoring"), "included")
  expect_identical(attr(separate, "directedness"), "irrelevant")
  expect_identical(attr(separate, "session_aggregation"), "session_local")
  expect_identical(attr(dyn_durations(
    dn, unit = "vertex_activity", sessions = "bounded"
  ), "session_aggregation"), "session_local_then_union")
  expect_identical(attr(dyn_durations(
    dn, unit = "vertex_activity", sessions = "collapse"
  ), "session_aggregation"), "labels_erased")
  expect_identical(attr(dyn_durations(
    dn, unit = "vertex_activity", censored = "exclude"
  ), "vertex_censoring"), "excluded")
  spell_default <- dyn_durations(dn, unit = "vertex_spell")
  expect_identical(attr(spell_default, "duration_unit"), "vertex_spell")
  expect_identical(attr(spell_default, "duration_quantity"), "duration")
  unsessioned <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1)
  )
  expect_identical(attr(dyn_durations(
    unsessioned, unit = "vertex_activity"
  ), "session_aggregation"), "labels_erased")
})

test_that("D02 ignores every edge property outside universe and horizon", {
  activity <- data.frame(node = c("A", "B"),
                         start = c(0, 1), end = c(4, 3))
  simple <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 4),
    vertex_spells = activity, observation_start = 0, observation_end = 4
  )
  elaborate_edges <- data.frame(
    from = c("A", "A", "B", "A"), to = c("B", "B", "A", "A"),
    start = c(0, 0, 2, 1), end = c(4, 4, 2, 3),
    weight = c(1, 99, -2, 7), left = c(TRUE, FALSE, FALSE, TRUE),
    right = c(FALSE, TRUE, FALSE, TRUE)
  )
  elaborate <- quiet_dynet(
    elaborate_edges, directed = FALSE, loops = TRUE, weight = "weight",
    onset_censored = "left", terminus_censored = "right",
    vertex_spells = activity, observation_start = 0, observation_end = 4
  )
  measures <- c("events", "total", "union", "mean", "median", "first", "last")
  expect_equal(as.data.frame(dyn_durations(
    elaborate, unit = "vertex_activity", measure = measures
  )), as.data.frame(dyn_durations(
    simple, unit = "vertex_activity", measure = measures
  )), ignore_attr = TRUE)
  expect_equal(as.data.frame(dyn_durations(
    elaborate, unit = "vertex_spell", measure = c("duration", "first", "last")
  )), as.data.frame(dyn_durations(
    simple, unit = "vertex_spell", measure = c("duration", "first", "last")
  )), ignore_attr = TRUE)
})

test_that("D02 implicit activity is invariant to an empty-string vertex label", {
  dn <- quiet_dynet(
    data.frame(from = "", to = "B", start = 0, end = 2),
    nodes = data.frame(name = c("", "B")),
    observation_start = 0, observation_end = 2
  )
  got <- dyn_durations(
    dn, unit = "vertex_activity", measure = c("events", "total", "union")
  )
  expect_equal(c(
    vertex_duration_value(got, "", "events"),
    vertex_duration_value(got, "", "total"),
    vertex_duration_value(got, "", "union")
  ), c(1, 2, 2))
})
