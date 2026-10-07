# Coerce a permutation test to a data frame

Coerce a permutation test to a data frame

## Usage

``` r
# S3 method for class 'dynet_significance'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `dynet_significance` from
  [`significance()`](https://pak.dynasite.org/Dynet/reference/significance.md).

- row.names:

  Passed to the data frame method.

- optional:

  Passed to the data frame method.

- ...:

  Ignored.

## Value

A base data frame, one row per tested cell.
