# Journeys, reach, tie formation and durations against tsna and networkDynamic run live, on the bundled
# school_contacts spells and on networks drawn by simulab::simulate_temporal_network(), plus a recovery of
# simulab's formation and dissolution probabilities by events().
#   - dyn_reachability()           tsna::tReach() (the deprecated name of reachability());
#   - path_centrality(closeness)   reached vertices over summed latency, the latencies from tsna::tPath();
#   - summary.dynet_paths()        reach and latencies of tsna::tPath() from one source;
#   - pathways()                   each endpoint's foremost arrival, against tsna::tPath();
#   - events()                     formations and dissolutions per period, against tsna::tEdgeFormation() and
#                                  tsna::tEdgeDissolution();
#   - durations()                  per pair, networkDynamic::network.collapse()'s activity count and duration.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
network <- dynet(school_contacts)
last <- max(spells$end)

sim_spells <- function(seed, nodes = 8, periods = 30, formation = 0.05, dissolution = 0.3) {
  drawn <- as.data.frame(simulab::simulate_temporal_network(nodes = nodes, periods = periods,
                                                              initial_probability = 0.2,
                                                              formation_probability = formation,
                                                              dissolution_probability = dissolution, seed = seed))
  data.frame(from = drawn$from, to = drawn$to, start = as.numeric(drawn$onset), end = as.numeric(drawn$terminus))
}

#' Earliest arrival from every vertex at `start`, by tsna::tPath(): one row per source and target
tsna_arrivals <- function(edges, start, vertices = sort(unique(c(edges$from, edges$to)))) {
  history <- ref_network_dynamic(edges, vertices = vertices)
  do.call(rbind, lapply(vertices, \(source) {
    found <- tsna::tPath(history, v = match(source, vertices), start = start, direction = "fwd")
    data.frame(source = source, node = vertices, tdist = found$tdist)
  }))
}

test_that("dyn_reachability() reach counts from t = 18 equal tsna::tReach()", {
  skip_without_reference(c("tsna", "networkDynamic"))
  history <- ref_network_dynamic(spells)
  reach <- \(direction) tsna::tReach(history, direction = direction, sample = length(people), start = 18, end = last,
                                     graph.step.time = 0) - 1
  theirs <- data.frame(node = rep(people, 2L), measure = rep(c("forward_reach_count", "backward_reach_count"),
                                                              each = length(people)),
                       value = c(reach("fwd"), reach("bkwd")))
  expect_warning(old <- dyn_reachability(network, direction = "both", start = 18, measure = "reach_count"),
                 "deprecated")
  expect_reference(as.data.frame(old), theirs, reference = "tsna", covers = "dyn_reachability()",
                   quantity = "reach count from t = 18, deprecated name", tolerance = 0, key = c("node", "measure"))
})

test_that("temporal closeness equals reached vertices over the summed tsna::tPath() latencies", {
  skip_without_reference(c("tsna", "networkDynamic"))
  cases <- list(list(name = "school_contacts from t = 18", edges = spells, start = 18),
                list(name = "school_contacts from t = 0", edges = spells, start = 0),
                list(name = "simulab seed 11 from t = 1", edges = sim_spells(11L), start = 1),
                list(name = "simulab seed 12 from t = 1", edges = sim_spells(12L), start = 1))
  rows <- lapply(cases, \(case) {
    found <- subset(tsna_arrivals(case$edges, case$start), source != node)
    reached <- is.finite(found$tdist)
    count <- tapply(reached, found$source, sum)
    latency <- tapply(ifelse(reached, found$tdist, 0), found$source, sum)
    list(ours = cbind(case = case$name, as.data.frame(path_centrality(dynet(case$edges), measure = "closeness",
                                                                       start = case$start))),
         theirs = data.frame(case = case$name, node = names(count), measure = "closeness",
                             value = ifelse(count > 0, as.numeric(count) / as.numeric(latency), 0)))
  })
  # One division of a short sum of latencies.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "tsna", covers = "path_centrality()", quantity = "temporal closeness",
                   tolerance = 1e-10, key = c("case", "node", "measure"))
})

test_that("summary() of the journeys from one vertex gives tsna::tPath()'s reach and latencies", {
  skip_without_reference(c("tsna", "networkDynamic"))
  cases <- list(list(name = "Ana", edges = spells, source = "Ana"),
                list(name = "simulab seed 13, Node 1", edges = sim_spells(13L), source = "Node 1"))
  rows <- lapply(cases, \(case) {
    vertices <- sort(unique(c(case$edges$from, case$edges$to)))
    origin <- min(case$edges$start)
    found <- subset(tsna_arrivals(case$edges, origin, vertices), source == case$source & node != case$source &
                      is.finite(tdist))
    theirs <- data.frame(case = case$name, property = c("reachable", "reachable share", "median latency", "max latency"),
                         value = c(nrow(found), nrow(found) / (length(vertices) - 1), stats::median(found$tdist),
                                   max(found$tdist)))
    ours <- transform(subset(as.data.frame(summary(paths(dynet(case$edges), from = case$source))),
                             property %in% theirs$property), value = as.numeric(value))
    list(ours = cbind(case = case$name, ours), theirs = theirs)
  })
  # The summary prints its values rounded to a few decimals.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "tsna", covers = "summary.dynet_paths()", quantity = "journeys from one vertex",
                   tolerance = 1e-6, key = c("case", "property"))
})

test_that("each endpoint's foremost arrival in pathways() equals tsna::tPath()", {
  skip_without_reference(c("tsna", "networkDynamic"))
  rows <- lapply(c(21L, 22L, 23L, 24L), \(seed) {
    drawn <- ref_random_spells(seed, vertices = 6L, spells = 16L, span = 20)
    edges <- subset(drawn, !duplicated(paste(from, to)))
    source <- sort(unique(edges$from))[[1L]]
    origin <- min(edges$start)
    arrivals <- tsna_arrivals(edges, origin)
    found <- arrivals[arrivals$source == source & arrivals$node != source & is.finite(arrivals$tdist), ]
    routes <- unique(subset(as.data.frame(pathways(dynet(edges), from = source)), select = c(endpoint, arrival_time)))
    endpoints <- subset(as.data.frame(summary(pathways(dynet(edges), from = source))), select = c(endpoint, first_arrival))
    list(routes = cbind(seed = seed, routes), endpoints = cbind(seed = seed, endpoints),
         theirs = data.frame(seed = seed, endpoint = found$node, arrival_time = origin + found$tdist,
                             first_arrival = origin + found$tdist))
  })
  theirs <- do.call(rbind, lapply(rows, `[[`, "theirs"))
  # Arrival times are input times copied through.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "routes")), subset(theirs, select = c(seed, endpoint, arrival_time)),
                   reference = "tsna", covers = c("pathways()", "as.data.frame.dynet_pathways()"),
                   quantity = "arrival of the optimal routes per endpoint", tolerance = 1e-10, key = c("seed", "endpoint"))
  expect_reference(do.call(rbind, lapply(rows, `[[`, "endpoints")),
                   subset(theirs, select = c(seed, endpoint, first_arrival)), reference = "tsna",
                   covers = "summary.dynet_pathways()", quantity = "first arrival per endpoint", tolerance = 1e-10,
                   key = c("seed", "endpoint"))
})

test_that("formations and dissolutions per period equal tsna::tEdgeFormation() and tsna::tEdgeDissolution()", {
  skip_without_reference(c("tsna", "networkDynamic"))
  rows <- lapply(c(14L, 15L, 16L), \(seed) {
    edges <- sim_spells(seed)
    history <- ref_network_dynamic(edges)
    times <- seq(2, 30)
    formed <- tsna::tEdgeFormation(history, start = 2, end = 30, time.interval = 1)
    dissolved <- tsna::tEdgeDissolution(history, start = 2, end = 30, time.interval = 1)
    ours <- subset(as.data.frame(events(dynet(edges), measure = c("formation", "dissolution"), start = 2, end = 30,
                                        step = 1, window = 1)), select = c(time, measure, value))
    list(ours = cbind(seed = seed, ours),
         theirs = data.frame(seed = seed, time = rep(stats::time(formed), 2L),
                             measure = rep(c("formation", "dissolution"), each = length(formed)),
                             value = c(as.numeric(formed), as.numeric(dissolved))))
  })
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "tsna", covers = "events()", quantity = "per period, simulab networks", tolerance = 0,
                   key = c("seed", "time", "measure"))
})

test_that("per-pair spell counts and durations equal networkDynamic::network.collapse()", {
  skip_without_reference(c("networkDynamic", "network"))
  rows <- lapply(c(17L, 18L, 19L), \(seed) {
    edges <- sim_spells(seed)
    collapsed <- networkDynamic::network.collapse(ref_network_dynamic(edges), onset = 0, terminus = 100,
                                                  rm.time.info = FALSE)
    arcs <- as.data.frame(collapsed, unit = "edges")
    pair <- paste(arcs$.tail, arcs$.head)
    theirs <- data.frame(seed = seed, pair = rep(pair, 4L),
                         measure = rep(c("events", "total", "union", "mean"), each = length(pair)),
                         value = c(arcs$activity.count, arcs$activity.duration, arcs$activity.duration,
                                   arcs$activity.duration / arcs$activity.count))
    ours <- transform(as.data.frame(durations(dynet(edges), measure = c("events", "total", "union", "mean"))),
                      pair = paste(from, to))
    list(ours = cbind(seed = seed, subset(ours, select = c(pair, measure, value))), theirs = theirs)
  })
  # No two spells of a pair overlap in these networks, so the summed and the merged durations coincide.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "networkDynamic", covers = "durations()", quantity = "per pair, simulab networks",
                   tolerance = 1e-12, key = c("seed", "pair", "measure"))
  ours_union <- transform(as.data.frame(durations(network, measure = "union")), pair = paste(from, to))
  collapsed <- networkDynamic::network.collapse(ref_network_dynamic(spells), onset = 0, terminus = last,
                                                rm.time.info = FALSE)
  arcs <- as.data.frame(collapsed, unit = "edges")
  # school_contacts has overlapping spells of one pair: networkDynamic merges them, which is the union duration.
  expect_reference(subset(ours_union, select = c(pair, value)),
                   data.frame(pair = paste(arcs$.tail, arcs$.head), value = arcs$activity.duration),
                   reference = "networkDynamic", covers = "durations()", quantity = "union duration, school_contacts",
                   tolerance = 1e-10, key = "pair")
})

test_that("events() recovers simulab's formation and dissolution probabilities (Monte Carlo summary)", {
  nodes <- 30
  periods <- 60
  formation <- 0.05
  dissolution <- 0.3
  dyads <- nodes * (nodes - 1)
  # Fixed from the parameters before any run. At t = 2..60 each dyad inactive at t - 1 forms with probability
  # 0.05 and each active one dissolves with probability 0.3. The active share starts at 0.2 and tends to
  # 0.05 / 0.35 = 0.143, so at least 80% of the 870 dyads (696) are at risk of forming and at least 12% (104) of
  # dissolving at each of the 59 instants; the mean of the 59 fractions has a binomial standard error of at most
  # sqrt(0.05 * 0.95 / (696 * 59)) = 0.00108 and sqrt(0.3 * 0.7 / (104 * 59)) = 0.00585. Four of each.
  tolerance_formation <- 4 * sqrt(formation * (1 - formation) / (0.8 * dyads * (periods - 1)))
  tolerance_dissolution <- 4 * sqrt(dissolution * (1 - dissolution) / (0.12 * dyads * (periods - 1)))
  rows <- do.call(rbind, lapply(1:5, \(seed) {
    net <- dynet(sim_spells(seed, nodes = nodes, periods = periods, formation = formation, dissolution = dissolution))
    fraction <- \(measure) mean(as.data.frame(events(net, measure = measure, start = 2, end = periods, step = 1,
                                                     window = 0))$value)
    data.frame(seed = seed, formation = fraction("formation_fraction"),
               dissolution = fraction("dissolution_fraction"))
  }))
  recovery <- "independent: recovery of the parameters of simulab simulate_temporal_network()"
  expect_reference(subset(rows, select = c(seed, formation)), data.frame(seed = 1:5, formation = formation),
                   reference = recovery, covers = "events()", quantity = "Monte Carlo summary: formation probability",
                   tolerance = tolerance_formation, key = "seed")
  expect_reference(subset(rows, select = c(seed, dissolution)), data.frame(seed = 1:5, dissolution = dissolution),
                   reference = recovery, covers = "events()",
                   quantity = "Monte Carlo summary: dissolution probability", tolerance = tolerance_dissolution,
                   key = "seed")
})
