three_journeys <- function() {
  # Three A->D journeys, each criterion selecting a different one:
  #   A->F->G->D  arrives 3, 3 hops   (earliest arrival)
  #   A->B->D     arrives 5, 2 hops   (fewest hops)
  #   A->C->D     arrives 7, 2 hops   (shortest elapsed)
  dynet(
    data.frame(from = c("A", "B", "A", "C", "A", "F", "G"),
               to   = c("B", "D", "C", "D", "F", "G", "D"),
               time = c(0, 5, 6, 7, 1, 2, 3)),
    format = "contact", directed = TRUE,
    nodes = data.frame(name = c("A", "B", "C", "D", "F", "G")),
    observation_start = 0, observation_end = 10)
}

test_that("an unknown criterion is rejected", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(paths(dn, from = "Ana", criterion = "cheapest"))
  expect_error(Dynet:::.criterion_select("cheapest"),
               class = "dynet_bad_input")
})

test_that("the default criterion still computes what it always computed", {
  # foremost_then_shortest is what every release before this one returned, so
  # the default call must not move by a single value.
  dn <- three_journeys()
  out <- as.data.frame(paths(dn, from = "A", start = 0, end = 10))
  d <- out[out$node == "D", ]
  expect_identical(d$arrival_time, 3)
  expect_identical(d$n_hops, 3L)
  expect_identical(d$n_paths, 1)
})

test_that("min_hops selects a genuinely different journey", {
  dn <- three_journeys()
  out <- as.data.frame(paths(dn, from = "A", criterion = "min_hops",
                             start = 0, end = 10))
  d <- out[out$node == "D", ]
  expect_identical(d$n_hops, 2L)
  expect_identical(d$arrival_time, 5)
})

test_that("min_hops never uses more hops, and never arrives earlier", {
  # The dominance property that defines the two criteria. A violation of
  # either means the selection rule is wrong.
  dn <- dynet(school_contacts, format = "contact")
  for (src in c("Ana", "Jonas", "Kira")) {
    a <- as.data.frame(paths(dn, from = src))
    b <- as.data.frame(paths(dn, from = src, criterion = "min_hops"))
    both <- a$reachable & b$reachable
    expect_true(all(b$n_hops[both] <= a$n_hops[both]), info = src)
    expect_true(all(b$arrival_time[both] >= a$arrival_time[both]), info = src)
  }
})

test_that("reachability is identical under every criterion", {
  # Every criterion optimises over the SAME feasible journey set, and that set
  # is nonempty exactly when the target is reachable. Only the selected
  # journey differs, never who can be reached.
  dn <- dynet(school_contacts, format = "contact")
  for (src in c("Ana", "Jonas", "Kira")) {
    for (dir in c("forward", "backward")) {
      a <- as.data.frame(paths(dn, from = src, direction = dir))
      b <- as.data.frame(paths(dn, from = src, direction = dir,
                               criterion = "min_hops"))
      expect_identical(a$reachable, b$reachable, info = paste(src, dir))
    }
  }
})

test_that("hop counts stay inside the vertex-simple bound", {
  dn <- dynet(school_contacts, format = "contact")
  n <- nrow(as.data.frame(dn, what = "nodes"))
  for (cr in c("foremost_then_shortest", "min_hops")) {
    out <- as.data.frame(paths(dn, from = "Ana", criterion = cr))
    hops <- out$n_hops[out$reachable]
    expect_true(all(hops <= n - 1L), info = cr)
  }
})

test_that("the criterion is recorded on the result, not just applied", {
  dn <- dynet(school_contacts, format = "contact")
  expect_identical(attr(paths(dn, from = "Ana"), "criterion"),
                   "foremost_then_shortest")
  expect_identical(
    attr(paths(dn, from = "Ana", criterion = "min_hops"), "criterion"),
    "min_hops")
})

test_that("the criterion carries through every session mode", {
  dn <- dynet(school_contacts, format = "contact")
  for (mode in c("bounded", "collapse")) {
    a <- as.data.frame(paths(dn, from = "Ana", sessions = mode))
    b <- as.data.frame(paths(dn, from = "Ana", sessions = mode,
                             criterion = "min_hops"))
    both <- a$reachable & b$reachable
    expect_true(all(b$n_hops[both] <= a$n_hops[both]), info = mode)
  }
})

test_that("a backward search honours the criterion too", {
  dn <- dynet(school_contacts, format = "contact")
  a <- as.data.frame(paths(dn, from = "Ana", direction = "backward"))
  b <- as.data.frame(paths(dn, from = "Ana", direction = "backward",
                           criterion = "min_hops"))
  both <- a$reachable & b$reachable
  expect_true(all(b$n_hops[both] <= a$n_hops[both]))
  # Backward maximises departure, so the min_hops journey departs no later.
  expect_true(all(b$arrival_time[both] <= a$arrival_time[both]))
})

test_that("temporal closeness uses the distance its criterion optimised", {
  dn <- dynet(school_contacts, format = "contact")
  enc <- Dynet:::.encode(dn)

  # Under min_hops the distance is the hop count, so closeness is
  # dimensionless and directly comparable with static closeness. Under
  # foremost it is elapsed latency and carries inverse-time units.
  tree <- Dynet:::.optimal_path_search(enc, 1L, 0, upper = 25,
                                       criterion = "min_hops")
  target <- seq_len(tree$n) != 1L & is.finite(tree$arrival)
  hand <- 1 / mean(as.numeric(tree$n_hops[target]))
  got <- as.data.frame(dyn_centrality(dn, measure = "closeness",
                                      scope = "temporal",
                                      criterion = "min_hops"))$value[[1L]]
  expect_equal(got, hand)

  # The two criteria must actually disagree, or the argument does nothing.
  a <- as.data.frame(dyn_centrality(dn, measure = "closeness",
                                    scope = "temporal"))$value
  expect_false(isTRUE(all.equal(a, rep(got, length(a)))))
})

test_that("temporal betweenness follows the criterion's optimal family", {
  # Betweenness distributes dependency over the selected optimal journeys, so
  # changing which journeys are optimal must change the result.
  dn <- dynet(school_contacts, format = "contact")
  a <- as.data.frame(dyn_centrality(dn, measure = "betweenness",
                                    scope = "temporal"))$value
  b <- as.data.frame(dyn_centrality(dn, measure = "betweenness",
                                    scope = "temporal",
                                    criterion = "min_hops"))$value
  expect_false(isTRUE(all.equal(a, b)))
  expect_true(all(a >= 0))
  expect_true(all(b >= 0))
})

test_that("reach is identical under every criterion, in centrality too", {
  dn <- dynet(school_contacts, format = "contact")
  for (m in c("reach", "reach_count")) {
    a <- as.data.frame(dyn_centrality(dn, measure = m, scope = "temporal"))$value
    b <- as.data.frame(dyn_centrality(dn, measure = m, scope = "temporal",
                                      criterion = "min_hops"))$value
    expect_identical(a, b, info = m)
  }
})

test_that("the default temporal centrality is unchanged by the criterion work", {
  # Frozen values from before criterion support existed.
  dn <- dynet(school_contacts, format = "contact")
  cl <- as.data.frame(dyn_centrality(dn, measure = "closeness",
                                     scope = "temporal"))
  expect_equal(cl$value[cl$node == "Ana"], 0.130784708249497, tolerance = 1e-12)
  bt <- as.data.frame(dyn_centrality(dn, measure = "betweenness",
                                     scope = "temporal"))
  expect_equal(sum(bt$value), 238)
})
