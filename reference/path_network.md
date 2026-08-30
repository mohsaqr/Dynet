# Build the union network of optimal temporal paths

[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md) uses an
endpoint-local foremost-then-shortest criterion, so its routes need not
form one predecessor tree. This function therefore returns the honest
union of all expanded optimal route hops. Edge `weight` is the number of
endpoint/path families using the hop; `first_time` and `last_time`
retain its temporal range.

## Usage

``` r
path_network(x)
```

## Arguments

- x:

  A result from
  [`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md).

## Value

A static `dynet_path_network` cograph netobject, whose two tidy tables
are reached with `as.data.frame(x, what = "edges")` and
`as.data.frame(x, what = "nodes")`. The edge table has one row per hop
used by at least one optimal route, with `from`, `to`, `weight` (how
many endpoint/path families use the hop), `first_time` and `last_time`
(the hop's temporal range) and `n_endpoints` (how many distinct
endpoints it serves). The node table has one row per vertex the source
actually reaches, the source included, with `name`, `arrival_time`,
`latency`, `n_hops`, `n_paths` and `groups` (hop count as a grouping
label for plotting). Unreachable vertices are absent, not present with
`NA`.
