# Dynet TODO — the non-inference capability gaps, staged

Dynet 0.3.53. Derived from `ECOSYSTEM.md`, which enumerated 3,556 functions
across 34 R and Python packages, and from `ecosystem/VERIFIED-SUBSTRATE.md`,
which records what was confirmed by running code rather than assumed.

Inference (paradigm two — RSiena, tergm, relevent, goldfish, PAFit,
NetworkChange) is deliberately **out of scope**. So is diffusion, which
netdiffuseR and EpiModel own properly; the right move there is an
`as_diffnet()` bridge, filed in Stage 5.

## Baseline this is measured against

| | |
|---|---:|
| Exported functions | 36 |
| Measure selectors (19 snapshot + 40 graph + 4 temporal) | 63 |
| Of those, genuinely time-respecting | 10 |
| Test files | 64 |
| `test_that` blocks | 724 |
| Tests asserting a condition **class** | 223 |
| Distinct `dynet_*` condition classes | 24 |
| Null models / resampling functions | **0** |
| Temporal community functions | **0** |
| Path optimality criteria implemented | **1 of 5** |

Every new item must arrive with tests in that same style: a class-asserting
error-path test and an invariant test, not just a happy path.

## Staging

Six stages, 45 items. Ordered by **consequence**, not size. Stage 0 comes
first because it is wrong output from a released package; Stage 1 next because
until it exists every number the package reports is a point estimate with no
interval, which the project's own standards forbid.

| Stage | Theme | Items | S / M / L | Depends on |
|---|---|---:|---|---|
| 0 | Defects in shipped code | 3 | 3 / 0 / 0 | **DONE** (D1 withdrawn, D2+D3 fixed) |
| 1 | Null models and generators | 8 | 3 / 4 / 1 | **DONE** (A0-A5, B1-B2) |
| 2 | Path criteria and temporal centrality depth | 14 | 2 / 9 / 3 | **B6, B1, A1, A3, A6, A7, B4, A5, A2, A4, B2 DONE**; 3 open |
| 3 | Global temporal measures, inter-event times, motifs | 7 | 2 / 3 / 2 | Stage 2 for path-dependent items |
| 4 | Temporal communities and phases | 7 | 1 / 5 / 1 | **DONE** (items 1-7) |
| 5 | Animation, representation, interop | 6 | 0 / 3 / 3 | nothing |
| | **Total** | **45** | **11 / 24 / 10** | |

```
Stage 0  D1 closeness returns Inf ─── fix before trusting any temporal centrality
         D2 projection metadata ──────────────────────┐
         D3 pshifts column contract ─── blocks 1.A2   │
                                                      │
Stage 1  A0 .with_seed ─> A1 randomise ─> A2 significance ─> A3 null plots
                       └─> A4 activity-aware      │
                          B1 generators ─> B2 block/activation
                                                  └─ minimum shippable slice
                                                     is A0 -> A1 -> A2
Stage 2  B6 participation, B1 katz  (independent, ship first)
         A1 criterion vocabulary ─> A2 foremost, A3 min_hops, A4 fastest,
                                    A5 latest_departure, A3b shortest
                                 └─> A6 criterion-aware centrality
                                     ├─> A7 reachability costs
                                     ├─> B4 edge_centrality
                                     └─> B5 top-k closeness
         B1 katz ─> B2 temporal PageRank ─> B3 walk centrality

Stage 3  B1 gaps, A2 persistence, A3 turnover, C1 motifs  (independent)
         A1 temporal efficiency/diameter ─> A4 node-level efficiency
         A5 segregation (SID) — specced but argued lowest value

Stage 4  DONE. 1 coupling ─> 2 multislice_modularity ─> 3 temporal_communities
                                            ├─> 4 match_communities ─> 6 community_trajectory
                                            └─> 5 community_change
         7 phases() rode on similarity() and needed none of them
Stage 5  independent throughout                                              ─┘
```

## What to build first

**`ecosystem/todo-stage0-defects.md`, then Stage 1 A0 -> A1 -> A2.** That
sequence fixes a live wrong-output bug and then gives every `measure`/`value`
verb in the package a percentile interval and a permutation p-value in one
call, without adding a single new statistic. Stage 2's B6 and B1 are the
cheapest genuinely new capabilities and are independent of everything.

## Detail

Each stage has its own specification file. Every item carries a proposed API
signature, the algorithm, real references, the external package its numbers
must be verified against, the specific tests required, and an effort estimate.

- Stage 0 — `ecosystem/todo-stage0-defects.md`
- Stage 1 — `ecosystem/todo-stage1-nulls.md`
- Stage 2 — `ecosystem/todo-stage2-paths.md`
- Stage 3 — `ecosystem/todo-stage3-measures.md`
- Stage 4 — `ecosystem/todo-stage4-communities.md`
- Stage 5 — `ecosystem/todo-stage5-visual.md`

No item anywhere proposes a new `Imports` dependency. The only addition
proposed at all is `jsonlite` in `Suggests`, used solely in a guarded test.

Read `ecosystem/VERIFIED-SUBSTRATE.md` before starting any of them. It records
four things that were assumed missing and are not — igraph export
(`cograph::to_igraph(dn)` works), path latency (`paths()` already reports it),
and the filmstrip / time-prism plot equivalents (`type = "snapshots"` and
`type = "layers"`).

It also **corrects an earlier claim of my own** that Stage 4 was cheap because
cograph's 25 community functions could be delegated to. Re-measurement showed
that is false: `cograph::supra_adjacency()` couples every pair of layers rather
than consecutive ones, which is categorical coupling and wrong for time, and
cograph's community functions are `igraph` wrappers with igraph in cograph's
*Suggests*. Dynet's own `projection()` already has the correct ordinal chain
coupling and is the substrate to build on. Only `compare_communities()` and the
`community_consensus()` stability pattern carry over.
