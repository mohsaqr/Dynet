# The verbs built on the optimal journeys of a temporal network: pathways(), path_network(), path_trajectories(),
# temporal betweenness (path_centrality()) and edge_centrality(). On small random networks with one spell per
# ordered pair, every vertex-simple journey is enumerated (helper-reference.R), entered as early as possible; the
# optimal journeys to a vertex are the foremost ones with the fewest hops. Betweenness counts, over every source
# and target, the share of their optimal journeys through a vertex (as an intermediate) or along a spell.

by_enumeration <- "independent: exhaustive enumeration of vertex-simple journeys"
paths_covers <- c("paths()", "as.data.frame.dynet_paths()")
seeds <- c(21L, 22L, 23L)

#' A random network with one spell per ordered pair, so that a journey is named by its vertices
pair_unique_spells <- function(seed) {
  drawn <- ref_random_spells(seed, vertices = 6L, spells = 16L, span = 20)
  subset(drawn, !duplicated(paste(from, to)))
}

#' Every source's optimal journeys, with the number of optimal journeys between their two ends
all_optimal <- function(edges) {
  vertices <- sort(unique(c(edges$from, edges$to)))
  found <- do.call(rbind, lapply(vertices, \(source) {
    journeys <- optimal_journeys(edges, source)
    if (nrow(journeys)) cbind(source = source, journeys) else NULL
  }))
  per_pair <- stats::aggregate(cbind(n_optimal = n_hops) ~ source + node, found, length)
  merge(found, per_pair)
}

test_that("the number of foremost, then shortest, journeys equals exhaustive enumeration, through paths() and pathways()", {
  invisible(lapply(c(21L, 22L, 23L), \(seed) {
    # One spell per pair, so that a journey is named by its sequence of vertices.
    drawn <- ref_random_spells(seed, vertices = 6L, spells = 16L, span = 20)
    edges <- subset(drawn, !duplicated(paste(from, to)))
    source <- sort(unique(edges$from))[[1L]]
    origin <- min(edges$start)
    journeys <- rbind(data.frame(node = source, arrival_time = origin, n_hops = 0, route = source),
                      enumerate_journeys(edges, source, origin, source, 0))
    best <- foremost_by_enumeration(edges, source)
    optimal <- merge(journeys, best, by = c("node", "arrival_time", "n_hops"))
    counted <- stats::aggregate(cbind(n_paths = arrival_time) ~ node, optimal, length)
    by_enumeration <- "independent: exhaustive enumeration of vertex-simple journeys"
    expect_reference(subset(as.data.frame(paths(dynet(edges), from = source)), reachable), counted,
                     reference = by_enumeration, covers = paths_covers,
                     quantity = sprintf("number of optimal journeys, seed %d", seed), tolerance = 0, key = "node")
    routes <- merge(subset(counted, node != source), best)
    expected <- data.frame(endpoint = routes$node, count = routes$n_paths, min_hops = routes$n_hops,
                           first_arrival = routes$arrival_time)
    expect_reference(as.data.frame(summary(pathways(dynet(edges), from = source))), expected,
                     reference = by_enumeration, covers = c("pathways()", "summary.dynet_pathways()"),
                     quantity = sprintf("routes per endpoint, seed %d", seed), tolerance = 1e-10, key = "endpoint")
  }))
})

test_that("each optimal route, and each arc's use by them, equal exhaustive enumeration", {
  invisible(lapply(c(21L, 22L, 23L), \(seed) {
    drawn <- ref_random_spells(seed, vertices = 6L, spells = 16L, span = 20)
    edges <- subset(drawn, !duplicated(paste(from, to)))
    source <- sort(unique(edges$from))[[1L]]
    optimal <- optimal_journeys(edges, source)
    by_enumeration <- "independent: exhaustive enumeration of vertex-simple journeys"
    routes <- data.frame(route = optimal$route, endpoint = optimal$node, count = 1, n_hops = optimal$n_hops,
                         arrival_time = optimal$arrival_time)
    expect_reference(as.data.frame(pathways(dynet(edges), from = source)), routes, reference = by_enumeration,
                     covers = c("pathways()", "as.data.frame.dynet_pathways()"),
                     quantity = sprintf("optimal route, seed %d", seed), tolerance = 1e-10, key = "route")
    steps <- strsplit(optimal$route, " -> ", fixed = TRUE)
    arcs <- do.call(rbind, Map(\(stops, endpoint) {
      data.frame(from = utils::head(stops, -1L), to = utils::tail(stops, -1L), endpoint = endpoint)
    }, steps, optimal$node))
    used <- stats::aggregate(cbind(weight = endpoint) ~ from + to, arcs, length)
    reached <- stats::aggregate(cbind(n_endpoints = endpoint) ~ from + to, arcs, \(ends) length(unique(ends)))
    expect_reference(as.data.frame(path_network(paths(dynet(edges), from = source))), merge(used, reached),
                     reference = by_enumeration, covers = c("path_network()", "as.data.frame.dynet_path_network()"),
                     quantity = sprintf("arc use by optimal journeys, seed %d", seed), tolerance = 0, key = c("from", "to"))
  }))
})

test_that("the prefix tree of the optimal journeys from a source equals exhaustive enumeration", {
  invisible(lapply(seeds, \(seed) {
    edges <- pair_unique_spells(seed)
    source <- sort(unique(edges$from))[[1L]]
    optimal <- optimal_journeys(edges, source)
    steps <- strsplit(optimal$route, " -> ", fixed = TRUE)
    prefixes <- unlist(lapply(steps, \(stops) vapply(seq_along(stops)[-1L], \(depth) {
      paste(utils::head(stops, depth), collapse = " -> ")
    }, character(1))))
    counted <- table(prefixes)
    theirs <- rbind(data.frame(route = source, count = nrow(optimal) + 1),
                    data.frame(route = names(counted), count = as.numeric(counted)))
    ours <- transform(as.data.frame(path_trajectories(paths(dynet(edges), from = source))),
                      route = gsub("@[^ ]*", "", node))
    expect_reference(ours, theirs, reference = by_enumeration,
                     covers = c("path_trajectories()", "as.data.frame.dynet_path_trajectories()"),
                     quantity = sprintf("journeys through each prefix, seed %d", seed), tolerance = 0, key = "route")
  }))
})

test_that("summary() of the prefix tree and of the path network count branches, arcs and journeys by enumeration", {
  invisible(lapply(seeds, \(seed) {
    edges <- pair_unique_spells(seed)
    source <- sort(unique(edges$from))[[1L]]
    optimal <- optimal_journeys(edges, source)
    steps <- strsplit(optimal$route, " -> ", fixed = TRUE)
    hops <- lengths(steps) - 1L
    depths <- seq_len(max(hops))
    prefixes <- lapply(depths, \(depth) unique(vapply(steps[hops >= depth], \(stops) {
      paste(utils::head(stops, depth + 1L), collapse = " -> ")
    }, character(1))))
    theirs <- data.frame(depth = c(0, depths), branches = c(1, lengths(prefixes)),
                         vertices = c(1, vapply(depths, \(depth) {
                           length(unique(vapply(steps[hops >= depth], `[[`, character(1), depth + 1L)))
                         }, numeric(1))),
                         count = c(nrow(optimal) + 1, vapply(depths, \(depth) sum(hops >= depth), numeric(1))))
    found <- paths(dynet(edges), from = source)
    expect_reference(as.data.frame(summary(path_trajectories(found))), theirs, reference = by_enumeration,
                     covers = "summary.dynet_path_trajectories()", quantity = sprintf("per depth, seed %d", seed),
                     tolerance = 0, key = "depth")
    arcs <- unique(do.call(rbind, lapply(steps, \(stops) data.frame(from = utils::head(stops, -1L),
                                                                     to = utils::tail(stops, -1L)))))
    network_summary <- data.frame(property = c("edges", "total weight"), value = c(nrow(arcs), sum(hops)))
    ours <- transform(subset(as.data.frame(summary(path_network(found))), property %in% network_summary$property),
                      value = as.numeric(value))
    expect_reference(ours, network_summary, reference = by_enumeration, covers = "summary.dynet_path_network()",
                     quantity = sprintf("arcs and their use, seed %d", seed), tolerance = 0, key = "property")
  }))
})

test_that("temporal betweenness equals the share of optimal journeys through each vertex, over all sources", {
  invisible(lapply(seeds, \(seed) {
    edges <- pair_unique_spells(seed)
    vertices <- sort(unique(c(edges$from, edges$to)))
    found <- all_optimal(edges)
    inner <- lapply(strsplit(found$route, " -> ", fixed = TRUE), \(stops) utils::head(stops[-1L], -1L))
    through <- vapply(vertices, \(vertex) sum(vapply(inner, \(stops) vertex %in% stops, logical(1)) / found$n_optimal),
                      numeric(1))
    theirs <- data.frame(node = vertices, measure = "betweenness", value = unname(through))
    ours <- as.data.frame(path_centrality(dynet(edges), measure = "betweenness"))
    # Sums of a few ratios of small integers.
    expect_reference(ours, theirs, reference = by_enumeration, covers = "path_centrality()",
                     quantity = sprintf("temporal betweenness, seed %d", seed), tolerance = 1e-12,
                     key = c("node", "measure"))
  }))
})

test_that("temporal edge betweenness equals the share of optimal journeys along each spell, over all sources", {
  invisible(lapply(seeds, \(seed) {
    edges <- pair_unique_spells(seed)
    found <- all_optimal(edges)
    steps <- strsplit(found$route, " -> ", fixed = TRUE)
    arcs <- do.call(rbind, Map(\(stops, share) {
      data.frame(from = utils::head(stops, -1L), to = utils::tail(stops, -1L), share = share)
    }, steps, 1 / found$n_optimal))
    along <- stats::aggregate(share ~ from + to, arcs, sum)
    theirs <- merge(edges[c("from", "to")], along, all.x = TRUE)
    theirs <- transform(theirs, measure = "betweenness", value = ifelse(is.na(share), 0, share), share = NULL)
    ours <- as.data.frame(edge_centrality(dynet(edges)))
    expect_reference(ours, theirs, reference = by_enumeration, covers = "edge_centrality()",
                     quantity = sprintf("temporal edge betweenness, seed %d", seed), tolerance = 1e-12,
                     key = c("from", "to", "measure"))
  }))
})

test_that("temporal betweenness counting the endpoints of each journey differs (negative control)", {
  edges <- pair_unique_spells(21L)
  found <- all_optimal(edges)
  stops <- strsplit(found$route, " -> ", fixed = TRUE)
  with_ends <- sum(vapply(stops, length, numeric(1)) / found$n_optimal)
  ours <- as.data.frame(path_centrality(dynet(edges), measure = "betweenness"))
  expect_differs(sum(ours$value), with_ends, reference = by_enumeration, covers = "path_centrality()",
                 quantity = "total betweenness with endpoints counted", tolerance = 1e-6)
})
