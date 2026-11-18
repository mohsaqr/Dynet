library(igraph)
contacts <- utils::read.delim("../data/school_contacts.tsv")
people <- sort(unique(c(contacts$from, contacts$to)))
spells <- graph_from_data_frame(data.frame(contacts[c("from", "to")], weight = 1), directed = TRUE,
                                vertices = people)
graph <- simplify(spells, edge.attr.comb = list(weight = "sum"))
graph
near <- closeness(graph, mode = "out", normalized = TRUE, weights = NA)
near[is.nan(near)] <- 0
nodes <- list(degree = degree(graph, mode = "all"), strength = strength(graph, mode = "all"),
              betweenness = betweenness(graph, directed = TRUE, weights = NA),
              coreness = coreness(graph, mode = "all"), closeness = near)
whole <- c(edges = ecount(graph), density = edge_density(graph), reciprocity = reciprocity(graph),
           mean_distance = mean_distance(graph, directed = TRUE, unconnected = TRUE, weights = NA),
           diameter = diameter(graph, directed = TRUE, unconnected = TRUE, weights = NA))
result <- rbind(
  do.call(rbind, Map(function(value, measure) {
    data.frame(quantity = sprintf("%s: %s", measure, people), kind = measure, value = as.numeric(value))
  }, nodes, names(nodes))),
  data.frame(quantity = names(whole), kind = "graph", value = unname(whole)))
result
