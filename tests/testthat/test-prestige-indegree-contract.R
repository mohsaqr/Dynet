prestige_frame <- function(dn, rescale = FALSE, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "prestige", prestige = "indegree",
    rescale = rescale, ...
  ))
}

prestige_vector <- function(dn, rescale = FALSE, ...) {
  df <- prestige_frame(dn, rescale, ...)
  stats::setNames(df$value, df$node)
}

test_that("indegree prestige is the binary adjacency column sum", {
  single <- matrix(c(0, 0, 1, 0), 2L, 2L)
  reciprocal <- matrix(c(0, 1, 1, 0), 2L, 2L)
  chain <- matrix(0, 3L, 3L)
  chain[cbind(1:2, 2:3)] <- 1
  in_star <- matrix(0, 4L, 4L)
  in_star[cbind(1:3, 4L)] <- 1
  out_star <- t(in_star)

  expect_identical(.indegree_prestige(single), c(0, 1))
  expect_identical(.indegree_prestige(reciprocal), c(1, 1))
  expect_identical(.indegree_prestige(chain), c(0, 1, 1))
  expect_identical(.indegree_prestige(in_star), c(0, 0, 0, 3))
  expect_identical(.indegree_prestige(out_star), c(1, 1, 1, 0))
})

test_that("rescaled prestige is a within-block sum share", {
  chain <- matrix(0, 3L, 3L)
  chain[cbind(1:2, 2:3)] <- 1
  in_star <- matrix(0, 4L, 4L)
  in_star[cbind(1:3, 4L)] <- 1
  expect_identical(.indegree_prestige(chain, TRUE), c(0, 1 / 2, 1 / 2))
  expect_identical(.indegree_prestige(in_star, TRUE), c(0, 0, 0, 1))

  empty <- .indegree_prestige(matrix(0, 3L, 3L), TRUE)
  expect_true(all(is.nan(empty)))
  expect_false(any(is.na(empty) & !is.nan(empty)))
})

test_that("public prestige matches directed degree mode in exactly", {
  dn <- quiet_dynet(random_edges(seed = 61L), interval = 2)
  prestige <- prestige_frame(dn)
  degree <- as.data.frame(dyn_centrality(
    dn, measure = "degree", mode = "in"
  ))
  key <- function(df) paste(df$time, df$node, sep = "\r")
  expect_identical(
    stats::setNames(prestige$value, key(prestige))[key(degree)],
    stats::setNames(degree$value, key(degree))
  )
})

test_that("retained directed loops contribute once", {
  spells <- data.frame(
    from = c("A", "B", "C"), to = c("A", "A", "B"), time = c(0, 0, 10)
  )
  nodes <- data.frame(name = c("A", "B", "C"))
  dn <- quiet_dynet(spells, nodes = nodes, loops = TRUE)
  expect_identical(
    prestige_vector(dn, start = 0, end = 0, window = 0),
    c(A = 2, B = 0, C = 0)
  )
  expect_identical(
    prestige_vector(dn, TRUE, start = 0, end = 0, window = 0),
    c(A = 1, B = 0, C = 0)
  )
})

test_that("empty and singleton normalized blocks are explicitly undefined", {
  loopless_singleton <- matrix(0, 1L, 1L)
  expect_identical(.indegree_prestige(loopless_singleton), 0)
  expect_true(is.nan(.indegree_prestige(loopless_singleton, TRUE)))

  nodes <- data.frame(name = c("A", "B"))
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 0), nodes = nodes)
  empty <- prestige_vector(
    dn, TRUE, start = 10, end = 10, window = 0
  )
  expect_true(all(is.nan(empty)))

  singleton <- quiet_dynet(
    data.frame(from = "Q", to = "Q", time = 0), loops = TRUE
  )
  expect_identical(
    prestige_vector(singleton, TRUE, start = 0, end = 0, window = 0),
    c(Q = 1)
  )
  inactive <- prestige_vector(
    singleton, TRUE, start = 1, end = 1, window = 0
  )
  expect_true(is.nan(inactive[["Q"]]))
})

test_that("public prestige obeys representation and coordinate invariants", {
  spells <- data.frame(
    from = c("a", "a", "a", "c", "d", "b"),
    to = c("b", "b", "b", "b", "d", "b"),
    start = c(0, 0, 0, 1, 0, 2), end = c(4, 4, 2, 3, 4, 2),
    weight = c(7, -7, 0, 100, 11, 50)
  )
  value_at <- function(x, at, window, nodes = NULL) {
    dn <- quiet_dynet(x, nodes = nodes, weight = "weight", loops = TRUE)
    prestige_vector(dn, start = at, end = at, window = window)
  }
  reference <- value_at(spells, 1, 1)
  expect_identical(value_at(spells[6:1, ], 1, 1), reference)
  expect_identical(value_at(rbind(spells, spells[1:3, ]), 1, 1), reference)
  expect_identical(value_at(
    transform(spells, start = start + 17, end = end + 17), 18, 1
  ), reference)
  expect_identical(value_at(
    transform(spells, start = start * 3, end = end * 3), 3, 3
  ), reference)

  rename <- c(a = "z", b = "q", c = "m", d = "x")
  renamed_spells <- transform(
    spells, from = unname(rename[from]), to = unname(rename[to])
  )
  renamed <- value_at(renamed_spells, 1, 1)
  expect_identical(unname(renamed[unname(rename[names(reference)])]),
                   unname(reference))

  reversed <- value_at(transform(spells, from = to, to = from), 1, 1)
  expect_identical(reversed, c(a = 1, b = 0, c = 1, d = 1))
})

test_that("prestige remains binary in valued and mixed queries", {
  spells <- data.frame(
    from = c("A", "A", "A", "C"), to = rep("B", 4), time = 0,
    weight = c(5, -5, 0, -7)
  )
  dn <- quiet_dynet(spells, weight = "weight")
  alone <- prestige_frame(dn, start = 0, end = 0, window = 0)
  mixed <- as.data.frame(dyn_centrality(
    dn, measure = c("strength", "degree", "prestige"),
    prestige = "indegree", start = 0, end = 0, window = 0
  ))
  mixed_prestige <- subset(mixed, measure == "prestige")
  expect_identical(mixed_prestige$value, alone$value)
  expect_identical(
    stats::setNames(alone$value, alone$node), c(A = 0, B = 2, C = 0)
  )
  degree_alone <- as.data.frame(dyn_centrality(
    dn, measure = "degree", start = 0, end = 0, window = 0
  ))
  expect_identical(subset(mixed, measure == "degree")$value,
                   degree_alone$value)
})

test_that("prestige rescaling is local to every time and session block", {
  spells <- data.frame(
    from = c("A", "A", "C"), to = c("B", "B", "B"),
    time = c(0, 1, 1)
  )
  dn <- quiet_dynet(spells)
  result <- prestige_frame(
    dn, TRUE, start = 0, end = 1, step = 1, window = 0
  )
  expect_identical(
    as.numeric(tapply(result$value, result$time, sum)), c(1, 1)
  )
  expect_identical(result$value[result$node == "B"], c(1, 1))

  session_spells <- data.frame(
    from = c("A", "C"), to = c("B", "B"), time = 0,
    session = c("s1", "s2")
  )
  session_dn <- quiet_dynet(session_spells, session = "session")
  collapsed <- prestige_vector(
    session_dn, TRUE, sessions = "collapse",
    start = 0, end = 0, window = 0
  )
  bounded <- prestige_vector(
    session_dn, TRUE, sessions = "bounded",
    start = 0, end = 0, window = 0
  )
  separate <- prestige_frame(
    session_dn, TRUE, sessions = "separate",
    start = 0, end = 0, window = 0
  )
  expect_identical(bounded, collapsed)
  expect_identical(collapsed, c(A = 0, B = 1, C = 0))
  expect_true(all(tapply(separate$value, separate$session, sum) == 1))
  expect_true(all(separate$value[separate$node == "B"] == 1))
  expect_true(all(separate$value[separate$node != "B"] == 0))

  permuted_spells <- session_spells[c(2, 1), ]
  permuted_spells$session <- unname(c(s1 = "later", s2 = "earlier")[
    permuted_spells$session
  ])
  permuted_dn <- quiet_dynet(permuted_spells, session = "session")
  permuted <- prestige_frame(
    permuted_dn, TRUE, sessions = "separate",
    start = 0, end = 0, window = 0
  )
  permuted$session <- unname(c(later = "s1", earlier = "s2")[
    permuted$session
  ])
  key <- function(x) paste(x$session, x$node, sep = "\r")
  expect_identical(
    stats::setNames(permuted$value, key(permuted))[key(separate)],
    stats::setNames(separate$value, key(separate))
  )
})

test_that("prestige is incoming, directed, and snapshot-only", {
  spells <- data.frame(from = c("A", "A"), to = c("B", "C"), time = 0)
  dn <- quiet_dynet(spells)
  incoming <- prestige_vector(dn, start = 0, end = 0, window = 0)
  expect_identical(
    prestige_vector(dn, mode = "out", start = 0, end = 0, window = 0),
    incoming
  )
  expect_error(
    dyn_centrality(
      quiet_dynet(spells, directed = FALSE), measure = "prestige"
    ),
    class = "dynet_needs_directed"
  )
  expect_error(
    dyn_centrality(dn, measure = "prestige", scope = "temporal"),
    class = "dynet_unknown_measure"
  )
})

test_that("prestige arguments are validated without silent effects", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 0))
  expect_error(
    dyn_centrality(dn, measure = "prestige", prestige = "unknown"),
    class = "dynet_bad_input"
  )
  expect_error(
    dyn_centrality(dn, measure = "prestige", rescale = NA),
    class = "dynet_bad_input"
  )
  expect_error(
    dyn_centrality(dn, measure = "degree", rescale = TRUE),
    class = "dynet_bad_input"
  )
})

test_that("prestige publishes scoped mathematical metadata", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 0))
  result <- dyn_centrality(dn, measure = "prestige", rescale = TRUE)
  expect_identical(attr(result, "definition"), "indegree")
  expect_identical(attr(result, "direction"), "incoming")
  expect_identical(attr(result, "matrix_transform"), "none")
  expect_identical(attr(result, "normalization"), "sum_to_one")
  expect_identical(attr(result, "unit"), "share_of_active_binary_dyads")
  expect_identical(attr(result, "weights"), "ignored")
  expect_identical(attr(result, "loops"), "retained_once")
  expect_identical(attr(result, "zero_total"), "NaN")
  expect_identical(attr(result, "session_aggregation"),
                   "binary_calendar_union")

  mixed <- dyn_centrality(
    dn, measure = c("degree", "prestige"), rescale = TRUE
  )
  expect_null(attr(mixed, "definition"))
  metadata <- attr(mixed, "measure_metadata")$prestige
  expect_identical(metadata$definition, "indegree")
  expect_identical(metadata$normalization, "sum_to_one")
})
