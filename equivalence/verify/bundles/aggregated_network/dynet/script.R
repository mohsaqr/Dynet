library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
nodes <- centrality_series(network, measure = c("degree", "strength", "betweenness", "coreness"),
                           mode = "all", window = "all")
nodes
near <- centrality_series(network, measure = "closeness", mode = "out", window = "all")
near
graph <- metrics(network, measure = c("edges", "density", "reciprocity", "mean_distance", "diameter"),
                 window = "all")
graph
result <- rbind(
  transform(as.data.frame(nodes), quantity = sprintf("%s: %s", measure, node), kind = measure, node = NULL),
  transform(as.data.frame(near), quantity = sprintf("%s: %s", measure, node), kind = measure, node = NULL),
  transform(as.data.frame(graph), quantity = measure, kind = "graph"))
