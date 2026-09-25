# First rows of a temporal measure

Truncates the rows without rewriting what the measure is. The printed
header still describes the series the rows came from, and a
`first n of N rows` line records the truncation.

## Usage

``` r
# S3 method for class 'dynet_metric'
head(x, n = 6L, ...)
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
head(degree)
#> # Degree (node-level)
#> # 14 vertices | 6 time points, 4 per bin | time in step
#> # first 6 of 84 rows
#>  time node measure value
#>     0  Ana  degree     3
#>     0  Ben  degree     3
#>     0 Cara  degree     2
#>     0  Dan  degree     5
#>     0  Eve  degree     8
#>     0 Finn  degree     3
```
