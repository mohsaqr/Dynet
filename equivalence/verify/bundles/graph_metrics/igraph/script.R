library(igraph)
contacts <- utils::read.delim("../data/school_contacts.tsv")
people <- sort(unique(c(contacts$from, contacts$to)))
snapshot <- function(lo, hi) {
  active <- contacts[contacts$start < hi & contacts$end > lo, c("from", "to")]
  simplify(graph_from_data_frame(active, directed = TRUE, vertices = people))
}
long <- function(time, measure, name, value) {
  data.frame(quantity = sprintf("%s t=%g: %s", measure, time, name), kind = measure, value = as.numeric(value))
}
triad_classes <- paste0("triad_", c("003", "012", "102", "021D", "021U", "021C", "111D", "111U",
                                     "030T", "030C", "201", "120D", "120U", "120C", "210", "300"))
one_window <- function(lo) {
  graph <- snapshot(lo, lo + 7)
  dyads <- dyad_census(graph)
  value <- c(edges = ecount(graph), density = edge_density(graph), reciprocity = reciprocity(graph),
             components = count_components(graph, mode = "weak"),
             components_strong = count_components(graph, mode = "strong"),
             isolates = sum(degree(graph, mode = "all") == 0), mutual = dyads$mut, asymmetric = dyads$asym,
             null = dyads$null, mean_distance = mean_distance(graph, directed = TRUE, unconnected = TRUE),
             diameter = diameter(graph, directed = TRUE, unconnected = TRUE),
             setNames(triad_census(graph), triad_classes))
  data.frame(quantity = sprintf("%s t=%g", names(value), lo), kind = names(value), value = unname(value))
}
result <- do.call(rbind, lapply(c(0, 7, 14, 21), one_window))
head(result, 27)
