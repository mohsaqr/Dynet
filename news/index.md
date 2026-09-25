# Changelog

## Dynet 0.4.13

### Breaking changes

- [`dyn_reachability()`](https://pak.dynasite.org/Dynet/reference/dyn_reachability.md)
  is renamed
  [`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md).
  The old name still works, forwards every argument unchanged and warns
  with class `dynet_deprecated`; it will be removed in a future release.
  Note that `sna` also exports a
  [`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md):
  with both attached, the one attached last wins, so call
  [`Dynet::reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md)
  when in doubt.

- [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
  is split in two, because its two scopes returned different things.
  [`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md)
  is the old default (`scope = "snapshot"`): centrality in every window,
  a series per vertex.
  [`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md)
  is the old `scope = "temporal"` for `"closeness"` and `"betweenness"`:
  one value per vertex from time-respecting paths across the period,
  with no `time` column. Temporal `"reach"` and `"reach_count"` are
  [`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md).
  Neither new function has a `scope` argument, so each returns one
  shape. `path_centrality(plot = TRUE)` now draws, which the old
  temporal scope silently ignored.
  [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
  still works, returns exactly what it returned before and warns with
  class `dynet_deprecated`. The new names avoid
  [`cograph::centrality()`](https://sonsoles.me/cograph/reference/centrality.html)
  and `tna::centralities()`.

- `centrality_series(measure = "strength")` now weights each spell by
  the share of its duration inside the window
  (`weight * overlap / duration`) instead of counting its full weight in
  every window it touches. Tiled windows therefore add back up to the
  network’s total weight rather than counting a long spell once per
  window. Point contacts keep their full weight in the window that holds
  them, `window = 0` still uses full weights at the instant, and the
  part of a spell outside the observation period is not reassigned to
  observed windows. Degree and every binary measure are unchanged.
  [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md),
  [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md) and
  the network plots still count each spell’s full weight in every bin it
  touches, as
  [`networkDynamic::network.collapse()`](https://rdrr.io/pkg/networkDynamic/man/network.collapse.html)
  does; their documentation now says so.

- `plot(type = "events")` marks where each link starts the way cograph’s
  TNA styling does: the first 20% of each link, from its source, is
  dotted. The new `edge_start_style` and `edge_start_length` arguments,
  named as in
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html),
  change or turn off the mark. Row labels are now drawn in their actor’s
  colour, so they work as the colour key, and nodes are larger.

### Bug fixes

- [`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md)’
  `"temporal_density"`, `"observed_pair_density"`, `"onset_intensity"`
  and `"observed_pair_onset_intensity"` no longer count time after the
  data end as exposure. Without explicit observation bounds, a last
  window reaching past the final spell divided by its full width, so
  tiled windows did not pool to the whole-period value. Integration now
  stops at the observation period, which defaults to the data’s span, as
  [`tsna::tEdgeDensity()`](https://rdrr.io/pkg/tsna/man/density.html)
  does. On `school_contacts` with weekly windows the final partial
  week’s temporal density goes from 0.0013 to 0.0181; explicit
  `observation_end` values are honoured as before.

- [`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md)’
  `"concurrent_nodes"` and `"concurrent_share"` now require
  simultaneity. With a positive `window` they were read from the
  window’s union snapshot, so a vertex tied to one partner early in the
  window and to another later was counted as concurrent although the two
  ties never overlapped. A vertex now counts when relations to two
  distinct neighbours are active at the same instant somewhere in the
  window; spells that only meet at a boundary do not overlap, and a
  point contact is concurrent with whatever is active at its timestamp.
  `window = 0` results are unchanged. The result records the rule in the
  `concurrency_window_rule` attribute.
  [`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) is
  unaffected: it counts group pairs connected anywhere in the window and
  never implied simultaneity.

## Dynet 0.4.12

### Breaking changes

- In a threaded log, a self-reply that `loops = FALSE` drops is now
  removed before the thread’s lifetime is computed, so a dropped post no
  longer keeps its thread alive. Threaded networks built from logs with
  self-replies can have shorter spells than before; `loops = TRUE` is
  unchanged.

### New features

- [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) gains
  `min_thread_posts`: for a threaded log, threads with fewer surviving
  posts are dropped whole and reported with a message, so the “threads
  that never became an exchange” rule of the chapter-17 analysis is one
  argument rather than a hand-written filter. Requires `thread`; a value
  below 1 or a non-threaded log raises `dynet_bad_input` /
  `dynet_needs_thread`.
- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on a
  [`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md)
  result accepts a group name in `highlight`, which colours every flow
  into or out of that group. A `highlight` that matches no series raises
  `dynet_unknown_highlight` instead of drawing everything grey.
- `mooc_people` carries `expert_level`, the chapter’s label for the
  experience code, so the mixing attribute needs no recode.
- The website article that rebuilt the MOOC network from the published
  CSV files was removed;
  [`vignette("ch17-temporal-networks")`](https://pak.dynasite.org/Dynet/articles/ch17-temporal-networks.md)
  builds the same network from the bundled data in one call. The site
  deploy now clears files that are no longer built.
- [`set_tie_sessions()`](https://pak.dynasite.org/Dynet/reference/set_tie_sessions.md)
  gains `breaks` and `labels`: sessions can be cut on the time axis
  (`breaks = c(7, 14)` gives three weeks) instead of being derived by
  hand as a column and matched positionally against the spell table.

## Dynet 0.4.7

### Breaking changes

- [`add_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/add_vertex_spells.md)
  and
  [`update_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/update_vertex_spells.md)
  now refuse input they cannot honour instead of accepting it silently.
  Supplying `session` to a network with no session scheme raises
  `dynet_incompatible_vertex_spells` rather than dropping the label;
  [`add_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/add_vertex_spells.md)
  used to discard it and return normally while
  [`update_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/update_vertex_spells.md)
  already errored on the same input. Supplying a column outside the
  vertex-spell schema to
  [`update_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/update_vertex_spells.md)
  raises `dynet_unknown_column` rather than returning the object
  unchanged, so a misspelled field is no longer a silent no-op.

### Performance

- [`summary()`](https://rdrr.io/r/base/summary.html) gains
  `temporal_density`, `FALSE` by default. That one row integrates exact
  occupancy over every eligible ordered pair, so its cost is quadratic
  in the vertex count: on a 442-vertex forum network it alone took about
  32 seconds, while the other fourteen rows were immediate. It now reads
  `"not computed"` unless asked for, and
  [`summary()`](https://rdrr.io/r/base/summary.html) on that network
  takes 0.3 seconds. Pass `temporal_density = TRUE` for the number.

### Bug fixes

- [`as_dynet()`](https://pak.dynasite.org/Dynet/reference/as_dynet.md)
  placed per-edge attributes on the wrong spell when importing an
  **undirected** `networkDynamic`.
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md)
  canonicalises an undirected pair before sorting its spells, and the
  importer derived its ordering from the raw tail and head, so the two
  permutations disagreed whenever the endpoints were stored in the other
  order. Attributes now follow the canonical endpoints.

- [`remove_ties()`](https://pak.dynasite.org/Dynet/reference/remove_ties.md)
  matched the `start` and `end` selectors with exact equality on
  doubles, so a spell that accumulated as `0.1 + 0.1 + 0.1` could not be
  removed by naming `0.3`. Times are now compared with the same
  magnitude-relative tolerance the rest of the package uses.

- `dyn_centrality(measure = "closeness", scope = "temporal")` returned
  `Inf` without a word when every reachable vertex was joined within one
  instant. `Inf` is still returned, since it is the honest limit, but a
  `dynet_zero_latency` warning now accompanies it.

### Documentation

- Five statements that contradicted the code are corrected: kept
  self-loops **are** counted by degree and contribute two,
  `snapshots(at = )` can return zero rows when the nearest bin holds no
  active tie, `animate(seed = NULL)` leaves the caller’s random state
  advanced rather than restored, `similarity(sessions = "separate")`
  adds no session column, and only one of the four Krackhardt indices is
  an index of hierarchy.

- [`set_tie_sessions()`](https://pak.dynasite.org/Dynet/reference/set_tie_sessions.md)
  now documents that a full-length vector is matched positionally
  against the **sorted spell table**, not against the data frame the
  network was built from. Derive labels from `as.data.frame(dn)`.

- [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) now
  documents that canonical spell column names – `duration`, `weight`,
  `session`, `thread`, `onset_censored`, `terminus_censored` – are
  dropped from tie attributes even when never named as arguments.

- Internal specification identifiers that had leaked into the manual
  pages with no definition anywhere are replaced by the measure names
  they referred to.

## Dynet 0.4.6

- New verb
  [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md):
  the measurement grid as a film, written to a GIF (`gifski`) or an mp4
  or webm video (`av`), chosen by the extension of `file`. It takes the
  same four grid arguments as every measuring verb, so an animation
  shows exactly what
  [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
  tabulates and what `plot(dn, type = "snapshots")` draws as a
  filmstrip, and a test pins that the three agree bin for bin.

  Each bin is drawn `tween` times, six by default. Between bins the
  vertices glide along the smoothstep curve, a tie about to appear fades
  in dotted and green, one about to vanish fades out dashed and
  vermilion, and with `measure =` node size follows a snapshot measure
  from
  [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
  on the same grid. Tie width follows weight on one scale fixed across
  the whole animation, so the same weight has the same width in every
  frame. A vertex not present in a bin is drawn as `absent` says: faded
  in place, parked out of sight at the edge of the layout and gliding in
  when it arrives and out when it leaves, or hidden; a present vertex
  with no tie is drawn as `isolates` says. A timeline strip under the
  network shows the grid, a marker at the current time, and the key;
  both the tie states and the strip can be turned off.

  Five layouts and a coordinate table. `"spring"`, the default, lays out
  the union of every bin once; `"circle"`, `"oval"` and `"groups"` are
  rings; `"relaxed"` re-runs
  [`cograph::layout_spring()`](https://sonsoles.me/cograph/reference/layout_spring.html)
  per bin, seeded from the bin before it and held within
  `max_displacement`, then smooths every vertex’s path with a centred
  triangular kernel, which halved the direction reversals between
  consecutive moves on `school_contacts` at a two per cent cost in
  structure. Under every layout but `"relaxed"` a vertex never moves,
  and every layout covers the whole vertex set, so a vertex never
  changes place because its neighbours came and went.

  The file goes to [`tempfile()`](https://rdrr.io/r/base/tempfile.html)
  unless `file` says otherwise, so nothing reaches the working directory
  by accident. `gifski` and `av` are Suggests; without the one the
  extension needs the verb raises `dynet_needs_gifski` or
  `dynet_needs_av`, and an extension it cannot write raises
  `dynet_unknown_format`. A bin holding nothing to draw is skipped with
  a message that counts the skipped bins. The tidy bin table comes back
  invisibly, one row per bin with `time`, `nodes`, `ties`, `forming`,
  `dissolving` and the bin’s first rendered `frame`, as class
  `dynet_animation` with [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html) and
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html);
  `as.data.frame(x, what = "frames")` maps every rendered frame to its
  time.

- New website article *Animating a temporal network*, a tutorial on
  [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md)
  over the classroom and the MOOC forum data.

- `set_vertex_spells(dn, "ties")` declares each vertex present from the
  start of its first tie spell to the end of its last, so a network
  built from a tie log alone can say when each vertex arrived and left.

- New vignette `ch17-temporal-networks`: chapter 17 of *Learning
  Analytics Methods and Tutorials* (Saqr, 2024), “Temporal network
  analysis: Introduction, methods and analysis with R”, re-run with
  Dynet’s verbs in the chapter’s own order – build, active subnetwork,
  visualisation, graph-level and node-level measures, reachability,
  mixing. Its data is bundled as `mooc_posts` (2529 posts across 338
  discussion threads of a MOOC forum, April to June 2013) and
  `mooc_people` (445 participants with their experience level), so the
  vignette reaches no network at render time. The two places where the
  chapter’s own code changes its numbers – the thread spell rule, and
  ties admitted before single-post discussions are dropped – are named
  and measured rather than reproduced.

- Backward routes on interval spells keep the route family of an
  unattained supremum. An interval spell is half-open, so the latest
  departure into a target is a supremum no journey reaches exactly.
  `paths(direction = "backward")` used to report `NA` hops, zero paths
  and no steps for such a vertex, which left every backward trajectory
  tree on interval data drawing only its source. The family that
  approaches the supremum is now reported in full – hops, exact path
  count and reconstructed steps – and `attained` is what records that
  the instant itself is not realised. Route reconstruction under
  `sessions = "bounded"` and `sessions = "separate"` is unchanged.

- Reachability is anchored at each vertex’s own presence. With vertex
  spells declared,
  [`dyn_reachability()`](https://pak.dynasite.org/Dynet/reference/dyn_reachability.md),
  `dyn_centrality(scope = "temporal")` and the default origin of
  [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) start a
  vertex’s forward search at its first appearance inside the window and
  its backward search at its last, instead of at the window bound. A
  vertex that entered the network late no longer scores zero; a backward
  search may anchor at the instant a vertex leaves. An explicit `at` is
  still used exactly.

- `dynet(nodes = )` names the vertices from a node table whose key is
  not `name` but which has a `name` column, as
  `network(vertex.attrnames = )` does: edge endpoints and vertex spells
  given by the key are translated, and the key stays on the node table
  as an attribute. `vertex.id`, `node`, `vertex` and `node.id` are
  recognised as vertex keys.

- `dynet(vertex_spells = )` resolves its node, start and end columns
  through the alias table and ignores other columns, so a node table
  with `onset` and `terminus` columns is accepted as it is.

- [`rename_nodes()`](https://pak.dynasite.org/Dynet/reference/rename_nodes.md)
  takes the name of a vertex attribute whose values become the node
  names.

## Dynet 0.4.4

- Every example, the README, both vignettes and the reproductions are
  written one call per line: a verb’s result is named, and the next verb
  takes that object. No call is nested inside another. Nothing computed
  changed.

## Dynet 0.4.3

- [`remove_ties()`](https://pak.dynasite.org/Dynet/reference/remove_ties.md),
  [`remove_arcs()`](https://pak.dynasite.org/Dynet/reference/remove_arcs.md)
  and
  [`update_ties()`](https://pak.dynasite.org/Dynet/reference/update_ties.md)
  take `ties` as a condition on the spell table (`ties = duration > 2`),
  as
  [`induce_subgraph()`](https://pak.dynasite.org/Dynet/reference/induce_subgraph.md)
  already did; positions and masks still work.
- On an undirected network a tie keeps its row position through an edit:
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) now
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
  [`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md)
  orders simultaneous turns by speaker, group turn, then target in
  vertex order; temporal closeness is `Inf` when every reachable vertex
  is reached at zero latency; co-presence connects every member pair for
  the whole group span.

## Dynet 0.4.2

- `eigenvector`, `hub` and `authority` are certified like eigenvector
  prestige: a snapshot whose spectral radius is zero or whose Perron
  root is repeated returns `NA` for that block under a warning of class
  `dynet_eigen_undefined`, instead of one arbitrary basis vector.
- [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) picks
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
  [`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md)
  and
  [`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md)
  results have [`plot()`](https://rdrr.io/r/graphics/plot.default.html)
  methods with Dynet’s rendering defaults, so
  `plot(collapsed, layout = "oval")` is the whole call.
- [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) keeps
  every column of the log it did not consume as a tie attribute, for
  interval, contact and threaded logs, so
  `induce_subgraph(ties = group == "A_01")` works on a freshly built
  network as it already did after
  [`as_dynet()`](https://pak.dynasite.org/Dynet/reference/as_dynet.md)
  and
  [`add_ties()`](https://pak.dynasite.org/Dynet/reference/add_ties.md).
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
  [`pathways()`](https://pak.dynasite.org/Dynet/reference/pathways.md):
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
  [`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md)
  verb, centrality `mode` (`"all"`, `"out"`, `"in"`), node selection by
  condition, temporal reach, closeness and betweenness, bounded and
  session-aware path searches, per-hop traversal time, and the first two
  vignettes.
- Public verbs dropped the `dyn_` prefix except
  [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
  and
  [`dyn_reachability()`](https://pak.dynasite.org/Dynet/reference/dyn_reachability.md).

## Dynet 0.2.0

- First tidy, name-addressed release: one constructor for interval,
  contact, threaded and co-presence logs; every verb returns a
  one-row-per-observation data frame; values checked against the statnet
  ecosystem.
