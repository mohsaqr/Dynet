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
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  traversal_time = 0,
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- from:

  Name of the vertex to start from.

- at:

  Forward source-availability time or backward arrival deadline.
  Defaults to the start of the observation window for forward paths and
  its end for backward paths. Date and date-time values use the
  network's time scale. It cannot be combined with `start` or `end`.

- direction:

  `"forward"` traces where the vertex can reach; `"backward"` traces who
  could have reached it.

- sessions:

  How to treat sessions, as in
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md).

- start, end:

  Inclusive lower and upper traversal-time bounds. Interval spells
  remain terminus-exclusive. When these are supplied, use them instead
  of `at`.

- traversal_time:

  Nonnegative duration charged for every hop, in the network's time
  unit. A calendar network also accepts a scalar `difftime`.

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
(whether that optimum itself is realized), `latency` (time taken from
the source), `n_hops`, and the exact count `n_paths`. Bounded mode adds
`path_session` and `n_best_sessions`; separate mode adds `session` and
`origin`. Use `as.data.frame(x, what = "steps")` for every reconstructed
optimal route; its endpoint-local `path_id` distinguishes tied atom
sequences.

## Details

A valid forward journey has distinct vertices, hop-entry times `x`, and
completion times `y = x + traversal_time`. The source is ready at
`start`, each later entry is no earlier than the preceding completion,
and final completion is at or before `end`. At zero duration, entry and
completion coincide and recover P01's nondecreasing traversal times. The
empty journey reaches the source at `start`. With `at`, that value
supplies `start` for forward paths or `end` for backward paths. Cycles
are unnecessary for reach and earliest arrival because deleting a
repeated-vertex section and waiting at that vertex preserves every later
hop.

`start` and `end` form a closed bound on the complete journey: entry may
equal `start` and completion may equal `end`. This does not close
interval activity on the right. At zero duration, an event or interval
onset at `end` is eligible while an interval terminating there cannot be
entered. With positive duration, no nonempty hop can both enter and
complete at `end`; `start = end` therefore leaves only the empty
journey.

Declared vertex activity gates traversal appearances. The forward source
must be active exactly at `start`, and the backward target exactly at
`end`; otherwise every fixed-universe row, including the anchor, is
unreachable. After a valid anchor, waiting may cross inactive periods. A
zero-duration hop requires both endpoints at its time. A
positive-duration interval hop requires both endpoints continuously on
the closed traversal from entry through completion. A delayed point
contact requires both endpoints at its trigger and the receiver again at
completion, but creates no continuous edge or tail occupancy. Several
activity-created timing domains of one canonical contact remain one path
atom and cannot multiply `n_paths`.

For backward paths, `arrival_time` is the latest-departure supremum for
a journey ending at the named target by the resolved `end`, and
`latency` is `end` minus that value. A supremum at an interval's
excluded terminus need not itself be an attainable departure.

With `sessions = "bounded"`, each endpoint is optimized across complete
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
minimized first and hop count second. Journey identity is the ordered
sequence of canonical oriented contacts. Duplicate points, overlapping
or touching interval segmentation, weights, and waiting schedules do not
multiply paths; genuinely recurrent contacts do. `n_paths` is exact
through `2^53`, after which a `dynet_path_overflow` condition is raised.
The empty journey has one path, an unreachable endpoint has zero, and an
unattained backward supremum has zero because it has no maximizing
journey.

## References

Kempe, D., Kleinberg, J., & Kumar, A. (2002). Connectivity and inference
problems for temporal networks. *Journal of Computer and System
Sciences*, 64(4), 820-842.

Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97-125.

Casteigts, A., Corsini, A., & Sarkar, W. (2024). Simple, strict, proper,
happy: A study of reachability in temporal graphs. *Theoretical Computer
Science*, 991, 114434.

## Examples

``` r
dn <- dynet(school_contacts)
paths(dn, from = "Ana")
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
summary(paths(dn, from = "Ana"))
#>          property   value
#> 1          source     Ana
#> 2       direction forward
#> 3       reachable      13
#> 4 reachable share       1
#> 5  median latency    7.51
#> 6     max latency   11.66
#> 7     median hops       2
#> 8        max hops       4
```
