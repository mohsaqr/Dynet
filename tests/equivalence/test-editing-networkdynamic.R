# The editing verbs, dynet() and its summary against networkDynamic, the statnet package that stores a temporal
# network as spells and edits them in place. Each verb's edit is made on a networkDynamic object with
# networkDynamic's own editing functions (add.edges.active(), deactivate.edges(), network::delete.edges(),
# network::delete.vertices(), network::get.inducedSubgraph(), activate.vertices(), deactivate.vertices(),
# delete.vertex.activity()), and the spell table networkDynamic lists afterwards is the reference. The
# observation-period verbs are checked through tsna::tEdgeDensity(), which divides by the declared period.
#
# The input is drawn by simulab::simulate_temporal_network() (a dyad Markov chain of formation and dissolution
# over discrete periods): no two spells of one pair overlap or abut, so networkDynamic, which merges overlapping
# spells of a pair, lists them one by one as Dynet does. Three seeds. Times are whole periods: tolerance 1e-12.

nd_seeds <- c(3L, 4L, 5L)
nd_refs <- c("networkDynamic", "network")
spell_key <- c("from", "to", "start")

#' One simulab temporal network as a spell table `from`, `to`, `start`, `end`
sim_spells <- function(seed) {
  drawn <- as.data.frame(simulab::simulate_temporal_network(nodes = 8, periods = 30, initial_probability = 0.2,
                                                              formation_probability = 0.05,
                                                              dissolution_probability = 0.3, seed = seed))
  data.frame(from = drawn$from, to = drawn$to, start = as.numeric(drawn$onset), end = as.numeric(drawn$terminus))
}

#' The spells networkDynamic lists, by vertex name, with their durations
nd_spells <- function(history) {
  listed <- as.data.frame(history)
  names_in <- network::get.vertex.attribute(history, "vertex.names")
  data.frame(from = names_in[listed$tail], to = names_in[listed$head], start = listed$onset, end = listed$terminus,
             duration = listed$duration)
}

#' The vertex spells networkDynamic lists, by vertex name
#'
#' networkDynamic() gives every vertex a spell over the observed period when it builds the object, and a vertex
#' with no activity attribute is active by default; Dynet holds no vertex spell until one is set. The reference
#' therefore deletes networkDynamic's vertex activity before an edit (`nd_without_vertex_spells()`) and lists the
#' spells that have a finite onset.
nd_vertex_spells <- function(history) {
  listed <- networkDynamic::get.vertex.activity(history, as.spellList = TRUE, active.default = FALSE)
  listed <- subset(listed, is.finite(onset))
  names_in <- network::get.vertex.attribute(history, "vertex.names")
  data.frame(node = names_in[listed$vertex.id], start = listed$onset, end = listed$terminus,
             duration = listed$terminus - listed$onset)
}

#' Every seed's result of `ours(network, spells)` and `theirs(history, spells)`, stacked with a `seed` column
by_seed <- function(ours, theirs) {
  rows <- lapply(nd_seeds, \(seed) {
    spells <- sim_spells(seed)
    list(ours = cbind(seed = seed, ours(dynet(spells), spells)),
         theirs = cbind(seed = seed, theirs(ref_network_dynamic(spells), spells)))
  })
  list(ours = do.call(rbind, lapply(rows, `[[`, "ours")), theirs = do.call(rbind, lapply(rows, `[[`, "theirs")))
}

test_that("dynet() lists the spells networkDynamic lists", {
  skip_without_reference(nd_refs)
  sides <- by_seed(\(net, spells) as.data.frame(net), \(history, spells) nd_spells(history))
  expect_reference(sides$ours, sides$theirs, reference = "networkDynamic",
                   covers = c("dynet()", "as.data.frame.dynet()"), quantity = "spell, simulab networks",
                   tolerance = 1e-12, key = c("seed", spell_key))
})

test_that("summary() counts the vertices, spells and pairs networkDynamic holds, and its observed range", {
  skip_without_reference(nd_refs)
  wanted <- c("vertices", "edge spells", "distinct pairs", "observed from", "observed to")
  sides <- by_seed(\(net, spells) transform(subset(summary(net), property %in% wanted), value = as.numeric(value)),
                   \(history, spells) {
                     period <- unlist(network::get.network.attribute(history, "net.obs.period")$observations)
                     data.frame(property = wanted,
                                value = c(network::network.size(history), nrow(as.data.frame(history)),
                                          network::network.edgecount(history), min(period), max(period)))
                   })
  expect_reference(sides$ours, sides$theirs, reference = "networkDynamic", covers = c("summary.dynet()", "dynet()"),
                   quantity = "network, simulab networks", tolerance = 1e-12, key = c("seed", "property"))
})

test_that("add_ties() and add_arcs() equal networkDynamic::add.edges.active()", {
  skip_without_reference(nd_refs)
  # Two spells on pairs with no spell in the drawn network, so that networkDynamic adds new edges.
  extra <- \(spells) {
    vertices <- sort(unique(c(spells$from, spells$to)))
    free <- subset(expand.grid(from = vertices, to = vertices, stringsAsFactors = FALSE),
                   from != to & !paste(from, to) %in% paste(spells$from, spells$to))
    transform(utils::head(free, 2L), start = c(3, 12), end = c(7, 20))
  }
  added <- \(history, spells) {
    new <- extra(spells)
    vertices <- network::get.vertex.attribute(history, "vertex.names")
    networkDynamic::add.edges.active(history, tail = match(new$from, vertices), head = match(new$to, vertices),
                                     onset = new$start, terminus = new$end)
    nd_spells(history)
  }
  ties <- by_seed(\(net, spells) as.data.frame(add_ties(net, extra(spells))), added)
  expect_reference(ties$ours, ties$theirs, reference = "networkDynamic", covers = "add_ties()",
                   quantity = "spell after adding two", tolerance = 1e-12, key = c("seed", spell_key))
  arcs <- by_seed(\(net, spells) as.data.frame(add_arcs(net, extra(spells))), added)
  expect_reference(arcs$ours, arcs$theirs, reference = "networkDynamic", covers = "add_arcs()",
                   quantity = "spell after adding two arcs", tolerance = 1e-12, key = c("seed", spell_key))
})

test_that("remove_ties() and remove_arcs() equal network::delete.edges() of every edge a vertex sends", {
  skip_without_reference(nd_refs)
  sender <- \(spells) sort(unique(spells$from))[[1L]]
  removed <- \(history, spells) {
    listed <- as.data.frame(history)
    vertices <- network::get.vertex.attribute(history, "vertex.names")
    network::delete.edges(history, unique(listed$edge.id[vertices[listed$tail] == sender(spells)]))
    nd_spells(history)
  }
  ties <- by_seed(\(net, spells) as.data.frame(remove_ties(net, from = sender(spells))), removed)
  expect_reference(ties$ours, ties$theirs, reference = "networkDynamic", covers = "remove_ties()",
                   quantity = "spell after removing the first sender's", tolerance = 1e-12, key = c("seed", spell_key))
  arcs <- by_seed(\(net, spells) as.data.frame(remove_arcs(net, from = sender(spells))), removed)
  expect_reference(arcs$ours, arcs$theirs, reference = "networkDynamic", covers = "remove_arcs()",
                   quantity = "spell after removing the first sender's arcs", tolerance = 1e-12,
                   key = c("seed", spell_key))
})

test_that("update_ties() shortening spells equals networkDynamic::deactivate.edges() of their tails", {
  skip_without_reference(nd_refs)
  # Every spell of at least two periods ends one period earlier.
  ours <- \(net, spells) {
    # update_ties() takes a condition on its spell table and one row of `data` per selected spell, in that order.
    chosen <- subset(as.data.frame(net), end - start >= 2)
    as.data.frame(update_ties(net, ties = end - start >= 2, data = data.frame(end = chosen$end - 1)))
  }
  theirs <- \(history, spells) {
    listed <- as.data.frame(history)
    shorten <- subset(listed, terminus - onset >= 2)
    # One call per spell: given an edge twice in one call, deactivate.edges() applies only one of its spells.
    nd_spells(Reduce(\(net, k) networkDynamic::deactivate.edges(net, e = shorten$edge.id[[k]],
                                                                onset = shorten$terminus[[k]] - 1,
                                                                terminus = shorten$terminus[[k]]),
                     seq_len(nrow(shorten)), history))
  }
  sides <- by_seed(ours, theirs)
  expect_reference(sides$ours, sides$theirs, reference = "networkDynamic", covers = "update_ties()",
                   quantity = "spell after shortening the long ones by one period", tolerance = 1e-12,
                   key = c("seed", spell_key))
})

test_that("induce_subgraph() equals network::get.inducedSubgraph() of five vertices", {
  skip_without_reference(nd_refs)
  chosen <- \(spells) utils::head(sort(unique(c(spells$from, spells$to))), 5L)
  theirs <- \(history, spells) {
    vertices <- network::get.vertex.attribute(history, "vertex.names")
    nd_spells(networkDynamic::as.networkDynamic(network::get.inducedSubgraph(history, v = match(chosen(spells), vertices))))
  }
  sides <- by_seed(\(net, spells) as.data.frame(induce_subgraph(net, nodes = chosen(spells))), theirs)
  expect_reference(sides$ours, sides$theirs, reference = "networkDynamic", covers = "induce_subgraph()",
                   quantity = "spell among five vertices", tolerance = 1e-12, key = c("seed", spell_key))
})

test_that("rename_nodes() equals setting networkDynamic's vertex.names", {
  skip_without_reference(nd_refs)
  theirs <- \(history, spells) {
    vertices <- network::get.vertex.attribute(history, "vertex.names")
    network::set.vertex.attribute(history, "vertex.names", ifelse(vertices == "Node 1", "First", vertices))
    nd_spells(history)
  }
  sides <- by_seed(\(net, spells) as.data.frame(rename_nodes(net, c(`Node 1` = "First"))), theirs)
  expect_reference(sides$ours, sides$theirs, reference = "networkDynamic", covers = "rename_nodes()",
                   quantity = "spell after renaming Node 1", tolerance = 1e-12, key = c("seed", spell_key))
})

test_that("remove_nodes(cascade = TRUE) equals network::delete.vertices()", {
  skip_without_reference(nd_refs)
  theirs <- \(history, spells) {
    network::delete.vertices(history, match("Node 2", network::get.vertex.attribute(history, "vertex.names")))
    nd_spells(history)
  }
  sides <- by_seed(\(net, spells) as.data.frame(remove_nodes(net, "Node 2", cascade = TRUE)), theirs)
  expect_reference(sides$ours, sides$theirs, reference = "networkDynamic", covers = "remove_nodes()",
                   quantity = "spell after removing Node 2", tolerance = 1e-12, key = c("seed", spell_key))
})

test_that("the vertex-spell verbs equal activate.vertices(), deactivate.vertices() and delete.vertex.activity()", {
  skip_without_reference(nd_refs)
  presence <- data.frame(node = c("Node 1", "Node 3", "Node 5"), start = c(0, 2, 6), end = c(12, 25, 18))
  vertex_key <- c("seed", "node", "start")
  activated <- \(history) {
    networkDynamic::delete.vertex.activity(history)
    vertices <- network::get.vertex.attribute(history, "vertex.names")
    networkDynamic::activate.vertices(history, onset = presence$start, terminus = presence$end,
                                      v = match(presence$node, vertices))
    history
  }
  read <- \(net) as.data.frame(net, what = "vertex_spells")
  added <- by_seed(\(net, spells) read(add_vertex_spells(net, presence)), \(history, spells) {
    nd_vertex_spells(activated(history))
  })
  expect_reference(added$ours, added$theirs, reference = "networkDynamic", covers = "add_vertex_spells()",
                   quantity = "vertex spell after adding three", tolerance = 1e-12, key = vertex_key)
  set <- by_seed(\(net, spells) read(set_vertex_spells(net, presence)), \(history, spells) {
    nd_vertex_spells(activated(history))
  })
  expect_reference(set$ours, set$theirs, reference = "networkDynamic", covers = "set_vertex_spells()",
                   quantity = "vertex spell after setting three", tolerance = 1e-12, key = vertex_key)
  # Node 3's presence ends at 8 instead of 25.
  updated <- by_seed(\(net, spells) {
    with_three <- add_vertex_spells(net, presence)
    read(update_vertex_spells(with_three, read(with_three)$node == "Node 3", data.frame(end = 8)))
  }, \(history, spells) {
    history <- activated(history)
    v3 <- match("Node 3", network::get.vertex.attribute(history, "vertex.names"))
    networkDynamic::deactivate.vertices(history, onset = 8, terminus = 25, v = v3)
    nd_vertex_spells(history)
  })
  expect_reference(updated$ours, updated$theirs, reference = "networkDynamic", covers = "update_vertex_spells()",
                   quantity = "vertex spell after ending Node 3's at 8", tolerance = 1e-12, key = vertex_key)
  removed <- by_seed(\(net, spells) {
    with_three <- add_vertex_spells(net, presence)
    read(remove_vertex_spells(with_three, read(with_three)$node == "Node 3"))
  }, \(history, spells) {
    history <- activated(history)
    v3 <- match("Node 3", network::get.vertex.attribute(history, "vertex.names"))
    networkDynamic::delete.vertex.activity(history, v = v3)
    subset(nd_vertex_spells(history), node != "Node 3")
  })
  expect_reference(removed$ours, removed$theirs, reference = "networkDynamic", covers = "remove_vertex_spells()",
                   quantity = "vertex spell after removing Node 3's", tolerance = 1e-12, key = vertex_key)
})

test_that("set_observations() and clear_observations() change the temporal density as tsna::tEdgeDensity() does", {
  skip_without_reference(c("tsna", nd_refs))
  declared <- \(history, lo, hi) {
    network::set.network.attribute(history, "net.obs.period",
                                   list(observations = list(c(lo, hi)), mode = "continuous", time.increment = NA,
                                        time.unit = "step"))
    history
  }
  density <- \(net) subset(as.data.frame(metrics(net, measure = "temporal_density", window = "all")),
                           select = c(measure, value))
  tsna_density <- \(history) data.frame(measure = "temporal_density",
                                        value = tsna::tEdgeDensity(history, mode = "duration", agg.unit = "dyad"))
  set <- by_seed(\(net, spells) density(set_observations(net, start = 0, end = 40)),
                 \(history, spells) tsna_density(declared(history, 0, 40)))
  expect_reference(set$ours, set$theirs, reference = "tsna", covers = c("set_observations()", "metrics()"),
                   quantity = "temporal density over a declared period 0 to 40", tolerance = 1e-12,
                   key = c("seed", "measure"))
  cleared <- by_seed(\(net, spells) density(clear_observations(set_observations(net, start = 0, end = 40))),
                     \(history, spells) tsna_density(history))
  expect_reference(cleared$ours, cleared$theirs, reference = "tsna", covers = c("clear_observations()", "metrics()"),
                   quantity = "temporal density after clearing the declared period", tolerance = 1e-12,
                   key = c("seed", "measure"))
})
