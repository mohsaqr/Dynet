# Last rows of a temporal measure

The counterpart of
[`head.dynet_metric()`](https://pak.dynasite.org/Dynet/reference/head.dynet_metric.md);
the header still describes the series and a `last n of N rows` line
records the truncation.

## Usage

``` r
# S3 method for class 'dynet_metric'
tail(x, n = 6L, ...)
```

## Arguments

- x:

  A `dynet_metric`.

- n:

  Number of rows to keep. Defaults to six.

- ...:

  Passed to the default method.

## Value

A `dynet_metric` with at most `n` rows, carrying the source counts so
its header stays true to the series.

## Examples

``` r
dn <- dynet(school_contacts)
degree <- centrality_series(dn, step = 4, window = 4)
tail(degree)
#> # Degree (node-level)
#> # 14 vertices | 6 time points, 4 per bin | time in step
#> # last 6 of 84 rows
#>  time  node measure value
#>    20  Iris  degree     1
#>    20 Jonas  degree     2
#>    20  Kira  degree     3
#>    20   Leo  degree     1
#>    20  Mira  degree     2
#>    20  Nils  degree     3
```
