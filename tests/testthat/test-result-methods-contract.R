# Every result class should answer print, summary, plot and as.data.frame.
# These were the classes that fell through to a base method: dynet_pshifts to
# data.frame (whose plot() draws a scatter matrix of shift labels) and
# dynet_collapsed_list to list (whose as.data.frame flattened the sessions
# sideways into ONE row of s1.from, s2.from, ... columns).

test_that("pshifts answers all four generics itself", {
  dn <- quiet_dynet(school_contacts)
  shifts <- pshifts(dn)

  for (generic in c("print", "summary", "plot", "as.data.frame")) {
    expect_false(
      is.null(getS3method(generic, "dynet_pshifts", optional = TRUE)),
      info = generic
    )
  }

  flat <- as.data.frame(shifts)
  expect_identical(class(flat), "data.frame")
  expect_identical(names(flat), c("shift", "family", "count"))
  expect_identical(nrow(flat), 13L)

  # Families partition the shifts, so their counts must total the whole.
  digest <- summary(shifts)
  expect_identical(sum(digest$count), sum(flat$count))
  expect_equal(sum(digest$share), 1)
  expect_setequal(digest$family, unique(flat$family))
  expect_identical(digest$count, sort(digest$count, decreasing = TRUE))

  expect_s3_class(plot(shifts), "ggplot")
})

test_that("a session-separated collapse stacks into one tidy frame", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "A", "B"), to = c("B", "B", "C"),
    start = c(0, 0, 1), end = c(2, 3, 4),
    session = c("s1", "s2", "s1")
  ), session = "session")
  split <- collapse_network(dn, sessions = "separate")

  stacked <- as.data.frame(split)
  expect_identical(class(stacked), "data.frame")
  expect_identical(names(stacked)[[1L]], "session")
  expect_setequal(stacked$session, c("s1", "s2"))
  # One row per pair per session, never one wide row for everything.
  expect_identical(nrow(stacked), 3L)

  # A session is reachable by ARGUMENT rather than by reaching in with `$`.
  one <- as.data.frame(split, session = "s1")
  expect_identical(nrow(one), 2L)
  expect_false("session" %in% names(one))
  expect_identical(one, as.data.frame(split[["s1"]]))

  digest <- summary(split)
  expect_identical(digest$session, c("s1", "s2"))
  expect_identical(digest$pairs, c(2L, 1L))
  expect_identical(sum(digest$pairs), nrow(stacked))

  expect_error(as.data.frame(split, session = "nope"),
               class = "dynet_unknown_session")
})

test_that("similarity, projection and trajectories summarise their own shape", {
  dn <- quiet_dynet(school_contacts)

  # Similarity: the nearest bin must be a real OTHER bin, never itself.
  sim <- summary(similarity(dn, step = 5, window = 5))
  expect_true(all(sim$nearest != sim$time))
  expect_true(all(sim$min <= sim$mean & sim$mean <= sim$max))

  # Projection: one row per slice, and the last slice has nowhere to carry a
  # vertex forward to, so it emits no identity arcs.
  proj <- summary(projection(dn, step = 5, window = 5))
  expect_identical(nrow(proj), 5L)
  expect_identical(proj$identity_arcs[[5L]], 0L)
  expect_true(all(proj$identity_arcs[-5L] > 0L))

  # Trajectories: depth zero is the queried vertex alone, with no parent to be
  # a branching fraction of.
  traj <- summary(path_trajectories(paths(dn, from = "Ana")))
  expect_identical(traj$depth[[1L]], 0L)
  expect_identical(traj$branches[[1L]], 1L)
  expect_true(is.na(traj$mean_branching[[1L]]))
  expect_true(all(traj$mean_branching[-1L] > 0 &
                    traj$mean_branching[-1L] <= 1))
})

test_that("plot = TRUE draws without changing what a verb returns", {
  dn <- quiet_dynet(school_contacts)
  # The contract is base R's hist(): drawing is a side effect, the tidy result
  # still comes back. A verb whose return TYPE changed with an argument would
  # break every downstream caller.
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  verbs <- list(
    function(p) centrality_series(dn, measure = "degree", plot = p),
    function(p) metrics(dn, plot = p),
    function(p) snapshots(dn, plot = p),
    function(p) paths(dn, from = "Ana", plot = p),
    function(p) similarity(dn, step = 5, window = 5, plot = p),
    function(p) pshifts(dn, plot = p),
    function(p) pathways(dn, from = "Ana", plot = p),
    function(p) burstiness(dn, plot = p),
    function(p) durations(dn, plot = p),
    function(p) reachability(dn, plot = p),
    function(p) events(dn, plot = p)
  )
  lapply(verbs, function(call_verb) {
    quiet <- call_verb(FALSE)
    drawn <- call_verb(TRUE)
    expect_identical(as.data.frame(drawn), as.data.frame(quiet))
    expect_identical(class(drawn), class(quiet))
  })

  # Every verb rejects a non-logical by class rather than drawing something.
  expect_error(metrics(dn, plot = "yes"), class = "dynet_bad_input")
  expect_error(paths(dn, from = "Ana", plot = NA), class = "dynet_bad_input")
  expect_error(pathways(dn, from = "Ana", plot = c(TRUE, TRUE)),
               class = "dynet_bad_input")
})

test_that("`top` counts vertices whose series has an undefined bin", {
  # A vertex outside its activity spell, and any bin the grid never defined,
  # contribute a missing value rather than a measured zero. Ranking with a
  # bare `sort()` dropped those vertices silently: `top = 5` returned four,
  # and once every vertex had one undefined bin it returned none at all.
  spells <- data.frame(
    from = c("A", "B", "C", "D", "A"), to = c("B", "C", "D", "A", "C"),
    start = c(0, 1, 2, 3, 1), end = c(1, 2, 3, 4, 2)
  )
  activity <- data.frame(
    node = c("A", "B", "C", "D", "E"),
    start = c(0, 0, 0, 0, 9), end = c(5, 5, 5, 5, 10)
  )
  dn <- quiet_dynet(spells, vertex_spells = activity,
                    observation_start = 0, observation_end = 5)
  degree <- centrality_series(dn, measure = "degree", start = 0, end = 5,
                              step = 1, window = 1)
  measured <- as.data.frame(degree)
  expect_true(anyNA(measured$value))

  # The invariant: `top = k` yields exactly min(k, number of vertices).
  n_nodes <- length(unique(measured$node))
  counts <- vapply(seq_len(n_nodes + 2L), function(k) {
    kept <- as.data.frame(degree, top = k)
    length(unique(kept$node))
  }, integer(1L))
  expect_identical(counts, pmin(seq_len(n_nodes + 2L), n_nodes))

  # A vertex with nothing defined stays in the ordering, last, rather than
  # vanishing from it.
  ranked <- as.data.frame(degree, top = n_nodes)
  expect_identical(unique(ranked$node)[[n_nodes]], "E")
})

test_that("`top` selects the same vertices for the table and the plot", {
  dn <- quiet_dynet(school_contacts)
  degree <- centrality_series(dn, measure = "degree", step = 4, window = 4)
  kept <- as.data.frame(degree, top = 5)
  drawn <- plot(degree, top = 5)
  drawn_nodes <- sort(unique(drawn$data$node))
  expect_identical(sort(unique(kept$node)), drawn_nodes)
  expect_length(drawn_nodes, 5L)
})

test_that("both directed-only guards refuse the same measures", {
  # The proximity panel validates `measure` itself rather than going through
  # centrality_series(), so the two lists must not drift apart. Its copy used to
  # omit "prestige", which then ran on a symmetric adjacency and returned a
  # directed quantity without complaint.
  undirected <- quiet_dynet(school_contacts, directed = FALSE)
  directed_only <- Dynet:::.directed_only_measures
  expect_gt(length(directed_only), 0L)

  # `indegree` and `outdegree` also raise a deprecation warning on the way
  # out; muffle that one condition so the error class is what is asserted.
  refuses <- function(call_it) {
    withCallingHandlers(
      expect_error(call_it(), class = "dynet_needs_directed"),
      dynet_deprecated = function(w) invokeRestart("muffleWarning")
    )
  }
  pdf(tempfile())
  on.exit(grDevices::dev.off(), add = TRUE)
  lapply(directed_only, function(measure) {
    refuses(function() centrality_series(undirected, measure = measure))
    refuses(function() plot(undirected, type = "proximity", measure = measure))
  })
})
