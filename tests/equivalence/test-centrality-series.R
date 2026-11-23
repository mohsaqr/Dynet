# centrality_series(): vertex centrality in each window of a temporal network, on the bundled school_contacts
# spells (240 directed spells among 14 pupils, 0 to 21.52). Each window's snapshot is the set of ordered pairs
# with a spell overlapping it; the references measure that snapshot. igraph and sna (through tsna's windowing)
# are run live; Dynet's kernels are its own base-R code (R/kernels.R, R/kernels-sna.R), not calls to either.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
onsets <- c(0, 7, 14, 21)
network <- dynet(school_contacts)
series_covers <- c("centrality_series()", "as.data.frame.dynet_metric()")

test_that("degree, betweenness and coreness in windows of 7 equal igraph on each snapshot", {
  skip_without_reference("igraph")
  per_window <- lapply(onsets, \(lo) {
    graph <- ref_snapshot(spells, lo, lo + 7, people)
    list(degree = igraph::degree(graph, mode = "all"),
         betweenness = igraph::betweenness(graph, directed = TRUE),
         coreness = igraph::coreness(graph, mode = "all"))
  })
  ours <- as.data.frame(centrality_series(network, measure = c("degree", "betweenness", "coreness"), mode = "all",
                                          step = 7, window = 7))
  # Integers and ratios of small integers: exact up to a few ulp on both sides.
  expect_reference(ours, ref_node_table(per_window, onsets), reference = "igraph", covers = series_covers,
                   quantity = "windows of 7", tolerance = 1e-10, key = c("time", "node", "measure"))
})

test_that("in- and out-degree in windows of 7 equal igraph", {
  skip_without_reference("igraph")
  per_window <- lapply(onsets, \(lo) {
    graph <- ref_snapshot(spells, lo, lo + 7, people)
    list(indegree = igraph::degree(graph, mode = "in"), outdegree = igraph::degree(graph, mode = "out"))
  })
  ours <- as.data.frame(centrality_series(network, measure = c("indegree", "outdegree"), step = 7, window = 7))
  expect_reference(ours, ref_node_table(per_window, onsets), reference = "igraph", covers = series_covers,
                   quantity = "in- and out-degree, windows of 7", tolerance = 0, key = c("time", "node", "measure"))
})

test_that("out-closeness in windows of 7 equals igraph's normalised closeness where it is defined", {
  skip_without_reference("igraph")
  per_window <- lapply(onsets, \(lo) {
    list(closeness = igraph::closeness(ref_snapshot(spells, lo, lo + 7, people), mode = "out", normalized = TRUE))
  })
  theirs <- ref_node_table(per_window, onsets)
  ours <- as.data.frame(centrality_series(network, measure = "closeness", mode = "out", step = 7, window = 7))
  defined <- subset(theirs, !is.nan(value))
  undefined <- subset(theirs, is.nan(value))
  keys <- c("time", "node", "measure")
  expect_reference(merge(ours, defined[keys]), defined, reference = "igraph", covers = series_covers,
                   quantity = "out-closeness, windows of 7", tolerance = 1e-10, key = keys)
  # Not "not comparable" (STANDARD decision 8): the quantity is undefined for igraph only; Dynet gives a number.
  expect_known_difference(merge(ours, undefined[keys]), undefined, reference = "igraph", covers = "centrality_series()",
                          quantity = "out-closeness of a vertex that reaches no one", tolerance = 1e-10, key = keys,
                          reason = "Dynet defines closeness of a vertex with no outgoing path as 0; igraph leaves it undefined (NaN).")
})

test_that("PageRank in windows of 7 equals igraph::page_rank()", {
  skip_without_reference("igraph")
  per_window <- lapply(onsets, \(lo) {
    list(pagerank = igraph::page_rank(ref_snapshot(spells, lo, lo + 7, people), directed = TRUE, damping = 0.85)$vector)
  })
  ours <- as.data.frame(centrality_series(network, measure = "pagerank", damping = 0.85, step = 7, window = 7))
  # Solved by power iteration in Dynet and by PRPACK in igraph; the package's own kernel script holds it to 1e-6.
  expect_reference(ours, ref_node_table(per_window, onsets), reference = "igraph", covers = series_covers,
                   quantity = "PageRank, windows of 7", tolerance = 1e-6, key = c("time", "node", "measure"))
})

test_that("whole-period strength, hub, authority and constraint equal igraph on the aggregate graph", {
  skip_without_reference("igraph")
  stacked <- igraph::graph_from_data_frame(data.frame(spells[c("from", "to")], weight = 1), directed = TRUE,
                                           vertices = people)
  aggregate <- igraph::simplify(stacked, edge.attr.comb = list(weight = "sum"))
  binary <- igraph::delete_edge_attr(aggregate, "weight")
  scaled <- \(values) values / max(values)
  theirs <- ref_node_table(list(list(
    strength = igraph::strength(aggregate, mode = "all"),
    hub = igraph::hits_scores(binary, scale = TRUE)$hub,
    authority = igraph::hits_scores(binary, scale = TRUE)$authority,
    constraint = igraph::constraint(binary))), 0)
  ours <- as.data.frame(centrality_series(network, measure = c("strength", "hub", "authority", "constraint"),
                                          window = "all"))
  # Hub and authority scores are found by iteration on both sides (ARPACK in igraph); 1e-6 is the precision of the
  # iteration.
  expect_reference(ours, theirs, reference = "igraph", covers = series_covers,
                   quantity = "whole period, aggregate graph", tolerance = 1e-6, key = c("node", "measure"))
})

test_that("whole-period eigenvector centrality equals igraph's, by in-arcs and on the collapsed undirected graph", {
  skip_without_reference("igraph")
  binary <- ref_snapshot(spells, 0, 22, people)
  scaled <- \(values) values / max(values)
  incoming <- ref_node_table(list(list(eigenvector = scaled(igraph::eigen_centrality(binary, directed = TRUE)$vector))), 0)
  undirected <- igraph::as_undirected(binary, mode = "collapse")
  either <- ref_node_table(list(list(eigenvector = scaled(igraph::eigen_centrality(undirected)$vector))), 0)
  # Found by iteration on both sides (ARPACK in igraph); 1e-6 is the precision of the iteration.
  expect_reference(as.data.frame(centrality_series(network, measure = "eigenvector", mode = "in", window = "all")),
                   incoming, reference = "igraph", covers = series_covers, quantity = "eigenvector, in-arcs",
                   tolerance = 1e-6, key = c("node", "measure"))
  expect_reference(as.data.frame(centrality_series(network, measure = "eigenvector", mode = "all", window = "all")),
                   either, reference = "igraph", covers = series_covers, quantity = "eigenvector, arcs in either direction",
                   tolerance = 1e-6, key = c("node", "measure"))
})

test_that("degree, betweenness, prestige, Harary, information and flow centrality equal sna through tsna::tSnaStats()", {
  skip_without_reference(c("tsna", "sna", "networkDynamic"))
  history <- ref_network_dynamic(spells)
  sna_series <- function(snafun, ...) {
    values <- tsna::tSnaStats(history, snafun = snafun, start = 0, end = 21, time.interval = 7, aggregate.dur = 7,
                              ...)
    data.frame(time = rep(onsets, each = length(people)), node = rep(people, length(onsets)),
               value = as.numeric(t(as.matrix(values))))
  }
  grid <- list(start = 0, end = 21, step = 7, window = 7)
  ours <- function(measure, mode = "all") {
    subset(as.data.frame(do.call(centrality_series, c(list(network, measure = measure, mode = mode), grid))),
           select = c(time, node, value))
  }
  stated <- list(reference = "tsna", covers = series_covers, key = c("time", "node"))
  # Counts and ratios of counts: exact up to rounding.
  do.call(expect_reference, c(list(ours("degree"), sna_series("degree", gmode = "digraph", cmode = "freeman"),
                                   quantity = "Freeman degree", tolerance = 1e-10), stated))
  do.call(expect_reference, c(list(ours("betweenness"), sna_series("betweenness", gmode = "digraph"),
                                   quantity = "betweenness", tolerance = 1e-10), stated))
  do.call(expect_reference, c(list(ours("degree", mode = "in"), sna_series("prestige", gmode = "digraph"),
                                   quantity = "in-degree prestige", tolerance = 1e-10), stated))
  do.call(expect_reference, c(list(ours("harary", mode = "out"), sna_series("graphcent", gmode = "digraph"),
                                   quantity = "Harary graph centrality", tolerance = 1e-10), stated))
  # Information centrality inverts a matrix on both sides. In the last window seven pupils are isolated: the
  # information matrix is singular there, sna returns values near 0 and Dynet NA.
  information <- sna_series("infocent", gmode = "digraph")
  connected <- subset(information, time < 21)
  do.call(expect_reference, c(list(merge(ours("information"), connected[c("time", "node")]), connected,
                                   quantity = "information centrality", tolerance = 1e-8), stated))
  expect_not_comparable(merge(ours("information"), subset(information, time == 21, select = c(time, node))),
                        subset(information, time == 21), reference = "tsna", covers = "centrality_series()",
                        quantity = "information centrality, disconnected window", key = c("time", "node"),
                        reason = "Information centrality inverts a matrix that is singular on a disconnected graph: Dynet returns NA, sna a value near 0.")
  do.call(expect_reference, c(list(ours("flow_betweenness"), sna_series("flowbet", gmode = "digraph"),
                                   quantity = "flow betweenness", tolerance = 1e-8), stated))
})

test_that("load centrality equals networkx.load_centrality() on the whole-period graph", {
  ref_skip_without_python("networkx")
  arcs <- unique(spells[c("from", "to")])
  load <- ref_python(c(
    "import json, sys, networkx as nx",
    "given = json.load(open(sys.argv[1]))",
    "graph = nx.DiGraph()",
    "graph.add_nodes_from(given['people'])",
    "graph.add_edges_from(zip(given['from'], given['to']))",
    "json.dump(nx.load_centrality(graph, normalized=False), open(sys.argv[2], 'w'))"),
    list(people = people, from = arcs$from, to = arcs$to))
  theirs <- data.frame(node = names(load), measure = "load", value = unlist(load, use.names = FALSE))
  ours <- as.data.frame(centrality_series(network, measure = "load", window = "all"))
  # Sums of path fractions over 14 vertices.
  expect_reference(ours, theirs, reference = "networkx", covers = series_covers, quantity = "load, whole period",
                   tolerance = 1e-9, key = c("node", "measure"), note = sprintf("networkx %s", ref_python_version("networkx")))
})

test_that("summary() of a degree series equals the mean, standard deviation and range of igraph's degrees", {
  skip_without_reference("igraph")
  degrees <- ref_node_table(lapply(onsets, \(lo) list(degree = igraph::degree(ref_snapshot(spells, lo, lo + 7, people),
                                                                               mode = "all"))), onsets)
  by_node <- split(degrees$value, degrees$node)
  theirs <- data.frame(node = names(by_node), mean = vapply(by_node, mean, numeric(1)),
                       sd = vapply(by_node, stats::sd, numeric(1)), min = vapply(by_node, min, numeric(1)),
                       max = vapply(by_node, max, numeric(1)))
  ours <- as.data.frame(summary(centrality_series(network, measure = "degree", step = 7, window = 7)))
  expect_reference(ours, theirs, reference = "igraph", covers = "summary.dynet_metric()",
                   quantity = "degree over four windows", tolerance = 1e-10, key = "node")
})

test_that("head() and tail() of a series return the first and last rows igraph's degrees give", {
  skip_without_reference("igraph")
  degrees <- ref_node_table(list(list(degree = igraph::degree(ref_snapshot(spells, 0, 7, people), mode = "all"))), 0)
  series <- centrality_series(network, measure = "degree", step = 7, window = 7)
  expect_reference(as.data.frame(head(series, 3)), utils::head(degrees, 3), reference = "igraph",
                   covers = "head.dynet_metric()", quantity = "first three rows", tolerance = 0,
                   key = c("time", "node", "measure"))
  last <- ref_node_table(list(list(degree = igraph::degree(ref_snapshot(spells, 21, 28, people), mode = "all"))), 21)
  expect_reference(as.data.frame(tail(series, 3)), utils::tail(last, 3), reference = "igraph",
                   covers = "tail.dynet_metric()", quantity = "last three rows", tolerance = 0,
                   key = c("time", "node", "measure"))
})

test_that("the deprecated dyn_centrality() gives igraph's degree, as centrality_series() does", {
  skip_without_reference("igraph")
  theirs <- ref_node_table(list(list(degree = igraph::degree(ref_snapshot(spells, 0, 22, people), mode = "all"))), 0)
  expect_warning(old <- dyn_centrality(network, measure = "degree", window = "all"), "deprecated")
  expect_reference(as.data.frame(old), theirs, reference = "igraph", covers = "dyn_centrality()",
                   quantity = "degree, whole period", tolerance = 0, key = c("node", "measure"))
})

test_that("total degree of each window against igraph on windows half as wide differs (negative control)", {
  skip_without_reference("igraph")
  # The last window is left out: the data end at 21.52, so its narrow and full windows hold the same spells.
  full <- utils::head(onsets, -1L)
  narrow <- data.frame(time = full, value = vapply(full, \(lo) sum(igraph::degree(ref_snapshot(spells, lo, lo + 3.5, people))),
                                                    numeric(1)))
  series <- subset(as.data.frame(centrality_series(network, measure = "degree", step = 7, window = 7)), time < 21)
  ours <- data.frame(time = full, value = as.numeric(tapply(series$value, series$time, sum)))
  expect_differs(ours, narrow, reference = "igraph", covers = "centrality_series()",
                 quantity = "total degree, reference on windows of 3.5", tolerance = 0.5, key = "time")
})
