# The summaries of snapshots, projections, collapsed networks, similarities, phases and null models, each
# recomputed by outside software on the same networks: networkDynamic::network.extract() and network.collapse(),
# sna::gden(), stats::dist(method = "binary") (one minus the Jaccard index of two tie sets) and igraph. The
# formula checks of each summary stay in its own file; these are the second way.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
network <- dynet(school_contacts)
onsets <- c(0, 7, 14, 21)

#' A window's snapshot extracted by networkDynamic: its arcs by vertex name
extracted_arcs <- function(history, lo, hi) {
  extracted <- networkDynamic::network.extract(history, onset = lo, terminus = hi, rule = "any")
  arcs <- network::as.edgelist(extracted)
  names_in <- network::get.vertex.attribute(extracted, "vertex.names")
  data.frame(from = names_in[arcs[, 1L]], to = names_in[arcs[, 2L]])
}

test_that("summary() of the snapshots counts each window's ties and active vertices as network.extract() does", {
  skip_without_reference(c("networkDynamic", "network"))
  history <- ref_network_dynamic(spells)
  theirs <- do.call(rbind, lapply(onsets, \(lo) {
    arcs <- extracted_arcs(history, lo, lo + 7)
    data.frame(time = lo, ties = nrow(arcs), nodes = length(unique(c(arcs$from, arcs$to))))
  }))
  ours <- subset(as.data.frame(summary(snapshots(network, step = 7, window = 7))), select = c(time, ties, nodes))
  expect_reference(ours, theirs, reference = "networkDynamic", covers = "summary.dynet_snapshot()",
                   quantity = "ties and active vertices per window", tolerance = 0, key = "time")
})

test_that("summary() of the projection counts each slice's within-slice arcs as network.extract() does", {
  skip_without_reference(c("networkDynamic", "network"))
  history <- ref_network_dynamic(spells)
  theirs <- data.frame(slice = seq_along(onsets),
                       within_slice = vapply(onsets, \(lo) nrow(extracted_arcs(history, lo, lo + 7)), numeric(1)))
  ours <- subset(as.data.frame(summary(projection(network, step = 7, window = 7))), select = c(slice, within_slice))
  expect_reference(ours, theirs, reference = "networkDynamic", covers = "summary.dynet_projection()",
                   quantity = "within-slice arcs per slice", tolerance = 0, key = "slice")
})

test_that("summary() of the collapsed network gives network.collapse()'s edge count and sna::gden()'s density", {
  skip_without_reference(c("networkDynamic", "network", "sna"))
  collapsed <- networkDynamic::network.collapse(ref_network_dynamic(spells), onset = 0, terminus = max(spells$end))
  theirs <- data.frame(property = c("vertices", "edges", "density"),
                       value = c(network::network.size(collapsed), network::network.edgecount(collapsed),
                                 sna::gden(collapsed)))
  ours <- transform(subset(as.data.frame(summary(collapse_network(network))), property %in% theirs$property),
                    value = as.numeric(value))
  # The summary prints the density to four decimals.
  expect_reference(ours, theirs, reference = "sna", covers = "summary.dynet_collapsed()", quantity = "binary",
                   tolerance = 5e-5, key = "property")
})

test_that("the per-session collapsed tables and their summary equal network.collapse() of each session", {
  skip_without_reference(c("networkDynamic", "network"))
  rows <- lapply(c(3L, 4L), \(seed) {
    drawn <- as.data.frame(simulab::simulate_temporal_network(nodes = 8, periods = 30, initial_probability = 0.2,
                                                                formation_probability = 0.05,
                                                                dissolution_probability = 0.3, seed = seed))
    edges <- data.frame(from = drawn$from, to = drawn$to, start = as.numeric(drawn$onset),
                        end = as.numeric(drawn$terminus))
    edges$session <- ifelse(edges$start <= 15, "first half", "second half")
    by_session <- collapse_network(dynet(edges, session = "session"), sessions = "separate")
    theirs <- do.call(rbind, lapply(split(edges, edges$session), \(part) {
      history <- ref_network_dynamic(part)
      collapsed <- networkDynamic::network.collapse(history, onset = 0, terminus = 100, rm.time.info = FALSE)
      arcs <- as.data.frame(collapsed, unit = "edges")
      listed <- as.data.frame(history)
      names_in <- network::get.vertex.attribute(history, "vertex.names")
      pair <- paste(names_in[listed$tail], names_in[listed$head])
      data.frame(session = part$session[[1L]], from = arcs$.tail, to = arcs$.head,
                 spell_count = arcs$activity.count, total_duration = arcs$activity.duration,
                 union_duration = arcs$activity.duration,
                 first = as.numeric(tapply(listed$onset, pair, min)[paste(arcs$.tail, arcs$.head)]),
                 last = as.numeric(tapply(listed$terminus, pair, max)[paste(arcs$.tail, arcs$.head)]))
    }))
    summarised <- do.call(rbind, lapply(split(theirs, theirs$session), \(one) {
      data.frame(session = one$session[[1L]], pairs = nrow(one), nodes = length(unique(c(one$from, one$to))),
                 union_duration = sum(one$union_duration), total_duration = sum(one$total_duration))
    }))
    list(ours = cbind(seed = seed, as.data.frame(by_session)), theirs = cbind(seed = seed, theirs),
         ours_summary = cbind(seed = seed, summary(by_session)), theirs_summary = cbind(seed = seed, summarised))
  })
  stack <- \(part) do.call(rbind, lapply(rows, `[[`, part))
  # No two spells of a pair overlap in these networks; times are whole periods.
  expect_reference(stack("ours"), stack("theirs"), reference = "networkDynamic",
                   covers = c("collapse_network()", "as.data.frame.dynet_collapsed_list()"),
                   quantity = "session and pair, simulab networks", tolerance = 1e-12,
                   key = c("seed", "session", "from", "to"))
  expect_reference(stack("ours_summary"), stack("theirs_summary"), reference = "networkDynamic",
                   covers = "summary.dynet_collapsed_list()", quantity = "per session, simulab networks",
                   tolerance = 1e-12, key = c("seed", "session"))
})

#' Each window's tie set as a 0/1 row: one row per window, one column per ordered pair
tie_rows <- function(width, starts) {
  t(vapply(starts, \(lo) as.vector(ref_adjacency(spells, lo, lo + width, people) > 0), logical(length(people)^2)))
}

test_that("summary() of the similarities equals one minus stats::dist(method = 'binary') between the windows", {
  jaccard <- 1 - as.matrix(stats::dist(tie_rows(7, onsets), method = "binary"))
  theirs <- do.call(rbind, lapply(seq_along(onsets), \(i) {
    values <- jaccard[i, -i]
    data.frame(time = onsets[[i]], mean = mean(values), min = min(values), max = max(values))
  }))
  expect_reference(as.data.frame(summary(similarity(network, method = "jaccard", step = 7, window = 7))), theirs,
                   reference = "stats", covers = "summary.dynet_similarity()", quantity = "per window",
                   tolerance = 1e-12, key = "time")
})

test_that("summary() of the phases gives each phase's cohesion from stats::dist(method = 'binary')", {
  starts <- seq(0, 20, by = 2)
  distance <- as.matrix(stats::dist(tie_rows(2, starts), method = "binary"))
  cases <- list(list(k = 2, contiguous = TRUE), list(k = 3, contiguous = TRUE), list(k = 3, contiguous = FALSE))
  rows <- lapply(cases, \(case) {
    found <- phases(network, k = case$k, method = "jaccard", linkage = "ward.D2", contiguous = case$contiguous,
                    step = 2, window = 2)
    assigned <- as.data.frame(found)
    phase_of <- assigned$phase[match(starts, assigned$time)]
    theirs <- do.call(rbind, lapply(split(seq_along(starts), phase_of), \(inside) {
      within <- distance[inside, inside]
      data.frame(n_bins = length(inside), start = min(starts[inside]),
                 cohesion = if (length(inside) > 1L) 1 - mean(within[lower.tri(within)]) else NA_real_)
    }))
    label <- sprintf("k = %d, contiguous = %s", case$k, case$contiguous)
    ours <- subset(as.data.frame(summary(found)), select = c(start, n_bins, cohesion))
    list(ours = cbind(case = label, ours), theirs = cbind(case = label, theirs))
  })
  # A mean of at most 55 ratios of tie counts.
  defined <- \(table) subset(table, !is.na(cohesion))
  expect_reference(defined(do.call(rbind, lapply(rows, `[[`, "ours"))), defined(do.call(rbind, lapply(rows, `[[`, "theirs"))),
                   reference = "stats", covers = "summary.dynet_phases()", quantity = "per phase of two or more windows",
                   tolerance = 1e-12, key = c("case", "start"))
})

test_that("summary() of the surrogates counts each replicate's spells and distinct pairs as igraph does", {
  skip_without_reference("igraph")
  rows <- lapply(c("timeline", "targets", "times"), \(method) {
    null <- randomise(network, method = method, n = 10, seed = 5)
    drawn <- as.data.frame(null)
    theirs <- do.call(rbind, lapply(split(drawn, drawn$replicate), \(one) {
      graph <- igraph::graph_from_data_frame(subset(one, select = c(from, to)), directed = TRUE)
      data.frame(replicate = one$replicate[[1L]], n_events = igraph::ecount(graph),
                 n_pairs = igraph::ecount(igraph::simplify(graph, remove.loops = FALSE)))
    }))
    list(ours = cbind(method = method, subset(summary(null), select = c(replicate, n_events, n_pairs))),
         theirs = cbind(method = method, theirs))
  })
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "igraph", covers = "summary.dynet_null()", quantity = "per replicate", tolerance = 0,
                   key = c("method", "replicate"))
})
