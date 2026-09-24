# Coerce an animation to a data frame

Coerce an animation to a data frame

## Usage

``` r
# S3 method for class 'dynet_animation'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("bins", "frames"),
  ...
)
```

## Arguments

- x:

  A `dynet_animation` from
  [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md).

- row.names, optional:

  As in
  [`base::as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

- what:

  `"bins"`, the default, for one row per bin with the columns
  [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md)
  documents; `"frames"` for one row per rendered frame, with `frame`,
  `bin` (the bin the frame belongs to), `phase` (how far along the
  transition to the next bin, in `[0, 1)`) and `time` (where the
  timeline marker stands).

- ...:

  Ignored.

## Value

A plain `data.frame`.

## Examples

``` r
if (requireNamespace("gifski", quietly = TRUE) &&
  requireNamespace("cograph", quietly = TRUE)) {
  dn <- dynet(school_contacts)
  frames <- animate(dn, step = 6, window = 6, tween = 2)
  as.data.frame(frames)
  as.data.frame(frames, what = "frames")
}
#>   frame bin phase time
#> 1     1   1   0.0    0
#> 2     2   1   0.5    3
#> 3     3   2   0.0    6
#> 4     4   2   0.5    9
#> 5     5   3   0.0   12
#> 6     6   3   0.5   15
#> 7     7   4   0.0   18
#> 8     8   4   0.0   18
```
