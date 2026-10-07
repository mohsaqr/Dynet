# Tidy data frame of community trajectories

Tidy data frame of community trajectories

## Usage

``` r
# S3 method for class 'dynet_trajectory'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("node", "time", "global", "allegiance"),
  ...
)
```

## Arguments

- x:

  A `dynet_trajectory` from
  [`community_trajectory()`](https://pak.dynasite.org/Dynet/reference/community_trajectory.md).

- row.names, optional:

  Ignored, for method consistency.

- what:

  `"node"` for one row per vertex per measure, `"time"` for persistence
  per bin, `"global"` for persistence over the whole series, or
  `"allegiance"` for one row per ordered vertex pair.

- ...:

  Ignored.

## Value

A plain data frame.
