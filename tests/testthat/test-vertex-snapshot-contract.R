v02_edges <- function() data.frame(
  from = c("A", "B", "C", "D", "B"),
  to = c("B", "C", "A", "A", "D"),
  start = 0, end = 5, weight = 2:6
)

v02_vertices <- function() data.frame(
  node = c("A", "A", "B", "C", "C", "E"),
  start = c(0, 4, 1, 0, 3, 2),
  end = c(4, 4, 5, 2, 5, 4)
)

v02_values <- function(result, measure) {
  x <- as.data.frame(result)
  x$value[x$measure == measure]
}

test_that("V02 exact snapshots use the eligible induced population", {
  dn <- quiet_dynet(v02_edges(), weight = "weight", nodes = data.frame(
    name = c("A", "B", "C", "D"), group = c("x", "x", "y", "y")
  ), vertex_spells = v02_vertices())
  wanted <- c("edges", "active_nodes", "isolates", "density", "mutual",
              "asymmetric", "null", "components", "components_strong",
              "largest_component")
  got <- metrics(dn, wanted, start = 0, end = 5, step = 1, window = 0)
  expect_equal(v02_values(got, "edges"), c(2, 5, 3, 5, 5, 0))
  expect_equal(v02_values(got, "active_nodes"), c(3, 4, 3, 4, 4, 0))
  expect_equal(v02_values(got, "isolates"), c(0, 0, 1, 1, 0, 1))
  expect_equal(v02_values(got, "density"), c(1/3, 5/12, 1/4, 1/4, 5/12, 0))
  expect_equal(v02_values(got, "mutual"), rep(0, 6))
  expect_equal(v02_values(got, "asymmetric"), c(2, 5, 3, 5, 5, 0))
  expect_equal(v02_values(got, "null"), c(1, 1, 3, 5, 1, 0))
  expect_equal(v02_values(got, "components"), c(1, 1, 2, 2, 1, 1))
  expect_equal(v02_values(got, "components_strong"), c(3, 1, 2, 2, 1, 1))
  expect_equal(v02_values(got, "largest_component"), c(1, 1, 3/4, 4/5, 1, 1))
  centralization <- metrics(
    dn, c("centralization_degree", "centralization_betweenness",
          "centralization_closeness"),
    start = 0, end = 5, step = 1, window = 0
  )
  expect_equal(v02_values(centralization, "centralization_degree"),
               c(1/2, 1/6, 1/6, 5/24, 1/6, NA))
  expect_equal(v02_values(centralization, "centralization_betweenness"),
               c(0, 7/18, 1/18, 11/48, 7/18, NA))
  expect_equal(v02_values(centralization, "centralization_closeness"),
               c(1/2, 13/60, 2/9, 7/20, 13/60, NA))

  degree <- as.data.frame(dyn_centrality(
    dn, "degree", start = 0, end = 5, step = 1, window = 0
  ))
  actual <- matrix(degree$value, nrow = 5)
  expected <- cbind(
    c(2, NA, 1, 1, NA), c(3, 3, 2, 2, NA),
    c(2, 2, NA, 2, 0), c(3, 3, 2, 2, 0),
    c(3, 3, 2, 2, NA), c(NA, NA, NA, 0, NA)
  )
  expect_equal(actual, expected)
  expect_equal(unique(degree$node), c("A", "B", "C", "D", "E"))
  expect_identical(names(degree), c("time", "node", "measure", "value"))
})

test_that("V02 positive windows use independent any unions before induction", {
  edges <- data.frame(from = "A", to = "B", start = .75, end = 1.25)
  vertices <- data.frame(
    node = c("A", "B"), start = c(0, 1.5), end = c(.5, 2)
  )
  dn <- quiet_dynet(edges, vertex_spells = vertices,
                    observation_start = 0, observation_end = 2)
  wide <- metrics(dn, c("edges", "density"), start = 0, end = 0,
                      step = 1, window = 2)
  expect_equal(v02_values(wide, "edges"), 1)
  expect_equal(v02_values(wide, "density"), 1/2)
  exact <- as.data.frame(snapshots(dn, start = 0, end = 2,
                                       step = .25, window = 0))
  expect_equal(nrow(exact), 0)
})

test_that("V02 genuine terminus points authorize exact edges", {
  edge <- data.frame(from = "A", to = "B", start = 2, end = 2)
  with_point <- quiet_dynet(edge, vertex_spells = data.frame(
    node = c("A", "A", "B"), start = c(0, 2, 2), end = c(2, 2, 4)
  ))
  without_point <- quiet_dynet(edge, vertex_spells = data.frame(
    node = c("A", "B"), start = c(0, 2), end = c(2, 4)
  ))
  expect_equal(nrow(snapshots(with_point, start = 2, end = 2,
                                  step = 1, window = 0)), 1)
  expect_equal(nrow(snapshots(without_point, start = 2, end = 2,
                                  step = 1, window = 0)), 0)
})

test_that("V02 empty and singleton eligible populations retain exact pins", {
  edge <- data.frame(from = "A", to = "B", start = 0, end = 4)
  nodes <- data.frame(name = c("A", "B", "C"))
  empty <- quiet_dynet(edge, nodes = nodes, vertex_spells = data.frame(
    node = c("A", "B", "C"), start = 0, end = 1
  ))
  all_measures <- c(
    "density", "edges", "active_nodes", "isolates", "transitivity",
    "reciprocity", "components", "components_strong", "largest_component",
    "mean_distance", "diameter", "mutual", "asymmetric", "null",
    "assortativity", "centralization_degree", "centralization_betweenness",
    "centralization_closeness", "triads", "connectedness", "efficiency",
    "hierarchy", "lubness"
  )
  got <- as.data.frame(metrics(empty, all_measures, start = 2, end = 2,
                                   step = 1, window = 0))
  scalar <- setNames(got$value, got$measure)
  expect_equal(unname(scalar[c("density", "edges", "active_nodes", "isolates",
                               "components", "components_strong",
                               "largest_component", "efficiency")]), rep(0, 8))
  expect_equal(unname(scalar[c("transitivity", "connectedness")]), c(1, 1))
  expect_true(all(is.na(scalar[c("mean_distance", "diameter", "assortativity",
                                  "centralization_degree",
                                  "centralization_betweenness",
                                  "centralization_closeness")])))
  expect_true(all(is.nan(scalar[c("hierarchy", "lubness")])))
  expect_equal(sum(grepl("^triad_", names(scalar))), 16)
  expect_equal(sum(scalar[grepl("^triad_", names(scalar))]), 0)
  expect_true(all(is.na(as.data.frame(dyn_centrality(
    empty, "degree", start = 2, end = 2, step = 1, window = 0
  ))$value)))

  singleton <- quiet_dynet(edge, nodes = nodes, vertex_spells = data.frame(
    node = c("A", "B", "C"), start = c(2, 0, 0), end = c(3, 1, 1)
  ))
  one <- metrics(singleton, c("density", "edges", "active_nodes",
                                  "isolates", "components", "components_strong",
                                  "largest_component", "efficiency"),
                     start = 2, end = 2, step = 1, window = 0)
  expect_equal(v02_values(one, "density"), 0)
  expect_equal(v02_values(one, "edges"), 0)
  expect_equal(v02_values(one, "active_nodes"), 0)
  expect_equal(v02_values(one, "isolates"), 1)
  expect_equal(v02_values(one, "components"), 1)
  expect_equal(v02_values(one, "components_strong"), 1)
  expect_equal(v02_values(one, "largest_component"), 1)
  expect_true(is.nan(v02_values(one, "efficiency")))
})

test_that("V02 bounded filters sessions locally and collapse may authorize", {
  edges <- data.frame(
    from = c("A", "A", "D"), to = c("B", "C", "A"),
    start = c(0, 0, 3), end = c(2, 2, 4), wave = c("s1", "s2", "s1")
  )
  vertices <- data.frame(
    node = c("A", "B", "C"), start = 0, end = 2,
    session = c("s1", "s1", "s2")
  )
  dn <- quiet_dynet(edges, session = "wave", nodes = data.frame(
    name = c("A", "B", "C", "D")
  ), vertex_spells = vertices)
  bounded <- metrics(dn, c("edges", "density"), sessions = "bounded",
                         start = 1, end = 1, step = 1, window = 0)
  collapsed <- metrics(dn, c("edges", "density"), sessions = "collapse",
                           start = 1, end = 1, step = 1, window = 0)
  separate <- as.data.frame(metrics(
    dn, c("edges", "density"), sessions = "separate",
    start = 1, end = 1, step = 1, window = 0
  ))
  expect_equal(v02_values(bounded, "edges"), 1)
  expect_equal(v02_values(bounded, "density"), 1/12)
  expect_equal(v02_values(collapsed, "edges"), 2)
  expect_equal(v02_values(collapsed, "density"), 1/6)
  expect_equal(separate$value[separate$measure == "edges"], c(1, 0))
  expect_equal(separate$value[separate$measure == "density"], c(1/6, 0))
})

test_that("V02 snapshots, mixing, loops, weights and isolates share one state", {
  edges <- data.frame(
    from = c("A", "A", "A"), to = c("B", "B", "A"),
    start = 0, end = 2, weight = c(2, 5, 7)
  )
  nodes <- data.frame(name = c("A", "B", "C"), group = c("x", "y", "z"))
  vertices <- data.frame(node = c("A", "B", "C"), start = 0, end = 2)
  dn <- quiet_dynet(edges, nodes = nodes, groups = "group", weight = "weight",
                    loops = TRUE, vertex_spells = vertices)
  snap <- snapshots(dn, start = 1, end = 1, step = 1, window = 0)
  pair <- paste(snap$from, snap$to, sep = "->")
  expect_equal(snap$weight[match(c("A->A", "A->B"), pair)], c(7, 7))
  expect_equal(snap$n_spells[match(c("A->A", "A->B"), pair)], c(1L, 2L))
  graph <- metrics(dn, c("edges", "active_nodes", "isolates", "density"),
                       start = 1, end = 1, step = 1, window = 0)
  expect_equal(v02_values(graph, "edges"), 1)
  expect_equal(v02_values(graph, "active_nodes"), 2)
  expect_equal(v02_values(graph, "isolates"), 1)
  expect_equal(v02_values(graph, "density"), 1/6)
  node <- as.data.frame(dyn_centrality(
    dn, c("degree", "strength"), start = 1, end = 1, step = 1, window = 0
  ))
  expect_equal(node$value[node$measure == "degree"], c(3, 1, 0))
  expect_equal(node$value[node$measure == "strength"], c(21, 7, 0))
  mix <- as.data.frame(mixing(dn, "group", start = 1, end = 1,
                                  step = 1, window = 0))
  expect_equal(sum(mix$value), 2)
  expect_equal(nrow(mix), 9)
})

test_that("V02 direct helpers expose fixed eligibility and filtered edge rows", {
  dn <- quiet_dynet(v02_edges(), weight = "weight",
                    vertex_spells = v02_vertices())
  enc <- Dynet:::.encode(dn)
  state <- Dynet:::.snapshot_state(
    dn, enc, data.frame(lo = 2, hi = 2, closed = TRUE, time = 2),
    window = 0, sessions = "bounded", label = "all"
  )
  expect_identical(enc$names[state$eligible], c("A", "B", "D", "E"))
  expect_equal(sum(state$active), 3)
  expect_identical(state$index, which(state$eligible))
  view <- Dynet:::.bin_netobject(dn, 2)
  expect_identical(as.data.frame(view, what = "nodes")$name,
                   c("A", "B", "D", "E"))
  expect_false("C" %in% as.data.frame(view, what = "vertex_spells")$node)
})

test_that("V02 observed vertex fragments and direct eligibility respect gaps", {
  edges <- data.frame(from = "A", to = "B", start = 0, end = 6)
  observations <- data.frame(start = c(0, 4), end = c(2, 6))
  vertices <- data.frame(
    node = c("A", "B"), start = c(1, 3), end = c(5, 3)
  )
  dn <- quiet_dynet(edges, observation_spells = observations,
                    vertex_spells = vertices)
  fragments <- Dynet:::.observed_vertex_fragments(dn)
  expect_equal(fragments$node, c("A", "A"))
  expect_equal(fragments$start, c(1, 4))
  expect_equal(fragments$end, c(2, 5))
  activity <- Dynet:::.encode_vertex_activity(dn)
  expect_identical(activity$declared, c(TRUE, TRUE))
  in_gap <- Dynet:::.vertex_eligibility(
    activity, data.frame(lo = 3, hi = 3, closed = TRUE), 0
  )
  expect_identical(in_gap, c(FALSE, FALSE))
  second <- Dynet:::.vertex_eligibility(
    activity, data.frame(lo = 4, hi = 4, closed = TRUE), 0
  )
  expect_identical(second, c(TRUE, FALSE))
})

test_that("V02 all snapshot centralities pin empty and singleton populations", {
  edges <- data.frame(from = "A", to = "B", start = 0, end = 4)
  nodes <- data.frame(name = c("A", "B", "C"))
  empty <- quiet_dynet(edges, nodes = nodes, vertex_spells = data.frame(
    node = c("A", "B", "C"), start = 0, end = 1
  ))
  measures <- setdiff(Dynet:::.node_measures, c("indegree", "outdegree"))
  # participation is the one measure that needs a grouping; one label per
  # vertex keeps every enumerated measure in the same call.
  groups <- c("g1", "g1", "g2")
  got <- as.data.frame(dyn_centrality(
    empty, measures, start = 2, end = 2, step = 1, window = 0, groups = groups
  ))
  expect_true(all(is.na(got$value)))

  singleton <- quiet_dynet(edges, nodes = nodes, vertex_spells = data.frame(
    node = c("A", "B", "C"), start = c(2, 0, 0), end = c(3, 1, 1)
  ))
  one <- as.data.frame(dyn_centrality(
    singleton, measures, start = 2, end = 2, step = 1, window = 0,
    groups = groups
  ))
  expect_true(all(is.na(one$value[one$node != "A"])))
  expect_equal(one$value[one$node == "A" & one$measure == "pagerank"], 1)
  expect_true(is.na(one$value[one$node == "A" & one$measure == "constraint"]))
})

test_that("V02 no-activity compatibility preserves public values and shape", {
  base <- quiet_dynet(v02_edges(), weight = "weight")
  empty <- quiet_dynet(v02_edges(), weight = "weight", vertex_spells = data.frame(
    node = character(), start = numeric(), end = numeric()
  ))
  expect_equal(metrics(base, c("density", "triads")),
               metrics(empty, c("density", "triads")),
               ignore_attr = TRUE)
  expect_equal(dyn_centrality(base, c("degree", "pagerank", "strength")),
               dyn_centrality(empty, c("degree", "pagerank", "strength")),
               ignore_attr = TRUE)
  expect_equal(snapshots(base), snapshots(empty))
})

test_that("V02 proximity slices use induced state and mask inactive vertices", {
  dn <- quiet_dynet(
    data.frame(from = "A", to = "B", start = 0, end = 2),
    nodes = data.frame(name = c("A", "B", "C")),
    vertex_spells = data.frame(
      node = c("A", "B", "C"), start = 0, end = .5
    )
  )
  slices <- Dynet:::.proximity_slices(dn, slices = 3, window = .2)
  expect_equal(slices$weight[, 1L], c(1, 1, 0))
  expect_true(all(is.na(slices$weight[, 2L:3L])))
  expect_true(all(is.na(slices$pos[, 2L:3L])))

  isolate_dn <- quiet_dynet(
    data.frame(from = c("A", "C"), to = c("B", "A"),
               start = c(0, 3), end = c(2, 4)),
    vertex_spells = data.frame(
      node = c("A", "B"), start = 0, end = .5
    )
  )
  isolate_only <- Dynet:::.bin_netobject(isolate_dn, 1)
  expect_identical(as.data.frame(isolate_only, what = "nodes")$name, "C")
  expect_equal(nrow(as.data.frame(isolate_only, what = "network")), 0)
})

test_that("V02 snapshots are invariant to rows, names, translation and scale", {
  edges <- v02_edges()
  vertices <- v02_vertices()
  baseline <- quiet_dynet(edges, weight = "weight", vertex_spells = vertices)
  measure <- function(dn, start, end, step) {
    x <- as.data.frame(metrics(
      dn, c("density", "active_nodes", "isolates", "triads"),
      start = start, end = end, step = step, window = 0
    ))
    x[, c("measure", "value")]
  }
  permuted <- quiet_dynet(
    edges[c(5, 2, 4, 1, 3), ], weight = "weight",
    vertex_spells = vertices[c(6, 3, 1, 5, 2, 4), ]
  )
  expect_equal(measure(permuted, 0, 5, 1), measure(baseline, 0, 5, 1))

  map <- c(A = "u", B = "v", C = "w", D = "x", E = "y")
  renamed_edges <- edges
  renamed_edges$from <- unname(map[renamed_edges$from])
  renamed_edges$to <- unname(map[renamed_edges$to])
  renamed_vertices <- vertices
  renamed_vertices$node <- unname(map[renamed_vertices$node])
  renamed <- quiet_dynet(
    renamed_edges, weight = "weight", vertex_spells = renamed_vertices
  )
  expect_equal(measure(renamed, 0, 5, 1), measure(baseline, 0, 5, 1))

  shifted_edges <- transform(edges, start = start + 10, end = end + 10)
  shifted_vertices <- transform(vertices, start = start + 10, end = end + 10)
  shifted <- quiet_dynet(
    shifted_edges, weight = "weight", vertex_spells = shifted_vertices
  )
  expect_equal(measure(shifted, 10, 15, 1), measure(baseline, 0, 5, 1))

  scaled_edges <- transform(edges, start = start * 3, end = end * 3)
  scaled_vertices <- transform(vertices, start = start * 3, end = end * 3)
  scaled <- quiet_dynet(
    scaled_edges, weight = "weight", vertex_spells = scaled_vertices
  )
  expect_equal(measure(scaled, 0, 15, 3), measure(baseline, 0, 5, 1))
})

test_that("V02 proximity respects every observation component closure and gap", {
  dn <- quiet_dynet(
    data.frame(from = c("A", "C"), to = c("B", "D"),
               start = c(1, 4), end = c(1, 4)),
    observation_spells = data.frame(start = c(0, 3), end = c(1, 4)),
    vertex_spells = data.frame(
      node = c("A", "B", "C", "D"), start = c(1, 1, 4, 4),
      end = c(1, 1, 4, 4)
    )
  )
  component <- Dynet:::.proximity_slices(
    dn, slices = NULL, window = 1
  )
  expect_equal(component$times, c(0, 3))
  expect_equal(component$weight[, 1L], c(1, 1, NA, NA))
  expect_equal(component$weight[, 2L], c(NA, NA, 1, 1))

  custom <- Dynet:::.proximity_slices(dn, slices = 5, window = 3)
  gap <- custom$times > 1 & custom$times < 3
  expect_true(any(gap))
  expect_true(all(is.na(custom$weight[, gap])))
  expect_true(all(is.na(custom$pos[, gap])))
  expect_true(all(is.na(custom$weight[3:4, custom$times <= 1])))
  expect_true(all(is.na(custom$weight[1:2, custom$times >= 3])))

  repeated <- quiet_dynet(
    data.frame(from = c("A", "A"), to = c("B", "B"),
               start = c(0, 3), end = c(1, 4)),
    observation_spells = data.frame(start = c(0, 3), end = c(1, 4)),
    vertex_spells = data.frame(
      node = rep(c("A", "B"), each = 2), start = c(0, 3, 0, 3),
      end = c(1, 4, 1, 4)
    )
  )
  repeated_slices <- Dynet:::.proximity_slices(
    repeated, slices = 5, window = .4
  )
  expect_equal(repeated_slices$times, 0:4)
  expect_true(all(is.na(repeated_slices$pos[, 3L])))
  expect_true(all(is.finite(repeated_slices$pos[, c(1L, 2L, 4L, 5L)])))
})

test_that("V02 proximity lines omit inactive runs without bridging them", {
  file <- tempfile(fileext = ".png")
  grDevices::png(file, width = 5, height = 4, units = "in", res = 72)
  on.exit({grDevices::dev.off(); unlink(file)}, add = TRUE)
  graphics::plot(NA, xlim = c(1, 5), ylim = c(-1, 3))
  drawn <- Dynet:::.draw_proximity_line(
    1:5, c(0, 1, NA, 1, 2), c(1, 2, NA, 2, 3), "black", flow = 0
  )
  expect_equal(drawn$x, c(1, 2, 4, 5))
  expect_equal(drawn$y, c(0, 1, 1, 2))
  absent <- Dynet:::.draw_proximity_line(
    1:3, rep(NA_real_, 3), rep(NA_real_, 3), "black", flow = 0
  )
  expect_equal(absent, list(x = numeric(), y = numeric()))
})
