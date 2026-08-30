# Tidy tables from a collapsed temporal network

Tidy tables from a collapsed temporal network

## Usage

``` r
# S3 method for class 'dynet_collapsed'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("edges", "nodes"),
  ...
)
```

## Arguments

- x:

  A network returned by
  [`collapse_network()`](https://mohsaqr.github.io/Dynet/reference/collapse_network.md).

- row.names, optional:

  Ignored; present for compatibility.

- what:

  `"edges"` or `"nodes"`.

- ...:

  Ignored.

## Value

A plain `data.frame`. For `"edges"`, one row per collapsed vertex pair
carrying every weighting side by side: `from`, `to`, `binary`,
`union_duration`, `total_duration`, `duration_fraction`, `spell_count`,
`weight_sum`, `weighted_duration`, `latest_weight`, `first`, `last`, and
the `activity.duration` and `activity.count` aliases. For `"nodes"`, one
row per vertex with `name`, `activity_duration` and its
`activity.duration` alias, plus any static vertex attributes the network
carries. See
[`collapse_network()`](https://mohsaqr.github.io/Dynet/reference/collapse_network.md)
for what each weighting means.
