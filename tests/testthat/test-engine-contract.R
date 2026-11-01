# Contracts of the internal engine (R/engine.R): tolerant time comparison,
# the structural entry guard, and the measurement grid at awkward magnitudes.
# Every block pins either a condition class or an invariant; the oracles are
# hand counts, translation invariance and scale equivariance, because the
# grid's external oracle (tsna) is not a dependency of the package.

time_eq <- function(a, b) getFromNamespace(".time_eq", "Dynet")(a, b)
time_leq <- function(a, b) getFromNamespace(".time_leq", "Dynet")(a, b)
time_geq <- function(a, b) getFromNamespace(".time_geq", "Dynet")(a, b)

grid_of <- function(dn, ...) {
  ns <- asNamespace("Dynet")
  spec <- ns$.window_spec(dn, ...)
  ns$.grid_for(ns$.encode(dn), dn, spec)
}

# --- tolerant time comparison ----------------------------------------------

test_that("summed increments equal their exact value under every helper", {
  k <- seq_len(1000L)
  summed <- vapply(k, function(i) Reduce(`+`, rep(0.1, i)), numeric(1L))
  exact <- k / 10
  expect_true(all(time_eq(summed, exact)))
  expect_true(all(time_leq(summed, exact) & time_geq(summed, exact)))
  # Symmetry: the comparison does not depend on argument order.
  expect_identical(time_eq(summed, exact), time_eq(exact, summed))
})

test_that("each pair is compared at its own magnitude, not the vector's", {
  # A Unix timestamp elsewhere in the vector must not widen the tolerance of
  # a pair near zero.
  expect_identical(time_eq(c(0, 1.7e9), c(1e-8, 1.7e9)), c(FALSE, TRUE))
  a <- c(0, 0.3, 1.7e9, -5, 1e-13)
  b <- c(2e-14, 0.1 + 0.1 + 0.1, 1.7e9 + 1e-3, -5 - 1e-12, 0)
  scalar <- vapply(seq_along(a), function(i) time_eq(a[i], b[i]), logical(1L))
  expect_identical(time_eq(a, b), scalar)
  # The documented floor: below magnitude one the tolerance is 128 * eps.
  expect_true(time_eq(0, 2e-14))
  expect_false(time_eq(0, 4e-14))
  # Unix scale: a few hundred ulps agree, a millisecond does not.
  ulp <- 2^(floor(log2(1.7e9)) - 52)
  expect_true(time_eq(1.7e9 + 100 * ulp, 1.7e9))
  expect_false(time_eq(1.7e9 + 1e-3, 1.7e9))
})

test_that("equal infinities are equal and a missing time is never TRUE", {
  expect_true(time_eq(Inf, Inf))
  expect_true(time_eq(-Inf, -Inf))
  expect_false(time_eq(Inf, -Inf))
  expect_false(time_eq(Inf, 1e308))
  # eq agrees with leq-and-geq wherever both are defined.
  x <- c(-Inf, -1, 0, 0.3, Inf)
  pairs <- expand.grid(a = x, b = x)
  expect_identical(time_eq(pairs$a, pairs$b),
                   time_leq(pairs$a, pairs$b) & time_geq(pairs$a, pairs$b))
  expect_true(is.na(time_eq(NA_real_, 1)))
  expect_true(is.na(time_eq(NaN, NaN)))
  expect_true(is.na(time_leq(NA_real_, 1)))
  expect_true(is.na(time_geq(1, NA_real_)))
})

# --- the structural entry guard --------------------------------------------

test_that("a structurally corrupted dynet is refused with a class", {
  dn <- quiet_dynet(triangle_edges())
  check <- getFromNamespace(".check_dynet", "Dynet")
  # Each corruption edits one table of an otherwise valid object.
  tamper <- function(table, column, value) {
    bad <- dn
    if (is.null(column)) {
      bad[table] <- list(value)
    } else {
      bad[[table]][[column]] <- value
    }
    bad
  }
  spells <- dn$spells
  corrupt <- list(
    no_start = tamper("spells", "start", NULL),
    no_spells = tamper("spells", NULL, NULL),
    stray_endpoint = tamper("spells", "from", replace(spells$from, 1L, "Q")),
    reversed = tamper("spells", "end",
                      replace(spells$end, 1L, spells$start[1L] - 1)),
    missing_time = tamper("spells", "start", replace(spells$start, 2L, NA)),
    text_time = tamper("spells", "start", as.character(spells$start)),
    no_nodes = tamper("nodes", NULL, NULL),
    duplicate_names = tamper("nodes", "name",
                             replace(dn$nodes$name, 1L, dn$nodes$name[2L])),
    duplicate_spell_id = tamper("spells", ".raw_spell",
                                replace(spells$.raw_spell, 2L, 1L))
  )
  lapply(names(corrupt), function(nm) {
    bad <- corrupt[[nm]]
    expect_s3_class(bad, "dynet")
    expect_error(check(bad), class = "dynet_corrupt_object", info = nm)
    expect_error(metrics(bad, "edges"), class = "dynet_bad_input", info = nm)
  })
  expect_error(check(unclass(dn)), class = "dynet_bad_input")
})

test_that("every network dynet() builds passes the structural guard", {
  check <- getFromNamespace(".check_dynet", "Dynet")
  built <- list(
    school = quiet_dynet(school_contacts),
    contact = quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                                     time = c(0, 1)), time = "time"),
    weighted = quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                                      start = 0:1, end = 1:2,
                                      weight = c(0.5, 2))),
    vertex_spells = quiet_dynet(triangle_edges(),
      vertex_spells = data.frame(node = c("A", "B", "C"), start = 0, end = 7)),
    observed = quiet_dynet(triangle_edges(),
      observation_spells = data.frame(start = c(1, 4.5), end = c(3, 6))),
    sessions = quiet_dynet(transform(triangle_edges(), s = c("x", "y", "x")),
                           session = "s")
  )
  lapply(names(built), function(nm) {
    expect_identical(check(built[[nm]]), "bounded", info = nm)
  })
  edited <- remove_ties(built$school, from = "Jonas")
  expect_identical(check(edited), "bounded")
})

# --- the measurement grid ---------------------------------------------------

test_that("a defaulted end keeps the last events whatever the start", {
  # Contacts at 0, 1, ..., 10. With tiling windows every contact at or after
  # `start` must be counted exactly once. Counting the default end from the
  # first observed time instead of from `start` used to drop the contact at
  # 10 whenever `start` was off the data's lattice.
  dn <- quiet_dynet(data.frame(from = rep(c("A", "B"), length.out = 11),
                               to = rep(c("B", "C"), length.out = 11),
                               time = 0:10), time = "time")
  ns <- asNamespace("Dynet")
  enc <- ns$.encode(dn)
  lapply(c(0, 0.5, -4.5, 0.25, 3), function(st) {
    spec <- ns$.window_spec(dn, start = st, step = 1)
    grid <- ns$.grid_for(enc, dn, spec)
    counted <- vapply(seq_len(nrow(grid)), function(k) {
      sum(ns$.active(enc, grid$lo[k], grid$hi[k], grid$closed[k], spec$window))
    }, numeric(1L))
    expect_identical(sum(counted), as.numeric(sum(0:10 >= st)),
                     info = format(st))
    expect_true(grid$closed[nrow(grid)], info = format(st))
  })
})

test_that("an unbounded or vanishing-step grid is refused with a class", {
  dn <- quiet_dynet(triangle_edges())
  expect_error(metrics(dn, "edges", step = 1e-12), class = "dynet_bad_grid")
  expect_error(metrics(dn, "edges", step = 1e-12), class = "dynet_bad_input")
  grid_bins <- getFromNamespace(".grid_bins", "Dynet")
  expect_error(grid_bins(Inf, 1), class = "dynet_bad_grid")
  expect_error(grid_bins(1, 0), class = "dynet_bad_grid")
})

test_that("the grid is translation invariant at Unix-timestamp magnitude", {
  # The same network shifted by 1699999990 must get the same bins. Ratio-
  # scaled tolerances used to invent a trailing bin there (8 bins for a
  # 0.7-long period measured every 0.1) and skip a component's first bin.
  build <- function(offset, a, len, observed) {
    s <- as.numeric(sprintf("%.1f", offset + a / 10))
    e <- as.numeric(sprintf("%.1f", offset + (a + len) / 10))
    edges <- data.frame(from = c("A", "B"), to = c("B", "C"),
                        start = c(s, s), end = c(e, e))
    if (observed) {
      quiet_dynet(edges, observation_spells = data.frame(
        start = c(s, e + 1), end = c(e, e + 2)))
    } else {
      quiet_dynet(edges)
    }
  }
  cases <- expand.grid(a = c(0, 2, 7), len = c(3, 7, 12), step = c(0.1, 0.3),
                       start_shift = c(NA, -0.3, 0.1), observed = c(FALSE, TRUE))
  offset <- 1699999990
  agree <- vapply(seq_len(nrow(cases)), function(i) {
    cc <- cases[i, ]
    lo <- lapply(c(0, offset), function(off) {
      dn <- build(off, cc$a, cc$len, cc$observed)
      st <- if (is.na(cc$start_shift)) NULL else
        as.numeric(sprintf("%.1f", off + cc$a / 10 + cc$start_shift))
      grid_of(dn, start = st, step = cc$step)$lo - off
    })
    length(lo[[1L]]) == length(lo[[2L]]) &&
      all(abs(lo[[1L]] - lo[[2L]]) < 1e-4)
  }, logical(1L))
  expect_true(all(agree))
})

test_that("vertex-spell boundaries anchor the grid like edge boundaries", {
  # Scale equivariance: a network measured in units of 0.1 must agree with
  # the same network measured in whole units. Vertex C arrives at 0.3; the
  # window [0.2, 0.3) used to end at 0.30000000000000004 and count C present.
  build <- function(scale) {
    quiet_dynet(
      data.frame(from = c("A", "A"), to = c("B", "C"), start = 0,
                 end = 2 * scale),
      vertex_spells = data.frame(node = c("A", "B", "C"),
                                 start = c(0, 0, 0.3) * scale,
                                 end = 2 * scale))
  }
  tenths <- metrics(build(1), measure = c("active_nodes", "edges"), step = 0.1)
  units <- metrics(build(10), measure = c("active_nodes", "edges"), step = 1)
  tenths_df <- as.data.frame(tenths)
  units_df <- as.data.frame(units)
  expect_identical(tenths_df$value, units_df$value)
  expect_equal(tenths_df$time * 10, units_df$time)
})
