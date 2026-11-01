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
  degree <- sort(as.data.frame(centrality_series(dn, measure = "degree"))$value)
  for (net in attr(null, "networks")) {
    expect_equal(sort(as.data.frame(centrality_series(net, measure = "degree"))$value),
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

  # B->A on [7, 8] is observed while A is inactive, so the observed network
  # itself holds one infeasible spell; a surrogate may hold no more.
  observed_bad <- sum(!feasible(as.data.frame(dn)))
  expect_identical(observed_bad, 1L)
  constrained <- randomise(dn, method = "times", n = 40, seed = 1)
  df <- as.data.frame(constrained)
  bad_per_rep <- vapply(split(df, df$replicate),
                        function(r) sum(!feasible(r)), integer(1L))
  expect_true(all(bad_per_rep <= observed_bad))
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

# ---------------------------------------------------------------------------
# Regressions from the 2026-11-01 audit
# ---------------------------------------------------------------------------

undirected_degrees <- function(spells) {
  pairs <- unique(data.frame(a = pmin(spells$from, spells$to),
                             b = pmax(spells$from, spells$to)))
  sort(table(c(pairs$a, pairs$b)))
}

test_that("undirected rewiring keeps every degree and the number of pairs", {
  # The swap used to test existence on the ordered key, so it could create a
  # pair that already existed the other way round and merge the two.
  dn <- quiet_dynet(random_edges(seed = 3), directed = FALSE)
  pairs_of <- function(sp) nrow(unique(data.frame(pmin(sp$from, sp$to),
                                                  pmax(sp$from, sp$to))))
  kept <- vapply(1:20, function(s) {
    null <- suppressWarnings(randomise(dn, method = "edges", n = 1, seed = s))
    sp <- attr(null, "networks")[[1L]]$spells
    identical(undirected_degrees(sp), undirected_degrees(dn$spells)) &&
      pairs_of(sp) == pairs_of(dn$spells) && all(sp$from <= sp$to)
  }, logical(1L))
  expect_true(all(kept))
})

test_that("a scope a method cannot honour is refused, not widened", {
  dn <- quiet_dynet(random_edges(seed = 5), directed = TRUE)
  for (m in c("edges", "labels")) {
    expect_error(randomise(dn, method = m, within = "sender", n = 2),
                 class = "dynet_null_bad_scope")
  }
  expect_error(randomise(dn, method = "reversal", within = "sender"),
               class = "dynet_bad_input")
  expect_error(randomise(dn, method = "times", within = "session"),
               class = "dynet_bad_input")
})

test_that("times within a sender keeps every sender's own times", {
  dn <- quiet_dynet(random_edges(seed = 5), directed = TRUE)
  by_sender <- function(sp) {
    vapply(split(paste(sp$start, sp$end), sp$from),
           function(v) paste(sort(v), collapse = ";"), character(1L))
  }
  null <- randomise(dn, method = "times", within = "sender", n = 10, seed = 1)
  kept <- vapply(attr(null, "networks"), function(net) {
    identical(by_sender(net$spells), by_sender(dn$spells))
  }, logical(1L))
  expect_true(all(kept))
  # And it is a shuffle, not the identity.
  moved <- vapply(attr(null, "networks"), function(net) {
    !identical(net$spells[c("from", "to", "start")],
               dn$spells[c("from", "to", "start")])
  }, logical(1L))
  expect_true(any(moved))
})

test_that("targets within a session repair self-loops inside the session", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "C", "A", "B", "C"), to = c("B", "C", "A", "C", "A", "B"),
    time = c(1, 2, 3, 11, 12, 13), session = rep(c("s1", "s2"), each = 3)))
  null <- randomise(dn, method = "targets", within = "session", n = 30,
                    seed = 1)
  df <- as.data.frame(null)
  expect_false(any(df$from == df$to))
  targets_of <- function(d) {
    vapply(split(d$to, d$session), function(v) paste(sort(v), collapse = ""),
           character(1L))
  }
  kept <- vapply(split(df, df$replicate), function(r) {
    identical(targets_of(r), targets_of(as.data.frame(dn)))
  }, logical(1L))
  expect_true(all(kept))
})

activity_network <- function() {
  dynet(
    data.frame(from = c("A", "A", "B", "B", "C"), to = c("B", "C", "C", "A", "B"),
               start = c(0, 1, 6, 7, 8), end = c(1, 2, 7, 8, 9)),
    vertex_spells = data.frame(node = c("A", "B", "C"), start = c(0, 0, 0),
                               end = c(3, 10, 10)),
    observation_start = 0, observation_end = 10)
}

test_that("constraints never break what the method holds fixed", {
  dn <- activity_network()
  times <- as.data.frame(randomise(dn, method = "times", n = 30, seed = 1))
  kept <- vapply(split(times, times$replicate), function(r) {
    identical(sort(paste(r$start, r$end)),
              sort(paste(dn$spells$start, dn$spells$end)))
  }, logical(1L))
  expect_true(all(kept))

  timeline <- randomise(dn, method = "timeline", n = 10, seed = 1)
  seq_of <- function(sp) {
    sort(unname(vapply(split(sp$start, paste(sp$from, sp$to)),
                       function(v) paste(sort(v), collapse = ";"),
                       character(1L))))
  }
  kept <- vapply(attr(timeline, "networks"), function(net) {
    identical(seq_of(net$spells), seq_of(dn$spells))
  }, logical(1L))
  expect_true(all(kept))
})

test_that("labels and reversal carry vertex activity with them", {
  dn <- activity_network()
  labels <- randomise(dn, method = "labels", n = 10, seed = 1)
  degree_of <- function(sp) sort(as.vector(table(c(sp$from, sp$to))))
  iso <- vapply(attr(labels, "networks"), function(net) {
    # The vertex whose name A moved to must carry A's short presence.
    renamed <- net$vertex_spells$node[net$vertex_spells$end < 5]
    identical(degree_of(net$spells), degree_of(dn$spells)) &&
      length(renamed) == 1L
  }, logical(1L))
  expect_true(all(iso))
  expect_identical(sum(attr(labels, "rejected")), 0L)

  reversed <- randomise(dn, method = "reversal")
  back <- randomise(attr(reversed, "networks")[[1L]], method = "reversal")
  vs <- attr(back, "networks")[[1L]]$vertex_spells
  expect_equal(vs$start[order(vs$node)], c(0, 0, 0))
  expect_equal(vs$end[order(vs$node)], c(3, 10, 10))
})

test_that("summary reports the rejections behind each replicate", {
  dn <- activity_network()
  null <- randomise(dn, method = "times", n = 5, seed = 1)
  s <- summary(null)
  expect_true("rejected" %in% names(s))
  expect_identical(s$rejected, as.integer(attr(null, "rejected")))
  expect_error(randomise(quiet_dynet(chain_edges()), method = "times",
                         within = "session"),
               class = "dynet_no_sessions")
})
