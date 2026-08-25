colnorm_eigen_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector.colnorm",
    rescale = rescale, ...
  ))
}

colnorm_eigen_vector <- function(dn, rescale = FALSE, ...) {
  df <- colnorm_eigen_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("column-normalized incoming prestige has its literal uniform ray", {
  b <- matrix(c(
    0, 1, 1,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expected_transform <- matrix(c(
    0, 1, 1 / 2,
    0, 0, 1 / 2,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  totals <- colSums(b)
  transformed <- b
  transformed[, totals > 0] <- sweep(
    transformed[, totals > 0, drop = FALSE], 2L, totals[totals > 0], "/"
  )
  expect_identical(transformed, expected_transform)
  expect_equal(as.vector(t(transformed) %*% rep(1, 3)), rep(1, 3))
  expect_equal(
    .eigen_prestige(b, definition = "eigenvector.colnorm"),
    rep(1 / sqrt(3), 3), tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(b, TRUE, definition = "eigenvector.colnorm"),
    rep(1 / 3, 3), tolerance = 1e-14
  )
  expect_gt(max(abs(.eigen_prestige(b) - rep(1 / sqrt(3), 3))), 0.1)
  expect_gt(max(abs(
    .eigen_prestige(b, definition = "eigenvector.rownorm") -
      rep(1 / sqrt(3), 3)
  )), 0.1)
})

test_that("zero columns permit a nonuniform certified ray", {
  b <- matrix(c(
    1, 1, 0,
    0, 0, 0,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expected_transform <- matrix(c(
    1 / 2, 1, 0,
    0, 0, 0,
    1 / 2, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expected_raw <- c(1, 2, 0) / sqrt(5)
  expected_scaled <- c(1 / 3, 2 / 3, 0)
  expect_equal(as.vector(t(expected_transform) %*% c(1, 2, 0)),
               c(1, 2, 0) / 2)
  expect_equal(
    .eigen_prestige(b, definition = "eigenvector.colnorm"),
    expected_raw, tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(b, TRUE, definition = "eigenvector.colnorm"),
    expected_scaled, tolerance = 1e-14
  )
  normalized_column_sums <- colSums(expected_transform)
  normalized_column_sums <- normalized_column_sums /
    sum(normalized_column_sums)
  expect_gt(max(abs(normalized_column_sums - expected_scaled)), 0.1)
})

test_that("periodic column-normalized matrices retain the real Perron ray", {
  reciprocal <- matrix(c(0, 1, 1, 0), 2L, 2L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(reciprocal, definition = "eigenvector.colnorm"),
    rep(1 / sqrt(2), 2), tolerance = 1e-14
  )
  cycle <- matrix(c(
    0, 1, 0,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(cycle, definition = "eigenvector.colnorm"),
    rep(1 / sqrt(3), 3), tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(cycle, TRUE, definition = "eigenvector.colnorm"),
    rep(1 / 3, 3), tolerance = 1e-14
  )
})

test_that("loops enter the binary column denominator before the solve", {
  looped <- matrix(c(0, 1, 0, 1), 2L, 2L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(looped, definition = "eigenvector.colnorm"),
    c(0, 1), tolerance = 1e-14
  )
  loopless <- looped
  diag(loopless) <- 0
  expect_warning(
    value <- .eigen_prestige(loopless,
                             definition = "eigenvector.colnorm"),
    class = "dynet_prestige_eigen_undefined"
  )
  expect_true(all(is.na(value)))

  spells <- data.frame(
    from = c("A", "B"), to = c("B", "B"), time = 0
  )
  retained <- quiet_dynet(spells, loops = TRUE)
  dropped <- quiet_dynet(spells, loops = FALSE)
  expect_equal(
    colnorm_eigen_vector(retained, start = 0, end = 0, window = 0),
    c(A = 0, B = 1), tolerance = 1e-14
  )
  expect_warning(
    dropped_value <- dyn_centrality(
      dropped, measure = "prestige", prestige = "eigenvector.colnorm",
      start = 0, end = 0, window = 0
    ), class = "dynet_prestige_eigen_undefined"
  )
  expect_true(all(is.na(as.data.frame(dropped_value)$value)))
})

test_that("defective geometric-one column-normalized rays are accepted", {
  defective_unique <- matrix(c(
    1, 0, 0,
    1, 1, 0,
    0, 1, 0
  ), 3L, 3L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(defective_unique,
                    definition = "eigenvector.colnorm"),
    c(1, 0, 0), tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(defective_unique, TRUE,
                    definition = "eigenvector.colnorm"),
    c(1, 0, 0), tolerance = 1e-14
  )
})

test_that("column-normalized zero-radius and tied rays are undefined", {
  cases <- list(
    zero = matrix(0, 3L, 3L),
    arc = matrix(c(0, 1, 0, 0), 2L, 2L, byrow = TRUE),
    chain = matrix(c(0, 1, 0, 0, 0, 1, 0, 0, 0), 3L, 3L, byrow = TRUE)
  )
  lapply(cases, function(x) {
    expect_warning(
      value <- .eigen_prestige(x, definition = "eigenvector.colnorm"),
      class = "dynet_prestige_eigen_undefined"
    )
    expect_true(all(is.na(value)))
    expect_identical(attr(value, "prestige_diagnostic")$reason,
                     "zero_spectral_radius")
  })
  expect_warning(
    tied <- .eigen_prestige(diag(2), definition = "eigenvector.colnorm"),
    class = "dynet_prestige_eigen_undefined"
  )
  expect_true(all(is.na(tied)))
  expect_identical(attr(tied, "prestige_diagnostic")$reason,
                   "nonunique_perron_eigenspace")

  expect_warning(
    singleton <- .eigen_prestige(
      matrix(0, 1L, 1L), definition = "eigenvector.colnorm"
    ), class = "dynet_prestige_eigen_undefined"
  )
  expect_true(is.na(singleton))
  expect_identical(
    .eigen_prestige(matrix(1, 1L, 1L),
                    definition = "eigenvector.colnorm"),
    1
  )
})

test_that("public column-normalized eigen prestige is binary and mode invariant", {
  spells <- data.frame(
    from = c("A", "A", "A", "C"),
    to = c("A", "A", "B", "A"), time = 0,
    weight = c(9, -4, 100, 7)
  )
  dn <- quiet_dynet(spells, weight = "weight", loops = TRUE)
  expected <- c(A = 1 / sqrt(5), B = 2 / sqrt(5), C = 0)
  actual <- colnorm_eigen_vector(dn, start = 0, end = 0, window = 0)
  expect_equal(actual, expected, tolerance = 1e-14)
  expect_equal(
    colnorm_eigen_vector(
      dn, mode = "out", start = 0, end = 0, window = 0
    ), expected, tolerance = 1e-14
  )
  mixed <- as.data.frame(dyn_centrality(
    dn, measure = c("strength", "prestige"),
    prestige = "eigenvector.colnorm", start = 0, end = 0, window = 0
  ))
  prestige_rows <- subset(mixed, measure == "prestige")
  expect_equal(stats::setNames(prestige_rows$value, prestige_rows$node),
               expected, tolerance = 1e-14)
})

test_that("session union precedes column normalization", {
  spells <- data.frame(
    from = c("A", "A", "C"), to = c("A", "B", "A"), time = 0,
    session = c("s1", "s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session", loops = TRUE)
  expect_equal(
    colnorm_eigen_vector(
      dn, sessions = "bounded", start = 0, end = 0, window = 0
    ), c(A = 1 / sqrt(5), B = 2 / sqrt(5), C = 0), tolerance = 1e-14
  )
  expect_equal(
    colnorm_eigen_vector(
      dn, TRUE, sessions = "collapse", start = 0, end = 0, window = 0
    ), c(A = 1 / 3, B = 2 / 3, C = 0), tolerance = 1e-14
  )

  expect_warning(
    separate <- dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.colnorm",
      sessions = "separate", start = 0, end = 0, window = 0
    ), class = "dynet_prestige_eigen_undefined"
  )
  separate_df <- as.data.frame(separate)
  s1 <- subset(separate_df, session == "s1")
  s2 <- subset(separate_df, session == "s2")
  expect_equal(stats::setNames(s1$value, s1$node),
               c(A = 1 / sqrt(2), B = 1 / sqrt(2), C = 0),
               tolerance = 1e-14)
  expect_true(all(is.na(s2$value)))
  diagnostics <- attr(separate, "prestige_diagnostics")
  expect_identical(diagnostics$session, "s2")

  expect_warning(
    separate_scaled <- dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.colnorm",
      rescale = TRUE, sessions = "separate",
      start = 0, end = 0, window = 0
    ), class = "dynet_prestige_eigen_undefined"
  )
  scaled_s1 <- subset(as.data.frame(separate_scaled), session == "s1")
  expect_equal(stats::setNames(scaled_s1$value, scaled_s1$node),
               c(A = 1 / 2, B = 1 / 2, C = 0), tolerance = 1e-14)
})

test_that("defined separate sessions use independent spectral scales", {
  spells <- data.frame(
    from = c("A", "A", "C", "A", "B", "C"),
    to = c("A", "B", "A", "B", "C", "A"), time = 0,
    session = rep(c("s1", "s2"), each = 3L)
  )
  dn <- quiet_dynet(spells, session = "session", loops = TRUE)
  raw <- colnorm_eigen_frame(
    dn, sessions = "separate", start = 0, end = 0, window = 0
  )
  scaled <- colnorm_eigen_frame(
    dn, TRUE, sessions = "separate", start = 0, end = 0, window = 0
  )
  raw_s1 <- subset(raw, session == "s1")
  raw_s2 <- subset(raw, session == "s2")
  scaled_s1 <- subset(scaled, session == "s1")
  scaled_s2 <- subset(scaled, session == "s2")
  expect_equal(stats::setNames(raw_s1$value, raw_s1$node),
               c(A = 1 / sqrt(5), B = 2 / sqrt(5), C = 0),
               tolerance = 1e-14)
  expect_equal(stats::setNames(raw_s2$value, raw_s2$node),
               c(A = 1 / sqrt(3), B = 1 / sqrt(3), C = 1 / sqrt(3)),
               tolerance = 1e-14)
  expect_equal(stats::setNames(scaled_s1$value, scaled_s1$node),
               c(A = 1 / 3, B = 2 / 3, C = 0), tolerance = 1e-14)
  expect_equal(stats::setNames(scaled_s2$value, scaled_s2$node),
               c(A = 1 / 3, B = 1 / 3, C = 1 / 3), tolerance = 1e-14)
  expect_equal(as.numeric(tapply(raw$value^2, raw$session, sum)), c(1, 1),
               tolerance = 1e-14)
  expect_equal(as.numeric(tapply(scaled$value, scaled$session, sum)), c(1, 1),
               tolerance = 1e-14)
})

test_that("snapshot boundaries precede column normalization", {
  spells <- data.frame(
    from = c("A", "C", "A"), to = c("B", "A", "A"),
    start = c(0, 2, 2), end = c(2, 4, 2)
  )
  dn <- quiet_dynet(spells, loops = TRUE)
  expect_equal(
    colnorm_eigen_vector(dn, start = 2, end = 2, window = 0),
    c(A = 1, B = 0, C = 0), tolerance = 1e-14
  )
  expect_warning(
    half_open <- dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.colnorm",
      start = 1, end = 1, window = 1
    ), class = "dynet_prestige_eigen_undefined"
  )
  expect_true(all(is.na(as.data.frame(half_open)$value)))
  expect_equal(
    colnorm_eigen_vector(dn, start = 0, end = 0, window = 4),
    c(A = 1 / sqrt(5), B = 2 / sqrt(5), C = 0), tolerance = 1e-14
  )

  expect_warning(
    several <- dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.colnorm",
      start = 1, end = 2, step = 1, window = 1
    ), class = "dynet_prestige_eigen_undefined"
  )
  several_df <- as.data.frame(several)
  expect_identical(several_df$time, rep(c(1, 2), each = 3L))
  expect_true(all(is.na(subset(several_df, time == 1)$value)))
  final <- subset(several_df, time == 2)
  expect_equal(stats::setNames(final$value, final$node),
               c(A = 1, B = 0, C = 0), tolerance = 1e-14)
  diagnostics <- attr(several, "prestige_diagnostics")
  expect_identical(diagnostics$time, 1)
  expect_identical(diagnostics$reason, "zero_spectral_radius")
})

test_that("column-normalized eigen prestige publishes transform and solver", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "A"), time = 0
  ))
  raw <- dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector.colnorm"
  )
  expect_identical(attr(raw, "definition"), "eigenvector.colnorm")
  expect_identical(attr(raw, "direction"), "incoming")
  expect_identical(attr(raw, "matrix_transform"),
                   "transpose_column_stochastic_binary_adjacency")
  expect_identical(attr(raw, "column_denominator"),
                   "distinct_incoming_binary_dyads")
  expect_identical(attr(raw, "zero_columns"), "all_zero")
  expect_identical(attr(raw, "uniqueness"), "geometric_multiplicity_one")
  expect_identical(attr(raw, "normalization"), "l2_unit")
  expect_identical(attr(raw, "unit"),
                   "l2_incoming_column_stochastic_perron_weight")
  expect_identical(attr(raw, "loops"),
                   "retained_once_before_column_normalization")
  expect_identical(attr(raw, "undefined"), "NA")

  scaled <- dyn_centrality(
    dn, measure = c("degree", "prestige"),
    prestige = "eigenvector.colnorm", rescale = TRUE
  )
  metadata <- attr(scaled, "measure_metadata")$prestige
  expect_identical(metadata$normalization, "sum_to_one")
  expect_identical(metadata$unit,
                   "share_of_incoming_column_stochastic_perron_weight")
})

test_that("column-normalized eigen prestige obeys coordinates and scope", {
  spells <- data.frame(
    from = c("A", "A", "C"), to = c("A", "B", "A"),
    start = c(0, 0, 1), end = c(3, 2, 3)
  )
  value_at <- function(x, at, window) {
    colnorm_eigen_vector(quiet_dynet(x, loops = TRUE),
                         start = at, end = at, window = window)
  }
  reference <- value_at(spells, 1, 1)
  expect_equal(value_at(spells[3:1, ], 1, 1), reference, tolerance = 1e-14)
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
    undirected, measure = "prestige", prestige = "eigenvector.colnorm"
  ), class = "dynet_needs_directed")
  expect_error(dyn_centrality(
    quiet_dynet(data.frame(from = "A", to = "B", time = 0)),
    measure = "prestige", prestige = "eigenvector.colnorm",
    scope = "temporal"
  ), class = "dynet_unknown_measure")
})
