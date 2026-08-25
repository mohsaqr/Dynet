test_that("V04 temporal density integrates eligible directed pair-time", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "C"), start = 0, end = 4
  )
  activity <- data.frame(
    node = c("A", "B", "C"), start = c(0, 0, 2), end = c(4, 2, 4)
  )
  directed <- quiet_dynet(edges, vertex_spells = activity,
                          observation_start = 0, observation_end = 4)
  undirected <- quiet_dynet(edges, directed = FALSE, vertex_spells = activity,
                            observation_start = 0, observation_end = 4)
  expect_equal(Dynet:::.temporal_density(directed), 1 / 2)
  expect_equal(Dynet:::.temporal_density(undirected), 1)
  summary_value <- as.numeric(subset(
    summary(directed), property == "temporal density"
  )$value)
  expect_equal(summary_value, .5)
})

test_that("V04 induces occupied edges on exact eligible endpoints", {
  edge <- data.frame(from = "A", to = "B", start = 0, end = 4)
  activity <- data.frame(
    node = c("A", "B", "C"), start = c(0, 2, 0), end = c(4, 4, 4)
  )
  dn <- quiet_dynet(edge, nodes = data.frame(name = c("A", "B", "C")),
                    vertex_spells = activity,
                    observation_start = 0, observation_end = 4)
  # [0,2): eligible A,C, no edge; [2,4): eligible A,B,C, one of six arcs.
  expect_equal(Dynet:::.temporal_density(dn), 2 / (2 * 2 + 6 * 2))
})

test_that("V04 zero eligible risk is undefined and zero occupancy is zero", {
  edge <- data.frame(from = "A", to = "B", start = 0, end = 2)
  singleton <- quiet_dynet(edge, vertex_spells = data.frame(
    node = c("A", "B"), start = c(0, 2), end = c(2, 2)
  ), observation_start = 0, observation_end = 2)
  expect_true(is.na(Dynet:::.temporal_density(singleton)))

  point <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 1),
    vertex_spells = data.frame(node = c("A", "B"), start = 0, end = 2),
    observation_start = 0, observation_end = 2
  )
  expect_equal(Dynet:::.temporal_density(point), 0)
})

test_that("V04 observation gaps and collapse use one eligible calendar union", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "B"), start = c(0, 4), end = c(2, 6),
    wave = c("s1", "s2")
  )
  activity <- data.frame(
    node = c("A", "B", "A", "B"), start = c(0, 0, 4, 4),
    end = c(2, 2, 6, 6), session = c("s1", "s2", "s2", "s1")
  )
  dn <- quiet_dynet(
    edges, session = "wave", vertex_spells = activity,
    observation_spells = data.frame(start = c(0, 4), end = c(2, 6))
  )
  expect_equal(Dynet:::.temporal_density(dn), 1 / 2)
})

test_that("V04 retains all-static density and representation invariants", {
  edges <- data.frame(
    from = c("A", "A", "A"), to = c("B", "B", "A"),
    start = c(0, 1, 0), end = c(2, 3, 3), weight = c(1, 9, 7)
  )
  base <- quiet_dynet(edges, weight = "weight", loops = TRUE,
                      observation_start = 0, observation_end = 3)
  duplicate <- quiet_dynet(rbind(edges, edges[1, ]), weight = "weight",
                           loops = TRUE, observation_start = 0,
                           observation_end = 3)
  expect_equal(Dynet:::.temporal_density(base), 1 / 2)
  expect_equal(Dynet:::.temporal_density(duplicate),
               Dynet:::.temporal_density(base))
})

test_that("V04 exact ledger reconciles a rich changing population", {
  edges <- data.frame(
    from = c("A", "B", "A", "C", "D", "B"),
    to = c("B", "A", "C", "D", "A", "C"),
    start = c(0, 3, 0, 1, 0, 0), end = c(6, 5, 10, 9, 10, 10)
  )
  activity <- data.frame(
    node = c("B", "C"), start = c(0, 2), end = c(4, 8)
  )
  directed <- quiet_dynet(edges, vertex_spells = activity,
                          observation_start = 0, observation_end = 10)
  ledger <- Dynet:::.temporal_risk_ledger(directed)
  expect_equal(unname(ledger), c(64, 29, 35))
  expect_equal(Dynet:::.temporal_density(directed), 29 / 64)

  undirected <- quiet_dynet(edges, directed = FALSE, vertex_spells = activity,
                            observation_start = 0, observation_end = 10)
  expect_equal(unname(Dynet:::.temporal_risk_ledger(undirected)), c(32, 28, 4))
  expect_equal(Dynet:::.temporal_density(undirected), 7 / 8)
})

test_that("V04 point-only coeligibility has zero exposure", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 1, end = 1),
    vertex_spells = data.frame(node = c("A", "B"), start = 1, end = 1),
    observation_start = 0, observation_end = 2
  )
  expect_identical(Dynet:::.temporal_risk_ledger(dn),
                   c(risk = 0, occupied = 0, empty = 0))
  expect_true(is.na(Dynet:::.temporal_density(dn)))
})

test_that("V04 is translation, scale, and censor invariant", {
  edges <- data.frame(
    from = c("A", "A"), to = c("B", "C"), start = c(0, 2), end = c(4, 6),
    onset_censored = c(TRUE, FALSE), terminus_censored = c(FALSE, TRUE)
  )
  activity <- data.frame(
    node = c("A", "B", "C"), start = c(0, 1, 3), end = c(6, 5, 6),
    onset_censored = c(TRUE, FALSE, FALSE),
    terminus_censored = c(FALSE, TRUE, FALSE)
  )
  make <- function(multiplier = 1, offset = 0, censor = TRUE) {
    e <- edges
    v <- activity
    e[c("start", "end")] <- e[c("start", "end")] * multiplier + offset
    v[c("start", "end")] <- v[c("start", "end")] * multiplier + offset
    if (!censor) {
      e <- e[setdiff(names(e), c("onset_censored", "terminus_censored"))]
      v <- v[setdiff(names(v), c("onset_censored", "terminus_censored"))]
    }
    quiet_dynet(e, vertex_spells = v, observation_start = offset,
                observation_end = 6 * multiplier + offset)
  }
  values <- vapply(list(make(), make(3, 10), make(censor = FALSE)),
                   Dynet:::.temporal_density, numeric(1L))
  expect_equal(values, rep(values[[1L]], 3L))
})
