.projection_edge_order <- function(x) {
  x[order(x$edge_type, x$from_state, x$to_state), , drop = FALSE]
}

test_that("E02 three nodes by three slices has exact states and arcs", {
  nodes <- data.frame(
    name = c("A", "B", "C"), group = c("g1", "g2", "g3")
  )
  dn <- quiet_dynet(
    data.frame(
      from = c("A", "B", "C"), to = c("B", "C", "A"),
      start = 0:2, end = 1:3
    ), nodes = nodes, observation_start = 0, observation_end = 3
  )
  projection <- projection(dn, step = 1, window = 1)
  expect_s3_class(projection, "dynet_projection")
  expect_type(projection, "list")
  expect_identical(names(projection), c("vertices", "edges", "meta"))

  vertices <- as.data.frame(projection, what = "vertices")
  expected_vertices <- data.frame(
    state = 1:9, slice = rep(1:3, each = 3),
    time = rep(as.numeric(0:2), each = 3),
    start = rep(as.numeric(0:2), each = 3),
    end = rep(as.numeric(1:3), each = 3),
    closed = rep(c(FALSE, FALSE, TRUE), each = 3),
    node = rep(c("A", "B", "C"), 3), active = TRUE,
    group = rep(c("g1", "g2", "g3"), 3), stringsAsFactors = FALSE
  )
  expect_identical(vertices, expected_vertices)

  within <- data.frame(
    from_state = c(1L, 5L, 9L), to_state = c(2L, 6L, 7L),
    from_node = c("A", "B", "C"), to_node = c("B", "C", "A"),
    from_slice = 1:3, to_slice = 1:3,
    from_time = as.numeric(0:2), to_time = as.numeric(0:2),
    edge_type = "within_slice", weight = 1, n_spells = 1L, lag = 0,
    stringsAsFactors = FALSE
  )
  identity <- data.frame(
    from_state = 1:6, to_state = 4:9,
    from_node = rep(c("A", "B", "C"), 2),
    to_node = rep(c("A", "B", "C"), 2),
    from_slice = rep(1:2, each = 3), to_slice = rep(2:3, each = 3),
    from_time = rep(as.numeric(0:1), each = 3),
    to_time = rep(as.numeric(1:2), each = 3),
    edge_type = "identity_arc", weight = 1, n_spells = 0L, lag = 1,
    stringsAsFactors = FALSE
  )
  expected_edges <- .projection_edge_order(rbind(within, identity))
  actual_edges <- .projection_edge_order(
    as.data.frame(projection, what = "edges")
  )
  rownames(expected_edges) <- NULL
  rownames(actual_edges) <- NULL
  expect_identical(actual_edges, expected_edges)
  expect_false(any(actual_edges$to_time < actual_edges$from_time))
  expect_false(any(
    actual_edges$edge_type == "identity_arc" &
      actual_edges$to_slice != actual_edges$from_slice + 1L
  ))
})

test_that("E02 metadata and fixed accessor schemas are public", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    observation_start = 0, observation_end = 1
  )
  projection <- projection(dn, step = 1, window = 1)
  expect_identical(names(projection$meta), c(
    "source_directed", "directed", "time_unit", "origin", "step", "window",
    "sessions", "n_nodes", "n_slices", "n_blocks", "vertex_rule",
    "within_slice_rule", "identity_rule", "omega", "coupling",
    "identity_weight",
    "undirected_rule", "observation_gap_waiting", "session_aggregation",
    "node_attribute_names", "node_attribute_renames"
  ))
  expect_true(projection$meta$source_directed)
  expect_true(projection$meta$directed)
  expect_identical(projection$meta$origin, 0)
  expect_identical(projection$meta$step, 1)
  expect_identical(projection$meta$window, 1)
  expect_identical(projection$meta$n_nodes, 2L)
  expect_identical(projection$meta$n_slices, 1L)
  expect_identical(projection$meta$n_blocks, 1L)
  expect_identical(projection$meta$identity_weight, 1)
  expect_identical(projection$meta$observation_gap_waiting, "allowed")
  expect_identical(projection$meta$node_attribute_renames,
                   setNames(character(), character()))

  vertices <- as.data.frame(projection, what = "vertices")
  edges <- as.data.frame(projection, what = "edges")
  expect_identical(names(vertices), c(
    "state", "slice", "time", "start", "end", "closed", "node", "active"
  ))
  expect_identical(names(edges), c(
    "from_state", "to_state", "from_node", "to_node", "from_slice",
    "to_slice", "from_time", "to_time", "edge_type", "weight",
    "n_spells", "lag"
  ))
  expect_error(as.data.frame(projection, what = "bad"))
})

test_that("E02 point membership uses later interior and closed final slices", {
  dn <- quiet_dynet(
    data.frame(
      from = c("A", "B", "C"), to = c("B", "C", "A"),
      time = c(0, 1, 3)
    ), observation_start = 0, observation_end = 3
  )
  projection <- projection(dn, step = 1, window = 1)
  within <- as.data.frame(projection, what = "edges")
  within <- within[within$edge_type == "within_slice", ]
  expect_identical(within$from_state, c(1L, 5L, 9L))
  expect_identical(within$to_state, c(2L, 6L, 7L))
  expect_identical(within$from_time, c(0, 1, 2))

  terminus <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    observation_start = 0, observation_end = 2
  )
  terminus_edges <- as.data.frame(
    projection(terminus, step = 1, window = 1), what = "edges"
  )
  terminus_edges <- terminus_edges[terminus_edges$edge_type == "within_slice", ]
  expect_identical(terminus_edges$from_slice, 1L)
})

test_that("E02 retains inactive states and induces separately aggregated endpoints", {
  nodes <- data.frame(name = c("A", "B", "C", "D"), role = 1:4)
  activity <- data.frame(
    node = c("A", "B", "C", "D"),
    start = c(0, .5, .25, 1), end = c(.5, 1, .25, 2)
  )
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    nodes = nodes, vertex_spells = activity,
    observation_start = 0, observation_end = 2
  )
  projection <- projection(dn, step = 1, window = 1)
  vertices <- as.data.frame(projection, what = "vertices")
  expect_identical(vertices$active, c(TRUE, TRUE, TRUE, FALSE,
                                      FALSE, FALSE, FALSE, TRUE))
  expect_identical(vertices$role, rep(1:4, 2))
  within <- as.data.frame(projection, what = "edges")
  within <- within[within$edge_type == "within_slice", ]
  expect_identical(within$from_state, 1L)
  expect_identical(within$to_state, 2L)
  identity <- as.data.frame(projection, what = "edges")
  identity <- identity[identity$edge_type == "identity_arc", ]
  expect_identical(identity$from_state, 1:4)
  expect_identical(identity$to_state, 5:8)
})

test_that("E02 sums duplicate weights and expands undirected dyads", {
  edges <- data.frame(
    from = c("A", "A", "A"), to = c("B", "B", "A"),
    start = 0, end = 1, weight = c(2, 3, 4)
  )
  directed <- quiet_dynet(
    edges, weight = "weight", loops = TRUE,
    observation_start = 0, observation_end = 1
  )
  directed_within <- as.data.frame(
    projection(directed, step = 1, window = 1), what = "edges"
  )
  directed_within <- directed_within[
    directed_within$edge_type == "within_slice", ]
  expect_identical(directed_within$from_node, c("A", "A"))
  expect_identical(directed_within$to_node, c("A", "B"))
  expect_identical(directed_within$weight, c(4, 5))
  expect_identical(directed_within$n_spells, c(1L, 2L))

  undirected <- quiet_dynet(
    edges, directed = FALSE, weight = "weight", loops = TRUE,
    observation_start = 0, observation_end = 1
  )
  projection <- projection(undirected, step = 1, window = 1)
  undirected_within <- as.data.frame(projection, what = "edges")
  undirected_within <- undirected_within[
    undirected_within$edge_type == "within_slice", ]
  undirected_within <- undirected_within[
    order(undirected_within$from_node, undirected_within$to_node), ]
  expect_identical(undirected_within$from_node, c("A", "A", "B"))
  expect_identical(undirected_within$to_node, c("A", "B", "A"))
  expect_identical(undirected_within$weight, c(4, 5, 5))
  expect_identical(undirected_within$n_spells, c(1L, 2L, 2L))
  expect_false(projection$meta$source_directed)
  expect_true(projection$meta$directed)
})

test_that("E02 links observation components and point slices by calendar lag", {
  dn <- quiet_dynet(
    data.frame(
      from = c("A", "B"), to = c("B", "C"), time = c(1, 3)
    ), observation_spells = data.frame(start = c(0, 3), end = c(1, 4))
  )
  projection <- projection(dn, step = 1, window = 1)
  vertices <- as.data.frame(projection, what = "vertices")
  expect_identical(vertices$observation, rep(1:2, each = 3))
  expect_identical(vertices$time, rep(c(0, 3), each = 3))
  identity <- as.data.frame(projection, what = "edges")
  identity <- identity[identity$edge_type == "identity_arc", ]
  expect_identical(identity$from_state, 1:3)
  expect_identical(identity$to_state, 4:6)
  expect_identical(identity$lag, rep(3, 3))

  points <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("B", "A"), time = c(2, 5)),
    observation_spells = data.frame(start = c(2, 5), end = c(2, 5))
  )
  point_projection <- projection(points, step = 1, window = 1)
  point_vertices <- as.data.frame(point_projection, what = "vertices")
  expect_identical(point_vertices$time, rep(c(2, 5), each = 2))
  point_identity <- as.data.frame(point_projection, what = "edges")
  point_identity <- point_identity[point_identity$edge_type == "identity_arc", ]
  expect_identical(point_identity$lag, c(3, 3))
})

test_that("E02 sessions form deterministic blocks without cross-session arcs", {
  dn <- quiet_dynet(
    data.frame(
      from = c("A", "B"), to = c("B", "C"), time = c(0, 1),
      session = c("s1", "s2")
    ), session = "session", observation_start = 0, observation_end = 2
  )
  bounded <- projection(dn, sessions = "bounded", step = 1, window = 1)
  separate <- projection(dn, sessions = "separate", step = 1, window = 1)
  bounded_vertices <- as.data.frame(bounded, what = "vertices")
  separate_vertices <- as.data.frame(separate, what = "vertices")
  expect_identical(bounded_vertices, separate_vertices)
  expect_identical(bounded_vertices$state, 1:12)
  expect_identical(bounded_vertices$session, rep(c("s1", "s2"), each = 6))
  expect_identical(bounded_vertices$slice, rep(rep(1:2, each = 3), 2))

  bounded_edges <- as.data.frame(bounded, what = "edges")
  separate_edges <- as.data.frame(separate, what = "edges")
  expect_identical(bounded_edges, separate_edges)
  identity <- bounded_edges[bounded_edges$edge_type == "identity_arc", ]
  expect_identical(identity$from_state, c(1:3, 7:9))
  expect_identical(identity$to_state, c(4:6, 10:12))
  expect_false(any(identity$from_state <= 6L & identity$to_state >= 7L))

  within <- bounded_edges[bounded_edges$edge_type == "within_slice", ]
  expect_identical(within$from_state, c(1L, 11L))
  expect_identical(within$to_state, c(2L, 12L))
  collapsed <- projection(dn, sessions = "collapse", step = 1, window = 1)
  collapsed_vertices <- as.data.frame(collapsed, what = "vertices")
  expect_false("session" %in% names(collapsed_vertices))
  expect_identical(collapsed_vertices$state, 1:6)
  collapsed_within <- as.data.frame(collapsed, what = "edges")
  collapsed_within <- collapsed_within[
    collapsed_within$edge_type == "within_slice", ]
  expect_identical(collapsed_within$from_state, c(1L, 5L))
  expect_identical(collapsed_within$to_state, c(2L, 6L))
})

test_that("E02 copied attributes use deterministic collision-safe names", {
  nodes <- data.frame(
    name = c("A", "B"), state = c("oldA", "oldB"),
    node_state = c("keepA", "keepB"), active = c(10, 20),
    group = c("g1", "g2"), check.names = FALSE
  )
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1), nodes = nodes,
    observation_start = 0, observation_end = 1
  )
  projection <- projection(dn, step = 1, window = 1)
  vertices <- as.data.frame(projection, what = "vertices")
  expect_identical(
    names(vertices),
    c("state", "slice", "time", "start", "end", "closed", "node", "active",
      "node_node_state", "node_state", "node_active", "group")
  )
  expect_identical(vertices$node_node_state, c("oldA", "oldB"))
  expect_identical(vertices$node_state, c("keepA", "keepB"))
  expect_identical(vertices$node_active, c(10, 20))
  expect_identical(vertices$group, c("g1", "g2"))
  expect_identical(
    projection$meta$node_attribute_renames,
    c(state = "node_node_state", active = "node_active")
  )
})

test_that("E02 validates grids and preserves affine-time structure", {
  edges <- data.frame(
    from = c("A", "B"), to = c("B", "A"), start = c(0, 1), end = c(1, 2)
  )
  base <- quiet_dynet(edges, observation_start = 0, observation_end = 2)
  shifted <- quiet_dynet(
    transform(edges, start = start + 10, end = end + 10),
    observation_start = 10, observation_end = 12
  )
  scaled <- quiet_dynet(
    transform(edges, start = start * 4, end = end * 4),
    observation_start = 0, observation_end = 8
  )
  base_projection <- projection(base, step = 1, window = 1)
  shifted_projection <- projection(shifted, step = 1, window = 1)
  scaled_projection <- projection(scaled, step = 4, window = 4)
  base_vertices <- as.data.frame(base_projection, what = "vertices")
  shifted_vertices <- as.data.frame(shifted_projection, what = "vertices")
  scaled_vertices <- as.data.frame(scaled_projection, what = "vertices")
  expect_identical(shifted_vertices$state, base_vertices$state)
  expect_identical(shifted_vertices$time - 10, base_vertices$time)
  expect_identical(scaled_vertices$state, base_vertices$state)
  expect_identical(scaled_vertices$time / 4, base_vertices$time)

  edge_shape <- function(x) {
    x <- as.data.frame(x, what = "edges")
    x[, c("from_state", "to_state", "edge_type", "n_spells")]
  }
  expect_identical(edge_shape(shifted_projection), edge_shape(base_projection))
  expect_identical(edge_shape(scaled_projection), edge_shape(base_projection))
  expect_equal(
    as.data.frame(scaled_projection, what = "edges")$lag / 4,
    as.data.frame(base_projection, what = "edges")$lag
  )

  expect_error(projection(base, step = 0))
  expect_error(projection(base, window = -1))
  expect_error(projection(base, start = 2, end = 1), class = "dynet_bad_input")
  expect_error(projection(base, start = 10, end = 11),
               class = "dynet_outside_observation")
  expect_error(projection(base, sessions = "separate"),
               class = "dynet_no_sessions")
})

test_that("projection metadata reports the interlayer coupling it actually used", {
  dn <- dynet(school_contacts, format = "contact")

  # Regression: identity_weight was hard-coded to 1 while the arcs carried
  # omega, so the metadata contradicted the data for every omega != 1. The
  # earlier test could not catch it because it only ever used the default.
  for (omega in c(1, 0.5, 0.37, 0)) {
    p <- projection(dn, omega = omega)
    arcs <- as.data.frame(p, what = "edges")
    weights <- unique(arcs$weight[arcs$edge_type == "identity_arc"])

    expect_identical(p$meta$omega, omega)
    expect_identical(p$meta$identity_weight, omega)
    expect_identical(weights, omega)
  }
})

test_that("projection identity arcs join consecutive slices only", {
  # Ordinal (chain) coupling, not categorical. cograph::supra_adjacency()
  # couples every pair of layers, which is wrong for time; this is the
  # property that makes projection() the right substrate for multislice work.
  dn <- dynet(school_contacts, format = "contact")
  arcs <- as.data.frame(projection(dn), what = "edges")
  identity <- arcs[arcs$edge_type == "identity_arc", ]

  expect_true(nrow(identity) > 0)
  expect_identical(unique(identity$to_slice - identity$from_slice), 1L)
  expect_true(all(identity$from_node == identity$to_node))
})
