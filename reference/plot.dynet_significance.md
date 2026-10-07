# Plot a permutation test

Plot a permutation test

## Usage

``` r
# S3 method for class 'dynet_significance'
plot(x, type = c("null", "series", "z"), ...)
```

## Arguments

- x:

  A `dynet_significance` from
  [`significance()`](https://pak.dynasite.org/Dynet/reference/significance.md).

- type:

  `"null"` draws the surrogate distribution with the observed value
  marked, `"series"` draws the observed value over time inside the null
  band, and `"z"` orders vertices or cells by standardised deviation.

- ...:

  Ignored.

## Value

A `ggplot` object.
