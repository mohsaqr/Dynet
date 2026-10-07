# Network turnover: volatility and fluctuability

`"volatility"` is the proportion of eligible pairs whose tie state
changed between one time bin and the next. `"fluctuability"` is the
number of distinct pairs ever active divided by the total number of
pair-bin activations, so it is low when the same few pairs recur and
high when activity is spread thin.

## Usage

``` r
turnover(
  dn,
  measure = c("volatility", "fluctuability"),
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

- measure:

  `"volatility"`, the default, or `"fluctuability"`. Both may be asked
  for at once at `scope = "overall"`.

- scope:

  `"pertime"`, the default, for one row per transition, or `"overall"`
  for one row per measure. `"fluctuability"` is defined only at
  `"overall"`: it is a property of the whole observed series, and a
  per-bin value would be the constant 1 dressed up as data.

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

A `dynet_metric` at `level = "graph"`. Under `scope = "pertime"` the
columns are `time`, `measure` and `value`, one row per transition, where
`time` is the **earlier** bin of the pair; the final bin opens no
transition and contributes no row. Under `scope = "overall"` they are
`measure` and `value`, one row per requested measure. A leading
`session` column is present under `sessions = "separate"`. `volatility`
lies in `[0, 1]` and `fluctuability` in `(0, 1]`, or is `NA_real_` when
no pair is active anywhere in the grid. Print it,
[`summary()`](https://rdrr.io/r/base/summary.html) it,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) it, or take the
plain frame with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

## Details

Volatility is the *proportion* Hamming distance over the eligible
non-loop pair domain: the strict upper triangle for an undirected
network, every ordered off-diagonal pair for a directed one. This is not
the scale `cograph::layer_similarity(method = "hamming")` uses, which is
a raw count over the full symmetric matrix and is therefore
`2 * choose(n, 2)` times larger on an undirected network.

**Fluctuability is grid-dependent and comparable only across networks
measured on the same grid.** Its denominator sums per-bin active-pair
counts, so halving `step` roughly doubles it and roughly halves the
result. That is a property of the published definition rather than a
defect; teneto's own documentation concedes the measure is not
normalised in a way that makes comparisons across very different
networks meaningful.

Weights and spell counts are ignored throughout: a pair is tied in a bin
or it is not. Loops are excluded from the domain.

## Conditions

Errors: `dynet_incompatible_scope` when `"fluctuability"` is asked for
at `scope = "pertime"`; `dynet_empty_result` when the grid yields fewer
than two bins, or when the network has fewer than two vertices and the
pair domain is empty; `dynet_no_sessions` when `sessions = "separate"`
is asked of a network with no session column; and `dynet_bad_input` when
`dn` is not a `dynet`.

## References

Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to
temporal network theory: applications to functional brain connectivity.
*Network Neuroscience*, 1(2), 69-99.
[doi:10.1162/NETN_a_00011](https://doi.org/10.1162/NETN_a_00011)

Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97-125.
[doi:10.1016/j.physrep.2012.03.001](https://doi.org/10.1016/j.physrep.2012.03.001)

## See also

[`persistence()`](https://pak.dynasite.org/Dynet/reference/persistence.md)
for the node-level view of what survived, and
[`events()`](https://pak.dynasite.org/Dynet/reference/events.md) for raw
formation and dissolution counts.

## Examples

``` r
dn <- dynet(school_contacts)
churn <- turnover(dn)
churn
#> # Turnover per transition (graph-level)
#> # 21 time points, 1 per bin | time in step
#> # volatility 0 is a frozen network; fluctuability 1 repeats no pair
#>  time    measure      value
#>     0 volatility 0.05494505
#>     1 volatility 0.07692308
#>     2 volatility 0.06593407
#>     3 volatility 0.11538462
#>     4 volatility 0.06043956
#>     5 volatility 0.15934066
#>     6 volatility 0.16483516
#>     7 volatility 0.11538462
#>     8 volatility 0.10989011
#>     9 volatility 0.10439560
#>    10 volatility 0.13736264
#>    11 volatility 0.09890110
#> # 9 more rows. summary() aggregates them; plot() draws them.

summarised <- turnover(dn, measure = c("volatility", "fluctuability"),
                       scope = "overall")
summarised
#> # Turnover over the series (graph-level)
#> # time in step
#> # measures: volatility, fluctuability
#> # volatility 0 is a frozen network; fluctuability 1 repeats no pair
#>        measure     value
#>     volatility 0.1004710
#>  fluctuability 0.3313253
```
