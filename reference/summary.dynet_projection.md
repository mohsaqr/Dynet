# Summarise a time projection

Summarise a time projection

## Usage

``` r
# S3 method for class 'dynet_projection'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_projection` result.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per slice: `slice`, its `time`, the number
of `active` vertex states, the `within_slice` arcs induced in it, and
the `identity_arcs` leaving it for the next slice. The final slice emits
no identity arcs, so its count is zero.

## Examples

``` r
summary(projection(dynet(school_contacts), step = 5, window = 5))
#>   slice time active within_slice identity_arcs
#> 1     1    0     14           40            14
#> 2     2    5     14           60            14
#> 3     3   10     14           62            14
#> 4     4   15     14           33            14
#> 5     5   20     14           17             0
```
