# event_graph(): events as vertices, temporal adjacency as arcs.

contact_chain <- function(directed = TRUE) {
  quiet_dynet(data.frame(
    from = c("A", "B", "C", "A", "B"), to = c("B", "C", "D", "C", "D"),
    time = c(1, 2, 3, 4, 5)
  ), directed = directed)
}

# Vertices reached from `u` by following arcs out of the events that leave
# it: the targets of reached events, or every endpoint when undirected.
event_reach <- function(eg, dn, u) {
  ev <- as.data.frame(eg)
  adj <- as.data.frame(eg, what = "adjacencies")
  frontier <- if (dn$directed) ev$event[ev$from == u] else
    ev$event[ev$from == u | ev$to == u]
  seen <- frontier
  repeat {
    nxt <- setdiff(adj$to_event[adj$from_event %in% frontier], seen)
    if (!length(nxt)) break
    seen <- c(seen, nxt)
    frontier <- nxt
  }
  reached <- ev$event %in% seen
  hit <- if (dn$directed) ev$to[reached] else c(ev$from[reached], ev$to[reached])
  sort(setdiff(unique(hit), u))
}

test_that("broken inputs raise classed errors", {
  dn <- contact_chain()
  expect_error(event_graph(dn, delta = -1), class = "dynet_bad_input")
  expect_error(event_graph(dn, delta = NA_real_), class = "dynet_bad_input")
  expect_error(event_graph(dn, delta = c(1, 2)), class = "dynet_bad_input")
  expect_error(event_graph(dn, loops = NA), class = "dynet_bad_input")
  expect_error(event_graph(data.frame(from = "A", to = "B")),
               class = "dynet_bad_input")
  expect_error(event_graph(dn, sessions = "separate"),
               class = "dynet_no_sessions")
  loops_only <- quiet_dynet(data.frame(from = "A", to = "A", time = 1),
                            loops = TRUE)
  expect_error(event_graph(loops_only), class = "dynet_empty_network")
})

test_that("a contact chain gives the hand-computed adjacencies", {
  # A->B@1, B->C@2, C->D@3, A->C@4, B->D@5. Through the target of the earlier
  # event and the source of the later one: B->C follows A->B (via B), and so
  # does B->D (via B); C->D follows B->C (via C); nothing leaves D or follows
  # A->C at C after time 4.
  eg <- event_graph(contact_chain())
  adj <- as.data.frame(eg, what = "adjacencies")
  expect_identical(adj$from_event, c(1L, 1L, 2L))
  expect_identical(adj$to_event, c(2L, 5L, 3L))
  expect_identical(adj$via, c("B", "B", "C"))
  expect_equal(adj$wait, c(1, 4, 1))
  expect_identical(nrow(as.data.frame(eg)), 5L)
})

test_that("direction = 'ignore' joins through any shared endpoint", {
  respect <- as.data.frame(event_graph(contact_chain()), what = "adjacencies")
  ignore <- as.data.frame(event_graph(contact_chain(), direction = "ignore"),
                          what = "adjacencies")
  # A->C@4 shares A with A->B@1 and C with B->C@2 and C->D@3; only ignoring
  # direction admits those.
  expect_gt(nrow(ignore), nrow(respect))
  key <- function(a) paste(a$from_event, a$to_event, a$via)
  expect_true(all(key(respect) %in% key(ignore)))
})

test_that("simultaneous events at a shared vertex are never adjacent", {
  dn <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                               time = c(2, 2)))
  adj <- as.data.frame(event_graph(dn), what = "adjacencies")
  expect_identical(nrow(adj), 0L)
  undirected <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                                       time = c(2, 2)), directed = FALSE)
  expect_identical(nrow(as.data.frame(event_graph(undirected),
                                      what = "adjacencies")), 0L)
})

test_that("an interval event is followed only once it has ended", {
  dn <- quiet_dynet(data.frame(from = c("A", "B", "B", "B"),
                               to = c("B", "C", "D", "E"),
                               start = c(0, 2, 5, 6), end = c(5, 3, 6, 7)))
  adj <- as.data.frame(event_graph(dn), what = "adjacencies")
  # B->C starts at 2, while A->B is still running until 5; B->D starts at the
  # very instant A->B ends, which is not after it; B->E starts at 6.
  expect_identical(adj$from_event[adj$via == "B"], 1L)
  expect_identical(adj$to_event[adj$from_event == 1L], 4L)
  expect_equal(adj$wait[adj$from_event == 1L], 1)
})

test_that("every wait is positive and every via is a real shared vertex", {
  dn <- quiet_dynet(random_edges(seed = 5L))
  eg <- event_graph(dn)
  ev <- as.data.frame(eg)
  adj <- as.data.frame(eg, what = "adjacencies")
  expect_true(all(adj$wait > 0))
  expect_true(all(adj$via %in% dn$nodes$name))
  # Under "respect" the via is the earlier event's target and the later
  # event's source.
  expect_identical(adj$via, ev$to[adj$from_event])
  expect_identical(adj$via, ev$from[adj$to_event])
})

test_that("arcs run forward in event order, so the graph is acyclic", {
  dn <- quiet_dynet(random_edges(seed = 6L), directed = FALSE)
  eg <- event_graph(dn, direction = "ignore")
  ev <- as.data.frame(eg)
  adj <- as.data.frame(eg, what = "adjacencies")
  expect_true(all(adj$from_event < adj$to_event))
  expect_true(all(ev$start[adj$to_event] > ev$start[adj$from_event]))
  expect_false(is.unsorted(ev$start))
})

test_that("a longer delta only adds adjacencies", {
  dn <- quiet_dynet(random_edges(seed = 7L))
  key <- function(delta) {
    adj <- as.data.frame(event_graph(dn, delta = delta), what = "adjacencies")
    paste(adj$from_event, adj$to_event, adj$via)
  }
  short <- key(0.5)
  medium <- key(3)
  long <- key(Inf)
  expect_true(all(short %in% medium))
  expect_true(all(medium %in% long))
  expect_lt(length(short), length(long))
})

test_that("next adjacencies are a subset of all adjacencies at the earliest start", {
  dn <- quiet_dynet(random_edges(seed = 8L))
  all_adj <- as.data.frame(event_graph(dn), what = "adjacencies")
  next_adj <- as.data.frame(event_graph(dn, adjacency = "next"),
                            what = "adjacencies")
  key <- function(a) paste(a$from_event, a$to_event, a$via)
  expect_true(all(key(next_adj) %in% key(all_adj)))
  expect_lt(nrow(next_adj), nrow(all_adj))
  # Each kept successor starts at the earliest start among all successors
  # through the same vertex.
  earliest <- stats::aggregate(to_time ~ from_event + via, all_adj, min)
  joined <- merge(next_adj, earliest, by = c("from_event", "via"),
                  suffixes = c("", "_min"))
  expect_equal(joined$to_time, joined$to_time_min)
})

test_that("on contact data, event-graph reach is path reach with a short hop", {
  # A traversal time below the smallest gap between contact times makes
  # paths() strictly time-increasing, which is the event graph's rule.
  invisible(lapply(c(TRUE, FALSE), function(directed) {
    lapply(1:6, function(seed) {
      edges <- random_edges(n_v = 6L, n_e = 18L, span = 10, seed = seed)
      edges$end <- NULL
      edges$start <- round(edges$start)
      names(edges)[names(edges) == "start"] <- "time"
      dn <- quiet_dynet(edges, directed = directed)
      eg <- event_graph(dn)
      lapply(dn$nodes$name, function(u) {
        p <- as.data.frame(paths(dn, from = u, traversal_time = 0.5))
        expect_identical(event_reach(eg, dn, u),
                         sort(setdiff(p$node[p$reachable], u)),
                         info = sprintf("seed %d, source %s", seed, u))
      })
    })
  }))
})

test_that("no adjacency crosses a session wall unless sessions collapse", {
  edges <- data.frame(from = c("A", "B", "B"), to = c("B", "C", "D"),
                      time = c(1, 2, 3), session = c("s1", "s1", "s2"))
  dn <- quiet_dynet(edges, session = "session")
  bounded <- as.data.frame(event_graph(dn), what = "adjacencies")
  collapsed <- as.data.frame(event_graph(dn, sessions = "collapse"),
                             what = "adjacencies")
  expect_identical(bounded$to_event, 2L)
  expect_identical(collapsed$to_event, c(2L, 3L))
  separate <- event_graph(dn, sessions = "separate")
  expect_identical(as.data.frame(separate, what = "adjacencies")$session, "s1")
  expect_true("session" %in% names(as.data.frame(separate)))
  expect_false("session" %in% names(as.data.frame(event_graph(dn))))
})

test_that("self-loops are dropped by default and adjacent at their vertex when kept", {
  dn <- quiet_dynet(data.frame(from = c("A", "B", "B"), to = c("B", "B", "C"),
                               time = c(1, 2, 3)), loops = TRUE)
  expect_identical(nrow(as.data.frame(event_graph(dn))), 2L)
  kept <- event_graph(dn, loops = TRUE)
  adj <- as.data.frame(kept, what = "adjacencies")
  expect_identical(nrow(as.data.frame(kept)), 3L)
  expect_true(all(c("1 2", "2 3") %in% paste(adj$from_event, adj$to_event)))
})

test_that("the result is invariant to the order of the input rows", {
  edges <- random_edges(seed = 9L)
  shuffled <- edges[rev(seq_len(nrow(edges))), ]
  a <- event_graph(quiet_dynet(edges))
  b <- event_graph(quiet_dynet(shuffled))
  drop_spell <- function(x) as.data.frame(x)[, c("event", "from", "to", "start", "end")]
  expect_identical(drop_spell(a), drop_spell(b))
  expect_identical(as.data.frame(a, what = "adjacencies"),
                   as.data.frame(b, what = "adjacencies"))
})

test_that("summary has one row per event and degrees that balance", {
  eg <- event_graph(quiet_dynet(random_edges(seed = 10L)))
  s <- summary(eg)
  expect_s3_class(s, "data.frame")
  expect_identical(names(s), c("event", "time", "in_degree", "out_degree",
                               "mean_wait"))
  expect_identical(nrow(s), nrow(as.data.frame(eg)))
  expect_identical(sum(s$in_degree), sum(s$out_degree))
  expect_true(all(is.na(s$mean_wait[s$out_degree == 0L])))
  expect_true(all(s$mean_wait[s$out_degree > 0L] >= 0))
})

test_that("print returns its input invisibly", {
  eg <- event_graph(contact_chain())
  expect_output(printed <- withVisible(print(eg)), "Event graph")
  expect_false(printed$visible)
})

test_that("the storyline marks a stretch solid exactly when it is an adjacency", {
  eg <- event_graph(contact_chain(), delta = 1.5)
  p <- plot(eg)
  expect_s3_class(p, "ggplot")
  # B appears in events 1, 2 and 5. 1 -> 2 through B is an adjacency (wait 1);
  # 2 -> 5 is not (B is the source of event 2, and the wait is 3 > 1.5).
  stretch_layer <- Filter(function(l) "lt" %in% names(l$data), p$layers)
  expect_length(stretch_layer, 1L)
  stretches <- unique(stretch_layer[[1L]]$data[, c("part", "node", "lt")])
  b <- stretches[stretches$node == "B", ]
  expect_identical(b$lt[order(b$part)], c("relay", "no relay"))
})

test_that("the storyline rejects malformed arguments by class", {
  eg <- event_graph(contact_chain())
  expect_error(plot(eg, top = 0), class = "dynet_bad_input")
  expect_error(plot(eg, top = 2.5), class = "dynet_bad_input")
  expect_error(plot(eg, node_size = -1), class = "dynet_bad_input")
  expect_error(plot(eg, capsule_alpha = 2), class = "dynet_bad_input")
  expect_error(plot(eg, arrows = NA), class = "dynet_bad_input")
  expect_error(plot(eg, line_width = 0), class = "dynet_bad_input")
  expect_error(plot(eg, capsule_color = "not-a-colour"),
               class = "dynet_bad_palette")
  expect_error(plot(eg, palette = 3), class = "dynet_bad_palette")
  expect_error(plot(eg, start = 10), class = "dynet_empty_result")
})

test_that("top limits the drawn actors to the most active ones", {
  eg <- event_graph(quiet_dynet(random_edges(seed = 11L)))
  p <- plot(eg, top = 3)
  drawn <- unique(p$layers[[length(p$layers)]]$data$node)
  expect_length(drawn, 3L)
})

test_that("styling arguments reach the layers they name", {
  eg <- event_graph(contact_chain(), delta = 1.5)
  styled <- plot(eg, capsule_color = "steelblue", capsule_alpha = 0.3,
                 capsule_width = 4, arrow_color = "black", line_width = 2)
  params <- lapply(styled$layers, function(l) l$aes_params)
  capsule <- Filter(function(a) identical(a$linewidth, 4), params)
  expect_length(capsule, 1L)
  expect_identical(capsule[[1L]]$colour, "steelblue")
  expect_identical(capsule[[1L]]$alpha, 0.3)
  expect_true(any(vapply(params, function(a) identical(a$colour, "black"),
                         logical(1L))))
  # Dropping the arrows removes exactly one layer and nothing else.
  expect_identical(length(plot(eg, arrows = FALSE)$layers),
                   length(plot(eg)$layers) - 1L)
})
