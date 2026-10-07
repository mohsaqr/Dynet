# Draw detected phases over the between-bin similarity heatmap

The heatmap
[`plot.dynet_similarity()`](https://pak.dynasite.org/Dynet/reference/plot.dynet_similarity.md)
draws, with the phase blocks outlined on it, so the reader can see
whether the blocks the algorithm found are the blocks the eye finds.

## Usage

``` r
# S3 method for class 'dynet_phases'
plot(x, base_size = 12, ...)
```

## Arguments

- x:

  A `dynet_phases` frame.

- base_size:

  Base text size.

- ...:

  Ignored.

## Value

A `ggplot` object.
