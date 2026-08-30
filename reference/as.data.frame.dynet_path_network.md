# Tidy tables from a temporal path-union network

Tidy tables from a temporal path-union network

## Usage

``` r
# S3 method for class 'dynet_path_network'
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
  [`path_network()`](https://mohsaqr.github.io/Dynet/reference/path_network.md).

- row.names, optional:

  Ignored.

- what:

  `"edges"` or `"nodes"`.

- ...:

  Ignored.

## Value

A plain `data.frame`. For `"edges"`, one row per hop used by an optimal
route, with `from`, `to`, `weight`, `first_time`, `last_time` and
`n_endpoints`. For `"nodes"`, one row per reached vertex, with `name`,
`arrival_time`, `latency`, `n_hops`, `n_paths` and `groups`. See
[`path_network()`](https://mohsaqr.github.io/Dynet/reference/path_network.md)
for what each column means.
