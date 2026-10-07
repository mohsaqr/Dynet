# Time-respecting paths from a vertex

Follows every time-respecting path out of (or into) one vertex and
reports where it gets to, when, and through whom. A path may only use
edges whose timing runs forward, so unlike a path in a flattened network
it can never travel back in time.

The source vertex is named, not numbered. `paths(dn, from = "Ana")`
works; there is no vertex index to look up first.

At the default zero traversal duration, forward paths use nondecreasing
hop times, so relations active at the same instant may form a multi-hop
chain. Waiting is allowed. Interval spells are onset-inclusive and
terminus-exclusive; point events trigger at their exact timestamp
through a distinct event rule. A positive duration separates a hop's
trigger or entry from its completion, as detailed below. Reach and
arrival do not depend on edge-row order or duplicate spell rows.

## Usage

``` r
paths(
  dn,
  from,
  at = NULL,
  direction = c("forward", "backward"),
  criterion = c("foremost_then_shortest", "min_hops", "foremost", "fastest",
    "latest_departure", "shortest"),
  cost = c("hops", "weight"),
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  traversal_time = 0,
  max_states = 1e+05,
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- from:

  Name of the one vertex the search is anchored on: the source of a
  forward search, the target of a backward one.

- at:

  Forward source-availability time or backward arrival deadline. An
  explicit `at` is used exactly: a source that is not present at that
  instant reaches nothing. The default, `NULL`, lets the vertex supply
  its own anchor. A vertex with declared spells (see
  [`set_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/set_vertex_spells.md))
  starts at the first instant it is present inside the window, or at the
  last instant searching backward; a vertex with no declared spells
  starts at the window bound, which is `start` for a forward search and
  `end` for a backward one, each defaulting in turn to the matching end
  of the observation window. Date and date-time values use the network's
  time scale. It cannot be combined with `start` or `end`.

- direction:

  `"forward"` traces where the vertex can reach; `"backward"` traces who
  could have reached it.

- criterion:

  Which optimisation problem to solve. `"foremost_then_shortest"` (the
  default, and what every earlier release computed) takes the earliest
  arrival and, among journeys attaining it, the fewest hops.
  `"min_hops"` takes the fewest time-respecting contacts and, among
  those, the earliest arrival. `"foremost"` is pure earliest arrival
  with no tie-break: the whole family of vertex-simple journeys
  attaining it, so `n_paths` counts every one and `n_hops` is `NA` when
  they differ in length. Counting foremost paths is \#P-hard in general
  (Buss et al., 2024), so the family is enumerated exactly, keeping only
  prefixes that can still attain some endpoint's optimum; the search
  raises `dynet_path_family_too_large` if it exceeds `max_states`.
  `"fastest"` minimises journey duration, arrival minus departure, the
  one criterion that measures transit rather than clock position; among
  equally fast journeys it takes the earliest departure, then the fewest
  hops. Its minimum can be an infimum with no minimising journey (a
  departure that approaches an interval's excluded terminus), reported
  with `attained = FALSE` and an empty family. `"latest_departure"` asks
  the planning question: leaving `from`, how late can one set off and
  still reach each vertex by `end`? It is a forward query and needs a
  finite deadline, so `end` (or `at`) must be given unless the network
  has an explicit observation window; combining it with
  `direction = "backward"` is an error, because the target-pivoted
  latest departure is what a backward query already reports. These are
  different problems and can select different journeys; only
  reachability is identical across criteria.

- cost:

  For `criterion = "shortest"` only: what a contact costs. `"hops"` (the
  default) charges one per contact, which is exactly
  `criterion = "min_hops"`. `"weight"` charges each contact its tie
  weight, so the shortest journey is the one with the least summed
  weight, and the table gains a `path_cost` column holding that sum.
  Every weight must be positive and finite (`dynet_bad_weight`
  otherwise): a zero-cost cycle would re-admit non-simple journeys. The
  weight is a cost only; when a contact can be entered, and how long a
  hop takes, is unchanged. Two overlapping spells of one pair are one
  contact, at the weight of the earlier spell.

- sessions:

  How to treat sessions, as in
  [`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md).

- start, end:

  Inclusive lower and upper traversal-time bounds. Interval spells
  remain terminus-exclusive. When these are supplied, use them instead
  of `at`.

- traversal_time:

  Nonnegative duration charged for every hop, in the network's time
  unit. A calendar network also accepts a scalar `difftime`.

- max_states:

  For `criterion = "foremost"` only: the largest number of search states
  one source may expand before the family is declared too large.
  Supplying it with any other criterion is an error.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn, so
  `plot = TRUE` saves the wrapping
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call without
  changing what comes back. Use
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on the result
  when the figure needs arguments of its own.

## Value

An object of class `"dynet_paths"`: a tidy data frame with one row per
vertex and columns `node`, `reachable`, `arrival_time`, `attained`
(whether that optimum itself is realised), `latency` (elapsed time
between the origin and `arrival_time`, in either direction), `n_hops`,
and the exact count `n_paths`. Under `criterion = "latest_departure"` a
`departure_time` column follows `arrival_time`, holding the latest
departure supremum from `from`, and a `duration` column; `arrival_time`,
`n_hops` and `n_paths` then describe the journeys that depart exactly
then (earliest arrival, then fewest hops, within that family). Under
`criterion = "fastest"` the same two columns hold the fastest journey's
departure and its duration. In both cases an unattained optimum keeps
its limiting departure, arrival and duration but has `n_hops = NA` and
`n_paths = 0`. Under `criterion = "shortest"` a `path_cost` column
follows `n_paths`: the summed cost of the cheapest journey, `n_hops` is
the fewest hops among the cheapest journeys (`NA` when they differ), and
`arrival_time` and `n_paths` describe the cheapest journeys that arrive
earliest. Bounded mode adds `path_session` and `n_best_sessions`;
separate mode adds `session` and `origin`, one complete vertex block per
session. Use `as.data.frame(x, what = "steps")` for every reconstructed
optimal route: one row per vertex visited, with `endpoint`, `path_id`
(endpoint-local, distinguishing tied atom sequences), `path_session`,
`step`, `node`, `time` and `attained`, preceded by `session` in separate
mode.

## Details

A valid forward journey has distinct vertices, hop-entry times `x`, and
completion times `y = x + traversal_time`. The source is ready at the
resolved origin, each later entry is no earlier than the preceding
completion, and final completion is at or before `end`. At zero
duration, entry and completion coincide, recovering the nondecreasing
hop times described above. The empty journey reaches the source at the
origin. With `at`, that value is both the origin and the window bound:
`start` for forward paths or `end` for backward paths. Cycles are
unnecessary for reach and earliest arrival because deleting a
repeated-vertex section and waiting at that vertex preserves every later
hop.

The origin is anchored at the source's own presence. Without `at`, a
vertex with declared spells starts at the first instant it is present
inside the window, or at the last instant when searching backward, so a
vertex that enters the network late is never scored from a time before
it existed; a vertex with no declared spells starts at the window bound.
A vertex that is never present inside the window has no valid anchor, so
every row of its result, the source row included, is unreachable. The
resolved origin is reported in the printed header; under
`sessions = "separate"`, where every session resolves its own, it is
reported in the `origin` column instead.

`start` and `end` form a closed bound on the complete journey: entry may
equal `start` and completion may equal `end`. This does not close
interval activity on the right. At zero duration, an event or interval
onset at `end` is eligible while an interval terminating there cannot be
entered. With positive duration, no nonempty hop can both enter and
complete at `end`; `start = end` therefore leaves only the empty
journey.

Declared vertex activity gates traversal appearances. The anchor must be
valid: the forward source must be active exactly at the resolved origin,
and the backward target either active there or leaving exactly there,
since a spell's terminus is the last instant that vertex exists even
though presence is half-open. An invalid anchor – which an explicit `at`
outside the source's own spells produces – leaves every fixed-universe
row, including the anchor row itself, unreachable. After a valid anchor,
waiting may cross inactive periods. A zero-duration hop requires both
endpoints at its time. A positive-duration interval hop requires both
endpoints continuously on the closed traversal from entry through
completion. A delayed point contact requires both endpoints at its
trigger and the receiver again at completion, but creates no continuous
edge or tail occupancy. Several activity-created timing domains of one
canonical contact remain one path atom and cannot multiply `n_paths`.

For backward paths, `arrival_time` is the latest-departure supremum for
a journey ending at the named target by the resolved `end`, and
`latency` is `end` minus that value. A supremum at an interval's
excluded terminus need not itself be an attainable departure. Such an
endpoint is still reachable and still reports its route family:
`n_hops`, `n_paths` and the steps of the routes that approach the
supremum are those of the family, and `attained = FALSE` records that
the instant itself is not realised.

A latest-departure query is solved by time reversal: the latest
departure from `from` into a vertex `z` by `end` is the label a backward
search rooted at `z` assigns to `from`, so one backward search per
vertex answers it with every session, activity and attainment rule
inherited unchanged. In particular each target inherits the backward
anchor rule and must be active at `end`; the empty journey departs from
`from` at `end` itself. The `optimality` attribute records `"maximum"`
for this criterion and `"minimum"` for the others, and `deadline`
records the resolved `end`.

A shortest query with weight costs is solved by settling vertex
appearances in order of accumulated cost (Wu et al., 2016): every cost
is positive, so the cheapest open appearance is final when it is settled
and every predecessor of an appearance is settled before it, which is
what makes the journey count exact. Two journeys tie when their summed
weights agree within a relative tolerance of
`sqrt(.Machine$double.eps)`.

A fastest query is a sweep over candidate departures: for a fixed
source-ready time the problem is prefix-optimal again, so the minimum
duration is the minimum over departures `d` of the earliest arrival from
`d` minus `d`. The candidates are the atom-domain endpoints (shifted by
whole multiples of `traversal_time`), each taken exactly and from below,
at which the source can depart; one forward search runs per candidate.

With `sessions = "bounded"`, each endpoint is optimised across complete
session-specific searches. A unique winner is named in `path_session`;
ties leave it missing and are counted in `n_best_sessions`. No merged
predecessor tree is exposed. The steps accessor retains a complete route
from every tied best session, so each route stays inside one session.
With `sessions = "separate"`, every session contributes a complete
vertex block and resolves its own default origin. In the steps table,
`time` is the optimal search label at that route vertex. For backward
interval paths it can be an unattained supremum, as indicated by
`attained = FALSE`.

With positive `traversal_time`, an interval hop entered at `x` arrives
at `x + traversal_time` and must fit within continuous activity for that
pair; overlapping or touching interval spells form one component.
Completion exactly at the component terminus is allowed. A point event
triggers at its timestamp and arrives after the same duration; it does
not represent continued edge activity. The query `end` bounds
completion, not only entry.

Optimal forward journeys are shortest foremost: final completion is
minimised first (foremost) and hop count second (shortest). Backward
journeys mirror it, maximising the departure time first and minimising
hop count second. There is no criterion argument: this is the only
criterion `paths()` offers, and it is recorded on the result as
`"foremost_then_shortest"`. A fastest journey, which minimises elapsed
time rather than arrival time, is a different optimum and is not
computed here. Journey identity is the ordered sequence of canonical
oriented contacts. Duplicate points, overlapping or touching interval
segmentation, weights, and waiting schedules do not multiply paths;
genuinely recurrent contacts do. `n_paths` is exact through `2^53`,
after which a `dynet_path_overflow` condition is raised. The empty
journey has one path and an unreachable endpoint has none.

Failures are classed. An unknown `from` raises `dynet_unknown_vertex`; a
`from` that is not one name, a negative `traversal_time`, combining `at`
with `start` or `end`, or a window that cannot hold a journey, raises
`dynet_bad_input`; a window disjoint from explicit observation raises
`dynet_outside_observation`; a count beyond `2^53` raises
`dynet_path_overflow`; and expanding more than a million routes through
`as.data.frame(x, what = "steps")` raises
`dynet_path_expansion_too_large`, which the compact `n_paths` column
answers instead.

## References

Kempe, D., Kleinberg, J., & Kumar, A. (2002). Connectivity and inference
problems for temporal networks. *Journal of Computer and System
Sciences*, 64(4), 820-842.

Bui-Xuan, B., Ferreira, A., & Jarry, A. (2003). Computing shortest,
fastest, and foremost journeys in dynamic networks. *International
Journal of Foundations of Computer Science*, 14(2), 267-285.

Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97-125.

Casteigts, A., Corsini, A., & Sarkar, W. (2024). Simple, strict, proper,
happy: A study of reachability in temporal graphs. *Theoretical Computer
Science*, 991, 114434.

Buss, S., Molter, H., Niedermeier, R., & Rymar, M. (2024). Algorithmic
aspects of temporal betweenness. *Network Science*, 12(2), 160-188.

Wu, H., Cheng, J., Huang, S., Ke, Y., Lu, Y., & Xu, Y. (2014). Path
problems in temporal graphs. *Proceedings of the VLDB Endowment*, 7(9),
721-732.

Bui-Xuan, B., Ferreira, A., & Jarry, A. (2003). Computing shortest,
fastest, and foremost journeys in dynamic networks. *International
Journal of Foundations of Computer Science*, 14(2), 267-285.

## Examples

``` r
dn <- dynet(school_contacts)
paths(dn, from = "Ana", criterion = "latest_departure", end = 10)
#> # Latest departures from ‘Ana’ reaching each vertex by t = 10
#> # reaches 12 of 13 other vertices | time in step
#>   node reachable arrival_time departure_time duration attained latency n_hops
#>    Ana      TRUE        10.00          10.00     0.00     TRUE   10.00      0
#>    Ben      TRUE         9.59           7.07     2.52    FALSE    9.59     NA
#>   Cara      TRUE         6.77           6.77     0.00    FALSE    6.77     NA
#>    Dan      TRUE         9.49           9.13     0.36    FALSE    9.49     NA
#>    Eve     FALSE           NA             NA       NA    FALSE      NA     NA
#>   Finn      TRUE         6.96           6.77     0.19    FALSE    6.96     NA
#>   Gita      TRUE         9.35           9.13     0.22    FALSE    9.35     NA
#>   Hugo      TRUE         9.93           9.13     0.80    FALSE    9.93     NA
#>   Iris      TRUE        10.00           6.77     3.23    FALSE   10.00     NA
#>  Jonas      TRUE         9.13           9.13     0.00    FALSE    9.13     NA
#>   Kira      TRUE         7.07           7.07     0.00    FALSE    7.07     NA
#>    Leo      TRUE         9.65           6.77     2.88    FALSE    9.65     NA
#>  n_paths
#>        1
#>        0
#>        0
#>        0
#>        0
#>        0
#>        0
#>        0
#>        0
#>        0
#>        0
#>        0
#> # 2 more rows. summary() aggregates them; plot() draws the tree.

# Every earliest-arrival journey, not only the shortest ones
few <- dynet(data.frame(from = c("A", "A", "B", "C"),
                        to = c("D", "B", "C", "D"),
                        time = c(4, 1, 2, 4)),
             format = "contact", directed = TRUE)
paths(few, from = "A", criterion = "foremost")
#> # Time-respecting paths from ‘A’, from t = 1
#> # reaches 3 of 3 other vertices | time in step
#>  node reachable arrival_time attained latency n_hops n_paths
#>     A      TRUE            1     TRUE       0      0       1
#>     B      TRUE            1     TRUE       0      1       1
#>     C      TRUE            2     TRUE       1      2       1
#>     D      TRUE            4     TRUE       3     NA       2
paths(few, from = "A", criterion = "fastest")
#> # Time-respecting paths from ‘A’, from t = 1
#> # reaches 3 of 3 other vertices | time in step
#>  node reachable arrival_time departure_time duration attained latency n_hops
#>     A      TRUE            1              1        0     TRUE       0      0
#>     B      TRUE            1              1        0     TRUE       0      1
#>     C      TRUE            2              1        1     TRUE       1      2
#>     D      TRUE            4              4        0     TRUE       3      1
#>  n_paths
#>        1
#>        1
#>        1
#>        1
routes <- paths(dn, from = "Ana")
routes
#> # Time-respecting paths from ‘Ana’, from t = 0
#> # reaches 13 of 13 other vertices | time in step
#>   node reachable arrival_time attained latency n_hops n_paths
#>    Ana      TRUE         0.00     TRUE    0.00      0       1
#>    Ben      TRUE         9.59     TRUE    9.59      3       3
#>   Cara      TRUE         6.67     TRUE    6.67      1       1
#>    Dan      TRUE         7.98     TRUE    7.98      4       1
#>    Eve      TRUE        11.66     TRUE   11.66      4       3
#>   Finn      TRUE         6.96     TRUE    6.96      2       1
#>   Gita      TRUE         6.36     TRUE    6.36      2       1
#>   Hugo      TRUE         7.98     TRUE    7.98      3       1
#>   Iris      TRUE        10.00     TRUE   10.00      3       1
#>  Jonas      TRUE         2.12     TRUE    2.12      1       1
#>   Kira      TRUE         6.12     TRUE    6.12      2       2
#>    Leo      TRUE         9.65     TRUE    9.65      3       1
#> # 2 more rows. summary() aggregates them; plot() draws the tree.
summary(routes)
#>          property   value
#> 1          source     Ana
#> 2       direction forward
#> 3       reachable      13
#> 4 reachable share       1
#> 5  median latency    7.51
#> 6     max latency   11.66
#> 7     median hops       2
#> 8        max hops       4
paths(dn, from = "Ana", start = 0, end = 10)
#> # Time-respecting paths from ‘Ana’, from t = 0
#> # reaches 12 of 13 other vertices | time in step
#>   node reachable arrival_time attained latency n_hops n_paths
#>    Ana      TRUE         0.00     TRUE    0.00      0       1
#>    Ben      TRUE         9.59     TRUE    9.59      3       3
#>   Cara      TRUE         6.67     TRUE    6.67      1       1
#>    Dan      TRUE         7.98     TRUE    7.98      4       1
#>    Eve     FALSE           NA    FALSE      NA     NA       0
#>   Finn      TRUE         6.96     TRUE    6.96      2       1
#>   Gita      TRUE         6.36     TRUE    6.36      2       1
#>   Hugo      TRUE         7.98     TRUE    7.98      3       1
#>   Iris      TRUE        10.00     TRUE   10.00      3       1
#>  Jonas      TRUE         2.12     TRUE    2.12      1       1
#>   Kira      TRUE         6.12     TRUE    6.12      2       2
#>    Leo      TRUE         9.65     TRUE    9.65      3       1
#> # 2 more rows. summary() aggregates them; plot() draws the tree.
paths(dn, from = "Ana", direction = "backward")
#> # Time-respecting paths into ‘Ana’, from t = 21.52
#> # reaches 13 of 13 other vertices | time in step
#>   node reachable arrival_time attained latency n_hops n_paths
#>    Ana      TRUE        21.52     TRUE    0.00      0       1
#>    Ben      TRUE        17.14    FALSE    4.38      2       1
#>   Cara      TRUE        20.33    FALSE    1.19      1       1
#>    Dan      TRUE        21.33    FALSE    0.19      1       1
#>    Eve      TRUE        15.73    FALSE    5.79      2       1
#>   Finn      TRUE        20.26    FALSE    1.26      2       1
#>   Gita      TRUE        16.76    FALSE    4.76      3       2
#>   Hugo      TRUE        19.80    FALSE    1.72      1       1
#>   Iris      TRUE        17.57    FALSE    3.95      3       1
#>  Jonas      TRUE        20.46    FALSE    1.06      2       1
#>   Kira      TRUE        16.86    FALSE    4.66      2       1
#>    Leo      TRUE        12.62    FALSE    8.90      2       1
#> # 2 more rows. summary() aggregates them; plot() draws the tree.
```
