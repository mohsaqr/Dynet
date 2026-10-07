# Tidy frame of a temporal motif census

Tidy frame of a temporal motif census

## Usage

``` r
# S3 method for class 'dynet_motifs'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `dynet_motifs` result.

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- ...:

  Ignored.

## Value

A plain `data.frame` carrying the same rows and columns as `x`: `motif`,
`family`, `pattern` and `count`, preceded by `node` for a local census
and by `session` when the census is session-local.
