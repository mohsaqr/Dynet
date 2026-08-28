# TODO — Stage 4: temporal community detection

Implementation spec for `Dynet` 0.3.53. No package code is written here.

Every claim in the "What already exists" section below was established by
running code in this session (2026-08-28, R 4.5 arm64, cograph 2.4.5,
igraph 2.3.3, multinet 4.3.4, teneto 0.5.3 on `/opt/homebrew` python3.14).
Numbers quoted are real output, not recollection.

---

## What already exists — measured, not assumed

### `projection()` is the correct substrate, and it is already right

`projection(dn, omega =)` returns a `dynet_projection` whose vertex table is
exactly the time-expanded state set and whose edge table carries the identity
arcs at weight `omega`. Run on `school_contacts`:

```
14 vertices x 22 slices  = 308 vertex states
within_slice arcs        = 332
identity_arc arcs        = 294   ( = 14 nodes x 21 slice gaps )
```

Identity arcs connect **consecutive slices only** (`from_slice`,
`to_slice = from_slice + 1`), which is precisely Mucha's **ordinal**
interlayer coupling — the correct coupling for a temporal network. Weight is
`omega` verbatim: with `projection(dn, omega = 0.37)`,
`unique(weight[edge_type == "identity_arc"])` is `0.37`.

### `cograph::supra_adjacency()` exists but builds the WRONG coupling for time

This is the single most important negative finding. `coupling = "diagonal"`
does **not** mean "chain"; it means "same node across *every* pair of layers".
Measured on three identical 3-node layers with `omega = 0.4`:

```
     t1_A t1_B t1_C t2_A t2_B t2_C t3_A t3_B t3_C
t1_A  0.0  1.0  0.0  0.4  0.0  0.0  0.4  0.0  0.0   <- t1_A--t3_A is 0.4
```

`t1_A—t3_A` is coupled at 0.4 although the slices are two apart. That is
**categorical** coupling (all-to-all), appropriate for aspect-layers such as
"phone / email / face-to-face", and wrong for time, where a node should be
tied only to its immediate past and future. `coupling = "full"` is worse still
(it couples *different* nodes across layers). The matrix is symmetric and
carries useful attributes (`n_nodes`, `n_layers`, `node_names`,
`layer_names`, `omega`, `coupling`), but Dynet must not use it for multislice
temporal modularity. **`projection()` already does the right thing and
`supra_adjacency()` does not.**

### cograph's community detection is real, tidy — and unusable here for two reasons

`cograph::communities()`, `community_louvain()`, `community_leiden()`,
`community_infomap()`, `community_consensus()`, `detect_communities()`,
`compare_communities()`, `cluster_quality()`, `n_communities()` all exist and
`communities()` returns a tidy `node`/`community` data frame. Run on a
12 x 12 two-block supra-matrix it correctly returned 2 communities,
modularity 0.5.

But:

1. **They all delegate to igraph.** `deparse(cograph::community_louvain)` line
   10 is literally `igraph::cluster_louvain(g, weights = w, resolution =
   resolution)`. igraph is in **cograph's Suggests**, not its Imports (checked
   cograph's `DESCRIPTION`: `Imports: ggplot2, grDevices, grid, Matrix, R6,
   stats, utils`). igraph is also only in **Dynet's Suggests**. So nothing in
   this chain is guaranteed installed. Same for
   `cograph::compare_communities()`, whose body ends in `igraph::compare(...)`.
2. **Even if igraph were an Import, it computes the wrong quality function.**
   `igraph::cluster_louvain()` on the supra-adjacency uses the static
   Newman–Girvan null on the *whole* supra-graph: supra-degrees
   \(\kappa_{js}\) and the global total \(2\mu\). Mucha's null uses
   **slice-local** degrees \(k_{is}, k_{js}\) and **slice-local** totals
   \(2m_s\), and applies no null to the interlayer arcs at all. Those are
   different objective functions, not different implementations of one.

**Conclusion: the substrate is genuinely done (`projection()`), and the
optimisation on top is genuinely missing.** The effort is therefore mid-sized,
not enormous — but larger than "call cograph", which does not work.

### One real bug found in `projection()`

```r
p <- projection(dn, omega = 0.37)
unique(as.data.frame(p, what = "edges")$weight[... == "identity_arc"])  # 0.37
p$meta$identity_weight                                                  # 1   <- wrong
"omega" %in% names(p$meta)                                              # FALSE
```

`R/projection.R:292` hard-codes `identity_weight = 1` regardless of `omega`,
and `omega` is never recorded in `meta`. Item 1 fixes this; every later item
depends on being able to read the coupling back off the object.

### Reference implementations reachable from this machine

| Tool | Status | Use |
|---|---|---|
| `multinet::glouvain_ml(n, gamma, omega)` 4.3.4 | **installed, ran** | The Mucha generalized-Louvain reference. Returns a tidy `actor / layer / cid` frame — one row per node per layer. Exactly the shape item 3 must return. |
| `multinet::nmi_ml`, `omega_index_ml` | **installed, ran** | Partition-comparison reference. |
| `teneto.communitymeasures` 0.5.3 | **installed, ran** | `flexibility, promiscuity, allegiance, recruitment, integration, persistence`. Source read; exact formulas transcribed into item 6. |
| `igraph::modularity`, `igraph::compare` 2.3.3 | **installed, ran** | Static-limit calibration for items 2 and 5. |
| `scipy.optimize.linear_sum_assignment` | **installed** | Hungarian cross-check for item 4. |
| `tnetwork` 1.2 (`longitudinal_similarity`, `consecutive_sn_similarity`, `onmi`) | **NOT importable** | `ModuleNotFoundError` on python3, python3.13 and `/opt/homebrew/bin/python3`. ECOSYSTEM.md lists it as enumerated, but it is not in any interpreter on this machine. Treated as literature-only. |
| `phasik` 1.3.4 | **NOT importable** | Same. Literature-only. |
| `NetworkChange` 1.1.0 | installed per ECOSYSTEM.md, not exercised | Different paradigm (Bayesian changepoint), not a reference for anything here. |

### Naming collision, measured

`communities` is exported by **both** cograph (an Import) and igraph (a
Suggest). `modularity` is exported by igraph. `supra` is exported by cograph.
`community_change`, `community_trajectory`, `phases`, `match_communities` are
free. See item 3 for the recommendation.

### Dynet has no randomness anywhere today

`grep -rn "set.seed" R/` returns only a comment in `R/palette.R` saying
"Deterministic: no sampling and no seed." Item 3 introduces the **first**
stochastic verb in the package, so it must also introduce the RNG discipline
(save/restore `.Random.seed` under `on.exit()`, an explicit `seeds =`
argument, a reported stability statistic). This is part of the cost.

---

## Items, in dependency order

---

## 1. Record the coupling on the projection and expose the ordinal supra-matrix

**Why.** Every later item needs to read `omega` back off a projection and to
turn it into a symmetric slice-ordered supra-adjacency. Today `meta$omega`
does not exist and `meta$identity_weight` lies (says `1` when the arcs carry
`0.37`, verified above). `cograph::supra_adjacency()` cannot be used because
its `"diagonal"` coupling is all-to-all across layers, not the chain a
temporal network needs.

**Proposed API.** No new export. Two changes plus one internal.

```r
projection(dn, sessions = c("bounded", "collapse", "separate"),
           start = NULL, end = NULL, step = NULL, window = NULL,
           omega = 1,
           coupling = c("ordinal", "categorical"))
```

`coupling = "ordinal"` (default, current behaviour) links slice *s* to *s+1*
only. `coupling = "categorical"` links every pair of slices, matching
`cograph::supra_adjacency(coupling = "diagonal")`; it is offered only so the
cograph result can be reproduced and compared, and the docs must say it is
not the temporal convention.

Internal, not exported:

```r
.supra(p, symmetrise = TRUE)
```

returning `list(layers = <list of T n x n numeric matrices, dimnames = node
names>, omega = <numeric>, coupling = <character>, times = <numeric T>,
nodes = <character n>, sessions = <character or NULL>)`. Per-slice matrices,
never the n·T x n·T block matrix — see the memory note in item 3.

Example calls:

```r
projection(dn, step = 1, window = 1, omega = 0.5)
projection(dn, step = 1, window = 1, omega = 0.5, coupling = "categorical")
```

**Return.** `projection()` keeps class `dynet_projection` and its two existing
tables unchanged. `meta` gains `omega` (numeric scalar) and `coupling`
(character scalar); `meta$identity_weight` is **replaced** by `meta$omega` and
removed, since it was never anything but a wrong duplicate of it.

**Algorithm.** Mechanical. Replace `identity_weight = 1` at `R/projection.R:292`
with `omega = omega, coupling = coupling`. Under `coupling = "categorical"`
the identity-arc loop emits one arc for every ordered slice pair
\((s, r), s < r\) rather than only \(r = s+1\). `.supra()` reassembles
per-slice dense matrices from the `within_slice` rows via `.adjacency()`-style
`tapply()` accumulation over the linear cell index (as `R/engine.R:863`
already does), symmetrising with `a + t(a)` when
`p$meta$source_directed` is `FALSE`. Pitfall: a directed source network
produces asymmetric slices, and multislice modularity as published is defined
for symmetric slices — if `p$meta$source_directed`, symmetrise as
\(A^{sym} = (A + A^{\mathsf T})/2\) and **say so in a `note` on the result**,
never silently.

**References.**
- Mucha, P. J., Richardson, T., Macon, K., Porter, M. A., & Onnela, J.-P.
  (2010). Community structure in time-dependent, multiscale, and multiplex
  networks. *Science*, 328(5980), 876–878. — the ordinal/categorical
  distinction is theirs (their Fig. 1).
- Kivelä, M., Arenas, A., Barthelemy, M., Gleeson, J. P., Moreno, Y., &
  Porter, M. A. (2014). Multilayer networks. *Journal of Complex Networks*,
  2(3), 203–271. — supra-adjacency formalism.

**Verify against.** `cograph::supra_adjacency(layers, omega, coupling =
"diagonal")` must equal the block assembly of `.supra()` under
`coupling = "categorical"`, cell for cell. Verified this session that
cograph's `"diagonal"` is all-to-all, so this is a genuine equality test, and
under `coupling = "ordinal"` the two must **differ** for `T >= 3` — assert
that too, so the distinction can never silently regress.

**Tests** (`tests/testthat/test-projection-coupling.R`)
- *Error path:* `expect_error(projection(dn, omega = -1), class = "dynet_bad_input")`;
  `expect_error(projection(dn, coupling = "chain"), ...)` from `match.arg()`.
- *Regression for the found bug:* for `omega` in `c(0, 0.37, 3)`, the unique
  identity-arc weight equals `omega` **and** `meta$omega` equals `omega`.
- *Invariant:* under `coupling = "ordinal"`, `abs(to_slice - from_slice) == 1`
  for every identity arc; under `"categorical"`, the identity-arc count is
  `n * choose(T, 2)`.
- *Cross-package:* `skip_if_not_installed("cograph")`; categorical `.supra()`
  block-assembles to `cograph::supra_adjacency(..., coupling = "diagonal")`
  within `sqrt(.Machine$double.eps)`.

**Effort. S.** One-line meta fix, one new `match.arg()` branch, one internal
assembler reusing existing `.adjacency()` machinery.

**Depends on.** Nothing.

---

## 2. Implement multislice modularity as a quality function

**Why.** Item 3 cannot be written, tested or trusted without a `Q` it can
evaluate independently of the optimiser, and users need to score a partition
they already have (e.g. a class roster) against the network. Getting the null
model right is the whole point: the static Newman–Girvan null applied to the
supra-adjacency is a *different objective*, and that is exactly the mistake
delegating to `igraph::cluster_louvain()` would make.

**Proposed API.**

```r
modularity(dn, membership = NULL, gamma = 1, omega = 1,
           sessions = c("bounded", "collapse", "separate"),
           start = NULL, end = NULL, step = NULL, window = NULL)
```

`membership` is a data frame with columns `time`, `node`, `community` —
i.e. the exact shape item 3 returns, so `modularity(dn, membership =
communities(dn))` round-trips with no reshaping by the caller. `NULL` means
"score the partition that puts every state in one community", which is the
`Q = 0` baseline and makes the argument's absence meaningful rather than an
error.

```r
modularity(dn, membership = communities(dn, omega = 1))
modularity(dn, membership = communities(dn), gamma = 1.5, omega = 0.25)
modularity(dn, membership = roster, gamma = 1, omega = 1)   # a known partition
```

**Return.** A `dynet_metric` at `level = "graph"`, `what = "Multislice
modularity"`, one row per component of the decomposition plus the total:

| `measure` | one row per |
|---|---|
| `q` | the whole network — the multislice \(Q\) |
| `q_intra` | the whole network — the \(\delta_{sr}\) part of \(Q\) |
| `q_inter` | the whole network — the \(\delta_{ij}\omega\) part of \(Q\) |
| `two_mu` | the whole network — the normaliser \(2\mu\) |
| `n_communities` | the whole network |
| `n_empty_slices` | the whole network |

Columns: `measure`, `value` (the `dynet_metric` graph-level contract; no
`time` column, because \(Q\) is not defined per bin). Attributes carry
`gamma`, `omega`, `coupling`. `q_intra + q_inter` must equal `q` exactly.

**Algorithm.** The Mucha et al. (2010) multislice quality function. With
\(A_{ijs}\) the weight of edge \(i\)–\(j\) in slice \(s\):

- \(k_{is} = \sum_j A_{ijs}\) — **slice-local** strength
- \(2m_s = \sum_{ij} A_{ijs}\) — **slice-local** total
- \(\omega_{jsr}\) — coupling of node \(j\) between slices \(s\) and \(r\);
  ordinal coupling gives \(\omega_{jsr} = \omega\,\mathbb{1}[\,|s-r| = 1\,]\)
- \(c_{js} = \sum_r \omega_{jsr}\) — **interlayer strength**: \(\omega\) for
  the first and last slice, \(2\omega\) for every interior slice
- \(\kappa_{js} = k_{js} + c_{js}\)
- \(2\mu = \sum_{js} \kappa_{js}\)

$$
Q = \frac{1}{2\mu}\sum_{ijsr}
\Big[\big(A_{ijs} - \gamma\,\tfrac{k_{is}k_{js}}{2m_s}\big)\delta_{sr}
      + \delta_{ij}\,\omega_{jsr}\Big]\,
\delta\!\left(g_{is}, g_{jr}\right)
$$

**The three things that are not the static null, and that an implementer will
get wrong if they are not spelled out:**

1. The null term uses \(k_{is}, k_{js}\) and \(2m_s\) **from slice \(s\)
   alone**. It is *not* \(\kappa_{is}\kappa_{js}/2\mu\). Slices with different
   densities get different nulls; that is the entire reason multislice
   modularity can compare a sparse bin with a dense one.
2. The null is multiplied by \(\delta_{sr}\), so **no null is subtracted from
   the interlayer arcs**. Identity arcs are not stochastic edges to be
   explained away; they are the assertion that a node is the same node. A
   static Louvain on the supra-matrix subtracts a null from them and is
   therefore optimising something else.
3. The normaliser is \(2\mu = \sum \kappa_{js}\), which **includes** the
   coupling strength — not \(\sum_s 2m_s\). This is why \(Q\) does not blow
   up as \(\omega\) grows.

Sums run over ordered pairs, so each matched interlayer pair contributes
\(2\omega\).

*Calibration identities, both verified numerically this session on a random
12-node graph (`set.seed(7)`, `p = 0.35`) and a 3-block partition:*

- \(T = 1, \omega = 0\): \(Q\) equals `igraph::modularity()` exactly.
  Measured `-0.1064000000` from both.
- \(\omega = 0\), any \(T\): \(Q\) equals the \(2m_s\)-weighted mean of the
  per-slice Newman–Girvan modularities. Measured `-0.0982017544` from both.

These are the two hard tests. They pin the null model and the normaliser.

*Numerical pitfalls.*
- **Empty slice.** \(2m_s = 0\) gives \(0/0\). Define the null contribution of
  an edgeless slice as exactly `0` (no edges, no expectation) and count the
  slice in `n_empty_slices`. Do **not** reach for `na.rm = TRUE`; guard the
  division explicitly.
- **Empty network.** If \(2\mu = 0\) the quantity is undefined — raise
  `errorCondition(class = "dynet_empty_result")` rather than returning `NaN`.
- **Accumulation order.** Sum slice by slice and add the interlayer term last,
  so \(Q\) is reproducible bit-for-bit across runs; do not fold a 308 x 308
  matrix in an arbitrary order.
- Never `==` on \(Q\); every comparison in tests uses `all.equal()` with an
  explicit tolerance.

*Seed/stability.* None. \(Q\) is deterministic given a partition; the verb
takes no seed and must not.

**References.**
- Mucha, Richardson, Macon, Porter & Onnela (2010), *Science* 328:876–878.
- Newman, M. E. J., & Girvan, M. (2004). Finding and evaluating community
  structure in networks. *Physical Review E*, 69(2), 026113. — the static
  limit the calibration test pins.
- Reichardt, J., & Bornholdt, S. (2006). Statistical mechanics of community
  detection. *Physical Review E*, 74(1), 016110. — the \(\gamma\) resolution
  parameter.
- Bazzi, M., Porter, M. A., Williams, S., McDonald, M., Fenn, D. J., & Howison,
  S. D. (2016). Community detection in temporal multilayer networks, with an
  application to correlation networks. *Multiscale Modeling & Simulation*,
  14(1), 1–41. — behaviour of \(Q\) as \(\omega\) varies.

**Verify against.** `igraph::modularity()` for the two calibration identities
above (exact, verified). No R implementation of the multislice \(Q\) *value*
is reachable — `multinet::glouvain_ml()` returns a partition and no quality
score, so the value itself has no external oracle and must be pinned by the
two static reductions plus the hand-computed 8-node fixture below.

**Tests** (`tests/testthat/test-multislice-modularity.R`)
- *Error path:* `expect_error(modularity(dn, membership = data.frame(node =
  "A")), class = "dynet_bad_input")` (missing `time`/`community`);
  `expect_error(modularity(dn, membership = bad_names), class =
  "dynet_unknown_node")` when `membership$node` names a vertex not in
  `dn$nodes$name` — vertices are addressed by name, so a typo must be caught,
  not silently dropped.
- *Calibration 1:* `skip_if_not_installed("igraph")`; single slice, `omega = 0`
  ⇒ equals `igraph::modularity()`. Verified value `-0.1064` on the seeded
  fixture.
- *Calibration 2:* `omega = 0`, `T = 2` ⇒ equals the \(2m_s\)-weighted mean of
  per-slice `igraph::modularity()`. Verified value `-0.09820175`.
- *Invariant — relabelling:* permuting community labels (`1 -> 9`, `2 -> 3`)
  leaves \(Q\) unchanged. Verified `TRUE` on the prototype.
- *Invariant — node permutation:* permuting the vertex order of every slice
  and the membership identically leaves \(Q\) unchanged. Verified `TRUE`.
- *Invariant — decomposition:* `q_intra + q_inter == q` under `all.equal()`.
- *Invariant — trivial partition:* one community for everything, `omega = 0`
  ⇒ \(Q = 0\). Verified `-0.00000` on the prototype.
- *Property — \(\omega\) monotonicity:* on the fixture below, \(Q\) of the
  persistent partition is increasing in \(\omega\) and overtakes the switching
  partition. **Measured, 8 nodes, 2 slices, slice 1 = two 4-cliques,
  slice 2 = a 3-clique and a 5-clique (node D defects):**

  | \(\omega\) | \(Q\) persistent | \(Q\) switching | \(Q\) one-community |
  |---|---|---|---|
  | 0 | 0.32615 | 0.42462 | 0.00000 |
  | 0.25 | 0.37607 | 0.45798 | 0.07407 |
  | 1 | 0.48951 | 0.53380 | 0.24242 |
  | 2.5 | 0.62564 | 0.62479 | — |
  | 5 | 0.74083 | 0.70178 | 0.61538 |

  Freeze these as a snapshot fixture. The crossover between 2 and 2.5 is the
  whole meaning of \(\omega\) and any change to the null or the normaliser
  moves it.
- *Empty slice:* a grid with an edgeless bin returns a finite \(Q\) and
  `n_empty_slices >= 1`; never `NaN`.

**Effort. M.** The formula is short but every term is a place to be wrong, and
the two calibration identities plus the \(\omega\)-crossover fixture are the
real work. Roughly 120 lines of R and 200 of tests.

**Depends on.** Item 1.

---

## 3. Detect temporal communities by generalized Louvain

**Why.** This is the hole: no R package optimises the Mucha quality function
over a time-expanded network. `multinet::glouvain_ml()` reaches it only by
pretending time bins are unordered aspect-layers, and the aspect-layer
coupling is all-to-all rather than a chain. The verb is what lets a user watch
a community persist, split or dissolve.

**Proposed API.**

```r
communities(dn, gamma = 1, omega = 1,
            method = c("louvain", "consensus"),
            seeds = 1:10,
            sessions = c("bounded", "collapse", "separate"),
            start = NULL, end = NULL, step = NULL, window = NULL,
            max_passes = 20L, tol = 1e-10)
```

```r
communities(dn)
communities(dn, gamma = 1.25, omega = 0.5, seeds = 1:50)
communities(dn, method = "consensus", seeds = 1:100, step = 2, window = 2)
```

Note the shape of the contract: the caller never post-processes. Want the
communities of one bin? `communities(dn, start = 5, end = 5)`. Want the
biggest community? `summary()` on the result gives sizes. There is no
subsetting on the public surface.

*Naming.* `communities` is exported by cograph (an Import) and igraph (a
Suggest) — measured. Dynet always calls cograph as `cograph::`, so nothing
inside the package breaks, but `library(cograph); library(Dynet)` will print a
mask warning. The name still matches the package idiom (`snapshots()`,
`similarity()`, `events()`) and is recommended; if the maintainer would rather
not mask, `temporal_communities()` is collision-free (checked against cograph,
igraph and stats).

**Return.** Class `c("dynet_communities", "data.frame")` — **not**
`dynet_metric`, because the value is a nominal label and `dynet_metric` is
contracted to a numeric `value`. One row per **node per time bin**:

| column | meaning |
|---|---|
| `session` | present only when the network has sessions |
| `time` | bin start time |
| `node` | vertex **name** |
| `community` | integer label, globally consistent across bins when `omega > 0` |
| `active` | logical, was the vertex eligible in this bin (from `projection()`) |
| `stability` | numeric in \([0,1]\), fraction of the `seeds` runs in which this state was co-assigned with its modal partner set |

Attributes: `gamma`, `omega`, `n_communities`, `q` (the best \(Q\)),
`q_runs` (numeric, one per seed), `seeds`, `stability_ari` (mean pairwise
adjusted Rand index across runs), `n_passes`, `converged`.

Methods to ship: `print` (header with \(Q\), community count, the stability
figure, then the first rows), `summary` (one row per community: `community`,
`n_states`, `n_nodes`, `first_time`, `last_time`, `n_bins`, `persistence`),
`as.data.frame(x, what = c("membership", "runs", "sizes"))` so the per-seed
\(Q\) values and the community sizes are reachable by argument rather than by
`$`, and `plot` (an alluvial/stacked ribbon over time, Okabe–Ito fill, each
ribbon directly labelled so colour is not the only channel).

**Algorithm.** Generalized Louvain (Jutla, Jeub & Mucha's `GenLouvain`,
adapted) optimising the item-2 \(Q\).

*Phase 1 — local moving, without ever forming \(B\).* The modularity matrix
is \(nT \times nT\); for 500 nodes and 100 bins that is 50,000 states and
2.5 x 10⁹ doubles ≈ 20 GB. It must never be materialised. Instead keep, for
each slice \(s\), the dense \(n \times n\) slice \(A_s\) (or its edge list),
the strength vector \(k_{\cdot s}\), the scalar \(2m_s\), and a
`communities x slices` matrix \(K_{c,s} = \sum_{j \in c \cap s} k_{js}\)
updated incrementally on every move. Then moving state \((i,s)\) from
community \(a\) to \(b\) changes \(2\mu Q\) by

$$
\Delta = 2\Big[\big(w_{i \to b, s} - \gamma\tfrac{k_{is}K_{b,s}}{2m_s}\big)
              -\big(w_{i \to a\setminus i, s} - \gamma\tfrac{k_{is}(K_{a,s}-k_{is})}{2m_s}\big)\Big]
        + 2\omega\big[\,\mathbb{1}[g_{i,s-1}=b] + \mathbb{1}[g_{i,s+1}=b]
                      - \mathbb{1}[g_{i,s-1}=a] - \mathbb{1}[g_{i,s+1}=a]\,\big]
$$

where \(w_{i \to c, s} = \sum_{j \in c} A_{ijs}\). The interlayer part is
trivial: a state has exactly two interlayer neighbours, \((i,s-1)\) and
\((i,s+1)\), and each contributes \(\omega\) — this is where ordinal coupling
pays off, and where categorical coupling would cost \(T-1\) lookups instead
of 2.

*Phase 2 — aggregation on \(B\), not on \(A\).* This is the step naive
implementations get wrong. The multislice null is **not** preserved by
aggregating the adjacency, because \(k_{is}\) is slice-local. Aggregate the
**modularity matrix**:
\(B^{agg}_{cd} = \sum_{(i,s) \in c}\sum_{(j,r) \in d} B_{is,jr}\).
After the first pass the number of communities is small (tens), so this
aggregate is cheap and dense, and passes 2..`max_passes` are ordinary Louvain
on \(B^{agg}\) with the *bare* modularity \(\sum_{cd} B^{agg}_{cd}\delta(h_c,h_d)\)
— no further null subtraction, because the null is already inside \(B^{agg}\).
Iterate until \(\Delta Q < \)`tol` or `max_passes` is hit.

*Seeds and stability — mandatory, not optional.* Modularity landscapes are
near-degenerate (Good, de Montjoye & Clauset 2010): many partitions sit within
a hair of the maximum, and Louvain's answer depends on node order. Therefore:

- `seeds` defaults to `1:10`, never a single value, and `length(seeds) == 1`
  emits a `warningCondition(class = "dynet_single_seed")` naming the risk.
- Run the optimiser once per seed with an independently permuted state order.
- The reported partition is the **highest-\(Q\)** run, ties broken by the
  lexicographically smallest membership vector so the answer is deterministic
  given `seeds`.
- Stability is reported and printed: `stability_ari` = mean pairwise adjusted
  Rand index across the `length(seeds)` runs, and the per-state `stability`
  column = the fraction of runs agreeing with the reported co-classification.
  A user who sees `stability_ari = 0.31` knows not to interpret the labels.
- `method = "consensus"` returns instead the consensus partition of the runs
  (Lancichinetti & Fortunato 2012): build the co-classification matrix
  \(D_{uv}\) = fraction of runs placing states \(u,v\) together, threshold it
  at the value expected under a null permutation of the run labels (Bassett
  et al. 2013), and re-run generalized Louvain on \(D\) until the runs agree.
- RNG hygiene: Dynet has no randomness today. Save `.Random.seed` and restore
  it with `on.exit(add = TRUE, after = FALSE)`; use
  `withr`-free base save/restore since `withr` is not a dependency. Never
  mutate the user's stream.

*Other numerical pitfalls.*
- Incremental \(\Delta\) accumulation drifts. Recompute \(Q\) from scratch
  (item 2) at the end of every pass and assert it did not decrease by more
  than `tol`; if it did, stop with a `warningCondition(class =
  "dynet_no_converge")` and return the last good partition — never a silently
  unconverged result.
- Never `==` on \(\Delta\); the move-acceptance test is `Delta > tol`.
- Empty slices contribute no intra term and must not divide by \(2m_s = 0\).
- Inactive states (`active == FALSE` from `projection()`) still have identity
  arcs — Dynet permits waiting through inactivity — so they are carried along
  by the coupling and get a label. Document that; do not drop them, which
  would break the chain.
- `omega = 0` decouples the slices entirely and labels then become
  per-bin-arbitrary. In that case set the result's labels via item 4 and
  record `attr(x, "matched") <- TRUE`, so the returned frame is never a set of
  meaningless per-bin integers.

**References.**
- Mucha, Richardson, Macon, Porter & Onnela (2010), *Science* 328:876–878.
- Jeub, L. G. S., Bazzi, M., Jutla, I. S., & Mucha, P. J. (2011–2019). *A
  generalized Louvain method for community detection implemented in MATLAB.*
  https://github.com/GenLouvain/GenLouvain — the aggregation-on-\(B\) recipe.
- Blondel, V. D., Guillaume, J.-L., Lambiotte, R., & Lefebvre, E. (2008). Fast
  unfolding of communities in large networks. *J. Stat. Mech.*, P10008.
- Traag, V. A., Waltman, L., & van Eck, N. J. (2019). From Louvain to Leiden:
  guaranteeing well-connected communities. *Scientific Reports*, 9, 5233. —
  the badly-connected-community defect of Louvain; note in the docs that the
  Leiden refinement is not implemented and why (see Effort).
- Good, B. H., de Montjoye, Y.-A., & Clauset, A. (2010). Performance of
  modularity maximization in practical contexts. *Physical Review E*, 81(4),
  046106. — the degeneracy that forces multiple seeds.
- Lancichinetti, A., & Fortunato, S. (2012). Consensus clustering in complex
  networks. *Scientific Reports*, 2, 336.
- Bassett, D. S., Porter, M. A., Wymbs, N. F., Grafton, S. T., Carlson, J. M.,
  & Mucha, P. J. (2013). Robust detection of dynamic community structure in
  networks. *Chaos*, 23(1), 013142.

**Verify against.** `multinet::glouvain_ml(n, gamma, omega)` — installed and
run this session. Its return is `actor / layer / cid`, one row per node per
layer, confirming the target shape. **Honest caveat, measured.** On the
8-actor / 2-layer planted fixture (slice 1 = two 4-cliques; slice 2 = a
3-clique {A,B,C} and a 5-clique {D..H}):

| \(\omega\) | multinet `glouvain_ml` result | item-2 \(Q\) ranking |
|---|---|---|
| 0 | 4 communities, slices independent | switching wins |
| 0.25 | the switching partition | switching wins |
| 1 | the persistent partition | switching still wins (0.534 > 0.490) |
| 5 | the persistent partition | persistent wins (0.741 > 0.702) |

multinet flips between \(\omega = 0.25\) and \(1\); the published \(Q\) flips
between \(2\) and \(2.5\). The *ordering of regimes* agrees; the crossover
point does not. multinet couples layers all-to-all (aspect-layers) rather than
as a chain, and `glouvain_ml` is a local heuristic, so this is expected. The
cross-check must therefore assert **qualitative agreement** — same partition
at \(\omega = 0\) (independent slices) and at large \(\omega\) (fully
persistent), and monotone convergence toward persistence — and must **not**
assert numerical equality of \(\omega\) thresholds. Say this in the test
comment so nobody later "fixes" it.

**Tests** (`tests/testthat/test-temporal-communities.R`)
- *Error path:* `expect_error(communities(dn, omega = -1), class =
  "dynet_bad_input")`; `expect_error(communities(dn, seeds = numeric(0)),
  class = "dynet_bad_input")`; `expect_error(communities(dn, start = 5, end =
  5, step = 1), class = "dynet_empty_result")` when the grid yields no edges.
- *Warning path:* `expect_warning(communities(dn, seeds = 1), class =
  "dynet_single_seed")`.
- *Invariant — planted partition recovered.* Build a temporal SBM: 20 nodes,
  10 bins, two blocks, within-block tie probability 0.6, between 0.05, blocks
  constant. With `omega = 1, seeds = 1:20` the recovered partition must have
  adjusted Rand index `> 0.95` against the plant, at every bin. Run from three
  independent generator seeds and require all three.
- *Invariant — planted split recovered.* Same, but one block splits in two at
  bin 6. Assert `n_communities` rises at bin 6 and the pre-split members stay
  co-assigned before it.
- *Invariant — node relabelling.* Permute `dn`'s vertex names via
  `rename_nodes()`; the partition, mapped back through the renaming, is
  identical and \(Q\) is unchanged.
- *Invariant — output contract.* `nrow()` equals
  `n_nodes * n_bins` exactly (one row per node per bin, inactive states
  included); `community` has no `NA`; `node` is a subset of `dn$nodes$name`.
- *Property — \(\omega\) limits.* `omega = 0` reproduces per-bin detection;
  `omega = 1e3` gives a single label per node across all bins
  (`flexibility == 0` for every node).
- *Property — \(\gamma\) monotonicity.* `n_communities` is non-decreasing in
  `gamma` over `c(0.5, 1, 2, 4)` (allow ties, assert no decrease).
- *Determinism:* two calls with the same `seeds` return identical frames
  (`expect_identical`), and the user's `.Random.seed` is unchanged afterwards.
- *Consistency with item 2:* `attr(result, "q")` equals
  `modularity(dn, membership = result, gamma =, omega =)` at `q`, to
  `sqrt(.Machine$double.eps)`.
- *Cross-package:* `skip_if_not_installed("multinet")`; the qualitative
  agreement table above, asserted as ordering not equality.
- *Snapshot:* `expect_snapshot(print(communities(school_contacts_dn, seeds =
  1:5)))`.

**Effort. L.** The optimiser is the largest single piece of new numerical code
in the package: never-materialised \(B\), incremental \(K_{c,s}\) bookkeeping,
aggregation on \(B\), multi-seed orchestration, consensus, plus the first RNG
discipline Dynet has ever needed, plus four S3 methods and an alluvial plot.
The Leiden refinement (Traag 2019) is explicitly **out of scope** for the
first cut — it would roughly double the work and cannot be delegated
(`cograph::community_leiden` is an igraph wrapper on a static graph). Note the
Louvain badly-connected-communities caveat in `@details` instead.

**Depends on.** Items 1 and 2; item 4 when `omega = 0`.

---

## 4. Match community labels across time bins

**Why.** Community labels are arbitrary per bin. If bin 3's "community 2" is
bin 4's "community 1", then flexibility, persistence and allegiance in item 6
measure relabelling noise and nothing else — teneto's own docstring warns
"It is important to make sure that the different community labels across time
points are not arbitrary." This is the subtle item and it must be solved
explicitly, not assumed away.

**The honest framing, which halves the problem.** When `omega > 0`, the
multislice optimisation of item 3 already returns labels that are globally
consistent across slices — the coupling *is* the matching, and it is done
inside the objective rather than as a post-hoc heuristic. Verified: on the
8-actor fixture, `multinet::glouvain_ml(omega = 1)` gave `cid` 0 to
{A,B,C,D} in **both** layers with no post-processing. Matching is needed only
for (a) `omega = 0` or per-bin detection, (b) comparing partitions from
different runs or different `gamma`, (c) importing an externally computed
partition. Item 4 exists for those cases and must document that `omega > 0`
does not need it.

**Proposed API.**

```r
match_communities(x, method = c("hungarian", "greedy"),
                  overlap = c("intersection", "jaccard"),
                  threshold = 0.1)
```

`x` is a `dynet_communities` frame (item 3) or any data frame with
`time`, `node`, `community`.

```r
match_communities(communities(dn, omega = 0))
match_communities(communities(dn, omega = 0), overlap = "jaccard", threshold = 0.3)
match_communities(external_partition, method = "greedy")
```

**Return.** Class `c("dynet_communities", "data.frame")` — the same shape as
item 3 so it drops straight into items 2 and 6 — with two extra columns:

| column | meaning |
|---|---|
| `session`, `time`, `node`, `active` | as item 3 |
| `community` | the **matched**, time-consistent label |
| `community_raw` | the original per-bin label, kept so the matching is auditable |
| `event` | `"born"`, `"persist"`, `"split"`, `"merge"`, `"dissolve"` — the lifecycle event of this state's community at this bin |

`as.data.frame(x, what = "events")` returns the community-level lifecycle
table: one row per community per bin, columns `time`, `community`, `event`,
`size`, `overlap` (the matched overlap score), `matched_from`.

**Algorithm.**

*Cost.* For consecutive bins \(s, s+1\), build the contingency matrix
\(N_{ab} = |C_a^{s} \cap C_b^{s+1}|\) over the nodes active in both bins.
`overlap = "jaccard"` normalises to
\(J_{ab} = N_{ab}/(|C_a^{s}| + |C_b^{s+1}| - N_{ab})\).

*Assignment — the default.* Maximum-weight bipartite matching (the
**Hungarian / Kuhn–Munkres** algorithm, Kuhn 1955; Munkres 1957) on the
rectangular \(|s| \times |s+1|\) matrix, padded to square with zero rows or
columns. This is the choice that matters: greedy "take the best overlap first"
matching is **order-dependent**, so two runs that differ only in row order can
return different labels — a determinism defect. Hungarian is unique up to
ties, and ties are broken by the smallest raw label so the result is fully
determined. Base-R implementation required: no assignment solver exists in
base R, `clue::solve_LSAP` would be a new dependency and is forbidden, so a
compact \(O(n^3)\) Jonker–Volgenant/Munkres routine (~110 lines) goes in
`R/communities.R` as `.assign_max()`.

*Chaining.* Walk bins left to right holding a label registry. A matched pair
whose overlap exceeds `threshold` inherits the earlier label (`event =
"persist"`); an unmatched bin-\(s{+}1\) community takes a fresh label
(`"born"`); an unmatched bin-\(s\) community is closed (`"dissolve"`). Two
bin-\(s{+}1\) communities both overlapping one bin-\(s\) community above
`threshold` is a `"split"`: the larger inherits, the other is born, and both
rows are marked. The mirror case is a `"merge"`. This is the
Greene–Doyle–Cunningham (2010) event taxonomy with an optimal rather than
greedy assignment step.

*Pitfalls.*
- Nodes inactive in one of the two bins must be excluded from \(N_{ab}\), or
  a community that merely goes quiet reads as dissolving. Use the `active`
  column.
- `threshold` on a Jaccard overlap and on a raw intersection mean different
  things; validate that `threshold` is in \([0,1]\) for `"jaccard"` and a
  non-negative count for `"intersection"`, with a named `.check()`.
- Label drift over long series: a community that dissolves at bin 10 and a
  structurally unrelated one born at bin 40 must not share a label. Registry
  labels are never recycled.
- Empty bin (no active nodes): carry the registry through unchanged, emit no
  events, do not error.
- `method = "greedy"` is offered for comparability with the published
  event-detection literature only; its docs must state it is order-dependent.

**References.**
- Kuhn, H. W. (1955). The Hungarian method for the assignment problem. *Naval
  Research Logistics Quarterly*, 2(1–2), 83–97.
- Munkres, J. (1957). Algorithms for the assignment and transportation
  problems. *Journal of the SIAM*, 5(1), 32–38.
- Jonker, R., & Volgenant, A. (1987). A shortest augmenting path algorithm for
  dense and sparse linear assignment problems. *Computing*, 38, 325–340.
- Greene, D., Doyle, D., & Cunningham, P. (2010). Tracking the evolution of
  communities in dynamic social networks. *ASONAM 2010*, 176–183. — the
  Jaccard-threshold event taxonomy.
- Palla, G., Barabási, A.-L., & Vicsek, T. (2007). Quantifying social group
  evolution. *Nature*, 446, 664–667. — birth/growth/merge/split/death of
  communities over time.
- Cazabet, R., & Rossetti, G. (2019). Challenges in community discovery on
  temporal networks. In *Temporal Network Theory*, Springer, 181–197. — the
  matching-vs-coupling trade-off; the method behind `tnetwork`.
- Bassett et al. (2013), *Chaos* 23:013142 — why arbitrary labels invalidate
  flexibility.

**Verify against.** `scipy.optimize.linear_sum_assignment` (installed,
confirmed) for `.assign_max()`: generate 200 random rectangular cost matrices
(seeded), compare the achieved total to scipy's optimum with `all.equal()`.
Optimal total is unique even when the assignment is not, so this is an exact
oracle. `tnetwork`'s `longitudinal_similarity` / `consecutive_sn_similarity`
would be the natural end-to-end oracle for the matching *pipeline*, but
**tnetwork is not importable on this machine** — `ModuleNotFoundError` on
python3, python3.13 and `/opt/homebrew/bin/python3`. No R equivalent exists.
So the pipeline is pinned by planted fixtures, not by an external run, and
that limitation must be stated in the test file.

**Tests** (`tests/testthat/test-community-matching.R`)
- *Error path:* `expect_error(match_communities(data.frame(a = 1)), class =
  "dynet_bad_input")`; `expect_error(match_communities(x, overlap =
  "jaccard", threshold = 2), class = "dynet_bad_input")`.
- *Invariant — pure relabelling is undone.* Take a partition with constant
  membership over 5 bins, randomly permute the labels **within each bin**, run
  `match_communities()`, and require the result to be constant over time, i.e.
  `flexibility` (item 6) is exactly `0` for every node. This is the defining
  property of the item and it must be tested from at least five permutation
  seeds.
- *Invariant — idempotence.* `match_communities(match_communities(x))` equals
  `match_communities(x)`.
- *Invariant — order independence.* Row-shuffling the input frame does not
  change the output (this is what fails for `method = "greedy"`, so assert it
  for `"hungarian"` and assert with a comment that `"greedy"` is exempt).
- *Property — planted split.* Fixture where one community splits at bin 4:
  exactly one `event == "split"` row group at bin 4, and the larger fragment
  keeps the label.
- *Property — planted dissolve/birth.* A community that empties at bin 3 and a
  disjoint one appearing at bin 7 receive different labels.
- *Assignment oracle:* `skip_on_cran()`; the scipy comparison above, run as a
  fixture of pre-computed optima checked into `tests/testthat/fixtures/` so
  the test does not need python at check time.

**Effort. M.** The Hungarian routine in base R is the bulk (~110 lines) and is
self-contained and testable against an exact oracle. The chaining registry and
the event taxonomy are straightforward bookkeeping. Roughly 250 lines plus
tests.

**Depends on.** Item 3 (for its input shape); the assignment routine itself
depends on nothing.

---

## 5. Measure how much the partition changed between consecutive bins

**Why.** "Did the community structure reorganise, and when?" is a different
question from "who is with whom", and it is answered by a label-invariant
comparison of consecutive partitions — no matching needed, which makes this
the cheapest useful output in the whole stage. Prior art is
`tnetwork::consecutive_sn_similarity`, `tnetwork::longitudinal_similarity`
and `multinet::nmi_ml` / `omega_index_ml`, none of which exists in R for a
temporal network.

**Proposed API.**

```r
community_change(x,
                 measure = c("nmi", "ari", "vi", "split_join",
                             "jaccard", "omega_index"),
                 against = c("previous", "first", "all"))
```

`x` is a `dynet_communities` frame from item 3 or 4.

```r
community_change(communities(dn))
community_change(communities(dn), measure = c("nmi", "ari"))
community_change(communities(dn), measure = "ari", against = "all")
```

`against = "all"` gives the full bin-by-bin matrix in the same long shape
`similarity()` already uses (`time`, `other`, `measure`, `value`), so the two
verbs plot with the same heatmap code.

**Return.** A `dynet_metric` at `level = "graph"`. For `against =
"previous"` or `"first"`: one row per time bin per measure, columns
`session`, `time`, `measure`, `value`; the first bin is `NA` for
`"previous"` because there is no predecessor, and that `NA` is meaningful and
documented, not filled. For `against = "all"`: one row per ordered pair of
bins per measure, columns `session`, `time`, `other`, `measure`, `value`.

**Algorithm.** All six statistics come from the \(r \times c\) contingency
table \(n_{ab}\) of two partitions of the same node set, restricted to nodes
active in both bins.

- **NMI** (Danon et al. 2005), normalised by the arithmetic mean:
  \(I = \sum_{ab}\frac{n_{ab}}{N}\log\frac{n_{ab}N}{a_b}\) with
  \(a_\cdot, b_\cdot\) the margins;
  \(\mathrm{NMI} = 2I/(H_1 + H_2)\). Define \(0\log 0 = 0\) explicitly; use
  `log()` on ratios computed once, and guard \(H_1 + H_2 = 0\) (both
  partitions trivial) by returning `1` with a documented convention.
- **ARI** (Hubert & Arabie 1985):
  \(\frac{\sum_{ab}\binom{n_{ab}}{2} - E}{\tfrac12[\sum_a\binom{a_\cdot}{2} + \sum_b\binom{b_\cdot}{2}] - E}\),
  \(E = \frac{\sum_a\binom{a_\cdot}{2}\sum_b\binom{b_\cdot}{2}}{\binom{N}{2}}\).
  Use `lchoose()`/exact integer arithmetic for \(\binom{n}{2} = n(n-1)/2\);
  never `choose()` in a loop.
- **VI** (Meilă 2007): \(H_1 + H_2 - 2I\). Not normalised by default; report
  it in nats and say so.
- **split-join** (van Dongen 2000): \(2N - \sum_a\max_b n_{ab} - \sum_b\max_a n_{ab}\).
- **Jaccard** on co-classification pairs: pairs together in both, over pairs
  together in at least one.
- **Omega index** (Collins & Dent 1988; Gates & Ahn 2019): agreement on the
  *number* of communities each pair shares, chance-corrected — the only one of
  the six that generalises to overlapping communities, which is why multinet
  ships it.

*Pitfalls.*
- Nodes inactive in one bin must be dropped from **both** partitions before
  the table is built, or a quiet node reads as a reorganisation. Report
  `n_compared` as an attribute.
- Fewer than two nodes active in both bins ⇒ every statistic is undefined;
  return `NA` and count it, do not divide by zero.
- \(0\log 0\): compute the entropy sum over non-zero cells only, chosen by
  the cell value, not by `na.rm = TRUE`.
- Multiplicity: with `T` bins there are `T-1` comparisons and a user will read
  them as a series. The verb reports values, not p-values, so no correction is
  needed — but if a `permutations =` argument is ever added, `p.adjust(method
  = "BH")` is required and must be named in the output.
- These statistics are label-invariant by construction, so item 4 is **not** a
  dependency. Say so in `@details`; it is a common misunderstanding.

**References.**
- Danon, L., Díaz-Guilera, A., Duch, J., & Arenas, A. (2005). Comparing
  community structure identification. *J. Stat. Mech.*, P09008.
- Hubert, L., & Arabie, P. (1985). Comparing partitions. *Journal of
  Classification*, 2, 193–218.
- Meilă, M. (2007). Comparing clusterings — an information based distance.
  *Journal of Multivariate Analysis*, 98(5), 873–895.
- van Dongen, S. (2000). *Performance criteria for graph clustering and Markov
  cluster experiments.* CWI Technical Report INS-R0012.
- Collins, L. M., & Dent, C. W. (1988). Omega: a general formulation of the
  Rand index of cluster recovery suitable for non-disjoint solutions.
  *Multivariate Behavioral Research*, 23(2), 231–242.
- Gates, A. J., & Ahn, Y.-Y. (2019). Element-centric clustering comparison
  unifies overlaps and hierarchy. *Scientific Reports*, 9, 8574.
- Vinh, N. X., Epps, J., & Bailey, J. (2010). Information theoretic measures
  for clusterings comparison. *JMLR*, 11, 2837–2854. — chance correction.
- Cazabet, R. *tnetwork* 1.2, `longitudinal_similarity`,
  `consecutive_sn_similarity`, `onmi`.

**Verify against.** `igraph::compare()`, reached via
`cograph::compare_communities()` — **run this session** on
`a = c(1,1,1,2,2,2)`, `b = c(1,1,2,2,2,2)`:

```
vi = 0.6931472   nmi = 0.478704   split.join = 2
rand = 0.6666667   adjusted.rand = 0.3243243
```

Freeze those five as fixtures; they pin every normalisation choice above.
Note that `cograph::compare_communities()` **requires igraph** (its body is
`igraph::compare(...)`) and igraph is only Suggested, so Dynet must implement
these in base R and use cograph only as a `skip_if_not_installed()` oracle.
For the omega index: `multinet::omega_index_ml` — run this session, giving
`0.3236994` between the `omega = 1` and `omega = 0` partitions of the 8-actor
fixture (`nmi_ml` gave `0.5202157` on the same pair). `tnetwork::onmi` is
**not reachable** (module not installed) and is cited from the literature only.

**Tests** (`tests/testthat/test-community-change.R`)
- *Error path:* `expect_error(community_change(data.frame(x = 1)), class =
  "dynet_bad_input")`; `expect_error(community_change(x, measure = "cosine"),
  ...)` from `match.arg()`.
- *Calibration:* the five igraph values above, exact to
  `sqrt(.Machine$double.eps)`.
- *Invariant — identity.* Comparing a partition with itself gives
  `nmi = 1`, `ari = 1`, `jaccard = 1`, `omega_index = 1`, `vi = 0`,
  `split_join = 0`.
- *Invariant — label permutation.* Randomly relabelling either partition
  changes nothing, from five seeds. This is the property that makes item 4
  unnecessary here.
- *Invariant — symmetry.* `value(s, r) == value(r, s)` for every measure under
  `against = "all"`.
- *Invariant — ARI chance level.* Two independent uniform random partitions of
  200 nodes into 4 blocks give a mean ARI within `0.02` of `0` over 200
  replicates from a fixed seed (a chance-correction test that NMI would fail,
  which is the point of shipping both).
- *Edge case:* one bin with a single active node returns `NA`, not `NaN`, and
  does not error.
- *Cross-package:* `skip_if_not_installed("multinet")` for `omega_index`.

**Effort. M.** Six statistics from one contingency table is maybe 150 lines,
but they are exactly the kind of formula where a normalisation convention
silently differs from the reference, so the calibration fixtures are the real
work. No optimisation, no randomness.

**Depends on.** Item 3. **Not** item 4.

---

## 6. Measure community trajectories per node

**Why.** Once labels are consistent, the interesting quantities are about
individual nodes over time: how often a node changes group (flexibility), how
many distinct groups it has belonged to (promiscuity), how reliably it stays
put (persistence), how often two nodes co-occur (allegiance), and how tightly
a node sticks to its own reference group versus visiting others (recruitment,
integration). This whole family is what learning analytics and network
neuroscience actually report, and no R package computes any of it.

**Proposed API.**

```r
community_trajectory(x,
                     measure = c("flexibility", "promiscuity", "persistence",
                                 "recruitment", "integration"),
                     reference = NULL)
```

```r
community_trajectory(communities(dn))
community_trajectory(communities(dn), measure = c("flexibility", "persistence"))
community_trajectory(communities(dn), measure = "recruitment", reference = "class")
```

`reference` names a **node attribute already on `dn`** (carried through
`projection()` into item 3's frame) giving each node's static group;
`recruitment` and `integration` are undefined without one and must raise if
asked for with `reference = NULL`. Passing a column name rather than a vector
is the point — the caller never builds an aligned vector by hand.

Allegiance is pairwise, not per node, so it gets its own accessor rather than
its own verb:

```r
as.data.frame(community_trajectory(x), what = "allegiance")
```

returning `node`, `other`, `value` — one row per ordered node pair, the tidy
form of teneto's matrix.

**Return.** A `dynet_metric` at `level = "node"`, one row per **node per
measure**, columns `session`, `node`, `measure`, `value`. No `time` column:
every measure in this family is a summary over the whole series. Persistence
is also available per bin and globally through the accessor:
`as.data.frame(x, what = c("node", "time", "global", "allegiance"))` — an
argument, never a `$`.

**Algorithm.** Transcribed from teneto 0.5.3 source, read this session, so
the conventions match exactly. Let \(C\) be the `n x T` matrix of matched
labels.

- **flexibility** \(= \frac{1}{T-1}\sum_{t=2}^{T}\mathbb{1}[C_{it} \ne C_{i,t-1}]\).
  Undefined for `T = 1`; raise `dynet_empty_result`.
- **promiscuity** \(= \frac{|\{\,C_{i\cdot}\,\}| - 1}{|\{\,C\,\}| - 1}\) —
  numerator is the node's distinct label count minus one, denominator the
  **global** distinct label count minus one. A node in one community scores
  `0`, a node in every community scores `1`. Note teneto's exact denominator;
  it is global, not per node. Guard \(|\{C\}| = 1\) (one community overall) —
  teneto divides by zero there; Dynet must return `0` with a documented
  convention and a `note` on the result.
- **persistence**, three granularities:
  global \(=\operatorname{mean}(C_{\cdot,1:T-1} = C_{\cdot,2:T})\);
  per node \(=\) the row mean of the same;
  per bin \(=\) the column mean, with `NA` at \(t = 1\).
- **allegiance** \(P_{ij} = \frac{1}{T}\sum_t \mathbb{1}[C_{it} = C_{jt}]\),
  diagonal `NA`. Note teneto divides by `T`, the number of bins, not by the
  number of bins where both are active — replicate that and document it.
- **recruitment**\(_i = \operatorname{mean}_{j: R_j = R_i, j \ne i} P_{ij}\),
  where \(R\) is `reference`.
- **integration**\(_i = \operatorname{mean}_{j: R_j \ne R_i} P_{ij}\).

*Pitfalls.*
- **Label arbitrariness is the whole risk.** If `x` came from `communities(dn,
  omega = 0)` without item 4, flexibility measures nothing. The verb must
  check `attr(x, "omega") > 0 || isTRUE(attr(x, "matched"))` and otherwise
  raise `errorCondition(class = "dynet_unmatched_labels")` naming
  `match_communities()`. This guard is the reason item 6 depends on item 4.
- Inactive states: teneto has no concept of them. Dynet does. Default is to
  count an inactive state as carrying its coupled label forward (consistent
  with `projection()`'s waiting convention) — document it, and record
  `n_inactive_states` on the result so the reader can judge.
- \(T = 1\): flexibility and persistence undefined ⇒ classed error, not `NaN`.
- `reference` naming a node attribute that does not exist ⇒
  `dynet_bad_input` listing the attributes that do.
- The allegiance matrix is \(n^2\); for 5,000 nodes it is 200 MB and the tidy
  long form is 25 million rows. Cap it: compute allegiance only when asked
  for, and raise a classed error above a documented node count rather than
  exhausting memory silently.
- No randomness; nothing to seed. If `x` came from a stochastic run, its
  `stability_ari` should be reported in this result's `note` so a trajectory
  is never read without the stability of the partition it rests on.

**References.**
- Bassett, D. S., Wymbs, N. F., Porter, M. A., Mucha, P. J., Carlson, J. M., &
  Grafton, S. T. (2011). Dynamic reconfiguration of human brain networks
  during learning. *PNAS*, 108(18), 7641–7646. — flexibility.
- Papadopoulos, L., Puckett, J. G., Daniels, K. E., & Bassett, D. S. (2016).
  Evolution of network architecture in a granular material under compression.
  *Physical Review E*, 94(3), 032908. — promiscuity.
- Bassett et al. (2013), *Chaos*, 23(1), 013142. — allegiance.
- Bassett, D. S., Yang, M., Wymbs, N. F., & Grafton, S. T. (2015).
  Learning-induced autonomy of sensorimotor systems. *Nature Neuroscience*,
  18(5), 744–751. — recruitment and integration.
- Mattar, M. G., Cole, M. W., Thompson-Schill, S. L., & Bassett, D. S. (2015).
  A functional cartography of cognitive systems. *PLoS Computational Biology*,
  11(12), e1004533.
- Bazzi et al. (2016), *Multiscale Modeling & Simulation*, 14(1), 1–41. —
  persistence.
- Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to
  temporal network theory. *Network Neuroscience*, 1(2), 69–99. — teneto.

**Verify against.** `teneto.communitymeasures` 0.5.3, **run this session**.
Fixture: 6 nodes x 4 bins, `C` rows
`(0,0,0,0), (0,0,0,0), (0,0,0,0), (1,1,1,1), (1,1,1,1), (0,0,1,1)` — node 6
defects at bin 3. Static reference `R = (0,0,0,1,1,0)`.

```
flexibility        0, 0, 0, 0, 0, 0.333333
promiscuity        0, 0, 0, 0, 0, 1
persistence global 0.944444
persistence node   1, 1, 1, 1, 1, 0.666667
persistence time   NA, 1, 0.833333, 1
recruitment        0.833333, 0.833333, 0.833333, 1, 1, 0.5
integration        0, 0, 0, 0.125, 0.125, 0.5
allegiance   [ NA  1   1   0   0  0.5 ]
             [ 1   NA  1   0   0  0.5 ]
             [ 1   1   NA  0   0  0.5 ]
             [ 0   0   0   NA  1  0.5 ]
             [ 0   0   0   1   NA 0.5 ]
             [0.5 0.5 0.5 0.5 0.5  NA ]
```

Check these into `tests/testthat/fixtures/teneto-communitymeasures.rds` so the
test needs no python. This is a genuine cross-language equivalence check and
should be logged in `LEARNINGS.md` per the project's translation rule.

**Tests** (`tests/testthat/test-community-trajectory.R`)
- *Error path:* `expect_error(community_trajectory(x_unmatched), class =
  "dynet_unmatched_labels")` — the guard that makes the whole item meaningful;
  `expect_error(community_trajectory(x, measure = "recruitment"), class =
  "dynet_bad_input")` when `reference` is `NULL`;
  `expect_error(community_trajectory(x_one_bin), class =
  "dynet_empty_result")`.
- *Equivalence:* every number in the teneto table above, to
  `sqrt(.Machine$double.eps)`.
- *Invariant — relabelling.* Applying a global label permutation to `C`
  changes nothing in any measure (allegiance included).
- *Invariant — node permutation.* Permuting the node order permutes the output
  rows and nothing else; the allegiance frame is unchanged after reordering by
  name.
- *Invariant — bounds.* Flexibility, promiscuity, persistence, allegiance,
  recruitment and integration all lie in \([0,1]\) on 100 random partitions
  from a fixed seed.
- *Property — flexibility endpoints.* A constant partition gives flexibility
  exactly `0` for every node; a partition where every node changes label at
  every bin gives exactly `1`.
- *Property — allegiance symmetry.* \(P_{ij} = P_{ji}\) for every pair, and
  the diagonal is `NA`.
- *Property — recruitment/integration decomposition.* For a reference with two
  equal groups, the mean of recruitment and integration weighted by group
  sizes equals the mean off-diagonal allegiance.
- *Break-it check:* flip the persistence normaliser from `T-1` to `T` once and
  confirm the equivalence test fails (the project rule requires demonstrating
  the test can fail).

**Effort. M.** Six formulas, all short and all with exact reference values
already in hand. The work is the label-arbitrariness guard, the inactive-state
convention, the allegiance memory cap, and the accessor with four `what`
values. Roughly 200 lines plus a substantial equivalence test.

**Depends on.** Items 3 and 4.

---

## 7. Detect temporal phases by clustering the between-bin similarity

**Scope decision: IN SCOPE, and it belongs here rather than as its own
stage — but as its own item, after the community items, and only in its
distance-clustering form.**

The reasoning, stated plainly. Two very different things are called "regime
detection". phasik's method is: build a distance matrix between time slices,
hierarchically cluster it, cut the dendrogram, and call the resulting
contiguous blocks *phases*. Dynet is **already one function short of that** —
`similarity(dn, method =)` returns exactly that matrix, tidy, today, and its
`plot()` already draws it. Adding phases is one clustering call on an object
the package already produces; leaving it out would be leaving free ground
unoccupied. NetworkChange's method is different in kind: a Bayesian
hidden-Markov changepoint model over a tensor decomposition, requiring MCMC,
convergence diagnostics, multiple chains and \(\hat R\). That is a modelling
paradigm Dynet has deliberately stayed out of (ECOSYSTEM.md: "Worth *not*
doing: inferential modelling"), it would need new dependencies, and
NetworkChange already does it well. **Recommendation: ship the phasik-style
verb; do not reimplement NetworkChange; cite it in `@seealso`.**

**Why.** A user who sees the similarity heatmap immediately asks "so how many
regimes are there and where do they start?" and today has to answer it by
eye. Phases are also the natural `reference` argument for item 6's
recruitment and integration.

**Proposed API.**

```r
phases(dn, k = NULL,
       method = c("jaccard", "overlap", "hamming", "cosine", "pearson"),
       linkage = c("ward.D2", "average", "complete"),
       contiguous = TRUE,
       k_max = 10L,
       sessions = c("bounded", "collapse", "separate"),
       start = NULL, end = NULL, step = NULL, window = NULL)
```

```r
phases(dn)
phases(dn, k = 3, method = "cosine")
phases(dn, k_max = 6, contiguous = FALSE)
```

`k = NULL` chooses the number of phases by the silhouette maximum over
`2:k_max` and **reports the whole profile**, so the choice is visible and the
sensitivity to it is checkable — the project rule on consequential arbitrary
choices.

**Return.** Class `c("dynet_phases", "data.frame")`, one row per **time bin**:

| column | meaning |
|---|---|
| `session` | present only when the network has sessions |
| `time` | bin start |
| `phase` | integer phase label, `1..k`, non-decreasing when `contiguous = TRUE` |
| `boundary` | logical, is this bin the first of its phase |
| `silhouette` | this bin's silhouette width under the chosen `k` |

`as.data.frame(x, what = c("bins", "profile", "phases"))`: `"profile"` gives
`k`, `silhouette_mean`, `within_ss` over `2:k_max` — the sensitivity table;
`"phases"` gives one row per phase with `phase`, `start`, `end`, `n_bins`,
`cohesion`. `print` names the boundaries in time units; `plot` overlays the
phase blocks on the `similarity()` heatmap.

**Algorithm.**
1. \(D = 1 - S\) from `similarity(dn, method =)` (for `"hamming"`, which is
   already a distance, \(D = S\) normalised by the number of possible ties —
   handle explicitly, because `similarity()`'s hamming diagonal is `0` while
   every other method's is `1`; getting this backwards silently inverts the
   result).
2. `stats::hclust(as.dist(D), method = linkage)`, then `stats::cutree(k)`.
   Base R, no new dependency. `ward.D2` is the default because \(D\) is a
   proper distance under it.
3. `contiguous = TRUE` (the default, and the temporally meaningful one)
   constrains phases to be time-contiguous. Do this by dynamic programming,
   not by hacking the dendrogram: partition `1..T` into `k` contiguous
   segments minimising total within-segment sum of squared distances. This is
   exactly Fisher's (1958) optimal one-dimensional partition and is
   \(O(k T^2)\) with a prefix-cost table — for the bin counts Dynet produces
   (tens to low hundreds) that is instant, and unlike `cutree()` it is
   **deterministic and globally optimal**, so no seeds are needed.
4. `contiguous = FALSE` uses plain `cutree()` and can return a phase that
   recurs — appropriate for cyclic data (weekday/weekend), and the docs should
   say that is when to use it.
5. Silhouette computed in base R from \(D\) directly (Rousseeuw 1987); it is
   twelve lines and does not justify a dependency.

*Pitfalls.*
- Fewer than three bins ⇒ no phase structure; raise
  `dynet_empty_result` (`similarity()` already raises for `< 2`).
- `k >= T` ⇒ every bin its own phase; reject with `dynet_bad_input` rather
  than returning a degenerate answer.
- Silhouette is undefined for `k = 1` and for a singleton cluster; return `NA`
  for that bin, never `0`, and exclude singletons from the mean with an
  explicit filter rather than `na.rm = TRUE`.
- `"pearson"` similarity can be negative, so \(1 - S \in [0, 2]\); that is a
  valid distance, but document the range so a reader does not expect
  \([0,1]\).
- **No randomness anywhere in this item**, by design: `hclust` is
  deterministic and the contiguous partition is exact. That is a feature —
  say in `@details` that unlike item 3 no seeding is required, so a user knows
  the difference is intentional.

**References.**
- Fisher, W. D. (1958). On grouping for maximum homogeneity. *JASA*, 53(284),
  789–798. — the optimal contiguous partition.
- Rousseeuw, P. J. (1987). Silhouettes: a graphical aid to the interpretation
  and validation of cluster analysis. *Journal of Computational and Applied
  Mathematics*, 20, 53–65.
- Murtagh, F., & Legendre, P. (2014). Ward's hierarchical agglomerative
  clustering method: which algorithms implement Ward's criterion? *Journal of
  Classification*, 31, 274–295. — why `ward.D2`.
- Lucas, M., Morris, A., Townsend-Teague, A., Tichit, L., Habermann, B. H., &
  Barrat, A. (2023). Inferring cell cycle phases from a partially temporal
  network of protein interactions. *Cell Reports Methods*, 3(3), 100397. —
  phasik's method.
- Park, J. H., & Sohn, Y. (2020). Detecting structural changes in longitudinal
  network data. *Bayesian Analysis*, 15(1), 133–157. — NetworkChange, cited as
  the alternative paradigm and explicitly not reimplemented.

**Verify against.** phasik 1.3.4 would be the direct oracle but is **not
importable on this machine** (`ModuleNotFoundError` on every interpreter
checked), so it is literature-only and the test file must say so.
NetworkChange answers a different question and is not a value oracle.
Reachable oracles: `stats::hclust` + `stats::cutree` pin steps 2 and 4 exactly
(they are base R, so this is really an internal-consistency check);
`cluster::silhouette` is not installed and is not a dependency, so the
silhouette is pinned by a hand-computed 4-point fixture instead; the Fisher
contiguous partition is pinned by brute-force enumeration over all
\(\binom{T-1}{k-1}\) cut sets for `T <= 12`, which is an exact oracle and the
strongest test in this item.

**Tests** (`tests/testthat/test-phases.R`)
- *Error path:* `expect_error(phases(dn, k = 1), class = "dynet_bad_input")`;
  `expect_error(phases(dn, k = 99), class = "dynet_bad_input")`;
  `expect_error(phases(dn_two_bins), class = "dynet_empty_result")`.
- *Invariant — planted regime recovered.* A network that is one clique for
  bins 1–10 and a different, disjoint clique for bins 11–20 must return
  `k = 2` with the boundary at bin 11, for every `method` and every `linkage`.
- *Invariant — exactness of the contiguous partition.* For `T <= 12`,
  brute-force every contiguous `k`-partition and assert the verb's total cost
  equals the minimum. Run over 50 random distance matrices from a fixed seed.
- *Invariant — contiguity.* With `contiguous = TRUE`, `phase` is
  non-decreasing in `time` for every input, checked over 100 random matrices.
- *Invariant — monotone refinement.* `k + 1` phases refine `k` phases under
  `contiguous = TRUE` (every `k+1` boundary set contains… — assert the weaker
  and true property that within-segment cost is non-increasing in `k`).
- *Property — determinism.* Two calls return `expect_identical` results and
  the user's `.Random.seed` is untouched.
- *Sensitivity:* `as.data.frame(phases(dn), what = "profile")` has one row per
  `k` in `2:k_max` and no `NA` in `silhouette_mean` except where a singleton
  cluster forced one.
- *Snapshot:* `expect_snapshot(print(phases(school_contacts_dn)))`.

**Effort. M.** `hclust`/`cutree` are free; the Fisher dynamic program (~50
lines) and the base-R silhouette (~15) are the new numerics, and both have
exact oracles. The plot overlay on the existing `similarity()` heatmap and the
four-way accessor are the rest.

**Depends on.** Nothing in this stage — it rides on the existing
`similarity()`. It can be built first if a quick win is wanted. It composes
with item 6 (a phase label is a natural `reference =`).

---

## Summary

| # | Item | Effort | Depends on |
|---|---|---|---|
| 1 | Record coupling on the projection; internal ordinal supra | S | — |
| 2 | Multislice modularity as a quality function | M | 1 |
| 3 | `communities()` — generalized Louvain, multi-seed | **L** | 1, 2 (4 when `omega = 0`) |
| 4 | `match_communities()` — Hungarian label matching | M | 3 |
| 5 | `community_change()` — partition comparison over time | M | 3 |
| 6 | `community_trajectory()` — flexibility … integration | M | 3, 4 |
| 7 | `phases()` — regime detection by slice clustering | M | — (rides on `similarity()`) |

Total: one L and five M plus one S. The substrate really is built — but not
by `cograph::supra_adjacency()`, whose coupling is wrong for time, and not by
`cograph::communities()`, which needs a Suggested igraph and optimises a
different objective. `projection()` is the asset; the optimiser is the work.

New dependencies proposed: **none**. igraph, multinet, cograph's community
functions, scipy and teneto appear only as `skip_if_not_installed()` oracles
and as fixture generators whose output is checked into
`tests/testthat/fixtures/`.

*Prepared 2026-08-28 against Dynet 0.3.53. Every measured value quoted above
was produced by running the named tool in this session; the two
non-reproducible items (tnetwork, phasik) are marked as such wherever they
appear.*
