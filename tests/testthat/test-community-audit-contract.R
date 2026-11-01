# Audit of the community verbs, 2026-11-01: the defects found, each pinned by
# a condition-class test and an invariant, plus the oracle checks the audit
# ran against igraph and a hand evaluation of the Mucha et al. formula.

# Three dense blocks of eight; block one splits at bin 3 and blocks two and
# three merge at bin 5. Labels are scrambled per bin so matching has work.
scrambled_truth <- function(seed = 9L) {
  base <- rep(1:3, each = 8L)
  truth <- vapply(0:7, function(t) {
    g <- base
    if (t >= 3) g[1:4] <- 4L
    if (t >= 5) g[g == 3L] <- 2L
    g
  }, integer(24L))
  nodes <- sprintf("v%02d", 1:24)
  set.seed(seed)
  raw <- unlist(lapply(seq_len(8L), function(b) {
    codes <- sample(100:199, 4L)
    codes[truth[, b]]
  }))
  data.frame(time = rep(0:7, each = 24L), node = rep(nodes, 8L),
             community = raw, stringsAsFactors = FALSE)
}

# A clean planted partition: identical blocks in every bin, no noise.
clean_blocks <- function(names = sprintf("v%02d", 1:12), bins = 3L) {
  block <- rep(1:3, each = 4L)
  pairs <- t(utils::combn(12L, 2L))
  inside <- pairs[block[pairs[, 1L]] == block[pairs[, 2L]], , drop = FALSE]
  bridge <- rbind(c(4L, 5L), c(8L, 9L))
  links <- rbind(inside, bridge)
  rows <- do.call(rbind, lapply(seq_len(bins) - 1L, function(t) {
    data.frame(from = names[links[, 1L]], to = names[links[, 2L]], time = t)
  }))
  quiet_dynet(rows, format = "contact", directed = FALSE,
              nodes = data.frame(name = names), observation_start = 0,
              observation_end = bins)
}

# ------------------------------------------------- matched_from (defect 1)

test_that("matched_from names the predecessor by its matched label", {
  events <- as.data.frame(match_communities(scrambled_truth()),
                          what = "events")
  persist <- subset(events, event == "persist")
  # A continuation inherits its predecessor's label, so the two must agree.
  # Before the fix matched_from carried the predecessor's raw per-bin code.
  expect_identical(persist$matched_from, persist$community)
  # The splinter of the bin-3 split records the community it came from.
  split <- subset(events, time == 3 & event == "split")
  expect_identical(nrow(split), 2L)
  expect_length(unique(split$matched_from), 1L)
  expect_true(unique(split$matched_from) %in%
                subset(events, time == 2)$community)
  expect_true(all(split$overlap > 0))
})

test_that("every matched_from is a label alive in the previous bin", {
  for (seed in 1:5) {
    events <- as.data.frame(match_communities(scrambled_truth(seed)),
                            what = "events")
    times <- sort(unique(events$time))
    linked <- subset(events, !is.na(matched_from))
    before <- times[match(linked$time, times) - 1L]
    alive <- mapply(function(t, label) {
      label %in% subset(events, time == t & event != "dissolve")$community
    }, before, linked$matched_from)
    expect_true(all(alive), info = sprintf("seed %d", seed))
  }
  expect_error(match_communities(scrambled_truth(), threshold = -1),
               class = "dynet_bad_input")
})

test_that("a hand-computed two-bin Jaccard matching is reproduced", {
  # Bin 0: {a,b,c} {d,e,f}. Bin 1: {d,e,f,g} {a,b} {c}, raw codes scrambled.
  # Jaccard: {a,b,c} vs {a,b} = 2/3, vs {c} = 1/3; {d,e,f} vs {d,e,f} over
  # the vertices active in both bins = 1. So the optimal pairing is
  # {a,b,c} -> {a,b} and {d,e,f} -> {d,e,f,g}; {c} is a splinter of the first.
  x <- data.frame(
    time = c(rep(0, 7), rep(1, 7)),
    node = rep(letters[1:7], 2),
    community = c(5, 5, 5, 7, 7, 7, 9, 3, 3, 1, 2, 2, 2, 2),
    active = c(rep(TRUE, 6), FALSE, rep(TRUE, 7)))
  out <- match_communities(x, threshold = 0.2)
  late <- subset(as.data.frame(out), time == 1)
  early <- subset(as.data.frame(out), time == 0)
  expect_identical(late$community[late$node == "a"],
                   early$community[early$node == "a"])
  expect_identical(late$community[late$node == "d"],
                   early$community[early$node == "d"])
  expect_false(late$community[late$node == "c"] %in% early$community)
  events <- subset(as.data.frame(out, what = "events"), time == 1)
  splinter <- subset(events, community == late$community[late$node == "c"])
  expect_identical(splinter$event, "split")
  expect_equal(splinter$overlap, 1 / 3)
  expect_identical(splinter$matched_from,
                   early$community[early$node == "a"])
  # Partial injection: no earlier label is inherited twice in one bin.
  inherited <- subset(events, event != "dissolve" & event != "born")
  expect_false(anyDuplicated(inherited$community) > 0L)
})

# ------------------------------------- dynet_bad_input parents (defect 2)

test_that("every community error carries the dynet_bad_input parent", {
  dn <- clean_blocks()
  found <- temporal_communities(dn, step = 1, window = 1, seeds = 1:2)
  expect_error(community_change(found, measure = "nope"),
               class = "dynet_unknown_measure")
  expect_error(community_change(found, measure = "nope"),
               class = "dynet_bad_input")
  expect_error(community_trajectory(found, measure = "nope"),
               class = "dynet_bad_input")
  raw <- scrambled_truth()
  expect_error(community_trajectory(raw), class = "dynet_unmatched_labels")
  expect_error(community_trajectory(raw), class = "dynet_bad_input")
  stranger <- data.frame(time = 0, node = "zz", community = 1)
  expect_error(multislice_modularity(dn, membership = stranger, step = 1,
                                     window = 1),
               class = "dynet_unknown_node")
  expect_error(multislice_modularity(dn, membership = stranger, step = 1,
                                     window = 1),
               class = "dynet_bad_input")
  matched <- match_communities(raw)
  expect_error(community_trajectory(matched, measure = "recruitment",
                                    reference = "nope"),
               class = "dynet_bad_input")
})

test_that("a one-bin trajectory is an empty result and a bad input", {
  dn <- clean_blocks(bins = 1L)
  found <- temporal_communities(dn, step = 1, window = 1, seeds = 1:2)
  expect_error(community_trajectory(found), class = "dynet_empty_result")
  expect_error(community_trajectory(found), class = "dynet_bad_input")
})

# ------------------------------------------------ non-convergence (defect 3)

test_that("a run stopped by max_passes says so", {
  dn <- clean_blocks()
  expect_warning(
    temporal_communities(dn, step = 1, window = 1, seeds = 1:3,
                         max_passes = 1),
    class = "dynet_no_converge")
  # At the default cap the clean structure converges, and nothing is said.
  expect_no_warning(
    temporal_communities(dn, step = 1, window = 1, seeds = 1:3))
})

test_that("consensus that never agrees is reported, not returned as agreed", {
  # A ring has no community structure, so the runs disagree; one round with
  # no aggregation pass cannot reconcile them.
  ring <- data.frame(from = sprintf("n%02d", 1:12),
                     to = sprintf("n%02d", c(2:12, 1)))
  rows <- do.call(rbind, lapply(0:2, function(t) transform(ring, time = t)))
  dn <- quiet_dynet(rows, format = "contact", directed = FALSE,
                    observation_start = 0, observation_end = 3)
  supra <- .supra(projection(dn, step = 1, window = 1))
  flat <- lapply(1:6, function(s) .with_seed(s, {
    labels <- .genlouvain_run(supra, 1, 1, "ordinal", 1e-10, 20L)
    v <- unlist(lapply(labels, as.vector))
    match(v, unique(v))
  }))
  expect_gt(length(unique(flat)), 1L)
  expect_warning(
    out <- .consensus_partition(supra, flat, 1, 1, "ordinal", 1e-10, 1L,
                                1:6),
    class = "dynet_no_converge")
  # Whatever it returns is still a full partition of every state.
  expect_identical(sum(vapply(out, length, integer(1L))), 36L)
  expect_false(anyNA(unlist(out)))
})

# --------------------------------------------- empty uncoupled bin (defect 4)

test_that("an edgeless bin under omega = 0 warns that its labels are arbitrary", {
  dn <- clean_blocks(bins = 4L)
  rows <- subset(as.data.frame(dn), start != 2)
  gap <- quiet_dynet(data.frame(from = rows$from, to = rows$to,
                                time = rows$start),
                     format = "contact", directed = FALSE,
                     nodes = data.frame(name = dn$nodes$name),
                     observation_start = 0, observation_end = 4)
  expect_warning(
    temporal_communities(gap, omega = 0, step = 1, window = 1, seeds = 1:2),
    class = "dynet_empty_slice")
  # With coupling the quiet bin inherits its labels, so nothing to warn
  # about, and every vertex still has exactly one community per bin.
  coupled <- temporal_communities(gap, omega = 1, step = 1, window = 1,
                                  seeds = 1:2)
  expect_identical(attr(coupled, "n_empty_slices"), 1L)
  per_bin <- table(coupled$time, coupled$node)
  expect_true(all(per_bin == 1L))
  frame <- as.data.frame(coupled)
  expect_identical(subset(frame, time == 2)$community,
                   subset(frame, time == 1)$community)
})

# -------------------------------------------------------------- oracles

test_that("with omega = 0 each bin's modularity is Newman's, and blocks are found", {
  # igraph::modularity() and igraph::cluster_louvain() were the oracle in the
  # audit (agreement to 1e-15, NMI 1); igraph is not a declared dependency,
  # so the shipped test recomputes Newman-Girvan Q directly.
  dn <- clean_blocks()
  found <- temporal_communities(dn, omega = 0, step = 1, window = 1,
                                seeds = 1:3)
  score <- multislice_modularity(dn, membership = found, omega = 0,
                                 step = 1, window = 1)
  bins <- as.data.frame(score, what = "bins")
  supra <- .supra(projection(dn, step = 1, window = 1))
  frame <- as.data.frame(found)
  newman <- vapply(seq_along(supra$blocks[[1L]]$layers), function(s) {
    a <- supra$blocks[[1L]]$layers[[s]]
    slice <- subset(frame, time == bins$time[[s]])
    labels <- slice$community[match(rownames(a), slice$node)]
    k <- rowSums(a)
    sum((a - outer(k, k) / sum(k)) * outer(labels, labels, "==")) / sum(k)
  }, numeric(1L))
  expect_equal(bins$q, newman, tolerance = 1e-12)
  expect_true(all(bins$q >= -0.5 & bins$q <= 1))
  # The planted blocks are the communities found, in every bin.
  block <- rep(1:3, each = 4L)
  for (t in unique(frame$time)) {
    slice <- subset(frame, time == t)
    found_block <- slice$community[order(slice$node)]
    pair <- unique(data.frame(x = found_block, y = block))
    expect_identical(nrow(pair), 3L)
  }
})

test_that("Q equals the Mucha formula evaluated by hand on two slices", {
  rows <- data.frame(from = c("a", "c", "a", "a", "b", "a"),
                     to = c("b", "d", "c", "b", "c", "d"),
                     time = c(0, 0, 0, 1, 1, 1))
  dn <- quiet_dynet(rows, format = "contact", directed = FALSE,
                    observation_start = 0, observation_end = 2)
  g <- cbind(c(1, 1, 2, 2), c(1, 1, 1, 2))
  membership <- data.frame(time = rep(c(0, 1), each = 4),
                           node = rep(c("a", "b", "c", "d"), 2),
                           community = as.vector(g))
  # Slice 0: a-b, a-c, c-d. Slice 1: a-b, b-c, a-d. Every 2m_s = 6.
  a0 <- matrix(c(0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0), 4)
  a1 <- matrix(c(0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0), 4)
  hand <- function(gamma, omega) {
    slice <- function(a, labels) {
      k <- rowSums(a)
      same <- outer(labels, labels, "==")
      sum((a - gamma * outer(k, k) / sum(k)) * same)
    }
    coupling <- 2 * omega * sum(g[, 1] == g[, 2])
    (slice(a0, g[, 1]) + slice(a1, g[, 2]) + coupling) / (12 + 8 * omega)
  }
  for (gamma in c(0.5, 1, 1.7)) for (omega in c(0, 0.5, 3)) {
    q <- as.data.frame(multislice_modularity(dn, membership = membership,
                                             gamma = gamma, omega = omega,
                                             step = 1, window = 1))
    expect_equal(q$value[q$measure == "q"], hand(gamma, omega),
                 tolerance = 1e-12,
                 info = sprintf("gamma %s omega %s", gamma, omega))
  }
})

# ----------------------------------------------------------- invariants

test_that("a clean structure is recovered whatever the vertices are called", {
  plain <- temporal_communities(clean_blocks(), step = 1, window = 1,
                                seeds = 1:3)
  renamed_names <- sprintf("z%02d", 12:1)
  renamed <- temporal_communities(clean_blocks(renamed_names), step = 1,
                                  window = 1, seeds = 1:3)
  expect_equal(attr(renamed, "q"), attr(plain, "q"), tolerance = 1e-12)
  a <- as.data.frame(plain)
  b <- as.data.frame(renamed)
  b$node <- sprintf("v%02d", 13L - as.integer(sub("z", "", b$node)))
  b <- b[order(b$time, b$node), ]
  a <- a[order(a$time, a$node), ]
  # Same partition up to the names of the communities.
  pair <- unique(data.frame(x = a$community, y = b$community))
  expect_false(anyDuplicated(pair$x) > 0L)
  expect_false(anyDuplicated(pair$y) > 0L)
})

test_that("shuffling the spell rows changes nothing", {
  dn <- clean_blocks()
  rows <- as.data.frame(dn)
  set.seed(4)
  shuffled <- rows[sample(nrow(rows)), ]
  dn2 <- quiet_dynet(data.frame(from = shuffled$from, to = shuffled$to,
                                time = shuffled$start),
                     format = "contact", directed = FALSE,
                     nodes = data.frame(name = dn$nodes$name),
                     observation_start = 0, observation_end = 3)
  a <- temporal_communities(dn, step = 1, window = 1, seeds = 1:3)
  b <- temporal_communities(dn2, step = 1, window = 1, seeds = 1:3)
  expect_identical(as.data.frame(a), as.data.frame(b))
})
