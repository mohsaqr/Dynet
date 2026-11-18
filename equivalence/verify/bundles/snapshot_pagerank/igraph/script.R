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
one_window <- function(lo) {
  long(lo, "pagerank", people, page_rank(snapshot(lo, lo + 7), directed = TRUE, damping = 0.85)$vector)
}
result <- do.call(rbind, lapply(c(0, 7, 14, 21), one_window))
head(result, 14)
