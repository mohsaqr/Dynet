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
