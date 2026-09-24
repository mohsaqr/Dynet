# Plot pathways on a time axis

One row per route, drawn along real time: a point at each vertex placed
at the moment the route reaches it, joined by a segment. The horizontal
gap between two points is the waiting time at that vertex, so the
drawing is time-respecting in the way a bar of a route string is not – a
route that waits is visibly slower than one that does not, and where
routes arrive relative to each other is read off the axis.

## Usage

``` r
# S3 method for class 'dynet_pathways'
plot(x, top = 12L, labels = TRUE, base_size = 12, ...)
```

## Arguments

- x:

  A `dynet_pathways` result.

- top:

  Number of routes to draw, most frequent first. Defaults to twelve,
  which keeps the vertex labels legible.

- labels:

  Whether to name the vertex at each step. `TRUE` by default; turn it
  off for a dense figure where the shape is the point.

- base_size:

  Base font size, as in
  [`ggplot2::theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html).
  Defaults to twelve.

- ...:

  Ignored.

## Value

A `ggplot` object. A `top`, `labels` or `base_size` that is not one
valid value raises `dynet_bad_input`.

## Details

Routes are ordered by frequency, most used at the top, with the count
and share to the right of each. Fill marks the endpoint, which the row
already names, so colour never carries a distinction alone.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- pathways(dn, from = "Ana")
plot(routes)
```
