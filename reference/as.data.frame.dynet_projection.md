# Tidy tables from a time-projected network

Tidy tables from a time-projected network

## Usage

``` r
# S3 method for class 'dynet_projection'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("vertices", "edges"),
  ...
)
```

## Arguments

- x:

  A projection returned by
  [`projection()`](https://mohsaqr.github.io/Dynet/reference/projection.md).

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- what:

  `"vertices"` returns vertex-time states and `"edges"` returns directed
  within-slice and identity arcs.

- ...:

  Ignored.

## Value

A plain data frame. Vertex rows contain `state`, optional `session` and
`observation`, `slice`, `time`, `start`, `end`, `closed`, `node`,
`active`, and copied node attributes. Edge rows contain `from_state`,
`to_state`, `from_node`, `to_node`, optional `session`, `from_slice`,
`to_slice`, `from_time`, `to_time`, `edge_type`, `weight`, `n_spells`,
and `lag`.
