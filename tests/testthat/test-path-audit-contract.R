# Contracts pinned by the 2026-11 path audit. Each defect below was found by
# an exhaustive journey enumerator or by tsna, not by a happy-path example;
# every block pairs the concrete repro with an invariant over random networks.

path_audit_rows <- function(x) {
  out <- as.data.frame(x)
  out <- out[order(out$node), c("node", "reachable", "arrival_time",
                                "attained", "n_hops", "n_paths")]
  rownames(out) <- NULL
  out
}

test_that("bounded sessions merge by the criterion's own primary key", {
  # s1 joins A to C directly but late; s2 joins them early in two hops.
  e <- data.frame(from = c("A", "A", "B"), to = c("C", "B", "C"),
                  start = c(10, 1, 2), end = c(11, 2, 3),
                  session = c("s1", "s2", "s2"))
  dn <- quiet_dynet(e)
  fewest <- paths(dn, from = "A", criterion = "min_hops")
  c_row <- subset(as.data.frame(fewest), node == "C")
  expect_identical(c_row$n_hops, 1L)
  expect_equal(c_row$arrival_time, 10)
  expect_identical(c_row$path_session, "s1")
  shortest <- paths(dn, from = "A", criterion = "shortest")
  expect_equal(subset(as.data.frame(shortest), node == "C")$path_cost, 1)
  # The default criterion still takes the earliest arrival first.
  default <- paths(dn, from = "A")
  expect_equal(subset(as.data.frame(default), node == "C")$arrival_time, 2)
})

test_that("bounded mode on a one-session network equals collapse mode", {
  invariant <- lapply(1:4, function(seed) {
    e <- random_edges(n_v = 6L, n_e = 14L, span = 10, seed = seed)
    e$session <- "only"
    dn <- quiet_dynet(e)
    source <- as.data.frame(dn, what = "nodes")$name[[1L]]
    grid <- expand.grid(direction = c("forward", "backward"),
                        criterion = c("foremost_then_shortest", "min_hops",
                                      "foremost"),
                        stringsAsFactors = FALSE)
    Map(function(direction, criterion) {
      bounded <- paths(dn, from = source, direction = direction,
                       criterion = criterion, sessions = "bounded")
      collapsed <- paths(dn, from = source, direction = direction,
                         criterion = criterion, sessions = "collapse")
      expect_equal(path_audit_rows(bounded), path_audit_rows(collapsed))
    }, grid$direction, grid$criterion)
  })
  expect_length(invariant, 4L)
})

test_that("an unattained backward optimum keeps its family in bounded mode", {
  e <- data.frame(from = c("A", "B"), to = c("B", "C"), start = c(1, 2),
                  end = c(2, 3), session = "s1")
  dn <- quiet_dynet(e)
  into <- paths(dn, from = "C", direction = "backward")
  a_row <- subset(as.data.frame(into), node == "A")
  expect_false(a_row$attained)
  expect_identical(a_row$n_hops, 2L)
  expect_equal(a_row$n_paths, 1)
  steps <- as.data.frame(into, what = "steps")
  expect_identical(subset(steps, endpoint == "A")$node, c("A", "B", "C"))
})

test_that("a hop-primary criterion reports attainment of the time it reports", {
  # One hop either way: an interval whose latest departure is the unattained
  # supremum 8, and a point contact realised at 6.
  e <- data.frame(from = c("V", "V"), to = c("T", "T"), start = c(5, 6),
                  end = c(8, 6))
  dn <- quiet_dynet(e)
  into <- paths(dn, from = "T", direction = "backward",
                criterion = "min_hops", end = 10)
  v_row <- subset(as.data.frame(into), node == "V")
  expect_equal(v_row$arrival_time, 8)
  expect_false(v_row$attained)
  expect_equal(v_row$n_paths, 1)

  # Invariant: every reported endpoint's attainment is the attainment of the
  # time its own routes carry at that endpoint.
  lapply(1:5, function(seed) {
    net <- quiet_dynet(random_edges(n_v = 6L, n_e = 14L, span = 10,
                                    seed = seed))
    target <- as.data.frame(net, what = "nodes")$name[[2L]]
    lapply(c("min_hops", "foremost_then_shortest"), function(criterion) {
      found <- paths(net, from = target, direction = "backward",
                     criterion = criterion)
      table <- subset(as.data.frame(found), reachable & n_paths > 0)
      steps <- subset(as.data.frame(found, what = "steps"),
                      node == endpoint)
      at_endpoint <- steps$attained[match(table$node, steps$endpoint)]
      expect_identical(table$attained, at_endpoint)
      expect_equal(table$arrival_time,
                   steps$time[match(table$node, steps$endpoint)])
    })
  })
})

test_that("the backward foremost family counts journeys tied on a supremum", {
  # v4 departs just before 3 either through v1 -> v5 or through v1 -> v3 ->
  # v5; both approach the same unattained supremum.
  e <- data.frame(from = c("v4", "v1", "v1", "v3"),
                  to = c("v1", "v5", "v3", "v5"),
                  start = c(1, 6, 3, 0), end = c(3, 7, 8, 4))
  dn <- quiet_dynet(e)
  family <- paths(dn, from = "v5", direction = "backward",
                  criterion = "foremost", end = 9)
  v4 <- subset(as.data.frame(family), node == "v4")
  expect_equal(v4$n_paths, 2)
  expect_true(is.na(v4$n_hops))
  expect_error(paths(dn, from = "v5", direction = "backward",
                     criterion = "foremost", end = 9, max_states = 2),
               class = "dynet_path_family_too_large")

  # Invariant: the foremost family contains the foremost-then-shortest one.
  lapply(1:5, function(seed) {
    net <- quiet_dynet(random_edges(n_v = 6L, n_e = 14L, span = 10,
                                    seed = seed))
    target <- as.data.frame(net, what = "nodes")$name[[1L]]
    lapply(c("forward", "backward"), function(direction) {
      wide <- path_audit_rows(paths(net, from = target, direction = direction,
                                    criterion = "foremost"))
      narrow <- path_audit_rows(paths(net, from = target,
                                      direction = direction))
      expect_identical(wide$reachable, narrow$reachable)
      expect_equal(wide$arrival_time, narrow$arrival_time)
      expect_true(all(wide$n_paths >= narrow$n_paths))
    })
  })
})

test_that("pathways counts every optimal route, not only tree leaves", {
  dn <- quiet_dynet(chain_edges())
  routes <- pathways(dn, from = "A")
  expect_setequal(routes$route, c("A -> B", "A -> B -> C",
                                  "A -> B -> C -> D", "A -> B -> C -> D -> E"))
  expect_setequal(summary(routes)$endpoint, c("B", "C", "D", "E"))
  expect_error(pathways(dn, from = "E"),
               class = c("dynet_empty_result"))
  expect_error(pathways(dn, from = "E"), class = "dynet_bad_input")

  # Invariant: one source's counted routes are its family's path counts.
  lapply(1:5, function(seed) {
    net <- quiet_dynet(random_edges(n_v = 6L, n_e = 14L, span = 10,
                                    seed = seed))
    lapply(as.data.frame(net, what = "nodes")$name, function(source) {
      family <- as.data.frame(paths(net, from = source))
      all_routes <- tryCatch(
        pathways(net, from = source, min_hops = 0),
        dynet_empty_result = function(condition) NULL
      )
      expect_equal(sum(all_routes$count), sum(family$n_paths))
    })
  })
})

test_that("path_network takes one session of a separate-session result", {
  e <- data.frame(from = c("A", "B", "A", "D"), to = c("B", "C", "D", "C"),
                  start = c(1, 2, 1, 2), end = c(2, 3, 2, 3),
                  session = c("s1", "s1", "s2", "s2"))
  dn <- quiet_dynet(e)
  separate <- paths(dn, from = "A", sessions = "separate")
  expect_error(path_network(separate), class = "dynet_needs_session")
  expect_error(path_network(separate), class = "dynet_bad_input")
  expect_error(path_network(separate, session = "s9"),
               class = "dynet_unknown_session")
  expect_error(path_network(paths(dn, from = "A"), session = "s1"),
               class = "dynet_bad_input")

  # Invariant: each session's network holds exactly that session's reached
  # vertices, once each, and only hops between them.
  lapply(c("s1", "s2"), function(label) {
    union_network <- path_network(separate, session = label)
    nodes <- as.data.frame(union_network, what = "nodes")
    block <- subset(as.data.frame(separate), session == label & reachable)
    expect_false(anyDuplicated(nodes$name) > 0L)
    expect_setequal(nodes$name, block$node)
    edges <- as.data.frame(union_network)
    expect_true(all(c(edges$from, edges$to) %in% nodes$name))
  })
})

test_that("trajectory tokens keep millisecond hop times at Unix scale", {
  clock <- 1.7e9
  e <- data.frame(from = c("A", "A", "B"), to = c("B", "B", "C"),
                  time = clock + c(0.001, 0.002, 0.004))
  dn <- quiet_dynet(e, format = "contact")
  family <- paths(dn, from = "A", criterion = "foremost")
  tree <- as.data.frame(path_trajectories(family))
  # Two routes reach C through B at different instants: two branches.
  expect_identical(sum(tree$vertex == "C"), 2L)
  expect_false(anyDuplicated(tree$node) > 0L)
  # Invariant: the tree's times are the route steps' times, exactly.
  steps <- as.data.frame(family, what = "steps")
  expect_true(all(tree$time %in% steps$time))
  expect_identical(Dynet:::.path_time_token(c(2.12, NA)), c("2.12", "NA"))
  expect_error(path_trajectories(family, min_count = 0),
               class = "dynet_bad_input")
})

test_that("path failures carry the package parent class", {
  dn <- quiet_dynet(chain_edges())
  expect_error(paths(dn, from = "nobody"), class = "dynet_unknown_node")
  expect_error(paths(dn, from = "nobody"), class = "dynet_bad_input")
  expect_error(reachability(dn, measure = "nope"), class = "dynet_bad_input")
  expect_error(path_trajectories(paths(dn, from = "A"), min_count = 99),
               class = "dynet_bad_input")
})

test_that("a computed arrival meets an instantaneous vertex spell it equals", {
  # The point contact fires at 0.1 and takes 0.2, so B is reached at the
  # computed 0.1 + 0.2 = 0.30000000000000004, where B's declared presence is
  # the instant 0.3. Before the tolerant comparison B was unreachable.
  reach_at <- function(clock) {
    e <- data.frame(from = "A", to = "B", time = clock + 0.1)
    dn <- quiet_dynet(e, format = "contact")
    present <- data.frame(node = c("A", "B", "B"),
                          start = clock + c(0, 0, 0.3),
                          end = clock + c(1, 0.2, 0.3))
    dn <- set_vertex_spells(dn, present)
    found <- paths(dn, from = "A", traversal_time = 0.2)
    subset(as.data.frame(found), node == "B")
  }
  local <- reach_at(0)
  expect_true(local$reachable)
  expect_identical(local$n_hops, 1L)
  expect_equal(local$arrival_time, 0.3)
  # Invariant: the same network on a Unix-second clock answers the same.
  unix <- reach_at(1.7e9)
  expect_true(unix$reachable)
  expect_identical(unix$n_hops, local$n_hops)
  expect_equal(unix$arrival_time - 1.7e9, local$arrival_time,
               tolerance = 1e-6)
  expect_error(paths(quiet_dynet(chain_edges()), from = "A",
                     traversal_time = -0.1),
               class = "dynet_bad_input")
})
