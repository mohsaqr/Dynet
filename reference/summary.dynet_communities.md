# Summarize a temporal community partition

Summarize a temporal community partition

## Usage

``` r
# S3 method for class 'dynet_communities'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_communities` frame.

- ...:

  Ignored.

## Value

A data frame with one row per community: `community`, `n_states`,
`n_nodes`, `first_time`, `last_time`, `n_bins` and `persistence`, the
share of the bins it spans in which it is actually present.
