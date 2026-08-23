# Dynet — Temporal Network Analysis Package

## Vision

A standalone R package for temporal network analysis. Dynet is a cograph with attitude — it builds objects that any cograph function recognizes as a network with temporal personality. Clean, intuitive, modern API. No magic, no hidden state. Every function takes a `dynet`, computes something, returns a result.

## Architecture

### Identity

- **Standalone package.** No dependency on cograph. No circular risk.
- **cograph-compatible by structure.** Same fields (`$weights`, `$nodes`, `$edges`, `$directed`, `$meta`, `$node_groups`). Cograph recognizes a dynet by checking `$meta$type == "temporal"`.
- **Dependency flows one way:** cograph can recognize dynet objects. Dynet never imports cograph.

### Dependencies

```
Imports: ggplot2
Suggests: igraph, testthat, tsna, networkDynamic, sna
```

- **ggplot2** — only hard dependency (plots).
- **igraph** in Suggests — snapshot functions require it and error clearly if missing. Not a silent skip.
- **tsna, networkDynamic, sna** — test-only, for numerical equivalence verification.

---

## The `dynet` Object

### Construction

```r
# Auto-detect columns — just works
dn <- dynet(edges)

# Full control when needed
dn <- dynet(edges,
  from = "sender", to = "receiver",
  start = "time", duration = "dur",
  session = "class_period",
  directed = FALSE,
  interval = 7
)
```

### Smart Input Coercion

**Column detection** (case-insensitive, alias-based):
- from/to: `from/to`, `source/target`, `sender/receiver`, `head/tail`
- time: `start+end`, `onset+terminus`, `start+duration`, `time` (instantaneous, duration = 1 interval)
- session: auto-detect if `session` column exists, or user specifies

**Four time input formats:**
- `start` + `end` (interval)
- `onset` + `terminus` (statnet convention — recognized as alias)
- `start` + `duration`
- `time` only (instantaneous events, duration = 1 interval)

All normalized internally to `[start, end)` half-open intervals.

### Structure

```r
# Class: "dynet"

structure(
  list(
    weights     = NULL,                                     # cograph slot (NULL for temporal)
    nodes       = data.frame(id, label, name, x, y),        # cograph-compatible
    edges       = data.frame(from, to, weight, start, end, session),  # weight = end - start
    directed    = logical,
    meta        = list(
      source   = "dynet",
      type     = "temporal",
      layout   = NULL,
      temporal = list(
        time_range  = c(min_start, max_end),
        interval    = interval,
        time_bins   = numeric_vector,                       # bin boundaries
        time_unit   = "step"
      ),
      sessions = list(
        labels     = character_vector,
        boundaries = list_of_ranges
      )
    ),
    node_groups = NULL                                      # cograph slot
  ),
  class = "dynet"
)
```

**Notes:**
- `$edges$weight` is computed as `end - start` (edge duration). Cograph functions that read `$edges$weight` get meaningful values.
- `$weights` is NULL because there is no single static weight matrix for temporal networks. Cograph functions that need a weight matrix should use `snapshot()` to extract one at a specific time.
- `$meta$temporal$time_bins` stores bin boundaries (length = n_bins + 1). Number of bins is derived as `length(time_bins) - 1L`, never stored redundantly.
- Self-loops (`from == to`) are accepted but excluded from degree calculations. A warning is issued on construction if self-loops are present.

Cograph sees: `$weights`, `$nodes`, `$edges`, `$directed`, `$meta`, `$node_groups`. Standard network.
Dynet functions see: `$meta$type == "temporal"`, `$meta$temporal`, `$meta$sessions`. The attitude.

### Print

```
Dynet [directed | temporal]
  6 vertices | 10 edges
  Time: [1, 12) | 11 bins x 1 step
  Sessions: Mon_AM (5), Mon_PM (5)
```

The half-open `[1, 12)` notation makes the interval convention visible.

---

## Sessions

Temporal data often has breaks — class periods, work shifts, semesters. Sessions are a grouping variable in the edge data:

```r
edges <- data.frame(
  from = c("A", "A", "B"),
  to   = c("B", "C", "C"),
  start = c(1, 3, 8),
  end   = c(2, 5, 10),
  session = c("Mon_AM", "Mon_AM", "Mon_PM")
)

dn <- dynet(edges, session = "session")
```

Every metric function accepts a `sessions` argument:
- **`"bounded"`** (default) — sessions are walls. Temporal paths don't cross session boundaries. Burstiness, density, formation/dissolution computed within sessions. Gaps between sessions don't exist.
- **`"collapse"`** — ignore session labels, treat all edges as one continuous timeline.
- **`"separate"`** — compute independently per session, return a named list of results.

**Return type convention with sessions:**
- `"bounded"` and `"collapse"`: return type is the same as documented (matrix, vector, scalar, etc.)
- `"separate"`: return type is always a named list, where each element has the same structure as the `"bounded"` result for that session.

---

## Function API

### Principle

Every function takes a `dynet`, computes, returns a result. No hidden state. No caching. Stateless, functional, predictable.

### Construction

| Function | Purpose | Returns |
|----------|---------|---------|
| `dynet(edges, ...)` | Build temporal network | `dynet` object |

### Naming Convention

All dynet functions use the `dyn_` prefix to avoid masking igraph, stats, or sna generics. This is explicit, grep-friendly, and CRAN-safe:

```r
dyn_degree(dn)              # not degree() — avoids masking igraph::degree
dyn_closeness(dn)           # not closeness() — avoids masking igraph::closeness
dyn_betweenness(dn)         # not betweenness() — avoids masking igraph::betweenness
dyn_paths(dn, from = "A")   # clear provenance
```

### Temporal Metrics (base R, no igraph)

| Function | Key Arguments | Returns | Statnet Reference |
|----------|--------------|---------|-------------------|
| `dyn_degree(dn)` | `mode = c("all", "in", "out")`, `sessions` | vertices x bins matrix | `tsna::tDegree` |
| `dyn_reachability(dn)` | `direction = c("fwd", "bkwd")`, `sessions` | integer vector per vertex | `tsna::tReach` |
| `dyn_paths(dn, from)` | `from`, `start`, `sessions` | `"dyn_paths"` data.frame: vertex, arrival_time, previous, n_hops | `tsna::tPath` |
| `dyn_closeness(dn, type = "temporal")` | `sessions` | numeric vector per vertex | custom (sum of distances) |
| `dyn_betweenness(dn, type = "temporal")` | `sessions` | numeric vector per vertex | custom (path counting) |
| `dyn_formation(dn)` | `sessions` | integer vector per bin | `tsna::tEdgeFormation` |
| `dyn_dissolution(dn)` | `sessions` | integer vector per bin | `tsna::tEdgeDissolution` |
| `dyn_durations(dn)` | `sessions` | named numeric per unique edge pair | `tsna::edgeDuration` |
| `dyn_burstiness(dn)` | `sessions` | list: `$burstiness` (numeric vector), `$iet` (list of IET vectors) | Goh & Barabasi (2008) |
| `dyn_density(dn)` | `sessions` | scalar | `tsna::tEdgeDensity` |

### Snapshot Metrics (igraph required)

All snapshot functions internally call `.build_snapshots()` (an internal helper in `snapshots.R`) to construct igraph objects for each bin. Each function builds its own snapshots — no shared state.

**Graph-level** (return numeric/integer vector per bin):

| Function | Key Arguments | Statnet Reference |
|----------|--------------|-------------------|
| `dyn_snapshot(dn, at)` | `at` (time point) | `networkDynamic::network.collapse` |
| `dyn_snapshots(dn)` | `sessions` | `networkDynamic::get.networks` |
| `dyn_sdensity(dn)` | `sessions` | `sna::gden` via `tSnaStats` |
| `dyn_transitivity(dn)` | `sessions` | `sna::gtrans` via `tSnaStats` |
| `dyn_reciprocity(dn)` | `sessions` | `sna::grecip` via `tSnaStats` |
| `dyn_centralization(dn, measure)` | `measure = c("degree", "betweenness", "closeness")`, `sessions` | `sna::centralization` |
| `dyn_components(dn)` | `sessions` | `sna::components` |
| `dyn_dyad_census(dn)` | `sessions` | `sna::dyad.census` |
| `dyn_triad_census(dn)` | `sessions` | `sna::triad.census` |
| `dyn_distance(dn)` | `sessions` | `igraph::mean_distance` + `igraph::diameter` |
| `dyn_assortativity(dn)` | `sessions` | `igraph::assortativity_degree` |

**Node-level** (return vertices x bins matrix):

| Function | Statnet Reference |
|----------|-------------------|
| `dyn_closeness(dn, type = "snapshot")` | `igraph::closeness` |
| `dyn_betweenness(dn, type = "snapshot")` | `igraph::betweenness` |
| `dyn_eigenvector(dn)` | `igraph::eigen_centrality` |
| `dyn_pagerank(dn)` | `igraph::page_rank` |
| `dyn_hub_score(dn)` | `igraph::hits_scores` |
| `dyn_authority_score(dn)` | `igraph::hits_scores` |
| `dyn_constraint(dn)` | `igraph::constraint` |
| `dyn_coreness(dn)` | `igraph::coreness` |

**`dyn_closeness()` and `dyn_betweenness()` dispatch:** These two functions live in a single file (`centrality.R`) and dispatch on `type`:
- `type = "temporal"` (default): pure base R temporal algorithm (BFS-based)
- `type = "snapshot"`: igraph-based per-snapshot computation

### `dyn_paths` Class

`dyn_paths(dn, from)` returns a `"dyn_paths"` class (inherits `data.frame`) with:
- Columns: `vertex`, `arrival_time`, `previous`, `n_hops`
- Attributes: `source`, `start_time`
- Own `plot.dyn_paths()` method: tree layout visualization of the BFS tree

### Visualization

| Plot Type | What It Shows |
|-----------|--------------|
| `"degree"` | Mean degree over time (line) |
| `"formation"` | Formation + dissolution lines |
| `"reachability"` | Forward reachability histogram |
| `"centrality"` | Temporal betweenness bar chart (top 20) |
| `"burstiness"` | Burstiness histogram with B=0 reference |
| `"duration"` | Edge duration histogram |
| `"iet"` | Inter-event time histogram (log scale if heavy-tailed) |
| `"snapshot"` | Grid of igraph plots at evenly-spaced times |
| `"reciprocity"` | Reciprocity + transitivity over time |
| `"centralization"` | Degree/betweenness/closeness centralization over time |
| `"eigenvector"` | Mean eigenvector centrality over time |
| `"dyad_census"` | Stacked area: mutual/asymmetric/null |
| `"proximity"` | Proximity timeline (flagship) |

All via `plot(dn, type = "...")`, returns ggplot2 object (except `"snapshot"` which uses base igraph graphics). Plot functions internally call the relevant `dyn_*` computation function — e.g., `plot(dn, type = "degree")` calls `dyn_degree(dn)` internally.

### S3 Methods

| Method | Purpose |
|--------|---------|
| `print.dynet()` | Compact summary: vertices, edges, time range, bins, sessions |
| `summary.dynet()` | Full report: overview + edge dynamics stats |
| `plot.dynet()` | Dispatch to plot types |
| `plot.dyn_paths()` | BFS tree visualization |

---

## Edge Case Conventions

Matching statnet/sna conventions exactly:

| Situation | Convention |
|-----------|-----------|
| NaN reciprocity on empty graph | 0 |
| NaN transitivity (no two-paths/triples) | 1 (matches `sna::gtrans`) |
| NA assortativity on edgeless bins | NA |
| NaN closeness (isolated vertex) | 0 |
| PageRank on empty graph | 1/n for all vertices |
| Burstiness with < 2 events | NA |
| Reachability includes self | Yes (matches `tsna::tReach`) |
| Self-loops | Accepted, warned, excluded from degree |

---

## File Structure

```
Dynet/
  DESCRIPTION
  NAMESPACE
  R/
    dynet.R          # dynet() constructor, validation, smart column detection
    degree.R         # dyn_degree()
    paths.R          # dyn_paths(), dyn_reachability()
    centrality.R     # dyn_closeness(), dyn_betweenness() (both temporal + snapshot),
                     #   dyn_eigenvector(), dyn_pagerank(), dyn_hub_score(),
                     #   dyn_authority_score(), dyn_constraint(), dyn_coreness()
    dynamics.R       # dyn_formation(), dyn_dissolution(), dyn_durations(),
                     #   dyn_burstiness(), dyn_density()
    snapshots.R      # dyn_snapshot(), dyn_snapshots(), .build_snapshots(),
                     #   dyn_sdensity(), dyn_transitivity(), dyn_reciprocity(),
                     #   dyn_centralization(), dyn_components(), dyn_dyad_census(),
                     #   dyn_triad_census(), dyn_distance(), dyn_assortativity()
    plot.R           # plot.dynet() — all plot types except proximity
    proximity.R      # proximity timeline (called by plot.dynet type="proximity")
    methods.R        # print.dynet(), summary.dynet(), plot.dyn_paths()
    utils.R          # .detect_columns(), .resolve_sessions(), .build_time_bins(),
                     #   .temporal_bfs(), .temporal_bfs_backward(), .trace_path()
  tests/testthat/
    helpers.R        # shared synthetic data generators (chain, star, random, burst)
    test-dynet.R     # constructor, validation, column detection, sessions
    test-degree.R    # vs tsna::tDegree
    test-paths.R     # BFS, reachability vs tsna::tPath, tsna::tReach
    test-centrality.R # closeness/betweenness (temporal + snapshot), eigenvector, etc.
    test-dynamics.R  # formation/dissolution/durations/burstiness vs tsna
    test-snapshots.R # snapshot graph-level metrics vs sna/igraph
    test-plot.R      # all plot types return ggplot/invisible
    test-proximity.R # proximity timeline
    test-methods.R   # print, summary
  man/               # roxygen2-generated
```

Each R file < 400 lines. Each test file mirrors its source. `dyn_closeness()` and `dyn_betweenness()` live in `centrality.R` (single definition, `type` dispatch), eliminating any NAMESPACE collision.

---

## Numerical Equivalence Contract

Every metric must pass exact equivalence against statnet references:

| Dynet Function | Reference Implementation | Tolerance |
|----------------|-------------------------|-----------|
| `dyn_degree()` | `tsna::tDegree` | Exact (integer) |
| `dyn_reachability()` | `tsna::tReach` | Exact (integer) |
| `dyn_paths()` | `tsna::tPath` | 1e-10 (arrival times) |
| `dyn_formation()` | `tsna::tEdgeFormation` | Exact (integer) |
| `dyn_dissolution()` | `tsna::tEdgeDissolution` | Exact (integer) |
| `dyn_durations()` | `tsna::edgeDuration` | 1e-10 |
| `dyn_burstiness()` | Manual Goh & Barabasi | 1e-10 |
| `dyn_density()` | `tsna::tEdgeDensity` | 1e-10 |
| `dyn_sdensity()` | `sna::gden` via `tSnaStats` | 1e-10 |
| `dyn_transitivity()` | `sna::gtrans` via `tSnaStats` | 1e-10 |
| `dyn_reciprocity()` | `sna::grecip` via `tSnaStats` | 1e-10 |
| `dyn_dyad_census()` | `sna::dyad.census` via `tSnaStats` | Exact |
| `dyn_triad_census()` | `sna::triad.census` via `tSnaStats` | Exact |
| All snapshot centralities | `igraph::*` | 1e-6 |

**Test topologies:** chain (5v), star (5v), random (10v/30e), large directed (50v/200e), large undirected (40v/150e), dense (30v/400e), very large (100v/500e). Multiple seeds per topology.

---

## Implementation Phases

### Phase 1: Foundation
- `dynet()` constructor with smart column detection
- `print.dynet()`, `summary.dynet()`
- Session infrastructure in `utils.R`
- BFS internals in `utils.R` (`.temporal_bfs()`, `.trace_path()`)
- Full test suite for constructor

### Phase 2: Core Temporal Metrics (base R)
- `dyn_degree()` — exact match vs `tsna::tDegree`
- `dyn_paths()`, `dyn_reachability()` — exact match vs `tsna::tPath`, `tsna::tReach`
- `dyn_closeness(type = "temporal")`, `dyn_betweenness(type = "temporal")`
- `dyn_formation()`, `dyn_dissolution()` — exact match vs `tsna::tEdgeFormation/Dissolution`
- `dyn_durations()` — exact match vs `tsna::edgeDuration`
- `dyn_burstiness()`, `dyn_density()`
- Full equivalence test suite

### Phase 3: Snapshot Metrics (igraph)
- `dyn_snapshot()`, `dyn_snapshots()`, `.build_snapshots()`
- All graph-level snapshot metrics
- All node-level snapshot centralities (`dyn_closeness(type="snapshot")`, etc.)
- Equivalence tests vs `tSnaStats` and igraph

### Phase 4: Visualization
- All plot types via `plot.dynet()`
- `plot.dyn_paths()` tree visualization
- Proximity timeline
- Okabe-Ito palette throughout

---

## v2 Roadmap (planned, not built in v1)

Features informed by Python ecosystem research (Teneto, Raphtory, pathpy):

| Feature | Inspired By | Priority |
|---------|-------------|----------|
| Volatility (network change rate) | Teneto | High |
| Temporal motifs (3-node, Paranjape et al.) | Raphtory | High |
| Rolling/expanding window API | Raphtory | High |
| Topological overlap / edge persistence | Teneto | Medium |
| Temporal community detection | Teneto | Medium |
| Fluctuability | Teneto | Medium |
| Temporal participation coefficient | Teneto | Medium |
| SID (segregation-integration difference) | Teneto | Low |
| Higher-order Markov path models | pathpy | Low |
| TERGM integration | R-native (tergm) | Low |

**Note:** The fixed-bin architecture in v1 (`time_bins` from `seq()`) should not be assumed in internal code, to allow rolling/expanding windows in v2.

---

## Design Constraints

1. **No for loops** — vectorized ops, apply family. Exception: temporal BFS inner loop (unavoidable sequential dependency).
2. **igraph in Suggests** — snapshot functions require it and say so clearly. Core temporal metrics work without igraph.
3. **Base R preferred** — no tidyverse. ggplot2 for plots only.
4. **`dyn_` prefix** — all exported computation functions prefixed to avoid namespace collisions with igraph/sna/stats.
5. **cograph-compatible** — same fields, recognized by `$meta$type == "temporal"`.
6. **CRAN-ready** — `@return` tags on all exports, no global variable warnings, `_R_CHECK_LIMIT_CORES_` guard.
7. **Okabe-Ito palette** — all visualizations use this accessible color palette.
