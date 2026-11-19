# burstiness() and gaps(): the rhythm of each vertex's events. For every pupil of the bundled school_contacts,
# the onsets of its incident spells are sorted; the gaps are their differences. Burstiness is
# B = (sigma - mu) / (sigma + mu) with the population standard deviation of the gaps (Goh and Barabasi, 2008),
# memory the Pearson correlation of consecutive gaps.

spells <- school_contacts
network <- dynet(school_contacts)
incident <- data.frame(node = c(spells$from, spells$to), time = c(spells$start, spells$start))
onsets <- lapply(split(incident$time, incident$node), sort)

test_that("events, mean gap, burstiness and memory equal the formulas on the sorted onsets", {
  rhythm <- vapply(onsets, \(times) {
    gap <- diff(times)
    mu <- mean(gap)
    sigma <- sqrt(mean((gap - mu)^2))
    c(events = length(times), mean_gap = mu, burstiness = (sigma - mu) / (sigma + mu),
      memory = stats::cor(utils::head(gap, -1L), utils::tail(gap, -1L)))
  }, numeric(4))
  theirs <- data.frame(node = colnames(rhythm)[col(rhythm)], measure = rownames(rhythm)[row(rhythm)],
                       value = as.vector(rhythm))
  ours <- as.data.frame(burstiness(network, measure = c("events", "mean_gap", "burstiness", "memory")))
  # A mean, a standard deviation and a correlation of about thirty gaps.
  expect_reference(ours, theirs, reference = "independent: Goh and Barabasi (2008) formulas on sorted onsets, base R",
                   covers = c("burstiness()", "as.data.frame.dynet_metric()"), quantity = "per pupil", tolerance = 1e-10,
                   key = c("node", "measure"))
})

test_that("each vertex's gaps are the differences of its sorted onsets", {
  theirs <- do.call(rbind, Map(\(times, node) {
    data.frame(node = node, index = seq_len(length(times) - 1L), time = utils::tail(times, -1L), gap = diff(times))
  }, onsets, names(onsets)))
  ours <- stats::setNames(subset(as.data.frame(gaps(network)), select = c(node, index, time, value)),
                          c("node", "index", "time", "gap"))
  # Differences of two-decimal times.
  expect_reference(ours, theirs, reference = "independent: differences of sorted onsets, base R", covers = "gaps()",
                   quantity = "gap per vertex", tolerance = 1e-10, key = c("node", "index"))
})

test_that("summary() of the gaps gives their number, mean, standard deviation and range", {
  per_node <- lapply(onsets, diff)
  theirs <- data.frame(node = names(per_node), n = lengths(per_node), mean = vapply(per_node, mean, numeric(1)),
                       sd = vapply(per_node, stats::sd, numeric(1)), min = vapply(per_node, min, numeric(1)),
                       max = vapply(per_node, max, numeric(1)))
  expect_reference(as.data.frame(summary(gaps(network))), theirs, reference = "independent: differences of sorted onsets, base R",
                   covers = "summary.dynet_metric()", quantity = "gaps per vertex, summarised", tolerance = 1e-10,
                   key = "node")
})

test_that("burstiness with the sample standard deviation differs (negative control)", {
  sample_b <- vapply(onsets, \(times) {
    gap <- diff(times)
    (stats::sd(gap) - mean(gap)) / (stats::sd(gap) + mean(gap))
  }, numeric(1))
  ours <- as.data.frame(burstiness(network, measure = "burstiness"))
  expect_differs(ours, data.frame(node = names(sample_b), measure = "burstiness", value = unname(sample_b)),
                 reference = "independent: Goh and Barabasi (2008) formulas on sorted onsets, base R",
                 covers = "burstiness()", quantity = "burstiness, sample standard deviation", tolerance = 1e-6,
                 key = c("node", "measure"))
})
