# Stage 2 TODO — Path optimality criteria and temporal centrality depth

Package: `Dynet` 0.3.53
Prepared: 2026-08-28
Scope: implementation specs only. No package code is written by this document.

Every item obeys the package idiom: one call with named arguments, a tidy
one-row-per-observation base `data.frame`, vertices addressed by name,
base R only (Imports stay `cograph`, `ggplot2`, `grDevices`, `graphics`),
`.check_dynet()` then `match.arg()`, classed `errorCondition(..., class =
"dynet_*", call = NULL)`, results through `.metric()`, and full roxygen on
every export. No item asks the caller to subset, sort or filter a result.

---

## Part 0 — What was verified in this session before anything was specified

Everything in this section was run, not recalled. Commands were executed
against the working tree at `/Users/mohammedsaqr/Documents/Github/temporal`
with `devtools::load_all(".")`.

**V1. `paths()` really implements exactly one criterion.** Confirmed at
`R/paths.R:1608`, `criterion = "foremost_then_shortest"` is a hard-coded
attribute, and `args(paths)` has no `criterion` parameter:

```
function (dn, from, at = NULL, direction = c("forward", "backward"),
    sessions = c("bounded", "collapse", "separate"), start = NULL,
    end = NULL, traversal_time = 0)
```

`paths(dn, from = "A", criterion = "fastest")` fails with
`unused argument (criterion = "fastest")`. Same for `dyn_reachability()`.

**V2. MATH_ROADMAP risk #7 is already fixed — do not re-specify it.**
The roadmap's line ~71 ("Temporal betweenness counts one arbitrary
earliest-arrival tree rather than distributing dependency over all equally
optimal journeys") describes a pre-0.3.9 state. The current
`.temporal_betweenness_values()` (`R/centrality.R:1562`) distributes exact
dependency over the whole tied family using prefix × suffix counts on the
appearance DAG (`.optimal_endpoint_dependency()`, `R/centrality.R:1517`).
Verified on a diamond with two tied 2-hop journeys:

```
  node reachable arrival_time attained latency n_hops n_paths
1    A      TRUE            0     TRUE       0      0       1
...
4    D      TRUE            1     TRUE       1      2       2

  node     measure value
2    B betweenness   0.5
3    C betweenness   0.5
```

The remaining betweenness weakness is **different and narrower**: the optimal
family is hard-wired to shortest-foremost, so Dynet reports one of at least
five distinct betweenness quantities and offers the user no way to name which.
That is what item **A6** fixes.

**V3. Latest departure already exists, but only pivoted on the target.**
`paths(dn, from = "D", direction = "backward", start = 0, end = 10)` returns
latest-departure suprema into `D` for every source, with an `attained` flag
for the half-open-interval case. On the fixture below it correctly reports
`A` departing at 6. What does **not** exist is the source-pivoted dual
("from `A`, what is the latest I can leave to still reach each `z` by `H`?").
Item **A4** adds only that.

**V4. Reach and reach_count are criterion-invariant. Do not change their
values.** Every criterion optimises over the same feasible journey set, and
that set is nonempty exactly when the target is reachable; loop erasure makes
walk-reachability and path-reachability coincide (MATH_ROADMAP P07, "Path,
prefix, and finiteness contract"). MATH_ROADMAP already states this at the end
of P07: "Reach and reach count remain criterion-independent." The brief's
claim that reach depends on the criterion is wrong. `criterion` is therefore
added to `dyn_reachability()` only because item **A7** adds *cost-valued*
measures (`latency`, `duration`, `hops`) that genuinely do depend on it.

**V5. "Shortest" and "minimum hops" are currently the same quantity in
Dynet.** TGLib and Wu et al. define *shortest* as the minimum sum of edge
transition times and *minimum hops* as the minimum number of contacts. Dynet
charges one scalar `traversal_time` δ per hop, so the transition sum is
exactly `δ × hops` and the two orderings coincide for every δ ≥ 0 (including
δ = 0, where every journey has transition sum 0 and the criterion is vacuous).
They only separate once a *per-contact* cost exists. Item **A3** adds
`min_hops`; item **A3b** adds the per-contact `cost =` model that makes
`shortest` a distinct criterion.

**V6. External oracle availability, checked by running each import.**

| Reference | Status | Usable for |
|---|---|---|
| `tsna` 0.3.6 | installed | `tPath(type = )` accepts only `"earliest.arrive"` and `"latest.depart"`. **No** `fewest.steps` despite the help text. Oracle for foremost and latest-departure labels only. |
| TGLib / `pytglib` | **NOT installed**. `python3 -c "import pytglib"` → `ModuleNotFoundError`. Would need a C++17 + pybind11 build. | Nothing, unless someone compiles it. Every item below that names TGLib as its conceptual source must be verified against a hand-computed fixture instead. |
| `teneto` 0.5.3 (Python) | installed, source read in session | `temporal_participation_coeff` (formula confirmed from source), `shortest_temporal_path` (topological + temporal distance), `temporal_closeness_centrality`. |
| `dynetx` (Python) | installed | `all_time_respecting_paths`, `path_length`, `path_duration`. **Unreliable:** on the 7-contact fixture below it enumerated only 2 of the 3 valid A→D journeys, silently dropping `(A,B,0),(B,D,5)`. In isolation the same two edges are found. Use only on fixtures where the source has a single appearance, and never as the sole oracle. |
| `raphtory` 0.17.0 (Python) | installed | `temporally_reachable_nodes`, `pagerank` (static). No criterion-specific path API. |
| `pathpy` 3.0.0a2 (Python) | installed | static algorithms only; no temporal path oracle. |
| `igraph`, `sna`, `networkDynamic` | installed | static kernels, activity semantics. |

The practical consequence: for `fastest`, `min_hops`, `shortest`, temporal
Katz, temporal PageRank and temporal walk centrality there is **no installed
reference implementation**. The primary oracle must be MATH_ROADMAP's Layer 2
— a deliberately slow exhaustive enumerator written from the written
contract, not from the production kernel — plus literal hand-computed
fixtures.

**V7. The shared fixture.** Seven instantaneous contacts, directed,
`start = 0`, `end = 10`, δ = 0:

```r
d <- data.frame(from = c("A","B","A","C","A","F","G"),
                to   = c("B","D","C","D","F","G","D"),
                time = c(0,   5,  6,  7,  1,  2,  3))
dn <- dynet(d, directed = TRUE)
```

Three A→D journeys exist. Every one of the five criteria picks a different
answer, and only the first is computable today:

| Criterion | Journey | arrival | departure | hops | duration |
|---|---|---|---|---|---|
| foremost / foremost-then-shortest **(today)** | A→F→G→D | **3** | 1 | 3 | 2 |
| minimum hops (tie-broken by arrival) | A→B→D | 5 | 0 | **2** | 5 |
| fastest | A→C→D | 7 | 6 | 2 | **1** |
| latest departure (H = 10) | A→C→D | 7 | **6** | 2 | 1 |
| pure foremost (family) | A→F→G→D | 3 | 1 | 3 (unique here) | 2 |

Verified today's answer with the engine:

```
  node reachable arrival_time attained latency n_hops n_paths
4    D      TRUE            3     TRUE       3      3       1
```

and the backward query at `end = 10` gave `A` a latest-departure supremum of
6, confirming the fastest/latest-departure row.

**V8. Result-frame precedents that the specs below reuse rather than
invent.** `.metric()` already supports `level = "edge"` and puts `from`/`to`
in the front columns — `durations()` returns `from, to, measure, value`, so
an edge-level temporal result has a home. `.paths_tables()` (`R/paths.R:1106`)
already returns `NA_integer_` for `n_hops` when tied routes disagree, so
"report the value when unique across the optimal family, `NA` otherwise" is an
existing convention, not a new one. `.path_entry_domains()` already carries an
`end_closed` flag per domain component, which is exactly the attainment
machinery `fastest` needs. `cograph::detect_communities()` is available
through an existing Import, so item **B6** needs no new dependency.

---

## Part A — Path optimality criteria

### A1 — Add the `criterion` vocabulary and the criterion-aware path frame

**Why.** `paths()` answers one of five distinct optimisation problems and
silently presents it as *the* answer; MATH_ROADMAP P07 explicitly defers the
`criterion` argument until an engine exists ("If several criteria are
genuinely implemented later, add one final named `criterion` argument and a
query-wide attribute"). This item builds the argument, the frame contract and
the metadata once, so A2–A5 each add only a solver. It ships no new criterion
by itself beyond re-labelling what exists.

**Proposed API**

```r
paths(dn, from, at = NULL,
      direction = c("forward", "backward"),
      criterion = c("foremost_then_shortest", "foremost", "min_hops",
                    "shortest", "fastest", "latest_departure"),
      cost = c("hops", "weight"),
      sessions = c("bounded", "collapse", "separate"),
      start = NULL, end = NULL, traversal_time = 0)
```

```r
dn <- dynet(school_contacts)
paths(dn, from = "Ana")                                   # unchanged default
paths(dn, from = "Ana", criterion = "min_hops")
paths(dn, from = "Ana", criterion = "fastest", start = 0, end = 10)
```

`cost` is validated here but only consulted by `criterion = "shortest"`
(item A3b); supplying `cost = "weight"` with any other criterion raises
`dynet_bad_input` rather than being ignored.

**Return.** `dynet_paths`, one row per vertex, columns in this order:

`node`, `reachable`, `arrival_time`, `departure_time`, `attained`,
`latency`, `duration`, `n_hops`, `path_cost`, `n_paths`.
Bounded mode appends `path_session`, `n_best_sessions`; separate mode
prepends `session`, `origin`. `as.data.frame(x, what = "steps")` is unchanged
in shape.

- `departure_time` — first-hop entry time of the optimal family; `NA_real_`
  when the family disagrees (existing `n_hops` convention), and equal to the
  window's lower bound `L` for the empty source journey.
- `duration` — `arrival_time - departure_time`; `NA_real_` when
  `departure_time` is `NA`. For the empty journey it is `0`.
- `latency` — unchanged meaning: `arrival_time - L` forward,
  `H - arrival_time` backward. Kept so no existing caller breaks.
- `path_cost` — the scalar the criterion actually optimised, in its own units:
  arrival for `foremost*`, hops for `min_hops`, the transition sum for
  `shortest`, duration for `fastest`, departure for `latest_departure`.
- `attained` — already present; now additionally `FALSE` when a `fastest`
  infimum or `latest_departure` supremum has no minimiser/maximiser.

Query-wide attributes gain `criterion` (already present, now honest),
`cost`, and `optimality` = `"minimum"` or `"maximum"`.

**Algorithm.** No new solver. Three mechanical changes:

1. Thread `criterion` from `paths()` through `.optimal_bounded_search()` into
   `.optimal_path_search()` and `.finalize_optimal_search()`. The selection
   rule in `.finalize_optimal_search()` (`R/paths.R:574–592`) becomes a
   dispatch on a `.criterion_select(criterion)` closure returning
   `(select_best, tie_break)` instead of the hard-coded
   `min(time)` then `min(hops)`.
2. `.optimal_paths_table()` gains the three new columns. `departure_time`
   comes from the first non-source state of each expanded route; the
   uniqueness reduction reuses the `unique(...)`-then-`NA` pattern already in
   `.paths_tables()`.
3. `.vertex_path_metadata()` gains the `cost` and `optimality` attributes.

Pitfalls. (a) `departure_time` must **not** be recovered by expanding routes
— `.optimal_steps()` refuses above 10^6 routes and expansion is the expensive
path. Carry the first-hop entry time forward on the state itself (one extra
numeric vector on `search$state`, set at `depth == 1L` and inherited
thereafter); when two predecessor arcs merge into one state with different
first-hop times, mark the state's first-hop time as ambiguous
(`NA_real_`) so ambiguity propagates instead of being resolved arbitrarily.
(b) `duration` is a difference of two nearly equal doubles on long calendar
axes — never compare durations with `==`; use `abs(a - b) < sqrt(.Machine$double.eps)`
scaled by the time range, and reuse the existing
`sprintf("%.17g")` state-key convention for exact-value identity.
(c) `path_cost` for `min_hops` is an integer count stored in a numeric column;
keep it numeric so the column type never changes with the criterion.

**References.** Bui-Xuan, Ferreira & Jarry (2003), *IJFCS* 14(2), 267–285 —
the three-criteria taxonomy. Wu, Cheng, Huang, Ke, Lu & Xu (2014), *PVLDB*
7(9), 721–732 — the four path problems on temporal graphs. Oettershagen &
Mutzel (2022), TGLib, ICDM Workshops (arXiv:2209.12587) — the five-criterion
implementation surface Dynet is matching.

**Verify against.** Nothing external: this item changes no number. The gate is
that `paths(dn, from = "Ana")` and every existing temporal-centrality value is
**bit-identical** before and after. Capture the current values of the full
`test-optimal-paths.R`, `test-paths.R`, `test-session-paths.R`,
`test-path-bounds.R` and `test-traversal-contract.R` suites as the fixture.

**Tests** (`tests/testthat/test-path-criterion-contract.R`)
- `expect_error(paths(dn, from = "Ana", criterion = "cheapest"), class = "dynet_bad_input")`
  (via `match.arg`, wrapped so the class holds).
- `expect_error(paths(dn, from = "Ana", criterion = "foremost", cost = "weight"), class = "dynet_bad_input")`.
- Regression: `expect_identical(as.data.frame(paths(dn, from = "Ana"))[c("node","arrival_time","n_hops","n_paths")], <frozen fixture>)`.
- Invariant: `duration == arrival_time - departure_time` wherever both are
  finite, asserted with `all.equal` at `sqrt(.Machine$double.eps)`.
- Invariant: for the empty source journey, `departure_time == L`,
  `duration == 0`, `n_hops == 0`, `n_paths == 1`, under every criterion.
- Property: translating every time by `+1000` shifts `arrival_time` and
  `departure_time` by 1000 and leaves `duration`, `n_hops`, `path_cost`
  (except for arrival-valued criteria) and `n_paths` unchanged.

**Effort. M.** No mathematics, but it touches the selection core, the public
frame and four session code paths, and the "changes no number" gate demands a
full regression capture first.

**Depends on.** Nothing.

---

### A2 — Add `criterion = "foremost"` (pure earliest arrival, no hop tie-break)

**Why.** The current default silently applies a *secondary* hop minimisation
that the literature's "foremost journey" does not include, so Dynet's
`n_paths` under-counts the earliest-arrival family and its betweenness credits
only the minimum-hop subset of it. Exposing pure foremost makes the existing
default legible by contrast and gives the earliest-arrival multiplicity that
Bui-Xuan et al. actually define.

**Proposed API**

```r
paths(dn, from = "Ana", criterion = "foremost")
paths(dn, from = "Ana", criterion = "foremost", start = 0, end = 10)
paths(dn, from = "Ana", criterion = "foremost", sessions = "collapse")
```

**Return.** As A1. `n_hops` is `NA_integer_` whenever the foremost family
contains journeys of differing length; `path_cost` equals `arrival_time`;
`n_paths` counts every vertex-simple journey attaining the earliest arrival.

**Algorithm.** In `.finalize_optimal_search()`, keep the
`best <- min(state$time[ids])` step and **delete** the subsequent
`best_hops <- min(state$hops[ids])` filter, so `selected_states[[endpoint]]`
retains every minimum-arrival state. `n_paths` is then
`Reduce(.path_count_add, state$count[ids], init = 0)` over the unfiltered set.

The correctness subtlety this exposes: `.optimal_path_search()`'s
`add_candidate()` currently *prunes* a state that arrives at the same
`(vertex, time, attained)` key with strictly more hops
(`if (hops[[id]] < depth) return(FALSE)`). That pruning is safe for
shortest-foremost but **not** for pure foremost, because a longer-hop prefix
at the same appearance is a genuinely distinct foremost journey. Under
`criterion = "foremost"` the state key must widen to
`(vertex, time, attained, hops)` and the hop-dominance branch must be
disabled. State count then grows from O(appearances) to
O(appearances × n).

Pitfalls. (a) Complexity: the widened state space makes the search
O(n · |atoms| · |appearances|) per source, and route expansion can be
exponential. `.optimal_steps()`'s existing 10^6 guard
(`dynet_path_expansion_too_large`) must be reached, not exceeded — check
`n_paths` before expansion, which it already does. (b) `.path_count_add()`'s
2^53 guard becomes reachable on real data; that is correct behaviour, but the
message should name the criterion. (c) Do **not** enable this criterion for
temporal betweenness — see A6.

**References.** Bui-Xuan, Ferreira & Jarry (2003) — foremost journey.
Buß, Molter, Niedermeier & Rymar (2024), *Network Science* 12(2), 160–188 —
foremost vs. shortest-foremost path families and their counting complexity.
Casteigts, Corsini & Sarkar (2024), *TCS* 991, 114434 — vertex-simple
temporal path definitions.

**Verify against.** `tsna::tPath(type = "earliest.arrive")` (installed 0.3.6)
for the arrival *labels* only — it selects one route under ties and cannot
validate the family size. Family size is validated against a hand-rolled
exhaustive enumerator over vertex-simple sequences on a ≤ 6-vertex fixture,
written from MATH_ROADMAP P07's contract and not from `.optimal_path_search`.

**Tests** (`test-path-criterion-foremost-contract.R`)
- Error path: `expect_error(dyn_centrality(dn, measure = "betweenness", scope = "temporal", criterion = "foremost"), class = "dynet_intractable_criterion")`.
- Literal: on a fixture with one 1-hop and one 3-hop journey both arriving at
  `t = 4`, `foremost` gives `n_paths == 2` and `n_hops == NA_integer_`,
  while `foremost_then_shortest` gives `n_paths == 1` and `n_hops == 1L`.
- Invariant: `arrival_time` is identical under `foremost` and
  `foremost_then_shortest` for every vertex and every fixture — the two
  criteria differ only in the family, never in the optimum.
- Invariant: `n_paths(foremost) >= n_paths(foremost_then_shortest)`
  pointwise.
- Property: edge-row permutation and vertex relabelling leave `n_paths`
  unchanged.

**Effort. M.** The solver change is small; the widened state key and its
complexity consequences need care and a guard rail.

**Depends on.** A1.

---

### A3 — Add `criterion = "min_hops"` (fewest time-respecting contacts)

**Why.** Minimum hops is the temporal analogue of static geodesic distance and
is the only criterion under which "temporal closeness" is comparable with
static closeness. Dynet cannot express it: the fixture in V7 shows the current
default returning a 3-hop journey when a 2-hop one exists. TGLib ships it as
`minimum hops`; teneto's `shortest_temporal_path` reports it as *topological
distance*.

**Proposed API**

```r
paths(dn, from = "Ana", criterion = "min_hops")
paths(dn, from = "Ana", criterion = "min_hops", start = 0, end = 10)
dyn_centrality(few, measure = "closeness", scope = "temporal",
               criterion = "min_hops")
```

**Return.** As A1. `path_cost` equals `n_hops`. `arrival_time` is the earliest
arrival *among minimum-hop journeys* (the documented tie-break), so it is
generally later than the foremost arrival. `n_paths` counts journeys attaining
both the minimum hop count and that earliest arrival.

**Algorithm.** The tie-break must be stated as part of the criterion:
`min_hops` orders journeys by `(h(J), A(J))` ascending — the reverse
lexicographic order that MATH_ROADMAP P07 names "shortest-then-foremost" and
explicitly rejects as the *default*. This ordering is prefix-optimal within a
fixed hop budget, so a layered Bellman relaxation is exact:

```
EA[0, s] = L ;  EA[0, v] = +Inf for v != s
for k = 1 .. n-1:
    EA[k, v] = min( EA[k-1, v],
                    min over atoms a = (u -> v) of
                      .path_forward_entry(domains[[a]], EA[k-1, u]) + delta )
n_hops(z)      = min { k : EA[k, z] finite }
arrival_time(z) = EA[n_hops(z), z]
```

The inner relaxation is exactly the existing `.path_forward_entry()` call, so
the hop layering already present in `.optimal_path_search()`'s
`for (depth in seq_len(max(0L, n - 1L)))` loop is reused unchanged; only the
per-layer state retention changes. At layer `k` keep, per vertex, the single
earliest arrival — this is safe because a later arrival at the same vertex and
hop count can never extend to an earlier arrival downstream (monotonicity of
`.path_forward_entry` in `ready`). State count therefore *falls* to
O(n × hops), the cheapest of the five criteria.

`n_paths` is counted on the layer-`k*` sub-DAG: an arc `(u at layer k-1) →
(v at layer k)` is retained only when `.path_forward_entry(a, EA[k-1,u]) + δ`
equals `EA[k, v]` exactly, then `count[k, v] = Σ count[k-1, u]` through
`.path_count_add()`.

Pitfalls. (a) `seq_len(max(0L, n - 1L))`, never `1:(n-1)` — a singleton
network must produce zero layers. (b) The equality test selecting retained
arcs is a double comparison; use the existing
`state_key`/`sprintf("%.17g")` canonicalisation, not `==`, or minimum-hop
counts will be wrong by one on calendar axes. (c) Early termination when a
layer adds no state, which the existing loop already does via
`if (!added && !any(hops == depth)) break`. (d) `min_hops` and `shortest` are
**the same criterion** under Dynet's scalar `traversal_time` (see V5);
`criterion = "shortest"` with the default `cost = "hops"` must therefore
delegate to this solver and record `criterion = "shortest"` with
`cost = "hops"` in metadata rather than pretending to be a second algorithm.

**References.** Bui-Xuan, Ferreira & Jarry (2003) — shortest journey by hop
count. Wu et al. (2014), *PVLDB* 7(9) — minimum-hop path problem. Pan &
Saramäki (2011), *Phys. Rev. E* 84, 016105 — temporal path length and its use
in temporal centrality.

**Verify against.** No installed R oracle: `tsna::tPath()` 0.3.6 rejects
`fewest.steps` (verified in session). Use (i) a hand-rolled exhaustive
enumerator on ≤ 6 vertices, (ii) `teneto.networkmeasures.shortest_temporal_path`
(installed 0.5.3) for the *topological distance* column on discrete-time
fixtures with `steps_per_t = 1`, and (iii) `dynetx.algorithms.path_length`
**only** on fixtures where the source has a single appearance — dynetx dropped
a valid journey on the V7 fixture (verified in session) and is not trustworthy
beyond that. On the V7 fixture the expected literal is
`n_hops(A → D) == 2L`, `arrival_time == 5`, `path_cost == 2`.

**Tests** (`test-path-criterion-minhops-contract.R`)
- Error path: `expect_error(paths(dn, from = "nobody", criterion = "min_hops"), class = "dynet_unknown_vertex")`.
- Literal: the V7 fixture gives `n_hops = 2`, `arrival_time = 5` for `D`,
  against the default's `n_hops = 3`, `arrival_time = 3`.
- Invariant (dominance): for every vertex and every fixture,
  `n_hops(min_hops) <= n_hops(foremost_then_shortest)` and
  `arrival_time(min_hops) >= arrival_time(foremost_then_shortest)`.
  A criterion that violates either is wrong.
- Invariant (reach): `is.finite(arrival_time)` is identical under
  `min_hops` and the default — the criterion never changes reachability (V4).
- Invariant (bound): `n_hops <= n - 1` for every vertex.
- Property: on a static-equivalent network (every contact active over the
  whole window), `n_hops` equals the unweighted geodesic distance from
  `.geodesic()`, which is an in-package oracle.

**Effort. M.** The layered DP is a genuine but small new solver that reuses
`.path_forward_entry()`; the counting sub-DAG and the double-comparison
discipline are the real work.

**Depends on.** A1.

---

### A3b — Give `criterion = "shortest"` a per-contact cost so it stops being `min_hops`

**Why.** Under Dynet's single scalar `traversal_time`, "minimum transition
sum" is `δ × hops` and carries no information beyond hop count (V5). Shipping
`shortest` as a distinct criterion name without a per-contact cost would be a
false catalogue entry. This item makes the distinction real and is the only
place where Dynet's edge `weight` acquires a path-theoretic meaning.

**Proposed API**

```r
paths(dn, from = "Ana", criterion = "shortest", cost = "weight")
dyn_centrality(few, measure = "closeness", scope = "temporal",
               criterion = "shortest", cost = "weight")
```

`cost = "hops"` (the default) delegates to A3 and is documented as identical
to `criterion = "min_hops"`. `cost = "weight"` treats each canonical contact
atom's `weight` as its additive transition cost **and** as its traversal
duration, so a heavier contact both costs more and takes longer.

**Return.** As A1. `path_cost` is the summed contact weight;
`arrival_time` is the earliest arrival among minimum-cost journeys.

**Algorithm.** Replace the constant `δ` in the A3 recurrence by the atom's own
weight `w(a)`, and replace the hop-layer index by a cost-ordered relaxation:

```
C[v] = min over atoms a = (u -> v) of ( C[u] + w(a) )
       subject to .path_forward_entry(domains[[a]], EA[u]) being finite
```

with `EA[v]` updated jointly. Because cost and time both increase along a
journey and vertex-simplicity bounds path length by `n - 1`, a Bellman–Ford
sweep over `n - 1` rounds is exact; a Dijkstra-style priority relaxation is
**not** valid here without proving that a cheaper prefix never arrives later
in a way that blocks a downstream contact — it can, so the label is the
2-D pair `(cost, arrival)` and the retained set per vertex is its Pareto
frontier, not a single scalar.

Pitfalls. (a) Weights must be strictly positive, or a zero-cost cycle
re-admits non-simple journeys; raise `dynet_bad_input` on any weight ≤ 0.
(b) Summing many weights accumulates floating-point error; sum in a fixed
canonical atom order (`atom_id`, which `.canonical_path_atoms()` already
assigns deterministically) so the same journey always produces the same
double, and compare costs with an explicit tolerance. (c) The Pareto frontier
per vertex can be O(|atoms|) wide; cap it and surface the cap as a classed
warning rather than truncating silently. (d) `weight` currently plays no role
in path identity — MATH_ROADMAP P08 states "weights ... do not multiply
paths". Making weight a cost changes that contract for this criterion only,
and the change must be recorded in the query-wide metadata
(`cost = "weight"`).

**References.** Wu, Cheng, Ke, Huang, Huang & Wu (2016), *IEEE TKDE* 28(11),
2927–2942 — shortest (minimum total traversal time) temporal paths.
Oettershagen & Mutzel (2022), TGLib — the `shortest` vs `minimum hops`
distinction.

**Verify against.** No installed oracle. Hand-computed fixture: a
three-vertex network with `A→B` weight 1 at `t = 0`, `B→C` weight 1 at
`t = 2`, `A→C` weight 5 at `t = 1`. Expected `path_cost(C) = 2` via `B`
(cost-optimal) versus `n_hops(C) = 1` via the direct contact — the two
criteria must disagree, which is the whole point of the item.

**Tests** (`test-path-criterion-shortest-contract.R`)
- Error path: `expect_error(paths(dn0, from = "A", criterion = "shortest", cost = "weight"), class = "dynet_bad_input")` on a network with a zero weight.
- Literal: the three-vertex fixture above.
- Invariant: with all weights equal to 1, `criterion = "shortest", cost = "weight"`
  reproduces `criterion = "min_hops"` exactly, including `n_paths`.
- Invariant: scaling every weight by `c > 0` multiplies `path_cost` by `c`
  and leaves the selected journey family identical.
- Property: adding a contact can only decrease or preserve `path_cost`,
  never increase it.

**Effort. L.** A genuinely new 2-D Pareto relaxation, a new meaning for
`weight`, and a frontier-width guard. Do this only after A3 ships.

**Depends on.** A1, A3.

---

### A4 — Add `criterion = "fastest"` (minimum journey duration, with attainment)

**Why.** Fastest is the only criterion that measures elapsed transit rather
than clock position, and it is the one criterion whose subpath-optimality
fails, so it cannot be bolted onto the existing single-label DP. MATH_ROADMAP
P07 already flags this ("Fastest can also have an unattained infimum at a
half-open interval boundary") and P07's own oracle spec demands "a literal
half-open-interval fixture with no minimizer".

**Proposed API**

```r
paths(dn, from = "Ana", criterion = "fastest")
paths(dn, from = "Ana", criterion = "fastest", start = 0, end = 10)
dyn_centrality(few, measure = "closeness", scope = "temporal",
               criterion = "fastest")
```

**Return.** As A1. `path_cost` equals `duration`. `attained` is `FALSE` when
the infimum is approached but not achieved; in that case `duration` holds the
infimum, `departure_time` and `arrival_time` hold the *supremal* departure and
its arrival as suprema, and `n_paths` is `0` (there is no minimising journey,
exactly as the existing backward-supremum convention already does).

**Algorithm — and why the obvious DP is wrong.**

Subpath optimality fails: if `J` is a fastest `s → z` journey passing through
`y`, its prefix `s → y` need not be a fastest `s → y` journey. On the V7
fixture the fastest `A → D` journey is `A→C→D` (duration 1) whose prefix
`A→C` has duration 0 — fine — but reverse the construction and a *later*
departure that is worse for `y` becomes better for `z`, because departing
later shortens the total wait even though it delays the intermediate arrival.
Consequently there is no scalar label per vertex that a Bellman relaxation can
minimise.

The correct reformulation: **fix the departure and the problem becomes
prefix-optimal again.** For a fixed departure lower bound `d`, minimising
arrival is exactly the existing earliest-arrival search, so

```
duration*(z) = inf over d in D of ( EA_d(z) - d )
```

where `EA_d(z)` is `.optimal_path_search(..., origin = d, direction = "forward")`
and `D` is the set of feasible first-hop departure times from `s`.

`EA_d(z)` is a non-decreasing step function of `d`, and its jump points lie
among the entry-domain endpoints of the canonical atoms. Therefore the infimum
is attained at one of:

1. the right endpoint `b` of a maximal domain component `[a, b]` with
   `end_closed = TRUE` — attained;
2. the supremum `b` of a component `[a, b)` with `end_closed = FALSE` — the
   candidate value is `lim_{d → b⁻} (EA_d(z) - d)`, an infimum with
   `attained = FALSE`;
3. `L` itself (the empty-wait departure).

Procedure: build the candidate set `D` from `.path_entry_domains()` of the
atoms incident to `s`, intersected with `[L, H]`, carrying each candidate's
`end_closed` flag; sort ascending; run the existing forward search once per
candidate; take the componentwise minimum of `EA_d(z) - d` per target `z`,
recording which candidate achieved it and whether that candidate was closed.

Pitfalls. (a) **Complexity.** `|D|` is O(deg(s) + number of domain
components) for a single `paths()` call — acceptable. For
`dyn_centrality(scope = "temporal")` it multiplies the already-O(n) search
count, giving O(n · |D| · search). Cap `|D|` and raise a classed warning
(`dynet_fastest_candidate_cap`) rather than running for hours; document
Wu et al. (2016)'s O(n + M) one-pass sliding-window algorithm as the
optimisation path if profiling demands it. (b) **Cancellation.**
`EA_d(z) - d` subtracts two nearly equal doubles on calendar axes; compute in
the network's native numeric time (which `.encode()` already produces) and
compare durations with a tolerance scaled to the observation span, never with
`==`. (c) **Unattained infima are the normal case, not an edge case.** With
δ = 0 and an interval contact `[0, 10)` followed by a point contact at
`t = 10`, every departure `d < 10` gives duration `10 - d`; the infimum is 0
and no journey attains it. This must return `duration = 0`,
`attained = FALSE`, `n_paths = 0` — never a fabricated minimiser at `d = 10`.
(d) The `attained` column already exists and already means this for backward
suprema, so the semantics compose; do not invent a second flag.

**References.** Bui-Xuan, Ferreira & Jarry (2003) — fastest journey.
Wu, Cheng, Ke, Huang, Huang & Wu (2016), *IEEE TKDE* 28(11), 2927–2942 —
the one-pass fastest-path algorithm and the departure-sweep formulation.
Oettershagen & Mutzel (2022), TGLib — `fastest` as a first-class query.

**Verify against.** No installed oracle (TGLib absent, `tsna` cannot do it).
Two fixtures, both hand-computed: (i) the V7 fixture, expected
`duration(A → D) = 1`, `departure_time = 6`, `arrival_time = 7`,
`attained = TRUE`; (ii) the half-open fixture `A→B` on `[0, 10)` and `B→C` at
instant `t = 10` with δ = 0, expected `duration(A → C) = 0`,
`attained = FALSE`, `n_paths = 0`. `dynetx.algorithms.path_duration` may
cross-check (i) only, with the enumeration caveat from V6.

**Tests** (`test-path-criterion-fastest-contract.R`)
- Error path: `expect_error(paths(dn, from = "Ana", criterion = "fastest", traversal_time = -1), class = "dynet_bad_input")`.
- Literal (i) and (ii) above, with (ii) asserting `attained == FALSE` and
  `n_paths == 0`.
- Invariant: `duration(fastest) <= duration(criterion)` for every other
  criterion and every vertex — fastest is the minimiser by definition. This is
  the single strongest property test in Part A; it catches a wrong candidate
  set immediately.
- Invariant: `arrival_time(fastest) >= arrival_time(foremost)` for every
  vertex.
- Invariant (reach): reachability is identical to the default (V4), including
  for unattained infima.
- Property: translating time leaves `duration` unchanged; scaling time by `c`
  scales `duration` by `c`.
- Mutation: an implementation that omits the open-endpoint candidates must
  fail fixture (ii); an implementation that treats an open endpoint as
  attained must fail its `attained` assertion.

**Effort. L.** A new outer sweep, a candidate-set derivation from the domain
machinery, an attainment contract, and a complexity guard. The single largest
item in Part A.

**Depends on.** A1.

---

### A5 — Add `criterion = "latest_departure"` (source-pivoted reverse foremost)

**Why.** V3 established that Dynet computes latest-departure suprema, but only
into a fixed *target*. The dual question — "leaving `Ana`, what is the latest
I can set off and still reach each other vertex by the deadline?" — has no
call today, and it is the natural planning query. TGLib exposes it as a
first-class criterion.

**Proposed API**

```r
paths(dn, from = "Ana", criterion = "latest_departure", end = 10)
paths(dn, from = "Ana", criterion = "latest_departure", start = 0, end = 10)
```

`direction = "backward"` combined with `criterion = "latest_departure"` is
redundant (it is the existing target-pivoted query) and must raise
`dynet_bad_input` naming the existing call rather than silently doing one of
the two.

**Return.** As A1. `path_cost` equals `departure_time` and the optimality
attribute is `"maximum"`. `attained` is `FALSE` at an open-interval supremum,
reusing the semantics `.path_backward_entry()` already implements.

**Algorithm.** Two correct routes; specify the first and document the second
as the optimisation.

*Route 1 (recommended, exact, reuses shipped code).* For each target `z`, the
latest departure from `s` into `z` by deadline `H` is precisely the
latest-departure label that a **backward** search rooted at `z` assigns to
`s`. So run `.optimal_bounded_search(dn, enc, z, H, "backward", ...)` for
every `z` and read off index `s`. Cost: `n` backward searches, i.e. exactly
what `dyn_reachability(direction = "backward")` already pays. Every session,
activity, attainment and bound rule is inherited unchanged — no new
mathematics.

*Route 2 (optimisation).* `EA_d(z)` is non-decreasing in `d`, so
`LD(z) = max { d in D : EA_d(z) <= H }` can be found by sweeping the candidate
departure set `D` from A4 in **decreasing** order and recording, for each `z`,
the first candidate at which `EA_d(z) <= H`. One pass over `|D|` forward
searches gives every `z` at once; when `|D| < n` this beats Route 1.

Pitfalls. (a) Route 1's `previous`/route reconstruction is oriented from
predecessor toward target; `.path_routes()` already reverses backward routes
(`if (identical(direction, "backward")) vertices <- rev(vertices)`), but the
`endpoint` column semantics differ — the result must be re-pivoted so rows are
targets of `s`, not sources into `z`. Get this wrong and the frame is
transposed silently. (b) Unreachable `z` gives `-Inf`; the frame must report
`departure_time = NA_real_` with `reachable = FALSE`, never `-Inf`. (c) The
deadline is `H`, which `.path_window()` resolves; when
`dn$meta$observation_explicit` is `FALSE` and no `end` is given, `H` is `Inf`
and latest departure is unbounded — raise `dynet_bad_input` requiring an
explicit `end` (or `at`) for this criterion. That is the honest response; an
`Inf` departure is not a result.

**References.** Wu et al. (2014), *PVLDB* 7(9) — latest-departure path
problem. Oettershagen & Mutzel (2022), TGLib — `latest departure` query.
MATH_ROADMAP P02 and P07 "Direction scope" for Dynet's existing
time-reversal dual and its attainment rule.

**Verify against.** `tsna::tPath(direction = "bkwd", type = "latest.depart")`
(installed 0.3.6) — a real oracle for this criterion, per-target. Run it once
per target and assemble the source-pivoted vector; that is the calibration.
Additionally, the internal cross-check: `paths(dn, from = "A",
criterion = "latest_departure", end = H)$departure_time[z]` must equal
`paths(dn, from = z, direction = "backward", end = H)$arrival_time["A"]`
for every `z`. On the V7 fixture that value is 6 for `z = D` (verified).

**Tests** (`test-path-criterion-latest-departure-contract.R`)
- Error path: `expect_error(paths(dn, from = "Ana", criterion = "latest_departure"), class = "dynet_bad_input")` on a network with no explicit observation window and no `end`.
- Error path: `expect_error(paths(dn, from = "Ana", direction = "backward", criterion = "latest_departure", end = 10), class = "dynet_bad_input")`.
- Literal: V7 fixture, `departure_time(D) == 6`, `arrival_time(D) == 7`.
- Invariant (duality): the source-pivoted / target-pivoted identity above,
  asserted for every ordered pair on a 6-vertex fixture.
- Invariant: `departure_time(latest_departure) >= departure_time(criterion)`
  for every other criterion and every vertex.
- Invariant (reach): reachability identical to the default (V4).
- Property: lowering `end` can only lower or preserve `departure_time`.

**Effort. M.** Route 1 is assembly rather than invention; the re-pivoting of
the result frame and the `Inf`-deadline guard are the real work.

**Depends on.** A1. (Route 2 additionally depends on A4's candidate set.)

---

### A6 — Make temporal closeness and betweenness criterion-aware

**Why.** This is the correctness item. `dyn_centrality(scope = "temporal")`
currently reports *one* of at least five temporal closeness measures and
*one* of at least five temporal betweenness measures, with the choice welded
into `.temporal_closeness_values()` (distance = foremost latency) and
`.temporal_betweenness_values()` (family = shortest-foremost), and
advertises it only as a `criterion` attribute. Buß et al. (2024) show these
are genuinely different rankings, not rescalings.

**Proposed API**

```r
dyn_centrality(few, measure = "closeness", scope = "temporal",
               criterion = "min_hops")
dyn_centrality(few, measure = "betweenness", scope = "temporal",
               criterion = "min_hops")
dyn_centrality(few, measure = c("closeness", "reach"), scope = "temporal",
               criterion = "fastest", start = 0, end = 10)
```

`criterion` defaults to `"foremost_then_shortest"`, so every existing call
returns exactly what it returns today.

**Return.** Unchanged `dynet_metric` shape: `node`, `measure`, `value`
(plus `session` when present). What changes is metadata:
`criterion` (already present), and `distance` — currently the fixed string
`"forward_latency"` — becomes one of `"forward_latency"`,
`"hop_count"`, `"transition_sum"`, `"journey_duration"`. The
betweenness record's `criterion` and `path_identity` follow the same
dispatch. For a mixed-measure call these go under `measure_metadata`, which
`.temporal_centrality()` already does.

**Algorithm.**

*Closeness.* `.temporal_closeness_values()` takes a distance vector rather
than hard-coding `tree$arrival - tree$origin`:

| criterion | distance `d(s, z)` |
|---|---|
| `foremost_then_shortest`, `foremost` | `arrival - L` (unchanged) |
| `min_hops` | hop count of the minimum-hop journey |
| `shortest` | transition sum |
| `fastest` | journey duration |
| `latest_departure` | `H - departure` |

`C(s) = |R_s| / Σ_{z ∈ R_s} d(s, z)`, keeping every existing boundary
convention: no reachable non-self endpoint → 0; all distances zero → `Inf`;
zero-distance endpoints stay in the numerator. The existing assertion
`all(latency >= 0)` generalises to `all(d >= 0)` and must stay — under
`fastest` with an unattained infimum `d` is the infimum, still ≥ 0.

Note the unit change: `min_hops` closeness is dimensionless and directly
comparable with static closeness; the others carry inverse-time units. The
`distance` metadata field is what tells the user which they have, and the
print header should not be relied on for it.

*Betweenness.* `.optimal_endpoint_dependency()` is already criterion-agnostic
in structure — it does prefix × suffix counting on whatever
`selected_states[[endpoint]]` contains. Once A1 makes state selection a
dispatch, betweenness follows for free **for the criteria whose optimal
family is polynomially countable**.

That qualification is the crux. Buß, Molter, Niedermeier & Rymar (2024) and
Rymar, Molter, Nichterlein & Niedermeier (2023) classify temporal betweenness
by optimality concept; per that classification the *shortest*,
*shortest-foremost* and *prefix-foremost* variants admit polynomial-time
algorithms while counting optimal *foremost* and *fastest* journeys is
#P-hard. Dynet's existing implementation sits on the tractable
shortest-foremost side, which is why it works. **Confirm the exact table in
Buß et al. (2024) §1 and Rymar et al. (2023) Table 1 before enabling any
criterion for betweenness — I did not have either paper open in this
session.** Until confirmed, the safe implementation is:

- enable betweenness for `foremost_then_shortest` (today), `min_hops`,
  `shortest`;
- reject `foremost` and `fastest` with a classed
  `dynet_intractable_criterion` error naming the reference;
- reject `latest_departure` for betweenness outright — its optimal family is
  defined by a supremum that may be unattained, so there is no family over
  which to distribute dependency (MATH_ROADMAP P07 "Direction scope" already
  makes exactly this argument for backward routes).

Pitfalls. (a) Under `fastest`, closeness must use the *infimum* distance even
when unattained, and must document that; silently dropping unattained targets
would reintroduce MATH_ROADMAP risk #6. (b) Under `min_hops`, a distance of 0
is impossible for `z ≠ s`, so the `Inf` branch of closeness becomes
unreachable — keep the branch, do not "optimise" it away. (c) Bounded-session
mode selects a winning session on the full criterion cost, not on arrival —
`.optimal_bounded_search()`'s per-endpoint reduction (`R/paths.R:650–678`)
compares `arrival` then `n_hops` and must be generalised alongside the
criterion dispatch or bounded results will mix criteria. This is the easiest
place in the whole document to introduce a silent bug.

**References.** Buß, Molter, Niedermeier & Rymar (2024), *Network Science*
12(2), 160–188. Rymar, Molter, Nichterlein & Niedermeier (2023), *JGAA*
27(3), 173–194. Tang, Musolesi, Mascolo, Latora & Nicosia (2010), SNS '10 —
temporal closeness and betweenness. Pan & Saramäki (2011), *Phys. Rev. E* 84,
016105 — hop-count temporal closeness.

**Verify against.** `teneto.networkmeasures.temporal_closeness_centrality`
(installed 0.5.3) computes closeness on teneto's temporal distance, which is
`shortest_temporal_path`'s temporal distance — comparable to Dynet's
`min_hops`/`foremost` closeness only on discrete-time fixtures and only after
matching the reachable-set denominator; treat it as a *rank* cross-check, not
a numerical one, and record the deliberate difference. The binding oracle is a
hand-rolled exhaustive enumerator that computes each criterion's optimal
family by brute force and then the closeness/betweenness sums, per
MATH_ROADMAP Layer 2.

**Tests** (`test-temporal-centrality-criterion-contract.R`)
- Error path: `expect_error(dyn_centrality(dn, measure = "betweenness", scope = "temporal", criterion = "fastest"), class = "dynet_intractable_criterion")`.
- Error path: `expect_error(dyn_centrality(dn, measure = "betweenness", scope = "temporal", criterion = "latest_departure"), class = "dynet_bad_input")`.
- Regression: the default call is bit-identical to the frozen 0.3.53 values
  for `closeness` and `betweenness` on `school_contacts`.
- Literal: on the V7 fixture, `closeness("A")` under the default is
  `1 / mean(c(0, 6, 3, 1, 2)) = 0.4166667` (verified in session), and under
  `min_hops` it is `1 / mean(hop distances)`, hand-computed.
- Invariant: `reach` and `reach_count` are **identical** across all five
  criteria for every vertex on every fixture — the criterion-invariance
  property from V4, and the test that stops anyone "fixing" reach.
- Invariant: betweenness is zero at every source and every target of every
  pair, and total betweenness lies in `[0, (n-1)(n-2)]`, under every enabled
  criterion.
- Invariant: on a network where all five criteria select the same family
  (a single-path chain), all five give identical betweenness.
- Property: relabelling and edge-row permutation change no value.

**Effort. M.** The closeness change is small and mechanical. The betweenness
change is small in code and large in required certainty — the tractability
gating must be right, and the bounded-session reduction is a trap.

**Depends on.** A1, and at least one of A2–A5 (ship alongside A3, the
cheapest new criterion).

---

### A7 — Give `dyn_reachability()` the criterion-dependent cost measures

**Why.** `dyn_reachability()` reports only the reachable-set size, which is
criterion-invariant (V4). Adding `criterion` alone would be an inert
argument — a defect. What the verb is missing is the *cost* of reaching:
mean latency, mean duration, mean hops. Those are criterion-dependent, are
what "reachability latency" means in teneto, and today force the caller into
`n` separate `paths()` calls plus manual aggregation — a Rule 0 violation the
package currently imposes.

**Proposed API**

```r
dyn_reachability(dn, measure = c("reach", "latency"))
dyn_reachability(dn, measure = "duration", criterion = "fastest",
                 start = 0, end = 10)
dyn_reachability(dn, measure = c("reach_count", "hops"),
                 criterion = "min_hops", direction = "forward")
```

Full signature adds `criterion` (as A1) after `traversal_time`, and extends
`measure` to `c("reach", "reach_count", "latency", "duration", "hops")`.

**Return.** Unchanged `dynet_metric` at node level, one row per vertex,
direction and measure. New long-form measure names follow the existing
`forward_` / `backward_` prefix convention: `forward_latency`,
`forward_duration`, `forward_hops`, and their backward counterparts. Each is
the **mean over the reachable non-self set**, `NaN` when that set is empty
(consistent with the package's `zero_total = "NaN"` convention rather than a
fabricated 0).

**Algorithm.** `dyn_reachability()` already builds, per source, the full
search result (`.bfs_bounded` / `.bfs_backward_bounded`, `R/paths.R:1759`).
The reduction helper `.temporal_reach_values()` gains siblings
`.temporal_latency_values()`, `.temporal_duration_values()`,
`.temporal_hop_values()` that read `arrival`, `departure`, `n_hops` off the
same trees — no extra search. Reuse the closeness reduction from A6 so the
identity `closeness = 1 / forward_latency` holds exactly by construction (it
is the reciprocal of the same mean), and test that identity.

`criterion` is threaded through and recorded in metadata even when only
criterion-invariant measures are requested; the documentation states the
invariance explicitly rather than erroring, because erroring on a harmless
argument is worse than a documented no-op.

Pitfalls. (a) `duration` and `hops` are undefined for the empty source
journey; the source is already excluded from every reach denominator, so the
same exclusion applies. (b) Under `fastest` with unattained infima, the mean
duration is a mean of infima — the metadata must say so
(`attainment = "infimum_included"`). (c) Backward `duration` is measured in
original time, matching `.temporal_bfs_backward()`'s convention; do not negate
it. (d) `NaN` versus `NA`: an isolate has an empty reachable set (`NaN`, a
0/0), not a missing value.

**References.** Holme & Saramäki (2012), *Physics Reports* 519(3), 97–125 —
reachability and latency in temporal networks. Thompson, Brantefors &
Fransson (2017), *Network Neuroscience* 1(2), 69–99 — teneto's
`reachability_latency`. Pan & Saramäki (2011) — hop-count reachability.

**Verify against.** `teneto.networkmeasures.reachability_latency` (installed
0.5.3) for the latency family on discrete-time fixtures, after matching
teneto's denominator convention (teneto's `rratio` normalises differently —
record the difference). In-package: `forward_latency` must satisfy
`1 / forward_latency == closeness` from `dyn_centrality(scope = "temporal")`
under the same criterion and window, exactly.

**Tests** (`test-reachability-cost-contract.R`)
- Error path: `expect_error(dyn_reachability(dn, measure = "speed"), class = "dynet_unknown_measure")`.
- Literal: V7 fixture, `forward_latency("A") == mean(c(0, 6, 3, 1, 2)) == 2.4`
  (the reciprocal of the closeness 0.4166667 verified in session).
- Invariant (the key one): for every fixture, criterion and window,
  `1 / forward_latency` equals `closeness` from
  `dyn_centrality(scope = "temporal")` to `sqrt(.Machine$double.eps)`.
- Invariant: `reach` and `reach_count` are identical for all five criteria.
- Invariant: `forward_hops >= 1` wherever `forward_reach_count > 0`.
- Invariant: `forward_duration <= forward_latency` under `criterion = "fastest"`
  (a duration can never exceed the latency measured from a fixed window start).
- Property: an isolate returns `NaN` for every cost measure and `0` for reach.

**Effort. M.** No new search; four reduction helpers, four measure names, and
the closeness-reciprocal identity to hold exactly.

**Depends on.** A1, A6.

---

## Part B — Temporal centrality depth

Placement rule used throughout: a measure whose row unit is a **vertex** goes
into `dyn_centrality()` as a new `measure =` value. A measure whose row unit
is a **contact** does not fit a node-level frame and gets its own verb. A
measure computed **per time bin** belongs to `scope = "snapshot"`, not
`scope = "temporal"`, whatever the literature calls it.

### B1 — Temporal Katz centrality (`measure = "katz"`, temporal scope)

**Why.** Temporal Katz is the cheapest genuinely new temporal centrality —
a single O(m) stream pass — and it is the only one of the walk-based family
with an exact static limit that can be hand-computed, which makes it the right
first item to fix the streaming conventions (batching, decay, overflow) that
B2 and B3 then reuse.

**Proposed API**

```r
dyn_centrality(dn, measure = "katz", scope = "temporal", beta = 0.1)
dyn_centrality(dn, measure = "katz", scope = "temporal",
               beta = 0.1, decay = 0.05)
dyn_centrality(dn, measure = c("katz", "reach"), scope = "temporal",
               beta = 0.1, start = 0, end = 10)
```

New arguments on `dyn_centrality()`: `beta = 0.1` (walk attenuation,
`0 < beta <= 1`) and `decay = 0` (exponential time-decay rate `c >= 0`;
`0` means no decay). Both are rejected with `dynet_bad_input` outside
`scope = "temporal"` with `measure = "katz"` (or B2/B3), matching how
`rescale` is already gated to `prestige`.

**Return.** `dynet_metric`, node level, one row per vertex (per session), with
`measure = "katz"`. Metadata: `attenuation = beta`, `decay = c`,
`decay_function = "exponential"`, `walk_rule = "strict"`,
`report_time` = the window's upper bound `H`.

**Algorithm.** Béres, Pálovics, Oláh & Benczúr (2018). Temporal Katz
centrality of `v` at report time `t` is the attenuated, time-decayed count of
temporal walks ending at `v`:

```
x_t(v) = Σ over temporal walks w ending at v at time t_w <= t
             beta^{|w|} * Phi(t - t_w),      Phi(s) = exp(-c * s)
```

Streaming recurrence over canonical contact atoms `(u, v)` at trigger time
`t`, processed in nondecreasing `t`:

```
x[u] <- x[u] * Phi(t - last[u]) ; last[u] <- t
x[v] <- x[v] * Phi(t - last[v]) ; last[v] <- t
x[v] <- x[v] + beta * (x[u] + 1)
```

and at the end `x[v] <- x[v] * Phi(H - last[v])` for every `v`. The `+ 1`
counts the length-one walk consisting of that contact alone.

**Simultaneity convention — decide this explicitly.** `paths()` at δ = 0 is
*non-strict*: equal-time contacts compose into a chain. Applying that here
would make the result depend on the arbitrary order of atoms sharing a
timestamp. Therefore temporal Katz uses the **strict** rule: all atoms with
the same trigger time form one batch, and every update in the batch reads the
pre-batch `x`. This is a deliberate, documented divergence from `paths()`;
`strict = FALSE` is rejected with `dynet_bad_input` because the non-strict
fixed point over a same-instant sub-DAG is not well defined when that sub-DAG
has a cycle.

Pitfalls. (a) **Overflow.** `x` grows with stream length; with `beta` close to
1 and a long stream it can exceed double range. Bound it: raise
`dynet_katz_overflow` when any `x[v]` exceeds `.Machine$double.xmax / 2`,
naming `beta`. Do not silently return `Inf`. (b) `Phi(t - last[v])` requires
`t >= last[v]`; assert it (`.check()`) rather than trusting the sort — a
negative exponent would silently *inflate* scores. (c) `exp(-c * s)` underflows
to exactly 0 for large `c * s`, which is correct and must not be "fixed";
but `c = 0` must take the `Phi == 1` branch without calling `exp` at all, so
the no-decay case is exact. (d) Interval contacts have a trigger *interval*,
not a timestamp — use the canonical atom's `start` as the trigger and record
`interval_rule = "onset"` in metadata, or the measure is undefined for
interval networks. (e) Weights are ignored, as they are for every other Dynet
centrality; say so in metadata (`weights = "ignored"`).

**References.** Béres, F., Pálovics, R., Oláh, A., & Benczúr, A. A. (2018).
Temporal walk based centrality metric for graph streams. *Applied Network
Science*, 3, 32. Katz, L. (1953). A new status index derived from sociometric
analysis. *Psychometrika*, 18(1), 39–43. Grindrod, Parsons, Higham & Estrada
(2011), *Phys. Rev. E* 83, 046120 — dynamic communicability, the matrix form
of the same idea.

**Verify against.** No installed implementation. Hand-computed static limit:
on a temporal DAG where each contact appears exactly once and times increase
strictly along every path, the set of temporal walks equals the set of static
walks, so with `decay = 0`

```
x = Σ_{k >= 1} beta^k (t(A))^k %*% rep(1, n)
```

which is a three-line base-R fixture (`A` nilpotent on a DAG, so the sum is
finite and exact). Second fixture: a single contact `A → B`, expected
`x = c(A = 0, B = beta)`. Third: a two-contact chain `A→B` at 0, `B→C` at 1,
`decay = 0`, expected `x = c(0, beta, beta + beta^2)`.

**Tests** (`test-temporal-katz-contract.R`)
- Error path: `expect_error(dyn_centrality(dn, measure = "katz", scope = "temporal", beta = 1.5), class = "dynet_bad_input")`.
- Error path: `expect_error(dyn_centrality(dn, measure = "katz", scope = "snapshot"), class = "dynet_unknown_measure")`.
- Literal: the three fixtures above, exact to `sqrt(.Machine$double.eps)`.
- Invariant (static limit): on the DAG fixture, equal to the truncated Katz
  series computed independently with `crossprod`/matrix powers.
- Invariant (monotone in beta): `x` is non-decreasing in `beta` at every
  vertex.
- Invariant (monotone in decay): `x` is non-increasing in `decay` at every
  vertex.
- Invariant (strictness): permuting the row order of contacts that share a
  timestamp leaves every value identical — the test that proves the batch
  rule was implemented.
- Property: translating all times by a constant leaves every value unchanged
  (because `H` translates with them).

**Effort. S.** One stream pass, one decay function, three fixtures. The only
real work is the simultaneity decision and the overflow guard.

**Depends on.** Nothing. (Independent of Part A.)

---

### B2 — Temporal PageRank (`measure = "pagerank"`, temporal scope)

**Why.** Temporal PageRank is the best-known walk-based temporal centrality
and the one with a provable static limit, which gives Dynet a calibration
target it already owns (`.pagerank()`). Dynet has PageRank at snapshot scope
only, which measures a frozen slice and cannot see temporal ordering at all.

**Proposed API**

```r
dyn_centrality(dn, measure = "pagerank", scope = "temporal",
               damping = 0.85, transition = 0.9)
dyn_centrality(dn, measure = "pagerank", scope = "temporal",
               damping = 0.85, transition = 1, rescale = TRUE)
```

Reuses the existing `damping` argument (α). New argument `transition = 1`
(β, the probability of continuing to the next available outgoing contact;
`0 < beta <= 1`). `rescale = TRUE` currently requires `measure = "prestige"`;
that gate widens to include temporal `"pagerank"`, and defaults to `TRUE`
here since the raw mass is not comparable across windows.

**Return.** `dynet_metric`, node level, one row per vertex. Metadata:
`damping`, `transition`, `normalization = "sum_to_one"` or `"none"`,
`walk_rule = "strict"`, `static_limit = "pagerank_as_transition_to_one"`.

**Algorithm.** Rozenshtein & Gionis (2016). Temporal PageRank sums over
temporal walks with damping α and a per-step continuation probability β:

```
r(u, t) = Σ_{v} Σ_{k >= 0} (1 - alpha) alpha^k
             Σ_{walks v ~> u of length k, ending by t}  Π_i (1 - beta) beta^{m_i}
```

where `m_i` counts the outgoing contacts of the walk's `i`-th vertex that were
skipped between consecutive walk steps. The paper's streaming form maintains a
current score `r` and an active mass `s` and, for each contact `(u, v, t)`:

```
r[u] <- r[u] + (1 - alpha)
s[u] <- s[u] + (1 - alpha)
r[v] <- r[v] + s[u] * alpha
if (beta < 1) { s[v] <- s[v] + s[u] * alpha * (1 - beta) ; s[u] <- s[u] * beta }
else          { s[v] <- s[v] + s[u] * alpha              ; s[u] <- 0 }
```

**This pseudocode is reconstructed from memory of Algorithm 1 and must be
verified line by line against the paper before implementation.** Follow
MATH_ROADMAP's "Definition reviewer" role: an independent derivation from the
published equation, not from this document.

Simultaneity: the same strict batching rule as B1, for the same reason.

Pitfalls. (a) The `beta = 1` branch zeroes `s[u]`, which is a different
recurrence, not a limit of the `beta < 1` branch — implement both, do not
divide by `(1 - beta)`. (b) `r` grows linearly in the number of contacts; with
`rescale = TRUE` this is invisible, with `rescale = FALSE` it is not comparable
across windows — say so in metadata rather than normalising silently. (c) A
vertex that never appears as a contact endpoint keeps `r = 0`; after
rescaling it is exactly 0, not `NaN`, provided at least one contact exists.
Zero contacts in a block → all-`NaN` after rescaling, matching the existing
`zero_total = "NaN"` convention. (d) Dangling nodes: the temporal formulation
has no teleportation matrix, so there is no dangling-mass correction and the
static limit only holds under the paper's stated sampling assumption. State
that limitation.

**References.** Rozenshtein, P., & Gionis, A. (2016). Temporal PageRank.
*ECML PKDD 2016*, LNCS 9852, 674–689. Page, Brin, Motwani & Winograd (1999),
The PageRank citation ranking. Béres et al. (2018) for the shared streaming
framework.

**Verify against.** In-package oracle via the paper's own convergence result:
generate a temporal network by repeatedly sampling contacts uniformly from a
fixed static digraph in random order (multiple seeds — `RNGkind("L'Ecuyer-CMRG")`,
at least 20 seeds, report the spread, never a single seed), run temporal
PageRank with `transition = 1`, and check that the rescaled scores converge to
`Dynet:::.pagerank(b, damping)` on that static graph as the stream lengthens.
Report the max absolute deviation and its decay with stream length, and pin an
explicit tolerance justified by that decay. No external implementation is
installed to compare against.

**Tests** (`test-temporal-pagerank-contract.R`)
- Error path: `expect_error(dyn_centrality(dn, measure = "pagerank", scope = "temporal", transition = 0), class = "dynet_bad_input")`.
- Literal: single contact `A → B`, `alpha = 0.85`, `beta = 1`, hand-computed
  `r` before and after rescaling.
- Invariant (simplex): with `rescale = TRUE`, `sum(value) == 1` to
  `sqrt(.Machine$double.eps)`, and every value in `[0, 1]`.
- Invariant (static limit): the multi-seed convergence check above, asserted
  as a rank correlation of at least a pinned threshold plus a decaying max
  deviation — not as exact equality.
- Invariant (strictness): permuting same-timestamp rows changes nothing.
- Invariant (monotone in stream): appending contacts never removes a vertex
  from positive score once it has one.
- Property: relabelling changes names, not values.

**Effort. M.** The recurrence is short but must be verified against the paper;
the convergence calibration needs a multi-seed harness and an honestly
justified tolerance.

**Depends on.** B1 (shares the atom-stream iterator, the strict batching rule
and the overflow guard).

---

### B3 — Temporal walk centrality (`measure = "walk"`, temporal scope)

**Why.** Walk centrality is the one measure in this family that scores a
vertex on its *brokerage in time* — the ability to receive information early
and pass it on later — rather than on accumulated arrivals. It is the natural
cheap complement to temporal betweenness, which costs `n` searches; walk
centrality costs two stream passes.

**Proposed API**

```r
dyn_centrality(dn, measure = "walk", scope = "temporal", beta = 0.1)
dyn_centrality(dn, measure = "walk", scope = "temporal",
               beta = 0.1, decay = 0.05)
```

Reuses `beta` and `decay` from B1.

**Return.** `dynet_metric`, node level, one row per vertex, `measure = "walk"`.
Metadata: `attenuation`, `decay`, `waiting_weight = "exponential"`,
`walk_rule = "strict"`.

**Algorithm.** Oettershagen, Mutzel & Kriege (2022). A vertex is central when
many temporal walks *arrive* at it and many temporal walks *depart* from it
afterwards. With `obtain(v, t)` the β-attenuated weight of temporal walks
ending at `v` at time `t`, and `distribute(v, t)` the weight of temporal walks
starting at `v` at time `t`:

```
c(v) = Σ_{t_in <= t_out}  obtain(v, t_in) * distribute(v, t_out) * f(t_out - t_in)
```

with `f` a non-increasing waiting weight (exponential `exp(-c * s)` here, to
match B1's `decay`).

Implementation: two passes over the canonical atom stream.
Forward pass computes `obtain` exactly as B1's `x` update, recording the value
at each contact. Backward pass over the reversed stream computes `distribute`
symmetrically. Then, for each vertex, combine the two time-indexed sequences.
The naive combination is O(k_v^2) in the vertex's contact count; the paper's
contribution is an O(m) evaluation using the fact that the exponential
waiting weight factorises, `f(t_out - t_in) = exp(-c*t_out) * exp(c*t_in)`,
so a single running prefix sum of `obtain(v, t_in) * exp(c * t_in)` suffices.

**The precise definitions (their Definitions 3.1–3.3) and the exact
normalisation must be checked against the paper before implementation — this
is the item in the document I am least confident about, and the MATH_ROADMAP
"Definition reviewer" step is mandatory here rather than optional.**

Pitfalls. (a) The factorisation `exp(c*t_in)` overflows for large `c * t_in`
on calendar axes; shift times by the window's lower bound `L` first (subtract
`L` from every timestamp) so exponents stay near zero, and note that the
result is translation-invariant so this is exact, not an approximation.
(b) `c = 0` degenerates the waiting weight to 1, at which point `c(v)` is
simply `total_obtain(v) * total_distribute(v)` restricted to `t_in <= t_out` —
a good cheap self-check. (c) The `t_in <= t_out` constraint is non-strict;
combined with strict batching this means a walk can arrive and depart at the
same timestamp but through different contacts — document the choice.
(d) Scores multiply two accumulators, so overflow arrives quadratically
faster than in B1; the guard must be on the product.

**References.** Oettershagen, L., Mutzel, P., & Kriege, N. M. (2022).
Temporal walk centrality: Ranking nodes in evolving networks. *WWW '22*,
1640–1650. Béres et al. (2018) for the underlying temporal walk weighting.
Grindrod & Higham (2013), *Proc. R. Soc. A* 469, 20130006 — broadcast and
receive centrality, the matrix analogue of obtain/distribute.

**Verify against.** No installed implementation; TGLib (which ships it) is not
installed and would need compiling. Hand-computed fixtures: (i) a path
`A→B` at 0, `B→C` at 1 with `decay = 0` gives `c(B) = beta * beta = beta^2`
(one incoming walk of weight β, one outgoing of weight β) and
`c(A) = c(C) = 0`; (ii) a star where the centre receives three contacts before
sending three, with the `c = 0` product identity checked directly.

**Tests** (`test-temporal-walk-centrality-contract.R`)
- Error path: `expect_error(dyn_centrality(dn, measure = "walk", scope = "temporal", decay = -1), class = "dynet_bad_input")`.
- Literal: fixtures (i) and (ii).
- Invariant: a vertex with no incoming contact, or no outgoing contact, scores
  exactly 0.
- Invariant (`decay = 0` identity): `c(v)` equals the direct
  `Σ_{t_in <= t_out} obtain * distribute` double sum computed by a slow
  O(k^2) reference on a small fixture — this is the test that validates the
  prefix-sum factorisation.
- Invariant: `c(v)` is non-increasing in `decay`.
- Property: time translation leaves every value unchanged (the `L`-shift
  above must make this exactly true, not approximately).

**Effort. L.** Two stream passes, a factorised prefix sum, an overflow regime
worse than B1's, and a definition that must be recovered from the paper first.

**Depends on.** B1.

---

### B4 — Temporal edge betweenness as a new `edge_centrality()` verb

**Why.** Edge-level results do not fit a node-level frame, so this cannot be a
`dyn_centrality()` measure — that is the correct answer to the brief's
question. But the machinery already exists: `.optimal_path_search()` stores
`pred_atom` alongside `pred_state`, and `.optimal_endpoint_dependency()`
already computes the exact prefix × suffix counts. Crediting atoms instead of
vertices is a small, principled extension that yields a genuinely new
capability — identifying the *contacts* that carry information, which is what
intervention questions actually ask.

**Proposed API**

```r
edge_centrality(dn, measure = "betweenness")
edge_centrality(dn, measure = "betweenness", criterion = "min_hops",
                start = 0, end = 10)
edge_centrality(dn, measure = "betweenness", sessions = "separate")
```

```r
edge_centrality(dn,
                measure = c("betweenness"),
                criterion = c("foremost_then_shortest", "min_hops", "shortest"),
                sessions = c("bounded", "collapse", "separate"),
                start = NULL, end = NULL, traversal_time = 0)
```

**Return.** `dynet_metric` at `level = "edge"`, one row per **canonical
contact atom**, columns `session` (when present), `from`, `to`, `start`,
`end`, `measure`, `value`. The atom, not the dyad, is the row unit: the same
`A → B` pair active in two disjoint spells is two rows, because a temporal
path uses one of them and not the other. `.metric()`'s front-column list
already places `from`, `to` first; `start`/`end` follow.

**Algorithm.** For every ordered source `s` and reachable target `z`, the
existing `.optimal_endpoint_dependency()` computes, per state, `count[state] *
suffix[state]` — the number of optimal `s → z` journeys through that state.
The same product on a *predecessor arc* gives the number through that arc:

```
credit(atom a) += Σ over arcs (parent -> child) labelled a of
                     count[parent] * suffix[child] / sigma(s, z)
```

where `sigma(s, z) = search$n_paths[[z]]`, and `pred_atom[[child]]` already
stores the atom label parallel to `pred_state[[child]]`. Sum over all `(s, z)`
pairs, exactly as `.temporal_betweenness_values()` does.

Bounded sessions combine numerators only from full-cost winning sessions
before division, reusing `.temporal_betweenness_values()`'s existing branch.

Pitfalls. (a) The atom identity must be the one `.canonical_path_atoms()`
assigns, so duplicate spell rows, overlapping interval segmentation and
weights do not multiply credit — the same invariance the node measure already
has. (b) An atom used by no optimal journey must appear with `value = 0`, not
be dropped; a dropped-zero result forces the caller to reconstruct the atom
list, which is a Rule 0 violation. (c) The result is not normalised; its range
is `[0, (n-1)(n-2)]` as for the node measure, and that must be stated.
(d) Row count is O(atoms), which on a contact log can exceed the node count by
orders of magnitude — the print method's default 12 rows is fine, but
`summary()` should be usable, so `summary.dynet_metric(by = "measure")` must
work on an edge-level frame (check: it groups by `intersect(c("session", by,
"measure"), names(df))`, so `by = "node"` is invalid here and must default to
`"measure"`).

**References.** Oettershagen & Mutzel (2022), TGLib — temporal edge
betweenness. Buß, Molter, Niedermeier & Rymar (2024), *Network Science* 12(2)
— the path-family definitions the credit is distributed over. Brandes (2001),
*Journal of Mathematical Sociology* 25(2), 163–177 — the prefix/suffix
dependency accumulation this generalises.

**Verify against.** No installed implementation (TGLib absent). The binding
oracle is **internal and exact**, which makes this item unusually safe:

> Because every optimal journey is vertex-simple, it enters each internal
> vertex through exactly one atom. Therefore, for every internal vertex `v`,
> the sum of edge betweenness over atoms **into** `v` equals `v`'s node
> temporal betweenness, exactly.

That identity, checked against the shipped `.temporal_betweenness_values()`
on every existing fixture, is a complete correctness test. Second identity:
the total edge betweenness over all atoms equals the sum over reachable
ordered pairs of the mean hop count of that pair's optimal family.

**Tests** (`test-temporal-edge-betweenness-contract.R`)
- Error path: `expect_error(edge_centrality(dn, measure = "closeness"), class = "dynet_unknown_measure")`.
- Error path: `expect_error(edge_centrality(dn, measure = "betweenness", criterion = "fastest"), class = "dynet_intractable_criterion")`.
- Literal: the diamond from V2 — two tied journeys `A→B→D` and `A→C→D` give
  each of the four atoms credit 0.5.
- Invariant (the node identity above), asserted for every vertex on
  `school_contacts` and on the V7 fixture.
- Invariant: every value is ≥ 0 and the total is within `[0, (n-1)(n-2)]`.
- Invariant: duplicating a spell row, or splitting an interval into two
  touching halves, changes no value — the canonical-atom invariance.
- Property: relabelling and row permutation change no value.

**Effort. M.** The credit accumulation is a ten-line change to an existing
helper; the new verb, its result contract, its documentation and the
edge-level `summary()`/`plot()` behaviour are the bulk of the work.

**Depends on.** A1 and A6 (for the `criterion` argument and its gating). Can
ship criterion-free against the current default if A1 slips.

---

### B5 — Top-k temporal closeness (`top =` on `dyn_centrality`)

**Why.** Temporal closeness costs `n` full path searches, which is why the
package's own examples subset to eight vertices ("Temporal scope walks
journeys between every ordered pair, so it costs far more than a snapshot").
The usual question is "who are the ten most central", and answering it does
not require computing all `n` values. Passing `top` as an argument is also the
Rule 0 answer to "I only want the leaders" — the alternative is the banned
`head(x[order(x$value, decreasing = TRUE), ], 10)`.

**Proposed API**

```r
dyn_centrality(dn, measure = "closeness", scope = "temporal", top = 10)
dyn_centrality(dn, measure = "closeness", scope = "temporal",
               top = 10, criterion = "min_hops")
```

`top = NULL` (default) computes every vertex, exactly as today. `top = k`
returns the `k` highest, **plus every vertex tied at the k-th value** — never
an arbitrary cut.

**Return.** `dynet_metric`, node level, `k` or more rows. Metadata gains
`top = k`, `sources_evaluated` (how many full searches were actually run) and
`selection = "exact_top_k_with_ties"`. The print header must say that values
for the remaining vertices were not computed, so nobody reads the frame as a
network-wide result; `summary()` on a `top` result is a summary of the
returned rows only, and the metadata says so.

**Algorithm.** Oettershagen & Mutzel (2022), *KAIS* 64, 507–535. Branch and
bound over sources, using an upper bound on closeness that a partially
completed search already supports.

Dynet's closeness is `C(s) = |R_s| / Σ_{z ∈ R_s} d(s, z)`. During the
hop-layered expansion of `.optimal_path_search()`, after completing layer `k`:

- `|R_s|` can never exceed `n - 1`;
- `Σ d(s, z)` can never decrease — every distance already finalised is final,
  and every vertex not yet reached will contribute a distance at least as
  large as the current layer's frontier distance `d_k`.

So with `R_k` the set already reached and `U = n - 1 - |R_k|` the number still
unreached,

```
UB_k(s) = (n - 1) / ( Σ_{z in R_k} d(s, z) + U * d_k )
```

is a valid upper bound (denominator under-estimated, numerator
over-estimated). Maintain a min-heap of the current `k` best complete values;
abandon a source as soon as `UB_k(s)` falls below the k-th best. Process
sources in a heuristic order (descending snapshot degree is a cheap and
effective proxy) so the threshold rises fast.

Pitfalls. (a) **The bound must be proved, not assumed.** If `d_k` is not a
valid lower bound on every unreached distance the algorithm returns the wrong
vertices *silently*. Under `criterion = "min_hops"` `d_k = k + 1` is trivially
valid. Under `foremost` the layer frontier is an arrival time and unreached
vertices can arrive *earlier* at a later layer (that is precisely why
shortest-foremost needs the state DAG) — **so the bound is invalid for
arrival-based criteria without a separate argument.** Restrict `top` to
`criterion = "min_hops"` (and `"shortest"`, where costs are monotone along a
journey) and raise `dynet_bad_input` otherwise, until a valid bound for
arrival-based criteria is derived and written down. This is the honest scope.
(b) The pruning is worthless on small or densely reachable networks; the
`sources_evaluated` metadata is what tells the user that. (c) Exact ties at
the k-th value must all be returned, so the heap comparison uses a tolerance
consistent with the rest of the package, not `==`. (d) `top` interacts with
`sessions = "separate"`: `top` applies **within** each session block, and the
documentation must say so.

**References.** Oettershagen, L., & Mutzel, P. (2022). Computing top-k
temporal closeness in temporal networks. *Knowledge and Information Systems*,
64, 507–535. Borassi, Crescenzi & Marino (2019) — branch-and-bound top-k
closeness in static graphs, the design this follows.

**Verify against.** Itself, exactly: for every fixture and every `k`,
`dyn_centrality(..., top = k)` must return precisely the rows that the
full computation's top `k` (with ties) contains, with identical values. That
is a complete correctness oracle and needs no external package. Run it over
every bundled dataset and every `k` from 1 to `n`.

**Tests** (`test-topk-closeness-contract.R`)
- Error path: `expect_error(dyn_centrality(dn, measure = "closeness", scope = "temporal", top = 0), class = "dynet_bad_input")`.
- Error path: `expect_error(dyn_centrality(dn, measure = "closeness", scope = "temporal", top = 5, criterion = "fastest"), class = "dynet_bad_input")`
  (bound not valid for arrival-based criteria).
- Invariant (exactness): for `k` in `seq_len(n)`, the `top = k` result equals
  the corresponding rows of the full result, values included. This is the test
  that matters.
- Invariant (ties): on a vertex-transitive fixture where every closeness is
  equal, `top = 1` returns all `n` rows.
- Invariant: `sources_evaluated <= n` and, on a fixture designed for pruning
  (one hub, many leaves), `sources_evaluated < n` — otherwise the branch and
  bound is not actually pruning and the item has no value.
- Property: `top = n` is identical to `top = NULL`.

**Effort. M.** The bound derivation and its criterion restriction are the
substance; the heap and the source ordering are routine. The exactness oracle
makes it cheap to get right.

**Depends on.** A3 (the `min_hops` criterion the bound is valid for), A6.

---

### B6 — Temporal participation coefficient (`measure = "participation"`, snapshot scope)

**Why.** Participation coefficient answers a question none of Dynet's existing
measures do — whether a vertex's contacts are concentrated inside one group or
spread across groups — and its temporal version is simply that quantity per
time bin. Dynet already has the two ingredients: a snapshot grid and
`cograph::detect_communities()` through an existing Import, plus node
attributes via the same mechanism `mixing()` uses.

**Placement note.** Despite the name, this belongs to `scope = "snapshot"`,
not `scope = "temporal"`. teneto's implementation (source read in session)
"only loops through temporal snapshots and calculates `P_i` for each t" — it
involves no time-respecting path at all. Putting it under `scope = "temporal"`
would misrepresent it.

**Proposed API**

```r
dyn_centrality(dn, measure = "participation", groups = "class")
dyn_centrality(dn, measure = "participation", groups = "detect")
dyn_centrality(dn, measure = "participation", groups = "class",
               step = 1, window = 7)
```

New argument `groups = NULL`: the name of a node attribute (validated exactly
as `mixing(attribute = )` does, with the same `dynet_unknown_attribute`-style
classed error listing available attributes), or the literal `"detect"` to run
`cograph::detect_communities()` on each bin's binary adjacency. Required for
`measure = "participation"` and rejected for every other measure, mirroring
how `rescale` is gated to `prestige`.

**Return.** `dynet_metric`, node level, one row per vertex, time bin and
measure — the ordinary snapshot shape, so `plot()`, `summary()` and the wide
layout work unchanged. Metadata: `groups` (the attribute name or `"detect"`),
`community_method` (when detecting), `zero_degree = "NaN"`,
`weights = "ignored"`.

**Algorithm.** Guimerà & Amaral (2005), applied per bin. For vertex `i` in
bin `t`, with `k_i(t)` its degree and `k_{ic}(t)` the number of its active
dyads whose other endpoint is in group `c`:

```
P_i(t) = 1 - sum_c ( k_ic(t) / k_i(t) )^2
```

confirmed from teneto's own source and docstring, read in this session.

Compute inside the existing `.over_bins(..., snapshot = TRUE)` framework
alongside every other snapshot measure: from the binary adjacency `b` already
built there, `k_i = rowSums(b)` (or the `mode`-appropriate margin on a
directed network) and `k_ic = b %*% G` where `G` is the vertex-by-group
indicator matrix. Then `P = 1 - rowSums((k_ic / k_i)^2)`. That is two matrix
products, fully vectorised, no loop.

Pitfalls. (a) `k_i(t) == 0` gives 0/0. teneto sets this to 0 (`part[np.isnan(part) == 1] = 0`
— read in session); Dynet's convention for an undefined ratio is `NaN` (see
`zero_total = "NaN"` for prestige). **Return `NaN` and record the deliberate
difference from teneto in the metadata and in `@details`.** Note also that
inactive vertices already receive `NA` from the snapshot machinery — `NA`
(not eligible) and `NaN` (eligible but degree zero) are different statements
and must not be conflated. (b) With `groups = "detect"`, communities are
re-detected per bin, so labels are not comparable across bins — but the
coefficient only uses the *partition*, not the labels, so the measure is
well defined; say so, and warn that a stochastic detection method makes the
result stochastic (run multiple seeds and report stability, per the project's
statistical rules; `cograph::detect_communities(method = "louvain")` is
stochastic). Prefer a deterministic method as the default for reproducibility.
(c) Directed networks: teneto's docstring says it "sums axis=1, so tnet may
need to be transposed"; Dynet must instead honour its own `mode` argument, and
`participation` joins `.mode_aware_measures`. (d) Weights are ignored, as
everywhere else in Dynet's snapshot catalogue.

**References.** Guimerà, R., & Amaral, L. A. N. (2005). Functional cartography
of complex metabolic networks. *Nature*, 433, 895–900. Thompson, W. H.,
Brantefors, P., & Fransson, P. (2017). From static to temporal network theory:
Applications to functional brain connectivity. *Network Neuroscience*, 1(2),
69–99 — the temporal version as implemented in teneto.

**Verify against.** `teneto.networkmeasures.temporal_participation_coeff`
(installed 0.5.3, source read in session) on a discrete-time fixture with a
fixed 1-D community vector. Two caveats to record: teneto's function contains
a stray `print(part)` debug statement inside the 1-D-communities branch, and
its time-varying-communities branch divides by `netshape[1]`, which is a
different quantity — calibrate only against the 1-D branch. Also verify the
static formula against a hand-computed 5-vertex, 2-group bin.

**Tests** (`test-temporal-participation-contract.R`)
- Error path: `expect_error(dyn_centrality(dn, measure = "participation"), class = "dynet_bad_input")` (no `groups`).
- Error path: `expect_error(dyn_centrality(dn, measure = "participation", groups = "nosuch"), class = "dynet_unknown_attribute")`.
- Error path: `expect_error(dyn_centrality(dn, measure = "degree", groups = "class"), class = "dynet_bad_input")`.
- Literal: a bin where a vertex has 2 contacts in its own group and 2 outside
  gives `P = 1 - (0.5^2 + 0.5^2) = 0.5`; all contacts in one group gives
  `P = 0`.
- Invariant (range): every finite value lies in `[0, 1 - 1/n_groups]`.
- Invariant (single group): with all vertices in one group, `P == 0` for every
  active vertex and `NaN` for every zero-degree eligible vertex.
- Invariant (degree zero): eligible zero-degree vertices are `NaN`; inactive
  vertices are `NA`. Assert both, distinctly.
- Property: permuting group labels changes no value.
- Stochasticity: with `groups = "detect"` and a stochastic method, run 20
  seeds and assert the reported stability summary exists — never report a
  single-seed value.

**Effort. S.** Two matrix products inside machinery that already exists, one
new argument, one gating rule. The `NaN`/`NA` distinction and the
stochastic-detection discipline are the only subtle parts.

**Depends on.** Nothing. (Independent of Part A and of B1–B5; the cheapest
item in the document and a good first ship.)

---

## Suggested order

```
B6  (S, independent)        ─┐ ship first: cheap, self-contained, no engine risk
B1  (S, independent)        ─┘

A1  (M)  criterion vocabulary + frame contract
 ├── A2  (M)  foremost
 ├── A3  (M)  min_hops            ─┐
 │    └── A3b (L)  shortest / cost │
 ├── A4  (L)  fastest              │
 └── A5  (M)  latest_departure     │
                                   │
A6  (M)  criterion-aware closeness/betweenness  ← needs A1 + one of A2..A5
 ├── A7  (M)  reachability cost measures
 ├── B4  (M)  edge_centrality()  (can ship criterion-free before A1)
 └── B5  (M)  top-k closeness    ← needs A3's min_hops for a valid bound

B2  (M)  temporal PageRank   ← needs B1's stream conventions
 └── B3  (L)  temporal walk centrality
```

Total: 12 items — 2 small, 7 medium, 3 large.

## Cross-cutting obligations for every item

- MATH_ROADMAP's "Required feature record" is written **before** any code:
  equation, unit of analysis, directed/undirected meaning, normalisation and
  range, loop/isolate/singleton behaviour, the exact meaning of `0`, `NA`,
  `NaN` and `Inf`, and every deliberate difference from a comparison package.
- The Definition reviewer derives the equation independently; the Fixture
  reviewer derives literal values without touching the production kernel.
  These are mandatory for A4, A6, B2 and B3.
- No item is done until `R CMD check --as-cran` is clean and the full existing
  suite passes unchanged — every Part A item is required to leave the default
  call bit-identical.
- `LEARNINGS.md` and `CHANGES.md` are updated per item, not per batch.
- Nothing in Part A or Part B changes visual output, so no `./tmp/` HTML
  render is required — except `plot()` on the new edge-level result in B4,
  which does need one.
