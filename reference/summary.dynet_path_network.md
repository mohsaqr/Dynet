# Describe a path network

Describe a path network

## Usage

``` r
# S3 method for class 'dynet_path_network'
summary(object, ...)
```

## Arguments

- object:

  A result from
  [`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md).

- ...:

  Ignored.

## Value

A `data.frame` with columns `property` and `value`, one row per
property, as for
[`summary.dynet_collapsed()`](https://pak.dynasite.org/Dynet/reference/summary.dynet_collapsed.md);
`weight` reads `"hops"`.
