# Closeness and betweenness on time-respecting paths

Centrality computed from the time-respecting paths that
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) finds,
taken across the whole observation period (or the `start`-to-`end`
window). A path may only continue along a tie that is available after it
arrives, so these values cannot be inflated by ties that occur in the
wrong order, as a flattened network is. The result is one value per
vertex, not a series: for centrality that changes from window to window,
use
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md);
for the number of vertices a vertex can reach, use
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md).

## Usage

``` r
path_centrality(
  dn,
  measure = "closeness",
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
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- measure:

  One or both of `"closeness"` (the default) and `"betweenness"`. Any
  other name raises `dynet_unknown_measure`.

- sessions:

  How to treat sessions: `"bounded"` (the default) keeps paths inside a
  session, `"collapse"` ignores sessions, `"separate"` reports each
  session on its own rows. `"separate"` on a network built without a
  session column raises `dynet_no_sessions`.

- start, end:

  Inclusive path-traversal bounds. Default to the observed range. A
  network built from dates may be addressed with dates.

- traversal_time:

  Nonnegative duration charged for every hop, in the network's time
  unit; `0` by default. A calendar network also accepts a scalar
  `difftime`.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn.

## Value

A node-level `dynet_metric`: a tidy data frame with one row per vertex
and measure, columns `node`, `measure` and `value`, preceded by
`session` under `sessions = "separate"`. There is no `time` column. A
single-measure result stores its mathematical choices as direct
attributes; a two-measure result stores named records under
`measure_metadata`.

## Details

Betweenness is the raw dependency sum over reachable forward ordered
pairs. For each source-target pair, its unit dependency is divided
equally over every canonical shortest-foremost journey, and an internal
vertex receives the fraction of those journeys that contain it. Sources
and targets receive no endpoint credit. This ordered-pair convention
also applies to undirected contacts because temporal reach is generally
asymmetric. The result is not normalised; its fixed range is
`[0, (n - 1) * (n - 2)]`.

Closeness is inverse mean forward latency over reachable vertices: if
\\R_s\\ is the set of reachable vertices other than source \\s\\,
\$\$C(s) = \|R_s\| / \sum\_{z \in R_s} (a_z - o_s),\$\$ where \\a_z\\ is
the foremost arrival time and \\o_s\\ is the source's resolved origin:
the traversal window's lower bound, or – when vertex activity was
declared – the source's first presence inside that window. Every
reachable endpoint is included once, regardless of how many optimal
paths reach it. A source with no reachable nonself endpoints has value
zero. If all reachable endpoints have zero latency, the value is `Inf`;
zero-latency endpoints remain in the numerator when mixed with positive
latencies. The measure therefore has inverse-time units, is invariant to
translating the time axis, and scales inversely when time is rescaled.

Both measures use
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) traversal
semantics: nondecreasing times, unlimited waiting, half-open interval
spells, and a separate exact timestamp rule for point events. Positive
`traversal_time` requires an interval traversal to finish within
continuous pair activity; a point event triggers at its timestamp and
reaches its endpoint after that duration. `start` and `end` bound every
measure. In separate-session output, a session outside a one-sided bound
contributes zero rows.

Declared vertex activity gates the exact source anchor and every hop.
Waiting after a valid anchor may cross inactivity; interval traversal
requires both endpoints through completion, while a point trigger
requires the receiver again after any traversal delay. Fixed node rows
and full-network denominators are retained.

## Conditions

Errors: `dynet_unknown_measure` (a measure other than `"closeness"` or
`"betweenness"`), `dynet_no_sessions` (`sessions = "separate"` without a
session column), `dynet_outside_observation` (the requested range misses
observed support; it also carries `dynet_bad_input`), and
`dynet_bad_input` for every other broken contract – `dn` not a `dynet`,
a malformed `measure`, an out-of-range `start`, `end` or
`traversal_time`.

## References

Pan, R. K., & Saramaki, J. (2011). Path lengths, correlations, and
centrality in temporal networks. *Physical Review E*, 84(1), 016105.

Tang, J., Musolesi, M., Mascolo, C., Latora, V., & Nicosia, V. (2010).
Analysing information flows and key mediators through temporal
centrality metrics. *Proceedings of SNS '10*.

Buss, S., Molter, H., Niedermeier, R., & Rymar, M. (2024). Algorithmic
aspects of temporal betweenness. *Network Science*, 12(2), 160-188.

Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora,
V. (2013). Graph metrics for temporal networks. In *Temporal Networks*
(pp. 15-40). Springer.

## See also

[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md),
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md),
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md).

## Examples

``` r
# Every ordered pair is searched, so the cost grows steeply with the
# vertex count; a subgraph keeps the example quick.
dn <- dynet(school_contacts)
few <- induce_subgraph(dn, nodes = c("Ana", "Ben", "Cara", "Dan", "Eve",
                                     "Finn", "Gita", "Hugo"))
path_centrality(few)
#> # Closeness (node-level)
#> # 8 vertices | time in step
#> # computed on time-respecting paths across the whole window
#>  node   measure      value
#>   Ana closeness 0.09987159
#>   Ben closeness 0.13180192
#>  Cara closeness 0.07404273
#>   Dan closeness 0.14198783
#>   Eve closeness 0.13908206
#>  Finn closeness 0.07579859
#>  Gita closeness 0.10995916
#>  Hugo closeness 0.12297962
path_centrality(few, measure = c("closeness", "betweenness"),
                start = 0, end = 10)
#> # Temporal centrality (node-level)
#> # 8 vertices | time in step
#> # measures: closeness, betweenness
#> # computed on time-respecting paths within the requested traversal window
#>  node     measure     value
#>   Ana   closeness 0.1380262
#>   Ben   closeness 0.1731902
#>  Cara   closeness 0.1270648
#>   Dan   closeness 0.1794258
#>   Eve   closeness 0.1740644
#>  Finn   closeness 0.1476015
#>  Gita   closeness 0.1773836
#>  Hugo   closeness 0.1461276
#>   Ana betweenness 8.0000000
#>   Ben betweenness 0.0000000
#>  Cara betweenness 7.0000000
#>   Dan betweenness 0.0000000
#> # 4 more rows. summary() aggregates them; plot() draws them.
```
