# Plot the bin-by-bin record of an animation

The film itself is the file
[`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md)
wrote; this draws what it shows per bin: ties active, ties forming and
ties dissolving, told apart by line type and point shape.

## Usage

``` r
# S3 method for class 'dynet_animation'
plot(x, base_size = 12, ...)
```

## Arguments

- x:

  A `dynet_animation` from
  [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md).

- base_size:

  Base font size.

- ...:

  Ignored.

## Value

A `ggplot` object.
