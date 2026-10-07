# Summarise a permutation test

Summarise a permutation test

## Usage

``` r
# S3 method for class 'dynet_significance'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_significance` from
  [`significance()`](https://pak.dynasite.org/Dynet/reference/significance.md).

- ...:

  Ignored.

## Value

A data frame with one row per measure and columns `measure`, `tested`,
`significant` and `median_z`.
