# Compare a measure against a temporal null model

Runs a measurement verb on the observed network and on every surrogate
from a null model, then reports the observed value beside the null
distribution, a percentile interval and a permutation p-value. This is
what turns any of this package's measures from a point estimate into a
result.

Works with every verb that returns a `measure` and a `value` column,
which is all of them:
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md),
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md),
[`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md),
[`events()`](https://pak.dynasite.org/Dynet/reference/events.md),
[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md),
[`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md),
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md),
[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md),
[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md)
and [`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md).

## Usage

``` r
significance(
  x,
  statistic,
  ...,
  method = c("times", "timeline", "edges", "targets", "labels"),
  n = 999L,
  alternative = c("two.sided", "greater", "less"),
  conf_level = 0.95,
  p_adjust = "BH",
  within = c("network", "sender", "session"),
  seed = NULL
)
```

## Arguments

- x:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md), or a
  `dynet_null` from
  [`randomise()`](https://pak.dynasite.org/Dynet/reference/randomise.md)
  when reusing one set of surrogates for several statistics.

- statistic:

  A measurement verb, passed as a function.

- ...:

  Passed to `statistic`, so `measure = "density"` and friends work
  without a wrapper.

- method, n, within:

  Null model settings, as in
  [`randomise()`](https://pak.dynasite.org/Dynet/reference/randomise.md).
  Supplying any of them alongside a `dynet_null` is an error rather than
  a silent override.

- alternative:

  `"two.sided"`, `"greater"` or `"less"`.

- conf_level:

  Width of the reported percentile interval of the null.

- p_adjust:

  Multiplicity correction, passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html).

- seed:

  A single whole number for a reproducible draw, or `NULL`.

## Value

A `dynet_significance` data frame with one row per cell of the observed
statistic. It carries every key column the statistic produced, then
`observed`, `null_mean`, `null_sd`, `null_lo`, `null_hi`, `z`, `p`,
`p_adj`, `p_mcse`, `n_ties` and `n_null`. `null_lo` and `null_hi` bound
the null distribution, not the observed value, which is why they are not
named as a confidence interval for it.

## Details

The p-value carries the standard plus-one correction, \\p = (1 + r) /
(1 + n)\\, so with 999 surrogates the smallest reportable value is 0.001
and never zero. `p_mcse` is the Monte-Carlo standard error on `p`
itself, computed from the same draws, so the precision of the p-value is
visible beside it.

A cell present in the observed result but absent from a surrogate counts
as missing, never as zero: a bin with no eligible pairs did not have
zero density, it had no density. `n_null` reports how many surrogates
actually produced each cell.

Under `method = "labels"` every structural measure is exactly invariant,
so every p is exactly one. That is correct, and it is a useful check
that the machinery is aligned rather than a failure.

`n_ties` counts surrogates numerically equal to the observed value. Read
it: a discrete statistic on a small network, such as density where every
value is a count over a fixed number of pairs, can put most of the null
mass exactly on the observed value. The p-value is then decided by how
ties are counted rather than by the tail, and it does **not** stabilise
as `n` grows. Measured on `school_contacts`, the density p-value varied
by 0.61 across five seeds at both 199 and 999 surrogates, while the
continuous burstiness p-value tightened from 0.19 to 0.07 over the same
increase. A large `n_ties` relative to `n_null` means more surrogates
will not help; a statistic with finer resolution will.

## References

Davison, A. C., and Hinkley, D. V. (1997). *Bootstrap Methods and Their
Application*. Cambridge University Press.

North, B. V., Curtis, D., and Sham, P. C. (2002). A note on the
calculation of empirical P values from Monte Carlo procedures. *American
Journal of Human Genetics*, 71(2), 439-441.

Benjamini, Y., and Hochberg, Y. (1995). Controlling the false discovery
rate. *Journal of the Royal Statistical Society B*, 57(1), 289-300.

## See also

[`randomise()`](https://pak.dynasite.org/Dynet/reference/randomise.md)
for the null models and what each one holds fixed.

## Examples

``` r
dn <- dynet(school_contacts)
significance(dn, statistic = metrics, measure = "density", n = 99, seed = 1)
#> # metrics against 99 surrogates | null "times" | two.sided
#> # null holds fixed: the multiset of (start, end) pairs, so the activity profile and duration distribution exactly; the pair set; each pair's event count
#> # 95% interval bounds the null, not the observed value
#> # 0 of 22 rows outside the null after BH correction
#>   time measure   observed  null_mean     null_sd    null_lo    null_hi
#> 1    0 density 0.05494505 0.05710956 0.003749480 0.04945055 0.06043956
#> 2    1 density 0.04395604 0.04256854 0.002524428 0.03846154 0.04395604
#> 3    2 density 0.05494505 0.05322455 0.002678722 0.04945055 0.05494505
#> 4    3 density 0.06593407 0.06338106 0.003623716 0.05494505 0.06593407
#> 5    4 density 0.07142857 0.07181707 0.004790804 0.06043956 0.07692308
#> 6    5 density 0.08791209 0.08269508 0.004668432 0.07142857 0.08791209
#> 7    6 density 0.15934066 0.15046065 0.007916007 0.13186813 0.16236264
#> 8    7 density 0.10439560 0.09723610 0.005684891 0.08791209 0.10439560
#>             z    p p_adj     p_mcse n_ties n_null
#> 1 -0.57728056 1.00     1 0.00000000     41     99
#> 2  0.54963006 1.00     1 0.00000000     75     99
#> 3  0.64228456 1.00     1 0.00000000     69     99
#> 4  0.70452604 1.00     1 0.00000000     61     99
#> 5 -0.08109294 1.00     1 0.00000000     44     99
#> 6  1.11750693 0.54     1 0.04983974     32     99
#> 7  1.12177887 0.33     1 0.04702127     21     99
#> 8  1.25939218 0.41     1 0.04918333     26     99
#> # 14 more rows.
```
