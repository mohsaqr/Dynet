rownorm_eigen_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector.rownorm",
    rescale = rescale, ...
  ))
}

rownorm_eigen_vector <- function(dn, rescale = FALSE, ...) {
  df <- rownorm_eigen_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("row-normalized incoming Perron prestige has its literal ray", {
  b <- matrix(c(
    0, 1, 1,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expected_transform <- matrix(c(
    0, 1 / 2, 1 / 2,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expected_raw <- c(2 / 3, 1 / 3, 2 / 3)
  expected_scaled <- c(2 / 5, 1 / 5, 2 / 5)

  denominator <- rowSums(b)
  transformed <- b
  transformed[denominator > 0, ] <-
    transformed[denominator > 0, , drop = FALSE] / denominator[denominator > 0]
  expect_identical(transformed, expected_transform)
  expect_equal(as.vector(t(transformed) %*% c(2, 1, 2)), c(2, 1, 2))
  expect_equal(
    .eigen_prestige(b, definition = "eigenvector.rownorm"),
    expected_raw, tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(b, TRUE, definition = "eigenvector.rownorm"),
    expected_scaled, tolerance = 1e-14
  )

  plain <- .eigen_prestige(b)
  indegree_rownorm <- colSums(expected_transform)
  indegree_rownorm <- indegree_rownorm / sum(indegree_rownorm)
  expect_gt(max(abs(plain - expected_raw)), 0.05)
  expect_gt(max(abs(indegree_rownorm - expected_scaled)), 0.05)
  wrong_order <- expected_transform
  wrong_order[] <- t(b)
  wrong_denominator <- rowSums(wrong_order)
  wrong_order[wrong_denominator > 0, ] <-
    wrong_order[wrong_denominator > 0, , drop = FALSE] /
      wrong_denominator[wrong_denominator > 0]
  expect_false(isTRUE(all.equal(t(wrong_order), expected_transform)))
})

test_that("periodic row-normalized matrices retain their real Perron ray", {
  reciprocal <- matrix(c(0, 1, 1, 0), 2L, 2L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(reciprocal, definition = "eigenvector.rownorm"),
    rep(1 / sqrt(2), 2), tolerance = 1e-14
  )

  cycle <- matrix(c(
    0, 1, 0,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(cycle, definition = "eigenvector.rownorm"),
    rep(1 / sqrt(3), 3), tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(cycle, TRUE, definition = "eigenvector.rownorm"),
    rep(1 / 3, 3), tolerance = 1e-14
  )
})

test_that("loops enter the binary row denominator before the solve", {
  looped <- matrix(c(0, 1, 1, 1), 2L, 2L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(looped, definition = "eigenvector.rownorm"),
    c(1, 2) / sqrt(5), tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(looped, TRUE, definition = "eigenvector.rownorm"),
    c(1 / 3, 2 / 3), tolerance = 1e-14
  )
  loopless <- looped
  diag(loopless) <- 0
  expect_equal(
    .eigen_prestige(loopless, definition = "eigenvector.rownorm"),
    rep(1 / sqrt(2), 2), tolerance = 1e-14
  )

  spells <- data.frame(
    from = c("A", "B", "B"), to = c("B", "A", "B"), time = 0
  )
  retained <- quiet_dynet(spells, loops = TRUE)
  dropped <- quiet_dynet(spells, loops = FALSE)
  expect_equal(
    rownorm_eigen_vector(retained, start = 0, end = 0, window = 0),
    c(A = 1 / sqrt(5), B = 2 / sqrt(5)), tolerance = 1e-14
  )
  expect_equal(
    rownorm_eigen_vector(dropped, start = 0, end = 0, window = 0),
    c(A = 1 / sqrt(2), B = 1 / sqrt(2)), tolerance = 1e-14
  )
})

test_that("zero sender rows stay zero without forcing undefined output", {
  leakage <- matrix(c(1, 1, 0, 0), 2L, 2L, byrow = TRUE)
  value <- .eigen_prestige(
    leakage, definition = "eigenvector.rownorm"
  )
  expect_equal(value, rep(1 / sqrt(2), 2), tolerance = 1e-14)
  diagnostic <- attr(value, "prestige_diagnostic")
  expect_null(diagnostic)

  loop_isolate <- diag(c(1, 0))
  expect_identical(
    .eigen_prestige(loop_isolate, definition = "eigenvector.rownorm"),
    c(1, 0)
  )

  defective_unique <- matrix(c(
    1, 1, 0,
    0, 1, 1,
    0, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(defective_unique,
                    definition = "eigenvector.rownorm"),
    c(0, 1 / sqrt(2), 1 / sqrt(2)), tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(defective_unique, TRUE,
                    definition = "eigenvector.rownorm"),
    c(0, 1 / 2, 1 / 2), tolerance = 1e-14
  )
})

test_that("row-normalized zero-radius and tied rays are undefined", {
  cases <- list(
    zero = matrix(0, 3L, 3L),
    arc = matrix(c(0, 1, 0, 0), 2L, 2L, byrow = TRUE),
    chain = matrix(c(0, 1, 0, 0, 0, 1, 0, 0, 0), 3L, 3L, byrow = TRUE)
  )
  lapply(cases, function(x) {
    expect_warning(
      value <- .eigen_prestige(x, definition = "eigenvector.rownorm"),
      class = "dynet_prestige_eigen_undefined"
    )
    expect_true(all(is.na(value)))
    expect_identical(attr(value, "prestige_diagnostic")$reason,
                     "zero_spectral_radius")
  })

  tied <- diag(2)
  expect_warning(
    value <- .eigen_prestige(tied, definition = "eigenvector.rownorm"),
    class = "dynet_prestige_eigen_undefined"
  )
  expect_true(all(is.na(value)))
  expect_identical(attr(value, "prestige_diagnostic")$reason,
                   "nonunique_perron_eigenspace")

  expect_warning(
    singleton <- .eigen_prestige(
      matrix(0, 1L, 1L), definition = "eigenvector.rownorm"
    ), class = "dynet_prestige_eigen_undefined"
  )
  expect_true(is.na(singleton))
  expect_identical(
    .eigen_prestige(matrix(1, 1L, 1L),
                    definition = "eigenvector.rownorm"),
    1
  )
})

test_that("public row-normalized eigen prestige is binary and mode invariant", {
  spells <- data.frame(
    from = c("A", "A", "A", "B", "C"),
    to = c("B", "B", "C", "C", "A"), time = 0,
    weight = c(9, -4, 100, 7, 3)
  )
  dn <- quiet_dynet(spells, weight = "weight")
  expected <- c(A = 2 / 3, B = 1 / 3, C = 2 / 3)
  actual <- rownorm_eigen_vector(dn, start = 0, end = 0, window = 0)
  expect_equal(actual, expected, tolerance = 1e-14)
  expect_equal(
    rownorm_eigen_vector(dn, mode = "out", start = 0, end = 0, window = 0),
    expected, tolerance = 1e-14
  )

  mixed <- as.data.frame(dyn_centrality(
    dn, measure = c("strength", "prestige"),
    prestige = "eigenvector.rownorm", start = 0, end = 0, window = 0
  ))
  prestige_rows <- subset(mixed, measure == "prestige")
  expect_equal(stats::setNames(prestige_rows$value, prestige_rows$node),
               expected, tolerance = 1e-14)
})

test_that("session union precedes row normalization", {
  spells <- data.frame(
    from = c("A", "B", "A", "B"),
    to = c("A", "A", "B", "A"), time = 0,
    session = c("s1", "s1", "s2", "s2")
  )
  dn <- quiet_dynet(spells, session = "session", loops = TRUE)
  expect_equal(
    rownorm_eigen_vector(
      dn, sessions = "bounded", start = 0, end = 0, window = 0
    ), c(A = 2 / sqrt(5), B = 1 / sqrt(5)), tolerance = 1e-14
  )
  expect_equal(
    rownorm_eigen_vector(
      dn, TRUE, sessions = "collapse", start = 0, end = 0, window = 0
    ), c(A = 2 / 3, B = 1 / 3), tolerance = 1e-14
  )

  separate <- rownorm_eigen_frame(
    dn, sessions = "separate", start = 0, end = 0, window = 0
  )
  s1 <- subset(separate, session == "s1")
  s2 <- subset(separate, session == "s2")
  expect_equal(stats::setNames(s1$value, s1$node), c(A = 1, B = 0),
               tolerance = 1e-14)
  expect_equal(stats::setNames(s2$value, s2$node),
               c(A = 1 / sqrt(2), B = 1 / sqrt(2)), tolerance = 1e-14)

  separate_scaled <- rownorm_eigen_frame(
    dn, TRUE, sessions = "separate", start = 0, end = 0, window = 0
  )
  scaled_s1 <- subset(separate_scaled, session == "s1")
  scaled_s2 <- subset(separate_scaled, session == "s2")
  expect_equal(stats::setNames(scaled_s1$value, scaled_s1$node),
               c(A = 1, B = 0), tolerance = 1e-14)
  expect_equal(stats::setNames(scaled_s2$value, scaled_s2$node),
               c(A = 1 / 2, B = 1 / 2), tolerance = 1e-14)
  expect_equal(
    as.numeric(tapply(separate_scaled$value, separate_scaled$session, sum)),
    c(1, 1), tolerance = 1e-14
  )
})

test_that("snapshot boundaries are applied before row normalization", {
  spells <- data.frame(
    from = c("A", "B", "A"), to = c("B", "A", "A"),
    start = c(0, 2, 2), end = c(2, 4, 2)
  )
  dn <- quiet_dynet(spells, loops = TRUE)
  expect_equal(
    rownorm_eigen_vector(dn, start = 2, end = 2, window = 0),
    c(A = 1, B = 0), tolerance = 1e-14
  )
  expect_warning(
    half_open <- dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.rownorm",
      start = 1, end = 1, window = 1
    ), class = "dynet_prestige_eigen_undefined"
  )
  expect_true(all(is.na(as.data.frame(half_open)$value)))
  expect_equal(
    rownorm_eigen_vector(dn, start = 0, end = 0, window = 4),
    c(A = 2 / sqrt(5), B = 1 / sqrt(5)), tolerance = 1e-14
  )
})

test_that("row-normalized eigen prestige publishes transform and solver", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "A"), time = 0
  ))
  raw <- dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector.rownorm"
  )
  expect_identical(attr(raw, "definition"), "eigenvector.rownorm")
  expect_identical(attr(raw, "direction"), "incoming")
  expect_identical(attr(raw, "matrix_transform"),
                   "transpose_row_stochastic_binary_adjacency")
  expect_identical(attr(raw, "row_denominator"),
                   "distinct_outgoing_binary_dyads")
  expect_identical(attr(raw, "zero_rows"), "all_zero")
  expect_identical(attr(raw, "uniqueness"), "geometric_multiplicity_one")
  expect_identical(attr(raw, "normalization"), "l2_unit")
  expect_identical(attr(raw, "unit"),
                   "l2_incoming_row_stochastic_perron_weight")
  expect_identical(attr(raw, "loops"),
                   "retained_once_before_row_normalization")
  expect_identical(attr(raw, "undefined"), "NA")

  scaled <- dyn_centrality(
    dn, measure = c("degree", "prestige"),
    prestige = "eigenvector.rownorm", rescale = TRUE
  )
  metadata <- attr(scaled, "measure_metadata")$prestige
  expect_identical(metadata$normalization, "sum_to_one")
  expect_identical(metadata$unit,
                   "share_of_incoming_row_stochastic_perron_weight")
})

test_that("row-normalized eigen prestige obeys coordinates and scope", {
  spells <- data.frame(
    from = c("A", "A", "B", "C"), to = c("B", "C", "C", "A"),
    start = c(0, 0, 1, 0), end = c(3, 2, 3, 3)
  )
  value_at <- function(x, at, window) {
    rownorm_eigen_vector(quiet_dynet(x), start = at, end = at,
                         window = window)
  }
  reference <- value_at(spells, 1, 1)
  expect_equal(value_at(spells[4:1, ], 1, 1), reference, tolerance = 1e-14)
  expect_equal(value_at(
    transform(spells, start = start + 17, end = end + 17), 18, 1
  ), reference, tolerance = 1e-14)
  expect_equal(value_at(
    transform(spells, start = start * 3, end = end * 3), 3, 3
  ), reference, tolerance = 1e-14)
  rename <- c(A = "z", B = "q", C = "m")
  renamed <- value_at(transform(
    spells, from = unname(rename[from]), to = unname(rename[to])
  ), 1, 1)
  expect_equal(unname(renamed[unname(rename[names(reference)])]),
               unname(reference), tolerance = 1e-14)

  undirected <- quiet_dynet(data.frame(from = "A", to = "B", time = 0),
                            directed = FALSE)
  expect_error(dyn_centrality(
    undirected, measure = "prestige", prestige = "eigenvector.rownorm"
  ), class = "dynet_needs_directed")
  expect_error(dyn_centrality(
    quiet_dynet(data.frame(from = "A", to = "B", time = 0)),
    measure = "prestige", prestige = "eigenvector.rownorm",
    scope = "temporal"
  ), class = "dynet_unknown_measure")
})
