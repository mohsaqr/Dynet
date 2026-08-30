# Plot a temporal measure

Draws the quantity against time. Node-level measures are drawn as one
line per vertex; graph-level measures as one line per measure.
Distinctions are carried by colour and line type together, never by
colour alone.

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

  `"line"` for trajectories over time, `"heatmap"` for a vertex-by-time
  tile plot, `"ridge"` for small multiples per measure.

- highlight:

  Optional character vector of vertex names to draw in colour, with
  everything else in grey. Useful when there are many vertices.

- top:

  Draw only the `top` vertices by mean value. `NULL` draws all.

- palette:

  Colours for the series: `"okabe"` (the default), `"extended"`,
  `"many"`, your own vector of colours, or a function of `n`.

- base_size:

  Base font size.

- ...:

  Ignored.

## Value

A `ggplot` object.

## Examples

``` r
dn <- dynet(school_contacts)
plot(dyn_centrality(dn, measure = "degree"), top = 5)

plot(dyn_centrality(dn, measure = "degree"), palette = "extended")

```
