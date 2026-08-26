v03_row <- function(x, node, session = NULL) {
  frame <- as.data.frame(x)
  keep <- frame$node == node
  if (!is.null(session)) keep <- keep & frame$session == session
  frame[keep, , drop = FALSE]
}

test_that("V03 requires an exact anchor then permits waiting through absence", {
  edges <- data.frame(
    from = c("S", "A"), to = c("A", "T"), start = c(1, 5), end = c(1, 5)
  )
  activity <- data.frame(
    node = c("S", "A", "A", "T"), start = c(0, 1, 5, 5),
    end = c(2, 1, 5, 5)
  )
  dn <- quiet_dynet(edges, vertex_spells = activity,
                    observation_start = 0, observation_end = 5)

  paths <- paths(dn, "S", start = 0, end = 5, sessions = "collapse")
  target <- v03_row(paths, "T")
  expect_true(target$reachable)
  expect_equal(target$arrival_time, 5)
  expect_equal(target$n_hops, 2L)
  expect_equal(target$n_paths, 1)

  invalid <- as.data.frame(paths(
    dn, "S", start = 2.5, end = 5, sessions = "collapse"
  ))
  expect_false(any(invalid$reachable))
  expect_true(all(!invalid$attained & invalid$n_paths == 0))
  expect_true(all(is.na(invalid$arrival_time) & is.na(invalid$n_hops)))

  backward <- as.data.frame(paths(
    dn, "T", direction = "backward", start = 0, end = 5,
    sessions = "collapse"
  ))
  expect_equal(backward$arrival_time[match(c("S", "A", "T"), backward$node)],
               c(1, 5, 5))
})

test_that("V03 zero-duration hops require both exact endpoint appearances", {
  edge <- data.frame(from = "S", to = "T", start = 2, end = 2)
  base <- data.frame(
    node = c("S", "S", "T"), start = c(0, 2, 0), end = c(0, 2, 2)
  )
  blocked <- quiet_dynet(edge, vertex_spells = base,
                         observation_start = 0, observation_end = 2)
  restored <- quiet_dynet(edge, vertex_spells = rbind(
    base, data.frame(node = "T", start = 2, end = 2)
  ), observation_start = 0, observation_end = 2)
  expect_false(v03_row(paths(blocked, "S", start = 0, end = 2), "T")$reachable)
  expect_true(v03_row(paths(restored, "S", start = 0, end = 2), "T")$reachable)
})

test_that("V03 positive interval traversal needs closed endpoint occupancy", {
  edge <- data.frame(from = "S", to = "T", start = 0, end = 2)
  make <- function(tail_end = 3, head_end = 3, close_tail = FALSE,
                   close_head = FALSE) {
    activity <- data.frame(
      node = c("S", "T"), start = c(0, 0), end = c(tail_end, head_end)
    )
    if (close_tail) activity <- rbind(
      activity, data.frame(node = "S", start = 2, end = 2)
    )
    if (close_head) activity <- rbind(
      activity, data.frame(node = "T", start = 2, end = 2)
    )
    quiet_dynet(edge, vertex_spells = activity,
                observation_start = 0, observation_end = 3)
  }
  ok <- v03_row(paths(make(), "S", start = 0, end = 2,
                          traversal_time = 2), "T")
  expect_equal(ok$arrival_time, 2)
  expect_false(v03_row(paths(make(tail_end = 2), "S", start = 0, end = 2,
                                 traversal_time = 2), "T")$reachable)
  expect_false(v03_row(paths(make(head_end = 2), "S", start = 0, end = 2,
                                 traversal_time = 2), "T")$reachable)
  closed <- paths(make(tail_end = 2, head_end = 2, close_tail = TRUE,
                           close_head = TRUE), "S", start = 0, end = 2,
                      traversal_time = 2)
  expect_true(v03_row(closed, "T")$reachable)
})

test_that("V03 delayed points gate trigger and receiver completion", {
  edge <- data.frame(from = "S", to = "T", start = 1, end = 1)
  make <- function(receiver_completion = TRUE) {
    activity <- data.frame(
      node = c("S", "T"), start = c(1, 1), end = c(1, 1)
    )
    if (receiver_completion) activity <- rbind(
      activity, data.frame(node = "T", start = 3, end = 3)
    )
    quiet_dynet(edge, vertex_spells = activity,
                observation_start = 0, observation_end = 3)
  }
  ok <- v03_row(paths(make(), "S", start = 1, end = 3,
                          traversal_time = 2), "T")
  expect_equal(ok$arrival_time, 3)
  expect_false(v03_row(paths(make(FALSE), "S", start = 1, end = 3,
                                 traversal_time = 2), "T")$reachable)
})

test_that("V03 activity domains preserve parent contact path identity", {
  edges <- data.frame(
    from = c("S", "A"), to = c("A", "T"),
    start = c(0, 4), end = c(4, 4)
  )
  activity <- data.frame(
    node = c("S", "S", "A", "A", "A", "T"),
    start = c(0, 2, 0, 2, 4, 4), end = c(1, 3, 1, 3, 4, 4)
  )
  dn <- quiet_dynet(edges, vertex_spells = activity,
                    observation_start = 0, observation_end = 4)
  paths <- paths(dn, "S", start = 0, end = 4)
  target <- v03_row(paths, "T")
  expect_equal(target$n_paths, 1)
  expect_equal(target$n_hops, 2L)
  steps <- as.data.frame(paths, what = "steps")
  expect_equal(steps$node[steps$endpoint == "T"], c("S", "A", "T"))
})

test_that("V03 collapse unions activity while bounded and separate stay local", {
  edges <- data.frame(
    from = c("S", "A"), to = c("A", "T"), start = c(1, 5), end = c(1, 5),
    wave = c("s1", "s2")
  )
  activity <- data.frame(
    node = c("S", "A", "A", "T"), start = c(0, 1, 5, 5),
    end = c(2, 1, 5, 5), session = c("s1", "s1", "s1", "s2")
  )
  dn <- quiet_dynet(edges, session = "wave", vertex_spells = activity,
                    observation_start = 0, observation_end = 5)
  expect_true(v03_row(paths(
    dn, "S", start = 0, end = 5, sessions = "collapse"
  ), "T")$reachable)
  expect_false(v03_row(paths(
    dn, "S", start = 0, end = 5, sessions = "bounded"
  ), "T")$reachable)
  separate <- paths(dn, "S", start = 0, end = 5, sessions = "separate")
  expect_false(any(as.data.frame(separate)$reachable[
    as.data.frame(separate)$node == "T"
  ]))
})

test_that("V03 backward activity boundaries preserve supremum attainment", {
  edge <- data.frame(from = "A", to = "T", start = 0, end = 5)
  make <- function(close_tail = FALSE) {
    activity <- data.frame(
      node = c("A", "T", "T"), start = c(0, 0, 5), end = c(4, 5, 5)
    )
    if (close_tail) activity <- rbind(
      activity, data.frame(node = "A", start = 4, end = 4)
    )
    quiet_dynet(edge, vertex_spells = activity,
                observation_start = 0, observation_end = 5)
  }
  open <- v03_row(paths(
    make(), "T", direction = "backward", start = 0, end = 5
  ), "A")
  expect_true(open$reachable)
  expect_equal(open$arrival_time, 4)
  expect_false(open$attained)
  expect_true(is.na(open$n_hops))
  expect_equal(open$n_paths, 0)

  closed <- v03_row(paths(
    make(TRUE), "T", direction = "backward", start = 0, end = 5
  ), "A")
  expect_true(closed$attained)
  expect_equal(closed$n_hops, 1L)
  expect_equal(closed$n_paths, 1)
})

test_that("V03 paths reachability and temporal centrality share activity gates", {
  edges <- data.frame(
    from = c("S", "A"), to = c("A", "T"), start = c(1, 3), end = c(1, 3)
  )
  activity <- data.frame(
    node = c("S", "A", "A", "T"), start = c(0, 1, 3, 3),
    end = c(2, 1, 3, 3)
  )
  dn <- quiet_dynet(edges, vertex_spells = activity,
                    observation_start = 0, observation_end = 3)
  paths <- as.data.frame(paths(dn, "S", start = 0, end = 3))
  expected <- sum(paths$reachable[paths$node != "S"])
  reach <- as.data.frame(dyn_reachability(
    dn, direction = "forward", start = 0, end = 3,
    measure = "reach_count"
  ))
  central <- as.data.frame(dyn_centrality(
    dn, c("reach_count", "closeness", "betweenness"),
    scope = "temporal", start = 0, end = 3
  ))
  expect_equal(reach$value[reach$node == "S"], expected)
  expect_equal(central$value[
    central$node == "S" & central$measure == "reach_count"
  ], expected)
  expect_equal(reach$value[reach$node == "A"], 0)
  expect_equal(central$value[
    central$node == "A" & central$measure == "reach_count"
  ], 0)
  expect_equal(central$value[
    central$node == "S" & central$measure == "closeness"
  ], 1 / mean(c(1, 3)))
  expect_equal(central$value[
    central$node == "A" & central$measure == "betweenness"
  ], 1)
  expect_true(all(central$value[
    central$node == "T" & central$measure %in% c("reach_count", "closeness")
  ] == 0))
  expect_identical(attr(paths(dn, "S", start = 0, end = 3),
                        "vertex_path_rule"), "endpoint_activity_gated")
})

test_that("V03 waiting crosses observation gaps but interval atoms do not", {
  observations <- data.frame(start = c(0, 4), end = c(2, 6))
  chain_edges <- data.frame(
    from = c("S", "A"), to = c("A", "T"), start = c(1, 5), end = c(1, 5)
  )
  activity <- data.frame(
    node = c("S", "A", "A", "T"), start = c(0, 1, 5, 5),
    end = c(2, 1, 5, 5)
  )
  chain <- quiet_dynet(chain_edges, observation_spells = observations,
                       vertex_spells = activity)
  expect_true(v03_row(paths(chain, "S", start = 0, end = 6), "T")$reachable)

  interval <- quiet_dynet(
    data.frame(from = "S", to = "T", start = 1, end = 5),
    observation_spells = observations,
    vertex_spells = data.frame(node = c("S", "T"), start = 0, end = 6)
  )
  expect_false(v03_row(paths(
    interval, "S", start = 0, end = 6, traversal_time = 4
  ), "T")$reachable)

  delayed <- quiet_dynet(
    data.frame(from = "S", to = "T", start = 1, end = 1),
    observation_spells = observations,
    vertex_spells = data.frame(
      node = c("S", "T", "T"), start = c(0, 1, 5), end = c(2, 1, 5)
    )
  )
  expect_equal(v03_row(paths(
    delayed, "S", start = 0, end = 6, traversal_time = 4
  ), "T")$arrival_time, 5)
})

test_that("V03 activity-gated tied families retain exact atom counts", {
  edges <- data.frame(
    from = c("S", "S", "A", "B"), to = c("A", "B", "T", "T"),
    start = c(1, 1, 3, 3), end = c(1, 1, 3, 3)
  )
  activity <- data.frame(
    node = c("S", "A", "A", "B", "B", "T"),
    start = c(0, 1, 3, 1, 3, 3), end = c(2, 1, 3, 1, 3, 3)
  )
  dn <- quiet_dynet(edges, vertex_spells = activity,
                    observation_start = 0, observation_end = 3)
  paths <- paths(dn, "S", start = 0, end = 3)
  expect_equal(v03_row(paths, "T")$n_paths, 2)
  routes <- as.data.frame(paths, what = "steps")
  routes <- routes[routes$endpoint == "T", ]
  expect_equal(length(unique(routes$path_id)), 2L)
  expect_setequal(split(routes$node, routes$path_id),
                  list(c("S", "A", "T"), c("S", "B", "T")))
})

test_that("V03 preserves all-static output and time/order transformations", {
  edges <- data.frame(
    from = c("S", "A", "S"), to = c("A", "T", "T"),
    start = c(1, 3, 5), end = c(1, 3, 5)
  )
  base <- quiet_dynet(edges, observation_start = 0, observation_end = 5)
  original <- as.data.frame(paths(base, "S", start = 0, end = 5))
  reordered <- quiet_dynet(edges[c(3, 1, 2), ],
                           observation_start = 0, observation_end = 5)
  expect_equal(as.data.frame(paths(
    reordered, "S", start = 0, end = 5
  )), original, ignore_attr = TRUE)

  activity <- data.frame(
    node = c("S", "A", "A", "T", "T"),
    start = c(0, 1, 3, 3, 5), end = c(2, 1, 3, 3, 5)
  )
  explicit <- quiet_dynet(edges, vertex_spells = activity,
                          observation_start = 0, observation_end = 5)
  shifted_edges <- edges
  shifted_edges$start <- shifted_edges$start + 10
  shifted_edges$end <- shifted_edges$end + 10
  shifted_activity <- activity
  shifted_activity$start <- shifted_activity$start + 10
  shifted_activity$end <- shifted_activity$end + 10
  shifted <- quiet_dynet(shifted_edges, vertex_spells = shifted_activity,
                         observation_start = 10, observation_end = 15)
  left <- as.data.frame(paths(explicit, "S", start = 0, end = 5))
  right <- as.data.frame(paths(shifted, "S", start = 10, end = 15))
  right$arrival_time <- right$arrival_time - 10
  expect_equal(right[c("node", "reachable", "arrival_time", "attained",
                       "n_hops", "n_paths")],
               left[c("node", "reachable", "arrival_time", "attained",
                      "n_hops", "n_paths")], ignore_attr = TRUE)
})

test_that("V03 bounded atoms keep observation provenance aligned", {
  edges <- data.frame(
    from = c("C", "A"), to = c("D", "B"), start = c(0, 0), end = c(0, 4),
    wave = c("s1", "s2")
  )
  dn <- quiet_dynet(
    edges, session = "wave",
    observation_spells = data.frame(start = c(0, 3), end = c(1, 4))
  )
  paths <- paths(dn, "A", start = 0, end = 4, sessions = "bounded")
  search <- attr(paths, "optimal_search")$search$per_session$s2
  expect_identical(search$atoms$observation, c(1L, 2L))
})
