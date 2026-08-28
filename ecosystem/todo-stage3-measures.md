# Stage 3 — implementation TODOs: genuinely temporal measures, inter-event
# times, and temporal motifs

Target: `Dynet` 0.3.53. Written 2026-08-28. **Spec only — no package code was
written or changed.**

Everything asserted below about the current package was run in this session
against `devtools::load_all(".")` at 0.3.53. Everything asserted about `teneto`
was run against teneto 0.5.3 in system `python3`; everything asserted about
`raphtory` was run against raphtory 0.17.0. Reference numbers are pasted from
those runs, not recalled.

---

## What was checked first, and what turned out to be true

| Claim under test | Verdict |
|---|---|
| `metrics(dn, measure = "efficiency")` is not temporal | **True, and worse than stated.** It is *Krackhardt* efficiency (`.efficiency()` in `R/kernels-sna.R`, reached from `.graph_measure()` in `R/graph.R:441`), a tree-departure index. Dynet has no global (Latora–Marchiori) efficiency at all, temporal or static. Ran: `metrics(dynet(school_contacts), measure = "efficiency")` → 22 rows, `0.9796`, `1.0000`, … one per bin. |
| `metrics(dn, measure = "diameter")` is not temporal | **True.** `.graph_measure("diameter", …)` is `max()` of the finite off-diagonal static geodesics of that bin's adjacency (`R/graph.R:456`). Ran: values 2, 4, 4, 3, 6, 4 … one per bin. |
| topological overlap, fluctuability, volatility, SID absent | **True.** `.graph_measures` (`R/graph.R:5`) has 40 entries; none of them. `grep` over `R/` finds no `overlap`-as-node-persistence, no `fluctuab`, no `volatil`, no `\bsid\b`. |
| `similarity()` is a *different* quantity from topological overlap | **True, and the distinction is sharp** — see the box under item A2. |
| `burstiness(measure = "events")` returns counts, not gaps | **True.** Ran: `Ana 36`, `Ben 34`, `Cara 35`, `Dan 35`. The gaps exist only inside `.burst_primitives()` (`R/events.R:1454`) and are discarded. |
| `durations()` returns counts per pair, not gaps | **True.** Ran `durations(dn, measure = "events")` → `Ana Cara 1`, `Ana Dan 3`, `Ana Gita 5`, `Ana Iris 1`. |
| `pshifts()` is a dyadic P-shift census | **True.** `R/pshifts.R` classifies **consecutive ordered pairs of turns** into Gibson's fixed 13 labels via `.pshift_classify(previous, current)`; each turn is one uncensored raw-spell onset. It looks at exactly two events at a time and at most four distinct actors, with a group-target collapse rule. It is *not* a three-node motif census and cannot be extended into one by parameter change. |
| Anything here already exists | **No.** All seven items below are genuinely absent. |

Two further findings that change the specs and must not be lost:

1. **`.temporal_closeness_values()` (`R/centrality.R:1598`) uses `1 / mean(latency)`, not `mean(1 / latency)`.** So does teneto's `temporal_efficiency` (`1 / np.nanmean(pathmat)` — read from source). The published temporal-efficiency definition (Tang 2010, Nicosia 2013, following Latora–Marchiori) is the **mean of inverses**. These disagree numerically. On the fixture in A1 they are `0.8235` (teneto, 1/mean) versus `0.9087` (mean of 1/d). The spec picks mean-of-inverses and says so loudly.
2. **teneto 0.5.3's `volatility()` is broken on modern scipy.** It raises `AttributeError: module 'scipy.spatial.distance' has no attribute 'kulsinski'` (removed in scipy ≥ 1.11) from `teneto/utils/utils.py:518`. I obtained reference values by shimming `scipy.spatial.distance.kulsinski` before `import teneto`. The verification script must carry that shim or the reference run dies.

---

## Ordering

```
B1  gaps()                       — no dependency
A2  persistence()                — no dependency
A3  turnover()                   — no dependency
A1  metrics(temporal_efficiency, temporal_diameter)  — depends on paths() machinery (exists)
A4  dyn_centrality(scope="temporal", measure="efficiency")  — depends on A1
C1  motifs()                     — no dependency (reuses the pshifts() event-extraction shape)
A5  segregation()  [SID]         — depends on A3 only for its metadata idiom; blocked on
                                   user-supplied communities, lowest priority
```

---

# B1 — Return the inter-event time distribution

**Title.** Expose the inter-event gaps that `burstiness()` already computes, as a
tidy one-row-per-gap table.

**Why.** `.burst_primitives()` (`R/events.R:1454`) already builds the exact
inter-event gap vector per vertex, uses it for `B` and `M`, and then throws it
away; `burstiness(measure = "mean_gap")` returns only its mean. A user who wants
to plot the gap distribution, fit a power law to it, or test the Poisson null
cannot get at it. teneto exposes `intercontacttimes(tnet)` and dynetx exposes
`inter_event_time_distribution(G, u, v)`; Dynet exposes neither. This is the
cheapest real gap in the package because the numerator already exists.

**Proposed API.**

```r
gaps <- function(dn,
                 unit     = c("node", "pair"),
                 sessions = c("bounded", "collapse", "separate"),
                 censored = c("include", "exclude"))
```

```r
dn <- dynet(school_contacts)
gaps(dn)                                  # every inter-event gap, per vertex
gaps(dn, unit = "pair")                   # per ordered pair (per dyad if undirected)
summary(gaps(dn), by = "node")            # n, mean, sd, min, max per vertex
plot(gaps(dn))                            # the distribution over time
```

A new **verb**, not a `measure =` on `durations()` and not an argument. Three
reasons, in order of weight: (1) the row cardinality is different — `durations()`
is one row per pair per measure, this is one row per *gap*, and a verb whose row
meaning changes with an argument is a Rule 0 defect waiting to happen; (2) the
quantity is different — `durations()` measures how long a tie *was up*, this
measures how long a pair or vertex *was quiet*; (3) `durations()` already carries
five `unit` values and seven `measure` values and is at its complexity ceiling.

**Return.** A `dynet_metric`, `level = "node"` for `unit = "node"` and
`level = "edge"` for `unit = "pair"`, with **no aggregation** — one row per
consecutive pair of events.

| unit | columns, in `.metric()` front order |
|---|---|
| `"node"` | `session` (separate only), `time`, `node`, `index`, `measure`, `value` |
| `"pair"` | `session` (separate only), `time`, `from`, `to`, `index`, `measure`, `value` |

- `time` — the onset time of the **later** event of the pair, so the row plots at
  the moment the gap closed and `plot.dynet_metric()` works unmodified.
- `index` — integer, 1-based rank of the gap within that vertex's (or pair's)
  ordered event sequence, restarting at 1 in each session under `"bounded"` and
  `"separate"`. It is what makes the row addressable without the caller sorting.
- `measure` — the constant string `"gap"`.
- `value` — the gap, in the network's `time_unit`. Non-negative; **exactly zero
  is legitimate** (simultaneous distinct raw spells incident to the same vertex).
- Attributes, mirroring `burstiness()`: `event_identity = "incident_spell_start"`
  (node) or `"pair_spell_start"` (pair), `loop_contribution = "one_event"`,
  `weights = "ignored"`, `raw_censoring = "censored_onsets_excluded"`,
  `session_gaps` set from `sessions` exactly as `burstiness()` sets it.
- A vertex or pair with fewer than two usable events contributes **zero rows**,
  not an `NA` row. `nrow(gaps(dn))` therefore equals
  `sum(burstiness(dn, measure = "events")$value) - (number of vertices with >= 1 event)`
  under `sessions = "collapse"`; that identity is the invariant test.

**Algorithm.**

1. Reuse `.split_sessions()` and the eligibility mask from `burstiness()`
   verbatim: `eligible <- .time_in_observation(dn, raw_time) & !enc$raw_event_onset_censored`,
   and `event_time <- .observed_time(dn, raw_time)` when observations are declared.
2. For `unit = "node"`, the event set of vertex *v* is
   `which((enc$raw_from == v | enc$raw_to == v) & eligible)` — identical to
   `burstiness()`, so a loop contributes one event and direction is ignored.
   For `unit = "pair"`, key on `(enc$raw_from, enc$raw_to)` when directed and on
   `(pmin, pmax)` when undirected; loops are excluded, matching `durations()`.
3. Refactor `.burst_primitives()` to return the per-sequence gap vectors and the
   sorted event times **alongside** what it already returns, so `gaps()` and
   `burstiness()` compute the gaps once. Do not fork the computation — a second
   implementation is how the two verbs start disagreeing.
4. Sort each sequence with `order(event_time, seq_along(event_time))` — an
   explicit deterministic secondary key, because simultaneous events are real
   here and input order must not decide the answer.
5. Gaps are `diff(sorted_times)` **within** each session sequence under
   `"bounded"` and `"separate"`, and across the pooled calendar under
   `"collapse"`. This is the same wall rule `.burst_stats_sequences()` applies,
   and it is why the two verbs must share the primitive.

*Numerical pitfalls.* No division, no logarithm — the arithmetic is a `diff()`.
The pitfalls are elsewhere: (a) **do not** drop zero gaps, and do not silently
`na.rm` them; they are the signature of simultaneous events and dropping them
would silently inflate `mean_gap` relative to `burstiness()`'s own value.
(b) `diff()` on a length-0 or length-1 vector returns `numeric(0)` — correct
here, but the caller must `rbind` a zero-row frame with the right column types,
not `NULL`. (c) `1:n` is fatal in this function; use `seq_along()`.
(d) A calendar-time network's gaps are `difftime`-derived doubles; keep them
numeric in `value` and record the unit in the `time_unit` attribute, as every
other verb does.

**References.**
- Goh, K.-I., & Barabási, A.-L. (2008). Burstiness and memory in complex systems.
  *Europhysics Letters*, 81(4), 48002. \doi{10.1209/0295-5075/81/48002}
- Barabási, A.-L. (2005). The origin of bursts and heavy tails in human dynamics.
  *Nature*, 435, 207–211. \doi{10.1038/nature03459}
- Karsai, M., Kaski, K., Barabási, A.-L., & Kertész, J. (2012). Universal features
  of correlated bursty behaviour. *Scientific Reports*, 2, 397.
  \doi{10.1038/srep00397}
- Rocha, L. E. C., & Blondel, V. D. (2013). Bursts of vertex activation and
  epidemics in evolving networks. *PLoS Computational Biology*, 9(3), e1002974.
  \doi{10.1371/journal.pcbi.1002974}
- Holme, P., & Saramäki, J. (2012). Temporal networks. *Physics Reports*, 519(3),
  97–125. \doi{10.1016/j.physrep.2012.03.001}

**Verify against.** `teneto.networkmeasures.intercontacttimes` (teneto 0.5.3,
importable, **runs**) for `unit = "pair"`. Reference generated in this session on
the fixture of item A2 (undirected, 4 nodes, contacts
`(0,1,t=0) (1,2,t=0) (0,1,t=1) (2,3,t=1) (0,1,t=2) (1,2,t=2) (0,2,t=3)`):

```
ict[0,1] = [1 1]      ict[1,0] = [1 1]
ict[1,2] = [2]        ict[2,1] = [2]
```

Note teneto returns the *same* array for `(i,j)` and `(j,i)` on an undirected
network; Dynet's `unit = "pair"` must emit each unordered dyad **once**, so the
test compares against one triangle of teneto's matrix, not both.
`dynetx.classes.function.inter_event_time_distribution` is also importable and
returns a `{gap: count}` dictionary — use it as a second, independent check of
the *node-level* (`u` given, `v` omitted) case, which teneto does not offer.
No external reference exists for Dynet's session-wall and censoring policies:
those need a **hand-computed fixture**.

**Tests** (`tests/testthat/test-interevent-gaps-contract.R`).

```r
test_that("gaps refuses a mode argument it does not own", {
  dn <- dynet(school_contacts)
  expect_error(gaps(dn, unit = "session"), class = "dynet_bad_input")
})
test_that("gaps refuses separate without sessions", {
  dn <- dynet(school_contacts)
  expect_error(gaps(dn, sessions = "separate"), class = "dynet_no_sessions")
})
```

- **Error path, by class.** The two above. `dynet_no_sessions` comes free from
  `.check_dynet()`; the `unit` rejection must come from `match.arg()`, which
  raises a plain error — so wrap it as `dynet_bad_input` via `.check()` or accept
  `match.arg()`'s condition and assert on it explicitly rather than pretending it
  is classed.
- **Invariant 1 (row count).** For `sessions = "collapse"`,
  `nrow(gaps(dn))` equals `sum(events) - (vertices with at least one event)`,
  computed from `burstiness(dn, measure = "events")`. Property, not fixture.
- **Invariant 2 (consistency with burstiness).** `summary(gaps(dn), by = "node")$mean`
  equals `burstiness(dn, measure = "mean_gap")$value` to
  `sqrt(.Machine$double.eps)` for every vertex with ≥ 1 gap. This is the test
  that catches the two implementations drifting apart, and it is the reason for
  the shared-primitive refactor.
- **Invariant 3 (non-negativity and ordering).** `all(gaps(dn)$value >= 0)`, and
  within each `node` the `index` column is `seq_len(n)` with `time` non-decreasing.
- **Invariant 4 (session walls).** On a two-session fixture,
  `nrow(gaps(dn, sessions = "bounded")) < nrow(gaps(dn, sessions = "collapse"))`
  by exactly the number of vertices active in both sessions — the cross-wall gaps
  that `"bounded"` must not create.
- **Equivalence.** The teneto fixture above, `expect_equal(..., tolerance = 1e-12)`.
- **Snapshot.** `expect_snapshot(print(gaps(dn)))` and
  `expect_snapshot(print(summary(gaps(dn))))`.
- **Sanity.** Break `diff()` to `diff(sorted, lag = 2)` once and confirm
  Invariant 2 fails.

**Effort. S.** The gap vector already exists and is already correct; the work is
a shared-primitive refactor, a `data.frame` assembly, `@return` documentation of
the two column layouts, and the tests. No new mathematics, no new numerical risk.

**Depends on.** Nothing.

---

# A2 — `persistence()`: node-level topological overlap and the temporal correlation coefficient

**Title.** Add a `persistence()` verb reporting per-vertex topological overlap
between consecutive slices, its per-vertex mean, and the network-level temporal
correlation coefficient.

**Why.** Topological overlap answers "did *this vertex* keep the same neighbours
from one slice to the next", which is the standard temporal-network measure of
edge persistence (Tang 2010; Nicosia 2013) and the basis of the temporal
correlation coefficient. Dynet has nothing at this level: `similarity()` answers
a genuinely different question (below), and `events()` counts formations and
dissolutions network-wide without attributing them to vertices. It needs no
temporal paths — only slice comparison — so it is cheap.

> **`similarity()` is not topological overlap, and the two must not be conflated.**
> `similarity()` (`R/similarity.R`) builds one binary layer per bin, hands each
> **pair of layers** to `cograph::layer_similarity()`, and returns a full
> bin × bin matrix in long form: it is a **graph-level, all-pairs-of-times,
> edge-set** comparison. Topological overlap is a **node-level,
> consecutive-times-only, neighbourhood** comparison — the overlap of *vertex i's*
> neighbour set at `t` with *vertex i's* neighbour set at `t+1`, normalised by
> the geometric mean of its two degrees. Three concrete differences: (a) its
> output is indexed by `(node, time)`, not `(time, other)`; (b) it never compares
> non-adjacent bins; (c) a network in which every vertex swaps *all* its partners
> at each step but keeps its degree scores 0 on topological overlap while
> `similarity(method = "jaccard")` can be arbitrary. Additionally
> `cograph::layer_similarity(method = "hamming")` returns a **raw count over the
> full symmetric matrix** — verified this session: on two 4-vertex layers
> differing in two dyads it returns `4`, whereas teneto's Hamming volatility on
> the same layers is `2/6 = 0.3333` (upper triangle, proportion). Any code that
> reuses `similarity()` to build a persistence measure must divide by
> `2 * n_pairs` for an undirected network. Do not assume the scales agree.

**Proposed API.**

```r
persistence <- function(dn,
                        scope    = c("pertime", "node", "overall"),
                        sessions = c("bounded", "collapse", "separate"),
                        start = NULL, end = NULL, step = NULL, window = NULL)
```

```r
dn <- dynet(school_contacts)
persistence(dn)                                 # one row per vertex per transition
persistence(dn, scope = "node")                 # average topological overlap per vertex
persistence(dn, scope = "overall")              # temporal correlation coefficient
plot(persistence(dn), type = "heatmap")
```

One verb, one measure family, `scope` selecting the aggregation level — the same
shape as `dyn_centrality(scope = )`. Deliberately **not** a `measure =` on
`metrics()`: `metrics()` is graph-level by contract (`level = "graph"` is
hard-coded at `R/graph.R`), and two of the three scopes here are node-level.
The `"overall"` scope is graph-level and is the *only* place the temporal
correlation coefficient is exposed — it must not also appear in `metrics()`, or
there are two implementations to keep in step.

**Return.** A `dynet_metric`.

| scope | level | columns | one row per |
|---|---|---|---|
| `"pertime"` | `"node"` | `session`, `time`, `node`, `measure`, `value` | vertex × transition `t → t+1` |
| `"node"` | `"node"` | `session`, `node`, `measure`, `value` | vertex |
| `"overall"` | `"graph"` | `session`, `measure`, `value` | (session, or one row) |

- `measure` is `"topological_overlap"`, `"average_topological_overlap"`, and
  `"temporal_correlation"` respectively.
- `time` for `"pertime"` is the **earlier** bin of the transition. The final bin
  therefore produces no row (teneto returns `nan` there; Dynet drops the row,
  because a `dynet_metric` row whose value is structurally undefined is noise).
  State this in `@return`.
- `value` ∈ `[0, 1]` for all three scopes. Attributes:
  `overlap_normalisation = "geometric_mean_of_degrees"`,
  `empty_neighbourhood = "zero"`, `weights = "ignored"`, `loops = "excluded"`,
  `final_bin = "dropped"`.

**Algorithm.** Let `G[i,j,t]` be the binary, loop-free, undirected snapshot for
bin `t` — i.e. `.binary(.adjacency(...), directed)` symmetrised with
`pmax(m, t(m))` exactly as `similarity()` does, so a directed network is read as
a contact network for this measure (state that in `@details`; the published
definition is for undirected graphs).

1. **Per-time**, for vertex `i` and consecutive bins `t`, `t+1`:

   ```
   TopoOverlap[i,t] = sum_j G[i,j,t] * G[i,j,t+1]
                      / sqrt( sum_j G[i,j,t] * sum_j G[i,j,t+1] )
   ```

   i.e. `crossprod`-free: `num <- rowSums(Gt * Gt1)`,
   `den <- sqrt(rowSums(Gt) * rowSums(Gt1))`.
2. **Per node**: `AvgTopoOverlap[i] = mean over the T-1 transitions`.
3. **Overall**: `TempCorrCoeff = mean over vertices of AvgTopoOverlap[i]`.

*Numerical pitfalls.* (a) **The denominator is zero whenever a vertex is
isolated in either slice — this is the common case, not an edge case.** teneto
resolves `0/0` to `0` (verified: node 3 in the fixture below, isolated at `t=0`,
gets `0.0`, not `NaN`). Adopt that convention, implement it as an explicit
`ifelse(den > 0, num / den, 0)` — never `num/den` followed by `nan_to_num`, and
never a bare `na.rm = TRUE` downstream — and document it, because "0" here means
"no persistence", which is a *substantive* claim about an isolated vertex and a
reader deserves to know it was chosen rather than computed. (b) No log space is
needed; the products are of 0/1 entries and cannot underflow. (c) The `sqrt` of a
product of two integer row sums is exact in double for any realistic degree; do
not rewrite it as `exp(0.5*(log a + log b))`, which is *less* accurate here.
(d) Never compare `den == 0` on a double that came from a sum of doubles — the
row sums are integer-valued, but guard with `den > 0` rather than `!= 0` anyway.
(e) With fewer than two bins the whole measure is undefined: raise
`dynet_empty_result`, as `similarity()` already does for the same reason.

**References.**
- Tang, J., Scellato, S., Musolesi, M., Mascolo, C., & Latora, V. (2010).
  Small-world behavior in time-varying graphs. *Physical Review E*, 81(5),
  055101(R). \doi{10.1103/PhysRevE.81.055101}
- Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora, V.
  (2013). Graph metrics for temporal networks. In P. Holme & J. Saramäki (Eds.),
  *Temporal Networks* (pp. 15–40). Springer.
  \doi{10.1007/978-3-642-36461-7_2}
- Clauset, A., & Eagle, N. (2007). Persistence and periodicity in a dynamic
  proximity network. *DIMACS Workshop on Computational Methods for Dynamic
  Interaction Networks*.
- Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to temporal
  network theory: applications to functional brain connectivity.
  *Network Neuroscience*, 1(2), 69–99. \doi{10.1162/NETN_a_00011}

**Verify against.** `teneto.networkmeasures.topological_overlap` (teneto 0.5.3,
**runs unpatched**). Reference values generated in this session, undirected,
4 nodes `A B C D` = `0 1 2 3`, contacts
`(0,1,t=0) (1,2,t=0) (0,1,t=1) (2,3,t=1) (0,1,t=2) (1,2,t=2) (0,2,t=3)`:

```
calc='pertime'   (node x time)
[[1.         1.         0.         nan]
 [0.70710678 0.70710678 0.         nan]
 [0.         0.         0.         nan]
 [0.         0.         0.         nan]]
calc='node'      [0.66666667 0.47140452 0.         0.        ]
calc='overtime'  0.2845177968644246
```

Hand-checked in this session and reproduced independently: node 0 has
neighbourhood `{1}` at `t=0` and `{1}` at `t=1`, so `1/sqrt(1*1) = 1`; node 1 has
`{0,2}` then `{0}`, so `1/sqrt(2*1) = 0.7071`; node 3 has `{}` then `{2}`, so
`0/0 → 0`. The node means are over `T-1 = 3` transitions and the overtime value
is their mean over 4 vertices — arithmetic confirmed by hand.

**Grid warning for whoever writes the test.** Building that fixture with
`dynet(d, format = "contact", directed = FALSE)` and calling a measure with the
default grid gives **three** bins, not four — verified this session:
`metrics(dn, measure = "edges")` returns `2, 2, 3`, because the default last bin
is closed and absorbs the `t=3` contact. The four teneto slices are recovered
with `start = 0, end = 3, window = 0`, which gives `2, 2, 2, 1` — the correct
per-slice edge counts. **Every equivalence test in items A2, A3 and A5 must pass
`start = 0, end = 3, window = 0` explicitly**, or it will compare a 3-bin Dynet
result against a 4-slice teneto result and the mismatch will be blamed on the
formula.

**Tests** (`tests/testthat/test-persistence-contract.R`).

- **Error path, by class.** `expect_error(persistence(dynet(data.frame(from="A", to="B", time=1), format="contact")), class = "dynet_empty_result")` — a single bin has no transition.
  Second: `expect_error(persistence(dn, sessions = "separate"), class = "dynet_no_sessions")`.
- **Invariant 1 (range).** `all(persistence(dn, scope = s)$value >= 0 & <= 1)` for all three scopes.
- **Invariant 2 (aggregation consistency).** `persistence(dn, scope = "node")$value`
  equals the per-vertex mean of `persistence(dn, scope = "pertime")$value`, and
  `persistence(dn, scope = "overall")$value` equals the mean of the `"node"`
  values, to `sqrt(.Machine$double.eps)`. This is the test that keeps the three
  scopes one computation.
- **Invariant 3 (frozen network).** On a network whose every edge is present in
  every bin, every non-isolated vertex scores exactly `1` at every transition and
  `temporal_correlation` equals the share of non-isolated vertices. Property test,
  generated for `n = 3..8`.
- **Invariant 4 (permutation).** Renaming vertices with `rename_nodes()` permutes
  the result rows and leaves the values attached to the same names — catches any
  place an index leaked out.
- **Equivalence.** The teneto fixture, all three scopes, `tolerance = 1e-12`,
  guarded by `skip_on_cran()` and a stored fixture file (do not shell out to
  python in the test).
- **Snapshot.** `expect_snapshot(print(persistence(dn)))`.

**Effort. M.** The formula is three lines of vectorised base R and the reference
is exact and runs. The work is the `scope` plumbing across three different
`level`/column layouts, the drop-the-final-bin decision, the `0/0` convention and
its documentation, and reusing `similarity()`'s layer construction without
duplicating it.

**Depends on.** Nothing.

---

# A3 — `turnover()`: volatility and fluctuability

**Title.** Add a `turnover()` verb giving Hamming volatility between consecutive
slices and the fluctuability of the whole observed series.

**Why.** Volatility ("how much did the network change from one slice to the
next") and fluctuability ("were the edge events spread over many distinct pairs
or concentrated on a few") are the two standard teneto whole-network dynamics
summaries, and Dynet has neither. `events()` counts formations and dissolutions
but does not normalise them, and — verified this session — cannot be used to
recover volatility on a contact network, because a point contact registers as
both a formation and a dissolution in the same bin (`events(dn)` on the item-A2
fixture returns `formation 2, dissolution 2` at `t = 0`). Neither measure needs
temporal paths; both are pure slice comparison.

**Proposed API.**

```r
turnover <- function(dn,
                     measure  = c("volatility", "fluctuability"),
                     scope    = c("pertime", "overall"),
                     sessions = c("bounded", "collapse", "separate"),
                     start = NULL, end = NULL, step = NULL, window = NULL)
```

```r
dn <- dynet(school_contacts)
turnover(dn, measure = "volatility")                        # one row per transition
turnover(dn, measure = "volatility", scope = "overall")     # the mean, one row
turnover(dn, measure = "fluctuability", scope = "overall")  # one row
plot(turnover(dn, measure = "volatility"))
```

`"fluctuability"` is defined **only** at `scope = "overall"`; requesting it at
`"pertime"` raises a classed error rather than returning a column of `1`s (a
single slice trivially has every edge distinct, so the per-time value is a
constant and would be a lie dressed as data).

**Return.** A `dynet_metric`, `level = "graph"`.

| scope | columns | one row per |
|---|---|---|
| `"pertime"` | `session`, `time`, `measure`, `value` | transition `t → t+1` (× measure) |
| `"overall"` | `session`, `measure`, `value` | measure (× session under `"separate"`) |

- `time` is the **earlier** bin, matching `persistence()`. The final bin produces
  no volatility row.
- `volatility` ∈ `[0, 1]`. `fluctuability` ∈ `(0, 1]`.
- Attributes: `distance = "hamming_proportion"`,
  `opportunity_domain` copied from the `metrics()` vocabulary
  (`"eligible_nonloop_unordered_dyads"` / `"..._ordered_pairs"`),
  `weights = "ignored"`, `loops = "excluded"`, `final_bin = "dropped"`.

**Algorithm.** With `G[,,t]` the binary loop-free snapshot for bin `t` and `P`
the number of eligible non-loop pairs (`n(n-1)/2` undirected, `n(n-1)` directed):

1. **Volatility per time.**
   `V[t] = ( number of pairs with G[.,.,t] != G[.,.,t+1] ) / P`
   — the *proportion* Hamming distance over the pair domain (scipy's `hamming`,
   which is what teneto calls). For an undirected network the domain is the
   strict upper triangle.
2. **Volatility overall.** `mean(V[t])` over the `T-1` transitions.
   Do **not** compute it as a separate pass; compute `V[t]` once and mean it, so
   the two scopes cannot disagree.
3. **Fluctuability.**
   `F = ( number of distinct pairs active in at least one bin ) / ( sum over t of the number of active pairs in bin t )`
   — teneto's `H` over `sum G`. Numerator is `sum(apply(G, c(1,2), any))` on the
   pair domain; denominator is `sum(metrics(dn, measure = "edges")$value)` over
   the same grid.

*Numerical pitfalls.* (a) **Guard the fluctuability denominator.** An empty grid
(no active pair in any bin) gives `0/0`; return `NA_real_` with a documented
`empty_series = "NA"` attribute, never `NaN` propagated or a silent `0`. (b)
`P == 0` (a one-vertex network) makes volatility `0/0`; raise
`dynet_empty_result` rather than dividing. (c) Fluctuability's denominator is a
**sum of per-bin counts and is therefore grid-dependent** — halving `step`
roughly doubles it and roughly halves `F`. This is a property of the published
definition, not a bug, and it must be stated in `@details` with a sentence
telling the reader that `F` is comparable only across networks measured on the
same grid. teneto's own docstring concedes `F` "is not normalized which makes
comparisons of F across very different networks difficult". (d) Counting with
`tabulate()` on an integer pair key beats `table()` and beats a 3-d array on any
network with more than a few hundred vertices; the `T × n × n` dense array is the
memory ceiling here and should not be materialised — accumulate per bin.
(e) No `==` on doubles: the snapshots are 0/1 integers, compare with `!=` on
integers after `storage.mode(m) <- "integer"`.

**References.**
- Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to temporal
  network theory: applications to functional brain connectivity.
  *Network Neuroscience*, 1(2), 69–99. \doi{10.1162/NETN_a_00011}
  *(the paper that defines both fluctuability and volatility; teneto is its
  reference implementation)*
- Holme, P., & Saramäki, J. (2012). Temporal networks. *Physics Reports*, 519(3),
  97–125. \doi{10.1016/j.physrep.2012.03.001}
- Nicosia, V., et al. (2013). Graph metrics for temporal networks. In
  *Temporal Networks*, Springer. \doi{10.1007/978-3-642-36461-7_2}

**Verify against.** `teneto.networkmeasures.fluctuability` (**runs unpatched**)
and `teneto.networkmeasures.volatility` (**does not run on this machine without a
shim** — see the note at the top; `scipy.spatial.distance.kulsinski` was removed
in scipy ≥ 1.11 and teneto 0.5.3 dereferences it eagerly at
`teneto/utils/utils.py:518`). With the shim applied, reference values on the
item-A2 fixture, generated this session:

```
fluctuability                       0.5714285714285714     (= 4 distinct pairs / 7 edge events)
volatility calc='overtime'  hamming 0.38888888888888884
volatility calc='pertime'   hamming [0.3333333333333333, 0.3333333333333333, 0.5]
```

Hand-checked this session: slices are `{01,12}`, `{01,23}`, `{01,12}`, `{02}`;
the pair domain has `choose(4,2) = 6` entries; the symmetric differences are of
size 2, 2 and 3, giving `2/6, 2/6, 3/6` and a mean of `0.38889`. Fluctuability's
distinct pairs are `{01,12,23,02}` = 4 over 7 events = `0.571428…`.

Because the reference cannot be run cleanly, **store the four numbers as a
fixture in `tests/testthat/fixtures/` with a comment recording the shim**, and
note in `LEARNINGS.md` that teneto's volatility is unrunnable on scipy ≥ 1.11.
The session-wall and censoring policies have no external reference and need a
**hand-computed fixture** either way.

**Tests** (`tests/testthat/test-turnover-contract.R`).

- **Error path, by class.**
  `expect_error(turnover(dn, measure = "fluctuability", scope = "pertime"), class = "dynet_incompatible_scope")` —
  a new condition class, raised from an explicit guard, not from `match.arg()`.
  Second: `expect_error(turnover(single_bin_dn), class = "dynet_empty_result")`.
- **Invariant 1 (range).** `volatility` ∈ `[0,1]`, `fluctuability` ∈ `(0,1]`.
- **Invariant 2 (identity of a frozen network).** A network with identical edges
  in every bin has `volatility == 0` at every transition and
  `fluctuability == 1/T`. Property test over `T = 2..6`.
- **Invariant 3 (aggregation consistency).**
  `turnover(scope = "overall", measure = "volatility")$value` equals
  `mean(turnover(scope = "pertime", measure = "volatility")$value)` exactly.
- **Invariant 4 (scale independence).** Multiplying every timestamp by a constant
  and scaling `step` by the same constant leaves both values unchanged —
  volatility and fluctuability are dimensionless.
- **Invariant 5 (cross-check against `similarity()`).** For an undirected
  network, `volatility[t]` equals
  `similarity(method = "hamming")` at `(t, t+1)` divided by `2 * choose(n, 2)`.
  Because this reaches into `similarity()`'s off-diagonal, it is a **test-only**
  computation, written inside the test body where brackets are legal — it is not
  something a user should ever have to do, which is precisely why `turnover()`
  exists.
- **Equivalence.** The stored teneto fixture, `tolerance = 1e-12`, with
  `start = 0, end = 3, window = 0` on the Dynet side (see the grid warning in A2).
- **Snapshot.** `expect_snapshot(print(turnover(dn)))`.
- **Sanity.** Change the volatility denominator from `P` to `n^2` once and confirm
  the equivalence test and Invariant 5 both fail.

**Effort. M.** Straightforward arithmetic and a runnable-ish reference; the cost
is the `pertime`/`overall` plumbing, the fluctuability-scope rejection, the
`NA` policy on an empty series, and getting the pair domain (upper triangle
versus full matrix) right in both the directed and undirected case — the exact
place where the cograph-Hamming scale mismatch will bite anyone who copies from
`similarity()`.

**Depends on.** Nothing.

---

# A1 — Temporal efficiency and temporal diameter as `metrics()` measures

**Title.** Add `"temporal_efficiency"` and `"temporal_diameter"` to `metrics()`,
computed from all-pairs time-respecting paths inside each reporting window.

**Why.** `metrics(dn, measure = "efficiency")` returns *Krackhardt* efficiency and
`metrics(dn, measure = "diameter")` returns the static geodesic diameter of each
bin — both verified this session. Neither says anything about whether information
can actually traverse the network in time, which is the one question a temporal
network exists to answer. Both quantities have published definitions and both are
in ECOSYSTEM.md's "10 of 59 measures are genuinely temporal" indictment.

**These two need temporal paths.** They are the only items in this document that
depend on `paths()`; A2, A3, A5 and B1 are pure slice comparison and C1 is pure
event enumeration.

**Proposed API.** Extend the existing verb — no new function.

```r
metrics(dn, measure = "temporal_efficiency", basis = c("hops", "latency"),
        traversal_time = 0, ...)
metrics(dn, measure = "temporal_diameter",   basis = c("hops", "latency"),
        traversal_time = 0, ...)
```

```r
dn <- dynet(school_contacts)
metrics(dn, measure = "temporal_efficiency", window = "all")
metrics(dn, measure = c("temporal_efficiency", "temporal_diameter"), window = "all")
metrics(dn, measure = "temporal_efficiency", basis = "latency", traversal_time = 1)
```

`basis` and `traversal_time` join the existing signature and are rejected with
`dynet_bad_input` when no path-based measure is requested — the same pattern
`durations()` already uses to reject `mode` for the wrong `unit`, and
`dyn_centrality()` already uses to reject `traversal_time` at snapshot scope.

Each row is one reporting window, and the temporal search runs **within** that
window: `start = bin_start`, `end = bin_end`. `window = "all"` therefore gives the
one whole-network number a reader usually wants, and the default grid gives the
time series. This is the only design that keeps `metrics()`'s "one row per time
point and measure" contract intact.

**Return.** Unchanged: a `dynet_metric` at `level = "graph"`, columns `session`,
`time`, `measure`, `value`. New attributes `basis`, `traversal_time`,
`unreachable_rule = "excluded_from_mean"`, `temporal_connected` (logical, whether
every ordered pair was reachable inside the window).

**Algorithm.** For each reporting window `[a, b]` and each source `s`:

1. Run the existing `.optimal_path_search(enc, s, a, upper = b)`. Verified this
   session that it returns `arrival`, `n_hops`, `attained`, `n_paths` and
   `origin` — everything needed. Do **not** call the public `paths()` in a loop;
   it re-encodes the network each time.
2. Temporal distance for the ordered pair `(s, j)`, `j != s`:
   - `basis = "hops"` → `d[s,j] = n_hops[j]`, `Inf` when `!is.finite(arrival[j])`.
   - `basis = "latency"` → `d[s,j] = arrival[j] - origin`, `Inf` when unreachable.
3. **Temporal efficiency** (Latora–Marchiori lifted to temporal distance, as in
   Tang 2010 eq. 3 and Nicosia 2013 §2.3):

   ```
   E = 1/(N (N-1)) * sum over ordered pairs s != j of 1 / d[s,j]
   ```

   with the convention `1/Inf = 0`, so unreachable pairs contribute zero and `E`
   is defined for a disconnected network. `E` ∈ `[0, 1]` for `basis = "hops"`.
4. **Temporal diameter** (Bui-Xuan 2003; Whitbeck 2012):

   ```
   D = max over ordered pairs s != j, over the finite d[s,j], of d[s,j]
   ```

   `NA_real_` when no ordered pair is reachable. Record
   `temporal_connected = all(is.finite(d))` as an attribute, because a diameter
   reported without saying whether the network was temporally connected is the
   classic misleading number: `D` is the diameter *of the reachable part*.

*Numerical pitfalls, and the one that decides `basis`'s default.*

- **`basis = "latency"` divides by a latency that is legitimately zero.** At the
  default `traversal_time = 0` Dynet permits non-decreasing hop times, so a
  multi-hop journey completed within one instant has `latency == 0` and
  `1/0 = Inf`. Do not silently drop those pairs and do not clamp them. Emit
  `warningCondition("... zero-latency reachable pairs make temporal efficiency
  infinite; set a positive traversal_time or use basis = \"hops\"",
  class = "dynet_zero_latency")` and return `Inf`. `Inf` is the honest limit —
  instantaneous reach — and suppressing it would be exactly the silent failure
  the house rules forbid. Note that `.temporal_closeness_values()`
  (`R/centrality.R:1607`) has the same exposure today via `1/mean(latency)` and
  is not guarded; fixing that is in scope for this item.
- **Therefore `basis = "hops"` is the default.** Hop count between distinct
  vertices is ≥ 1, so the reciprocal is always in `(0, 1]` and the measure is
  always finite. It is also the convention the discrete-slice literature uses.
- **Do not use `1 / mean(d)`.** teneto does (`1 / np.nanmean(pathmat)`, read from
  source this session) and so does Dynet's existing temporal closeness. The
  published temporal efficiency is `mean(1 / d)`. They differ: on the fixture
  below, `0.8235` versus `0.9087`. Document the divergence in `@details`, cite
  it, and do not "fix" the reference by matching teneto.
- Guard `N < 2`: return `NA_real_` for both, not `0/0`.
- No log space needed. `sum(1/d)` over at most `N(N-1)` terms each in `(0,1]`
  cannot overflow or lose precision meaningfully.
- **Cost.** Measured this session: 14 sources × one anchor on `school_contacts`
  takes **2.44 s elapsed** through the public `paths()`. The default 22-bin grid
  would be ≈ 54 s. The internal search will be faster, but this is still `L`
  territory: document the cost in `@details`, recommend `window = "all"`, and
  consider a `message()` when `n_windows * n_nodes` exceeds a few thousand.

**References.**
- Latora, V., & Marchiori, M. (2001). Efficient behavior of small-world networks.
  *Physical Review Letters*, 87(19), 198701. \doi{10.1103/PhysRevLett.87.198701}
- Tang, J., Scellato, S., Musolesi, M., Mascolo, C., & Latora, V. (2010).
  Small-world behavior in time-varying graphs. *Physical Review E*, 81(5),
  055101(R). \doi{10.1103/PhysRevE.81.055101}
- Nicosia, V., et al. (2013). Graph metrics for temporal networks. In
  *Temporal Networks*, Springer. \doi{10.1007/978-3-642-36461-7_2}
- Bui-Xuan, B.-M., Ferreira, A., & Jarry, A. (2003). Computing shortest, fastest,
  and foremost journeys in dynamic networks. *International Journal of
  Foundations of Computer Science*, 14(2), 267–285.
  \doi{10.1142/S0129054103001728}
- Whitbeck, J., Dias de Amorim, M., Conan, V., & Guillaume, J.-L. (2012).
  Temporal reachability graphs. *MobiCom '12*, 377–388.
  \doi{10.1145/2348543.2348589}
- Kempe, D., Kleinberg, J., & Kumar, A. (2002). Connectivity and inference
  problems for temporal networks. *JCSS*, 64(4), 820–842.
  \doi{10.1006/jcss.2002.1829}

**Verify against.** `teneto.networkmeasures.temporal_efficiency` and
`teneto.networkmeasures.shortest_temporal_path` — **directionally only**, and the
spec must say so in a comment above the test. Three conventions differ and none
of them can be reconciled by an argument:

1. teneto's temporal distance is **≥ 1 per hop** (a same-slice hop costs one time
   step); Dynet's latency at `traversal_time = 0` can be `0`.
2. teneto computes `1/mean(d)`; the published measure is `mean(1/d)`.
3. teneto 0.5.3's `shortest_temporal_path` reports a `path includes` column that
   is **demonstrably inconsistent** with its own `t_start` — on the fixture below,
   row 8 claims `from 0, to 3, t_start 0, temporal-distance 1.0` via
   `[[0,2],[2,3]]`, but edge `0–2` does not exist until `t=3`. Treat its distances
   as a smell test, not an oracle.

Reference run, this session, same fixture as A2 (undirected, 4 nodes):

```
teneto temporal_efficiency (1/mean d)        0.823529411764706
mean(1/d) over the same finite entries       0.9087301587301587
max finite temporal distance                 3.0
finite entries / nan entries                 42 / 22
```

**A hand-computed fixture is required** for the actual equivalence test.
Recommended: the 4-node directed chain `A->B [0,1], B->C [1,2], C->D [2,3]`.
**Its distances were confirmed by running `paths()` on it this session** — from
`A`: `n_hops` 1, 2, 3 to `B`, `C`, `D`; from `B`: 1, 2 to `C`, `D`; from `C`: 1
to `D`; every backward pair `reachable = FALSE`. So
`E = (1/1+1/2+1/3+1/1+1/2+1/1) / (4*3) = 4.33333…/12 = 0.361111…` and `D = 3`,
both hand-computable and stable under refactoring.

That same run is the **direct evidence for the zero-latency pitfall above**:
`paths(dn, from = "A")` reports `arrival_time = 0` for `B` — a real hop with a
latency of exactly zero — so `basis = "latency"` on this fixture divides by zero
today. It is not a hypothetical.

**Tests** (`tests/testthat/test-temporal-efficiency-contract.R`).

- **Error path, by class.**
  `expect_error(metrics(dn, measure = "density", basis = "hops"), class = "dynet_bad_input")` —
  `basis` supplied without a path measure.
  Second: `expect_error(metrics(dn, measure = "temporal_efficiency", traversal_time = -1), class = "dynet_bad_input")`.
- **Warning path, by class.**
  `expect_warning(metrics(dn, measure = "temporal_efficiency", basis = "latency", traversal_time = 0), class = "dynet_zero_latency")`
  on a fixture with a same-instant two-hop chain, and assert the returned value is
  `Inf` — the condition and the value are both part of the contract.
- **Calibration.** The hand-computed chain above: `expect_equal(value, 4.3333333333333333/12)` and `expect_equal(diameter, 3)`.
- **Invariant 1 (monotone in reachability).** Adding an edge to a temporal
  network never decreases `temporal_efficiency` and never increases
  `temporal_diameter` (with `basis = "hops"`). Property test over random
  fixtures with a fixed seed, `RNGkind("L'Ecuyer-CMRG")`.
- **Invariant 2 (bounds).** `basis = "hops"` gives `E ∈ [0,1]`; `E == 1` exactly
  when every ordered pair is reachable in one hop; `E == 0` exactly when nothing
  is reachable.
- **Invariant 3 (relabelling).** Renaming vertices does not change either value.
- **Invariant 4 (agreement with `dyn_reachability()`).** `E > 0` if and only if
  `sum(dyn_reachability(dn, direction = "forward", measure = "reach_count")$value) > 0`
  over the same window — the two verbs must agree about what is reachable.
- **Invariant 5 (`temporal_connected` honesty).** On a fixture where `D` cannot
  see part of the network, `attr(result, "temporal_connected")` is `FALSE`.
- **Snapshot.** `expect_snapshot(print(metrics(dn, measure = "temporal_efficiency", window = "all")))`.
- **Sanity.** Replace `mean(1/d)` with `1/mean(d)` once and confirm the
  calibration test fails (it will: `0.3611` vs `1/1.8333 = 0.5455`).

**Effort. L.** Not because the formula is hard — it is four lines — but because
it is `N` searches per reporting window with a measured 2.44 s for one window of
a 14-vertex network, which forces a cost story, an internal-search path that
bypasses `paths()`, a `window = "all"` recommendation in the docs and examples,
and possibly a progress `message()`. Plus the `basis`/`traversal_time` argument
plumbing into a verb that currently takes neither, the zero-latency warning
class, and fixing the same exposure in `.temporal_closeness_values()`.

**Depends on.** Nothing new — `paths()` and `.optimal_path_search()` already
exist and were confirmed working this session.

---

# A4 — Node-level temporal efficiency in `dyn_centrality()`

**Title.** Add `"efficiency"` to `dyn_centrality(scope = "temporal")`.

**Why.** Once A1 computes the full temporal distance matrix per window, the
per-vertex row and column means are free, and they are the natural companion to
the temporal closeness Dynet already ships. teneto exposes exactly this as
`temporal_efficiency(calc = 'node_from')` and `calc = 'node_to'`. It also gives
Dynet a per-vertex measure that, unlike its temporal closeness, is defined when
some targets are unreachable.

**Proposed API.** Extend `.temporal_measures` (`R/centrality.R:17`) from
`c("closeness", "betweenness", "reach", "reach_count")` to include `"efficiency"`.

```r
dyn_centrality(dn, measure = "efficiency", scope = "temporal")
dyn_centrality(dn, measure = "efficiency", scope = "temporal", direction = "in")
dyn_centrality(dn, measure = c("closeness", "efficiency"), scope = "temporal")
```

`direction = c("out", "in")` selects `node_from` (mean over targets `j` of
`1/d[i,j]`) versus `node_to` (mean over sources of `1/d[j,i]`). Reuse
`dyn_centrality()`'s existing rejection of `mode` at temporal scope — do not add
a second direction argument with a different name; if `mode` cannot be reused,
that is an argument for renaming, not for a parallel vocabulary.

**Return.** Unchanged shape: a `dynet_metric` at `level = "node"`, columns
`session`, `node`, `measure`, `value`, one row per vertex, `measure` being
`"efficiency"`. Value ∈ `[0,1]` with `basis = "hops"`.

**Algorithm.** Add an `efficiency` branch to `.temporal_measure()`
(`R/centrality.R:1493`), fed by the same `trees` list every other temporal
measure uses:

```
eff_out[i] = (1/(N-1)) * sum over j != i of 1 / d[i,j]      # 1/Inf = 0
```

Reuse A1's `d` construction so there is one definition of temporal distance in
the package.

*Numerical pitfalls.* Identical to A1 and inherited from it: `1/0 = Inf` at
`basis = "latency"` with `traversal_time = 0`; `N < 2` gives `NA_real_`, not
`0/0`. One new one: the mean is over `N-1` targets **including unreachable ones**
(they contribute 0), which is what makes efficiency well-defined on a
disconnected network and what distinguishes it from the existing
`.temporal_closeness_values()`, which averages latency over reachable targets
only. Say so in `@details`, because a reader will otherwise expect
`efficiency == 1/closeness` and it does not hold.

**References.** Same as A1, plus:
- Marchiori, M., & Latora, V. (2000). Harmony in the small-world.
  *Physica A*, 285(3–4), 539–546. \doi{10.1016/S0378-4371(00)00311-3}
  *(harmonic centrality, the node-level ancestor of this quantity)*

**Verify against.** `teneto.networkmeasures.temporal_efficiency(calc='node_from')`
and `calc='node_to'` — with the same three convention caveats as A1, so
directional only. The **hand-computed fixture** is the same 4-node directed
chain: `eff_out(A) = (1/1 + 1/2 + 1/3)/3 = 0.611111…`,
`eff_out(B) = (0 + 1/1 + 1/2)/3 = 0.5`, `eff_out(C) = (0 + 0 + 1/1)/3 = 0.333333…`,
`eff_out(D) = 0`.

**Tests** (added to `tests/testthat/test-temporal-efficiency-contract.R`).

- **Error path, by class.**
  `expect_error(dyn_centrality(dn, measure = "efficiency", scope = "snapshot"), class = "dynet_unknown_measure")` —
  efficiency is temporal-scope only, and `.temporal_measures` versus
  `.node_measures` already enforces exactly this.
- **Calibration.** The four hand-computed chain values above.
- **Invariant 1 (aggregation).** `mean(dyn_centrality(dn, measure = "efficiency", scope = "temporal")$value)`
  equals `metrics(dn, measure = "temporal_efficiency", window = "all")$value` to
  `sqrt(.Machine$double.eps)`. The single most valuable test here — it is what
  guarantees A1 and A4 share one distance matrix.
- **Invariant 2 (bounds and direction).** All values ∈ `[0,1]`; on a directed
  chain, `"out"` efficiency is non-increasing along the chain and `"in"` is
  non-decreasing.
- **Invariant 3 (relation to reach).** `efficiency == 0` exactly where
  `dyn_reachability(measure = "reach_count") == 0`.
- **Snapshot.** `expect_snapshot(print(dyn_centrality(dn, measure = "efficiency", scope = "temporal")))`.

**Effort. S**, *conditional on A1 landing first*. It is one `switch()` branch, one
entry in `.temporal_measures`, one `@param` sentence and the tests. **L if
attempted alone**, because it would have to build the distance matrix itself.

**Depends on.** **A1.** Do not start this first.

---

# C1 — `motifs()`: a δ-temporal three-node motif census

**Title.** Add a `motifs()` verb counting Paranjape δ-temporal three-edge,
up-to-three-node motifs, globally and per vertex.

**Why.** `pshifts()` is a **dyadic** census: `.pshift_classify(previous, current)`
looks at exactly two consecutive turns and assigns one of Gibson's 13 labels
(confirmed by reading `R/pshifts.R` in full this session). It cannot see a
three-edge pattern and cannot be parameterised into one. Temporal motifs are the
standard way to characterise local temporal structure, they are absent from every
R package (ECOSYSTEM.md gap 3), and three separate Python/C++ libraries implement
them — so the definition is settled enough to copy rather than invent.

**The definition adopted, and why — this is the part that must be argued.**

Three incompatible families exist in the literature. Dynet adopts **Paranjape,
Benson & Leskovec (2017)**, as implemented by raphtory 0.17.0 and DyNetworkX:

| Choice | Dynet's rule | Why, and what was rejected |
|---|---|---|
| **Motif size** | Exactly **3 edges**, on **at most 3 distinct nodes** | Paranjape's `(3,3)` family. Kovanen (2011) instead allows arbitrary size with *consecutive-adjacent* events; that family is elegant but its instance count is unbounded and its "Δt-adjacency" is a different notion of nearby. Fixing `k = 3` gives a fixed 40-column census that prints as a tidy table, which Kovanen's does not. |
| **δ window** | `t_last - t_first <= delta`, where `t` are the three edge times **in sorted order**. `delta` is required, has no default, and is in the network's `time_unit`. | This is Paranjape's definition and raphtory's, and it was **confirmed empirically this session**: on `A->B@1, B->C@2, A->C@3`, `delta = 10` returns one triangle motif and `delta = 1` returns nothing (`3 - 1 = 2 > 1`). Kovanen instead bounds *consecutive* gaps (`t_{i+1} - t_i <= delta`), which is strictly weaker; the two agree only for `k = 2`. Requiring `delta` rather than defaulting it is deliberate: there is no principled default, and a silent default would make every reported count an artefact of a number the user never chose. Point at `gaps()` (item B1) in `@seealso` as the way to choose one. |
| **Edge distinctness** | The three edges are three **distinct events**. The same *pair* may repeat — that is exactly what the two-node motifs and the PRE/POST star classes are. Loops are excluded. | Verified this session: `A->B@1, A->B@2, A->B@3` at `delta = 10` returns two-node motif counts at global indices 24 and 31, one each. Requiring distinct *pairs* would delete 16 of the 40 classes. |
| **Overlapping instances** | **All** qualifying ordered triples are counted; instances may share edges. | Paranjape's definition and raphtory's. Verified: `A->B@1, B->C@2, A->C@3, A->B@4` at `delta = 10` returns four distinct motif instances (indices 10, 15, 33, 34) from four edges — `choose(4,3) = 4` windows, all qualifying. Edge-disjoint counting is a different (harder, NP-flavoured) problem and is not what any reference implements. |
| **Isomorphism classes** | **40**, in raphtory's order: indices 1–24 stars (PRE, MID, POST × 8 direction words), 25–32 two-node, 33–40 triangles. Direction words are `III, IIO, IOI, IOO, OII, OIO, OOI, OOO` read from the centre/first node, `I` = 0, `O` = 1. | Copying raphtory's ordering verbatim is the single decision that makes the whole thing verifiable — a user can `expect_equal()` against a raphtory run. Inventing a Dynet ordering would make every count unfalsifiable. |
| **Direction** | **Directed networks only.** An undirected network raises `dynet_needs_directed`, exactly as `pshifts()` does. | The 40-class taxonomy is defined by edge directions; there is no honest undirected projection of it. Reading each undirected contact in its stored orientation would produce numbers that look like motif counts and are not. |
| **Event identity** | One **uncensored, observed raw-spell onset** = one edge event. Intervals contribute their onset only; termini, durations, weights and vertex censor flags are ignored. | Identical to `pshifts()` (`event_identity = "uncensored_observed_raw_spell_start"`), so the two censuses count the same events and can be cross-tabulated. Any other choice would make `motifs()` and `pshifts()` silently disagree about what happened. |
| **Simultaneous events** | Ordered by the deterministic key `(time, from, to, raw_spell_index)`. **This is Dynet's choice, not the paper's** — Paranjape assumes distinct timestamps — and `@details` must say so. | Determinism is non-negotiable (house rule); leaving it to input order would make the census depend on row shuffling. Record it as `tie_rule = "time_from_to_raw_spell"`, matching `pshifts()`'s `tie_rule`. |
| **Session and observation walls** | Motifs may not straddle an observation gap or, under `sessions = "bounded"`, a session boundary. | Same walls `pshifts()` applies (`observation_walls = "components_and_gaps"`). |

**Proposed API.**

```r
motifs <- function(dn, delta,
                   output   = c("global", "local"),
                   sessions = c("bounded", "collapse", "separate"),
                   start = NULL, end = NULL)
```

```r
dn <- dynet(school_contacts)
motifs(dn, delta = 2)                        # 40 rows: the global census
motifs(dn, delta = 2, output = "local")      # 40 rows per vertex
summary(motifs(dn, delta = 2), by = "measure")
```

Deliberately mirrors `pshifts()` (`output = c("final", "cumulative")` there;
`c("global", "local")` here) so the two censuses read as siblings.

**Return.** A `dynet_motifs` data frame — a new class alongside `dynet_pshifts`,
not a `dynet_metric`, because the row identity is a fixed taxonomy class, exactly
as for P-shifts.

| output | columns | one row per |
|---|---|---|
| `"global"` | `session` (separate only), `motif`, `family`, `pattern`, `count` | motif class (40 rows) |
| `"local"` | `session` (separate only), `node`, `motif`, `family`, `pattern`, `count` | vertex × motif class |

- `motif` — the raphtory index, `1..40` (1-based for R).
- `family` — `"star_pre"`, `"star_mid"`, `"star_post"`, `"two_node"`, `"triangle"`.
- `pattern` — the direction word (`"OOO"`, `"IOI"`, …) for stars and two-node
  motifs; the triangle's edge form (`"i>j,j>k,i>k"`, …) for triangles. This is
  what lets a reader interpret a row without a lookup table.
- `count` — integer, ≥ 0. All 40 classes are always present, including zeros —
  a census with rows silently missing is not a census.
- Ships `print`, `summary`, `plot` and `as.data.frame` methods, per the house
  rule that every result class gets all four.
- Attributes: `delta`, `motif_family = "paranjape_2017_3_3"`,
  `motif_order = "raphtory_0.17"`, `event_identity`, `tie_rule`,
  `overlapping_instances = "counted"`, `loops = "excluded"`,
  `observation_walls`, `session_aggregation`.
- **Local counting rule** (raphtory's, adopt verbatim and document): for stars,
  only the **centre** node counts the motif; for two-node motifs, **both** nodes
  count it; for triangles, **all three** count it. Therefore
  `sum(local) != sum(global)` — the global census divides triangle counts by 3
  and two-node counts by 2. This is the single most likely source of a wrong
  implementation and needs its own invariant test.

**Algorithm.**

1. **Event extraction.** Reuse the shape of `.pshift_raw_turns()`: keep rows with
   `!enc$raw_event_onset_censored & .time_in_observation(dn, onset)`, drop loops,
   apply `start`/`end`, tag each event with its observation component and session.
   The output is a table of `(time, from, to, component, session, raw_spell)`.
   Do **not** apply `pshifts()`'s `group_events` collapse — that rule is specific
   to turn-taking and would delete real motif edges.
2. **Sort** by the deterministic key above.
3. **Enumerate δ-windows.** For each event index `k`, find the maximal run
   `[lo(k), k]` with `time[k] - time[lo] <= delta` via `findInterval()` on the
   sorted times — one vectorised call, no search loop. Within each run, the
   candidate triples ending at `k` are the `choose(k - lo, 2)` pairs from
   `lo..k-1` plus event `k`.
4. **Filter and classify.** Keep triples spanning ≤ 3 distinct vertices, then map
   `(node set size, first-edge orientation pattern, star/two-node/triangle shape)`
   to one of the 40 indices via a precomputed lookup table built once at package
   load. Classification is a table lookup on an integer key, not a cascade of
   `if`s — the pshifts `.pshift_classify()` cascade does not scale to 40 classes.
5. **Accumulate** with `tabulate(index, nbins = 40)`; for `output = "local"`,
   `tabulate()` on a `(node - 1) * 40 + index` key.
6. **Aggregate over sessions** exactly as `pshifts()` does: `"collapse"` erases
   labels, `"bounded"` counts within sessions and sums, `"separate"` returns
   per-session blocks.

*Numerical pitfalls and complexity.* No division and no logarithm — every
quantity is an integer count. The real risks are combinatorial and are named
here so they are designed for, not discovered:

- **Complexity.** Naive enumeration is `O(E * w^2)` where `w` is the number of
  events in a δ-window. On a bursty network with a generous `delta`, `w` can be
  most of `E` and the cost becomes cubic. Paranjape's own algorithm is
  `O(E * w)` via incremental counters. **Implement the `O(E * w^2)` version
  first** (it is honest, testable against raphtory, and adequate for the
  hundreds-of-events networks Dynet targets), *and* raise a
  `message()` — not a warning — reporting the largest window size when
  `max(w) > 500`, so a user who supplies an absurd `delta` learns why the call is
  slow. Record the chosen algorithm in an attribute.
- **Counter overflow.** `tabulate()` returns integer; on a dense network with a
  large `delta`, a triangle class can exceed `.Machine$integer.max`. Accumulate in
  `double` and check `count <= 2^53` before reporting, raising
  `dynet_count_overflow` above it — `paths()` already establishes exactly this
  pattern with `dynet_path_overflow` and `2^53`.
- **The `for` loop question.** Step 3's window scan is genuinely sequential in
  spirit but is expressible as `findInterval()` + `Map()` over event indices;
  write it that way. If a real loop survives, it needs the justifying comment the
  house rules require — "vectorising would materialise
  `n_events x max_window x max_window` triples" is such a justification and is
  probably true.
- `seq_len()` throughout: an empty event set is the common case for a small
  `start`/`end` window and `1:0` would enumerate backwards.

**References.**
- Paranjape, A., Benson, A. R., & Leskovec, J. (2017). Motifs in temporal
  networks. *WSDM '17*, 601–610. \doi{10.1145/3018661.3018731}
  *(the adopted definition, the 40 classes, and the linear-time algorithm)*
- Kovanen, L., Karsai, M., Kaski, K., Kertész, J., & Saramäki, J. (2011).
  Temporal motifs in time-dependent networks. *Journal of Statistical Mechanics*,
  P11005. \doi{10.1088/1742-5468/2011/11/P11005}
  *(the rejected alternative — cite it and say why it was rejected)*
- Holme, P., & Saramäki, J. (2012). Temporal networks. *Physics Reports*, 519(3),
  97–125. \doi{10.1016/j.physrep.2012.03.001}
- Gibson, D. R. (2003). Participation shifts and institutional change in
  relational systems. *Social Forces*, 81, 1335–1380.
  \doi{10.1353/sof.2003.0055}
  *(cite in `@seealso`, to place `motifs()` against `pshifts()`)*
- Oettershagen, L., & Mutzel, P. (2022). TGLib: an open-source library for
  temporal graph analysis. *arXiv:2209.12587*.

**Verify against.** `raphtory.algorithms.global_temporal_three_node_motif` and
`local_temporal_three_node_motifs` — **raphtory 0.17.0 is installed and runs
here**, and it is a far better oracle than teneto (which has no motif function at
all). Reference values generated in this session, `delta = 10` unless noted,
0-based raphtory indices:

| fixture (directed edges, `src dst time`) | non-zero global counts |
|---|---|
| `A B 1; B C 2; A C 3` | `(34, 1)` — triangle class 3, `i>j, j>k, i>k` |
| same, `delta = 1` | *(none)* — confirms δ spans first-to-last |
| `A B 1; A B 2; A B 3` | `(24, 1), (31, 1)` — one two-node motif, counted from each end |
| `A B 1; A B 2; A C 3` | `(7, 1)` — PRE star, `OOO` |
| `A B 1; A C 2; A B 3` | `(15, 1)` — MID star, `OOO` |
| `A B 1; A C 2; A C 3` | `(23, 1)` — POST star, `OOO` |
| `A B 1; C B 2; A C 3` | `(32, 1)` — triangle class 1 |
| `A B 1; B C 2; A C 3; A B 4` | `(10, 1), (15, 1), (33, 1), (34, 1)` — four overlapping instances from four edges |

Store these eight cases as a fixture file with the generating python recorded in
a comment. They cover every family, both the δ boundary and the overlap rule.
**No external reference exists** for Dynet's session walls, observation-gap walls,
censoring policy or simultaneous-event tie rule: those need **hand-computed
fixtures**.

**Tests** (`tests/testthat/test-temporal-motifs-contract.R`).

- **Error path, by class.**
  `expect_error(motifs(undirected_dn, delta = 2), class = "dynet_needs_directed")`
  — same class `pshifts()` already raises.
  Second: `expect_error(motifs(dn), class = "dynet_bad_input")` — `delta` is
  required and has no default.
  Third: `expect_error(motifs(dn, delta = -1), class = "dynet_bad_input")`.
- **Calibration.** All eight raphtory fixtures, `expect_identical()` on the
  integer counts. This is the test that makes the class taxonomy real.
- **Invariant 1 (census completeness).** `nrow(motifs(dn, delta))` is exactly 40
  for `"global"` and `40 * n_nodes` for `"local"`, whatever the data, including
  an empty window.
- **Invariant 2 (local/global reconciliation).** `sum` of local triangle counts
  `== 3 *` global triangle counts; local two-node `== 2 *` global two-node;
  local star `==` global star. Directly tests the documented per-family counting
  rule and is where a wrong implementation shows up.
- **Invariant 3 (δ monotonicity).** Total count is non-decreasing in `delta`;
  `motifs(dn, delta = 0)` counts only motifs whose three edges are simultaneous.
  Property test over a grid of `delta`.
- **Invariant 4 (relabelling).** Renaming vertices leaves the global census
  identical and permutes the local one — the standard leak test.
- **Invariant 5 (time translation).** Adding a constant to every timestamp leaves
  the census identical; scaling every timestamp *and* `delta` by the same positive
  constant leaves it identical.
- **Invariant 6 (row-order independence).** Shuffling the input rows with a fixed
  seed leaves the census bit-identical — the test for the tie rule.
- **Invariant 7 (agreement with `pshifts()` on a 2-edge projection).** On a
  fixture with exactly two events, the census is all zeros while `pshifts()`
  classifies one shift; confirms the two verbs have different arity and neither is
  secretly the other.
- **Snapshot.** `expect_snapshot(print(motifs(dn, delta = 2)))`.
- **Sanity.** Change the δ test from `t_last - t_first <= delta` to
  `t_last - t_first < delta` once and confirm the boundary fixture fails.

**Effort. L.** The largest item here. A 40-class lookup table that must match
raphtory's ordering exactly, a windowed enumeration written without a naive triple
loop, a new result class with four S3 methods, session and observation walls, an
overflow guard, and a definitional `@details` section that has to argue the
Paranjape-versus-Kovanen choice. Budget it as its own piece of work; do not fold
it into a release with anything else.

**Depends on.** Nothing, though it should be written **after** B1 so that
`@seealso` can point a user at `gaps()` for choosing `delta` — which is the only
honest way to pick one.

---

# A5 — `segregation()`: the segregation–integration difference (SID)

**Title.** Add a `segregation()` verb computing Fransson's SID from a
user-supplied community assignment.

**Why.** SID is the standard teneto measure of whether a network is, at a given
moment, more internally clustered or more cross-cluster connected than usual.
It completes the teneto measure set. It is listed **last and lowest priority**
for an honest reason: **it cannot be computed without a community assignment, and
Dynet has no community detection** (ECOSYSTEM.md gap 2: "No R package does
temporal community detection"). Every other item here works on a bare `dynet`;
this one requires the user to bring a partition from somewhere else. That is a
real limitation on its usefulness, and the API must make it visible rather than
inventing a default partition.

**Proposed API.**

```r
segregation <- function(dn, communities,
                        scope    = c("pertime", "overall"),
                        sessions = c("bounded", "collapse", "separate"),
                        start = NULL, end = NULL, step = NULL, window = NULL)
```

```r
dn <- dynet(school_contacts)
groups <- c(Ana = "a", Ben = "a", Cara = "b", Dan = "b", ...)   # named, by vertex NAME
segregation(dn, communities = groups)
segregation(dn, communities = groups, scope = "overall")
```

`communities` is a **named** character or factor vector, names matched against
`dn$nodes$name` — never a positional integer vector as teneto takes, because
positional community vectors are exactly the index-based addressing this package
exists to avoid. An unnamed vector, a name not in the network, or a vertex with
no assignment raises `dynet_bad_communities`; a vertex may not be silently
dropped, because dropping it changes the `N_A` denominators.

Note the deliberate asymmetry with `mixing()`, which takes a *node attribute
column name*. If `mixing()`'s attribute mechanism can carry a partition, prefer
`communities = "group"` naming a column in `dn$nodes` **as well as** accepting a
named vector — check `R/mixing.R` before fixing the signature. Two ways to say
the same thing is acceptable here only if `mixing()` already established one of
them.

**Return.** A `dynet_metric`, `level = "graph"`, columns `session`, `time`
(`"pertime"` only), `measure` (`"sid"`), `value`. One row per time bin.
`value` is unbounded and signed: positive means more segregation than
integration. Attributes: `communities_n`, `community_sizes`,
`strength = "binary_row_sums"`, `axis` (directed only).

**Algorithm.** Per bin, with `S[i]` the binary snapshot row sums (temporal
strength) and communities `a, b` of sizes `N_a, N_b`:

```
SID[t] = sum over a of [ (2 / (N_a (N_a - 1))) * S_within[a,t]
                       - sum over b != a of (1 / (N_a N_b)) * S_between[a,b,t] ]
```

where `S_within[a,t]` is the total edge weight inside community `a` and
`S_between[a,b,t]` the total between `a` and `b`, following Fransson (2018) as
implemented in teneto's `sid`.

*Numerical pitfalls.* (a) **`N_a == 1` makes `2/(N_a(N_a-1))` a division by
zero.** teneto returns `nan` in that case — verified from its docstring's own
example, which shows a `nan` row for a singleton community. Dynet must return
`NA_real_` for that community's contribution and, because the global SID sums
over communities, **the whole bin's value becomes `NA_real_`** unless the
singleton is excluded. Do not silently drop singletons. Raise a
`warningCondition(class = "dynet_singleton_community")` naming the community, and
return `NA`. (b) `N_a * N_b` is fine but guard it anyway. (c) The measure is a
difference of two normalised sums and is **not** bounded; do not write a
`[0,1]` range check. (d) Directed networks need an `axis` choice (teneto's
`axis = 0/1`); default to out-strength and say so.

**References.**
- Fransson, P., Thompson, W. H., Skiöld, B., et al. (2018). Brain network
  segregation and integration during an epoch-related working memory fMRI
  experiment. *NeuroImage*, 178, 147–161.
  \doi{10.1016/j.neuroimage.2018.05.040}
- Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to temporal
  network theory. *Network Neuroscience*, 1(2), 69–99.
  \doi{10.1162/NETN_a_00011}

**Verify against.** `teneto.networkmeasures.sid` (teneto 0.5.3, **runs
unpatched**). Reference generated this session on the item-A2 fixture with
`communities = [0, 0, 1, 1]`, `calc = 'overtime'`:

```
[ 0.5   2.    0.5  -0.5 ]
```

Note that teneto's `calc='overtime'` returns a **per-time-point vector** of
length `T`, not a scalar — verified above, length 4 for a 4-slice network. The
naming is teneto's, not a Dynet error; `scope = "pertime"` is the honest name for
that quantity and `scope = "overall"` should be its mean. Say so in `@details`.
The equivalence test needs `start = 0, end = 3, window = 0` on the Dynet side
(see the grid warning in A2).

**Tests** (`tests/testthat/test-segregation-contract.R`).

- **Error path, by class.**
  `expect_error(segregation(dn, communities = c("a", "b")), class = "dynet_bad_communities")` — unnamed.
  Second: `expect_error(segregation(dn, communities = c(NotAVertex = "a")), class = "dynet_bad_communities")`.
  Third: `expect_error(segregation(dn, communities = partial_named_vector), class = "dynet_bad_communities")` — incomplete coverage.
- **Warning path, by class.**
  `expect_warning(segregation(dn, communities = with_a_singleton), class = "dynet_singleton_community")`,
  and assert the returned value is `NA_real_`.
- **Equivalence.** The teneto fixture above, `tolerance = 1e-12`.
- **Invariant 1 (community relabelling).** Renaming the community *labels*
  (`"a" -> "x"`) leaves every value identical.
- **Invariant 2 (vertex relabelling).** Renaming vertices with `rename_nodes()`
  and permuting `communities` accordingly leaves every value identical.
- **Invariant 3 (sign).** On a fixture with only within-community edges, SID > 0
  at every bin; with only between-community edges, SID < 0.
- **Invariant 4 (aggregation).** `scope = "overall"` equals the mean of
  `scope = "pertime"`.
- **Snapshot.** `expect_snapshot(print(segregation(dn, communities = groups)))`.

**Effort. M.** The formula is a few lines over community-blocked row sums and
the reference runs. The cost is the `communities` validation contract (named,
complete, matched by name), the singleton `NA` policy and its warning class, the
directed `axis` decision, and reconciling the signature with `mixing()`.

**Depends on.** Nothing technically. **Do it last**, and consider not doing it at
all until Dynet or a companion can *produce* a temporal partition — a measure the
user can only run by importing a partition from Python is of limited value, and
saying so is more useful than shipping it quietly.

---

## Summary of what this adds

| Item | Verb | New? | Needs temporal paths? | Effort | Reference runs here |
|---|---|---|---|---|---|
| B1 | `gaps()` | new verb | no | S | yes — teneto + dynetx |
| A2 | `persistence()` | new verb | no | M | yes — teneto |
| A3 | `turnover()` | new verb | no | M | partly — teneto, volatility needs a scipy shim |
| A1 | `metrics(temporal_efficiency, temporal_diameter)` | new measures | **yes** | L | directional only; hand fixture required |
| A4 | `dyn_centrality(measure = "efficiency", scope = "temporal")` | new measure | **yes** | S after A1 | directional only; hand fixture required |
| C1 | `motifs()` | new verb | no | L | yes — raphtory 0.17.0 |
| A5 | `segregation()` | new verb | no | M | yes — teneto |

Four new verbs, four new `measure` values, one new `dynet_motifs` class. No new
package dependencies: everything is base R plus the existing optional `cograph`.

## Environment, for reproducing the reference values

- R 4.5.x, `devtools::load_all(".")` at Dynet 0.3.53, macOS 15 (Darwin 25.3.0), arm64.
- `teneto` 0.5.3 in system `python3` (`/opt/homebrew/lib/python3.14/site-packages`).
  `volatility()` requires shimming `scipy.spatial.distance.kulsinski` before
  `import teneto`; `topological_overlap`, `fluctuability`, `sid`,
  `intercontacttimes`, `temporal_efficiency` and `shortest_temporal_path` run
  unpatched.
- `raphtory` 0.17.0 and `dynetx` in the same interpreter. `dynetworkx`,
  `networkx_temporal` and `tnetwork` are **not** installed.
- Reference generation scripts used in this session were scratch files and were
  not committed; the values are pasted verbatim above and every one of them was
  additionally hand-checked where hand-checking was feasible.
