# The editing verbs: adding, removing and updating ties, inducing a subgraph, renaming vertices, and setting or
# clearing the observation period. Each edit of the bundled school_contacts network is compared with the same
# edit made on the spell list in base R (a ledger), so the resulting spell table, durations included, must agree.
# networkDynamic's importer is checked through as_dynet().

spells <- school_contacts
network <- dynet(school_contacts)
ledger <- "independent: the same edit made on the spell list, base R"
spell_key <- c("from", "to", "start")
with_duration <- \(table) transform(table, duration = end - start)

test_that("add_ties() and add_arcs() append the new spells", {
  extra <- data.frame(from = c("Ana", "Ben"), to = c("Ben", "Cara"), start = c(3.333, 4.444), end = c(5.5, 6.25))
  expected <- with_duration(rbind(spells, extra))
  # Sums of two-decimal times.
  expect_reference(as.data.frame(add_ties(network, extra)), expected, reference = ledger,
                   covers = "add_ties()", quantity = "spell after adding two", tolerance = 1e-10, key = spell_key)
  expect_reference(as.data.frame(add_arcs(network, extra)), expected, reference = ledger,
                   covers = "add_arcs()", quantity = "spell after adding two arcs", tolerance = 1e-10, key = spell_key)
})

test_that("remove_ties() and remove_arcs() drop every spell a pupil sends", {
  expected <- with_duration(subset(spells, from != "Ana"))
  expect_reference(as.data.frame(remove_ties(network, from = "Ana")), expected, reference = ledger,
                   covers = "remove_ties()", quantity = "spell after removing Ana's", tolerance = 1e-10, key = spell_key)
  expect_reference(as.data.frame(remove_arcs(network, from = "Ana")), expected, reference = ledger,
                   covers = "remove_arcs()", quantity = "spell after removing Ana's arcs", tolerance = 1e-10,
                   key = spell_key)
})

test_that("update_ties() rewrites the terminus of the selected spells", {
  expected <- with_duration(transform(spells, end = ifelse(from == "Ana", start + 0.05, end)))
  updated <- update_ties(network, ties = from == "Ana", data = data.frame(end = subset(spells, from == "Ana")$start + 0.05))
  expect_reference(as.data.frame(updated), expected, reference = ledger, covers = "update_ties()",
                   quantity = "spell after shortening Ana's", tolerance = 1e-10, key = spell_key)
})

test_that("induce_subgraph() keeps the spells among the chosen pupils", {
  chosen <- c("Ana", "Ben", "Cara", "Dan", "Eve")
  expected <- with_duration(subset(spells, from %in% chosen & to %in% chosen))
  expect_reference(as.data.frame(induce_subgraph(network, nodes = chosen)), expected, reference = ledger,
                   covers = "induce_subgraph()", quantity = "spell among five pupils", tolerance = 1e-10, key = spell_key)
})

test_that("rename_nodes() relabels a pupil in every spell", {
  renamed <- transform(spells, from = ifelse(from == "Ana", "Anna", from), to = ifelse(to == "Ana", "Anna", to))
  expect_reference(as.data.frame(rename_nodes(network, c(Ana = "Anna"))), with_duration(renamed), reference = ledger,
                   covers = "rename_nodes()", quantity = "spell after renaming Ana", tolerance = 1e-10, key = spell_key)
})

test_that("set_observations() and clear_observations() set and restore the observed period", {
  observed <- set_observations(network, start = 0, end = 30)
  stated <- data.frame(property = c("observed from", "observed to", "span"), value = c(0, 30, 30))
  read <- \(net) transform(subset(summary(net), property %in% stated$property), value = as.numeric(value))
  expect_reference(read(observed), stated, reference = ledger, covers = "set_observations()",
                   quantity = "observed period set to 0 to 30", tolerance = 0, key = "property")
  restored <- data.frame(property = stated$property, value = c(min(spells$start), max(spells$end),
                                                               max(spells$end) - min(spells$start)))
  expect_reference(read(clear_observations(observed)), restored, reference = ledger, covers = "clear_observations()",
                   quantity = "observed period back to the data's", tolerance = 1e-12, key = "property")
  # A longer observed period dilutes the temporal density: occupied pair-time over 14 * 13 * 30.
  pair <- paste(spells$from, spells$to)
  occupied <- sum(vapply(split(spells, pair), \(one) ref_union_length(one$start, one$end), numeric(1)))
  density <- as.data.frame(metrics(observed, measure = "temporal_density", window = "all"))
  expect_reference(density, data.frame(measure = "temporal_density", value = occupied / (14 * 13 * 30)), reference = ledger,
                   covers = c("set_observations()", "metrics()"), quantity = "temporal density over 0 to 30",
                   tolerance = 1e-12, key = "measure")
})

test_that("remove_nodes() with cascade drops a pupil and every spell it takes part in", {
  expected <- with_duration(subset(spells, from != "Ana" & to != "Ana"))
  expect_reference(as.data.frame(remove_nodes(network, "Ana", cascade = TRUE)), expected, reference = ledger,
                   covers = "remove_nodes()", quantity = "spell after removing Ana", tolerance = 1e-10, key = spell_key)
})

test_that("the vertex-spell verbs add, set, update and remove periods of presence", {
  presence <- data.frame(node = c("Ana", "Ben", "Cara"), start = c(0, 1.5, 3.25), end = c(10, 12, 21.52))
  read <- \(net) as.data.frame(net, what = "vertex_spells")
  expected <- transform(presence, duration = end - start)
  vertex_key <- c("node", "start")
  added <- add_vertex_spells(network, presence)
  expect_reference(read(added), expected, reference = ledger, covers = "add_vertex_spells()",
                   quantity = "vertex spell after adding three", tolerance = 1e-12, key = vertex_key)
  expect_reference(read(set_vertex_spells(network, presence)), expected, reference = ledger,
                   covers = "set_vertex_spells()", quantity = "vertex spell after setting three", tolerance = 1e-12,
                   key = vertex_key)
  updated <- transform(expected, end = ifelse(node == "Ben", 8, end), duration = ifelse(node == "Ben", 8 - start, duration))
  # These two verbs take positions or a logical mask over the vertex-spell table, not a condition.
  bens <- read(added)$node == "Ben"
  expect_reference(read(update_vertex_spells(added, bens, data.frame(end = 8))), updated, reference = ledger,
                   covers = "update_vertex_spells()", quantity = "vertex spell after ending Ben's at 8",
                   tolerance = 1e-12, key = vertex_key)
  expect_reference(read(remove_vertex_spells(added, bens)), subset(expected, node != "Ben"), reference = ledger,
                   covers = "remove_vertex_spells()", quantity = "vertex spell after removing Ben's", tolerance = 1e-12,
                   key = vertex_key)
})

test_that("as_dynet() reads a networkDynamic object's spells as networkDynamic lists them", {
  skip_without_reference(c("networkDynamic", "network"))
  history <- ref_network_dynamic(spells)
  listed <- as.data.frame(history)
  vertices <- network::get.vertex.attribute(history, "vertex.names")
  theirs <- data.frame(from = vertices[listed$tail], to = vertices[listed$head], start = listed$onset,
                       end = listed$terminus, duration = listed$duration)
  expect_reference(as.data.frame(as_dynet(history)), theirs, reference = "networkDynamic",
                   covers = c("as_dynet()", "as_dynet.networkDynamic()"), quantity = "spell", tolerance = 1e-10,
                   key = spell_key)
})

test_that("the spell table after removing Ana's spells against the full ledger differs (negative control)", {
  expect_differs(nrow(as.data.frame(remove_ties(network, from = "Ana"))), nrow(spells), reference = ledger,
                 covers = "remove_ties()", quantity = "number of spells, removal against no removal", tolerance = 0.5)
})
