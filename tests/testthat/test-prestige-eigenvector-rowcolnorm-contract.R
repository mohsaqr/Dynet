rowcolnorm_eigen_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector.rowcolnorm",
    rescale = rescale, ...
  ))
}

rowcolnorm_eigen_vector <- function(dn, rescale = FALSE, ...) {
  df <- rowcolnorm_eigen_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("true row-column balancing precedes exact uniform Perron scores", {
  phi <- (1 + sqrt(5)) / 2
  b <- matrix(c(
    1, 1, 0,
    1, 1, 1,
    0, 1, 1
  ), 3L, 3L, byrow = TRUE)
  expected_transform <- matrix(c(
    1 / phi, 1 / phi^2, 0,
    1 / phi^2, 1 / phi^3, 1 / phi^2,
    0, 1 / phi^2, 1 / phi
  ), 3L, 3L, byrow = TRUE)
  balanced <- .rowcol_balance(b)
  expect_identical(balanced$status, "ok")
  expect_gt(balanced$iterations, 1L)
  expect_lte(balanced$residual, 1e-12)
  expect_equal(balanced$matrix, expected_transform, tolerance = 2e-12)
  expect_equal(rowSums(balanced$matrix), rep(1, 3), tolerance = 1e-12)
  expect_equal(colSums(balanced$matrix), rep(1, 3), tolerance = 1e-12)
  expect_equal(
    .eigen_prestige(b, definition = "eigenvector.rowcolnorm"),
    rep(1 / sqrt(3), 3), tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(b, TRUE, definition = "eigenvector.rowcolnorm"),
    rep(1 / 3, 3), tolerance = 1e-14
  )

  one_sweep <- .rowcol_sweep(b)
  expect_equal(rowSums(one_sweep), c(39 / 40, 21 / 20, 39 / 40))
  expect_equal(max(abs(rowSums(one_sweep) - 1)), 1 / 20)
})

test_that("balanced eigen prestige leaves RNG state untouched", {
  old_seed <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv(), inherits = FALSE)
  } else {
    NULL
  }
  on.exit({
    if (is.null(old_seed)) {
      if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
        rm(".Random.seed", envir = globalenv())
      }
    } else {
      assign(".Random.seed", old_seed, envir = globalenv())
    }
  }, add = TRUE)
  b <- matrix(c(
    1, 1, 0,
    1, 1, 1,
    0, 1, 1
  ), 3L, 3L, byrow = TRUE)
  set.seed(20260825L)
  before_direct <- .Random.seed
  invisible(.eigen_prestige(b, definition = "eigenvector.rowcolnorm"))
  expect_identical(.Random.seed, before_direct)

  dn <- quiet_dynet(data.frame(
    from = c("A", "A", "B", "B", "B", "C", "C"),
    to = c("A", "B", "A", "B", "C", "B", "C"), time = 0
  ), loops = TRUE)
  before_public <- .Random.seed
  invisible(dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector.rowcolnorm",
    start = 0, end = 0, window = 0
  ))
  expect_identical(.Random.seed, before_public)
})

test_that("periodic balanced supports retain their unique real Perron ray", {
  reciprocal <- matrix(c(0, 1, 1, 0), 2L, 2L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(reciprocal,
                    definition = "eigenvector.rowcolnorm"),
    rep(1 / sqrt(2), 2), tolerance = 1e-14
  )
  cycle <- matrix(c(
    0, 1, 0,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(cycle, definition = "eigenvector.rowcolnorm"),
    rep(1 / sqrt(3), 3), tolerance = 1e-14
  )
  expect_equal(
    .eigen_prestige(cycle, TRUE,
                    definition = "eigenvector.rowcolnorm"),
    rep(1 / 3, 3), tolerance = 1e-14
  )
})

test_that("total support does not imply a unique balanced Perron ray", {
  for (b in list(diag(2), diag(c(1, 1, 1)))) {
    expect_identical(.rowcol_balance(b)$status, "ok")
    expect_warning(
      value <- .eigen_prestige(
        b, definition = "eigenvector.rowcolnorm"
      ), class = "dynet_prestige_eigen_undefined"
    )
    expect_true(all(is.na(value)))
    diagnostic <- attr(value, "prestige_diagnostic")
    expect_identical(diagnostic$stage, "spectrum")
    expect_identical(diagnostic$status, "undefined")
    expect_identical(diagnostic$reason, "nonunique_perron_eigenspace")
    expect_identical(diagnostic$balance_status, "ok")
    expect_lte(diagnostic$balance_residual, 1e-12)
  }

  block <- matrix(c(
    1, 1, 0,
    1, 1, 0,
    0, 0, 1
  ), 3L, 3L, byrow = TRUE)
  expect_identical(.rowcol_balance(block)$status, "ok")
  expect_warning(
    value <- .eigen_prestige(block,
                             definition = "eigenvector.rowcolnorm"),
    class = "dynet_prestige_eigen_undefined"
  )
  expect_true(all(is.na(value)))
  expect_identical(attr(value, "prestige_diagnostic")$eigenspace_dimension,
                   2L)
})

test_that("support failure is terminal before spectrum", {
  zero <- matrix(0, 3L, 3L)
  hall <- matrix(c(
    0, 0, 1,
    0, 0, 1,
    1, 1, 0
  ), 3L, 3L, byrow = TRUE)
  unsupported <- matrix(c(
    0, 1, 1,
    0, 0, 1,
    1, 0, 0
  ), 3L, 3L, byrow = TRUE)
  cases <- list(
    zero_margin = zero,
    no_perfect_matching = hall,
    not_total_support = unsupported
  )
  lapply(names(cases), function(reason) {
    expect_warning(
      value <- .eigen_prestige(
        cases[[reason]], definition = "eigenvector.rowcolnorm"
      ), class = "dynet_prestige_infeasible"
    )
    expect_true(all(is.na(value)))
    diagnostic <- attr(value, "prestige_diagnostic")
    expect_identical(diagnostic$stage, "support")
    expect_identical(diagnostic$status, "infeasible")
    expect_identical(diagnostic$reason, reason)
    expect_true(is.na(diagnostic$spectral_radius))
  })
})

test_that("balance nonconvergence is terminal before spectrum", {
  b <- matrix(c(
    1, 1, 0,
    1, 1, 1,
    0, 1, 1
  ), 3L, 3L, byrow = TRUE)
  expect_warning(
    value <- .eigen_prestige(
      b, definition = "eigenvector.rowcolnorm",
      balance_tol = 1e-12, balance_max_iter = 1L
    ), class = "dynet_prestige_nonconvergence"
  )
  expect_true(all(is.na(value)))
  diagnostic <- attr(value, "prestige_diagnostic")
  expect_identical(diagnostic$stage, "balance")
  expect_identical(diagnostic$status, "nonconverged")
  expect_identical(diagnostic$reason, "iteration_cap")
  expect_identical(diagnostic$balance_iterations, 1L)
  expect_equal(diagnostic$balance_residual, 1 / 20)
  expect_true(is.na(diagnostic$spectral_radius))
})

test_that("retained loops affect support before balancing", {
  reciprocal <- matrix(c(0, 1, 1, 0), 2L, 2L, byrow = TRUE)
  unsupported_loop <- matrix(c(1, 1, 1, 0), 2L, 2L, byrow = TRUE)
  expect_equal(
    .eigen_prestige(reciprocal,
                    definition = "eigenvector.rowcolnorm"),
    rep(1 / sqrt(2), 2), tolerance = 1e-14
  )
  expect_warning(
    looped <- .eigen_prestige(
      unsupported_loop, definition = "eigenvector.rowcolnorm"
    ), class = "dynet_prestige_infeasible"
  )
  expect_true(all(is.na(looped)))
  expect_identical(attr(looped, "prestige_diagnostic")$reason,
                   "not_total_support")

  expect_warning(
    loopless_singleton <- .eigen_prestige(
      matrix(0, 1L, 1L), definition = "eigenvector.rowcolnorm"
    ), class = "dynet_prestige_infeasible"
  )
  expect_true(is.na(loopless_singleton))
  expect_identical(
    .eigen_prestige(matrix(1, 1L, 1L),
                    definition = "eigenvector.rowcolnorm"),
    1
  )
})

test_that("public balanced eigen prestige ignores weights and mode", {
  spells <- data.frame(
    from = c("A", "A", "B", "C"),
    to = c("B", "B", "C", "A"), time = 0,
    weight = c(9, -4, 100, 3)
  )
  dn <- quiet_dynet(spells, weight = "weight")
  expected <- c(A = 1 / sqrt(3), B = 1 / sqrt(3), C = 1 / sqrt(3))
  actual <- rowcolnorm_eigen_vector(dn, start = 0, end = 0, window = 0)
  expect_equal(actual, expected, tolerance = 1e-14)
  expect_equal(
    rowcolnorm_eigen_vector(
      dn, mode = "out", start = 0, end = 0, window = 0
    ), expected, tolerance = 1e-14
  )
  mixed <- as.data.frame(dyn_centrality(
    dn, measure = c("strength", "prestige"),
    prestige = "eigenvector.rowcolnorm", start = 0, end = 0, window = 0
  ))
  prestige_rows <- subset(mixed, measure == "prestige")
  expect_equal(stats::setNames(prestige_rows$value, prestige_rows$node),
               expected, tolerance = 1e-14)
})

test_that("session union precedes support balancing and spectrum", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "A"), time = 0,
    session = c("s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  expect_equal(
    rowcolnorm_eigen_vector(
      dn, sessions = "bounded", start = 0, end = 0, window = 0
    ), c(A = 1 / sqrt(2), B = 1 / sqrt(2)), tolerance = 1e-14
  )
  expect_equal(
    rowcolnorm_eigen_vector(
      dn, TRUE, sessions = "collapse", start = 0, end = 0, window = 0
    ), c(A = 1 / 2, B = 1 / 2), tolerance = 1e-14
  )
  expect_warning(
    separate <- dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.rowcolnorm",
      sessions = "separate", start = 0, end = 0, window = 0
    ), class = "dynet_prestige_infeasible"
  )
  expect_true(all(is.na(as.data.frame(separate)$value)))
  expect_identical(attr(separate, "prestige_diagnostics")$stage,
                   rep("support", 2L))

  loops <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("A", "B"), time = 0,
    session = c("s1", "s2")
  ), session = "session", loops = TRUE)
  expect_warning(
    union_identity <- dyn_centrality(
      loops, measure = "prestige", prestige = "eigenvector.rowcolnorm",
      sessions = "bounded", start = 0, end = 0, window = 0
    ), class = "dynet_prestige_eigen_undefined"
  )
  expect_true(all(is.na(as.data.frame(union_identity)$value)))
  expect_identical(attr(union_identity, "prestige_diagnostics")$stage,
                   "spectrum")
})

test_that("defined separate sessions each receive their own exact scale", {
  spells <- data.frame(
    from = c("A", "B", "C", "A", "A", "B", "B", "C", "C"),
    to = c("B", "C", "A", "B", "C", "A", "C", "A", "B"), time = 0,
    session = c(rep("s1", 3L), rep("s2", 6L))
  )
  dn <- quiet_dynet(spells, session = "session")
  raw <- rowcolnorm_eigen_frame(
    dn, sessions = "separate", start = 0, end = 0, window = 0
  )
  scaled <- rowcolnorm_eigen_frame(
    dn, TRUE, sessions = "separate", start = 0, end = 0, window = 0
  )
  expect_equal(raw$value, rep(1 / sqrt(3), 6), tolerance = 1e-14)
  expect_equal(scaled$value, rep(1 / 3, 6), tolerance = 1e-14)
  expect_equal(as.numeric(tapply(raw$value^2, raw$session, sum)), c(1, 1),
               tolerance = 1e-14)
  expect_equal(as.numeric(tapply(scaled$value, scaled$session, sum)), c(1, 1),
               tolerance = 1e-14)
})

test_that("final-bin point changes support and public status", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "A"),
    start = c(0, 2), end = c(2, 2)
  )
  dn <- quiet_dynet(spells)
  warning_classes <- character()
  several <- withCallingHandlers(
    dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.rowcolnorm",
      start = 0, step = 1, window = 1
    ), warning = function(w) {
      warning_classes <<- c(warning_classes, class(w)[1L])
      invokeRestart("muffleWarning")
    }
  )
  several_df <- as.data.frame(several)
  expect_identical(several_df$time, rep(c(0, 1), each = 2L))
  expect_true(all(is.na(subset(several_df, time == 0)$value)))
  final <- subset(several_df, time == 1)
  expect_equal(stats::setNames(final$value, final$node),
               c(A = 1 / sqrt(2), B = 1 / sqrt(2)), tolerance = 1e-14)
  expect_identical(warning_classes, "dynet_prestige_infeasible")
  diagnostics <- attr(several, "prestige_diagnostics")
  expect_identical(diagnostics$time, 0)
  expect_identical(diagnostics$stage, "support")

  expect_warning(
    point <- dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.rowcolnorm",
      start = 2, end = 2, window = 0
    ), class = "dynet_prestige_infeasible"
  )
  expect_true(all(is.na(as.data.frame(point)$value)))
  expect_equal(
    rowcolnorm_eigen_vector(dn, start = 0, end = 0, window = 3),
    c(A = 1 / sqrt(2), B = 1 / sqrt(2)), tolerance = 1e-14
  )
})

test_that("mixed terminal stages aggregate distinct warning classes", {
  spells <- data.frame(
    from = c("A", "A", "B", "A", "B"),
    to = c("B", "A", "B", "B", "A"),
    time = c(0, 1, 1, 2, 2)
  )
  dn <- quiet_dynet(spells, loops = TRUE)
  warning_classes <- character()
  result <- withCallingHandlers(
    dyn_centrality(
      dn, measure = "prestige", prestige = "eigenvector.rowcolnorm",
      start = 0, end = 2, step = 1, window = 0
    ), warning = function(w) {
      warning_classes <<- c(warning_classes, class(w)[1L])
      invokeRestart("muffleWarning")
    }
  )
  expect_identical(warning_classes,
                   c("dynet_prestige_infeasible",
                     "dynet_prestige_eigen_undefined"))
  result_df <- as.data.frame(result)
  expect_true(all(is.na(subset(result_df, time %in% c(0, 1))$value)))
  time_two <- subset(result_df, time == 2)
  expect_equal(stats::setNames(time_two$value, time_two$node),
               c(A = 1 / sqrt(2), B = 1 / sqrt(2)), tolerance = 1e-14)
  diagnostics <- attr(result, "prestige_diagnostics")
  expect_identical(diagnostics$time, c(0, 1))
  expect_identical(diagnostics$stage, c("support", "spectrum"))
  expect_identical(diagnostics$status, c("infeasible", "undefined"))
})

test_that("balanced eigen prestige publishes both certification stages", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "A"), time = 0
  ))
  raw <- dyn_centrality(
    dn, measure = "prestige", prestige = "eigenvector.rowcolnorm"
  )
  expect_identical(attr(raw, "definition"), "eigenvector.rowcolnorm")
  expect_identical(attr(raw, "direction"), "incoming")
  expect_identical(attr(raw, "matrix_transform"),
                   "transpose_sinkhorn_knopp_balanced_binary_adjacency")
  expect_identical(attr(raw, "pipeline_order"),
                   "binary_union_total_support_balance_transpose_perron")
  expect_identical(attr(raw, "support_requirement"),
                   "total_support_full_vertex_matrix")
  expect_identical(attr(raw, "balance_solver_tolerance"), 1e-12)
  expect_identical(attr(raw, "balance_maximum_iterations"), 10000L)
  expect_identical(attr(raw, "balance_error_norm"),
                   "max_absolute_margin")
  expect_identical(attr(raw, "uniqueness"), "geometric_multiplicity_one")
  expect_identical(attr(raw, "defined_values"), "uniform")
  expect_identical(attr(raw, "normalization"), "l2_unit")
  expect_identical(attr(raw, "unit"),
                   "l2_incoming_doubly_stochastic_perron_weight")
  expect_identical(attr(raw, "loops"),
                   "retained_once_before_support_and_balancing")
  expect_identical(attr(raw, "undefined"), "NA")

  scaled <- dyn_centrality(
    dn, measure = c("degree", "prestige"),
    prestige = "eigenvector.rowcolnorm", rescale = TRUE
  )
  metadata <- attr(scaled, "measure_metadata")$prestige
  expect_identical(metadata$normalization, "sum_to_one")
  expect_identical(metadata$unit,
                   "share_of_incoming_doubly_stochastic_perron_weight")
})

test_that("balanced eigen prestige obeys coordinates and scope", {
  spells <- data.frame(
    from = c("A", "A", "B", "B", "B", "C", "C"),
    to = c("A", "B", "A", "B", "C", "B", "C"),
    start = c(0, 0, 0, 0, 1, 0, 0),
    end = c(3, 2, 3, 3, 3, 3, 3)
  )
  value_at <- function(x, at, window) {
    rowcolnorm_eigen_vector(quiet_dynet(x, loops = TRUE),
                            start = at, end = at, window = window)
  }
  reference <- value_at(spells, 1, 1)
  expect_equal(value_at(spells[7:1, ], 1, 1), reference, tolerance = 1e-14)
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
    undirected, measure = "prestige", prestige = "eigenvector.rowcolnorm"
  ), class = "dynet_needs_directed")
  expect_error(dyn_centrality(
    quiet_dynet(data.frame(from = "A", to = "B", time = 0)),
    measure = "prestige", prestige = "eigenvector.rowcolnorm",
    scope = "temporal"
  ), class = "dynet_unknown_measure")
})
