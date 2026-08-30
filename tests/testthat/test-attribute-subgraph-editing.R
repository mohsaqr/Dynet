test_that("node attributes update immutably and can be added", {
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    nodes = data.frame(name = c("A", "B"), role = factor(c("x", "y")))
  )
  changed <- update_nodes(dn, data.frame(
    name = c("A", "B"), role = c("lead", "y"), score = c(2, 3)
  ))
  nodes <- as.data.frame(changed, what = "nodes")
  expect_true(is.factor(nodes$role))
  expect_identical(as.character(nodes$role), c("lead", "y"))
  expect_equal(nodes$score, c(2, 3))
  expect_false("score" %in% names(as.data.frame(dn, what = "nodes")))
})

test_that("node renaming changes ties, activity, and cograph labels together", {
  dn <- dynet(
    data.frame(from = c("A", "B"), to = c("B", "C"), start = 0, end = 2),
    vertex_spells = data.frame(node = "A", start = 0, end = 1)
  )
  changed <- rename_nodes(dn, c(A = "Alpha", C = "Gamma"))
  expect_setequal(as.data.frame(changed, what = "nodes")$name,
                  c("Alpha", "B", "Gamma"))
  expect_true(any(as.data.frame(changed)$from == "Alpha"))
  expect_true(any(as.data.frame(changed)$to == "Gamma"))
  expect_identical(as.data.frame(changed, what = "vertex_spells")$node,
                   "Alpha")
  expect_error(rename_nodes(dn, c(A = "B")), class = "dynet_duplicate_node")
})

test_that("tie updates replace canonical fields and preserve arbitrary attributes", {
  dn <- dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 1), end = c(1, 2)
  ))
  changed <- update_ties(dn, 2, data.frame(
    from = "A", start = 2, end = 4, weight = 3, kind = "reply"
  ))
  ties <- as.data.frame(changed)
  edited <- ties[ties$end == 4, ]
  expect_identical(edited$from, "A")
  expect_identical(edited$to, "C")
  expect_equal(edited$weight, 3)
  expect_identical(edited$kind, "reply")
  expect_true(is.na(ties$kind[ties$end == 1]))
  expect_equal(nrow(as.data.frame(dn)), 2)
})

test_that("tie endpoint updates require explicit permission for new loops", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
  expect_error(update_ties(dn, 1, data.frame(to = "A")),
               class = "dynet_loop_not_allowed")
  changed <- update_ties(dn, 1, data.frame(to = "A"), loops = TRUE)
  expect_identical(as.data.frame(changed)$from, "A")
  expect_identical(as.data.frame(changed)$to, "A")
})

test_that("temporal subgraphs select raw spell attributes and induced nodes", {
  dn <- dynet(data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"),
    start = 0:2, end = 1:3
  ), nodes = data.frame(name = LETTERS[1:5], role = 1:5))
  dn <- add_nodes(dn, data.frame(name = "E", role = 5))
  dn <- update_ties(dn, 1:3, data.frame(course = c("g1", "g1", "g2")))

  group <- induce_subgraph(dn, ties = as.data.frame(dn)$course == "g1")
  expect_equal(nrow(as.data.frame(group)), 2)
  expect_setequal(as.data.frame(group, what = "nodes")$name, c("A", "B", "C"))
  expect_identical(as.data.frame(group)$course, c("g1", "g1"))

  nodes <- induce_subgraph(dn, nodes = c("A", "B", "E"), keep_isolates = TRUE)
  expect_setequal(as.data.frame(nodes, what = "nodes")$name, c("A", "B", "E"))
  expect_equal(nrow(as.data.frame(nodes)), 1)
})

test_that("`ties` accepts a condition on the spell table, as `nodes` does", {
  dn <- dynet(data.frame(
    from = c("A", "B", "C"), to = c("B", "C", "D"),
    start = 0:2, end = c(1, 4, 3)
  ), nodes = data.frame(name = LETTERS[1:5], role = 1:5))
  dn <- update_ties(dn, 1:3, data.frame(course = c("g1", "g1", "g2")))

  # The capability that was missing: a bare condition on a tie attribute.
  # Before this, only `nodes` evaluated a condition and `ties` raised
  # "object 'course' not found", which forced the caller to hand-build a mask
  # with `as.data.frame(dn)$course == "g1"` -- the ritual Rule 0 forbids.
  by_attribute <- induce_subgraph(dn, ties = course == "g1")
  expect_identical(as.data.frame(by_attribute)$course, c("g1", "g1"))
  expect_setequal(as.data.frame(by_attribute, what = "nodes")$name,
                  c("A", "B", "C"))

  # A structural column of the spell table works the same way.
  expect_identical(nrow(as.data.frame(induce_subgraph(dn, ties = duration > 1))), 1L)

  # Conditions on both tables compose.
  expect_identical(
    nrow(as.data.frame(induce_subgraph(dn, nodes = role < 4, ties = course == "g1"))),
    2L
  )

  # Every previously supported form still resolves identically.
  mask <- c(TRUE, TRUE, FALSE)
  expect_identical(as.data.frame(induce_subgraph(dn, ties = mask)),
                   as.data.frame(by_attribute))
  expect_identical(as.data.frame(induce_subgraph(dn, ties = 1:2)),
                   as.data.frame(by_attribute))
  expect_identical(
    as.data.frame(induce_subgraph(dn, ties = as.data.frame(dn)$course == "g1")),
    as.data.frame(by_attribute)
  )

  expect_error(induce_subgraph(dn, ties = no_such_column == 1),
               class = "simpleError")
  expect_error(induce_subgraph(dn, ties = c(TRUE, FALSE)),
               class = "dynet_bad_input")
  expect_error(induce_subgraph(dn), class = "dynet_bad_input")
})
