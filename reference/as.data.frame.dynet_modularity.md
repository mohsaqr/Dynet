# Tidy data frame of a multislice modularity result

Tidy data frame of a multislice modularity result

## Usage

``` r
# S3 method for class 'dynet_modularity'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("total", "bins"),
  ...
)
```

## Arguments

- x:

  A `dynet_modularity` from
  [`multislice_modularity()`](https://pak.dynasite.org/Dynet/reference/multislice_modularity.md).

- row.names, optional:

  Ignored, for method consistency.

- what:

  `"total"` for the whole-series decomposition, or `"bins"` for one row
  per slice: that slice's own Newman–Girvan modularity `q`, its edge
  total `two_m`, and `n_communities`, the number of communities with a
  member in it.

- ...:

  Passed on for `what = "total"`.

## Value

A plain data frame.
