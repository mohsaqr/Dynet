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

  Number of rows to keep.

- ...:

  Passed to the default method.

## Value

A `dynet_metric` with at most `n` rows, carrying the source counts so
its header stays true to the series.
