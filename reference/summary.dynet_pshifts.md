# Summarise participation shifts by family

Summarise participation shifts by family

## Usage

``` r
# S3 method for class 'dynet_pshifts'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_pshifts` result.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per shift family: `family`, its `count`,
the `share` of all classified transitions it accounts for, and
`top_shift`, the single most frequent shift type within it. `share` is
`NaN` when nothing was classified.

## Examples

``` r
summary(pshifts(dynet(school_contacts)))
#>            family count      share top_shift
#> 1   turn_usurping   206 0.87659574     AB-XY
#> 2  turn_receiving    18 0.07659574     AB-BY
#> 3 turn_continuing     8 0.03404255     AB-AY
#> 4   turn_claiming     3 0.01276596     A0-XY
```
