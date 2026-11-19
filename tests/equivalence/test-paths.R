# paths(), reachability() and path_centrality(): time-respecting journeys. An interval spell [start, end) can be
# entered at any instant from its onset up to but excluding its terminus; waiting is free and a hop takes no time.
# References: tsna::tPath() and tsna::tReach() run live, the earliest-arrival recurrence, and exhaustive
# enumeration of every vertex-simple journey on small random networks.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
network <- dynet(school_contacts)
paths_covers <- c("paths()", "as.data.frame.dynet_paths()")

test_that("earliest arrival from five pupils equals tsna::tPath()", {
  skip_without_reference(c("tsna", "networkDynamic"))
  history <- ref_network_dynamic(spells)
  sources <- utils::head(people, 5L)
  theirs <- do.call(rbind, lapply(sources, \(source) {
    found <- tsna::tPath(history, v = match(source, people), start = 0, direction = "fwd")
    data.frame(source = source, node = people, reachable = is.finite(found$tdist), arrival_time = found$tdist)
  }))
  ours <- do.call(rbind, lapply(sources, \(source) {
    cbind(source = source, as.data.frame(paths(network, from = source, at = 0)))
  }))
  expect_reference(subset(ours, select = c(source, node, reachable)), subset(theirs, select = c(source, node, reachable)),
                   reference = "tsna", covers = paths_covers, quantity = "reached", tolerance = 0,
                   key = c("source", "node"))
  reached <- subset(theirs, reachable, select = c(source, node, arrival_time))
  # Arrival times are input times copied through.
  expect_reference(merge(ours, reached[c("source", "node")]), reached, reference = "tsna", covers = paths_covers,
                   quantity = "earliest arrival from t = 0", tolerance = 1e-10, key = c("source", "node"))
})

test_that("earliest arrival and latency from Ana equal the earliest-arrival recurrence", {
  arrival <- ref_earliest_arrival(spells, "Ana", min(spells$start), people)
  theirs <- data.frame(node = people, arrival_time = unname(arrival), latency = unname(arrival) - min(spells$start))
  ours <- as.data.frame(paths(network, from = "Ana"))
  expect_reference(ours, theirs, reference = "independent: earliest-arrival recurrence, base R",
                   covers = paths_covers, quantity = "from Ana", tolerance = 1e-10, key = "node")
})

test_that("arrival time and hops of the foremost journeys equal exhaustive enumeration on random networks", {
  invisible(lapply(c(11L, 12L, 13L), \(seed) {
    edges <- ref_random_spells(seed, vertices = 6L, spells = 14L, span = 20)
    source <- sort(unique(edges$from))[[1L]]
    theirs <- foremost_by_enumeration(edges, source)
    ours <- subset(as.data.frame(paths(dynet(edges), from = source)), reachable)
    expect_reference(ours, theirs, reference = "independent: exhaustive enumeration of vertex-simple journeys",
                     covers = paths_covers, quantity = sprintf("foremost journeys, seed %d", seed), tolerance = 1e-10,
                     key = "node")
  }))
})

test_that("summary() of the journeys from Ana gives the reach and latencies of the earliest-arrival recurrence", {
  arrival <- ref_earliest_arrival(spells, "Ana", min(spells$start), people)
  latency <- (arrival - min(spells$start))[names(arrival) != "Ana" & is.finite(arrival)]
  theirs <- data.frame(property = c("reachable", "reachable share", "median latency", "max latency"),
                       value = c(length(latency), length(latency) / (length(people) - 1), stats::median(latency),
                                 max(latency)))
  ours <- transform(subset(as.data.frame(summary(paths(network, from = "Ana"))), property %in% theirs$property),
                    value = as.numeric(value))
  # The summary prints its values rounded to a few decimals.
  expect_reference(ours, theirs, reference = "independent: earliest-arrival recurrence, base R",
                   covers = "summary.dynet_paths()", quantity = "journeys from Ana", tolerance = 1e-6, key = "property")
})

test_that("forward and backward reach counts from t = 18 equal tsna::tReach()", {
  skip_without_reference(c("tsna", "networkDynamic"))
  history <- ref_network_dynamic(spells)
  last <- max(spells$end)
  reach <- \(direction) tsna::tReach(history, direction = direction, sample = length(people), start = 18, end = last,
                                     graph.step.time = 0) - 1
  theirs <- data.frame(node = rep(people, 2L), measure = rep(c("forward_reach_count", "backward_reach_count"),
                                                              each = length(people)),
                       value = c(reach("fwd"), reach("bkwd")))
  ours <- as.data.frame(reachability(network, direction = "both", start = 18, measure = "reach_count"))
  expect_reference(ours, theirs, reference = "tsna", covers = c("reachability()", "as.data.frame.dynet_metric()"),
                   quantity = "reach count from t = 18", tolerance = 0, key = c("node", "measure"))
})

test_that("reach counts and temporal closeness from t = 18 equal the earliest-arrival recurrence", {
  late <- vapply(people, \(source) ref_earliest_arrival(spells, source, 18, people), numeric(length(people)))
  dimnames(late) <- list(to = people, from = people)
  reached <- is.finite(late) & row(late) != col(late)
  latency <- ifelse(reached, late - 18, 0)
  by_recurrence <- "independent: earliest-arrival recurrence, base R"
  counts <- data.frame(node = rep(people, 2L),
                       measure = rep(c("forward_reach_count", "backward_reach_count"), each = length(people)),
                       value = c(colSums(reached), rowSums(reached)))
  expect_reference(as.data.frame(reachability(network, direction = "both", start = 18, measure = "reach_count")),
                   counts, reference = by_recurrence, covers = "reachability()", quantity = "reach count from t = 18",
                   tolerance = 0, key = c("node", "measure"))
  expect_warning(old <- dyn_reachability(network, direction = "both", start = 18, measure = "reach_count"),
                 "deprecated")
  expect_reference(as.data.frame(old), counts, reference = by_recurrence, covers = "dyn_reachability()",
                   quantity = "reach count from t = 18, deprecated name", tolerance = 0, key = c("node", "measure"))
  closeness <- data.frame(node = people, measure = "closeness",
                          value = ifelse(colSums(reached) > 0, colSums(reached) / colSums(latency), 0))
  # One division of a short sum of subtractions.
  expect_reference(as.data.frame(path_centrality(network, measure = "closeness", start = 18)), closeness,
                   reference = by_recurrence, covers = "path_centrality()",
                   quantity = "temporal closeness from t = 18", tolerance = 1e-10, key = c("node", "measure"))
})

test_that("latency from Ana against the recurrence started at t = 5 differs (negative control)", {
  arrival <- ref_earliest_arrival(spells, "Ana", 5, people)
  late <- subset(data.frame(node = people, latency = unname(arrival) - 5), node != "Ana" & is.finite(latency))
  ours <- subset(as.data.frame(paths(network, from = "Ana")), node %in% late$node)
  expect_differs(ours, late, reference = "independent: earliest-arrival recurrence, base R", covers = "paths()",
                 quantity = "latency from Ana, reference started at t = 5", tolerance = 1e-6, key = "node")
})
