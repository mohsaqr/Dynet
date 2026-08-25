domain_proximity_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "domain.proximity",
    rescale = rescale, ...
  ))
}

domain_proximity_vector <- function(dn, rescale = FALSE, ...) {
  df <- domain_proximity_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("domain proximity combines incoming domain and mean hop distance", {
  chain <- matrix(c(
    0, 1, 0,
    0, 0, 1,
    0, 0, 0
  ), 3L, 3L, byrow = TRUE)
  chain_raw <- c(0, 1 / 2, 2 / 3)
  expect_identical(.domain_proximity_prestige(chain), chain_raw)
  expect_identical(
    .domain_proximity_prestige(chain, TRUE), chain_raw / sum(chain_raw)
  )
  expect_identical(
    .domain_proximity_prestige(t(chain)), c(2 / 3, 1 / 2, 0)
  )

  shortcut <- chain
  shortcut[1L, 3L] <- 1
  expect_identical(.domain_proximity_prestige(shortcut), c(0, 1 / 2, 1))
  expect_identical(
    .domain_proximity_prestige(shortcut, TRUE), c(0, 1 / 3, 2 / 3)
  )
  expect_false(identical(
    .domain_proximity_prestige(chain), .domain_prestige(chain)
  ))
})

test_that("partial domains are valid and unreachable vertices are excluded", {
  disconnected <- matrix(0, 6L, 6L)
  disconnected[cbind(c(1, 2, 4), c(2, 3, 5))] <- 1
  disconnected_raw <- c(0, 1 / 5, 4 / 15, 0, 1 / 5, 0)
  expect_identical(
    .domain_proximity_prestige(disconnected), disconnected_raw
  )
  expect_identical(
    .domain_proximity_prestige(disconnected, TRUE),
    disconnected_raw / sum(disconnected_raw)
  )

  empty <- matrix(0, 3L, 3L)
  expect_identical(.domain_proximity_prestige(empty), c(0, 0, 0))
  expect_true(all(is.nan(.domain_proximity_prestige(empty, TRUE))))
  expect_identical(.domain_proximity_prestige(matrix(0, 1L, 1L)), 0)
  expect_true(is.nan(.domain_proximity_prestige(matrix(0, 1L, 1L), TRUE)))
})

test_that("cycles and shortest-path asymmetry have literal rational values", {
  cycle <- matrix(c(
    0, 1, 0,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_identical(.domain_proximity_prestige(cycle), rep(2 / 3, 3L))
  expect_identical(.domain_proximity_prestige(cycle, TRUE), rep(1 / 3, 3L))

  asymmetric <- matrix(c(
    0, 1, 1, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
    1, 0, 0, 0
  ), 4L, 4L, byrow = TRUE)
  asymmetric_raw <- c(1 / 2, 1 / 2, 3 / 4, 3 / 5)
  expect_identical(
    .domain_proximity_prestige(asymmetric), asymmetric_raw
  )
  expect_identical(
    .domain_proximity_prestige(asymmetric, TRUE),
    asymmetric_raw / sum(asymmetric_raw)
  )
})

test_that("loops, values, and path multiplicity do not alter hop proximity", {
  diamond <- matrix(c(
    0, 1, 1, 0,
    0, 0, 0, 1,
    0, 0, 0, 1,
    0, 0, 0, 0
  ), 4L, 4L, byrow = TRUE)
  expected <- c(0, 1 / 3, 1 / 3, 3 / 4)
  expect_identical(.domain_proximity_prestige(diamond), expected)
  valued <- diamond * matrix(seq_len(16L), 4L, 4L)
  diag(valued) <- 99
  expect_identical(.domain_proximity_prestige(valued), expected)

  loop_only <- quiet_dynet(
    data.frame(from = "Q", to = "Q", time = 0), loops = TRUE
  )
  expect_identical(
    domain_proximity_vector(loop_only, start = 0, end = 0, window = 0),
    c(Q = 0)
  )
  expect_true(is.nan(domain_proximity_vector(
    loop_only, TRUE, start = 0, end = 0, window = 0
  )))

  weighted_spells <- data.frame(
    from = c("A", "A", "A", "B"), to = c("B", "B", "B", "C"),
    time = 0, weight = c(9, -9, 0, 100)
  )
  weighted_dn <- quiet_dynet(weighted_spells, weight = "weight")
  alone <- domain_proximity_vector(
    weighted_dn, start = 0, end = 0, window = 0
  )
  mixed <- as.data.frame(dyn_centrality(
    weighted_dn, measure = c("strength", "prestige"),
    prestige = "domain.proximity", start = 0, end = 0, window = 0
  ))
  expect_identical(alone, c(A = 0, B = 1 / 2, C = 2 / 3))
  actual <- subset(mixed, measure == "prestige")
  expect_identical(stats::setNames(actual$value, actual$node), alone)
})

test_that("adding an isolate changes only raw universe scaling", {
  arc2 <- matrix(c(0, 1, 0, 0), 2L, 2L, byrow = TRUE)
  arc3 <- matrix(0, 3L, 3L)
  arc3[1L, 2L] <- 1
  expect_identical(.domain_proximity_prestige(arc2), c(0, 1))
  expect_identical(.domain_proximity_prestige(arc3), c(0, 1 / 2, 0))
  expect_identical(.domain_proximity_prestige(arc3, TRUE), c(0, 1, 0))
})

test_that("public domain proximity is incoming and mode independent", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "A"), to = c("B", "C", "D"), time = 0
  ))
  incoming <- dyn_centrality(
    dn, measure = "prestige", prestige = "domain.proximity",
    start = 0, end = 0, window = 0
  )
  outgoing_mode <- dyn_centrality(
    dn, measure = "prestige", prestige = "domain.proximity", mode = "out",
    start = 0, end = 0, window = 0
  )
  expect_identical(
    stats::setNames(as.data.frame(incoming)$value,
                    as.data.frame(incoming)$node),
    c(A = 0, B = 1 / 3, C = 4 / 9, D = 1 / 3)
  )
  expect_identical(as.data.frame(outgoing_mode)$value,
                   as.data.frame(incoming)$value)
  expect_identical(attr(incoming, "what"), "Domain proximity prestige")
})

test_that("session union precedes geodesics and separate uses global n", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"), time = 0,
    session = c("s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  expect_identical(
    domain_proximity_vector(
      dn, sessions = "bounded", start = 0, end = 0, window = 0
    ),
    c(A = 0, B = 1 / 2, C = 2 / 3)
  )
  expect_identical(
    domain_proximity_vector(
      dn, TRUE, sessions = "collapse", start = 0, end = 0, window = 0
    ),
    stats::setNames(c(0, 1 / 2, 2 / 3) / sum(c(0, 1 / 2, 2 / 3)),
                    c("A", "B", "C"))
  )
  separate <- domain_proximity_frame(
    dn, sessions = "separate", start = 0, end = 0, window = 0
  )
  expect_identical(separate$value[separate$session == "s1"], c(0, 1 / 2, 0))
  expect_identical(separate$value[separate$session == "s2"], c(0, 0, 1 / 2))
  separate_scaled <- domain_proximity_frame(
    dn, TRUE, sessions = "separate", start = 0, end = 0, window = 0
  )
  expect_identical(
    separate_scaled$value[separate_scaled$session == "s1"], c(0, 1, 0)
  )
  expect_identical(
    separate_scaled$value[separate_scaled$session == "s2"], c(0, 0, 1)
  )
})

test_that("rescaling is local to positive and zero reporting blocks", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "A"), to = c("B", "C", "C"), time = c(0, 0, 2)
  ))
  result <- domain_proximity_frame(
    dn, TRUE, start = 0, end = 2, step = 1, window = 0
  )
  at_zero <- result$value[result$time == 0]
  at_one <- result$value[result$time == 1]
  at_two <- result$value[result$time == 2]
  expect_identical(sum(at_zero), 1)
  expect_true(all(is.nan(at_one)))
  expect_identical(sum(at_two), 1)
})

test_that("domain proximity is static within a reporting window", {
  spells <- data.frame(
    from = c("B", "A"), to = c("C", "B"),
    start = c(0, 2), end = c(1, 3)
  )
  dn <- quiet_dynet(spells)
  expect_identical(
    domain_proximity_vector(dn, start = 0, end = 0, window = 3),
    c(A = 0, B = 1 / 2, C = 2 / 3)
  )
})

test_that("point, interval, and final-bin boundaries precede geodesics", {
  spells <- data.frame(
    from = c("A", "B", "A", "C"), to = c("B", "C", "C", "A"),
    start = c(0, 2, 2, 3), end = c(2, 3, 2, 3)
  )
  dn <- quiet_dynet(spells)
  expect_identical(
    domain_proximity_vector(dn, start = 2, end = 2, window = 0),
    c(A = 0, B = 0, C = 1)
  )
  expect_identical(
    domain_proximity_vector(dn, start = 1, end = 1, window = 1),
    c(A = 0, B = 1 / 2, C = 0)
  )
  nonfinal <- domain_proximity_frame(
    dn, start = 2, end = 3, step = 1, window = 1
  )
  expect_identical(nonfinal$value[nonfinal$time == 2], c(0, 0, 1))
  final <- domain_proximity_frame(dn, start = 1, step = 1, window = 1)
  expect_identical(final$value[final$time == 2], c(2 / 3, 0, 1))
})

test_that("domain proximity metadata states the complete formula", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 0))
  raw <- dyn_centrality(
    dn, measure = "prestige", prestige = "domain.proximity"
  )
  expect_identical(attr(raw, "definition"), "domain.proximity")
  expect_identical(attr(raw, "direction"), "incoming")
  expect_identical(attr(raw, "matrix_transform"),
                   "directed_unweighted_geodesics")
  expect_identical(attr(raw, "path_scope"), "static_active_snapshot")
  expect_identical(attr(raw, "domain"),
                   "distinct_reaching_nonself_vertices")
  expect_identical(attr(raw, "distance"), "minimum_hop_count")
  expect_identical(attr(raw, "path_weighting"),
                   "domain_fraction_over_mean_distance")
  expect_identical(attr(raw, "unreachable"),
                   "excluded_from_domain_and_distance_sum")
  expect_identical(attr(raw, "formula"), "r^2/((n-1)*sum_distance)")
  expect_identical(attr(raw, "network_size_normalization"), "n_minus_one")
  expect_identical(attr(raw, "normalization"), "none")
  expect_identical(attr(raw, "unit"), "lin_domain_proximity")
  expect_identical(attr(raw, "weights"), "ignored")
  expect_identical(attr(raw, "loops"), "no_effect_self_excluded")
  expect_identical(attr(raw, "zero_domain"), "zero")
  expect_identical(attr(raw, "zero_total"), "NaN")

  mixed <- dyn_centrality(
    dn, measure = c("degree", "prestige"),
    prestige = "domain.proximity", rescale = TRUE
  )
  metadata <- attr(mixed, "measure_metadata")$prestige
  expect_identical(metadata$normalization, "sum_to_one")
  expect_identical(metadata$unit, "share_of_lin_domain_proximity")
})

test_that("domain proximity obeys coordinate invariants and validation", {
  spells <- data.frame(
    from = c("A", "B", "A"), to = c("B", "C", "D"),
    start = c(0, 1, 0), end = c(3, 3, 2)
  )
  value_at <- function(x, at, window) {
    domain_proximity_vector(
      quiet_dynet(x), start = at, end = at, window = window
    )
  }
  reference <- value_at(spells, 1, 1)
  expect_identical(value_at(spells[3:1, ], 1, 1), reference)
  expect_identical(value_at(
    transform(spells, start = start + 11, end = end + 11), 12, 1
  ), reference)
  expect_identical(value_at(
    transform(spells, start = start * 3, end = end * 3), 3, 3
  ), reference)
  rename <- c(A = "z", B = "q", C = "m", D = "x")
  renamed <- value_at(transform(
    spells, from = unname(rename[from]), to = unname(rename[to])
  ), 1, 1)
  expect_identical(unname(renamed[unname(rename[names(reference)])]),
                   unname(reference))

  undirected <- quiet_dynet(data.frame(from = "A", to = "B", time = 0),
                            directed = FALSE)
  expect_error(
    dyn_centrality(
      undirected, measure = "prestige", prestige = "domain.proximity"
    ),
    class = "dynet_needs_directed"
  )
  expect_error(
    dyn_centrality(
      quiet_dynet(data.frame(from = "A", to = "B", time = 0)),
      measure = "prestige", prestige = "domain.proximity", scope = "temporal"
    ),
    class = "dynet_unknown_measure"
  )
})
