# Rhythm, persistence, segregation and community-trajectory measures against teneto (Thompson et al. 2017), the
# Python package of temporal network measures, run live through the reference Python:
#   - gaps(unit = "pair")      teneto.networkmeasures.intercontacttimes() of a directed contact array;
#   - burstiness()             teneto.networkmeasures.bursty_coeff() (Goh and Barabasi 2008, population standard
#                              deviation) of each vertex's gaps; the gaps are the differences of the vertex's
#                              sorted incident onsets, taken in base R, since teneto pools gaps per edge, not per
#                              vertex;
#   - persistence()            teneto.networkmeasures.topological_overlap() (Tang et al. 2010) of the folded
#                              window snapshots, per time, per vertex and overall;
#   - segregation()            teneto.networkmeasures.sid() (Fransson's segregation-integration difference) of the
#                              same snapshots, two communities (teneto's sum over community pairs equals the sum
#                              over communities only for two: with C communities it counts each within term C - 1
#                              times);
#   - community_trajectory()   teneto.communitymeasures.flexibility(), promiscuity() and persistence(calc = "node")
#                              of the matched node-by-bin label matrix.
# The snapshots and the label matrix, teneto's inputs, are built in base R from the spell list and from
# match_communities()'s table; teneto computes each measure from them.

teneto_ref <- "teneto"

teneto_python <- function(code, input) {
  ref_python(c("import json, sys", "import numpy as np", "import warnings", "warnings.simplefilter('ignore')",
               "given = json.load(open(sys.argv[1]))", code), input)
}

#' Seeded directed contacts at whole times, one contact per pair and time at most
random_contacts <- function(seed, vertices = 6L, contacts = 120L, times = 60L) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
          add = TRUE)
  set.seed(seed)
  drawn <- data.frame(from = sprintf("v%d", sample(vertices, contacts, TRUE)),
                      to = sprintf("v%d", sample(vertices, contacts, TRUE)), time = sample(times, contacts, TRUE) - 1)
  drawn <- subset(drawn, from != to)
  drawn[!duplicated(drawn), ]
}

test_that("each ordered pair's gaps equal teneto's intercontact times", {
  ref_skip_without_python("teneto", reference = teneto_ref)
  rows <- lapply(1:3, \(seed) {
    contacts <- random_contacts(seed)
    vertices <- sort(unique(c(contacts$from, contacts$to)))
    found <- teneto_python(c(
      "import teneto",
      "n = len(given['vertices']); T = int(max(given['time'])) + 1",
      "net = np.zeros((n, n, T))",
      "net[given['i'], given['j'], given['t']] = 1",
      "ict = teneto.networkmeasures.intercontacttimes(net)['intercontacttimes']",
      "rows = [(i, j, k + 1, float(g)) for i in range(n) for j in range(n) if ict[i, j] is not None",
      "        for k, g in enumerate(ict[i, j])]",
      "json.dump({'i': [r[0] for r in rows], 'j': [r[1] for r in rows], 'index': [r[2] for r in rows],",
      "           'gap': [r[3] for r in rows], 'nettype': teneto.networkmeasures.intercontacttimes(net)['nettype']},",
      "          open(sys.argv[2], 'w'))"),
      list(vertices = vertices, i = match(contacts$from, vertices) - 1L, j = match(contacts$to, vertices) - 1L,
           t = as.integer(contacts$time), time = contacts$time))
    stopifnot("teneto must read the array as binary directed" = identical(found$nettype, "bd"))
    theirs <- data.frame(seed = seed, from = vertices[found$i + 1L], to = vertices[found$j + 1L], index = found$index,
                         value = found$gap)
    ours <- subset(as.data.frame(gaps(dynet(contacts, format = "contact"), unit = "pair")),
                   select = c(from, to, index, value))
    list(ours = cbind(seed = seed, ours), theirs = theirs)
  })
  # Differences of whole times.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = teneto_ref, covers = "gaps()", quantity = "gap per ordered pair, random contacts",
                   tolerance = 1e-12, key = c("seed", "from", "to", "index"))
})

test_that("each vertex's burstiness equals teneto's bursty_coeff() of its gaps", {
  ref_skip_without_python("teneto", reference = teneto_ref)
  cases <- list(school = school_contacts,
                contacts = transform(random_contacts(4L), start = time, end = time + 0.5, time = NULL))
  rows <- Map(\(spells, case) {
    incident <- data.frame(node = c(spells$from, spells$to), time = c(spells$start, spells$start))
    per_node <- lapply(split(incident$time, incident$node), \(times) diff(sort(times)))
    found <- teneto_python(c(
      "import teneto",
      "out = [float(teneto.networkmeasures.bursty_coeff({'intercontacttimes': np.array(g, dtype=float)})[0])",
      "       for g in given['gaps']]",
      "json.dump({'b': out}, open(sys.argv[2], 'w'))"),
      list(gaps = unname(per_node)))
    list(ours = cbind(case = case, as.data.frame(burstiness(dynet(spells), measure = "burstiness"))),
         theirs = data.frame(case = case, node = names(per_node), measure = "burstiness", value = found$b))
  }, cases, names(cases))
  # A mean and a population standard deviation of at most forty gaps.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = teneto_ref, covers = "burstiness()", quantity = "burstiness per vertex",
                   tolerance = 1e-10, key = c("case", "node", "measure"))
})

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
onsets <- c(0, 7, 14, 21)
folded_windows <- function(edges, onsets, width, vertices) {
  lapply(onsets, \(lo) {
    layer <- ref_adjacency(edges, lo, lo + width, vertices)
    pmax(layer, t(layer))
  })
}

test_that("topological overlap per transition, per vertex and overall equals teneto's topological_overlap()", {
  ref_skip_without_python("teneto", reference = teneto_ref)
  cases <- list(list(name = "windows of 7", step = 7, onsets = onsets),
                list(name = "windows of 3", step = 3, onsets = seq(0, 21, by = 3)))
  rows <- lapply(cases, \(case) {
    layers <- folded_windows(spells, case$onsets, case$step, people)
    found <- teneto_python(c(
      "import teneto",
      "net = np.transpose(np.array(given['layers'], dtype=float), (1, 2, 0))",
      "per = teneto.networkmeasures.topological_overlap(net, calc='pertime')[:, :-1]",
      "node = teneto.networkmeasures.topological_overlap(net, calc='node')",
      "whole = teneto.networkmeasures.topological_overlap(net, calc='overtime')",
      "json.dump({'per': per.tolist(), 'node': node.tolist(), 'whole': float(whole)}, open(sys.argv[2], 'w'))"),
      list(layers = lapply(layers, unname)))
    # One row per vertex, one column per transition.
    per <- found$per
    lo <- utils::head(case$onsets, -1L)
    net <- dynet(spells)
    list(
      ours_per = cbind(case = case$name, as.data.frame(persistence(net, scope = "pertime", step = case$step,
                                                                    window = case$step))),
      theirs_per = data.frame(case = case$name, time = rep(lo, each = length(people)), node = rep(people, length(lo)),
                              measure = "topological_overlap", value = as.vector(per)),
      ours_node = cbind(case = case$name, as.data.frame(persistence(net, scope = "node", step = case$step,
                                                                     window = case$step))),
      theirs_node = data.frame(case = case$name, node = people, measure = "average_topological_overlap",
                               value = found$node),
      ours_all = cbind(case = case$name, as.data.frame(persistence(net, scope = "overall", step = case$step,
                                                                    window = case$step))),
      theirs_all = data.frame(case = case$name, measure = "temporal_correlation", value = found$whole))
  })
  stack <- \(part) do.call(rbind, lapply(rows, `[[`, part))
  # Ratios and means of small counts.
  expect_reference(stack("ours_per"), stack("theirs_per"), reference = teneto_ref, covers = "persistence()",
                   quantity = "topological overlap per vertex and transition", tolerance = 1e-12,
                   key = c("case", "time", "node", "measure"))
  expect_reference(stack("ours_node"), stack("theirs_node"), reference = teneto_ref, covers = "persistence()",
                   quantity = "topological overlap per vertex, averaged", tolerance = 1e-12,
                   key = c("case", "node", "measure"))
  expect_reference(stack("ours_all"), stack("theirs_all"), reference = teneto_ref, covers = "persistence()",
                   quantity = "temporal correlation", tolerance = 1e-12, key = c("case", "measure"))
})

test_that("segregation equals teneto's sid() of the folded windows, two communities", {
  ref_skip_without_python("teneto", reference = teneto_ref)
  splits <- list(halves = rep(c("early", "late"), each = 7L), unequal = rep(c("early", "late"), c(5L, 9L)))
  rows <- Map(\(group, case) {
    layers <- folded_windows(spells, onsets, 7, people)
    found <- teneto_python(c(
      "import teneto",
      "net = np.transpose(np.array(given['layers'], dtype=float), (1, 2, 0))",
      "out = teneto.networkmeasures.sid(net, np.array(given['communities']), calc='overtime')",
      "json.dump({'sid': [float(v) for v in out]}, open(sys.argv[2], 'w'))"),
      list(layers = lapply(layers, unname), communities = match(group, unique(group)) - 1L))
    network <- dynet(spells, nodes = data.frame(name = people, group = group))
    list(ours = cbind(case = case, as.data.frame(segregation(network, "group", step = 7, window = 7))),
         theirs = data.frame(case = case, time = onsets, measure = "sid", value = found$sid))
  }, splits, names(splits))
  # Sums of a few ratios of small integers.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = teneto_ref, covers = "segregation()", quantity = "SID per window of 7",
                   tolerance = 1e-12, key = c("case", "time", "measure"))
})

test_that("flexibility, promiscuity and persistence of the matched labels equal teneto's community measures", {
  ref_skip_without_python("teneto", reference = teneto_ref)
  membership <- function(seed, n = 30L, bins = 5L) {
    old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
    on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
            add = TRUE)
    set.seed(seed)
    planted <- sample(1:4, n, TRUE)
    labels <- lapply(seq_len(bins), \(bin) replace(planted, sample(n, 7L), sample(1:4, 7L, TRUE)))
    data.frame(time = rep(seq_len(bins) - 1, each = n), node = rep(sprintf("v%02d", seq_len(n)), bins),
               community = unlist(labels))
  }
  rows <- lapply(c(31L, 32L, 33L), \(seed) {
    matched <- match_communities(membership(seed))
    table <- as.data.frame(matched)
    nodes <- sort(unique(table$node))
    times <- sort(unique(table$time))
    labels <- matrix(table$community[match(paste(rep(nodes, length(times)), rep(times, each = length(nodes))),
                                           paste(table$node, table$time))], nrow = length(nodes))
    found <- teneto_python(c(
      "import teneto",
      "c = np.array(given['labels'])",
      "json.dump({'flexibility': teneto.communitymeasures.flexibility(c).tolist(),",
      "           'promiscuity': teneto.communitymeasures.promiscuity(c).tolist(),",
      "           'persistence': teneto.communitymeasures.persistence(c, calc='node').tolist()},",
      "          open(sys.argv[2], 'w'))"),
      list(labels = unname(labels)))
    measures <- c("flexibility", "promiscuity", "persistence")
    list(ours = cbind(seed = seed, as.data.frame(community_trajectory(matched, measure = measures))),
         theirs = data.frame(seed = seed, node = rep(nodes, length(measures)),
                             measure = rep(measures, each = length(nodes)),
                             value = unlist(found[measures], use.names = FALSE)))
  })
  # Means of four indicator values and ratios of small counts.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = teneto_ref, covers = c("community_trajectory()", "as.data.frame.dynet_trajectory()"),
                   quantity = "per vertex, matched labels", tolerance = 1e-12, key = c("seed", "node", "measure"))
})
