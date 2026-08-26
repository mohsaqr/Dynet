test_that("snapshot degree on a triangle matches the value worked out by hand", {
  # A->B over [1,4), B->C over [2,5), C->A over [3,6). In the bin [3,4) all
  # three edges overlap, so every vertex has one edge in and one out.
  dn <- quiet_dynet(triangle_edges())
  deg <- as.data.frame(dyn_centrality(dn, measure = "degree"))
  at3 <- deg[deg$time == 3, , drop = FALSE]
  expect_equal(at3$value[order(at3$node)], c(2, 2, 2))
})

test_that("degree counts self-loops with igraph's stub convention", {
  sp <- data.frame(from = c("A", "A"), to = c("A", "B"),
                   start = 0, end = 1, stringsAsFactors = FALSE)
  dn <- quiet_dynet(sp, loops = TRUE, interval = 1)
  expected <- list(all = c(A = 3, B = 1),
                   out = c(A = 2, B = 0),
                   `in` = c(A = 1, B = 1))
  for (md in names(expected)) {
    got <- as.data.frame(dyn_centrality(dn, measure = "degree", mode = md))
    got <- stats::setNames(got$value, got$node)
    expect_equal(got[names(expected[[md]])], expected[[md]])
  }
})

test_that("temporal centrality on a chain matches hand calculation", {
  dn <- quiet_dynet(chain_edges())
  got <- as.data.frame(dyn_centrality(
    dn, measure = c("reach", "closeness", "betweenness"), scope = "temporal"))
  take <- function(measure)
    got$value[match(paste(c("A", "B", "C", "D", "E"), measure),
                    paste(got$node, got$measure))]
  expect_equal(take("reach"), c(1, 3 / 4, 2 / 4, 1 / 4, 0))
  # A reaches B at the window origin, and zero-latency reachable endpoints
  # remain in the inverse-mean-latency numerator.
  expect_equal(take("closeness"), c(2 / 3, 1 / 2, 2 / 5, 1 / 3, 0))
  expect_equal(take("betweenness"), c(0, 3, 4, 3, 0))
})

test_that("graph measures on the same triangle match hand calculation", {
  dn <- quiet_dynet(triangle_edges())
  m <- as.data.frame(metrics(
    dn, measure = c("density", "reciprocity", "transitivity", "edges")))
  at3 <- m[m$time == 3, , drop = FALSE]
  # three of six possible directed edges; no edge is reciprocated; the three
  # two-paths are all open because the closing edge runs the other way.
  expect_equal(at3$value[at3$measure == "density"], 0.5)
  expect_equal(at3$value[at3$measure == "reciprocity"], 0)
  expect_equal(at3$value[at3$measure == "transitivity"], 0)
  expect_equal(at3$value[at3$measure == "edges"], 3)
})

test_that("a window keeps an event that point sampling misses", {
  # The C-D spell opens and closes strictly inside the second bin, touching
  # neither of its edges, so a point sample at the bin's left edge misses it.
  brief <- data.frame(from = c("A", "C", "A"), to = c("B", "D", "B"),
                      start = c(0, 1.3, 3), end = c(0.5, 1.6, 3.5),
                      stringsAsFactors = FALSE)
  dn <- quiet_dynet(brief, interval = 1)
  win <- as.data.frame(metrics(dn, measure = "edges"))
  ins <- as.data.frame(metrics(dn, measure = "edges", window = 0))
  expect_equal(win$value[win$time == 1], 1)
  expect_equal(ins$value[ins$time == 1], 0)
})

test_that("density stays inside the unit interval and degrees sum to twice the edges", {
  dn <- quiet_dynet(random_edges(seed = 21L))
  dens <- metrics(dn, measure = "density")
  expect_true(all(dens$value >= 0 & dens$value <= 1))

  deg <- as.data.frame(dyn_centrality(dn, measure = "degree"))
  edges <- as.data.frame(metrics(dn, measure = "edges"))
  per_time <- tapply(deg$value, deg$time, sum)
  expect_equal(as.numeric(per_time),
               2 * edges$value[match(names(per_time), edges$time)])
})

test_that("censuses over time always account for every dyad and triple", {
  dn <- quiet_dynet(random_edges(n_v = 10L, seed = 22L))
  n <- nrow(as.data.frame(dn, what = "nodes"))
  dyads <- as.data.frame(metrics(dn, measure = c("mutual", "asymmetric", "null")))
  expect_true(all(tapply(dyads$value, dyads$time, sum) == choose(n, 2)))

  triads <- as.data.frame(metrics(dn, measure = "triads"))
  expect_true(all(tapply(triads$value, triads$time, sum) == choose(n, 3)))
})

test_that("measures are invariant to relabelling the vertices", {
  e <- random_edges(seed = 23L)
  relabel <- c(setNames(paste0("z", 1:12), paste0("v", 1:12)))
  e2 <- e
  e2$from <- unname(relabel[e$from])
  e2$to   <- unname(relabel[e$to])

  a <- as.data.frame(dyn_centrality(quiet_dynet(e), measure = "betweenness"))
  b <- as.data.frame(dyn_centrality(quiet_dynet(e2), measure = "betweenness"))
  a$node <- unname(relabel[a$node])
  key <- function(d) d$value[order(d$time, d$node)]
  expect_equal(key(a), key(b))

  ga <- metrics(quiet_dynet(e), measure = "transitivity")
  gb <- metrics(quiet_dynet(e2), measure = "transitivity")
  expect_equal(ga$value, gb$value)
})

test_that("burstiness is bounded and undefined where it must be", {
  dn <- quiet_dynet(random_edges(seed = 24L))
  b <- as.data.frame(burstiness(dn))
  vals <- b$value[b$measure == "burstiness"]
  expect_true(all(is.na(vals) | (vals >= -1 & vals <= 1)))

  # A vertex with a single event has no gap, so burstiness is not defined.
  sparse <- data.frame(from = c("A", "C"), to = c("B", "D"),
                       start = c(1, 2), end = c(2, 3), stringsAsFactors = FALSE)
  sb <- as.data.frame(burstiness(quiet_dynet(sparse)))
  expect_true(all(is.na(sb$value[sb$measure == "burstiness"])))
})

test_that("a perfectly regular sequence is minimally bursty", {
  metronome <- data.frame(from = rep("A", 12), to = rep("B", 12),
                          start = seq(0, 22, by = 2),
                          end = seq(0, 22, by = 2) + 0.5,
                          stringsAsFactors = FALSE)
  b <- as.data.frame(burstiness(quiet_dynet(metronome)))
  expect_equal(b$value[b$node == "A" & b$measure == "burstiness"], -1)
})

test_that("durations recover the spells that went in", {
  dn <- quiet_dynet(triangle_edges())
  d <- as.data.frame(durations(dn, measure = c("events", "total", "mean")))
  expect_equal(sum(d$value[d$measure == "events"]), 3)
  expect_equal(sum(d$value[d$measure == "total"]), sum(c(3, 3, 3)))
  expect_true(all(d$value[d$measure == "mean"] == 3))
})

test_that("formation and dissolution each account for every spell once", {
  dn <- quiet_dynet(random_edges(seed = 25L))
  ev <- as.data.frame(events(dn, measure = c("formation", "dissolution")))
  n_spells <- nrow(as.data.frame(dn))
  expect_equal(sum(ev$value[ev$measure == "formation"]), n_spells)
  expect_lte(sum(ev$value[ev$measure == "dissolution"]), n_spells)
})

test_that("mixing counts every active edge exactly once", {
  dn <- quiet_dynet(forum_posts, thread = "thread", nodes = forum_people)
  mix <- as.data.frame(mixing(dn, attribute = "role"))
  edges <- as.data.frame(metrics(dn, measure = "edges"))
  by_time <- tapply(mix$value, mix$time, sum)
  expect_equal(as.numeric(by_time),
               edges$value[match(as.numeric(names(by_time)), edges$time)])
})

test_that("snapshots agree with the edge counts the metric verbs report", {
  dn <- quiet_dynet(random_edges(seed = 26L))
  snaps <- snapshots(dn)
  edges <- as.data.frame(metrics(dn, measure = "edges"))
  counted <- tapply(rep(1, nrow(snaps)), snaps$time, sum)
  expect_equal(as.numeric(counted),
               edges$value[match(as.numeric(names(counted)), edges$time)])
})
