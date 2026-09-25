# The contract every verb in the package must honour: a tidy data frame,
# vertex names not indices, and no nested lists.

all_verbs <- function(dn) {
  list(
    centrality  = centrality_series(dn, measure = c("degree", "closeness")),
    temporal    = path_centrality(dn, measure = "closeness"),
    metrics     = metrics(dn, measure = c("density", "reciprocity")),
    events      = events(dn),
    durations   = durations(dn),
    burstiness  = burstiness(dn),
    reachability = reachability(dn)
  )
}

test_that("every measurement verb returns a tidy data frame, never a matrix or list", {
  dn <- quiet_dynet(random_edges())
  for (nm in names(all_verbs(dn))) {
    res <- all_verbs(dn)[[nm]]
    expect_s3_class(res, "dynet_metric", exact = FALSE)
    expect_s3_class(res, "data.frame")
    expect_true(is.data.frame(as.data.frame(res)), info = nm)
    expect_true(all(c("measure", "value") %in% names(res)), info = nm)
    expect_type(res$value, "double")
    expect_false(any(vapply(as.data.frame(res), is.list, logical(1L))), info = nm)
  }
})

test_that("results identify vertices by name, never by index", {
  dn <- quiet_dynet(random_edges())
  named <- c("centrality", "temporal", "burstiness", "reachability")
  verbs <- all_verbs(dn)
  for (nm in named) {
    expect_type(verbs[[nm]]$node, "character")
    expect_true(all(verbs[[nm]]$node %in% as.data.frame(dn, what = "nodes")$name))
  }
  expect_type(verbs$durations$from, "character")
  paths <- paths(dn, from = "v1")
  steps <- as.data.frame(paths, what = "steps")
  expect_type(paths$node, "character")
  expect_false("previous" %in% names(paths))
  expect_type(steps$endpoint, "character")
  expect_type(steps$node, "character")
  expect_type(steps$path_session, "character")
  expect_false(any(vapply(steps, is.list, logical(1L))))
})

test_that("sessions add rows rather than nesting the result in a list", {
  e <- random_edges()
  e$session <- rep(c("term1", "term2"), length.out = nrow(e))
  dn <- quiet_dynet(e, session = "session")

  sep <- centrality_series(dn, measure = "degree", sessions = "separate")
  expect_s3_class(sep, "data.frame")
  expect_false(is.list(sep$value) || inherits(sep, "list"))
  expect_setequal(unique(sep$session), c("term1", "term2"))

  pooled <- centrality_series(dn, measure = "degree", sessions = "collapse")
  expect_false("session" %in% names(pooled))
})

test_that("as.data.frame gives long and wide layouts without hand-reshaping", {
  dn <- quiet_dynet(random_edges())
  deg <- centrality_series(dn, measure = "degree")
  long <- as.data.frame(deg)
  wide <- as.data.frame(deg, layout = "wide")
  expect_identical(class(long), "data.frame")
  expect_identical(class(wide), "data.frame")
  expect_equal(nrow(wide), length(unique(long$node)))
  expect_equal(nrow(long), length(unique(long$node)) * length(unique(long$time)))
})

test_that("summary collapses time into a tidy table with a peak", {
  dn <- quiet_dynet(random_edges())
  s <- summary(centrality_series(dn, measure = "degree"))
  expect_s3_class(s, "data.frame")
  expect_true(all(c("node", "measure", "n", "mean", "sd", "min", "max",
                    "peak_time") %in% names(s)))
  expect_equal(nrow(s), length(unique(centrality_series(dn, measure = "degree")$node)))

  by_time <- summary(centrality_series(dn, measure = "degree"), by = "time")
  expect_true("time" %in% names(by_time))
})

test_that("asking for several measures stacks them in one frame", {
  dn <- quiet_dynet(random_edges())
  two <- centrality_series(dn, measure = c("degree", "betweenness"))
  expect_setequal(unique(two$measure), c("degree", "betweenness"))
  one <- centrality_series(dn, measure = "degree")
  expect_equal(nrow(two), 2L * nrow(one))
})

test_that("unknown measures and wrong directedness raise classed conditions", {
  dn <- quiet_dynet(random_edges())
  expect_error(centrality_series(dn, measure = "nonsense"),
               class = "dynet_unknown_measure")
  expect_error(metrics(dn, measure = "nonsense"),
               class = "dynet_unknown_measure")
  expect_error(paths(dn, from = "not_a_vertex"),
               class = "dynet_unknown_vertex")
  expect_error(centrality_series(dn, sessions = "separate"),
               class = "dynet_no_sessions")
  expect_error(mixing(dn, attribute = "role"),
               class = "dynet_unknown_attribute")

  und <- quiet_dynet(random_edges(), directed = FALSE)
  expect_error(centrality_series(und, measure = "hub"),
               class = "dynet_needs_directed")
  expect_error(metrics(und, measure = "reciprocity"),
               class = "dynet_needs_directed")
})

test_that("summary n counts the values the statistics used", {
  # A vertex outside its declared activity spell contributes a missing value,
  # not a measured zero. Reporting the row count as `n` advertised
  # observations that no mean or sd was ever computed from.
  edges <- data.frame(from = c("A", "B"), to = c("B", "C"),
                      start = c(0, 5), end = c(1, 6))
  dn <- dynet(edges, vertex_spells = data.frame(node = "A", start = 3,
                                                end = 6))
  measured <- centrality_series(dn, measure = "degree")
  long <- as.data.frame(measured)
  stats <- summary(measured)

  rows <- sum(long$node == "A")
  present <- sum(!is.na(long$value[long$node == "A"]))
  expect_lt(present, rows)
  expect_identical(stats$n[stats$node == "A"], present)

  # A fully active vertex is unaffected: every row is a measured value.
  expect_identical(stats$n[stats$node == "B"],
                   sum(!is.na(long$value[long$node == "B"])))
  expect_identical(stats$n[stats$node == "B"], sum(long$node == "B"))
})
