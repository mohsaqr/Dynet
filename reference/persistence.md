# Neighbourhood persistence between consecutive time bins

Topological overlap: the share of a vertex's ties that survive from one
time bin to the next, normalised by the geometric mean of its degrees in
the two bins. Averaged over a vertex's transitions it is that vertex's
persistence; averaged again over vertices it is the network's temporal
correlation coefficient (Tang et al., 2010).

## Usage

``` r
persistence(
  dn,
  scope = c("pertime", "node", "overall"),
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL,
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- scope:

  `"pertime"`, the default, for one row per vertex per transition;
  `"node"` for each vertex's mean over its transitions; `"overall"` for
  the temporal correlation coefficient, one number per session.

- sessions:

  How to treat sessions, as in
  [`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md).

- start, end, step, window:

  The measurement grid, as in
  [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md).
  A transition is a consecutive pair of bins on that grid, so the grid
  decides what "persisted" means; widening `step` makes persistence
  easier.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn.

## Value

A `dynet_metric`. Under `scope = "pertime"` it is `level = "node"` with
columns `time`, `node`, `measure` and `value`, one row per vertex per
transition, where `time` is the **earlier** bin of the pair; the final
bin opens no transition and so contributes no rows at all, rather than a
row whose value is structurally undefined. Under `scope = "node"` it is
`level = "node"` with `node`, `measure` and `value`, one row per vertex.
Under `scope = "overall"` it is `level = "graph"` with `measure` and
`value`, one row per session. A leading `session` column is present
under `sessions = "separate"`. `measure` is `"topological_overlap"`,
`"average_topological_overlap"` and `"temporal_correlation"`
respectively, and `value` lies in `[0, 1]` at every scope. Print it,
[`summary()`](https://rdrr.io/r/base/summary.html) it,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) it, or take the
plain frame with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

## Details

The measure is defined on undirected neighbourhoods, so a directed
network is read as a contact network here: each layer is folded onto its
transpose before the overlap is taken. Weights and spell counts are
ignored – a pair is tied in a bin or it is not – and loops are excluded.

A vertex isolated in either bin of a transition scores zero rather than
a missing value. That is a substantive claim, not an arithmetic
accident: the ratio is genuinely 0/0, and zero is the convention teneto
uses. A reader who wants isolation and genuine turnover distinguished
should read the degree alongside, which
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md)
gives.

## Conditions

Errors: `dynet_empty_result` when the grid yields fewer than two bins,
since a single bin opens no transition and the measure is undefined;
`dynet_no_sessions` when `sessions = "separate"` is asked of a network
with no session column; and `dynet_bad_input` when `dn` is not a
`dynet`.

## References

Tang, J., Scellato, S., Musolesi, M., Mascolo, C., & Latora, V. (2010).
Small-world behavior in time-varying graphs. *Physical Review E*, 81(5),
055101(R).
[doi:10.1103/PhysRevE.81.055101](https://doi.org/10.1103/PhysRevE.81.055101)

Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora,
V. (2013). Graph metrics for temporal networks. In P. Holme & J.
Saramaki (Eds.), *Temporal Networks* (pp. 15-40). Springer.
[doi:10.1007/978-3-642-36461-7_2](https://doi.org/10.1007/978-3-642-36461-7_2)

Clauset, A., & Eagle, N. (2007). Persistence and periodicity in a
dynamic proximity network. *DIMACS Workshop on Computational Methods for
Dynamic Interaction Networks*.

## See also

[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md),
which compares whole edge sets between every pair of bins and answers a
different question, and
[`turnover()`](https://pak.dynasite.org/Dynet/reference/turnover.md) for
the complementary view of what changed.

## Examples

``` r
dn <- dynet(school_contacts)
kept <- persistence(dn)
kept
#> # Neighbourhood persistence per transition (node-level)
#> # 14 vertices | 21 time points, 1 per bin | time in step
#> # 1 keeps every neighbour, 0 keeps none; an isolated vertex scores 0
#>  time  node             measure     value
#>     0   Ana topological_overlap 0.0000000
#>     0   Ben topological_overlap 0.0000000
#>     0  Cara topological_overlap 1.0000000
#>     0   Dan topological_overlap 1.0000000
#>     0   Eve topological_overlap 0.4082483
#>     0  Finn topological_overlap 0.0000000
#>     0  Gita topological_overlap 0.0000000
#>     0  Hugo topological_overlap 0.0000000
#>     0  Iris topological_overlap 0.4082483
#>     0 Jonas topological_overlap 1.0000000
#>     0  Kira topological_overlap 0.7071068
#>     0   Leo topological_overlap 0.0000000
#> # 282 more rows. summary() aggregates them; plot() draws them.

per_node <- persistence(dn, scope = "node")
per_node
#> # Neighbourhood persistence per vertex (node-level)
#> # 14 vertices | time in step
#> # 1 keeps every neighbour, 0 keeps none; an isolated vertex scores 0
#>   node                     measure     value
#>    Ana average_topological_overlap 0.3736034
#>    Ben average_topological_overlap 0.3999443
#>   Cara average_topological_overlap 0.4203873
#>    Dan average_topological_overlap 0.4037204
#>    Eve average_topological_overlap 0.3901184
#>   Finn average_topological_overlap 0.2970579
#>   Gita average_topological_overlap 0.2680499
#>   Hugo average_topological_overlap 0.4283606
#>   Iris average_topological_overlap 0.3508067
#>  Jonas average_topological_overlap 0.4012369
#>   Kira average_topological_overlap 0.5274689
#>    Leo average_topological_overlap 0.3489197
#> # 2 more rows. summary() aggregates them; plot() draws them.

overall <- persistence(dn, scope = "overall")
overall
#> # Temporal correlation coefficient (graph-level)
#> # time in step
#> # 1 keeps every neighbour, 0 keeps none; an isolated vertex scores 0
#>               measure     value
#>  temporal_correlation 0.3894722
```
