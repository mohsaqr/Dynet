# metrics(): graph-level structure in each window of a temporal network, on the bundled school_contacts spells.
# Each window's snapshot is the set of ordered pairs with a spell overlapping it. igraph measures the snapshot;
# sna measures it through tsna::tSnaStats(), which builds the windows itself from a networkDynamic object.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
onsets <- c(0, 7, 14, 21)
network <- dynet(school_contacts)
metric_covers <- c("metrics()", "as.data.frame.dynet_metric()")

triad_classes <- c("003", "012", "102", "021D", "021U", "021C", "111D", "111U", "030T", "030C", "201", "120D",
                   "120U", "120C", "210", "300")

test_that("counts, density, reciprocity, components, distances and the censuses equal igraph in windows of 7", {
  skip_without_reference("igraph")
  per_window <- lapply(onsets, \(lo) {
    graph <- ref_snapshot(spells, lo, lo + 7, people)
    dyads <- igraph::dyad_census(graph)
    values <- c(edges = igraph::ecount(graph), density = igraph::edge_density(graph),
                reciprocity = igraph::reciprocity(graph), components = igraph::count_components(graph, mode = "weak"),
                components_strong = igraph::count_components(graph, mode = "strong"),
                isolates = sum(igraph::degree(graph, mode = "all") == 0), mutual = dyads$mut,
                asymmetric = dyads$asym, null = dyads$null,
                mean_distance = igraph::mean_distance(graph, directed = TRUE, unconnected = TRUE),
                diameter = igraph::diameter(graph, directed = TRUE, unconnected = TRUE),
                stats::setNames(igraph::triad_census(graph), paste0("triad_", triad_classes)))
    data.frame(time = lo, measure = names(values), value = unname(values))
  })
  ours <- as.data.frame(metrics(network, measure = c("edges", "density", "reciprocity", "components",
                                                     "components_strong", "isolates", "mutual", "asymmetric", "null",
                                                     "mean_distance", "diameter", "triads"), step = 7, window = 7))
  # Counts and ratios of counts; mean distance is a ratio of integer sums.
  expect_reference(ours, do.call(rbind, per_window), reference = "igraph", covers = metric_covers,
                   quantity = "windows of 7", tolerance = 1e-10, key = c("time", "measure"))
})

test_that("the largest component and the active vertices equal igraph in windows of 7", {
  skip_without_reference("igraph")
  per_window <- lapply(onsets, \(lo) {
    graph <- ref_snapshot(spells, lo, lo + 7, people)
    values <- c(largest_component = max(igraph::components(graph, mode = "weak")$csize) / length(people),
                active_nodes = sum(igraph::degree(graph, mode = "all") > 0))
    data.frame(time = lo, measure = names(values), value = unname(values))
  })
  ours <- as.data.frame(metrics(network, measure = c("largest_component", "active_nodes"), step = 7, window = 7))
  expect_reference(ours, do.call(rbind, per_window), reference = "igraph",
                   covers = metric_covers, quantity = "share of vertices in the largest component, and active vertices",
                   tolerance = 1e-12, key = c("time", "measure"))
})

test_that("density, transitivity, reciprocity, Krackhardt's indices and degree centralization equal sna through tsna", {
  skip_without_reference(c("tsna", "sna", "networkDynamic"))
  history <- ref_network_dynamic(spells)
  sna_series <- function(snafun, label, ...) {
    values <- tsna::tSnaStats(history, snafun = snafun, start = 0, end = 21, time.interval = 7, aggregate.dur = 7,
                              ...)
    data.frame(time = onsets, measure = label, value = as.numeric(values))
  }
  theirs <- rbind(sna_series("gden", "density", mode = "digraph"),
                  sna_series("gtrans", "transitivity", mode = "digraph"),
                  sna_series("grecip", "reciprocity", measure = "edgewise"),
                  sna_series("mutuality", "mutual"),
                  sna_series("components", "components_strong"),
                  sna_series("connectedness", "connectedness"),
                  sna_series("efficiency", "efficiency"),
                  sna_series("hierarchy", "hierarchy", measure = "krackhardt"),
                  sna_series("lubness", "lubness"),
                  sna_series("centralization", "centralization_degree", FUN = sna::degree, mode = "digraph"))
  ours <- as.data.frame(metrics(network, measure = unique(theirs$measure), start = 0, end = 21, step = 7, window = 7))
  # Counts and ratios of counts.
  expect_reference(ours, theirs, reference = "tsna", covers = metric_covers, quantity = "windows of 7",
                   tolerance = 1e-10, key = c("time", "measure"))
})

test_that("the triad census equals sna::triad.census() and the dyad census sna::dyad.census() on the whole period", {
  skip_without_reference("sna")
  adjacency <- ref_adjacency(spells, 0, 22, people)
  triads <- sna::triad.census(adjacency, mode = "digraph")
  dyads <- sna::dyad.census(adjacency)
  theirs <- data.frame(measure = c(paste0("triad_", triad_classes), "mutual", "asymmetric", "null"),
                       value = c(as.numeric(triads), as.numeric(dyads)))
  ours <- as.data.frame(metrics(network, measure = c("triads", "mutual", "asymmetric", "null"), window = "all"))
  expect_reference(ours, theirs, reference = "sna", covers = metric_covers, quantity = "censuses, whole period",
                   tolerance = 0, key = "measure")
})

test_that("closeness centralization is sna's, rescaled from sna's theoretical maximum to Dynet's", {
  skip_without_reference("sna")
  n <- length(people)
  adjacency <- ref_adjacency(spells, 0, 22, people)
  undirected <- dynet(school_contacts, directed = FALSE)
  raw <- c(directed = sna::centralization(adjacency, sna::closeness, mode = "digraph"),
           undirected = sna::centralization(pmax(adjacency, t(adjacency)), sna::closeness, mode = "graph"))
  # Dynet divides by the largest possible sum of differences, n - 1 (directed) or n - 2 (undirected); sna by
  # (n - 1)^2 / n and (n - 1)(n - 2) / (2n - 3). The ratios turn one into the other.
  rescaled <- raw * c(((n - 1)^2 / n) / (n - 1), ((n - 1) * (n - 2) / (2 * n - 3)) / (n - 2))
  ours <- c(directed = as.data.frame(metrics(network, measure = "centralization_closeness", window = "all"))$value,
            undirected = as.data.frame(metrics(undirected, measure = "centralization_closeness", window = "all"))$value)
  expect_reference(ours, rescaled, reference = "sna", covers = "metrics()",
                   quantity = "closeness centralization, whole period, on Dynet's scale", tolerance = 1e-12)
  expect_known_difference(ours, raw, reference = "sna", covers = "metrics()",
                          quantity = "closeness centralization, whole period", tolerance = 1e-12,
                          reason = "Dynet normalises by the maximum sum of differences n - 1 (directed) or n - 2 (undirected); sna::centralization() by (n - 1)^2 / n and (n - 1)(n - 2) / (2n - 3).",
                          agrees_with = "sna's value times the ratio of the two maxima")
})

test_that("edge counts in windows of 7 against igraph on windows of 3.5 differ (negative control)", {
  skip_without_reference("igraph")
  # The last window is left out: the data end at 21.52, so its narrow and full windows hold the same spells.
  narrow <- do.call(rbind, lapply(utils::head(onsets, -1L), \(lo) {
    data.frame(time = lo, measure = "edges", value = igraph::ecount(ref_snapshot(spells, lo, lo + 3.5, people)))
  }))
  ours <- subset(as.data.frame(metrics(network, measure = "edges", step = 7, window = 7)), time < 21)
  expect_differs(ours, narrow, reference = "igraph", covers = "metrics()", quantity = "edges, reference on windows of 3.5",
                 tolerance = 0.5, key = c("time", "measure"))
})
