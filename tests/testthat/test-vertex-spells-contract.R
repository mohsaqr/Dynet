v01_core_spells <- function() {
  data.frame(
    node = c("A", "B", "A", "C", "B", "E", "A", "B", "C", "B", "B"),
    start = c(0, 2, 2, 4, 1, 10, 5, 4, 0, 6, 2),
    end = c(3, 2, 5, 6, 4, 12, 7, 4, 2, 6, 2),
    onset_censored = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
                       TRUE, FALSE, FALSE, FALSE, FALSE),
    terminus_censored = c(TRUE, FALSE, TRUE, FALSE, FALSE, TRUE,
                          FALSE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
}

v01_edges <- function() {
  data.frame(
    from = c("A", "D"), to = c("B", "C"),
    start = c(0, 0), end = c(7, 6), stringsAsFactors = FALSE
  )
}

v01_key <- function(x) {
  x[order(is.na(x$session), x$session, x$node, x$start, x$end),
    c("node", "start", "end", "duration", "instant", "session",
      "onset_censored", "terminus_censored")]
}

test_that("V01 canonicalizes declared vertex activity literally", {
  dn <- quiet_dynet(v01_edges(), vertex_spells = v01_core_spells())
  actual <- as.data.frame(dn, what = "vertex_spells")
  expected <- data.frame(
    vertex_spell = 1:7,
    node = c("A", "B", "B", "B", "C", "C", "E"),
    start = c(0, 1, 4, 6, 0, 4, 10),
    end = c(7, 4, 4, 6, 2, 6, 12),
    duration = c(7, 3, 0, 0, 2, 2, 2),
    instant = c(FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE),
    session = rep(NA_character_, 7),
    onset_censored = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    terminus_censored = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  expect_equal(actual, expected, ignore_attr = TRUE)
  expect_identical(
    names(actual),
    c("vertex_spell", "node", "start", "end", "duration", "instant",
      "session", "onset_censored", "terminus_censored")
  )
  expect_identical(as.data.frame(dn, what = "nodes")$name,
                   c("A", "B", "C", "D", "E"))
  expect_identical(dn$meta$vertex_activity, "explicit")
  expect_identical(dn$meta$vertex_activity_default,
                   "always_for_unlisted_nodes")
  expect_identical(dn$meta$vertex_activity_interval,
                   "positive_half_open_instant_closed")
  expect_identical(dn$meta$vertex_activity_input_rows, 11L)
  expect_identical(dn$meta$vertex_activity_components, 7L)
  expect_identical(dn$meta$n_dynamic_vertices, 4L)
  expect_identical(dn$meta$n_implicit_static_vertices, 1L)
  expect_identical(dn$meta$n_vertex_onset_censored, 2L)
  expect_identical(dn$meta$n_vertex_terminus_censored, 3L)
  expect_identical(dn$meta$edge_vertex_activity_policy,
                   "snapshot_induced_v02_paths_endpoint_gated_v03")
})

test_that("V01 normalization helpers expose the same typed canonical contract", {
  direct <- Dynet:::.normalize_vertex_spells(
    v01_core_spells(), origin = 0, time_unit = "step"
  )
  public <- as.data.frame(quiet_dynet(
    v01_edges(), vertex_spells = v01_core_spells()
  ), what = "vertex_spells")
  expect_equal(direct$spells, public, ignore_attr = TRUE)
  expect_equal(Dynet:::.empty_vertex_spells(), public[FALSE, ],
               ignore_attr = TRUE)

  nodes <- data.frame(name = c("A", "B", "C", "D"),
                      role = c("x", "x", "y", "y"))
  with_isolate <- quiet_dynet(
    v01_edges(), nodes = nodes,
    vertex_spells = data.frame(node = "E", start = 0, end = 1)
  )
  node_table <- as.data.frame(with_isolate, what = "nodes")
  expect_true(is.na(node_table$role[node_table$name == "E"]))
})

test_that("V01 uses half-open point coverage and stable optional defaults", {
  spells <- data.frame(
    node = rep("A", 7),
    start = c(0, 1, 2, 4, 4, 5, 5),
    end = c(2, 4, 2, 4, 4, 5, 5)
  )
  dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 6
  ), vertex_spells = spells)
  actual <- as.data.frame(dn, what = "vertex_spells")
  expect_equal(actual$start, c(0, 4, 5))
  expect_equal(actual$end, c(4, 4, 5))
  expect_identical(actual$instant, c(FALSE, TRUE, TRUE))
  expect_identical(actual$session, rep(NA_character_, 3))
  expect_identical(actual$onset_censored, rep(FALSE, 3))
  expect_identical(actual$terminus_censored, rep(FALSE, 3))
})

test_that("V01 reduces only censor flags at union extrema with OR", {
  outer <- data.frame(
    node = "A", start = c(0, 0, 1, 1), end = c(4, 3, 4, 3),
    onset_censored = c(FALSE, TRUE, FALSE, TRUE),
    terminus_censored = c(FALSE, FALSE, TRUE, TRUE)
  )
  out <- as.data.frame(quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 4
  ), vertex_spells = outer), what = "vertex_spells")
  expect_equal(out[c("start", "end")], data.frame(start = 0, end = 4))
  expect_true(out$onset_censored)
  expect_true(out$terminus_censored)

  interior <- data.frame(
    node = "A", start = c(0, 1), end = c(4, 3),
    onset_censored = c(FALSE, TRUE),
    terminus_censored = c(FALSE, TRUE)
  )
  out <- as.data.frame(quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 4
  ), vertex_spells = interior), what = "vertex_spells")
  expect_false(out$onset_censored)
  expect_false(out$terminus_censored)
})

test_that("V01 keeps sessions separate without changing the edge session universe", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"), start = c(0, 0), end = c(5, 5),
    wave = c("s1", "s2")
  )
  spells <- data.frame(
    node = c("A", "A", "A"), start = c(0, 2, 0), end = c(2, 4, 4),
    session = c("s1", "s1", "s2")
  )
  dn <- quiet_dynet(edges, session = "wave", vertex_spells = spells)
  actual <- as.data.frame(dn, what = "vertex_spells")
  expect_equal(actual$node, c("A", "A"))
  expect_equal(actual$start, c(0, 0))
  expect_equal(actual$end, c(4, 4))
  expect_identical(actual$session, c("s1", "s2"))
  expect_identical(dn$meta$sessions, c("s1", "s2"))
  expect_identical(dn$meta$vertex_sessions, c("s1", "s2"))

  global <- quiet_dynet(
    edges, session = "wave",
    vertex_spells = data.frame(node = "A", start = 0, end = 4)
  )
  expect_true(is.na(as.data.frame(global, what = "vertex_spells")$session))
  expect_identical(global$meta$sessions, c("s1", "s2"))
  expect_null(global$meta$vertex_sessions)
})

test_that("V01 session components retain points, gaps, and outer censor state", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"), start = 0, end = 5,
    wave = c("s1", "s2")
  )
  spells <- data.frame(
    node = "A", start = c(0, 2, 4, 0, 1, 3),
    end = c(2, 4, 4, 1, 1, 4),
    session = c("s1", "s1", "s1", "s2", "s2", "s2"),
    onset_censored = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
    terminus_censored = c(FALSE, TRUE, FALSE, FALSE, FALSE, TRUE)
  )
  actual <- as.data.frame(quiet_dynet(
    edges, session = "wave", vertex_spells = spells
  ), what = "vertex_spells")
  expected <- data.frame(
    vertex_spell = 1:5, node = rep("A", 5),
    start = c(0, 4, 0, 1, 3), end = c(4, 4, 1, 1, 4),
    duration = c(4, 0, 1, 0, 1),
    instant = c(FALSE, TRUE, FALSE, TRUE, FALSE),
    session = c("s1", "s1", "s2", "s2", "s2"),
    onset_censored = c(TRUE, FALSE, FALSE, FALSE, FALSE),
    terminus_censored = c(TRUE, FALSE, FALSE, FALSE, TRUE)
  )
  expect_equal(actual, expected, ignore_attr = TRUE)
})

test_that("V01 session and node identifiers cannot collide through serialization", {
  edges <- data.frame(
    from = c("b\rc", "c"), to = c("X", "Y"), start = 0, end = 2,
    wave = c("a", "a\rb")
  )
  spells <- data.frame(
    node = c("b\rc", "c"), start = c(0, 1), end = c(1, 2),
    session = c("a", "a\rb")
  )
  actual <- as.data.frame(quiet_dynet(
    edges, session = "wave", vertex_spells = spells
  ), what = "vertex_spells")
  expect_equal(nrow(actual), 2L)
  expect_setequal(paste(actual$session, actual$node),
                  paste(spells$session, spells$node))
})

test_that("V01 accepts numeric, Date, and POSIXct vertex clocks", {
  numeric_dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 10, end = 20
  ), vertex_spells = data.frame(node = "A", start = 12, end = 17))
  expect_equal(as.data.frame(numeric_dn, what = "vertex_spells")$start, 12)
  expect_equal(as.data.frame(numeric_dn, what = "vertex_spells")$end, 17)

  day <- as.Date("2026-08-01")
  date_dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = day, end = day + 5
  ), time_unit = "days",
  vertex_spells = data.frame(node = "A", start = day + 1, end = day + 3))
  expect_equal(as.data.frame(date_dn, what = "vertex_spells")$start, 1)
  expect_equal(as.data.frame(date_dn, what = "vertex_spells")$end, 3)

  hour <- as.POSIXct("2026-08-01 00:00:00", tz = "UTC")
  posix_dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = hour, end = hour + 6 * 3600
  ), time_unit = "hours", vertex_spells = data.frame(
    node = "A", start = hour + 3600, end = hour + 3 * 3600
  ))
  expect_equal(as.data.frame(posix_dn, what = "vertex_spells")$start, 1)
  expect_equal(as.data.frame(posix_dn, what = "vertex_spells")$end, 3)
})

test_that("V01 is invariant to source order, relabeling, translation, and scale", {
  raw <- v01_core_spells()
  base <- quiet_dynet(v01_edges(), vertex_spells = raw)
  permuted <- quiet_dynet(v01_edges(), vertex_spells = raw[c(11:1), ])
  expect_equal(as.data.frame(permuted, what = "vertex_spells"),
               as.data.frame(base, what = "vertex_spells"),
               ignore_attr = TRUE)

  map <- c(A = "z", B = "x", C = "y", D = "v", E = "w")
  renamed <- raw
  renamed$node <- unname(map[renamed$node])
  renamed_edges <- v01_edges()
  renamed_edges$from <- unname(map[renamed_edges$from])
  renamed_edges$to <- unname(map[renamed_edges$to])
  relabeled <- quiet_dynet(renamed_edges, vertex_spells = renamed)
  expect_identical(as.data.frame(relabeled, what = "nodes")$name,
                   sort(unname(map)))
  relabeled_table <- as.data.frame(relabeled, what = "vertex_spells")
  relabeled_table$node <- names(map)[match(relabeled_table$node, map)]
  expect_equal(v01_key(relabeled_table),
               v01_key(as.data.frame(base, what = "vertex_spells")),
               ignore_attr = TRUE)

  shifted <- transform(raw, start = start + 17, end = end + 17)
  shifted_edges <- transform(v01_edges(), start = start + 17, end = end + 17)
  shifted_table <- as.data.frame(
    quiet_dynet(shifted_edges, vertex_spells = shifted),
    what = "vertex_spells"
  )
  shifted_table$start <- shifted_table$start - 17
  shifted_table$end <- shifted_table$end - 17
  expect_equal(v01_key(shifted_table),
               v01_key(as.data.frame(base, what = "vertex_spells")),
               ignore_attr = TRUE)

  scaled <- transform(raw, start = start * 3, end = end * 3)
  scaled_edges <- transform(v01_edges(), start = start * 3, end = end * 3)
  scaled_table <- as.data.frame(
    quiet_dynet(scaled_edges, vertex_spells = scaled),
    what = "vertex_spells"
  )
  expect_equal(scaled_table$duration,
               3 * as.data.frame(base, what = "vertex_spells")$duration)
  scaled_table$start <- scaled_table$start / 3
  scaled_table$end <- scaled_table$end / 3
  scaled_table$duration <- scaled_table$duration / 3
  expect_equal(v01_key(scaled_table),
               v01_key(as.data.frame(base, what = "vertex_spells")),
               ignore_attr = TRUE)

  reversal_source <- raw[raw$start < raw$end, , drop = FALSE]
  reversal_base <- quiet_dynet(v01_edges(), vertex_spells = reversal_source)
  reversed <- transform(
    reversal_source, start = 20 - end, end = 20 - start,
    onset_censored = terminus_censored,
    terminus_censored = onset_censored
  )
  reversed_edges <- transform(
    v01_edges(), start = 20 - end, end = 20 - start
  )
  reversed_table <- as.data.frame(quiet_dynet(
    reversed_edges, vertex_spells = reversed
  ), what = "vertex_spells")
  expected_reversed <- as.data.frame(reversal_base, what = "vertex_spells")
  old_start <- expected_reversed$start
  expected_reversed$start <- 20 - expected_reversed$end
  expected_reversed$end <- 20 - old_start
  old_onset <- expected_reversed$onset_censored
  expected_reversed$onset_censored <- expected_reversed$terminus_censored
  expected_reversed$terminus_censored <- old_onset
  expected_reversed <- expected_reversed[order(
    expected_reversed$node, expected_reversed$start, expected_reversed$end
  ), , drop = FALSE]
  rownames(expected_reversed) <- NULL
  expected_reversed$vertex_spell <- seq_len(nrow(expected_reversed))
  expect_equal(reversed_table, expected_reversed, ignore_attr = TRUE)
})

test_that("V01 session relabeling changes labels but not components", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"), start = 0, end = 5,
    wave = c("s1", "s2")
  )
  spells <- data.frame(
    node = c("A", "A", "A"), start = c(0, 2, 1), end = c(2, 4, 3),
    session = c("s1", "s1", "s2")
  )
  base <- as.data.frame(quiet_dynet(
    edges, session = "wave", vertex_spells = spells
  ), what = "vertex_spells")
  session_map <- c(s1 = "beta", s2 = "alpha")
  edges$wave <- unname(session_map[edges$wave])
  spells$session <- unname(session_map[spells$session])
  renamed <- as.data.frame(quiet_dynet(
    edges, session = "wave", vertex_spells = spells
  ), what = "vertex_spells")
  renamed$session <- names(session_map)[match(renamed$session, session_map)]
  expect_equal(v01_key(renamed), v01_key(base), ignore_attr = TRUE)
})

test_that("V01 raw storage stays non-destructive after V03 derived views", {
  edges <- data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 2), end = c(7, 6)
  )
  spells <- data.frame(
    node = c("A", "B", "C"), start = c(1, 4, 0), end = c(3, 5, 1)
  )
  legacy <- quiet_dynet(edges)
  expect_no_warning(explicit <- quiet_dynet(edges, vertex_spells = spells))
  expect_equal(as.data.frame(explicit), as.data.frame(legacy),
               ignore_attr = TRUE)
  expect_equal(as.data.frame(explicit, what = "bins"),
               as.data.frame(legacy, what = "bins"), ignore_attr = TRUE)
  expect_false(identical(
    as.data.frame(dyn_metrics(explicit, measure = "density"))$value,
    as.data.frame(dyn_metrics(legacy, measure = "density"))$value
  ))
  expect_equal(nrow(dyn_snapshots(explicit, at = 3, window = 0)), 0)
  expect_gt(nrow(dyn_snapshots(legacy, at = 3, window = 0)), 0)
  explicit_paths <- as.data.frame(dyn_paths(explicit, from = "A"))
  legacy_paths <- as.data.frame(dyn_paths(legacy, from = "A"))
  expect_false(any(explicit_paths$reachable))
  expect_true(all(explicit_paths$n_paths == 0))
  expect_true(all(legacy_paths$reachable))
  expect_equal(as.data.frame(dyn_events(
    explicit, measure = c("formation", "dissolution", "active", "new_pairs")
  )), as.data.frame(dyn_events(
    legacy, measure = c("formation", "dissolution", "active", "new_pairs")
  )), ignore_attr = TRUE)
  explicit_duration <- as.data.frame(dyn_durations(
    explicit, measure = c("events", "total")
  ))
  legacy_duration <- as.data.frame(dyn_durations(
    legacy, measure = c("events", "total")
  ))
  expect_equal(nrow(explicit_duration), 0L)
  expect_equal(nrow(legacy_duration), 4L)
  expect_equal(explicit$meta$time_range, legacy$meta$time_range)

  bounded <- quiet_dynet(
    edges, vertex_spells = spells,
    observation_start = 1, observation_end = 5
  )
  gapped <- quiet_dynet(
    edges, vertex_spells = spells,
    observation_spells = data.frame(start = c(1, 4), end = c(2, 5))
  )
  expect_equal(as.data.frame(bounded, what = "vertex_spells"),
               as.data.frame(explicit, what = "vertex_spells"),
               ignore_attr = TRUE)
  expect_equal(as.data.frame(gapped, what = "vertex_spells"),
               as.data.frame(explicit, what = "vertex_spells"),
               ignore_attr = TRUE)
})

test_that("V01 all-static inputs have a typed empty accessor", {
  legacy <- quiet_dynet(v01_edges())
  empty <- data.frame(node = character(), start = numeric(), end = numeric())
  explicit_empty <- quiet_dynet(v01_edges(), vertex_spells = empty)
  expected <- data.frame(
    vertex_spell = integer(), node = character(), start = numeric(),
    end = numeric(), duration = numeric(), instant = logical(),
    session = character(), onset_censored = logical(),
    terminus_censored = logical(), stringsAsFactors = FALSE
  )
  expect_equal(as.data.frame(legacy, what = "vertex_spells"), expected,
               ignore_attr = TRUE)
  expect_equal(as.data.frame(explicit_empty, what = "vertex_spells"), expected,
               ignore_attr = TRUE)
  expect_identical(legacy$meta$vertex_activity, "static")
  expect_identical(explicit_empty$meta$vertex_activity, "static")
  expect_equal(as.data.frame(explicit_empty), as.data.frame(legacy),
               ignore_attr = TRUE)

  empty_session <- data.frame(
    node = character(), start = numeric(), end = numeric(),
    session = character()
  )
  session_typed <- quiet_dynet(v01_edges(), vertex_spells = empty_session)
  expect_equal(as.data.frame(session_typed, what = "vertex_spells"), expected,
               ignore_attr = TRUE)
})

test_that("V01 loop cleaning and internal netobject slices preserve activity", {
  edges <- data.frame(
    from = c("A", "A"), to = c("A", "B"), start = c(0, 0), end = c(2, 2)
  )
  spells <- data.frame(node = c("A", "B"), start = c(0, 1), end = c(2, 2))
  dropped <- quiet_dynet(edges, loops = FALSE, vertex_spells = spells)
  kept <- quiet_dynet(edges, loops = TRUE, vertex_spells = spells)
  expect_equal(as.data.frame(dropped, what = "vertex_spells"),
               as.data.frame(kept, what = "vertex_spells"),
               ignore_attr = TRUE)
  expect_identical(as.data.frame(dropped, what = "nodes")$name, c("A", "B"))
  expect_identical(as.data.frame(kept, what = "nodes")$name, c("A", "B"))

  expected <- as.data.frame(kept, what = "vertex_spells")
  ranged <- Dynet:::.range_netobject(kept, 0, 2)
  binned <- Dynet:::.bin_netobject(kept, 1)
  expect_equal(as.data.frame(ranged, what = "vertex_spells"), expected,
               ignore_attr = TRUE)
  expect_equal(as.data.frame(binned, what = "vertex_spells"), expected,
               ignore_attr = TRUE)
})

test_that("V01 validates its fixed schema, values, flags, and sessions", {
  edges <- v01_edges()
  good <- data.frame(node = "A", start = 0, end = 1)
  expect_error(dynet(edges, vertex_spells = 1),
               class = "dynet_bad_vertex_spells")
  expect_error(dynet(edges, vertex_spells = data.frame(node = "A", start = 0)),
               class = "dynet_missing_column")
  expect_error(dynet(edges, vertex_spells = transform(good, attribute = 1)),
               class = "dynet_bad_vertex_spells")
  duplicate_names <- good
  names(duplicate_names)[3] <- "start"
  expect_error(dynet(edges, vertex_spells = duplicate_names),
               class = "dynet_bad_vertex_spells")
  expect_error(dynet(edges, vertex_spells = transform(good, node = NA_character_)),
               class = "dynet_bad_vertex_spells")
  expect_error(dynet(edges, vertex_spells = transform(good, node = "")),
               class = "dynet_bad_vertex_spells")
  expect_error(dynet(edges, vertex_spells = transform(good, start = Inf)),
               class = "dynet_bad_vertex_spells")
  expect_error(dynet(edges, vertex_spells = transform(good, start = 2, end = 1)),
               class = "dynet_bad_vertex_spells")
  expect_error(dynet(edges, vertex_spells = transform(good,
    onset_censored = 1)), class = "dynet_bad_vertex_censor")
  expect_error(dynet(edges, vertex_spells = transform(good,
    onset_censored = NA)), class = "dynet_bad_vertex_censor")
  expect_error(dynet(edges, vertex_spells = data.frame(
    node = "A", start = 1, end = 1, onset_censored = TRUE
  )), class = "dynet_bad_vertex_censor")
  expect_error(dynet(edges, vertex_spells = transform(good, session = "s1")),
               class = "dynet_incompatible_vertex_spells")

  session_edges <- transform(edges, wave = c("s1", "s2"))
  expect_error(dynet(session_edges, session = "wave",
                     vertex_spells = transform(good, session = "s3")),
               class = "dynet_unknown_session")
  mixed <- rbind(transform(good, session = "s1"),
                 transform(good, session = NA_character_))
  expect_error(dynet(session_edges, session = "wave", vertex_spells = mixed),
               class = "dynet_bad_vertex_spells")
})
