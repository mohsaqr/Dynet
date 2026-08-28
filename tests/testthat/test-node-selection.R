# induce_subgraph() reads vertex names out of whatever result the caller
# filtered, so a selection never has to be extracted with `$`.

test_that("a node-bearing data frame selects the same subgraph as its names", {
  dn <- dynet(school_contacts)
  busy <- subset(as.data.frame(dn, what = "nodes", measure = "degree"),
                 degree > 16)
  from_frame <- induce_subgraph(dn, nodes = busy)
  from_names <- induce_subgraph(dn, nodes = busy$name)
  expect_identical(as.data.frame(from_frame), as.data.frame(from_names))
})

test_that("a `node` column is read as well as a `name` column", {
  dn <- dynet(school_contacts)
  top <- subset(as.data.frame(dyn_centrality(dn, measure = "degree",
                                             window = "all")), value > 16)
  expect_true("node" %in% names(top))
  sub <- induce_subgraph(dn, nodes = top)
  expect_setequal(as.data.frame(sub, what = "nodes")$name, top$node)
})

test_that("a factor of names is accepted", {
  dn <- dynet(school_contacts)
  keep <- utils::head(as.data.frame(dn, what = "nodes")$name, 6L)
  expect_identical(
    as.data.frame(induce_subgraph(dn, nodes = factor(keep))),
    as.data.frame(induce_subgraph(dn, nodes = keep)))
})

test_that("a frame with no vertex column says so", {
  dn <- dynet(school_contacts)
  expect_error(induce_subgraph(dn, nodes = data.frame(x = 1:2)),
               class = "dynet_unknown_node")
})

test_that("an unknown vertex is still refused when it arrives in a frame", {
  dn <- dynet(school_contacts)
  expect_error(induce_subgraph(dn, nodes = data.frame(name = "Nobody")),
               class = "dynet_unknown_node")
})

test_that("a condition on the vertex table selects in one call", {
  dn <- dynet(school_contacts)
  direct <- induce_subgraph(dn, degree > 16)
  staged <- induce_subgraph(dn, nodes = subset(
    as.data.frame(dn, what = "nodes", measure = "degree"), degree > 16))
  expect_identical(as.data.frame(direct), as.data.frame(staged))
})

test_that("a condition may name several measures and an attribute", {
  dn <- dynet(school_contacts, nodes = data.frame(
    name = unique(c(school_contacts$from, school_contacts$to)),
    room = rep(c("A", "B"), length.out = 14L)))
  got <- as.data.frame(
    induce_subgraph(dn, degree > 12 & betweenness > 0 & room == "A"),
    what = "nodes")
  expect_gt(nrow(got), 0L)
  expect_identical(unique(got$room), "A")
})

test_that("the vertex table shadows the calling frame, as subset() does", {
  # `sna::degree` is a function in scope during the equivalence checks. The
  # measure must still win, or a condition would silently compare a function.
  dn <- dynet(school_contacts)
  degree <- function(...) stop("must not be called")
  expect_s3_class(induce_subgraph(dn, degree > 16), "dynet")
})

test_that("a variable that is not a measure resolves from the caller", {
  dn <- dynet(school_contacts)
  keep <- c("Jonas", "Dan")
  expect_setequal(
    as.data.frame(induce_subgraph(dn, nodes = keep), what = "nodes")$name,
    keep)
})

test_that("a logical mask must have one value per vertex", {
  dn <- dynet(school_contacts)
  expect_error(induce_subgraph(dn, nodes = c(TRUE, FALSE)),
               class = "dynet_bad_input")
})

test_that("a condition that selects nothing says so", {
  dn <- dynet(school_contacts)
  expect_error(induce_subgraph(dn, degree > 1e6),
               class = "dynet_empty_network")
})
