# Changelog

## Dynet 0.4.4

- Every example, the README, both vignettes and the reproductions are
  written one call per line: a verb’s result is named, and the next verb
  takes that object. No call is nested inside another. Nothing computed
  changed.

## Dynet 0.4.3

- [`remove_ties()`](https://mohsaqr.github.io/Dynet/reference/remove_ties.md),
  [`remove_arcs()`](https://mohsaqr.github.io/Dynet/reference/remove_arcs.md)
  and
  [`update_ties()`](https://mohsaqr.github.io/Dynet/reference/update_ties.md)
  take `ties` as a condition on the spell table (`ties = duration > 2`),
  as
  [`induce_subgraph()`](https://mohsaqr.github.io/Dynet/reference/induce_subgraph.md)
  already did; positions and masks still work.
- On an undirected network a tie keeps its row position through an edit:
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md) now
  canonicalises endpoints before sorting, the order every rebuild uses,
  so `update_ties(ties = 1:2)` edits the rows the caller saw.
- Bonacich power and information centrality on a singular system return
  `NA` under a warning of class `dynet_kernel_singular` instead of
  silently; the spectral warning and this one share the parent class
  `dynet_measure_undefined`.
- The `sample` and `indegree`/`outdegree` deprecation warnings carry
  class `dynet_deprecated`; the duplicate-`nodes` warning carries
  `dynet_duplicate_nodes`.
- Documentation states what was previously only implemented:
  assortativity correlates total degree at both ends of every arc;
  closeness centralisation uses this package’s reachable-set closeness
  with maxima `n - 1` (directed) and `n - 2` (undirected);
  [`pshifts()`](https://mohsaqr.github.io/Dynet/reference/pshifts.md)
  orders simultaneous turns by speaker, group turn, then target in
  vertex order; temporal closeness is `Inf` when every reachable vertex
  is reached at zero latency; co-presence connects every member pair for
  the whole group span.

## Dynet 0.4.2

- `eigenvector`, `hub` and `authority` are certified like eigenvector
  prestige: a snapshot whose spectral radius is zero or whose Perron
  root is repeated returns `NA` for that block under a warning of class
  `dynet_eigen_undefined`, instead of one arbitrary basis vector.
- [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md) picks
  up a column named `weight`, `weights` or `strength` as the tie weight
  and says so; before, an unnamed weight column was silently replaced by
  ones.
- `window = 0` on the default grid now samples through the last observed
  instant, as `tsna` does; a positive window is unchanged.

## Dynet 0.4.1

- Plot defaults: node-level bar charts and the frequency trajectory tree
  colour by vertex, in the network’s own order, so a vertex keeps one
  colour across every view; `plot(dn, type = "timeline")` and `"events"`
  take `step`, a bin width (`1/24` on a network in days is hourly), and
  the timeline is clipped to the declared observation window;
  [`collapse_network()`](https://mohsaqr.github.io/Dynet/reference/collapse_network.md)
  and
  [`path_network()`](https://mohsaqr.github.io/Dynet/reference/path_network.md)
  results have [`plot()`](https://rdrr.io/r/graphics/plot.default.html)
  methods with Dynet’s rendering defaults, so
  `plot(collapsed, layout = "oval")` is the whole call.
- [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md) keeps
  every column of the log it did not consume as a tie attribute, for
  interval, contact and threaded logs, so
  `induce_subgraph(ties = group == "A_01")` works on a freshly built
  network as it already did after
  [`as_dynet()`](https://mohsaqr.github.io/Dynet/reference/as_dynet.md)
  and
  [`add_ties()`](https://mohsaqr.github.io/Dynet/reference/add_ties.md).
- `dynet(thread_clock = "relative")` puts each thread of a threaded log
  on its own clock, measured from the thread’s first post: the *Trees of
  Thought* construction in one call.
- Reproduction `inst/reproduction/thought-chains/thought_chains.Rmd`:
  the Trees of Thought analysis on the bundled `thought_chains`, with a
  gallery of every temporal view and result plot.
- New bundled dataset `thought_chains`: the Trees of Thought reply table
  (code of a message to the code of the message it answers) with
  identities stripped, the bottom 20% of authors trimmed, the two sparse
  weekdays removed, the calendar shifted by whole weeks, and Evaluation
  merged with Acceptance into Approving. 23,017 links, 240 participants,
  nine codes.
- Window edges are snapped onto the data’s own boundaries. A grid built
  as `start + k * step` with a step such as `1/24` fell one ulp short of
  the exact spell boundaries a date-converted network carries, so a
  spell ending exactly at a window’s start was counted inside it.
  Integer-hour and `POSIXct`-hour encodings of one network now give
  identical series (`tests/testthat/test-bin-edge-snap.R`).

## Dynet 0.4.0

- New verb
  [`pathways()`](https://mohsaqr.github.io/Dynet/reference/pathways.md):
  whole time-respecting routes ranked by how often they are used, with
  `print`, `summary`, `plot` and `as.data.frame(what = "steps")`.
- `plot = TRUE` on the thirteen measurement verbs draws as a side effect
  and still returns the tidy table, in the manner of
  [`hist()`](https://rdrr.io/r/graphics/hist.html).
- `induce_subgraph(ties = )` takes a condition on the spell table, as
  `nodes =` already did.
- `as.data.frame(x, what = "diagnostics")` exposes the prestige
  diagnostics; `dynet_pshifts` and `dynet_collapsed_list` gained the
  full method set and `as.data.frame(x, session = )` reaches one session
  by argument.
- New bundled dataset `synthdata`, a resampled synthetic twin of the
  Trees of Thought interaction data, with the reproduction under
  `inst/reproduction/`.
- The dependency floor is R \>= 4.1; the package defines its own `%||%`.
  Continuous checking on macOS, Windows and Linux (devel, release,
  oldrel-1, and a pinned 4.1).
- Events landing just past a bin boundary are no longer discarded; the
  final default window is closed on its right edge.
- Two wrong-output defects found by adversarial review were fixed, and
  the internal helper pages were removed from the manual.

## Dynet 0.3 series

- The
  [`similarity()`](https://mohsaqr.github.io/Dynet/reference/similarity.md)
  verb, centrality `mode` (`"all"`, `"out"`, `"in"`), node selection by
  condition, temporal reach, closeness and betweenness, bounded and
  session-aware path searches, per-hop traversal time, and the first two
  vignettes.
- Public verbs dropped the `dyn_` prefix except
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md)
  and
  [`dyn_reachability()`](https://mohsaqr.github.io/Dynet/reference/dyn_reachability.md).

## Dynet 0.2.0

- First tidy, name-addressed release: one constructor for interval,
  contact, threaded and co-presence logs; every verb returns a
  one-row-per-observation data frame; values checked against the statnet
  ecosystem.
