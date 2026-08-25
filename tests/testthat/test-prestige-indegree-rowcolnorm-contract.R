rowcol_prestige_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "indegree.rowcolnorm",
    rescale = rescale, ...
  ))
}

rowcol_prestige_vector <- function(dn, rescale = FALSE, ...) {
  df <- rowcol_prestige_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("total support is stronger than one perfect matching", {
  cycle <- matrix(c(0, 1, 1, 0), 2L, 2L, byrow = TRUE)
  triangular <- matrix(c(1, 1, 0, 1), 2L, 2L, byrow = TRUE)
  hall <- matrix(c(
    0, 0, 1,
    0, 0, 1,
    1, 1, 0
  ), 3L, 3L, byrow = TRUE)
  reducible <- matrix(c(
    1, 1, 0,
    1, 1, 0,
    0, 0, 1
  ), 3L, 3L, byrow = TRUE)

  expect_identical(.perfect_matching(cycle), c(2L, 1L))
  expect_true(.total_support(cycle)$ok)
  expect_false(.total_support(triangular)$ok)
  expect_identical(.total_support(triangular)$reason, "not_total_support")
  expect_false(.total_support(hall)$ok)
  expect_identical(.total_support(hall)$reason, "no_perfect_matching")
  expect_true(.total_support(reducible)$ok)
  expect_identical(.total_support(matrix(0, 2L, 2L))$reason, "zero_margin")
})

test_that("deterministic balancing reaches the exact golden-ratio matrix", {
  b <- matrix(c(
    1, 1, 0,
    1, 1, 1,
    0, 1, 1
  ), 3L, 3L, byrow = TRUE)
  phi <- (1 + sqrt(5)) / 2
  expected <- matrix(c(
    1 / phi, 1 / phi^2, 0,
    1 / phi^2, 1 / phi^3, 1 / phi^2,
    0, 1 / phi^2, 1 / phi
  ), 3L, 3L, byrow = TRUE)
  result <- .rowcol_balance(b)
  expect_identical(result$status, "ok")
  expect_gt(result$iterations, 1L)
  expect_lte(result$residual, 1e-12)
  expect_equal(result$matrix, expected, tolerance = 2e-12)
  expect_equal(rowSums(result$matrix), rep(1, 3), tolerance = 1e-12)
  expect_equal(colSums(result$matrix), rep(1, 3), tolerance = 1e-12)
  expect_identical(result$matrix == 0, b == 0)

  expected_one_pass <- matrix(c(
    3 / 5, 3 / 8, 0,
    2 / 5, 1 / 4, 2 / 5,
    0, 3 / 8, 3 / 5
  ), 3L, 3L, byrow = TRUE)
  expect_equal(.rowcol_sweep(b), expected_one_pass, tolerance = 1e-15)
  reverse_sweep <- b
  reverse_sweep <- t(t(reverse_sweep) / colSums(reverse_sweep))
  reverse_sweep <- reverse_sweep / rowSums(reverse_sweep)
  expect_gt(max(abs(reverse_sweep - expected_one_pass)), 0.01)

  one_pass <- .rowcol_balance(b, max_iter = 1L)
  expect_identical(one_pass$status, "nonconverged")
  expect_gt(one_pass$residual, 1e-12)
  expect_true(all(is.na(one_pass$matrix)))
  max_gate <- .rowcol_balance(b, tol = 0.03, max_iter = 1L)
  expect_identical(max_gate$status, "nonconverged")
  expect_gt(max_gate$residual, 0.03)

  set.seed(81L)
  rng_before <- .Random.seed
  first <- .rowcol_balance(b)
  expect_identical(.Random.seed, rng_before)
  set.seed(914L)
  second <- .rowcol_balance(b)
  expect_identical(first$matrix, second$matrix)
})

test_that("reducible total support is feasible and uniquely scaled", {
  b <- matrix(c(
    1, 1, 0,
    1, 1, 0,
    0, 0, 1
  ), 3L, 3L, byrow = TRUE)
  result <- .rowcol_balance(b)
  expect_identical(result$status, "ok")
  expect_identical(result$matrix, matrix(c(
    1 / 2, 1 / 2, 0,
    1 / 2, 1 / 2, 0,
    0, 0, 1
  ), 3L, 3L, byrow = TRUE))
})

test_that("row-column prestige is exactly uniform only after feasibility", {
  b <- matrix(c(
    1, 1, 0,
    1, 1, 1,
    0, 1, 1
  ), 3L, 3L, byrow = TRUE)
  expect_identical(
    .indegree_prestige(b, definition = "indegree.rowcolnorm"),
    c(1, 1, 1)
  )
  expect_identical(
    .indegree_prestige(b, TRUE, "indegree.rowcolnorm"),
    rep(1 / 3, 3)
  )

  triangular <- matrix(c(1, 1, 0, 1), 2L, 2L, byrow = TRUE)
  expect_true(all(is.na(
    .indegree_prestige(triangular, definition = "indegree.rowcolnorm")
  )))
  expect_warning(
    value <- .indegree_prestige(
      b, definition = "indegree.rowcolnorm", max_iter = 1L
    ),
    class = "dynet_prestige_nonconvergence"
  )
  expect_true(all(is.na(value)))
  expect_true(is.na(.indegree_prestige(
    matrix(0, 1L, 1L), definition = "indegree.rowcolnorm"
  )))
})

test_that("public feasible prestige is uniform and selector-distinct", {
  spells <- data.frame(
    from = c("A", "A", "B", "B", "B", "C", "C"),
    to = c("A", "B", "A", "B", "C", "B", "C"), time = 0
  )
  dn <- quiet_dynet(spells, loops = TRUE)
  raw <- rowcol_prestige_vector(dn, start = 0, end = 0, window = 0)
  scaled <- rowcol_prestige_vector(
    dn, TRUE, start = 0, end = 0, window = 0
  )
  expect_identical(raw, c(A = 1, B = 1, C = 1))
  expect_identical(scaled, c(A = 1 / 3, B = 1 / 3, C = 1 / 3))

  s01 <- as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "indegree",
    start = 0, end = 0, window = 0
  ))
  s02 <- as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "indegree.rownorm",
    start = 0, end = 0, window = 0
  ))
  expect_identical(s01$value, c(2, 3, 2))
  expect_equal(s02$value, c(5 / 6, 4 / 3, 5 / 6), tolerance = 1e-15)
})

test_that("structurally infeasible public blocks are warned and all NA", {
  chain <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"), time = 0
  ))
  expect_warning(
    result <- dyn_centrality(
      chain, measure = "prestige", prestige = "indegree.rowcolnorm",
      start = 0, end = 0, window = 0
    ),
    class = "dynet_prestige_infeasible"
  )
  expect_true(all(is.na(as.data.frame(result)$value)))
  diagnostic <- attr(result, "prestige_diagnostics")
  expect_identical(diagnostic$status, "infeasible")
  expect_identical(diagnostic$reason, "zero_margin")
})

test_that("loop policy precedes total-support feasibility", {
  looped <- quiet_dynet(
    data.frame(from = "Q", to = "Q", time = 0), loops = TRUE
  )
  expect_identical(
    rowcol_prestige_vector(looped, TRUE, start = 0, end = 0, window = 0),
    c(Q = 1)
  )
  expect_warning(
    inactive <- dyn_centrality(
      looped, measure = "prestige", prestige = "indegree.rowcolnorm",
      start = 1, end = 1, window = 0
    ),
    class = "dynet_prestige_infeasible"
  )
  expect_true(is.na(as.data.frame(inactive)$value))
  expect_identical(
    attr(inactive, "prestige_diagnostics")$reason, "zero_margin"
  )

  spells <- data.frame(
    from = c("A", "A", "B"), to = c("A", "B", "A"), time = 0
  )
  retained <- quiet_dynet(spells, loops = TRUE)
  expect_warning(
    retained_value <- rowcol_prestige_vector(
      retained, start = 0, end = 0, window = 0
    ),
    class = "dynet_prestige_infeasible"
  )
  expect_true(all(is.na(retained_value)))

  dropped <- quiet_dynet(spells, loops = FALSE)
  expect_identical(
    rowcol_prestige_vector(dropped, start = 0, end = 0, window = 0),
    c(A = 1, B = 1)
  )
})

test_that("bounded union occurs before feasibility and session balancing", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "A"), time = 0,
    session = c("s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  expect_identical(
    rowcol_prestige_vector(
      dn, sessions = "bounded", start = 0, end = 0, window = 0
    ),
    c(A = 1, B = 1)
  )
  expect_identical(
    rowcol_prestige_vector(
      dn, TRUE, sessions = "collapse", start = 0, end = 0, window = 0
    ),
    c(A = 1 / 2, B = 1 / 2)
  )
  expect_warning(
    separate <- dyn_centrality(
      dn, measure = "prestige", prestige = "indegree.rowcolnorm",
      sessions = "separate", start = 0, end = 0, window = 0
    ),
    class = "dynet_prestige_infeasible"
  )
  expect_true(all(is.na(as.data.frame(separate)$value)))
  expect_equal(nrow(attr(separate, "prestige_diagnostics")), 2L)
})

test_that("weights and repeated spells do not enter the balancing matrix", {
  spells <- data.frame(
    from = c("A", "A", "A", "B", "B", "B", "C", "C"),
    to = c("A", "A", "B", "A", "B", "C", "B", "C"), time = 0,
    weight = c(9, -9, 0, 7, 2, -3, 100, 4)
  )
  dn <- quiet_dynet(spells, loops = TRUE, weight = "weight")
  mixed <- as.data.frame(dyn_centrality(
    dn, measure = c("strength", "prestige"),
    prestige = "indegree.rowcolnorm",
    start = 0, end = 0, window = 0
  ))
  expect_identical(subset(mixed, measure == "prestige")$value, c(1, 1, 1))

  b <- matrix(c(9, 2, 0, 3, 4, 8, 0, 5, 7), 3L, 3L, byrow = TRUE)
  binary <- .rowcol_balance((b > 0) * 1)
  valued <- .rowcol_balance(b)
  expect_equal(valued$matrix, binary$matrix, tolerance = 0)
})

test_that("row-column prestige publishes support and solver metadata", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "A"), time = 0
  ))
  result <- dyn_centrality(
    dn, measure = "prestige", prestige = "indegree.rowcolnorm"
  )
  expect_identical(attr(result, "what"),
                   "Row-column-normalized indegree prestige")
  expect_identical(attr(result, "definition"), "indegree.rowcolnorm")
  expect_identical(attr(result, "matrix_transform"),
                   "sinkhorn_knopp_row_column")
  expect_identical(attr(result, "support_requirement"),
                   "total_support_full_vertex_matrix")
  expect_identical(attr(result, "support_policy"),
                   "preserve_all_binary_dyads")
  expect_identical(attr(result, "unit"),
                   "balanced_incoming_nomination_mass")
  expect_identical(attr(result, "undefined"), "NA")
  expect_identical(attr(result, "zero_total"), "not_applicable_feasible")
  expect_identical(attr(result, "solver_tolerance"), 1e-12)
  expect_identical(attr(result, "error_norm"), "max_absolute_margin")
  expect_identical(attr(result, "maximum_iterations"), 10000L)
})

test_that("row-column prestige obeys public coordinate invariants", {
  spells <- data.frame(
    from = c("A", "A", "B", "B", "B", "C", "C"),
    to = c("A", "B", "A", "B", "C", "B", "C"),
    start = c(0, 0, 0, 0, 1, 1, 0), end = c(4, 4, 4, 4, 3, 3, 4)
  )
  value_at <- function(x, at, window) {
    rowcol_prestige_vector(
      quiet_dynet(x, loops = TRUE), start = at, end = at, window = window
    )
  }
  reference <- value_at(spells, 1, 1)
  expect_identical(value_at(spells[7:1, ], 1, 1), reference)
  expect_identical(value_at(
    transform(spells, start = start + 13, end = end + 13), 14, 1
  ), reference)
  expect_identical(value_at(
    transform(spells, start = start * 3, end = end * 3), 3, 3
  ), reference)

  rename <- c(A = "z", B = "q", C = "m")
  renamed <- value_at(transform(
    spells, from = unname(rename[from]), to = unname(rename[to])
  ), 1, 1)
  expect_identical(unname(renamed[unname(rename[names(reference)])]),
                   unname(reference))
})
