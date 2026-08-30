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
    function(p) dyn_centrality(dn, measure = "degree", plot = p),
    function(p) metrics(dn, plot = p),
    function(p) snapshots(dn, plot = p),
    function(p) paths(dn, from = "Ana", plot = p),
    function(p) similarity(dn, step = 5, window = 5, plot = p),
    function(p) pshifts(dn, plot = p),
    function(p) pathways(dn, from = "Ana", plot = p),
    function(p) burstiness(dn, plot = p),
    function(p) durations(dn, plot = p),
    function(p) dyn_reachability(dn, plot = p),
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
