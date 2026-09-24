# Summarise an animation

Summarise an animation

## Usage

``` r
# S3 method for class 'dynet_animation'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_animation` from
  [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md).

- ...:

  Ignored.

## Value

A one-row plain `data.frame` with `bins`, `frames`, `fps`, `seconds`,
`tween`, `ease`, `layout`, `format`, `measure` (what node size follows,
`NA` when it is constant), `first_time`, `last_time`, `min_ties`,
`max_ties`, `turnover` (over the bins after the first that hold a tie,
the median share of a bin's ties that were not active in the bin before:
near 0 the film flows, near 1 every bin is a new picture; `NA` with a
single bin) and `file`.

## Examples

``` r
if (requireNamespace("gifski", quietly = TRUE) &&
  requireNamespace("cograph", quietly = TRUE)) {
  dn <- dynet(school_contacts)
  frames <- animate(dn, step = 6, window = 6, tween = 2)
  summary(frames)
}
#>   bins frames fps   seconds tween  ease layout format measure first_time
#> 1    4      8  12 0.6666667     2 dwell spring    gif    <NA>          0
#>   last_time min_ties max_ties turnover                                file
#> 1        18       25       65     0.56 /tmp/Rtmp4FenTd/file1e2451aa9f6.gif
```
