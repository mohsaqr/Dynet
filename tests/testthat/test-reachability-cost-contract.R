test_that("an unknown reach measure is rejected by class", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(dyn_reachability(dn, measure = "speed"),
               class = "dynet_unknown_measure")
})

test_that("one over mean latency equals temporal closeness exactly", {
  # The binding internal oracle. Both summarise the same optimal journeys, so
  # any divergence means the two verbs disagree about what an optimal journey
  # is -- which no external reference would catch.
  dn <- dynet(school_contacts, format = "contact")
  latency <- as.data.frame(dyn_reachability(
    dn, measure = "latency", direction = "forward"))$value
  closeness <- as.data.frame(dyn_centrality(
    dn, measure = "closeness", scope = "temporal"))$value
  expect_equal(1 / latency, closeness)
})

test_that("the identity holds under min_hops too, with hops as the distance", {
  dn <- dynet(school_contacts, format = "contact")
  hops <- as.data.frame(dyn_reachability(
    dn, measure = "hops", direction = "forward",
    criterion = "min_hops"))$value
  closeness <- as.data.frame(dyn_centrality(
    dn, measure = "closeness", scope = "temporal",
    criterion = "min_hops"))$value
  expect_equal(1 / hops, closeness)
})

test_that("reach is criterion-invariant while the cost measures are not", {
  dn <- dynet(school_contacts, format = "contact")
  expect_identical(
    as.data.frame(dyn_reachability(dn))$value,
    as.data.frame(dyn_reachability(dn, criterion = "min_hops"))$value)

  a <- as.data.frame(dyn_reachability(dn, measure = "latency",
                                      direction = "forward"))$value
  b <- as.data.frame(dyn_reachability(dn, measure = "latency",
                                      direction = "forward",
                                      criterion = "min_hops"))$value
  expect_false(isTRUE(all.equal(a, b)))
})

test_that("mean hops is at least one wherever anything is reachable", {
  dn <- dynet(school_contacts, format = "contact")
  out <- as.data.frame(dyn_reachability(
    dn, measure = c("reach_count", "hops"), direction = "forward"))
  reached <- out$value[out$measure == "forward_reach_count"]
  hops <- out$value[out$measure == "forward_hops"]
  expect_true(all(hops[reached > 0] >= 1))
})

test_that("an isolate reports NaN for a cost measure and zero for reach", {
  # NaN because the mean over an empty reachable set is 0/0, never a
  # fabricated zero: an isolate did not have latency zero, it had no latency.
  # dynet() drops a vertex with no edges, so the isolate has to be declared
  # eligible through vertex_spells to exist in the network at all.
  dn <- dynet(
    data.frame(from = c("A", "B"), to = c("B", "A"), time = c(0, 1)),
    format = "contact", directed = TRUE,
    nodes = data.frame(name = c("A", "B", "Alone")),
    vertex_spells = data.frame(node = c("A", "B", "Alone"), start = 0, end = 2),
    observation_start = 0, observation_end = 2)
  out <- as.data.frame(dyn_reachability(
    dn, measure = c("reach_count", "latency"), direction = "forward"))
  expect_identical(out$value[out$measure == "forward_reach_count" &
                               out$node == "Alone"], 0)
  expect_true(is.nan(out$value[out$measure == "forward_latency" &
                                 out$node == "Alone"]))
})

test_that("cost measures work in both directions and in every session mode", {
  dn <- dynet(school_contacts, format = "contact")
  out <- as.data.frame(dyn_reachability(dn, measure = c("latency", "hops")))
  expect_setequal(unique(out$measure),
                  c("forward_latency", "forward_hops",
                    "backward_latency", "backward_hops"))
  expect_true(all(out$value[!is.nan(out$value)] >= 0))
  for (mode in c("bounded", "collapse")) {
    got <- as.data.frame(dyn_reachability(dn, measure = "hops",
                                          direction = "forward",
                                          sessions = mode))
    expect_gt(nrow(got), 0L)
  }
})
