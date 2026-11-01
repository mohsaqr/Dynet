# Plot a temporal measure

Draws the quantity against time. Node-level measures are drawn as one
line per vertex, pair-level measures as one marked line per vertex pair
(each observation is a point, so a pair observed once is still drawn),
and graph-level measures as one line per measure. Distinctions are
carried by colour and line type together, never by colour alone; when
there are more series than distinct colour and line-type combinations, a
`dynet_palette_recycled` warning says so rather than letting two series
look identical in silence.

## Usage

``` r
# S3 method for class 'dynet_metric'
plot(
  x,
  type = c("line", "heatmap", "ridge"),
  highlight = NULL,
  top = NULL,
  palette = "okabe",
  base_size = 12,
  ...
)
```

## Arguments

- x:

  A `dynet_metric`.

- type:

  `"line"` for trajectories over time, `"heatmap"` for a series-by-time
  tile plot (one row per vertex, pair or measure), `"ridge"` for small
  multiples per measure. Ignored for a measure with no time axis. Any
  other value raises `dynet_bad_choice`.

- highlight:

  Optional character vector naming the series to draw in colour, with
  everything else in grey: vertex names for a node-level measure,
  measure names for a graph-level one. For a pair-level measure a vertex
  name selects every pair that vertex belongs to, and for a
  [`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md)
  result a group name selects every flow into or out of that group, so
  `highlight = "Teacher"` colours the teacher rows and columns of the
  mixing table. A name that matches nothing raises an error of class
  `dynet_unknown_highlight`. Ignored for a measure with no time axis.

- top:

  How many series to draw. For a measure taken over time, the `top`
  vertices (or pairs, for a pair-level measure) with the largest mean
  value; `NULL`, the default, draws every one. A graph-level series
  ignores it. For a measure with no time axis, the `top` rows with the
  largest absolute value, defaulting to `30`, with a subtitle naming how
  many of how many are shown.

- palette:

  Colours for the series: `"okabe"` (the default), `"extended"`,
  `"many"`, your own vector of colours, or a function of `n`. Okabe-Ito
  has nine colours and the lines six types, so eighteen series can be
  told apart; beyond that a `dynet_palette_recycled` warning suggests
  `top`, `highlight` or `palette = "many"`.

- base_size:

  Base font size.

- ...:

  Ignored.

## Value

A `ggplot` object. Drawing happens when that object is printed, so the
plot is the return value here rather than a side effect.

## Details

A measure with no time axis, such as reachability or
[`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md),
has no trajectory to draw and is shown as a bar panel instead, one bar
per vertex or pair and one facet per measure. `type` and `highlight`
have nothing to act on there and are ignored.

## Examples

``` r
dn <- dynet(school_contacts)
degree <- centrality_series(dn, measure = "degree")
plot(degree, top = 5)

plot(degree, palette = "extended")

```
