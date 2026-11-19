# events(): formation and dissolution of ties in windows of 7 on the bundled school_contacts spells, against
# counts taken from the spell list in base R. Formation counts spells beginning in the window, dissolution spells
# ending in it, active spells overlapping it, new pairs the ordered pairs whose first spell begins in it. The last
# window ends where the data end (21.52) and is closed there.

spells <- school_contacts
network <- dynet(school_contacts)
last <- max(spells$end)
onsets <- c(0, 7, 14, 21)

test_that("formation, dissolution, active spells and new pairs in windows of 7 equal counts from the spell list", {
  pair <- paste(spells$from, spells$to)
  first_onset <- tapply(spells$start, pair, min)
  inside <- \(times, lo) {
    hi <- min(lo + 7, last)
    sum(times >= lo & (times < hi | (hi == last & times <= hi)))
  }
  theirs <- do.call(rbind, lapply(onsets, \(lo) {
    data.frame(time = lo, measure = c("formation", "dissolution", "active", "new_pairs"),
               value = c(inside(spells$start, lo), inside(spells$end, lo),
                         sum(spells$start < lo + 7 & spells$end > lo), inside(first_onset, lo)))
  }))
  ours <- as.data.frame(events(network, measure = c("formation", "dissolution", "active", "new_pairs"), step = 7,
                               window = 7))
  expect_reference(ours, theirs, reference = "independent: counts of onsets and termini per window, base R",
                   covers = c("events()", "as.data.frame.dynet_metric()"), quantity = "windows of 7", tolerance = 0,
                   key = c("time", "measure"))
})

test_that("the formation rate equals confirmed formations over integrated inactive pair-time, written out", {
  # Two directed pairs observed over [0, 10]: A->B is up on [2, 4) and [7, 9), B->C on [5, 8). Twelve ordered
  # pairs are at risk while inactive. Formations: A->B at 2 and 7, B->C at 5 (three). Inactive pair-time: every
  # ordered pair over 10 time units (120) less the time each pair is up (2 + 2 + 3 = 7): 113.
  edges <- data.frame(from = c("A", "A", "B"), to = c("B", "B", "C"), start = c(2, 7, 5), end = c(4, 9, 8))
  directed <- dynet(edges, nodes = data.frame(name = c("A", "B", "C", "D")), keep_isolates = TRUE,
                    observation_start = 0, observation_end = 10)
  ours <- as.data.frame(events(directed, measure = "formation_rate", step = 10, window = 10))
  expect_reference(subset(ours, select = c(time, value)), data.frame(time = 0, value = 3 / (12 * 10 - 7)),
                   reference = "independent: formations over inactive ordered-pair time, worked by hand",
                   covers = "events()", quantity = "formation rate", tolerance = 1e-12, key = "time")
})

test_that("formation counts against termini counts differ (negative control)", {
  theirs <- data.frame(time = onsets, measure = "formation",
                       value = vapply(onsets, \(lo) sum(spells$end >= lo & spells$end < lo + 7), numeric(1)))
  ours <- as.data.frame(events(network, measure = "formation", step = 7, window = 7))
  expect_differs(ours, theirs, reference = "independent: counts of onsets and termini per window, base R",
                 covers = "events()", quantity = "formation against termini", tolerance = 0.5, key = c("time", "measure"))
})
