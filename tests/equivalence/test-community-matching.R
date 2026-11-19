# The community verbs that compare partitions across bins: community_change() (partition comparison between
# consecutive bins), match_communities() (optimal assignment of community labels across bins) and
# community_trajectory() (flexibility, promiscuity, persistence). The input is a random membership table, not
# temporal_communities(), whose optimiser is stochastic. References: igraph's compare(), aricode, scikit-learn's
# adjusted mutual information, clue's linear assignment solver, and the formulas written out in base R.

#' A random membership table: `bins` bins of `n` vertices in up to four communities
random_membership <- function(seed, n = 30L, bins = 4L) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
          add = TRUE)
  set.seed(seed)
  planted <- sample(1:4, n, TRUE)
  labels <- lapply(seq_len(bins), \(bin) {
    moved <- planted
    flip <- sample(n, 6L)
    moved[flip] <- sample(1:4, 6L, TRUE)
    moved
  })
  data.frame(time = rep(seq_len(bins) - 1, each = n), node = rep(sprintf("v%02d", seq_len(n)), bins),
             community = unlist(labels))
}

#' Each bin's partition beside the previous bin's, as two label vectors over the same vertices
consecutive <- function(table) {
  bins <- split(table, table$time)
  Map(\(before, after) {
    shared <- intersect(before$node, after$node)
    list(time = after$time[[1L]], before = before$community[match(shared, before$node)],
         after = after$community[match(shared, after$node)])
  }, utils::head(bins, -1L), utils::tail(bins, -1L))
}

test_that("NMI, VI, split-join distance and ARI between consecutive bins equal igraph::compare()", {
  skip_without_reference("igraph")
  table <- random_membership(21L)
  theirs <- do.call(rbind, lapply(consecutive(table), \(pair) {
    data.frame(time = pair$time, measure = c("nmi", "vi", "split_join", "ari"),
               value = c(igraph::compare(pair$before, pair$after, method = "nmi"),
                         igraph::compare(pair$before, pair$after, method = "vi"),
                         igraph::compare(pair$before, pair$after, method = "split.join"),
                         igraph::compare(pair$before, pair$after, method = "adjusted.rand")))
  }))
  ours <- subset(as.data.frame(community_change(match_communities(table),
                                                measure = c("nmi", "vi", "split_join", "ari"))), !is.na(value))
  expect_reference(ours, theirs, reference = "igraph", covers = "community_change()",
                   quantity = "consecutive bins, 30 vertices", tolerance = 1e-12, key = c("time", "measure"))
})

test_that("NMI and ARI between consecutive bins equal aricode", {
  skip_without_reference("aricode")
  table <- random_membership(21L)
  theirs <- do.call(rbind, lapply(consecutive(table), \(pair) {
    data.frame(time = pair$time, measure = c("nmi", "ari"),
               value = c(aricode::NMI(pair$before, pair$after, variant = "sum"), aricode::ARI(pair$before, pair$after)))
  }))
  ours <- subset(as.data.frame(community_change(match_communities(table), measure = c("nmi", "ari"))), !is.na(value))
  expect_reference(ours, theirs, reference = "aricode", covers = "community_change()",
                   quantity = "consecutive bins, 30 vertices", tolerance = 1e-12, key = c("time", "measure"))
})

test_that("AMI between consecutive bins equals scikit-learn's adjusted_mutual_info_score (arithmetic mean)", {
  ref_skip_without_python("sklearn", reference = "scikit-learn")
  table <- random_membership(21L)
  pairs <- consecutive(table)
  ami <- ref_python(c(
    "import json, sys",
    "from sklearn.metrics import adjusted_mutual_info_score",
    "given = json.load(open(sys.argv[1]))",
    "json.dump([adjusted_mutual_info_score(p['before'], p['after'], average_method='arithmetic') for p in given],",
    "          open(sys.argv[2], 'w'))"),
    unname(lapply(pairs, \(pair) list(before = pair$before, after = pair$after))))
  theirs <- data.frame(time = vapply(pairs, `[[`, numeric(1), "time"), measure = "ami", value = as.numeric(ami))
  ours <- subset(as.data.frame(community_change(match_communities(table), measure = "ami")), !is.na(value))
  # The expected mutual information is a hypergeometric sum taken in a different order on each side.
  expect_reference(ours, theirs, reference = "scikit-learn", covers = "community_change()",
                   quantity = "AMI, consecutive bins", tolerance = 1e-10, key = c("time", "measure"),
                   note = sprintf("scikit-learn %s", ref_python_version("sklearn")))
})

test_that("AMI with aricode's maximum-entropy normaliser is a known difference", {
  skip_without_reference("aricode")
  table <- random_membership(21L)
  theirs <- do.call(rbind, lapply(consecutive(table), \(pair) {
    data.frame(time = pair$time, measure = "ami", value = aricode::AMI(pair$before, pair$after))
  }))
  ours <- subset(as.data.frame(community_change(match_communities(table), measure = "ami")), !is.na(value))
  expect_known_difference(ours, theirs, reference = "aricode", covers = "community_change()",
                          quantity = "AMI, consecutive bins", tolerance = 1e-10, key = c("time", "measure"),
                          reason = "Dynet normalises adjusted mutual information by the arithmetic mean of the two entropies (scikit-learn's default); aricode::AMI() by their maximum.")
})

test_that("the label matching between two bins reaches the total Jaccard overlap clue::solve_LSAP() reaches", {
  skip_without_reference("clue")
  table <- subset(random_membership(5L, n = 40L, bins = 2L))
  before <- subset(table, time == 0)
  after <- subset(table, time == 1)
  jaccard <- outer(sort(unique(before$community)), sort(unique(after$community)), Vectorize(\(i, j) {
    one <- before$node[before$community == i]
    two <- after$node[after$community == j]
    length(intersect(one, two)) / length(union(one, two))
  }))
  size <- max(dim(jaccard))
  square <- matrix(0, size, size)
  square[seq_len(nrow(jaccard)), seq_len(ncol(jaccard))] <- jaccard
  optimum <- sum(square[cbind(seq_len(size), as.integer(clue::solve_LSAP(square, maximum = TRUE)))])
  matched <- as.data.frame(match_communities(table, threshold = 0))
  first <- unique(subset(matched, time == 0, select = c(community, community_raw)))
  second <- unique(subset(matched, time == 1, select = c(community, community_raw)))
  kept <- merge(first, second, by = "community", suffixes = c("_before", "_after"))
  ours <- sum(jaccard[cbind(match(kept$community_raw_before, sort(unique(before$community))),
                            match(kept$community_raw_after, sort(unique(after$community))))])
  expect_reference(ours, optimum, reference = "clue", covers = "match_communities()",
                   quantity = "total Jaccard overlap of the matching", tolerance = 1e-12)
})

test_that("the matched table keeps every vertex's raw label", {
  table <- random_membership(21L)
  expect_reference(as.data.frame(match_communities(table)), stats::setNames(table, c("time", "node", "community_raw")),
                   reference = "independent: the membership table given, base R",
                   covers = "as.data.frame.dynet_communities()", quantity = "raw label", tolerance = 0,
                   key = c("time", "node"))
})

test_that("summary() of the matched communities gives each community's states, vertices and bins", {
  matched <- as.data.frame(match_communities(random_membership(21L)))
  theirs <- do.call(rbind, lapply(split(matched, matched$community), \(rows) {
    data.frame(community = rows$community[[1L]], n_states = nrow(rows), n_nodes = length(unique(rows$node)),
               first_time = min(rows$time), last_time = max(rows$time), n_bins = length(unique(rows$time)))
  }))
  expect_reference(as.data.frame(summary(match_communities(random_membership(21L)))), theirs,
                   reference = "independent: aggregation of the matched table, base R",
                   covers = "summary.dynet_communities()", quantity = "per community", tolerance = 0, key = "community")
})

test_that("flexibility, promiscuity and persistence equal their formulas on the matched labels", {
  matched <- as.data.frame(match_communities(random_membership(21L)))
  by_node <- split(matched[order(matched$time), ], matched$node[order(matched$time)])
  labels_seen <- length(unique(matched$community))
  theirs <- do.call(rbind, lapply(by_node, \(rows) {
    changes <- mean(diff(rows$community) != 0)
    data.frame(node = rows$node[[1L]], measure = c("flexibility", "promiscuity", "persistence"),
               value = c(changes, (length(unique(rows$community)) - 1) / (labels_seen - 1), 1 - changes))
  }))
  ours <- as.data.frame(community_trajectory(match_communities(random_membership(21L)),
                                             measure = c("flexibility", "promiscuity", "persistence")))
  expect_reference(ours, theirs, reference = "independent: flexibility, promiscuity and persistence formulas, base R",
                   covers = c("community_trajectory()", "as.data.frame.dynet_trajectory()"), quantity = "per vertex",
                   tolerance = 1e-12,
                   key = c("node", "measure"))
})

test_that("NMI against the bins two apart differs (negative control)", {
  skip_without_reference("igraph")
  table <- random_membership(21L)
  bins <- split(table$community, table$time)
  theirs <- data.frame(time = c(2, 3), measure = "nmi",
                       value = c(igraph::compare(bins[[1L]], bins[[3L]], method = "nmi"),
                                 igraph::compare(bins[[2L]], bins[[4L]], method = "nmi")))
  ours <- subset(as.data.frame(community_change(match_communities(table), measure = "nmi")), time >= 2)
  expect_differs(ours, theirs, reference = "igraph", covers = "community_change()",
                 quantity = "NMI against a bin two apart", tolerance = 1e-6, key = c("time", "measure"))
})
