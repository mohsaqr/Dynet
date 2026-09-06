# ===========================================================================
# Stage 2 B3: temporal walk centrality, Oettershagen, Mutzel & Kriege (2022).
# The oracle is the definition itself: every strict temporal walk on a small
# network is enumerated and Definitions 4.1 to 4.3 are evaluated literally.
# ===========================================================================

contacts <- function(from, to, time, end = max(time) + 1, directed = TRUE) {
  nm <- sort(unique(c(from, to)))
  log <- data.frame(from = from, to = to, time = time)
  dynet(log, format = "contact", directed = directed,
        nodes = data.frame(name = nm),
        observation_start = 0, observation_end = end)
}

walk_values <- function(dn, ...) {
  result <- dyn_centrality(dn, measure = "walk", scope = "temporal", ...)
  frame <- as.data.frame(result)
  stats::setNames(frame$value, frame$node)
}

# Definitions 4.1 to 4.3 by brute force. A strict walk uses at most one
# contact per timestamp, so the enumeration is finite.
walk_oracle <- function(log, beta, decay, directed = TRUE) {
  if (!directed) {
    log <- rbind(log, data.frame(from = log$to, to = log$from, time = log$time))
  }
  m <- nrow(log)
  walks <- list()
  grow <- function(seq) {
    last <- seq[length(seq)]
    next_contacts <- which(log$from == log$to[last] & log$time > log$time[last])
    for (j in next_contacts) {
      longer <- c(seq, j)
      walks[[length(walks) + 1L]] <<- longer
      grow(longer)
    }
  }
  for (i in seq_len(m)) {
    walks[[length(walks) + 1L]] <- i
    grow(i)
  }
  weight <- vapply(walks, function(s) beta^(length(s) - 1L), numeric(1L))
  ends_at <- vapply(walks, function(s) log$to[s[length(s)]], character(1L))
  ends_when <- vapply(walks, function(s) log$time[s[length(s)]], numeric(1L))
  starts_at <- vapply(walks, function(s) log$from[s[1L]], character(1L))
  starts_when <- vapply(walks, function(s) log$time[s[1L]], numeric(1L))
  vertices <- sort(unique(c(log$from, log$to)))
  vapply(vertices, function(v) {
    incoming <- which(ends_at == v)
    outgoing <- which(starts_at == v)
    total <- 0
    for (a in incoming) for (b in outgoing) {
      if (ends_when[a] < starts_when[b]) {
        total <- total + weight[a] * weight[b] *
          exp(-decay * (starts_when[b] - ends_when[a]))
      }
    }
    total
  }, numeric(1L))
}

test_that("walk rejects parameters outside their range, the wrong scope, and a traversal time", {
  dn <- contacts("A", "B", 0)
  expect_error(walk_values(dn, beta = 0), class = "dynet_bad_input")
  expect_error(walk_values(dn, beta = 1.5), class = "dynet_bad_input")
  expect_error(walk_values(dn, decay = -1), class = "dynet_bad_input")
  expect_error(walk_values(dn, traversal_time = 1), class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = "walk", scope = "snapshot"),
               class = "dynet_unknown_measure")
})

test_that("a two-contact path scores its middle vertex one, and its ends zero", {
  # One walk arrives at B (A->B at 0), one leaves it (B->C at 1); a single
  # contact weighs one under Definition 4.1, so C(B) = 1 whatever beta is.
  dn <- contacts(c("A", "B"), c("B", "C"), c(0, 1))
  expect_equal(walk_values(dn, beta = 0.3), c(A = 0, B = 1, C = 0))
  expect_equal(walk_values(dn, beta = 0.9), c(A = 0, B = 1, C = 0))
})

test_that("a hub pairs every arrival with every strictly later departure", {
  # Three arrivals at 1, 2, 3 and three departures at 4, 5, 6: nine pairs.
  hub <- contacts(c("L1", "L2", "L3", "H", "H", "H"),
                  c("H", "H", "H", "M1", "M2", "M3"),
                  c(1, 2, 3, 4, 5, 6))
  expect_equal(unname(walk_values(hub)["H"]), 9)
  # A fourth arrival at 5 pairs only with the departure at 6: an arrival and
  # a departure at one instant are two contacts that cannot chain.
  later <- contacts(c("L1", "L2", "L3", "L4", "H", "H", "H"),
                    c("H", "H", "H", "H", "M1", "M2", "M3"),
                    c(1, 2, 3, 5, 4, 5, 6))
  expect_equal(unname(walk_values(later)["H"]), 10)
})

test_that("a three-contact chain weighs the longer walk by beta", {
  # A->B at 0, B->C at 1, C->D at 2. Into C arrive the walk B->C (1) and
  # A->B->C (beta); out of C leaves C->D (1). Out of B leave B->C (1) and
  # B->C->D (beta); into B arrives A->B (1).
  chain <- contacts(c("A", "B", "C"), c("B", "C", "D"), c(0, 1, 2))
  expect_equal(walk_values(chain, beta = 0.25),
               c(A = 0, B = 1.25, C = 1.25, D = 0))
})

test_that("a vertex with no incoming or no outgoing contact scores exactly zero", {
  dn <- contacts(c("A", "A", "B", "C"), c("B", "C", "C", "D"), c(0, 1, 2, 3))
  values <- walk_values(dn)
  expect_identical(unname(values[c("A", "D")]), c(0, 0))
  expect_true(all(values[c("B", "C")] > 0))
})

test_that("the streaming result equals the literal definition on random contact networks", {
  set.seed(2022)
  for (trial in 1:3) {
    v <- c("a", "b", "c", "d", "e", "f")
    log <- data.frame(from = sample(v, 14, TRUE), to = sample(v, 14, TRUE),
                      time = sample(1:9, 14, TRUE))
    log <- log[log$from != log$to, ]
    for (decay in c(0, 0.4)) {
      dn <- contacts(log$from, log$to, log$time)
      got <- walk_values(dn, beta = 0.6, decay = decay)
      want <- walk_oracle(log, beta = 0.6, decay = decay)
      expect_equal(unname(got[names(want)]), unname(want),
                   info = sprintf("trial %d, decay %g", trial, decay))
    }
    und <- contacts(log$from, log$to, log$time, directed = FALSE)
    got_und <- walk_values(und, beta = 0.6, decay = 0.2)
    want_und <- walk_oracle(log, beta = 0.6, decay = 0.2, directed = FALSE)
    expect_equal(unname(got_und[names(want_und)]), unname(want_und),
                 info = sprintf("undirected trial %d", trial))
  }
})

test_that("the score is non-increasing in decay and invariant to a time shift", {
  log <- random_edges(n_v = 8L, n_e = 40L, seed = 31L)
  dn <- quiet_dynet(log)
  none <- walk_values(dn, beta = 0.5, decay = 0)
  some <- walk_values(dn, beta = 0.5, decay = 0.1)
  more <- walk_values(dn, beta = 0.5, decay = 1)
  expect_true(all(some <= none + 1e-12))
  expect_true(all(more <= some + 1e-12))
  shifted <- log
  shifted$start <- shifted$start + 1e6
  shifted$end <- shifted$end + 1e6
  dn_shifted <- quiet_dynet(shifted)
  expect_equal(walk_values(dn_shifted, beta = 0.5, decay = 0.1), some)
})

test_that("the result records its definition", {
  dn <- contacts(c("A", "B"), c("B", "C"), c(0, 1))
  result <- dyn_centrality(dn, measure = "walk", scope = "temporal", beta = 0.3, decay = 0.2)
  expect_identical(attr(result, "attenuation"), 0.3)
  expect_identical(attr(result, "decay"), 0.2)
  expect_identical(attr(result, "walk_rule"), "strict")
  expect_identical(attr(result, "walk_weight"), "beta_per_junction")
  expect_identical(attr(result, "pairing"), "arrival_strictly_before_departure")
  mixed <- dyn_centrality(dn, measure = c("walk", "katz"), scope = "temporal")
  expect_identical(attr(mixed, "measure_metadata")$walk$walk_rule, "strict")
})

test_that("an accumulator past the double range is a classed error, not Inf", {
  # beta = 1 on a long dense strict stream doubles the walk count at every
  # instant, so it passes 2^1023 well inside a few thousand contacts.
  n <- 1200L
  log <- data.frame(from = rep(c("A", "B"), n), to = rep(c("B", "A"), n),
                    time = seq_len(2L * n))
  dn <- contacts(log$from, log$to, log$time)
  expect_error(walk_values(dn, beta = 1), class = "dynet_walk_overflow")
})
