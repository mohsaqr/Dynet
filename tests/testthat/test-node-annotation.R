# as.data.frame(dn, what = "nodes", measure = ) annotates the vertex table so a
# selection can be made with subset() instead of reshaping a measure frame.

test_that("each measure becomes one column, one row per vertex", {
  dn <- dynet(school_contacts)
  got <- as.data.frame(dn, what = "nodes",
                       measure = c("degree", "indegree", "outdegree"))
  expect_identical(nrow(got), nrow(as.data.frame(dn, what = "nodes")))
  expect_true(all(c("name", "degree", "indegree", "outdegree") %in% names(got)))
  expect_false(anyNA(got$degree))
})

test_that("the annotation is the whole-period centrality, not a first bin", {
  dn <- dynet(school_contacts)
  annotated <- as.data.frame(dn, what = "nodes", measure = "degree")
  direct <- as.data.frame(dyn_centrality(dn, measure = "degree",
                                         window = "all"))
  expect_equal(annotated$degree[match(direct$node, annotated$name)],
               direct$value)
})

test_that("in- and out-degree sum to degree on a directed network", {
  dn <- dynet(data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"),
                         start = c(0, 1, 2), end = c(1, 2, 3)))
  got <- as.data.frame(dn, what = "nodes",
                       measure = c("degree", "indegree", "outdegree"))
  expect_equal(got$indegree + got$outdegree, got$degree)
})

test_that("attributes survive the annotation", {
  dn <- dynet(school_contacts, nodes = data.frame(
    name = unique(c(school_contacts$from, school_contacts$to)), room = "A"))
  got <- as.data.frame(dn, what = "nodes", measure = "degree")
  expect_true("room" %in% names(got))
  expect_identical(unique(got$room), "A")
})

test_that("sessions are reported separately when asked", {
  dn <- dynet(data.frame(from = c("A", "B", "A"), to = c("B", "C", "C"),
                         start = c(0, 10, 20), end = c(1, 11, 21),
                         session = c("s1", "s1", "s2")),
              session = "session")
  got <- as.data.frame(dn, what = "nodes", measure = "degree",
                       sessions = "separate")
  expect_true("session" %in% names(got))
  expect_identical(sort(unique(got$session)), c("s1", "s2"))
})

test_that("the annotated table filters with subset and needs no reach-in", {
  dn <- dynet(school_contacts)
  busy <- subset(as.data.frame(dn, what = "nodes", measure = "degree"),
                 degree > 16)
  expect_gt(nrow(busy), 0L)
  expect_true(all(busy$degree > 16))
})

test_that("`measure` is refused for every other table", {
  dn <- dynet(school_contacts)
  expect_error(as.data.frame(dn, what = "edges", measure = "degree"),
               class = "dynet_bad_input")
  expect_error(as.data.frame(dn, what = "network", measure = "degree"),
               class = "dynet_bad_input")
})

test_that("an unknown measure is refused by the measure vocabulary", {
  dn <- dynet(school_contacts)
  expect_error(as.data.frame(dn, what = "nodes", measure = "notameasure"),
               class = "dynet_unknown_measure")
})
