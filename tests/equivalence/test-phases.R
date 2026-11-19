# phases(): segments of a temporal network's history, found by clustering its windows on the distance
# 1 - Jaccard similarity of their tie sets. On the bundled school_contacts spells in windows of 2. With
# contiguous = FALSE the phases are the groups of stats::hclust() (Ward's criterion) cut at k; the silhouette of
# each window is checked against cluster::silhouette() for the phases returned.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
network <- dynet(school_contacts)
onsets <- seq(0, 20, by = 2)
layers <- lapply(onsets, \(lo) ref_adjacency(spells, lo, lo + 2, people) > 0)
distance <- outer(seq_along(onsets), seq_along(onsets), Vectorize(\(i, j) {
  1 - sum(layers[[i]] & layers[[j]]) / sum(layers[[i]] | layers[[j]])
}))

#' Whether every two windows share a phase: the partition without its labels
together <- function(time, phase) {
  pairs <- expand.grid(time = time, other = time)
  pairs$same <- as.numeric(phase[match(pairs$time, time)] == phase[match(pairs$other, time)])
  pairs
}

test_that("non-contiguous phases are the groups of Ward's hierarchical clustering of the windows", {
  groups <- stats::cutree(stats::hclust(stats::as.dist(distance), method = "ward.D2"), k = 3)
  ours <- as.data.frame(phases(network, k = 3, method = "jaccard", linkage = "ward.D2", contiguous = FALSE, step = 2,
                               window = 2))
  expect_reference(together(ours$time, ours$phase), together(onsets, groups), reference = "stats",
                   covers = c("phases()", "as.data.frame.dynet_phases()"), quantity = "two windows in one phase",
                   tolerance = 0, key = c("time", "other"))
})

test_that("each window's silhouette equals cluster::silhouette() for the phases found", {
  skip_without_reference("cluster")
  found <- as.data.frame(phases(network, k = 2, method = "jaccard", step = 2, window = 2))
  widths <- cluster::silhouette(found$phase, stats::as.dist(distance))
  # A ratio of mean distances between eleven windows.
  expect_reference(found, data.frame(time = onsets, silhouette = widths[, "sil_width"]), reference = "cluster",
                   covers = c("phases()", "as.data.frame.dynet_phases()"), quantity = "silhouette, two contiguous phases",
                   tolerance = 1e-12, key = "time")
})

test_that("summary() gives each phase's span and cohesion, one minus its mean within-phase distance", {
  found <- as.data.frame(phases(network, k = 2, method = "jaccard", step = 2, window = 2))
  theirs <- do.call(rbind, lapply(split(seq_along(onsets), found$phase[match(onsets, found$time)]), \(inside) {
    within <- distance[inside, inside]
    data.frame(start = min(onsets[inside]), end = max(onsets[inside]), n_bins = length(inside),
               cohesion = if (length(inside) > 1L) 1 - mean(within[lower.tri(within)]) else NA_real_)
  }))
  ours <- as.data.frame(summary(phases(network, k = 2, method = "jaccard", step = 2, window = 2)))
  expect_reference(ours, theirs, reference = "independent: within-phase mean distance, base R",
                   covers = "summary.dynet_phases()", quantity = "per phase", tolerance = 1e-12, key = "start")
})

test_that("phases from single-linkage clustering differ from Ward's (negative control)", {
  groups <- stats::cutree(stats::hclust(stats::as.dist(distance), method = "single"), k = 3)
  ours <- as.data.frame(phases(network, k = 3, method = "jaccard", linkage = "ward.D2", contiguous = FALSE, step = 2,
                               window = 2))
  expect_differs(sum(together(ours$time, ours$phase)$same), sum(together(onsets, groups)$same), reference = "stats",
                 covers = "phases()", quantity = "pairs of windows sharing a phase, single linkage", tolerance = 0.5)
})
