# Verified substrate — what Dynet can already delegate to

Run and confirmed on 2026-08-28 in this session. These findings change the
effort estimates in TODO.md and override any spec that assumes the work is
greenfield.

## CORRECTED — cograph does NOT give you temporal communities for free

An earlier draft of this file claimed cograph's 25 community functions plus
`supra_adjacency()` meant only the quality function was missing. **That was
wrong on two counts, both re-measured here.**

### 1. `supra_adjacency()` builds the wrong coupling for time

Three identical 2-node layers, `omega = 0.4`, `coupling = "diagonal"`:

         L1_A L1_B L2_A L2_B L3_A L3_B
    L1_A  0.0  1.0  0.4  0.0  0.4  0.0     <- L1_A--L3_A = 0.4
    L1_B  1.0  0.0  0.0  0.4  0.0  0.4
    L2_A  0.4  0.0  0.0  1.0  0.4  0.0
    L2_B  0.0  0.4  1.0  0.0  0.0  0.4
    L3_A  0.4  0.0  0.4  0.0  0.0  1.0
    L3_B  0.0  0.4  0.0  0.4  1.0  0.0

Slice 1 is coupled to slice 3 at full strength. That is **categorical**
(all-to-all) coupling, appropriate for aspect layers. Time needs **ordinal**
coupling — a chain joining consecutive slices only. `supra_adjacency()` is
therefore unusable as-is for temporal multislice modularity.

**Dynet's own `projection()` already has this right.** Its identity arcs are
`forward_unconditional_waiting_consecutive_slices` — a chain — and `omega`
passes through to their weights. Build on `projection()`, not on
`supra_adjacency()`.

### 2. cograph's community functions are igraph wrappers, and igraph is a *Suggest*

`cograph::community_louvain` body, line 10:

    result <- igraph::cluster_louvain(g, weights = w, resolution = resolution)

Confirmed by `packageDescription("cograph")`: igraph is in **Suggests**, not
Imports (`Depends: FALSE, Imports: FALSE, Suggests: TRUE`). So every one of
those 25 functions is conditionally available, and anything Dynet delegates to
them inherits that guard. Dynet already Suggests igraph, so this is workable —
but it must be `requireNamespace()`-guarded at every use site, not assumed.

Worse, the objective is wrong even when igraph is present: running Leiden or
Louvain on a supra-graph optimises **standard modularity with supra-degrees
and a global 2m**, whereas Mucha's multislice modularity uses slice-local
degrees k_is and slice-local 2m_s, and must not subtract a null term from the
interlayer identity arcs at all.

### What can still be reused

- `compare_communities(method = c("vi","nmi","split.join","rand","adjusted.rand"))`
  — partition similarity between consecutive bins, genuinely reusable.
- `community_consensus(n_runs = 100, seed =)` — the consensus/stability pattern
  is the right one to follow, and satisfies the multiple-seeds rule.
- `cograph::layout_spring(initial =, anchor_strength =)` — a seeded layout
  engine already in Imports, which removes the need for a new layout dependency
  in the animation work.

### A real bug found on the way

`R/projection.R:293` records `identity_weight = 1` in the result metadata while
the identity arcs themselves carry `omega`. `omega` is never stored in `meta`.
Fix before building anything on top of `projection()`.

## Other verified facts that override assumptions

- `cograph::to_igraph(dn)` **works** on a `dynet` — it inherits
  `cograph_network`. igraph export is available but undiscoverable from
  Dynet's own surface. That is a Rule 0 documentation/API problem, not a
  missing capability.
- `paths()` **already reports** `median latency` and `max latency` in its
  summary. Reachability latency is not absent.
- `plot(type = "snapshots")` is ndtv's filmstrip; `type = "layers"` / `"stack"`
  cover timePrism. Those are not gaps.
- `metrics("efficiency")` and `metrics("diameter")` return **per-bin static**
  values. Temporal efficiency and temporal diameter genuinely are absent.
- `burstiness(measure = "events")` returns event **counts**, not the
  inter-event time distribution. The distribution is computed internally and
  never returned.
- `R/paths.R:1608` uses `criterion = "foremost_then_shortest"` — one criterion
  only. `MATH_ROADMAP.md` admits "still foremost cost rather than fastest cost".
- `as_dynet()` is import-only; there is no export verb.
- `add_nodes()` documents "optional **static** attributes" — no temporally
  extended attributes.

## CORRECTION — the Python oracles ARE reachable, on two different interpreters

Stage 1 and Stage 4 both recorded `networkx_temporal`, `tnetwork` and `phasik`
as "not installed" and downgraded their verification plans to literature-only.
That is true of the **system** `python3` and false overall. The libraries are
split across two interpreters, and both were re-checked on 2026-08-28:

| Interpreter | Importable |
|---|---|
| `python3` (system) | teneto 0.5.3, dynetx 0.3.2, pathpy 3.0.0a2, raphtory 0.17.0 |
| the venv below | networkx-temporal 1.4.4, tnetwork 1.2, phasik 1.3.4, DyNetworkX 0.4.2, TGX |

The venv needs two workarounds, both already built:

    VENV=/private/tmp/claude-503/-Users-mohammedsaqr-Documents-Github-temporal/6679738e-87e5-48fc-950f-b70d8e0fd33d/scratchpad/venv
    SHIM=/private/tmp/claude-503/-Users-mohammedsaqr-Documents-Github-temporal/6679738e-87e5-48fc-950f-b70d8e0fd33d/scratchpad/shim          # contains turtle.py -> "import pandas as pd"
    PYTHONPATH=$SHIM MPLBACKEND=Agg $VENV/bin/python -c "import networkx_temporal"

The `turtle` shim is required because networkx-temporal 1.4.4 ships
`from turtle import pd` in `utils/convert/pandas.py`, which drags in tkinter.
`tnetwork` additionally needs `setuptools<81` for `pkg_resources`.

**Consequences for the specs.**

- Stage 1 item B2 claimed no verified reference exists for the dynamic SBM.
  It does. Confirmed signature:

      dynamic_stochastic_block_model(B, z, d=None, d_out=None, t=1,
          transition_matrix=None, fix_transition_prob=False,
          directed=False, multigraph=True, isolates=True, selfloops=False,
          create_using=None, distribution=['poisson','bernoulli'],
          sparse=None, seed=None) -> TemporalGraph

  It takes an explicit block matrix `B`, a membership vector `z`, a
  `transition_matrix` for drifting membership and a `seed`. That is a usable
  distributional oracle for the `"block"` model — exact per-draw equivalence
  is still impossible across RNG streams, so compare distributions, not draws.
- Stage 4 marked tnetwork and phasik literature-only. Both import. Their
  dynamic-community and phase-clustering results are reachable as fixtures.

These are not blocking corrections — a hand-computed fixture is never wrong —
but a spec that says "no reference exists" when one does will send an
implementer down the weaker path.

## CORRECTION — MATH_ROADMAP's risk list is stale in two places

`MATH_ROADMAP.md` lines 69–72 list known weaknesses. Two of them describe a
pre-0.3.53 state and must not be re-specified as work:

**Risk #7 — "Temporal betweenness counts one arbitrary earliest-arrival tree
rather than distributing dependency over all equally optimal journeys."**
Already fixed. `.temporal_betweenness_values()` distributes exact dependency
over the whole tied family via prefix x suffix counts on the appearance DAG.
Verified on a diamond with two tied two-hop journeys:

    d  <- data.frame(from = c("A","A","B","C"), to = c("B","C","D","D"),
                     time = c(0, 0, 1, 1))
    dn <- dynet(d, format = "contact", directed = TRUE)
    paths(dn, from = "A")           # D: n_hops 2, n_paths 2
    dyn_centrality(dn, measure = "betweenness", scope = "temporal")
    #   node     measure value
    # 2    B betweenness   0.5     <- distributed, not 1/0
    # 3    C betweenness   0.5

The real remaining weakness is narrower: the optimal family is hard-wired to
shortest-foremost, so Dynet reports one of at least five distinct betweenness
quantities and gives the user no way to name which. That is Stage 2 item A6,
not a bug.

**Risk #6 — "Temporal closeness drops every reachable target whose latency is
zero."** Also stale, and its fix is what created defect D1. The current
`.temporal_closeness_values()` selects targets on `is.finite(arrival)`, not on
`latency > 0`, so zero-latency targets are *included* — which is why
`1 / mean(latency)` divides by zero and returns `Inf`. Fixing #6 introduced
D1. Whoever fixes D1 should update both roadmap entries in the same change.

**Also corrected: reach is criterion-invariant.** Every criterion optimises
over the same feasible journey set, and that set is nonempty exactly when the
target is reachable. `MATH_ROADMAP` P07 already says so. So adding `criterion`
to `dyn_reachability()` is inert unless cost-valued measures (latency,
duration, hops) are added alongside it — Stage 2 item A7.

**And: "shortest" and "min_hops" are currently the same quantity.** Dynet
charges one scalar `traversal_time` per hop, so the transition sum is exactly
`delta x hops` and the two orderings coincide for every delta >= 0. They
separate only once a per-contact cost exists (Stage 2 item A3b).
