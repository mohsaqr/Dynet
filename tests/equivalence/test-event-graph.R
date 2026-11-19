# event_graph(): the event graph of Kivela et al. (2018). Each spell is an event; event i leads to event j when
# they share a vertex in the order of time (for a directed network, i's receiver is j's sender), j starts strictly
# after i ends, and no later than `delta` after it. On the bundled school_contacts spells, against every ordered
# pair of events enumerated in base R. Reticula (Badie-Modiri and Kivela, 2023), the reference implementation, is a
# Python package that is not installed on the ci machine: its two tests are recorded skips.

network <- dynet(school_contacts)
# 0.995 rather than 1: the spell times have two decimals, so no gap falls on the bound to within rounding.
delta <- 0.995

#' Every ordered pair of events that the definition joins
enumerate_arcs <- function(events, delta) {
  joined <- outer(events$to, events$from, `==`)
  wait <- outer(events$end, events$start, \(end, start) start - end)
  found <- which(joined & wait > 0 & wait <= delta, arr.ind = TRUE)
  data.frame(from_event = events$event[found[, 1L]], to_event = events$event[found[, 2L]],
             via = events$to[found[, 1L]], wait = wait[found])
}

test_that("the arcs of the event graph equal every ordered pair of events the definition joins", {
  graph <- event_graph(network, delta = delta)
  theirs <- enumerate_arcs(as.data.frame(graph), delta)
  ours <- as.data.frame(graph, what = "adjacencies")
  # The wait is one subtraction of two-decimal times.
  expect_reference(ours, theirs, reference = "independent: enumeration of every ordered pair of events, base R",
                   covers = c("event_graph()", "as.data.frame.dynet_event_graph()"), quantity = "arc, delta 0.995",
                   tolerance = 1e-10, key = c("from_event", "to_event", "via"))
})

test_that("summary() gives each event's in- and out-degree and mean wait", {
  graph <- event_graph(network, delta = delta)
  events <- as.data.frame(graph)
  arcs <- enumerate_arcs(events, delta)
  out_wait <- tapply(arcs$wait, factor(arcs$from_event, events$event), mean)
  theirs <- data.frame(event = events$event,
                       in_degree = as.numeric(table(factor(arcs$to_event, events$event))),
                       out_degree = as.numeric(table(factor(arcs$from_event, events$event))),
                       mean_wait = as.numeric(out_wait))
  defined <- subset(theirs, out_degree > 0)
  stated <- "independent: enumeration of every ordered pair of events, base R"
  expect_reference(merge(as.data.frame(summary(graph)), defined["event"]), defined, reference = stated,
                   covers = "summary.dynet_event_graph()", quantity = "event with a successor", tolerance = 1e-10,
                   key = "event")
  ended <- subset(theirs, out_degree == 0, select = c(event, in_degree, out_degree))
  expect_reference(merge(as.data.frame(summary(graph)), ended["event"]), ended, reference = stated,
                   covers = "summary.dynet_event_graph()", quantity = "event without a successor", tolerance = 0,
                   key = "event")
})

test_that("arcs enumerated with a successor allowed to start as its predecessor ends differ (negative control)", {
  graph <- event_graph(network, delta = delta)
  events <- as.data.frame(graph)
  joined <- outer(events$to, events$from, `==`)
  wait <- outer(events$end, events$start, \(end, start) start - end)
  expect_differs(nrow(as.data.frame(graph, what = "adjacencies")), sum(joined & wait >= -1 & wait <= delta),
                 reference = "independent: enumeration of every ordered pair of events, base R", covers = "event_graph()",
                 quantity = "number of arcs, successors starting up to 1 before the predecessor ends", tolerance = 0.5)
})

test_that("event_graph agrees with Reticula on directed delayed events", {
  ref_skip_without_python("reticula", reference = "Reticula")
  graph <- event_graph(network, delta = delta, sessions = "collapse")
  events <- as.data.frame(graph)
  vertices <- sort(unique(c(events$from, events$to)))
  arcs <- ref_python(c(
    "import json, sys",
    "import reticula as ret",
    "given = json.load(open(sys.argv[1]))",
    "edge = ret.directed_delayed_temporal_edge[ret.int64, ret.double]",
    "kind = ret.directed_delayed_temporal_network[ret.int64, ret.double]",
    "edges = [edge(f, t, s, e) for f, t, s, e in zip(given['from'], given['to'], given['start'], given['end'])]",
    "ids = {(f, t, s, e): k for f, t, s, e, k in zip(given['from'], given['to'], given['start'], given['end'], given['event'])}",
    "graph = ret.event_graph(kind(edges), ret.temporal_adjacency.limited_waiting_time[edge](given['delta']))",
    "key = lambda x: (x.tail(), x.head(), x.cause_time(), x.effect_time())",
    "json.dump({'from_event': [ids[key(a.tail())] for a in graph.edges()],",
    "           'to_event': [ids[key(a.head())] for a in graph.edges()]}, open(sys.argv[2], 'w'))"),
    list(from = match(events$from, vertices) - 1L, to = match(events$to, vertices) - 1L, start = events$start,
         end = events$end, event = events$event, delta = delta))
  theirs <- data.frame(from_event = arcs$from_event, to_event = arcs$to_event, present = TRUE)
  ours <- transform(unique(subset(as.data.frame(graph, what = "adjacencies"), select = c(from_event, to_event))),
                    present = TRUE)
  expect_reference(ours, theirs, reference = "Reticula", covers = "event_graph()", quantity = "arc, delta 0.995",
                   tolerance = 0, key = c("from_event", "to_event"))
})

test_that("event_graph(events = 'messages') agrees with Reticula's directed temporal hyperedges", {
  ref_skip_without_python("reticula", reference = "Reticula")
  # Written for when Reticula is installed: a broadcast log, each message one hyperedge from its sender to every
  # recipient at one instant.
  log <- data.frame(from = c("A", "A", "B", "C", "A"), to = c("B", "C", "A", "A", "B"), time = c(1, 1, 2, 3, 4))
  graph <- event_graph(dynet(log, format = "contact", directed = TRUE), events = "messages", sessions = "collapse")
  events <- as.data.frame(graph)
  arcs <- ref_python(c(
    "import json, sys",
    "import reticula as ret",
    "given = json.load(open(sys.argv[1]))",
    "edge = ret.directed_temporal_hyperedge[ret.int64, ret.double]",
    "kind = ret.directed_temporal_hypernetwork[ret.int64, ret.double]",
    "edges = [edge([f], list(t), s) for f, t, s in zip(given['from'], given['to'], given['start'])]",
    "ids = {(f, tuple(sorted(t)), s): k for f, t, s, k in zip(given['from'], given['to'], given['start'], given['event'])}",
    "graph = ret.event_graph(kind(edges), ret.temporal_adjacency.simple[edge]())",
    "key = lambda x: (x.tails()[0], tuple(sorted(x.heads())), x.cause_time())",
    "json.dump({'from_event': [ids[key(a.tail())] for a in graph.edges()],",
    "           'to_event': [ids[key(a.head())] for a in graph.edges()]}, open(sys.argv[2], 'w'))"),
    list(from = match(events$from, LETTERS) - 1L,
         to = lapply(strsplit(events$to, ",", fixed = TRUE), \(names_in) match(names_in, LETTERS) - 1L),
         start = events$start, event = events$event))
  theirs <- data.frame(from_event = arcs$from_event, to_event = arcs$to_event, present = TRUE)
  ours <- transform(unique(subset(as.data.frame(graph, what = "adjacencies"), select = c(from_event, to_event))),
                    present = TRUE)
  expect_reference(ours, theirs, reference = "Reticula", covers = "event_graph()", quantity = "message arc",
                   tolerance = 0, key = c("from_event", "to_event"))
})
