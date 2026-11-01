# Draw collapsed networks, one panel per session

Draw collapsed networks, one panel per session

## Usage

``` r
# S3 method for class 'dynet_collapsed_list'
plot(x, palette = "okabe", ...)
```

## Arguments

- x:

  A `dynet_collapsed_list` from
  `collapse_network(sessions = "separate")`.

- palette:

  Palette specification, as in
  [`plot.dynet()`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md).

- ...:

  Passed to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
  for every panel; a per-panel `title` naming the session is set and can
  be overridden here.

## Value

`x`, invisibly; the panels are drawn on the current device. Raises
`dynet_needs_cograph` when cograph is not installed.
