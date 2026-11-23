# mixing() and segregation(): ties within and between groups of vertices in each window. On the bundled
# school_contacts spells in windows of 7, with the 14 pupils split into two groups by name order. A pair is tied
# in a window when one of its spells overlaps it. References: ergm's nodemix term on each window's snapshot, and
# Fransson's segregation-integration difference written out from its formula.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
groups <- data.frame(name = people, group = rep(c("early", "late"), each = 7L))
network <- dynet(school_contacts, nodes = groups)
onsets <- c(0, 7, 14, 21)

test_that("tie counts between every ordered pair of groups equal ergm's nodemix on each window", {
  skip_without_reference(c("ergm", "network"))
  theirs <- do.call(rbind, lapply(onsets, \(lo) {
    adjacency <- ref_adjacency(spells, lo, lo + 7, people)
    snapshot <- network::network(adjacency, directed = TRUE, matrix.type = "adjacency")
    network::set.vertex.attribute(snapshot, "group", groups$group)
    mixed <- summary(snapshot ~ nodemix("group", levels2 = TRUE))
    pair <- strsplit(sub("^mix\\.group\\.", "", names(mixed)), ".", fixed = TRUE)
    data.frame(time = lo, from_group = vapply(pair, `[[`, character(1), 1L),
               to_group = vapply(pair, `[[`, character(1), 2L), value = as.numeric(mixed))
  }))
  ours <- as.data.frame(mixing(network, "group", step = 7, window = 7))
  expect_reference(ours, theirs, reference = "ergm", covers = "mixing()", quantity = "ties between groups, windows of 7",
                   tolerance = 0, key = c("time", "from_group", "to_group"))
})

test_that("groups set by update_nodes() give ergm's nodemix counts on each window", {
  skip_without_reference(c("ergm", "network"))
  theirs <- do.call(rbind, lapply(onsets, \(lo) {
    snapshot <- network::network(ref_adjacency(spells, lo, lo + 7, people), directed = TRUE, matrix.type = "adjacency")
    network::set.vertex.attribute(snapshot, "group", groups$group)
    mixed <- summary(snapshot ~ nodemix("group", levels2 = TRUE))
    pair <- strsplit(sub("^mix\\.group\\.", "", names(mixed)), ".", fixed = TRUE)
    data.frame(time = lo, from_group = vapply(pair, `[[`, character(1), 1L),
               to_group = vapply(pair, `[[`, character(1), 2L), value = as.numeric(mixed))
  }))
  # The network is built without groups; update_nodes() adds them, and mixing() reads them.
  ours <- as.data.frame(mixing(update_nodes(dynet(school_contacts), groups), "group", step = 7, window = 7))
  expect_reference(ours, theirs, reference = "ergm", covers = c("update_nodes()", "mixing()"),
                   quantity = "ties between groups set by update_nodes(), windows of 7", tolerance = 0,
                   key = c("time", "from_group", "to_group"))
})

test_that("tie counts between groups equal the snapshot's adjacency summed by group", {
  theirs <- do.call(rbind, lapply(onsets, \(lo) {
    adjacency <- ref_adjacency(spells, lo, lo + 7, people)
    counts <- rowsum(t(rowsum(adjacency, groups$group)), groups$group)
    data.frame(time = lo, from_group = colnames(counts)[col(counts)], to_group = rownames(counts)[row(counts)],
               value = as.vector(counts))
  }))
  ours <- as.data.frame(mixing(network, "group", step = 7, window = 7))
  expect_reference(ours, theirs, reference = "independent: snapshot adjacency summed by group, base R",
                   covers = "mixing()", quantity = "ties between groups, windows of 7", tolerance = 0,
                   key = c("time", "from_group", "to_group"))
})

test_that("segregation equals Fransson's segregation-integration difference on each folded window", {
  sid <- function(adjacency, group) {
    folded <- pmax(adjacency, t(adjacency))
    levels_seen <- sort(unique(group))
    sum(vapply(levels_seen, \(one) {
      inside <- group == one
      n_a <- sum(inside)
      within <- sum(folded[inside, inside]) / 2
      between <- sum(vapply(setdiff(levels_seen, one), \(other) {
        sum(folded[inside, group == other]) / (n_a * sum(group == other))
      }, numeric(1)))
      2 * within / (n_a * (n_a - 1)) - between
    }, numeric(1)))
  }
  theirs <- data.frame(time = onsets, measure = "sid",
                       value = vapply(onsets, \(lo) sid(ref_adjacency(spells, lo, lo + 7, people), groups$group),
                                      numeric(1)))
  ours <- as.data.frame(segregation(network, "group", step = 7, window = 7))
  # Sums of a few ratios of small integers.
  expect_reference(ours, theirs, reference = "independent: Fransson segregation-integration difference, base R",
                   covers = "segregation()", quantity = "SID, windows of 7", tolerance = 1e-12, key = c("time", "measure"))
})

test_that("ties between groups counted as spells, not ties, differ (negative control)", {
  # The last window is left out: each of its pairs has a single spell.
  full <- utils::head(onsets, -1L)
  theirs <- data.frame(time = full, value = vapply(full, \(lo) nrow(subset(spells, start < lo + 7 & end > lo)), numeric(1)))
  mixed <- subset(as.data.frame(mixing(network, "group", step = 7, window = 7)), time < 21)
  ours <- data.frame(time = full, value = as.numeric(tapply(mixed$value, mixed$time, sum)))
  expect_differs(ours, theirs, reference = "independent: snapshot adjacency summed by group, base R",
                 covers = "mixing()", quantity = "ties between all groups against spells", tolerance = 0.5, key = "time")
})
