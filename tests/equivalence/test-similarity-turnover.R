# similarity(), turnover() and persistence(): how much the tie set changes between windows. On the bundled
# school_contacts spells in windows of 7. A pair is tied in a window when one of its spells overlaps it; loops are
# excluded. References: sna::hdist() and sna::gcor() on the windows' adjacency matrices (run live), and the
# definitions written out in base R (Jaccard; volatility and fluctuability, Thompson et al. 2017; topological
# overlap, Tang et al. 2010). similarity() computes its coefficients through cograph::layer_similarity(), which
# is not a reference here.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
network <- dynet(school_contacts)
onsets <- c(0, 7, 14, 21)
layers <- lapply(onsets, \(lo) ref_adjacency(spells, lo, lo + 7, people))
pairs <- expand.grid(time = seq_along(onsets), other = seq_along(onsets))

test_that("Hamming distance and graph correlation between every two windows equal sna::hdist() and sna::gcor()", {
  skip_without_reference("sna")
  # sna reads a stack of graphs as graph x sender x receiver.
  stacked <- aperm(array(unlist(layers), c(length(people), length(people), length(onsets))), c(3L, 1L, 2L))
  hamming <- sna::hdist(stacked, mode = "digraph", diag = FALSE)
  correlation <- sna::gcor(stacked, mode = "digraph", diag = FALSE)
  theirs <- rbind(data.frame(time = onsets[pairs$time], other = onsets[pairs$other], measure = "hamming",
                             value = hamming[cbind(pairs$time, pairs$other)]),
                  data.frame(time = onsets[pairs$time], other = onsets[pairs$other], measure = "pearson",
                             value = correlation[cbind(pairs$time, pairs$other)]))
  ours <- rbind(as.data.frame(similarity(network, method = "hamming", step = 7, window = 7)),
                as.data.frame(similarity(network, method = "pearson", step = 7, window = 7)))
  # A count, and a correlation of two 0/1 vectors of length 182.
  expect_reference(ours, theirs, reference = "sna", covers = c("similarity()", "as.data.frame.dynet_similarity()"),
                   quantity = "between windows of 7", tolerance = 1e-10, key = c("time", "other", "measure"))
})

test_that("on the undirected network, Hamming distance and correlation equal sna's over the unordered pairs", {
  skip_without_reference("sna")
  folded <- lapply(layers, \(layer) pmax(layer, t(layer)))
  stacked <- aperm(array(unlist(folded), c(length(people), length(people), length(onsets))), c(3L, 1L, 2L))
  hamming <- sna::hdist(stacked, mode = "graph", diag = FALSE)
  correlation <- sna::gcor(stacked, mode = "graph", diag = FALSE)
  theirs <- rbind(data.frame(time = onsets[pairs$time], other = onsets[pairs$other], measure = "hamming",
                             value = hamming[cbind(pairs$time, pairs$other)]),
                  data.frame(time = onsets[pairs$time], other = onsets[pairs$other], measure = "pearson",
                             value = correlation[cbind(pairs$time, pairs$other)]))
  undirected <- dynet(school_contacts, directed = FALSE)
  ours <- rbind(as.data.frame(similarity(undirected, method = "hamming", step = 7, window = 7)),
                as.data.frame(similarity(undirected, method = "pearson", step = 7, window = 7)))
  expect_reference(ours, theirs, reference = "sna", covers = "similarity()", quantity = "undirected, between windows of 7",
                   tolerance = 1e-10, key = c("time", "other", "measure"))
})

test_that("Jaccard similarity between every two windows equals shared ties over ties in either", {
  jaccard <- \(one, two) sum(one & two) / sum(one | two)
  theirs <- data.frame(time = onsets[pairs$time], other = onsets[pairs$other], measure = "jaccard",
                       value = mapply(\(i, j) jaccard(layers[[i]] > 0, layers[[j]] > 0), pairs$time, pairs$other))
  ours <- as.data.frame(similarity(network, method = "jaccard", step = 7, window = 7))
  expect_reference(ours, theirs, reference = "independent: Jaccard index of two tie sets, base R",
                   covers = "similarity()", quantity = "between windows of 7", tolerance = 1e-12,
                   key = c("time", "other", "measure"))
})

test_that("volatility equals sna::hdist() between consecutive windows over the ordered pairs", {
  skip_without_reference("sna")
  domain <- length(people) * (length(people) - 1)
  stacked <- aperm(array(unlist(layers), c(length(people), length(people), length(onsets))), c(3L, 1L, 2L))
  hamming <- sna::hdist(stacked, mode = "digraph", diag = FALSE)
  consecutive <- hamming[cbind(seq_len(length(onsets) - 1L), seq_len(length(onsets) - 1L) + 1L)]
  theirs <- data.frame(time = utils::head(onsets, -1L), measure = "volatility", value = consecutive / domain)
  ours <- as.data.frame(turnover(network, measure = "volatility", step = 7, window = 7))
  expect_reference(ours, theirs, reference = "sna", covers = "turnover()", quantity = "volatility, windows of 7",
                   tolerance = 1e-12, key = c("time", "measure"))
})

test_that("overall volatility and fluctuability equal their definitions", {
  domain <- length(people) * (length(people) - 1)
  changed <- vapply(seq_len(length(onsets) - 1L), \(i) sum(layers[[i]] != layers[[i + 1L]]), numeric(1))
  ever <- Reduce(`|`, lapply(layers, \(layer) layer > 0))
  theirs <- data.frame(measure = c("volatility", "fluctuability"),
                       value = c(mean(changed / domain), sum(ever) / sum(vapply(layers, sum, numeric(1)))))
  ours <- as.data.frame(turnover(network, measure = c("volatility", "fluctuability"), scope = "overall", step = 7,
                                 window = 7))
  expect_reference(ours, theirs, reference = "independent: Thompson et al. (2017) volatility and fluctuability, base R",
                   covers = "turnover()", quantity = "whole series", tolerance = 1e-12, key = "measure")
})

test_that("topological overlap of each vertex between consecutive windows equals Tang et al.'s definition", {
  folded <- lapply(layers, \(layer) pmax(layer, t(layer)))
  overlap <- \(one, two) {
    shared <- rowSums(one * two)
    scale <- sqrt(rowSums(one) * rowSums(two))
    ifelse(scale > 0, shared / scale, 0)
  }
  per_transition <- lapply(seq_len(length(onsets) - 1L), \(i) overlap(folded[[i]], folded[[i + 1L]]))
  theirs <- do.call(rbind, Map(\(values, lo) {
    data.frame(time = lo, node = people, measure = "topological_overlap", value = unname(values))
  }, per_transition, utils::head(onsets, -1L)))
  by_definition <- "independent: Tang et al. (2010) topological overlap, base R"
  expect_reference(as.data.frame(persistence(network, scope = "pertime", step = 7, window = 7)), theirs,
                   reference = by_definition, covers = "persistence()", quantity = "per vertex and transition",
                   tolerance = 1e-12, key = c("time", "node", "measure"))
  average <- data.frame(node = people, measure = "average_topological_overlap",
                        value = rowMeans(do.call(cbind, per_transition)))
  expect_reference(as.data.frame(persistence(network, scope = "node", step = 7, window = 7)), average,
                   reference = by_definition, covers = "persistence()", quantity = "per vertex, averaged",
                   tolerance = 1e-12, key = c("node", "measure"))
  overall <- data.frame(measure = "temporal_correlation", value = mean(rowMeans(do.call(cbind, per_transition))))
  expect_reference(as.data.frame(persistence(network, scope = "overall", step = 7, window = 7)), overall,
                   reference = by_definition, covers = "persistence()", quantity = "temporal correlation",
                   tolerance = 1e-12, key = "measure")
})

test_that("summary() of the similarities gives each window's mean, least and greatest similarity to the others", {
  jaccard <- \(one, two) sum(one & two) / sum(one | two)
  theirs <- do.call(rbind, lapply(seq_along(onsets), \(i) {
    values <- vapply(setdiff(seq_along(onsets), i), \(j) jaccard(layers[[i]] > 0, layers[[j]] > 0), numeric(1))
    data.frame(time = onsets[[i]], mean = mean(values), min = min(values), max = max(values))
  }))
  expect_reference(as.data.frame(summary(similarity(network, method = "jaccard", step = 7, window = 7))), theirs,
                   reference = "independent: Jaccard index of two tie sets, base R", covers = "summary.dynet_similarity()",
                   quantity = "per window", tolerance = 1e-12, key = "time")
})

test_that("Hamming distance counting both triangles of the folded windows differs (negative control)", {
  folded <- lapply(layers, \(layer) pmax(layer, t(layer)))
  theirs <- data.frame(time = onsets[pairs$time], other = onsets[pairs$other], measure = "hamming",
                       value = mapply(\(i, j) sum(folded[[i]] != folded[[j]]), pairs$time, pairs$other))
  theirs <- subset(theirs, time != other)
  ours <- subset(as.data.frame(similarity(network, method = "hamming", step = 7, window = 7)), time != other)
  expect_differs(ours, theirs, reference = "independent: Hamming count of two tie sets, base R",
                 covers = "similarity()", quantity = "Hamming distance of the folded windows", tolerance = 0.5,
                 key = c("time", "other", "measure"))
})
