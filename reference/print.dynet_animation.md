# Print an animation's bin table

Print an animation's bin table

## Usage

``` r
# S3 method for class 'dynet_animation'
print(x, n = 12L, ...)
```

## Arguments

- x:

  A `dynet_animation` from
  [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md).

- n:

  Largest number of bins to list, `12` by default.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
if (requireNamespace("gifski", quietly = TRUE) &&
  requireNamespace("cograph", quietly = TRUE)) {
  dn <- dynet(school_contacts)
  frames <- animate(dn, step = 6, window = 6, tween = 2)
  print(frames, n = 3)
}
#> # Animation of 4 bins in 8 frames at 12 fps | spring layout | gif | time in step
#> # /tmp/RtmpbC9cDu/file1e84697c04c3.gif
#>  bin frame time window_start window_end nodes idle ties forming dissolving
#>    1     1    0            0          6    14    0   43      NA         19
#>    2     3    6            6         12    14    0   65      41         33
#>    3     5   12           12         18    14    0   55      23         44
#> # 1 more bin.
```
