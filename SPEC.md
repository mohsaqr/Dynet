# Temporal Network Analysis Module — Build Spec

## Goal

Build an enterprise-grade temporal network analysis module for Nestimate that is:
1. Numerically exact against established reference implementations (tsna, ndtv, networkDynamic, igraph)
2. Architecturally aligned with cograph's `cograph_network` output format
3. Capable of handling real-world temporal network data at scale
4. Dependency-minimal (igraph in Suggests, not Imports)

## Scope

One file, one module:

| File | Purpose |
|------|---------|
| `R/temporal_network.R` | Core temporal network construction, metrics, S3 methods |

Plus full test suite in `tests/testthat/test-temporal_network.R`.

---

## Entry Point

```r
temporal_network(edges, from_col, to_col, onset_col, terminus_col,
                 directed = TRUE, time_interval = 1)
```

**Input:** Edge-timestamped data frame. Each row = one edge event active during `[onset, terminus)`.

**Output:** S3 class `"temporal_network"` — a list structured for compatibility with the cograph ecosystem. See Return Structure section for the full layout.

---

## Computational Modules

The function computes ALL of the following in a single pass. Each module is an internal function (`.compute_*` prefix) that can be independently tested.

### A. Time-Varying Degree (`.compute_time_varying_degree`)
- Point-in-time degree at each bin start: edge active if `onset <= t AND terminus > t`
- Returns: `degree` (n_vertices x n_bins), `indegree`, `outdegree` (directed only)
- **Reference:** tsna::tDegree with `cmode="freeman"`
- **Implementation:** `tabulate()` on active from/to indices per bin. No loops.

### B. Temporal Paths & Centralities (`.compute_all_temporal_paths`)
- Earliest-arrival temporal BFS from every vertex
- Forward and backward reachability (include self, matching tsna::tReach)
- Temporal closeness: `|reachable| / sum(arrival_distances)`
- Temporal betweenness: fraction of shortest temporal paths through each vertex, normalized by `(n-1)(n-2)` (directed) or `(n-1)(n-2)/2` (undirected)
- **Reference:** tsna::tReach, Nicosia et al. (2013) temporal betweenness
- **Implementation:** Multi-pass BFS (iterate until convergence for non-DAG temporal structures). Trace paths via predecessor array.

The temporal BFS (`.temporal_bfs`) is the critical algorithm:
```
For each edge (u -> v) with onset/terminus:
  depart = max(arrival[u], onset)
  if depart < terminus AND depart < arrival[v]:
    arrival[v] = depart
Repeat until no changes (handles non-DAG cycles).
```

### C. Edge Formation & Dissolution (`.compute_formation_dissolution`)
- Per-bin counts of edges forming (onset in bin) and dissolving (terminus in bin)
- **Reference:** tsna formation/dissolution model

### D. Edge Durations (`.compute_edge_durations`)
- Per unique (from, to) pair: sum of all spell durations
- Use `tapply()` on pair keys

### E. Inter-Event Times & Burstiness (`.compute_iet_burstiness`)
- Per-vertex: sorted unique onset times of incident edges, then `diff()` for IET
- Burstiness coefficient: `B = (sigma - mu) / (sigma + mu)`
  - B < 0: periodic, B = 0: Poisson, B > 0: bursty
- **Reference:** Goh & Barabasi (2008)

### F. Temporal Density (`.compute_temporal_density`)
- `sum(edge_durations) / (n_possible_edges * time_span)`
- Directed: `n*(n-1)`, Undirected: `n*(n-1)/2`

### G. Static Snapshots (`.build_static_snapshots`)
- One igraph graph per time bin (point-in-time at bin start)
- Simplify multi-edges (match networkDynamic::network.collapse)
- All vertices present in every snapshot
- **Dependency:** igraph (in Suggests). If igraph unavailable, store snapshots as adjacency matrices instead.

### H. Snapshot-Based Metrics (`.compute_snapshot_metrics`)

**Graph-level time series** (one value per bin):
| Metric | igraph function | Fallback |
|--------|----------------|----------|
| Edge density | `edge_density()` | `n_edges / n_possible` |
| Transitivity | Manual A^2 for directed; `transitivity(type="global")` for undirected | Manual computation |
| Degree centralization | `centr_degree()$centralization` | Manual Freeman formula |
| Betweenness centralization | `centr_betw()$centralization` | Skip if no igraph |
| Closeness centralization | `centr_clo()$centralization` | Skip if no igraph |
| N components | `components()$no` | BFS-based component counting |
| Mean distance | `mean_distance(unconnected=TRUE)` | Floyd-Warshall on adj matrix |
| Diameter | `diameter()` | Max of distance matrix |
| Assortativity | `assortativity_degree()` | Manual Pearson on degree pairs |
| Reciprocity (directed) | `reciprocity()` | `sum(A & t(A)) / sum(A)` |
| Mutuality (directed) | `dyad_census()$mut` | Manual |
| Dyad census (directed) | `dyad_census()` | Manual Mut/Asym/Null |
| Triad census (directed) | `triad_census()` | Skip if no igraph |

**Convention for edge cases:**
- NaN reciprocity on empty graph -> 0
- NaN transitivity (no two-paths/triples) -> 1 (matches sna::gtrans)
- NA assortativity on edgeless bins -> NA

**Node-level time series** (n_vertices x n_bins matrices):
| Metric | igraph function | Fallback |
|--------|----------------|----------|
| Closeness | `closeness(normalized=TRUE)` | Manual BFS distances |
| Betweenness | `betweenness(normalized=TRUE)` | Skip if no igraph |
| Eigenvector | `eigen_centrality()$vector` | `eigen(A)$vectors[,1]` |
| PageRank | `page_rank()$vector` | Power iteration |
| Hub score | `hits_scores()$hub` | Skip if no igraph |
| Authority score | `hits_scores()$authority` | Skip if no igraph |
| Burt's constraint | `constraint()` | Skip if no igraph |
| K-core (coreness) | `coreness()` | Skip if no igraph |

---

## Return Structure

```r
structure(
  list(
    # ---- cograph-compatible core ----
    weights          = NULL,              # Not applicable for temporal nets
    nodes            = data.frame(        # cograph_network compatible
      id    = seq_len(n_vertices),
      label = vertex_names,
      name  = vertex_names,
      x     = numeric(n_vertices),       # Layout coords (initially 0)
      y     = numeric(n_vertices)
    ),
    edges            = canon_edges,       # data.frame: from (int), to (int),
                                          #   onset, terminus, weight (duration)
    directed         = directed,
    meta             = list(
      source   = "nestimate",
      layout   = NULL,
      temporal = list(
        time_range    = c(t_min, t_max),
        time_interval = time_interval,
        n_bins        = n_bins,
        time_bins     = time_bins
      )
    ),
    node_groups      = NULL,

    # ---- Nestimate temporal extras ----
    n_vertices       = n_vertices,
    n_edges          = nrow(canon_edges),
    vertex_names     = vertex_names,

    # Time-varying node metrics (n_vertices x n_bins matrices)
    degree           = degree_mat,
    indegree         = indeg_mat,        # NULL if undirected
    outdegree        = outdeg_mat,       # NULL if undirected

    # Temporal path centralities (n_vertices vectors)
    reachability_fwd = reach_fwd,
    reachability_bkwd = reach_bkwd,
    temporal_closeness = temp_close,
    temporal_betweenness = temp_betw,

    # Edge dynamics
    formation        = formation_vec,    # n_bins integer vector
    dissolution      = dissolution_vec,
    edge_durations   = dur_named_vec,    # named numeric (per unique pair)

    # Burstiness
    iet_vertex       = iet_list,         # list of numeric vectors per vertex
    burstiness       = burst_vec,        # n_vertices numeric

    # Global metrics
    temporal_density = scalar,

    # Snapshots (igraph objects or adjacency matrices)
    snapshots        = snapshot_list,

    # Snapshot-based graph-level (n_bins vectors)
    density_bins     = numeric,
    reciprocity      = numeric,          # NULL if undirected
    mutuality        = integer,          # NULL if undirected
    dyad_census      = matrix,           # 3 x n_bins, NULL if undirected
    transitivity     = numeric,
    centralization_degree = numeric,
    centralization_betweenness = numeric,
    centralization_closeness = numeric,
    n_components     = integer,
    triad_census     = matrix,           # 16 x n_bins, NULL if undirected
    mean_distance    = numeric,
    diameter         = numeric,
    assortativity    = numeric,

    # Snapshot-based node-level (n_vertices x n_bins matrices)
    closeness_snapshot = matrix,
    betweenness_snapshot = matrix,
    eigenvector      = matrix,
    page_rank        = matrix,
    hub_score        = matrix,
    authority_score  = matrix,
    constraint       = matrix,
    coreness         = matrix
  ),
  class = "temporal_network"
)
```

---

## S3 Methods

### `print.temporal_network(x, ...)`
Compact summary: vertices, edges, time range, bins, mean degree, reachability %, top temporal betweenness nodes.

### `summary.temporal_network(object, ...)`
Full report: per-vertex centrality table, degree time series, edge dynamics stats, graph-level time series means.

### `plot.temporal_network(x, type = "degree", ...)`
Dispatches to internal plot functions. Returns ggplot2 objects (except `"snapshot"` which uses base graphics via igraph).

| type | What it plots |
|------|--------------|
| `"degree"` | Mean degree over time (line) |
| `"formation"` | Formation + dissolution lines |
| `"reachability"` | Forward reachability histogram |
| `"centrality"` | Temporal betweenness bar chart (top 20) |
| `"burstiness"` | Burstiness histogram with B=0 reference line |
| `"duration"` | Edge duration histogram |
| `"iet"` | Inter-event time histogram (log scale if heavy-tailed) |
| `"snapshot"` | Grid of igraph plots at evenly-spaced time points |
| `"reciprocity"` | Reciprocity + transitivity over time |
| `"centralization"` | Degree/betweenness/closeness centralization over time |
| `"eigenvector"` | Mean eigenvector centrality over time |
| `"dyad_census"` | Stacked area: mutual/asymmetric/null |
| `"proximity"` | Proximity timeline (see below) |

### Colors
Use Okabe-Ito palette everywhere.

---

## Proximity Timeline

The flagship visualization. Each vertex is a horizontal trajectory over time, with y-position determined by network centrality and line width by another metric.

**Algorithm:**
1. Compute a metric matrix (n_vertices x n_bins) -- default: strength-based interleaved slot assignment
2. Interleaved slot positions: 0, +s, -s, +2s, -2s, ... -- guarantees one node at y=0 per bin
3. At each bin: sort vertices by metric, assign to interleaved slots
4. Spline-interpolate to high resolution (200+ points) for smooth curves. Clamp to observed range.
5. Render as `geom_segment()` per consecutive time pair, with `linewidth` mapped to size metric and `color` mapped to vertex/group

**Parameters:** `metric`, `size_metric`, `vertex_group`, `vertex_color`, `vertex_label`, `labels_at`, `label_size`, `line_width`, `alpha`, `highlight`, `n_slices`, `spline`

---

## Additional Exported Functions

```r
temporal_paths(x, from, start = NULL)
```
Runs temporal BFS from a single vertex. Returns data frame with vertex, arrival_time, previous, n_hops. Class `"temporal_paths"` with `plot()` method (tree layout).

```r
extract_snapshot(x, at)
```
Returns igraph graph (or adjacency matrix) of edges active at time `at`.

---

## Numerical Verification Requirements

Every metric must be verified against reference implementations using identical synthetic test data:

| Metric | Reference | Tolerance |
|--------|-----------|-----------|
| Time-varying degree | tsna::tDegree | Exact (integer) |
| Forward reachability | tsna::tReach(direction="fwd") | Exact (integer) |
| Backward reachability | tsna::tReach(direction="bkwd") | Exact (integer) |
| Edge formation/dissolution | tsna formation model | Exact (integer) |
| Temporal closeness | Custom validation (sum of distances) | 1e-10 |
| Temporal betweenness | Custom validation (path counting) | 1e-10 |
| Burstiness | Manual computation from IET | 1e-10 |
| Snapshot density | igraph::edge_density | 1e-10 |
| Snapshot transitivity | sna::gtrans / igraph::transitivity | 1e-6 |
| Reciprocity | igraph::reciprocity | 1e-10 |
| Dyad census | igraph::dyad_census | Exact |
| Triad census | igraph::triad_census | Exact |
| All node centralities | igraph functions | 1e-6 |

---

## Test Structure (test-temporal_network.R)

1. **Input validation** (8+ tests): missing columns, non-numeric times, terminus <= onset, NAs
2. **Chain topology** (5+ tests): A->B->C->D->E with known reachability, closeness, betweenness
3. **Star topology** (5+ tests): hub reaches all, leaves reach 1
4. **Undirected** (5+ tests): symmetric reachability, doubled edges in BFS
5. **Edge dynamics** (5+ tests): formation/dissolution counts, edge durations
6. **Burstiness** (3+ tests): bursty data (B > 0), periodic data (B < 0), single-event vertices (NA)
7. **Snapshot metrics** (10+ tests): density, transitivity, reciprocity, centralization per bin
8. **Node-level centralities** (5+ tests): closeness, betweenness, eigenvector, PageRank per snapshot
9. **Large-scale** (3+ tests): 100+ vertices, 1000+ edges -- verify no crashes, reasonable timing
10. **S3 methods** (5+ tests): print, summary, plot (all types return ggplot or invisible)
11. **Proximity timeline** (5+ tests): spline interpolation, interleaved slots, highlight, labels
12. **temporal_paths** (5+ tests): BFS from specific vertices, path tracing, unreachable vertices
13. **extract_snapshot** (3+ tests): correct edges at specific time points

---

## Implementation Priorities

### Phase 1: Core (must be exact)
- `temporal_network()` with modules A-F (no igraph dependency)
- All S3 print/summary methods
- Full test suite for Phase 1 functions

### Phase 2: Snapshots (igraph-enhanced)
- Module G (static snapshots) + Module H (snapshot metrics)
- Graceful degradation when igraph unavailable
- `temporal_paths()` and `extract_snapshot()`
- Snapshot-related plot types
- Compare against tsna/igraph reference values

### Phase 3: Visualization
- Proximity timeline plot
- All remaining plot types
- Performance optimization for large networks

---

## Design Constraints

1. **No for loops** -- use `vapply`, `tapply`, `tabulate`, vectorized ops. Exception: temporal BFS inner loop (unavoidable sequential dependency).
2. **igraph in Suggests only** -- core metrics (degree, reachability, burstiness, formation/dissolution, temporal density) must work without igraph. Snapshot-based metrics gracefully skip when igraph unavailable.
3. **Base R preferred** -- no tidyverse. ggplot2 for plots (already an Import).
4. **cograph_network compatible** -- `$nodes`, `$edges`, `$directed`, `$meta` fields follow cograph conventions. The `temporal_network` class can be passed to cograph functions that inspect these fields.
5. **NEVER touch diagonals** -- no zeroing, excluding, or modifying diagonal entries in any matrix operation.
6. **CRAN-ready** -- `@return` tags on all exports, no global variable warnings, `_R_CHECK_LIMIT_CORES_` guard on any parallel code.

---

## Reference: cograph_network Format

The output objects must include these fields for cograph compatibility:

```r
$weights        # numeric matrix (p x p) -- named rows/cols
$nodes          # data.frame(id = int, label = chr, name = chr, x = num, y = num)
$edges          # data.frame(from = int, to = int, weight = num)
$directed       # logical
$meta           # list(source = "nestimate", layout = NULL, ...)
$node_groups    # NULL or factor
```

For `temporal_network`: `$weights` is NULL (no single static matrix), `$edges` has extra `onset`/`terminus` columns. The `$meta$temporal` sub-list carries time metadata.

---

## Reference: Sidelined Code

The previous implementation is in `sidelined/` and copied as reference in this folder:
- `ref-temporal_network.R` -- ~1800 lines, fully functional but igraph-coupled
- `ref-test-temporal_network.R` -- comprehensive test generators and test cases

These contain working algorithms that should be reused/adapted. The main changes needed:
1. Restructure output to match cograph_network format
2. Add igraph-absent fallback paths for snapshot metrics
3. Consolidate color palettes to Okabe-Ito
4. Add `@return` roxygen tags to all exports
