# Draw optimal temporal paths as a trajectory tree

Draws the optimal route family returned by
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md) using
the trajectory-tree grammar ported from the `transitiontrees` package:
leaves stacked in depth-first order, parents centred on their children,
and branches carried by a cosine smoothstep. Nodes follow that package's
horizontal phylogram rather than its capsule style – a count-sized
filled circle with its label set below it. Branch width always shows how
many optimal routes use a branch; node fill shows the chosen `measure`,
and every node also prints its value, so nothing is encoded by colour
alone.

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
  base_size = 11
)
```

## Arguments

- x:

  A result from
  [`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md) or
  from
  [`path_trajectories()`](https://mohsaqr.github.io/Dynet/reference/path_trajectories.md).

- measure:

  Node fill. `"frequency"` is the number of optimal routes through the
  branch, `"time"` is the attained time at the node, and
  `"predictability"` is the branching fraction of the parent's routes
  that continue along the branch.

- orientation:

  `"horizontal"` grows the tree left to right with hop number on the x
  axis; `"vertical"` grows it top to bottom.

- min_count:

  Draw only branches used by at least this many optimal routes. Ignored
  when `x` is already a
  [`path_trajectories()`](https://mohsaqr.github.io/Dynet/reference/path_trajectories.md)
  result.

- base_size:

  Base text size.

## Value

A `ggplot` object.

## See also

[`path_trajectories()`](https://mohsaqr.github.io/Dynet/reference/path_trajectories.md)
for the tidy tree behind the plot.

## Examples

``` r
dn <- dynet(school_contacts)
paths <- paths(dn, from = "Ana")
plot_path_trajectories(paths)

plot_path_trajectories(paths, measure = "time", orientation = "vertical")
```
