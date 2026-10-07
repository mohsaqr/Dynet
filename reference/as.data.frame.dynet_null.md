# Coerce surrogate networks to a data frame

Coerce surrogate networks to a data frame

## Usage

``` r
# S3 method for class 'dynet_null'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `dynet_null` from
  [`randomise()`](https://pak.dynasite.org/Dynet/reference/randomise.md).

- row.names:

  Passed to the data frame method.

- optional:

  Passed to the data frame method.

- ...:

  Ignored.

## Value

A base data frame, one row per surrogate spell per replicate.
