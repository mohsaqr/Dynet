# Summarise a temporal motif census by family

Summarise a temporal motif census by family

## Usage

``` r
# S3 method for class 'dynet_motifs'
summary(object, by = c("family", "node"), ...)
```

## Arguments

- object:

  A `dynet_motifs` result.

- by:

  `"family"`, the default, or `"node"` for a local census.

- ...:

  Ignored.

## Value

A plain `data.frame` with one row per group: the group, its `count`, its
`share` of all instances, and the `top_motif` index within it.
