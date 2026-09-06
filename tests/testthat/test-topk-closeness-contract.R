# ===========================================================================
# Stage 2 B5: top-k temporal closeness. The oracle is the full computation:
# for every k, `top = k` must return exactly the rows of the full result at
# or above the k-th value, values included.
# ===========================================================================

full_closeness <- function(dn, ...) {
  as.data.frame(dyn_centrality(
    dn, measure = "closeness", scope = "temporal", criterion = "min_hops", ...
  ))
}

expect_top_k_exact <- function(dn, ...) {
  full <- full_closeness(dn, ...)
  blocks <- if ("session" %in% names(full)) split(full, full$session) else list(full)
  n_max <- max(vapply(blocks, nrow, integer(1L)))
  for (k in seq_len(n_max)) {
    got <- full_closeness(dn, top = k, ...)
    want <- do.call(rbind, lapply(blocks, function(block) {
      kth <- sort(block$value, decreasing = TRUE)[min(k, nrow(block))]
      block[block$value >= kth - 1e-8, , drop = FALSE]
    }))
    rownames(want) <- NULL
    expect_identical(got$node, want$node, info = sprintf("k = %d", k))
    expect_equal(got$value, want$value, info = sprintf("k = %d", k))
    if ("session" %in% names(full)) expect_identical(got$session, want$session)
  }
}

test_that("`top` is validated and restricted to the criterion with a valid bound", {
  dn <- quiet_dynet(school_contacts)
  expect_error(dyn_centrality(dn, measure = "closeness", scope = "temporal",
                              criterion = "min_hops", top = 0),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = "closeness", scope = "temporal",
                              criterion = "min_hops", top = 2.5),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = "closeness", scope = "temporal", top = 5),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = "closeness", scope = "temporal",
                              criterion = "fastest", top = 5),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = "degree", top = 5),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = c("closeness", "reach"), scope = "temporal",
                              criterion = "min_hops", top = 5),
               class = "dynet_bad_input")
})

test_that("top-k equals the full computation for every k, on every bundled shape", {
  expect_top_k_exact(quiet_dynet(school_contacts))
  expect_top_k_exact(quiet_dynet(school_contacts, directed = FALSE))
  expect_top_k_exact(quiet_dynet(random_edges(seed = 7L)))
  expect_top_k_exact(quiet_dynet(forum_posts, thread = "thread"))
  expect_top_k_exact(quiet_dynet(school_contacts), start = 2, end = 12)
})

test_that("top-k ranks within each session under separate, and prunes nothing under bounded", {
  spells <- rbind(
    cbind(random_edges(n_v = 8L, n_e = 30L, seed = 3L), session = "s1"),
    cbind(random_edges(n_v = 8L, n_e = 30L, seed = 4L), session = "s2")
  )
  dn <- quiet_dynet(spells, session = "session")
  expect_top_k_exact(dn, sessions = "separate")
  expect_top_k_exact(dn, sessions = "collapse")
  bounded <- dyn_centrality(dn, measure = "closeness", scope = "temporal",
                            criterion = "min_hops", top = 2, sessions = "bounded")
  expect_identical(attr(bounded, "sources_evaluated"), attr(bounded, "sources_total"))
  expect_top_k_exact(dn, sessions = "bounded")
})

test_that("every vertex tied at the k-th value is returned", {
  pairs <- expand.grid(from = c("A", "B", "C", "D"), to = c("A", "B", "C", "D"),
                       stringsAsFactors = FALSE)
  pairs <- pairs[pairs$from != pairs$to, ]
  pairs$time <- 0
  complete <- quiet_dynet(pairs)
  one <- full_closeness(complete, top = 1)
  expect_identical(nrow(one), 4L)
  expect_equal(one$value, rep(1, 4))
})

test_that("the branch and bound actually prunes, and its metadata says how much", {
  # The hub reaches every leaf in one hop (closeness 1); the leaves form a
  # ring walked in time order, so each reaches the others at growing hop
  # counts and none can tie the hub.
  hub <- quiet_dynet(data.frame(
    from = c("H", "H", "H", "H", "H", "L1", "L2", "L3", "L4", "L5", "L1"),
    to   = c("L1", "L2", "L3", "L4", "L5", "L2", "L3", "L4", "L5", "L1", "L2"),
    time = c(1, 1, 1, 1, 1, 2, 3, 4, 5, 6, 7)
  ))
  lead <- dyn_centrality(hub, measure = "closeness", scope = "temporal",
                         criterion = "min_hops", top = 1)
  expect_identical(as.data.frame(lead)$node, "H")
  expect_equal(as.data.frame(lead)$value, 1)
  expect_identical(attr(lead, "top"), 1L)
  expect_identical(attr(lead, "selection"), "exact_top_k_with_ties")
  expect_identical(attr(lead, "sources_total"), 6L)
  expect_lt(attr(lead, "sources_evaluated"), 6L)
  expect_match(attr(lead, "note"), "not computed")
  expect_output(print(lead), "not computed")

  school <- dyn_centrality(quiet_dynet(school_contacts), measure = "closeness",
                           scope = "temporal", criterion = "min_hops", top = 3)
  expect_lt(attr(school, "sources_evaluated"), attr(school, "sources_total"))
})

test_that("top = n is the full result, apart from the selection record", {
  dn <- quiet_dynet(school_contacts)
  n <- nrow(dn$nodes)
  full <- dyn_centrality(dn, measure = "closeness", scope = "temporal", criterion = "min_hops")
  all_of <- dyn_centrality(dn, measure = "closeness", scope = "temporal",
                           criterion = "min_hops", top = n)
  expect_identical(as.data.frame(all_of), as.data.frame(full))
  expect_null(attr(full, "top"))
  expect_identical(attr(all_of, "sources_evaluated"), n)
})

test_that("the partial-closeness bound is attained and non-increasing across layers", {
  # Layer 1: B and C at one hop; layer 2: D at two hops.
  expect_equal(Dynet:::.min_hops_closeness_bound(c(1L, 2L, 3L), c(0L, 1L, 1L), 1L), 1)
  expect_equal(Dynet:::.min_hops_closeness_bound(c(1L, 2L, 3L, 4L), c(0L, 1L, 1L, 2L), 1L), 3 / 4)
  # A vertex seen again at a later layer keeps its first-appearance distance.
  expect_equal(Dynet:::.min_hops_closeness_bound(c(1L, 2L, 2L), c(0L, 1L, 2L), 1L), 1)
  # Nothing settled beyond the source bounds nothing.
  expect_identical(Dynet:::.min_hops_closeness_bound(1L, 0L, 1L), Inf)
})
