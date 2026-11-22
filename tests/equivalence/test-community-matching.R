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

# The assignment of one bin's communities to the next, written out from the definition: the Jaccard overlap
# of two communities over the vertices present in both bins (match_communities()' Details), the assignment that
# maximises the total overlap from clue::solve_LSAP() on the matrix padded square with zeros, and a pairing kept
# only when its overlap exceeds `threshold`. Every later community is one row: `before` is the raw label of the
# earlier community whose label it inherits (0 when it inherits none) and `overlap` the score of that pairing (0
# when none). Nothing below calls Dynet.

#' Two bins as a membership table, from two vectors of labels named by vertex
two_bins <- function(before, after) {
  data.frame(time = rep(c(0, 1), c(length(before), length(after))), node = c(names(before), names(after)),
             community = unname(c(before, after)))
}

#' Two bins of random labels: `k_before` communities, then each vertex's label folded onto `k_after` and a
#' share `drift` of the vertices moved at random; every label of both bins occurs
seeded_two_bins <- function(seed, n, k_before, k_after, drift = 0.3) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
          add = TRUE)
  set.seed(seed)
  before <- sample(c(seq_len(k_before), sample(k_before, n - k_before, TRUE)))
  after <- (before - 1L) %% k_after + 1L
  moved <- sample(n, round(drift * n))
  after[moved] <- sample(k_after, length(moved), TRUE)
  after[sample(n, k_after)] <- seq_len(k_after)
  names(before) <- names(after) <- sprintf("v%02d", seq_len(n))
  list(before = before, after = after)
}

#' The overlap of every earlier community with every later one, over the vertices present in both bins
ref_overlap <- function(before, after, overlap = c("jaccard", "intersection")) {
  overlap <- match.arg(overlap)
  shared <- intersect(names(before), names(after))
  rows <- sort(unique(before))
  cols <- sort(unique(after))
  score <- outer(rows, cols, Vectorize(\(i, j) {
    one <- intersect(names(before)[before == i], shared)
    two <- intersect(names(after)[after == j], shared)
    both <- length(intersect(one, two))
    either <- length(union(one, two))
    if (identical(overlap, "intersection")) both else if (either > 0L) both / either else 0
  }))
  dimnames(score) <- list(rows, cols)
  score
}

#' The weight matrix padded square with zeros, and the earlier community assigned to each later one by
#' clue::solve_LSAP() (0 for a later community left to the padding)
ref_lsap <- function(weight) {
  size <- max(dim(weight))
  square <- matrix(0, size, size)
  square[seq_len(nrow(weight)), seq_len(ncol(weight))] <- weight
  column <- as.integer(clue::solve_LSAP(square, maximum = TRUE))
  list(total = sum(square[cbind(seq_len(size), column)]),
       row_of = vapply(seq_len(ncol(weight)), \(j) {
         row <- which(column == j)
         if (length(row) && row <= nrow(weight)) row else 0L
       }, integer(1)))
}

#' Greene, Doyle and Cunningham's (2010) greedy step: take the largest remaining overlap, remove its row and
#' column, repeat while one is positive; the row given to each column (0 for none). Stops on a tie between two
#' candidates for the largest, where the greedy answer would depend on the order of the rows.
ref_greedy <- function(weight) {
  state <- Reduce(\(state, step) {
    open <- weight
    open[state$used_rows, ] <- -Inf
    open[, state$used_cols] <- -Inf
    best <- max(open)
    if (best <= 0) return(state)
    stopifnot("the greedy step has a tie" = sum(abs(open - best) < 1e-12) == 1L)
    cell <- which(abs(open - best) < 1e-12, arr.ind = TRUE)
    state$row_of[[cell[[1L, 2L]]]] <- cell[[1L, 1L]]
    state$used_rows <- c(state$used_rows, cell[[1L, 1L]])
    state$used_cols <- c(state$used_cols, cell[[1L, 2L]])
    state
  }, seq_len(min(dim(weight))), list(row_of = integer(ncol(weight)), used_rows = integer(), used_cols = integer()))
  state$row_of
}

#' Every permutation of `seq_len(n)`, one per row
ref_permutations <- function(n) {
  if (n == 1L) return(matrix(1L, 1L, 1L))
  smaller <- ref_permutations(n - 1L)
  do.call(rbind, lapply(seq_len(n), \(first) {
    cbind(first, matrix(setdiff(seq_len(n), first)[smaller], nrow(smaller)))
  }))
}

#' How many different sets of pairings above `threshold` reach the maximum total, by enumeration of every
#' assignment of the padded square matrix: 1 when the optimal matching is unique
ref_optimal_pairings <- function(weight, threshold = 0) {
  size <- max(dim(weight))
  square <- matrix(0, size, size)
  square[seq_len(nrow(weight)), seq_len(ncol(weight))] <- weight
  every <- ref_permutations(size)
  totals <- apply(every, 1L, \(column) sum(square[cbind(seq_len(size), column)]))
  best <- every[abs(totals - max(totals)) < 1e-12, , drop = FALSE]
  kept <- apply(best, 1L, \(column) {
    above <- square[cbind(seq_len(size), column)] > threshold
    paste(which(above), column[above], collapse = ";")
  })
  length(unique(kept))
}

#' The pairing expected for every later community from a row assignment
ref_pairing <- function(weight, row_of, threshold = 0) {
  score <- ifelse(row_of > 0L, weight[cbind(pmax(row_of, 1L), seq_len(ncol(weight)))], 0)
  inherits <- score > threshold
  data.frame(after = as.numeric(colnames(weight)),
             before = ifelse(inherits, as.numeric(rownames(weight))[pmax(row_of, 1L)], 0),
             overlap = ifelse(inherits, score, 0))
}

#' Dynet's pairing for every community of bin `to`: the raw label of the bin-`from` community whose matched label
#' it carries (0 when none) and the overlap the events table records for that inheritance (0 when none)
dynet_pairing <- function(matched, from, to) {
  members <- unique(subset(as.data.frame(matched), select = c(time, community, community_raw)))
  later <- stats::setNames(subset(members, time == to, select = c(community, community_raw)), c("community", "after"))
  earlier <- stats::setNames(subset(members, time == from, select = c(community, community_raw)),
                             c("community", "before"))
  inherited <- subset(as.data.frame(matched, what = "events"),
                      time == to & !is.na(matched_from) & matched_from == community, select = c(community, overlap))
  out <- merge(merge(later, earlier, by = "community", all.x = TRUE), inherited, by = "community", all.x = TRUE)
  data.frame(after = as.numeric(out$after), before = ifelse(is.na(out$before), 0, as.numeric(out$before)),
             overlap = ifelse(is.na(out$overlap), 0, out$overlap))
}

#' The total overlap of the pairings Dynet made into bin `to`
dynet_total <- function(matched, from, to) sum(dynet_pairing(matched, from, to)$overlap)

# Tolerance 1e-12 throughout: each overlap is one division of two counts on both sides, a total a sum of at most
# six such ratios; the labels are integers.

matching_inputs <- list(
  "40 vertices, 3 communities then 5" = seeded_two_bins(31L, 40L, 3L, 5L),
  "40 vertices, 5 communities then 3" = seeded_two_bins(33L, 40L, 5L, 3L),
  "40 vertices, 6 communities then 6" = seeded_two_bins(37L, 40L, 6L, 6L, drift = 0.5)
)

test_that("the pairing between two bins, communities unequal in number, equals clue::solve_LSAP()", {
  skip_without_reference("clue")
  lapply(names(matching_inputs), \(label) {
    given <- matching_inputs[[label]]
    weight <- ref_overlap(given$before, given$after)
    stopifnot("the optimal matching is unique" = ref_optimal_pairings(weight) == 1L)
    optimum <- ref_lsap(weight)
    matched <- match_communities(two_bins(given$before, given$after), threshold = 0)
    expect_reference(dynet_pairing(matched, 0, 1), ref_pairing(weight, optimum$row_of), reference = "clue",
                     covers = "match_communities()", quantity = sprintf("pairing, %s", label), tolerance = 1e-12,
                     key = "after")
    expect_reference(dynet_total(matched, 0, 1), optimum$total, reference = "clue", covers = "match_communities()",
                     quantity = sprintf("total Jaccard overlap, %s", label), tolerance = 1e-12)
  })
})

test_that("with vertices leaving and joining, the pairing over the vertices of both bins equals clue::solve_LSAP()", {
  skip_without_reference("clue")
  # v01-v10 leave after bin 0 (community 1 has no one left), v31-v40 join in bin 1 (community 9 has no one who
  # was there before): both are communities with no member in the overlap, the first dissolves, the second is born.
  before <- stats::setNames(c(rep(1, 10), rep(2, 8), rep(3, 7), rep(4, 5)), sprintf("v%02d", 1:30))
  after <- stats::setNames(c(rep(5, 6), rep(6, 5), rep(7, 9), rep(9, 10)), sprintf("v%02d", 11:40))
  weight <- ref_overlap(before, after)
  stopifnot("community 9 has no member present in both bins" = all(weight[, "9"] == 0),
            "community 1 has no member present in both bins" = all(weight["1", ] == 0),
            "the optimal matching is unique" = ref_optimal_pairings(weight) == 1L)
  optimum <- ref_lsap(weight)
  matched <- match_communities(two_bins(before, after), threshold = 0)
  expect_reference(dynet_pairing(matched, 0, 1), ref_pairing(weight, optimum$row_of), reference = "clue",
                   covers = "match_communities()", quantity = "pairing, vertices leaving and joining",
                   tolerance = 1e-12, key = "after")
  expect_reference(dynet_total(matched, 0, 1), optimum$total, reference = "clue", covers = "match_communities()",
                   quantity = "total Jaccard overlap, vertices leaving and joining", tolerance = 1e-12)
})

test_that("over three bins each consecutive pairing equals clue::solve_LSAP()", {
  skip_without_reference("clue")
  first <- seeded_two_bins(41L, 60L, 4L, 6L)
  second <- seeded_two_bins(42L, 60L, 6L, 5L)
  bins <- list(first$before, first$after, (second$after + first$after) %% 5 + 1)
  bins[[3L]] <- stats::setNames(bins[[3L]], names(first$after))
  table <- do.call(rbind, Map(\(labels, time) data.frame(time = time, node = names(labels), community = labels),
                              bins, c(0, 1, 2)))
  matched <- match_communities(table, threshold = 0)
  lapply(c(1L, 2L), \(step) {
    weight <- ref_overlap(bins[[step]], bins[[step + 1L]])
    stopifnot("the optimal matching is unique" = ref_optimal_pairings(weight) == 1L)
    expect_reference(dynet_pairing(matched, step - 1, step), ref_pairing(weight, ref_lsap(weight)$row_of),
                     reference = "clue", covers = "match_communities()",
                     quantity = sprintf("pairing into bin %d of three, 60 vertices", step), tolerance = 1e-12,
                     key = "after")
  })
})

test_that("with tied overlaps the total of the matching equals clue::solve_LSAP()'s", {
  skip_without_reference("clue")
  # Every community of bin 0 shares two of its four vertices with every community of bin 1: each overlap is
  # 2 / 6 and both assignments reach 2 / 3. The pairs are not unique, so only the total is compared.
  before <- stats::setNames(rep(c(1, 2), each = 4), sprintf("v%02d", 1:8))
  after <- stats::setNames(c(1, 1, 2, 2, 1, 1, 2, 2), sprintf("v%02d", 1:8))
  weight <- ref_overlap(before, after)
  stopifnot("both assignments are optimal" = ref_optimal_pairings(weight) == 2L)
  matched <- match_communities(two_bins(before, after), threshold = 0)
  expect_reference(dynet_total(matched, 0, 1), ref_lsap(weight)$total, reference = "clue",
                   covers = "match_communities()", quantity = "total Jaccard overlap, tied overlaps",
                   tolerance = 1e-12)
})

# Communities A, B in bin 0 and X, Y in bin 1 share 5 (A, X), 4 (A, Y), 4 (B, X) and 0 (B, Y) vertices. The
# shared counts make the greedy step take (A, X) and stop (total 5); the optimal assignment is (A, Y), (B, X)
# (total 8).
greedy_trap <- list(
  before = stats::setNames(c(rep(1, 9), rep(2, 4)), sprintf("v%02d", 1:13)),
  after = stats::setNames(c(rep(1, 5), rep(2, 4), rep(1, 4)), sprintf("v%02d", 1:13))
)

test_that("with overlap = 'intersection' the pairing equals clue::solve_LSAP() on the shared counts", {
  skip_without_reference("clue")
  inputs <- c(list("13 vertices, greedy and optimal differ" = greedy_trap), matching_inputs)
  lapply(names(inputs), \(label) {
    given <- inputs[[label]]
    weight <- ref_overlap(given$before, given$after, overlap = "intersection")
    stopifnot("the optimal matching is unique" = ref_optimal_pairings(weight) == 1L)
    optimum <- ref_lsap(weight)
    matched <- match_communities(two_bins(given$before, given$after), overlap = "intersection", threshold = 0)
    expect_reference(dynet_pairing(matched, 0, 1), ref_pairing(weight, optimum$row_of), reference = "clue",
                     covers = "match_communities()", quantity = sprintf("intersection pairing, %s", label),
                     tolerance = 1e-12, key = "after")
  })
})

test_that("method = 'greedy' makes the pairing of the greedy best-overlap step", {
  inputs <- list("13 vertices, intersection" = list(given = greedy_trap, overlap = "intersection"),
                 "40 vertices, 6 communities then 6, Jaccard" = list(given = matching_inputs[[3L]], overlap = "jaccard"))
  lapply(names(inputs), \(label) {
    given <- inputs[[label]]$given
    weight <- ref_overlap(given$before, given$after, overlap = inputs[[label]]$overlap)
    matched <- match_communities(two_bins(given$before, given$after), method = "greedy",
                                 overlap = inputs[[label]]$overlap, threshold = 0)
    expect_reference(dynet_pairing(matched, 0, 1), ref_pairing(weight, ref_greedy(weight)),
                     reference = "independent: greedy best-overlap assignment (Greene, Doyle and Cunningham 2010), base R",
                     covers = "match_communities()", quantity = sprintf("greedy pairing, %s", label),
                     tolerance = 1e-12, key = "after")
  })
})

test_that("a pairing below the threshold passes on no label", {
  skip_without_reference("clue")
  # A = v01-v10 and B = v11-v30 in bin 0; X = v01-v03 and Y = v04-v30 in bin 1. The optimal assignment is
  # (A, X) at 3 / 10 and (B, Y) at 20 / 27. With threshold = 0.5, X's pairing is below it: X should be born.
  before <- stats::setNames(c(rep(1, 10), rep(2, 20)), sprintf("v%02d", 1:30))
  after <- stats::setNames(c(rep(1, 3), rep(2, 27)), sprintf("v%02d", 1:30))
  weight <- ref_overlap(before, after)
  stopifnot("the optimal matching is unique" = ref_optimal_pairings(weight, threshold = 0.5) == 1L)
  matched <- match_communities(two_bins(before, after), threshold = 0.5)
  expect_reference(dynet_pairing(matched, 0, 1), ref_pairing(weight, ref_lsap(weight)$row_of, threshold = 0.5),
                   reference = "clue", covers = "match_communities()", quantity = "pairing, threshold 0.5",
                   tolerance = 1e-12, key = "after")
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
