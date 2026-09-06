# ===========================================================================
# Stage 2 A3b: criterion = "shortest" with a per-contact cost.
# The oracle for hop costs is min_hops itself; for weight costs, hand-built
# fixtures, scaling, and monotonicity under added contacts.
# ===========================================================================

cheap_detour <- function() {
  # A->C directly at t = 1 costs 5; A->B->C (t = 0 then t = 2) costs 2.
  log <- data.frame(from = c("A", "B", "A"), to = c("B", "C", "C"),
                    time = c(0, 2, 1), weight = c(1, 1, 5))
  dynet(log, format = "contact", directed = TRUE, weight = "weight",
        observation_start = 0, observation_end = 10)
}

weighted_random <- function(seed = 11L, n_v = 10L, n_e = 45L) {
  e <- random_edges(n_v = n_v, n_e = n_e, seed = seed)
  e$weight <- round(stats::runif(nrow(e), 0.5, 4), 2)
  e
}

shortest_frame <- function(dn, ...) {
  routes <- paths(dn, criterion = "shortest", cost = "weight", ...)
  as.data.frame(routes)
}

test_that("bad weights, misplaced cost and backward queries are classed errors", {
  log <- data.frame(from = c("A", "B"), to = c("B", "C"),
                    time = c(0, 1), weight = c(1, 0))
  zero <- dynet(log, format = "contact", weight = "weight")
  expect_error(paths(zero, from = "A", criterion = "shortest", cost = "weight"),
               class = "dynet_bad_weight")
  expect_error(paths(zero, from = "A", criterion = "shortest", cost = "weight"),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(zero, measure = "closeness", scope = "temporal",
                              criterion = "shortest", cost = "weight"),
               class = "dynet_bad_weight")
  # hop costs never read the weight, so the same network is fine
  by_hops <- paths(zero, from = "A", criterion = "shortest")
  expect_s3_class(by_hops, "dynet_paths")
  dn <- quiet_dynet(school_contacts)
  expect_error(paths(dn, from = "Ana", criterion = "min_hops", cost = "weight"),
               class = "dynet_bad_input")
  expect_error(paths(dn, from = "Ana", cost = "hops"), class = "dynet_bad_input")
  expect_error(paths(dn, from = "Ana", criterion = "shortest", direction = "backward"),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = "degree", cost = "weight"),
               class = "dynet_bad_input")
})

test_that("the cheapest journey is not the fewest-hop one, and the table says so", {
  dn <- cheap_detour()
  routes <- paths(dn, from = "A", criterion = "shortest", cost = "weight",
                  start = 0, end = 10)
  cheap <- as.data.frame(routes)
  c_row <- cheap[cheap$node == "C", ]
  expect_equal(c_row$path_cost, 2)
  expect_identical(c_row$n_hops, 2L)
  expect_equal(c_row$arrival_time, 2)
  expect_equal(c_row$n_paths, 1)
  expect_equal(cheap$path_cost[cheap$node == "A"], 0)
  fewest <- paths(dn, from = "A", criterion = "min_hops", start = 0, end = 10)
  few <- as.data.frame(fewest)
  expect_identical(few$n_hops[few$node == "C"], 1L)
  expect_equal(few$arrival_time[few$node == "C"], 1)
  expect_false("path_cost" %in% names(few))
  expect_identical(attr(routes, "cost"), "weight")
  expect_output(print(routes), "summed tie weight")
  steps <- as.data.frame(routes, what = "steps")
  expect_true(all(c("A", "B", "C") %in% steps$node))
})

test_that("hop costs are min_hops exactly, and unit weights reproduce it including n_paths", {
  dn <- quiet_dynet(school_contacts)
  for (src in c("Ana", "Jonas", "Kira")) {
    fewest <- paths(dn, from = src, criterion = "min_hops")
    hops <- as.data.frame(fewest)
    by_hops_routes <- paths(dn, from = src, criterion = "shortest")
    by_hops <- as.data.frame(by_hops_routes)
    by_weight <- shortest_frame(dn, from = src)
    expect_identical(by_hops[names(hops)], hops, info = src)
    expect_equal(by_hops$path_cost, as.numeric(hops$n_hops), info = src)
    expect_identical(by_weight[names(hops)], hops, info = src)
    expect_equal(by_weight$path_cost, as.numeric(hops$n_hops), info = src)
  }
})

test_that("scaling every weight scales path_cost and changes nothing else", {
  e <- weighted_random()
  dn <- quiet_dynet(e, weight = "weight")
  e3 <- e
  e3$weight <- e3$weight * 3
  dn3 <- quiet_dynet(e3, weight = "weight")
  for (src in c("v1", "v4", "v7")) {
    a <- shortest_frame(dn, from = src)
    b <- shortest_frame(dn3, from = src)
    expect_equal(b$path_cost, 3 * a$path_cost, info = src)
    rest <- setdiff(names(a), "path_cost")
    expect_identical(a[rest], b[rest], info = src)
  }
})

test_that("adding a contact never increases any path_cost", {
  e <- weighted_random(seed = 5L)
  dn <- quiet_dynet(e, weight = "weight")
  before <- shortest_frame(dn, from = "v2")
  extra <- data.frame(from = "v2", to = "v9", start = 3, end = 4, weight = 0.7)
  e_more <- rbind(e, extra)
  more <- quiet_dynet(e_more, weight = "weight")
  after <- shortest_frame(more, from = "v2")
  both <- before$reachable & after$reachable
  expect_true(all(after$reachable[before$reachable]))
  expect_true(all(after$path_cost[both] <= before$path_cost[both] + 1e-9))
})

test_that("shortest journeys are time-respecting and never cheaper than any other criterion's", {
  e <- weighted_random(seed = 9L)
  dn <- quiet_dynet(e, weight = "weight")
  for (src in c("v1", "v5")) {
    w <- shortest_frame(dn, from = src)
    fewest <- paths(dn, from = src, criterion = "min_hops")
    h <- as.data.frame(fewest)
    foremost <- paths(dn, from = src)
    f <- as.data.frame(foremost)
    expect_identical(w$reachable, h$reachable, info = src)
    ok <- w$reachable
    # the cheapest journey arrives no earlier than the foremost one
    expect_true(all(w$arrival_time[ok] >= f$arrival_time[ok] - 1e-9), info = src)
    # and uses at least as many hops as the fewest-hop one
    expect_true(all(w$n_hops[ok] >= h$n_hops[ok]), info = src)
  }
})

test_that("sessions merge by cost, and separate blocks rank on their own", {
  s1 <- weighted_random(seed = 21L, n_v = 7L, n_e = 25L)
  s1$session <- "s1"
  s2 <- weighted_random(seed = 22L, n_v = 7L, n_e = 25L)
  s2$session <- "s2"
  spells <- rbind(s1, s2)
  dn <- quiet_dynet(spells, session = "session", weight = "weight")
  bounded <- shortest_frame(dn, from = "v1", sessions = "bounded")
  separate <- shortest_frame(dn, from = "v1", sessions = "separate")
  collapse <- shortest_frame(dn, from = "v1", sessions = "collapse")
  expect_true("path_session" %in% names(bounded))
  expect_true(all(c("session", "path_cost") %in% names(separate)))
  # bounded keeps journeys inside one session: its cost is the best of the
  # per-session costs, and no better than the collapsed search's
  per <- tapply(separate$path_cost, separate$node, min, na.rm = TRUE)
  reach <- bounded$reachable
  best_per_session <- as.numeric(per[bounded$node[reach]])
  expect_equal(bounded$path_cost[reach], best_per_session)
  expect_true(all(collapse$path_cost[reach] <= bounded$path_cost[reach] + 1e-9))
})

test_that("closeness and betweenness under shortest read the cost, and top-k stays exact", {
  e <- weighted_random(seed = 13L)
  dn <- quiet_dynet(e, weight = "weight")
  closeness <- dyn_centrality(dn, measure = "closeness", scope = "temporal",
                              criterion = "shortest", cost = "weight")
  clo <- as.data.frame(closeness)
  by_hand <- vapply(clo$node, function(src) {
    fr <- shortest_frame(dn, from = src)
    d <- fr$path_cost[fr$reachable & fr$node != src]
    if (!length(d)) 0 else 1 / mean(d)
  }, numeric(1L))
  expect_equal(clo$value, unname(by_hand))
  expect_identical(attr(closeness, "distance"), "summed_weight")

  school <- quiet_dynet(school_contacts)
  unit_result <- dyn_centrality(school, measure = "betweenness", scope = "temporal",
                                criterion = "shortest", cost = "weight")
  unit <- as.data.frame(unit_result)
  hops_result <- dyn_centrality(school, measure = "betweenness", scope = "temporal",
                                criterion = "min_hops")
  hops <- as.data.frame(hops_result)
  expect_equal(unit$value, hops$value)

  for (k in seq_len(nrow(clo))) {
    leaders <- dyn_centrality(dn, measure = "closeness", scope = "temporal",
                              criterion = "shortest", cost = "weight", top = k)
    got <- as.data.frame(leaders)
    kth <- sort(clo$value, decreasing = TRUE)[k]
    want <- clo[clo$value >= kth - 1e-8, ]
    expect_identical(got$node, want$node, info = sprintf("k = %d", k))
    expect_equal(got$value, want$value, info = sprintf("k = %d", k))
  }
})

test_that("the tolerant cost comparison treats a rounding difference as a tie", {
  expect_true(Dynet:::.cost_eq(0.1 + 0.2, 0.3))
  expect_false(Dynet:::.cost_eq(1, 1.001))
})
