# Dynet Math-First Roadmap

Status: planning document

Prepared: 2026-08-24

Scope: mathematical definitions, algorithms, fixtures, and numerical
equivalence.

Animation, HTML, widgets, movie export, and rendering are out of scope.

## Objective

Develop Dynet one mathematical feature at a time. Correctness comes
before catalogue size and performance. Each feature must have a written
mathematical contract, literal fixtures, an independent check, and a
tidy public result before the next feature begins.

The target is not to reproduce every function in `networkDynamic`,
`tsna`, or `ndtv`. The target is a mathematically complete
temporal-analysis core. Other packages are comparison implementations
only where their definitions agree with Dynet’s written contract.

## Current baseline

The following work is complete and remains under regression protection:

- Snapshot grids with separate `start`, `end`, `step`, and `window`,
  including rolling windows and point sampling.
- Directed `mode = "all"`, `"out"`, and `"in"`. The old `indegree` and
  `outdegree` measure names are deprecated aliases.
- The graph-level families accepted by
  [`tsna::tSnaStats()`](https://rdrr.io/pkg/tsna/man/tSnaStats.html).
- The current snapshot centrality catalogue, calibrated against `sna`,
  `igraph`, or NetworkX where definitions agree.
- Forward earliest-arrival values calibrated against
  [`tsna::tPath()`](https://rdrr.io/pkg/tsna/man/paths.html) on the
  existing equivalence datasets.
- Tidy, name-addressed `dynet_metric` and `dynet_paths` results.
- Direct cograph compatibility. No rendering work belongs in this
  roadmap.

The existing statement that Dynet has complete `tSnaStats()` coverage
needs a qualification. `degree` with `mode = "in"` matches only
`sna::prestige(cmode = "indegree", rescale = FALSE)` numerically. Dynet
has no public prestige measure and does not implement the other eight
prestige definitions. Dynet’s load centrality follows Goh and NetworkX,
whereas [`sna::loadcent()`](https://rdrr.io/pkg/sna/man/loadcent.html)
also credits path endpoints. These are different quantities, not
numerical disagreements to hide with a tolerance.

## Confirmed correctness risks

The first work cycle repairs quantities that can currently be wrong or
depend on an unstated convention.

1.  [`summary.dynet()`](https://mohsaqr.github.io/Dynet/reference/summary.dynet.md)
    sums raw spell durations. Three identical `A -> B` spells over
    `[0, 10)` produce temporal density `1.5`; occupancy must use the
    union of active intervals.
2.  A supplied `at` is not transformed when a backward path reverses
    time. On `A -> B [0, 1)`, asking who could reach `B` by time 1
    incorrectly reports `A` as unreachable.
3.  The path kernel permits boarding when arrival equals an interval’s
    terminus, although interval activity elsewhere follows
    `[start, end)`. Instantaneous contacts require their own explicit
    rule.
4.  Equal-arrival predecessors are reduced to one edge. Public
    construction imposes an order first, but the selected predecessor
    can still change when tied rows or vertex names change.
5.  Bounded-session arrival and predecessor values are selected
    separately by vertex, so one reported chain can combine different
    sessions. `sessions = "separate"` currently behaves like collapse
    and emits no session rows.
6.  Temporal closeness drops every reachable target whose latency is
    zero. An immediate `A -> B` contact can therefore give `A` reach 1
    and closeness 0.
7.  Temporal betweenness counts one arbitrary earliest-arrival tree
    rather than distributing dependency over all equally optimal
    journeys.
8.  Temporal reach divides by `n - 1` without a singleton convention.

## Work one feature at a time

Only one numbered feature is active at a time. A later feature does not
begin until the active feature passes its exit gate.

### Multi-agent roles

The work may use three supporting agents while features remain
sequential.

1.  **Definition reviewer:** independently derives the equation,
    boundary rules, undefined cases, and literature or package
    reference. This agent does not edit production code.
2.  **Fixture reviewer:** independently derives literal values, a slow
    oracle, invariants, and mutation cases. This agent must not reuse
    the production kernel to calculate expectations.
3.  **Implementation reviewer:** reviews the completed change for
    mathematical and API defects and reruns the focused calibration.
4.  **Primary agent:** owns the production edit, integration, complete
    test run, documentation, and report.

Definition and fixture reviews may run in parallel. Production files are
edited by one agent only. Separate mathematical features are never
implemented in parallel because later definitions depend on earlier
ones.

### Required feature record

Before code is written, the active feature records:

- Equation or algorithmic definition and citation.
- Unit of analysis: vertex, ordered pair, dyad, spell, event, or
  vertex-time state.
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

The definition and citation were written before implementation.

A bug fix has a regression fixture that fails on the prior
implementation. A new feature has literal fixtures before production
implementation exists.

Directed, undirected, empty-window, disconnected, loop, singleton, and
boundary cases are covered where relevant.

A slow independent oracle exists for a new combinatorial algorithm.

External equivalence passes wherever definitions agree.

Differences from external packages are documented, not filtered away.

Edge-row permutation and vertex-renaming invariance pass.

Time translation and scaling properties pass where applicable.

The public verb returns a tidy, name-addressed base `data.frame` or a
result class with a tidy
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) accessor.

No public example uses `$`, bracket extraction, sorting, or mapping
rituals.

Default behavior and output shape remain compatible unless the feature
explicitly authorizes a breaking correction.

Undefined and non-convergent cases test the exact documented value,
warning, or classed error. Expected warnings are checked, never hidden.

New validation errors are classed.

At least one plausible mutant is caught.

Path features catch boundary, direction/anchor, equal-predecessor,
duplicate-state, and cross-session mutants whenever those risks apply.

The focused
[`testthat::test_file()`](https://testthat.r-lib.org/reference/test_file.html)
run passes.

Every new or changed function, including an internal helper, has a
direct test.

The full `devtools::test()` run passes.

Every previously applicable standing equivalence script still passes.

The relevant equivalence script records checks, compared values, maximum
error, exclusions, and mutant failures.

The R version, oracle-package versions, RNG seed, restrictions, and
predeclared tolerance are recorded. Integer and rational fixtures use
exact equality.

`R CMD check --as-cran --no-manual` is clean.

A fresh-session or installed-package check passes; validation does not
depend on sourcing every file in `R/`.

Every new or changed function has roxygen `@param`, `@return`, and
`@examples`; numerical functions also document the equation,
conventions, edge cases, and citation.

No new `for` loop exists without a sequential-dependency justification,
and no dependency is added where base R is sufficient.

`LEARNINGS.md`, `CHANGES.md`, and `HANDOFF.md` are updated and kept out
of commits.

Equivalence artifacts and session files remain unstaged.

Git is not run until the completed change is summarized and permission
is available; `git diff --check` is part of that authorized final pass.

Only after acceptance: bump `DESCRIPTION` by `0.0.1`, then commit and
push if requested.

## Validation layers

Every numerical feature follows the same validation ladder.

### Layer 1 — Literal fixtures

Use deterministic micro-networks with expected values written directly
in the test. Expectations must not call a Dynet helper.

Reusable static fixtures include a single arc, reciprocated pair, chain,
fork, diamond, cycle, star, disconnected components, complete graph,
brokerage triangle, repeated spells, and a separate loop case. Empty
behavior is tested through an empty measurement window or private kernel
because [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md)
does not currently construct an edgeless object.

Reusable temporal fixtures include a valid chronological chain,
impossible time order, late boarding of a long-open edge, equal-arrival
diamond, equal-arrival journeys with unequal hops, simultaneous events,
zero-duration contacts, exact onset and terminus arrival, recurrent and
overlapping spells, a session wall, censored spells, and an observation
gap after gaps can be represented.

### Layer 2 — Independent tiny oracle

Use a deliberately slow implementation on small inputs:

- Enumerate temporal journeys for at most six vertices directly from the
  written contract, not from the production relaxation logic.
- If production merges sorted intervals, integrate activity with a
  sorted change-point sweep, and vice versa.
- Classify participation shifts directly from consecutive event roles.
- Build projected vertex and edge sets directly from the slice
  definition.

### Layer 3 — External equivalence

- [`tsna::tPath()`](https://rdrr.io/pkg/tsna/man/paths.html) and
  `tReach()` for arrival/latest-departure values and traversal duration.
- [`networkDynamic::network.extract()`](https://rdrr.io/pkg/networkDynamic/man/network.extract.html)
  and `network.collapse()` for matched activity semantics.
- [`tsna::edgeDuration()`](https://rdrr.io/pkg/tsna/man/durations.html),
  `vertexDuration()`, and `tiedDuration()` for matching duration units.
- [`tsna::tEdgeFormation()`](https://rdrr.io/pkg/tsna/man/incidence.html)
  and `tEdgeDissolution()` for aligned discrete-time transition
  fractions.
- `sna`, `igraph`, and NetworkX for static kernels.
- `ergm::nodemix()` for mixing where its table convention matches.
- `relevent::accum.ps()` and
  [`tsna::pShiftCount()`](https://rdrr.io/pkg/tsna/man/pShiftCount.html)
  for participation shifts.
- [`tsna::timeProjectedNetwork()`](https://rdrr.io/pkg/tsna/man/timeProjectedNetwork.html)
  for projected vertex and edge sets.

An external package is an oracle only where its definition matches the
Dynet contract.
[`tsna::tPath()`](https://rdrr.io/pkg/tsna/man/paths.html) cannot
validate Dynet’s predecessor choice, hop count under a different tie
rule, path multiplicity, tied-path betweenness, or exact
instantaneous-event convention.

### Layer 4 — Mathematical properties

At minimum, test the applicable properties:

- Relabelling changes names, not values.
- Edge-row permutation changes nothing.
- Transposition swaps in- and out-results.
- Undirected input orientation changes nothing.
- Translating time preserves durations, latency, and path identity.
- Positive time rescaling rescales duration and latency but preserves
  reach.
- Starting later cannot increase forward reach.
- Backward results equal forward results on the time-reversed transpose.
- Duplicating or splitting a spell without changing its activity union
  does not change binary measures or occupancy.
- Formation and dissolution transition numerators do not exceed their
  risk sets.
- Occupancy remains in `[0, 1]`.
- A projection retaining every vertex has `n_vertices * n_slices` states
  and `n_vertices * (n_slices - 1)` identity arcs.

### Layer 5 — Public contract

Exercise the exported verb, not only its private kernel. Results use
vertex names, stack measures by rows, add session rows rather than
nested lists, and retain the mathematical choices needed to interpret
each value.

## Decision gate — load centrality

The current Goh/NetworkX definition remains the default. Before adding
any endpoint-crediting variant, decide whether exact
[`sna::loadcent()`](https://rdrr.io/pkg/sna/man/loadcent.html)
compatibility has a real use case. If approved, it becomes its own
future feature with an explicit argument such as `load = "sna"`. If
rejected, record the decision and make no code, version, or release
change.

## Ordered feature queue

### C01 — Union-duration temporal density

**Purpose:** repair the density already reported by `summary(dn)`.

**Contract:** under the current assumptions of one continuous
observation span and an always-active fixed vertex universe, sum the
union length of active intervals for every relational opportunity and
divide by opportunity count times observation span. Directed
opportunities are ordered pairs; undirected opportunities are unordered
dyads. Loops are excluded from numerator and denominator even when
retained for other analyses. A future loop-inclusive density would need
a different name. Preserve `summary(dn)`’s current
`sessions = "collapse"` meaning: union intervals for the same pair on
the shared calendar across session labels, so overlapping labels cannot
double count occupancy.

**Public surface:** keep the columns of `summary(dn)` unchanged; only
the incorrect value changes. Additional variants wait for D04.

**Fixtures:** duplicate, nested, partially overlapping, split, and
disjoint spells; opposite directed pairs; complete full-period network;
empty active window at the private level; loop spell; zero-duration
contact; overlapping sessions clipped to the current observed range.

**Oracle:** production uses a sorted interval union; the oracle
integrates `active_pair_count(t) > 0` over sorted change points.

**Exit:** occupancy is in `[0, 1]`; duplicate and split invariance pass;
the public `summary(dn)` regression is pinned. O01 and V01–V04 later
generalize the observation span and eligible population.

### P01 — Temporal traversal contract

**Purpose:** freeze eligibility before changing path algorithms or APIs.

**Contract decisions:** interval spells use `[start, end)`;
instantaneous events are traversable at their event time through a
separate event rule; waiting is allowed; arrival at an interval terminus
cannot board it; simultaneous-event order is defined rather than
inherited from row order; and journey identity states whether vertices,
edge spells, or vertex-time states may repeat.

This feature changes no search-range API. Bounds are P03.

**Fixtures:** exact onset, exact terminus, late boarding, instantaneous
event, simultaneous chain and cycle, repeated spell, and session wall.

**Oracle:** exhaustive tiny journey enumeration written from the
approved contract. `networkDynamic` and `tsna` validate only matching
activity and arrival values.

**Exit:** eligibility is invariant to input order and consistent with
every other Dynet use of `[start, end)`.

### P02 — Backward anchor correction

**Purpose:** make an explicit backward `at` use the requested calendar
time.

**Status:** complete in 0.3.4.

**Contract:** a backward query anchored at deadline `t` reports each
vertex’s latest-departure supremum for a journey ending at the target by
`t`. Exact time reflection sends `[s,e)` to `(-e,-s]`, not another
half-open interval, so the backward kernel works in original time and
carries whether each supremum is attained. This state prevents an exact
event from composing through an interval’s excluded terminus.

**Public surface:** no new argument. `at` is the backward deadline in
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md) and
[`dyn_reachability()`](https://mohsaqr.github.io/Dynet/reference/dyn_reachability.md).
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md) exposes
logical `attained` beside the reported optimum.

**Fixtures:** one arc before, at, inside, and after its bounds; a
chronological chain; an unreachable reverse chain; interval/event
endpoint composition; Date conversion; undirected orientation; session
walls; translation and positive scaling; and attained/unattained session
ties.

**Oracle:** exhaustive original-time enumeration carries both the
supremum and its attainment state.
`tsna::tPath(direction = "bkwd", type = "latest.depart")` calibrates
interior cases where definitions match. Ordinary half-open reflected
networks are retained only as a deliberate mutant because they reverse
endpoint inclusion.

**Exit:** all backward values and attainment states equal the exhaustive
oracle; public calendar anchors, latency, reach, and endpoint behavior
are pinned; standing mutants and the complete package gates pass.

### P03 — Path search bounds

**Purpose:** add a latest admissible search time without mixing an API
feature into P01’s boundary repair.

**Status:** complete in 0.3.5.

**Approved public surface:**
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md) and
[`dyn_reachability()`](https://mohsaqr.github.io/Dynet/reference/dyn_reachability.md)
gain named `start` and `end` bounds. Existing `at` remains a
compatibility alias for `start` in forward queries and `end` in backward
queries; mixing `at` with a canonical bound is an error. For
`dyn_centrality(scope = "temporal")`, its existing `start` and `end`
arguments bound temporal `reach`; bounded temporal closeness and
betweenness remain deferred to their own mathematical features.

**Contract:** the search horizon is the closed traversal-time window
`[start,end]`. Every hop time lies inside it. Edge activity remains
P01’s separate rule: interval `[s,e)` is usable at `t` exactly when
`s <= t < e`, and a point event at `t` is usable exactly then.
Consequently a point event or interval onset at the search `end` is
included, while an interval terminating there cannot be boarded at that
instant. `start == end` computes same-time closure; only `start > end`
is invalid.

Forward paths make the source available at `start` and retain earliest
arrival at or before `end`. Backward paths use `end` as the target
deadline and retain journeys whose first traversal is at or after
`start`. A backward numeric supremum equal to `start` survives only when
its P02 attainment state is true. Missing opposite bounds preserve
current behavior; all explicit bounds use the network’s Date/POSIX
conversion.

**Fixtures:** events before, at, and after each bound; interval onset
and terminus at `end`; a long-open edge crossing the window; equal-time
chains in a degenerate window; backward attained and unattained
lower-bound ties; chronological chains; Date conversion; invalid and
conflicting bounds; translation/scaling; and sessions partially inside
the range.

**Oracle:** extend the independent P01 enumerator with
`next_time <= end` and the P02 enumerator with
`candidate > start || (candidate == start && attained)`. Use
[`tsna::tPath()`](https://rdrr.io/pkg/tsna/man/paths.html) only on
interior cases because its upper-horizon boundary differs.

**Exit:** public paths, reachability, and temporal reach agree on the
same eligible journeys; exhaustive values and attainment states match;
widening and time-transform invariants hold; boundary/session mutants
fail; classed errors cover invalid combinations; and snapshot-grid
behavior is unchanged.

### P04 — Session-integral paths

**Purpose:** ensure every reported path belongs to one session and make
`sessions = "separate"` genuinely separate.

**Status:** complete in 0.3.6.

**Contract:** a bounded journey cannot use edges from two session
labels. Arrival, hop count, path session, and predecessor reconstruction
for a target come from the same complete session-specific search. A
single merged predecessor column cannot represent endpoint-specific
session choices and is removed from the primary table.

**Public surface:** preserve `bounded`, `collapse`, and `separate`.
Separate mode returns one complete `session`-by-vertex block per session
with a session-local default origin. In bounded mode the primary table
retains one best value per endpoint and adds `path_session` plus
`n_best_sessions`. `path_session` is present only for a unique best
session; tied optima remain explicit rather than choosing by session
name or hop count.

`as.data.frame(x, what = "steps")` returns a tidy chronological route
table keyed by endpoint, path session, and step. Bounded steps retain
every tied best-session route; each route is reconstructed wholly from
that session’s search. If tied routes disagree in hops, primary `n_hops`
is `NA`. The empty source/target journey is session-vacuous in bounded
mode. Within-session path multiplicity and optimal-journey criteria
remain P07/P08 work.

The same wall applies to downstream consumers: bounded temporal
betweenness reconstructs an endpoint from one complete winning-session
tree and never from a merged predecessor vector. Its current arbitrary
one-tree handling of ties is preserved until P10 defines optimal-journey
dependency. A supplied session column must be complete; partially
missing labels are rejected at construction rather than silently
dropping unlabelled spells during a split.

**Fixtures:** forward and backward false merged chains; pure
cross-session false reach; unique and tied competing sessions with equal
and unequal hop counts; backward attained/unattained ties; source-only
sessions; common bounds; directed/undirected orientation; session-label
and row-order permutations; downstream bounded betweenness; and
partially missing labels.

**Oracle:** split the public spell table by literal session labels
without production splitters, enumerate each session with the approved
P01/P02 oracle, and construct the bounded envelope from complete
per-session results. Forward uses minimum arrival; backward uses maximum
`(latest, attained)` lexicographically.

**Exit:** every reconstructed target path is session-integral; separate
output equals independent per-session calls; the primary table and steps
accessor cannot disagree about arrival, attainment, hop count,
ambiguity, or session; and deliberate merged-predecessor, first-session,
lost-attainment, omitted source-session, and bounds-after-selection
mutants fail.

### P05 — Traversal duration

**Purpose:** allow crossing an edge to consume positive time.

**Status:** complete in 0.3.7.

**Public surface:** add a final `traversal_time = 0` argument to
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md),
[`dyn_reachability()`](https://mohsaqr.github.io/Dynet/reference/dyn_reachability.md),
and
[`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md).
It is one constant nonnegative finite duration per hop, not an
edge-weight interpretation. A numeric value is measured in the network’s
stored time unit. A scalar `difftime` is converted for calendar networks
and rejected for numeric step networks. Dates and date-times are
instants, not durations, and are invalid here. A nonzero value is valid
only for temporal centrality; snapshot centrality rejects it.

**Journey contract:** write `delta = traversal_time`. A journey retains
P01’s distinct vertices, selected spells, unlimited waiting, and session
rules. If a hop is entered at `x`, its endpoint is reached at
`y = x + delta`; the next hop cannot be entered before `y`. The source
is ready at the resolved lower bound `L`, and the final completion
cannot exceed the closed upper bound `H`.

For interval activity, first union overlapping or touching positive
intervals for the same oriented pair under the selected session policy.
Bounded and separate modes union only within one label; collapse ignores
labels before the union. This makes traversal invariant to arbitrary
segmentation of continuous edge activity. In one resulting component
`[s,e)`, the occupied traversal `[x,x + delta)` must fit: `s <= x` and
`x + delta <= e`. Finishing exactly at the excluded component terminus
is eligible because no occupancy occurs at `e`. At `delta = 0`, preserve
P01 exactly and require `s <= x < e`; zero duration does not turn the
terminus into an entry point.

A point event is deliberately not treated as an empty interval. It
triggers a hop exactly at its timestamp `q`, after which the endpoint is
reached at `q + delta`. This preserves positive-delay analysis for
contact-format networks while preventing a second point event at `q`
from composing after a positive delay. It is an explicit event-trigger
latency rule, not a claim that the relation remains active during
`(q,q + delta)`. This differs deliberately from `tsna`’s inconsistent
positive-delay point behavior.

**Forward recurrence:** for an interval, set `x = max(arrival[u], s)`
and candidate completion `y = x + delta`; require the applicable spell
rule and `y <= H`. For a point event, require `arrival[u] <= q` and
`q + delta <= H`, then propose `q + delta`. Minimize completion as
before. Public forward `arrival_time` is endpoint completion and
`latency` includes waiting plus every hop duration.

**Backward recurrence:** the target begins at `(B,attained) = (H,TRUE)`.
For an incoming interval `[s,e)`, let `m = min(B,e)` and candidate entry
`d = m - delta`. Its attainment is
`(delta > 0 || m < e) && (m < B || attained)`. Retain it when `d > s`,
or when `d == s` and attained, and apply the same attained equality rule
at `L`. Across candidates maximize `d`, preferring attained over
unattained at equal numeric values. This reduces exactly to P02 when
`delta = 0`; for positive duration, entry at `e - delta` and completion
at `e` are attained.

For a point event `q`, require `q + delta < B`, or equality with an
attained downstream bound, plus `q >= L`. Its candidate latest entry is
`(q,TRUE)`. Public backward `arrival_time` remains latest
entry/departure and latency is `H - arrival_time`.

**Result contract:** primary and metric columns remain stable. Store the
resolved scalar as `traversal_time` metadata and show a positive value
in print headers. The steps table keeps its node-label meaning: forward
`time` is the completion/arrival label at that node; backward `time` is
the latest entry label. Together with the scalar and consecutive route
vertices, these labels make every hop’s entry, completion, and waiting
interval checkable.

**Fixtures:** interval exactly long enough and just too short; entry at
a terminus; completion exactly at the spell and query termini; multi-hop
and waiting chains; point trigger followed by an interval; simultaneous
point chain at zero and positive duration; backward exact-fit attainment
and the zero-duration unattained counterpart; lower bounds;
directed/undirected; bounded/collapse/separate sessions and tied
winners; calendar `difftime`; translation, scaling, monotonicity, row
order, duplicates, overlapping and touching interval splits, positive
gaps, and zero-duration regression across every P01–P04 fixture.

**Oracle and comparison:** independently enumerate vertex-simple
journeys from literal spells, carrying entry, completion, session, and
backward attainment states. Deliberate mutants add the duration only
once, report entry as arrival, require strict completion, ignore
completion at the horizon, leave point arrivals undelayed, compose
positive-delay simultaneous events, reverse the backward sign, lose
attainment, merge sessions, or alter the zero case.

Installed `tsna::tPath(graph.step.time = ...)` is comparison evidence
only for interior positive-duration interval cases with `start = 0`. Its
implementation can accept completion after `end`, departure before
`start`, and insufficient later spells, and its point-event result
changes with origin and direction. `networkDynamic` supplies activity
data but no path-duration algorithm; `ndtv` has no mathematical path
API.

**Exit:** zero is mathematically and numerically identical to P01–P04;
positive duration cannot improve reach or arrival; every reported hop
satisfies its activity component and the closed query horizon; backward
values are the exact original-time dual with correct attainment; path,
reachability, and temporal centrality agree; session-integral
reconstruction survives; the exhaustive oracle and limited `tsna`
calibration pass; and all deliberate mutants fail.

### P06 — Temporal reach contract

**Purpose:** rebuild reach on P01–P05.

**Status:** complete in 0.3.8.

**Approved mathematical contract:** for the fixed vertex universe (V),
let (R^+(v)) contain every other vertex reachable from (v) by a P01–P05
journey, and let (R^-(v)) contain every other vertex that can reach (v).
The forward and backward counts are the corresponding set cardinalities,
so a target is counted once even when several journeys or bounded
sessions attain it. The empty source journey is always excluded.
Proportion is count divided by (\|V\|-1) when (\|V\|\>1), and is defined
as exactly zero for a singleton. Isolates, empty windows, and session
blocks with no eligible hop therefore produce zero rather than `NA`,
`NaN`, or `Inf`.

Reach inherits the complete direction, anchor, closed query-bound,
traversal duration, pair-activity-union, point-event, attainment, and
session semantics approved in P01–P05. A finite unattained backward
supremum counts whenever it proves that at least one feasible journey
exists; a boundary-only unattained value does not. In bounded mode a
target reached through more than one complete session still counts once.
Collapse may cross session labels. Separate mode reports one block per
real session but retains the full fixed vertex universe and the same
(\|V\|-1) denominator; separate blocks are not additive estimates of
bounded reach.

**Approved public surface:** existing `forward_reach`, `backward_reach`,
and temporal centrality `reach` remain source-excluding proportions. Add
a final `measure = "reach"` argument to
[`dyn_reachability()`](https://mohsaqr.github.io/Dynet/reference/dyn_reachability.md),
accepting any requested order of `"reach"` and `"reach_count"`; counts
use the distinct long-form measure names `forward_reach_count` and
`backward_reach_count`. Temporal centrality accepts `reach_count`
alongside `reach`. Its `reach` remains forward proportion and its
`reach_count` forward count. Both reduce the same search trees through
one internal helper, and the default call retains its present rows,
names, order, class, metadata, and values. Bounds are accepted when all
requested temporal centrality measures are `reach` or `reach_count`
only.

Within each session,
[`dyn_reachability()`](https://mohsaqr.github.io/Dynet/reference/dyn_reachability.md)
retains direction-major order, then requested-measure order, then vertex
order. Count values remain numeric in the standard `value` column. No
wide count/proportion columns, quantity column, or renamed
`reach_proportion` alias is added.

**Fixtures:** singleton, isolate, chain, fork, later start, backward
mirror, bounded range, traversal-duration monotonicity, unattained
backward reach, duplicate bounded-session attainment, collapse crossing,
and separate sessions with the fixed global denominator.

**Oracle:** literal reachable sets; count/proportion identity;
later-start, earlier-end, and larger-duration monotonicity; same-window
forward/backward relation transposition; equality between forward
[`dyn_reachability()`](https://mohsaqr.github.io/Dynet/reference/dyn_reachability.md)
and temporal centrality; and full-census
[`tsna::tReach()`](https://rdrr.io/pkg/tsna/man/reachable_set_sizes.html)
only where the underlying P01–P05 journey definitions match. Installed
`tsna` counts the seed, so the calibration is Dynet count =
`tReach() - 1` and Dynet proportion = `(tReach() - 1) / (n - 1)`, with
the singleton handled by Dynet’s zero convention. `networkDynamic`
supplies activity spells but no reach measure; `ndtv` supplies no
mathematical reach API.

**Exit:** both public reach interfaces agree, the default is backward
compatible, every count is a source-excluded set cardinality, every
proportion uses the approved denominator, no singleton division is
undefined, the literal and metamorphic oracle gates pass, and the
limited `tsna` calibration passes.

### P07 — Optimal temporal-journey criterion

**Purpose:** choose the order used to decide which temporal journeys are
optimal before closeness, multiplicity, or betweenness depends on it.

**Status:** complete in 0.3.9 as a definition-and-oracle milestone; P08
is the first production implementation of this order.

**Approved criterion:** use the published **shortest foremost** temporal
path, spelled out as **foremost, then shortest** to make the priority
unambiguous. For a fixed source-ready lower bound (L), completion bound
(H), traversal duration (), and session policy, let ({J}\_{sz}) be the
set of complete P01–P05 vertex-simple journeys from (s) to (z). If
journey (J) has final completion (A(J)) and (h(J)) hops, its cost is

\[ (J) = (A(J), h(J)), \]

ordered lexicographically ascending. Thus a journey is shortest foremost
when it first has the earliest attainable final completion and, among
journeys with that completion, has the fewest hops. The empty source
journey has cost ((L,0)). Absolute completion is retained in forward
public output. Replacing (A(J)) by (A(J)-L) gives the same order because
(L) is fixed, but this is still foremost cost rather than fastest cost.

Every reachable forward pair has such an attained earliest completion.
For each finite vertex/spell sequence, the P01–P05 earliest-entry
recurrence either produces an attained completion or proves
infeasibility: interval onsets are closed, point triggers are exact, and
positive-duration interval completion may equal the component terminus.
There are finitely many vertex-simple discrete sequences, so the
attainable sequence minima have an attainable global minimum. This
existence property does not extend automatically to fastest infima or
backward latest-departure suprema.

Unlimited waiting remains part of P01. Waiting from (L), intermediate
waiting, and every positive traversal duration can therefore increase
final completion; hop count ignores them. A point at (q) completes at
(q+). Feasibility continues to require final completion no later than
(H) and one complete session-integral journey where the session policy
requires it.

**Rejected alternatives:** pure foremost minimizes only (A(J)) and
leaves unequal-hop ties; under a walk interpretation it would also leave
cycle-padded ties. Pure shortest minimizes only (h(J)) and may
deliberately arrive later. Fastest minimizes (A(J)-D(J)), where (D(J))
is actual first-hop entry; it excludes waiting at the source before
departure but includes later waiting and traversal duration. Using
(A(J)-L) as “fastest” would silently collapse it into foremost. Fastest
can also have an unattained infimum at a half-open interval boundary.
The reverse lexicographic order ((h,A)) is shortest-then-foremost and is
a different criterion. None of these alternatives is exposed by P07.

**Path, prefix, and finiteness contract:** standard vertex centrality
uses temporal paths, not walks: no vertex repeats. This agrees with Buß
et al.’s path definition and is also forced by the approved order. If a
feasible walk repeats a vertex, delete the closed subwalk and wait at
that vertex until the unchanged suffix begins. Final completion is
preserved and hop count strictly falls, for both positive-duration
traversal and simultaneous zero-duration cycles. A repeated-vertex walk
therefore cannot be shortest foremost.

A shortest-foremost complete path need not have a shortest-foremost
prefix to an intermediate vertex. A later one-hop prefix may wait for
the same final contact as an earlier two-hop prefix and produce the
shorter foremost complete path. P08 must consequently retain
vertex-appearance/contact states rather than one lexicographically best
label per vertex. Safe pruning is componentwise dominance: state
((a_1,h_1)) dominates ((a_2,h_2)) only when (a_1a_2) and (h_1h_2), with
at least one strict inequality and with compatible session/identity
state. At a fixed arrival, every prefix of a minimum-hop path to that
vertex appearance is minimum-hop for its own arrival appearance. Hop
count strictly increases along every predecessor transition, so
equal-time non-strict contacts do not create a cycle in an expanded
state graph whose predecessor arcs are traversal/contact arcs and whose
waiting is implicit. P08 must not insert explicit zero-hop waiting or
dominance arcs and then reuse this acyclicity proof.

Vertex simplicity makes the set of vertex sequences finite, but
arbitrary continuous waiting schedules over interval spells would still
create uncountably many timed realizations. P08 must freeze a discrete
journey identity before it counts ties; P07 does not equate different
waiting schedules with new public paths.

**Direction scope:** temporal closeness and betweenness use forward
ordered pairs with source ready at (L). P02’s backward query is the
time-reversal dual: maximize the original-time latest-departure label
into deadline (H), then minimize hops when the maximum is attained and
ties are eventually implemented. An unattained latest-departure supremum
has no maximizing journey, so no optimal path family exists on which to
apply the hop tie-break; retain only P02’s reach/supremum label in that
case. Backward route selection must not be used as the path family for
forward centrality.

**Public surface and sequencing:** P07 adds no argument, output column,
or metadata because the current one-label earliest-arrival tree cannot
implement the hop tie-break. In particular, its `n_hops` and
reconstructed `steps` are representative route(s) from the current
foremost tree(s), not yet guaranteed shortest foremost. P08 implements
the state engine; P09 then approves closeness; P10 approves exact
dependency distribution. Reach and reach count remain
criterion-independent. If several criteria are genuinely implemented
later, add one final named `criterion` argument and a query-wide
attribute; never encode the choice as a tidy result column or accept
unsupported values in advance.

**Fixtures:** earliest-but-longer versus later-but-shorter; the critical
later-fewer-hop prefix followed by one shared final contact; pure
shortest arriving later; fastest departing later; source and
intermediate waiting; positive traversal duration; simultaneous
zero-time cycle; equal-arrival unequal-hop routes; session walls;
bounds; row permutation; relabelling; and time translation.

**Oracle:** exhaustively enumerate complete P01–P05 vertex-simple
journeys on tiny networks, compute `(final_completion, hops)` only after
enumeration, and select the literal lexicographic minimum. Separately
compute the pure foremost, shortest, shortest-then-foremost, and
prefix-foremost sets so every candidate is proved distinct. For fastest,
compute the infimum and its attainment state, and return a fastest set
only when the infimum is attained; include a literal half-open-interval
fixture with no minimizer. The oracle must reject one-label-prefix, pure
foremost, reversed-priority, source-wait-excluding, walk/cycle,
row-order, and session-crossing mutants.

Installed [`tsna::tPath()`](https://rdrr.io/pkg/tsna/man/paths.html)
calibrates earliest-arrival/latest-departure labels and chooses one
route under ties; it does not validate a shortest-foremost tied family.
Its help mentions `fewest.steps`, but installed 0.3.6 does not accept
that value in the function’s `type` argument. `networkDynamic` supplies
the activity representation and `ndtv` supplies no mathematical
path-selection API.

**References:** Bui-Xuan, Ferreira, and Jarry (2003) distinguish
shortest by hop count, foremost by arrival date, and fastest by time
span in [Computing Shortest, Fastest, and Foremost Journeys in Dynamic
Networks](https://www-npa.lip6.fr/~buixuan/files/BFJ03.pdf). Buß,
Molter, Niedermeier, and Rymar define vertex-simple temporal paths and
shortest foremost paths as earliest-arrival paths with minimum
transitions in [Algorithmic Aspects of Temporal
Betweenness](https://www.cambridge.org/core/journals/network-science/article/algorithmic-aspects-of-temporal-betweenness/5AC743D74B11417B032C389E3D0C5B27E).
Rymar et al. formalize prefix compatibility and exchangeability in [JGAA
27(3),
2023](https://jgaa.info/index.php/jgaa/article/download/paper619/2333/2140).

**Exit:** the literal and exhaustive definition oracle passes; every
competing criterion differs on at least one fixture; loop erasure, state
dominance, and expanded-state acyclicity obligations are recorded for
P08; the exhaustive oracle’s selected optimal family is invariant to
input row order, names, and time translation; and no unsupported public
criterion is promised before its engine exists.

### P08 — State-expanded optimal-path multiplicity

**Purpose:** retain every state needed to identify all approved optimal
journeys.

**Status:** complete in 0.3.10.

**Approved identity:** one journey is one ordered sequence of canonical,
oriented transition atoms. A positive-interval atom is one maximal
continuous activity component for an oriented pair and effective
session; a point atom is one unique oriented-pair/time contact.
Duplicate raw rows, edge weights, overlapping or touching interval
segmentation, and alternative waiting or entry schedules do not multiply
paths. Distinct recurrent atoms do, even when their vertex and displayed
time sequences agree. Collapse erases session labels before
canonicalization. Bounded and separate identities include the literal
session. Undirected traversal orientation is part of the atom.

**State contract:** enforce P07’s vertex-simple rule through its
loop-erasure result. A forward state is an exact
`(session scope, vertex, completion time)` appearance carrying the
minimum hop count at that appearance, an exact path count, and
contact-labelled predecessor arcs. Retain every distinct appearance
time: an earlier appearance must not prune a later one because both
recurrent contacts can feed the same optimal suffix. At the same
appearance, replace on fewer hops, add counts and parallel
contact-labelled arcs on equal hops, and discard greater hops. The
source state is `(source, L, 0, 1)`.

The backward dual retains
`(session scope, vertex, latest-departure supremum, attained)`.
Unattained suffix states remain internally because an earlier incoming
contact can cap strictly below their supremum and create an attained
upstream state. Endpoint selection counts only attained maximizing
states. A single numeric backward envelope is therefore insufficient for
multiplicity.

Every predecessor traversal raises hop count by one. Hop order is
consequently a topological order even for simultaneous contacts; waiting
and dominance are implicit and never become graph arcs. Vertex
simplicity bounds useful paths by `n - 1` hops. If a minimum-hop
appearance route repeated a vertex, erasing the closed subwalk and
waiting to the unchanged suffix would produce the same appearance with
fewer hops, a contradiction. Replacing any non-minimum prefix at an
exact appearance similarly gives a shorter complete route. Induction in
hop order and unique last-atom decomposition establish completeness and
exact counting without a visited-set state.

**Endpoint contract:** forward endpoints first minimize final completion
and then hops. Backward endpoints first maximize latest departure,
prefer an attained optimum at an equal numeric supremum, and then
minimize hops among attained optima. Counts sum all tied minimum-hop
appearance families. The empty source/target journey has `n_hops = 0`
and `n_paths = 1`. An unreachable endpoint has missing
arrival/latency/hops and `n_paths = 0`. A finite backward supremum that
is not attained remains reachable with its numeric label, has
`n_hops = NA`, `n_paths = 0`, and has no route rows.

Bounded sessions compete on the full criterion, not arrival alone.
`n_best_sessions` counts sessions containing a full-cost optimum;
`path_session` is present only when exactly one does; and `n_paths` sums
session-qualified optimal sequences across every tied winning session.
The bounded empty journey is session-vacuous and has zero best sessions.
Separate mode reports session-local families and one empty journey in
each block.

**Public surface:** add exact numeric `n_paths` after `n_hops` in the
tidy primary table and query-wide `criterion = "foremost_then_shortest"`
metadata. No criterion argument is added. The steps accessor lazily
expands every optimal atom sequence, adding endpoint-local `path_id`
after `endpoint` (`session`- and endpoint-local in separate mode). It
retains path-specific state times; a later prefix used by a target must
not borrow the earlier primary label of the same vertex. Distinct atom
sequences may intentionally produce otherwise identical visible route
rows. The internal predecessor DAG is never exposed as a list column.

Counts use base-R numeric storage but must remain exact. Values through
`2^53` are permitted. Every addition checks the remaining exact range
first and raises classed `dynet_path_overflow` before a larger count
could be rounded, saturated, or made infinite. Lazy route
materialization may independently raise a classed expansion-size error
without invalidating compact counts.

**Fixtures:** two- and three-way merges; equal arrival with unequal
hops; earliest-but-longer versus globally shortest; earlier-more-hops
versus later-fewer-hops; recurrent contacts with one vertex trace but
two atom sequences; simultaneous and explicit repeated-vertex cycles;
positive duration; duplicate points; duplicate, split, overlapping,
touching, and genuinely disjoint interval components; point/interval
atoms with the same visible trace; cross-session walls; unequal-hop and
equal-cost session ties; the same route duplicated across sessions;
backward unattained and exact-event ties; row/session permutation;
relabelling; time translation/scaling; and a binary-diamond count of
`2^53` followed by a classed `2^54` overflow.

**Oracle:** independently canonicalize atoms with a change-point
construction, then exhaustively enumerate complete vertex-simple atom
sequences on at most six vertices. Carry visited vertices, ready time,
atom identity, entries, completions, and session; select the endpoint
family only after enumeration. Backward enumeration propagates
original-time suprema and attainment and counts only attained sequences
tied at the global optimum. Compare labels, attainment, hops, counts,
and complete semantic atom-sequence families.

**Exit:** state and journey counts are exact; the predecessor graph is
acyclic; primary and expanded path tables agree; every defining path,
identity, session, backward-attainment, route-time, overflow, and
eager-expansion mutant fails; and the universal gate passes.

### P09 — Temporal closeness equation

**Status:** complete in Dynet 0.3.11. The literal suite, independent
exhaustive arrival oracle, transformations, deliberate mutants,
implementation review, full package tests, standing calibrations, fresh
tarball, and package check pass at the gate recorded below.

**Purpose:** replace silent zero-latency exclusion with a cited scalar
distance and explicit infinity convention after P08 fixes the underlying
journey family.

**Approved equation:** for source-ready time `L`, let `R_s` contain
every reachable nonself endpoint, let `A_sz` be its P08 earliest
completion, and let `ell_sz = A_sz - L` be forward latency. Define

\[ C_L(s)=
``` math
\begin{cases}
 0, & R_s=\varnothing,\\
 |R_s|\big/\sum_{z\in R_s}\ell_{sz}, & R_s\ne\varnothing.
 \end{cases}
```

\]

Every reachable endpoint is included exactly once, including latency
zero. Thus an isolate, empty eligible window, or singleton is exactly
zero. A nonempty family whose total latency is zero is exactly positive
infinity; mixed zero/positive latency is finite and the zero-latency
endpoint remains in the numerator. No epsilon, `+1`, discretization, or
positive-duration requirement is introduced. Values are in `[0, Inf]`,
have units inverse time, are translation invariant, and divide by `k`
when all times, bounds, and traversal duration are rescaled by positive
`k`. With positive per-hop duration `delta`, every nonempty latency is
at least `delta`, so finite closeness is at most `1 / delta`.

This is inverse mean latency over reachable endpoints, retaining Dynet’s
existing finite-positive normalization and values. Holme and Saramaki’s
temporal-closeness equation supplies the inverse total/mean latency
basis; Dynet’s reachable-set restriction is explicit because ordinary
temporal networks are usually disconnected. Their separately published
harmonic temporal efficiency averages reciprocal pair latencies and
becomes infinite when any one latency is zero; it is not silently
substituted here. A future harmonic latency-efficiency or hop-distance
quantity requires a distinct measure name.

**Public surface:** retain temporal `measure = "closeness"`; add no
definition argument. It now accepts the same `start` and `end` path
bounds as reach. Store query-wide
`criterion = "foremost_then_shortest"`, `distance = "forward_latency"`,
and `normalization = "reachable_inverse_mean"` metadata. Multiplicity,
tied sessions, and P08’s hop tie-break never weight an endpoint.
Collapse, bounded, and separate inherit the complete P08/P06 session
semantics; separate rows use their session-local origin.

**Fixtures:** all-zero simultaneous chain; mixed zero/positive latency;
positive-delay chain; partially reachable fork; isolate; singleton;
closed bounds; positive traversal duration; cross-session wall;
equal-cost bounded session ties; P08’s later-prefix trap and equal
diamond; row permutation; relabelling; translation; and positive
scaling.

**Oracle:** independently enumerate complete vertex-simple atom
sequences, select endpoint arrival/hops only after enumeration, reduce
each endpoint once with the literal equation, and compare the complete
latency table before the scalar.
[`tsna::tPath()`](https://rdrr.io/pkg/tsna/man/paths.html) calibrates
only matching arrival interiors; installed `tsna`, `networkDynamic`, and
`ndtv` expose no matching closeness scalar.

**References:** Holme, P., and Saramaki, J. (2012), *Temporal networks*,
Physics Reports 519, equations 3–4; Tang, J. et al. (2010), *Analysing
information flows and key mediators through temporal centrality
metrics*, SNS; and Buß et al. (2024), *Algorithmic aspects of temporal
betweenness*, for the P08 shortest-foremost family.

**Exit:** every reachable target is included exactly once; zero,
missing, and infinite values follow the equation; bounds and sessions
agree with paths; translation/scaling and duration properties pass;
zero-drop, absolute-arrival, epsilon, harmonic-reciprocal, hop-distance,
multiplicity-weighting, session-merging, and bounds-after-selection
mutants fail; and the universal gate passes.

### P10 — Exact temporal betweenness

**Status:** complete in Dynet 0.3.12. Definition and fixture reviews
converged before implementation; the literal suite, independent
exhaustive route-family oracle, compact/overflow stress,
transformations, deliberate mutants, implementation review, full tests,
standing calibrations, fresh tarball, and package check pass at the
recorded gate.

**Purpose:** distribute source-target dependency across all equally
optimal temporal journeys.

**Approved equation:** for a reachable forward ordered pair `(s,z)`, let
`sigma_sz` be the number of P08 canonical-atom shortest-foremost
journeys and let `sigma_sz(v)` count those whose internal named-vertex
sequence contains `v`. Define the raw temporal betweenness

\[ B(v)=\_{} . \]

Every reachable pair contributes at most one to a given vertex and
exactly `h_sz - 1` across all internal vertices, because every selected
pair family has common hop count `h_sz`. P07/P08’s shortest-foremost
optima are vertex-simple, so membership and one credit per route
coincide. Sources and targets never receive their endpoint dependency;
unreachable pairs, empty journeys, direct journeys, isolates, singleton
networks, and two-vertex networks contribute zero. All returned values
are finite and nonnegative. P08’s `dynet_path_overflow` is raised before
any inexact path family can enter the dependency calculation.

This is the unnormalized Freeman/Buß sum and deliberately preserves
Dynet’s existing chain scale. Its fixed theoretical range is
`[0, (n - 1)(n - 2)]`. Both directed and undirected temporal networks
use ordered `(s,z)` pairs: an undirected contact can be traversed either
way, but time-respecting reach is generally asymmetric, so static
undirected halving is wrong. A future normalized quantity must have an
explicit surface and use the fixed ordered-pair divisor `(n - 1)(n - 2)`
for both directedness values; it must not divide by the observed
reachable-pair count.

**Algorithm:** for each source, use P08’s contact-labelled appearance
DAG. For each reachable endpoint, seed its selected terminal states,
propagate suffix path counts backward in descending hop order, and
multiply each state’s exact prefix count by its suffix count. Sum states
back to their named vertices, excluding source and endpoint, then divide
by the endpoint’s complete `sigma_sz`. This endpoint-specific form is
deliberately simple and prevents a state selected as an endpoint for one
pair from losing its role as an intermediate for another. It never
expands route rows. Parallel predecessor atoms remain distinct; waiting
is not an arc.

In bounded mode, `sigma_sz` is the sum across only full `(arrival,hops)`
winning sessions. Numerators are accumulated in those session DAGs and
divided by that global winning-family count. Collapse erases session
identity before canonicalization. Separate reports session-local values
with the fixed global vertex universe and session-local default origin.
Closed bounds, interval and point rules, and positive traversal duration
are exactly P01–P08’s.

**Public surface:** preserve temporal `measure = "betweenness"`, enable
its existing `start` and `end` arguments, and add no normalization
argument. Betweenness-only results store
`criterion = "foremost_then_shortest"`,
`pair_domain = "forward_reachable_ordered"`, `normalization = "none"`,
and `path_identity = "canonical_atom_sequence"`. Mixed results scope
this record under `measure_metadata$betweenness`. Output remains one
tidy named-vertex row per measure and optional separate session.

**Fixtures:** five-node chain; equal and recurrent asymmetric diamonds;
three-way merge with suffix; P08’s later-prefix trap; cross-session
wall; tied, duplicated, and unequal-hop winning sessions; disconnected
component; simultaneous cycle; staggered and simultaneous undirected
chains; closed bounds; positive duration; duplicate and weighted rows;
interval segmentation; row/session permutation; relabelling;
translation; positive time scaling; and time-reversed transpose.

**Oracle:** independently canonicalize raw contacts, enumerate all
vertex-simple atom sequences for at most six vertices, apply P01–P05
feasibility directly, and select `(completion,hops)` only after complete
enumeration. Reduce literal internal named-vertex membership without
calling a production path, atom, state, session, or route-expansion
helper. Compare complete semantic route families and pairwise fractions
before aggregation. `tsna` is not an oracle for tied paths because it
retains one arbitrary path.

**References:** Freeman, L. C. (1977), *A set of measures of centrality
based on betweenness*, Sociometry 40; Brandes, U. (2001), *A faster
algorithm for betweenness centrality*, Journal of Mathematical Sociology
25; and Buß, Molter, Niedermeier, and Rymar (2024), *Algorithmic aspects
of temporal betweenness*, Network Science 12, Definition 7 and
shortest-foremost algorithm.

**Exit:** pairwise and global dependency conservation pass; tied
journeys and winning sessions split credit exactly; endpoint,
representative-tree, missing-division, recurrent-identity,
duplicate-row, one-label-prefix, wrong-criterion, session-merge,
first-session, static-undirected-halving, accidental-normalization,
ignored-bound/duration, state-occurrence, eager-route, and overflow
mutants fail; state-to-vertex aggregation, relabelling, permutation,
translation, scaling, reversal, and the universal gate pass.

### A01 — Burstiness and memory audit

**Purpose:** calibrate existing public event-sequence mathematics before
adding new measures.

**Status:** complete in Dynet 0.3.13. The literal contract suite,
independent raw-incidence oracle, extreme-scale checks, standing
equivalence layers, and implementation review pass with no remaining
finding.

**Approved event identity:** each raw spell row contributes one onset
event to each distinct incident vertex. Direction does not change
incidence. A self-loop therefore contributes one event, not two stubs.
Distinct rows at the same timestamp remain distinct events and create
zero interevent gaps after sorting. Interval termini, durations, and
weights do not alter this row-event sequence; weight is explicitly
ignored rather than expanded as multiplicity.

For one sequence of sorted event times, let `tau` be consecutive
differences. For bounded sessions, construct `tau` independently inside
every session and pool those primitive within-session gaps; never form a
gap across a wall. Collapse erases labels before sorting and therefore
includes calendar gaps between sessions. Separate reports a
fixed-universe block per session. The `events` count is the number of
incident onset occurrences; in bounded mode the number of usable gaps
can be less than `events - 1`.

**Approved equations:** with `k` usable gaps, define their empirical
mean and population standard deviation

\[ =k^{-1}\_i_i, =, B=(-)/(+). \]

`mean_gap` is defined for `k >= 1`. Burstiness requires `k >= 2` and is
`NA` when `mu = sigma = 0`; otherwise finite nonnegative gaps give
`B in [-1,1)`, with one only a limit. This is the direct equal-mass
empirical plug-in for Goh and Barabasi’s interevent distribution, not
R’s [`sd()`](https://rdrr.io/r/stats/sd.html) sample denominator and not
the Kim–Jo finite-size-corrected variant.

For every within-sequence adjacent gap pair
`(x_j,y_j)=(tau_i,tau_(i+1))`, pool the pairs without crossing session
walls and define memory as their ordinary Pearson correlation. It
requires at least two pairs and nonzero variance in both marginal
vectors; otherwise it is `NA`. Thus one ordinary sequence normally needs
at least four events. The exact finite-sample value is `cor(x,y)`, lies
in `[-1,1]`, and regular constant gaps have undefined memory, not one.

Zero events report `events = 0` and all other quantities `NA`; one event
has no gap; two events have only `mean_gap`; three events can define
burstiness; four can define memory if both lag vectors vary. Equal-time
zero gaps are data, not missingness. Translating time preserves every
result. Positive scaling preserves events, burstiness, and memory while
multiplying `mean_gap`.

**Public surface:** retain
[`burstiness()`](https://mohsaqr.github.io/Dynet/reference/burstiness.md)
and its existing four measure names. Results publish
`event_identity = "incident_spell_start"`, `dispersion = "population"`,
`memory = "lag1_pearson"`, `loop_contribution = "one_event"`,
`weights = "ignored"`, and a mode-specific `session_gaps` attribute
(`"included"`, `"excluded"`, or `"session_local"`). Undefined cases are
literal `NA`, never `NaN`.

**Fixtures:** regular, hand-calculated irregular, alternating,
clustered, equal-time and all-zero gaps; zero through four events;
loop-once; interval onset; weighted rows; collapse/bounded/separate
sessions; row/session permutation; relabelling; translation; positive
scaling; reversal; and shuffled gap order.

**Oracle:** construct named incidence occurrences directly from raw
public spells, form session-local gap and adjacent-pair tables, pool the
primitive tables according to mode, and apply literal sums, squared
deviations, and dot products without `.burst_stats()`,
`.split_sessions()`, [`sd()`](https://rdrr.io/r/stats/sd.html), or
[`cor()`](https://rdrr.io/r/stats/cor.html). Compare event/gap/pair
tables before scalars. No installed comparison package is an oracle
unless its finite plug-in and session conventions match exactly.

**Reference:** Goh, K.-I., and Barabasi, A.-L. (2008), *Burstiness and
memory in complex systems*, EPL 81, 48002, equations 1 and 4,
<doi:10.1209/0295-5075/81/48002>.

**Exit:** sample-SD, timestamp-deduplication, zero-gap removal,
loop-double, loop-drop, endpoint-direction, interval-end,
weight-expansion, cross-session gap, cross-session lag,
per-session-coefficient averaging, regular-memory, all-zero, threshold,
absolute-time, and scaling mutants fail; literal values, session
pooling, translation/scaling, and the universal gate pass.

### A02 — Temporal mixing audit

**Purpose:** freeze the group-mixing table and its margins.

**Status:** complete in Dynet 0.3.14. Literal tables and margins, the
source-independent raw-dyad oracle, scoped `ergm` calibration,
collision-safe public labels, standing regressions, and implementation
review pass.

**Approved unit and activity:** one row is one reporting-bin/group-pair
cell. First form the binary active vertex-dyad snapshot under the shared
grid rule. A directed dyad `(u,v)`, or undirected unordered dyad
`{u,v}`, is present when at least one of its raw spells is active in the
bin. Positive windows use overlap with `[lo,hi)` and the established
final-bin closure; point sampling uses interval activity
`start <= t < end` and exact point events. Duplicate, overlapping, or
split spells and edge weights never multiply a binary dyad. Overlapping
reporting windows may count the same dyad once in each window.

For group map `g`, the directed table contains every ordered pair and is

\[ M\_{ab}=*{u:g(u)=a}*{v:g(v)=b}Y\_{uv}. \]

It has `q^2` cells, reciprocal dyads remain distinct, and a retained
loop contributes one to its diagonal cell. Thus `sum(M)=E`; row margins
are grouped outdegree and column margins grouped indegree, with a loop
contributing one to each. Cell maxima are `n_a n_b`, with a loopless
diagonal maximum `n_a(n_a-1)`.

The undirected table contains exactly one lexicographically canonical
cell `(a,b)`, `a <= b`, so it has `q(q+1)/2` rows rather than a
symmetric duplicate table. Cross-group edges, within-group edges, and
retained loops each contribute one. Again `sum(M)=E`. Its grouped stub
margin is

\[ d_a=2M\_{aa}+*{ba}M*{(a,b),(a,b)}, \_a d_a=2E. \]

A retained loop is one mixing edge but two undirected degree stubs. The
cross cell maximum is `n_a n_b`; the diagonal maximum is
`choose(n_a,2)+n_a` when loops are retained and `choose(n_a,2)`
otherwise. Mixing deliberately counts an explicitly retained loop even
though path/density kernels remove diagonals.

**Groups, sessions, and undefined cases:** the fixed group universe
contains every realized vertex attribute value, including isolates, in
deterministic character order. Missing values form one explicit
collision-safe level ordered after observed labels; a literal user label
such as `"(missing)"` remains a different group. A missing attribute
column raises classed `dynet_unknown_attribute`. Every supported cell is
emitted, including zeros in empty bins and separate sessions. A
singleton has one zero diagonal cell, or one when its retained loop is
active. Values are nonnegative integer counts; zero means no active
dyad, while `NA`, `NaN`, and infinity are never results.

Bounded and collapsed snapshot mixing both take the binary calendar
union: the same active dyad in two sessions counts once. Session walls
constrain multi-edge journeys and event-gap adjacency, not a
one-snapshot dyad identity. Separate mode reports one session-local
table over the fixed global group universe and its existing
session-local default grid. Consequently separate tables are not
generally additive to the collapsed table.

**Public surface:** retain
[`mixing()`](https://mohsaqr.github.io/Dynet/reference/mixing.md) and
its arguments. `value` remains a raw, unnormalized binary-dyad count;
weighted mixing is not added, and any future weight-sum quantity needs a
distinct public name. Directed display labels use `"A -> B"`; undirected
labels change to the truthful `"A -- B"`. Structured `from_group` and
`to_group` columns are authoritative and are never reparsed from display
text. Results publish `unit = "active_binary_dyads"`,
`pair_domain = "directed_ordered"` or `"undirected_unordered"`,
`normalization = "none"`, `weights = "ignored"`,
`loops = "retained_once"`, `missing_group = "explicit_level"`, and
`session_aggregation = "binary_calendar_union"` or `"session_local"`.
Newman’s normalized mixing matrix `e` is deliberately not this raw
table.

**Fixtures:** a literal directed two-group table with exact row/column
margins; reciprocal cross- and within-group dyads; the corresponding
undirected triangle and stub margins; missing values plus a literal
`"(missing)"` label; repeated, overlapping, split, and weighted spells;
one retained loop; empty bins; singleton; collapse/bounded/separate
duplicated sessions; group labels containing both display delimiters;
row/session permutation; vertex and group relabelling; endpoint
reversal/transposition; time translation and scaling; and undirected
stored-orientation reversal.

**Oracle:** select active raw spells and canonicalize directed or
undirected dyad keys without `.active()`, `.adjacency()`, `.binary()`,
`.over_bins()`, `.split_sessions()`, or a production mixing helper.
Compare active dyad sets, complete cells, totals, and grouped degree
margins before public results. On matched simple loopless snapshots,
compare independently aligned cells with
`ergm::nodemix("group", levels2 = TRUE)`; this external check validates
table reduction, not temporal windows, session semantics, loops, or
weights.

**References:** Newman, M. E. J. (2003), *Mixing patterns in networks*,
Physical Review E 67, 026126, <doi:10.1103/PhysRevE.67.026126>; Morris,
M., Handcock, M. S., and Hunter, D. R. (2008), *Specification of
exponential-family random graph models: terms and computational
aspects*, Journal of Statistical Software 24(4),
<doi:10.18637/jss.v024.i04>; and the `ergm` 4.12 `nodemix` term
definition.

**Exit:** spell-count, weight-expansion,
group-before-dyad-deduplication, direction-loss, transposition,
symmetric-undirected, within-group-halving, loop-drop,
missing-drop/collision, zero-cell omission, delimiter-parsing,
wrong-window-boundary, onset-only, bounded-session-multiplicity,
separate-universe, factor-order, absolute-time, and scaling mutants
fail; literal cells, totals, margins, transformations, limited `ergm`
calibration, and the universal gate pass.

## Prestige features

Each prestige definition is a separate feature, calibration, version,
and exit gate. The candidate public call is
`dyn_centrality(dn, measure = "prestige", prestige = "domain")`.

### S01 — Prestige: indegree

**Purpose:** add the first public prestige definition and prove its
exact relationship to directed in-degree.

**Status:** complete in Dynet 0.3.15. Exact binary indegree equality,
block normalization and `NaN` degeneracy, loop/session/boundary
semantics, mixed binary-versus-valued isolation, direct raw-spell and
`sna` calibration, transformations, standing regressions, documentation,
and independent implementation review pass.

For one directed binary active-dyad snapshot `B`, define degree prestige

\[ p_j=*i B*{ij}, B\_{ij}=1{ij}. \]

This is received nominations and is definitionally identical, vertex by
vertex and bin by bin, to
`dyn_centrality(measure = "degree", mode = "in")`. It is not
in-strength: duplicate, overlapping, or split spells and edge weights do
not multiply `B`. An explicitly retained directed loop contributes once
to its vertex’s prestige. Raw values are nonnegative integers with range
`[0,n-1]` without loops and `[0,n]` when loops are retained. Isolates,
empty snapshots, and a loopless singleton have raw value zero.

With `rescale = TRUE`, normalize independently inside each reported
time/session block:

\[ q_j=p_j/\_kp_k. \]

When the total is positive, values lie in `[0,1]` and sum to one. When
every raw value is zero, normalization is undefined and every returned
value is literal `NaN`, matching
[`sna::prestige()`](https://rdrr.io/pkg/sna/man/prestige.html)’s
division by zero; it is not silently replaced by zero or `NA`. An
isolate in a nonempty block remains zero. A singleton retained loop has
raw and normalized value one.

Prestige is directed-only. Undirected degree has no nomination
direction, and a retained undirected loop uses a two-stub degree
convention that cannot equal `sna` prestige’s one-loop convention.
Undirected requests therefore raise classed `dynet_needs_directed`.
`mode` does not alter prestige: incoming direction is intrinsic. Bounded
and collapsed snapshot modes take the same binary calendar union, while
separate mode reports a session-local vector over the fixed global
vertex universe. Rescaling is block-local, never global over times or
sessions. Activity uses the established interval-overlap, exact point,
and final-bin rules.

**Public surface:** add
`dyn_centrality(dn, measure = "prestige", prestige = "indegree", rescale = FALSE)`
at snapshot scope. `prestige` is one supported scalar choice in S01 and
reserves the selector for S02–S09; `rescale` is one logical and errors
when true without a prestige measure. No public `diag`, `nodes`,
`tmaxdev`, or `tol` argument is added. Output remains tidy with
`measure = "prestige"`. A prestige-only result directly publishes
`definition = "indegree"`, `direction = "incoming"`,
`matrix_transform = "none"`, `normalization = "none"` or `"sum_to_one"`,
`unit = "active_binary_dyads"` or `"share_of_active_binary_dyads"`,
`weights = "ignored"`, `loops = "retained_once"`, `zero_total = "NaN"`,
and session aggregation. Mixed results store the record under
`measure_metadata$prestige`.

**Fixtures:** single arc; reciprocal pair; chain; in- and out-stars;
isolate; empty bin; loopless and looped singleton; retained loop plus
incoming arc; repeated, overlapping, split, and weighted spells; two
distinct senders; undirected rejection; collapse/bounded/separate
sessions with fixed universe; several bins to catch global
normalization; row/session permutation; vertex relabelling; endpoint
reversal; time translation/scaling; and mixed degree/prestige output.

**Oracle:** select active public spells by literal interval/point rules,
form a fixed-name binary adjacency matrix without production grid,
activity, adjacency, binary, session, degree, or prestige helpers, and
calculate column sums plus block-local shares directly. Compare the
active matrix and prestige vector before the public result, then
key-join every raw value against public degree mode `in`. Compare binary
matrices with
`sna::prestige(cmode = "indegree", gmode = "digraph", diag = loops, rescale = ...)`;
`sna` valued inputs are outside the equivalence domain because they sum
magnitudes.

**References:** Wasserman and Faust (1994), *Social Network Analysis:
Methods and Applications*, Chapter 5; and `sna` 2.8
`prestige()`/`degree()` definitions.

**Exit:** outdegree/row-sum, all-degree, transpose, spell-count,
weight-sum, loop-drop/double, `n-1`/max/global normalization,
empty-zero/`NA`, isolate-drop, undirected-acceptance, mode-sensitive,
bounded-session-multiplicity, separate-universe, wrong-boundary,
name/order, absolute-time, and scaling mutants fail; raw equality to
degree-in, finite `sna` agreement, literal `NaN` degeneracy, tidy shape,
metadata, standing gates, and implementation review pass.

### S02 — Prestige: indegree row-normalized

**Purpose:** measure received nomination mass after every active sender
splits one unit equally across its distinct active outgoing dyads.

**Status:** complete in Dynet 0.3.16. Literal row-stochastic
calculations, zero-row and zero-total behavior, pre-normalization loop
policy, binary weight/representation invariance,
session-before-normalization semantics, direct raw-spell and `sna`
calibration, standing regressions, documentation, and independent
implementation review pass.

For the same directed binary active-dyad snapshot `B` as S01, let

\[ d_i=*k B*{ik}, R\_{ij}=
``` math
\begin{cases}B_{ij}/d_i,&d_i>0,\\0,&d_i=0,\end{cases}
 \qquad
```

p_j=*iR*{ij}. \]

Thus `R` is the uniquely defined row-stochastic transform on nonzero
rows; every zero outgoing row is explicitly an all-zero row. Each active
sender contributes exactly one unit in total, divided uniformly over
binary outgoing neighbors. This transform occurs before the incoming
column sum. It is not S01 indegree followed by normalization, and it is
not column normalization. If `r = sum(d_i > 0)`, then `sum(p) = r`. Raw
scores are nonnegative rational sender-nomination mass with graph-size
range `[0,n-1]` without loops and `[0,n]` when loops are retained.

With `rescale = TRUE`, apply the existing second-stage score
normalization inside each reported time/session block:

\[ q_j=p_j/\_kp_k=p_j/r \]

when `r > 0`. These values lie in `[0,1]` and sum to one. When `r = 0`,
raw scores are all zero and every rescaled score is literal `NaN`. An
outgoing isolate contributes no mass but may receive prestige; an
incoming isolate and a total isolate score zero. A loopless singleton is
raw zero/rescaled `NaN`; a retained singleton loop is raw and rescaled
one. The transform is closed form and unique: S02 has no tolerance,
iteration, convergence, or eigenvector ambiguity.

Binary support is formed before row normalization. Duplicate,
overlapping, and split spells and event weights do not change `B` or the
shares. A retained loop is one outgoing choice and one incoming
contribution and participates in its row denominator. The measure
remains directed-only, snapshot-only, and intrinsically incoming; `mode`
is ignored. Bounded/collapse form their binary calendar union before
normalization. Separate mode normalizes each session over the fixed
global vertex universe. Every transform and optional rescaling is
block-local and inherits the established interval-overlap, exact-point,
final-bin, and grid rules.

**Public surface:** extend the S01 selector with exact
comparison-package spelling `prestige = "indegree.rownorm"`; keep
`rescale`, tidy `measure = "prestige"`, and the same classed
directed/snapshot validation. The human label becomes
`"Row-normalized indegree prestige"`. Prestige-only metadata publishes
`definition = "indegree.rownorm"`, `direction = "incoming"`,
`matrix_transform = "row_stochastic"`, `zero_rows = "all_zero"`,
`normalization = "none"` or `"sum_to_one"`,
`unit = "active_sender_nomination_mass"` or
`"share_of_active_sender_nomination_mass"`, `weights = "ignored"`,
`loops = "retained_once"`, `zero_total = "NaN"`, and session
aggregation. Mixed output keeps the same record under
`measure_metadata$prestige`. No public `tol` argument is added.

**Fixtures:** zero matrix; single arc; reciprocal pair; chain; in- and
out-stars; incoming, outgoing, and total isolates; loopless/looped
singleton; loop plus another outgoing choice;
repeated/split/overlapping/weighted spells; several bins;
bounded/collapse/separate sessions; and the discriminator

\[ B=
``` math
\begin{bmatrix}0&1&1\\0&0&0\\0&1&0\end{bmatrix}
```
, R=
``` math
\begin{bmatrix}0&1/2&1/2\\0&0&0\\0&1&0\end{bmatrix}
```

, \]

which gives `p = (0, 3/2, 1/2)` and `q = (0, 3/4, 1/4)`. This differs
from raw indegree `(0,2,1)`, column-normalized indegree `(0,1,1)`, and
the transpose-row-normalized result `(3/2,0,1/2)`.

**Oracle:** independently select active public spells by literal
interval and point rules, form fixed-universe binary `B`, count each
positive row with a direct loop, allocate `1/d_i` to its targets, and
accumulate columns. Do not call a production grid, activity, adjacency,
binary, session, normalization, degree, or prestige helper. Compare
active dyads, `B`, `R`, `p/q`, and keyed public values. On independently
binarized matrices, compare
`sna::prestige(cmode = "indegree.rownorm", gmode = "digraph", diag = loops, rescale = ...)`.
Valued `sna` input is outside equivalence because it divides edge
magnitudes by valued row sums; Dynet deliberately ignores weights.

**References:** Wasserman and Faust (1994), Chapter 5, for incoming
nomination prestige; Butts (2024), `sna` 2.8 `prestige()` and
`make.stochastic()` definitions, <doi:10.32614/CRAN.package.sna>, for
this exact transform.

**Exit:** S01/raw-column-sum, column-normalization,
transpose/wrong-margin, receiver-outdegree, fixed-`n`, `n-1`, maximum,
edge-count, valued/spell-count, zero-row-`NaN`,
loop-drop/double/normalize-then-drop, session-before-union,
session-multiplicity, global rescaling, empty-zero/`NA`,
isolate/name-order, undirected-acceptance, mode-sensitive,
wrong-label/metadata, boundary, absolute-time, and scaling mutants fail;
literal nonsingular and degenerate calculations, exact finite `sna`
agreement, public transformations, standing gates, and implementation
review pass.

### S03 — Prestige: indegree row-column-normalized

**Purpose:** define row-column normalization as a deterministic
full-vertex binary matrix scaling, including the structural cases in
which no such score exists.

**Status:** complete in Dynet 0.3.17. Full-vertex total-support
certification, deterministic Sinkhorn–Knopp balancing, exact uniform
feasible scale, classed warned-`NA` infeasibility/nonconvergence,
loop/session/weight ordering, permutation and algebraic oracles, scoped
nonrandom `sna` calibration, standing regressions, documentation, and
independent implementation review pass.

For directed binary active-dyad matrix `B`, seek positive diagonal
matrices `D_r,D_c` such that

\[ X=D_rBD_c,X=, X^T=, p_j=*iX*{ij}. \]

The transform preserves the zero pattern and every positive binary dyad.
It exists exactly when `B` has **total support**: every positive entry
lies on a positive diagonal, equivalently every support edge belongs to
at least one perfect matching of the full `n`-by-`n` bipartite vertex
matrix. A single perfect matching is insufficient. When total support
holds, `X` is unique; the diagonal factors need not be unique unless the
support is fully indecomposable. Dynet does not reduce to active
rows/columns and does not prune unsupported active edges: either would
change the fixed vertex universe or the observed dyad support.

Feasibility is certified deterministically before scaling. Find one full
bipartite matching by ordered augmenting paths. Orient each nonmatching
edge from its row to the row matched to its column; a nonmatching edge
belongs to some perfect matching exactly when its two row endpoints lie
in the same strong component of this alternating graph. Any zero
row/column, isolate, Hall violation, or edge outside all perfect
matchings makes the whole block structurally undefined.

For total-support `B`, use fixed-order Sinkhorn–Knopp sweeps: divide
every row by its sum, then every column by its sum. After each complete
sweep define

\[ ={\_i\|*jX*{ij}-1\|, \_j\|*iX*{ij}-1\|}. \]

Stop when finite `epsilon <= 1e-12`, with an internal cap of 10,000
complete sweeps. Preserve the exact zero pattern and require every
supported value to remain finite and positive. A certified feasible
block that misses the cap or develops nonfinite arithmetic emits one
classed `dynet_prestige_nonconvergence` warning and returns all
`NA_real_`; no partial approximation is published. Structural
infeasibility deterministically returns an all-`NA_real_` block without
treating it as an empty nomination count. Raw and rescaled undefined
blocks are both `NA`, distinct from S01/S02 zero totals and `NaN`.

Every successfully balanced column sums to one by definition. Therefore

\[ p=(1,,1), q=p/\_jp=(1/n,,1/n). \]

Raw feasible range is the singleton `{1}` and rescaled feasible range is
`{1/n}`. This definition cannot rank vertices: it is exposed as a
calibrated compatibility/transform diagnostic, not as a discriminating
centrality. A retained loop-only singleton is feasible and scores one; a
loopless singleton, empty block, or any block with an isolate is
undefined `NA`.

Binary support is formed before feasibility and balancing. Duplicate,
overlapping, and split spells and weights are ignored. Retained loops
are ordinary support edges and may create a perfect matching; loop
policy is resolved before the support test. Bounded/collapse take their
binary calendar union before feasibility. Separate checks each session
on the fixed global vertex universe, so an absent session vertex makes
that block undefined. Scaling is independently local to every
time/session block under the shared grid and activity rules.

**Public surface:** extend `prestige` with exact spelling
`"indegree.rowcolnorm"`; retain `rescale`, directed/snapshot-only
validation, intrinsic incoming direction, tidy `measure = "prestige"`,
and no public tolerance or RNG control. The label is
`"Row-column-normalized indegree prestige"`. Direct/scoped metadata
publishes `definition = "indegree.rowcolnorm"`,
`direction = "incoming"`,
`matrix_transform = "sinkhorn_knopp_row_column"`,
`support_requirement = "total_support_full_vertex_matrix"`,
`support_policy = "preserve_all_binary_dyads"`, `normalization = "none"`
or `"sum_to_one"`, unit `"balanced_incoming_nomination_mass"` or
`"share_of_balanced_incoming_nomination_mass"`, `weights = "ignored"`,
`loops = "retained_once_before_balancing"`, `undefined = "NA"`,
`zero_total = "not_applicable_feasible"`, solver tolerance `1e-12`,
error norm `"max_absolute_margin"`, maximum iterations `10000`, and
session aggregation.

**Fixtures:** directed cycle/permutation; complete matrix; reducible
total-support `diag(J2,1)`; retained-loop identity; loopless regular
support; zero matrix; single arc; chain; star; isolate; Hall-deficient
support without zero margins; perfect-matching-but-not-total-support
triangular/chord support; forced one-sweep non-convergence; several bins
and all session policies. The primary exact discriminator is

\[ B=
``` math
\begin{bmatrix}1&1&0\\1&1&1\\0&1&1\end{bmatrix}
```
, X=
``` math
\begin{bmatrix}\phi^{-1}&\phi^{-2}&0\\
 \phi^{-2}&\phi^{-3}&\phi^{-2}\\0&\phi^{-2}&\phi^{-1}\end{bmatrix}
```

, =(1+)/2. \]

One row-plus-column pass has correct column margins but row sums
`(39/40,21/20,39/40)`, so tests assert the internal transformed matrix
and residual, not only the necessarily uniform public vector. This
matrix has S01 `(2,3,2)`, S02 `(5/6,4/3,5/6)`, and S03 `(1,1,1)`.

**Oracle:** for `n <= 7`, independently enumerate all permutations and
their positive diagonals. Total support holds exactly when at least one
diagonal exists and the union of its cells equals every positive `B`
cell. For feasible literal matrices, calculate the maximum-entropy point
in the convex hull of their permutation matrices or use the stated exact
algebra, never the production matching/SCC or Sinkhorn code. Compare
support, feasibility reason, balanced matrix, maximum margin residual,
iterations/status, `p/q`, and keyed public values. Exact
`sna::prestige(cmode = "indegree.rowcolnorm")` agreement is required
only on matrices whose initial row/column pass is already doubly
stochastic, so its randomized annealer never runs. General feasible
seeded `sna` runs are qualitative residual evidence only; valued and
infeasible matrices are excluded.

Installed `sna` 2.8 uses a randomized, loose-tolerance annealer and does
not forward `prestige(tol=)` into `make.stochastic()`. Its nonuniform
results on a feasible matrix are numerical residuals, not prestige
differences. Dynet’s deterministic strict-support policy and undefined
cases are deliberate.

**References:** Sinkhorn, R. (1964), *Annals of Mathematical Statistics*
35, 876–879, <doi:10.1214/aoms/1177703591>; Sinkhorn, R. and Knopp, P.
(1967), *Pacific Journal of Mathematics* 21, 343–348,
<doi:10.2140/pjm.1967.21.343>; Knight, P. A. (2008), *SIAM Journal on
Matrix Analysis and Applications* 30, 261–275, <doi:10.1137/060659624>;
and Butts (2024), `sna` 2.8, <doi:10.32614/CRAN.package.sna>.

**Exit:** S01/S02, final-vector normalization, one-pass, column-only
residual, reversed sweep, transpose, random-annealer/RNG,
full-indecomposability, perfect-matching-only, silent support pruning,
isolate reduction, partial iterate, L1/mean residual, spell/weight,
loop-order, session-before-union, global scaling, `NA`-to-zero/`NaN`,
name/order, boundary, absolute-time, scaling, wrong label/metadata, and
return-ones-without-feasibility mutants fail; exact matrices, structural
failures, deterministic convergence, scoped `sna` evidence, standing
gates, and implementation review pass.

### S04 — Prestige: domain

**Purpose:** define Lin’s unweighted incoming reachability-domain
prestige on each directed active snapshot.

**Status:** complete in Dynet 0.3.18. Literal boundary and degeneracy
fixtures, independent simple-path enumeration, exact binary `sna`
calibration, public transformations, standing regressions,
documentation, and independent implementation review pass.

For fixed-universe binary directed adjacency `B`, let `H[i,j] = 1`
exactly when `i = j` or a directed path of at least one hop from `i` to
`j` exists. The incoming domain of vertex `j` and its raw prestige are

\[ D_j={ij:H\_{ij}=1}, p_j=\|D_j\|=*i H*{ij}-1. \]

Thus domain prestige is indegree in the directed reachability graph
after its reflexive diagonal is excluded. Every distinct predecessor
vertex contributes once regardless of path length, number of paths, or a
return cycle. It is not direct indegree, outgoing reach, weak-component
size, shortest-distance proximity, or temporal reachability through
chronologically ordered spells.

Raw values are exact integer counts in `[0,n-1]`; their sum is the
number of reachable ordered nonself vertex pairs in `[0,n(n-1)]`.
`rescale = TRUE` returns `q = p / sum(p)` independently within each
reporting block. A positive total yields values in `[0,1]` summing to
one. A zero total yields literal `NaN` for every vertex without a
warning, including empty active blocks and singletons. Isolates and
unreachable targets otherwise score zero. Explicit loops cannot change
nonself reachability and self is excluded even when a cycle returns to
its start.

Binary support is formed before closure. Duplicate, overlapping, and
split spells and every edge-weight magnitude are ignored. Bounded and
collapsed sessions take their binary calendar union before closure;
separate sessions close each session-local matrix on the fixed global
vertex universe. Closure is local to the inherited time/session block.
Activity and point/interval boundaries remain those of the snapshot
grid. Edges active at different times inside one positive window may
concatenate in this static closure even when their raw chronology
prevents a time-respecting journey.

**Public surface:** extend `prestige` with exact spelling `"domain"`;
retain `rescale`, directed/snapshot-only validation, intrinsic incoming
direction, tidy `measure = "prestige"`, and no new path arguments. The
label is `"Domain prestige"`. Direct/scoped metadata publishes
`definition = "domain"`, `direction = "incoming"`,
`matrix_transform = "directed_transitive_closure"`,
`path_scope = "static_active_snapshot"`,
`path_weighting = "unweighted_distinct_reachers"`,
`self_reach = "excluded"`, normalization `"none"` or `"sum_to_one"`,
unit `"distinct_reaching_vertices"` or
`"share_of_ordered_reachable_pairs"`, `weights = "ignored"`,
`loops = "no_effect_self_excluded"`, `unreachable = "zero"`,
`zero_total = "NaN"`, and session aggregation. `mode` is ignored.

**Fixtures:** zero matrix; loopless and loop-only singleton; single arc;
reciprocal pair; fork and merge; chain and reversed chain; diamond with
two paths but one source credit; redundant transitive edge; directed
cycle; strong component with a tail; disconnected chain, component, and
isolate; strongly connected asymmetric graph that separates domain from
distance weighting; loops; duplicates, values, and interval
representations; several bins; all session policies; exact onset,
terminus, point, positive-window, and final-bin boundaries. A window
containing early `B -> C` and later `A -> B` must still score the static
union as the chain `(0,1,2)` although chronological forward reach would
deny `A -> C`.

**Oracle:** independently select raw spells under literal grid/session
rules, form binary dyads, and enumerate every simple vertex sequence of
lengths one through `n-1` for each ordered nonself pair. Mark reach once
when any sequence is valid, then compare the full Boolean closure,
raw/rescaled values, and keyed public output. Do not call Dynet
activity, adjacency, geodesic, reachability, or prestige helpers. Exact
`sna` 2.8 agreement is required for binary directed matrices on the same
full vertex universe using `cmode = "domain"`; valued/edgelist inputs,
`gmode = "graph"`, node subsets, and temporal activity are outside the
honest comparison domain.

**References:** Lin, N. (1976), *Foundations of Social Research*,
McGraw-Hill; Wasserman, S. and Faust, K. (1994), *Social Network
Analysis*, Chapter 5, <doi:10.1017/CBO9780511815478.006>; and Butts
(2024), `sna` 2.8, <doi:10.32614/CRAN.package.sna>.

**Exit:** outgoing, transpose, direct-indegree, weak-component,
include-self, path-multiplicity, distance-weighted,
chronological-temporal, loop-credit, valued/spell-count,
closure-before-session-union, cross-session-separate, wrong-rescaling,
global-block, zero-to-zero/`NA`, isolate/name/order, mode, undirected,
temporal-scope, and boundary mutants fail; literal closure, independent
enumeration, exact binary `sna` agreement, transformations, standing
gates, documentation, and implementation review pass.

### S05 — Prestige: domain proximity

**Purpose:** define Lin’s incoming domain fraction discounted by mean
directed hop distance, including the correct treatment of unreachable
vertices.

**Status:** complete in Dynet 0.3.19. Literal geodesic, disconnected,
boundary, session, and binary-isolation fixtures; independent
simple-path enumeration; scoped exact and explicit divergent `sna`
evidence; standing regressions; documentation; and independent
implementation review pass.

For binary directed snapshot `B`, let `d(i,j)` be the unweighted
directed shortest-path distance, and define

\[ D_j={ij:d(i,j)\<},r_j=\|D_j\|, s_j=\_{iD_j}d(i,j), \]

\[ p_j=
``` math
\begin{cases}
 0,&r_j=0,\\
 \dfrac{r_j/(n-1)}{s_j/r_j}
 =\dfrac{r_j^2}{(n-1)s_j},&r_j>0.
 \end{cases}
```

\]

Unreachable vertices are excluded from both `r_j` and `s_j`; self is
excluded. Every predecessor contributes once and its minimum hop count
is used, so path multiplicity is irrelevant but a transitive shortcut
may raise prestige. This is incoming, not outgoing, proximity and is not
S04 unweighted domain, direct indegree, harmonic centrality, or
chronology-aware temporal closeness.

Raw values are dimensionless in `[0,1]`, with one attained exactly when
every other vertex has a direct arc into the target. A zero domain,
isolate, empty active block, or singleton has raw value zero.
`rescale = TRUE` additionally divides by the block sum; positive blocks
sum to one and an all-zero block is literal all-`NaN` without warning.
Adding one isolate to an `n`-vertex graph multiplies existing raw values
by `(n-1)/n`, appends zero, and leaves defined rescaled shares
unchanged.

Binary window/session union precedes geodesics. Weights, duplicates, and
overlap/split representation are ignored; loops cannot alter nonself
shortest distances. Bounded/collapse use the calendar union, while
separate computes session-local geodesics on the fixed global vertex
universe. Closure is static inside each inherited snapshot block:
differently timed dyads within a window may concatenate without
chronological feasibility. Time translation and positive scaling
therefore leave values unchanged.

**Deliberate `sna` difference:** installed `sna` 2.8 evaluates
unreachable terms as `FALSE * Inf`, producing `NaN` distance sums and
then replacing those scores with zero. It consequently zeros every
partial nonempty incoming domain. On `A -> B -> C`, the published
equation gives `(0,1/2,2/3)` while `sna` returns `(0,0,2/3)`. Dynet must
not copy this arithmetic artifact. Exact whole-vector `sna` agreement is
restricted to binary directed matrices where each vertex has either an
empty domain or all `n-1` predecessors; partial domains are an explicit
expected divergence, never tolerance-filtered.

**Public surface:** extend `prestige` with exact spelling
`"domain.proximity"`; retain `rescale`, directed/snapshot-only
validation, intrinsic incoming direction, and no new path/tolerance
arguments. The label is `"Domain proximity prestige"`. Metadata
publishes the selector and direction,
`matrix_transform = "directed_unweighted_geodesics"`,
`path_scope = "static_active_snapshot"`,
`domain = "distinct_reaching_nonself_vertices"`,
`distance = "minimum_hop_count"`,
`path_weighting = "domain_fraction_over_mean_distance"`,
`unreachable = "excluded_from_domain_and_distance_sum"`,
`formula = "r^2/((n-1)*sum_distance)"`,
`network_size_normalization = "n_minus_one"`, normalization
none/sum-to-one, unit `"lin_domain_proximity"` or
`"share_of_lin_domain_proximity"`, ignored weights,
no-effect/self-excluded loops, `zero_domain = "zero"`,
`zero_total = "NaN"`, and session aggregation. `mode` is ignored.

**Fixtures:** zero, singleton, loop-only, single and reciprocal arcs;
fork, merge, chain and reverse chain; chain plus a transitive shortcut;
diamond; directed cycle and complete graph; strong component with tail;
disconnected chain/component/isolate; strongly connected asymmetric
distance discriminator; loops; representations and values; multiple
blocks; every session policy; static-versus-temporal chronology; exact
interval, point, and closed-final-bin boundaries. The primary literal
chain has `r=(0,1,2)`, `s=(0,1,3)`, raw `(0,1/2,2/3)`, and rescaled
`(0,3/7,4/7)`. The four-cycle plus shortcut `A->C` has raw
`(1/2,1/2,3/4,3/5)` and shares `(10,10,15,12)/47`.

**Oracle:** independently select raw spells and binary dyads, then
enumerate every simple directed vertex sequence through length `n-1` for
each ordered nonself pair. The minimum valid length is its distance.
Filter finite distances before summing, explicitly branch on `r=0`, and
compare binary adjacency, the full distance matrix, `r`, `s`,
raw/rescaled values, and keyed public output. Do not call Dynet
grid/activity/session/adjacency/binary/geodesic/prestige helpers or
external graph algorithms. Exact `sna` cases and explicit partial-
domain divergence are recorded separately.

**References:** Lin, N. (1976), *Foundations of Social Research*,
McGraw-Hill; Wasserman, S. and Faust, K. (1994), *Social Network
Analysis*, Chapter 5, <doi:10.1017/CBO9780511815478.006>; and Butts
(2024), `sna` 2.8, <doi:10.32614/CRAN.package.sna>.

**Exit:** S04/no-distance, direct indegree, outgoing/transpose,
undirected, self, path-count/sum, harmonic-mean, missing-square,
missing-domain-fraction, `n` denominator, `Inf` contamination/`sna` bug,
weighted/spell, loop, session-before-union/cross-session, temporal
chronology, active-subgraph universe, wrong rescaling, zero-domain
`NA`/`NaN`, all-zero normalized zero/NA, name/isolate/mode/scope, and
boundary mutants fail; literal distances, enumeration, scoped exact and
divergent `sna` evidence, transformations, standing gates,
documentation, and implementation review pass.

### S06 — Prestige: eigenvector

**Purpose:** define incoming binary eigenvector prestige only where its
Perron ray is mathematically unique.

**Status:** complete in Dynet 0.3.20. Literal Perron/periodic/reducible/
defective/undefined cases, independent characteristic-polynomial and
cofactor oracle, scoped `sna` calibration, binary/session/loop/boundary
gates, standing regressions, documentation, and independent
implementation review pass.

For directed binary active-dyad adjacency `B` (row sender, column
receiver), let `rho` be its spectral radius. Incoming prestige is the
nonnegative ray

\[ B^T p=p, p_j=^{-1}*i B*{ij}p_i. \]

Publish a score exactly when `rho > 0` and the eigenspace of `B^T` at
the real Perron root `+rho` is one-dimensional. Reducibility alone is
not failure: one positive-radius critical class may define a unique ray
with structural zeros elsewhere. A defective repeated Perron root is
also accepted when its ordinary eigenspace is one-dimensional and the
nonnegative vector and residual checks pass; the equation asks for a
unique eigenvector ray, not perturbation stability. Two equal dominant
components or any other higher-dimensional Perron eigenspace are
undefined. A zero spectral radius is undefined even when a nilpotent
matrix has a one-dimensional nullspace: empty blocks, zero graphs, DAGs,
and loopless singletons therefore return all `NA_real_`.

Equal-modulus eigenvalues other than `+rho` do not imply ambiguity.
Reciprocal and directed cycles have `-rho` or complex roots on the
spectral circle but a unique real nonnegative Perron ray and remain
valid. The solver must select the real `+rho` root, never the first
maximum-modulus eigenvalue.

Orient the ray by a positive sum. Materially mixed signs are numerical
failure; only tolerance-sized negative noise may be clamped to zero,
never transformed with elementwise absolute value. Raw
(`rescale = FALSE`) scores have Euclidean norm one, lie in `[0,1]`, and
sum in `[1,sqrt(n)]`. `rescale = TRUE` divides that feasible vector by
its sum. Undefined raw and rescaled blocks are both all `NA`, never
zero, `NaN`, or an arbitrary basis vector.

Use deterministic base-R direct eigenspectrum and SVD rank checks with
fixed internal relative tolerance `1e-10` and no public solver knob. Set
`rho=max(Mod(lambda))`, identify a real root within scaled tolerance,
compute the numerical nullity of `B^T-rho I`, extract/orient its one
null vector, and verify nonnegativity, unit scale, and maximum absolute
eigen residual. A structural zero-radius or nonunique block returns
`NA`; invalid/nonfinite spectral arithmetic likewise returns `NA`.
Public calls accumulate one classed `dynet_prestige_eigen_undefined`
warning and per-block diagnostics containing reason, spectral radius,
eigenspace dimension, and residual. No partial or arbitrary vector is
returned.

Binary support and loop policy precede the spectrum. Duplicate,
overlapping, and split spells and every weight are ignored. Retained
loops are genuine diagonal support and may change `rho`, uniqueness, and
the vector. Bounded and collapsed sessions take binary calendar union
before eigensolving; separate solves each session on the fixed global
vertex universe. Adding isolates to a defined positive-radius block
appends zeros without changing either scale. The measure is static
within each inherited snapshot block and invariant to time
translation/scaling.

**Public surface:** add exact selector `prestige = "eigenvector"`,
distinct from current `measure = "eigenvector"` (which is mode-aware,
max-normalized, and does not certify uniqueness). Prestige remains
directed/snapshot-only, intrinsically incoming, and ignores `mode`. The
label is `"Eigenvector prestige"`. Metadata publishes
`definition = "eigenvector"`, `direction = "incoming"`,
`matrix_transform = "transpose_binary_adjacency"`,
`eigenvalue = "positive_perron_root"`,
`spectral_requirement = "positive_radius_unique_perron_eigenspace"`,
`uniqueness = "geometric_multiplicity_one"`, `sign = "nonnegative"`, raw
normalization `"l2_unit"` or final `"sum_to_one"`, unit
`"l2_incoming_perron_weight"` or `"share_of_incoming_perron_weight"`,
ignored weights, retained-once loops before eigensolve, undefined `NA`,
solver/tolerance, error norm, and session aggregation.

**Fixtures:** a loop-free asymmetric plastic-constant matrix separating
incoming and outgoing rays; reciprocal and three-cycles with
negative/complex co-dominant roots; complete digraph; retained-loop
golden-ratio matrix; reducible unique dominant block with isolates;
lower-radius secondary block; defective but one-ray Perron root; two
equal dominant components and identity matrix; zero matrix, DAG, single
arc, and loopless/looped singleton; weights, duplicates, sessions,
several bins, static-versus-temporal union, exact
point/interval/final-bin boundaries, transformations, and mixed
strength.

For `B=[[0,1,1],[0,0,1],[1,0,0]]`, `rho` is the positive root of
`rho^3-rho-1=0` and incoming `u=(rho^-1,rho^-2,1)`. Raw is
`u/sqrt(sum(u^2))`; rescaled is `u/sum(u)`. A directed three-cycle is
raw `(1/sqrt(3),...)` despite complex roots appearing first in a generic
maximum-modulus eigensolver. Two reciprocal dyads are undefined `NA`.

**Oracle:** independently derive characteristic polynomials for literal
matrices by the Leibniz determinant formula, identify the positive
spectral root and multiplicity, determine nullity with independent
elimination, solve the stated eigenvector algebra, and check sign,
scale, and residual. It must not call the production prestige/eigen
helper. Random secondary checks may use an external eigensolver only
after independently gating a unique positive ray.

Installed `sna` 2.8 with `cmode = "eigenvector", diag = FALSE` reverses
loop-free edgelists and returns the incoming L2 ray; its outer `rescale`
makes the sum one. Exact comparison is limited to binary loopless
positive-radius unique cases where its power iteration demonstrably
converges. With `diag = TRUE`, `prestige()` skips the transpose and the
nested `evcent()` then drops loops under its own default, so looped
cases are an explicit excluded implementation defect. Zero-radius,
tied/reducible ambiguity, valued data, graph mode, node subsets, and
`tmaxdev` are not external oracles.

**References:** Bonacich (1972), <doi:10.1080/0022250X.1972.9989806>;
Wasserman and Faust (1994), Chapter 5,
<doi:10.1017/CBO9780511815478.006>; Berman and Plemmons (1994),
<doi:10.1137/1.9781611971262>; and Butts (2024), `sna` 2.8,
<doi:10.32614/CRAN.package.sna>.

**Exit:** outgoing/right-vector, symmetrized, direct-indegree,
valued/spell, loop-drop/double, max/L1 scale, missing second rescale,
arbitrary sign/abs, first-max-modulus/complex, reject-periodic,
accept-nonunique, reject-defective- unique, arbitrary component/sink,
zero/DAG arbitrary, no residual, session- before-union/global scaling,
active-universe, name/order/mode/temporal/boundary, and `sna diag=TRUE`
mutants fail; literal eigenpairs, independent algebra, scoped `sna`,
transformations, standing gates, documentation, and implementation
review pass.

### S07 — Prestige: eigenvector row-normalized

**Purpose:** measure incoming recursive prestige after every active
sender has one unit of binary nomination mass to distribute.

**Status:** complete in Dynet 0.3.21. Literal transform/eigenpair,
periodic, loop, zero-row, defective-one-ray, undefined, session,
boundary, and coordinate fixtures; independent
characteristic-polynomial/elimination oracle; scoped `sna` calibration;
standing regressions; documentation; and independent implementation
review pass.

For directed binary active-dyad adjacency `B`, let `d[i] = sum(B[i,])`
and form the row-stochastic matrix

\[ P\_{ij}=
``` math
\begin{cases}B_{ij}/d_i,&d_i>0,\\0,&d_i=0.\end{cases}
```

P^T p=(P)p. \]

Binary calendar union and loop policy precede row normalization. A
retained loop is one outgoing option in both the numerator and
denominator. Zero rows remain exactly zero: there is no teleportation or
dangling-row imputation. Thus each active sender divides one unit
equally among its distinct outgoing dyads, and inactive senders
contribute no mass. Normalization is performed before transpose and
before the Perron solve; row-normalizing `t(B)`, column- normalizing
`B`, or normalizing the final vector are different statistics.

S06’s certification contract applies unchanged to `P`: publish the
unique nonnegative ray exactly when `rho(P) > 0` and the ordinary
eigenspace of `P^T` at the real root `+rho` has geometric dimension one.
Reducible and defective- but-one-ray matrices and periodic matrices with
negative or complex peripheral peers remain valid. Zero-radius and
higher-dimensional Perron eigenspaces are all `NA` with the existing
classed warning and diagnostics. A zero row alone does not imply
failure; a substochastic matrix can have a unique positive root below
one. Raw scores are nonnegative and L2-unit; `rescale = TRUE` divides
the feasible ray to sum one.

Duplicate, overlapping, and split spells and weight magnitudes are
ignored. Bounded and collapsed sessions take binary union before row
normalization; separate sessions transform and solve independently on
the fixed global vertex universe. The definition is a static incoming
snapshot statistic, ignores `mode`, and is invariant to edge order,
names, time translation, and positive time scaling.

**Public surface:** add exact selector
`prestige = "eigenvector.rownorm"`, labelled
`"Row-normalized eigenvector prestige"`. Metadata records
`matrix_transform = "transpose_row_stochastic_binary_adjacency"`,
outgoing binary-dyad row denominators, exact zero rows,
positive-root/geometric- uniqueness certification, nonnegative sign,
L2/sum scale, ignored weights, loop-before-normalization, solver
tolerance, undefined `NA`, and session aggregation. No solver argument
is public.

**Fixtures:** for `B=[[0,1,1],[0,0,1],[1,0,0]]`, row normalization gives
`P=[[0,1/2,1/2],[0,0,1],[1,0,0]]`, `rho=1`, and incoming ray `(2,1,2)`:
raw `(2/3,1/3,2/3)` and rescaled `(2/5,1/5,2/5)`. This differs from S06,
row-normalized indegree, and the wrong transform order. Reciprocal and
directed cycles remain valid. `B=[[0,1],[1,1]]` gives ray `(1,2)`, while
dropping the loop gives the uniform reciprocal result. `B=[[1,1],[0,0]]`
has a zero sender row, `rho=1/2`, and ray `(1,1)`. Zero graphs, DAGs,
single arcs, tied recurrent components, retained-loop singletons,
weights/duplicates, session union, separate sessions, several bins,
interval/point/final-bin boundaries, and coordinate transformations
complete the literal matrix.

**Oracle and external comparison:** independently binarize selected raw
spells, divide literal matrix rows, construct `P^T`, derive
characteristic polynomials with the Leibniz determinant formula, and
obtain the Perron null ray with cofactors/elimination. Compare the
transform cells, radius/status, sign, residual, scales, and keyed public
output without calling Dynet’s normalization or eigensolver. Installed
`sna` 2.8 uses `eigen(t(make.stochastic(B, mode="row")))`; exact
comparison is restricted to binary primitive cases with a strict modulus
gap, aligning the arbitrary raw global sign. Periodic, tied, nilpotent,
and zero-radius behavior is deliberate oracle-tested divergence because
`sna` may select a complex or arbitrary basis vector.

**References:** Bonacich (1972), <doi:10.1080/0022250X.1972.9989806>;
Wasserman and Faust (1994), Chapter 5,
<doi:10.1017/CBO9780511815478.006>; Berman and Plemmons (1994),
<doi:10.1137/1.9781611971262>; and Butts (2024), `sna` 2.8,
<doi:10.32614/CRAN.package.sna>.

**Exit:** no-row-transform, S02 column sums,
transpose-before-row-normalize, column-normalize, wrong eigenvector
side, valued/count rows, zero-row NaN or imputation, loop-order,
arbitrary max-modulus/complex root, reject-periodic, accept-tied,
reject-defective-one-ray, arbitrary nilpotent sink, wrong L1/max or
missing rescale, session-before-union/global scaling, active-universe,
name/order/mode/scope/boundary mutants fail; literal
transforms/eigenpairs, independent algebra, scoped `sna`,
transformations, standing gates, documentation, and implementation
review pass.

### S08 — Prestige: eigenvector column-normalized

**Purpose:** measure incoming recursive prestige after every nominated
vertex’s binary incoming dyads have total weight one.

**Status:** complete in Dynet 0.3.22. Literal full-column and
zero-column transforms, periodic/loop/defective/undefined cases,
session-local scaling, closed-final-bin diagnostics, independent
characteristic-polynomial and elimination oracle, scoped `sna`
calibration, standing regressions, documentation, and independent
implementation review pass.

For directed binary active-dyad adjacency `B`, let `c[j] = sum(B[,j])`
and form

\[ Q\_{ij}=
``` math
\begin{cases}B_{ij}/c_j,&c_j>0,\\0,&c_j=0.\end{cases}
```

Q^T p=(Q)p. \]

Binary calendar union and loop policy precede column normalization. A
retained loop is one incoming option in both numerator and denominator.
Zero columns remain exactly zero, with no imputation or teleportation.
Conceptually the order is column-normalize `B`, transpose, then solve;
this is algebraically equivalent to row-normalizing `t(B)`, but not to
column-normalizing `t(B)` or using S07’s `t(row_normalize(B))`.

S06’s certification contract applies unchanged to `Q`: publish exactly
when `rho(Q) > 0` and the ordinary eigenspace of `Q^T` at real `+rho`
has geometric dimension one. Reducible, periodic, and
defective-but-one-ray matrices remain valid; zero-radius and genuinely
multidimensional Perron eigenspaces are all `NA` with the existing
classed warning and diagnostics. Raw scores are nonnegative and L2-unit;
`rescale = TRUE` makes their sum one. Because every nonzero row of `Q^T`
sums to one, `rho` lies in `[0,1]`. If every vertex has positive
indegree, a certified ray is necessarily uniform; informative nonuniform
scores require at least one zero column.

Duplicate, overlapping, and split spells and all weights are ignored.
Bounded and collapsed sessions take binary union before column
normalization; separate sessions transform, solve, and rescale
independently on the fixed global vertex universe. The definition is
directed, incoming, snapshot-only, ignores `mode`, and is invariant to
edge order, names, time translation, and positive time scaling.

**Public surface:** add exact selector
`prestige = "eigenvector.colnorm"`, labelled
`"Column-normalized eigenvector prestige"`. Metadata records
`matrix_transform = "transpose_column_stochastic_binary_adjacency"`,
distinct incoming binary-dyad column denominators, exact zero columns,
positive-root/ geometric-uniqueness certification, nonnegative sign,
L2/sum scale, ignored weights, loop-before-normalization, solver
tolerance, undefined `NA`, and session aggregation. No solver argument
is public.

**Fixtures:** for `B=[[0,1,1],[0,0,1],[1,0,0]]`, column totals `(1,1,2)`
give `Q=[[0,1,1/2],[0,0,1/2],[1,0,0]]`; the unique incoming ray is
uniform, raw `(1/sqrt(3),...)` and rescaled `(1/3,...)`, unlike S06 and
S07. For `B=[[1,1,0],[0,0,0],[1,0,0]]`, the third column is zero and
`rho=1/2` with ray `(1,2,0)`, raw `(1,2,0)/sqrt(5)`, and share
`(1/3,2/3,0)`. This differs from column sums. Reciprocal and directed
cycles remain valid. Retained-loop versus dropped-loop fixtures, zero
columns, zero graphs/DAGs/singletons, equal dominant components, a
defective geometric-one root, weights/duplicates, session
union/separation, several bins, interval/point/final-bin boundaries, and
coordinate transformations complete the literal matrix.

**Oracle and external comparison:** independently binarize selected raw
spells, divide literal matrix columns with scalar denominators,
transpose, derive characteristic polynomials by the Leibniz determinant
formula, and solve the Perron null ray with elimination. Compare every
transformed cell, radius/status, geometric dimension, sign, residual,
both scales, and keyed public output without Dynet’s normalization or
eigensolver. Installed `sna` 2.8 uses
`eigen(t(make.stochastic(B, mode="col")))`; exact comparison is
restricted to binary positive-radius cases with a strict modulus gap,
aligning the arbitrary raw global sign. Periodic, tied, nilpotent, and
zero-radius behavior is deliberate oracle-tested divergence because
`sna` may select a complex or arbitrary vector.

**References:** Bonacich (1972), <doi:10.1080/0022250X.1972.9989806>;
Wasserman and Faust (1994), Chapter 5,
<doi:10.1017/CBO9780511815478.006>; Berman and Plemmons (1994),
<doi:10.1137/1.9781611971262>; and Butts (2024), `sna` 2.8,
<doi:10.32614/CRAN.package.sna>.

**Exit:** S06/no transform, S07/row transform, direct column sums, wrong
transpose/order/side, valued/count columns, zero-column NaN or
imputation, loop-order, arbitrary max-modulus/complex root,
reject-periodic, accept-tied, reject-defective-one-ray, arbitrary
nilpotent sink, wrong max/L1 scale or missing rescale,
session-before-union/global scaling, active-universe,
name/order/mode/scope/boundary mutants fail; literal
transforms/eigenpairs, independent algebra, scoped `sna`,
transformations, standing gates, documentation, and implementation
review pass.

### S09 — Prestige: eigenvector row-column-normalized

**Status:** complete in Dynet 0.3.23. The full binary-union,
total-support, deterministic balancing, and certified incoming-Perron
pipeline is implemented with distinct structural, numerical, and
spectral terminal diagnostics. Literal balancing/spectrum fixtures, the
independent permutation/convex-dual oracle, scoped `sna` comparison,
transformations, standing gates, documentation, source/check/install
validation, and implementation review pass.

**Purpose:** compose certified binary matrix balancing with certified
incoming Perron prestige without returning an arbitrary partial
transform or ray.

For each reporting block, first form binary adjacency `B` after loop
policy and calendar/session union. Certify S03 total support on the full
fixed vertex matrix, then run its deterministic row-then-column
Sinkhorn–Knopp sweeps to obtain `X = D[r] B D[c]` with every row and
column sum one, maximum absolute margin residual at most `1e-12`, and at
most 10,000 sweeps. Only a completed balance enters the S06 equation

\[ X^T p=p. \]

The stages are terminal and ordered. Total-support failure returns all
`NA`, status `infeasible`, and `dynet_prestige_infeasible`; balance cap
or nonfinite arithmetic returns all `NA`, status `nonconverged`, and
`dynet_prestige_nonconvergence`; a successful balance whose Perron
eigenspace has geometric dimension other than one returns all `NA`,
status `undefined`, and `dynet_prestige_eigen_undefined`. No partial
iterate is eigensolved. Public multi-block calls aggregate each warning
class once. Diagnostics identify the terminal stage and keep balance
iterations/margin residual distinct from spectral radius/dimension/eigen
residual; successful balance evidence remains available when spectrum
certification fails.

Every valid `X` is doubly stochastic, so `rho(X)=1` and the all-ones ray
always exists. Total support alone is insufficient: block-diagonal
balanced matrices have several independent Perron rays. When the Perron
eigenspace is one-dimensional, every defined raw score is returned
theorem-exactly as `1/sqrt(n)` and every `rescale = TRUE` score as
`1/n`, after both certifications pass. Periodic irreducible matrices
remain valid. A defective Perron root cannot arise from a power-bounded
stochastic matrix, although S06’s geometric uniqueness rule remains the
shared general policy. S09 is therefore a support, balance, and
irreducibility diagnostic rather than a vertex ranking.

Empty/zero/DAG/isolate/single-arc/loopless-singleton blocks fail at
total support, not at zero spectral radius. A retained-loop singleton is
defined and scores one. Duplicate, overlapping, and split spells and all
weights are ignored. Retained loops enter before support certification.
Bounded/collapsed sessions union binary dyads before the full pipeline;
separate sessions run it independently on the fixed global universe. The
definition is directed, incoming, snapshot-only, ignores `mode`, and is
invariant to names, edge order, time translation, and positive scaling.

**Public surface:** add exact selector
`prestige = "eigenvector.rowcolnorm"`, labelled
`"Row-column-normalized eigenvector prestige"`. Metadata records the
full pipeline order, transpose of Sinkhorn-balanced binary adjacency,
total-support requirement/preservation, balance
solver/tolerance/cap/margin norm, Perron root/geometric
uniqueness/sign/solver/tolerance/eigen norm, exact uniform defined
values, L2/sum scale and units, loops, ignored weights, undefined `NA`,
terminal warning stages, and session aggregation. There is no public
solver or RNG argument.

**Fixtures:** the true-balancing support `B=[[1,1,0],[1,1,1],[0,1,1]]`
converges to the symmetric golden-ratio doubly stochastic matrix and
then returns uniform raw/shares; one sweep has exact row-margin residual
`1/20` and must not pass. Reciprocal and directed cycles prove periodic
validity. Full/loop-free regular supports prove exact uniform scales.
`diag(2)`, `diag(J2,1)`, and two disjoint cycles are balanceable but
spectrally nonunique. Zero margins, Hall failure, and
perfect-matching-but-not- total-support matrices fail at S03; a forced
one-sweep cap fails at balance. Looped/loopless singletons and
unsupported loops, weights/duplicates, session union and separate fixed
universes, mixed terminal stages, several bins, interval/point/final-bin
boundaries, and transformations complete the matrix.

**Oracle and external comparison:** independently enumerate every
permutation matching and require every support cell to occur in one.
Obtain literal exact balanced matrices or an independent maximum-entropy
solution, verify support and both margins, derive characteristic
polynomials by Leibniz expansion and geometric nullity by
elimination/SCC structure, and return exact uniform values only after
both gates. Compare adjacency, matching coverage, transform, residuals,
stage/status/reason, spectral dimension, scores, diagnostics, and keyed
public output without production matching, balancing, or spectral
helpers. Installed `sna` 2.8 uses a randomized loose-tolerance
row-column annealer followed by unguarded `eigen`; exact comparison is
restricted to binary regular primitive matrices whose first row/column
pass is already doubly stochastic and whose `+1` root has a strict
modulus gap. General balancing, periodic, tied, infeasible, valued, and
arbitrary-basis cases are documented exclusions/divergences.

**References:** Sinkhorn (1964), <doi:10.1214/aoms/1177703591>; Sinkhorn
and Knopp (1967), <doi:10.2140/pjm.1967.21.343>; Knight (2008),
<doi:10.1137/060659624>; Bonacich (1972),
<doi:10.1080/0022250X.1972.9989806>; Berman and Plemmons (1994),
<doi:10.1137/1.9781611971262>; Wasserman and Faust (1994), Chapter 5,
<doi:10.1017/CBO9780511815478.006>; and Butts (2024), `sna` 2.8,
<doi:10.32614/CRAN.package.sna>.

**Exit:** skip/weak/pruned total support, active-universe reduction, one
sweep, column-only residual, randomized balancing, partial iterate,
eigensolve-before- balance, re-binarized balance, always uniform/skip
spectrum, accept tied or arbitrary block, reject periodic, wrong scale,
valued/count/loop/session order, wrong terminal
stage/class/reason/residual, undefined zero/NaN, and coordinate/
mode/scope/boundary mutants fail; literal balancing/spectrum,
independent algebra, scoped `sna`, transformations, standing gates,
documentation, and implementation review pass.

For S01–S09, exact
[`sna::prestige()`](https://rdrr.io/pkg/sna/man/prestige.html) agreement
is not enough. Every feature also needs a literal nonsingular
calculation, a degenerate fixture, an undefined or non-convergent
fixture, and an explicitly reconciled scale.

## Observation features

### O01 — Observation bounds and clipping

**Status:** complete in Dynet 0.3.24. Non-destructive continuous
observation bounds, clipped activity/exposure views, preserved raw
endpoint events, hard temporal-path horizons, global explicit session
calendars, empty-view semantics, calendar conversion, classed query
intersection, independent intersection/change-point validation, scoped
`networkDynamic` comparison, standing gates, documentation,
source/check/install validation, and final review pass.

**Purpose:** represent one continuous observation interval.

**Definition:** let the raw event range be `[R_s,R_e]`. Optional scalar
`observation_start` and `observation_end` independently replace `R_s`
and `R_e`; the resulting continuous observation interval is `[O_s,O_e]`,
with `O_s <= O_e`. Numeric bounds use the network’s internal time scale.
`Date` or `POSIXct` bounds address calendar networks and are converted
against the constructor’s stored origin and unit. Missing, nonfinite,
nonscalar, scale-mismatched, or reversed bounds raise classed
`dynet_bad_input` errors.

Raw spells, weights, sessions, vertex membership, and aggregate network
data remain unchanged. Measurement obtains a derived view. A
positive-duration spell `[s,e)` contributes `[max(s,O_s),min(e,O_e))`
exactly when that intersection has positive duration. An instantaneous
event at `t` contributes unchanged exactly when `O_s <= t <= O_e`;
clipping never converts a positive interval into an instantaneous event.
The final closed observation endpoint for events is consistent with
Dynet’s default final-bin convention. Outside spells remain inspectable
through [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
but cannot enter a snapshot, path, duration, density numerator, or other
measured exposure.

Clipping defines activity, not event history: raw onsets and termini
remain the only genuine formation and dissolution times. A clipped left
endpoint does not fabricate a formation at `O_s`, and a clipped right
endpoint does not fabricate a dissolution at `O_e`. Explicit query
bounds are intersected operationally with the observed view and can
never recover preserved raw activity outside the observation interval.

`new_pairs` means first observed evidence: a pair already active at
`O_s` is not new later, while a raw tie wholly before `O_s` does not
suppress its first observed onset. Default temporal-path horizons are
hard `[O_s,O_e]` bounds; completion after `O_e` is inadmissible even
when a punctual contact is entered before it. Empty observed sessions
retain source-only path trees and zero source-excluding reach.

When either bound is explicit, metadata records the raw event range
separately from the observation interval, `time_range` becomes the
observation interval, and default global and per-session measurement
grids span observation time rather than shrinking to the first or last
observed edge. The fixed vertex and session universes survive even when
the derived view contains no edge. With no explicit bound the object,
default grid, and every existing result retain the pre-O01 behavior
exactly. A numeric equality with an observation boundary is not a censor
indicator; explicit censor state belongs to O03.

**Public surface:** add `observation_start = NULL` and
`observation_end = NULL` to
[`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md). The
tidy spell accessor continues to return one raw input-derived spell per
row with original `start` and `end`. Observation metadata supplies
`event_range` and `observation` only when a bound was explicitly
requested.

**Fixtures:** inside, outside-left, outside-right, left-clipped,
right-clipped, both-side clipped, starts-at-end, ends-at-start,
instantaneous events at both limits, an entirely empty observed view,
retained raw vertices and sessions, one-sided bounds, zero-span contact
observation, and `Date` and `POSIXct` bounds. Compare literal clipped
rows, activity masks, density, paths, default grids, and raw accessors.

**Oracle and external comparison:** independently intersect raw
intervals and point events by direct scalar cases and a change-point
exposure calculation; compare public snapshots with
[`networkDynamic::network.collapse()`](https://rdrr.io/pkg/networkDynamic/man/network.collapse.html)
on matched half-open interiors and its point extraction at the closed
final limit. Record the deliberate final-event closure and
raw-versus-measurement distinction.

**Exit:** no-clipping, destructive raw clipping, outside-row retention,
positive-to-point conversion, open final-event, raw-range grid,
session-range grid, inferred censoring, wrong calendar origin/unit, and
active-universe reduction mutants fail; literal views/exposure,
transformations, external interiors, all standing gates, documentation,
and implementation review pass.

### O02 — Multiple observation spells and gaps

**Status:** complete in Dynet 0.3.25. Canonical discontinuous support,
raw-preserving fragment provenance, union-risk denominators,
observed-time event gaps, component-qualified globally phased grids,
allowed vertex waiting with same-fragment interval traversal,
independent union/change-point and scoped `networkDynamic` validation,
standing gates, documentation, source/check/install validation, and
final definition/fixture review pass.

**Purpose:** represent discontinuous observation without pretending a
gap is risk time.

**Definition:** `observation_spells` is a nonempty data frame with
exactly the required `start` and `end` time columns. It is mutually
exclusive with O01’s scalar observation bounds. Values must be finite,
use one clock compatible with the network, and satisfy `end >= start`;
violations raise classed `dynet_bad_input`, and conflicting observation
interfaces additionally raise `dynet_conflicting_observation`.

Normalize observation input deterministically. Sort by start and end;
merge positive spells that overlap or are adjacent; remove duplicate
points and points covered by a positive spell’s closed support; retain
uncovered points as punctual components. A point never bridges a
positive gap. The positive exposure support is the union `Q` of
normalized half-open intervals and the punctual support `Q*`
additionally contains every component endpoint and retained isolated
point. Metadata stores the normalized table, its hull, and
`observation_duration = sum(end - start)`. The hull is descriptive only
and must never replace exposure time in a denominator.

Each raw positive edge spell is intersected independently with every
positive observation component, producing one row per positive fragment.
A raw point is retained unchanged exactly when it belongs to `Q*`;
positive spells never become points. Every fragment carries stable
`raw_spell`, `observation`, and within-spell `fragment` identifiers,
preserved `raw_start` and `raw_end`, and strict
`left_observation_censored` and `right_observation_censored` flags.
Those flags record administrative cuts only: equality alone does not set
one, they do not mutate O03’s future raw censor state, and fragment
boundaries do not fabricate formations or dissolutions. Raw spell,
weight, vertex, session, and aggregate access remain unchanged.

Formation and dissolution are genuine raw endpoints in `Q*`, counted
once per raw spell even if it yields several fragments. `new_pairs` is
the first observed evidence across all components and does not reset
after a gap; a tie active when observation begins suppresses later
novelty, while an entirely unobserved earlier tie does not. Burstiness
uses eligible raw onsets mapped to the cumulative observed-time clock,
so gaps contribute zero interevent risk time while O01 and session
pooling rules remain intact.

Duration summaries first combine fragments by raw spell. `events` counts
raw spells, `total` sums their observed durations, `mean` and `median`
operate on those per-raw-spell durations, and `first` and `last` are
observed support coordinates. Genuine observed points count as
zero-duration events; a positive spell with only an observed endpoint
does not enter duration output. Temporal density unions fragments per
pair and divides by possible pairs times `observation_duration`;
duration-normalized results are `NA` when that duration is zero.

Measurement grids are observation-component-qualified and include an
`observation` column. Default grids restart at each component and close
the final bin of each component. An explicit start retains global step
phase, but every emitted window is intersected with one component, no
window aggregates across a gap, and no gap-only bin is emitted. A query
may span components; a closed query that intersects none raises
`dynet_outside_observation`. `sessions = "separate"` produces the
session-by-observation cross product, including empty fixed-universe
blocks.

Observation gaps remove edge availability but are deliberately not path
walls: waiting at a persistent static vertex across a gap is allowed.
Every positive-duration interval traversal must nevertheless fit wholly
inside one retained fragment, and path coalescing must never reconnect
fragments across a gap. A punctual contact continues to trigger its P04
delayed arrival without requiring edge persistence during that delay.
Session walls remain independent and mandatory. Default path horizons
use the observation hull, latency remains calendar elapsed time, and
metadata records `observation_gap_waiting = "allowed"` and
`latency_clock = "calendar"`.

**Public surface:** add `observation_spells = NULL` to
[`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md);
`as.data.frame(dn, what = "observations")` returns canonical components
and `as.data.frame(dn, what = "observed_edges")` returns the measurement
fragments and their provenance.

**Fixtures:** exact normalization of unsorted, duplicate, overlapping,
adjacent, covered-point, and isolated-point input; two positive
intervals with a gap containing raw endpoints; spells clipped on either
side and spanning the gap; genuine contacts at both component endpoints
and in the gap; duration, density, event, new-pair, burstiness, grid,
and temporal-path literals; a positive traversal that would straddle a
gap; independent session walls; numeric, `Date`, and `POSIXct` clocks;
loops, weights, singleton and empty observed views; row-order and
affine-time transformations.

**Oracle and external comparison:** independently normalize and
intersect by direct change-point/union arithmetic, compare every public
fragment, event, duration, density, grid, burst-clock, and path literal,
and reject hull-risk, fragment-event, fragment-count, gap-bin,
cross-gap-coalescing, and path-wall mutants. Compare normalized
observation periods and matched interior activity with `networkDynamic`
where its public semantics overlap; record Dynet’s closed punctual
endpoints, component grids, and allowed vertex waiting as deliberate
scope decisions.

**Exit:** observed-time denominators use the union of observation
spells; events in unobserved gaps are excluded; literal and randomized
oracle cases, scoped external comparisons, all standing gates,
documentation, source/check/ clean-install validation, and independent
definition, fixture, and implementation review pass.

### O03 — Explicit censor indicators

**Status:** complete in Dynet 0.3.26. The focused contract passes 103
assertions; the independent oracle passes 121 literal, 6,139 randomized,
10 scoped external, and 577 production comparisons while rejecting eight
mutants. The 2,855-assertion full suite, standing comparisons,
documentation, source/check/clean-install validation, and independent
definition and fixture reviews pass.

**Purpose:** distinguish a boundary observed at the limit from an
unknown boundary clipped to it.

**Definition:** add explicit interval-format column selectors
`onset_censored = NULL` and `terminus_censored = NULL` to
[`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md). They
are never auto-detected. A selected column must be strictly logical and
complete; an omitted side is all false. Either selector is incompatible
with contact, threaded, or co-presence construction and raises
`dynet_incompatible_censor`; malformed values raise `dynet_bad_censor`,
both also inheriting `dynet_bad_input`. An interval encoded with an
explicit end or duration may be punctual only when both flags are false.

For raw positive spell `[s,e)`, `onset_censored = TRUE` means the actual
onset is unknown at or before `s` and no formation was witnessed at `s`;
`terminus_censored = TRUE` means the actual terminus is unknown at or
after `e` and no dissolution was witnessed at `e`. These source states
never alter numeric activity, weights, sessions, direction, loops,
adjacency, paths, density, aggregate edges, or known observed exposure.
They are not inferred from numeric equality, O01 bounds, or O02
fragmentation.

Store both flags on the raw canonical spell through sorting, loop
handling, undirected endpoint canonicalization, and session splitting.
The raw edge accessor exposes them whenever either selector was
explicitly supplied, including an all-false column. Every observed
fragment copies them unchanged alongside the orthogonal O02
`left_observation_censored` and `right_observation_censored`
administrative-cut flags; the two families are never ORed or
substituted.

A formation is a raw onset in observed punctual support whose
`onset_censored` flag is false. A dissolution analogously requires a
known raw terminus. There is no option to relabel an explicitly unknown
boundary as an event. `new_pairs` can occur only at an uncensored
observed onset with no earlier observed evidence; an observed
left-censored/prevalent spell vetoes a simultaneous or later novelty
claim, while a wholly unobserved censored row does not. Burstiness uses
only uncensored observed raw onsets. Right censoring does not affect an
onset sequence.

All censored spells retain their known observed follow-up in snapshots,
paths, density, and exposure. Add `censored = c("include", "exclude")`
to
[`durations()`](https://mohsaqr.github.io/Dynet/reference/durations.md),
defaulting to `"include"` for compatibility. Inclusion summarizes all
eligible raw spells; exclusion first removes any raw spell with either
explicit censor flag and then calculates the existing raw-spell
`events`, `total`, `mean`, `median`, `first`, and `last`. O02
administrative cuts never trigger this filter. Result metadata records
the policy. Future formation/dissolution rate numerators inherit the
known-endpoint rule while their risk denominators retain known observed
exposure; O03 adds no uncited rate estimator.

Metadata distinguishes `raw_censoring = "explicit"`, resolved source
columns, and onset/terminus/both counts from observation censoring,
which remains administrative and not inferred. Event and burst results
record their known- onset/terminus filters.

**Fixtures:** four numerically identical positive spells with
uncensored, left-, right-, and both-side raw states; the same states on
distinct and duplicate pairs; O01 both-side administrative cuts; O02
multi-fragment cross-products; left-censored simultaneous/later novelty
veto and wholly unobserved history; known point events and rejected
flagged points; duration include/exclude literals;
bounded/collapse/separate sessions; retained and dropped loops; weights;
one-sided flag columns; explicit all-false input; numeric, `Date`, and
`POSIXct` clocks; row/name permutation, translation, positive scaling,
and edge transpose invariance.

**Oracle and external comparison:** independently validate and carry raw
flags, intersect raw activity with observation support, derive
administrative cuts by strict inequalities, count only known raw
endpoint events once per raw spell, derive novelty from chronological
observed evidence, and recombine fragment duration by raw identity
before applying the include/exclude filter. Randomize valid flags,
clocks, support, pairs, and sessions while forcing punctual flags false.
`networkDynamic` automatically derives its similarly named flags from
observation truncation rather than accepting Dynet’s independent source
state; compare only uncensored activity/duration interiors and record
explicit raw state as deliberate non-equivalence.

**References:** Kaplan and Meier (1958),
<doi:10.1080/01621459.1958.10501452>; Andersen and Gill (1982),
<doi:10.1214/aos/1176345976>; and `networkDynamic` 0.11.5,
<doi:10.32614/CRAN.package.networkDynamic>.

**Exit:** inference-from-bound, raw/admin OR, censor-erases-activity,
censored-endpoint-event, fragment-event, fragment-count,
censored-novelty, unobserved-history, ignored/inverted duration filter,
flagged-point coercion, onset/terminus swap, session leakage, and
raw/aggregate mutation mutants fail; literal and randomized oracle
cases, scoped external interiors, all standing gates, documentation,
source/check/clean-install validation, and independent definition,
fixture, and implementation review pass.

## Vertex-activity features

### V01 — Vertex-activity representation and accessor

**Status:** complete in Dynet 0.3.27. The 89-assertion focused contract
and 2,944-assertion full suite pass. The independent normalizer passes
81 literal, 9,743 randomized, 36 scoped external, and 15,039 production
comparisons while rejecting 11 mutants with maximum numerical error
zero. Standing comparisons, documentation, source/check/clean-install
validation, and independent definition, fixture, and implementation
reviews pass.

**Purpose:** store a changing eligible vertex population without
introducing a general mutable attribute framework or changing
measurements before their own V02–V04 contracts.

**Public surface:** append `vertex_spells = NULL` to
[`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md) so
existing positional calls are unchanged. A non-`NULL` table has the
exact required columns `node`, `start`, and `end`, and may additionally
have the exact columns `session`, `onset_censored`, and
`terminus_censored`; other columns are rejected. Names are not
auto-detected. The table may have zero rows. Node and session values
become nonempty, complete character identifiers. Times are finite values
on the already resolved edge clock, never a second origin, and must
satisfy `end >= start`. Censor columns are strict complete logicals,
default false when omitted, and a point cannot be censored. Validation
uses classed `dynet_bad_vertex_spells`, `dynet_bad_vertex_censor`,
`dynet_unknown_session`, or `dynet_incompatible_vertex_spells`
conditions, each inheriting from `dynet_bad_input` where applicable.

**Unit and boundary definition:** one canonical row is one maximal
declared vertex-activity component. A positive input spell is eligible
on `[start,end)`; a zero-duration spell is eligible exactly at its time.
Normalize independently by node and, when supplied, session: union
overlapping or adjacent positive spells, deduplicate points, discard a
point only when it lies inside a positive component under
`start <= point < end`, and retain a point at that component’s excluded
terminus. Components never merge across nodes or sessions. Canonical
rows are sorted by session, node, start, end and receive stable integer
`vertex_spell` identifiers.

For a merged positive component, `onset_censored` is the OR of onset
flags on source rows attaining its minimum start and `terminus_censored`
is the OR of terminus flags on source rows attaining its maximum end.
Any contributing spell known to extend beyond an outer boundary
therefore censors the union boundary; flags on boundaries strictly
inside the component disappear. Raw censor state never changes activity
and is never ORed with O01/O02 administrative cuts.

**Vertex universe and default:** names present only in `vertex_spells`
join the fixed vertex universe and receive `NA` for absent supplied
attributes. A vertex with any declared row is dynamic and is eligible
only on its declared union. A fixed-universe vertex with no declared row
anywhere is implicit static and eligible at all times. When `session` is
supplied, labels must be complete and belong to the existing
edge-session universe; a declared vertex is inactive in unlisted
sessions, while a wholly undeclared vertex remains static in every
session. A table without `session` is global and applies to every edge
session. Vertex-only session labels do not expand current
`meta$sessions` in V01.

**Accessor:** `as.data.frame(dn, what = "vertex_spells")` returns
canonical declared rows only, never synthetic infinite rows or
observation-clipped fragments. Its fixed tidy columns are
`vertex_spell`, `node`, `start`, `end`, `duration`, `instant`,
`session`, `onset_censored`, and `terminus_censored`; omitted optional
inputs yield typed `NA` sessions and false flags. `NULL` or a typed
zero-row table therefore returns a typed zero-row accessor and means
every fixed vertex is implicit static. Metadata records
`vertex_activity = "static"|"explicit"`,
`vertex_activity_default = "always_for_unlisted_nodes"`,
`vertex_activity_interval = "positive_half_open_instant_closed"`, the
global or session scope, raw and canonical row counts, dynamic/static
vertex counts, raw censor counts, and
`edge_vertex_activity_policy = "stored_unchecked_v01"`.

**Deliberate V01 non-effects:** for an unchanged fixed vertex universe,
vertex declarations do not change the edge-derived `time_range`,
observation support, grids, session universe, aggregate edge table,
snapshots, paths, density, events, durations, plots, or any other
existing result. A name introduced only by `vertex_spells` deliberately
expands the fixed universe immediately and is therefore an isolate in
legacy measurements until V02 applies eligibility. An edge whose
endpoint is inactive is preserved without clipping, extension,
rejection, or warning; V02 and V03 define its snapshot and traversal
consequences. Observation bounds and gaps likewise do not rewrite the
raw canonical accessor. The derived V02 view will intersect positive
activity with positive observed support, retain genuine points in closed
punctual support, copy raw flags, and carry separate strict
administrative-cut provenance, but V01 exposes no second accessor.

**Fixtures:** overlapping, nested, duplicate, adjacent, and disjoint
positive spells; covered, duplicate, and excluded-terminus points;
duplicate outer boundaries with one censored contributor; distinct
vertices and sessions; implicit static and activity-only isolates;
inconsistent edges and loops; zero-row/all-static compatibility;
numeric, `Date`, and `POSIXct` clocks; O01 bounds and O02 gaps as
noninterference cases; row, name, session, translation, and
positive-scale transformations. Time reversal is tested only as
endpoint- table normalization equivariance with swapped raw censor
sides: reflection of half-open activity changes endpoint closure, so V01
claims no reflected boundary-eligibility invariance.

**Oracle and external comparison:** an independent sort-sweep normalizer
works from the written half-open/point rules and never calls Dynet
construction, union, observation, encoding, grid, or activity helpers.
Randomize valid clocks, flags, points, overlaps, nodes, and sessions and
reject no-union, adjacency-gap, terminus-point absorption, covered-point
retention, censor-AND, internal-censor, session-merge, clock-reset,
implicit-inactive, destructive-clipping, and metric-leakage mutants.
Compare unsessioned canonical positive interiors, points, and
`is.active()` boundary values with `networkDynamic` 0.11.5 only where
definitions agree; its integer vertex IDs, observation-derived censor
state, and activity-reconciliation behavior are deliberate
non-equivalences.

**References:** Holme and Saramaki (2012),
<doi:10.1016/j.physrep.2012.03.001>; `networkDynamic` 0.11.5,
<doi:10.32614/CRAN.package.networkDynamic>.

**Exit:** all literal and randomized canonical rows, scoped external
values, mutants, invariants, classed validation, unchanged legacy
outputs, standing gates, documentation, source/check/clean-install
validation, and independent definition, fixture, and implementation
reviews pass before V02 begins.

### V02 — Vertex activity in snapshots

**Status:** complete in Dynet 0.3.28. The 93-assertion focused contract
and 3,040-assertion full suite pass. The independent oracle passes 38
literal, 300 randomized, 15 scoped external, and 1,450 production
comparisons while rejecting five mutants with maximum numerical error
zero. Standing comparisons, documentation, source/check/clean-install
validation, and independent definition, fixture, and implementation
reviews pass.

**Purpose and unit:** apply V01’s declared vertex eligibility to every
snapshot consumer through one induced-snapshot state. For reporting
window `W` and effective session `q`, let `V_q(W)` contain each declared
vertex whose activity is present at any time in `W`, plus every wholly
undeclared vertex. Let `E_q(W)` be the raw edge rows active at any time
in `W` under O01/O02 and the established edge rule. The snapshot is

\[ G_q(W)=(V_q(W),E_q(W)\[V_q(W)\]). \]

Positive windows independently take the any-time union of vertex
activity and edge activity and then induce: a common instant shared by
an edge and both endpoints is not required. At `window = 0`, all
predicates are evaluated at the exact reporting time and are therefore
simultaneous. This is the matched
`networkDynamic::network.extract(rule = "any")` convention, not an
all-window or coactivity-duration rule.

**Boundaries and observation:** a positive vertex spell `[s,e)`
intersects a positive window iff `s < hi && e > lo`. A genuine point `p`
belongs iff `lo <= p < hi`, plus `p == hi` for a right-closed final
window. At exact `t`, a positive spell belongs iff `s <= t < e` and a
point iff `p == t`. Positive spells never acquire punctual activity at
their terminus; censor flags never alter eligibility. Eligibility is
derived non-destructively on O01/O02 observed support. Positive activity
is intersected with positive observation components, genuine points
survive at closed observation endpoints, and no component-qualified bin
bridges a gap.

**Sessions:** `collapse` erases vertex and edge session labels, takes
their independent calendar unions, and then induces; cross-session
endpoint authorization is deliberate. `bounded` builds each
session-local induced graph and unions its surviving dyads into one
block. `separate` reports those same local induced graphs separately.
Global vertex schedules apply in every session, a session-scoped
declared vertex is inactive in unlisted sessions, and a wholly
undeclared vertex is static in every session. Duplicate surviving dyads
are binary-presence one; snapshot `weight` and `n_spells` aggregate only
the raw active rows surviving endpoint filtering.

**Node and graph output:** snapshot
[`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md)
retains one row per fixed vertex/time/measure. Each kernel is computed
on the eligible principal submatrix and expanded to fixed vertex order;
every inactive value is typed `NA_real_`, never zero or a dropped row.
Eligible isolates retain the already frozen static-kernel result. No new
result column is added, because `NA` and the result metadata communicate
inactivity without changing the tidy schema.

Every graph kernel receives the eligible principal submatrix. Density,
dyad/triad census opportunities, component membership, largest-component
share, and Freeman centralization denominators therefore use eligible
order `n_e`, not the fixed universe. `active_nodes` remains eligible
vertices incident to a nonloop dyad and `isolates = n_e - active_nodes`;
a loop-only eligible vertex is an isolate for these graph measures.
Binary eligibility is independent of weights, signs, duplicates, and
multiplicity. Retained loops remain available to downstream kernels
under their already frozen loop rules.

For `n_e = 0`, density, edges, active nodes, isolates, weak/strong
components, largest share, all censuses, and efficiency are zero;
transitivity and connectedness are one; mean distance, diameter,
assortativity, and all three centralizations are `NA`; hierarchy and
LUBness are `NaN`. For `n_e = 1`, density, edges, active nodes,
reciprocity, and censuses are zero; isolates, weak/strong components,
largest share, transitivity, and connectedness are one; mean distance,
diameter, assortativity, and centralizations are `NA`; efficiency,
hierarchy, and LUBness are `NaN`. Centralization is always `NA` below
three eligible vertices.

**Other affected verbs:**
[`mixing()`](https://mohsaqr.github.io/Dynet/reference/mixing.md)
retains A02’s fixed complete group cell support but counts only
endpoint-valid dyads.
[`snapshots()`](https://mohsaqr.github.io/Dynet/reference/snapshots.md)
emits only endpoint-valid edge rows and preserves weights and spell
counts from surviving raw rows; it remains edge-only and does not
fabricate rows for eligible isolates. Snapshot plotting and proximity
views use the same state. Affected result metadata records the eligible
population, any/exact window rule, induction rule, observation rule,
session aggregation, and opportunity domain where applicable.

**Deliberate non-effects:** raw edge and vertex accessors, aggregate
network, time range, grid, session universe, temporal paths and
centrality (V03), edge formation/dissolution/new-pair/active-spell
events, durations, burstiness, and whole-window temporal density/risk
sets (V04) remain unchanged.

**Fixtures and oracle:** literal cases cover the six-state
changing-population core, a positive-window no-common-instant
discriminator, exact onset/terminus and point boundaries, empty and
singleton populations, bounded/collapse/ separate session leakage,
observation gaps, loops, duplicates, weights, vertex-only isolates, and
fixed mixing support. A slow oracle directly tests interval/point
membership, filters endpoint-valid raw IDs, constructs induced binary
and valued matrices, enumerates dyads and triads, and derives paths and
Freeman numerators without using production encoding, activity, grid,
adjacency, snapshot-state, or graph helpers. It tests
row/name/time/session transformations, combinatorial margins, and
mutants for ignored activity, edge-incidence eligibility, inactive
zero/drop, full-universe denominators, all/common-instant window rules,
terminus absorption, point loss, missing endpoint filtering,
compute-then-mask, gap bridging, session leakage, group support
shrinkage, loop misuse, and weight-dependent eligibility.

**References:** Holme and Saramaki (2012),
<doi:10.1016/j.physrep.2012.03.001>; `networkDynamic` 0.11.5,
<doi:10.32614/CRAN.package.networkDynamic>; Freeman (1979),
<doi:10.1016/0378-8733(78)90021-7>; and Butts (2008),
<doi:10.18637/jss.v024.i06>.

**Exit:** literal and randomized induced states, external matched
interiors, all mutants and invariants, unchanged legacy/no-activity
output, tidy public shape, standing gates, documentation,
source/check/clean-install validation, and independent definition,
fixture, and implementation reviews pass before V03 begins.

### V03 — Vertex activity in temporal paths

**Frozen definition (0.3.29):** vertex activity gates traversal
appearances, not storage while waiting. A forward source must be
eligible exactly at the resolved `start`, and a backward target exactly
at the resolved `end`; an ineligible anchor returns the complete
fixed-universe unreachable block, including its self row. After a valid
anchor, waiting through inactive periods is allowed. This preserves the
P07/P08 vertex-simple and canonical-atom path definitions: an earlier
arrival continues to dominate every later arrival at the same vertex.

At zero traversal duration, both endpoints must be eligible at the hop
time. For a positive-duration interval hop entered at `x` and completed
at `y = x + traversal_time`, both endpoints must be continuously
eligible on the closed traversal `[x, y]`, in addition to P05’s
edge-occupancy rule. A genuine vertex point can therefore close a
half-open vertex spell at `y`. A point edge still triggers
instantaneously: both endpoints must be eligible at its trigger, and the
receiver must also be eligible at delayed completion; it creates no
continuous edge or tail occupancy. Time outside explicit observation
support is unconstrained rather than declared inactive, while observed
vertex spells retain V01 half-open/point semantics.

Intersecting one canonical edge atom with vertex schedules may create
several feasible entry domains. Those domains retain one parent
`atom_id`: timing choice, waiting schedule, activity segmentation,
duplicates, weights, and erased session labels do not multiply paths.
Backward searches retain exact open-boundary supremum attainment.
Collapse erases edge and vertex session labels before feasibility;
bounded and separate searches use global plus matching session activity
and never cross a session wall.

Apply this definition without a new public argument to
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md), both
directions of
[`dyn_reachability()`](https://mohsaqr.github.io/Dynet/reference/dyn_reachability.md),
and temporal reach, closeness, and betweenness. Output stays
fixed-universe. V03 changes feasible journey families only: V04 owns
risk-set denominators, and event/duration measures stay unchanged.
Calibrate exact one-hop activity predicates with `networkDynamic`;
[`tsna::tPath()`](https://rdrr.io/pkg/tsna/man/paths.html) ignores
vertex activity and is retained only as an all-static compatibility
check. The deliberate alternative is the continuous-wait node-presence
rule in Latapy, Viard and Magnien (2018), which Dynet does not adopt.

**Required gates:** literal anchor, waiting-gap, zero-duration boundary,
positive interval, delayed point, domain-identity, backward-attainment,
observation, session, tied-family, and invariant fixtures; an
independent vertex-simple parent-atom oracle; endpoint, waiting-wall,
boundary, point, identity, observation, and session mutants; external
matched predicates; all standing gates, docs, source/check/clean-install
validation, and independent definition, fixture, implementation, and
final review.

**Exit complete (0.3.29, 2026-08-25):** the focused contract passes 47
assertions and the full package suite passes 3,089. The independent
oracle passes 300 forward and 150 backward randomized point systems,
positive-duration boundary literals, 21 scoped `networkDynamic`
predicates, and seven mutant discriminators. All standing exhaustive
traversal, backward, bounds, traversal-time, optimal-family, session,
reach, closeness, and betweenness oracles pass. Grid remains
4,974/4,974; the accepted kernel 75/78 directed- closeness and measure
2,060/2,070 undirected-eigenvector definition baselines are unchanged.
Independent definition, fixture, implementation, and final reviews are
clear. Source build, `R CMD check` (status OK), and clean installed
smoke validation pass before V04 begins.

### V04 — Vertex activity in risk sets

**Frozen candidate for definition review (0.3.30):** whole-window
temporal density is the ratio of two calendar integrals over positive
observed support. At time `t`, let `V(t)` be the exact V01 eligible
vertex set after collapse has erased session labels. The opportunity
count is `|V(t)|(|V(t)|-1)` for a directed network and
`choose(|V(t)|, 2)` for an undirected network. The occupied count is the
number of unique non-loop ordered pairs or dyads whose union edge state
is active at `t` and whose endpoints both belong to `V(t)`. Integrate
both counts independently over every interval induced by observation,
edge, and vertex change points, then divide occupied pair-time by
eligible opportunity-time. Do not average instantaneous density ratios.

Positive vertex and edge spells are half-open; exact points contribute
no duration to either integral. Observation gaps contribute neither
numerator nor denominator. Undeclared vertices remain statically
eligible. Duplicate, overlapping, touching, weighted, and
session-labelled representations cannot multiply pair-time; collapse
unions all labels before state evaluation. Loops never enter numerator
or denominator. A zero eligible opportunity integral is undefined
(`NA`), including empty/singleton-only and point-only risk sets; a
positive opportunity integral with no eligible edge occupancy is zero.

V04 changes current
[`summary.dynet()`](https://mohsaqr.github.io/Dynet/reference/summary.dynet.md)
temporal density and its internal `.temporal_density()` only. Snapshot
density already follows V02. Raw event counts and durations remain
unchanged; D04 will expose additional occupancy and onset-intensity
variants, while T01–T04 will consume the same two-sided risk state for
transition fractions/rates. Preserve all-static C01 output exactly and
record the integrated eligible-opportunity definition in metadata/docs.

**Required gates:** directed/undirected changing-population literals,
endpoint induction, empty/singleton/point-only risks, observation gaps,
collapse session union, duplicate/weight/loop invariants,
translation/scaling, an independent change-point oracle, fixed-universe
and average-of-ratios mutants, external matched state checks, standing
gates, documentation, package/check/install, and independent reviews.

**Exit complete (0.3.30, 2026-08-25):** 16 focused assertions and all
3,105 package assertions pass. The independent exact change-point oracle
matches 300 random changing-population systems, 16 scoped external
midpoint states, and seven denominator/numerator mutants. The standing
all-static temporal-density, V02, and V03 oracles pass. Independent
definition, fixture, implementation, and final reviews are clear. Source
build, `R CMD check` (status OK), and clean installed smoke validation
pass before D01 begins.

Each V feature has its own constructor/accessor or measurement
regression and exit gate. Do not treat V01–V04 as one migration.

## Duration and exposure features

### D01 — Edge-spell and pair-duration units

**Purpose:** distinguish spell and relational-pair quantities after
O01–O03 and V01–V04 are settled.

**Status:** complete in Dynet 0.3.31. Endpoint-valid raw identities,
point contacts, pair summed and binary-union duration, censoring,
session policies, direction/loops, empty schemas, compatibility,
coordinate transformations, direct helper coverage, independent
change-cell enumeration, scoped `tsna` comparison, documentation,
source/check/install validation, and independent implementation review
pass. The oracle completed 427 checks over 5,476 values with maximum
error zero and rejected seven deliberate mutants.

**Frozen definition (0.3.31):** append `unit = c("pair", "spell")` after
the existing arguments. The default `unit = "pair"`, existing positional
calls, default measures, and pair schema remain backward-compatible.
Pair measures retain `events`, `total`, `mean`, `median`, `first`, and
`last`, and add `union`. Here `events` is retained raw-spell count,
`total` is summed retained spell duration, and `union` is binary
pair-union duration. With `unit = "spell"`, allowed measures are
`duration`, `first`, and `last` (default `duration`) and the tidy result
adds stable query-local `raw_spell`, one row per retained raw identity
and measure. Unit plus measure unambiguously names the quantity; Dynet
does not claim a persistent multiplex edge ID.

For raw spell `i`, intersect its positive edge activity with positive
observed support and exact simultaneous eligibility of both endpoints,
then recombine all O02/activity fragments under its raw identity. Its
duration is the sum of fragment widths, first is the first retained
time, and last the final retained time. An observed genuine point with
eligible endpoints is one zero-duration spell; administrative boundary
contact is not fabricated. Pair `total`, mean, and median operate on
these spell durations, including retained points; pair `union`
calendar-unions all retained positive fragments. Thus
`0 <= union <= total`, and union cannot exceed V04 eligible opportunity
time.

`censored = "exclude"` removes a whole raw identity before reduction if
either explicit raw edge censor flag is set; administrative observation
flags never exclude it. Vertex censor flags never change eligibility.
Directed reverse pairs remain distinct; undirected endpoints are
canonical. Retained loops are valid duration subjects. Weights never
matter.

Collapse erases edge and vertex labels before endpoint gating. Bounded
derives each session-local retained state, then pools spell identities
and Boolean- unions pair occupancy on the shared calendar without
cross-session authorization or double exposure. Separate returns those
local sparse blocks. Global schedules apply to every session and
undeclared vertices stay static. No retained spell means no row.

**Fixtures:** disjoint, overlapping, nested, recurrent, instantaneous,
opposite directed pairs, censored spells, observation gap, and inactive
endpoint.

**Oracle:** change-point integration and
[`tsna::edgeDuration()`](https://rdrr.io/pkg/tsna/man/durations.html)
only for matching spell/dyad subjects.

**Exit:** every row’s unit/measure names its quantity; union duration is
bounded by observed eligible time while summed duration may exceed it
when multiplicity is intentional. Literal spell/pair tables, independent
oracle, scoped external checks, mutants/invariants, unchanged default
behavior without activity, standing gates, docs, package/check/install,
and independent reviews pass.

**Exit complete (0.3.31):** focused tests pass 49 assertions and the
complete suite passes 3,155. O01–O03 and V01 standing oracles remain
green. Source `/private/tmp/Dynet_0.3.31.tar.gz`, CRAN-style check
`/private/tmp/Dynet-0.3.31-final-check/Dynet.Rcheck` (no errors or
warnings; the known private-URL and slow-example notes only), and clean
installed library `/private/tmp/dynet-d01-library` pass. Final review is
clear.

### D02 — Vertex activity duration

**Status:** complete in Dynet 0.3.32. Fixed-universe vertex aggregates
and canonical/implicit activity-spell rows, observation gaps and points,
canonical censor exclusion, bounded/collapsed/separate sessions, fixed
zero and sparse empty schemas, edge irrelevance, transformations,
metadata, independent normalization/change-cell enumeration, scoped
`tsna`, documentation, source/check/install validation, and independent
implementation review pass.

**Frozen definition (0.3.32):** extend the existing selector with two
distinct units and no new argument. `unit = "vertex_activity"` returns
fixed-universe vertex aggregates with columns `node`, `measure`, and
`value` (plus `session` for separate mode); `unit = "vertex_spell"`
returns sparse canonical V01 component rows and adds `vertex_spell` plus
`implicit`. Existing `unit = "spell"` remains an edge raw spell. Vertex
aggregate measures are `events`, `total`, `union`, `mean`, `median`,
`first`, and `last`, defaulting to `events`, `total`, and `union`;
vertex-spell measures are `duration`, `first`, and `last`, defaulting to
`duration`.

For canonical declared component `k` of vertex `v`, let `S[v,k]` be its
positive half-open activity intersected with positive observation
support, with O02 fragments recombined under the unchanged V01
`vertex_spell`. Genuine declared points survive on closed punctual
support; a positive component merely touching an observation endpoint
does not become a point. Write `d[v,k] = mu(S[v,k])`,
`f[v,k] = inf(S[v,k])`, and `l[v,k] = sup(S[v,k])`; a retained point has
zero duration and equal first and last. For retained identities `K[v]`,

\[ events_v=\|K\[v\]\|,total_v=*{kK\[v\]}d\[v,k\],
union_v=!(*{kK\[v\]}S\[v,k\]). \]

Mean and median reduce the identity durations including points; first
and last are the extrema across retained identities. Thus
`0 <= union <= total`. A declared vertex with no retained identity
receives fixed aggregate rows: events/total/union zero and
mean/median/first/last `NA_real_`, never `NaN` or infinity. Spell output
is sparse. A wholly undeclared fixed-universe vertex is represented for
measurement only by one `implicit = TRUE`, `vertex_spell = NA_integer_`
always-active identity over all observed support; it is never added to
the V01 accessor. A vertex declared anywhere never falls back to this
default, including an unlisted separate session. Point-only observed
support retains the implicit identity with duration zero.

For vertex units, `censored = "exclude"` removes an entire canonical V01
component when either canonical outer censor flag is true;
administrative observation cuts do not exclude it and implicit
identities are uncensored. Collapse preserves identities but erases
labels for union. Bounded evaluates global-plus-matching schedules
locally, pools each identity once, and Boolean- unions the shared
calendar. Separate emits fixed-universe local blocks; global components
and implicit statics appear in every block, while a vertex declared only
in another session is locally inactive. Bounded and collapse aggregate
values therefore agree for vertex activity, while separate can differ.

Direction, loops, weights, edge multiplicity/activity, and edge censor
flags are irrelevant except for construction of the fixed node/session
universe and legacy observation horizon. Translation preserves
counts/durations and shifts first/last; positive scaling multiplies
duration and endpoint values. Metadata records the unit, quantity,
canonical-plus-implicit identity, sum/union rule, observation and censor
rules, irrelevant directedness, and session aggregation.

The union is the stream-graph node-presence duration of Latapy, Viard,
and Magnien (2018), <doi:10.1007/s13278-018-0537-7>. Scoped comparisons
use
[`tsna::vertexDuration()`](https://rdrr.io/pkg/tsna/man/durations.html)
(Butts, 2024, <doi:10.32614/CRAN.package.tsna>) only for one continuous
observation, matched nonoverlapping canonical schedules, no
sessions/censor filtering, and `active.default = TRUE`. O02 gaps/points,
explicit censoring, session semantics, and tidy fixed-universe output
are deliberate external exclusions.

**Fixtures:** implicit always-active, intermittent,
overlapping/adjacent, recurrent, censored, never-active, gap-split
parent, genuine point, point-only observation, singleton, global/session
schedules, row/name/time transforms, typed empty spell output, and fixed
zero aggregate rows.

**Oracle:** independently normalize raw vertex rows and observation
support, intersect change cells, recombine canonical parents, synthesize
implicit statics, and reduce spell/vertex quantities without production
V01/O02/duration helpers; compare
[`tsna::vertexDuration()`](https://rdrr.io/pkg/tsna/man/durations.html)
only in the scoped domain above.

**Exit:** literal component and fixed-universe tables, independent
randomized oracle, scoped external checks, coordinate/session/censor
invariants, mutants, D01/V01–V04 standing gates,
helper/docs/package/check/install, and independent reviews pass.

**Exit complete (0.3.32):** focused D02 tests pass 89 assertions and the
full suite passes 3,244. The independent oracle passes 1,003 checks over
18,766 values with maximum error zero, three scoped `tsna` comparisons,
and eight mutant kills. D01 and V01–V04 standing oracles remain green.
Source `/private/tmp/Dynet_0.3.32.tar.gz`, CRAN-style check
`/private/tmp/Dynet-0.3.32-check/Dynet.Rcheck` (no errors or warnings;
the known private-URL and slow-example notes only), and clean installed
library `/private/tmp/dynet-d02-library` pass. Final review is clear.

### D03 — Tied duration

**Status:** complete in Dynet 0.3.33. Endpoint-stub events and summed
duration, binary incident exposure, in/out/all and undirected modes,
two-stub loops, points/gaps/activity/censoring/sessions, fixed zeros,
collision-safe names, transformations and bounds, independent
raw/change-cell enumeration, scoped `tsna`, documentation,
source/check/install validation, and independent implementation review
pass.

**Frozen definition (0.3.33):** extend `unit` with `"node_ties"` and
append `mode = c("out", "in", "all")` after it, retaining the roadmap’s
outgoing default and every prior positional call. An explicitly supplied
`mode` with any other unit is a classed
`dynet_incompatible_duration_mode` error. Undirected calls accept every
value but normalize effective mode to `"all"` while recording requested
and effective mode. Node ties allow exactly `events`, `total`, and
`union`, defaulting to events and total, and return fixed-universe node
rows (plus session only in separate mode). All zeros are defined; no
`NA`, `NaN`, or infinity occurs.

Reuse D01’s endpoint-valid retained raw-spell fragments. If raw identity
`i` has recombined positive support `F[i]` and duration `d[i]`, define
incidence multiplicity `c[v,i,m]` as one for a directed tail in out
mode, one for a head in in mode, their sum in all mode, and
endpoint-stub count in undirected effective-all mode. Hence a retained
loop counts once in out, once in in, and twice in directed-all or
undirected results. This preserves exact `all = out + in` for additive
quantities and matches `tsna` combined incidence.

\[ events_v^m=\_i c\[v,i,m\]1{i retained}, total_v^m=\_i
c\[v,i,m\]d\[i\], \]

\[ union_v^m=!(\_{i:c\[v,i,m\]\>0}F\[i\]). \]

Union is Boolean incident calendar exposure: loop multiplicity,
reciprocal overlap, duplicates, repeated pairs, and simultaneous
neighbors count time once. Thus `0 <= union <= total`, and union cannot
exceed the D02 eligible vertex-activity union for that node. Points
affect events only. Weights never matter. Directed transpose swaps
out/in and preserves all; undirected modes are identical.

Observation gaps, point rules, exact endpoint activity, raw edge censor
include/exclude, and fragment recombination are exactly D01. Vertex
censor flags never filter. Collapse erases labels before gating; bounded
gates locally then pools raw identities and Boolean-unions
shared-calendar exposure; separate returns fixed-node local blocks.
Global schedules apply in every session and undeclared vertices are
static.

[`tsna::tiedDuration()`](https://rdrr.io/pkg/tsna/man/tiedDuration.html)
(Bender-deMoll and Morris, 2025, <doi:10.32614/CRAN.package.tsna>) is an
external oracle for events/counts and total/duration only under
continuous unsessioned static-endpoint, uncensored, matched-spell
conventions, mapping all to combined. It deliberately is not an oracle
for union, O02 gaps/points, endpoint eligibility, source censoring, or
sessions. Incident-union exposure follows the stream presence framework
of Latapy, Viard, and Magnien (2018), <doi:10.1007/s13278-018-0537-7>.

**Fixtures:** pure sender/receiver, reciprocal pair, directed
simultaneous and repeated star, retained loop, undirected loop/dyad,
isolate/singleton, point, gap-split identity, endpoint inactivity,
censoring, session pooling and cross-authorization, transformations,
typed fixed-zero output, and metadata.

**Oracle:** independently intersect raw spells with observation and
endpoint activity, recombine raw identity, enumerate endpoint stubs, and
integrate incident union by change-cell midpoints without
D01/D03/path/union helpers; compare scoped `tsna` counts/durations and
reject incidence, fragment, hull, censor, point, session, weight, and
sparse-output mutants.

**Exit:** literal in/out/all/undirected tables, all=out+in and union
bounds, independent randomized oracle, scoped external checks,
transformations, D01/D02/V01–V04 standing gates,
helpers/docs/package/check/install, and independent reviews pass.

**Exit complete (0.3.33):** focused D03 tests pass 82 assertions and the
full suite passes 3,327. The independent oracle passes 1,506 checks over
17,802 values with maximum error zero, six scoped `tsna` comparisons,
and thirteen mutant kills. D01/D02 and V01–V04 standing oracles remain
green; the D03 name invariant also repaired and regression-pinned D02
implicit activity for an empty-string vertex label. Source
`/private/tmp/Dynet_0.3.33.tar.gz`, check
`/private/tmp/Dynet-0.3.33-check/Dynet.Rcheck` (no errors/warnings; the
known private-URL and slow-example notes only), and clean installed
library `/private/tmp/dynet-d03-library` pass. Final review is clear.

### D04 — Temporal edge-density variants

**Purpose:** generalize C01 through
[`metrics()`](https://mohsaqr.github.io/Dynet/reference/metrics.md)
using O and V semantics.

**Status:** complete in Dynet 0.3.34. Four exact window-integrated
selectors, global endpoint-valid pair cohorts, raw-onset exposure,
points/censoring/gaps, changing opportunity, session policies,
transformations, mixed-result metadata, independent enumeration, scoped
`tsna`, documentation, source/check/install validation, and independent
review pass.

Expose separately named quantities:

- Pair-time occupancy over all eligible opportunities.
- Pair-time occupancy over pairs ever observed.
- Raw spell-onset intensity over all eligible opportunity time.
- Raw spell-onset intensity over observed-pair opportunity time.

Only occupancies are probabilities bounded by one. Define zero
denominators and instantaneous-only networks explicitly. A contact row
is one raw onset event; spell termini are not a second event.
Relational-state transition intensities belong to T03 and T04 after the
transition kernel exists.

**Oracle:** change-point integration and
[`tsna::tEdgeDensity()`](https://rdrr.io/pkg/tsna/man/density.html) only
where its experimental denominator matches.

**Frozen definition (0.3.34):** retain
`metrics(..., measure = "density")` as the V02 any-time snapshot
statistic and retain it as the default. Add exactly four selectors
without a new argument or output column:

- `"temporal_density"`: binary occupied pair-time over every eligible
  nonloop opportunity;
- `"observed_pair_density"`: the same occupied numerator over eligible
  time for pairs ever observed;
- `"onset_intensity"`: known raw spell onsets over every eligible
  nonloop opportunity-time; and
- `"observed_pair_onset_intensity"`: the same onset numerator over
  eligible time for pairs ever observed.

Their labels are respectively “Temporal density”, “Observed-pair
temporal density”, “Edge-onset intensity”, and “Observed-pair edge-onset
intensity”. The existing graph-level tidy schema remains `session`,
`time`, `measure`, and `value`, with `session` removed outside separate
mode. A positive reporting window computes each quantity over that exact
window, clipped to its O02 observation component; rolling windows
deliberately overlap. `window = 0` has zero opportunity-time, so all
four new quantities are `NA`, while existing snapshot measures retain
their point-state definitions. `summary(dn)` remains the pooled
full-history collapse value of `temporal_density`; across observation
gaps it divides pooled numerators and denominators rather than averaging
ratios.

For effective session policy `s`, reporting window `W`, and ordered pair
(directed) or canonical unordered dyad (undirected) `r`, let `Y[r,s](t)`
be the indicator of positive observed time and exact simultaneous V01
eligibility of both distinct endpoints. Let `E[r,s](t)` be binary union
edge presence after endpoint induction. Define

\[ R_s(W)=\_r*WY*{r,s}(t),dt, O_s(W)=*r*WY*{r,s}(t)E*{r,s}(t),dt. \]

Loops never enter either ledger. Duplicate, overlapping, adjacent,
weighted, censored, and multiplex representations cannot multiply `O`;
edge and vertex intervals remain half-open, and gaps and points add no
exposure.

Freeze the ever-observed set `H_s` once from the complete stored
observed history under the requested effective session policy. Query
`start`, `end`, `step`, and `window` do not redefine it, and observation
gaps do not reset it. A nonloop pair enters `H_s` when it has
endpoint-valid observed evidence: positive edge support, an eligible
genuine edge point, or a raw onset or terminus in closed observed
punctual support with both endpoints exactly eligible. Raw and
administrative censor flags do not erase existence, while a wholly
unobserved row or evidence occurring only with an ineligible endpoint
does not establish membership. Thus a prevalent left-censored tie with
observed follow-up is included. `H_s` conditions the pair domain rather
than starting a clock: its opportunity counts before and after the first
evidence. Set

\[ R\_{H,s}(W)=\_{rH_s}*WY*{r,s}(t),dt. \]

Because every occupied interval belongs to `H_s`, both occupancies share
`O`: `temporal_density = O/R` and `observed_pair_density = O/R_H`. Both
lie in `[0,1]`, with `O <= R_H <= R`.

Let `N_s(W)` count a raw nonloop edge identity once when its raw start
is in the reporting bin under the established half-open/final-closed
event rule, is in closed observed support, is not explicitly
onset-censored, and has both endpoints exactly eligible at that instant
under the effective session policy. Intervals and genuine contacts each
contribute one onset; recurrent, duplicate, overlapping, and
simultaneous raw rows remain distinct events. Termini never contribute,
terminus censoring is irrelevant, weights do not multiply counts, and
observation or activity clipping never fabricates an onset. Exact
instantaneous eligibility is intentional: the two-sided risk rule
belongs to T01–T04 confirmed relational-state transitions. Define
`onset_intensity = N/R` and `observed_pair_onset_intensity = N/R_H`.
Their unit is inverse network time; they are finite nonnegative
intensities with no upper bound.

Every zero denominator returns literal `NA_real_`, never zero, `NaN`, or
infinity, even when a point onset exists. A positive denominator with
zero numerator returns exact zero. Hence a positive-risk network with no
ever-observed pair has zero all-pair occupancy and intensity but
undefined observed-pair quantities. A point edge inside positive
opportunity contributes one onset and no occupancy; point-only
observation or point-only coeligibility makes all four quantities
undefined.

Collapse erases edge and vertex labels before eligibility, presence,
evidence, and onset evaluation, permits V02’s established cross-session
authorization, calendar-unions pair risk and occupancy once, and counts
every eligible raw identity. Bounded constructs these objects within
each session, then calendar-unions pair risk/occupancy, unions the
ever-observed pair sets, and pools distinct raw onsets without
cross-session endpoint authorization. Separate returns each
session-local result. Global vertex schedules apply in every session and
undeclared vertices are static. When labels cannot affect eligibility,
bounded and collapse agree.

Translation preserves all four values. Positive rescaling by `k`
preserves both occupancies and divides both intensities by `k`.
Transposition, vertex renaming, and edge-row permutation preserve graph
totals. Duplicating or splitting a raw row without changing binary union
preserves both occupancies but deliberately adds raw onsets. Undirected
row reversal changes neither the domain nor any value, though every raw
row still contributes its own onset.

The public result records a named per-measure scope
(`snapshot_any_union` for old graph measures, `whole_window_exact` for
D04) so mixed calls do not inherit misleading snapshot-only metadata.
D04 metadata names the numerator, all/ever-observed denominator, global
pair-cohort scope, exact change-point integration, positive observed
clock, ordered-pair/dyad domain, binary occupancy, uncensored raw-start
identity, exact onset eligibility, zero instantaneous exposure,
inverse-time intensity units, ignored weights and loops, and effective
session aggregation.

**Literal ledgers:** on directed static `A,B,C,D` over `[0,10)`, use
`A->B [0,4)`, overlapping duplicate `A->B [2,6)`, `B->A [1,3)`, point
`A->C` at 5, `C->D [6,10)`, and retained weighted loop `A->A [0,10)`.
Then `H={AB,BA,AC,CD}`, `O=12`, `N=5`, `R=120`, and `R_H=40`, so the
four values are `1/10, 3/10, 1/24, 1/8`. Undirected canonicalization
gives `H={AB,AC,CD}`, `O=10`, `R=60`, `R_H=30`, and values
`1/6, 1/3, 1/12, 1/6`; raw direction is canonicalized only after event
identity is counted. A changing-population fixture with implicit `A`,
`B [0,5)`, `C [5,10)`, and matching `AB`, `AC` spells has
`R=20, R_H=10, O=10, N=2` and values `1/2, 1, 1/10, 1/5`.

Additional literal gates cover an endpoint-invalid raw pair excluded
from `H`; mixed onset/terminus censoring; a prevalent clipped spell;
positive-risk point contact; point-only observation; loop-only history;
no positive coeligibility; full-history `H` in early and late query
windows; snapshot versus integrated density; final-bin closure;
collapse/bounded/separate and cross-label authorization; zero
denominators; duplicates, splitting, relabeling, row order, transpose,
orientation, translation, scaling, and disjoint-window ledger
additivity.

The independent oracle normalizes raw observation and vertex schedules
on its own, enumerates pair eligibility and binary presence at midpoints
of every window/observation/vertex/edge change cell, builds `H` in a
separate complete- history evidence pass, and scans raw starts directly
for `N`. It must not call the production snapshot, duration, union, or
risk helpers. It compares the pair ledgers before the four ratios and
rejects fixed-order, snapshot-average, observation-hull,
per-window-cohort, raw-edge-cohort, onset-only-cohort, raw-duration-sum,
deduplicated-event, terminus-event, fragment-onset, censored-onset,
two-sided-onset, point-duration, loop, weight, boundary,
session-summation, cross-authorization, and zero-denominator mutants.

Stream-graph density supplies `O/R` and its co-presence denominator
(Latapy, Viard, and Magnien, 2018, <doi:10.1007/s13278-018-0537-7>). Raw
count/exposure is an incidence intensity rather than a state-transition
hazard (Andersen and Gill, 1982, <doi:10.1214/aos/1176345976>).
Installed
[`tsna::tEdgeDensity()`](https://rdrr.io/pkg/tsna/man/density.html)
0.3.6 is scoped to continuous, unsessioned, all-static, nonmultiplex
systems: duration/dyad can match temporal density and duration/edge can
match observed-pair density with one edge ID per pair. Event/dyad is
unimplemented; event/edge has a denominator-parenthesization bug away
from a zero origin and does not share Dynet censor semantics. Its empty
case returns zero where this contract is undefined, so no broader
equivalence is claimed.

**Exit complete (0.3.34):** focused D04 tests pass 70 assertions and the
full suite passes 3,397. The independent raw-table/change-cell oracle
passes 803 checks over 7,203 values in 250 unsessioned and 100 sessioned
randomized systems, three scoped `tsna` comparisons, and 23 mutant
discriminators with maximum error zero. D01–D03, V04, and standing
temporal-density oracles remain green. Mixed exact/snapshot metadata,
global cohort behavior, split-row onset identity, unequal component
pooling, singletons, observation touches, and undirected reversal have
direct gates. Source `/private/tmp/Dynet_0.3.34.tar.gz`, check
`/private/tmp/Dynet-0.3.34-check/Dynet.Rcheck` (no errors/warnings; the
known private-URL and slow-example notes only), and clean installed
library `/private/tmp/dynet-d04-library` pass. Final independent review
is clear.

## Turnover features

Raw spell-onset and spell-terminus counts already exist. The next four
features count relational-state transitions on union activity, so
duplicates and overlapping spells do not create false transitions.

At each timestamp, collapse every spell for a relational pair and
compare its union state immediately before the entire batch with its
union state immediately after the batch. Adjacent spells `[0, 1)` and
`[1, 2)` therefore have union `[0, 2)` and create no dissolution or
reformation at 1. Formation is `inactive -> active`; dissolution is
`active -> inactive`. A zero-duration contact leaves persistent state
unchanged and belongs to the separately named raw impulse-event count,
not the transition numerator.

A relationship transition is counted only when both endpoints, the pair,
and the observation process are eligible immediately before and
immediately after the timestamp batch. Vertex entry, vertex exit,
observation entry, and observation exit never create relationship
formation or dissolution. Risk-set denominators use the same two-sided
eligibility rule, so a tie incident to an entering vertex is not a
formation and a tie disappearing with an exiting vertex is not a
dissolution.

Left-censored onsets and right-censored termini are always excluded from
these confirmed-transition numerators. A sensitivity analysis that
counts administrative or censored endpoints would be a separately named
pseudo-transition quantity with its own denominator.

### T01 — Formation fraction

Add a separately named formation-transition fraction at an individual
change time. It is the number of eligible absent-to-active pair
transitions divided by the two-sided eligible pairs inactive immediately
before the timestamp batch. Positive-width windows do not return this
fraction; use T03 for exposure-based rates.

**Status:** complete in Dynet 0.3.35. The definition and literal fixture
ledger below were frozen before production implementation.

**Frozen definition (0.3.35):** add exactly
`events(..., measure = "formation_fraction")`, labelled “Formation
transition fraction”. Preserve the existing default raw
formation/dissolution call, signature, meanings, and graph-level tidy
schema. T01 is valid only for `window = 0`; requesting it with a
positive or default window, including in a mixed call, raises classed
`dynet_transition_requires_instant` inheriting from `dynet_bad_input`
and directs the user to T03. It may be mixed with existing event
selectors at zero width. `start`, `end`, and `step` retain the ordinary
requested exact-time grid and O02 component rows; T01 does not silently
replace that grid with irregular change times. At an interior non-change
time its numerator is zero and its value is zero when risk is positive.
A simple public call is
`events(dn, "formation_fraction", start = 1, end = 1, window = 0)`.

At sampled time `t`, define the exact one-sided state of every positive
half-open interval `[s,e)` algebraically: it is present immediately
before the timestamp batch iff `s < t <= e`, and immediately after iff
`s <= t < e`. Genuine point rows are absent on both sides. Apply the
same strict/non-strict limits to positive canonical observation and V01
vertex intervals. Thus observation must exist on both sides, and each
distinct endpoint must be eligible on both sides; isolated observation
or vertex points contribute to neither limit. All boundaries at one
timestamp are processed as one batch, never sequentially and never
through `t +/- epsilon`.

For nonloop opportunity `r` (ordered when directed, canonical unordered
dyad when undirected), let `Z_r(t)` indicate this two-sided observation
and endpoint eligibility, and let `E_r^-` and `E_r^+` be binary union
edge presence before and after the complete batch. Let `K_r(t)` indicate
at least one positive raw spell for `r` starting exactly at `t`, ending
after `t`, not explicitly onset-censored, and belonging to an effective
session scope that establishes the post-state. Define

\[ F_r(t)=Z_r(t)(1-E_r^(-)E_r)+K_r(t), D_0(t)=\_r Z_r(t)(1-E_r^-), \]

\[ formation_fraction(t)=. \]

When `D_0=0`, return literal `NA_real_`, never zero, `NaN`, or infinity.
Positive risk with no confirmed formation returns exact zero. The
numerator is a subset of the pair-state risk set, so the fraction is in
`[0,1]`.

The numerator counts binary pair-state transitions, not raw onsets and
not first-ever pairs. Duplicate or simultaneous starts for one pair
count once; an onset while another spell keeps the pair active is no
transition. Overlapping and adjacent `[0,1),[1,2)` spells have union
state active on both sides at 1, so create neither dissolution nor
reformation. A point contact is a D04/raw formation impulse but never
changes persistent one-sided state. Weights, signs, and multiplicity do
not affect the fraction. Loops are absent from numerator and risk.
Directed reverse pairs remain distinct; undirected orientation
canonicalizes before union and confirmation.

Raw censor flags never change `E^-` or `E^+`. A state change caused only
by onset-censored starts is unconfirmed and contributes zero while its
pair stays in the inactive-pre denominator. One uncensored contributing
positive start is enough to confirm the pair even alongside censored
duplicates. Terminus censoring is irrelevant to T01. Administrative
observation/activity fragment starts never satisfy `K`, and explicit
query bounds merely select timestamps: history on both sides of an
interior queried bound remains available.

Collapse erases edge and vertex session labels before eligibility,
state, and confirmation, permitting the established cross-session
authorization and counting each calendar pair once. Separate applies the
entire equation within each session and returns a local row. Bounded
first identifies, for each pair, the sessions in which both endpoints
are eligible on both sides; only those session-local edge states and
uncensored starts may contribute. It then ORs their pre-state,
post-state, and confirmation onto one calendar pair before applying
`F/D` once. This prevents cross-session endpoint authorization and
double counting, while a pair active throughout one eligible session
masks an onset in another from becoming a bounded union-state formation.
Global vertex schedules apply in every session; undeclared vertices are
static. With no session labels, bounded is effective collapse.

At an O01 outer bound, O02 gap endpoint, observation entry/exit, vertex
entry/exit, or point-only support, one side of `Z` is false, so those
boundaries cannot create transitions. A query boundary strictly inside
observed support does not truncate state. Adjacent observation intervals
were already merged and their shared coordinate remains an ordinary
interior time.

Output metadata records `event_identity="binary_pair_union_transition"`
for T01 without relabelling existing raw formation/dissolution rows. It
also names `transition="inactive_to_active"`,
`risk_set="two_sided_eligible_inactive_prestate_nonloop_pairs"`,
`batching="all_boundaries_at_timestamp"`,
`interval_state="half_open_one_sided_limits"`,
`confirmation="at_least_one_uncensored_positive_raw_onset"`,
`points="impulses_excluded"`, ignored weights, exact-time-only window
rule, probability unit, ordered-pair/dyad domain, requested-grid rule,
and effective session aggregation. Mixed raw-event/T01 calls use named
per-measure identity and scope metadata rather than one misleading
scalar.

Row, vertex, and session permutation, positive weight changes,
transposition, undirected endpoint reversal, time translation, and
positive time scaling (with the query transformed) preserve the scalar.
Duplicate/overlap representations and splitting a spell into adjacent
raw rows preserve the pair-state fraction. Time reversal is deliberately
not a T01 self-invariance. With interval limits reflected and censor
sides exchanged it maps the confirmed formation set to the T02
dissolution set, but inactive-pre and active-pre denominators need not
produce equal scalar fractions.

**Literal ledger:** on static directed `A,B,C` with positive observation
around `t=1`, use adjacent `A->B [0,1)` and `[1,2)`, duplicated
`A->C [1,2)`, `B->C [0.5,1.5)`, point `C->A` at 1, and onset-censored
`C->B [1,2)`. Before, `AB` and `BC` are active; the inactive risk set is
`{AC,BA,CA,CB}`. Only `AC` is a confirmed binary formation, so the
directed fraction is `1/4`. Undirected pre-state is `{AB,BC}`, its sole
inactive dyad `AC` forms, and the fraction is 1.

Additional literal gates cover first and recurrent formation versus
first-ever pairs; overlapping, duplicate, adjacent, simultaneous
end/start, and point batches; all-censored and mixed-censor starts;
terminus censoring; complete absent/full risk; loops, singleton, and no
two-sided opportunity; vertex entry/exit and observation/gap/point
boundaries; non-change time and interior query bounds;
collapse/bounded/separate masking and cross-label authorization; raw
formation disagreement; transformations; typed schema, labels, metadata,
and the classed positive-window error. Direct shared-kernel tests pin
eligible, pre/post active, risk, and confirmed formation pair sets, not
only their ratio.

The independent oracle normalizes observation and vertex schedules from
raw fixture tables, evaluates symbolic one-sided predicates without
epsilon, canonicalizes session-local binary pair state, scans positive
raw starts for confirmation, and derives pair sets before ratios. It
must not call production
active/snapshot/vertex/duration/D04/event/transition helpers. It
enumerates all raw, vertex, and observation change times plus non-change
controls and rejects raw-onset, first-only, sequential-batch,
exact-snapshot, point-state, adjacent-reformation, duplicate, censor,
clipped-boundary, wrong-risk, one-sided-eligibility,
loop/weight/direction, zero-risk, positive-window, and session-policy
mutants.

The risk-set convention follows Andersen and Gill (1982,
<doi:10.1214/aos/1176345976>), and half-open spell activity aligns with
`networkDynamic` 0.11.5 (<doi:10.32614/CRAN.package.networkDynamic>).
Scoped
`tsna::tEdgeFormation(result.type="fraction", include.censored=FALSE)`
0.3.6 can agree only for continuous unsessioned static-vertex,
loop-free, one-edge-object-per-pair interior times where each onset is a
genuine absent-to-active union transition and there are no simultaneous
ends, replacement spells, duplicates, overlaps, points, or activity
changes. Its documented denominator ignores vertex activity, so no wider
parity is claimed. T02–T04 must reuse this exact state ledger rather
than rederive boundary rules.

**Exit complete (0.3.35):** focused T01 tests pass 88 assertions and the
full suite passes 3,485. The independent raw-table oracle passes 9,906
exact-time checks over 9,906 values in 250 unsessioned and 100 sessioned
randomized systems, six restricted `tsna` comparisons, and 25 mutant
discriminators with maximum error zero. O02, V04, and D04 standing
oracles remain green, and final independent review is clear. Source
`/private/tmp/Dynet_0.3.35.tar.gz`, check
`/private/tmp/Dynet-0.3.35-check/Dynet.Rcheck` (no errors/warnings; the
known private-URL and slow-example notes plus a transient
inability-to-verify-time note), and clean installed library
`/private/tmp/dynet-t01-library` pass.

### T02 — Dissolution fraction

Add the active-to-absent transition fraction at an individual change
time, divided by the two-sided eligible active risk set immediately
before the timestamp batch.

**Status:** complete in Dynet 0.3.36. The definition and fixture ledger
below were frozen before production implementation.

**Frozen definition (0.3.36):** add exactly
`events(..., measure = "dissolution_fraction")`, labelled “Dissolution
transition fraction”. Existing raw `dissolution`, T01, defaults,
signature, and tidy schema remain unchanged. T02 accepts only
`window = 0`; positive or default windows (including mixed calls) raise
`dynet_transition_requires_instant`, inheriting from `dynet_bad_input`,
and direct users to T04. Requested `start`, `end`, and `step` grids
remain exact and are not replaced by irregular change times. At a
non-change time the value is zero when active risk is positive and
`NA_real_` when risk is zero.

Reuse T01’s exact symbolic state ledger: for positive `[s,e)`, pre-state
is `s < t <= e`, post-state is `s <= t < e`, and points are absent on
both sides. Observation and vertex eligibility use the same limits. For
each nonloop ordered pair (directed) or canonical dyad (undirected), `Z`
requires observation and both endpoints on both sides; `E-` and `E+` are
binary union states after the complete timestamp batch. No epsilon or
sequential ordering is permitted. Let `L` indicate at least one positive
raw spell with `start < t`, `end = t`, known terminus, and an effective
eligible session scope establishing the pre-state. Then
`G = Z * E- * (1-E+) * L` and `D1 = sum(Z * E-)`; T02 is `sum(G) / D1`
for positive `D1`, otherwise `NA_real_`. Stable active pairs remain in
the denominator. The result is in `[0,1]`.

Raw termini are not counted directly. Duplicate/simultaneous termini
count once; overlap, adjacent replacement, and same-time end/start
batches remain active on both sides. Points, loops, weights, signs,
multiplicity, onset censoring, and administrative observation/activity
cuts do not confirm a dissolution. A state change caused only by
terminus-censored rows remains in risk with numerator zero; one
uncensored contributing terminus confirms it. Observation/vertex
boundaries and points fail `Z`; query bounds do not censor stored
history. Recurrent dissolution is valid.

Collapse erases labels before eligibility/state/confirmation. Separate
applies the full equation per session. Bounded first filters to sessions
with two-sided endpoint eligibility, ORs local pre-state, post-state,
and confirmation onto each calendar pair, then applies `G/D` once;
continued activity in one eligible session masks a local end in another.
Labels never cross-authorize bounded endpoints, and pairs are never
double counted. Without labels, bounded is effective collapse. Empty,
singleton, loop-only, point-only, wholly inactive, or zero-active-risk
domains return `NA_real_`.

Metadata uses `event_identity="binary_pair_union_transition"`,
`transition="active_to_inactive"`,
`risk_set="two_sided_eligible_active_prestate_nonloop_pairs"`, and
`confirmation="at_least_one_uncensored_positive_raw_terminus"`, while
reusing T01 batching, half-open state, point, weights,
exact-window/grid, domain, unit, and session metadata. A single
transition selector retains scalar transition/risk/confirmation
attributes; when both fractions are requested those three become named
per-measure mappings. The shared ledger preserves T01’s existing
formation fields and `counts` vector exactly and adds typed
terminus-confirmation, dissolution-risk, dissolution-set, and
dissolution-count fields.

Permutation, positive-weight, transpose, undirected-reversal,
translation, and positive time-scaling transformations preserve the
scalar when the query is transformed. Reflecting interval limits and
swapping censor sides maps confirmed T02 sets to T01 sets, not
necessarily equal scalar fractions because the active-pre and
inactive-pre denominators differ.

**Literal ledger:** on static directed `A,B,C`, observation `[0,3]`, at
`t=1` use adjacent `AB [0,1),[1,2)`, duplicate `AC [0,1)` rows,
persistent `BA [0,2)` plus short `BA [0,1)`, persistent `BC [0.5,1.5)`,
point `CA` at 1, terminus-censored `CB [0,1)`, and loop `AA [0,1)`.
Two-sided domain is `{AB,AC,BA,BC,CA,CB}`; active-before/risk is
`{AB,AC,BA,BC,CB}`; active-after is `{AB,BA,BC}`; only `AC` is a
confirmed disappearance, giving `1/5`. Undirected risk is `{AB,AC,BC}`,
post-state `{AB,BC}`, and the value is `1/3`. Raw `dissolution` is six,
proving raw termini are not the T02 unit. Additional fixtures pin
recurrence, duplicates, overlap, adjacency, replacement, censor
mixtures, loops, boundaries, sessions, transformations, metadata, typed
schema, and the classed positive-window error.

The independent oracle must normalize raw observation/activity itself,
use symbolic one-sided predicates, derive session-local binary states
and raw terminus confirmation, then apply session policy. It must not
call production state, event, duration, density, path, or transition
helpers. Randomized systems and mutants cover raw-count, last-ever,
sequential, snapshot, point, adjacency, duplicate, censor-side,
wrong-risk, one-sided eligibility, loop/weight/direction, zero-risk,
positive-window, and session-policy errors. Restricted
`tsna::tEdgeDissolution(result.type="fraction", include.censored=FALSE)`
parity is claimed only for continuous unsessioned static-vertex,
loop-free, one-edge-per-pair interior times with genuine isolated
termini and no duplicates, overlap, replacement, points, or activity
changes; calibration values at times 3, 5, and 8 are `1/2`, `1`, and
`1`. T03–T04 must continue using this one shared ledger.

**Exit complete (0.3.36):** focused T02 tests pass 108 assertions and
the full suite passes 3,593. The independent raw-table oracle passes 13
literal assertions and 9,906 exact-time values across 250 unsessioned
and 100 sessioned randomized systems, six restricted `tsna` comparisons,
and 25 mutant discriminators with maximum error zero. T01, O02, V04, and
D04 standing oracles remain green, and final independent review is
clear. Source `/private/tmp/Dynet_0.3.36.tar.gz`, check
`/private/tmp/Dynet-0.3.36-check/Dynet.Rcheck` (no errors/warnings; the
known private-URL and slow-example notes plus a transient
inability-to-verify-time note), and clean installed library
`/private/tmp/dynet-t02-library` pass.

### T03 — Formation rate

Divide eligible absent-to-active transitions by integrated empty-pair
risk time over a positive window. State the inverse time unit in result
metadata.

**Status:** complete in Dynet 0.3.37. The definition and fixture ledger
below were frozen before production implementation.

**Frozen definition (0.3.37):** add exactly
`events(..., measure = "formation_rate")`, labelled “Formation
transition rate”. Preserve existing raw events and T01/T02 meanings and
tidy schema. T03 is valid only for `window > 0`; `window = 0` raises
`dynet_rate_requires_positive_window` inheriting from `dynet_bad_input`
and directs users to T01. A fraction and rate in one call raises
`dynet_incompatible_transition_windows` inheriting from
`dynet_bad_input`. Raw event selectors may mix with T03 at positive
width. Requested bin and rolling-window semantics, including the closed
final endpoint, remain those of the existing event grid.

For positive reporting window `W`, reuse T01’s confirmed pair formation
set at each included timestamp batch. Let `F(W)` be the sum of distinct
confirmed binary pair formations at those timestamps (a recurrent pair
counts again at a different timestamp). Let `Y_r(t)` indicate positive
observation and exact simultaneous eligibility of both endpoints for
nonloop opportunity `r`, and let `E_r(t)` be binary-union pair state.
Define exact change-point exposure

\[ A_0(W)=\_r_W Y_r(t)\[1-E_r(t)\],dt, formation_rate(W)=F(W)/A_0(W). \]

Integrate positive half-open cells cut by window limits, observation
components/gaps, vertex activity boundaries, and edge-union boundaries;
do not average T01 fractions, sum instantaneous risk counts, use a
grid/Riemann midpoint approximation, or use D04’s ever-observed cohort.
If `A_0=0`, return literal `NA_real_` even when a boundary formation
makes `F>0`; positive exposure with no confirmed formation is zero.
Rates are finite nonnegative and have inverse network-time units. Points
have zero exposure and cannot confirm.

At each numerator timestamp use T01’s symbolic pre/post predicates and
full batch union. Onset censoring suppresses confirmation but not state;
one known duplicate confirms, terminus censoring is irrelevant, and
administrative observation/activity fragment starts never confirm. Query
bounds select events without truncating history. Events at the left
endpoint are included using prehistory; the right endpoint is included
only for an existing closed final bin. Observation gaps and
endpoint/activity entry/exit fail two-sided `Z` and do not fabricate
formations. Duplicates, overlap, adjacency, replacement, points, loops,
weights, signs, direction canonicalization, and multiplicity follow T01.
A positive time scale by `c` multiplies exposure by `c` and divides the
rate by `c`; translation preserves it.

Collapse erases labels before eligibility, state, and confirmation.
Separate computes numerator and exposure wholly within each session.
Bounded filters each session to endpoint-authorized local eligibility,
ORs local eligibility and active state onto calendar pairs, and
integrates the calendar union once; it never sums local empty exposure
and never cross-authorizes labels. A continuing eligible tie in one
session masks an onset in another. With no labels bounded is collapse.
The domain is all eligible nonloop ordered pairs or canonical dyads, not
first-ever or ever-observed pairs.

Metadata records `measure_scope="whole_window_exact"`,
`event_identity="binary_pair_union_transition"`,
`transition="inactive_to_active"`,
`transition_numerator="confirmed_pair_formations_in_window"`,
`risk_set="integrated_eligible_inactive_nonloop_pair_time"`,
`confirmation="at_least_one_uncensored_positive_raw_onset"`,
`risk_clock="positive_observed_time"`,
`risk_integration="exact_change_point"`,
`batching="all_boundaries_at_timestamp"`,
`interval_state="half_open_one_sided_limits"`,
`points="impulses_excluded"`, `weights="ignored"`,
`window_rule="positive_window_only"`, inverse-time unit, opportunity
domain, and effective session aggregation. Mixed raw/T01/T03 calls use
named per-measure identity, scope, numerator, denominator, and unit
metadata rather than scalar leakage.

**Literal ledger:** on static directed `A,B,C`, observation `[0,10]`,
use `AB [2,6),[8,10)`, `AC [0,4)`, `BA [3,7)`, point `BC` at 5,
duplicated `CA [5,9)`, onset-censored `CB [4,8)`, and loop `AA [1,9)`.
Inactive exposure by ordered pair is
`AB=4, AC=6, BA=6, BC=10, CA=6, CB=6`, so `A0=38`; confirmed formations
are `AB@2, BA@3, CA@5, AB@8` and the rate is `2/19`. (The pair-key
exposure table and timestamp set are the authoritative fixture objects;
raw formation count is a discriminator.) Undirected reduction has
`AB=3, AC=2, BC=6`, `A0=11`, three confirmed formations, and rate
`3/11`. Additional literals pin observation components, vertex
boundaries, censor mixtures, empty/full/zero exposure, windows,
sessions, transformations, units, metadata, and typed schema.

The independent oracle must normalize raw observation/activity itself,
enumerate all window, observation, vertex, and edge change cells,
integrate canonical `Y(1-E)` exactly, and separately scan symbolic
confirmed onset timestamps under T01 session rules. It must not call
production transition, state, exposure, D04, snapshot, duration, path,
or event helpers. Mutants must kill raw-onset counts, first-ever-only,
averaged T01 fractions, instant risk sums, fixed/active/ever-observed
denominators, gap bridging, point exposure, one-sided eligibility,
batch/duplicate/adjacency errors, censor mistakes, boundary ownership,
zero-to-zero/Inf, session summation, and scale invariance.

`tsna::tEdgeFormation(..., result.type="count")` may calibrate only the
numerator in a narrow continuous unsessioned static-vertex loop-free
one-edge-per-pair domain. Its instantaneous denominator is not T03
exposure; an independent integration of `tsna:::emptyDyadCount` is
calibration only and is not a public equivalence claim. Andersen–Gill
(1982, <doi:10.1214/aos/1176345976>) supports event count per integrated
at-risk time, and `networkDynamic` 0.11.5 supplies the half-open state
convention. T04 must reuse this exposure engine with active-pair
exposure.

**Exit complete (0.3.37):** focused T03 tests pass 91 assertions and the
full suite passes 3,684. The independent raw-table oracle passes 9
literal assertions and 8,552 rate comparisons across 350 randomized
systems, six restricted `tsna` calibration checks, and 30 mutant
discriminators with maximum error zero. T01 and T02 oracles remain
green, and final independent review is clear. Source
`/private/tmp/Dynet_0.3.37.tar.gz`, check
`/private/tmp/Dynet-0.3.37-check-final/Dynet.Rcheck` (no
errors/warnings; the known private-URL and slow-example notes plus a
transient inability-to-verify-time note), and clean installed library
`/private/tmp/dynet-t03-library` pass.

### T04 — Dissolution rate

Divide eligible active-to-absent transitions by integrated active-pair
risk time over a positive window. Treat right censoring and zero risk
time explicitly.

**Status:** complete in Dynet 0.3.38. The definition and fixture ledger
below were frozen before production implementation.

**Frozen definition (0.3.38):** add exactly
`events(..., measure = "dissolution_rate")`, labelled “Dissolution
transition rate”. It requires `window > 0`; `window = 0` raises
`dynet_rate_requires_positive_window` inheriting from `dynet_bad_input`
and directs users to T02. Any call containing a fraction and either rate
raises `dynet_incompatible_transition_windows` inheriting from
`dynet_bad_input`. `formation_rate` and `dissolution_rate` may mix at
positive width, as may raw event selectors. Preserve all defaults,
schemas, and existing selector meanings.

For positive reporting window `W`, reuse T02’s confirmed pair
dissolution set at every included timestamp batch. Let `D(W)` sum
distinct confirmed binary pair dissolutions at those timestamps, with
recurrent times counted again. Let `Y_r(t)` be positive observation and
exact simultaneous endpoint eligibility for each nonloop ordered
pair/dyad, and `E_r(t)` its binary-union active state. Define exact
change-point active exposure

\[ A_1(W)=\_r_W Y_r(t)E_r(t),dt, dissolution_rate(W)=D(W)/A_1(W). \]

Integrate positive half-open cells cut by window, observation components
and gaps, vertex activity, and edge-union boundaries. Do not use raw
spell duration, ever-observed cohorts, instantaneous T02 risk, averaged
fractions, or grid approximations. If `A_1=0`, return literal
`NA_real_`, even when a boundary event makes `D>0`; positive exposure
with no confirmed dissolution returns exact zero. Rates are finite
nonnegative, unbounded, and measured per network-time. Positive time
scaling by `c` divides the rate by `c`.

At each terminus timestamp use T02’s full-history symbolic batch state.
Known terminus censoring confirms a disappearance; one known duplicate
suffices and all-censored disappearance remains unconfirmed. Onset
censoring is irrelevant. Observation/activity fragment ends, gaps,
points, loops, weights, signs, duplicates, overlaps, adjacent
replacement, same-time end/start batches, and administrative boundaries
cannot fabricate a dissolution. Query limits select events without
truncating history; final closed bins own their right endpoint.

Collapse erases labels before state, eligibility, exposure, and
confirmation. Separate computes `D` and `A1` per session. Bounded
endpoint-authorizes each session, ORs local
eligibility/state/confirmation onto each calendar pair, and integrates
active union once; it never sums local exposure or cross-authorizes
labels. Continued activity in one eligible session masks a local end in
another. With no labels bounded is collapse.

Metadata uses `measure_scope="whole_window_exact"`,
`event_identity="binary_pair_union_transition"`,
`transition="active_to_inactive"`,
`transition_numerator="confirmed_pair_dissolutions_in_window"`,
`risk_set="integrated_eligible_active_nonloop_pair_time"`,
`confirmation="at_least_one_uncensored_positive_raw_terminus"`,
`risk_clock="positive_observed_time"`,
`risk_integration="exact_change_point"`, T01
batching/half-open/point/weight/window/domain/session metadata, and
`transition_unit="per_<time_unit>"`. Mixed T03/T04 calls must use named
transition, risk, confirmation, numerator, denominator, unit, identity,
and scope mappings; single T04 may retain scalar attributes.

**Literal ledger:** static directed `A,B,C`, observation `[0,10]`, with
`AB [0,2),[4,8)`, `AC [0,10)`, `BA [1,5)`, point `BC` at 5, duplicated
`CA [2,6)`, terminus-censored `CB [3,7)`, and loop `AA [0,10)`. Active
exposure is `AB=6, AC=10, BA=4, BC=0, CA=4, CB=4`, total `A1=28`.
Confirmed dissolutions are `AB@2, BA@5, CA@6, AB@8`, so `D=4` and the
rate is `1/7`; raw known dissolution count is a discriminator.
Undirected union exposure is `AB=8, AC=10, BC=4`, total `22`; only the
true AB end at 8 is confirmed, so the rate is `1/22`. Additional
literals pin censor mixtures, gaps, vertex boundaries, recurrence,
windows, sessions, zero exposure, units/scaling, metadata, and typed
schema.

The independent oracle must normalize raw tables itself, integrate
canonical `Y*E` over exact change cells, and separately derive symbolic
T02 dissolution sets under all session policies. It must not call
production transition, exposure, D04, snapshot, duration, path, or event
helpers. Mutants cover raw terminus counts, last-ever-only, averaged
fractions, wrong active/inactive or instant denominators, points,
sequential batches, duplicates, overlap, adjacency, censor sides,
fragment ends, boundaries/gaps, loops/weights, direction,
zero-to-zero/Inf, final closure, session summation and masking, and
time-scale invariance. Restricted `tsna` count parity is calibration
only for continuous unsessioned static loop-free one-edge-per-pair
isolated termini; its instantaneous fraction denominator is not T04
exposure. Andersen–Gill (1982, <doi:10.1214/aos/1176345976>) and
`networkDynamic` 0.11.5 supply the risk and half-open conventions. T04
is the active-exposure dual of T03.

**Exit complete (0.3.38):** focused T04 tests pass 96 assertions and the
full suite passes 3,780. The independent raw-table oracle passes 9
literal assertions and 8,552 rate comparisons across 350 randomized
systems, six restricted `tsna` calibration checks, and 30 mutant
discriminators with maximum error zero. T01, T02, and T03 oracles remain
green, and final independent review is clear. Source
`/private/tmp/Dynet_0.3.38.tar.gz`, check
`/private/tmp/Dynet-0.3.38-check-final/Dynet.Rcheck` (no
errors/warnings; the known private-URL and slow-example notes plus a
transient inability-to-verify-time note), and clean installed library
`/private/tmp/dynet-t04-library` pass.

For T01–T04, fixtures include first and recurrent ties, duplicate and
overlapping spells, simultaneous dissolution/reformation, empty and full
risk sets, directed and undirected opportunities, loops, vertex
entry/exit, observation gaps, and censoring. Fractions stay in `[0, 1]`;
rates rescale inversely with the time unit. `tsna` is an oracle only for
aligned discrete fractions with matching batch-state semantics.

## Event-sequence and projection features

### E01 — Participation shifts

**Purpose:** implement Gibson’s 13 classes.

**Candidate public surface:** a dedicated
[`pshifts()`](https://mohsaqr.github.io/Dynet/reference/pshifts.md) verb
returning one tidy row per class, or one row per event and class for
cumulative output.

Before implementation, define how each Dynet format becomes an event
sequence: whether an interval contributes its onset only, whether
threaded and co-presence constructions are eligible, canonical order for
tied times, repeated events, group-directed events, simultaneous
recipients, missing endpoints, and session walls.

**Status:** complete for Dynet 0.3.39. The definition and literal ledger
below are frozen before production implementation.

**Frozen definition (0.3.39):** add
`pshifts(dn, sessions = c("bounded", "collapse", "separate"), output = c("final", "cumulative"), start = NULL, end = NULL, group_events = c("simultaneous", "none"))`.
Require directed Dynet input; undirected/co-presence input raises
`dynet_needs_directed` inheriting from `dynet_bad_input`. `final` is the
default and returns graph-level counts only.

Convert one-row-per-raw-spell identities to turns: each uncensored
observed raw onset contributes once, interval duration and terminus are
ignored, and point contacts contribute their point. Fragment starts,
active snapshots, weights, overlap/union, vertex activity, and
onset-censored rows do not contribute. Query limits and each observation
component are sequence walls; gaps do not bridge and query truncation
starts a fresh sequence. Malformed or missing endpoints are errors,
never Gibson’s group sentinel. Terminus censoring is irrelevant.
Collapse erases labels before inference; bounded and separate construct
within-session sequences.

With `group_events = "simultaneous"`, two or more distinct nonself
targets sharing exactly `(time, speaker)` become one group-directed turn
`A->0`; duplicate rows to one target remain repeated dyadic turns.
`"none"` keeps each row dyadic. A retained self-loop is an unclassified
sequence break, not a bridge. Order turns deterministically by
`(time, speaker canonical index, named-target before group, target canonical index)`;
exact identical duplicates retain multiplicity. Ties are ordered, not
batched, and unresolved equal-time renaming is not claimed invariant.

For consecutive valid turns, classify exactly these fixed labels and
order: `AB-BA`, `AB-B0`, `AB-BY`, `A0-X0`, `A0-XA`, `A0-XY`, `AB-X0`,
`AB-XA`, `AB-XB`, `AB-XY`, `A0-AY`, `AB-A0`, `AB-AY`. A previous `AB` or
`A0` and current `C->D/0` map by receiving (`C=B`), claiming (previous
`A0`, `C!=A`), usurping (previous `AB`, `C` outside `{A,B}`), or
continuing (`C=A`) rules; self-loop/malformed/first turns increment
nothing. Every eligible consecutive pair maps to at most one class.

`final` returns exactly 13 rows with `shift`, `family`, and integer
`count`, plus `session` for separate; zero/one-event sequences still
emit typed zeros. `cumulative` returns one row per derived turn and
class state with sequence, event, restored time, speaker, target, group,
shift, family, and cumulative count; its terminal vector equals `final`.
Class results as `c("dynet_pshifts", "data.frame")` and retain fixed
labels. Metadata records raw-onset identity, Gibson classification,
onset-only conversion, group rule, tie rule,
duplicate/terminus/weight/activity/loop conventions, walls, and session
aggregation. Translation/time scaling preserve counts.

**Literal ledger:** put each minimal pair in its own session:
`A->B,B->A`, `A->B,B->0`, `A->B,B->C`, `A->0,C->0`, `A->0,C->A`,
`A->0,C->B`, `A->B,C->0`, `A->B,C->A`, `A->B,C->B`, `A->B,C->D`,
`A->0,A->B`, `A->B,A->0`, and `A->B,A->C`; each contributes one
corresponding class. Encode `->0` as two distinct simultaneous
recipients. Add repeated dyads, tied speakers, a loop wall, censored
onset, interval/thread/contact equivalence, group opt-out, range
truncation, observation gaps, and collapse/bounded/separate fixtures.

The independent oracle reads raw public spells, filters observed known
onsets, forms group turns itself, canonicalizes ties, splits walls, and
classifies consecutive role pairs without calling production
event/session/pshift helpers. Mutants cover active/end events,
fragments, censored starts, weights, pair-union deduplication,
same-target grouping, row-order ties, cross-wall predecessors, loop
bridging, and undirected acceptance. `relevent::accum.ps()` parity is
restricted to continuous directed no-wall unique-time dyadic turns;
`tsna` is restricted further to its own preprocessing convention. Gibson
(2003, <doi:10.1353/sof.2003.0055>) is the primary classification
reference.

**Fixtures:** one minimal event pair per class plus unclassified
repetition, tied times, grouped recipients, row permutation, range
truncation, and directedness rejection.

**Oracle:** literal role classification, `relevent::accum.ps()`, and
[`tsna::pShiftCount()`](https://rdrr.io/pkg/tsna/man/pShiftCount.html)
where event conversion matches.

### E02 — Time-projected network

**Purpose:** create a discrete vertex-time representation with forward
identity arcs.

**Status:** active for Dynet 0.3.39. The following definition is frozen
before production tests and implementation.

**Frozen definition (0.3.39):** add
`projection(dn, sessions = c("bounded", "collapse", "separate"), start = NULL, end = NULL, step = NULL, window = NULL)`.
It returns a list of class `dynet_projection`, never a bare matrix. Its
public tables are available through
`as.data.frame(x, what = c("vertices", "edges"))`.

Use the ordinary component-qualified Dynet measurement grid and V02
snapshot state. Positive windows independently aggregate vertex
eligibility and edge activity with the `any` rule and then induce on the
eligible vertex set; instantaneous windows use exact simultaneous state.
Interior positive bins are half open and the last default bin of each
observation component is closed on the right, so a genuine
final-boundary point belongs to that final slice. Observation points
produce punctual slices. Explicit query limits, phase, step,
rolling-window, clipping, outside-observation errors, Date/POSIX
conversion, and the final-boundary rule are inherited from the common
grid.

Emit every fixed-universe node in every slice, including inactive nodes
and eligible isolates. Vertex rows have structural columns, in order:
integer `state`; optional character `session`; optional integer
`observation`; integer `slice`; numeric `time`, `start`, and `end`;
logical `closed`; character `node`; logical `active`; then copied public
node attributes. Structural names win collisions. A colliding source
attribute `x` is copied as `node_x`, repeatedly prefixing `node_` until
the name conflicts with neither a structural column nor an unchanged
source attribute; record the old-to-new mapping as a named character
vector. State IDs are deterministic blocks in source-session order (one
`all` block after collapse), then slice order, then fixed node order:
`offset + (slice - 1) * n_nodes + node_index`.

Within each slice, retain one directed projected edge per endpoint-valid
ordered pair. Sum active raw weights into numeric `weight` and count
active raw rows in integer `n_spells`; duplicates and overlaps therefore
collapse only inside a slice. A directed source retains direction. Each
nonloop undirected source dyad becomes two opposite directed projected
edges carrying the same weight and spell count; an undirected loop, when
allowed by the source, appears once. The projected network itself is
always directed.

Add one unconditional forward identity arc for every fixed node between
each pair of consecutive emitted slices in the same block. Identity arcs
remain through inactive vertex periods and between consecutive emitted
observation components, matching Dynet’s permission to wait at a static
vertex across an observation gap. They never run backward, skip a slice,
or cross a source session wall. Their `weight` is exactly `1`,
`n_spells` is exactly `0`, and their `lag` is the calendar difference
between slice times. Within-slice lag is zero.

Edge rows have structural columns, in order: integer `from_state` and
`to_state`; character `from_node` and `to_node`; optional character
`session`; integer `from_slice` and `to_slice`; numeric `from_time` and
`to_time`; character `edge_type` equal to `within_slice` or
`identity_arc`; numeric `weight`; integer `n_spells`; and numeric `lag`.

For a source with sessions, bounded and separate projections construct
one full session-local block per source session in canonical
source-session order, including an empty-edge block, expose the
`session` key, and never add an arc between blocks. Collapse erases
labels before snapshot aggregation, constructs one calendar block, and
omits `session`. Without source sessions bounded is effective collapse
and omits the column; separate retains the established
`dynet_no_sessions` error. The distinction between bounded and separate
remains in metadata for compositional consistency even though their
projected graph rows coincide on sessioned input.

Store `$vertices`, `$edges`, and `$meta`. Metadata names are exactly
`source_directed`, `directed`, `time_unit`, `origin`, `step`, `window`,
`sessions`, `n_nodes`, `n_slices`, `n_blocks`, `vertex_rule`,
`within_slice_rule`, `identity_rule`, `identity_weight`,
`undirected_rule`, `observation_gap_waiting`, `session_aggregation`,
`node_attribute_names`, and `node_attribute_renames`. Metadata records
the always-directed result, fixed state population, V02 any/instant
rule, forward-unconditional identity rule, undirected expansion, gap
waiting, and session policy.

**Fixtures:** three named vertices over three unit slices with `A->B`,
`B->C`, and `C->A` respectively: exactly nine state rows, three
within-slice edges, and six forward identity arcs. Add interior and
final-boundary points; inactive declared vertices and vertex-only
isolates; duplicate weighted rows; directed loops; undirected expansion;
point-only and gapped observation; bounded/collapse/separate sessions
including an empty local block; singleton and empty-edge fixed
universes; rolling and instant windows; copied node attributes and
collisions; row/name/time translation and positive-scaling
transformations; and invalid range/grid/accessor requests.

**Oracle and external comparison:** independently build the grid from
public raw spells, observation support, and vertex spells; evaluate
vertex/edge `any` or exact-point state without calling production
projection, snapshot, grid, or encoding helpers; assign literal state
IDs; and generate identity arcs by adjacent row blocks. Mutants cover
dropping inactive states, endpoint union before induction, interval-end
inclusion, omission of the final closed point, raw-row rather than pair
aggregation, binary or averaged weights, backward or cross-session
identity, omission across observation gaps, identity arcs only for
active nodes, wrong state offsets, undirected non-expansion, and copied
attribute loss. Compare
[`tsna::timeProjectedNetwork()`](https://rdrr.io/pkg/tsna/man/timeProjectedNetwork.html)
only on continuous, all-static, interior, non-session, uncensored
interval fixtures with matching unit bins; its own inactivity, boundary,
attribute, and preprocessing rules do not define Dynet semantics.

## G01 — Lightweight structural descriptives

**Status:** complete as a deliberately bounded descriptive extension.
Dynet does not implement an ERGM formula ecosystem and does not require
`ergm`. Existing
[`metrics()`](https://mohsaqr.github.io/Dynet/reference/metrics.md)
selectors already cover isolates, directed dyad census, density,
reciprocity, transitivity, triads, and mixing.

Add only the missing low-cost descriptive selectors through
[`metrics()`](https://mohsaqr.github.io/Dynet/reference/metrics.md):
`degree_mean`, `degree_variance`, `degree_min`, `degree_max`,
`concurrent_nodes`, `concurrent_share`, `in_2stars`, `out_2stars`, and
`two_paths`. All use the binary loop-free endpoint-induced snapshot.
Directed degree is incoming plus outgoing arcs; undirected degree is
distinct neighbours. Concurrency means at least two distinct neighbours,
so reciprocal arcs do not manufacture concurrency. Directed stars sum
choose-2 over the corresponding margins. Directed two-paths count
ordered `i -> j -> k` paths with distinct endpoints; undirected paths
count each unordered wedge once. Empty eligible snapshots return zero.
In/out stars require directed input.

Shared-partner distributions, general k-stars, node-factor/node-match
ERGM terms, transitive/cyclic change statistics, and formula parity are
explicitly optional backlog rather than completion criteria.

## I01 — Immutable node and tie editing

**Status:** complete for Dynet 0.3.41. Cograph mutation helpers operate
only on the flattened graph and cannot preserve Dynet’s temporal spell
ledger. Dynet therefore exposes
[`add_nodes()`](https://mohsaqr.github.io/Dynet/reference/add_nodes.md),
[`remove_nodes()`](https://mohsaqr.github.io/Dynet/reference/remove_nodes.md),
[`add_ties()`](https://mohsaqr.github.io/Dynet/reference/add_ties.md),
and
[`remove_ties()`](https://mohsaqr.github.io/Dynet/reference/remove_ties.md),
plus directed-only
[`add_arcs()`](https://mohsaqr.github.io/Dynet/reference/add_arcs.md)
and
[`remove_arcs()`](https://mohsaqr.github.io/Dynet/reference/remove_arcs.md)
aliases. Every operation returns a rebuilt object and leaves its input
unchanged.

Tie additions require existing named endpoints and the existing
clock/session scheme. Raw interval identity, weights, censor flags,
observations, vertex activity, aggregate weights, cograph node IDs,
groups, and metadata are rebuilt together. Explicit observation support
stays fixed; implicit support expands or contracts with the raw event
range. Removal accepts exact public-row positions or conjunctive
named/time/session selectors and cannot leave an edgeless Dynet. Node
removal is isolate-only by default; `cascade = TRUE` explicitly removes
incident tie and vertex-activity identities. Undirected endpoints and
cograph node ordering are canonicalized together.

## R01 — Temporal paper-reproduction surface

**Status:** complete for Dynet 0.3.42. Scope is limited to
temporal-network operations found across the Trees of Thought scripts.
General data wrangling, spreadsheet I/O, sequence analysis, clustering,
psychometric networks, and generic plotting remain external.

The compatibility layer adds
[`as_dynet.networkDynamic()`](https://mohsaqr.github.io/Dynet/reference/as_dynet.networkDynamic.md)
and exact static
[`collapse_network()`](https://mohsaqr.github.io/Dynet/reference/collapse_network.md)
cograph output; node/tie attribute edits and renaming; vertex-activity,
observation, and session edits; temporal subgraphs; loop-free
descriptive replacements for ERGM `meandeg`, `idegree1.5`, `odegree1.5`,
and `triangle`; diffusion degree; and explicit path-family and
transmission-timeline views. Existing Dynet APIs cover the remaining
legacy centrality, prestige, graph, census, mixing, duration,
reachability, time-respecting path, projection, and proximity
operations.

The rendered reproduction and its CSV artifacts live under
`inst/reproduction/trees-of-thought`. On the supplied weighted dynamic
object, collapse parity passes for 98 aggregate edges, duration total
352.6367, duration range, and the 84/13/1 activity-count distribution.
On the corrected loop-free first window, the five ERGM descriptive
comparisons pass with maximum absolute error below `1.5e-13`. The
supplied nominal no-loop object is audited as containing nine self-loop
spells because its construction script reused the unfiltered table.

## Execution order

Proceed exactly in this order:

``` text
C01
-> P01 -> P02 -> P03 -> P04 -> P05 -> P06 -> P07 -> P08 -> P09 -> P10
-> A01 -> A02
-> S01 -> S02 -> S03 -> S04 -> S05 -> S06 -> S07 -> S08 -> S09
-> O01 -> O02 -> O03
-> V01 -> V02 -> V03 -> V04
-> D01 -> D02 -> D03 -> D04
-> T01 -> T02 -> T03 -> T04
-> E01 -> E02
-> G01 -> I01 -> R01
```

The opening is deliberately corrective. C01 repairs a bounded quantity
already reported publicly. P01 freezes traversal before P02 calibrates
backward paths. P08 cannot begin until P07 defines the optimal journey;
P09 then uses P08’s state engine for any hop-aware closeness definition.
Duration and turnover work waits for observation and vertex-activity
semantics so denominators are not implemented twice.

## Completion boundary

The required mathematical roadmap ends at bounded G01; I01 and R01 add
requested object plumbing and a paper-reproduction surface without
importing an ERGM formula ecosystem. Sophisticated ERGM statistics
remain optional backlog and do not prevent a complete release.
