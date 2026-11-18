# Exports Dynet comparison cases as bundles for Prova Verify (format:
# plan/24-verify.md in the prova repository), with Prova's R writer.
#
# Every live side of a case is an R script, stored in the bundle and run there
# in its own R process: its console is the side's raw output and the table it
# leaves in `result` holds the side's values. Quantities are matched by name.
#
# References, in the order the package's own tests and equivalence scripts use
# them: igraph for the graph kernels (local_testing_and_equivalence/
# kernels-vs-statnet.R), base R / stats for the definition-level quantities
# (the "-vs-independent", "-vs-exhaustive", "-vs-direct-formulas" scripts), and
# tsna, whose values for temporal density are pinned as literals in
# tests/testthat/test-temporal-density-span-contract.R. tsna, networkDynamic
# and sna are compared live only when installed; here they are a retained side.
#
# Run from the package root:
#   PROVA_VERIFY_R=<prova>/reporters/verify.R \
#     Rscript equivalence/verify/export-bundles.R [case ...]
source(Sys.getenv("PROVA_VERIFY_R", file.path("..", "prova", "reporters", "verify.R")))

.verify_base <- file.path("equivalence", "verify")
.verify_generator <- "Dynet equivalence/verify/export-bundles.R"
.verify_read <- "contacts <- utils::read.delim(\"../data/school_contacts.tsv\")"

#' The bundled contact data every case uses, written to a file
#'
#' `school_contacts`: 240 directed interval spells among 14 pupils over 21.52
#' time units, 110 distinct ordered pairs, several of them with overlapping
#' spells. It is the dataset the package's own tsna-pinned tests use.
#' @return The path of a tab-separated spell list named `school_contacts.tsv`.
.verify_contacts <- function() {
  loaded <- new.env(parent = emptyenv())
  load(file.path("data", "school_contacts.rda"), envir = loaded)
  contacts <- loaded$school_contacts
  stopifnot(
    "`school_contacts` must have from, to, start, end" =
      identical(names(contacts), c("from", "to", "start", "end")),
    "`school_contacts` must have no missing value" = !anyNA(contacts)
  )
  file <- file.path(tempdir(), "school_contacts.tsv")
  utils::write.table(contacts, file, sep = "\t", quote = FALSE, row.names = FALSE)
  file
}

# verify_run() writes the script it runs with setdiff(), which also drops every
# repeated line (a second closing brace, say). A script therefore travels as one
# element holding all its lines; only the `library()` line of the package's own
# side stays apart, because that is the line the writer takes out for `load`.
.verify_lines <- function(...) paste(c(...), collapse = "\n")

.dynet <- function(script, key = NULL) {
  # The development source is what runs (`load`), so the version is the source's
  # own, read from DESCRIPTION, not that of whatever copy may be installed.
  verify_side("dynet", name = "Dynet", package = "Dynet", primary = TRUE, load = ".", key = key,
              version = unname(read.dcf("DESCRIPTION")[1L, "Version"]),
              script = c("library(Dynet)", .verify_lines(.verify_read, "network <- dynet(contacts)", script)))
}
.igraph <- function(script) {
  verify_side("igraph", package = "igraph", authority = "open-source",
              url = "https://cran.r-project.org/package=igraph",
              script = .verify_lines("library(igraph)", .verify_read, script))
}
.base <- function(script, key = NULL) {
  verify_side("base-r", name = "base R, from the definition", authority = "independent",
              version = as.character(getRversion()), role = "definition-level oracle", key = key,
              script = .verify_lines(.verify_read, script))
}

# Shared reference code -------------------------------------------------------

# A window [lo, hi) holds a spell [start, end) when the two overlap; the any-time
# union of those spells is the window's binary directed snapshot.
.igraph_snapshot <- c(
  "people <- sort(unique(c(contacts$from, contacts$to)))",
  "snapshot <- function(lo, hi) {",
  "  active <- contacts[contacts$start < hi & contacts$end > lo, c(\"from\", \"to\")]",
  "  simplify(graph_from_data_frame(active, directed = TRUE, vertices = people))",
  "}",
  "long <- function(time, measure, name, value) {",
  "  data.frame(quantity = sprintf(\"%s t=%g: %s\", measure, time, name), kind = measure, value = as.numeric(value))",
  "}")

# The length of the union of a set of intervals: sort by onset, start a new run
# wherever an onset lies beyond everything seen so far.
.base_union <- c(
  "union_length <- function(start, end) {",
  "  by_onset <- order(start)",
  "  start <- start[by_onset]",
  "  reach <- cummax(end[by_onset])",
  "  opens <- c(TRUE, start[-1] > head(reach, -1))",
  "  sum(tapply(reach, cumsum(opens), max) - start[opens])",
  "}")

#' Every live case: its words, its tolerance and the script of each side
#'
#' A script's paths are relative to its own folder inside the bundle. Each
#' leaves a long data frame `result` with `quantity`, `kind` and `value`.
#' Tolerances were fixed before the first run; the reason is beside each.
#' @return A named list of cases.
.verify_cases <- function() {
  list(
    construction_counts = list(
      title = "A temporal network from a spell list, and its counts",
      description = "dynet() builds a directed temporal network from 240 interval spells. Its vertex, spell and pair counts, its observed range, and each ordered pair's number of spells, summed duration, union duration and mean spell duration are compared with the same quantities taken from the spell list in base R.",
      covers = c("dynet()", "summary.dynet()", "durations()"),
      # Counts are integers and every duration is a sum of at most a dozen
      # two-decimal numbers, so anything beyond accumulated rounding is a defect.
      tolerance = 1e-10,
      sides = list(
        .dynet(c(
          "network",
          "overview <- summary(network)",
          "overview",
          "counts <- subset(overview, property %in% c(\"vertices\", \"edge spells\", \"distinct pairs\",",
          "                                            \"observed from\", \"observed to\", \"span\", \"time bins\"))",
          "ties <- as.data.frame(durations(network, measure = c(\"events\", \"total\", \"union\", \"mean\")))",
          "head(ties)",
          "result <- rbind(",
          "  subset(transform(counts, quantity = property, kind = \"network\", value = as.numeric(value)),",
          "         select = c(quantity, kind, value)),",
          "  subset(transform(ties, quantity = sprintf(\"%s: %s -> %s\", measure, from, to), kind = measure),",
          "         select = c(quantity, kind, value)))")),
        .base(c(
          .base_union,
          "contacts$duration <- contacts$end - contacts$start",
          "pair <- paste(contacts$from, \"->\", contacts$to)",
          "network <- c(vertices = length(unique(c(contacts$from, contacts$to))), `edge spells` = nrow(contacts),",
          "             `distinct pairs` = length(unique(pair)), `observed from` = min(contacts$start),",
          "             `observed to` = max(contacts$end), span = max(contacts$end) - min(contacts$start),",
          "             `time bins` = ceiling(max(contacts$end) - min(contacts$start)))",
          "network",
          "ties <- list(events = tapply(contacts$duration, pair, length), total = tapply(contacts$duration, pair, sum),",
          "             union = vapply(split(contacts, pair), function(spells) union_length(spells$start, spells$end), numeric(1)),",
          "             mean = tapply(contacts$duration, pair, mean))",
          "result <- rbind(",
          "  data.frame(quantity = names(network), kind = \"network\", value = unname(network)),",
          "  do.call(rbind, Map(function(value, measure) {",
          "    data.frame(quantity = sprintf(\"%s: %s\", measure, names(value)), kind = measure, value = as.numeric(value))",
          "  }, ties, names(ties))))",
          "head(result, 12)")))),

    snapshot_centrality = list(
      title = "Centrality over time, in tiled seven-unit windows",
      description = "Degree, betweenness, closeness and coreness of every pupil in each seven-unit window of the school contacts (0, 7, 14, 21), against igraph on the binary directed snapshot of the same window. Closeness is reachable vertices over summed geodesic distance, which is igraph's normalised out-closeness with an isolate set to zero.",
      covers = "centrality_series()",
      # Degree and coreness are integers, betweenness and closeness are ratios
      # of small integers: exact arithmetic up to a few ulp on both sides.
      tolerance = 1e-10,
      sides = list(
        .dynet(c(
          "series <- centrality_series(network, measure = c(\"degree\", \"betweenness\", \"closeness\", \"coreness\"),",
          "                            mode = \"all\", step = 7, window = 7)",
          "series",
          "out_closeness <- centrality_series(network, measure = \"closeness\", mode = \"out\", step = 7, window = 7)",
          "result <- rbind(",
          "  transform(subset(as.data.frame(series), measure != \"closeness\"),",
          "            quantity = sprintf(\"%s t=%g: %s\", measure, time, node), kind = measure),",
          "  transform(as.data.frame(out_closeness),",
          "            quantity = sprintf(\"%s t=%g: %s\", measure, time, node), kind = measure))")),
        .igraph(c(
          .igraph_snapshot,
          "one_window <- function(lo) {",
          "  graph <- snapshot(lo, lo + 7)",
          "  near <- closeness(graph, mode = \"out\", normalized = TRUE)",
          "  near[is.nan(near)] <- 0",
          "  rbind(long(lo, \"degree\", people, degree(graph, mode = \"all\")),",
          "        long(lo, \"betweenness\", people, betweenness(graph, directed = TRUE)),",
          "        long(lo, \"closeness\", people, near),",
          "        long(lo, \"coreness\", people, coreness(graph, mode = \"all\")))",
          "}",
          "result <- do.call(rbind, lapply(c(0, 7, 14, 21), one_window))",
          "head(result, 14)")))),

    snapshot_pagerank = list(
      title = "PageRank over time",
      description = "PageRank (damping 0.85) of every pupil in each seven-unit window, against igraph::page_rank() on the binary directed snapshot of the same window.",
      covers = "centrality_series()",
      # PageRank is solved iteratively on one side and by PRPACK on the other;
      # the package's own kernel script (kernels-vs-statnet.R) holds it to 1e-6.
      tolerance = 1e-6,
      sides = list(
        .dynet(c(
          "series <- centrality_series(network, measure = \"pagerank\", damping = 0.85, step = 7, window = 7)",
          "series",
          "result <- transform(as.data.frame(series), quantity = sprintf(\"%s t=%g: %s\", measure, time, node),",
          "                    kind = measure)")),
        .igraph(c(
          .igraph_snapshot,
          "one_window <- function(lo) {",
          "  long(lo, \"pagerank\", people, page_rank(snapshot(lo, lo + 7), directed = TRUE, damping = 0.85)$vector)",
          "}",
          "result <- do.call(rbind, lapply(c(0, 7, 14, 21), one_window))",
          "head(result, 14)")))),

    graph_metrics = list(
      title = "Graph-level structure over time",
      description = "Edges, density, edgewise reciprocity, weak and strong components, isolates, the dyad census, mean geodesic distance, diameter and the sixteen-class triad census of each seven-unit window, against igraph on the binary directed snapshot of the same window.",
      covers = "metrics()",
      # Counts and ratios of counts; mean distance is a ratio of integer sums.
      tolerance = 1e-10,
      sides = list(
        .dynet(c(
          "series <- metrics(network, measure = c(\"edges\", \"density\", \"reciprocity\", \"components\", \"components_strong\",",
          "                                       \"isolates\", \"mutual\", \"asymmetric\", \"null\", \"mean_distance\",",
          "                                       \"diameter\", \"triads\"), step = 7, window = 7)",
          "series",
          "result <- transform(as.data.frame(series), quantity = sprintf(\"%s t=%g\", measure, time), kind = measure)")),
        .igraph(c(
          .igraph_snapshot,
          "triad_classes <- paste0(\"triad_\", c(\"003\", \"012\", \"102\", \"021D\", \"021U\", \"021C\", \"111D\", \"111U\",",
          "                                     \"030T\", \"030C\", \"201\", \"120D\", \"120U\", \"120C\", \"210\", \"300\"))",
          "one_window <- function(lo) {",
          "  graph <- snapshot(lo, lo + 7)",
          "  dyads <- dyad_census(graph)",
          "  value <- c(edges = ecount(graph), density = edge_density(graph), reciprocity = reciprocity(graph),",
          "             components = count_components(graph, mode = \"weak\"),",
          "             components_strong = count_components(graph, mode = \"strong\"),",
          "             isolates = sum(degree(graph, mode = \"all\") == 0), mutual = dyads$mut, asymmetric = dyads$asym,",
          "             null = dyads$null, mean_distance = mean_distance(graph, directed = TRUE, unconnected = TRUE),",
          "             diameter = diameter(graph, directed = TRUE, unconnected = TRUE),",
          "             setNames(triad_census(graph), triad_classes))",
          "  data.frame(quantity = sprintf(\"%s t=%g\", names(value), lo), kind = names(value), value = unname(value))",
          "}",
          "result <- do.call(rbind, lapply(c(0, 7, 14, 21), one_window))",
          "head(result, 27)")))),

    collapsed_edges = list(
      title = "The time-collapsed network: one weighted edge per pair",
      description = "collapse_network() flattens the whole observed period into one static edge per ordered pair. Each pair's spell count, summed duration, union duration (overlaps counted once), earliest onset and latest terminus are compared with the same quantities aggregated from the spell list in base R.",
      covers = c("collapse_network()", "as.data.frame.dynet_collapsed()"),
      # Integer counts, and sums and extremes of two-decimal times.
      tolerance = 1e-10,
      sides = list(
        .dynet(key = "pair", c(
          "flat <- collapse_network(network, weight = \"spell_count\")",
          "flat",
          "result <- subset(transform(as.data.frame(flat), pair = paste(from, \"->\", to)),",
          "                 select = c(pair, spell_count, total_duration, union_duration, first, last))")),
        .base(key = "pair", c(
          .base_union,
          "contacts$duration <- contacts$end - contacts$start",
          "pair <- paste(contacts$from, \"->\", contacts$to)",
          "result <- data.frame(",
          "  pair = sort(unique(pair)),",
          "  spell_count = as.numeric(tapply(contacts$duration, pair, length)),",
          "  total_duration = as.numeric(tapply(contacts$duration, pair, sum)),",
          "  union_duration = vapply(split(contacts, pair), function(spells) union_length(spells$start, spells$end), numeric(1)),",
          "  first = as.numeric(tapply(contacts$start, pair, min)),",
          "  last = as.numeric(tapply(contacts$end, pair, max)))",
          "head(result)")))),

    aggregated_network = list(
      title = "Measures of the time-collapsed network",
      description = "The whole observed period measured as one window (window = \"all\"): each pupil's degree, strength (number of incident spells), betweenness, out-closeness and coreness, and the graph's edges, density, reciprocity, mean distance and diameter, against igraph on the aggregated graph, in which a pair's weight is its number of spells.",
      covers = c("centrality_series()", "metrics()"),
      # Integers and ratios of integers, as in the windowed cases.
      tolerance = 1e-10,
      sides = list(
        .dynet(c(
          "nodes <- centrality_series(network, measure = c(\"degree\", \"strength\", \"betweenness\", \"coreness\"),",
          "                           mode = \"all\", window = \"all\")",
          "nodes",
          "near <- centrality_series(network, measure = \"closeness\", mode = \"out\", window = \"all\")",
          "near",
          "graph <- metrics(network, measure = c(\"edges\", \"density\", \"reciprocity\", \"mean_distance\", \"diameter\"),",
          "                 window = \"all\")",
          "graph",
          "result <- rbind(",
          "  transform(as.data.frame(nodes), quantity = sprintf(\"%s: %s\", measure, node), kind = measure, node = NULL),",
          "  transform(as.data.frame(near), quantity = sprintf(\"%s: %s\", measure, node), kind = measure, node = NULL),",
          "  transform(as.data.frame(graph), quantity = measure, kind = \"graph\"))")),
        .igraph(c(
          "people <- sort(unique(c(contacts$from, contacts$to)))",
          "spells <- graph_from_data_frame(data.frame(contacts[c(\"from\", \"to\")], weight = 1), directed = TRUE,",
          "                                vertices = people)",
          "graph <- simplify(spells, edge.attr.comb = list(weight = \"sum\"))",
          "graph",
          "near <- closeness(graph, mode = \"out\", normalized = TRUE, weights = NA)",
          "near[is.nan(near)] <- 0",
          "nodes <- list(degree = degree(graph, mode = \"all\"), strength = strength(graph, mode = \"all\"),",
          "              betweenness = betweenness(graph, directed = TRUE, weights = NA),",
          "              coreness = coreness(graph, mode = \"all\"), closeness = near)",
          "whole <- c(edges = ecount(graph), density = edge_density(graph), reciprocity = reciprocity(graph),",
          "           mean_distance = mean_distance(graph, directed = TRUE, unconnected = TRUE, weights = NA),",
          "           diameter = diameter(graph, directed = TRUE, unconnected = TRUE, weights = NA))",
          "result <- rbind(",
          "  do.call(rbind, Map(function(value, measure) {",
          "    data.frame(quantity = sprintf(\"%s: %s\", measure, people), kind = measure, value = as.numeric(value))",
          "  }, nodes, names(nodes))),",
          "  data.frame(quantity = names(whole), kind = \"graph\", value = unname(whole)))",
          "result")))),

    temporal_paths = list(
      title = "Time-respecting paths, reachability and temporal closeness",
      description = "Earliest arrival times and latencies from one pupil over the whole period (paths()), and, for a search opened at t = 18, how many others every pupil reaches and is reached by (reachability()) and its temporal closeness, reached vertices over summed latency (path_centrality()). The reference is the earliest-arrival recurrence written out in base R: an interval spell [start, end) can be entered at any instant from its onset up to but excluding its terminus, waiting is free and a hop takes no time. tsna::tPath() is the package's live oracle for the same quantities and is not installed here.",
      covers = c("paths()", "reachability()", "path_centrality()"),
      # Arrival times are input times copied through; latencies are one
      # subtraction and closeness one division of a short sum of them.
      tolerance = 1e-10,
      sides = list(
        .dynet(c(
          "journeys <- paths(network, from = \"Ana\")",
          "journeys",
          "reach <- reachability(network, direction = \"both\", start = 18, measure = \"reach_count\")",
          "reach",
          "closeness <- path_centrality(network, measure = \"closeness\", start = 18)",
          "closeness",
          "arrivals <- as.data.frame(journeys)",
          "result <- rbind(",
          "  subset(transform(arrivals, quantity = sprintf(\"arrival_time from Ana: %s\", node), kind = \"arrival_time\",",
          "                   value = arrival_time), select = c(quantity, kind, value)),",
          "  subset(transform(arrivals, quantity = sprintf(\"latency from Ana: %s\", node), kind = \"latency\",",
          "                   value = latency), select = c(quantity, kind, value)),",
          "  subset(transform(as.data.frame(reach), quantity = sprintf(\"%s from t=18: %s\", measure, node), kind = measure),",
          "         select = c(quantity, kind, value)),",
          "  subset(transform(as.data.frame(closeness), quantity = sprintf(\"temporal closeness from t=18: %s\", node),",
          "                   kind = \"temporal_closeness\"), select = c(quantity, kind, value)))")),
        .base(c(
          "people <- sort(unique(c(contacts$from, contacts$to)))",
          "# Earliest arrival at every vertex from `source`, present from `origin` on.",
          "earliest <- function(source, origin) {",
          "  arrival <- setNames(rep(Inf, length(people)), people)",
          "  arrival[source] <- origin",
          "  repeat {",
          "    enterable <- arrival[contacts$from] < contacts$end",
          "    entered <- pmax(arrival[contacts$from], contacts$start)[enterable]",
          "    best <- tapply(entered, contacts$to[enterable], min)",
          "    improved <- pmin(arrival[names(best)], best)",
          "    if (identical(unname(improved), unname(arrival[names(best)]))) break",
          "    arrival[names(best)] <- improved",
          "  }",
          "  arrival",
          "}",
          "from_ana <- earliest(\"Ana\", min(contacts$start))",
          "from_ana",
          "late <- vapply(people, earliest, numeric(length(people)), origin = 18)",
          "dimnames(late) <- list(to = people, from = people)",
          "reached <- is.finite(late) & row(late) != col(late)",
          "latency <- ifelse(reached, late - 18, 0)",
          "result <- rbind(",
          "  data.frame(quantity = sprintf(\"arrival_time from Ana: %s\", people), kind = \"arrival_time\", value = unname(from_ana)),",
          "  data.frame(quantity = sprintf(\"latency from Ana: %s\", people), kind = \"latency\",",
          "             value = unname(from_ana) - min(contacts$start)),",
          "  data.frame(quantity = sprintf(\"forward_reach_count from t=18: %s\", people), kind = \"forward_reach_count\",",
          "             value = colSums(reached)),",
          "  data.frame(quantity = sprintf(\"backward_reach_count from t=18: %s\", people), kind = \"backward_reach_count\",",
          "             value = rowSums(reached)),",
          "  data.frame(quantity = sprintf(\"temporal closeness from t=18: %s\", people), kind = \"temporal_closeness\",",
          "             value = ifelse(colSums(reached) > 0, colSums(reached) / colSums(latency), 0)))",
          "result")))),

    burstiness = list(
      title = "Burstiness, memory and inter-event gaps",
      description = "For every pupil: the number of incident events, the mean gap between consecutive events, the burstiness B = (sigma - mu) / (sigma + mu) of those gaps with the population standard deviation, and the memory coefficient, the Pearson correlation of consecutive gaps (Goh and Barabasi, 2008). The reference computes them from the sorted onset times with base R and stats::cor().",
      covers = c("burstiness()", "gaps()"),
      # A mean, a standard deviation and a correlation of about thirty gaps.
      tolerance = 1e-10,
      sides = list(
        .dynet(c(
          "rhythm <- burstiness(network, measure = c(\"events\", \"mean_gap\", \"burstiness\", \"memory\"))",
          "rhythm",
          "summary(gaps(network))",
          "result <- transform(as.data.frame(rhythm), quantity = sprintf(\"%s: %s\", measure, node), kind = measure)")),
        .base(c(
          "incident <- data.frame(node = c(contacts$from, contacts$to), time = c(contacts$start, contacts$start))",
          "rhythm <- function(times) {",
          "  gap <- diff(sort(times))",
          "  mu <- mean(gap)",
          "  sigma <- sqrt(mean((gap - mu)^2))",
          "  c(events = length(times), mean_gap = mu, burstiness = (sigma - mu) / (sigma + mu),",
          "    memory = stats::cor(head(gap, -1), tail(gap, -1)))",
          "}",
          "per_node <- vapply(split(incident$time, incident$node), rhythm, numeric(4))",
          "t(per_node)",
          "result <- data.frame(quantity = sprintf(\"%s: %s\", rownames(per_node)[row(per_node)], colnames(per_node)[col(per_node)]),",
          "                     kind = rownames(per_node)[row(per_node)], value = as.numeric(per_node))"))))
  )
}

#' Export one live case
#'
#' @param name The case's name.
#' @return One row: the bundle, its sides and how its compared values came out.
export_case <- function(name) {
  case <- .verify_cases()[[name]]
  verify_export(bundle = file.path(.verify_base, "bundles", name), title = case$title,
                description = case$description, sides = case$sides,
                data = c(`School contacts (spell list)` = .verify_contacts()),
                tolerance = case$tolerance, covers = case$covers, generator = .verify_generator)
}

# Temporal density: two live sides and tsna's retained values ----------------

#' The tsna values pinned in the package's own test
#'
#' Read out of tests/testthat/test-temporal-density-span-contract.R, so that the
#' bundle shows the very literals and provenance comment the test carries
#' rather than a retyped copy.
#' @return A list: `lines` (the test, as text) and `values` (quantity, kind, value).
.verify_tsna_density <- function() {
  test <- readLines(file.path("tests", "testthat", "test-temporal-density-span-contract.R"))
  opens <- grep("reproduce tsna::tEdgeDensity", test, fixed = TRUE)
  stopifnot("the tsna-pinned test must be in the test file exactly once" = length(opens) == 1L)
  closes <- opens + which(test[-seq_len(opens)] == "})")[1L]
  lines <- test[seq(opens, closes)]
  literals <- regmatches(lines, gregexpr("0\\.0[0-9]{10,}", lines)) |> unlist() |> as.numeric()
  stopifnot("the test must pin one whole-period and four tiled values" = length(literals) == 5L)
  list(lines = lines, values = data.frame(
    quantity = c("temporal_density whole period", sprintf("temporal_density t=%g", c(0, 7, 14, 21))),
    kind = "temporal_density", value = literals))
}

#' Export the temporal density case
#'
#' @return One row, as [export_case()].
export_temporal_density <- function() {
  bundle <- file.path(.verify_base, "bundles", "temporal_density")
  unlink(bundle, recursive = TRUE)
  dir.create(bundle, recursive = TRUE)
  data <- verify_copy(.verify_contacts(), bundle, file.path("data", "school_contacts.tsv"),
                      label = "School contacts (spell list)")
  sides <- list(
    .dynet(c(
      "whole <- metrics(network, measure = \"temporal_density\", window = \"all\")",
      "whole",
      "tiled <- metrics(network, measure = \"temporal_density\", step = 7, window = 7)",
      "tiled",
      "result <- rbind(",
      "  transform(as.data.frame(whole), quantity = \"temporal_density whole period\", kind = measure),",
      "  transform(as.data.frame(tiled), quantity = sprintf(\"temporal_density t=%g\", time), kind = measure))")),
    .base(c(
      .base_union,
      "people <- unique(c(contacts$from, contacts$to))",
      "pair_slots <- length(people) * (length(people) - 1)",
      "# Occupied ordered-pair time inside [lo, hi] over all ordered-pair time there.",
      "density <- function(lo, hi) {",
      "  inside <- contacts[contacts$start < hi & contacts$end > lo, ]",
      "  inside$start <- pmax(inside$start, lo)",
      "  inside$end <- pmin(inside$end, hi)",
      "  occupied <- vapply(split(inside, paste(inside$from, inside$to)),",
      "                     function(spells) union_length(spells$start, spells$end), numeric(1))",
      "  sum(occupied) / (pair_slots * (hi - lo))",
      "}",
      "observed_to <- max(contacts$end)",
      "onsets <- c(0, 7, 14, 21)",
      "result <- data.frame(",
      "  quantity = c(\"temporal_density whole period\", sprintf(\"temporal_density t=%g\", onsets)),",
      "  kind = \"temporal_density\",",
      "  value = c(density(min(contacts$start), observed_to),",
      "            vapply(onsets, function(lo) density(lo, min(lo + 7, observed_to)), numeric(1))))",
      "print(result, digits = 15)")),
    verify_side("tsna", package = NULL, version = "0.3.6", authority = "open-source", source = "retained",
                run_at = "2026-11-01", command = "tsna::tEdgeDensity(nd, agg.unit = \"dyad\")",
                url = "https://cran.r-project.org/package=tsna",
                role = "values pinned in tests/testthat/test-temporal-density-span-contract.R"))
  runs <- lapply(sides[1:2], function(side) verify_run(bundle, side, reads = data$path))
  retained <- .verify_tsna_density()
  dir.create(file.path(bundle, "tsna"))
  writeLines(retained$lines, file.path(bundle, "tsna", "pinned-test.R"))
  utils::write.table(retained$values, file.path(bundle, "tsna", "values.tsv"), sep = "\t", quote = FALSE,
                     row.names = FALSE)
  # Fifteen decimals are pinned and the test itself holds Dynet to 1e-12 of them.
  comparisons <- verify_compare(
    list(dynet = verify_values(runs[[1L]]$result), `base-r` = verify_values(runs[[2L]]$result),
         tsna = retained$values),
    tolerance = 1e-12)
  sections <- list(
    list(id = "code", title = "Code", items = list(
      runs[[1L]]$code, runs[[2L]]$code,
      verify_item(bundle, file.path("tsna", "pinned-test.R"), side = "tsna", type = "code", language = "r",
                  label = "The package test that pins tsna's values, with how they were produced"))),
    list(id = "output", title = "Raw output", items = list(
      runs[[1L]]$output, runs[[2L]]$output,
      verify_item(bundle, file.path("tsna", "values.tsv"), side = "tsna", type = "table",
                  label = "Retained values (tsna 0.3.6, 2026-11-01)"))),
    list(id = "data", title = "Data", items = list(data)))
  verify_write(
    bundle, title = "Temporal density, whole period and tiled windows",
    description = "The share of ordered-pair time during which a tie is up, overlapping spells of one pair counted once, over the whole observed period and in each seven-unit window, the last cut where the data end (21.52). Dynet against the change-point integral written out in base R and against the values tsna::tEdgeDensity(agg.unit = \"dyad\") gave on 2026-11-01, which the package's test suite pins as literals. tsna is not installed on this machine, so its side is retained, not rerun.",
    sides = sides, sections = sections, comparisons = comparisons, covers = "metrics()",
    generator = .verify_generator)
  states <- vapply(comparisons, function(row) row$status, character(1))
  data.frame(bundle = bundle, sides = length(sides), compared = length(states),
             agree = sum(states == "agree"), disagree = sum(states == "disagree"),
             missing = sum(states == "missing"))
}

# Run --------------------------------------------------------------------------

.verify_exporters <- function() {
  live <- names(.verify_cases())
  c(stats::setNames(lapply(live, function(name) function() export_case(name)), live),
    list(temporal_density = export_temporal_density))
}

# A reference that is not installed is reported and its live cases are skipped;
# nothing is installed from here.
absent <- Filter(function(package) !requireNamespace(package, quietly = TRUE),
                 c("igraph", "tsna", "networkDynamic", "sna"))
if (length(absent)) {
  message(messageCondition(
    sprintf("Not installed, so not run live: %s. tsna's temporal density is exported from its retained values.\n",
            toString(absent)),
    class = "dynet_verify_reference_absent"))
}

exporters <- .verify_exporters()
requested <- commandArgs(trailingOnly = TRUE)
if (length(requested) == 0L) requested <- names(exporters)
stopifnot("every requested case must be one of the exported cases" = all(requested %in% names(exporters)))
needs_igraph <- c("snapshot_centrality", "snapshot_pagerank", "graph_metrics", "aggregated_network")
runnable <- setdiff(requested, if ("igraph" %in% absent) needs_igraph)
print(do.call(rbind, lapply(exporters[runnable], function(export) export())), row.names = FALSE)
