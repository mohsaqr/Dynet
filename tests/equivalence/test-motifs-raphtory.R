# motifs(): the 40-class census of three-edge, three-node delta-temporal motifs (Paranjape, Benson and Leskovec
# 2017) against raphtory 0.17 (algorithms.global_temporal_three_node_motif() and
# local_temporal_three_node_motifs()), whose class numbering Dynet documents and follows. raphtory takes whole
# timestamps, so the event times (on a 0.01 grid) and delta are multiplied by 100 on its side. Events at one
# instant are ordered differently by the two (Dynet: time, sender, receiver, row), so every input here has distinct
# event times: seeded random event lists of 6 and 9 vertices and a simulab temporal network's formation events.
# Counts are integers: tolerance 0.

raphtory_ref <- "raphtory"

raphtory_census <- function(events, delta, nodes) {
  ref_python(c(
    "import json, sys",
    "import raphtory as rp",
    "from raphtory import algorithms as al",
    "given = json.load(open(sys.argv[1]))",
    "g = rp.Graph()",
    "for t, a, b in zip(given['time'], given['from'], given['to']):",
    "    g.add_edge(int(t), a, b)",
    "glob = al.global_temporal_three_node_motif(g, int(given['delta']))",
    "loc = al.local_temporal_three_node_motifs(g, int(given['delta']))",
    "local = {name: [int(v) for v in loc[name]['motif_counter']] for name in given['nodes']}",
    "json.dump({'global': [int(v) for v in glob], 'local': local}, open(sys.argv[2], 'w'))"),
    list(time = round(events$time * 100), from = events$from, to = events$to, delta = round(delta * 100),
         nodes = nodes))
}

#' Seeded directed events at distinct times on a 0.01 grid
distinct_events <- function(seed, vertices, n_events, span) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
          add = TRUE)
  set.seed(seed)
  drawn <- data.frame(from = sample(LETTERS[seq_len(vertices)], n_events, TRUE),
                      to = sample(LETTERS[seq_len(vertices)], n_events, TRUE),
                      time = sort(sample(seq(0, span, by = 0.01), n_events)))
  subset(drawn, from != to)
}

#' simulab formation events, one per spell onset, moved apart within their period to distinct times
simulab_events <- function(seed) {
  spells <- as.data.frame(simulab::simulate_temporal_network(nodes = 7, periods = 40, initial_probability = 0.15,
                                                               formation_probability = 0.06,
                                                               dissolution_probability = 0.4, seed = seed))
  spells <- spells[order(spells$onset, spells$from, spells$to), ]
  data.frame(from = sub("Node ", "N", spells$from), to = sub("Node ", "N", spells$to),
             time = spells$onset + (seq_len(nrow(spells)) %% 100) / 100)
}

cases <- list(list(name = "6 vertices, seed 20171, delta 8", events = distinct_events(20171L, 6L, 140L, 200), delta = 8),
              list(name = "6 vertices, seed 5, delta 3", events = distinct_events(5L, 6L, 160L, 150), delta = 3),
              list(name = "9 vertices, seed 6, delta 12", events = distinct_events(6L, 9L, 150L, 200), delta = 12),
              list(name = "simulab seed 7, delta 2", events = simulab_events(7L), delta = 2),
              list(name = "simulab seed 8, delta 5", events = simulab_events(8L), delta = 5))

#' The cases with raphtory's census, computed inside each test (after its skip)
runs_of <- function() lapply(cases, \(case) {
  stopifnot("event times must be distinct" = !anyDuplicated(case$events$time))
  nodes <- sort(unique(c(case$events$from, case$events$to)))
  network <- dynet(case$events, format = "contact")
  c(case, list(nodes = nodes, network = network, theirs = raphtory_census(case$events, case$delta, nodes)))
})

test_that("the global census equals raphtory's global_temporal_three_node_motif()", {
  ref_skip_without_python("raphtory", reference = raphtory_ref)
  runs <- runs_of()
  ours <- do.call(rbind, lapply(runs, \(run) {
    cbind(case = run$name, as.data.frame(motifs(run$network, delta = run$delta)))
  }))
  theirs <- do.call(rbind, lapply(runs, \(run) data.frame(case = run$name, motif = seq_len(40L), count = run$theirs$global)))
  expect_reference(ours, theirs, reference = raphtory_ref, covers = c("motifs()", "as.data.frame.dynet_motifs()"),
                   quantity = "instances per class", tolerance = 0, key = c("case", "motif"))
})

test_that("the local census equals raphtory's local_temporal_three_node_motifs()", {
  ref_skip_without_python("raphtory", reference = raphtory_ref)
  runs <- runs_of()
  ours <- do.call(rbind, lapply(runs, \(run) {
    cbind(case = run$name, as.data.frame(motifs(run$network, delta = run$delta, output = "local")))
  }))
  theirs <- do.call(rbind, lapply(runs, \(run) {
    do.call(rbind, lapply(run$nodes, \(node) {
      data.frame(case = run$name, node = node, motif = seq_len(40L), count = unlist(run$theirs$local[[node]]))
    }))
  }))
  expect_reference(ours, theirs, reference = raphtory_ref, covers = c("motifs()", "as.data.frame.dynet_motifs()"),
                   quantity = "instances per vertex and class", tolerance = 0, key = c("case", "node", "motif"))
})

test_that("the family summary equals raphtory's census summed by family", {
  ref_skip_without_python("raphtory", reference = raphtory_ref)
  runs <- runs_of()
  families <- c("star_pre", "star_mid", "star_post", "two_node", "triangle")
  ours <- do.call(rbind, lapply(runs, \(run) {
    cbind(case = run$name, subset(summary(motifs(run$network, delta = run$delta)), select = c(family, count, share)))
  }))
  theirs <- do.call(rbind, lapply(runs, \(run) {
    counts <- run$theirs$global
    by_family <- vapply(seq_along(families), \(f) sum(counts[(f - 1L) * 8L + seq_len(8L)]), numeric(1))
    data.frame(case = run$name, family = families, count = by_family, share = by_family / sum(counts))
  }))
  # Shares are ratios of counts below a few thousand.
  expect_reference(ours, theirs, reference = raphtory_ref, covers = "summary.dynet_motifs()",
                   quantity = "instances per family", tolerance = 1e-12, key = c("case", "family"))
})
