# Draw optimal temporal paths as a trajectory tree

Draws the optimal route family returned by
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) using the
trajectory-tree grammar ported from the `transitiontrees` package:
leaves stacked in depth-first order, parents centred on their children,
and branches carried by a cosine smoothstep. Nodes follow that package's
horizontal phylogram rather than its capsule style – a count-sized
filled circle with its label set below it. Node size and branch width
always show how many optimal routes use a branch. Every node also prints
the value of the chosen `measure` beside its vertex name, so nothing is
encoded by colour alone: the default frequency view is free to fill each
node with its vertex's own colour, while the `"time"` and
`"predictability"` views fill from a ramp with a colour bar.

Forward paths grow away from the queried source. Backward paths are
flipped so the queried target is the root and possible senders branch
away from it. A named vertex repeats whenever it is reached under a
different temporal history.

## Usage

``` r
plot_path_trajectories(
  x,
  measure = c("frequency", "time", "predictability"),
  orientation = c("horizontal", "vertical"),
  min_count = 1L,
  base_size = 11,
  palette = "okabe"
)
```

## Arguments

- x:

  A result from
  [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) or from
  [`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md).

- measure:

  What each node reports, and what fills it. `"frequency"`, the default,
  is the number of optimal routes through the branch and fills by
  vertex, since node size already carries the count; `"time"` is the
  attained time at the node and `"predictability"` the branching
  fraction of the parent's routes that continue along the branch, both
  filled from a ramp.

- orientation:

  `"horizontal"` grows the tree left to right with hop number on the x
  axis; `"vertical"` grows it top to bottom.

- min_count:

  Draw only branches used by at least this many optimal routes. Defaults
  to `1`, the complete family. Ignored when `x` is already a
  [`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
  result.

- base_size:

  Base text size, as in
  [`ggplot2::theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html).
  Defaults to eleven.

- palette:

  Palette for the vertex colours of the frequency view, as in
  [`plot.dynet()`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md).
  Defaults to `"okabe"`.

## Value

A `ggplot` object. A tree with no branch to draw raises
`dynet_empty_result`; an `x` that is neither a
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) nor a
[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
result, or a `base_size` that is not one positive number, raises
`dynet_bad_input`.

## See also

[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
for the tidy tree behind the plot.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- paths(dn, from = "Ana")
plot_path_trajectories(routes)

plot_path_trajectories(routes, measure = "time", orientation = "vertical")
```
