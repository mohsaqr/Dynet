test_that("networkDynamic import retains temporal structure and static attributes", {
  skip_if_not_installed("network")
  skip_if_not_installed("networkDynamic")
  legacy <- networkDynamic::networkDynamic(
    base.net = NULL,
    edge.spells = data.frame(
      onset = c(0, 1), terminus = c(2, 3),
      tail = c(1, 2), head = c(2, 3)
    ),
    create.TEAs = TRUE
  )
  network::set.vertex.attribute(legacy, "Name", c("A", "B", "C"))
  network::set.vertex.attribute(legacy, "role", c("x", "x", "y"))
  network::set.edge.attribute(legacy, "weight", c(2, 4))
  network::set.edge.attribute(legacy, "kind", c("first", "second"))

  dn <- as_dynet(legacy, group_attribute = "role")
  ties <- as.data.frame(dn)
  expect_s3_class(dn, "dynet")
  expect_identical(as.data.frame(dn, what = "nodes")$name, c("A", "B", "C"))
  expect_equal(ties$weight, c(2, 4))
  expect_identical(ties$kind, c("first", "second"))
  expect_identical(dn$meta$legacy_source, "networkDynamic")
  expect_identical(dn$node_groups$group, c("x", "x", "y"))
  expect_equal(unname(dn$meta$time_range), c(0, 3))
})

test_that("networkDynamic import prefers semantic Name over integer vertex.names", {
  skip_if_not_installed("network")
  skip_if_not_installed("networkDynamic")
  legacy <- networkDynamic::networkDynamic(
    base.net = NULL,
    edge.spells = data.frame(onset = 0, terminus = 1, tail = 1, head = 2)
  )
  network::set.vertex.attribute(legacy, "Name", c("Sender", "Receiver"))
  dn <- as_dynet(legacy)
  expect_identical(as.data.frame(dn, what = "nodes")$name,
                   c("Receiver", "Sender"))
  expect_setequal(as.data.frame(dn)$from, "Sender")
  expect_setequal(as.data.frame(dn)$to, "Receiver")
})

test_that("collapse reports union, additive, weighted, and legacy duration fields", {
  dn <- dynet(data.frame(
    from = c("A", "A", "A", "B"),
    to = c("B", "B", "B", "C"),
    start = c(0, 1, 4, 0), end = c(2, 3, 4, 1),
    weight = c(2, 3, 5, 7)
  ), weight = "weight", observation_start = 0, observation_end = 4)
  flat <- collapse_network(dn, weight = "union_duration")
  edges <- as.data.frame(flat)
  ab <- edges[edges$from == "A" & edges$to == "B", ]

  expect_s3_class(flat, "cograph_network")
  expect_equal(ab$union_duration, 3)
  expect_equal(ab$total_duration, 4)
  expect_equal(ab$duration_fraction, 0.75)
  expect_equal(ab$spell_count, 3)
  expect_equal(ab$weight_sum, 10)
  expect_equal(ab$weighted_duration, 10)
  expect_equal(ab$latest_weight, 5)
  expect_equal(ab$activity.duration, ab$union_duration)
  expect_equal(ab$activity.count, ab$spell_count)
  expect_equal(flat$edges$weight[flat$edges$from == match("A", flat$nodes$name) &
                                   flat$edges$to == match("B", flat$nodes$name)], 3)
})

test_that("collapse clips a range and uses exact endpoint opportunity", {
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 5),
    observation_start = 0, observation_end = 5,
    vertex_spells = data.frame(
      node = c("A", "B"), start = c(0, 1), end = c(4, 3)
    )
  )
  flat <- collapse_network(dn, start = 0.5, end = 4.5,
                           weight = "duration_fraction")
  edge <- as.data.frame(flat)
  expect_equal(edge$union_duration, 2)
  expect_equal(edge$total_duration, 2)
  expect_equal(edge$duration_fraction, 1)
  nodes <- as.data.frame(flat, what = "nodes")
  expect_equal(nodes$activity_duration[nodes$name == "A"], 3.5)
  expect_equal(nodes$activity_duration[nodes$name == "B"], 2)
})

test_that("collapse can return separate session-specific cograph networks", {
  dn <- dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 0), end = c(2, 3), session = c("s1", "s2")
  ), session = "session")
  out <- collapse_network(dn, sessions = "separate")
  expect_s3_class(out, "dynet_collapsed_list")
  expect_identical(names(out), c("s1", "s2"))
  expect_equal(as.data.frame(out$s1)$union_duration, 2)
  expect_equal(as.data.frame(out$s2)$union_duration, 3)
})

test_that("tie mutation preserves imported and newly supplied attributes", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
  dn <- add_nodes(dn, "C")
  changed <- add_ties(dn, data.frame(
    from = "B", to = "C", start = 1, end = 2, kind = "reply"
  ))
  ties <- as.data.frame(changed)
  expect_true("kind" %in% names(ties))
  expect_true(is.na(ties$kind[ties$from == "A"]))
  expect_identical(ties$kind[ties$from == "B"], "reply")
  retained <- remove_ties(changed, ties = 1)
  expect_identical(as.data.frame(retained)$kind, "reply")
})

