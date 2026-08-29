test_that("an unknown edge measure is rejected by class", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(edge_centrality(dn, measure = "closeness"),
               class = "dynet_unknown_measure")
})

test_that("contact betweenness reconciles exactly with vertex betweenness", {
  # The binding oracle, and it needs no external package. Every optimal
  # journey is vertex-simple, so it enters each vertex through exactly one
  # contact. The contacts arriving at a vertex therefore carry that vertex's
  # temporal betweenness, plus one unit for each source that reaches it (those
  # journeys end there, so the vertex form scores them zero).
  dn <- dynet(school_contacts, format = "contact")
  edges <- as.data.frame(edge_centrality(dn))
  nodes <- as.data.frame(dyn_centrality(dn, measure = "betweenness",
                                        scope = "temporal"))
  reach <- as.data.frame(dyn_reachability(dn, measure = "reach_count",
                                          direction = "backward"))

  into <- vapply(nodes$node, function(v) sum(edges$value[edges$to == v]),
                 numeric(1L))
  in_reach <- reach$value[match(nodes$node, reach$node)]
  expect_equal(unname(into), nodes$value + in_reach)
})

test_that("the identity also holds under min_hops", {
  dn <- dynet(school_contacts, format = "contact")
  edges <- as.data.frame(edge_centrality(dn, criterion = "min_hops"))
  nodes <- as.data.frame(dyn_centrality(dn, measure = "betweenness",
                                        scope = "temporal",
                                        criterion = "min_hops"))
  reach <- as.data.frame(dyn_reachability(dn, measure = "reach_count",
                                          direction = "backward"))
  into <- vapply(nodes$node, function(v) sum(edges$value[edges$to == v]),
                 numeric(1L))
  in_reach <- reach$value[match(nodes$node, reach$node)]
  expect_equal(unname(into), nodes$value + in_reach)
})

test_that("a tied diamond splits credit evenly over its contacts", {
  # Two equally optimal journeys A->B->D and A->C->D. Each of the four
  # contacts carries 1 for its own endpoint pair plus 0.5 for the tied A->D
  # pair.
  dn <- dynet(
    data.frame(from = c("A", "A", "B", "C"), to = c("B", "C", "D", "D"),
               time = c(0, 0, 1, 1)),
    format = "contact", directed = TRUE,
    nodes = data.frame(name = c("A", "B", "C", "D")),
    observation_start = 0, observation_end = 2)
  out <- as.data.frame(edge_centrality(dn))
  expect_identical(nrow(out), 4L)
  expect_equal(out$value, rep(1.5, 4L))
})

test_that("the census keeps every contact, including unused ones", {
  # A contact used by no optimal journey is present with value zero. Dropping
  # it would force the caller to rebuild the contact list to find out.
  dn <- dynet(school_contacts, format = "contact")
  out <- as.data.frame(edge_centrality(dn))
  expect_identical(nrow(out), 240L)
  expect_true(any(out$value == 0))
  expect_true(all(out$value >= 0))
})

test_that("the result is an edge-level metric with the contact columns", {
  dn <- dynet(school_contacts, format = "contact")
  out <- edge_centrality(dn)
  expect_s3_class(out, "dynet_metric")
  expect_true(all(c("from", "to", "start", "end", "measure", "value") %in%
                    names(as.data.frame(out))))
  expect_identical(attr(out, "criterion"), "foremost_then_shortest")
})

test_that("the total equals the summed hop counts of the credited journeys", {
  # A second exact identity. Each reachable ordered pair spreads exactly one
  # unit of credit across the contacts of its optimal journeys, so the grand
  # total is the number of hops those journeys take, summed over pairs.
  for (cr in c("foremost_then_shortest", "min_hops")) {
    dn <- dynet(school_contacts, format = "contact")
    total <- sum(as.data.frame(edge_centrality(dn, criterion = cr))$value)
    reached <- as.data.frame(dyn_reachability(
      dn, measure = "reach_count", direction = "forward",
      criterion = cr))$value
    mean_hops <- as.data.frame(dyn_reachability(
      dn, measure = "hops", direction = "forward", criterion = cr))$value
    expect_equal(total, sum(reached * mean_hops), info = cr)
  }
})

test_that("relabelling vertices changes no contact score", {
  dn <- dynet(school_contacts, format = "contact")
  before <- as.data.frame(edge_centrality(dn))$value
  after <- as.data.frame(
    edge_centrality(rename_nodes(dn, c(Ana = "Zara"))))$value
  expect_equal(sort(before), sort(after))
})
