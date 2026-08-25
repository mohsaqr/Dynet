test_that("vertex activity can be set, added, updated, removed, and cleared", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 5),
              observation_start = 0, observation_end = 5)
  set <- set_vertex_spells(dn, data.frame(node = "A", start = 0, end = 2))
  expect_equal(nrow(as.data.frame(set, what = "vertex_spells")), 1)

  added <- add_vertex_spells(set, data.frame(node = "A", start = 3, end = 4))
  expect_equal(nrow(as.data.frame(added, what = "vertex_spells")), 2)
  changed <- update_vertex_spells(added, 2, data.frame(end = 5))
  expect_equal(as.data.frame(changed, what = "vertex_spells")$end, c(2, 5))

  removed <- remove_vertex_spells(changed, 1)
  expect_equal(nrow(as.data.frame(removed, what = "vertex_spells")), 1)
  cleared <- set_vertex_spells(removed, NULL)
  expect_equal(nrow(as.data.frame(cleared, what = "vertex_spells")), 0)
  expect_identical(cleared$meta$vertex_activity, "static")
  expect_equal(nrow(as.data.frame(dn, what = "vertex_spells")), 0)
})

test_that("vertex activity edits validate node and clock", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
  expect_error(set_vertex_spells(
    dn, data.frame(node = "C", start = 0, end = 1)
  ), class = "dynet_unknown_node")
  expect_error(set_vertex_spells(
    dn, data.frame(node = "A", start = 2, end = 1)
  ), class = "dynet_bad_vertex_spells")
})

test_that("observation support can be replaced without changing raw spells", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 10))
  bounded <- set_observations(dn, data = data.frame(
    start = c(1, 7), end = c(3, 9)
  ))
  expect_equal(as.data.frame(bounded)$start, 0)
  expect_equal(as.data.frame(bounded)$end, 10)
  observed <- as.data.frame(bounded, what = "observations")
  expect_equal(observed$start, c(1, 7))
  expect_equal(observed$end, c(3, 9))
  expect_equal(sum(as.data.frame(bounded, what = "observed_edges")$duration), 4)

  scalar <- set_observations(dn, start = 2, end = 6)
  expect_equal(unname(scalar$meta$time_range), c(2, 6))
  restored <- clear_observations(scalar)
  expect_equal(unname(restored$meta$time_range), c(0, 10))
  expect_false(isTRUE(restored$meta$observation_explicit))
})

test_that("tie sessions can be assigned, renamed, and removed", {
  dn <- dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 1), end = c(1, 2)
  ))
  sessioned <- set_tie_sessions(dn, c("first", "second"))
  expect_identical(sessioned$meta$sessions, c("first", "second"))
  renamed <- rename_sessions(sessioned, c(first = "s1", second = "s2"))
  expect_identical(renamed$meta$sessions, c("s1", "s2"))
  expect_identical(as.data.frame(renamed)$session, c("s1", "s2"))
  cleared <- set_tie_sessions(renamed, NULL)
  expect_null(cleared$meta$sessions)
  expect_false("session" %in% names(as.data.frame(cleared)))
})

