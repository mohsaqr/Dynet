test_that("add_ties is immutable and rebuilds the cograph projection", {
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1, w = 1),
    weight = "w", nodes = data.frame(name = c("A", "B", "C"))
  )
  dn <- add_nodes(dn, "C")
  changed <- add_ties(dn, data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0.5, 1), end = c(2, 3), weight = c(2, 4)
  ))

  expect_equal(nrow(as.data.frame(dn, what = "edges")), 1)
  expect_equal(nrow(as.data.frame(changed, what = "edges")), 3)
  expect_s3_class(changed, "dynet")
  expect_s3_class(changed, "cograph_network")
  flat <- as.data.frame(changed, what = "network")
  expect_equal(flat$weight[flat$from == "A" & flat$to == "B"], 3)
  expect_equal(flat$weight[flat$from == "B" & flat$to == "C"], 4)
  expect_equal(unname(changed$meta$time_range), c(0, 3))
})

test_that("explicit observation support does not expand when ties are added", {
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    observation_start = 0, observation_end = 2,
    nodes = data.frame(name = c("A", "B", "C"))
  )
  dn <- add_nodes(dn, "C")
  changed <- add_ties(dn, data.frame(
    from = "B", to = "C", start = 3, end = 4
  ))
  expect_equal(unname(changed$meta$time_range), c(0, 2))
  expect_equal(unname(changed$meta$event_range), c(0, 4))
  expect_equal(nrow(as.data.frame(changed, what = "observed_edges")), 1)
})

test_that("undirected additions canonicalize endpoints and arcs require direction", {
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    directed = FALSE, nodes = data.frame(name = c("A", "B", "C"))
  )
  dn <- add_nodes(dn, "C")
  changed <- add_ties(dn, data.frame(
    from = "C", to = "A", start = 1, end = 2
  ))
  ties <- as.data.frame(changed, what = "edges")
  expect_true(any(ties$from == "A" & ties$to == "C"))
  expect_error(add_arcs(dn, data.frame(
    from = "A", to = "C", start = 1, end = 2
  )), class = "dynet_needs_directed")
  expect_error(remove_arcs(dn, ties = 1), class = "dynet_needs_directed")
})

test_that("undirected cograph projection survives a node inserted before existing names", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1),
              directed = FALSE)
  dn <- add_nodes(dn, "0")
  changed <- add_ties(dn, data.frame(
    from = "A", to = "0", start = 1, end = 2
  ))
  flat <- as.data.frame(changed, what = "network")
  expect_true(any(flat$from == "0" & flat$to == "A"))
  expect_equal(nrow(flat), 2)
})

test_that("add_arcs delegates on a directed network", {
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    nodes = data.frame(name = c("A", "B", "C"))
  )
  dn <- add_nodes(dn, "C")
  changed <- add_arcs(dn, data.frame(
    from = "C", to = "A", start = 1, end = 2
  ))
  expect_equal(nrow(as.data.frame(changed, what = "edges")), 2)
})

test_that("tie additions validate nodes, clocks, loops, sessions, and censoring", {
  dn <- dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"), start = 0, end = 1,
    session = c("s1", "s2")
  ), session = "session")

  expect_error(add_ties(dn, data.frame(
    from = "A", to = "D", start = 1, end = 2, session = "s1"
  )), class = "dynet_unknown_node")
  expect_error(add_ties(dn, data.frame(
    from = "A", to = "C", start = 2, end = 1, session = "s1"
  )), class = "dynet_bad_input")
  expect_error(add_ties(dn, data.frame(
    from = "A", to = "A", start = 1, end = 2, session = "s1"
  )), class = "dynet_loop_not_allowed")
  expect_error(add_ties(dn, data.frame(
    from = "A", to = "C", start = 1, end = 2
  )), class = "dynet_missing_session")
  expect_error(add_ties(dn, data.frame(
    from = "A", to = "C", start = 1, end = 2, session = "new"
  )), class = "dynet_unknown_session")

  changed <- add_ties(dn, data.frame(
    from = "A", to = "C", start = 1, end = 2, session = "s1",
    onset_censored = TRUE, terminus_censored = FALSE
  ))
  expect_identical(changed$meta$raw_censoring, "explicit")
  expect_identical(changed$meta$n_onset_censored, 1L)
})

test_that("remove_ties accepts exact positions and explicit selectors", {
  dn <- dynet(data.frame(
    from = c("A", "A", "B"), to = c("B", "B", "C"),
    start = c(0, 1, 2), end = c(1, 2, 3)
  ))
  one <- remove_ties(dn, ties = 2)
  expect_equal(nrow(as.data.frame(one, what = "edges")), 2)
  expect_false(any(as.data.frame(one, what = "edges")$start == 1))

  pair <- remove_ties(dn, from = "A", to = "B")
  expect_equal(nrow(as.data.frame(pair, what = "edges")), 1)
  expect_identical(as.data.frame(pair, what = "edges")$from, "B")
  expect_error(remove_ties(dn), class = "dynet_missing_tie_selector")
  expect_error(remove_ties(dn, ties = c(1, 2, 3)),
               class = "dynet_empty_network")
})

test_that("removal selectors can distinguish time and session", {
  dn <- dynet(data.frame(
    from = c("A", "A", "A"), to = c("B", "B", "B"),
    start = c(0, 1, 1), end = c(1, 2, 2),
    session = c("s1", "s1", "s2")
  ), session = "session")
  changed <- remove_ties(
    dn, from = "A", to = "B", start = 1, session = "s1"
  )
  ties <- as.data.frame(changed, what = "edges")
  expect_equal(nrow(ties), 2)
  expect_true(any(ties$session == "s2" & ties$start == 1))
})

test_that("nodes can be added as isolates and removed safely", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
  added <- add_nodes(dn, data.frame(name = "C", role = "observer"))
  expect_true("C" %in% as.data.frame(added, what = "nodes")$name)
  expect_equal(nrow(as.data.frame(dn, what = "nodes")), 2)
  restored <- remove_nodes(added, "C")
  expect_identical(as.data.frame(restored, what = "nodes")$name,
                   as.data.frame(dn, what = "nodes")$name)
  expect_error(remove_nodes(dn, "A"), class = "dynet_node_not_isolate")
})

test_that("node-only edits preserve the source format label", {
  dn <- dynet(data.frame(from = "A", to = "B", when = 1), time = "when")
  added <- add_nodes(dn, "C")
  expect_identical(added$meta$format, "contact")
  expect_identical(remove_nodes(added, "C")$meta$format, "contact")
})

test_that("cascade node removal removes incident temporal identities", {
  dn <- dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 1), end = c(1, 2)
  ))
  changed <- remove_nodes(dn, "A", cascade = TRUE)
  expect_identical(as.data.frame(changed, what = "nodes")$name, c("B", "C"))
  expect_equal(nrow(as.data.frame(changed, what = "edges")), 1)
})

test_that("calendar additions use the existing origin and unit", {
  dn <- dynet(data.frame(
    from = "A", to = "B",
    start = as.Date("2026-01-01"), end = as.Date("2026-01-02")
  ))
  dn <- add_nodes(dn, "C")
  changed <- add_ties(dn, data.frame(
    from = "B", to = "C",
    start = as.Date("2026-01-03"), end = as.Date("2026-01-04")
  ))
  ties <- as.data.frame(changed, what = "edges")
  one_day <- as.data.frame(dn, what = "edges")$end[[1L]]
  expect_equal(ties$start[ties$to == "C"], 2 * one_day)
  expect_equal(ties$end[ties$to == "C"], 3 * one_day)
  expect_identical(changed$meta$origin, dn$meta$origin)
})

test_that("grouped node additions preserve cograph grouping", {
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    nodes = data.frame(name = c("A", "B"), role = c("x", "y")),
    groups = "role"
  )
  changed <- add_nodes(dn, data.frame(name = "C", role = "x"))
  expect_identical(changed$node_groups$group[changed$node_groups$node == "C"],
                   "x")
  expect_error(add_nodes(dn, "C"), class = "dynet_missing_group")
})

test_that("editing preserves the established empty-string vertex label", {
  dn <- dynet(data.frame(from = "", to = "B", start = 0, end = 1))
  dn <- add_nodes(dn, "C")
  changed <- add_ties(dn, data.frame(
    from = c("", "B"), to = c("C", "C"), start = c(1, 2), end = c(2, 3)
  ))
  expect_true(any(as.data.frame(changed, what = "edges")$from == ""))
  removed <- remove_nodes(changed, "", cascade = TRUE)
  expect_false("" %in% as.data.frame(removed, what = "nodes")$name)
})

test_that("new classed node attributes retain their declared type", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
  changed <- add_nodes(dn, data.frame(
    name = c("C", "D"),
    joined = as.Date(c("2026-01-03", "2026-01-04")),
    cohort = factor(c("x", "y"))
  ))
  nodes <- as.data.frame(changed, what = "nodes")
  expect_s3_class(nodes$joined, "Date")
  expect_true(is.factor(nodes$cohort))
  expect_true(all(is.na(nodes$joined[nodes$name %in% c("A", "B")])))
  expect_identical(as.character(nodes$cohort[nodes$name %in% c("C", "D")]),
                   c("x", "y"))
})
