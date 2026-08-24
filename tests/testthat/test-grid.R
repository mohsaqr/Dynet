# ===========================================================================
# The measurement grid: start, end, step, window -- and `mode`.
# ===========================================================================

test_that("the default grid is unchanged by the new arguments", {
  dn <- quiet_dynet(random_edges(seed = 5L), interval = 2)
  plain <- as.data.frame(dyn_metrics(dn, measure = "edges"))
  spelt <- as.data.frame(dyn_metrics(dn, measure = "edges", step = 2,
                                     window = 2))
  expect_equal(plain$value, spelt$value)
  expect_equal(plain$time, spelt$time)
})

test_that("the default grid tiles the observed period with nothing to spare", {
  # Twelve units of observation in steps of five: three windows, the last
  # opening at 10 and running past the end. A fourth would measure nothing.
  sp <- data.frame(from = c("A", "B"), to = c("B", "C"),
                   start = c(0, 6), end = c(1, 12),
                   stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, interval = 5)
  got <- as.data.frame(dyn_metrics(dn, measure = "edges"))
  expect_equal(got$time, c(0, 5, 10))

  # An exact multiple must not gain an empty trailing window either.
  sp2 <- data.frame(from = "A", to = "B", start = 0, end = 10,
                    stringsAsFactors = FALSE)
  dn2 <- quiet_dynet(sp2, interval = 5)
  got2 <- as.data.frame(dyn_metrics(dn2, measure = "edges"))
  expect_equal(got2$time, c(0, 5))

  # And the whole period is still covered: no observation falls past the grid.
  dn3 <- quiet_dynet(random_edges(seed = 4L, span = 23), interval = 3)
  g3 <- as.data.frame(dyn_metrics(dn3, measure = "edges"))
  rng <- dn3$meta$time_range
  expect_lt(max(g3$time), rng[["end"]])
  expect_gte(max(g3$time) + 3, rng[["end"]])
})

test_that("measurements are taken at start, start + step, ... up to end", {
  dn <- quiet_dynet(random_edges(span = 40, seed = 6L))
  got <- as.data.frame(dyn_metrics(dn, measure = "edges", start = 5,
                                   end = 20, step = 3))
  expect_equal(unique(got$time), seq(5, 20, by = 3))
  # `end` is a bound, not a promise: 20 is not reachable from 5 in steps of 3.
  expect_equal(max(got$time), 20)

  odd <- as.data.frame(dyn_metrics(dn, measure = "edges", start = 5,
                                   end = 21, step = 4))
  expect_equal(unique(odd$time), c(5, 9, 13, 17, 21))
})

test_that("window is the width of a measurement and step is its spacing", {
  # Two spells four units apart. A window of one sees them separately; a
  # window of five sees them together, whatever the step.
  sp <- data.frame(from = c("A", "C"), to = c("B", "D"),
                   start = c(0, 4), end = c(0.5, 4.5),
                   stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, interval = 1)

  narrow <- as.data.frame(dyn_metrics(dn, measure = "edges", start = 0,
                                      end = 4, step = 1, window = 1))
  expect_equal(narrow$value, c(1, 0, 0, 0, 1))

  wide <- as.data.frame(dyn_metrics(dn, measure = "edges", start = 0,
                                    end = 4, step = 1, window = 5))
  expect_equal(wide$value, c(2, 1, 1, 1, 1))
})

test_that("a rolling window overlaps and a disjoint one partitions", {
  dn <- quiet_dynet(random_edges(seed = 7L, span = 20))
  roll <- as.data.frame(dyn_metrics(dn, measure = "edges", step = 1,
                                    window = 5))
  disj <- as.data.frame(dyn_metrics(dn, measure = "edges", step = 1,
                                    window = 1))
  expect_equal(nrow(roll), nrow(disj))
  # Every rolling window contains the disjoint one that starts with it.
  expect_true(all(roll$value >= disj$value))
  expect_gt(sum(roll$value), sum(disj$value))

  # Disjoint formation counts partition the spells; rolling ones cannot.
  ev <- as.data.frame(dyn_events(dn, measure = "formation"))
  expect_equal(sum(ev$value), nrow(dn$spells))
})

test_that("window = 0 samples at a point, matching the old instant rule", {
  brief <- data.frame(from = c("A", "C"), to = c("B", "D"),
                      start = c(0, 1.3), end = c(2.5, 1.6),
                      stringsAsFactors = FALSE)
  dn <- quiet_dynet(brief, interval = 1)
  at_point <- as.data.frame(dyn_metrics(dn, measure = "edges", window = 0))
  # A-B spans the sample points at 1 and 2; C-D lives between them.
  expect_equal(at_point$value[at_point$time == 1], 1)
  expect_equal(at_point$value[at_point$time == 2], 1)

  expect_warning(
    legacy <- as.data.frame(dyn_metrics(
      dn, measure = "edges", sample = "instant")),
    "deprecated")
  expect_equal(legacy, at_point)
})

test_that("point-sampled event measures count events at the sample point", {
  sp <- data.frame(from = c("A", "B"), to = c("B", "C"),
                   start = c(0, 1), end = c(1, 2),
                   stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, interval = 1)
  got <- as.data.frame(dyn_events(
    dn, measure = c("formation", "dissolution", "new_pairs"),
    start = 0, end = 2, step = 1, window = 0))
  at <- function(time, measure)
    got$value[got$time == time & got$measure == measure]
  expect_equal(at(0, "formation"), 1)
  expect_equal(at(1, "formation"), 1)
  expect_equal(at(1, "dissolution"), 1)
  expect_equal(at(2, "dissolution"), 1)
  expect_equal(at(0, "new_pairs"), 1)
  expect_equal(at(1, "new_pairs"), 1)
})

test_that("the retired sample argument remains wired through public verbs", {
  dn <- quiet_dynet(random_edges(seed = 17L), interval = 1)
  expect_warning(
    old_c <- as.data.frame(dyn_centrality(
      dn, measure = "degree", sample = "instant")), "deprecated")
  new_c <- as.data.frame(dyn_centrality(dn, measure = "degree", window = 0))
  expect_equal(old_c, new_c)

  expect_warning(old_s <- dyn_snapshots(dn, sample = "instant"), "deprecated")
  new_s <- dyn_snapshots(dn, window = 0)
  expect_equal(old_s, new_s)

  expect_error(
    suppressWarnings(dyn_metrics(dn, sample = "instant", window = 2)),
    class = "dynet_bad_input")
  expect_error(
    suppressWarnings(dyn_metrics(dn, sample = "window", window = 0)),
    class = "dynet_bad_input")
})

test_that("a truncated range is an exact subset of the full series", {
  dn <- quiet_dynet(random_edges(seed = 8L, span = 30), interval = 1)
  full <- as.data.frame(dyn_metrics(dn, measure = "edges", step = 1))
  # The default grid is anchored at the first observation, not at zero, so a
  # subset has to be asked for on that same phase.
  t0 <- dn$meta$time_range[["start"]]
  cut <- as.data.frame(dyn_metrics(dn, measure = "edges", start = t0 + 4,
                                   end = t0 + 11, step = 1))
  overlap <- full[full$time >= t0 + 4 - 1e-9 & full$time <= t0 + 11 + 1e-9, ]
  expect_equal(cut$value, overlap$value)
  expect_equal(cut$time, overlap$time)
})

test_that("only a defaulted end closes its last window on the right", {
  # One spell landing exactly on the final observed time. The default grid
  # must not lose it; an explicitly requested grid is taken literally.
  sp <- data.frame(from = c("A", "C"), to = c("B", "D"),
                   start = c(0, 3), end = c(1, 3),
                   stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, interval = 1)
  auto <- as.data.frame(dyn_metrics(dn, measure = "edges"))
  expect_equal(auto$value[auto$time == max(auto$time)], 1)

  literal <- as.data.frame(dyn_metrics(dn, measure = "edges", start = 0,
                                       end = 2, step = 1))
  expect_equal(literal$value, c(1, 0, 0))
})

test_that("every grid verb takes the four arguments and agrees on the grid", {
  dn <- quiet_dynet(random_edges(seed = 9L, span = 20), interval = 1)
  args <- list(start = 2, end = 14, step = 3, window = 6)
  times <- seq(2, 14, by = 3)

  expect_equal(unique(do.call(dyn_metrics,
    c(list(dn, measure = "density"), args))$time), times)
  expect_equal(unique(do.call(dyn_centrality,
    c(list(dn, measure = "degree"), args))$time), times)
  expect_equal(unique(do.call(dyn_events,
    c(list(dn, measure = "formation"), args))$time), times)
  expect_equal(unique(do.call(dyn_snapshots, c(list(dn), args))$time), times)
})

test_that("the grid arguments are validated", {
  dn <- quiet_dynet(random_edges(seed = 10L))
  expect_error(dyn_metrics(dn, step = 0), class = "dynet_bad_input")
  expect_error(dyn_metrics(dn, step = -1), class = "dynet_bad_input")
  expect_error(dyn_metrics(dn, window = -1), class = "dynet_bad_input")
  expect_error(dyn_metrics(dn, start = 5, end = 2), class = "dynet_bad_input")
  expect_error(dyn_metrics(dn, step = c(1, 2)), class = "dynet_bad_input")
  expect_error(dyn_metrics(dn, start = "yesterday"), class = "dynet_bad_input")
  # Temporal scope has no grid to place; saying otherwise is a mistake, not a
  # silently ignored argument.
  expect_error(dyn_centrality(dn, measure = "closeness", scope = "temporal",
                              window = 3), class = "dynet_bad_input")
})

test_that("a network built from dates may be addressed with dates", {
  sp <- data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"),
                   start = as.Date(c("2024-01-01", "2024-01-05", "2024-01-09")),
                   end   = as.Date(c("2024-01-03", "2024-01-07", "2024-01-11")),
                   stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, interval = 1)
  got <- as.data.frame(dyn_metrics(dn, measure = "edges",
                                   start = as.Date("2024-01-05"),
                                   end = as.Date("2024-01-09"), step = 2))
  expect_equal(nrow(got), 3L)
  expect_equal(got$time, c(4, 6, 8))

  num <- quiet_dynet(random_edges(seed = 11L))
  expect_error(dyn_metrics(num, start = as.Date("2024-01-01")),
               class = "dynet_bad_input")
})

test_that("a degenerate range still yields one measurement", {
  dn <- quiet_dynet(random_edges(seed = 12L, span = 10), interval = 1)
  one <- as.data.frame(dyn_metrics(dn, measure = "edges", start = 3,
                                   end = 3, window = 4))
  expect_equal(nrow(one), 1L)
  expect_equal(one$time, 3)
})

# ---------------------------------------------------------------------------
# mode
# ---------------------------------------------------------------------------

test_that("mode = in and out partition mode = all for degree and strength", {
  dn <- quiet_dynet(random_edges(seed = 13L))
  for (ms in c("degree", "strength")) {
    all_v <- as.data.frame(dyn_centrality(dn, measure = ms, mode = "all"))
    out_v <- as.data.frame(dyn_centrality(dn, measure = ms, mode = "out"))
    in_v  <- as.data.frame(dyn_centrality(dn, measure = ms, mode = "in"))
    expect_equal(out_v$value + in_v$value, all_v$value)
    expect_equal(tapply(out_v$value, out_v$time, sum),
                 tapply(in_v$value, in_v$time, sum))
  }
})

test_that("mode picks the right margin on a known network", {
  # A star: every arc points at the hub.
  sp <- data.frame(from = c("A", "B", "C"), to = c("H", "H", "H"),
                   start = c(0, 0, 0), end = c(1, 1, 1),
                   stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, interval = 1)
  deg <- function(md) {
    v <- as.data.frame(dyn_centrality(dn, measure = "degree", mode = md))
    stats::setNames(v$value, v$node)
  }
  expect_equal(unname(deg("in")[c("A", "B", "C", "H")]), c(0, 0, 0, 3))
  expect_equal(unname(deg("out")[c("A", "B", "C", "H")]), c(1, 1, 1, 0))
  expect_equal(unname(deg("all")[c("A", "B", "C", "H")]), c(1, 1, 1, 3))
})

test_that("mode changes closeness and coreness, not only degree", {
  # A directed path A -> B -> C. Out-closeness ranks A highest because it can
  # reach the most; in-closeness ranks C highest for the same reason reversed.
  sp <- data.frame(from = c("A", "B"), to = c("B", "C"),
                   start = c(0, 0), end = c(1, 1),
                   stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, interval = 1)
  cl <- function(md) {
    v <- as.data.frame(dyn_centrality(dn, measure = "closeness", mode = md))
    stats::setNames(v$value, v$node)[c("A", "B", "C")]
  }
  # A reaches B at 1 and C at 2: 2 / 3. B reaches C at 1: 1 / 1. C reaches none.
  expect_equal(unname(cl("out")), c(2 / 3, 1, 0))
  expect_equal(unname(cl("in")), c(0, 1, 2 / 3))
  # Ignoring direction makes the path symmetric.
  expect_equal(unname(cl("all")), c(2 / 3, 1, 2 / 3))

  # Coreness: a directed triangle A -> B -> C -> A with one extra arc D -> B.
  # Every vertex has out-degree one, so the out-core is one throughout; D has
  # no in-arc at all, so it falls out of the in-core entirely. Reference
  # values are igraph::coreness(mode = ) on the same graph.
  tri <- data.frame(from = c("A", "B", "C", "D"), to = c("B", "C", "A", "B"),
                    start = 0, end = 1, stringsAsFactors = FALSE)
  dt <- quiet_dynet(tri, interval = 1)
  co <- function(md) {
    v <- as.data.frame(dyn_centrality(dt, measure = "coreness", mode = md))
    stats::setNames(v$value, v$node)[c("A", "B", "C", "D")]
  }
  expect_equal(unname(co("out")), c(1, 1, 1, 1))
  expect_equal(unname(co("in")), c(1, 1, 1, 0))
  expect_equal(unname(co("all")), c(2, 2, 2, 1))
})

test_that("mode is ignored where it has no meaning", {
  dn <- quiet_dynet(random_edges(seed = 14L))
  # Betweenness, PageRank and the rest have a single directional definition.
  a <- as.data.frame(dyn_centrality(dn, measure = "betweenness", mode = "all"))
  b <- as.data.frame(dyn_centrality(dn, measure = "betweenness", mode = "in"))
  expect_equal(a$value, b$value)

  und <- quiet_dynet(random_edges(seed = 14L), directed = FALSE)
  u1 <- as.data.frame(dyn_centrality(und, measure = "degree", mode = "out"))
  u2 <- as.data.frame(dyn_centrality(und, measure = "degree", mode = "in"))
  expect_equal(u1$value, u2$value)
})

test_that("retired degree names remain as deprecated aliases", {
  dn <- quiet_dynet(random_edges(seed = 15L))
  expect_warning(
    old_in <- as.data.frame(dyn_centrality(dn, measure = "indegree")),
    "deprecated")
  expect_warning(
    old_out <- as.data.frame(dyn_centrality(dn, measure = "outdegree")),
    "deprecated")
  new_in <- as.data.frame(dyn_centrality(dn, measure = "degree", mode = "in"))
  new_out <- as.data.frame(dyn_centrality(dn, measure = "degree", mode = "out"))
  expect_equal(old_in$value, new_in$value)
  expect_equal(old_out$value, new_out$value)
  expect_error(dyn_centrality(dn, mode = "sideways"))
})

test_that("temporal centrality rejects a snapshot direction mode", {
  dn <- quiet_dynet(chain_edges())
  expect_error(
    dyn_centrality(dn, measure = "closeness", scope = "temporal", mode = "in"),
    class = "dynet_bad_input")
})

test_that("the result records the grid and the mode it was measured on", {
  dn <- quiet_dynet(random_edges(seed = 16L), interval = 1)
  m <- dyn_centrality(dn, measure = "degree", step = 2, window = 6,
                      mode = "in")
  expect_equal(attr(m, "step"), 2)
  expect_equal(attr(m, "window"), 6)
  expect_equal(attr(m, "mode"), "in")
  expect_match(paste(capture.output(print(m)), collapse = " "), "rolling")
  expect_match(paste(capture.output(print(m)), collapse = " "), "mode in")

  plain <- dyn_centrality(dn, measure = "degree")
  expect_null(attr(plain, "mode"))
})
