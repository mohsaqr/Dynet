# `mode` names one or several directions. Several in one call is what removes
# the three-call-and-rbind ritual for degree, in-degree and out-degree.

test_that("several directions come back as one stacked measure column", {
  dn <- dynet(school_contacts)
  got <- as.data.frame(dyn_centrality(dn, measure = "degree",
                                      mode = c("all", "in", "out"),
                                      window = "all"))
  expect_setequal(unique(got$measure), c("degree", "degree_in", "degree_out"))
  n <- nrow(as.data.frame(dn, what = "nodes"))
  expect_identical(nrow(got), 3L * n)
})

test_that("the stacked directions agree with one call each", {
  dn <- dynet(school_contacts)
  stacked <- as.data.frame(dyn_centrality(dn, measure = "degree",
                                          mode = c("in", "out"),
                                          window = "all"))
  alone <- as.data.frame(dyn_centrality(dn, measure = "degree", mode = "in",
                                        window = "all"))
  got <- subset(stacked, measure == "degree_in")
  expect_equal(got$value[match(alone$node, got$node)], alone$value)
})

test_that("a single direction keeps the plain measure name it always had", {
  dn <- dynet(school_contacts)
  expect_identical(
    unique(as.data.frame(dyn_centrality(dn, measure = "degree", mode = "in",
                                        window = "all"))$measure), "degree")
  expect_identical(
    unique(as.data.frame(dyn_centrality(dn, measure = "degree",
                                        window = "all"))$measure), "degree")
})

test_that("a direction-blind measure is not computed once per direction", {
  dn <- dynet(school_contacts)
  got <- as.data.frame(dyn_centrality(dn, measure = "betweenness",
                                      mode = c("in", "out"), window = "all"))
  expect_identical(unique(got$measure), "betweenness")
  expect_identical(nrow(got), nrow(as.data.frame(dn, what = "nodes")))
})

test_that("an undirected network ignores direction without duplicating rows", {
  dn <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                         start = c(0, 1), end = c(1, 2)), directed = FALSE)
  got <- as.data.frame(dyn_centrality(dn, measure = "degree",
                                      mode = c("all", "in", "out"),
                                      window = "all"))
  expect_identical(unique(got$measure), "degree")
})

test_that("mixed measures expand only where direction means something", {
  dn <- dynet(school_contacts)
  got <- as.data.frame(dyn_centrality(dn, measure = c("degree", "betweenness"),
                                      mode = c("all", "in"), window = "all"))
  expect_setequal(unique(got$measure),
                  c("degree", "degree_in", "betweenness"))
})

test_that("several directions are still refused at temporal scope", {
  dn <- dynet(school_contacts)
  expect_error(dyn_centrality(dn, measure = "closeness", scope = "temporal",
                              mode = c("in", "out")),
               class = "dynet_bad_input")
})

test_that("an unknown direction is refused", {
  dn <- dynet(school_contacts)
  expect_error(dyn_centrality(dn, measure = "degree", mode = c("in", "sideways")),
               class = "dynet_bad_input")
})
