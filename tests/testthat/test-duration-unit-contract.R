d01_value <- function(x, measure) {
  frame <- as.data.frame(x)
  frame$value[frame$measure == measure]
}

test_that("D01 distinguishes endpoint-valid spell and pair duration units", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 2), end = c(4, 6)
  )
  activity <- data.frame(node = c("A", "B"), start = 1, end = 5)
  dn <- quiet_dynet(edges, vertex_spells = activity,
                    observation_start = 0, observation_end = 6)

  spell <- as.data.frame(durations(
    dn, unit = "spell", measure = c("duration", "first", "last")
  ))
  expect_identical(names(spell),
                   c("from", "to", "raw_spell", "measure", "value"))
  expect_equal(spell$value[spell$measure == "duration"], c(3, 3))
  expect_equal(spell$value[spell$measure == "first"], c(1, 2))
  expect_equal(spell$value[spell$measure == "last"], c(4, 5))

  pair <- durations(
    dn, unit = "pair",
    measure = c("events", "total", "union", "mean", "median", "first", "last")
  )
  expect_equal(d01_value(pair, "events"), 2)
  expect_equal(d01_value(pair, "total"), 6)
  expect_equal(d01_value(pair, "union"), 4)
  expect_equal(d01_value(pair, "mean"), 3)
  expect_equal(d01_value(pair, "median"), 3)
  expect_equal(d01_value(pair, "first"), 1)
  expect_equal(d01_value(pair, "last"), 5)
  expect_identical(attr(pair, "duration_unit"), "pair")
})

test_that("D01 observation gaps fragment time without multiplying raw spells", {
  edges <- data.frame(
    from = c("A", "A", "A"), to = c("B", "B", "B"),
    start = c(1, 2, 4), end = c(9, 8, 4)
  )
  dn <- quiet_dynet(
    edges, observation_spells = data.frame(start = c(0, 6), end = c(4, 10))
  )
  spell <- as.data.frame(durations(
    dn, unit = "spell", measure = c("duration", "first", "last")
  ))
  expect_equal(spell$value[spell$measure == "duration"], c(6, 4, 0))
  expect_equal(spell$value[spell$measure == "first"], c(1, 2, 4))
  expect_equal(spell$value[spell$measure == "last"], c(9, 8, 4))
  pair <- durations(
    dn, unit = "pair", measure = c("events", "total", "union")
  )
  expect_equal(d01_value(pair, "events"), 3)
  expect_equal(d01_value(pair, "total"), 10)
  expect_equal(d01_value(pair, "union"), 6)
})

test_that("D01 censoring removes whole raw identities before every unit", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"), start = c(0, 1), end = c(3, 4),
    left = c(FALSE, TRUE), right = FALSE
  )
  dn <- quiet_dynet(
    edges, onset_censored = "left", terminus_censored = "right",
    observation_start = 0, observation_end = 4
  )
  included <- durations(
    dn, unit = "pair", measure = c("events", "total", "union")
  )
  excluded <- durations(
    dn, unit = "pair", measure = c("events", "total", "union"),
    censored = "exclude"
  )
  expect_equal(d01_value(included, "events"), 2)
  expect_equal(d01_value(included, "total"), 6)
  expect_equal(d01_value(included, "union"), 4)
  expect_equal(d01_value(excluded, "events"), 1)
  expect_equal(d01_value(excluded, "total"), 3)
  expect_equal(d01_value(excluded, "union"), 3)
})

test_that("D01 validates unit-specific measure names", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
  expect_error(durations(dn, unit = "spell", measure = "union"),
               class = "dynet_unknown_measure")
  expect_error(durations(dn, unit = "pair", measure = "duration"),
               class = "dynet_unknown_measure")
})

test_that("D01 collapse authorizes across labels but bounded remains local", {
  edges <- data.frame(
    from = c("A", "C"), to = c("B", "D"), start = c(0, 0), end = c(5, 0),
    wave = c("s1", "s2")
  )
  activity <- data.frame(
    node = c("A", "B"), start = 0, end = 5, session = "s2"
  )
  dn <- quiet_dynet(edges, session = "wave", vertex_spells = activity,
                    observation_start = 0, observation_end = 5)
  collapsed <- as.data.frame(durations(
    dn, unit = "pair", measure = "union", sessions = "collapse"
  ))
  bounded <- as.data.frame(durations(
    dn, unit = "pair", measure = "union", sessions = "bounded"
  ))
  separate <- as.data.frame(durations(
    dn, unit = "pair", measure = "union", sessions = "separate"
  ))
  expect_equal(collapsed$value[collapsed$from == "A"], 5)
  expect_false("A" %in% bounded$from)
  expect_false("A" %in% separate$from)
})

test_that("D01 direction, undirected dyads, loops, empties and defaults are exact", {
  edges <- data.frame(
    from = c("A", "B", "A"), to = c("B", "A", "A"),
    start = c(0, 1, 0), end = c(2, 4, 1)
  )
  directed <- quiet_dynet(edges, loops = TRUE,
                          observation_start = 0, observation_end = 4)
  got <- as.data.frame(durations(
    directed, unit = "pair", measure = c("events", "total", "union")
  ))
  expect_equal(got$value[got$from == "A" & got$to == "B" &
                           got$measure == "union"], 2)
  expect_equal(got$value[got$from == "B" & got$to == "A" &
                           got$measure == "union"], 3)
  expect_equal(got$value[got$from == "A" & got$to == "A" &
                           got$measure == "union"], 1)

  undirected <- quiet_dynet(edges[1:2, ], directed = FALSE,
                            observation_start = 0, observation_end = 4)
  dyad <- durations(
    undirected, unit = "pair", measure = c("events", "total", "union")
  )
  expect_equal(d01_value(dyad, "events"), 2)
  expect_equal(d01_value(dyad, "total"), 5)
  expect_equal(d01_value(dyad, "union"), 4)

  inactive <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 2),
    vertex_spells = data.frame(node = c("A", "B"),
                               start = c(0, 1), end = c(1, 2)),
    observation_start = 0, observation_end = 2
  )
  empty_pair <- as.data.frame(durations(inactive, unit = "pair"))
  empty_spell <- as.data.frame(durations(inactive, unit = "spell"))
  expect_identical(names(empty_pair), c("from", "to", "measure", "value"))
  expect_identical(names(empty_spell),
                   c("from", "to", "raw_spell", "measure", "value"))
  expect_equal(nrow(empty_pair), 0L)
  expect_equal(nrow(empty_spell), 0L)

  expect_equal(
    as.data.frame(durations(directed)),
    as.data.frame(durations(
      directed, c("events", "total", "mean"), "bounded", "include",
      unit = "pair"
    )), ignore_attr = TRUE
  )
  expect_identical(attr(durations(directed), "session_aggregation"),
                   "labels_erased")
})

test_that("D01 fragment helpers expose exact raw-identity pieces directly", {
  dn <- quiet_dynet(
    data.frame(from = c("A", "A"), to = c("B", "B"),
               start = c(0, 2), end = c(4, 2)),
    vertex_spells = data.frame(node = c("A", "B"), start = 1, end = 3),
    observation_start = 0, observation_end = 4
  )
  fragments <- Dynet:::.duration_fragments(
    dn, Dynet:::.encode(dn), erase_sessions = TRUE, censored = "include"
  )
  expect_equal(
    fragments,
    data.frame(from = c("A", "A"), to = c("B", "B"),
               raw_spell = 1:2, start = c(1, 2), end = c(3, 2),
               instant = c(FALSE, TRUE)),
    ignore_attr = TRUE
  )
  blocks <- Dynet:::.duration_fragment_blocks(dn, "bounded", "include")
  expect_identical(names(blocks), "all")
  expect_equal(blocks$all, fragments, ignore_attr = TRUE)
})

test_that("D01 is invariant to coordinates and equivariant to affine time", {
  edges <- data.frame(
    from = c("A", "A", "B"), to = c("B", "B", "A"),
    start = c(0, 1, 3), end = c(2, 4, 3)
  )
  activity <- data.frame(node = c("A", "B"), start = 0, end = 4)
  measures <- c("events", "total", "union", "mean", "median", "first", "last")
  dn <- quiet_dynet(edges, vertex_spells = activity,
                    observation_start = 0, observation_end = 4)
  reference <- as.data.frame(durations(dn, measure = measures))

  permuted <- quiet_dynet(edges[c(3, 1, 2), ], vertex_spells = activity,
                          observation_start = 0, observation_end = 4)
  expect_equal(as.data.frame(durations(permuted, measure = measures)),
               reference, ignore_attr = TRUE)

  renamed_edges <- edges
  renamed_edges$from <- c("X", "X", "Y")
  renamed_edges$to <- c("Y", "Y", "X")
  renamed_activity <- activity
  renamed_activity$node <- c("X", "Y")
  renamed <- quiet_dynet(renamed_edges, vertex_spells = renamed_activity,
                         observation_start = 0, observation_end = 4)
  renamed_result <- as.data.frame(durations(renamed, measure = measures))
  expect_equal(renamed_result$value, reference$value)
  expect_identical(renamed_result$measure, reference$measure)

  affine_edges <- edges
  affine_edges$start <- 10 + 2 * affine_edges$start
  affine_edges$end <- 10 + 2 * affine_edges$end
  affine_activity <- activity
  affine_activity$start <- 10 + 2 * affine_activity$start
  affine_activity$end <- 10 + 2 * affine_activity$end
  affine <- quiet_dynet(affine_edges, vertex_spells = affine_activity,
                        observation_start = 10, observation_end = 18)
  transformed <- as.data.frame(durations(affine, measure = measures))
  expected <- reference$value
  duration_measure <- reference$measure %in%
    c("total", "union", "mean", "median")
  endpoint_measure <- reference$measure %in% c("first", "last")
  expected[duration_measure] <- 2 * expected[duration_measure]
  expected[endpoint_measure] <- 10 + 2 * expected[endpoint_measure]
  expect_equal(transformed$value, expected)

  base_spell <- as.data.frame(durations(
    dn, unit = "spell", measure = c("duration", "first", "last")
  ))
  affine_spell <- as.data.frame(durations(
    affine, unit = "spell", measure = c("duration", "first", "last")
  ))
  spell_expected <- base_spell$value
  is_duration <- base_spell$measure == "duration"
  spell_expected[is_duration] <- 2 * spell_expected[is_duration]
  spell_expected[!is_duration] <- 10 + 2 * spell_expected[!is_duration]
  expect_equal(affine_spell$value, spell_expected)
})
