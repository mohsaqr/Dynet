# Tidy data frame of a temporal community partition

Tidy data frame of a temporal community partition

## Usage

``` r
# S3 method for class 'dynet_communities'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("membership", "sizes", "runs", "events"),
  ...
)
```

## Arguments

- x:

  A `dynet_communities` frame.

- row.names, optional:

  Ignored, for method consistency.

- what:

  `"membership"` for the frame itself, `"sizes"` for one row per
  community per bin, `"runs"` for the modularity each seed reached, or
  `"events"` for the lifecycle table after
  [`match_communities()`](https://pak.dynasite.org/Dynet/reference/match_communities.md).

- ...:

  Ignored.

## Value

A plain data frame.
