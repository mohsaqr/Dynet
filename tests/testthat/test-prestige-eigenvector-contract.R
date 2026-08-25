eigen_prestige_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector",
    rescale = rescale, ...
  ))
}

eigen_prestige_vector <- function(dn, rescale = FALSE, ...) {
  df <- eigen_prestige_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("incoming Perron prestige has the literal plastic-constant ray", {
  b <- matrix(c(
    0, 1, 1,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  rho <- stats::uniroot(function(x) x^3 - x - 1, c(1, 2), tol = 1e-15)$root
  incoming <- c(1 / rho, 1 / rho^2, 1)
  expected_raw <- incoming / sqrt(sum(incoming^2))
  expected_scaled <- incoming / sum(incoming)
  expect_equal(.eigen_prestige(b), expected_raw, tolerance = 1e-12)
  expect_equal(.eigen_prestige(b, TRUE), expected_scaled, tolerance = 1e-12)
  expect_equal(sum(.eigen_prestige(b)^2), 1, tolerance = 1e-14)
  expect_equal(sum(.eigen_prestige(b, TRUE)), 1, tolerance = 1e-14)
  expect_lt(expected_raw[1], expected_raw[3])
})

test_that("periodic negative and complex spectral peers do not defeat Perron", {
  reciprocal <- matrix(c(0, 1, 1, 0), 2L, 2L, byrow = TRUE)
  expect_equal(.eigen_prestige(reciprocal), rep(1 / sqrt(2), 2),
               tolerance = 1e-14)
  expect_equal(.eigen_prestige(reciprocal, TRUE), c(1 / 2, 1 / 2),
               tolerance = 1e-14)

  cycle <- matrix(c(
    0, 1, 0,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  spectrum <- eigen(t(cycle))$values
  expect_equal(sort(Mod(spectrum)), rep(1, 3), tolerance = 1e-14)
  expect_true(any(abs(Im(spectrum)) > 0.5))
  expect_equal(.eigen_prestige(cycle), rep(1 / sqrt(3), 3),
               tolerance = 1e-14)
  expect_equal(.eigen_prestige(cycle, TRUE), rep(1 / 3, 3),
               tolerance = 1e-14)
})

test_that("retained loops alter the binary incoming Perron ray", {
  phi <- (1 + sqrt(5)) / 2
  looped <- matrix(c(0, 1, 1, 1), 2L, 2L, byrow = TRUE)
  ray <- c(1 / phi, 1)
  expect_equal(.eigen_prestige(looped), ray / sqrt(sum(ray^2)),
               tolerance = 1e-14)
  expect_equal(.eigen_prestige(looped, TRUE), ray / sum(ray),
               tolerance = 1e-14)
  loopless <- looped
  diag(loopless) <- 0
  expect_equal(.eigen_prestige(loopless), rep(1 / sqrt(2), 2),
               tolerance = 1e-14)

  spells <- data.frame(
    from = c("A", "B", "B"), to = c("B", "A", "B"), time = 0
  )
  retained <- quiet_dynet(spells, loops = TRUE)
  dropped <- quiet_dynet(spells, loops = FALSE)
  expect_equal(
    eigen_prestige_vector(retained, start = 0, end = 0, window = 0),
    stats::setNames(ray / sqrt(sum(ray^2)), c("A", "B")), tolerance = 1e-14
  )
  expect_equal(
    eigen_prestige_vector(dropped, start = 0, end = 0, window = 0),
    c(A = 1 / sqrt(2), B = 1 / sqrt(2)), tolerance = 1e-14
  )
})

test_that("reducible and defective matrices follow ray uniqueness", {
  reducible <- matrix(c(
    1, 1, 0,
    0, 0, 0,
    0, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_equal(.eigen_prestige(reducible), c(1 / sqrt(2), 1 / sqrt(2), 0),
               tolerance = 1e-14)
  expect_equal(.eigen_prestige(reducible, TRUE), c(1 / 2, 1 / 2, 0),
               tolerance = 1e-14)

  defective_unique <- matrix(c(1, 1, 0, 1), 2L, 2L, byrow = TRUE)
  expect_equal(.eigen_prestige(defective_unique), c(0, 1), tolerance = 1e-14)
  expect_equal(.eigen_prestige(defective_unique, TRUE), c(0, 1),
               tolerance = 1e-14)
})

test_that("zero radius and nonunique Perron eigenspaces are undefined NA", {
  zero <- matrix(0, 3L, 3L)
  expect_warning(value <- .eigen_prestige(zero),
                 class = "dynet_prestige_eigen_undefined")
  expect_true(all(is.na(value)))
  expect_identical(attr(value, "prestige_diagnostic")$reason,
                   "zero_spectral_radius")
  expect_warning(value_scaled <- .eigen_prestige(zero, TRUE),
                 class = "dynet_prestige_eigen_undefined")
  expect_true(all(is.na(value_scaled)))

  dag <- matrix(c(0, 1, 0, 0), 2L, 2L, byrow = TRUE)
  expect_warning(dag_value <- .eigen_prestige(dag),
                 class = "dynet_prestige_eigen_undefined")
  expect_true(all(is.na(dag_value)))

  tied <- matrix(0, 4L, 4L)
  tied[1, 2] <- tied[2, 1] <- tied[3, 4] <- tied[4, 3] <- 1
  expect_warning(tied_value <- .eigen_prestige(tied),
                 class = "dynet_prestige_eigen_undefined")
  expect_true(all(is.na(tied_value)))
  expect_identical(attr(tied_value, "prestige_diagnostic")$reason,
                   "nonunique_perron_eigenspace")
  expect_identical(attr(tied_value, "prestige_diagnostic")$eigenspace_dimension,
                   2L)
})

test_that("loopless and retained-loop singletons have distinct status", {
  expect_warning(loopless <- .eigen_prestige(matrix(0, 1L, 1L)),
                 class = "dynet_prestige_eigen_undefined")
  expect_true(is.na(loopless))
  expect_identical(.eigen_prestige(matrix(1, 1L, 1L)), 1)
  expect_identical(.eigen_prestige(matrix(1, 1L, 1L), TRUE), 1)
})

test_that("public binary prestige is isolated from values and strength", {
  spells <- data.frame(
    from = c("A", "A", "A", "A", "B", "C"),
    to = c("B", "B", "B", "C", "C", "A"), time = 0,
    weight = c(9, -9, 0, 100, -7, 4)
  )
  dn <- quiet_dynet(spells, weight = "weight")
  alone <- eigen_prestige_vector(dn, start = 0, end = 0, window = 0)
  mixed <- as.data.frame(dyn_centrality(
    dn, measure = c("strength", "prestige"), prestige = "eigenvector",
    start = 0, end = 0, window = 0
  ))
  actual <- subset(mixed, measure == "prestige")
  expect_identical(stats::setNames(actual$value, actual$node), alone)
  expect_equal(sum(alone^2), 1, tolerance = 1e-14)
  mode_out <- eigen_prestige_vector(
    dn, mode = "out", start = 0, end = 0, window = 0
  )
  expect_identical(mode_out, alone)
})

test_that("session union precedes the spectrum", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "A"), time = 0,
    session = c("s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  expect_equal(
    eigen_prestige_vector(
      dn, sessions = "bounded", start = 0, end = 0, window = 0
    ),
    c(A = 1 / sqrt(2), B = 1 / sqrt(2)), tolerance = 1e-14
  )
  expect_equal(
    eigen_prestige_vector(
      dn, TRUE, sessions = "collapse", start = 0, end = 0, window = 0
    ),
    c(A = 1 / 2, B = 1 / 2), tolerance = 1e-14
  )
  expect_warning(separate <- dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector",
    sessions = "separate", start = 0, end = 0, window = 0
  ), class = "dynet_prestige_eigen_undefined")
  expect_true(all(is.na(as.data.frame(separate)$value)))
  expect_equal(nrow(attr(separate, "prestige_diagnostics")), 2L)

  defined_spells <- data.frame(
    from = c("A", "B", "B", "C", "C"),
    to = c("B", "A", "C", "B", "C"), time = 0,
    session = c("s1", "s1", "s2", "s2", "s2")
  )
  defined <- quiet_dynet(defined_spells, session = "session", loops = TRUE)
  defined_raw <- eigen_prestige_frame(
    defined, sessions = "separate", start = 0, end = 0, window = 0
  )
  defined_scaled <- eigen_prestige_frame(
    defined, TRUE, sessions = "separate", start = 0, end = 0, window = 0
  )
  raw_norms <- tapply(defined_raw$value^2, defined_raw$session, sum)
  scaled_sums <- tapply(defined_scaled$value, defined_scaled$session, sum)
  expect_equal(as.numeric(raw_norms), c(1, 1), tolerance = 1e-14)
  expect_equal(as.numeric(scaled_sums), c(1, 1), tolerance = 1e-14)
  expect_false(isTRUE(all.equal(
    defined_raw$value[defined_raw$session == "s1"],
    defined_raw$value[defined_raw$session == "s2"]
  )))
})

test_that("snapshot activity boundaries are resolved before eigensolving", {
  spells <- data.frame(
    from = c("A", "B", "A"), to = c("B", "A", "A"),
    start = c(0, 2, 2), end = c(2, 4, 2)
  )
  dn <- quiet_dynet(spells, loops = TRUE)
  expect_equal(
    eigen_prestige_vector(dn, start = 2, end = 2, window = 0),
    c(A = 1, B = 0), tolerance = 1e-14
  )
  expect_warning(half_open <- dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector",
    start = 1, end = 1, window = 1
  ), class = "dynet_prestige_eigen_undefined")
  expect_true(all(is.na(as.data.frame(half_open)$value)))
  phi <- (1 + sqrt(5)) / 2
  union_ray <- c(phi, 1)
  expect_equal(
    eigen_prestige_vector(dn, start = 0, end = 0, window = 4),
    stats::setNames(union_ray / sqrt(sum(union_ray^2)), c("A", "B")),
    tolerance = 1e-14
  )
})

test_that("public undefined blocks warn once and carry diagnostics", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 0))
  expect_warning(result <- dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector",
    start = 0, end = 1, step = 1, window = 0
  ), class = "dynet_prestige_eigen_undefined")
  expect_true(all(is.na(as.data.frame(result)$value)))
  diagnostics <- attr(result, "prestige_diagnostics")
  expect_identical(diagnostics$status, rep("undefined", 2L))
  expect_identical(diagnostics$reason,
                   rep("zero_spectral_radius", 2L))
})

test_that("eigenvector prestige publishes its solver and scale", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "A"), time = 0
  ))
  raw <- dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector"
  )
  expect_identical(attr(raw, "definition"), "eigenvector")
  expect_identical(attr(raw, "direction"), "incoming")
  expect_identical(attr(raw, "matrix_transform"),
                   "transpose_binary_adjacency")
  expect_identical(attr(raw, "eigenvalue"), "positive_perron_root")
  expect_identical(attr(raw, "spectral_requirement"),
                   "positive_radius_unique_perron_eigenspace")
  expect_identical(attr(raw, "uniqueness"), "geometric_multiplicity_one")
  expect_identical(attr(raw, "sign"), "nonnegative")
  expect_identical(attr(raw, "normalization"), "l2_unit")
  expect_identical(attr(raw, "unit"), "l2_incoming_perron_weight")
  expect_identical(attr(raw, "solver"), "base_eigen_svd_nullity")
  expect_identical(attr(raw, "solver_tolerance"), 1e-10)
  expect_identical(attr(raw, "error_norm"), "max_absolute_eigen_residual")
  expect_identical(attr(raw, "undefined"), "NA")
  expect_identical(attr(raw, "loops"), "retained_once_before_eigensolve")

  scaled <- dyn_centrality(
    dn, measure = c("degree", "prestige"), prestige = "eigenvector",
    rescale = TRUE
  )
  metadata <- attr(scaled, "measure_metadata")$prestige
  expect_identical(metadata$normalization, "sum_to_one")
  expect_identical(metadata$unit, "share_of_incoming_perron_weight")
})

test_that("eigenvector prestige obeys coordinates and rejects wrong scope", {
  spells <- data.frame(
    from = c("A", "A", "B", "C"), to = c("B", "C", "C", "A"),
    start = c(0, 0, 1, 0), end = c(3, 2, 3, 3)
  )
  value_at <- function(x, at, window) {
    eigen_prestige_vector(quiet_dynet(x), start = at, end = at,
                          window = window)
  }
  reference <- value_at(spells, 1, 1)
  expect_equal(value_at(spells[4:1, ], 1, 1), reference, tolerance = 1e-14)
  expect_equal(value_at(
    transform(spells, start = start + 11, end = end + 11), 12, 1
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
    undirected, measure = "prestige", prestige = "eigenvector"
  ), class = "dynet_needs_directed")
  expect_error(dyn_centrality(
    quiet_dynet(data.frame(from = "A", to = "B", time = 0)),
    measure = "prestige", prestige = "eigenvector", scope = "temporal"
  ), class = "dynet_unknown_measure")
})
