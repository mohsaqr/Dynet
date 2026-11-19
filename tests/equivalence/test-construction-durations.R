# dynet(), its summary and table, durations() and collapse_network(): the counts and durations of a spell list.
# On the bundled school_contacts spells (240 directed spells, 110 ordered pairs, several with overlapping spells),
# against the same quantities taken from the spell list in base R, and against networkDynamic's
# network.collapse(), which merges overlapping spells of a pair before counting them.

spells <- school_contacts
network <- dynet(school_contacts)
by_spells <- "independent: aggregation of the spell list, base R"
pair_of <- \(table) paste(table$from, table$to)

test_that("the summary's counts and observed range equal the spell list's", {
  wanted <- c("vertices", "edge spells", "distinct pairs", "observed from", "observed to", "span", "time bins")
  ours <- transform(subset(summary(network), property %in% wanted), value = as.numeric(value))
  theirs <- data.frame(property = wanted,
                       value = c(length(unique(c(spells$from, spells$to))), nrow(spells),
                                 length(unique(pair_of(spells))), min(spells$start), max(spells$end),
                                 max(spells$end) - min(spells$start), ceiling(max(spells$end) - min(spells$start))))
  # Counts are integers and the range is copied from the input.
  expect_reference(ours, theirs, reference = by_spells, covers = c("dynet()", "summary.dynet()"),
                   quantity = "network", tolerance = 1e-10, key = "property")
})

test_that("the spell table keeps every spell with its duration", {
  # No two spells share sender, receiver and onset, so those three name a spell.
  expect_reference(as.data.frame(network), transform(spells, duration = end - start), reference = by_spells,
                   covers = c("dynet()", "as.data.frame.dynet()"), quantity = "spell", tolerance = 1e-10,
                   key = c("from", "to", "start"))
})

test_that("per-pair spell counts, summed, union and mean durations equal the spell list's", {
  pair <- pair_of(spells)
  duration <- spells$end - spells$start
  union <- vapply(split(spells, pair), \(one) ref_union_length(one$start, one$end), numeric(1))
  per_pair <- data.frame(pair = names(union), events = as.numeric(tapply(duration, pair, length)),
                         total = as.numeric(tapply(duration, pair, sum)), union = unname(union),
                         mean = as.numeric(tapply(duration, pair, mean)))
  theirs <- stats::reshape(per_pair, direction = "long", varying = c("events", "total", "union", "mean"),
                           v.names = "value", timevar = "measure", times = c("events", "total", "union", "mean"),
                           idvar = "pair")
  ours <- transform(as.data.frame(durations(network, measure = c("events", "total", "union", "mean"))),
                    pair = paste(from, to))
  # Sums of at most a dozen two-decimal numbers.
  expect_reference(ours, subset(theirs, select = c(pair, measure, value)), reference = by_spells,
                   covers = c("durations()", "as.data.frame.dynet_metric()"), quantity = "pair",
                   tolerance = 1e-10, key = c("pair", "measure"))
})

test_that("the collapsed network's per-pair counts, durations, first onset and last terminus equal the spell list's", {
  pair <- pair_of(spells)
  union <- vapply(split(spells, pair), \(one) ref_union_length(one$start, one$end), numeric(1))
  theirs <- data.frame(pair = names(union), spell_count = as.numeric(tapply(pair, pair, length)),
                       total_duration = as.numeric(tapply(spells$end - spells$start, pair, sum)),
                       union_duration = unname(union), first = as.numeric(tapply(spells$start, pair, min)),
                       last = as.numeric(tapply(spells$end, pair, max)))
  ours <- transform(as.data.frame(collapse_network(network, weight = "spell_count")), pair = paste(from, to))
  expect_reference(ours, theirs, reference = by_spells,
                   covers = c("collapse_network()", "as.data.frame.dynet_collapsed()"), quantity = "pair",
                   tolerance = 1e-10, key = "pair")
})

test_that("summary() of the collapsed network gives its vertex and pair counts and density", {
  vertices <- length(unique(c(spells$from, spells$to)))
  pairs <- length(unique(pair_of(spells)))
  theirs <- data.frame(property = c("vertices", "edges", "density", "total weight"),
                       value = c(vertices, pairs, pairs / (vertices * (vertices - 1)), pairs))
  ours <- transform(subset(as.data.frame(summary(collapse_network(network))), property %in% theirs$property),
                    value = as.numeric(value))
  # The summary prints the density to four decimals.
  expect_reference(ours, theirs, reference = by_spells, covers = "summary.dynet_collapsed()", quantity = "binary",
                   tolerance = 5e-5, key = "property")
})

test_that("activity counts and durations of the collapsed network equal networkDynamic::network.collapse()", {
  skip_without_reference(c("networkDynamic", "network"))
  vertices <- sort(unique(c(spells$from, spells$to)))
  collapsed <- networkDynamic::network.collapse(ref_network_dynamic(spells), onset = 0, terminus = max(spells$end),
                                                rm.time.info = FALSE)
  arcs <- as.data.frame(collapsed, unit = "edges")
  theirs <- data.frame(pair = paste(arcs$.tail, arcs$.head), activity.count = arcs$activity.count,
                       activity.duration = arcs$activity.duration)
  ours <- transform(as.data.frame(collapse_network(network)), pair = paste(from, to))
  expect_reference(ours, theirs, reference = "networkDynamic", covers = c("collapse_network()",
                                                                           "as.data.frame.dynet_collapsed()"),
                   quantity = "merged spells per pair", tolerance = 1e-10, key = "pair")
})

test_that("five ways spells of one pair overlap: activity counts and durations equal network.collapse()", {
  skip_without_reference(c("networkDynamic", "network"))
  cases <- list(overlap = data.frame(from = "A", to = "B", start = c(0, 1), end = c(2, 3)),
                abut = data.frame(from = "A", to = "B", start = c(0, 2), end = c(2, 3)),
                gap = data.frame(from = "A", to = "B", start = c(0, 2.5), end = c(2, 3)),
                nested = data.frame(from = "A", to = "B", start = c(0, 1, 4), end = c(5, 2, 6)),
                point = data.frame(from = "A", to = "B", start = c(0, 3), end = c(2, 3)))
  theirs <- do.call(rbind, Map(\(edges, case) {
    collapsed <- networkDynamic::network.collapse(ref_network_dynamic(edges), onset = 0, terminus = 10,
                                                  rm.time.info = FALSE)
    data.frame(case = case, activity.count = network::get.edge.attribute(collapsed, "activity.count"),
               activity.duration = network::get.edge.attribute(collapsed, "activity.duration"))
  }, cases, names(cases)))
  ours <- do.call(rbind, Map(\(edges, case) {
    cbind(case = case, as.data.frame(collapse_network(dynet(edges), start = 0, end = 10)))
  }, cases, names(cases)))
  expect_reference(ours, theirs, reference = "networkDynamic", covers = "collapse_network()",
                   quantity = "one pair, five overlap patterns", tolerance = 1e-12, key = "case")
})

test_that("the summed durations of all pairs against their union durations differ (negative control)", {
  pair <- pair_of(spells)
  union <- vapply(split(spells, pair), \(one) ref_union_length(one$start, one$end), numeric(1))
  ours <- as.data.frame(durations(network, measure = "total"))
  expect_differs(sum(ours$value), sum(union), reference = by_spells, covers = "durations()",
                 quantity = "summed duration of all pairs against their union duration", tolerance = 1e-6)
})
