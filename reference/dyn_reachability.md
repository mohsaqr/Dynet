# Reachability of every vertex

The number or share of other vertices each vertex can reach along
time-respecting paths, and the number or share that can reach it.
Reachability is the temporal replacement for component membership: in a
static network two vertices in the same component reach each other by
definition, whereas in a temporal network reach depends on whether the
timing lines up.

## Usage

``` r
dyn_reachability(
  dn,
  direction = c("both", "forward", "backward"),
  at = NULL,
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  traversal_time = 0,
  measure = "reach",
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- direction:

  `"both"` (the default, reporting each vertex's forward and backward
  reach side by side), `"forward"` or `"backward"`.

- at:

  Forward source-availability time or backward arrival deadline.
  Defaults to the beginning or end of each observed period,
  respectively. Date and date-time values use the network's time scale.
  It cannot be combined with `start` or `end`.

- sessions:

  How to treat sessions, as in
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md).

- start, end:

  Inclusive lower and upper traversal-time bounds. Interval spells
  remain terminus-exclusive.

- traversal_time:

  Nonnegative duration charged for every hop, in the network's time
  unit. A calendar network also accepts a scalar `difftime`.

- measure:

  One or both of `"reach"`, the proportion of other vertices, and
  `"reach_count"`, their number. The source vertex is excluded from
  both.

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

A `dynet_metric` at node level. Proportion measures are named
`forward_reach` and `backward_reach`; counts are named
`forward_reach_count` and `backward_reach_count`.

## Details

Reachability uses
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md)
traversal semantics: nondecreasing times, unlimited waiting, half-open
interval spells, and a separate exact timestamp rule for point events.
Positive `traversal_time` requires interval occupancy to finish within
continuous pair activity and delays a point-trigger arrival. Declared
vertex activity additionally requires an exact active query anchor and
active hop endpoints. Waiting after a valid anchor may cross vertex
inactivity; interval traversal requires both endpoints continuously
through completion, while a delayed point requires the receiver again at
completion. For backward reachability, the resolved `end` is a common
deadline and latest-departure suprema determine whether a vertex can
reach the target. The canonical `start` and `end` bounds apply one
closed traversal-time window to both forward and backward queries.

The source is excluded: a count is the number of distinct other vertices
in the reachable set, not the number of journeys. A proportion divides
that count by the full network size minus one. It is defined as zero for
a singleton network. In separate-session output the same full-network
denominator is retained in every session block.

In separate-session output, a session entirely outside a one-sided bound
contributes zero-reach rows rather than aborting the complete result.
Its missing implicit bound is clamped to the supplied bound, producing
the empty journey at that boundary and no eligible hop.

## Examples

``` r
# Reachability searches every ordered pair, so the example uses a small
# inline network to stay fast. The verb takes any `dynet`.
dn <- dynet(data.frame(
  from  = c("A", "B", "C", "A"),
  to    = c("B", "C", "D", "D"),
  start = c(0, 1, 2, 3),
  end   = c(1, 2, 3, 4)
))
dyn_reachability(dn)
#> # Reachability (node-level)
#> # 4 vertices | time in step
#> # measures: forward_reach, backward_reach
#> # share of other vertices joined by a time-respecting path
#>  node        measure     value
#>     A  forward_reach 1.0000000
#>     B  forward_reach 0.6666667
#>     C  forward_reach 0.3333333
#>     D  forward_reach 0.0000000
#>     A backward_reach 0.0000000
#>     B backward_reach 0.3333333
#>     C backward_reach 0.6666667
#>     D backward_reach 1.0000000
dyn_reachability(dn, direction = "forward")
#> # Reachability (node-level)
#> # 4 vertices | time in step
#> # share of other vertices joined by a time-respecting path
#>  node       measure     value
#>     A forward_reach 1.0000000
#>     B forward_reach 0.6666667
#>     C forward_reach 0.3333333
#>     D forward_reach 0.0000000
dyn_reachability(dn, start = 0, end = 2)
#> # Reachability (node-level)
#> # 4 vertices | time in step
#> # measures: forward_reach, backward_reach
#> # share of other vertices joined by a time-respecting path
#>  node        measure     value
#>     A  forward_reach 1.0000000
#>     B  forward_reach 0.6666667
#>     C  forward_reach 0.3333333
#>     D  forward_reach 0.0000000
#>     A backward_reach 0.0000000
#>     B backward_reach 0.3333333
#>     C backward_reach 0.6666667
#>     D backward_reach 1.0000000
```
