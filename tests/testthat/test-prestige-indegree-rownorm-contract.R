rownorm_prestige_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "indegree.rownorm",
    rescale = rescale, ...
  ))
}

rownorm_prestige_vector <- function(dn, rescale = FALSE, ...) {
  df <- rownorm_prestige_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("row-normalized prestige is the row-stochastic column mass", {
  b <- matrix(c(
    0, 1, 1,
    0, 0, 0,
    0, 1, 0
  ), 3L, 3L, byrow = TRUE)
  expect_identical(
    .indegree_prestige(b, definition = "indegree.rownorm"),
    c(0, 3 / 2, 1 / 2)
  )
  expect_identical(
    .indegree_prestige(b, TRUE, "indegree.rownorm"),
    c(0, 3 / 4, 1 / 4)
  )
  expect_false(identical(
    .indegree_prestige(b, definition = "indegree.rownorm"),
    .indegree_prestige(b, definition = "indegree")
  ))

  valued <- b
  valued[1L, 2L] <- 9
  expect_identical(
    .indegree_prestige(valued, definition = "indegree.rownorm"),
    c(0, 3 / 2, 1 / 2)
  )
})

test_that("zero outgoing rows are zero and zero totals remain undefined", {
  empty <- matrix(0, 3L, 3L)
  expect_identical(
    .indegree_prestige(empty, definition = "indegree.rownorm"),
    c(0, 0, 0)
  )
  expect_true(all(is.nan(
    .indegree_prestige(empty, TRUE, "indegree.rownorm")
  )))

  singleton <- matrix(0, 1L, 1L)
  expect_identical(
    .indegree_prestige(singleton, definition = "indegree.rownorm"), 0
  )
  expect_true(is.nan(
    .indegree_prestige(singleton, TRUE, "indegree.rownorm")
  ))
})

test_that("literal dyads distinguish row normalization from S01", {
  spells <- data.frame(
    from = c("A", "A", "C"), to = c("B", "C", "B"), time = 0
  )
  dn <- quiet_dynet(spells)
  rownorm <- rownorm_prestige_vector(
    dn, start = 0, end = 0, window = 0
  )
  raw <- as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "indegree",
    start = 0, end = 0, window = 0
  ))
  expect_identical(rownorm, c(A = 0, B = 3 / 2, C = 1 / 2))
  expect_identical(stats::setNames(raw$value, raw$node),
                   c(A = 0, B = 2, C = 1))
  expect_identical(
    rownorm_prestige_vector(dn, TRUE, start = 0, end = 0, window = 0),
    c(A = 0, B = 3 / 4, C = 1 / 4)
  )
})

test_that("loops enter the sender denominator before incoming reduction", {
  spells <- data.frame(
    from = c("A", "A", "B"), to = c("A", "B", "B"), time = c(0, 0, 10)
  )
  dn <- quiet_dynet(spells, loops = TRUE)
  expect_identical(
    rownorm_prestige_vector(dn, start = 0, end = 0, window = 0),
    c(A = 1 / 2, B = 1 / 2)
  )
  dropped <- quiet_dynet(spells, loops = FALSE)
  expect_identical(
    rownorm_prestige_vector(dropped, start = 0, end = 0, window = 0),
    c(A = 0, B = 1)
  )

  loop <- quiet_dynet(data.frame(from = "Q", to = "Q", time = 0), loops = TRUE)
  expect_identical(
    rownorm_prestige_vector(loop, TRUE, start = 0, end = 0, window = 0),
    c(Q = 1)
  )
})

test_that("duplicates and values cannot change sender allocation", {
  spells <- data.frame(
    from = c("A", "A", "A", "A", "C"),
    to = c("B", "B", "B", "C", "B"), time = 0,
    weight = c(9, -9, 0, 100, -7)
  )
  dn <- quiet_dynet(spells, weight = "weight")
  alone <- rownorm_prestige_vector(
    dn, start = 0, end = 0, window = 0
  )
  mixed <- as.data.frame(dyn_centrality(
    dn, measure = c("strength", "prestige"),
    prestige = "indegree.rownorm", start = 0, end = 0, window = 0
  ))
  expect_identical(alone, c(A = 0, B = 3 / 2, C = 1 / 2))
  actual <- subset(mixed, measure == "prestige")
  expect_identical(stats::setNames(actual$value, actual$node), alone)
})

test_that("bounded union precedes row normalization and separate stays local", {
  spells <- data.frame(
    from = c("A", "A"), to = c("B", "C"), time = 0,
    session = c("s1", "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  collapsed <- rownorm_prestige_vector(
    dn, sessions = "collapse", start = 0, end = 0, window = 0
  )
  bounded <- rownorm_prestige_vector(
    dn, sessions = "bounded", start = 0, end = 0, window = 0
  )
  separate <- rownorm_prestige_frame(
    dn, sessions = "separate", start = 0, end = 0, window = 0
  )
  expect_identical(collapsed, c(A = 0, B = 1 / 2, C = 1 / 2))
  expect_identical(bounded, collapsed)
  expect_identical(
    separate$value[separate$session == "s1"], c(0, 1, 0)
  )
  expect_identical(
    separate$value[separate$session == "s2"], c(0, 0, 1)
  )
})

test_that("second-stage rescaling is local to each reporting block", {
  spells <- data.frame(
    from = c("A", "A", "C"), to = c("B", "C", "B"), time = c(0, 0, 1)
  )
  dn <- quiet_dynet(spells)
  result <- rownorm_prestige_frame(
    dn, TRUE, start = 0, end = 1, step = 1, window = 0
  )
  expect_identical(as.numeric(tapply(result$value, result$time, sum)),
                   c(1, 1))
})

test_that("row-normalized prestige is selector-aware but mode-independent", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "A", "C"), to = c("B", "C", "B"), time = 0
  ))
  incoming <- dyn_centrality(
    dn, measure = "prestige", prestige = "indegree.rownorm",
    start = 0, end = 0, window = 0
  )
  outgoing_mode <- dyn_centrality(
    dn, measure = "prestige", prestige = "indegree.rownorm", mode = "out",
    start = 0, end = 0, window = 0
  )
  expect_identical(as.data.frame(outgoing_mode)$value,
                   as.data.frame(incoming)$value)
  expect_identical(attr(incoming, "what"),
                   "Row-normalized indegree prestige")
})

test_that("row-normalized prestige publishes its exact transform and unit", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "C"), time = 0
  ))
  raw <- dyn_centrality(
    dn, measure = "prestige", prestige = "indegree.rownorm"
  )
  expect_identical(attr(raw, "definition"), "indegree.rownorm")
  expect_identical(attr(raw, "matrix_transform"), "row_stochastic")
  expect_identical(attr(raw, "zero_rows"), "all_zero")
  expect_identical(attr(raw, "normalization"), "none")
  expect_identical(attr(raw, "unit"), "active_sender_nomination_mass")
  expect_identical(attr(raw, "loops"), "retained_once")

  mixed <- dyn_centrality(
    dn, measure = c("degree", "prestige"),
    prestige = "indegree.rownorm", rescale = TRUE
  )
  metadata <- attr(mixed, "measure_metadata")$prestige
  expect_identical(metadata$matrix_transform, "row_stochastic")
  expect_identical(metadata$normalization, "sum_to_one")
  expect_identical(metadata$unit,
                   "share_of_active_sender_nomination_mass")
  expect_identical(metadata$zero_rows, "all_zero")
})

test_that("public row-normalized prestige obeys coordinate invariants", {
  spells <- data.frame(
    from = c("A", "A", "C"), to = c("B", "C", "B"),
    start = c(0, 0, 1), end = c(4, 2, 3)
  )
  value_at <- function(x, at, window) {
    rownorm_prestige_vector(
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

  rename <- c(A = "z", B = "q", C = "m")
  renamed <- value_at(transform(
    spells, from = unname(rename[from]), to = unname(rename[to])
  ), 1, 1)
  expect_identical(unname(renamed[unname(rename[names(reference)])]),
                   unname(reference))
})
