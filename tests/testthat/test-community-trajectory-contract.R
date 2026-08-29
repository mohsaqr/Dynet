# Item 6: per-vertex measures over a matched partition.
#
# The reference values below were produced by running teneto 0.5.3's
# communitymeasures module in this session, not transcribed from a paper, so
# this is a genuine cross-language equivalence check.

teneto_fixture <- function() {
  nodes <- sprintf("n%d", 1:6)
  labels <- rbind(c(0, 0, 0, 0), c(0, 0, 0, 0), c(0, 0, 0, 0),
                  c(1, 1, 1, 1), c(1, 1, 1, 1), c(0, 0, 1, 1))
  dimnames(labels) <- list(nodes, NULL)
  hand_partition(labels, times = 0:3,
                 attributes = list(class = c(0, 0, 0, 1, 1, 0)))
}

test_that("unmatched labels are refused, because they would measure noise", {
  # The guard that gives the whole item its meaning: if the labels are per-bin
  # arbitrary, flexibility counts relabelling and nothing else.
  x <- teneto_fixture()
  attr(x, "matched") <- FALSE
  expect_error(community_trajectory(x), class = "dynet_unmatched_labels")
  expect_error(community_trajectory(data.frame(a = 1)),
               class = "dynet_bad_input")
  expect_error(community_trajectory(teneto_fixture(), measure = "cohesion"),
               class = "dynet_unknown_measure")
})

test_that("recruitment and integration refuse to run without a reference", {
  x <- teneto_fixture()
  expect_error(community_trajectory(x, measure = "recruitment"),
               class = "dynet_bad_input")
  expect_error(community_trajectory(x, measure = "integration",
                                    reference = "cohort"),
               class = "dynet_unknown_attribute")
})

test_that("one bin has no consecutive pair, so nothing here is defined", {
  nodes <- sprintf("n%d", 1:4)
  one <- hand_partition(matrix(1L, 4L, 1L, dimnames = list(nodes, NULL)),
                        times = 0)
  expect_error(community_trajectory(one), class = "dynet_empty_result")
})

test_that("every measure equals teneto 0.5.3 on the reference fixture", {
  x <- teneto_fixture()
  got <- as.data.frame(community_trajectory(
    x, measure = c("flexibility", "promiscuity", "persistence",
                   "recruitment", "integration"), reference = "class"))
  value <- function(m) got$value[got$measure == m]
  expect_equal(value("flexibility"), c(0, 0, 0, 0, 0, 1 / 3),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(value("promiscuity"), c(0, 0, 0, 0, 0, 1),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(value("persistence"), c(1, 1, 1, 1, 1, 2 / 3),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(value("recruitment"), c(5 / 6, 5 / 6, 5 / 6, 1, 1, 0.5),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(value("integration"), c(0, 0, 0, 0.125, 0.125, 0.5),
               tolerance = sqrt(.Machine$double.eps))

  trajectory <- community_trajectory(x)
  expect_equal(as.data.frame(trajectory, what = "global")$value, 17 / 18,
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(as.data.frame(trajectory, what = "time")$value,
               c(NA, 1, 5 / 6, 1), tolerance = sqrt(.Machine$double.eps))
  allegiance <- as.data.frame(trajectory, what = "allegiance")
  pair <- function(i, j) allegiance$value[allegiance$node == i &
                                            allegiance$other == j]
  expect_equal(pair("n1", "n2"), 1)
  expect_equal(pair("n1", "n4"), 0)
  expect_equal(pair("n1", "n6"), 0.5)
  expect_equal(pair("n4", "n6"), 0.5)
  expect_true(all(is.na(allegiance$value[allegiance$node ==
                                           allegiance$other])))
})

test_that("the persistence normaliser is T - 1, and the test can see it", {
  # A deliberate break: dividing by T instead of T - 1 must fail the
  # equivalence above. Confirmed here on the same fixture so the check is not
  # merely asserted.
  x <- teneto_fixture()
  got <- as.data.frame(community_trajectory(x, measure = "persistence"))
  wrong <- c(1, 1, 1, 1, 1, 2 / 3) * 3 / 4
  expect_false(isTRUE(all.equal(got$value, wrong)))
  expect_equal(got$value[[6L]], 2 / 3, tolerance = sqrt(.Machine$double.eps))
})

test_that("a global relabelling changes nothing", {
  x <- teneto_fixture()
  reference <- as.data.frame(community_trajectory(
    x, measure = c("flexibility", "promiscuity", "persistence")))
  relabelled <- x
  relabelled$community <- ifelse(x$community == 0, 7, 4)
  got <- as.data.frame(community_trajectory(
    relabelled, measure = c("flexibility", "promiscuity", "persistence")))
  expect_equal(got$value, reference$value)
})

test_that("permuting the vertices permutes the rows and nothing else", {
  x <- teneto_fixture()
  reference <- as.data.frame(community_trajectory(x, measure = "flexibility"))
  set.seed(2)
  shuffled <- x[sample(nrow(x)), ]
  attributes(shuffled) <- utils::modifyList(
    attributes(x)[setdiff(names(attributes(x)), "row.names")],
    list(row.names = seq_len(nrow(x))))
  got <- as.data.frame(community_trajectory(shuffled, measure = "flexibility"))
  expect_equal(got$value[match(reference$node, got$node)], reference$value)
})

test_that("every measure stays inside its unit interval", {
  set.seed(31)
  for (trial in seq_len(50L)) {
    n <- sample(4:10, 1L)
    bins <- sample(3:8, 1L)
    nodes <- sprintf("n%02d", seq_len(n))
    labels <- matrix(sample.int(3L, n * bins, replace = TRUE), n, bins,
                     dimnames = list(nodes, NULL))
    x <- hand_partition(labels,
                        attributes = list(class = rep(1:2, length.out = n)))
    got <- as.data.frame(community_trajectory(
      x, measure = c("flexibility", "promiscuity", "persistence",
                     "recruitment", "integration"), reference = "class"))
    inside <- got$value[!is.na(got$value)]
    expect_true(all(inside >= 0 & inside <= 1))
    allegiance <- as.data.frame(community_trajectory(x), what = "allegiance")
    off <- allegiance$value[!is.na(allegiance$value)]
    expect_true(all(off >= 0 & off <= 1))
  }
})

test_that("flexibility hits both of its endpoints exactly", {
  nodes <- sprintf("n%d", 1:4)
  still <- hand_partition(matrix(1L, 4L, 5L, dimnames = list(nodes, NULL)))
  expect_true(all(as.data.frame(community_trajectory(
    still, measure = "flexibility"))$value == 0))
  restless <- hand_partition(matrix(rep(seq_len(5L), each = 4L), 4L, 5L,
                                    dimnames = list(nodes, NULL)))
  expect_true(all(as.data.frame(community_trajectory(
    restless, measure = "flexibility"))$value == 1))
})

test_that("allegiance is symmetric with an undefined diagonal", {
  set.seed(12)
  nodes <- sprintf("n%d", 1:7)
  labels <- matrix(sample.int(3L, 35L, replace = TRUE), 7L, 5L,
                   dimnames = list(nodes, NULL))
  allegiance <- as.data.frame(
    community_trajectory(hand_partition(labels)), what = "allegiance")
  mirrored <- merge(allegiance, allegiance, by.x = c("node", "other"),
                    by.y = c("other", "node"))
  expect_equal(mirrored$value.x, mirrored$value.y)
  expect_true(all(is.na(allegiance$value[allegiance$node ==
                                           allegiance$other])))
})

test_that("recruitment and integration decompose the off-diagonal allegiance", {
  # With two reference groups every off-diagonal pair is counted exactly once
  # by one of the two, so their size-weighted mean is the overall mean.
  set.seed(19)
  nodes <- sprintf("n%d", 1:8)
  labels <- matrix(sample.int(2L, 40L, replace = TRUE), 8L, 5L,
                   dimnames = list(nodes, NULL))
  group <- rep(1:2, each = 4L)
  x <- hand_partition(labels, attributes = list(class = group))
  trajectory <- community_trajectory(
    x, measure = c("recruitment", "integration"), reference = "class")
  got <- as.data.frame(trajectory)
  allegiance <- as.data.frame(trajectory, what = "allegiance")
  overall <- mean(allegiance$value[!is.na(allegiance$value)])
  recruit <- got$value[got$measure == "recruitment"]
  integrate <- got$value[got$measure == "integration"]
  expect_equal(mean(recruit * 3 / 7 + integrate * 4 / 7), overall,
               tolerance = sqrt(.Machine$double.eps))
})

test_that("a partition from the verb itself flows straight in", {
  dn <- dynet(school_contacts, format = "contact")
  found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
  got <- community_trajectory(found)
  expect_s3_class(got, "dynet_metric")
  expect_identical(nrow(as.data.frame(got)),
                   length(unique(found$node)) * 3L)
  expect_identical(attr(got, "n_inactive_states"), sum(!found$active))
})
