domain_prestige_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "domain",
    rescale = rescale, ...
  ))
}

domain_prestige_vector <- function(dn, rescale = FALSE, ...) {
  df <- domain_prestige_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("domain prestige counts distinct incoming transitive reach", {
  chain <- matrix(c(
    0, 1, 0,
    0, 0, 1,
    0, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_identical(.domain_prestige(chain), c(0, 1, 2))
  expect_identical(.domain_prestige(chain, TRUE), c(0, 1 / 3, 2 / 3))
  expect_false(identical(.domain_prestige(chain), colSums(chain)))
  expect_identical(.domain_prestige(t(chain)), c(2, 1, 0))

  diamond <- matrix(c(
    0, 1, 1, 0,
    0, 0, 0, 1,
    0, 0, 0, 1,
    0, 0, 0, 0
  ), 4L, 4L, byrow = TRUE)
  expect_identical(.domain_prestige(diamond), c(0, 1, 1, 3))
  diamond[1L, 4L] <- 1
  expect_identical(.domain_prestige(diamond), c(0, 1, 1, 3))
})

test_that("cycles exclude self and paths never multiply a source", {
  cycle <- matrix(c(
    0, 1, 0,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_identical(.domain_prestige(cycle), c(2, 2, 2))
  expect_identical(.domain_prestige(cycle, TRUE), rep(1 / 3, 3L))

  scc_tail <- matrix(c(
    0, 1, 0,
    1, 0, 1,
    0, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_identical(.domain_prestige(scc_tail), c(1, 1, 2))
})

test_that("isolates are zero and zero-total normalization is NaN", {
  empty <- matrix(0, 3L, 3L)
  expect_identical(.domain_prestige(empty), c(0, 0, 0))
  expect_true(all(is.nan(.domain_prestige(empty, TRUE))))
  expect_identical(.domain_prestige(matrix(0, 1L, 1L)), 0)
  expect_true(is.nan(.domain_prestige(matrix(0, 1L, 1L), TRUE)))

  disconnected <- matrix(0, 6L, 6L)
  disconnected[cbind(c(1, 2, 4), c(2, 3, 5))] <- 1
  expect_identical(.domain_prestige(disconnected), c(0, 1, 2, 0, 1, 0))
  expect_identical(
    .domain_prestige(disconnected, TRUE),
    c(0, 1 / 4, 1 / 2, 0, 1 / 4, 0)
  )
})

test_that("loops and valued magnitudes cannot change the domain", {
  arc <- matrix(c(0, 7, 0, 0), 2L, 2L, byrow = TRUE)
  looped <- arc
  diag(looped) <- c(99, 4)
  expect_identical(.domain_prestige(arc), c(0, 1))
  expect_identical(.domain_prestige(looped), c(0, 1))

  loop <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("A", "B"), time = 0,
    weight = c(100, -7)
  ), loops = TRUE, weight = "weight")
  expect_identical(
    domain_prestige_vector(loop, start = 0, end = 0, window = 0),
    c(A = 0, B = 1)
  )
  dropped <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("A", "B"), time = 0
  ), loops = FALSE)
  expect_identical(
    domain_prestige_vector(dropped, start = 0, end = 0, window = 0),
    c(A = 0, B = 1)
  )

  loop_only <- quiet_dynet(
    data.frame(from = "Q", to = "Q", time = 0), loops = TRUE
  )
  expect_identical(
    domain_prestige_vector(loop_only, start = 0, end = 0, window = 0),
    c(Q = 0)
  )
  expect_true(is.nan(domain_prestige_vector(
    loop_only, TRUE, start = 0, end = 0, window = 0
  )))
})

test_that("the public chain is incoming and mode independent", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "A"), to = c("B", "C", "D"), time = 0
  ))
  incoming <- dyn_centrality(
    dn, measure = "prestige", prestige = "domain",
    start = 0, end = 0, window = 0
  )
  outgoing_mode <- dyn_centrality(
    dn, measure = "prestige", prestige = "domain", mode = "out",
    start = 0, end = 0, window = 0
  )
  expect_identical(
    stats::setNames(as.data.frame(incoming)$value,
                    as.data.frame(incoming)$node),
    c(A = 0, B = 1, C = 2, D = 1)
  )
  expect_identical(as.data.frame(outgoing_mode)$value,
                   as.data.frame(incoming)$value)
  expect_identical(attr(incoming, "what"), "Domain prestige")
})

test_that("domain is static closure within a reporting window", {
  spells <- data.frame(
    from = c("B", "A"), to = c("C", "B"),
    start = c(0, 2), end = c(1, 3)
  )
  dn <- quiet_dynet(spells)
  expect_identical(
    domain_prestige_vector(dn, start = 0, end = 0, window = 3),
    c(A = 0, B = 1, C = 2)
  )
})

test_that("point, interval, and final-bin boundaries precede closure", {
  spells <- data.frame(
    from = c("A", "B", "A", "C"), to = c("B", "C", "C", "A"),
    start = c(0, 2, 2, 3), end = c(2, 3, 2, 3)
  )
  dn <- quiet_dynet(spells)
  expect_identical(
    domain_prestige_vector(dn, start = 2, end = 2, window = 0),
    c(A = 0, B = 0, C = 2)
  )
  expect_identical(
    domain_prestige_vector(dn, start = 1, end = 1, window = 1),
    c(A = 0, B = 1, C = 0)
  )
  expect_identical(
    domain_prestige_vector(dn, start = 2, end = 2, window = 1),
    c(A = 0, B = 0, C = 2)
  )

  nonfinal <- domain_prestige_frame(
    dn, start = 2, end = 3, step = 1, window = 1
  )
  expect_identical(nonfinal$value[nonfinal$time == 2], c(0, 0, 2))

  default_grid <- domain_prestige_frame(
    dn, start = 1, step = 1, window = 1
  )
  expect_identical(default_grid$value[default_grid$time == 1], c(0, 1, 0))
  expect_identical(default_grid$value[default_grid$time == 2], c(2, 0, 2))
})

test_that("session union precedes closure and separate closure stays local", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"), time = 0,
    session = c("s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  expect_identical(
    domain_prestige_vector(
      dn, sessions = "bounded", start = 0, end = 0, window = 0
    ),
    c(A = 0, B = 1, C = 2)
  )
  expect_identical(
    domain_prestige_vector(
      dn, TRUE, sessions = "collapse", start = 0, end = 0, window = 0
    ),
    c(A = 0, B = 1 / 3, C = 2 / 3)
  )
  separate <- domain_prestige_frame(
    dn, sessions = "separate", start = 0, end = 0, window = 0
  )
  expect_identical(separate$value[separate$session == "s1"], c(0, 1, 0))
  expect_identical(separate$value[separate$session == "s2"], c(0, 0, 1))
})

test_that("domain rescaling is local to each reporting block", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "A"),
    time = c(0, 0, 1)
  ))
  result <- domain_prestige_frame(
    dn, TRUE, start = 0, end = 1, step = 1, window = 0
  )
  expect_identical(as.numeric(tapply(result$value, result$time, sum)), c(1, 1))
})

test_that("domain prestige publishes the frozen mathematical metadata", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 0))
  raw <- dyn_centrality(dn, measure = "prestige", prestige = "domain")
  expect_identical(attr(raw, "definition"), "domain")
  expect_identical(attr(raw, "direction"), "incoming")
  expect_identical(attr(raw, "matrix_transform"),
                   "directed_transitive_closure")
  expect_identical(attr(raw, "path_scope"), "static_active_snapshot")
  expect_identical(attr(raw, "path_weighting"),
                   "unweighted_distinct_reachers")
  expect_identical(attr(raw, "self_reach"), "excluded")
  expect_identical(attr(raw, "normalization"), "none")
  expect_identical(attr(raw, "unit"), "distinct_reaching_vertices")
  expect_identical(attr(raw, "weights"), "ignored")
  expect_identical(attr(raw, "loops"), "no_effect_self_excluded")
  expect_identical(attr(raw, "unreachable"), "zero")
  expect_identical(attr(raw, "zero_total"), "NaN")

  mixed <- dyn_centrality(
    dn, measure = c("degree", "prestige"), prestige = "domain",
    rescale = TRUE
  )
  metadata <- attr(mixed, "measure_metadata")$prestige
  expect_identical(metadata$normalization, "sum_to_one")
  expect_identical(metadata$unit, "share_of_ordered_reachable_pairs")
})

test_that("domain public invariants and validation are explicit", {
  spells <- data.frame(
    from = c("A", "B", "A"), to = c("B", "C", "D"),
    start = c(0, 1, 0), end = c(3, 3, 2)
  )
  value_at <- function(x, at, window) {
    domain_prestige_vector(
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
    dyn_centrality(undirected, measure = "prestige", prestige = "domain"),
    class = "dynet_needs_directed"
  )
  expect_error(
    dyn_centrality(
      quiet_dynet(data.frame(from = "A", to = "B", time = 0)),
      measure = "prestige", prestige = "domain", scope = "temporal"
    ),
    class = "dynet_unknown_measure"
  )
})
