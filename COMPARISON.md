# Dynet compared with the temporal- and static-network ecosystem

Dynet 0.3.44, compared function by function against four R packages and one
Python library. Every R row was enumerated from `getNamespaceExports()` and
every Python row from live `inspect` introspection of an installed build — no
row is written from recollection.

| Package | Version | Exports | Role |
|---|---|---|---|
| `networkDynamic` | 0.11.5 | 71 | temporal representation |
| `tsna` | 0.3.6 | 18 | temporal metrics and paths |
| `ndtv` | 0.13.4 | 23 | temporal visualisation |
| `sna` | 2.8 | 273 | static social-network analysis |
| `networkx-temporal` | 1.4.4 | ~130 | temporal representation and conversion (Python) |
| **`Dynet`** | **0.3.44** | **34** | **temporal mathematics** |

## How to read the Status column

| Status | Meaning |
|---|---|
| `equivalent` | Dynet does the same thing. Where the row says *[verified]*, both sides were run and compared numerically in this session. |
| `partial` | Dynet does some of it; the description says what is missing. |
| `none` | Dynet has no counterpart. |
| `n/a` | Plumbing with no analytic content, so no counterpart is expected. |

**The distinction that matters most.** Where Dynet matches an `sna` statistic,
it is the same static formula recomputed per time bin, not a temporal
generalisation. Only four measures carry a genuinely temporal definition —
`dyn_centrality(scope = "temporal")` for closeness, betweenness, reach and
reach_count — together with the path and reachability verbs. Likewise, most
`networkx-temporal` metrics are NetworkX static measures aggregated over
slices. Rows say so explicitly rather than implying more than is there.

## Verified numerical divergences

Four places where Dynet and `sna` disagree on a number. All were reproduced
independently before being written down.

1. **`centralization_closeness` — divergent normalisation; Dynet's is the
   sounder one.** Node values and the Freeman numerator agree with `sna`
   exactly. The denominators differ: Dynet uses `n - 1`, `sna` uses
   `(n - 1)^2 / n`. On the canonical directed out-star with `n = 5`, Dynet
   returns exactly `1` while `sna` returns `1.25`, overshooting the `[0, 1]`
   range a centralization index is defined to occupy. `sna`'s denominator
   assumes every pair is reachable, which fails on a directed star.
   `centralization_degree` and `centralization_betweenness` match `sna`
   exactly, so this is specific to closeness.
2. **`prestige = "indegree.rowcolnorm"` — Dynet is exact where `sna` is not.**
   Dynet returns exactly uniform `1` by deterministic Sinkhorn–Knopp
   balancing; `sna` 2.8's randomised annealer returned 0.9907–1.0127, an
   unconverged iterate.
3. **`load` centrality — constant endpoint offset.** Dynet equals
   `sna::loadcent(A) - (2n - 1)` exactly on both fixtures. Ranks agree,
   absolute values differ by a fixed endpoint convention.
4. **`reciprocity` — different default.** Dynet matches
   `sna::grecip(measure = "edgewise")`, not `sna`'s default
   `dyadic.nonnull`.

Clean agreement, verified numerically: degree (all three cmodes), betweenness,
closeness (all three mode mappings), harary/`graphcent`, information/`infocent`,
`flowbet`, `bonpow`, eigenvector (proportional; Dynet max-normalised against
`sna`'s L2), coreness/`kcores`, five of the nine prestige cmodes, density,
transitivity, the dyad census, all sixteen triad classes, all four Krackhardt
indices, weak and strong components, mutuality, isolates, and on the `tsna`
side `tDegree`, `tEdgeFormation`, `tEdgeDissolution`, `tReach`, `tPath`,
`edgeDuration`, `vertexDuration`, `tiedDuration`, `tEdgeDensity`, `tSnaStats`
and `tErgmStats`.

Two mappings that look right and are not, caught by running rather than
reading:

- `networkDynamic::network.size.active` is **not**
  `metrics(measure = "active_nodes")`. On the identical window they return 14
  and 8: the first counts declared vertex activity, the second counts
  non-isolates.
- `collapse_network(start = t, end = t)` returns **zero** edges, so
  `networkDynamic`'s `%k%` maps to `snapshots(..., window = 0)`, not to
  `collapse_network()`.

## Correction to an earlier assessment

`networkx-temporal`'s `to_unrolled()` was initially recorded as a Dynet gap.
It is not. Dynet's `projection()` is the time-expanded graph: it emits one
state per node per slice with an `active` flag, plus `within_slice` arcs and
forward weight-1 `identity_arc` rows that are exactly `to_unrolled()`'s edge
couplings. Only three sub-features are genuinely absent: the `delta`
cross-time-edge variant, `node_copies = 'fill'/'persist'`, and an inverse
`from_unrolled()`.

The one confirmed representational gap is
`temporal_node_similarity()` / `temporal_edge_similarity()`: a T-by-T matrix of
set overlap between every pair of snapshots under five coefficients. Dynet's
`events()` compares only adjacent bins, and only directionally.

---

# Dynet's own surface (0.3.44)

Enumerated from `getNamespaceExports("Dynet")` and the `man/` selector
vocabularies, then every measure was run against `school_contacts` to confirm
it exists and returns. 34 exported functions.

## Construction and coercion

| Function | What it does |
|---|---|
| `dynet()` | Build a temporal network from an interval, contact, threaded or co-presence log. Carries directedness, loops, weights, node attributes, sessions, observation windows and vertex-activity spells. |
| `as_dynet()` | Coerce from another representation; `as_dynet.networkDynamic()` imports a `networkDynamic` object. |
| `collapse_network()` | Flatten to a static `cograph` netobject, retaining activity duration, activity count, additive duration and weighted duration as selectable weights. |
| `induce_subgraph()` | Temporal subgraph by node or tie predicate. |
| `projection()` | Time-projected network. |

## Editing (all immutable — each returns a new network)

`add_nodes()`, `add_ties()`, `add_arcs()`, `add_vertex_spells()`,
`remove_nodes()`, `remove_ties()`, `remove_arcs()`, `remove_vertex_spells()`,
`rename_nodes()`, `rename_sessions()`, `update_nodes()`, `update_ties()`,
`update_vertex_spells()`, `set_observations()`, `clear_observations()`,
`set_tie_sessions()`, `set_vertex_spells()`.

## Measurement verbs

| Verb | Selector argument | Vocabulary |
|---|---|---|
| `dyn_centrality()` | `measure=`, `scope="snapshot"` | degree, strength, prestige, closeness, betweenness, eigenvector, pagerank, hub, authority, coreness, constraint, power, harary, information, load, flow_betweenness, diffusion, reach, reach_count |
| `dyn_centrality()` | `measure=`, `scope="temporal"` | closeness, betweenness, reach, reach_count — the only four defined over time rather than per snapshot |
| `dyn_centrality()` | `prestige=` | indegree, indegree.rownorm, indegree.rowcolnorm, domain, domain.proximity, eigenvector, eigenvector.rownorm, eigenvector.colnorm, eigenvector.rowcolnorm |
| `metrics()` | `measure=` | 40 selectors: density, edges, active_nodes, isolates, transitivity, reciprocity, components, components_strong, largest_component, mean_distance, diameter, mutual, asymmetric, null, assortativity, centralization_degree, centralization_betweenness, centralization_closeness, triads (16 classes), connectedness, efficiency, hierarchy, lubness, degree_mean, degree_variance, degree_min, degree_max, mean_degree, indegree_1_5, outdegree_1_5, triangles, concurrent_nodes, concurrent_share, in_2stars, out_2stars, two_paths, temporal_density, observed_pair_density, onset_intensity, observed_pair_onset_intensity |
| `paths()` | `direction=`, `traversal_time=`, bounds | Time-respecting journeys, shortest-foremost criterion, exact multiplicity |
| `dyn_reachability()` | `direction=`, `measure=` | Forward/backward temporal reach and reach counts |
| `events()` | `measure=` | formation, dissolution (fractions and rates) |
| `durations()` | `measure=`, `unit=` | events/total/mean over pair, spell, vertex_activity, vertex_spell, node_ties |
| `burstiness()` | `measure=` | burstiness, memory, events |
| `mixing()` | `attribute=` | Attribute mixing over active dyads |
| `snapshots()` | `at=`, `step=`, `window=` | Discrete time slices |
| `pshifts()` | — | Participation shifts |

Every measurement verb also takes `sessions = c("bounded","collapse","separate")`
and the windowing arguments `start`, `end`, `step`, `window`.

## Results and visualisation

| Function | What it does |
|---|---|
| `path_trajectories()` | The optimal route family as a tidy prefix tree, one row per node. |
| `plot_path_trajectories()` | Draws that tree; `measure = c("frequency","time","predictability")`, `orientation`, `min_count`. |
| `path_network()` | The union of optimal route hops as a static network. |

Every result class carries `print()`, `summary()`, `as.data.frame()` and, where
meaningful, `plot()`.

## What is distinctive

The verbs that have no snapshot-wise definition at all, and therefore no
counterpart in a library that aggregates static measures over slices:

- Time-respecting paths with a stated optimality criterion
  (shortest-foremost), exact path multiplicity, per-hop traversal duration,
  and backward latest-departure with attainment state.
- Temporal closeness and betweenness computed over journeys, not per snapshot.
- Temporal reach and reach counts, source-excluded.
- Burstiness and lag-one memory over incident onsets.
- The nine-variant prestige family, including Sinkhorn–Knopp row-column
  balancing with structural/numerical/spectral failure diagnostics returned as
  `NA` plus a classed warning rather than a silent approximation.
- Observation windows, discontinuous observation spells, and explicit
  onset/terminus censoring, which change the denominators of every rate.
- Declared vertex-activity spells, propagated into snapshots, paths and risk
  sets.
- Duration and exposure units that distinguish pair-union duration from
  raw-spell duration.
- Formation and dissolution fractions and rates over confirmed in-window
  events.

---

# `networkDynamic` and `ndtv` mapped against `Dynet`

Generated 2026-08-26. Versions actually loaded in this session:
`networkDynamic` 0.11.5 (71 exports), `ndtv` 0.13.4 (23 exports),
`Dynet` loaded with `devtools::load_all("/Users/mohammedsaqr/Documents/Github/temporal")`
(35 exports + 21 registered S3 methods).

Export lists were enumerated with `getNamespaceExports()`, not from memory.
Descriptions come from each package's own `.Rd` (`tools::Rd_db`), not from the
function name. Dynet argument names come from `args()`.

Rows tagged **[verified]** were checked by running both sides on the same data
(`school_contacts`, 240 edge spells, 14 vertices, rebuilt as a `networkDynamic`
from the identical spell matrix). Rows without that tag were mapped from the
help pages only and are stated as such.

Legend for **Status**: `equivalent` / `partial` / `none` / `n/a` (plumbing).

---

## `networkDynamic` 0.11.5 — 71 rows

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `%k%` | Infix for `network.collapse`: collapse the network *at one time point* into a plain static `network`. | `snapshots(dn, start = t, end = t, window = 0)` | `partial` — **[verified]** at `t = 3` both return the same 4 arcs (Nils→Eve, Iris→Finn, Hugo→Kira, Gita→Jonas). But Dynet returns a tidy edge table, not a `network` object, and `collapse_network(dn, start = 3, end = 3)` returns **0 edges** (zero-width windows carry no duration), so the point form has no `collapse_network` route. |
| `%t%` | Infix for `network.extract`: return a *reduced `networkDynamic`* holding only elements active at a point/interval. | `set_observations(dn, start = , end = )` | `partial` — **[verified]** `set_observations(dn, 0, 5)` narrows `meta$time_range` and all downstream measurement, but keeps all 240 spells; it does not return a smaller, truncated, re-censored temporal object. `induce_subgraph()` subsets by `nodes`/`ties` only, never by time. |
| `activate.edge.attribute` | Set a temporally-extended attribute (TEA) on edges over a spell. | — | `none` — Dynet vertex/edge attributes are **static** (`dynet(nodes = )`); **[verified]** `dn$nodes` carries only `id`, `label`, `name`, `x`, `y`, and `summary(dn)` reports `vertex attributes: none`. There is no time-varying attribute machinery at all. |
| `activate.edge.value` | Same as above but writes into the edge *value* (`mel`) slot rather than an attribute list. | — | `none` — no TEA support. |
| `activate.edges` | Add a spell of activity to existing edges (`onset`/`terminus`/`length`/`at`, edge set `e`). | `add_ties(dn, data = data.frame(from, to, start, end))` | `partial` — **[verified]** `add_ties` grew the spell table 240 → 241. But `add_ties` is keyed by endpoint names and always creates a spell row; it cannot address an existing edge by id and cannot use `length =`/`at =` shorthand. |
| `activate.network.attribute` | Set a TEA on the network itself (e.g. a changing `net.obs.period`). | — | `none` — no network-level TEA. |
| `activate.vertex.attribute` | Set a TEA on vertices over a spell. | — | `none` — no TEA. |
| `activate.vertices` | Add a spell of activity to vertices. | `add_vertex_spells(dn, data = data.frame(node, start, end))` | `partial` — **[verified]** adding a spell moved `vertex_spells` from 2 → 3 rows and `meta$vertex_activity` to `"explicit"`. Addressed by node name, not vertex id; no `length =`/`at =` shorthand. |
| `add.edge.networkDynamic` | PID-aware `add.edge` method: adds one edge and assigns/propagates a persistent edge id. | `add_ties(dn, data = )` | `partial` — Dynet adds ties but has no persistent-id concept (names are the identity); read from help + `args()`, not run side-by-side. |
| `add.edges.active` | Convenience: add edges *and* activate them over a spell in one call. | `add_ties(dn, data = data.frame(from, to, start, end))` | `equivalent` — **[verified]** `add_ties` is exactly "create the tie with this spell"; Dynet has no separate create/activate split, so the convenience is the default. |
| `add.edges.networkDynamic` | PID-aware `add.edges` method (vectorised). | `add_ties(dn, data = )` | `partial` — no persistent ids in Dynet. |
| `add.vertices.active` | Convenience: add vertices *and* activate them over a spell. | `add_nodes(dn, data = )` then `add_vertex_spells(dn, data = )` | `partial` — **[verified]** both verbs work, but Dynet needs two calls; there is no single add-and-activate verb. |
| `add.vertices.networkDynamic` | PID-aware `add.vertices` method. | `add_nodes(dn, data = )` | `partial` — no persistent ids. |
| `adjust.activity` | Affinely transform (shift/scale) **every** spell in the object — vertices, edges, TEAs and `net.obs.period` — at once. | — | `none` — Dynet has no time-rescaling or time-shifting verb. |
| `as.data.frame.networkDynamic` | Edge spells as a data frame, with optional observation window, truncation and censor flags. | `as.data.frame(dn)` | `partial` — **[verified]** Dynet returns the 240 **raw** spells with `from`/`to`/`start`/`end`/`duration`/`weight`; networkDynamic returns 231 rows because it merges overlapping spells per edge, and it exposes `onset.censored`/`terminus.censored`/`edge.id`. Dynet has no `start`/`end` window argument on the accessor. |
| `as.network.networkDynamic` | Drop the `networkDynamic` class, keeping all (including dynamic) attributes. | — | `n/a` — class-stripping plumbing. |
| `as.networkDynamic` | Generic for basic coercion into `networkDynamic`. | `as_dynet(x)` | `partial` — Dynet's generic converts *into* `dynet`; **[verified]** `as_dynet(nd)` round-trips a `networkDynamic` (231 spells, censor flags preserved). There is no `as.networkDynamic.dynet` export, so the reverse direction is missing. |
| `as.networkDynamic.network` | Method: wrap a static `network` as `networkDynamic`. | — | `n/a` — coercion helper. Dynet has no `as_dynet.network`; **[verified]** only `as_dynet.dynet` and `as_dynet.networkDynamic` are registered. |
| `as.networkDynamic.networkDynamic` | Method: identity. | `as_dynet.dynet` | `n/a` — identity plumbing. |
| `deactivate.edge.attribute` | Remove a TEA spell from edges. | — | `none` — no TEA. |
| `deactivate.edges` | Remove a spell of activity from edges. | `remove_ties(dn, from = , to = , start = , end = , session = )` | `partial` — **[verified]** `remove_ties(dn, from = "Jonas", to = "Dan")` dropped 240 → 234 spells. Dynet deletes matching spell rows; it cannot punch a hole out of the middle of a longer spell the way `deactivate.edges(onset =, terminus =)` does. |
| `deactivate.network.attribute` | Remove a network-level TEA spell. | — | `none` — no TEA. |
| `deactivate.vertex.attribute` | Remove a vertex TEA spell. | — | `none` — no TEA. |
| `deactivate.vertices` | Remove a spell of vertex activity, optionally cascading to incident edges. | `remove_vertex_spells(dn, spells = )` (cascade: `remove_nodes(dn, nodes, cascade = TRUE)`) | `partial` — **[verified]** `remove_vertex_spells` drops whole spell rows by index (3 → 2). It removes a listed spell, not an arbitrary time interval, and the `deactivate.edges = TRUE` cascade is only available on `remove_nodes`, which deletes the node entirely. |
| `delete.edge.activity` | Strip all timing information from given edges, leaving them always-active. | `clear_observations(dn)` | `partial` — **[verified]** `clear_observations(dn)` runs, but it clears the *observation window*, not per-element spells; there is no verb that makes a selected tie timeless. |
| `delete.vertex.activity` | Strip all vertex timing information, leaving vertices always-active. | `set_vertex_spells(dn, data = NULL)` | `partial` — resets vertex activity to the implicit always-on default for the whole network; cannot be scoped to a vertex subset. Read from `args()`, not run for the `NULL` case. |
| `dyads.age.at` | Age (time since spell onset) of the edge joining given tail/head pairs at a query time; returns vector, edgelist or matrix. | — | `none` — **[verified]** `dyads.age.at(nd, at = 1, tails = 10, heads = 4)` = 1. Dynet has no tie-age-at-time verb; `durations()` gives completed spell durations, not elapsed age at a query instant. |
| `edge.pid.check` | Verify the edge persistent-id attribute is valid. | — | `n/a` — pid bookkeeping; Dynet keys everything by vertex/tie name, so pids do not exist. |
| `edges.age.at` | Age of each edge's currently-active spell at a query time. | — | `none` — **[verified]** `edges.age.at(nd, at = 1)` returns `1, NA, NA, …`. No Dynet counterpart. |
| `get.change.times` | Every unique time at which any vertex, edge, or TEA changes state. | `events(dn, measure = c("formation", "dissolution"))` | `partial` — **[verified]** `get.change.times(nd)` returns 404 unique change points; `events()` returns *counts per bin* (`time = 0, formation = 11, dissolution = 7`), never the change-point vector itself. No Dynet verb returns unique change times. |
| `get.dyads.active` | Matrix of tail/head pairs joined by an edge active in the query spell. | `snapshots(dn, start = , end = , window = )` | `equivalent` — **[verified]** at `t = 3`, `get.dyads.active` returned pairs (14,5)(9,6)(8,11)(7,10) and `snapshots(dn, start = 3, end = 3, window = 0)` returned Nils→Eve, Iris→Finn, Hugo→Kira, Gita→Jonas — the same four arcs. Dynet returns a tidy data frame instead of a matrix. |
| `get.edge.activity` | Per-edge list of activity spells, or a flat spell-list data frame. | `as.data.frame(dn)` / `durations(dn, unit = "spell")` | `partial` — **[verified]** `get.edge.activity(as.spellList = TRUE)` gives 231×8 with `onset.censored`/`terminus.censored`/`edge.id`; Dynet's `as.data.frame(dn)` gives the 240 raw spells and `durations(dn, unit = "spell")` gives one duration per raw spell. Spell merging and per-edge list form are missing. |
| `get.edge.attribute.active` | Query an edge TEA at a time/interval, with `rule = any/all/earliest/latest`. | — | `none` — no TEA. |
| `get.edge.id` | Look up an edge id from its persistent id. | — | `n/a` — pid plumbing. |
| `get.edge.pid` | Look up an edge persistent id from its id. | — | `n/a` — pid plumbing. |
| `get.edge.value.active` | Query a time-varying edge *value* at a time/interval. | — | `none` — Dynet weights are per-spell constants (`weight` column), not queryable TEAs. |
| `get.edgeIDs.active` | Edge ids incident on `v` and active in the query spell, by `out`/`in`/`combined` neighbourhood. | — | `partial` — no Dynet verb returns incident tie ids for a vertex in a window. The closest is filtering `snapshots()` output, which is user-side subsetting, not a verb. Read from help; not run against Dynet. |
| `get.edges.active` | The edge objects incident on `v` and active in the query spell. | `snapshots(dn, start = , end = , window = )` | `partial` — **[verified]** `get.edges.active(nd, v = 10, at = 0.5)` returns 1 edge. Dynet returns the whole window's edge table; there is no `node = ` argument to restrict it to one vertex's incident ties. |
| `get.neighborhood.active` | Vertex ids adjacent to `v` in the query spell (`out`/`in`/`combined`). | — | `none` — **[verified]** `get.neighborhood.active(nd, v = 10, at = 0.5)` = vertex 4. Dynet has no time-scoped neighbourhood verb. `dyn_reachability()` answers a different question (time-respecting reach over the whole window, not one-step neighbours in a window). |
| `get.network.attribute.active` | Query a network-level TEA at a time/interval. | — | `none` — no TEA. |
| `get.networks` | List of collapsed static networks sampled periodically (start/end/increment or onset/terminus vectors). | `snapshots(dn, start = , end = , step = , window = )` | `equivalent` — **[verified]** `get.networks(nd, start = 0, end = 20, time.increment = 5)` gave edge counts **40, 60, 62, 33**; `snapshots(dn, start = 0, end = 20, step = 5, window = 5)` gave per-bin counts **40, 60, 62, 33** (plus a fifth bin at t = 20 with 17, since Dynet also reports the trailing bin). Dynet returns one tidy `time`/`from`/`to`/`weight`/`n_spells` frame instead of a list of `network` objects. |
| `get.vertex.activity` | Per-vertex activity spells, or a flat spell list. | `durations(dn, unit = "vertex_spell")` | `partial` — **[verified]** `get.vertex.activity(as.spellList = TRUE)` gives a 14×6 spell frame with censor flags; `durations(dn, unit = "vertex_spell")` gives one row per vertex spell with `duration` and an `implicit` flag, and `dn$vertex_spells` holds the raw table. Dynet has no verb returning onset/terminus columns for vertex spells directly. |
| `get.vertex.attribute.active` | Query a vertex TEA at a time/interval. | — | `none` — no TEA. |
| `get.vertex.id` | Vertex id from persistent id. | — | `n/a` — pid plumbing. |
| `get.vertex.pid` | Persistent id from vertex id. | — | `n/a` — pid plumbing. |
| `initialize.pids` | Create persistent id attributes on a network. | — | `n/a` — pid plumbing. |
| `is.active` | Logical: is each named vertex/edge active at a point or over an interval (with `rule`)? | — | `none` — **[verified]** `is.active(nd, at = 3, e = 1:5)` returns a logical vector. Dynet has no element-level activity predicate. |
| `is.adjacent.active` | Logical: are `vi` and `vj` adjacent in the query spell? | — | `none` — **[verified]** `is.adjacent.active(nd, vi = 10, vj = 4, at = 0.5)` = `TRUE`. No Dynet predicate. |
| `is.networkDynamic` | Class predicate. | — | `n/a` — Dynet has an internal `.check_dynet()` but exports no `is_dynet()`. |
| `list.edge.attributes.active` | Names of edge attributes active in the query spell. | — | `none` — no TEA. |
| `list.network.attributes.active` | Names of network attributes active in the query spell. | — | `none` — no TEA. |
| `list.vertex.attributes.active` | Names of vertex attributes active in the query spell. | — | `none` — no TEA. |
| `network.collapse` | Collapse a time range into a plain static `network`, aggregating TEAs onto it. | `collapse_network(dn, start = , end = , weight = , censored = )` | `partial` — **[verified]** identical edge sets: `network.collapse(nd, 0, 5)` = 40 edges vs `collapse_network(dn, start = 0, end = 5)` = 40; `network.collapse(nd, 3, 4)` = 12 vs `collapse_network(dn, 3, 4)` = 12. Dynet is **richer on weights** (`binary`, `union_duration`, `total_duration`, `duration_fraction`, `spell_count`, `weight_sum`, `weighted_duration`, `latest_weight` — all returned as columns at once). Missing: the `at = ` point form (returns 0 edges) and TEA-attribute aggregation rules. |
| `network.dyadcount.active` | Count of dyads whose *vertices* are active in the query spell (the density denominator). | — | `none` — **[verified]** `network.dyadcount.active(nd, 1, 2)` = 182, and Dynet's `density` at that bin is 8/182 = 0.0439560, so the denominator is used internally — but no `measure` returns it. |
| `network.dynamic.check` | Audit an object for malformed activity matrices (vertex/edge/dyad/TEA/`net.obs.period` checks). | — | `partial` — **[verified]** `network.dynamic.check(nd)` returns a named list of seven logical check vectors. Dynet validates at construction (`dynet()` raises classed conditions) but exports no standalone audit verb and returns no check report. |
| `network.edgecount.active` | Number of edges active in the query spell. | `metrics(dn, measure = "edges", start = , end = , window = )` | `equivalent` — **[verified]** `network.edgecount.active(nd, onset = 1, terminus = 2)` = 8; `metrics(dn, measure = "edges", start = 1, end = 2, step = 1, window = 1)` = 8 at `time = 1`. |
| `network.extract` | Return a *reduced `networkDynamic`* containing only elements active at a point/interval, with optional truncation and re-censoring. | `set_observations(dn, start = , end = )` | `partial` — **[verified]** `set_observations` narrows the window but keeps all 240 spells; **[verified]** `network.extract(nd, 0, 5)` returns a genuine 40-edge `networkDynamic`. Dynet cannot return a time-truncated temporal object. |
| `network.naedgecount.active` | Number of missing (`NA`) edges active in the query spell. | — | `none` — Dynet has no `NA`-edge concept; missingness is not represented in the spell table. |
| `network.size.active` | Number of *vertices* active in the query spell. | `metrics(dn, measure = "active_nodes", start = , end = , window = )` | `partial` — **[verified]** and **not the same measure**: over 1..2, `network.size.active` = 14 (all vertices, since no vertex spells were declared) while `metrics(..., "active_nodes")` = 8. networkDynamic counts declared vertex activity; Dynet's `active_nodes` counts non-isolates in the bin. Dynet exposes no count of the eligible vertex set. |
| `networkDynamic` | Construct from spell matrices, toggle lists, lists of networks, censoring info and `net.obs.period`. | `dynet(data, from = , to = , start = , end = , vertex_spells = , observation_spells = , onset_censored = , terminus_censored = , format = )` | `equivalent` — **[verified]** both built the same network from the same 240-row spell matrix (14 vertices, 0–21.52). Dynet accepts **more input shapes** (`format = "interval" / "contact" / "threaded" / "copresence"`, plus `duration`, `thread`, `actor`, `group`, `session`, `time_unit`, dates); networkDynamic accepts toggle matrices and a list of pre-made networks, which Dynet does not. |
| `print.networkDynamic` | Print method with timing summary. | `print(dn)` / `summary(dn)` | `n/a` — print plumbing. **[verified]** both print; Dynet's `summary(dn)` returns a tidy 15-row property/value frame. |
| `read.son` | Read a SoNIA `.son` file (node-attribute and arc-attribute event sections) into a `networkDynamic`. | — | `none` — Dynet has no file readers of any kind. |
| `reconcile.edge.activity` | Force edge spells to agree with incident vertex spells (`match.to.vertices`, `reduce.to.vertices`). | — | `none` — Dynet gates edges on endpoint eligibility *at measurement time* (`meta$edge_vertex_activity_policy`) but never rewrites stored spells to reconcile them. |
| `reconcile.vertex.activity` | Force vertex spells to agree with incident edges (`expand.to.edges`, `match.to.edges`, `encompass.edges`). | — | `none` — no reconciliation verb. |
| `search.spell` | Binary-search a sorted spell matrix for the insertion/overlap position of a query spell. | — | `none` — spell-interval algebra is internal to Dynet and not exported. |
| `spells.hit` | Index of the first spell in a matrix that overlaps a query spell. | — | `none` — not exported by Dynet. |
| `spells.overlap` | Logical: do two spells overlap at all? | — | `none` — not exported by Dynet. |
| `vertex.pid.check` | Verify the vertex persistent-id attribute is valid. | — | `n/a` — pid plumbing. |
| `vertices.age.at` | Age of each vertex's currently-active spell at a query time. | — | `none` — **[verified]** `vertices.age.at(nd, at = 1)` returns `Inf` for always-on vertices. No Dynet counterpart. |
| `when.edge.attrs.match` | Earliest/latest time each edge's TEA satisfies a comparison (`==`, `>`, `%in%`, …). | — | `none` — no TEA, so no attribute-match timing. |
| `when.vertex.attrs.match` | Earliest/latest time each vertex's TEA satisfies a comparison. | — | `none` — no TEA. |

**Row count: 71.**

---

## `ndtv` 0.13.4 — 23 rows

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `compute.animation` | Step through time, run a sequentially-stable layout per slice seeded from the previous slice's coordinates, and store the coordinates back into the network for later rendering. | — | `none` — **[verified]** ran successfully on the test network. Dynet's `plot(dn, type = "snapshots")` lays panels out on shared coordinates, but there is no seeded slice-to-slice layout optimiser and no stored animation coordinate track. |
| `effect.edgeAgeColor` | Return per-edge colours interpolated from edge age (start colour → end colour over `fade.dur`). | — | `none` — Dynet has no age-driven graphic-attribute effects. |
| `effect.vertexAgeColor` | Same, for vertices. | — | `none` — no age-driven effects. |
| `effectFun` | Factory that returns a configured effect function by name for use in animation arguments. | — | `n/a` — effect plumbing. **[verified]** it runs but expects the short name (`effectFun("edgeAgeColor", …)`); my first call with the full name errored. |
| `export.dot` | Write a network out as a Graphviz `.dot` file. | — | `none` — **[verified]** wrote a file. Dynet exports nothing to disk. |
| `export.pajek.net` | Write a network out as a Pajek `.net` file (no attributes/layout/timing). | — | `none` — **[verified]** wrote a file. No Dynet exporter. |
| `filmstrip` | Small-multiples static image: several animation frames drawn side by side. | `plot(dn, type = "snapshots", panels = )` | `equivalent` — **[verified]** both run and both produce evenly-spaced small multiples on shared coordinates (Dynet reported "Drawing 4 of 22 bins, evenly spaced across the window"). ndtv's frames come from the stored animation track, Dynet's from its time bins. |
| `layout.center` | Centre a coordinate matrix inside a given `xlim`/`ylim`. | — | `n/a` — layout plumbing. **[verified]** runs. |
| `layout.distance` | Geodesic-distance matrix for a network after symmetrising, with `Inf` replaced by `default.dist` — the input to MDS-style layouts. | `plot(dn, type = "proximity", default_dist = )` | `partial` — **[verified]** `layout.distance()` returned a 14×14 matrix and is a public verb; Dynet computes the same quantity internally (`.proximity_slices()`, `default_dist` argument) but exposes no distance-matrix verb. |
| `layout.normalize` | Rescale coordinates to (-1, 1), optionally preserving aspect ratio. | — | `n/a` — layout plumbing. **[verified]** runs. |
| `ndtvAnimationWidget` | `htmlwidgets` wrapper embedding an ndtv-d3 animation in a Shiny app. | — | `none` — Dynet has no htmlwidget or Shiny output. |
| `ndtvAnimationWidgetOutput` | Shiny UI-side output placeholder for the widget. | — | `n/a` — Shiny plumbing (and no Dynet counterpart anyway). |
| `network.layout.animate.Graphviz` | Sequentially-stable layout via Graphviz, accepting previous coordinates as a seed. | — | `none` — no seeded temporal layouts in Dynet. |
| `network.layout.animate.kamadakawai` | Sequentially-stable Kamada-Kawai layout with previous coordinates as seed. | — | `none` — no seeded temporal layouts. |
| `network.layout.animate.MDSJ` | Sequentially-stable layout via the Java MDSJ stress-majorisation library. | — | `none` — no seeded temporal layouts. |
| `network.layout.animate.useAttribute` | "Layout" that just reads stored `x`/`y` vertex attributes per slice. | — | `n/a` — layout plumbing. |
| `proximity.timeline` | Phase plot: vertices trace paths through time, positioned vertically by relative geodesic distance at sampled points; line size/colour configurable. | `plot(dn, type = "proximity", measure = , slices = , window = , highlight = , labels = , flow = )` | `equivalent` — **[verified]** both render the same kind of chart on the same data (ndtv with `mode = "sammon"`, Dynet with `slices = 20`). Dynet adds per-phase network panels (`networks = TRUE`), formation-event marks (`events = TRUE`), direct line labelling, corner-rounding (`flow`) and an Okabe-Ito palette; ndtv offers alternative 1-D scaling modes (`sammon`, `isoMDS`, …) that Dynet does not expose. ndtv's own help calls it a DRAFT. |
| `render.animation` | Render the stored animation track to an actual movie/frame sequence via the `animation` package (ffmpeg/HTML/etc.). | — | `none` — **[verified]** ran and produced frames. Dynet cannot produce animation of any kind. |
| `render.d3movie` | Export a self-contained interactive HTML/SVG animation using the ndtv-d3 player and open it in a browser. | — | `none` — **[verified]** wrote a working self-contained HTML file. Dynet has no interactive or web output. |
| `renderNdtvAnimationWidget` | Shiny server-side render function for the widget. | — | `n/a` — Shiny plumbing. |
| `timeline` | Phase plot of edge and vertex activity spells, one row per element, spells drawn horizontally. | `plot(dn, type = "timeline", top = )` | `equivalent` — **[verified]** both render. Dynet's version is a ggplot, is limited to edge spells (one row per vertex pair), and can be capped to the `top` busiest pairs; ndtv draws vertex spells too and returns base graphics. |
| `timePrism` | Pseudo-3D `scatterplot3d` prism: several network layout slices stacked along a time axis. | — | `none` — **[verified]** ran. Dynet has no 3-D / space-time-prism view. |
| `transmissionTimeline` | Plot a diffusion/transmission tree with **clock time on the x axis** and generation depth on the y axis. | `plot(paths(dn, from = ))` → `plot_path_trajectories(x, measure = "time")` | `partial` — **[verified]** `transmissionTimeline(tsna::tPath(nd, v = 1))` runs, and `plot(paths(dn, from = "Leo"))` renders the equivalent tree. **The axes differ**: Dynet's trajectory tree puts *hop number* on the x axis and encodes attained time only as node fill/label (`measure = "time"`), so the clock-time-versus-generation geometry ndtv draws is not reproduced. Dynet's tree does add route counts, branching probabilities and repeated vertices under different temporal histories. |

**Row count: 23.**

---

## What `networkDynamic`/`ndtv` do that Dynet does not

- **Temporally-extended attributes (TEAs).** The whole `activate.*.attribute` / `get.*.attribute.active` / `list.*.attributes.active` / `deactivate.*.attribute` / `when.*.attrs.match` family — 13 exports — has no Dynet counterpart at all. Dynet vertex attributes are static (`dynet(nodes = )`); `summary(dn)` reports `vertex attributes: none` for anything not supplied up front. Any analysis where a node's role, state or an edge's value *changes over time* is simply outside Dynet's data model.
- **Element-level activity queries.** `is.active`, `is.adjacent.active`, `get.neighborhood.active`, `get.edgeIDs.active`, `get.edges.active` answer "is this specific element on right now / who is next to it right now". Dynet has no predicate on a named element at a time, and no way to restrict a snapshot to one vertex's incident ties without user-side subsetting.
- **Element age at a time point.** `edges.age.at`, `vertices.age.at`, `dyads.age.at` measure time elapsed since the current spell's onset. Dynet's `durations()` measures completed spell lengths — a different quantity.
- **Returning a time-truncated temporal object.** `network.extract` / `%t%` hand back a real, smaller `networkDynamic` with truncation and re-censoring. Dynet's `set_observations()` only narrows metadata (all 240 spells were retained in the test), and `induce_subgraph()` subsets by nodes/ties, never by time.
- **Unique change times.** `get.change.times` returned 404 change points on the test network. Dynet's `events()` gives per-bin counts and no verb returns the change-point vector.
- **Spell-level surgery and repair.** `adjust.activity` (affine rescaling of every spell), `reconcile.vertex.activity` / `reconcile.edge.activity` (forcing vertex and edge spells into mutual consistency), `delete.*.activity` (making a selected element timeless). Dynet's editing verbs add and delete whole spell rows; they cannot punch an interval out of a spell, rescale the clock, or reconcile the two layers.
- **A standalone validity audit.** `network.dynamic.check` returns a per-element report across seven check families. Dynet validates only at construction and returns no report.
- **Persistent ids.** The seven-function pid family keeps element identity stable across extraction and re-indexing. Dynet sidesteps this by keying on names, which is cleaner but offers nothing when names collide or change.
- **Missing-data edges.** `network.naedgecount.active` — Dynet's spell table has no `NA`-edge representation.
- **File I/O.** `read.son`, `export.dot`, `export.pajek.net`. Dynet reads and writes nothing.
- **Animation, in every form.** `compute.animation` (seeded slice-to-slice layout optimisation), `render.animation` (movies), `render.d3movie` (self-contained interactive HTML — verified working), the `ndtvAnimationWidget*` Shiny trio, and the four `network.layout.animate.*` algorithms including Graphviz and Java MDSJ backends. Dynet produces static figures only. This is the single largest capability gap in the comparison.
- **The pseudo-3D space-time prism** (`timePrism`), and **clock-time transmission-tree geometry** (`transmissionTimeline`), neither of which Dynet reproduces.
- **Public geodesic-distance extraction** (`layout.distance`) and alternative 1-D scaling modes in the proximity plot (`sammon`, `isoMDS`), which Dynet computes internally but does not expose or offer.

## What Dynet does that they do not

*(Scoped to `networkDynamic` and `ndtv` only; several of these overlap with `tsna`, which was not part of this comparison.)*

- **Time-respecting path analysis as a first-class result.** `paths(dn, from = , direction = , traversal_time = , start = , end = )` returns a tidy frame of `reachable`, `arrival_time`, `latency`, `n_hops`, `n_paths` per target, with `path_trajectories()` giving the prefix tree (route counts, branching probabilities, repeated vertices under different histories) and `path_network()` giving the induced path network. `networkDynamic` has no path machinery whatsoever.
- **Temporal reachability and temporal centrality.** `dyn_reachability(dn, direction = , at = , traversal_time = , measure = )` and `dyn_centrality(dn, scope = "temporal", measure = c("closeness", "betweenness", "reach", "reach_count"))` — verified running. Neither package offers these.
- **A large snapshot-centrality catalogue.** `dyn_centrality(dn, scope = "snapshot", measure = )` covers 19 measures (degree/indegree/outdegree, strength, prestige, closeness, betweenness, eigenvector, pagerank, hub, authority, coreness, constraint, power, harary, information, load, flow_betweenness, diffusion) as a trajectory over time.
- **A large graph-level measure catalogue.** `metrics(dn, measure = )` covers 38 selectors including the triad census, Krackhardt's connectedness/efficiency/hierarchy/lubness, centralisation indices, assortativity, concurrency, and four exactly window-integrated temporal quantities (`temporal_density`, `observed_pair_density`, `onset_intensity`, `observed_pair_onset_intensity`) that integrate exact state over observed time rather than counting a binary union.
- **The `step` / `window` separation.** Every measuring verb takes both, so an overlapping sliding window is one argument, not a loop over `get.networks()`.
- **Richer collapse weights in one call.** `collapse_network()` returns `binary`, `union_duration`, `total_duration`, `duration_fraction`, `spell_count`, `weight_sum`, `weighted_duration` and `latest_weight` as columns simultaneously; `network.collapse` collapses to one aggregation at a time.
- **Burstiness and memory.** `burstiness(dn, measure = c("burstiness", "memory", "events"))` — per-node Goh-Barabási burstiness and memory coefficients, verified running. No counterpart in either package.
- **Participation-shift analysis.** `pshifts(dn, output = , group_events = )` returns the Gibson turn-taking shift census (`AB-BA`, `AB-B0`, `AB-BY`, … by family) — a conversation-analytic layer neither package has.
- **Mixing matrices over time.** `mixing(dn, attribute = , start = , end = , step = , window = )`.
- **Bipartite/state projection.** `projection(dn)` returns a tidy per-slice node-state table.
- **Sessions as a first-class dimension.** Every verb takes `sessions = c("bounded", "collapse", "separate")`, so paths and measures can be confined within sessions rather than leaking across gaps. `networkDynamic`'s `net.obs.period` records observation spells but does not gate traversal.
- **More input formats at construction.** `dynet(format = c("auto", "interval", "contact", "threaded", "copresence"))` plus `duration`, `thread`, `actor`, `group`, `session`, `time_unit` and date handling — including building a network from threaded discussion data or co-presence records, which `networkDynamic()` cannot ingest.
- **Tidy returns throughout.** Every verb returns a one-row-per-observation `data.frame` (with `as.data.frame()`, `print()`, `summary()` and `plot()` methods on each result class), rather than matrices, nested lists, or lists of `network` objects.

---

# `tsna` and `sna` mapped against `Dynet`

Generated 2026-08-26 on this machine. Every export was enumerated at runtime, not
recalled:

```r
sort(getNamespaceExports("tsna"))   # tsna 0.3.6  -> 18 exports
sort(getNamespaceExports("sna"))    # sna  2.8    -> 273 exports
devtools::load_all("."); sort(getNamespaceExports("Dynet"))  # -> 35 exports
```

One-line descriptions come from each function's own `\title` in the installed Rd
database, extended by reading the help page where the title was uninformative.

**Rows:** tsna 18, sna 273, total 291.

## What "verified" means here

Rows marked *verified numerically* were computed twice in this session — once
through Dynet and once through `sna`/`tsna` on the same small network — and
compared with `all.equal(tolerance = 1e-8)`. Two fixtures were used:

* a 6-vertex / 14-arc directed network with all spells `[0, 10]` and one bin, so
  the single snapshot *is* the static graph;
* a 7-vertex / 16-arc random directed network (`set.seed(7)`), same construction;
* a 5-vertex / 14-spell `networkDynamic` for the `tsna` side, converted with
  `as_dynet()`, so both packages see literally the same spell data.

Everything else is marked *doc only*.

## The honest framing

`sna` is a **static** network library. Dynet is a temporal one. Where Dynet has a
match for an `sna` statistic, the match is almost always **"the same statistic
recomputed on each time bin"** — `metrics()` and `dyn_centrality(scope =
"snapshot")` slice the timeline and hand the slice to the same formula. That is
a time series of a static index, *not* a temporal generalisation of it. Only four
quantities in Dynet are genuinely temporal (`scope = "temporal"`: closeness,
betweenness, reach, reach_count) plus `paths()`, `dyn_reachability()`,
`durations()`, `events()`, `burstiness()`, `pshifts()` and `projection()`.

In the other direction: 273 `sna` exports, and roughly 40 of them have any Dynet
counterpart at all. `sna` covers whole research programmes — Bayesian network
accuracy models, biased nets, QAP/CUG inference, network regression, blockmodels,
graph-distance MDS, two- and three-dimensional layout engines — that Dynet does
not attempt and is not trying to attempt.

---

# 1. `tsna` 0.3.6 — 18 exports

`tsna` is the closest thing to a direct predecessor: same problem, same
`networkDynamic` substrate. Dynet reproduces most of it and is a superset in
several places. Dynet reads `networkDynamic` directly via `as_dynet()`, so every
row below was checked on the *same* object.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tPath` | Forward/backward time-respecting path search from one seed vertex; returns per-vertex arrival time (`tdist`), predecessor and hop count (`gsteps`). | `paths(dn, from = "1", direction = "forward")` | **equivalent** — verified numerically: `tdist` == Dynet `latency`/`arrival_time`, `gsteps` == `n_hops`, on the shared 5-vertex fixture. Dynet adds `n_paths`, `attained`, and session bounding. |
| `is.tPath` | Class predicate for a `tPath` object. | `inherits(x, "dynet_paths")` | n/a (plumbing) |
| `as.network.tPath` | Turns a path search result into a static `network` object of the path tree. | `path_network(paths(dn, from = "1"))` | **equivalent** (doc only) — Dynet returns a tidy edge frame with `weight`, `first_time`, `last_time`, `n_endpoints` rather than a `network`. |
| `plot.tPath` | Plots the source network with one temporal path highlighted. | `plot(paths(dn, from = "1"))` | partial (doc only) — Dynet plots the path result; highlighting-on-source is not the same layout contract. |
| `plotPaths` | Plots several temporal paths highlighted on one network. | `plot_path_trajectories(paths(dn, from = "1"))` | partial (doc only) — Dynet draws a trajectory tree (frequency / time / predictability), not an overlay on the source layout. |
| `forward.reachable` | Set of vertices reachable forward in time from a seed set (deprecated inside tsna in favour of `tPath`). | `paths(dn, from = ..., direction = "forward")` | **equivalent** (doc only) |
| `tReach` | Size of the forward or backward temporally reachable set for every vertex. | `dyn_reachability(dn, direction = "forward", measure = "reach_count")` | **equivalent** — verified numerically. Note the convention: `tReach` counts the vertex itself (5 on a 5-vertex fixture); Dynet's `reach_count` excludes ego (4) and `measure = "reach"` reports the fraction. |
| `tDegree` | Momentary degree of every vertex at a series of timepoints. | `dyn_centrality(dn, measure = "degree", mode = "all", step = 2, window = 0)` | **equivalent** — verified numerically, whole 6x5 series identical. |
| `tEdgeFormation` | Count (or fraction) of edges forming in each time interval. | `events(dn, measure = "formation", step = 1)` | **equivalent** — verified numerically, all 11 bins identical. |
| `tEdgeDissolution` | Count (or fraction) of edges dissolving in each time interval. | `events(dn, measure = "dissolution", step = 1)` | **equivalent** — verified numerically, all 11 bins identical. |
| `tEdgeDensity` | Fraction of possible edge-time that is actually occupied, per edge (`agg.unit = "edge"`) or per dyad (`agg.unit = "dyad"`). | `metrics(dn, measure = "observed_pair_density")` and `metrics(dn, measure = "temporal_density")` | **equivalent** — verified numerically: `tEdgeDensity()` = 0.3230769 = Dynet `observed_pair_density`; `tEdgeDensity(agg.unit = "dyad")` = 0.21 = Dynet `temporal_density`. The names are swapped relative to intuition, so read the definition, not the label. |
| `edgeDuration` | Total active duration (or spell count) per edge. | `durations(dn, measure = "total", unit = "pair")` / `measure = "events"` | **equivalent** — verified numerically as a multiset (identical values, different edge ordering). `durations(unit = "spell", measure = "duration")` gives the per-spell breakdown tsna does not. |
| `vertexDuration` | Total active duration (or spell count) per vertex. | `durations(dn, measure = "total", unit = "vertex_activity")` / `measure = "events"` | **equivalent** — verified numerically (10,10,10,10,10 and 1,1,1,1,1). |
| `tiedDuration` | Duration a vertex spends tied to at least one other, or the count of such episodes. | `durations(dn, measure = "total", unit = "node_ties")` / `measure = "events"` | **equivalent** — verified numerically (10,10,9,7,6 and 4,3,3,2,2). Beware: passing `mode = "all"` instead of the default `mode = "out"` returns the *sum* over incident ties (19,16,16,16,17), a different quantity. |
| `tSnaStats` | Applies any `sna` graph- or vertex-level statistic at a series of timepoints. | `metrics(dn, measure = ...)` / `dyn_centrality(dn, measure = ..., scope = "snapshot")` | partial — verified numerically for `gden` and `connectedness` (both series identical). `tSnaStats` is a generic bridge to all 273 `sna` exports; Dynet's is a fixed, curated selector list. Wider where they overlap, narrower overall. |
| `tErgmStats` | Evaluates arbitrary `ergm` summary terms at a series of timepoints. | `metrics(dn, measure = c("edges", "triangles", "mean_degree", "in_2stars", "out_2stars", "indegree_1_5", "outdegree_1_5", "concurrent_nodes", "two_paths"))` | partial — verified numerically for `~edges + triangle + meandeg`, all six bins identical. Dynet hard-codes a dozen ERGM-flavoured statistics; `tErgmStats` accepts any ergm formula. |
| `timeProjectedNetwork` | Builds the time-expanded ("multi-slice") static network: one vertex per (vertex, slice), identity arcs forward in time, edges within slices. | `projection(dn, step = 1)` | partial — verified structurally: `timeProjectedNetwork` gave 50 vertices / 87 edges; `projection()` returned 50 (node, slice) state rows with `state`, `slice`, `time`, `start`, `end`, `node`, `active`. Same object, tidy frame instead of a `network`; Dynet does not expose the identity/contact arc list as a graph. |
| `pShiftCount` | Counts Gibson's 13 participation shifts in a relational event sequence. | `pshifts(dn)` | **equivalent** (doc only) — `pShiftCount` could **not** be run in this session: it requires `relevent`, which is not installed ("there is no package called 'relevent'"). Dynet's `pshifts()` ran and returned all 13 shift types grouped into the four Gibson families (turn receiving / claiming / usurping / continuing) plus `output = "cumulative"`. |

**tsna coverage:** 12 of 18 exports have an equivalent, 5 partial, 1 plumbing. Nothing in `tsna` is absent from Dynet in kind, though `tSnaStats`/`tErgmStats` are open-ended bridges that Dynet answers with a closed selector list.

---

# 2. `sna` 2.8 — 273 exports

## 2.1 Centrality and prestige (19)

This block plus `metrics()` is essentially the whole overlap between the two
packages. `dyn_centrality(scope = "snapshot")` runs these formulas on each time
bin; on a network with a single bin the result *is* the `sna` result, which is
how the rows below were verified.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `betweenness` | Freeman betweenness; seven `cmode`s (undirected, directed, endpoints, proximalsrc/tgt/sum, length- and linear-scaled). | `dyn_centrality(dn, measure = "betweenness")` | partial — verified numerically equal to `betweenness(A, gmode = "digraph")`. Dynet exposes only the plain directed/undirected definition; the six alternative `cmode`s have no Dynet argument. |
| `betweenness_R` | Pure-R reference implementation behind `betweenness`. | — | n/a (internal alternative implementation) |
| `bonpow` | Bonacich power centrality with attenuation `exponent`; negative values give the bargaining reading. | `dyn_centrality(dn, measure = "power", exponent = 1)` | **equivalent** — verified numerically against `bonpow(A, exponent = 1)`. |
| `brokerage` | Gould-Fernandez brokerage: classifies each vertex's mediating role (coordinator, gatekeeper, representative, consultant, liaison) given a partition. | — | none |
| `brokerage_R` | Pure-R implementation behind `brokerage`. | — | n/a |
| `closeness` | Closeness centrality; `cmode` in directed, undirected, suminvdir, suminvundir, gil-schmidt. | `dyn_centrality(dn, measure = "closeness", mode = "out")` (== `cmode = "directed"`), `mode = "all"` (== `cmode = "undirected"`), `mode = "in"` (== `closeness(t(A))`) | partial — verified numerically for all three of those mappings on the 7-vertex fixture. The harmonic (`suminv*`) and Gil-Schmidt variants have no Dynet counterpart. |
| `degree` | Degree centrality; `cmode` freeman / indegree / outdegree, optional `ignore.eval` and `rescale`. | `dyn_centrality(dn, measure = "degree", mode = c("all","in","out"))` | **equivalent** — verified numerically for all three `cmode`s. Dynet also has `measure = "strength"` for the valued version. |
| `degree_R` | Pure-R implementation behind `degree`. | — | n/a |
| `evcent` | Eigenvector centrality (principal eigenvector of the symmetrised adjacency), optionally rescaled to sum 1. | `dyn_centrality(dn, measure = "eigenvector", mode = "out")` | **equivalent** — verified numerically: Dynet's vector rescaled to unit L2 norm is exactly `evcent(A, gmode = "digraph")`. Dynet normalises to max = 1, `sna` to L2 = 1; the ranking is identical. `mode = "all"` gives a different (multiplicity-counting) vector, so use `"out"` to reproduce `sna`. |
| `evcent_R` | Pure-R implementation behind `evcent`. | — | n/a |
| `flowbet` | Flow betweenness — maximum-flow analogue of betweenness. | `dyn_centrality(dn, measure = "flow_betweenness")` | **equivalent** — verified numerically against `flowbet(A, gmode = "digraph")`. |
| `gilschmidt` | Gil-Schmidt power index: reachable fraction divided by mean geodesic distance to reachables. | — | none — closest is prestige `"domain.proximity"`, but that is an *incoming* domain measure, not the same index. |
| `gilschmidt_R` | Pure-R implementation behind `gilschmidt`. | — | n/a |
| `graphcent` | Harary graph centrality: reciprocal of eccentricity. | `dyn_centrality(dn, measure = "harary")` | **equivalent** — verified numerically against `graphcent(A, gmode = "digraph")`. |
| `infocent` | Stephenson-Zelen information centrality (harmonic mean of all path information). | `dyn_centrality(dn, measure = "information")` | **equivalent** — verified numerically against `infocent(A, gmode = "digraph")`. |
| `loadcent` | Goh load centrality: share of unit flow passing through each vertex. | `dyn_centrality(dn, measure = "load")` | partial — verified numerically: Dynet = `loadcent(A) - (2n - 1)` exactly, on both fixtures (offset 11 at n = 6, 13 at n = 7). The two differ by a constant endpoint convention, so rank order agrees but the numbers do not. |
| `prestige` | Vertex prestige, nine `cmode`s: `indegree`, `indegree.rownorm`, `indegree.rowcolnorm`, `eigenvector`, `eigenvector.rownorm`, `eigenvector.colnorm`, `eigenvector.rowcolnorm`, `domain`, `domain.proximity`. | `dyn_centrality(dn, measure = "prestige", prestige = "<same name>", rescale = )` | **equivalent** — see the dedicated section 2.1a below. |
| `stresscent` | Shimbel stress centrality: raw count of shortest paths through a vertex. | — | none — Dynet has `betweenness` and `load` but not the unnormalised path count. (Confirmed distinct: `stresscent` gave 7,1,7,3,1,3 where Dynet `load` gave 5.5,1,5.5,1.5,1,1.5.) |
| `stresscent_R` | Pure-R implementation behind `stresscent`. | — | n/a |

### 2.1a The prestige family — the richest overlap

Nine `sna::prestige()` `cmode`s against nine Dynet `prestige =` values. Verified on
the 6-vertex directed fixture, `all.equal(tolerance = 1e-8)`.

| `sna::prestige(cmode = )` | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `"indegree"` | Column sums of the adjacency matrix — how many others send to you. | `dyn_centrality(dn, measure = "prestige", prestige = "indegree")` | **equivalent** — verified numerically (3,2,3,2,2,2 both sides). Identical to `measure = "degree", mode = "in"`. |
| `"indegree.rownorm"` | Row-normalise first (each sender splits one unit across its out-ties), then take column sums. | `dyn_centrality(dn, measure = "prestige", prestige = "indegree.rownorm")` | **equivalent** — verified numerically. Dynet binarises the adjacency; `sna` uses valued magnitudes, so they diverge on a weighted network by design. |
| `"indegree.rowcolnorm"` | Row-column normalise (Sinkhorn-Knopp toward doubly stochastic), then column sums. | `dyn_centrality(dn, measure = "prestige", prestige = "indegree.rowcolnorm")` | partial, **deliberately different** — verified numerically and they disagree: Dynet returned exactly `1 1 1 1 1 1`; `sna` 2.8 returned `1.0127 1.0086 0.9998 0.9907 0.9997 1.0040`. Dynet runs deterministic fixed-order Sinkhorn sweeps to residual 1e-12 (max 10,000 sweeps) after certifying total support; `sna` 2.8 uses a randomised loose-tolerance annealer. The mathematically correct answer for a feasible block *is* uniform 1, so Dynet's is the exact one and `sna`'s is an unconverged iterate. |
| `"domain"` | Number of distinct others with a directed path into the vertex (in-degree in the reachability graph, diagonal excluded). | `dyn_centrality(dn, measure = "prestige", prestige = "domain")` | **equivalent** — verified numerically. Cross-checked against `rowSums(sna::reachability(A))`: Dynet domain + 1 == 7,7,7,7,7,7,7 on the fully-reachable 7-vertex fixture. |
| `"domain.proximity"` | Incoming domain fraction discounted by mean directed hop distance. | `dyn_centrality(dn, measure = "prestige", prestige = "domain.proximity")` | **equivalent** — verified numerically on this fixture. Dynet's docs record a deliberate divergence for *partial* domains: `sna` 2.8 performs a `FALSE * Inf` that zeroes a nonempty partial domain, which Dynet fixes. The fixture used here has full domains, so this session did not exercise the divergent branch. |
| `"eigenvector"` | Nonnegative Perron ray of the transposed adjacency — recursive incoming prestige. | `dyn_centrality(dn, measure = "prestige", prestige = "eigenvector")` | **equivalent** — verified numerically. Dynet certifies a one-dimensional Perron eigenspace by SVD nullity/residual at 1e-10 and returns `NA` with a classed warning when the eigenvector is not unique, where `sna` takes an elementwise absolute value and returns a number regardless. |
| `"eigenvector.rownorm"` | Row-stochastic normalisation, then the incoming Perron equation. | `dyn_centrality(dn, measure = "prestige", prestige = "eigenvector.rownorm")` | **equivalent** (doc only) — Dynet returned 0.5145, 0.3430, 0.5145, 0.3430, 0.3430, 0.3430 on the fixture; the two definitions agree on binary input by construction, but this row was not cross-run against `sna`. |
| `"eigenvector.colnorm"` | Column-stochastic normalisation, then the incoming Perron equation. | `dyn_centrality(dn, measure = "prestige", prestige = "eigenvector.colnorm")` | **equivalent** (doc only) — Dynet returned uniform 0.4082 on the fixture. |
| `"eigenvector.rowcolnorm"` | Doubly stochastic balancing, then the incoming Perron equation. | `dyn_centrality(dn, measure = "prestige", prestige = "eigenvector.rowcolnorm")` | partial (doc only) — same Sinkhorn tolerance divergence as `indegree.rowcolnorm`; Dynet returned uniform 0.4082. |

`rescale = TRUE` divides prestige by its block total, matching `sna`'s `rescale`
argument, with the documented difference that a zero total returns literal `NaN`
rather than a silent number.

## 2.2 Structure, census and graph-level indices (31)

Dynet's `metrics()` is the counterpart to this whole block. Its selector list,
read from `?metrics` and confirmed by running each one:
`density`, `edges`, `active_nodes`, `isolates`, `transitivity`, `reciprocity`,
`components`, `components_strong`, `largest_component`, `mean_distance`,
`diameter`, `mutual`, `asymmetric`, `null`, `assortativity`,
`centralization_degree`, `centralization_betweenness`, `centralization_closeness`,
`triads` (expands to all sixteen classes), `connectedness`, `efficiency`,
`hierarchy`, `lubness`, `degree_mean`, `degree_variance`, `degree_min`,
`degree_max`, `mean_degree`, `indegree_1_5`, `outdegree_1_5`, `triangles`,
`concurrent_nodes`, `concurrent_share`, `in_2stars`, `out_2stars`, `two_paths`,
`temporal_density`, `observed_pair_density`, `onset_intensity`,
`observed_pair_onset_intensity` — 40 selectors, of which the last four are
genuinely window-integrated temporal quantities with no `sna` analogue.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `centralization` | Freeman centralization of any supplied vertex-level index, against its theoretical maximum. | `metrics(dn, measure = c("centralization_degree", "centralization_betweenness", "centralization_closeness"))` | partial — verified numerically: degree and betweenness centralization match `centralization(A, degree/betweenness, mode = "digraph")` exactly; **closeness centralization disagreed** (Dynet 0.127904 vs `sna` 0.149221 `directed`, 0.061111 `undirected`, 0.018904 `suminvdir`) — a different normalising denominator. `sna` centralizes any index; Dynet offers exactly three. |
| `gden` | Graph density. | `metrics(dn, measure = "density")` | **equivalent** — verified numerically for both directed and undirected fixtures. |
| `gtrans` | Transitivity (weak, strong, weakcensus, strongcensus, rank, correlation). | `metrics(dn, measure = "transitivity")` | partial — verified numerically against the default `gtrans(A, mode = "digraph")` and `mode = "graph"`. Dynet has one definition; `sna` has six. |
| `transitivity_R` | Pure-R implementation behind `gtrans`. | — | n/a |
| `grecip` | Reciprocity (dyadic, dyadic.nonnull, edgewise, edgewise.lrr, correlation). | `metrics(dn, measure = "reciprocity")` | partial — verified numerically: Dynet 0.375 == `grecip(A, measure = "edgewise")`, **not** the `sna` default `dyadic.nonnull` (0.2308). Dynet exposes only the edgewise definition. |
| `mutuality` | Count of mutual (reciprocated) dyads. | `metrics(dn, measure = "mutual")` | **equivalent** — verified numerically. |
| `dyad.census` | Holland-Leinhardt M/A/N dyad census. | `metrics(dn, measure = c("mutual", "asymmetric", "null"))` | **equivalent** — verified numerically, all three cells. |
| `triad.census` | Davis-Leinhardt sixteen-class triad census (directed) or four-class (undirected). | `metrics(dn, measure = "triads")` | **equivalent** — verified numerically: all sixteen classes identical (003 0, 012 9, 102 2, 021D 2, 021U 2, 021C 6, 111D 4, 111U 3, 030T 2, 030C 0, 201 1, 120D 1, 120U 0, 120C 3, 210 0, 300 0). |
| `triad_census_R` | Pure-R implementation behind `triad.census`. | — | n/a |
| `triad.classify` | Returns the MAN class label of one specified triad. | — | none — Dynet gives the census, not per-triad classification. |
| `triad_classify_R` | Pure-R implementation behind `triad.classify`. | — | n/a |
| `hierarchy` | Krackhardt hierarchy (or reciprocity-based) index. | `metrics(dn, measure = "hierarchy")` | **equivalent** — verified numerically against `hierarchy(A, measure = "krackhardt")`. Dynet reports `NaN` where the index is undefined rather than a misleading number. |
| `connectedness` | Krackhardt connectedness: fraction of dyads that are weakly connected. | `metrics(dn, measure = "connectedness")` | **equivalent** — verified numerically, and again through `tsna::tSnaStats(snafun = "connectedness")` over six bins. |
| `connectedness_R` | Pure-R implementation behind `connectedness`. | — | n/a |
| `efficiency` | Krackhardt efficiency: how close the edge count is to the spanning-tree minimum. | `metrics(dn, measure = "efficiency")` | **equivalent** — verified numerically. |
| `lubness` | Krackhardt least-upper-boundedness. | `metrics(dn, measure = "lubness")` | **equivalent** — verified numerically. |
| `lubness_con_R` | Pure-R helper behind `lubness`. | — | n/a |
| `clique.census` | Maximal clique census with per-vertex and co-membership breakdowns. | — | none |
| `cliques_R` | Pure-R implementation behind `clique.census`. | — | n/a |
| `kcycle.census` | Counts cycles up to length k, with per-vertex and per-edge co-membership. | — | none |
| `kpath.census` | Counts paths up to length k, with per-vertex and per-edge co-membership. | — | partial only in the loosest sense: `metrics(dn, measure = "two_paths")` counts ordered two-paths, nothing beyond. |
| `cycleCensus_R` | Pure-R implementation behind `kcycle.census`. | — | n/a |
| `pathCensus_R` | Pure-R implementation behind `kpath.census`. | — | n/a |
| `kcores` | k-core decomposition; `cmode` freeman/indegree/outdegree, valued cores supported. | `dyn_centrality(dn, measure = "coreness", mode = "all")` | partial — verified numerically against `kcores(A, mode = "digraph", cmode = "freeman")` (3,3,3,3,3,3,3 both sides). `mode = "in"`/`"out"` in Dynet is documented as supported for coreness; only `freeman` was cross-run. |
| `kcores_R` | Pure-R implementation behind `kcores`. | — | n/a |
| `simmelian` | Extracts the Simmelian tie structure (ties embedded in a reciprocated triad). | — | none |
| `structure.statistics` | The cumulative fraction of vertex pairs within distance 0, 1, ..., n-1. | — | partial — `metrics(dn, measure = c("mean_distance", "diameter"))` gives two summaries of the same distance distribution but not the full curve. `sna` returned 0.1429 0.4694 0.8163 0.9796 1 1 1 on the fixture; Dynet has no vector-valued equivalent. |
| `nties` | Number of *possible* ties given size, mode and diagonal policy. | — | n/a (denominator helper; Dynet computes it internally for `density`) |
| `gliop` | Applies a binary operator to a graph-level index computed on two graphs. | — | n/a (helper for `cugtest`/`qaptest`) |
| `eval.edgeperturbation` | Effect on a structural index of adding/removing a single edge. | — | none |
| `centralgraph` | The "central graph" (elementwise median) of a stack of labelled graphs. | — | none — Dynet's `collapse_network()` aggregates a *timeline*, not a stack of parallel observations. |

Dynet-side selectors verified numerically against hand-computed `sna` quantities
in this session: `degree_mean` = `mean(degree(A))`, `degree_variance` =
`var(degree(A))`, `degree_min`/`degree_max` = `range(degree(A))`, `in_2stars` =
`sum(choose(indegree, 2))`, `out_2stars` = `sum(choose(outdegree, 2))`,
`indegree_1_5` = `sum(indegree^1.5)`, `largest_component` =
`max(component.dist(A)$csize)/n` — all matched.

## 2.3 Connectivity, components, distance and flow (25)

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `bicomponent.dist` | Bicomponents (2-connected blocks): membership, sizes, cut structure. | — | none |
| `bicomponents_R` | Pure-R implementation behind `bicomponent.dist`. | — | n/a |
| `component.dist` | Component membership and the component size distribution (weak/strong/unilateral/recursive). | `metrics(dn, measure = c("components", "components_strong", "largest_component"))` | partial — verified numerically for the weak and strong component *counts* and for the largest-component share. Dynet returns counts and a share, not per-vertex membership or the full size distribution. |
| `component_dist_R` | Pure-R implementation behind `component.dist`. | — | n/a |
| `component.largest` | The largest component, as a membership indicator or an induced subgraph. | `metrics(dn, measure = "largest_component")` | partial — verified numerically that Dynet's value is `max(csize)/n`, i.e. the *share*, not the vertex set. `induce_subgraph()` can extract a set but will not find it for you. |
| `component.size.byvertex` | Size of each vertex's own component. | — | none |
| `compsizes_R` | Pure-R implementation behind `component.size.byvertex`. | — | n/a |
| `components` | Number of maximal components (weak or strong). | `metrics(dn, measure = "components")` / `"components_strong"` | **equivalent** — verified numerically for both. |
| `undirComponents_R` | Pure-R undirected component finder. | — | n/a |
| `cutpoints` | Vertices whose removal increases the component count. | — | none |
| `cutpointsDir_R` | Pure-R directed cutpoint finder. | — | n/a |
| `cutpointsUndir_R` | Pure-R undirected cutpoint finder. | — | n/a |
| `geodist` | Full geodesic distance matrix plus shortest-path counts. | `metrics(dn, measure = c("mean_distance", "diameter"))` | partial — verified numerically that Dynet's `mean_distance` equals the mean finite off-diagonal `geodist(A)$gdist` and `diameter` equals its finite max. The distance *matrix* itself is not exposed. |
| `geodist_R` | Pure-R BFS geodesic backend behind `geodist`. | — | n/a |
| `geodist_adj_R` | Pure-R adjacency-based geodesic backend. | — | n/a |
| `geodist_val_R` | Pure-R valued (weighted) geodesic backend. | — | n/a |
| `is.connected` | Whether the graph is (weakly/strongly/unilaterally/recursively) connected. | `metrics(dn, measure = "components")` | partial (doc only) — a count of 1 answers the weak case; there is no boolean verb. |
| `is.isolate` | Whether a given vertex is an isolate. | `metrics(dn, measure = "isolates")` | partial — verified numerically that Dynet's count equals `length(sna::isolates(A))`; per-vertex testing needs `dyn_centrality(measure = "degree")` and reading the zeros. |
| `isolates` | Lists the isolates in a graph or stack. | `metrics(dn, measure = "isolates")` | partial — verified numerically as a count; Dynet returns the number, `sna` the identities. |
| `maxflow` | Maximum flow between vertex pairs (Edmonds-Karp). | — | none as a verb — used internally by `dyn_centrality(measure = "flow_betweenness")`, which was verified against `sna::flowbet`. |
| `maxflow_EK_R` | Pure-R Edmonds-Karp backend. | — | n/a |
| `neighborhood` | Adjacency at a given geodesic order (in/out/total/union), cumulative or not. | — | none |
| `reachability` | Full binary reachability matrix. | `dyn_reachability(dn)` (temporal), or `dyn_centrality(measure = "prestige", prestige = "domain")` (per snapshot) | partial — verified numerically that Dynet's snapshot `domain` prestige + 1 equals `rowSums(reachability(A))` on the fully-connected fixture. Dynet's `dyn_reachability()` is the genuinely temporal version and is *not* the same object: it respects time order, so it cannot run backwards through the timeline the way the static closure does. |
| `reachability_R` | Pure-R implementation behind `reachability`. | — | n/a |
| `ego.extract` | Extracts egocentric (ego + alters) subnetworks. | `induce_subgraph(dn, nodes = ...)` | partial (doc only) — Dynet induces on a supplied node set; it does not compute the neighbourhood for you. |

## 2.4 Blockmodelling, equivalence and positional analysis (6)

Nothing in this block has a Dynet counterpart. Dynet has no notion of positions,
roles or structural equivalence.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `blockmodel` | Builds a blockmodel from a partition of positions: block densities, image matrix, permuted sociomatrix. | — | none |
| `blockmodel.expand` | Generates a graph (or stack) from a blockmodel by an expansion rule. | — | none |
| `equiv.clust` | Hierarchical clustering of vertices by an equivalence relation (structural by default). | — | none |
| `sedist` | Pairwise structural-equivalence distances between positions. | — | none |
| `redist` | Pairwise regular-equivalence distances between positions. | — | none |
| `gclust.centralgraph` | Central graphs for each cluster in a hierarchical clustering of graphs. | — | none |

## 2.5 Graph comparison, distance and labelling (19)

`sna` compares *stacks of graphs on the same vertex set*. Dynet compares *time
bins of one evolving graph*. The two look superficially similar and are not the
same problem: `sna`'s stack has no order, Dynet's does.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `gcor` | Product-moment correlation between two or more labelled graphs. | — | none |
| `gcov` | Covariance between two or more labelled graphs. | — | none |
| `gscor` | Structural correlation (maximised over vertex relabellings). | — | none |
| `gscov` | Structural covariance (maximised over vertex relabellings). | — | none |
| `hdist` | Hamming distance between labelled graphs. | — | none |
| `structdist` | Structural (relabelling-minimised Hamming) distance between graphs. | — | none |
| `sdmat` | Estimated structural-distance matrix for a whole graph stack. | — | none |
| `gdist.plotdiff` | Plots differences in a graph-level index against inter-graph distance. | — | none |
| `gdist.plotstats` | Plots graph statistics over an MDS of inter-graph distances. | — | none |
| `gclust.boxstats` | Boxplots of a graph statistic by cluster of a graph clustering. | — | none |
| `lab.optimize` | Optimises a bivariate graph statistic over accessible vertex relabellings (dispatcher). | — | none |
| `lab.optimize.anneal` | Simulated-annealing relabelling optimiser. | — | none |
| `lab.optimize.exhaustive` | Exhaustive relabelling optimiser. | — | none |
| `lab.optimize.gumbel` | Gumbel extreme-value approximation to the relabelling optimum. | — | none |
| `lab.optimize.hillclimb` | Hill-climbing relabelling optimiser. | — | none |
| `lab.optimize.mc` | Monte Carlo relabelling optimiser. | — | none |
| `numperm` | The nth permutation vector by periodic placement. | — | n/a (plumbing) |
| `rperm` | A random permutation vector honouring exchangeability constraints. | — | n/a (plumbing) |
| `rmperm` | Randomly permutes the rows and columns of a matrix together. | — | n/a (plumbing) |

## 2.6 Regression, inference and statistical models (33)

The entire inferential half of `sna` is absent from Dynet. Dynet computes
descriptives; it does not fit models, test hypotheses or quantify uncertainty.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `bbnam` | Butts' hierarchical Bayesian network accuracy model (dispatcher over the three variants). | — | none |
| `bbnam.actor` | bbnam with actor-specific error rates. | — | none |
| `bbnam.pooled` | bbnam with pooled error rates. | — | none |
| `bbnam.fixed` | bbnam with fixed, known error rates. | — | none |
| `bbnam.bf` | Bayes factors comparing the bbnam variants. | — | none |
| `bbnam.jntlik` | Joint likelihood evaluation inside bbnam. | — | n/a (internal) |
| `bbnam.jntlik.slice` | One slice of the bbnam joint likelihood. | — | n/a (internal) |
| `bbnam.probtie` | Posterior tie probabilities inside bbnam. | — | n/a (internal) |
| `bn` | Fits a Skvoretz-Fararo biased net model by pseudolikelihood or method of moments. | — | none |
| `bn.nlpl.dyad` | Negative dyadic log-pseudolikelihood for `bn`. | — | n/a (internal) |
| `bn.nlpl.edge` | Negative edgewise log-pseudolikelihood for `bn`. | — | n/a (internal) |
| `bn.nlpl.triad` | Negative triadic log-pseudolikelihood for `bn`. | — | n/a (internal) |
| `bn.nltl` | Negative triad-census log-likelihood for `bn`. | — | n/a (internal) |
| `bn_dyadstats_R` | Dyad statistics backend for `bn`. | — | n/a (internal) |
| `bn_triadstats_R` | Triad statistics backend for `bn`. | — | n/a (internal) |
| `bn_lpl_dyad_R` | Dyadic log-pseudolikelihood backend for `bn`. | — | n/a (internal) |
| `bn_lpl_triad_R` | Triadic log-pseudolikelihood backend for `bn`. | — | n/a (internal) |
| `bn_ptriad_R` | Triad probability backend for `bn`. | — | n/a (internal) |
| `bn_cftp_R` | Coupling-from-the-past sampler for the biased net process. | — | n/a (internal) |
| `bn_mcmc_R` | MCMC sampler for the biased net process. | — | n/a (internal) |
| `rgbn` | Draws random graphs from a Skvoretz-Fararo biased net process. | — | none |
| `consensus` | Estimates a consensus network from multiple (CSS) observations. | — | none |
| `cug.test` | Univariate conditional-uniform-graph test of a graph-level index. | — | none |
| `cugtest` | Bivariate CUG hypothesis test (older interface). | — | none |
| `qaptest` | Quadratic assignment procedure test for a graph-level statistic. | — | none |
| `lnam` | Fits a linear network autocorrelation model (network effects on y and on the disturbance). | — | none |
| `se.lnam` | Standard errors for an `lnam` fit. | — | n/a (internal to `lnam`) |
| `netlm` | OLS network regression with QAP/permutation null distributions. | — | none |
| `netlogit` | Logistic network regression with QAP/permutation nulls. | — | none |
| `netcancor` | Canonical correlation between two sets of labelled graphs. | — | none |
| `pstar` | Fits a p*/ERGM by logistic approximation. | — | none |
| `npostpred` | Posterior predictive draws of a function of networks. | — | none |
| `potscalered.mcmc` | Gelman-Rubin potential scale reduction for MCMC chains. | — | n/a (diagnostic plumbing) |
| `nacf` | Sample network covariance/autocorrelation function of a vertex attribute at increasing geodesic lag. | `metrics(dn, measure = "assortativity")` | partial (doc only) — Dynet's assortativity is the degree-assortativity coefficient per bin (it ran and returned -0.0648 on the fixture), which is only the lag-1 special case of what `nacf` sweeps. |

## 2.7 Random graph generators and rewiring (12)

Dynet has no generators at all: no null models, no rewiring, no simulation.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `rgraph` | Draws Bernoulli (Erdos-Renyi) random graphs, optionally with per-tie probabilities. | — | none |
| `rgbern_R` | Pure-R Bernoulli graph backend. | — | n/a |
| `rgnm` | Draws density-conditioned random graphs (fixed edge count). | — | none |
| `rgnmix` | Draws mixing-matrix-conditioned random graphs. | — | none |
| `rguman` | Draws dyad-census (M/A/N) conditioned random graphs. | — | none |
| `rgws` | Draws from the Watts-Strogatz small-world model. | — | none |
| `rewire.ws` | Watts-Strogatz rewiring of an existing graph (edge endpoints). | — | none |
| `rewire.ud` | Uniform-dyad rewiring of an existing graph. | — | none |
| `wsrewire_R` | Pure-R Watts-Strogatz rewiring backend. | — | n/a |
| `udrewire_R` | Pure-R uniform-dyad rewiring backend. | — | n/a |
| `add.isolates` | Appends a given number of isolated vertices to a graph or stack. | `add_nodes(dn, data)` | partial (doc only) — Dynet adds named nodes with attributes; there is no "add k anonymous isolates" idiom. |

## 2.8 Visualization (45)

Dynet plots its own result objects (`plot()` methods on `dynet`, `dynet_metric`,
`dynet_paths`, plus `plot_path_trajectories()`); it does not ship a layout engine.
Layout in this ecosystem is `cograph`'s job, not Dynet's. Every row here is
therefore `none` or `n/a`.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `gplot` | Two-dimensional network plot with pluggable layout, the core `sna` drawing verb. | `plot(dn)` | partial (doc only) — Dynet draws a temporal network; it does not accept `sna`'s layout/parameter vocabulary. |
| `gplot.arrow` | Draws arrows or segments onto an existing plot. | — | n/a (drawing primitive) |
| `gplot.loop` | Draws self-loops onto an existing plot. | — | n/a (drawing primitive) |
| `gplot.vertex` | Draws vertex glyphs onto an existing plot. | — | n/a (drawing primitive) |
| `gplot.target` | Draws a graph as a target (concentric-ring) diagram. | — | none |
| `gplot3d` | Three-dimensional network plot via `rgl`. | — | none |
| `gplot3d.arrow` | Draws arrows in a three-dimensional plot. | — | n/a (drawing primitive) |
| `gplot3d.loop` | Draws self-loops in a three-dimensional plot. | — | n/a (drawing primitive) |
| `gplot.layout.adj` | 2D layout from a scaling of the adjacency matrix. | — | n/a (layout) |
| `gplot.layout.circle` | 2D circular layout. | — | n/a (layout) |
| `gplot.layout.circrand` | 2D layout: random points in an annulus. | — | n/a (layout) |
| `gplot.layout.eigen` | 2D layout from adjacency eigenvectors. | — | n/a (layout) |
| `gplot.layout.fruchtermanreingold` | 2D Fruchterman-Reingold force-directed layout. | — | n/a (layout) |
| `gplot.layout.geodist` | 2D layout from scaling the geodesic distance matrix. | — | n/a (layout) |
| `gplot.layout.hall` | 2D Hall (Laplacian eigenvector) layout. | — | n/a (layout) |
| `gplot.layout.kamadakawai` | 2D Kamada-Kawai energy-minimisation layout. | — | n/a (layout) |
| `gplot.layout.mds` | 2D metric MDS layout on a supplied dissimilarity. | — | n/a (layout) |
| `gplot.layout.princoord` | 2D principal-coordinates layout. | — | n/a (layout) |
| `gplot.layout.random` | 2D uniformly random layout. | — | n/a (layout) |
| `gplot.layout.rmds` | 2D MDS layout on the Euclidean row distances of the adjacency. | — | n/a (layout) |
| `gplot.layout.segeo` | 2D layout on structural-equivalence-of-geodesics distances. | — | n/a (layout) |
| `gplot.layout.seham` | 2D layout on structural-equivalence Hamming distances. | — | n/a (layout) |
| `gplot.layout.spring` | 2D spring-embedder layout. | — | n/a (layout) |
| `gplot.layout.springrepulse` | 2D spring embedder with an added repulsion term. | — | n/a (layout) |
| `gplot.layout.target` | 2D layout placing vertices on rings by a centrality score. | — | n/a (layout) |
| `gplot_layout_fruchtermanreingold_R` | Pure-R Fruchterman-Reingold backend. | — | n/a |
| `gplot_layout_fruchtermanreingold_old_R` | Legacy pure-R Fruchterman-Reingold backend. | — | n/a |
| `gplot_layout_kamadakawai_R` | Pure-R Kamada-Kawai backend. | — | n/a |
| `gplot_layout_target_R` | Pure-R target-diagram layout backend. | — | n/a |
| `gplot3d.layout.adj` | 3D adjacency-scaling layout. | — | n/a (layout) |
| `gplot3d.layout.eigen` | 3D eigenvector layout. | — | n/a (layout) |
| `gplot3d.layout.fruchtermanreingold` | 3D Fruchterman-Reingold layout. | — | n/a (layout) |
| `gplot3d.layout.geodist` | 3D geodesic-scaling layout. | — | n/a (layout) |
| `gplot3d.layout.hall` | 3D Hall layout. | — | n/a (layout) |
| `gplot3d.layout.kamadakawai` | 3D Kamada-Kawai layout. | — | n/a (layout) |
| `gplot3d.layout.mds` | 3D metric MDS layout. | — | n/a (layout) |
| `gplot3d.layout.princoord` | 3D principal-coordinates layout. | — | n/a (layout) |
| `gplot3d.layout.random` | 3D random layout. | — | n/a (layout) |
| `gplot3d.layout.rmds` | 3D MDS layout on Euclidean adjacency-row distances. | — | n/a (layout) |
| `gplot3d.layout.segeo` | 3D structural-equivalence-of-geodesics layout. | — | n/a (layout) |
| `gplot3d.layout.seham` | 3D structural-equivalence Hamming layout. | — | n/a (layout) |
| `gplot3d_layout_fruchtermanreingold_R` | Pure-R 3D Fruchterman-Reingold backend. | — | n/a |
| `gplot3d_layout_kamadakawai_R` | Pure-R 3D Kamada-Kawai backend. | — | n/a |
| `plot.sociomatrix` | Plots an adjacency matrix as a colour/intensity grid. | — | none |
| `sociomatrixplot` | Same as `plot.sociomatrix`, non-method spelling. | — | none |

## 2.9 Coercion, I/O and matrix plumbing (27)

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `%c%.matrix` | Graph composition operator: the relational product of two adjacency matrices. | — | none |
| `as.edgelist.sna` | Coerces a graph to `sna`'s edgelist representation. | `as.data.frame(dn)` | n/a (coercion) |
| `as.sociomatrix.sna` | Coerces a graph (or stack) to an adjacency matrix. | `as.data.frame(collapse_network(dn))` | n/a (coercion) — Dynet returns a tidy edge frame, deliberately not a matrix. |
| `is.edgelist.sna` | Predicate for the `sna` edgelist form. | — | n/a |
| `diag.remove` | Sets the diagonal of every matrix in a stack to `NA`. | — | n/a (matrix hygiene; Dynet's `loops = FALSE` covers the intent at construction) |
| `lower.tri.remove` | Sets the lower triangle of a stack to `NA`. | — | n/a |
| `upper.tri.remove` | Sets the upper triangle of a stack to `NA`. | — | n/a |
| `event2dichot` | Dichotomises a valued/event matrix by a threshold rule. | — | n/a — Dynet binarises at snapshot construction; there is no user-facing threshold verb. |
| `gt` | Transposes a graph (reverses arc direction). | — | none |
| `gvectorize` | Flattens adjacency matrices into tie vectors (for regression/QAP input). | — | n/a |
| `interval.graph` | Converts spell data to an interval graph, one vertex per spell, edges for temporal overlap. | — | none — this is the one genuinely temporal idea in `sna`, and Dynet has no interval-graph construction. |
| `make.stochastic` | Row-, column- or row-column-normalises a graph stack. | `dyn_centrality(dn, measure = "prestige", prestige = "indegree.rownorm" / "indegree.rowcolnorm")` | partial — the normalisations are the same family and were verified numerically at the prestige level (see 2.1a), but `make.stochastic` returns the normalised matrix and Dynet returns only the derived score. |
| `read.dot` | Reads a Graphviz DOT file. | — | none |
| `read.nos` | Reads a Neo-OrgStat input file. | — | none |
| `write.dl` | Writes graphs in UCINET DL format. | — | none |
| `write.nos` | Writes graphs in Neo-OrgStat format. | — | none |
| `sr2css` | Converts a row-wise self-report matrix to a CSS array with missing observations. | — | none |
| `stackcount` | Number of graphs in a stack. | — | n/a — Dynet's analogue is the number of time bins, implicit in any `metrics()` result. |
| `symmetrize` | Symmetrises an adjacency matrix (weak/strong/upper/lower rules). | `dynet(data, directed = FALSE)` | partial — verified numerically that Dynet's undirected `density` and `transitivity` equal `gden`/`gtrans` on `symmetrize(A, rule = "weak")`. Only the weak rule is reachable; the other three are not. |
| `gapply` | Applies a function over each vertex's neighbourhood. | — | none |
| `aggarray3d_R` | Internal 3D array aggregation helper. | — | n/a |
| `dyadcode_R` | Internal dyad-index encoder. | — | n/a |
| `logadd_R` | Internal log-space addition. | — | n/a |
| `logsub_R` | Internal log-space subtraction. | — | n/a |
| `logSum` | Log-space sum (log-sum-exp). | — | n/a |
| `logSub` | Log-space subtraction. | — | n/a |
| `logMean` | Log-space mean. | — | n/a |

## 2.10 S3 print / summary / plot / coef methods (56)

All plumbing for `sna`'s own result classes. Dynet has the parallel machinery for
its own classes (`print`/`summary`/`plot`/`as.data.frame` on `dynet`,
`dynet_metric`, `dynet_paths`, `dynet_collapsed`, `dynet_projection`,
`dynet_path_network`), but there is nothing to map one onto the other.

| Function | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `coef.bn` | Coefficients from a biased net fit. | — | n/a |
| `coef.lnam` | Coefficients from an `lnam` fit. | — | n/a |
| `plot.bbnam` | Posterior plots for a `bbnam` fit. | — | n/a |
| `plot.bbnam.actor` | Posterior plots for the actor-variance `bbnam`. | — | n/a |
| `plot.bbnam.fixed` | Posterior plots for the fixed-error `bbnam`. | — | n/a |
| `plot.bbnam.pooled` | Posterior plots for the pooled-error `bbnam`. | — | n/a |
| `plot.blockmodel` | Plots a blockmodel's permuted sociomatrix. | — | n/a |
| `plot.bn` | Diagnostic plots for a biased net fit. | — | n/a |
| `plot.cug.test` | Plots the CUG null distribution against the observed value. | — | n/a |
| `plot.cugtest` | Plots the older bivariate CUG test. | — | n/a |
| `plot.equiv.clust` | Plots the equivalence dendrogram. | — | n/a |
| `plot.lnam` | Diagnostic plots for an `lnam` fit. | — | n/a |
| `plot.qaptest` | Plots the QAP null distribution against the observed value. | — | n/a |
| `print.bayes.factor` | Prints a Bayes factor object. | — | n/a |
| `print.bbnam` | Prints a `bbnam` fit. | — | n/a |
| `print.bbnam.actor` | Prints an actor-variance `bbnam` fit. | — | n/a |
| `print.bbnam.fixed` | Prints a fixed-error `bbnam` fit. | — | n/a |
| `print.bbnam.pooled` | Prints a pooled-error `bbnam` fit. | — | n/a |
| `print.blockmodel` | Prints a blockmodel. | — | n/a |
| `print.bn` | Prints a biased net fit. | — | n/a |
| `print.cug.test` | Prints a univariate CUG test. | — | n/a |
| `print.cugtest` | Prints a bivariate CUG test. | — | n/a |
| `print.equiv.clust` | Prints an equivalence clustering. | — | n/a |
| `print.lnam` | Prints an `lnam` fit. | — | n/a |
| `print.netcancor` | Prints a network canonical correlation. | — | n/a |
| `print.netlm` | Prints a network OLS fit. | — | n/a |
| `print.netlogit` | Prints a network logit fit. | — | n/a |
| `print.qaptest` | Prints a QAP test. | — | n/a |
| `print.summary.bayes.factor` | Prints the detailed Bayes factor summary. | — | n/a |
| `print.summary.bbnam` | Prints the detailed `bbnam` summary. | — | n/a |
| `print.summary.bbnam.actor` | Prints the detailed actor-variance `bbnam` summary. | — | n/a |
| `print.summary.bbnam.fixed` | Prints the detailed fixed-error `bbnam` summary. | — | n/a |
| `print.summary.bbnam.pooled` | Prints the detailed pooled-error `bbnam` summary. | — | n/a |
| `print.summary.blockmodel` | Prints the detailed blockmodel summary. | — | n/a |
| `print.summary.bn` | Prints the detailed biased net summary. | — | n/a |
| `print.summary.brokerage` | Prints the detailed brokerage summary. | — | n/a |
| `print.summary.cugtest` | Prints the detailed CUG test summary. | — | n/a |
| `print.summary.lnam` | Prints the detailed `lnam` summary. | — | n/a |
| `print.summary.netcancor` | Prints the detailed `netcancor` summary. | — | n/a |
| `print.summary.netlm` | Prints the detailed `netlm` summary. | — | n/a |
| `print.summary.netlogit` | Prints the detailed `netlogit` summary. | — | n/a |
| `print.summary.qaptest` | Prints the detailed QAP test summary. | — | n/a |
| `summary.bayes.factor` | Detailed summary of a Bayes factor object. | — | n/a |
| `summary.bbnam` | Detailed summary of a `bbnam` fit. | — | n/a |
| `summary.bbnam.actor` | Detailed summary of an actor-variance `bbnam` fit. | — | n/a |
| `summary.bbnam.fixed` | Detailed summary of a fixed-error `bbnam` fit. | — | n/a |
| `summary.bbnam.pooled` | Detailed summary of a pooled-error `bbnam` fit. | — | n/a |
| `summary.blockmodel` | Detailed summary of a blockmodel. | — | n/a |
| `summary.bn` | Detailed summary of a biased net fit. | — | n/a |
| `summary.brokerage` | Detailed summary of a brokerage analysis. | — | n/a |
| `summary.cugtest` | Detailed summary of a CUG test. | — | n/a |
| `summary.lnam` | Detailed summary of an `lnam` fit. | — | n/a |
| `summary.netcancor` | Detailed summary of a `netcancor` fit. | — | n/a |
| `summary.netlm` | Detailed summary of a `netlm` fit. | — | n/a |
| `summary.netlogit` | Detailed summary of a `netlogit` fit. | — | n/a |
| `summary.qaptest` | Detailed summary of a QAP test. | — | n/a |

---

# 3. What `tsna` / `sna` do that Dynet does not

**Inference and modelling — the largest single gap.** `sna` fits models and tests
hypotheses; Dynet only describes. Absent from Dynet: network regression (`netlm`,
`netlogit`), canonical correlation (`netcancor`), the linear network
autocorrelation model (`lnam`, `se.lnam`), p*/ERGM by logistic approximation
(`pstar`), biased net models (`bn` and its ten backends), the Bayesian network
accuracy family (`bbnam` and its four variants plus `bbnam.bf`), CUG tests
(`cug.test`, `cugtest`), QAP tests (`qaptest`), posterior predictive draws
(`npostpred`), and consensus-structure estimation from CSS data (`consensus`).
Nothing in Dynet produces a p-value, a confidence interval or a null
distribution.

**Random graph generation and rewiring.** Dynet has no generators. `sna` has
Bernoulli (`rgraph`), density-conditioned (`rgnm`), mixing-conditioned
(`rgnmix`), dyad-census-conditioned (`rguman`), Watts-Strogatz (`rgws`,
`rewire.ws`, `rewire.ud`) and biased-net (`rgbn`) samplers. This is why the
inference gap is structural rather than incidental: with no null-model machinery,
Dynet cannot test anything even if a test were added.

**Blockmodelling, roles and positional analysis.** `blockmodel`,
`blockmodel.expand`, `equiv.clust`, `sedist`, `redist`, `brokerage`,
`gclust.centralgraph`. Dynet has no concept of a position or a role, and no
partitioning verb at all.

**Graph-set comparison.** `gcor`, `gcov`, `gscor`, `gscov`, `hdist`, `structdist`,
`sdmat` and the six `lab.optimize` relabelling optimisers compare graphs to each
other, including up to isomorphism. Dynet compares time bins of one graph, which
is a different (and easier) problem: the vertex labelling never changes.

**Cohesive subgroups and connectivity structure.** Absent from Dynet:
`clique.census`, `kcycle.census`, `kpath.census`, `bicomponent.dist`,
`cutpoints`, `simmelian`, `neighborhood`, `component.size.byvertex`,
`component.largest` (as a vertex set), `gapply`.

**Centralities `sna` has and Dynet does not:** `stresscent` (Shimbel stress),
`gilschmidt` (Gil-Schmidt power index), the harmonic closeness variants
(`closeness(cmode = "suminvdir"/"suminvundir")`), and `betweenness`'s six
alternative `cmode`s (endpoints, proximalsrc/tgt/sum, lengthscaled,
linearscaled). `centralization` in `sna` works on *any* index; Dynet has exactly
three fixed centralization selectors, and the closeness one does not reproduce
any `sna` cmode numerically.

**Graph-level indices `sna` has and Dynet does not:** `structure.statistics` (the
full distance-distribution curve), `triad.classify` (per-triad labelling),
`eval.edgeperturbation`, `centralgraph`, and the five `grecip` / six `gtrans`
definitional variants beyond the single one Dynet exposes.

**Visualization.** 45 of `sna`'s exports are drawing code: `gplot`, `gplot3d`, 17
two-dimensional and 12 three-dimensional layout algorithms, target diagrams, and
sociomatrix heatmaps. Dynet plots its own result objects and delegates network
layout to `cograph`.

**I/O and matrix utilities.** `read.dot`, `read.nos`, `write.dl`, `write.nos`,
`gvectorize`, `gt` (transpose), `%c%` (graph composition), `make.stochastic`,
`event2dichot`, `sr2css`, the triangle/diagonal removers, and `symmetrize`'s
strong/upper/lower rules (Dynet reaches only the weak rule, via
`dynet(directed = FALSE)`).

**`interval.graph`** deserves its own line: it is `sna`'s one temporal idea —
turning spell data into a graph whose vertices are spells and whose edges are
temporal overlaps. Dynet has no interval-graph construction.

**From `tsna` specifically:** `tSnaStats` and `tErgmStats` are *open-ended*
bridges — any `sna` statistic, any `ergm` term, evaluated over time. Dynet answers
the same need with a closed, curated selector list (40 in `metrics()`, 17+ in
`dyn_centrality()`). Where they overlap Dynet is richer and tidier; where a user
wants a statistic outside the list, `tsna` can still get it and Dynet cannot.
`timeProjectedNetwork` also returns a real `network` object that downstream
static tools can consume, where `projection()` returns a tidy state frame.

---

# 4. What Dynet does that `tsna` / `sna` do not

**Genuinely temporal vertex measures.** `dyn_centrality(scope = "temporal")`
computes closeness, betweenness, reach and reach_count on *time-respecting
paths* across the whole window. `sna` has no such thing by construction, and
`tsna` reaches only reach (`tReach`) and path distance (`tPath`) — it has no
temporal betweenness and no temporal closeness. On the shared fixture Dynet
returned temporal closeness 1.333, 0.800, 0.364, 0.267, 0.174 and temporal
betweenness 5, 2, 4, 6, 0; neither has a `tsna` counterpart.

**Traversal cost.** `traversal_time =` charges a nonnegative duration for every
temporal hop (accepting a `difftime` on calendar networks), which changes which
journeys are feasible at all. Neither package has this.

**Sessions as a first-class structure.** Every Dynet verb takes
`sessions = c("bounded", "collapse", "separate")`, so a path can be forbidden
from crossing a class period, a lab session or a conversation. `tsna` has no
session concept; a path there runs the length of the timeline.

**Exact window-integrated occupancy.** `metrics()`'s `temporal_density`,
`observed_pair_density`, `onset_intensity` and `observed_pair_onset_intensity`
integrate exact edge state over observed time with an explicit eligibility
ledger, distinguishing "no edge" from "not observed". `tsna::tEdgeDensity`
covers the first two but has no onset-intensity analogue and no
observation-window / censoring ledger.

**Burstiness and inter-event structure.** `burstiness(dn)` returns Goh-Barabasi
burstiness `B`, the memory coefficient `M`, and event counts per vertex. Neither
package has it.

**Participation shifts without a dependency.** `pshifts()` computes all thirteen
Gibson shifts grouped into four families, with `output = "cumulative"`, in base
Dynet. `tsna::pShiftCount` needs `relevent`, which was not installed here and so
could not be run.

**Path objects you can do something with.** `paths()` returns a tidy frame with
`reachable`, `arrival_time`, `attained`, `latency`, `n_hops` and `n_paths` per
vertex; `path_network()` turns it into an edge frame with `weight`, `first_time`,
`last_time` and `n_endpoints`; `path_trajectories()` turns it into a prefix tree
with per-branch `count` and `probability`; `plot_path_trajectories()` draws it by
frequency, time or predictability. `tsna` returns a `tPath` list and a
`network`, and stops there.

**Timeline editing as a supported surface.** Sixteen editing verbs — `add_ties`,
`add_arcs`, `add_nodes`, `add_vertex_spells`, `update_ties`, `update_nodes`,
`update_vertex_spells`, `remove_ties`, `remove_arcs`, `remove_nodes`,
`remove_vertex_spells`, `rename_nodes`, `rename_sessions`, `set_observations`,
`set_tie_sessions`, `set_vertex_spells`, `clear_observations` — plus
`induce_subgraph()`. `networkDynamic` has activation primitives, but they are a
lower-level API, and `tsna` itself adds no editing verbs.

**Weighted collapse with an explicit weight semantics.**
`collapse_network(dn, weight = )` offers eight distinct definitions — `binary`,
`union_duration`, `total_duration`, `duration_fraction`, `spell_count`,
`weight_sum`, `weighted_duration`, `latest_weight` — with censoring policy, and
returns all of them plus `first`/`last` in one tidy frame. `sna` has no timeline
to collapse; `tsna` has no equivalent verb.

**Durations at five granularities.** `durations(unit = )` covers `pair`, `spell`,
`vertex_activity`, `vertex_spell` and `node_ties`, with `measure` in
`events`/`total`/`mean` (or `duration`/`first`/`last` for spell units, `union` for
node ties) and a censoring policy. `tsna` splits this across three functions with
two modes each and no censoring argument.

**Attribute mixing over time.** `mixing(dn, attribute = ...)` gives the mixing
matrix per time bin. `sna` can *generate* mixing-conditioned graphs (`rgnmix`)
but has no descriptive mixing verb; `tsna` has none either.

**Rolling windows separated from sampling frequency.** `step` (how often you
look) and `window` (how much each look covers) are independent in every Dynet
verb, so a seven-day window stepped daily is one argument pair. `tsna` exposes
the same idea as `time.interval` / `aggregate.dur` in `tSnaStats` and
`tErgmStats` only; it is not available across its other functions.

**Numerical care that `sna` 2.8 does not exercise.** Dynet's
`indegree.rowcolnorm` runs deterministic Sinkhorn-Knopp to residual 1e-12 with a
total-support certificate and returned the exact answer (uniform 1) where `sna`'s
randomised annealer returned an unconverged iterate (0.9907 to 1.0127) — verified
side by side in this session. Dynet's spectral prestige certifies Perron
uniqueness by SVD nullity at 1e-10 and returns `NA` with a classed warning rather
than an elementwise absolute value. Dynet's `domain.proximity` fixes a
`FALSE * Inf` in `sna` 2.8 that zeroes partial nonempty domains (documented; not
exercised by this session's fixture). `hierarchy` and `lubness` return `NaN`
where undefined instead of a number.

**Tidy results throughout.** Every Dynet verb returns a one-row-per-observation
`data.frame` with `print`, `summary`, `plot` and `as.data.frame` methods. `sna`
returns bare vectors, matrices and 3-D arrays; `tsna` returns `ts` objects and
`tPath` lists.

---

# 5. Scoreboard

| | Exports | equivalent | partial | none | n/a |
|---|---|---|---|---|---|
| `tsna` 0.3.6 | 18 | 12 | 5 | 0 | 1 |
| `sna` 2.8 | 273 | 16 | 22 | 73 | 162 |

(Counts recomputed from the finished tables, not estimated. The supplementary
prestige sub-table in 2.1a adds 7 `equivalent` and 2 `partial` rows on top of the
single `prestige` row counted above.)

The `sna` `n/a` count is dominated by 56 S3 methods, 45 visualization exports and
roughly 30 exported pure-R backends (`*_R`) and internal helpers — code that has
no analytic content to map. Of the ~111 `sna` exports with real analytic content,
38 have any Dynet counterpart at all — and 73 have none.

**Verification tally:** 43 rows in the two main tables were checked by running
both implementations and comparing values (`all.equal`, tolerance 1e-8) — 12 of
the 18 `tsna` rows and 31 of the 273 `sna` rows — plus 6 of the 9 rows in the
prestige sub-table, 49 verified comparisons in all. The remaining rows are
described from the help pages and are marked *doc only* where the claim is a
positive one. Two comparisons disagreed and both are documented above:
`centralization_closeness` (Dynet 0.127904 against `sna` 0.149221 / 0.061111 /
0.018904 across cmodes — an unexplained normalisation difference, the one finding
here that looks like it wants a second look) and `indegree.rowcolnorm` (a
deliberate and documented convergence-tolerance difference where Dynet is the
exact one). Two further comparisons differed by a stated convention rather than
disagreeing: `loadcent` (constant `2n - 1` endpoint offset) and `reciprocity`
(Dynet matches `grecip(measure = "edgewise")`, not the `sna` default
`dyadic.nonnull`).

---

# `networkx-temporal` (Python) vs `Dynet` (R) — function-by-function mapping

**Python version documented here: `networkx-temporal` 1.4.4**, installed for real into a
throwaway venv at `/private/tmp/nxt-venv` and enumerated with `dir()` /
`inspect.signature()` / `inspect.getdoc()`. (The package has an import bug at 1.4.4 —
`networkx_temporal/utils/convert/pandas.py` line 1 reads `from turtle import pd`
instead of `import pandas as pd`, which crashes on any interpreter without `_tkinter`.
Enumeration was done with a stub `turtle` module injected into `sys.modules`.)

**Dynet side** enumerated with `devtools::load_all()` +
`getNamespaceExports("Dynet")` and every signature read from `args()` / the roxygen
block in `R/`. 36 exported verbs. Every mapping below was checked against the real
signature; several were executed.

---

## The divide these two libraries sit on

`networkx-temporal` is a **representation and conversion** library. Its core object is a
*list of NetworkX snapshot graphs* with a `slice()` method that decides how the list is
cut. Almost everything downstream is either (a) a different serialisation of that list —
`to_snapshots()`, `to_static()`, `to_events()`, `to_unrolled()` and their four `from_*`
inverses; (b) a bridge into one of 14 other graph ecosystems via `convert()`; or (c) an
ordinary static NetworkX measure applied per slice and returned as a list. Where it adds
genuine algorithmic value beyond that, it does so in **community detection on the
supra-adjacency matrix** (multislice modularity, Leiden, spectral clustering, with a GPU
path), in **snapshot-set similarity**, and in **drawing**.

`Dynet` is a **temporal-mathematics** library. Its core object is a spell/contact table
with an observation window, censoring flags, vertex activity spells, and sessions.
Its verbs compute quantities that are defined on *time-respecting paths* and on
*durations* — temporal reachability, temporal closeness/betweenness, latency, burstiness
and memory, mixing, tie/vertex duration and exposure, formation and dissolution rates, a
nine-variant prestige family, Gibson participation shifts. Most of these have **no
snapshot-wise definition at all**, so they are not "missing" from `networkx-temporal` —
they are a different question.

The practical consequence for the table: whenever a Python metric is *"NetworkX's static
measure, evaluated on each slice"*, the honest Dynet mapping is Dynet's
`scope = "snapshot"` verb, not one of Dynet's temporal verbs. Rows below say so
explicitly.

---

## 1. Construction and factory

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.TemporalGraph(t=None, directed, multigraph)` | Container class: an ordered list of NetworkX graphs, one per snapshot, sharing a NetworkX-compatible API. | `dynet(data, from =, to =, start =, end =)` | partial |
| `tx.TemporalDiGraph` | Directed variant of the above. | `dynet(data, directed = TRUE)` (the default) | equivalent |
| `tx.TemporalMultiGraph` | Undirected multigraph variant (parallel edges kept). | `dynet(data, directed = FALSE)`; Dynet keeps parallel spells natively (`n_spells`) rather than as a separate class | partial |
| `tx.TemporalMultiDiGraph` | Directed multigraph variant. | `dynet(data, directed = TRUE)` | partial |
| `tx.TemporalABC` | Abstract base class the four concrete classes inherit from. | — (no exported class hierarchy; Dynet has one S3 class `dynet`) | n/a |
| `tx.temporal_graph(t, directed, multigraph, create_using)` | Factory returning whichever of the four classes matches the flags; `t>1` pre-allocates empty snapshots. | `dynet(data, ..., directed =)` — Dynet has no empty-container constructor; a `dynet` is built from a data frame | partial |
| `tx.classes.empty_graph(...)` | NetworkX `empty_graph` re-export for the temporal classes. | — | none |
| `tx.classes.create_empty_copy(...)` | Graph with the same nodes, no edges. | `clear_observations(dn)` clears the observation window, not the edges; nearest is `remove_ties(dn, ties = ...)`. Not the same thing. | none |
| `tx.from_static(graph)` | Wraps one static NetworkX graph as a 1-snapshot temporal graph. | — (a `dynet` always carries time; a static graph is not a valid input) | none |
| `tx.from_snapshots(graphs)` | Builds a `TemporalGraph` from a list/dict of NetworkX graphs. | — (no list-of-graphs ingest) | none |
| `tx.from_events(events, directed, multigraph, node_attrs, edge_attrs)` | Builds from edge-level events: 3-tuples `(u,v,t)` or 4-tuples `(u,v,t,δ)` where δ is `+1`/`-1` (add/delete) or a float duration. | `dynet(data, from =, to =, time =)` for 3-tuples; `dynet(data, from =, to =, start =, duration =)` for the float-δ form. The `+1/-1` toggle form has no direct ingest. | partial |
| `tx.from_unrolled(UTG, delta)` | **Inverse** of `to_unrolled()`: recovers a temporal graph from a time-expanded static graph whose nodes are `'a_0'`, `'a_1'`, … | — Dynet's `projection()` is one-way; there is no inverse verb | none |
| `tx.from_pandas(edgelist, source, target, ...)` | NetworkX graph (or list of them) from a pandas edge list. | `dynet(data, from =, to =, ...)` — Dynet's only ingest is a data frame, so this is its native path | equivalent |
| `tx.from_numpy` / `tx.from_scipy` | Graph from a dense / sparse adjacency matrix. | — (no matrix ingest) | none |
| `tx.from_multigraph(graph)` / `tx.to_multigraph(graph)` | Cast between multigraph and simple-graph flavours. | — (Dynet has no multigraph *type*; multiplicity lives in `n_spells`) | none |
| — | — | `as_dynet(x)` — S3 generic with methods `as_dynet.dynet` and `as_dynet.networkDynamic`; converts a **`networkDynamic`** object into a `dynet` | n/a (no Python counterpart) |

## 2. Node / edge / snapshot access and counting

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `TG.nodes(copies=)` | Node view; `copies=True` counts a node once per snapshot it appears in. | `as.data.frame(dn)` returns the tie table; node-level activity comes from `durations(dn, unit = "vertex_activity")` | partial |
| `TG.edges(copies=)` | Edge view, ditto. | `as.data.frame(dn)` — one row per spell, with `from`, `to`, `start`, `end`, `duration`, `weight` | partial |
| `TG.temporal_nodes(copies=)` | Node sequence over all snapshots. | `snapshots(dn)` (endpoint-induced, one row per time and pair) | partial |
| `TG.temporal_edges(copies=)` | Edge sequence over all snapshots. | `snapshots(dn)` | partial |
| `TG.order(copies=)` | Number of nodes; `copies=True` sums per-snapshot node counts. | `metrics(dn, measure = "active_nodes")` (per time bin) | partial |
| `TG.temporal_order()` | Number of **unique** nodes (= `order(copies=False)`). | `metrics(dn, measure = "active_nodes", sessions = "collapse")` gives the active count per bin, not one scalar over the whole window; no single-scalar verb | partial |
| `TG.total_order()` | **Sum** of node counts across all snapshots (= `order(copies=True)`). | `metrics(dn, measure = "active_nodes")` — the per-bin series whose sum is this quantity | partial |
| `TG.size(weight=, copies=)` | Number of edges. | `metrics(dn, measure = "edges")` | partial |
| `TG.temporal_size()` | Number of **unique** interactions. | `metrics(dn, measure = "edges", sessions = "collapse")` per bin; the any-time union is the denominator basis of `metrics(dn, measure = "density")` | partial |
| `TG.total_size(weight=)` | **Sum** of edge counts across snapshots. | `metrics(dn, measure = "edges")` — the per-bin series | partial |
| `TG.number_of_nodes(copies=)` / `number_of_edges(weight=, copies=)` | Aliases for `order()` / `size()`. | as above | partial |
| `TG.number_of_snapshots()` | Length of the snapshot list. | `nrow(as.data.frame(metrics(dn, measure = "edges")))` — no dedicated verb; the bin grid is set by `start`/`end`/`step`/`window` | partial |
| `TG.neighbors(n)` | NetworkX neighbours, per current snapshot. | `dyn_centrality(dn, measure = "degree", scope = "snapshot")` gives counts, not the identity list | partial |
| `TG.temporal_neighbors(node)` | Single flat list of a node's neighbours across **all** snapshots. | `as.data.frame(collapse_network(dn))` — the any-time union edge list, filterable by verb rather than by hand | partial |
| `TG.number_of_neighbors(node)` | Neighbour count per snapshot. | `dyn_centrality(dn, measure = "degree", scope = "snapshot")` | equivalent |
| `TG.all_neighbors(graph, node)` | NetworkX `all_neighbors` re-export (in+out). | `dyn_centrality(dn, measure = "degree", mode = "all", scope = "snapshot")` | partial |
| `TG.index_node(node, interval=)` | Indices of the snapshots a node appears in. | `durations(dn, unit = "vertex_activity")`, or `plot(dn, type = "activity")` | partial |
| `TG.index_edge(edge, interval=)` | Indices of the snapshots an edge appears in. | `as.data.frame(dn)` (the spell's `start`/`end`) | partial |
| `TG.index_snapshot(snapshot, interval=)` | Index of a given snapshot object in the list. | — (no snapshot objects) | n/a |
| `TG.offsets(node=)` | Per-snapshot node offset in the unrolled/supra index. | `as.data.frame(projection(dn), what = "vertices")` — the `state` column is exactly this vertex-time index | equivalent |
| `TG.timestamps(attr=, default=)` | Snapshot index (or an attribute value) for every edge. | `as.data.frame(snapshots(dn))` — the `time` column | equivalent |
| `TG.snapshots()` / `TG.graphs` / `TG.t` / `TG.index` / `TG.names` | Properties exposing the underlying list of graphs, the time index and snapshot names. | — Dynet exposes tidy frames, never a list of graph objects | n/a |
| `TG.has_node(n)` / `TG.has_edge(u,v)` / `TG.get_edge_data(*edge)` / `TG.get_node_data(node)` / `TG.node(node)` / `TG.edge(*edge)` | Membership and attribute lookup. | `as.data.frame(dn)`, `induce_subgraph(dn, nodes = ...)` | partial |
| `TG.adj` / `TG.adjacency()` / `TG.degree` / `TG.in_degree` / `TG.out_degree` | NetworkX view passthroughs on the current snapshot. | `dyn_centrality(dn, measure = "degree", mode = "all" / "out" / "in", scope = "snapshot")` | equivalent |
| `TG.items()` / `keys()` / `values()` / `nbunch_iter()` / `is_directed()` / `is_multigraph()` / `is_frozen()` | Container and type-predicate plumbing. | `print(dn)`, `summary(dn)` | n/a |
| `tx.is_temporal_graph` / `is_static_graph` / `is_events_graph` / `is_events_multigraph` / `is_unrolled_graph` | Type predicates for the various representations. | `inherits(x, "dynet")` | partial |
| `tx.is_gpu_enabled()` | Whether a CuPy/CuGraph GPU backend is available. | — (Dynet is single-threaded base R + C-level kernels, no GPU path) | none |

## 3. Slicing and the four representations

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `TG.slice(bins, attr, level, axis, qcut, duplicates, rank_first, sort, names, as_view, fillna, inplace, applymap, apply_func)` | **The central verb.** Re-cuts the temporal graph into `bins` snapshots by an edge- or node-level `attr` (or by order of appearance), optionally quantile-cut, optionally with custom 2-tuple intervals; returns views by default. | Dynet has no persistent sliced object. Binning is an *argument* on every time-varying verb: `start =`, `end =`, `step =`, `window =` on `snapshots()`, `metrics()`, `dyn_centrality()`, `events()`, `mixing()`, `projection()`. `window = 0` samples an exact point. Quantile binning (`qcut`) has no equivalent. | partial |
| `TG.flatten()` | `slice(bins=1)` — one snapshot holding everything, still a `TemporalGraph`. | `collapse_network(dn, weight = "binary")` | equivalent |
| `tx.to_snapshots(TG, to=, as_view=)` | Returns the list of per-snapshot graphs (optionally converted to another library). | `snapshots(dn, at =, start =, end =, step =, window =)` — returns a tidy `time`/`from`/`to`/`weight`/`n_spells` frame, **not** a list of graph objects | partial |
| `tx.to_static(graph, to=, directed=, multigraph=, index=)` | Collapses everything into one static graph. Dynamic node attributes are lost. | `collapse_network(dn, weight = c("binary", "union_duration", "total_duration", "duration_fraction", "spell_count", "weight_sum", "weighted_duration", "latest_weight"), censored =)` — Dynet is **richer** here: eight weighting schemes plus censoring policy, versus Python's plain union | equivalent |
| `tx.to_events(TG, delta=, node_attrs=, edge_attrs=)` | Serialises to edge-level events: 3-tuples `(u,v,t)`, or 4-tuples with δ as `+1`/`-1` (edge addition/deletion) or as a float duration. Isolates without self-loops are dropped. | `as.data.frame(dn)` returns `from`/`to`/`start`/`end`/`duration`/`weight` — the float-δ form. The `+1`/`-1` add/delete stream is not emitted as a table; `events(dn, measure = c("formation", "dissolution"))` returns *counts* of those transitions per bin, not the event list. | partial |
| `tx.to_unrolled(TG, to=, delta=, edge_couplings=, node_copies=, node_index=)` | **The time-expanded graph.** One static graph containing every node-copy `(v, t)` plus "edge couplings" joining `(v,t)` to `(v,t+1)`. `delta` adds cross-time edges `(u_t, v_{t+δ})` for the Kim & Anderson (2012) time-series representation. `node_copies` ∈ `'all'` / `'fill'` / `'persist'` controls which snapshots get copies. Unlike `to_static()`, dynamic node attributes survive. | **`projection(dn, start =, end =, step =, window =, sessions =)`** — this is Dynet's time-expanded network. `as.data.frame(x, what = "vertices")` gives one vertex-time `state` per node per slice with an `active` flag; `as.data.frame(x, what = "edges")` gives within-slice arcs plus forward-pointing weight-1 `identity_arc` couplings. Dynet always emits every vertex in every slice (≡ `node_copies = 'all'`) and always couples forward only. **Not covered:** the `delta` cross-time-edge variant, `node_copies = 'fill' / 'persist'`, and returning a real graph object. | partial |
| `tx.from_unrolled(UTG, delta=)` | Inverse of the above. | — | none |
| `tx.to_adjacency_matrix(graph, weight=, device=, dtype=, format=)` | Single sparse adjacency matrix combining all snapshots (CPU or GPU). | — no public matrix accessor; `as.data.frame(collapse_network(dn))` is the tidy union edge list instead (Dynet deliberately returns tidy frames, never bare matrices) | partial |
| `tx.to_supra_adjacency_matrix(graph, weight=, interslice_weight=, interslice_weights=, interslice_couple=, interslice_directed=, return_offsets=, device=, dtype=, format=)` | Block matrix: intra-slice adjacencies on the diagonal, inter-slice identity couplings off it. `interslice_couple` ∈ `'shared'` / `'all'` / `'first'`; couplings can be directed; per-pair coupling weights supported. Feeds the community-detection module. | — Dynet's `projection()` *is* the same object in edge-list form (identity arcs = couplings), but there is no supra-matrix accessor and no per-pair coupling-weight control | partial |
| `tx.propagate_snapshots(TG, method='ffill'|'bfill', delta=)` | Carries nodes and edges forward (or backward) across snapshots so they persist. | — (Dynet interval spells persist by construction; there is no ffill/bfill on a contact network) | none |
| `tx.combine_snapshots(graphs)` | Union of snapshot *t* across several temporal graphs of equal length. | — | none |
| `tx.utils.temporal_split(graph, train_split, val_split, attr=)` | Disjoint train/val/test masks over time intervals, for ML. | — | none |

## 4. Conversion to other ecosystems

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.convert(graph, to=...)` | High-level dispatcher to 14 targets: `cugraph`, `cupy`, `dgl`, `dynetx`, `graph_tool`, `igraph`, `networkit`, `numpy`, `pandas`, `scipy`, `snap`, `stellargraph`, `teneto`, `torch_geometric`. Accepts a static graph, a `TemporalGraph`, or a list. | — Dynet converts **inbound** only, via `as_dynet(x)` on a `networkDynamic` object. There is no outbound bridge. | none |
| `tx.to_igraph` / `to_networkit` / `to_graph_tool` / `to_snap` / `to_dynetx` / `to_teneto` | Individual graph-library exporters. | — | none |
| `tx.to_dgl` / `to_torch_geometric` / `to_stellargraph` | Graph-ML framework exporters. | — | none |
| `tx.to_numpy` / `to_scipy` / `to_cupy` | Dense / sparse / GPU matrix exporters. | — | none |
| `tx.to_cugraph` | NVIDIA RAPIDS exporter. | — | none |
| `tx.to_pandas(graph, source, target, nodelist, dtype, edge_key)` | Edge list as a DataFrame. | `as.data.frame(dn)`, `as.data.frame(snapshots(dn))`, `as.data.frame(collapse_network(dn))` | equivalent |

## 5. Metrics and centrality (`tx.algorithms`)

Everything in this section except `temporal_degree`/`degree`/`degree_centrality` is a
**static NetworkX measure evaluated once per slice**, returned as a `List[dict]` (one
dict per snapshot). The Dynet column therefore maps to `scope = "snapshot"`, which is the
matching semantics. Dynet's `scope = "temporal"` measures are a *different quantity* and
are listed in section 12.

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.degree(TG, nbunch, weight)` | Degree **summed over snapshots**: `Σ_G Σ_j A_ij + A_ji`. Genuinely temporal in the weak sense of aggregating over time. Multigraph parallel edges count. | `durations(dn, measure = "events", unit = "node_ties", mode = "all")` — spells incident on each node, i.e. the same aggregation over time | partial |
| `tx.in_degree(TG, nbunch, weight)` / `tx.out_degree(...)` | Same, restricted to incoming / outgoing. | `durations(dn, measure = "events", unit = "node_ties", mode = "in")` / `mode = "out"` | partial |
| `tx.degree_centrality(TG, nbunch)` | The above divided by `|V|`. | `dyn_centrality(dn, measure = "degree", scope = "snapshot")` gives raw per-bin degree, not the time-summed normalised version; no exact match | partial |
| `tx.in_degree_centrality` / `tx.out_degree_centrality` | Directed variants of the above. | `dyn_centrality(dn, measure = "degree", mode = "in", scope = "snapshot")` / `mode = "out"` | partial |
| `tx.degree_centralization(TG, self_loops, isolates)` | Freeman degree centralization against the star-graph maximum, per snapshot. | `metrics(dn, measure = "centralization_degree")` | equivalent |
| `tx.in_degree_centralization` / `tx.out_degree_centralization` | Directed centralization. | `metrics(dn, measure = "centralization_degree")` — Dynet's centralization is not mode-split | partial |
| `tx.centralization(centrality, scalar)` | Generic centralization: applies the Freeman formula to **any** supplied centrality dict plus a theoretical maximum. | — Dynet ships three fixed centralizations: `metrics(dn, measure = c("centralization_degree", "centralization_betweenness", "centralization_closeness"))`. There is no user-supplied-vector generic. | partial |
| `tx.bridging_centrality(TG, betweenness)` | Betweenness × bridging coefficient (Hwang et al. 2006), per snapshot. Zero for isolates. With `betweenness=None`, returns the bridging coefficient alone. | — not in Dynet's `.node_measures` | none |
| `tx.brokering_centrality(TG, clustering_coef)` | Degree × clustering coefficient (per snapshot). | — not in Dynet's `.node_measures` | none |
| `tx.conductance(graph, communities, weight)` | Average conductance of a partition: cut weight over min volume (Kannan et al. 2004). | — Dynet has no community machinery | none |
| `tx.modularity(graph, communities, weight, resolution, spectral, sparse)` | Newman modularity, per snapshot. | — | none |
| `tx.modularity_multislice(TG, communities, resolution, interslice_weight, weight, spectral)` | **Multislice (Mucha et al.) modularity** on the supra-adjacency matrix, with interlayer couplings ω. Genuinely cross-slice. | — | none |
| `tx.modularity_spectral(adj, communities, gamma, directed, weight)` | Modularity computed from the graph spectrum; supports soft / mixed-membership assignments. | — | none |
| `tx.algorithms.NX_GPU_AUTOCONFIG` | Env-driven flag selecting a GPU default device. | — | n/a |

## 6. Community detection

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.spectral_clustering(graph, operator, weight, interslice_weight, device, **kw)` | Builds the supra-adjacency matrix and runs k-means on the eigenvectors of the chosen operator. Dispatches on `operator`. | — | none |
| `tx.spectral_clustering_laplacian(...)` | Normalised / unnormalised Laplacian operator. | — | none |
| `tx.spectral_clustering_bethe_hessian(...)` | Bethe–Hessian operator. | — | none |
| `tx.spectral_clustering_modularity(...)` | Modularity-matrix operator. | — | none |
| `tx.leiden_communities(graph, gamma, weight, interslice_weight, max_iter, seed, device, **kw)` | Leiden partition. On a `TemporalGraph` it optimises **multislice** modularity (temporal communities coupled across slices); on a static graph, ordinary modularity. CPU via `leidenalg`, GPU via CuPy. | — | none |
| `tx.leiden_multislice_gpu(...)` | The GPU/CuPy Leiden kernel directly. | — | none |
| `tx.community_matrix_from_vector(...)` | Membership vector → indicator matrix. | — | none |
| `tx.map_partitions_to_nodes(partitions, nodelist, default)` | Partition list → `{node: community}` map. | — | none |
| `tx.map_partitions_to_edges(...)` | Partition list → `{edge: community}` map. | — | none |
| `tx.transition_node_memberships(...)` | Advances community memberships through a Markov transition matrix (used by the dynamic SBM generator). | — | none |

## 7. Temporal evolution / snapshot similarity

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.temporal_node_similarity(TG, method='jaccard'\|'intersect'\|'overlap'\|'dice'\|'geometric', na_diag=False)` | **T×T matrix of set similarity between the node sets of every pair of snapshots.** For snapshots *s*, *r* with node sets *A*, *B*: jaccard `\|A∩B\|/\|A∪B\|`, intersect `\|A∩B\|/\|A\|`, overlap `\|A∩B\|/min(\|A\|,\|B\|)`, dice `2\|A∩B\|/(\|A\|+\|B\|)`, geometric `\|A∩B\|²/(\|A\|\|B\|)`. This is how the library measures churn / persistence of the active population over time. | — **genuine gap.** Dynet has no snapshot-vs-snapshot similarity verb. The closest relatives answer different questions: `durations(dn, unit = "vertex_activity")` gives per-node time-on, and `events(dn, measure = c("formation_rate", "dissolution_rate"))` gives adjacent-bin turnover rates — but neither yields the full pairwise T×T matrix, and neither generalises to non-adjacent snapshot pairs. | none |
| `tx.temporal_edge_similarity(TG, method=..., na_diag=False)` | Same five coefficients, applied to the **edge sets** of every pair of snapshots. Measures tie persistence / rewiring across the whole time grid. | — **genuine gap**, same reasoning. `events(dn, measure = c("formation", "dissolution", "formation_fraction", "dissolution_fraction", "formation_rate", "dissolution_rate"))` covers adjacent-bin tie turnover only. | none |

Both of these are one function each with a five-way `method` switch and would map cleanly
onto Dynet's tidy-return convention (one row per snapshot pair per method). They are the
clearest candidate features in this comparison.

## 8. Structural editing and subgraphs

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `TG.add_edge(u, v, **attr)` / `add_edges_from(ebunch, **attr)` | Add an edge (into the current snapshot). | `add_ties(dn, data, loops = FALSE)`; `add_arcs(dn, data, loops = FALSE)` for directed-only insertion | equivalent |
| `TG.add_weighted_edges_from(ebunch, weight)` | Weighted bulk add. | `add_ties(dn, data)` with a `weight` column | equivalent |
| `TG.add_node(n, **attr)` / `add_nodes_from(nodes, **attr)` | Add nodes with attributes. | `add_nodes(dn, data)` | equivalent |
| `TG.remove_edge(u, v)` / `remove_edges_from(ebunch)` | Remove edges. | `remove_ties(dn, ties =, from =, to =, start =, end =, session =)`; `remove_arcs(dn, ...)` | equivalent |
| `TG.remove_node(n)` / `remove_nodes_from(nodes)` | Remove nodes. | `remove_nodes(dn, nodes, cascade = FALSE)` — `cascade` also drops incident ties | equivalent |
| `TG.clear()` / `clear_edges()` | Empty the graph / drop all edges. | `clear_observations(dn)` clears the observation window only; there is no clear-all verb | partial |
| `TG.subgraph(nodes)` | Node-induced subgraph across all snapshots. | `induce_subgraph(dn, nodes = ..., keep_isolates = FALSE)` | equivalent |
| `TG.edge_subgraph(edges)` | Edge-induced subgraph. | `induce_subgraph(dn, ties = ..., keep_isolates = FALSE)` | equivalent |
| `tx.classes.isolates(graph)` | Isolate nodes. | `metrics(dn, measure = "isolates")` (count per bin) | partial |
| `tx.classes.relabel_nodes(...)` | Rename nodes via a mapping. | `rename_nodes(dn, mapping)` | equivalent |
| `tx.classes.compose(G, H)` / `compose_all(graphs)` | Union of two / several graphs. | — (nearest is `combine_snapshots`, also absent) | none |
| `TG.add_snapshot(G)` / `add_snapshots_from(graphs)` / `append(G)` / `insert(index, G)` / `pop(index)` / `remove_snapshot(G)` / `new_snapshot()` | List-like manipulation of the snapshot sequence. | — Dynet has no snapshot list to manipulate; the bin grid is derived from `start`/`end`/`step`/`window` at call time | n/a |
| `TG.copy(as_view)` / `to_directed(as_view)` / `to_undirected(reciprocal, as_view)` | Copies and directedness casts. | directedness is fixed at `dynet(data, directed =)`; no post-hoc cast verb | partial |
| `TG.update(edges, nodes)` | Bulk update from another graph. | `update_ties(dn, ties, data, loops = FALSE)`, `update_nodes(dn, data)`, `update_vertex_spells(dn, spells, data)` | equivalent |
| — | — | `set_observations(dn, data =, start =, end =)`, `clear_observations(dn)` — declare the **observation window** (what was watched, versus what merely did not happen) | n/a (no Python counterpart) |
| — | — | `set_vertex_spells(dn, data)`, `add_vertex_spells(dn, data)`, `remove_vertex_spells(dn, spells)`, `update_vertex_spells(dn, spells, data)` — explicit **vertex activity spells** | n/a |
| — | — | `set_tie_sessions(dn, session =)`, `rename_sessions(dn, mapping)` — session walls that time-respecting paths may not cross | n/a |

## 9. Node / edge attributes

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.get_node_attributes(graph, name)` / `get_edge_attributes(...)` | NetworkX attribute getters, lifted over snapshots. | `as.data.frame(dn)` carries node/tie attribute columns through | partial |
| `tx.set_node_attributes(...)` / `set_edge_attributes(...)` | Attribute setters. | `update_nodes(dn, data)` / `update_ties(dn, ties, data)` | equivalent |
| `tx.get_unique_node_attributes(graph, attr, default)` / `get_unique_edge_attributes(...)` | Distinct attribute values across the temporal graph. | — no dedicated verb | none |
| `tx.partition_nodes(graph, attr, default, index, unique)` | Groups nodes by attribute value, one dict per snapshot. | `mixing(dn, attribute = ...)` groups by attribute but returns a **mixing matrix**, not a partition listing | partial |
| `tx.partition_edges(graph, attr, default, index, unique)` | Groups edges by attribute value. | `mixing(dn, attribute = ...)` | partial |
| `tx.map_attr_to_nodes(...)` / `map_attr_to_edges(...)` | Broadcast an attribute onto nodes / edges. | `update_nodes(dn, data)` / `update_ties(dn, ties, data)` | partial |
| `tx.map_node_attr_to_edges(...)` / `map_edge_attr_to_nodes(...)` | Push node attributes onto incident edges and vice versa. | — | none |

## 10. I/O

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.read_graph(file, format=, **kw)` | Reads a `TemporalGraph` from a ZIP containing `{name}_{t}.{ext}` snapshot files, in any NetworkX-supported format (GraphML, GEXF, …). | — Dynet has no graph-file reader; input is always a data frame via `dynet()` | none |
| `tx.write_graph(TG, file=, format=, makedirs=, compression=, compresslevel=, allowZip64=, **kw)` | Writes each snapshot to its own file inside a ZIP; returns bytes if no file given. | — | none |

## 11. Drawing

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.draw(graph, backend='networkx', *a, **kw)` | Top-level plot dispatcher. | `plot(dn, type = c("timeline", "activity", "network", "snapshots", "proximity"))` | partial |
| `tx.draw_networkx(TG, pos, layout, nrows, ncols, fig, ax, figsize, title, suptitle, nodes, edges, labels, edge_labels, node_opts, edge_opts, ...)` | Matplotlib grid of snapshot subplots, with per-snapshot option overrides via `temporal_*` kwargs. Needs the `[draw]` extra. | `plot(dn, type = "snapshots", panels = 9L)` | partial |
| `tx.draw_networkx_nodes` / `draw_networkx_edges` / `draw_networkx_labels` / `draw_networkx_edge_labels` | Element-level NetworkX drawing primitives, lifted over snapshots. | — Dynet's plotting is verb-level, not primitive-level | none |
| `tx.layout(TG, layout='random', *a, **kw)` | Node positions from any NetworkX layout algorithm, shared across snapshots. | — layout is chosen internally by `plot(dn, type = "network")` | none |
| `tx.unrolled_layout(UTG, nodes)` | Positions for an unrolled graph: node on one axis, time on the other. | `plot(dn, type = "proximity", slices =, measure =, flow =)` — Dynet's proximity timeline is the same node-by-time layout idea, drawn as trajectories rather than as a node-link diagram | partial |
| — | — | `plot_path_trajectories(x, measure = c("frequency", "time", "predictability"), orientation =, min_count =)` on a `path_trajectories()` result | n/a |
| — | — | `plot(metrics(dn, measure = ...))`, `plot(events(dn, measure = ...))`, `plot(paths(dn, from = ...))` — S3 plot methods on every result class | n/a |

## 12. Generators and bundled datasets

| Python API | What it does | Dynet equivalent | Status |
|---|---|---|---|
| `tx.dynamic_stochastic_block_model(B, z, d, d_out, t, transition_matrix, fix_transition_prob, directed, multigraph, isolates, selfloops, distribution, sparse, seed)` | Dynamic SBM: community memberships evolve as a Markov chain; adjacencies sampled Poisson (default) or Bernoulli per snapshot. | — Dynet has no generative models | none |
| `tx.dynamic_sbm(...)` | Alias / convenience wrapper for the above. | — | none |
| `tx.stochastic_block_model(...)` | Static SBM. | — | none |
| `tx.example_sbm_graph()` | 75 nodes, 3 communities, 3 snapshots, p_in 0.20 / p_out 0.01, 10% transition probability. | — | none |
| `tx.generate_block_matrix(...)` / `generate_community_matrix(...)` / `generate_community_vector(...)` / `generate_degree_vector(...)` / `generate_transition_matrix(...)` | SBM parameter builders. | — | none |
| `tx.collegemsg_graph()` | CollegeMsg dataset: 1,899 students, 59,835 directed private messages over 193 days, `'time'` edge attribute `'YYYY-MM-DD HH:MM'`. | — Dynet ships its own data (see `data/`), not this one | none |
| `tx.pubmed_graph()` | Bundled PubMed temporal graph. Contents not documented beyond the loader; not inspected here. | — | none |
| `tx.fediverse_graph()` | Bundled Fediverse temporal graph. Contents not documented beyond the loader; not inspected here. | — | none |
| `tx.travian_graph()` | Bundled Travian (online game) temporal graph. Contents not documented beyond the loader; not inspected here. | — | none |

## 13. Dynet verbs with no `networkx-temporal` counterpart

Listed here rather than as `—` rows above, since the table is keyed on the Python API.

| Dynet call | What it does | Python equivalent | Status |
|---|---|---|---|
| `paths(dn, from =, at =, direction = c("forward", "backward"), sessions =, start =, end =, traversal_time =)` | Time-respecting (shortest-foremost) journeys from a source: per-target `reachable`, `arrival_time`, `attained`, `latency`, `n_hops`, `n_paths`. Nondecreasing times, unlimited waiting, half-open interval spells, exact-timestamp rule for point events, session walls. | — | none |
| `dyn_reachability(dn, direction = c("both", "forward", "backward"), at =, start =, end =, traversal_time =, measure = c("reach", "reach_count"))` | Forward / backward temporal reachable-set size and proportion for every vertex, source excluded. | — | none |
| `dyn_centrality(dn, measure = c("closeness", "betweenness", "reach", "reach_count"), scope = "temporal", traversal_time =)` | Centrality on time-respecting paths across the whole window. Cannot run backwards in time, so it is never inflated the way a flattened network is. | — | none |
| `dyn_centrality(dn, measure = "prestige", prestige = ...)` | Nine-variant prestige family: `"indegree"`, `"indegree.rownorm"`, `"indegree.rowcolnorm"` (Sinkhorn–Knopp), `"domain"`, `"domain.proximity"`, `"eigenvector"`, `"eigenvector.rownorm"`, `"eigenvector.colnorm"`, `"eigenvector.rowcolnorm"`, with `rescale =`. | — | none |
| `burstiness(dn, measure = c("burstiness", "memory", "events"), sessions =)` | Goh–Barabási burstiness coefficient and memory coefficient of each vertex's inter-event time sequence. | — | none |
| `mixing(dn, attribute, start =, end =, step =, window =)` | Time-varying mixing matrix over a node attribute (homophily / assortative mixing per bin). | — | none |
| `durations(dn, measure = c("events", "total", "mean"), unit = c("pair", "spell", "vertex_activity", "vertex_spell", "node_ties"), mode =, censored =)` | Duration and exposure accounting at five different units, with an explicit `censored = c("include", "exclude")` policy. | — | none |
| `events(dn, measure = c("formation", "dissolution", "active", "new_pairs", "formation_fraction", "dissolution_fraction", "formation_rate", "dissolution_rate"))` | Tie formation and dissolution counts, fractions and **rates** per bin — turnover dynamics. | closest is `temporal_edge_similarity()`, which measures pairwise set overlap rather than directional formation/dissolution | none |
| `pshifts(dn, output = c("final", "cumulative"), group_events =)` | Gibson (2003) participation shifts: the fixed thirteen classes of turn-taking transition, final totals or the cumulative running vector. | — | none |
| `path_trajectories(x, min_count = 1L)` and `path_network(x)` | Reduce a `paths()` result to recurring trajectories / a path network. | — | none |
| `metrics(dn, measure = c("temporal_density", "observed_pair_density", "onset_intensity", "observed_pair_onset_intensity"))` | Observation-window-aware density and onset intensity — denominators built from what was actually watched, not from `n(n-1)`. | — | none |
| `metrics(dn, measure = c("connectedness", "efficiency", "hierarchy", "lubness"))` | Krackhardt's four graph-level indices of hierarchy, per bin. | — | none |
| `metrics(dn, measure = c("concurrent_nodes", "concurrent_share"))` | Concurrency — how much of the network is simultaneously partnered, the key quantity in epidemic network models. | — | none |
| `set_observations()`, `clear_observations()`, `onset_censored`/`terminus_censored` on `dynet()` | Explicit observation windows and left/right censoring flags, threaded through every verb's `censored =` argument. | — `networkx-temporal` has no notion of censoring or of an observation window distinct from the data range | none |
| `dynet(data, format = c("auto", "interval", "contact", "threaded", "copresence"), session =, thread =, actor =, group =)` | Ingests four different relational data shapes, including **threaded** discussion data and **copresence** data, and carries session structure. | — | none |

---

## What `networkx-temporal` does that Dynet does not

- **Outbound interoperability.** `convert()` exports to 14 ecosystems (igraph, graph-tool,
  NetworKit, SNAP, DyNetX, teneto, DGL, PyTorch Geometric, StellarGraph, cuGraph, CuPy,
  NumPy, SciPy, pandas). Dynet converts inbound only, and only from `networkDynamic`.
- **Community detection, including genuinely cross-slice.** Leiden on multislice
  modularity (Mucha-style interlayer couplings ω), three spectral-clustering operators
  (Laplacian, Bethe–Hessian, modularity), plus `modularity`, `modularity_multislice`,
  `modularity_spectral`, `conductance`. Dynet has none of this.
- **Snapshot-set similarity over the whole time grid** — `temporal_node_similarity()` and
  `temporal_edge_similarity()` return a T×T matrix under five coefficients
  (jaccard/intersect/overlap/dice/geometric). Dynet's turnover measures only compare
  adjacent bins and only in the formation/dissolution direction.
- **The supra-adjacency matrix as a first-class object**, with `interslice_couple`
  (`'shared'`/`'all'`/`'first'`), directed couplings, and per-pair coupling weights.
  Dynet's `projection()` encodes the same structure but only as tidy edge rows, always
  forward-coupled, without per-pair weights.
- **Graph file I/O** — `read_graph()`/`write_graph()` round-trip a temporal graph through
  a ZIP of per-snapshot GraphML/GEXF/etc. files. Dynet has no graph-file reader or writer.
- **Generative models and bundled temporal datasets** — dynamic SBM with Markov community
  transitions, plus CollegeMsg, PubMed, Fediverse and Travian graphs.
- **GPU acceleration** for the adjacency/supra-adjacency construction, spectral clustering
  and Leiden (CuPy/cuGraph, `NX_GPU_AUTOCONFIG`).
- **`to_unrolled(delta=...)`** — the cross-time edge variant `(u_t, v_{t+δ})` giving the
  Kim & Anderson (2012) time-series representation, and `node_copies='fill'/'persist'`.
  Dynet's `projection()` covers the base unrolled graph but not these variants, and has no
  inverse (`from_unrolled()`).
- **`propagate_snapshots()`, `combine_snapshots()`, `temporal_split()`** — snapshot ffill/
  bfill, multi-graph snapshot union, and time-disjoint train/val/test masks for ML.
- **Quantile-based slicing** (`slice(qcut=True)`) and slicing on an arbitrary node- or
  edge-level attribute at `level='edge'|'node'|'source'|'target'`. Dynet bins on time only.
- **Live NetworkX API compatibility** — a `TemporalGraph` *is* a NetworkX graph for most
  purposes, so any NetworkX algorithm can be run on any snapshot for free. Dynet
  implements its own kernels and exposes tidy frames, not graph objects.
- **Two node-level measures Dynet lacks entirely**: `bridging_centrality` and
  `brokering_centrality`.

## What Dynet does that `networkx-temporal` does not

- **Time-respecting paths.** `paths()` returns shortest-foremost journeys with
  `arrival_time`, `latency`, `n_hops`, `n_paths` and an explicit `reachable`/`attained`
  distinction, under a defined traversal semantics (nondecreasing times, unlimited
  waiting, half-open interval spells, exact-timestamp rule for point events, per-hop
  `traversal_time` cost). `networkx-temporal` has no path machinery at all.
- **Temporal reachability.** `dyn_reachability()` computes forward and backward reachable
  set sizes and proportions per vertex, with closed traversal-time bounds and a
  backward-deadline formulation. No Python counterpart.
- **Temporal closeness and temporal betweenness** — `dyn_centrality(scope = "temporal")`.
  These are defined on time-respecting paths, cannot run backwards in time, and are
  therefore not the flattened-network values. `networkx-temporal`'s centralities are all
  static NetworkX measures per slice.
- **The nine-variant prestige family**, including Sinkhorn–Knopp row-column-normalised
  prestige and domain/domain-proximity prestige on the reachability graph.
- **Burstiness and memory** — `burstiness()` implements the Goh–Barabási burstiness
  coefficient and the memory coefficient on inter-event times. Nothing comparable exists
  on the Python side.
- **Observation windows and censoring as first-class semantics.** `observation_start`,
  `observation_end`, `observation_spells`, `onset_censored`, `terminus_censored`,
  `set_observations()`, and a `censored = c("include", "exclude")` argument threaded
  through `durations()` and `collapse_network()`. This is the difference between "no tie
  was observed" and "no tie existed", and `networkx-temporal` does not model it.
- **Declared vertex activity spells** — nodes have their own onset/terminus independent of
  their ties (`set_vertex_spells()`, `add_vertex_spells()`, …), and path traversal
  respects them. In `networkx-temporal` a node exists in a snapshot iff it appears there.
- **Sessions** — `set_tie_sessions()`, and a `sessions = c("bounded", "collapse",
  "separate")` argument on nearly every verb, so that time-respecting paths can be
  forbidden from crossing a session wall. No analogue.
- **Duration and exposure accounting at five units** — `durations(unit = c("pair",
  "spell", "vertex_activity", "vertex_spell", "node_ties"))` with `measure = c("events",
  "total", "mean")`.
- **Tie turnover rates** — `events()` gives formation/dissolution counts, fractions **and
  rates** plus `new_pairs` per bin, which is the directional turnover
  `temporal_edge_similarity()` only sees symmetrically.
- **Eight weighting schemes when collapsing to a static network** —
  `collapse_network(weight = c("binary", "union_duration", "total_duration",
  "duration_fraction", "spell_count", "weight_sum", "weighted_duration",
  "latest_weight"))`. `to_static()` offers a plain union only.
- **Observation-aware graph metrics** — `temporal_density`, `observed_pair_density`,
  `onset_intensity`, `observed_pair_onset_intensity`, whose denominators come from what
  was actually watched.
- **Concurrency measures** — `concurrent_nodes`, `concurrent_share`.
- **Krackhardt's four hierarchy indices** — `connectedness`, `efficiency`, `hierarchy`,
  `lubness`, per bin.
- **Gibson participation shifts** — `pshifts()`, the fixed thirteen turn-taking classes,
  final or cumulative, with simultaneous-recipient group inference.
- **Time-varying mixing matrices** — `mixing(dn, attribute = ...)` per bin.
- **Path trajectory analysis and its plot** — `path_trajectories()`, `path_network()`,
  `plot_path_trajectories(measure = c("frequency", "time", "predictability"))`.
- **Four relational data ingest formats** — `format = c("interval", "contact",
  "threaded", "copresence")`, so threaded discussion logs and copresence records become
  temporal networks without hand-reshaping.
- **A tidy result contract.** Every Dynet verb returns a one-row-per-observation
  `data.frame` with `print`, `summary`, `plot` and `as.data.frame()` methods.
  `networkx-temporal` returns `List[dict]`, sparse matrices, and NetworkX views.

---

## Correction to an earlier reading

An earlier pass flagged **`to_unrolled()` as a genuine Dynet gap**. That is wrong, and the
table above reflects the corrected finding: Dynet's **`projection()`** *is* the
time-expanded / vertex-time-state network. Confirmed by running it —
`as.data.frame(projection(dn), what = "vertices")` emits one `state` per node per slice
with an `active` flag, and `what = "edges"` emits within-slice arcs plus forward
weight-1 `identity_arc` couplings, which are exactly `to_unrolled()`'s "edge couplings".
Its roxygen cites `tsna::timeProjectedNetwork()` as the reference implementation. What
*is* missing from Dynet is only the `delta` cross-time-edge variant, the
`node_copies='fill'/'persist'` modes, and the inverse `from_unrolled()`.

`temporal_node_similarity()` / `temporal_edge_similarity()` **are** confirmed genuine
gaps — grepping Dynet's `R/` for `jaccard|dice|similarity` returns nothing.

## Rows flagged uncertain

- `tx.pubmed_graph()`, `tx.fediverse_graph()`, `tx.travian_graph()` — the loaders exist and
  were enumerated, but their docstrings do not describe node/edge counts or the time
  attribute. Not downloaded or inspected. Marked as such in the table.
- `tx.transition_node_memberships()` — enumerated at top level and clearly part of the
  dynamic-SBM generator, but its docstring was not read in full. Described from its
  context in `generators`.
- `tx.map_attr_to_nodes` / `map_attr_to_edges` / `map_node_attr_to_edges` /
  `map_edge_attr_to_nodes` — signatures enumerated; behaviour inferred from names and the
  neighbouring `partition_*` docstrings rather than read in full.
- `TG.degree` / `in_degree` / `out_degree` as *properties* resolve to NetworkX
  `DegreeView` objects on the current snapshot, while the module-level `tx.degree()` is
  the time-summed version. The two share a name and differ in meaning; the table
  separates them, but a user could conflate them.

---
