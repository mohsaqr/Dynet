# Dynet

Temporal network construction, measurement and visualisation in R.

A static network says two people are connected. A temporal network says when,
for how long, and in which order — and refuses to let a path run backwards in
time. Aggregating time away inflates connectivity and hides the dynamics; every
verb here keeps time in the result.

## Two commitments

**Vertices are named, never numbered.** `dyn_paths(dn, from = "Ana")`. There is
no vertex index to look up first, and no result that hands you an integer where
you expected a person. (The aggregate edge table uses integer endpoints because
that is cograph's schema, but nothing in the public surface exposes them —
`as.data.frame()` returns names, in every layout.)

**Every verb returns a tidy data frame.** One row per observation, with the
columns you would expect. No matrices, no nested lists, no named list of
matrices when you ask for sessions. Nothing in this package asks you to reach
into an object with `$` or to subset a result to make it readable.

## Building a network

One constructor covers the four shapes relational logs arrive in. The shape is
inferred from the arguments you name.

```r
library(Dynet)

# Interval log: each row carries its own start and end
dynet(school_contacts)

# Contact log: instantaneous events, no duration
dynet(clicks, time = "timestamp")

# Threaded log: a post stays active until its thread falls silent
dynet(forum_posts, thread = "thread", nodes = forum_people)

# Co-presence log: actors sharing a group become connected
dynet(seminar_attendance, actor = "student", group = "seminar")
```

Column names are matched case-insensitively against a table of aliases, so
`Sender`/`Receiver`, `source`/`target` and `onset`/`terminus` all work without
being spelled out. Times may be numeric, `Date`, `POSIXct` or character
date-time strings; date-time input is converted to elapsed time in a unit
chosen to suit the span, and the unit is reported.

When the study window is known independently of the event log, declare it on
construction:

```r
dn <- dynet(
  school_contacts,
  observation_start = 0,
  observation_end = 20
)
```

Observation bounds clip analytical exposure and constrain path horizons without
rewriting the source spells. Positive intervals use their half-open
intersection with the study window; genuine point contacts at either limit are
retained. `as.data.frame(dn)` still returns the original spell boundaries, and
clipping never fabricates formation, dissolution, or censoring events.

For interrupted observation, supply the observed spells directly:

```r
dn <- dynet(
  school_contacts,
  observation_spells = data.frame(
    start = c(0, 12),
    end = c(8, 20)
  )
)
as.data.frame(dn, what = "observations")
as.data.frame(dn, what = "observed_edges")
```

Overlapping or adjacent observation spells are normalized into canonical
components. Exposure denominators sum their durations rather than using the
hull, events in gaps are excluded, and an edge spanning a gap is exposed as
separate administratively censored fragments without changing its raw row.
Measurement grids restart within components and never create gap-only bins.
Temporal paths may wait at a persistent vertex across an observation gap, but
every positive-duration interval traversal must fit inside one observed
fragment. A point contact still triggers its configured delayed arrival;
session boundaries remain path walls.

When interval limits are themselves censored, name strict logical source
columns explicitly:

```r
dn <- dynet(
  interval_log,
  onset_censored = "left_censored",
  terminus_censored = "right_censored"
)
```

These are raw-data states, not inferred observation cuts. A censored onset is
not counted as a formation or burst event, and a censored terminus is not a
dissolution, but all known activity still contributes to snapshots, paths,
density, and observed exposure. `dyn_durations(censored = "include")` retains
that known follow-up; `censored = "exclude"` restricts summaries to raw spells
whose two boundaries are known. Observed fragments expose raw censor flags and
administrative observation-cut flags separately.

When the eligible vertex population itself changes, provide a separate tidy
activity table:

```r
dn <- dynet(
  interval_log,
  vertex_spells = data.frame(
    node = c("A", "A", "B"),
    start = c(0, 8, 2),
    end = c(5, 12, 10)
  )
)
as.data.frame(dn, what = "vertex_spells")
```

Positive vertex spells use `[start, end)` and points are exact. Overlapping or
adjacent declarations are unioned per named vertex; a point at an interval's
excluded terminus remains a separate active instant. Vertices not declared in
the table remain statically eligible, and names appearing only in the activity
table join the fixed vertex universe. Snapshot verbs independently take the
any-time union of vertex activity and edge activity over a positive window,
then remove edges whose endpoints are not eligible. A point snapshot instead
evaluates vertices and edges together at the exact time. Graph denominators
and censuses use only the eligible population; snapshot centrality retains the
fixed node rows and reports `NA` for inactive vertices, while eligible isolates
keep the ordinary static-kernel value. `dyn_snapshots()` stays edge-only, so it
does not fabricate rows for eligible isolates. Raw edge and vertex tables are
never clipped or rewritten. Temporal paths use the same declarations as
traversal gates: the named source or backward target must be active at the
query anchor, and every hop requires active endpoints. Waiting after a valid
anchor may cross an inactive period. A positive-duration interval traversal
requires both endpoints throughout the traversal; a delayed point contact
requires both endpoints at its trigger and the receiver again at completion.
Activity may split the feasible times of a contact without multiplying path
identity or counts. Whole-window risk sets use a separate integrated contract.

Whole-window temporal density integrates occupied pair-time over the exact
eligible pair-time risk set. Thus a period with two eligible vertices and a
period with four eligible vertices contribute different numbers of relational
opportunities; Dynet integrates those opportunities before dividing. Exact
contacts, exact vertex appearances, and observation gaps contribute no duration,
while duplicates, weights, loops, and overlapping session labels cannot
multiply exposure.

`dyn_metrics()` exposes that exact ledger inside every reporting window. Use
`temporal_density` for occupancy over all eligible pair-time and
`observed_pair_density` to condition the denominator on pairs with valid
evidence anywhere in the stored history. The matching `onset_intensity` and
`observed_pair_onset_intensity` selectors count known raw spell starts per unit
of those two opportunity clocks. A point contact adds an onset but no duration;
an onset-censored start does not count. The existing `density` selector remains
the any-time snapshot density, so it can intentionally differ from integrated
occupancy in a positive window.

The threaded format is worth naming explicitly. Forum and chat data carry a
timestamp and no end, so the duration of a tie has to be derived. Dynet applies
the rule from Saqr and Nouri (2020): a post is active from the moment it appears
until the last post in the same thread, so a message that provoked a long
argument stays live longer than one that fell flat. Deriving that by hand takes
a grouped mutate before you can build anything; here it is one argument.

## Editing without breaking time

Dynet objects are immutable: editing returns a rebuilt object and leaves the
source unchanged. Add isolates before referring to them as tie endpoints, then
add or remove temporal identities by name and time:

```r
dn2 <- add_nodes(dn, data.frame(name = "New student", role = "student"))
dn2 <- add_ties(dn2, data.frame(
  from = "Ana", to = "New student", start = 4, end = 6
))
dn2 <- remove_ties(dn2, from = "Ana", to = "New student", start = 4)
dn2 <- remove_nodes(dn2, "New student")
```

`add_arcs()` and `remove_arcs()` are directed-only aliases. Every mutation
rebuilds the canonical spell identities and cograph projection together;
cograph's static setters should be used only on a flattened cograph copy, not
to edit a temporal Dynet object.

The rest of the temporal state is editable by the same immutable contract:

```r
dn2 <- update_nodes(dn2, data.frame(name = "Ana", role = "facilitator"))
dn2 <- rename_nodes(dn2, c(Ana = "Ana S."))
dn2 <- update_ties(dn2, 1, data.frame(kind = "reply", weight = 2))
dn2 <- set_vertex_spells(dn2, activity_table)
dn2 <- add_vertex_spells(dn2, new_activity)
dn2 <- set_observations(dn2, data = observed_periods)
dn2 <- set_tie_sessions(dn2, session_labels)
dn2 <- rename_sessions(dn2, c(old = "new"))

# An edge-attribute-induced temporal subgraph
course <- induce_subgraph(
  dn2, ties = as.data.frame(dn2)$course_group == "course_1"
)
```

`update_vertex_spells()` and `remove_vertex_spells()` complete vertex-activity
editing; `clear_observations()` restores continuous implicit observation.
Overlapping activity or observation spells are canonicalized after every edit.

Existing `networkDynamic` objects can enter through `as_dynet()`, including
their activity spells, semantic vertex names, observation support, weights,
and compatible static attributes. Collapse any range back to a static cograph
network with duration, count, and weight summaries:

```r
dn <- as_dynet(readRDS("legacy-network.rds"))
flat <- collapse_network(dn, start = 0, end = 10,
                         weight = "union_duration")
cograph::splot(flat)
```

## Measuring

```r
dn <- dynet(school_contacts)

dyn_centrality(dn, measure = "degree")
dyn_centrality(dn, measure = c("degree", "betweenness"))
dyn_centrality(dn, measure = "closeness", scope = "temporal")

dyn_metrics(dn, measure = c("density", "reciprocity", "transitivity"))
dyn_metrics(dn, measure = c("degree_mean", "concurrent_share", "two_paths"))
dyn_metrics(dn, measure = c("temporal_density", "onset_intensity"))
dyn_events(dn)
dyn_events(dn, measure = "formation_fraction", start = 1, end = 1,
           window = 0)
dyn_durations(dn)
dyn_durations(dn, unit = "vertex_activity")
dyn_durations(dn, unit = "vertex_spell")
dyn_durations(dn, unit = "node_ties", mode = "all")
dyn_burstiness(dn)
dyn_paths(dn, from = "Ana")
path_network(dyn_paths(dn, from = "Ana"))
plot_path_timeline(dyn_paths(dn, from = "Ana"))
plot_path_trajectories(dyn_paths(dn, from = "Ana"),
                       measure = "frequency", orientation = "vertical")
dyn_reachability(dn)
dyn_pshifts(dn)
dyn_mixing(forum, attribute = "role")
dyn_snapshots(dn, at = 3)
```

`dyn_pshifts()` converts uncensored observed raw spell onsets into Gibson's
thirteen consecutive-turn participation-shift classes. It returns fixed,
typed totals by default; `output = "cumulative"` exposes the running state.
Use `sessions = "separate"` to retain session labels or
`group_events = "none"` to keep simultaneous recipients as dyads.

Lightweight structural descriptives stay inside `dyn_metrics()`. Degree
summaries, concurrent-node counts and shares, directed in/out 2-stars, and
two-paths use the same endpoint-induced snapshot semantics as density and the
existing dyad census; no ERGM package or formula interface is required.

Duration units stay explicit: pair summaries and raw edge spells use `pair`
and `spell`, while fixed-universe vertex-presence summaries and canonical V01
activity components use `vertex_activity` and `vertex_spell`. Vertex `total`
sums retained component durations; `union` measures binary vertex-time once.
Wholly undeclared vertices are represented by one measurement-only implicit
always-active component over observed support.

Node-tie duration keeps multiplicity and exposure separate. `events` and
`total` count/sum incident raw-spell endpoint stubs (so a loop contributes once
to each directed margin), while `union` measures the calendar time with at
least one qualifying incident tie. Out, in, and all modes never silently mix
these two quantities.

Raw formation counts and formation transitions are deliberately different.
`formation` counts known raw spell starts, including point contacts and
redundant starts on an already-active pair. `formation_fraction` instead asks,
at one exact time, what share of two-sided eligible pairs that were inactive
immediately before the whole timestamp batch became active immediately after.
Duplicate, overlapping, and adjacent spells are binary-unioned; points do not
change persistent state; observation or vertex entry/exit cannot fabricate a
transition. Use `window = 0`; positive-window turnover rates are separate
quantities.

`dissolution_fraction` is the dual exact-time quantity: confirmed binary
active-to-inactive pair-union transitions divided by all two-sided eligible
pairs active immediately before the complete timestamp batch. A positive raw
spell ending at the timestamp with a known terminus confirms the transition;
duplicate, overlapping, adjacent, and tied rows are unioned, so raw terminus
counts are not the numerator. Stable active pairs remain in the denominator,
zero active risk is `NA`, and positive risk without a confirmed end is zero.
Points, loops, weights, onset censoring, observation/activity boundaries, and
all-censored endings do not create confirmed transitions. Use
`dyn_events(dn, "dissolution_fraction", start = t, end = t, window = 0)`;
positive-width dissolution rates are reserved for T04.

`formation_rate` is the positive-window version of the formation transition:
its numerator sums confirmed binary pair formations at included timestamp
batches, while its denominator is exact integrated inactive eligible
nonloop pair-time across observation/activity/edge change cells. It is not a
raw-onset count or an average of instantaneous fractions. Zero exposure is
`NA`, positive exposure with no confirmed formation is zero, and the unit is
inverse network time. Use
`dyn_events(dn, "formation_rate", start = lo, end = hi, window = hi - lo)`;
instantaneous formation fractions remain the `window = 0` quantity.

`dissolution_rate` is the active-risk dual: confirmed binary pair dissolutions
per exact integrated active eligible pair-time over a positive window. Known
right-censored termini retain exposure but do not confirm an event; zero active
exposure is `NA`, while positive exposure without a confirmed dissolution is
zero. It is an inverse-time rate, not a raw terminus intensity or spell-time
sum. T03 and T04 can be requested together at positive width; instant
dissolution fractions remain the `window = 0` quantity.

`dyn_paths()` selects shortest-foremost journeys: earliest completion first,
then the fewest hops. Its compact endpoint table reports the exact `n_paths`
over canonical contact sequences; the steps accessor adds endpoint-local
`path_id` rows when tied routes are expanded. `plot_path_trajectories()` draws
those routes as a counted prefix tree, repeating a vertex when it occurs under
a different temporal history; it supports top-down and left-to-right layouts.

`dyn_burstiness()` treats each raw spell onset as one event at each distinct
incident vertex. It uses population gap dispersion and lag-one Pearson memory;
bounded sessions pool only within-session gaps and never bridge session walls.

`dyn_mixing()` reports raw active binary-dyad counts: ordered group cells for
directed networks and one unordered triangle for undirected networks. Repeated
spells and weights do not multiply a dyad; explicitly retained loops count
once, and missing group values remain an explicit collision-safe level.

Temporal closeness is inverse mean forward latency over reachable nonself
vertices. Immediate contacts are included: an all-zero reachable family has
infinite closeness, while a source reaching nobody has value zero. Explicit
`start` and `end` bounds, traversal duration, and session walls use the same
contract as temporal paths.

Temporal betweenness distributes each reachable ordered source-target pair's
dependency over every canonical shortest-foremost journey. It reports the raw
sum: tied routes and tied winning sessions split one pair's credit exactly,
and source/target endpoints receive none. Undirected contacts still use ordered
pairs because chronological reach need not be symmetric.

Ask for several measures in one call and they arrive stacked in one frame with
a `measure` column. Every result prints, summarises and plots:

```r
deg <- dyn_centrality(dn, measure = "degree")

summary(deg)                        # one row per vertex, with the peak time
summary(deg, by = "time")           # one row per time point
as.data.frame(deg)                  # the plain long frame
as.data.frame(deg, layout = "wide") # vertices by time, for export
plot(deg, top = 5)
```

### Snapshot scope and temporal scope

`scope = "snapshot"` measures the network as it stands in each bin, giving a
trajectory of ordinary centrality. `scope = "temporal"` measures the vertex
against time-respecting paths across the whole window. The second has no static
counterpart: it cannot travel backwards in time, so it is never inflated the way
a flattened network is. Explicit vertex activity gates these temporal paths;
an inactive source has zero temporal reach and closeness, while fixed node rows
and fixed risk-set denominators are retained.

### When the network is measured

Four arguments decide it, on every verb that returns a time series
(`dyn_centrality`, `dyn_metrics`, `dyn_events`, `dyn_mixing`, `dyn_snapshots`):

| argument | meaning | `tsna::tSnaStats()` |
|---|---|---|
| `start`, `end` | first and last measurement | `start`, `end` |
| `step` | how often to measure | `time.interval` |
| `window` | how much time each measurement covers | `aggregate.dur` |

`step` and `window` are separate on purpose, and that is the whole point. A
measurement every day covering the last seven days is a **rolling window**:

```r
dyn_metrics(dn, measure = "density", step = 1, window = 7)
```

Setting them equal partitions the period into disjoint bins, which is the
default. Setting `window = 0` samples the network at each point in time — the
convention `tsna` uses with `aggregate.dur = 0`. A positive window is the
default because point sampling silently drops any edge that begins and ends
between two sample points, a real loss on bursty data.

`start` and `end` default to the observed range, and a network built from dates
may be addressed with dates:

```r
dyn_metrics(dn, measure = "density",
            start = as.Date("2024-09-01"), end = as.Date("2024-12-01"),
            step = 7, window = 28)
```

One convention to know: on the **default** grid the final window is closed on
its right edge, so an event landing exactly on the last observed instant is
counted rather than dropped. A grid whose `end` you supplied is taken
literally, as `tsna` does — which is what makes a truncated range an exact
subset of the full series.

### What can be measured

`dyn_metrics()` covers the graph level and `dyn_centrality()` the vertex level.
Together they cover the core graph and vertex statistics exposed by
`tsna::tSnaStats()`, including directed binary indegree prestige before sender
normalization, after sender-row normalization, and after full row-column
balancing. The remaining prestige definitions are being added one calibrated
definition at a time, and
`load` follows Goh's relay-only definition rather than `sna::loadcent()`, which
also credits path endpoints.

| graph level | |
|---|---|
| structure | `density`, `edges`, `active_nodes`, `isolates`, `components`, `components_strong`, `largest_component` |
| temporal exposure | `temporal_density`, `observed_pair_density`, `onset_intensity`, `observed_pair_onset_intensity` |
| cohesion | `transitivity`, `reciprocity`, `assortativity`, `mean_distance`, `diameter` |
| censuses | `mutual`, `asymmetric`, `null`, `triads` |
| centralisation | `centralization_degree`, `centralization_betweenness`, `centralization_closeness` |
| Krackhardt | `connectedness`, `efficiency`, `hierarchy`, `lubness` |

| vertex level | |
|---|---|
| degree and prestige | `degree`, `strength`, `coreness`, `prestige` (`indegree`, `indegree.rownorm`, `indegree.rowcolnorm`, `domain`, `domain.proximity`, `eigenvector`, `eigenvector.rownorm`, `eigenvector.colnorm`, `eigenvector.rowcolnorm`) |
| distance family | `closeness`, `betweenness`, `harary`, `load` |
| spectral family | `eigenvector`, `pagerank`, `hub`, `authority`, `power` |
| flow and brokerage | `flow_betweenness`, `information`, `constraint` |

Two notes on cost and on well-posedness, because both bite in practice.
`flow_betweenness` solves a maximum flow for every ordered pair with and
without every vertex, so it is cubic in the vertex count times a flow solve --
fine on a classroom, slow on a cohort. Eigenvector centrality is unique when
the Perron eigenvalue has a one-dimensional eigenspace; strong connectivity is
a sufficient condition. Disconnected snapshots with equally dominant
components can admit more than one correct answer.

Row-column-normalized indegree prestige is defined only when every active
binary dyad belongs to a perfect matching of the full vertex matrix. Undefined
blocks are reported as `NA` with a classed warning. Every feasible score is
necessarily uniform (one raw, or `1/n` rescaled), so this option diagnoses a
balancing transform rather than ranking vertices.

Domain prestige counts the distinct other vertices that can reach each vertex
by any directed path in the active snapshot. It is incoming static transitive
reach, not chronology-aware temporal reach through the raw spells; loops never
credit self. `rescale = TRUE` turns the counts into shares of all reachable
ordered nonself pairs, with an all-zero block reported as `NaN`.

Domain-proximity prestige multiplies that incoming domain fraction by the
inverse mean directed hop distance of its members. Partial domains remain valid
and positive; unreachable vertices are excluded before distances are summed.
This follows the published Lin/Wasserman--Faust equation and deliberately
differs from `sna` 2.8's `0 * Inf` behavior on disconnected graphs.

Eigenvector prestige uses the incoming nonnegative Perron ray of the binary
snapshot. Raw scores have Euclidean norm one; rescaled scores sum to one.
Zero-radius or nonunique Perron blocks are `NA` with a classed warning instead
of an arbitrary eigensolver basis. Periodic cycles remain valid because their
real Perron ray is unique even when complex roots share its modulus.

Row-normalized eigenvector prestige first gives every active sender one unit
split equally across its distinct outgoing binary dyads, then solves the same
certified incoming Perron equation. Zero sender rows remain zero, retained
loops enter the row denominator, and session union occurs before normalization.
Use `prestige = "eigenvector.rownorm"`.

Column-normalized eigenvector prestige instead divides each nonzero binary
receiver column by its incoming-dyad count before the certified solve; zero
columns remain zero. When every vertex has positive indegree, every certified
score is necessarily uniform. Nonuniform defined rankings arise only when a
zero-indegree vertex is present. Use `prestige = "eigenvector.colnorm"`.

Row-column-normalized eigenvector prestige first requires total support, then
balances binary adjacency to doubly stochastic form, and only then certifies
the incoming Perron ray. Infeasible support, nonconvergent balancing, and a
nonunique balanced ray have distinct diagnostics. Every fully certified score
is necessarily uniform, so this is a transform/irreducibility diagnostic
rather than a ranking. Use `prestige = "eigenvector.rowcolnorm"`.

### Which edges count: `mode`

On a directed network, `mode` selects the direction for `degree`, `strength`,
`closeness` and `coreness`:

```r
dyn_centrality(dn, measure = "strength", mode = "in")   # in-strength
dyn_centrality(dn, measure = "degree", mode = "out")    # out-degree
```

The former `measure = "indegree"` and `measure = "outdegree"` spellings remain
available as deprecated aliases, so older scripts continue to run while moving
to the common `degree` plus `mode` interface.

`mode` applies to `degree`, `strength`, `closeness`, `coreness`, `harary` and
`eigenvector`. `"all"` is the default and counts both directions, so a
reciprocated pair counts twice — igraph's and cograph's convention. Measures
with a single directional definition (prestige, betweenness, PageRank, hub,
authority, constraint, load, information, flow betweenness) ignore it, as does an
undirected network.

## Drawing

**A `dynet` object is a cograph netobject.** Its class is
`c("dynet", "netobject", "cograph_network")` and it carries cograph's canonical
fields, so cograph renders it with no conversion:

```r
library(cograph)
splot(dn)                       # works directly
splot(dn, layout = "oval")      # every cograph argument applies
```

All node-link drawing in this package is cograph's. `plot()` adds the views
that are about *time* rather than about topology, and routes the topological
ones to `splot()`:

```r
plot(dn)                          # edge spells over time          (ggplot)
plot(dn, type = "activity")       # formation and dissolution      (ggplot)
plot(dn, type = "proximity")      # composite, see below           (cograph)

plot(dn, type = "network")        # the flattened network          (cograph)
plot(dn, type = "network", at = 13)  # one time bin                (cograph)
plot(dn, type = "snapshots")      # small multiples, shared layout (cograph)
plot_path_trajectories(
  dyn_paths(dn, from = "Ana"), orientation = "vertical"
)                                  # counted temporal prefix tree   (ggplot)
```

### The proximity timeline

One composite figure rather than a line chart. Each time bin is reduced to one
dimension by classical scaling, so vertices that are interacting sit near one
another; the lines are then joined through time, and clusters appear as bands
travelling together.

```r
plot(dn, type = "proximity")
plot(dn, type = "proximity", measure = "betweenness", phases = 4)
plot(dn, type = "proximity", networks = FALSE, highlight = c("Ana", "Ben"))
```

Reading it:

- **Line thickness** follows a node-level measure — degree by default, any
  measure `dyn_centrality()` accepts. A vertex that is merely present looks
  different from one that is busy.
- **Vertical marks** are times at which edges formed, shaded by how many.
- **Names sit at the right-hand end** of each line instead of in a legend, so
  no distinction rests on colour alone even when the palette repeats.
- **The strip beneath** is the phase each network panel covers — the network's
  own sessions when it has them, otherwise equal thirds.
- **The panels beneath that** are one `cograph::splot()` per phase, sharing the
  line colours, so a band in the timeline can be traced to a group in the
  network.

**The line never leaves the corridor its measurements define.** The network is
measured at 120 overlapping slices by default. Corners are rounded by *cutting*
them — Chaikin's algorithm, where every point produced is a convex combination
of measured points — so the curve flows without ever overshooting a
measurement.

That is the difference from interpolating a spline through the same points. A
spline is free to travel anywhere between two knots: on evenly spaced slices an
`fmm` or `natural` spline overshoots the pair it is joining by around one
standard deviation, and even a monotone Hermite spline by about half of one. It
draws the network passing through places no slice ever put it. Corner-cutting
provably cannot, and there is a test asserting so.

Set `flow = 0` for sharp joints, or a larger number to round harder.

Each slice is standardised before the lines are drawn, so a vertical distance
means the same thing at one time as at another. Slice width defaults to a sixth
of the observation window, because scaling is only meaningful on a slice whose
network is connected — measured over one narrow bin most vertices are isolated
and their placement is arbitrary. `slices` and `window` are both arguments:
narrow the window to resolve more, at the cost of a noisier picture.

The figure needs roughly nine by six inches; below that it declines to draw and
says so.

Colour comes from a **`"dynet"` theme registered in cograph's theme registry**,
so it shows up in `cograph::list_themes()` and can be asked for by name from
any cograph call:

```r
cograph::list_themes()          # ... "nature", "dynet"
splot(dn, theme = "dynet")      # from a bare cograph call
plot(dn, type = "network", theme = "dark")   # or ask for another
```

Anything passed through `...` reaches `splot()` and overrides Dynet's defaults
— the same delegation contract `lagdynamics::plot_transitions()` uses.

Two things sit outside the theme and have to, which is worth knowing if you
edit this:

- `splot()` treats a directed netobject with no `$method` as a *transition*
  network and applies its TNA look — a per-state colour ramp and a number on
  every edge. Right for a transition matrix, wrong here where an edge weight
  is a count of meetings. The TNA block also runs *before* the theme block and
  fills `node_fill`, which the theme block then declines to overwrite, so a
  theme alone cannot undo it. Hence `tna_styling = FALSE`.
- A theme holds one `node_fill`. Colouring vertices by partition needs a
  vector, so that is passed separately — and only when a partition exists, so
  an unpartitioned network still takes its fill from whichever theme you ask
  for. The colours are Okabe–Ito; cograph's own `palette_colorblind()` is an
  interpolated ramp, not the Okabe–Ito set.

Set the vertex partition once at construction and cograph picks it up
everywhere:

```r
forum <- dynet(forum_posts, thread = "thread", nodes = forum_people,
               groups = "role")
splot(forum)                      # coloured by role, no further argument
```

### Palettes

`palette` is an argument on every plot, and you can override it with anything:

```r
plot(dn, type = "network")                          # "okabe", the default
plot(dn, type = "proximity", palette = "extended")  # ~12 distinct
plot(dn, type = "proximity", palette = "many")      # one per vertex, any n
plot(dn, type = "network",  palette = c("#D55E00", "#0072B2"))   # your own
plot(dn, type = "network",  palette = function(n) hcl(seq(0, 340, length = n), 80, 60))
```

All three built-ins begin with Okabe–Ito, so a small network looks the same
whichever you pick, and they are deterministic — no `sample()`, no seed, the
same network gets the same colours every run.

The choice is a measurable trade, not a matter of taste. Minimum distance
between any two colours in CIE Lab, where 2.3 is the just-noticeable
difference and 10 a comfortable categorical gap:

| palette | n | min ΔE | under deuteranopia |
|---|---|---|---|
| `"okabe"` | 9 | 26.4 | **7.3** |
| `"extended"` | 20 | 13.5 | 2.4 |
| `"many"` | 60 | **23.6** | 1.2 |
| evenly spaced hue ramp | 60 | 4.7 | 0.0 |
| every qualitative ColorBrewer palette concatenated | 60 | **0.4** | 0.4 |

Two things worth knowing before reaching for `"many"`:

- **Hue alone collapses under colour blindness.** An evenly spaced hue ramp is
  already below the just-noticeable difference at eight colours. Okabe–Ito
  holds because it varies *lightness*, not only hue.
- **`"many"` is not colour-blind safe and cannot be.** Sixty categories do not
  fit in the space dichromatic vision leaves. It is for grouping and
  decoration; the labels do the identifying. Beyond about twelve colours,
  identification is a matching-and-memory limit rather than a perceptual one,
  and no palette fixes it — use `highlight`, or set a partition with
  `dynet(groups = )` so colour is back to a handful of categories.

Labels take their colour from the fill — black or white, whichever has the
higher contrast ratio — so a vertex that lands on Okabe–Ito's ninth colour
(black) still has a readable name. Pass `label_color` to override.

Nothing depends on colour alone: the
network views pair colour with shape, the ggplot views with a line type, and
the proximity timeline names every line at its right-hand end.

Line type is deliberately *not* the second channel in the proximity view. Base
graphics scales dash length by line width, so a dashed line disintegrates
exactly where it is thinnest — and thin there means low activity, not missing
data. Solid lines plus direct labels say the true thing.

## What it depends on

`cograph` for rendering, `ggplot2` for the time-series views. Nothing else.

Every metric — geodesics, Brandes betweenness, PageRank, HITS, k-cores, Burt's
constraint, the dyad and triad censuses — is base R matrix algebra, so
measurement works on a machine with no graph package installed. `igraph`,
`sna`, `tsna` and `networkDynamic` appear only in `Suggests`, where the test
suite uses them to check the numbers.

## How the numbers were checked

All 78 kernel comparisons against `igraph` and `sna` agree, across directed and
undirected graphs at three sizes. Earliest-arrival times agree with
`tsna::tPath` on twenty source-network combinations. Two conventions differ
deliberately and are documented where they are implemented:

- **Closeness** uses the reachable-set normalisation from `igraph`.
  `sna::closeness()` sums distance over unreachable vertices too, so it returns
  zero for every vertex as soon as the graph is disconnected — and every
  snapshot of a temporal network is disconnected.
- **Isolates** report a closeness of zero rather than `NaN`, so that averaging a
  series does not propagate a missing value.

## References

Holme, P., & Saramäki, J. (2012). Temporal networks. *Physics Reports*, 519(3),
97–125.

Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora, V.
(2013). Graph metrics for temporal networks. In *Temporal Networks* (pp. 15–40).
Springer.

Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis to
understand and improve collaborative learning. *Proceedings of the Tenth
International Conference on Learning Analytics & Knowledge*, 314–319.

Saqr, M. (2024). Temporal network analysis: Introduction, methods and analysis
with R. In M. Saqr & S. López-Pernas (Eds.), *Learning Analytics Methods and
Tutorials*. Springer.
