# Describe a collapsed temporal network

Describe a collapsed temporal network

## Usage

``` r
# S3 method for class 'dynet_collapsed'
summary(object, ...)
```

## Arguments

- object:

  A result from
  [`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md).

- ...:

  Ignored.

## Value

A `data.frame` with columns `property` and `value`, one row per
property: `vertices`, `edges`, `weight` (the rule the edge weights
follow), `density` (edges over possible non-loop pairs), `total weight`
and `mean weight`. Both columns are character so the table prints as one
block.

## Examples

``` r
dn <- dynet(school_contacts)
flat <- collapse_network(dn)
summary(flat)
#>       property  value
#> 1     vertices     14
#> 2        edges    110
#> 3       weight binary
#> 4      density 0.6044
#> 5 total weight    110
#> 6  mean weight      1
```
