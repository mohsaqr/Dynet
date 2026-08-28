.ps_labels <- c(
  "AB-BA", "AB-B0", "AB-BY", "A0-X0", "A0-XA", "A0-XY",
  "AB-X0", "AB-XA", "AB-XB", "AB-XY", "A0-AY", "AB-A0", "AB-AY"
)
.ps_families <- c(
  rep("turn_receiving", 3L), rep("turn_claiming", 3L),
  rep("turn_usurping", 4L), rep("turn_continuing", 3L)
)

.ps_add_named <- function(rows, session, time, speaker, target, ...) {
  rows[[length(rows) + 1L]] <- data.frame(
    from = speaker, to = target, start = time, end = time,
    session = session, stringsAsFactors = FALSE, ...
  )
  rows
}

.ps_add_group <- function(rows, session, time, speaker, stem) {
  rows <- .ps_add_named(rows, session, time, speaker, paste0(stem, "1"))
  .ps_add_named(rows, session, time, speaker, paste0(stem, "2"))
}

.ps_all_classes <- function() {
  rows <- list()
  add_pair <- function(index, first, second) {
    session <- sprintf("s%02d", index)
    if (identical(first[[2L]], "0")) {
      rows <<- .ps_add_group(rows, session, 1, first[[1L]], paste0("P", index))
    } else {
      rows <<- .ps_add_named(rows, session, 1, first[[1L]], first[[2L]])
    }
    if (identical(second[[2L]], "0")) {
      rows <<- .ps_add_group(rows, session, 2, second[[1L]], paste0("Q", index))
    } else {
      rows <<- .ps_add_named(rows, session, 2, second[[1L]], second[[2L]])
    }
  }
  ledger <- list(
    list(c("A", "B"), c("B", "A")),
    list(c("A", "B"), c("B", "0")),
    list(c("A", "B"), c("B", "C")),
    list(c("A", "0"), c("C", "0")),
    list(c("A", "0"), c("C", "A")),
    list(c("A", "0"), c("C", "B")),
    list(c("A", "B"), c("C", "0")),
    list(c("A", "B"), c("C", "A")),
    list(c("A", "B"), c("C", "B")),
    list(c("A", "B"), c("C", "D")),
    list(c("A", "0"), c("A", "B")),
    list(c("A", "B"), c("A", "0")),
    list(c("A", "B"), c("A", "C"))
  )
  for (i in seq_along(ledger)) add_pair(i, ledger[[i]][[1L]], ledger[[i]][[2L]])
  do.call(rbind, rows)
}

test_that("E01 classifier maps the thirteen literal role pairs exactly", {
  turn <- function(speaker, target = NA_character_, group = FALSE,
                   loop = FALSE) {
    list(speaker = speaker, target = target, group = group, loop = loop)
  }
  pairs <- list(
    list(turn("A", "B"), turn("B", "A")),
    list(turn("A", "B"), turn("B", group = TRUE)),
    list(turn("A", "B"), turn("B", "C")),
    list(turn("A", group = TRUE), turn("C", group = TRUE)),
    list(turn("A", group = TRUE), turn("C", "A")),
    list(turn("A", group = TRUE), turn("C", "B")),
    list(turn("A", "B"), turn("C", group = TRUE)),
    list(turn("A", "B"), turn("C", "A")),
    list(turn("A", "B"), turn("C", "B")),
    list(turn("A", "B"), turn("C", "D")),
    list(turn("A", group = TRUE), turn("A", "B")),
    list(turn("A", "B"), turn("A", group = TRUE)),
    list(turn("A", "B"), turn("A", "C"))
  )
  actual <- vapply(pairs, function(x) {
    Dynet:::.pshift_classify(x[[1L]], x[[2L]])
  }, integer(1L))
  expect_identical(actual, seq_len(13L))
  expect_identical(Dynet:::.pshift_labels, .ps_labels)
  expect_identical(Dynet:::.pshift_families, .ps_families)
  expect_true(is.na(Dynet:::.pshift_classify(
    turn("A", "B"), turn("A", "B")
  )))
  expect_true(is.na(Dynet:::.pshift_classify(
    turn("A", "B"), turn("C", "C", loop = TRUE)
  )))
})

test_that("E01 literal session ledger yields one of every class", {
  dn <- quiet_dynet(
    .ps_all_classes(), session = "session",
    observation_start = 0, observation_end = 3
  )
  separate <- pshifts(dn, sessions = "separate")
  expect_s3_class(separate, "dynet_pshifts")
  expect_identical(names(separate), c("session", "shift", "family", "measure", "value"))
  expect_identical(separate$shift, rep(.ps_labels, 13L))
  expect_identical(separate$family, rep(.ps_families, 13L))
  for (i in seq_len(13L)) {
    block <- separate[separate$session == sprintf("s%02d", i), ]
    expect_identical(block$value, as.integer(seq_len(13L) == i))
  }
  bounded <- pshifts(dn, sessions = "bounded")
  expect_identical(bounded$value, rep(1L, 13L))
})

test_that("E01 cumulative output uses public labels and terminal class state", {
  dn <- quiet_dynet(
    data.frame(
      from = c("A", "B"), to = c("B", "A"),
      start = c(1, 2), end = c(1, 2)
    ), observation_start = 0, observation_end = 3
  )
  cumulative <- pshifts(dn, output = "cumulative")
  expect_identical(
    names(cumulative),
    c("sequence", "event", "time", "speaker", "target", "group",
      "shift", "family", "measure", "value")
  )
  expect_identical(nrow(cumulative), 26L)
  expect_identical(cumulative$speaker, rep(c("A", "B"), each = 13L))
  expect_identical(cumulative$target, rep(c("B", "A"), each = 13L))
  expect_type(cumulative$speaker, "character")
  expect_type(cumulative$target, "character")
  expect_identical(cumulative$value[1:13], integer(13L))
  expect_identical(cumulative$value[14:26], c(1L, integer(12L)))
  terminal <- cumulative[cumulative$event == max(cumulative$event), ]
  expect_identical(terminal$value, pshifts(dn)$value)

  group <- quiet_dynet(
    data.frame(
      from = c("A", "A"), to = c("B", "C"),
      start = c(1, 1), end = c(1, 1)
    ), observation_start = 0, observation_end = 2
  )
  grouped <- pshifts(group, output = "cumulative")
  expect_identical(nrow(grouped), 13L)
  expect_true(all(grouped$group))
  expect_type(grouped$target, "character")
  expect_true(all(is.na(grouped$target)))
})

test_that("E01 simultaneous inference differs from repeated dyads and opt-out", {
  group_edges <- data.frame(
    from = c("A", "B", "B"), to = c("B", "C", "D"),
    start = c(1, 2, 2), end = c(1, 2, 2)
  )
  group_dn <- quiet_dynet(
    group_edges, observation_start = 0, observation_end = 3
  )
  inferred <- pshifts(group_dn)
  expect_identical(inferred$value, as.integer(seq_len(13L) == 2L))
  opt_out <- pshifts(group_dn, group_events = "none")
  expected <- integer(13L)
  expected[c(3L, 13L)] <- 1L
  expect_identical(opt_out$value, expected)

  duplicate <- transform(group_edges, to = c("B", "C", "C"))
  repeated <- pshifts(quiet_dynet(
    duplicate, observation_start = 0, observation_end = 3
  ))
  expect_identical(repeated$value, as.integer(seq_len(13L) == 3L))

  permuted <- quiet_dynet(
    group_edges[c(3, 1, 2), ], observation_start = 0, observation_end = 3
  )
  expect_identical(pshifts(permuted)$value, inferred$value)

  tied <- data.frame(
    from = c("C", "A"), to = c("D", "B"),
    start = c(1, 1), end = c(1, 1)
  )
  tied_dn <- quiet_dynet(tied, observation_start = 0, observation_end = 2)
  tied_expected <- as.integer(seq_len(13L) == 10L)
  expect_identical(pshifts(tied_dn)$value, tied_expected)
  expect_identical(
    pshifts(quiet_dynet(
      tied[2:1, ], observation_start = 0, observation_end = 2
    ))$value,
    tied_expected
  )
})

test_that("E01 observation components, queries, loops, and sessions are walls", {
  gap <- quiet_dynet(
    data.frame(
      from = c("A", "B"), to = c("B", "A"),
      start = c(1, 6), end = c(1, 6)
    ), observation_spells = data.frame(start = c(0, 5), end = c(2, 7))
  )
  expect_identical(pshifts(gap)$value, integer(13L))
  gap_cumulative <- pshifts(gap, output = "cumulative")
  expect_identical(unique(gap_cumulative$sequence), 1:2)

  within_components <- quiet_dynet(
    data.frame(
      from = c("A", "B", "A", "B"), to = c("B", "A", "B", "A"),
      start = c(1, 2, 6, 7), end = c(1, 2, 6, 7)
    ), observation_spells = data.frame(start = c(0, 5), end = c(3, 8))
  )
  within_final <- pshifts(within_components)
  expect_identical(within_final$value, c(2L, integer(12L)))
  within_cumulative <- pshifts(within_components, output = "cumulative")
  expect_identical(unique(within_cumulative$sequence), 1:2)
  terminal <- within_cumulative[
    within_cumulative$sequence == 2L & within_cumulative$event == 2L, ]
  expect_identical(terminal$value, within_final$value)

  point_components <- quiet_dynet(
    data.frame(
      from = c("A", "B"), to = c("B", "A"),
      start = c(1, 3), end = c(1, 3)
    ), observation_spells = data.frame(start = c(1, 3), end = c(1, 3))
  )
  expect_identical(pshifts(point_components)$value, integer(13L))

  closed_endpoint <- quiet_dynet(
    data.frame(
      from = c("E", "D", "F"), to = c("D", "A", "D"),
      start = c(0, 4, 4), end = c(0, 4, 4)
    ), observation_spells = data.frame(start = c(0, 6), end = c(4, 10))
  )
  endpoint_expected <- integer(13L)
  endpoint_expected[c(3L, 8L)] <- 1L
  expect_identical(pshifts(closed_endpoint)$value, endpoint_expected)

  range_dn <- quiet_dynet(
    data.frame(
      from = c("A", "B"), to = c("B", "A"),
      start = c(1, 2), end = c(1, 2)
    ), observation_start = 0, observation_end = 3
  )
  expect_identical(pshifts(range_dn)$value, c(1L, integer(12L)))
  expect_identical(pshifts(range_dn, start = 2)$value, integer(13L))

  loop <- quiet_dynet(
    data.frame(
      from = c("A", "C", "B"), to = c("B", "C", "A"),
      start = 1:3, end = 1:3
    ), loops = TRUE, observation_start = 0, observation_end = 4
  )
  expect_identical(pshifts(loop)$value, integer(13L))

  loop_with_group <- quiet_dynet(
    data.frame(
      from = c("A", "B", "B", "B"), to = c("B", "B", "C", "D"),
      start = c(1, 2, 2, 2), end = c(1, 2, 2, 2)
    ), loops = TRUE, observation_start = 0, observation_end = 3
  )
  expect_identical(pshifts(loop_with_group)$value, integer(13L))

  session_edges <- data.frame(
    from = c("A", "B"), to = c("B", "A"),
    start = c(1, 2), end = c(1, 2), session = c("one", "two")
  )
  session_dn <- quiet_dynet(
    session_edges, session = "session",
    observation_start = 0, observation_end = 3
  )
  expect_identical(pshifts(session_dn, sessions = "collapse")$value,
                   c(1L, integer(12L)))
  expect_identical(pshifts(session_dn, sessions = "bounded")$value,
                   integer(13L))
  separate <- pshifts(session_dn, sessions = "separate")
  expect_true(all(separate$value == 0L))
})

test_that("E01 raw-onset identity honors censoring but ignores other spell fields", {
  edges <- data.frame(
    from = c("A", "B", "C"), to = c("B", "A", "D"),
    start = c(1, 2, 3), end = c(9, 4, 8),
    weight = c(10, -3, 99), left = c(FALSE, FALSE, TRUE),
    right = c(FALSE, TRUE, FALSE)
  )
  dn <- quiet_dynet(
    edges, weight = "weight", onset_censored = "left",
    terminus_censored = "right", observation_start = 0, observation_end = 10
  )
  expect_identical(pshifts(dn)$value, c(1L, integer(12L)))
  changed <- transform(edges, end = start + 1, weight = c(1, 1, 1))
  changed_dn <- quiet_dynet(
    changed, weight = "weight", onset_censored = "left",
    terminus_censored = "right", observation_start = 0, observation_end = 10
  )
  expect_identical(pshifts(changed_dn)$value, pshifts(dn)$value)

  translated <- transform(edges, start = start + 20, end = end + 20)
  translated_dn <- quiet_dynet(
    translated, weight = "weight", onset_censored = "left",
    terminus_censored = "right", observation_start = 20,
    observation_end = 30
  )
  scaled <- transform(edges, start = start * 5, end = end * 5)
  scaled_dn <- quiet_dynet(
    scaled, weight = "weight", onset_censored = "left",
    terminus_censored = "right", observation_start = 0,
    observation_end = 50
  )
  expect_identical(pshifts(translated_dn)$value, pshifts(dn)$value)
  expect_identical(pshifts(scaled_dn)$value, pshifts(dn)$value)

  contacts <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("B", "A"), time = c(1, 2)),
    observation_start = 0, observation_end = 3
  )
  intervals <- quiet_dynet(
    data.frame(
      from = c("A", "B"), to = c("B", "A"),
      start = c(1, 2), end = c(7, 9)
    ), observation_start = 0, observation_end = 10
  )
  threaded <- quiet_dynet(
    data.frame(
      from = c("A", "B"), to = c("B", "A"), time = c(1, 2),
      thread = c("x", "x")
    ), thread = "thread", observation_start = 0, observation_end = 3
  )
  expect_identical(pshifts(contacts)$value, c(1L, integer(12L)))
  expect_identical(pshifts(intervals)$value, pshifts(contacts)$value)
  expect_identical(pshifts(threaded)$value, pshifts(contacts)$value)
})

test_that("E01 empty and singleton outputs preserve fixed public schemas", {
  one <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 1),
    observation_start = 0, observation_end = 2
  )
  final <- pshifts(one)
  expect_identical(final$shift, .ps_labels)
  expect_identical(final$family, .ps_families)
  expect_identical(final$value, integer(13L))

  empty <- pshifts(one, output = "cumulative", start = 2, end = 2)
  expect_identical(
    names(empty),
    c("sequence", "event", "time", "speaker", "target", "group",
      "shift", "family", "measure", "value")
  )
  expect_identical(nrow(empty), 0L)
  expect_type(empty$speaker, "character")
  expect_type(empty$target, "character")
  expect_type(empty$value, "integer")
})

test_that("E01 metadata, errors, and fixed output labels are explicit", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 1),
    observation_start = 0, observation_end = 2
  )
  out <- pshifts(dn)
  expect_identical(attr(out, "event_identity"),
                   "uncensored_observed_raw_spell_start")
  expect_identical(attr(out, "classification"), "gibson_13")
  expect_identical(attr(out, "interval_contribution"), "onset_only")
  expect_identical(attr(out, "duplicates"), "distinct_turns")
  expect_identical(attr(out, "termini"), "ignored")
  expect_identical(attr(out, "weights"), "ignored")
  expect_identical(attr(out, "vertex_activity"), "ignored")
  expect_identical(attr(out, "loops"), "unclassified_sequence_break")
  expect_identical(attr(out, "observation_walls"), "components_and_gaps")

  undirected <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 1),
    directed = FALSE, observation_start = 0, observation_end = 2
  )
  expect_error(pshifts(undirected), class = "dynet_needs_directed")
  expect_error(pshifts(undirected), class = "dynet_bad_input")
  expect_error(pshifts(dn, output = "bad"))
  expect_error(pshifts(dn, group_events = "bad"))
})

test_that("pshifts returns the measure/value pair every measurement verb shares", {
  dn <- dynet(school_contacts, format = "contact")
  out <- pshifts(dn)

  # Contract: pshifts() was the only measurement verb returning `count`
  # instead of `measure`/`value`, which excluded it from any verb that
  # consumes a measure generically.
  expect_true(all(c("measure", "value") %in% names(out)))
  expect_false("count" %in% names(out))
  expect_identical(unique(out$measure), "count")
  expect_type(out$value, "integer")
  expect_identical(nrow(out), 13L)

  # The rename changed no number: verified total on school_contacts.
  expect_identical(sum(out$value), 235L)
})

test_that("every measurement verb agrees on the measure/value column pair", {
  dn <- dynet(school_contacts, format = "contact")
  # school_contacts carries no node attributes, so mixing() needs its own
  # network rather than a guessed column name.
  grouped <- dynet(
    data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"), time = c(0, 1, 2)),
    format = "contact",
    nodes = data.frame(name = c("A", "B", "C"), team = c("x", "x", "y"))
  )
  results <- list(
    metrics        = metrics(dn),
    dyn_centrality = dyn_centrality(dn),
    events         = events(dn),
    burstiness     = burstiness(dn),
    durations      = durations(dn),
    mixing         = mixing(grouped, attribute = "team"),
    similarity     = similarity(dn),
    pshifts        = pshifts(dn)
  )
  for (nm in names(results)) {
    expect_true(all(c("measure", "value") %in% names(as.data.frame(results[[nm]]))),
                info = nm)
  }
})
