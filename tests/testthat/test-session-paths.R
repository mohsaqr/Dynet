path_rows <- function(x, nodes) {
  out <- as.data.frame(x)
  out[match(nodes, out$node), , drop = FALSE]
}

session_path_rows <- function(x, session, nodes) {
  out <- as.data.frame(x)
  block <- out[out$session == session, , drop = FALSE]
  block[match(nodes, block$node), , drop = FALSE]
}

route_steps <- function(x, endpoint, path_session = NULL) {
  out <- as.data.frame(x, what = "steps")
  out <- out[out$endpoint == endpoint, , drop = FALSE]
  if (!is.null(path_session)) {
    out <- out[out$path_session == path_session, , drop = FALSE]
  }
  out[order(out$step), , drop = FALSE]
}

test_that("bounded forward paths retain complete endpoint-specific sessions", {
  spells <- data.frame(
    from = c("S", "A", "S", "A"),
    to = c("A", "B", "A", "B"),
    time = c(1, 10, 5, 6),
    session = c("s1", "s1", "s2", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- paths(dn, from = "S", at = 0, sessions = "bounded")
  primary <- path_rows(paths, c("S", "A", "B"))

  expect_equal(primary$arrival_time, c(0, 1, 6))
  expect_identical(primary$path_session, c(NA_character_, "s1", "s2"))
  expect_equal(primary$n_best_sessions, c(0L, 1L, 1L))
  expect_equal(primary$n_hops, c(0L, 1L, 2L))
  expect_false("previous" %in% names(primary))

  to_a <- route_steps(paths, "A", "s1")
  expect_identical(to_a$node, c("S", "A"))
  expect_equal(to_a$time, c(0, 1))

  to_b <- route_steps(paths, "B", "s2")
  expect_identical(to_b$node, c("S", "A", "B"))
  expect_equal(to_b$time, c(0, 5, 6))
  expect_true(all(to_b$path_session == "s2"))
})

test_that("bounded paths exclude a journey assembled across sessions", {
  spells <- data.frame(
    from = c("S", "X"), to = c("X", "Y"), time = c(1, 2),
    session = c("s1", "s2"), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  bounded <- paths(dn, from = "S", at = 0, sessions = "bounded")
  collapsed <- paths(dn, from = "S", at = 0, sessions = "collapse")
  separate <- paths(dn, from = "S", at = 0, sessions = "separate")

  expect_false(path_rows(bounded, "Y")$reachable)
  expect_equal(path_rows(collapsed, "Y")$arrival_time, 2)
  expect_false(session_path_rows(separate, "s1", "Y")$reachable)
  expect_false(session_path_rows(separate, "s2", "Y")$reachable)

  bounded_reach <- as.data.frame(dyn_reachability(
    dn, direction = "forward", at = 0, sessions = "bounded"
  ))
  collapsed_reach <- as.data.frame(dyn_reachability(
    dn, direction = "forward", at = 0, sessions = "collapse"
  ))
  expect_equal(bounded_reach$value[bounded_reach$node == "S"], 1 / 2)
  expect_equal(collapsed_reach$value[collapsed_reach$node == "S"], 1)
})

test_that("bounded temporal betweenness combines complete winning sessions", {
  spells <- data.frame(
    from = c("A", "X", "B", "A", "Y"),
    to = c("X", "B", "C", "Y", "B"), time = c(4, 4, 5, 1, 1),
    session = c("s1", "s1", "s1", "s2", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  result <- as.data.frame(dyn_centrality(
    dn, measure = "betweenness", scope = "temporal", sessions = "bounded"
  ))
  value <- stats::setNames(result$value, result$node)

  expect_equal(unname(value[c("B", "X", "Y")]), c(2, 1, 1))
})

test_that("partially missing session labels are rejected", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(1, 2),
    session = c("s1", NA_character_), stringsAsFactors = FALSE
  )

  expect_error(
    dynet(spells, session = "session"),
    class = "dynet_bad_input"
  )
})

test_that("separate paths return complete session blocks and local origins", {
  spells <- data.frame(
    from = c("S", "A", "S", "A", "C"),
    to = c("A", "B", "A", "B", "D"),
    time = c(1, 10, 5, 6, 3),
    session = c("s1", "s1", "s2", "s2", "s3"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- paths(dn, from = "S", sessions = "separate")
  out <- as.data.frame(paths)

  expect_equal(nrow(out), 3L * 5L)
  expect_identical(attr(paths, "origin"), c(s1 = 1, s2 = 5, s3 = 3))
  expect_equal(unique(session_path_rows(paths, "s1", "S")$origin), 1)
  expect_equal(unique(session_path_rows(paths, "s2", "S")$origin), 5)
  expect_equal(unique(session_path_rows(paths, "s3", "S")$origin), 3)

  s3 <- session_path_rows(paths, "s3", c("S", "A", "B", "C", "D"))
  expect_identical(s3$reachable, c(TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_equal(s3$arrival_time, c(3, NA, NA, NA, NA))

  s3_steps <- as.data.frame(paths, what = "steps")
  s3_steps <- s3_steps[s3_steps$session == "s3", , drop = FALSE]
  expect_identical(s3_steps$endpoint, "S")
  expect_identical(s3_steps$node, "S")

  described <- summary(paths)
  expect_setequal(unique(described$session), c("s1", "s2", "s3"))
})

test_that("bounded paths break arrival ties by hop count", {
  spells <- data.frame(
    from = c("S", "S", "A"), to = c("T", "A", "T"),
    time = c(5, 2, 5), session = c("s1", "s2", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- paths(dn, from = "S", at = 0, sessions = "bounded")
  target <- path_rows(paths, "T")

  expect_equal(target$arrival_time, 5)
  expect_identical(target$path_session, "s1")
  expect_equal(target$n_best_sessions, 1L)
  expect_equal(target$n_hops, 1L)
  expect_equal(target$n_paths, 1)

  steps <- as.data.frame(paths, what = "steps")
  steps <- steps[steps$endpoint == "T", , drop = FALSE]
  expect_identical(unique(steps$path_session), "s1")
  expect_equal(nrow(steps), 2L)

  permuted <- quiet_dynet(spells[c(3, 1, 2), ], session = "session")
  again <- path_rows(
    paths(permuted, from = "S", at = 0, sessions = "bounded"), "T"
  )
  expect_equal(again$arrival_time, target$arrival_time)
  expect_equal(again$n_best_sessions, target$n_best_sessions)
  expect_identical(again$path_session, "s1")
})

test_that("equal-hop session ties keep an unambiguous hop count", {
  spells <- data.frame(
    from = c("S", "S"), to = c("T", "T"), time = c(5, 5),
    session = c("s1", "s2"), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- paths(dn, from = "S", at = 0, sessions = "bounded")
  target <- path_rows(paths, "T")

  expect_equal(target$arrival_time, 5)
  expect_true(is.na(target$path_session))
  expect_equal(target$n_best_sessions, 2L)
  expect_equal(target$n_hops, 1L)
  steps <- route_steps(paths, "T")
  expect_setequal(unique(steps$path_session), c("s1", "s2"))
})

test_that("bounded backward routes do not merge predecessor sessions", {
  spells <- data.frame(
    from = c("A", "B", "A", "B"),
    to = c("B", "T", "B", "T"),
    start = c(1, 8, 5, 7), end = c(4, 10, 7, 9),
    session = c("s1", "s1", "s2", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- paths(
    dn, from = "T", direction = "backward", at = 9,
    sessions = "bounded"
  )
  primary <- path_rows(paths, c("A", "B", "T"))

  expect_equal(primary$arrival_time, c(7, 9, 9))
  expect_identical(primary$attained, c(FALSE, TRUE, TRUE))
  expect_identical(primary$path_session, c(NA_character_, "s1", NA_character_))
  expect_equal(primary$n_hops, c(NA_integer_, 1L, 0L))
  expect_equal(primary$n_paths, c(0, 1, 1))

  to_a <- route_steps(paths, "A", "s2")
  expect_equal(nrow(to_a), 0L)

  to_b <- route_steps(paths, "B", "s1")
  expect_identical(to_b$node, c("B", "T"))
  expect_equal(to_b$time, c(9, 9))
  expect_true(all(to_b$attained))

  separate <- paths(
    dn, from = "T", direction = "backward", at = 9,
    sessions = "separate"
  )
  expect_equal(session_path_rows(separate, "s1", "A")$arrival_time, 4)
  expect_equal(session_path_rows(separate, "s2", "A")$arrival_time, 7)
})

test_that("attainment resolves a backward session tie before session identity", {
  spells <- data.frame(
    from = c("A", "A"), to = c("T", "T"),
    start = c(5, 0), end = c(5, 5), session = c("s1", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- paths(
    dn, from = "T", direction = "backward", at = 10,
    sessions = "bounded"
  )
  actor <- path_rows(paths, "A")

  expect_equal(actor$arrival_time, 5)
  expect_true(actor$attained)
  expect_identical(actor$path_session, "s1")
  expect_equal(actor$n_best_sessions, 1L)
  steps <- route_steps(paths, "A")
  expect_identical(unique(steps$path_session), "s1")
})

test_that("unattained backward session ties have no maximizing family", {
  spells <- data.frame(
    from = c("A", "A"), to = c("T", "T"),
    start = c(0, 1), end = c(5, 5), session = c("s1", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  paths <- paths(
    dn, from = "T", direction = "backward", at = 10,
    sessions = "bounded"
  )
  actor <- path_rows(paths, "A")

  expect_equal(actor$arrival_time, 5)
  expect_false(actor$attained)
  expect_true(is.na(actor$path_session))
  expect_equal(actor$n_best_sessions, 0L)
  expect_true(is.na(actor$n_hops))
  expect_equal(actor$n_paths, 0)
  steps <- route_steps(paths, "A")
  expect_equal(nrow(steps), 0L)
})

test_that("session optima are selected after applying path bounds", {
  spells <- data.frame(
    from = c("S", "S"), to = c("T", "T"), time = c(1, 4),
    session = c("s1", "s2"), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")

  bounded <- paths(
    dn, from = "S", sessions = "bounded", start = 2, end = 5
  )
  target <- path_rows(bounded, "T")
  expect_equal(target$arrival_time, 4)
  expect_identical(target$path_session, "s2")

  separate <- paths(
    dn, from = "S", sessions = "separate", start = 2, end = 5
  )
  expect_false(session_path_rows(separate, "s1", "T")$reachable)
  expect_equal(session_path_rows(separate, "s2", "T")$arrival_time, 4)

  untruncated <- paths(
    dn, from = "S", sessions = "bounded", start = 0, end = 5
  )
  expect_equal(path_rows(untruncated, "T")$arrival_time, 1)
  expect_identical(path_rows(untruncated, "T")$path_session, "s1")
})

test_that("undirected session paths ignore stored endpoint orientation", {
  one <- data.frame(
    from = c("A", "B"), to = c("S", "A"), time = c(1, 3),
    session = c("s1", "s1"), stringsAsFactors = FALSE
  )
  two <- data.frame(
    from = c("S", "A"), to = c("A", "B"), time = c(1, 3),
    session = c("s1", "s1"), stringsAsFactors = FALSE
  )
  first <- paths(
    quiet_dynet(one, session = "session", directed = FALSE),
    from = "S", at = 0, sessions = "bounded"
  )
  second <- paths(
    quiet_dynet(two, session = "session", directed = FALSE),
    from = "S", at = 0, sessions = "bounded"
  )
  a <- path_rows(first, c("S", "A", "B"))
  b <- path_rows(second, c("S", "A", "B"))

  expect_equal(a$arrival_time, c(0, 1, 3))
  expect_equal(a$arrival_time, b$arrival_time)
  expect_equal(a$n_hops, b$n_hops)
  expect_identical(a$path_session, b$path_session)
})

test_that("non-collapsed path plots reject a false single-tree rendering", {
  spells <- data.frame(
    from = c("S", "S"), to = c("A", "A"), time = c(1, 2),
    session = c("s1", "s2"), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")

  # Session identity is carried in the tree's node keys, so a bounded or
  # separate family draws without merging routes across sessions.
  expect_s3_class(plot(paths(dn, from = "S", sessions = "bounded")), "ggplot")
  expect_s3_class(plot(paths(dn, from = "S", sessions = "separate")), "ggplot")
})
