# Segregation-integration difference over time

Fransson's SID: for each time bin, how much more tied a network's
communities are internally than to each other, both normalised by the
number of pairs available. Positive means segregation exceeds
integration.

## Usage

``` r
segregation(
  dn,
  communities,
  scope = c("pertime", "overall"),
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

- communities:

  Either a vector **named by vertex name**, or a single string naming a
  column of the node table, as
  [`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md)
  takes. A positional vector is refused: matching a partition to
  vertices by position is exactly the index-based addressing this
  package avoids.

- scope:

  `"pertime"`, the default, for one row per bin, or `"overall"` for the
  mean over bins.

- sessions:

  How to treat sessions, as in
  [`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md).

- start, end, step, window:

  The measurement grid, as in
  [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md).

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn.

## Value

A `dynet_metric` at `level = "graph"` with columns `time` (under
`scope = "pertime"`), `measure`, which is the constant `"sid"`, and
`value`. A leading `session` column is present under
`sessions = "separate"`. **The value is signed and unbounded**: it is a
difference of two normalised sums, not a proportion, so there is no
range to check it against. Print it,
[`summary()`](https://rdrr.io/r/base/summary.html) it,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) it, or take the
plain frame with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

## Details

A community of one vertex makes the within-community normaliser
`2 / (N_a (N_a - 1))` a division by zero. Rather than drop the vertex,
which would change every other community's denominator, the bin returns
`NA_real_` and a `dynet_singleton_community` warning names the offending
community.

The measure is defined on undirected networks, and a directed one is
read by folding each layer onto its transpose, as
[`persistence()`](https://pak.dynasite.org/Dynet/reference/persistence.md)
does. Weights and spell counts are ignored: a pair is tied in a bin or
it is not.

## Conditions

Errors: `dynet_bad_communities` when the partition is unnamed, names a
vertex the network does not have, or leaves a vertex unassigned;
`dynet_no_sessions` under `sessions = "separate"` without a session
column; `dynet_bad_input` when `dn` is not a `dynet`. Warns with
`dynet_singleton_community` when a community has one member.

## References

Fransson, P., Thompson, W. H., Skiold, B., et al. (2018). Brain network
segregation and integration during an epoch-related working memory fMRI
experiment. *NeuroImage*, 178, 147-161.
[doi:10.1016/j.neuroimage.2018.05.040](https://doi.org/10.1016/j.neuroimage.2018.05.040)

Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to
temporal network theory. *Network Neuroscience*, 1(2), 69-99.
[doi:10.1162/NETN_a_00011](https://doi.org/10.1162/NETN_a_00011)

## See also

[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) for who
ties to whom by attribute, and
[`persistence()`](https://pak.dynasite.org/Dynet/reference/persistence.md)
for whether those ties survive.

## Examples

``` r
dn <- dynet(school_contacts)
groups <- stats::setNames(
  rep(c("a", "b"), length.out = nrow(dn$nodes)), dn$nodes$name
)
sid <- segregation(dn, communities = groups)
sid
#> # Segregation-integration difference (graph-level)
#> # 22 time points, 1 per bin | time in step
#> # positive is more segregated than integrated; signed and unbounded
#>  time measure        value
#>     0     sid -0.054421769
#>     1     sid  0.244897959
#>     2     sid -0.142857143
#>     3     sid -0.224489796
#>     4     sid -0.047619048
#>     5     sid  0.231292517
#>     6     sid  0.047619048
#>     7     sid  0.054421769
#>     8     sid -0.074829932
#>     9     sid -0.258503401
#>    10     sid -0.163265306
#>    11     sid  0.006802721
#> # 10 more rows. summary() aggregates them; plot() draws them.
```
