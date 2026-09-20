# Reference censuses from raphtory 0.17.0, generated live on 2026-09-20
# (python 3.14.4). Indices are converted to R's 1-based convention by adding 1
# to raphtory's 0-based output.
#
# Generating python, per case:
#   from raphtory import Graph
#   from raphtory import algorithms as algo
#   g = Graph()
#   for s, d, t in edges: g.add_edge(t, s, d)
#   algo.global_temporal_three_node_motif(g, delta=delta)
#
# The full 40-class lookup in R/motif-table.R was derived the same way, by
# enumerating every canonical three-edge sequence on at most three nodes and
# recording which class raphtory assigned it, globally and per vertex. That is
# why the taxonomy is checkable rather than asserted.
list(
  triangle_d10 = list(
    edges = data.frame(from = c("A", "B", "A"), to = c("B", "C", "C"),
                       time = c(1, 2, 3)),
    delta = 10, nonzero = 35L),
  # delta spans first-to-last, not consecutive gaps: 3 - 1 = 2 > 1.
  triangle_d1 = list(
    edges = data.frame(from = c("A", "B", "A"), to = c("B", "C", "C"),
                       time = c(1, 2, 3)),
    delta = 1, nonzero = integer(0)),
  # One two-node instance registers at BOTH endpoints' classes.
  two_node_repeat = list(
    edges = data.frame(from = c("A", "A", "A"), to = c("B", "B", "B"),
                       time = c(1, 2, 3)),
    delta = 10, nonzero = c(25L, 32L)),
  pre_star_OOO = list(
    edges = data.frame(from = c("A", "A", "A"), to = c("B", "B", "C"),
                       time = c(1, 2, 3)),
    delta = 10, nonzero = 8L),
  mid_star_OOO = list(
    edges = data.frame(from = c("A", "A", "A"), to = c("B", "C", "B"),
                       time = c(1, 2, 3)),
    delta = 10, nonzero = 16L),
  post_star_OOO = list(
    edges = data.frame(from = c("A", "A", "A"), to = c("B", "C", "C"),
                       time = c(1, 2, 3)),
    delta = 10, nonzero = 24L),
  triangle_class1 = list(
    edges = data.frame(from = c("A", "C", "A"), to = c("B", "B", "C"),
                       time = c(1, 2, 3)),
    delta = 10, nonzero = 33L),
  # Four edges give choose(4, 3) = 4 overlapping instances; instances may
  # share edges, which is Paranjape's rule and raphtory's.
  overlap_four_edge = list(
    edges = data.frame(from = c("A", "B", "A", "A"), to = c("B", "C", "C", "B"),
                       time = c(1, 2, 3, 4)),
    delta = 10, nonzero = c(11L, 16L, 34L, 35L))
)
