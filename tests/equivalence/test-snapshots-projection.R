# snapshots() and projection(): the static networks of a temporal network's windows, and the time-expanded
# (supra) network that stacks them. On the bundled school_contacts spells in windows of 7, a pair is in a window's
# snapshot when one of its spells overlaps the window for a positive length; its weight is the number of such
# spells. References: networkDynamic::network.extract() and tsna::timeProjectedNetwork(), and the spell list.

spells <- school_contacts
network <- dynet(school_contacts)
onsets <- c(0, 7, 14, 21)

#' Spells overlapping each window, counted per ordered pair
snapshot_counts <- function(edges, onsets, width) {
  do.call(rbind, lapply(onsets, \(lo) {
    inside <- subset(edges, start < lo + width & end > lo)
    counts <- as.data.frame(table(from = inside$from, to = inside$to), stringsAsFactors = FALSE)
    transform(subset(counts, Freq > 0, select = c(from, to)), time = lo,
              n_spells = as.numeric(subset(counts, Freq > 0)$Freq))
  }))
}

test_that("each window's ties and their spell counts equal the spells overlapping it", {
  theirs <- snapshot_counts(spells, onsets, 7)
  ours <- as.data.frame(snapshots(network, step = 7, window = 7))
  expect_reference(ours, transform(theirs, weight = n_spells),
                   reference = "independent: spells overlapping each window, base R",
                   covers = c("snapshots()", "as.data.frame.dynet_snapshot()"), quantity = "tie per window",
                   tolerance = 0, key = c("time", "from", "to"))
})

test_that("each window's ties equal networkDynamic::network.extract(rule = 'any')", {
  skip_without_reference(c("networkDynamic", "network"))
  people <- sort(unique(c(spells$from, spells$to)))
  history <- ref_network_dynamic(spells)
  theirs <- do.call(rbind, lapply(onsets, \(lo) {
    extracted <- networkDynamic::network.extract(history, onset = lo, terminus = lo + 7, rule = "any")
    arcs <- network::as.edgelist(extracted)
    names_in <- network::get.vertex.attribute(extracted, "vertex.names")
    data.frame(time = lo, from = names_in[arcs[, 1L]], to = names_in[arcs[, 2L]], present = TRUE)
  }))
  ours <- transform(as.data.frame(snapshots(network, step = 7, window = 7)), present = TRUE)
  expect_reference(ours, theirs, reference = "networkDynamic", covers = c("snapshots()", "as.data.frame.dynet_snapshot()"),
                   quantity = "tie per window",
                   tolerance = 0, key = c("time", "from", "to"))
})

test_that("summary() of the snapshots gives each window's ties, active vertices and summed weight", {
  counts <- snapshot_counts(spells, onsets, 7)
  theirs <- do.call(rbind, lapply(onsets, \(lo) {
    window <- subset(counts, time == lo)
    data.frame(time = lo, ties = nrow(window), nodes = length(unique(c(window$from, window$to))),
               weight = sum(window$n_spells))
  }))
  expect_reference(as.data.frame(summary(snapshots(network, step = 7, window = 7))), theirs,
                   reference = "independent: spells overlapping each window, base R", covers = "summary.dynet_snapshot()",
                   quantity = "per window", tolerance = 0, key = "time")
})

test_that("the projection's arcs equal tsna::timeProjectedNetwork()'s", {
  skip_without_reference(c("tsna", "networkDynamic", "network"))
  edges <- data.frame(from = c("A", "B", "C", "A"), to = c("B", "C", "A", "B"), start = c(0, 1, 2, 2.5),
                      end = c(1, 2, 3, 3))
  small <- dynet(edges, directed = TRUE, observation_start = 0, observation_end = 3)
  arcs <- as.data.frame(projection(small, start = 0, end = 2, step = 1, window = 1), what = "edges")
  history <- networkDynamic::activate.vertices(ref_network_dynamic(edges), onset = 0, terminus = 3)
  projected <- network::as.edgelist(tsna::timeProjectedNetwork(history, start = 0, end = 3, time.increment = 1))
  theirs <- data.frame(from_state = projected[, 1L], to_state = projected[, 2L], present = TRUE)
  expect_reference(transform(arcs, present = TRUE), theirs, reference = "tsna", covers = c("projection()",
                                                                                           "as.data.frame.dynet_projection()"),
                   quantity = "arc of the time-projected network", tolerance = 0, key = c("from_state", "to_state"))
})

test_that("summary() of the projection gives per slice the within-slice arcs and the identity arcs to the next", {
  counts <- snapshot_counts(spells, onsets, 7)
  people <- sort(unique(c(spells$from, spells$to)))
  theirs <- data.frame(slice = seq_along(onsets), time = onsets,
                       within_slice = vapply(onsets, \(lo) sum(counts$time == lo), numeric(1)),
                       identity_arcs = c(rep(length(people), length(onsets) - 1L), 0))
  expect_reference(as.data.frame(summary(projection(network, step = 7, window = 7))), theirs,
                   reference = "independent: spells overlapping each window, base R", covers = "summary.dynet_projection()",
                   quantity = "per slice", tolerance = 0, key = "slice")
})

test_that("tie counts of windows of 7 against windows of 3.5 differ (negative control)", {
  # The last window is left out: the data end at 21.52, so its narrow and full windows hold the same spells.
  full <- utils::head(onsets, -1L)
  narrow <- snapshot_counts(spells, full, 3.5)
  theirs <- data.frame(time = full, ties = as.numeric(table(factor(narrow$time, full))))
  ours <- subset(as.data.frame(summary(snapshots(network, step = 7, window = 7))), time < 21)
  expect_differs(ours, theirs, reference = "independent: spells overlapping each window, base R",
                 covers = "snapshots()", quantity = "ties per window, reference on windows of 3.5", tolerance = 0.5,
                 key = "time")
})
