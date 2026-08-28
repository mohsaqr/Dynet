test_that("a seeded call restores an existing random stream", {
  set.seed(42)
  before <- get(".Random.seed", envir = globalenv())
  Dynet:::.with_seed(1, runif(5))
  expect_identical(get(".Random.seed", envir = globalenv()), before)
})

test_that("a seeded call removes the stream when there was none", {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  Dynet:::.with_seed(1, runif(5))
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("the same seed gives the same draws and a different one does not", {
  expect_identical(Dynet:::.with_seed(3, runif(10)),
                   Dynet:::.with_seed(3, runif(10)))
  expect_false(identical(Dynet:::.with_seed(3, runif(10)),
                         Dynet:::.with_seed(4, runif(10))))
  expect_error(Dynet:::.with_seed("a", 1), class = "dynet_bad_input")
})

test_that("randomise rejects arguments that belong to another method", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(randomise(dn, method = "reversal", n = 5),
               class = "dynet_bad_input")
  expect_error(randomise(dn, method = "times", transpose = TRUE),
               class = "dynet_bad_input")
  expect_error(randomise(school_contacts, method = "times"),
               class = "dynet_bad_input")
  expect_error(randomise(dn, method = "times", within = "session"),
               class = "dynet_no_sessions")
})

test_that("a network with declared vertex activity is randomised, not refused", {
  # This used to raise dynet_randomise_unsupported. It now draws a constrained
  # surrogate instead; the feasibility guarantee is tested below.
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    vertex_spells = data.frame(node = "A", start = 0, end = 1)
  )
  out <- randomise(dn, method = "times", n = 3, seed = 1)
  expect_s3_class(out, "dynet_null")
  expect_identical(attr(out, "respect"), c("activity", "observation"))
})

test_that("every method conserves exactly what its table claims", {
  dn <- dynet(school_contacts, format = "contact")
  observed <- dn$spells

  times <- as.data.frame(randomise(dn, method = "times", n = 3, seed = 1))
  for (r in split(times, times$replicate)) {
    expect_identical(sort(r$start), sort(observed$start))
    expect_identical(sort(r$end), sort(observed$end))
    expect_identical(sort(paste(r$from, r$to)),
                     sort(paste(observed$from, observed$to)))
  }

  timeline <- as.data.frame(randomise(dn, method = "timeline", n = 3, seed = 1))
  for (r in split(timeline, timeline$replicate)) {
    expect_identical(nrow(r), nrow(observed))
    expect_identical(sort(r$start), sort(observed$start))
  }

  edges <- suppressWarnings(
    as.data.frame(randomise(dn, method = "edges", n = 3, seed = 1)))
  for (r in split(edges, edges$replicate)) {
    expect_identical(sort(table(observed$from)), sort(table(r$from)))
  }

  targets <- as.data.frame(
    randomise(dn, method = "targets", within = "sender", n = 3, seed = 1))
  for (r in split(targets, targets$replicate)) {
    expect_identical(sort(table(r$from)), sort(table(observed$from)))
  }

  reversal <- as.data.frame(randomise(dn, method = "reversal"))
  expect_identical(sort(reversal$duration), sort(observed$end - observed$start))
})

test_that("no surrogate has a self-loop or a negative duration", {
  dn <- dynet(school_contacts, format = "contact")
  for (m in c("times", "timeline", "edges", "targets", "labels", "reversal")) {
    n <- if (identical(m, "reversal")) 1L else 3L
    df <- suppressWarnings(as.data.frame(randomise(dn, method = m, n = n,
                                                   seed = 1)))
    expect_false(any(df$from == df$to), info = m)
    expect_true(all(df$end >= df$start), info = m)
    expect_true(all(df$duration >= 0), info = m)
  }
})

test_that("a label permutation changes no structural measure", {
  # The surrogate is isomorphic to the original, so this is an exact
  # correctness test on the whole rebuild path, not a weak null.
  dn <- dynet(school_contacts, format = "contact")
  null <- randomise(dn, method = "labels", n = 10, seed = 1)
  observed <- as.data.frame(
    metrics(dn, measure = c("density", "reciprocity", "transitivity")))
  for (net in attr(null, "networks")) {
    got <- as.data.frame(
      metrics(net, measure = c("density", "reciprocity", "transitivity")))
    expect_equal(got$value, observed$value)
  }
  degree <- sort(as.data.frame(dyn_centrality(dn, measure = "degree"))$value)
  for (net in attr(null, "networks")) {
    expect_equal(sort(as.data.frame(dyn_centrality(net, measure = "degree"))$value),
                 degree)
  }
})

test_that("the same seed gives identical surrogates and leaves the stream alone", {
  dn <- dynet(school_contacts, format = "contact")
  set.seed(99)
  before <- get(".Random.seed", envir = globalenv())
  a <- as.data.frame(randomise(dn, method = "times", n = 3, seed = 1))
  b <- as.data.frame(randomise(dn, method = "times", n = 3, seed = 1))
  expect_identical(a, b)
  expect_identical(get(".Random.seed", envir = globalenv()), before)
})

test_that("poor rewiring mixing is surfaced, not suppressed", {
  dn <- dynet(school_contacts, format = "contact")
  expect_warning(randomise(dn, method = "edges", n = 2, seed = 1, swaps = 1),
                 class = "dynet_null_poor_mixing")
})

test_that("randomise ships the four result methods", {
  dn <- dynet(school_contacts, format = "contact")
  null <- randomise(dn, method = "times", n = 3, seed = 1)
  expect_s3_class(null, "dynet_null")
  expect_s3_class(as.data.frame(null), "data.frame")
  expect_identical(nrow(summary(null)), 3L)
  expect_output(print(null), "holds fixed")
  skip_if_not_installed("ggplot2")
  expect_s3_class(plot(null), "ggplot")
})

test_that("declared vertex activity constrains the surrogates instead of refusing", {
  # A is eligible only on [0, 3] while events run out to 9, so an
  # unconstrained time permutation can place an A-event outside its window.
  dn <- dynet(
    data.frame(from = c("A", "A", "B", "B", "C"), to = c("B", "C", "C", "A", "B"),
               start = c(0, 1, 6, 7, 8), end = c(1, 2, 7, 8, 9)),
    vertex_spells = data.frame(node = c("A", "B", "C"), start = c(0, 0, 0),
                               end = c(3, 10, 10)),
    observation_start = 0, observation_end = 10)
  feasible <- function(df) {
    Dynet:::.spell_feasible(
      dn, data.frame(from = df$from, to = df$to, start = df$start,
                     end = df$end),
      c("activity", "observation"))
  }

  constrained <- randomise(dn, method = "times", n = 40, seed = 1)
  expect_true(all(feasible(as.data.frame(constrained))))
  expect_gt(sum(attr(constrained, "rejected")), 0L)

  # The unconstrained draw is what the refusal used to protect against, and it
  # is available on request with the bias documented.
  loose <- randomise(dn, method = "times", n = 40, seed = 1, respect = "none")
  expect_gt(sum(!feasible(as.data.frame(loose))), 0L)
  expect_identical(sum(attr(loose, "rejected")), 0L)
})

test_that("respect = none cannot be combined with a constraint", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(randomise(dn, method = "times", respect = c("none", "activity")),
               class = "dynet_bad_input")
})

test_that("a network with no declared activity is unaffected by respect", {
  dn <- dynet(school_contacts, format = "contact")
  a <- as.data.frame(randomise(dn, method = "times", n = 3, seed = 1))
  b <- as.data.frame(randomise(dn, method = "times", n = 3, seed = 1,
                               respect = "none"))
  expect_identical(a, b)
})
