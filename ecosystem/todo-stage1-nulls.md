# Stage 1 — Temporal null models and random temporal networks

Implementation TODO specs for Dynet 0.3.53. Two capability gaps, seven items,
ordered by dependency. Nothing here is code; every item is a contract another
session can implement against.

**Companion documents:** `MATH_ROADMAP.md` (the validation ladder these items
must climb), `ECOSYSTEM.md` (where the gap was ranked), `COMPARISON.md`.

---

## Verification performed in this session

Every claim of absence below was checked by running R, not by recalling.

**Dynet exports nothing for randomisation.** `NAMESPACE` lists 36 exports;
`grep -rn "rand|shuffle|permut|null_model|bootstrap" R/*.R -i` returns only
`.brandes_source` (Brandes' algorithm), a Holland–Leinhardt reference in
`R/mixing.R`, a comment in `R/centrality.R` about `sna`'s randomised annealer,
and a comment in `R/palette.R`. There is no null-model machinery, no surrogate
generator, and no seeded code path anywhere in `R/`. Both gaps are real.

**Dynet exports nothing for random network generation.** No `random_*`,
`sample_*`, `sim_*`, `rand_*` verb exists. `dynet()` is the only constructor.

**`ECOSYSTEM.md` is right about timeordered.** `getNamespaceExports("timeordered")`
returns 32 names, of which 14 are randomisation-related: `time_reversal`,
`randomizetimes`, `randomized_edges`, `randomizeidentities`,
`randomized_contacts`, `randomly_permuted_times`, `random_times`,
`contact_randomization`, `edge_randomization`, `total_randomization`,
`vertex_randomization`, `randomize_edges_helper`, `swap`, `rarefy`.

**Two of those twelve are unusable as oracles.** I read the source of all
fourteen in this session. `timeordered::total_randomization` and
`timeordered::vertex_randomization` are byte-for-byte the same function, and
both begin `edges$VertexFrom <- edges$VertexTo`, which destroys the sender
column before the rewiring loop ever sees it. They are a bug in timeordered
1.0.3, not a specification. Do not verify against them. Three others
(`contact_randomization`, `randomize_edges_helper`, `random_times`) use an
unbounded `repeat` with no iteration cap; Dynet's equivalents must bound
iterations and surface non-convergence.

**The surrogate-rebuild path works.** I built `dynet(school_contacts)`
(14 vertices, 240 spells), permuted the `(start, end)` pairs across rows, and
rebuilt with `Dynet:::.as_netobject(spells, nodes, directed, groups, meta,
vertex_spells)`. The result is a valid `dynet` and `metrics()` runs on it —
observed density at `time = 0` was `0.05494505`, the surrogate's `0.06043956`.
No new constructor is needed; A1 can reuse `.as_netobject()`.

**Relabelling invariance holds exactly.** With a random permutation of the 14
vertex names applied to `from`/`to`, `metrics(measure = c("density",
"reciprocity", "transitivity"))` was `all.equal`-identical, and the sorted
`dyn_centrality(measure = "degree")` series was `all.equal`-identical. This is
the invariant test A1's `"labels"` method is required to satisfy.

**Cost of a replicate, measured.** 20 replicates of *permute + rebuild +
`metrics(measure = "density")`* on that network took `0.328 s` elapsed
(≈ 16 ms each). 999 replicates of a graph-level measure is therefore a ~16 s
call; a temporal-betweenness statistic will be orders of magnitude worse, which
is why A2 needs a `message()` progress line and a documented cost.

**Which verbs A2 can wrap.** Called on `dynet(school_contacts)`:
`metrics`, `dyn_centrality`, `events`, `burstiness`, `durations`,
`dyn_reachability` and `mixing` all return `c("dynet_metric", "data.frame")`.
`similarity` returns `dynet_similarity` with `time/other/measure/value`.
`snapshots` returns `dynet_snapshot`; `projection` returns `dynet_projection`.
`pshifts` returns `dynet_pshifts` with columns `shift`, `family`, `count` —
**no `measure`/`value` pair**, so it is the one measurement verb A2 cannot
wrap. That is a contract inconsistency I found while reading, filed as A5.

**Weibull burstiness has an exact closed form**, computed here:
for inter-event times ~ Weibull(shape *k*), with
\(\mu = \Gamma(1+1/k)\), \(\sigma = \sqrt{\Gamma(1+2/k) - \mu^2}\),
Goh–Barabási \(B = (\sigma-\mu)/(\sigma+\mu)\) gives
`B(0.5) = 0.381966` (exactly \((3-\sqrt5)/2\)), `B(1) = 0` and
`B(2) = -0.313436`. Simulating 2e6 draws reproduced `0.3829` and `0.00048`.
These are B2's hand-computed fixtures.

---

## Item A0 — Add a seeded-RNG helper that restores the caller's stream

**Why.** Every item below draws random numbers, and the global rule forbids
leaving `.Random.seed` mutated. Writing the save/restore dance inline in each
verb would be the same eight lines copied four times, and the `rm()` branch
(when `.Random.seed` did not exist before the call) is the one everybody gets
wrong. One internal helper makes reproducibility a property of the package
rather than of each author.

**Proposed API** — internal, not exported.

```r
.with_seed <- function(seed, code)
```

`seed` is `NULL` (use the ambient stream, changing it as any RNG call would) or
a single finite integer. `code` is a lazily evaluated expression. Used at
exactly one place per verb, wrapping the whole random section:

```r
draws <- .with_seed(seed, replicate(n, .surrogate(dn, method), simplify = FALSE))
```

**Return.** The value of `code`. Side effect: when `seed` is not `NULL`, the
caller's `.Random.seed` is exactly as it was on entry, whether it existed or
not.

**Algorithm.**
1. If `seed` is `NULL`, `return(code)` — forcing the promise runs it in the
   caller's stream, which is the documented behaviour.
2. Validate: single, finite, whole-number-valued numeric, else
   `errorCondition(class = "dynet_bad_input")`.
3. If `.Random.seed` exists in `globalenv()` (`inherits = FALSE`), capture it
   and register `on.exit(assign(".Random.seed", old, envir = globalenv()),
   add = TRUE, after = FALSE)`.
4. If it does **not** exist, register
   `on.exit(rm(".Random.seed", envir = globalenv()), add = TRUE, after = FALSE)`
   instead. Assigning `NULL` is not the same thing and leaves a corrupt object.
5. `set.seed(seed)`, then force `code`.

*Pitfalls.* `after = FALSE` matters — the restore must run before any handler a
caller stacked on top. Do not touch `RNGkind()`; changing it and restoring it is
a second failure mode for no gain. Do not use `withr` — it is not a dependency
and the brief forbids adding one. `globalenv()` is correct here even inside a
package namespace, because that is where R keeps `.Random.seed`.

**References.** Not a published method. R Core Team, *Writing R Extensions*,
§"Random number generation"; R Core Team, `?set.seed` (the `.Random.seed`
contract).

**Verify against.** No external reference implementation is appropriate for a
three-line contract. `withr::with_seed()` implements the same idea and can be
read for comparison, but it is not a dependency and its behaviour when
`.Random.seed` is absent is the specific case a hand-written fixture must pin.

**Tests** — `tests/testthat/test-seed-contract.R`
- `"a seeded call restores an existing .Random.seed"` — set a seed in the test,
  capture `.Random.seed`, call `.with_seed(1, runif(5))`, assert `identical()`
  on the captured value.
- `"a seeded call removes .Random.seed when there was none"` — `rm()` it first
  (guarded by `exists()`), call, assert `!exists(".Random.seed", globalenv())`.
  *Error path:* `expect_error(.with_seed("a", 1), class = "dynet_bad_input")`.
- *Invariant:* `"the same seed gives the same draws"` —
  `expect_identical(.with_seed(3, runif(10)), .with_seed(3, runif(10)))`, and
  `expect_false(identical(.with_seed(3, ...), .with_seed(4, ...)))`.

**Effort.** S — one internal function, three tests, no numerical content.

**Depends on.** Nothing.

---

## Item A1 — Add `randomise()`, one verb producing surrogate temporal networks

**Why.** This is the package's highest-priority gap: not one of Dynet's
measures can currently carry a confidence interval or a p-value, because there
is no null to compare against. A measured density of 0.055 is not a finding
until we know what density a network with the same events but no temporal
structure would have shown. Every downstream inferential claim in the package
depends on this one verb existing first.

**Proposed API**

```r
randomise(dn,
          method = c("times", "timeline", "edges", "targets", "labels",
                     "reversal"),
          n = 99L,
          within = c("network", "sender", "session"),
          transpose = FALSE,
          swaps = 10,
          max_tries = 100L,
          keep = c("networks", "spells"),
          seed = NULL)
```

- `n` — number of surrogates. Forced to `1L` for `"reversal"`, which is
  deterministic; supplying `n > 1` there raises a classed error rather than
  silently returning 99 identical copies.
- `within` — the scope a shuffle is confined to. `"network"` shuffles across
  everything; `"sender"` shuffles within each source vertex, preserving that
  vertex's activity exactly; `"session"` shuffles within each session, so a
  surrogate cannot invent structure across a session wall.
- `transpose` — only meaningful with `"reversal"`; reverses time *and* swaps
  edge direction, which is the object the roadmap's Layer-4 property
  "backward results equal forward results on the time-reversed transpose"
  is stated against. `TRUE` with any other method is a classed error.
- `swaps` — for `"edges"` only, the number of double-edge swaps *per distinct
  dyad*. Ten is the conventional mixing heuristic.
- `max_tries` — iteration cap for the rejection loops in `"edges"` and
  `"targets"`. Hitting it is a classed **warning** with the achieved acceptance
  rate, never a silent partial shuffle.
- `keep` — `"networks"` (default) retains the surrogate `dynet` objects so
  `significance()` can reuse one set of replicates for many statistics;
  `"spells"` drops them to save memory.

```r
dn <- dynet(school_contacts)
randomise(dn, method = "times", n = 199, seed = 1)
randomise(dn, method = "edges", n = 199, seed = 1)
randomise(dn, method = "reversal", transpose = TRUE)
```

**Return.** A `dynet_null` object: a tidy `data.frame`, **one row per surrogate
spell per replicate**, with columns

| column | meaning |
|---|---|
| `replicate` | integer, `1..n` |
| `from`, `to` | vertex **names** in the surrogate |
| `start`, `end` | surrogate spell bounds, network time units |
| `duration` | `end - start` |
| `weight` | carried through unchanged |
| `session` | present only when the network has sessions |

Attributes (never reached into by a user): `method`, `n`, `within`,
`transpose`, `seed`, `preserves` and `destroys` (character vectors, printed by
`print()`), `acceptance` (numeric, `NA` for methods with no rejection step),
and `networks` (the list of surrogate `dynet` objects, `NULL` when
`keep = "spells"`).

Ships `print.dynet_null`, `summary.dynet_null`, `plot.dynet_null` and
`as.data.frame.dynet_null` as the brief requires. `print()` names the method
and prints its preserves/destroys lines — the whole point of a null model is
what it holds fixed, so the object must say it out loud.
`summary(x)` returns one row per replicate with `n_events`, `n_dyads`,
`t_min`, `t_max`, `mean_duration`, so a user can see at a glance that the
surrogates conserve what the method claims. `plot()` draws the surrogate
activity profile (events per bin) as thin grey lines with the observed profile
overplotted in `#0072B2` and a solid linetype — the distinction is carried by
colour **and** linetype **and** a direct label, never colour alone.

**What each method preserves and destroys.** This table is the documentation;
it goes into the roxygen `@details` verbatim, because a null model whose
invariants are not stated is not a null model.

| `method` | Preserves exactly | Destroys | Family (Reticula) |
|---|---|---|---|
| `"reversal"` | every spell duration; every dyad; every per-dyad event count; the aggregate weighted adjacency; all degrees; the global activity profile, mirrored | the arrow of time — every time-respecting path, all forward/backward asymmetry, causal ordering | — (deterministic control) |
| `"times"` | the multiset of `(start, end)` pairs, hence the global activity profile and the duration distribution exactly; the dyad set; each dyad's event count; the aggregate weighted adjacency | which dyad was active when — all coupling between topology and timing; each dyad's internal inter-event structure, hence its burstiness | event shuffling |
| `"timeline"` | each dyad's whole event sequence intact, hence per-link burstiness and memory; the dyad set; the total event count | the attachment of a timeline to a dyad; per-dyad event counts (a dyad inherits another's); the aggregate weighted adjacency | timeline shuffling |
| `"edges"` | the aggregate degree sequence (in- **and** out-degree, separately, when directed); every timeline exactly; the number of distinct dyads; total events; the global activity profile | topology above the degree sequence — clustering, triangles, community structure, degree–degree correlation | link shuffling |
| `"targets"` | each source vertex's event times and out-activity exactly (and, with `within = "network"`, the in-activity marginal) | who was reached — the pairing of sender to receiver, hence reciprocity, triadic closure and all path structure | link shuffling (degree-constrained) |
| `"labels"` | **everything structural** — the surrogate is isomorphic to the original | only the map from structure to vertex attributes | identity permutation |

The `"labels"` row is the one users get wrong, and the docs must be blunt: a
label permutation is a null model **for attribute-dependent quantities only**
(`mixing()`, group homophily, anything keyed on `groups`). Every structural
measure is *exactly* invariant under it. That is not a limitation to apologise
for — it is what makes it a free correctness test (see Tests).

**Algorithm.**

Common frame. Work on `dn$spells` (columns `from`, `to`, `start`, `end`,
`session`, `weight`, `onset_censored`, `terminus_censored`, `.raw_spell`).
Shuffle, re-sort by `order(start, end, from, to)`, reset `rownames`, then rebuild
with `.as_netobject(spells = , nodes = dn$nodes["name"], directed = dn$directed,
groups = NULL, meta = , vertex_spells = dn$vertex_spells)`. The `meta` list is
copied from `dn$meta` with `call` replaced by the `randomise()` call and a
`surrogate` field recording `method`/`replicate`; leaving the original
`match.call()` in place would make a surrogate lie about its provenance.

1. **`"reversal"`.** Let `[L, U]` be the observation hull, `dn$meta$time_range`
   (which is the observation interval when one was declared, and the raw event
   extrema otherwise). Map `start' = L + U - end`, `end' = L + U - start`.
   Swap `onset_censored` with `terminus_censored` — a left-censored spell
   becomes right-censored, and forgetting this silently corrupts
   `events(measure = "formation")` on the surrogate. With `transpose = TRUE`,
   additionally swap `from` and `to` (a no-op for undirected networks, where
   endpoints are already stored in canonical order).
   *Divergence from timeordered, to be documented:* `timeordered::time_reversal`
   reflects about the raw event extrema `min(TimeStart)`/`max(TimeStop)`. Dynet
   reflects about the *observation* hull, so that an explicitly bounded network
   reverses inside its declared measurement window rather than inside its data.
   The two agree exactly whenever no bounds were declared, which is the
   condition under which A1 claims equivalence.

2. **`"times"`.** Draw `o <- sample(nrow(spells))` once per replicate and set
   `start <- start[o]`, `end <- end[o]` **as a pair**. Permuting `start` and
   `end` independently would generate negative durations; that is the classic
   error and the reason the pair must move together. Under
   `within = "session"`, permute inside each `split()` block. Because this is a
   permutation of times that already exist, every surrogate event is inside the
   observed support by construction — which is exactly why a uniform re-draw of
   start times (timeordered's `random_times`) is **not** offered: it needs
   rejection sampling that cannot be guaranteed to terminate against a
   discontinuous support.

3. **`"timeline"`.** Key each spell by its dyad (canonicalised as
   `pmin`/`pmax` when undirected). `split()` the spell rows by dyad key, draw a
   permutation of the block list, and reassign each block's `from`/`to` to the
   dyad it landed on. Event times move as a block, untouched.

4. **`"edges"`.** Build the distinct dyad set of the aggregate network.
   Repeat `swaps * n_dyads` times: draw two dyads `(a,b)` and `(c,d)`; propose
   `(a,d)` and `(c,b)`; accept iff neither is a self-loop and neither already
   exists. For directed networks this preserves in- and out-degree separately;
   for undirected, degree. Then relabel each original dyad's whole timeline
   onto its image via a single `match()` on the dyad key.
   *Pitfalls.* Near-complete graphs admit few or no valid swaps — count
   acceptances, store the rate on the result, and `warningCondition(class =
   "dynet_null_poor_mixing")` when it falls below 0.5 (never a bare
   `suppressWarnings`, never an unbounded `repeat` as timeordered uses).
   Degree preservation must be asserted internally after the swap loop, not
   assumed. Note in `@details` that a plain double-edge swap does **not**
   preserve assortativity; a degree-correlation-preserving swap is a separate,
   later feature.

5. **`"targets"`.** Permute the `to` column. `within = "network"` permutes
   across all rows (in-activity marginal preserved); `within = "sender"`
   permutes inside each `split(seq_len(nrow), from)` block (each sender's set of
   contacts preserved, their assignment to times shuffled);
   `within = "session"` inside each session.
   *Pitfall.* A permutation can put `from == to`. Dynet's constructor **drops**
   self-loops, so an unrepaired surrogate silently loses events and biases every
   count downward. Repair with bounded pairwise swaps (at most `max_tries`
   passes); if self-loops remain, raise
   `errorCondition(class = "dynet_null_no_valid_draw")` naming the number of
   offending rows. Do not construct and let the constructor eat them.

6. **`"labels"`.** Draw `perm <- sample(dn$nodes$name)`, apply it to `from` and
   `to`, and apply the *same* permutation to the `name` column of the vertex
   table so that attributes travel with the old label while the structure moves
   to the new one. Getting the direction of this map backwards produces a
   surrogate that is structurally identical *and* attribute-identical — a null
   that tests nothing. The invariant test below catches exactly that.

*Scope limits, enforced not assumed.* Raise
`errorCondition(class = "dynet_randomise_unsupported")` when
`isTRUE(dn$meta$vertex_activity == "explicit")` or when
`dn$meta$observation_spells_explicit` is `TRUE`. In the first case a surrogate
can place an event while an endpoint is ineligible, and Dynet's snapshot
machinery would silently induce it away; in the second, `"reversal"` can land
events in an unobserved gap. Both produce a quietly biased null. Item A4 lifts
the restriction properly. Refusing loudly is correct; producing a wrong null
quietly is not.

**References.**

- Holme, P., & Saramäki, J. (2012). Temporal networks. *Physics Reports*,
  519(3), 97–125. \doi{10.1016/j.physrep.2012.03.001} — §4, the reference
  taxonomy of temporal randomisations.
- Gauvin, L., Génois, M., Karsai, M., Kivelä, M., Takaguchi, T., Valdano, E.,
  & Vestergaard, C. L. (2022). Randomized reference models for temporal
  networks. *SIAM Review*, 64(4), 763–830. \doi{10.1137/19M1242252} — the
  canonical statement of what each shuffling family preserves; the
  preserves/destroys table above follows its notation.
- Milo, R., Kashtan, N., Itzkovitz, S., Newman, M. E. J., & Alon, U. (2003).
  On the uniform generation of random graphs with prescribed degree sequences.
  *arXiv:cond-mat/0312028* — the double-edge swap and its mixing requirement.
- Maslov, S., & Sneppen, K. (2002). Specificity and stability in topology of
  protein networks. *Science*, 296(5569), 910–913.
  \doi{10.1126/science.1065103} — degree-preserving rewiring.
- Blonder, B., Wey, T. W., Dornhaus, A., James, R., & Sih, A. (2012).
  Temporal dynamics and network analysis. *Methods in Ecology and Evolution*,
  3(6), 958–972. \doi{10.1111/j.2041-210X.2012.00236.x} — the paper
  `timeordered` implements.
- Karsai, M., Kivelä, M., Pan, R. K., Kaski, K., Kertész, J., Barabási, A.-L.,
  & Saramäki, J. (2011). Small but slow world: how network topology and
  burstiness slow down spreading. *Physical Review E*, 83, 025102(R).
  \doi{10.1103/PhysRevE.83.025102} — why time shuffling is the right control
  for burstiness effects.

**Verify against.**

- `"reversal"`: **exact numerical equivalence** with
  `timeordered::time_reversal()` is achievable and required, because the method
  is deterministic. Build a matched `VertexFrom/VertexTo/TimeStart/TimeStop`
  frame from the same spells, run both, compare with `all.equal(tolerance =
  sqrt(.Machine$double.eps))`. Restrict the comparison to networks with no
  declared observation bounds, where the two reflection points coincide.
- `"edges"`: `igraph::rewire(g, igraph::keeping_degseq(niter = ...))` on the
  aggregate graph. igraph is already in `Suggests`. Per-draw equivalence is
  impossible (different RNG call order); what is exactly checkable and must be
  checked is that `igraph::degree()` of the Dynet surrogate's aggregate graph
  equals that of the original, and that over 500 draws the distribution of
  realised dyads matches igraph's within a chi-square tolerance.
- `"times"`, `"timeline"`, `"targets"`: `timeordered::randomly_permuted_times()`
  and `timeordered::randomizeidentities()` implement the same permutations, but
  exact per-draw equivalence is not achievable across two RNG call orders. The
  honest checks are the exact multiset invariants listed in the table
  (identical `(start, end)` multiset; identical per-dyad counts; identical
  aggregate weight matrix), all of which are hand-verifiable.
- `"labels"`: **no external reference implementation is needed or appropriate.**
  The specification is "the surrogate is isomorphic", and the fixture is the
  exact-invariance property, which I verified holds for this rebuild path in
  this session.
- **Do not verify against** `timeordered::total_randomization` or
  `vertex_randomization` — both are the same buggy function (see above).

**Tests** — `tests/testthat/test-randomise-contract.R`

- `"reversal matches timeordered::time_reversal exactly"` —
  `skip_if_not_installed("timeordered")`, Layer 3.
- `"every method conserves what its table claims"` — one `expect_*` per cell of
  the preserves column: `"times"` conserves the sorted `(start, end)` multiset
  and the aggregate weight matrix; `"timeline"` conserves each dyad's sorted
  event-time vector as a set of vectors; `"edges"` conserves in- and out-degree
  of the aggregate; `"targets"` with `within = "sender"` conserves each
  sender's event times; `"reversal"` conserves the duration multiset.
- *Invariant test (the important one):*
  `"a label permutation changes no structural measure"` — assert
  `all.equal` on `metrics(measure = c("density", "reciprocity", "transitivity"))`
  between the original and every one of 20 `"labels"` surrogates, and on the
  *sorted* `dyn_centrality(measure = "degree")` series. I confirmed this holds
  for a hand-built permutation in this session; the test pins it.
- *Second invariant:* `"no surrogate contains a self-loop or a negative
  duration"` — over all methods, all replicates: `expect_false(any(from == to))`
  and `expect_true(all(end >= start))`.
- *Error path 1:* `expect_error(randomise(dn, method = "reversal", n = 5),
  class = "dynet_bad_input")`.
- *Error path 2:* `expect_error(randomise(dn, method = "times", transpose = TRUE),
  class = "dynet_bad_input")`.
- *Error path 3:* `expect_error(randomise(dn_with_vertex_spells,
  method = "times"), class = "dynet_randomise_unsupported")`.
- *Error path 4:* `expect_error(randomise(school_contacts, method = "times"),
  class = "dynet_bad_input")` — a data frame is not a network.
- *Reproducibility:* `"the same seed gives the same surrogates"` —
  `expect_identical(as.data.frame(randomise(dn, seed = 1)),
  as.data.frame(randomise(dn, seed = 1)))`, and that
  `.Random.seed` is untouched across the call.
- `expect_snapshot(print(randomise(dn, method = "edges", n = 5, seed = 1)))` so
  the preserves/destroys wording cannot drift unreviewed.
- Sanity check the suite once by inverting the `"labels"` name map on purpose
  and confirming the isomorphism test fails.

**Effort.** L — six methods, two rejection loops with convergence reporting, a
new result class with four S3 methods, an external oracle, and the
preserves/destroys documentation that is the deliverable's real content.

**Depends on.** A0.

---

## Item A2 — Add `significance()`, turning any Dynet measure into an interval and a p-value

**Why.** `randomise()` alone leaves the caller holding surrogates and no
inference. This is the item that pays off the whole stage: it lets a user ask
"is this network's density, or this vertex's betweenness, or this burstiness,
higher than a network with the same events but no temporal structure would
show?" — currently unanswerable for every one of Dynet's measures — in one
call, with no assembly.

**Proposed API**

```r
significance(x, statistic, ...,
             method = c("times", "timeline", "edges", "targets", "labels"),
             n = 999L,
             over = c("time", "series"),
             alternative = c("two.sided", "greater", "less"),
             conf_level = 0.95,
             p_adjust = "BH",
             within = c("network", "sender", "session"),
             seed = NULL)
```

- `x` — a `dynet`, **or** a `dynet_null` from `randomise()`. Passing a
  `dynet_null` reuses one set of replicates across many statistics, which is
  both faster and statistically cleaner than drawing a fresh set per measure;
  `method`, `n` and `within` are then read from the object and supplying them
  is a classed error rather than a silent override.
- `statistic` — a Dynet measurement verb: `metrics`, `dyn_centrality`,
  `events`, `burstiness`, `durations`, `dyn_reachability`, `mixing`,
  `similarity`. The contract is *"a function of one `dynet` returning a data
  frame with `measure` and `value` columns"*, checked once against the observed
  call and raised as `errorCondition(class = "dynet_bad_statistic")` otherwise.
- `...` — passed straight to `statistic`, so
  `significance(dn, statistic = metrics, measure = "density")` and
  `significance(dn, statistic = dyn_centrality, measure = "betweenness",
  window = 5)` both work with no wrapper.
- `over` — `"time"` tests every time point separately (many tests, hence
  `p_adjust`); `"series"` collapses each replicate's series to its mean first
  and tests the single summary, which is the right choice when the question is
  about the network rather than about a particular bin.

```r
dn <- dynet(school_contacts)
significance(dn, statistic = metrics, measure = "density",
             method = "times", n = 999, seed = 1)

significance(dn, statistic = burstiness, measure = "burstiness",
             method = "times", over = "series", n = 999, seed = 1)

null <- randomise(dn, method = "edges", n = 999, seed = 1)
significance(null, statistic = dyn_centrality, measure = "degree")
```

**Return.** A `dynet_significance` object: a tidy `data.frame`, **one row per
cell of the observed statistic**, carrying every key column the statistic
itself produced plus the inference. Key columns are *"every column of the
statistic's result except `value`"* — that single rule covers `time` for
`metrics()`, `time`+`node` for `dyn_centrality()`, `from`+`to` for
`durations()`, `node` for `dyn_reachability()`, `time`+`from_group`+`to_group`
for `mixing()`, and `time`+`other` for `similarity()`, with no per-verb special
casing. Then:

| column | meaning |
|---|---|
| `observed` | the statistic on `dn` |
| `null_mean`, `null_sd` | mean and sd of the finite surrogate values |
| `null_lo`, `null_hi` | `conf_level` percentile interval **of the null distribution** — deliberately *not* named `ci_low`/`ci_high`, because it is not a confidence interval for `observed` |
| `z` | `(observed - null_mean) / null_sd`, `NA` when `null_sd` is 0 |
| `p` | permutation p-value with the +1 correction |
| `p_adj` | `p.adjust(p, method = p_adjust)` over the rows of this call |
| `p_mcse` | `sqrt(p * (1 - p) / (n + 1))`, the Monte-Carlo error on `p` itself |
| `n_null` | replicates whose statistic was finite for this cell |

Attributes: `method`, `n`, `seed`, `alternative`, `conf_level`, `p_adjust`,
`statistic` (deparsed), `preserves`/`destroys` carried from the `dynet_null`.
Ships `print`, `summary`, `plot` and `as.data.frame`. `print()` states the
method, `n`, the correction applied, and how many rows survived it — a bare
p-value is not a result, so the header names the effect size and the interval
before the count of significant rows. `summary()` returns one row per
`measure` with the count tested, count significant after correction, and the
median `z`. `plot()` draws `observed` over time as a solid `#0072B2` line with
the `null_lo`–`null_hi` band in grey and significant points marked by a filled
shape *and* a direct label — never colour alone. `cograph::plot_permutation()`
and `cograph::plot_bootstrap_forest()` were considered for reuse; I read their
signatures this session and they are shaped for edge-level permutation results
with a non-Okabe-Ito hard-coded palette, so a Dynet ggplot2 method is correct.

**Algorithm.**
1. Resolve `x` to a `dynet_null` — call `randomise()` when given a `dynet`,
   pass through when given a `dynet_null` (raising `dynet_bad_input` if
   `method`/`n`/`within` were also supplied). `"reversal"` is not offered here:
   with one deterministic surrogate there is no distribution to test against,
   and offering it would invite a p-value of 0.5 dressed as inference.
2. Compute `obs <- statistic(dn, ...)`. Validate `measure` and `value` are
   present. Build `keys <- setdiff(names(obs), "value")` and a collision-free
   row key with `do.call(paste, c(obs[keys], sep = "\r"))` — `"\r"` because it
   cannot occur in a vertex name or a formatted time.
3. For each replicate, run `statistic(surrogate, ...)` and align to the
   observed keys by `match()`. **A key present in the observed result but
   absent in a surrogate is `NA`, never 0** — a bin with no eligible pairs did
   not have zero density, it had no density, and imputing zero is the silent
   failure this design exists to avoid. Warn with
   `warningCondition(class = "dynet_null_incomplete")` if any cell's `n_null`
   is below `0.9 * n`, and report `n_null` per row regardless.
4. p-value, per Davison & Hinkley (1997, §4.2) and North, Curtis & Sham (2002):
   \(p = (1 + \#\{T^* \succeq T_{obs}\}) / (1 + n_{null})\), where \(\succeq\)
   is `>=` for `"greater"`, `<=` for `"less"`, and
   `abs(T* - null_mean) >= abs(T_obs - null_mean)` for `"two.sided"`.
   *Pitfall:* the `+1` is not cosmetic. Without it a p of exactly 0 is
   reportable, which is false — with 999 draws the smallest defensible p is
   0.001. Enforce `p >= 1 / (n_null + 1)` as an internal assertion.
   *Pitfall:* comparisons of doubles must use a tolerance,
   `T* >= T_obs - sqrt(.Machine$double.eps) * max(1, abs(T_obs))`, or a
   surrogate that is numerically identical to the observed value is
   inconsistently counted.
5. `null_lo`/`null_hi` from `stats::quantile(type = 7)` at
   `(1 - conf_level)/2` and `1 - (1 - conf_level)/2` of the finite surrogate
   values.
6. `z` guarded: `null_sd == 0` (every surrogate identical — the normal case
   under `"labels"` for a structural measure) yields `NA_real_`, not `Inf`.
   Document that `z` is only interpretable when the null is roughly symmetric;
   the percentile interval is the primary report and `z` is secondary.
7. `p_adjust` defaults to `"BH"` and the applied method is named in the print
   header. `p_adjust = "none"` is permitted and must be visible in the header.

*Cost.* Measured in this session: permute + rebuild + `metrics(measure =
"density")` on a 14-vertex, 240-spell network is ≈ 16 ms, so `n = 999` is a
~16 s call. A temporal-betweenness statistic is far worse. Emit a
`message()` with the elapsed estimate after the first ten replicates —
`message()`, never `cat()`, so it is suppressible.

*On the "never a single-seed result" rule.* `p_mcse` is the honest, per-call
answer: it is the Monte-Carlo uncertainty on the reported p, computed from the
same draws. The multi-seed obligation is discharged at test level (below),
where the same question is asked from several seeds and the p values are
required to agree within their MCSE.

**References.**

- Davison, A. C., & Hinkley, D. V. (1997). *Bootstrap Methods and Their
  Application*. Cambridge University Press. §4.2 — the \((1+r)/(1+n)\)
  Monte-Carlo test p-value.
- North, B. V., Curtis, D., & Sham, P. C. (2002). A note on the calculation of
  empirical P values from Monte Carlo procedures. *American Journal of Human
  Genetics*, 71(2), 439–441. \doi{10.1086/341527} — why the `+1` is mandatory.
- Milo, R., Shen-Orr, S., Itzkovitz, S., Kashtan, N., Chklovskii, D., & Alon,
  U. (2002). Network motifs: simple building blocks of complex networks.
  *Science*, 298(5594), 824–827. \doi{10.1126/science.298.5594.824} — the
  z-score-against-a-null convention and its caveats.
- Benjamini, Y., & Hochberg, Y. (1995). Controlling the false discovery rate.
  *JRSS B*, 57(1), 289–300. \doi{10.1111/j.2517-6161.1995.tb02031.x}
- Gauvin et al. (2022), as in A1 — for the choice of reference model.

**Verify against.** **No external reference implementation exists** for a
temporal-network permutation test in R: `timeordered` supplies randomisations
but no testing verb (`applynetworkfunction` merely maps a function over slices),
and `tsna`, `networkDynamic` and `ndtv` supply none. Hand-computed fixtures are
therefore required and are entirely feasible:
1. A network of two spells with `n = 3` and an enumerable surrogate set, where
   the numerator and denominator of `p` are written out longhand in the test.
2. `p` under `alternative = "greater"` for a statistic whose observed value is
   the maximum of the pooled set must equal exactly `1 / (n + 1)`.
3. `stats::quantile(v, c(0.025, 0.975), type = 7)` is the independent oracle
   for `null_lo`/`null_hi` on a fixed vector of surrogate values.
4. `p.adjust(p, "BH")` is base R and is its own oracle.

**Tests** — `tests/testthat/test-significance-contract.R`

- `"the p-value matches a longhand count on an enumerable null"` — the Layer-1
  fixture above, expectations written as literals, not computed by a Dynet
  helper.
- `"an observed maximum gives p = 1/(n+1) exactly"` — Layer 2.
- *Invariant test:* `"a label null gives p = 1 for every structural measure"` —
  under `method = "labels"`, every surrogate value equals the observed one, so
  every `p` must be exactly 1, every `null_sd` exactly 0 and every `z` `NA`.
  This is a single assertion that catches key-alignment bugs, `NA`-vs-0
  imputation bugs, and the tolerance bug in step 4 all at once.
- *Second invariant:* `"p never reaches zero and never exceeds one"` — across
  every method, `expect_true(all(p >= 1/(n+1) & p <= 1))`.
- *Multi-seed stability (the global rule):* `"the same p is recovered from
  independent seeds"` — run `seed = 1, 2, 3` at `n = 999` on the same question
  and assert the three p values agree within `3 * p_mcse`. `skip_on_cran()`.
- *Error path 1:* `expect_error(significance(dn, statistic = pshifts),
  class = "dynet_bad_statistic")` — `pshifts()` returns `count`, not `value`
  (see A5), and this is the test that documents it.
- *Error path 2:* `expect_error(significance(null_object, statistic = metrics,
  measure = "density", n = 50), class = "dynet_bad_input")` — `n` cannot be
  respecified against pre-drawn replicates.
- *Error path 3:* `expect_error(significance(dn, statistic = metrics,
  measure = "density", method = "reversal"), class = "dynet_bad_input")`.
- `expect_snapshot()` on `print()` and `summary()`.

**Effort.** M — the statistics are short and the key-alignment rule is one
line; the work is the result class, the `...` passthrough contract, and the
fixtures. Smaller than A1 because it owns no shuffling algorithm.

**Depends on.** A0, A1.

---

## Item A3 — Add `plot(x, type = "null")` for the null distribution itself

**Why.** A p-value with no picture of the null hides exactly the failure it is
meant to expose: a bimodal, degenerate or one-sided null makes `z` meaningless
and the percentile interval misleading, and neither is visible from the table.
A user cannot currently see the distribution their inference rests on.

**Proposed API** — an argument on the method A2 already ships, not a new verb.

```r
plot(x, type = c("series", "null", "z"), measure = NULL, at = NULL,
     base_size = 12, ...)
```

- `type = "series"` — the default described in A2.
- `type = "null"` — a histogram of the surrogate values with the observed value
  drawn as a labelled vertical rule, faceted by `measure`. `at` selects a
  single time point when the statistic has one; `NULL` pools all cells and says
  so in the subtitle.
- `type = "z"` — a caterpillar plot of `z` per key with the
  `null_lo`/`null_hi` band, ordered by `z`, for node-level statistics with
  many vertices.

```r
s <- significance(dn, statistic = metrics, measure = "density", n = 999, seed = 1)
plot(s, type = "null")
plot(significance(dn, statistic = dyn_centrality, measure = "degree",
                  n = 999, seed = 1), type = "z")
```

**Return.** A `ggplot` object, as every other `plot.dynet_*` method returns.

**Algorithm.** The surrogate values are needed per cell, so `significance()`
must retain them: store the aligned replicate matrix as a `draws` attribute
(one row per replicate, one column per observed key) when the result would
occupy less than a documented cap, and set it to `NULL` above the cap with the
reason recorded so `plot(type = "null")` can raise
`errorCondition(class = "dynet_null_draws_dropped")` telling the user to lower
`n` rather than failing obscurely. `theme_minimal(base_size = base_size)`,
observed rule in `#D55E00`, surrogate histogram in `#999999`, and the observed
value carries a direct text label as well as its colour.

**References.** Milo et al. (2002), as in A2 — the z-score's symmetry
assumption is what this plot exists to let a reader check.

**Verify against.** No numerical content, so no oracle. Per the global rules a
visual change must be rendered: produce `./tmp/null-plots.html` via
`rmarkdown::render()` showing all three `type` values on
`dynet(school_contacts)` and offer it for review rather than asserting it
looks right.

**Tests** — `tests/testthat/test-significance-plot.R`
- `"every plot type returns a ggplot"` — `expect_s3_class(..., "ggplot")` for
  all three, plus `skip_if_not_installed("ggplot2")`.
- *Invariant:* `"the drawn null has as many observations as replicates"` —
  inspect `ggplot2::ggplot_build(p)$data` and assert the histogram's row count
  reconciles with `n_null`.
- *Error path:* `expect_error(plot(s_without_draws, type = "null"),
  class = "dynet_null_draws_dropped")`.

**Effort.** S — one method, three panels, no new mathematics. The only design
decision is the `draws` retention cap.

**Depends on.** A2.

---

## Item A4 — Extend `randomise()` to declared vertex activity and discontinuous observation

**Why.** A1 deliberately refuses networks built with `vertex_spells` or
`observation_spells`, because a naive shuffle places events where an endpoint
is ineligible or inside an unobserved gap, and Dynet's snapshot machinery then
induces them away silently — a null that is quietly biased downward. These are
first-class features of `dynet()`, so the refusal is a real capability hole,
not a footnote.

**Proposed API** — no new verb; A1's `randomise()` stops raising
`dynet_randomise_unsupported` and gains one argument.

```r
randomise(dn, method = , n = , within = , transpose = , swaps = ,
          max_tries = , keep = , seed = ,
          respect = c("activity", "observation", "none"))
```

`respect` names the constraints a surrogate must satisfy; it accepts more than
one. `"activity"` requires both endpoints eligible for the whole surrogate
spell; `"observation"` requires the spell to lie inside one observed component;
`"none"` reproduces A1's unconstrained shuffle and is documented as producing a
biased null when either feature is present.

```r
scheduled <- dynet(school_contacts,
                   vertex_spells = data.frame(node = "Ana", start = 0, end = 10))
randomise(scheduled, method = "times", n = 199, seed = 1)
randomise(scheduled, method = "times", n = 199, respect = "none", seed = 1)
```

**Return.** Unchanged `dynet_null`, with two additional attributes:
`rejected` (count of proposals discarded per replicate) and `respect`.
`summary()` gains a `rejected` column so the constraint's bite is visible.

**Algorithm.**
1. Precompute, once, the feasible time set for each dyad: the intersection of
   both endpoints' eligibility union (from `.observed_vertex_fragments()` and
   `.encode_vertex_activity()`) with the observed support
   (`.observation_table()`). Both internals already exist and already return
   the half-open/point-closed semantics `dynet()` documents; A4 must reuse them
   rather than re-deriving eligibility, or the null and the measurement will
   disagree about what "active" means.
2. `"times"`, `"timeline"`: constrained permutation. Propose a permutation,
   test feasibility per row against the precomputed set, and repair by
   restricted swaps among infeasible rows, capped by `max_tries`. Uniform over
   the *feasible* permutations is not achieved by rejection-then-repair — say
   so in `@details`; the honest claim is "a feasible surrogate", not "a uniform
   draw from the feasible set". Overclaiming here would be worse than the
   current refusal.
3. `"edges"`, `"targets"`: the swap must additionally reject a proposal whose
   new dyad has no feasible window covering the timeline being carried onto it.
4. `"reversal"`: reflect within each observed component about that component's
   own hull, so no event crosses a gap. Document that this is *not* a global
   reversal and that time-respecting paths spanning components are therefore
   not simply mirrored.
5. Report the achieved acceptance rate; below 0.5 raise
   `warningCondition(class = "dynet_null_poor_mixing")`, and on exhaustion
   `errorCondition(class = "dynet_null_no_valid_draw")` naming the constraint
   that bound.

*Pitfall.* Eligibility is half-open for positive spells and closed for points
(`dn$meta$vertex_activity_interval == "positive_half_open_instant_closed"`).
A feasibility test written with `<=` on both ends will admit surrogate spells
that the snapshot machinery then drops. The feasibility predicate must be the
same one `.vertex_eligibility()` uses, called, not re-implemented.

**References.** Gauvin et al. (2022), §on constrained reference models —
constraints of this kind are the paper's "P[…]" notation and the source of the
"which permutations remain reachable" caveat. Holme & Saramäki (2012), §4.

**Verify against.** **No reference implementation exists.** No R or Python
package randomises a temporal network under declared vertex-activity spells;
`timeordered` has no concept of vertex activity and teneto's generators do not
constrain. Hand-computed fixtures are required: a three-vertex network where
one vertex is eligible only on `[0, 2)` admits an enumerable set of feasible
permutations, which the test writes out longhand and compares against the
surrogates drawn over 2,000 replicates.

**Tests** — `tests/testthat/test-randomise-activity-contract.R`
- `"every surrogate spell lies inside both endpoints' eligibility"` — the
  central Layer-5 assertion, over all methods and 200 replicates, checked with
  `.vertex_eligibility()` itself.
- `"no surrogate event lands in an unobserved gap"` — for a network built with
  `observation_spells`.
- *Invariant:* `"measuring a surrogate loses no events"` — the count of active
  edges summed over `snapshots()` on a surrogate equals the count on the
  original for `"times"` (which conserves per-dyad counts), proving nothing was
  silently induced away.
- *Invariant:* `"respect = 'none' reproduces A1 exactly"` — same seed, same
  surrogates as an unconstrained network of the same spells.
- *Error path:* `expect_error(randomise(tight_network, method = "edges",
  max_tries = 1L), class = "dynet_null_no_valid_draw")` on a network whose
  eligibility windows admit no rewiring.
- *Warning path:* `expect_warning(..., class = "dynet_null_poor_mixing")`.

**Effort.** M — the shuffling is A1's; the work is the feasibility precompute,
reusing three existing internals correctly, and the enumerable fixture. It is
not L only because A1 has already built the surrounding machinery.

**Depends on.** A1.

---

## Item A5 — Give `pshifts()` the `measure`/`value` columns every other verb returns

**Why.** Found while reading, not part of the original brief, and reported
rather than fixed silently. Called on `dynet(school_contacts)`, `pshifts()`
returns columns `shift`, `family`, `count` — it is the only measurement verb
without the `measure`/`value` pair that `metrics`, `dyn_centrality`, `events`,
`burstiness`, `durations`, `dyn_reachability`, `mixing` and `similarity` all
share. That inconsistency has a concrete cost: `significance()` (A2) keys on
`measure`/`value` and can wrap every measurement verb in the package **except**
participation shifts, so the one construct with an obvious permutation-test
literature is the one that cannot be tested.

**Proposed API** — no signature change.

```r
pshifts(dn, sessions = c("bounded", "collapse", "separate"))
```

**Return.** The same one-row-per-shift-type table, with `count` renamed to
`value` and a constant `measure = "count"` column added, in the front-column
order `.metric()` imposes: `shift`, `family`, `measure`, `value`. Whether this
also becomes a `dynet_metric` or stays `dynet_pshifts` is an implementation
choice; the columns are the contract.

```r
dn <- dynet(school_contacts)
pshifts(dn)
significance(dn, statistic = pshifts, method = "times", n = 999, seed = 1)
```

**Algorithm.** Rename at the point of construction in `R/pshifts.R`. This is a
breaking change to a public column name, so per the repo's own rules it needs a
`revdepcheck` pass and a `NEWS`/`CHANGES.md` entry; there is no way to add the
`value` column without either duplicating `count` (two names for one number —
worse) or renaming it.

**References.** Gibson, D. R. (2003). Participation shifts: order and
differentiation in group conversation. *Social Forces*, 81(4), 1335–1380.
\doi{10.1353/sof.2003.0055} — the construct itself, unchanged by this item.
Butts, C. T. (2008). A relational event framework for social action.
*Sociological Methodology*, 38(1), 155–200.
\doi{10.1111/j.1467-9531.2008.00203.x} — the P-shift counts and why a null is
the standard way to read them.

**Verify against.** `relevent::accum.ps()` and `tsna::pShiftCount()` are
already named in `MATH_ROADMAP.md` §Layer 3 as the oracles for the *values*,
and the values do not change here. The only thing to verify is that the
renamed column carries identical numbers — a same-session before/after
comparison, not an external one.

**Tests** — extend `tests/testthat/test-participation-shifts-contract.R`
- `"pshifts carries the measure and value columns"` —
  `expect_true(all(c("measure", "value") %in% names(pshifts(dn))))`.
- *Invariant:* `"renaming changed no number"` — the `value` column equals the
  values the existing external-oracle test already pins.
- *Integration:* `"significance() accepts pshifts"` — a small `n` run
  returning a `dynet_significance` with one row per shift type.
- *Error path (kept from A2):* the `dynet_bad_statistic` test in
  `test-significance-contract.R` must be inverted once A5 lands, and re-pointed
  at a genuinely non-conforming function so the error path stays covered.

**Effort.** S — a rename plus a constant column. The cost is the breaking
change discipline, not the code.

**Depends on.** Nothing to implement; A2's `pshifts` error-path test must be
updated in the same change.

---

## Item B1 — Add `random_dynet()` with the binomial and Poisson models

**Why.** Dynet has no way to produce a temporal network at all except from a
user's log, so every test fixture in the package is either the bundled
`school_contacts` or a hand-typed data frame, and every teaching example needs
a dataset. A generator with a known ground truth is also the only way to
calibrate the measures that currently have no external oracle — a Poisson
process has an exactly known burstiness of zero, which is a hand-computable
target `burstiness()` has never been checked against.

**Proposed API**

```r
random_dynet(nodes = 20L, times = 20L,
             model = c("binomial", "poisson"),
             p = 0.1, birth = NULL, persist = NULL,
             rate = 1, dyads = NULL,
             directed = TRUE, interval = 1, loops = FALSE,
             seed = NULL)
```

- `nodes` — a count, or a character vector of names. A count generates
  zero-padded names (`"n01"`, …, `"n20"`) so that lexical and numeric order
  agree; unpadded names sort `"n10"` before `"n2"` and make every fixture
  fragile.
- `times` — number of slices (`"binomial"`) or the length of the observation
  window in network time units (`"poisson"`).
- `p` — per-slice edge probability (`"binomial"`).
- `birth`, `persist` — the two-state Markov variant: `P(0 → 1) = birth`,
  `P(1 → 1) = persist`. Supplying either requires both and forbids `p`.
  **Named `persist`, not `death`**, deliberately: teneto's documentation calls
  the second parameter a "death rate" and then defines it as *"the probability
  of an active edge remaining present"*, which is its opposite. Dynet must not
  inherit that confusion.
- `rate` — Poisson process intensity per dyad, events per unit time.
- `dyads` — number of active dyads (`"poisson"`); `NULL` uses all of them.
- An argument that the chosen `model` ignores is a classed error, never
  silently dropped.

```r
random_dynet(nodes = 20, times = 30, model = "binomial", p = 0.15, seed = 1)
random_dynet(nodes = 12, times = 100, model = "poisson", rate = 0.5, seed = 1)
random_dynet(nodes = c("Ana", "Ben", "Cara"), times = 50, model = "poisson",
             rate = 2, seed = 1)
```

**Return.** A `dynet` — the same object `dynet()` builds, so every verb, plot
and accessor in the package applies with no special casing. `"binomial"`
produces an interval-format network; `"poisson"` produces a contact-format
network. `dn$meta` records `source = "random_dynet"` plus the generating
parameters, so a fixture can state its own provenance.

**Algorithm.**

*Common.* Wrap the whole draw in `.with_seed(seed, ...)` (A0). Build the dyad
universe as `n*(n-1)` ordered pairs when directed, `n*(n-1)/2` unordered pairs
otherwise, honouring `loops`. Construct the final object by calling the public
`dynet()` on the generated data frame rather than `.as_netobject()` — a
generator that bypasses the constructor could emit a network the constructor
would reject, and the tests would never notice.

*`"binomial"`.* For each dyad × slice draw `rbinom(1, 1, p)`, or, in the Markov
variant, run the two-state chain from a `rbinom(1, 1, birth / (1 - persist +
birth))` start — the stationary distribution, so there is no burn-in artefact
at `t = 1`. Then **collapse each maximal run of consecutive active slices into
one interval spell** `[t_first * interval, (t_last + 1) * interval)`. That
collapse is a real design decision and must be documented: it is what turns a
slice-based model into Dynet's spell model, and it means the generated network
has fewer, longer spells than the model has active slices. Emitting one spell
per active slice instead would triple the row count and give `durations()` a
degenerate answer.
*Pitfalls.* Vectorise the draw as one `rbinom(n_dyads * times, 1, p)` reshaped
by `matrix()`; a per-dyad loop is both slow and a rule violation. The Markov
variant genuinely needs a sequential recursion over slices — that is the one
place a `for` loop is defensible and the justifying comment must say so
(`Reduce()` with an accumulator is the idiomatic alternative and should be
preferred if it is readable). A draw can produce zero edges, which `dynet()`
rejects with `dynet_empty_network`; catch that specific class and re-raise as
`dynet_generator_empty` naming `p` and `times`, rather than letting a
constructor error surface from a generator.

*`"poisson"`.* For each active dyad, generate inter-event times as
`rexp(rate = rate)` and take their cumulative sum, truncated at `times`.
*Pitfall, and a documented divergence:* `teneto.generatenetwork.rand_poisson`
draws gaps with `numpy.random.poisson(lam)`, which yields **integer** gaps and
can yield a gap of exactly 0, producing duplicate simultaneous contacts on one
dyad. That is not a Poisson process. Dynet uses exponential gaps, which is,
and the roxygen must say the two are not numerically comparable and why.
Offer `gaps = c("exponential", "poisson")` only if a user asks for teneto
parity; do not add it speculatively.

**References.**

- Erdős, P., & Rényi, A. (1959). On random graphs I. *Publicationes
  Mathematicae*, 6, 290–297 — the per-slice binomial model.
- Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to
  temporal network theory: applications to functional brain connectivity.
  *Network Neuroscience*, 1(2), 69–99. \doi{10.1162/NETN_a_00011} — teneto,
  and `rand_binomial`/`rand_poisson` as its reference generators.
- Goh, K.-I., & Barabási, A.-L. (2008). Burstiness and memory in complex
  systems. *EPL*, 81(4), 48002. \doi{10.1209/0295-5075/81/48002} — the
  \(B = (\sigma-\mu)/(\sigma+\mu)\) that `burstiness()` implements and that
  this generator calibrates.
- Barabási, A.-L. (2005). The origin of bursts and heavy tails in human
  dynamics. *Nature*, 435, 207–211. \doi{10.1038/nature03459}

**Verify against.** `teneto.generatenetwork.rand_binomial` and `rand_poisson`
(teneto 0.5.3, confirmed installed and introspected this session: signatures
`rand_binomial(size, prob, netrep, nettype, initialize, netinfo, randomseed)`
and `rand_poisson(nnodes, ncontacts, lam, nettype, netinfo, netrep)`).
**Exact numerical equivalence is not achievable and must not be claimed** —
different RNG streams, and for `rand_poisson` a different and arguably wrong
gap distribution. What is checkable, and what the cross-language test must
check, is the distributional claim, per the repo's cross-language rules:
generate 500 networks in each language and compare mean density and mean edge
count with `all.equal(tolerance = )` justified by the Monte-Carlo error, not by
a guessed constant. Record the divergence in `LEARNINGS.md`.

The stronger checks are hand-computed and need no other language:
- `E[density per slice] = p` exactly, for the plain binomial variant.
- Stationary activity of the Markov variant is `birth / (1 - persist + birth)`.
- `E[inter-event gap] = 1/rate`, and Goh–Barabási `B = 0` in expectation for
  exponential gaps. I simulated 2e6 exponential draws in this session and got
  `B = 0.00048` against a target of exactly 0.

**Tests** — `tests/testthat/test-random-dynet-contract.R`
- `"a generated network is a dynet every verb accepts"` — build one and run
  `metrics()`, `dyn_centrality()`, `events()`, `durations()`, `snapshots()`
  over it, asserting no error and no `NA` where a value is defined.
- `"expected density equals p"` — 300 networks at `p = 0.2`, mean density
  within `4` standard errors of `0.2`. `skip_on_cran()`.
- *Invariant / calibration:* `"a Poisson process has zero burstiness"` — one
  long `"poisson"` network, `burstiness(dn, measure = "burstiness")` within
  `0.02` of `0`, from **three seeds**, reported and asserted individually.
  Note that `burstiness()` uses the **population** sd
  (`sqrt(mean((x - mu)^2))`, `R/events.R:1500`), not `stats::sd()`, so a
  hand-computed fixture must match that and not the sample sd.
- *Invariant:* `"the same seed gives an identical network"` —
  `expect_identical(as.data.frame(random_dynet(seed = 1)),
  as.data.frame(random_dynet(seed = 1)))`, plus `.Random.seed` untouched.
- *Invariant:* `"node names sort stably"` — `expect_identical(dn$nodes$name,
  sort(dn$nodes$name))` for a generated count, which is the zero-padding test.
- *Error path 1:* `expect_error(random_dynet(model = "poisson", p = 0.3),
  class = "dynet_bad_input")` — `p` is meaningless for the Poisson model and
  must not be silently ignored.
- *Error path 2:* `expect_error(random_dynet(nodes = 5, times = 5,
  p = 0), class = "dynet_generator_empty")`.
- *Error path 3:* `expect_error(random_dynet(model = "binomial",
  birth = 0.1), class = "dynet_bad_input")` — `birth` without `persist`.

**Effort.** M — two models, the run-collapse decision, name padding, parameter
cross-validation, and a cross-language distributional comparison. The code is
short; the contract around it is not.

**Depends on.** A0.

---

## Item B2 — Extend `random_dynet()` with the block and link-activation models

**Why.** B1's two models have no structure to find: a binomial temporal
network has no communities and no bursts, so it cannot serve as ground truth
for anything but a negative control. A dynamic stochastic block model is the
only way to test whether `mixing()` recovers a planted partition, and a
link-activation model with a tunable waiting-time distribution is the only way
to test `burstiness()` against a value other than zero — `MATH_ROADMAP.md`
already flags temporal community detection as the second-ranked gap, and this
is the fixture generator that work will need before it can start.

**Proposed API** — the same verb, two more `model` values and their arguments.

```r
random_dynet(nodes = 20L, times = 20L,
             model = c("binomial", "poisson", "block", "activation"),
             p = 0.1, birth = NULL, persist = NULL,
             rate = 1, dyads = NULL,
             blocks = 2L, p_within = 0.3, p_between = 0.02, block_switch = 0,
             waiting = c("exponential", "weibull", "lognormal"), shape = 1,
             directed = TRUE, interval = 1, loops = FALSE,
             seed = NULL)
```

- `blocks` — a count (equal-sized blocks) or a character vector of one block
  label per vertex.
- `p_within`, `p_between` — per-slice edge probability inside and between
  blocks.
- `block_switch` — per-slice probability a vertex changes block, so the planted
  partition drifts. `0` gives a static partition with dynamic edges.
- `waiting`, `shape` — the renewal process for `"activation"`.
  `waiting = "exponential"` reduces to a Poisson process; `"weibull"` with
  `shape < 1` gives bursty activity, `shape > 1` gives regular activity.

```r
random_dynet(nodes = 30, times = 40, model = "block", blocks = 3,
             p_within = 0.4, p_between = 0.02, seed = 1)
random_dynet(nodes = 30, times = 40, model = "block", blocks = 3,
             block_switch = 0.05, seed = 1)
random_dynet(nodes = 20, times = 200, model = "activation", p = 0.2,
             waiting = "weibull", shape = 0.5, seed = 1)
```

**Return.** A `dynet`, as B1. For `"block"` the planted partition is written
into the vertex table as a `groups` attribute through `dynet(nodes = ,
groups = )`, so `mixing(dn, attribute = "groups")` reads it and
`cograph::splot()` colours by it with no further argument — the ground truth
must be *in* the object, not returned alongside it for the caller to reattach.
`dn$meta` records the generating parameters including the realised block
membership at each slice when `block_switch > 0`.

**Algorithm.**

*`"block"`.* Assign membership `z`; per slice, edge probability is `p_within`
if `z[i] == z[j]` else `p_between`; draw and collapse runs into spells exactly
as B1's `"binomial"` does, so the two models share one code path and one
documented collapse rule. With `block_switch > 0`, resample each vertex's
membership between slices with that probability before drawing, and record the
per-slice membership.
*Pitfall.* With drifting membership the "planted partition" is no longer a
single vector, and any test that recovers *the* partition is ill-posed. State
in `@details` that `block_switch > 0` gives per-slice ground truth only, and
have `mixing()`-based tests use `block_switch = 0`.
*Pitfall.* `p_within` must exceed `p_between` for the partition to be
recoverable at all; a swapped pair is a common user error that produces a
disassortative network and a silently failing test. Do not forbid it — it is a
legitimate model — but say so in `@details` and note that `blocks = 1` makes
the model identical to `"binomial"` with `p = p_within`, which is itself a free
consistency test.

*`"activation"`.* Draw a static graph `G(n, p)` over the dyad universe, then
activate each surviving link by a renewal process: cumulative sums of
`rexp(rate = rate)`, `rweibull(shape = shape, scale = )` or `rlnorm()`,
truncated at `times`. Scale the Weibull and lognormal so their **mean** gap is
`1/rate` regardless of `shape` — otherwise changing `shape` changes the event
rate as well as the burstiness, and the two effects are inseparable in any test
that uses it. For Weibull that means `scale = 1 / (rate * gamma(1 + 1/shape))`.
*Pitfall.* `shape < 1` Weibull gaps are heavy-tailed and a truncated draw can
produce a link with zero events; that is correct model behaviour, not an error,
but the network can end up with fewer active dyads than the static graph had
and `@details` must say so.

**References.**

- Holland, P. W., Laskey, K. B., & Leinhardt, S. (1983). Stochastic
  blockmodels: first steps. *Social Networks*, 5(2), 109–137.
  \doi{10.1016/0378-8733(83)90021-7}
- Yang, T., Chi, Y., Zhu, S., Gong, Y., & Jin, R. (2011). Detecting communities
  and their evolutions in dynamic social networks — a Bayesian approach.
  *Machine Learning*, 82(2), 157–189. \doi{10.1007/s10994-010-5214-7} — the
  dynamic SBM with drifting membership.
- Ghasemian, A., Zhang, P., Clauset, A., Moore, C., & Peel, L. (2016).
  Detectability thresholds and optimal algorithms for community structure in
  dynamic networks. *Physical Review X*, 6, 031005.
  \doi{10.1103/PhysRevX.6.031005} — the regime where a planted partition is
  recoverable, which bounds what a test may assert.
- Goh & Barabási (2008), as in B1 — the burstiness this model tunes.
- Vázquez, A., Oliveira, J. G., Dezsö, Z., Goh, K.-I., Kondor, I., &
  Barabási, A.-L. (2006). Modeling bursts and heavy tails in human dynamics.
  *Physical Review E*, 73, 036127. \doi{10.1103/PhysRevE.73.036127} — the
  heavy-tailed waiting times `"activation"` reproduces.

**Verify against.** `networkx_temporal.dynamic_sbm` /
`dynamic_stochastic_block_model` is the closest reference (it appears in
`ECOSYSTEM-INDEX.md` line 606 from the live enumeration), but **it is not
installed here — `import networkx_temporal` raised `ModuleNotFoundError` in
this session — so I did not read its signature or semantics, and no claim of
parity may be made until someone does.** Reticula's "random link activation
temporal network" is documentation-derived only in `ECOSYSTEM.md` and is not
installed either. **Treat both models as having no verified reference
implementation and use hand-computed fixtures**, which are strong here:

1. `E[within-block density per slice] = p_within` and
   `E[between-block density] = p_between`, exactly, before the run-collapse.
2. With `blocks = 1`, `"block"` must be distributionally identical to
   `"binomial"` at `p = p_within` — a same-package consistency oracle.
3. `mixing(dn, attribute = "groups")` on a `block_switch = 0` network has a
   closed-form expected within-group fraction from `p_within`, `p_between` and
   the block sizes, computable in the test with three lines of arithmetic.
4. **Burstiness has an exact closed form under Weibull waiting**, which I
   derived and checked numerically in this session:
   \(\mu = \Gamma(1+1/k)\), \(\sigma = \sqrt{\Gamma(1+2/k)-\mu^2}\),
   \(B = (\sigma-\mu)/(\sigma+\mu)\), giving
   `B(k = 0.5) = 0.381966` — exactly \((3-\sqrt5)/2\) —
   `B(k = 1) = 0` and `B(k = 2) = -0.313436`.
   Simulating 2e6 Weibull(0.5) draws reproduced `0.3829`, and 2e6 exponential
   draws reproduced `0.00048`. These three numbers are the fixture, and they
   are independent of any other package.

**Tests** — extend `tests/testthat/test-random-dynet-contract.R`
- `"a block network carries its partition as a vertex attribute"` —
  `mixing(dn, attribute = "groups")` runs with no further argument.
- *Calibration:* `"within- and between-block densities match their parameters"`
  — 300 networks, means within 4 standard errors, `skip_on_cran()`.
- *Calibration, the important one:* `"Weibull waiting reproduces the closed-form
  burstiness"` — `shape = 0.5, 1, 2` against `0.381966`, `0`, `-0.313436`,
  from three seeds each, tolerance justified by the simulated Monte-Carlo
  error observed above (`0.001` at 2e6 gaps; loosen explicitly and state why
  for the smaller `n` a test can afford). Using the **population** sd, per
  `R/events.R:1500`.
- *Consistency oracle:* `"blocks = 1 reproduces the binomial model"` —
  distributional comparison of mean density.
- *Invariant:* `"changing shape does not change the event rate"` — mean events
  per link is `all.equal` across `shape = 0.5, 1, 2` at fixed `rate`, which is
  the test that catches a missing Weibull scale correction.
- *Error path 1:* `expect_error(random_dynet(model = "block", blocks = 3,
  waiting = "weibull"), class = "dynet_bad_input")` — `waiting` belongs to
  `"activation"`.
- *Error path 2:* `expect_error(random_dynet(model = "block",
  blocks = rep("a", 3), nodes = 5), class = "dynet_bad_input")` — a membership
  vector whose length does not match `nodes`.
- *Error path 3:* `expect_error(random_dynet(model = "activation",
  waiting = "weibull", shape = 0), class = "dynet_bad_input")`.

**Effort.** M — two models sharing B1's collapse path, plus the Weibull scale
correction and the closed-form calibration. Not L, because B1 has already built
the argument validation, naming and construction machinery.

**Depends on.** B1.

---

## Dependency order

```
A0  .with_seed()                        ── S ── depends on nothing
├── A1  randomise()                     ── L
│   ├── A2  significance()              ── M
│   │   └── A3  plot(type = "null")     ── S
│   └── A4  activity-aware randomise()  ── M
└── B1  random_dynet() binomial/poisson ── M
    └── B2  random_dynet() block/activation ── M

A5  pshifts() column contract           ── S ── independent; land with or before A2
```

A minimum shippable slice is **A0 → A1 → A2**: after those three, every measure
in the package that returns `measure`/`value` can carry a percentile interval
and a permutation p-value in one call. B1 and B2 are independent of that path
and can proceed in parallel, and B2 is what makes A1's `"edges"` and
`"timeline"` methods testable against a network with known planted structure
rather than only against invariants.

## Standing constraints every item inherits

- One call, named arguments, tidy `data.frame` out. No `[`, `[[` or `order()`
  in any example, vignette or roxygen block.
- Vertices by name. `random_dynet()` generates names; `randomise()` permutes
  names; no integer index reaches a result.
- Base R plus the existing `Imports` (cograph, ggplot2, grDevices, graphics)
  and `Suggests` (igraph, network, networkDynamic, sna, tsna, testthat,
  transitiontrees, knitr, rmarkdown). `timeordered` and `teneto` are used as
  oracles in tests only and must be reached through
  `skip_if_not_installed()` — `timeordered` is not currently in `Suggests` and
  adding it there is a `Suggests` addition, not an `Imports` one.
- Validation is `.check_dynet(dn, sessions)` then `match.arg()`; errors are
  `errorCondition(..., class = "dynet_<something>", call = NULL)`.
- Every export gets `@description @param @return @examples @seealso @export`
  and `@references` with author and year; every S3 method gets `@return`.
- Seeded randomness goes through A0's helper, never a bare `set.seed()`.
- Any plot change renders an HTML to `./tmp/` and is offered for review, never
  declared correct by inspection.
- `LEARNINGS.md` and `CHANGES.md` updated per item; `DESCRIPTION` version
  bumped before any push.
