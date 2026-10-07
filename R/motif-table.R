# ===========================================================================
# The Paranjape (2017) 3-node, 3-edge motif taxonomy
# ===========================================================================
# DERIVED, NOT TRANSCRIBED. This table was produced by brute force against
# raphtory 0.17.0 on 2026-09-20: every canonical three-edge sequence on at
# most three nodes was built as a raphtory graph and classified by
# `global_temporal_three_node_motif` and `local_temporal_three_node_motifs`
# with a delta large enough to admit it. Copying raphtory's ordering verbatim
# is what makes the census falsifiable -- a user can compare a Dynet run with
# a raphtory run index by index. Inventing an ordering would not be checkable
# against anything.
#
# Key: the three edges in time order, each written as <source><target> using
# canonical node labels 0, 1, 2 assigned by order of first appearance across
# (e1 source, e1 target, e2 source, e2 target, e3 source, e3 target).
#
# `global`: the 1-based index or indices the instance adds one to.
# `local`:  "<canonical node>:<index>" pairs, the per-vertex attribution.
#
# Note the counting rules this encodes, which are raphtory's and are NOT
# uniform across families:
#   star      one global index; only the centre counts it locally.
#   two-node  TWO global indices, one per endpoint; each endpoint counts its
#             own. So the local sum equals the global sum, not twice it.
#   triangle  one global index; all three vertices count it, so the local sum
#             is three times the global one.

.motif_lookup <- list(
  "010101" = list(global = c(25,32), local = "1:32,2:25"),
  "010102" = list(global = c(8), local = "1:8"),
  "010110" = list(global = c(26,31), local = "1:31,2:26"),
  "010112" = list(global = c(2), local = "2:2"),
  "010120" = list(global = c(7), local = "1:7"),
  "010121" = list(global = c(1), local = "2:1"),
  "010201" = list(global = c(16), local = "1:16"),
  "010202" = list(global = c(24), local = "1:24"),
  "010210" = list(global = c(15), local = "1:15"),
  "010212" = list(global = c(39), local = "1:39,2:39,3:39"),
  "010220" = list(global = c(23), local = "1:23"),
  "010221" = list(global = c(40), local = "1:40,2:40,3:40"),
  "011001" = list(global = c(27,30), local = "1:30,2:27"),
  "011002" = list(global = c(6), local = "1:6"),
  "011010" = list(global = c(28,29), local = "1:29,2:28"),
  "011012" = list(global = c(4), local = "2:4"),
  "011020" = list(global = c(5), local = "1:5"),
  "011021" = list(global = c(3), local = "2:3"),
  "011201" = list(global = c(11), local = "2:11"),
  "011202" = list(global = c(35), local = "1:35,2:35,3:35"),
  "011210" = list(global = c(12), local = "2:12"),
  "011212" = list(global = c(20), local = "2:20"),
  "011220" = list(global = c(36), local = "1:36,2:36,3:36"),
  "011221" = list(global = c(19), local = "2:19"),
  "012001" = list(global = c(14), local = "1:14"),
  "012002" = list(global = c(22), local = "1:22"),
  "012010" = list(global = c(13), local = "1:13"),
  "012012" = list(global = c(37), local = "1:37,2:37,3:37"),
  "012020" = list(global = c(21), local = "1:21"),
  "012021" = list(global = c(38), local = "1:38,2:38,3:38"),
  "012101" = list(global = c(9), local = "2:9"),
  "012102" = list(global = c(33), local = "1:33,2:33,3:33"),
  "012110" = list(global = c(10), local = "2:10"),
  "012112" = list(global = c(18), local = "2:18"),
  "012120" = list(global = c(34), local = "1:34,2:34,3:34"),
  "012121" = list(global = c(17), local = "2:17")
)
