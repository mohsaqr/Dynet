burst_values <- function(dn, ...) {
  result <- as.data.frame(dyn_burstiness(
    dn, measure = c("burstiness", "memory", "events", "mean_gap"), ...
  ))
  stats::setNames(result$value, paste(result$node, result$measure, sep = ":"))
}

test_that("the burst reducer uses population gap dispersion", {
  regular <- .burst_stats(c(0, 2, 4, 6))
  expect_identical(regular,
                   c(burstiness = -1, memory = NA_real_, events = 4,
                     mean_gap = 2))

  irregular <- .burst_stats(c(0, 1, 3, 8, 12))
  expect_equal(irregular[["burstiness"]],
               (sqrt(10) - 6) / (sqrt(10) + 6))
  expect_equal(irregular[["memory"]], 4 / sqrt(91))
  expect_identical(irregular[["events"]], 5)
  expect_identical(irregular[["mean_gap"]], 3)
})

test_that("the sequence reducer pools gaps and pairs only within sequences", {
  sequences <- list(c(0, 1, 2, 3), c(100, 102, 106, 114))
  primitive <- .burst_primitives(sequences)
  expect_identical(primitive$events, 8L)
  expect_identical(primitive$gaps, c(1, 1, 1, 2, 4, 8))
  expect_identical(
    primitive$pairs,
    data.frame(left = c(1, 1, 2, 4), right = c(1, 1, 4, 8))
  )

  pooled <- .burst_stats_sequences(sequences)
  expect_equal(
    pooled[c("events", "mean_gap")], c(events = 8, mean_gap = 17 / 6)
  )
  expect_equal(pooled[["burstiness"]],
               (sqrt(233) - 17) / (sqrt(233) + 17))
  expect_equal(pooled[["memory"]], 14 / sqrt(198))

  session_coefficients <- vapply(
    sequences, function(x) .burst_stats(x)[["burstiness"]], numeric(1L)
  )
  expect_false(isTRUE(all.equal(
    pooled[["burstiness"]], mean(session_coefficients)
  )))
  cross_wall_memory <- 38 / sqrt(1479)
  expect_false(isTRUE(all.equal(pooled[["memory"]], cross_wall_memory)))
})

test_that("gap order changes memory but not burstiness", {
  alternating <- .burst_stats(cumsum(c(0, 1, 9, 1, 9, 1, 9)))
  clustered <- .burst_stats(cumsum(c(0, 1, 1, 1, 9, 9, 9)))
  expect_identical(alternating[["burstiness"]], -1 / 9)
  expect_identical(clustered[["burstiness"]], -1 / 9)
  expect_identical(alternating[["memory"]], -1)
  expect_equal(clustered[["memory"]], 2 / 3)
})

test_that("equal-time occurrences retain zero gaps", {
  tied <- .burst_stats(c(0, 0, 2))
  expect_identical(tied,
                   c(burstiness = 0, memory = NA_real_, events = 3,
                     mean_gap = 1))

  all_zero <- .burst_stats(c(0, 0, 0))
  expect_true(is.na(all_zero[["burstiness"]]))
  expect_true(is.na(all_zero[["memory"]]))
  expect_identical(all_zero[["events"]], 3)
  expect_identical(all_zero[["mean_gap"]], 0)

  repeated <- .burst_stats(c(0, 0, 1, 1, 2))
  expect_identical(repeated[["burstiness"]], 0)
  expect_identical(repeated[["memory"]], -1)
})

test_that("zero through four events pin every undefined threshold", {
  zero <- .burst_stats(numeric())
  one <- .burst_stats(0)
  two <- .burst_stats(c(0, 2))
  three <- .burst_stats(c(0, 1, 3))
  four <- .burst_stats(c(0, 1, 3, 6))

  expect_identical(zero,
                   c(burstiness = NA_real_, memory = NA_real_, events = 0,
                     mean_gap = NA_real_))
  expect_identical(one,
                   c(burstiness = NA_real_, memory = NA_real_, events = 1,
                     mean_gap = NA_real_))
  expect_identical(two,
                   c(burstiness = NA_real_, memory = NA_real_, events = 2,
                     mean_gap = 2))
  expect_identical(three[["burstiness"]], -1 / 2)
  expect_true(is.na(three[["memory"]]))
  expect_equal(four[["burstiness"]],
               (sqrt(2 / 3) - 2) / (sqrt(2 / 3) + 2))
  expect_identical(four[["memory"]], 1)
})

test_that("one retained self-loop contributes one incident event", {
  spells <- data.frame(
    from = c("A", "A", "A"), to = c("B", "A", "B"), time = c(0, 1, 2)
  )
  value <- burst_values(quiet_dynet(spells, loops = TRUE))
  expect_identical(value[["A:events"]], 3)
  expect_identical(value[["A:mean_gap"]], 1)
  expect_identical(value[["A:burstiness"]], -1)
  expect_true(is.na(value[["A:memory"]]))
  expect_identical(value[["B:events"]], 2)
  expect_identical(value[["B:mean_gap"]], 2)
})

test_that("bounded sessions pool primitive gaps without crossing walls", {
  spells <- data.frame(
    from = rep("A", 6), to = rep("B", 6),
    time = c(0, 1, 2, 100, 101, 102),
    session = rep(c("s1", "s2"), each = 3)
  )
  dn <- quiet_dynet(spells, session = "session")
  bounded <- burst_values(dn, sessions = "bounded")
  collapsed <- burst_values(dn, sessions = "collapse")
  separate <- as.data.frame(dyn_burstiness(
    dn, measure = c("burstiness", "memory", "events", "mean_gap"),
    sessions = "separate"
  ))

  expect_identical(bounded[["A:events"]], 6)
  expect_identical(bounded[["A:mean_gap"]], 1)
  expect_identical(bounded[["A:burstiness"]], -1)
  expect_true(is.na(bounded[["A:memory"]]))
  expect_identical(collapsed[["A:mean_gap"]], 102 / 5)
  expect_identical(collapsed[["A:burstiness"]], 23 / 74)
  expect_equal(collapsed[["A:memory"]], -1 / 3)

  a <- separate[separate$node == "A", ]
  expect_true(all(a$value[a$measure == "events"] == 3))
  expect_true(all(a$value[a$measure == "mean_gap"] == 1))
  expect_true(all(a$value[a$measure == "burstiness"] == -1))
  expect_true(all(is.na(a$value[a$measure == "memory"])))
})

test_that("interval ends and weights do not change onset-event statistics", {
  base <- data.frame(
    from = rep("A", 4), to = rep("B", 4), start = c(0, 1, 3, 6),
    end = c(1, 2, 4, 7), weight = c(1, 1, 1, 1)
  )
  altered <- transform(base, end = c(100, 1.5, 20, 6.1),
                       weight = c(0.1, 2, 50, 999))
  expect_identical(burst_values(quiet_dynet(altered, weight = "weight")),
                   burst_values(quiet_dynet(base, weight = "weight")))
})

test_that("burstiness transforms by its documented units", {
  spells <- data.frame(
    from = rep("A", 5), to = rep("B", 5), time = c(0, 1, 3, 8, 12)
  )
  base <- burst_values(quiet_dynet(spells))
  permuted <- burst_values(quiet_dynet(spells[c(5, 2, 4, 1, 3), ]))
  shifted <- burst_values(quiet_dynet(transform(spells, time = time + 17)))
  scaled <- burst_values(quiet_dynet(transform(spells, time = time * 3)))
  renamed <- burst_values(quiet_dynet(transform(
    spells, from = "Q", to = "Z"
  )))
  expect_identical(permuted, base)
  expect_identical(shifted, base)
  expect_identical(unname(renamed), unname(base))
  expect_equal(
    scaled[grepl(":burstiness$|:memory$|:events$", names(scaled))],
    base[grepl(":burstiness$|:memory$|:events$", names(base))]
  )
  expect_equal(
    unname(scaled[grepl(":mean_gap$", names(scaled))]),
    3 * unname(base[grepl(":mean_gap$", names(base))])
  )

  ordinary <- .burst_stats(cumsum(c(0, 1, 2, 4, 8)))
  scaled_stats <- lapply(c(1e200, 1e100, 1e-100, 1e-200), function(scale) {
    .burst_stats(cumsum(c(0, 1, 2, 4, 8) * scale))
  })
  invariant <- c("burstiness", "memory", "events")
  lapply(scaled_stats, function(one) {
    expect_equal(one[invariant], ordinary[invariant])
    expect_false(any(is.nan(one)))
  })

  reversed <- burst_values(quiet_dynet(transform(spells, time = 12 - time)))
  expect_equal(reversed, base)
})

test_that("incidence is direction-neutral and undirected orientation-neutral", {
  spells <- data.frame(
    from = c("A", "B", "A", "B"), to = c("B", "A", "B", "A"),
    time = c(0, 1, 3, 6)
  )
  directed <- burst_values(quiet_dynet(spells, directed = TRUE))
  undirected <- burst_values(quiet_dynet(spells, directed = FALSE))
  reoriented <- burst_values(quiet_dynet(transform(
    spells, from = to, to = from
  ), directed = FALSE))
  expect_identical(undirected, directed)
  expect_identical(reoriented, undirected)
})

test_that("bounded burstiness is invariant to session and row order", {
  spells <- data.frame(
    from = rep("A", 6), to = rep("B", 6),
    time = c(0, 1, 2, 100, 101, 102),
    session = rep(c("s1", "s2"), each = 3)
  )
  base <- burst_values(quiet_dynet(spells, session = "session"),
                       sessions = "bounded")
  permuted <- spells[c(6, 2, 4, 1, 5, 3), ]
  permuted$session <- ifelse(permuted$session == "s1", "later", "earlier")
  expect_identical(
    burst_values(quiet_dynet(permuted, session = "session"),
                 sessions = "bounded"),
    base
  )
})

test_that("burstiness publishes event and session semantics", {
  dn <- quiet_dynet(data.frame(
    from = rep("A", 3), to = rep("B", 3), time = 0:2
  ))
  result <- dyn_burstiness(dn)
  expect_identical(attr(result, "event_identity"), "incident_spell_start")
  expect_identical(attr(result, "dispersion"), "population")
  expect_identical(attr(result, "memory"), "lag1_pearson")
  expect_identical(attr(result, "loop_contribution"), "one_event")
  expect_identical(attr(result, "weights"), "ignored")
  expect_identical(attr(result, "session_gaps"), "excluded")
})
