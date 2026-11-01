# Contracts pinned by the 2026-11-01 construction audit: every input dynet()
# cannot honour is refused with a classed condition, and every named argument
# is honoured rather than overridden by an auto-detected column.

# --- spell times --------------------------------------------------------------

test_that("a missing, infinite or negative duration is a classed error", {
  base <- data.frame(from = c("A", "B"), to = c("B", "C"), start = c(0, 1))
  expect_error(dynet(transform(base, duration = c(1, NA))),
               class = "dynet_bad_spell")
  expect_error(dynet(transform(base, duration = c(1, Inf))),
               class = "dynet_bad_spell")
  expect_error(dynet(transform(base, duration = c(1, -1))),
               class = "dynet_bad_input")
})

test_that("a difftime duration is read in the network's unit", {
  starts <- as.POSIXct(c("2024-01-01 00:00:00", "2024-01-05 00:00:00"),
                       tz = "UTC")
  by_end <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                             start = starts, end = starts + 2 * 86400))
  by_duration <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                                  start = starts,
                                  duration = as.difftime(c(2, 2),
                                                         units = "days")))
  expect_identical(by_end$meta$time_unit, "days")
  expect_equal(as.data.frame(by_duration), as.data.frame(by_end))
  expect_error(dynet(data.frame(from = "A", to = "B", start = 0,
                                duration = as.difftime(1, units = "days"))),
               class = "dynet_mixed_clock")
})

test_that("an infinite spell needs a finite observation window", {
  open_ended <- data.frame(from = c("A", "B"), to = c("B", "C"),
                           start = c(0, 2), end = c(Inf, 5))
  expect_error(dynet(open_ended), class = "dynet_unbounded_spell")
  expect_error(dynet(open_ended, observation_start = 0),
               class = "dynet_bad_input")
  bounded <- dynet(open_ended, observation_start = 0, observation_end = 10)
  # The raw endpoint survives; only measurement is clipped.
  expect_identical(as.data.frame(bounded)$end, c(Inf, 5))
  expect_identical(bounded$meta$n_bins, 10L)
})

test_that("start and end on different clocks are refused in both directions", {
  dates <- as.Date(c("2024-01-01", "2024-01-03"))
  expect_error(dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                                start = c(0, 1), end = dates)),
               class = "dynet_mixed_clock")
  expect_error(dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                                start = dates, end = c(5, 6))),
               class = "dynet_mixed_clock")
  # Invariant: the same calendar times as Date or as text give one network.
  as_date <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                              start = dates, end = dates + 1))
  as_text <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                              start = format(dates),
                              end = format(dates + 1)))
  expect_equal(as.data.frame(as_text), as.data.frame(as_date))
})

# --- named arguments win ------------------------------------------------------

test_that("an interval log honours an explicit `time` as the spell start", {
  log <- data.frame(from = c("A", "B"), to = c("B", "C"),
                    t0 = c(1, 2), t1 = c(3, 4))
  by_time <- dynet(log, time = "t0", end = "t1")
  by_start <- dynet(log, start = "t0", end = "t1")
  expect_equal(as.data.frame(by_time), as.data.frame(by_start))
  # A column that merely looks like a start does not override the argument.
  decoy <- transform(log, start = c(100, 200))
  expect_identical(as.data.frame(dynet(decoy, time = "t0", end = "t1"))$start,
                   c(1, 2))
  expect_error(dynet(log, time = "nope", end = "t1"),
               class = "dynet_missing_column")
})

test_that("a contact log honours an explicit `start` as the event time", {
  log <- data.frame(from = c("A", "B"), to = c("B", "C"), s = c(5, 7))
  spells <- as.data.frame(dynet(log, start = "s"))
  expect_identical(spells$start, c(5, 7))
  expect_identical(spells$end, spells$start)
  expect_error(dynet(log, start = "nope"), class = "dynet_missing_column")
})

test_that("a co-presence log honours an explicit `time` over a start alias", {
  log <- data.frame(actor = c("a", "b", "c"), group = c("g", "g", "h"),
                    start = c(100, 100, 100), when2 = c(1, 2, 3))
  log <- rbind(log, data.frame(actor = "d", group = "h", start = 100,
                               when2 = 4))
  spells <- as.data.frame(dynet(log, actor = "actor", group = "group",
                                time = "when2"))
  expect_identical(spells$start, c(1, 3))
  expect_identical(spells$end, c(2, 4))
})

test_that("`from` and `to` naming one column is refused", {
  log <- data.frame(a = c("A", "B"), b = c("B", "C"), start = 0, end = 1)
  expect_error(dynet(log, from = "a", to = "a"), class = "dynet_same_column")
})

# --- weights ------------------------------------------------------------------

test_that("a missing, infinite or negative weight is a classed error", {
  log <- data.frame(from = c("A", "B"), to = c("B", "C"), start = 0, end = 1)
  expect_error(dynet(transform(log, w = c(1, NA)), weight = "w"),
               class = "dynet_bad_weight")
  expect_error(dynet(transform(log, w = c(1, Inf)), weight = "w"),
               class = "dynet_bad_weight")
  expect_error(dynet(transform(log, w = c(-1, 2)), weight = "w"),
               class = "dynet_bad_weight")
  expect_error(dynet(transform(log, w = c("x", "y")), weight = "w"),
               class = "dynet_bad_input")
})

test_that("aggregate weight equals the summed spell weights", {
  log <- transform(random_edges(seed = 4),
                   w = seq_len(nrow(random_edges(seed = 4))) / 4)
  dn <- dynet(log, weight = "w")
  expect_equal(sum(as.data.frame(dn, what = "network")$weight),
               sum(as.data.frame(dn)$weight))
})

test_that("an auto-detected weight column is consumed, not duplicated", {
  log <- data.frame(from = c("A", "B"), to = c("B", "C"), start = 0, end = 1,
                    strength = c(2, 3))
  expect_message(dn <- dynet(log), "strength")
  spells <- as.data.frame(dn)
  expect_false("strength" %in% names(spells))
  expect_identical(spells$weight, c(2, 3))
})

test_that("a co-presence weight raises one classed warning only", {
  log <- data.frame(actor = c("a", "b"), group = "g", w = c(1, 2))
  seen <- character()
  withCallingHandlers(
    dynet(log, actor = "actor", group = "group", weight = "w"),
    warning = function(w) {
      seen <<- c(seen, class(w)[1L])
      invokeRestart("muffleWarning")
    }
  )
  expect_identical(seen, "dynet_weight_ignored")
})

# --- co-presence sessions -----------------------------------------------------

test_that("a co-presence group spanning two sessions is refused", {
  log <- data.frame(actor = c("a", "b", "c"), group = "g",
                    wave = c("w1", "w1", "w2"))
  expect_error(dynet(log, actor = "actor", group = "group", session = "wave"),
               class = "dynet_ambiguous_session")
  # Invariant: when each group lies in one session, its spells carry it.
  log$wave <- "w1"
  log <- rbind(log, data.frame(actor = c("a", "d"), group = "h", wave = "w2"))
  spells <- as.data.frame(dynet(log, actor = "actor", group = "group",
                                session = "wave"))
  expect_identical(unique(spells$session[spells$group == "g"]), "w1")
  expect_identical(unique(spells$session[spells$group == "h"]), "w2")
})

# --- vertices named only in `nodes` ---------------------------------------------

test_that("vertices named only in `nodes` are dropped with a message, or kept", {
  log <- data.frame(from = "A", to = "B", start = 0, end = 1)
  people <- data.frame(name = c("A", "B", "Z"), role = c("x", "y", "z"))
  expect_message(dropped <- dynet(log, nodes = people),
                 class = "dynet_dropped_nodes")
  expect_identical(as.data.frame(dropped, what = "nodes")$name, c("A", "B"))
  kept <- dynet(log, nodes = people, keep_isolates = TRUE)
  expect_identical(as.data.frame(kept, what = "nodes")$name, c("A", "B", "Z"))
  expect_identical(as.data.frame(kept, what = "nodes")$role, c("x", "y", "z"))
  # Invariant: keeping isolates never touches the spells.
  expect_identical(as.data.frame(kept), as.data.frame(dropped))
  expect_error(dynet(log, nodes = people, keep_isolates = NA),
               class = "dynet_bad_input")
  expect_error(dynet(log, nodes = c("A", "B")), class = "dynet_bad_nodes")
})

test_that("keep_isolates keeps the named vertices under a key-to-name table", {
  log <- data.frame(from = c("1", "2"), to = c("2", "3"), start = 0, end = 1)
  people <- data.frame(vertex.id = c("1", "2", "3", "4"),
                       name = c("A", "B", "C", "D"))
  kept <- dynet(log, nodes = people, keep_isolates = TRUE)
  expect_setequal(as.data.frame(kept, what = "nodes")$name,
                  c("A", "B", "C", "D"))
})

# --- condition classes ----------------------------------------------------------

test_that("every constructor failure inherits from dynet_bad_input", {
  expect_error(dynet(data.frame(a = 1, b = 2)), class = "dynet_bad_input")
  expect_error(suppressMessages(dynet(data.frame(from = "A", to = "A",
                                                 start = 0, end = 1))),
               class = "dynet_bad_input")
  expect_error(dynet(data.frame(from = "A", to = "B", time = "garbage")),
               class = "dynet_bad_input")
  expect_error(dynet(data.frame(from = "A", to = "B", start = 0, end = 1),
                     groups = "zz"),
               class = "dynet_bad_input")
  expect_error(dynet(data.frame(from = "A", to = "B", start = 2, end = 1)),
               class = "dynet_bad_spell")
  expect_error(dynet(data.frame(from = "A", to = "B", start = 0, end = 1),
                     observation_start = 5, observation_end = 1),
               class = "dynet_bad_observation")
})

test_that("as_dynet() on an unsupported object is a classed error", {
  expect_error(as_dynet(data.frame(a = 1)), class = "dynet_unsupported_class")
  expect_error(as_dynet(1:3), class = "dynet_bad_input")
  dn <- dynet(chain_edges())
  expect_identical(as_dynet(dn), dn)
})

# --- vertex spells ---------------------------------------------------------------

test_that("adjacent vertex spells merge across floating-point noise", {
  merged <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1),
                  vertex_spells = data.frame(node = c("A", "A"),
                                             start = c(0, 0.1 + 0.2),
                                             end = c(0.3, 1)))
  spells <- as.data.frame(merged, what = "vertex_spells")
  expect_identical(nrow(spells), 1L)
  expect_equal(c(spells$start, spells$end), c(0, 1))
  expect_error(dynet(data.frame(from = "A", to = "B", start = 0, end = 1),
                     vertex_spells = data.frame(node = "A", start = 1,
                                                end = 0)),
               class = "dynet_bad_vertex_spells")
})

test_that("the bin count does not invent a bin from timestamp rounding", {
  stamps <- 1.7e9 + c(0, 0.7)
  dn <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                         time = stamps), interval = 0.1)
  # (1.7e9 + 0.7) - 1.7e9 is 0.7000000477, whose bare ceiling over 0.1 is 8.
  expect_identical(dn$meta$n_bins, 7L)
  expect_error(dynet(data.frame(from = "A", to = "B", time = stamps[1L]),
                     interval = -1),
               class = "dynet_bad_input")
})

test_that("an open-ended networkDynamic spell imports only inside a finite window", {
  skip_if_not_installed("networkDynamic")
  skip_if_not_installed("network")
  base <- network::network.initialize(3)
  network::add.edges(base, c(1, 2), c(2, 3))
  network::set.vertex.attribute(base, "Name", c("A", "B", "C"))
  legacy <- suppressWarnings(suppressMessages(
    networkDynamic::networkDynamic(base.net = base, verbose = FALSE)
  ))
  networkDynamic::activate.edges(legacy, onset = 2, terminus = Inf, e = 1)
  networkDynamic::activate.edges(legacy, onset = 0, terminus = 5, e = 2)
  network::set.network.attribute(legacy, "net.obs.period", list(
    observations = list(c(0, 10)), mode = "continuous",
    time.increment = 1, time.unit = "step"
  ))
  dn <- as_dynet(legacy)
  spells <- as.data.frame(dn)
  reference <- networkDynamic::get.edge.activity(legacy, as.spellList = TRUE)
  # Oracle: the raw ledger and its censor flags are networkDynamic's own.
  expect_setequal(paste(spells$start, spells$end),
                  paste(reference$onset, reference$terminus))
  expect_identical(spells$terminus_censored[is.infinite(spells$end)], TRUE)
  network::delete.network.attribute(legacy, "net.obs.period")
  expect_error(as_dynet(legacy), class = "dynet_unbounded_spell")
})
