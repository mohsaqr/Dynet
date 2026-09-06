# Extracted from test-vertex-snapshot-contract.R:257

# prequel ----------------------------------------------------------------------
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

# test -------------------------------------------------------------------------
edges <- data.frame(from = "A", to = "B", start = 0, end = 4)
nodes <- data.frame(name = c("A", "B", "C"))
empty <- quiet_dynet(edges, nodes = nodes, vertex_spells = data.frame(
    node = c("A", "B", "C"), start = 0, end = 1
  ))
measures <- setdiff(Dynet:::.node_measures, c("indegree", "outdegree"))
got <- as.data.frame(dyn_centrality(
    empty, measures, start = 2, end = 2, step = 1, window = 0
  ))
expect_true(all(is.na(got$value)))
singleton <- quiet_dynet(edges, nodes = nodes, vertex_spells = data.frame(
    node = c("A", "B", "C"), start = c(2, 0, 0), end = c(3, 1, 1)
  ))
one <- as.data.frame(dyn_centrality(
    singleton, measures, start = 2, end = 2, step = 1, window = 0
  ))
