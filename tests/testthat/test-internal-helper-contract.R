test_that(".resolve_modes reads an untouched default as `all`", {
  expect_identical(.resolve_modes(c("all", "out", "in")), "all")
  expect_identical(.resolve_modes("in"), "in")
  expect_identical(.resolve_modes(c("out", "in")), c("out", "in"))
  expect_error(.resolve_modes("sideways"), class = "dynet_bad_input")
})

test_that(".measure_modes gives one row per output column", {
  one <- .measure_modes("degree", c("in", "out"), TRUE)
  expect_identical(one$measure, c("degree", "degree"))
  expect_identical(one$mode, c("in", "out"))
  expect_identical(one$label, c("degree_in", "degree_out"))

  # A direction-blind measure is not computed once per direction.
  two <- .measure_modes(c("degree", "betweenness"), c("all", "in"), TRUE)
  expect_identical(sum(two$measure == "betweenness"), 1L)

  # An undirected network drops directions entirely.
  undirected <- .measure_modes("degree", c("in", "out"), FALSE)
  expect_identical(nrow(undirected), 1L)
})

test_that(".node_names pulls the vertex column out of a node table", {
  expect_identical(
    .node_names(data.frame(node = c("A", "B"), value = 1:2), "nodes"),
    c("A", "B")
  )
})

test_that(".network_span reports the observed start and end", {
  span <- .network_span(dynet(school_contacts))
  expect_identical(names(span), c("start", "end"))
  expect_true(span[["end"]] > span[["start"]])
})

test_that(".over_bins returns one tidy row per bin and measure", {
  dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
  out <- .over_bins(dn, "bounded", function(enc, active, bin) {
    c(active_edges = sum(active))
  })
  expect_identical(names(out), c("session", "time", "measure", "value"))
  expect_true(all(out$measure == "active_edges"))
  expect_true(all(out$value == 1))
})

test_that(".annotate_nodes adds the requested measure to the node table", {
  dn <- dynet(school_contacts)
  out <- .annotate_nodes(dn, as.data.frame(dn, what = "nodes"),
                         "degree", "bounded", NULL, NULL)
  expect_true("degree" %in% names(out))
  expect_identical(nrow(out), nrow(as.data.frame(dn, what = "nodes")))
  expect_true(is.numeric(out$degree))
})

test_that(".select_nodes evaluates a predicate against node measures", {
  dn <- dynet(school_contacts)
  chosen <- .select_nodes(dn, quote(degree > 16), parent.frame())
  expect_true(is.character(chosen))
  measured <- .annotate_nodes(dn, as.data.frame(dn, what = "nodes"),
                              "degree", "bounded", NULL, NULL)
  expect_setequal(chosen, measured$name[measured$degree > 16])
})

test_that(".reverse_time flips an encoding and flags itself as reversed", {
  enc <- .encode(dynet(school_contacts))
  rev <- .reverse_time(enc)
  expect_true(isTRUE(rev$reversed))
  expect_identical(rev$names, enc$names)
  expect_identical(rev$n, enc$n)
})

test_that(".finalize_optimal_search returns one entry per vertex", {
  enc <- .encode(dynet(school_contacts))
  raw <- .optimal_path_search(enc, 1L, 0, upper = 10)
  fin <- .finalize_optimal_search(raw)
  expect_identical(length(fin$arrival), enc$n)
  expect_identical(length(fin$attained), enc$n)
  expect_true(is.logical(fin$attained))
  # A vertex that was never reached has no arrival time and no hop count.
  expect_true(all(is.infinite(fin$arrival[!fin$attained])))
  expect_true(all(is.na(fin$n_hops[!fin$attained])))
})

test_that("the internal %||% matches the base operator it stands in for", {
  # Dynet defines `%||%` so the dependency floor can stay at 4.1 rather than
  # the 4.4 base's own version would force. That is only safe while the two
  # behave identically, so pin it against base wherever base has one.
  skip_if_not(getRversion() >= "4.4.0", "base %||% needs R 4.4")
  ours <- getFromNamespace("%||%", "Dynet")
  cases <- list(
    list(NULL, 1), list(2, 1), list(NA, 1), list(list(), 1),
    list(character(0), 1), list(FALSE, 1), list(NULL, NULL),
    list(NULL, NA), list(0, NULL)
  )
  lapply(cases, function(case) {
    expect_identical(
      ours(case[[1]], case[[2]]),
      base::`%||%`(case[[1]], case[[2]])
    )
  })
})

test_that(".grid_bins keeps a late event without inventing a trailing bin", {
  gb <- getFromNamespace(".grid_bins", "Dynet")
  # Exact multiples, including ones the ratio cannot represent exactly:
  # 0.3 / 0.1 is 2.9999999999999996, which must still be three bins.
  expect_identical(gb(3, 1), 3L)
  expect_identical(gb(0.3, 0.1), 3L)
  expect_identical(gb(c(3, 0.3, 7), c(1, 0.1, 2)), c(3L, 3L, 4L))
  # A span genuinely above a multiple needs the extra bin, however slightly.
  # Regression: `ceiling(span / step - 1e-9)` put a fixed tolerance on the bin
  # COUNT, so anything within 1e-9 * step of a multiple was rounded away.
  expect_identical(gb(1 + 5e-10, 1), 2L)
  expect_identical(gb(1 + 1e-9, 1), 2L)
  expect_identical(gb(0, 1), 1L)
})

test_that("an event just past a bin boundary is not silently discarded", {
  # The user-visible consequence of the bug above: the second contact fell
  # outside the only bin built, and vanished from every derived measurement.
  lapply(c(5e-10, 1e-9, 2e-9, 1e-6), function(offset) {
    dn <- quiet_dynet(
      data.frame(from = c("A", "C"), to = c("B", "D"), time = c(0, 1 + offset)),
      format = "contact", interval = 1
    )
    seen <- as.data.frame(snapshots(dn))
    expect_identical(nrow(seen), 2L)
    expect_identical(length(unique(seen$time)), 2L)
  })
})
