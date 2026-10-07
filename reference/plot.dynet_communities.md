# Draw community membership as ribbons over time

One band per vertex per bin, stacked by community, so a community reads
as a block and a vertex changing community reads as a band crossing
between blocks. Communities are labelled directly on the plot as well as
coloured, because colour alone is not a channel every reader has.

## Usage

``` r
# S3 method for class 'dynet_communities'
plot(x, base_size = 12, ...)
```

## Arguments

- x:

  A `dynet_communities` frame.

- base_size:

  Base text size.

- ...:

  Ignored.

## Value

A `ggplot` object.
