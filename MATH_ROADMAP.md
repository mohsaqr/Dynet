# Dynet Math-First Roadmap

Status: planning document

Prepared: 2026-08-24

Scope: mathematical definitions, algorithms, fixtures, and numerical
equivalence.

Animation, HTML, widgets, movie export, and rendering are out of scope.

## Objective

Develop Dynet one mathematical feature at a time. Correctness comes before
catalogue size and performance. Each feature must have a written mathematical
contract, literal fixtures, an independent check, and a tidy public result
before the next feature begins.

The target is not to reproduce every function in `networkDynamic`, `tsna`, or
`ndtv`. The target is a mathematically complete temporal-analysis core. Other
packages are comparison implementations only where their definitions agree
with Dynet's written contract.

## Current baseline

The following work is complete and remains under regression protection:

- Snapshot grids with separate `start`, `end`, `step`, and `window`, including
  rolling windows and point sampling.
- Directed `mode = "all"`, `"out"`, and `"in"`. The old `indegree` and
  `outdegree` measure names are deprecated aliases.
- The graph-level families accepted by `tsna::tSnaStats()`.
- The current snapshot centrality catalogue, calibrated against `sna`,
  `igraph`, or NetworkX where definitions agree.
- Forward earliest-arrival values calibrated against `tsna::tPath()` on the
  existing equivalence datasets.
- Tidy, name-addressed `dynet_metric` and `dynet_paths` results.
- Direct cograph compatibility. No rendering work belongs in this roadmap.

The existing statement that Dynet has complete `tSnaStats()` coverage needs a
qualification. `degree` with `mode = "in"` matches only
`sna::prestige(cmode = "indegree", rescale = FALSE)` numerically. Dynet has no
public prestige measure and does not implement the other eight prestige
definitions. Dynet's load centrality follows Goh and NetworkX, whereas
`sna::loadcent()` also credits path endpoints. These are different quantities,
not numerical disagreements to hide with a tolerance.

## Confirmed correctness risks

The first work cycle repairs quantities that can currently be wrong or depend
on an unstated convention.

1. `summary.dynet()` sums raw spell durations. Three identical `A -> B`
   spells over `[0, 10)` produce temporal density `1.5`; occupancy must use the
   union of active intervals.
2. A supplied `at` is not transformed when a backward path reverses time. On
   `A -> B [0, 1)`, asking who could reach `B` by time 1 incorrectly reports
   `A` as unreachable.
3. The path kernel permits boarding when arrival equals an interval's
   terminus, although interval activity elsewhere follows `[start, end)`.
   Instantaneous contacts require their own explicit rule.
4. Equal-arrival predecessors are reduced to one edge. Public construction
   imposes an order first, but the selected predecessor can still change when
   tied rows or vertex names change.
5. Bounded-session arrival and predecessor values are selected separately by
   vertex, so one reported chain can combine different sessions.
   `sessions = "separate"` currently behaves like collapse and emits no
   session rows.
6. Temporal closeness drops every reachable target whose latency is zero. An
   immediate `A -> B` contact can therefore give `A` reach 1 and closeness 0.
7. Temporal betweenness counts one arbitrary earliest-arrival tree rather than
   distributing dependency over all equally optimal journeys.
8. Temporal reach divides by `n - 1` without a singleton convention.

## Work one feature at a time

Only one numbered feature is active at a time. A later feature does not begin
until the active feature passes its exit gate.

### Multi-agent roles

The work may use three supporting agents while features remain sequential.

1. **Definition reviewer:** independently derives the equation, boundary
   rules, undefined cases, and literature or package reference. This agent
   does not edit production code.
2. **Fixture reviewer:** independently derives literal values, a slow oracle,
   invariants, and mutation cases. This agent must not reuse the production
   kernel to calculate expectations.
3. **Implementation reviewer:** reviews the completed change for mathematical
   and API defects and reruns the focused calibration.
4. **Primary agent:** owns the production edit, integration, complete test
   run, documentation, and report.

Definition and fixture reviews may run in parallel. Production files are
edited by one agent only. Separate mathematical features are never implemented
in parallel because later definitions depend on earlier ones.

### Required feature record

Before code is written, the active feature records:

- Equation or algorithmic definition and citation.
- Unit of analysis: vertex, ordered pair, dyad, spell, event, or vertex-time
  state.
- Directed and undirected meaning.
- Binary or weighted meaning.
- Normalization and theoretical range.
- Loop, isolate, disconnected-network, and singleton behavior.
- Observation, censoring, session, and interval-boundary behavior.
- Exact meaning of zero, `NA`, `NaN`, and infinity.
- Deliberate differences from comparison packages.
- One public call with simple named arguments.
- Tidy row unit and output columns.

### Universal exit gate

A feature is complete only when all applicable boxes are satisfied:

- [ ] The definition and citation were written before implementation.
- [ ] A bug fix has a regression fixture that fails on the prior
      implementation. A new feature has literal fixtures before production
      implementation exists.
- [ ] Directed, undirected, empty-window, disconnected, loop, singleton, and
      boundary cases are covered where relevant.
- [ ] A slow independent oracle exists for a new combinatorial algorithm.
- [ ] External equivalence passes wherever definitions agree.
- [ ] Differences from external packages are documented, not filtered away.
- [ ] Edge-row permutation and vertex-renaming invariance pass.
- [ ] Time translation and scaling properties pass where applicable.
- [ ] The public verb returns a tidy, name-addressed base `data.frame` or a
      result class with a tidy `as.data.frame()` accessor.
- [ ] No public example uses `$`, bracket extraction, sorting, or mapping
      rituals.
- [ ] Default behavior and output shape remain compatible unless the feature
      explicitly authorizes a breaking correction.
- [ ] Undefined and non-convergent cases test the exact documented value,
      warning, or classed error. Expected warnings are checked, never hidden.
- [ ] New validation errors are classed.
- [ ] At least one plausible mutant is caught.
- [ ] Path features catch boundary, direction/anchor, equal-predecessor,
      duplicate-state, and cross-session mutants whenever those risks apply.
- [ ] The focused `testthat::test_file()` run passes.
- [ ] Every new or changed function, including an internal helper, has a
      direct test.
- [ ] The full `devtools::test()` run passes.
- [ ] Every previously applicable standing equivalence script still passes.
- [ ] The relevant equivalence script records checks, compared values,
      maximum error, exclusions, and mutant failures.
- [ ] The R version, oracle-package versions, RNG seed, restrictions, and
      predeclared tolerance are recorded. Integer and rational fixtures use
      exact equality.
- [ ] `R CMD check --as-cran --no-manual` is clean.
- [ ] A fresh-session or installed-package check passes; validation does not
      depend on sourcing every file in `R/`.
- [ ] Every new or changed function has roxygen `@param`, `@return`, and
      `@examples`; numerical functions also document the equation,
      conventions, edge cases, and citation.
- [ ] No new `for` loop exists without a sequential-dependency justification,
      and no dependency is added where base R is sufficient.
- [ ] `LEARNINGS.md`, `CHANGES.md`, and `HANDOFF.md` are updated and kept out
      of commits.
- [ ] Equivalence artifacts and session files remain unstaged.
- [ ] Git is not run until the completed change is summarized and permission
      is available; `git diff --check` is part of that authorized final pass.
- [ ] Only after acceptance: bump `DESCRIPTION` by `0.0.1`, then commit and
      push if requested.

## Validation layers

Every numerical feature follows the same validation ladder.

### Layer 1 — Literal fixtures

Use deterministic micro-networks with expected values written directly in the
test. Expectations must not call a Dynet helper.

Reusable static fixtures include a single arc, reciprocated pair, chain, fork,
diamond, cycle, star, disconnected components, complete graph, brokerage
triangle, repeated spells, and a separate loop case. Empty behavior is tested
through an empty measurement window or private kernel because `dynet()` does
not currently construct an edgeless object.

Reusable temporal fixtures include a valid chronological chain, impossible
time order, late boarding of a long-open edge, equal-arrival diamond,
equal-arrival journeys with unequal hops, simultaneous events, zero-duration
contacts, exact onset and terminus arrival, recurrent and overlapping spells,
a session wall, censored spells, and an observation gap after gaps can be
represented.

### Layer 2 — Independent tiny oracle

Use a deliberately slow implementation on small inputs:

- Enumerate temporal journeys for at most six vertices directly from the
  written contract, not from the production relaxation logic.
- If production merges sorted intervals, integrate activity with a sorted
  change-point sweep, and vice versa.
- Classify participation shifts directly from consecutive event roles.
- Build projected vertex and edge sets directly from the slice definition.

### Layer 3 — External equivalence

- `tsna::tPath()` and `tReach()` for arrival/latest-departure values and
  traversal duration.
- `networkDynamic::network.extract()` and `network.collapse()` for matched
  activity semantics.
- `tsna::edgeDuration()`, `vertexDuration()`, and `tiedDuration()` for matching
  duration units.
- `tsna::tEdgeFormation()` and `tEdgeDissolution()` for aligned discrete-time
  transition fractions.
- `sna`, `igraph`, and NetworkX for static kernels.
- `ergm::nodemix()` for mixing where its table convention matches.
- `relevent::accum.ps()` and `tsna::pShiftCount()` for participation shifts.
- `tsna::timeProjectedNetwork()` for projected vertex and edge sets.

An external package is an oracle only where its definition matches the Dynet
contract. `tsna::tPath()` cannot validate Dynet's predecessor choice, hop count
under a different tie rule, path multiplicity, tied-path betweenness, or exact
instantaneous-event convention.

### Layer 4 — Mathematical properties

At minimum, test the applicable properties:

- Relabelling changes names, not values.
- Edge-row permutation changes nothing.
- Transposition swaps in- and out-results.
- Undirected input orientation changes nothing.
- Translating time preserves durations, latency, and path identity.
- Positive time rescaling rescales duration and latency but preserves reach.
- Starting later cannot increase forward reach.
- Backward results equal forward results on the time-reversed transpose.
- Duplicating or splitting a spell without changing its activity union does
  not change binary measures or occupancy.
- Formation and dissolution transition numerators do not exceed their risk
  sets.
- Occupancy remains in `[0, 1]`.
- A projection retaining every vertex has `n_vertices * n_slices` states and
  `n_vertices * (n_slices - 1)` identity arcs.

### Layer 5 — Public contract

Exercise the exported verb, not only its private kernel. Results use vertex
names, stack measures by rows, add session rows rather than nested lists, and
retain the mathematical choices needed to interpret each value.

## Decision gate — load centrality

The current Goh/NetworkX definition remains the default. Before adding any
endpoint-crediting variant, decide whether exact `sna::loadcent()` compatibility
has a real use case. If approved, it becomes its own future feature with an
explicit argument such as `load = "sna"`. If rejected, record the decision and
make no code, version, or release change.

## Ordered feature queue

### C01 — Union-duration temporal density

**Purpose:** repair the density already reported by `summary(dn)`.

**Contract:** under the current assumptions of one continuous observation
span and an always-active fixed vertex universe, sum the union length of active
intervals for every relational opportunity and divide by opportunity count
times observation span. Directed opportunities are ordered pairs; undirected
opportunities are unordered dyads. Loops are excluded from numerator and
denominator even when retained for other analyses. A future loop-inclusive
density would need a different name. Preserve `summary(dn)`'s current
`sessions = "collapse"` meaning: union intervals for the same pair on the
shared calendar across session labels, so overlapping labels cannot double
count occupancy.

**Public surface:** keep the columns of `summary(dn)` unchanged; only the
incorrect value changes. Additional variants wait for D04.

**Fixtures:** duplicate, nested, partially overlapping, split, and disjoint
spells; opposite directed pairs; complete full-period network; empty active
window at the private level; loop spell; zero-duration contact; overlapping
sessions clipped to the current observed range.

**Oracle:** production uses a sorted interval union; the oracle integrates
`active_pair_count(t) > 0` over sorted change points.

**Exit:** occupancy is in `[0, 1]`; duplicate and split invariance pass; the
public `summary(dn)` regression is pinned. O01 and V01–V04 later generalize the
observation span and eligible population.

### P01 — Temporal traversal contract

**Purpose:** freeze eligibility before changing path algorithms or APIs.

**Contract decisions:** interval spells use `[start, end)`; instantaneous
events are traversable at their event time through a separate event rule;
waiting is allowed; arrival at an interval terminus cannot board it;
simultaneous-event order is defined rather than inherited from row order; and
journey identity states whether vertices, edge spells, or vertex-time states
may repeat.

This feature changes no search-range API. Bounds are P03.

**Fixtures:** exact onset, exact terminus, late boarding, instantaneous event,
simultaneous chain and cycle, repeated spell, and session wall.

**Oracle:** exhaustive tiny journey enumeration written from the approved
contract. `networkDynamic` and `tsna` validate only matching activity and
arrival values.

**Exit:** eligibility is invariant to input order and consistent with every
other Dynet use of `[start, end)`.

### P02 — Backward anchor correction

**Purpose:** make an explicit backward `at` use the requested calendar time.

**Status:** complete in 0.3.4.

**Contract:** a backward query anchored at deadline `t` reports each vertex's
latest-departure supremum for a journey ending at the target by `t`. Exact time
reflection sends `[s,e)` to `(-e,-s]`, not another half-open interval, so the
backward kernel works in original time and carries whether each supremum is
attained. This state prevents an exact event from composing through an
interval's excluded terminus.

**Public surface:** no new argument. `at` is the backward deadline in
`dyn_paths()` and `dyn_reachability()`. `dyn_paths()` exposes logical
`attained` beside the reported optimum.

**Fixtures:** one arc before, at, inside, and after its bounds; a chronological
chain; an unreachable reverse chain; interval/event endpoint composition;
Date conversion; undirected orientation; session walls; translation and
positive scaling; and attained/unattained session ties.

**Oracle:** exhaustive original-time enumeration carries both the supremum and
its attainment state. `tsna::tPath(direction = "bkwd",
type = "latest.depart")` calibrates interior cases where definitions match.
Ordinary half-open reflected networks are retained only as a deliberate mutant
because they reverse endpoint inclusion.

**Exit:** all backward values and attainment states equal the exhaustive
oracle; public calendar anchors, latency, reach, and endpoint behavior are
pinned; standing mutants and the complete package gates pass.

### P03 — Path search bounds

**Purpose:** add a latest admissible search time without mixing an API feature
into P01's boundary repair.

**Status:** complete in 0.3.5.

**Approved public surface:** `dyn_paths()` and `dyn_reachability()` gain named
`start` and `end` bounds. Existing `at` remains a compatibility alias for
`start` in forward queries and `end` in backward queries; mixing `at` with a
canonical bound is an error. For `dyn_centrality(scope = "temporal")`, its
existing `start` and `end` arguments bound temporal `reach`; bounded temporal
closeness and betweenness remain deferred to their own mathematical features.

**Contract:** the search horizon is the closed traversal-time window
`[start,end]`. Every hop time lies inside it. Edge activity remains P01's
separate rule: interval `[s,e)` is usable at `t` exactly when `s <= t < e`, and
a point event at `t` is usable exactly then. Consequently a point event or
interval onset at the search `end` is included, while an interval terminating
there cannot be boarded at that instant. `start == end` computes same-time
closure; only `start > end` is invalid.

Forward paths make the source available at `start` and retain earliest arrival
at or before `end`. Backward paths use `end` as the target deadline and retain
journeys whose first traversal is at or after `start`. A backward numeric
supremum equal to `start` survives only when its P02 attainment state is true.
Missing opposite bounds preserve current behavior; all explicit bounds use the
network's Date/POSIX conversion.

**Fixtures:** events before, at, and after each bound; interval onset and
terminus at `end`; a long-open edge crossing the window; equal-time chains in a
degenerate window; backward attained and unattained lower-bound ties;
chronological chains; Date conversion; invalid and conflicting bounds;
translation/scaling; and sessions partially inside the range.

**Oracle:** extend the independent P01 enumerator with `next_time <= end` and
the P02 enumerator with `candidate > start || (candidate == start &&
attained)`. Use `tsna::tPath()` only on interior cases because its upper-horizon
boundary differs.

**Exit:** public paths, reachability, and temporal reach agree on the same
eligible journeys; exhaustive values and attainment states match; widening and
time-transform invariants hold; boundary/session mutants fail; classed errors
cover invalid combinations; and snapshot-grid behavior is unchanged.

### P04 — Session-integral paths

**Purpose:** ensure every reported path belongs to one session and make
`sessions = "separate"` genuinely separate.

**Status:** complete in 0.3.6.

**Contract:** a bounded journey cannot use edges from two session labels.
Arrival, hop count, path session, and predecessor reconstruction for a target
come from the same complete session-specific search. A single merged
predecessor column cannot represent endpoint-specific session choices and is
removed from the primary table.

**Public surface:** preserve `bounded`, `collapse`, and `separate`.
Separate mode returns one complete `session`-by-vertex block per session with a
session-local default origin. In bounded mode the primary table retains one
best value per endpoint and adds `path_session` plus `n_best_sessions`.
`path_session` is present only for a unique best session; tied optima remain
explicit rather than choosing by session name or hop count.

`as.data.frame(x, what = "steps")` returns a tidy chronological route table
keyed by endpoint, path session, and step. Bounded steps retain every tied
best-session route; each route is reconstructed wholly from that session's
search. If tied routes disagree in hops, primary `n_hops` is `NA`. The empty
source/target journey is session-vacuous in bounded mode. Within-session path
multiplicity and optimal-journey criteria remain P07/P08 work.

The same wall applies to downstream consumers: bounded temporal betweenness
reconstructs an endpoint from one complete winning-session tree and never from
a merged predecessor vector. Its current arbitrary one-tree handling of ties
is preserved until P10 defines optimal-journey dependency. A supplied session
column must be complete; partially missing labels are rejected at construction
rather than silently dropping unlabelled spells during a split.

**Fixtures:** forward and backward false merged chains; pure cross-session false
reach; unique and tied competing sessions with equal and unequal hop counts;
backward attained/unattained ties; source-only sessions; common bounds;
directed/undirected orientation; session-label and row-order permutations;
downstream bounded betweenness; and partially missing labels.

**Oracle:** split the public spell table by literal session labels without
production splitters, enumerate each session with the approved P01/P02 oracle,
and construct the bounded envelope from complete per-session results. Forward
uses minimum arrival; backward uses maximum `(latest, attained)`
lexicographically.

**Exit:** every reconstructed target path is session-integral; separate output
equals independent per-session calls; the primary table and steps accessor
cannot disagree about arrival, attainment, hop count, ambiguity, or session;
and deliberate merged-predecessor, first-session, lost-attainment, omitted
source-session, and bounds-after-selection mutants fail.

### P05 — Traversal duration

**Purpose:** allow crossing an edge to consume positive time.

**Status:** complete in 0.3.7.

**Public surface:** add a final `traversal_time = 0` argument to `dyn_paths()`,
`dyn_reachability()`, and `dyn_centrality()`. It is one constant nonnegative
finite duration per hop, not an edge-weight interpretation. A numeric value is
measured in the network's stored time unit. A scalar `difftime` is converted
for calendar networks and rejected for numeric step networks. Dates and
date-times are instants, not durations, and are invalid here. A nonzero value
is valid only for temporal centrality; snapshot centrality rejects it.

**Journey contract:** write `delta = traversal_time`. A journey retains P01's
distinct vertices, selected spells, unlimited waiting, and session rules. If a
hop is entered at `x`, its endpoint is reached at `y = x + delta`; the next hop
cannot be entered before `y`. The source is ready at the resolved lower bound
`L`, and the final completion cannot exceed the closed upper bound `H`.

For interval activity, first union overlapping or touching positive intervals
for the same oriented pair under the selected session policy. Bounded and
separate modes union only within one label; collapse ignores labels before the
union. This makes traversal invariant to arbitrary segmentation of continuous
edge activity. In one resulting component `[s,e)`, the occupied traversal
`[x,x + delta)` must fit: `s <= x` and `x + delta <= e`. Finishing exactly at
the excluded component terminus is eligible because no occupancy occurs at
`e`. At `delta = 0`, preserve P01 exactly and require `s <= x < e`; zero
duration does not turn the terminus into an entry point.

A point event is deliberately not treated as an empty interval. It triggers a
hop exactly at its timestamp `q`, after which the endpoint is reached at
`q + delta`. This preserves positive-delay analysis for contact-format
networks while preventing a second point event at `q` from composing after a
positive delay. It is an explicit event-trigger latency rule, not a claim that
the relation remains active during `(q,q + delta)`. This differs deliberately
from `tsna`'s inconsistent positive-delay point behavior.

**Forward recurrence:** for an interval, set `x = max(arrival[u], s)` and
candidate completion `y = x + delta`; require the applicable spell rule and
`y <= H`. For a point event, require `arrival[u] <= q` and `q + delta <= H`,
then propose `q + delta`. Minimize completion as before. Public forward
`arrival_time` is endpoint completion and `latency` includes waiting plus every
hop duration.

**Backward recurrence:** the target begins at `(B,attained) = (H,TRUE)`. For
an incoming interval `[s,e)`, let `m = min(B,e)` and candidate entry
`d = m - delta`. Its attainment is
`(delta > 0 || m < e) && (m < B || attained)`. Retain it when `d > s`, or when
`d == s` and attained, and apply the same attained equality rule at `L`.
Across candidates maximize `d`, preferring attained over unattained at equal
numeric values. This reduces exactly to P02 when `delta = 0`; for positive
duration, entry at `e - delta` and completion at `e` are attained.

For a point event `q`, require `q + delta < B`, or equality with an attained
downstream bound, plus `q >= L`. Its candidate latest entry is `(q,TRUE)`.
Public backward `arrival_time` remains latest entry/departure and latency is
`H - arrival_time`.

**Result contract:** primary and metric columns remain stable. Store the
resolved scalar as `traversal_time` metadata and show a positive value in print
headers. The steps table keeps its node-label meaning: forward `time` is the
completion/arrival label at that node; backward `time` is the latest entry
label. Together with the scalar and consecutive route vertices, these labels
make every hop's entry, completion, and waiting interval checkable.

**Fixtures:** interval exactly long enough and just too short; entry at a
terminus; completion exactly at the spell and query termini; multi-hop and
waiting chains; point trigger followed by an interval; simultaneous point
chain at zero and positive duration; backward exact-fit attainment and the
zero-duration unattained counterpart; lower bounds; directed/undirected;
bounded/collapse/separate sessions and tied winners; calendar `difftime`;
translation, scaling, monotonicity, row order, duplicates, overlapping and
touching interval splits, positive gaps, and zero-duration regression across
every P01–P04 fixture.

**Oracle and comparison:** independently enumerate vertex-simple journeys
from literal spells, carrying entry, completion, session, and backward
attainment states. Deliberate mutants add the duration only once, report entry
as arrival, require strict completion, ignore completion at the horizon, leave
point arrivals undelayed, compose positive-delay simultaneous events, reverse
the backward sign, lose attainment, merge sessions, or alter the zero case.

Installed `tsna::tPath(graph.step.time = ...)` is comparison evidence only for
interior positive-duration interval cases with `start = 0`. Its implementation
can accept completion after `end`, departure before `start`, and insufficient
later spells, and its point-event result changes with origin and direction.
`networkDynamic` supplies activity data but no path-duration algorithm; `ndtv`
has no mathematical path API.

**Exit:** zero is mathematically and numerically identical to P01–P04; positive
duration cannot improve reach or arrival; every reported hop satisfies its
activity component and the closed query horizon; backward values are the exact
original-time dual with correct attainment; path, reachability, and temporal
centrality agree; session-integral reconstruction survives; the exhaustive
oracle and limited `tsna` calibration pass; and all deliberate mutants fail.

### P06 — Temporal reach contract

**Purpose:** rebuild reach on P01–P05.

**Status:** complete in 0.3.8.

**Approved mathematical contract:** for the fixed vertex universe \(V\), let
\(R^+(v)\) contain every other vertex reachable from \(v\) by a P01–P05
journey, and let \(R^-(v)\) contain every other vertex that can reach \(v\).
The forward and backward counts are the corresponding set cardinalities, so a
target is counted once even when several journeys or bounded sessions attain
it. The empty source journey is always excluded. Proportion is count divided
by \(|V|-1\) when \(|V|>1\), and is defined as exactly zero for a singleton.
Isolates, empty windows, and session blocks with no eligible hop therefore
produce zero rather than `NA`, `NaN`, or `Inf`.

Reach inherits the complete direction, anchor, closed query-bound, traversal
duration, pair-activity-union, point-event, attainment, and session semantics
approved in P01–P05. A finite unattained backward supremum counts whenever it
proves that at least one feasible journey exists; a boundary-only unattained
value does not. In bounded mode a target reached through more than one complete
session still counts once. Collapse may cross session labels. Separate mode
reports one block per real session but retains the full fixed vertex universe
and the same \(|V|-1\) denominator; separate blocks are not additive estimates
of bounded reach.

**Approved public surface:** existing `forward_reach`, `backward_reach`, and
temporal centrality `reach` remain source-excluding proportions. Add a final
`measure = "reach"` argument to `dyn_reachability()`, accepting any requested
order of `"reach"` and `"reach_count"`; counts use the distinct long-form
measure names `forward_reach_count` and `backward_reach_count`. Temporal
centrality accepts `reach_count` alongside `reach`. Its `reach` remains forward
proportion and its `reach_count` forward count. Both reduce the same search
trees through one internal helper, and the default call retains its present
rows, names, order, class, metadata, and values. Bounds are accepted when all
requested temporal centrality measures are `reach` or `reach_count` only.

Within each session, `dyn_reachability()` retains direction-major order, then
requested-measure order, then vertex order. Count values remain numeric in the
standard `value` column. No wide count/proportion columns, quantity column, or
renamed `reach_proportion` alias is added.

**Fixtures:** singleton, isolate, chain, fork, later start, backward mirror,
bounded range, traversal-duration monotonicity, unattained backward reach,
duplicate bounded-session attainment, collapse crossing, and separate
sessions with the fixed global denominator.

**Oracle:** literal reachable sets; count/proportion identity; later-start,
earlier-end, and larger-duration monotonicity; same-window forward/backward
relation transposition; equality between forward `dyn_reachability()` and
temporal centrality; and full-census `tsna::tReach()` only where the underlying
P01–P05 journey definitions match. Installed `tsna` counts the seed, so the
calibration is Dynet count = `tReach() - 1` and Dynet proportion =
`(tReach() - 1) / (n - 1)`, with the singleton handled by Dynet's zero
convention. `networkDynamic` supplies activity spells but no reach measure;
`ndtv` supplies no mathematical reach API.

**Exit:** both public reach interfaces agree, the default is backward
compatible, every count is a source-excluded set cardinality, every proportion
uses the approved denominator, no singleton division is undefined, the literal
and metamorphic oracle gates pass, and the limited `tsna` calibration passes.

### P07 — Optimal temporal-journey criterion

**Purpose:** choose the order used to decide which temporal journeys are
optimal before closeness, multiplicity, or betweenness depends on it.

Compare the published candidates explicitly: foremost (earliest arrival),
shortest (fewest hops among time-respecting journeys), fastest (least elapsed
travel time), and explicitly ordered lexicographic forms.
State whether the criterion is source-relative or query-bound-relative and
whether waiting contributes to cost.

The recommended candidate for finite tied-path counting is
foremost-then-shortest: minimize arrival time, then hops. It is not approved
until the definition review proves how prefixes are retained and shows that
simultaneous zero-time
cycles cannot create an infinite optimal family.

For standard vertex centrality, optimal journeys are vertex-simple. A
walk-based quantity that permits revisits is out of scope unless its state also
retains visited-vertex history and its vertex-credit rule receives a different
name.

**Public surface:** retain one default criterion only if it has a clear
published interpretation. Supporting more than one requires a named argument,
not separate result-processing rituals.

**Fixtures:** earliest-but-longer, later-but-shorter, fastest-but-later,
simultaneous cycle, waiting, and positive traversal duration.

**Exit:** every fixture has one literal optimal set under the approved order,
and optimality is independent of row order and names.

### P08 — State-expanded optimal-path multiplicity

**Purpose:** retain every state needed to identify all approved optimal
journeys.

**Contract:** freeze journey identity as a vertex sequence, edge-spell
sequence, or vertex-time-state sequence; decide whether identical spells are
distinct and whether paths differing only by waiting are distinct. Enforce
P07's vertex-simple rule. If that rule is ever relaxed, the state must retain
visited-vertex history before multiplicity or betweenness can be correct.

A single best label per vertex is insufficient. An earlier two-hop arrival and
a later one-hop arrival at the same vertex may both wait for the same final
edge, with the later prefix producing the shortest journey among the foremost
journeys to the target. Retain nondominated
`(vertex, arrival, hops, contact)` states, prove the optimal
substructure, and construct an acyclic predecessor graph over states.

**Public surface:** keep `dyn_paths()` tidy. If multiplicity is public, add
`n_paths`; do not expose nested predecessor lists.

**Fixtures:** two- and three-way merges, equal arrival with unequal hops,
earlier-more-hops versus later-fewer-hops, simultaneous cycle, repeated spell,
revisited-vertex candidate rejected by the simple-journey rule, row
permutation, and relabelling.

**Oracle:** exhaustive enumeration directly from P01 and P07's approved
journey rule, not production relaxation logic.

**Exit:** state counts and journey counts are exact; the state predecessor
graph is acyclic; all defining path mutants fail.

### P09 — Temporal closeness equation

**Purpose:** replace silent zero-latency exclusion with a cited scalar
distance and closeness formula after P08 can recover hop-aware optimal
journeys correctly.

P07 can select journeys, but lexicographic arrival and hop order does not by
itself turn zero elapsed time into a finite scalar distance. Choose a published
rule: permit infinite reciprocal latency, require a positive traversal cost,
use a cited discrete temporal distance, or expose separate latency and
hop-based closeness measures. Do not add an arbitrary constant merely to make
the result finite.

**Public surface:** retain temporal `measure = "closeness"` only if one
unambiguous definition is approved. Multiple published quantities require
distinct measure names or a clear named definition argument.

**Fixtures:** all-zero-latency contact, positive-delay chain, partially
reachable fork, isolate, translation, and positive time rescaling.

**Oracle:** literal equation and a package comparison only after its finite
sample and zero-distance rules are confirmed.

**Exit:** every reachable target is handled by the documented equation; zero,
`NA`, and infinity behavior are explicit.

### P10 — Exact temporal betweenness

**Purpose:** distribute source-target dependency across all equally optimal
temporal journeys.

**Contract:** derive dependency accumulation on P08's acyclic state graph,
then aggregate state dependency back to named vertices. Define normalization by
directedness and eligible reachable ordered pairs. If P07 permits a journey to
revisit a vertex, standard vertex betweenness credits that journey's passage
through the vertex once, not once per state occurrence; any occurrence-count
quantity needs a different name.

**Public surface:** preserve temporal `measure = "betweenness"` unless the
approved definition requires a distinct measure name.

**Fixtures:** chain, equal temporal diamond, asymmetric diamond, three-way
merge, earlier/later competing states, disconnected network, simultaneous
events, and directed/undirected mirrors.

**Oracle:** brute-force tiny journey enumeration. `tsna` is not an oracle for
tied paths because it retains one arbitrary path.

**Exit:** dependency is conserved per source-target pair; tied journeys split
credit exactly; state-to-vertex aggregation, relabelling, and permutation
invariance pass.

### A01 — Burstiness and memory audit

**Purpose:** calibrate existing public event-sequence mathematics before
adding new measures.

**Contract decisions:** sample versus population standard deviation, exact
finite-sample memory correlation, minimum event counts, equal-time events,
self-loop contribution, and session gaps.

**Fixtures:** regular gaps, hand-calculated irregular gaps, alternating
short/long gaps, clustered gaps, equal-time events, one through four events,
self-loop, and separate sessions.

**Oracle:** direct formulas from the event gaps, independently written, plus
the primary Goh and Barabási definition. A package comparison is added only
after confirming identical finite-sample conventions.

**Exit:** translation and scale invariance pass; every undefined threshold is
pinned exactly.

### A02 — Temporal mixing audit

**Purpose:** freeze the group-mixing table and its margins.

**Contract decisions:** directed ordered group pairs; for undirected input,
choose one unordered row per edge or a symmetric incidence table. Binary and
weighted mixing must have different names if both are supported.

**Fixtures:** literal directed two-group table, reciprocal cross-group pair,
within-group edge, undirected cross-group edge, missing attribute, repeated
spells, loop, and optional weighted case.

**Oracle:** literal table, grouped degree margins, and `ergm::nodemix(...,
levels2 = TRUE)` where conventions match.

**Exit:** totals and margins obey the approved convention; relabelling only
permutes group rows.

## Prestige features

Each prestige definition is a separate feature, calibration, version, and exit
gate. The candidate public call is
`dyn_centrality(dn, measure = "prestige", prestige = "domain")`.

### S01 — Prestige: indegree

Add the public measure and calibrate unscaled and `rescale = TRUE` forms against
`sna::prestige(cmode = "indegree")`. Prove its unscaled value equals degree
mode `in`.

### S02 — Prestige: indegree row-normalized

Define row normalization, literal matrix calculation, zero-row behavior, and
agreement with `cmode = "indegree.rownorm"`.

### S03 — Prestige: indegree row-column-normalized

Define the balancing algorithm, tolerance, termination, degenerate rows and
columns, and non-convergence behavior before comparison with
`cmode = "indegree.rowcolnorm"`.

### S04 — Prestige: domain

Define reachability-domain prestige, direction, isolates, and rescaling;
calibrate against `cmode = "domain"`.

### S05 — Prestige: domain proximity

Define Lin's proximity weighting and unreachable cases; calibrate against
`cmode = "domain.proximity"`.

### S06 — Prestige: eigenvector

Define the transposed adjacency, normalization, uniqueness, and complex or tied
dominant eigenvalues; calibrate only on mathematically identified cases.

### S07 — Prestige: eigenvector row-normalized

Add the row-normalized eigenvector definition with literal matrix and
degenerate-row fixtures.

### S08 — Prestige: eigenvector column-normalized

Add the column-normalized eigenvector definition with literal matrix and
degenerate-column fixtures.

### S09 — Prestige: eigenvector row-column-normalized

Combine the approved balancing and eigenvector contracts, including explicit
termination and non-uniqueness behavior.

For S01–S09, exact `sna::prestige()` agreement is not enough. Every feature
also needs a literal nonsingular calculation, a degenerate fixture, an
undefined or non-convergent fixture, and an explicitly reconciled scale.

## Observation features

### O01 — Observation bounds and clipping

**Purpose:** represent one continuous observation interval.

**Candidate public surface:** `observation_start` and `observation_end` on
`dynet()`.

Clip measured exposure non-destructively: preserve original spell boundaries
and derive clipped measurement views. Do not infer censoring from equality with
a boundary. Existing objects remain unchanged when bounds are absent.

**Fixtures:** inside, outside, left-clipped, right-clipped, both-side clipped,
and date-time bounds.

**Exit:** clipping preserves observed exposure and every existing default
result remains unchanged without explicit bounds.

### O02 — Multiple observation spells and gaps

**Purpose:** represent discontinuous observation without pretending a gap is
risk time.

**Candidate public surface:** a tidy `observation_spells` table with start and
end columns.

Intersect activity with the union of observation spells. An activity spell
crossing a gap becomes separate observed fragments at the two sides; the gap
contributes no exposure or risk time, and its fragment boundaries are marked
as observation-censored without changing the original raw spell. Entering or
leaving an observation spell is not itself a relationship formation or
dissolution.

**Fixtures:** two observed intervals, one gap containing events, adjacent
intervals, overlapping intervals, an activity spell spanning a gap, and a
session boundary independent of an observation gap.

**Exit:** observed-time denominators use the union of observation spells and
events in unobserved gaps are rejected or explicitly excluded under a classed
policy.

### O03 — Explicit censor indicators

**Purpose:** distinguish a boundary observed at the limit from an unknown
boundary clipped to it.

Accept explicit onset- and terminus-censor flags or an equivalent tidy input.
Never infer censoring solely from clipping.

**Fixtures:** uncensored, left-, right-, and both-side censored spells with the
same numeric boundaries but different flags.

**Exit:** numerically identical spells can carry different censor states and
duration/rate functions can include or exclude them deliberately.

## Vertex-activity features

### V01 — Vertex-activity representation and accessor

**Purpose:** store a changing eligible vertex population without a general
mutable attribute framework.

**Candidate public surface:** optional tidy `vertex_spells` input to `dynet()`
and `as.data.frame(dn, what = "vertex_spells")`. Static vertices remain always
active by default.

Define boundaries, overlapping-spell union, censor flags, and inconsistent
edge/endpoint activity policy.

### V02 — Vertex activity in snapshots

Apply V01 eligibility to active-node, isolate, density, census, and
centralization denominators. Pin empty eligible sets and inactive-node output.

### V03 — Vertex activity in temporal paths

Prevent traversal through an inactive endpoint. Define whether waiting through
an inactive period is allowed and calibrate matched cases against
`networkDynamic`.

### V04 — Vertex activity in risk sets

Use eligible ordered pairs or dyads, not the aggregate vertex universe, in
occupancy and turnover denominators. Changing-population fixtures must reconcile
the risk set at every change point.

Each V feature has its own constructor/accessor or measurement regression and
exit gate. Do not treat V01–V04 as one migration.

## Duration and exposure features

### D01 — Edge-spell and pair-duration units

**Purpose:** distinguish spell and relational-pair quantities after O01–O03
and V01–V04 are settled.

**Candidate public surface:** extend `dyn_durations()` with a named unit such
as `unit = "spell"` or `unit = "pair"`. Dynet has no persistent multiplex edge
ID, so it must not claim `tsna` edge-ID parity.

Define spell duration, spell count, pair summed duration, and pair union
duration as separately named measures.

**Fixtures:** disjoint, overlapping, nested, recurrent, instantaneous,
opposite directed pairs, censored spells, observation gap, and inactive
endpoint.

**Oracle:** change-point integration and `tsna::edgeDuration()` only for
matching spell/dyad subjects.

**Exit:** every row names its unit and quantity; union duration is bounded by
observed eligible time while summed duration may exceed it when multiplicity is
intentional.

### D02 — Vertex activity duration

**Candidate public surface:** `dyn_durations(dn, unit = "vertex_activity")`.
Return tidy spell- and vertex-level counts/durations from explicit V01 spells.

**Fixtures:** always-active, intermittent, overlapping, censored,
never-active, gap, and singleton vertices.

**Oracle:** literal interval integration and `tsna::vertexDuration()` where
observation conventions match.

### D03 — Tied duration

**Candidate public surface:** `dyn_durations(dn, unit = "node_ties",
mode = "out")`.

Define outgoing, incoming, and combined spell-duration/count sums. If union of
incident active time is also useful, give it a distinct measure name;
`tsna::tiedDuration(neighborhood = "combined")` sums incident spell durations
and is not an oracle for union exposure.

**Fixtures:** pure sender, pure receiver, reciprocal pair, directed star,
simultaneous incident spells, repeated spells, undirected edge, and isolate.

**Exit:** in/out transposition and literal totals pass.

### D04 — Temporal edge-density variants

**Purpose:** generalize C01 through `dyn_metrics()` using O and V semantics.

Expose separately named quantities:

- Pair-time occupancy over all eligible opportunities.
- Pair-time occupancy over pairs ever observed.
- Raw spell-onset intensity over all eligible opportunity time.
- Raw spell-onset intensity over observed-pair opportunity time.

Only occupancies are probabilities bounded by one. Define zero denominators and
instantaneous-only networks explicitly. A contact row is one raw onset event;
spell termini are not a second event. Relational-state transition intensities
belong to T03 and T04 after the transition kernel exists.

**Oracle:** change-point integration and `tsna::tEdgeDensity()` only where its
experimental denominator matches.

## Turnover features

Raw spell-onset and spell-terminus counts already exist. The next four features
count relational-state transitions on union activity, so duplicates and
overlapping spells do not create false transitions.

At each timestamp, collapse every spell for a relational pair and compare its
union state immediately before the entire batch with its union state
immediately after the batch. Adjacent spells `[0, 1)` and `[1, 2)` therefore
have union `[0, 2)` and create no dissolution or reformation at 1. Formation is
`inactive -> active`; dissolution is `active -> inactive`. A zero-duration
contact leaves persistent state unchanged and belongs to the separately named
raw impulse-event count, not the transition numerator.

A relationship transition is counted only when both endpoints, the pair, and
the observation process are eligible immediately before and immediately after
the timestamp batch. Vertex entry, vertex exit, observation entry, and
observation exit never create relationship formation or dissolution. Risk-set
denominators use the same two-sided eligibility rule, so a tie incident to an
entering vertex is not a formation and a tie disappearing with an exiting
vertex is not a dissolution.

Left-censored onsets and right-censored termini are always excluded from these
confirmed-transition numerators. A sensitivity analysis that counts
administrative or censored endpoints would be a separately named
pseudo-transition quantity with its own denominator.

### T01 — Formation fraction

Add a separately named formation-transition fraction at an individual change
time. It is the number of eligible absent-to-active pair transitions divided by
the two-sided eligible pairs inactive immediately before the timestamp batch.
Positive-width windows do not return this fraction; use T03 for exposure-based
rates.

### T02 — Dissolution fraction

Add the active-to-absent transition fraction at an individual change time,
divided by the two-sided eligible active risk set immediately before the
timestamp batch.

### T03 — Formation rate

Divide eligible absent-to-active transitions by integrated empty-pair risk
time over a positive window. State the inverse time unit in result metadata.

### T04 — Dissolution rate

Divide eligible active-to-absent transitions by integrated active-pair risk
time over a positive window. Treat right censoring and zero risk time
explicitly.

For T01–T04, fixtures include first and recurrent ties, duplicate and
overlapping spells, simultaneous dissolution/reformation, empty and full risk
sets, directed and undirected opportunities, loops, vertex entry/exit,
observation gaps, and censoring. Fractions stay in `[0, 1]`; rates rescale
inversely with the time unit. `tsna` is an oracle only for aligned discrete
fractions with matching batch-state semantics.

## Event-sequence and projection features

### E01 — Participation shifts

**Purpose:** implement Gibson's 13 classes.

**Candidate public surface:** a dedicated `dyn_pshifts()` verb returning one
tidy row per class, or one row per event and class for cumulative output.

Before implementation, define how each Dynet format becomes an event sequence:
whether an interval contributes its onset only, whether threaded and
co-presence constructions are eligible, canonical order for tied times,
repeated events, group-directed events, simultaneous recipients, missing
endpoints, and session walls.

**Fixtures:** one minimal event pair per class plus unclassified repetition,
tied times, grouped recipients, row permutation, range truncation, and
directedness rejection.

**Oracle:** literal role classification, `relevent::accum.ps()`, and
`tsna::pShiftCount()` where event conversion matches.

### E02 — Time-projected network

**Purpose:** create a discrete vertex-time representation with forward
identity arcs.

**Candidate public surface:** `dyn_projection(dn, step = 1, window = 1)`.
Return a class with `as.data.frame(x, what = "vertices")` and
`as.data.frame(x, what = "edges")`; never return a bare matrix.

Define slice membership, aggregation, undirected-edge conversion, identity-arc
weight, inactive vertices, and copied attributes.

**Fixture:** three named vertices and three slices with a different edge per
slice. Verify nine states, six identity arcs, exact within-slice edges, no
backward identity arc, and boundary behavior.

**Oracle:** construct literal tidy state and edge sets by a different method
from production, then compare with `tsna::timeProjectedNetwork()`.

## G01 onward — ERGM statistics, individually

`tErgmStats()` accepts an open-ended formula ecosystem, so complete ERGM parity
is not a finite target. Add only cited statistics that serve Dynet users, one
feature and calibration at a time:

1. Concurrent ties.
2. In-, out-, and k-stars.
3. Two-paths.
4. Transitive and cyclic triples.
5. Shared-partner distributions.
6. Degree ranges.
7. Node match and node factor.

Use `ergm` as a comparison implementation, keep kernels in base R where
reasonable, and expose results through existing tidy verbs.

## Execution order

Proceed exactly in this order:

```text
C01
-> P01 -> P02 -> P03 -> P04 -> P05 -> P06 -> P07 -> P08 -> P09 -> P10
-> A01 -> A02
-> S01 -> S02 -> S03 -> S04 -> S05 -> S06 -> S07 -> S08 -> S09
-> O01 -> O02 -> O03
-> V01 -> V02 -> V03 -> V04
-> D01 -> D02 -> D03 -> D04
-> T01 -> T02 -> T03 -> T04
-> E01 -> E02
-> G01 onward
```

The opening is deliberately corrective. C01 repairs a bounded quantity already
reported publicly. P01 freezes traversal before P02 calibrates backward paths.
P08 cannot begin until P07 defines the optimal journey; P09 then uses P08's
state engine for any hop-aware closeness definition. Duration and turnover
work waits for observation and vertex-activity semantics so denominators are
not implemented twice.

## First action

Start with C01 only:

1. Record the union-occupancy equation and loop exclusion in the function
   documentation.
2. Add the duplicated-spell public regression and the literal interval
   fixtures.
3. Make the production interval union and independent change-point oracle use
   different algorithms.
4. Implement the smallest internal helper needed by `summary.dynet()`.
5. Run the focused test, standing equivalence scripts, complete suite, fresh
   package check, and `R CMD check`.
6. Stop at the C01 exit gate. Do not open P01 in the same change.
