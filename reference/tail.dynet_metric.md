# Last rows of a temporal measure

The counterpart of
[`head.dynet_metric()`](https://mohsaqr.github.io/Dynet/reference/head.dynet_metric.md);
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

  Number of rows to keep.

- ...:

  Passed to the default method.

## Value

A `dynet_metric` with at most `n` rows, carrying the source counts so
its header stays true to the series.
