# Rename nodes everywhere in a temporal network

Rename nodes everywhere in a temporal network

## Usage

``` r
rename_nodes(dn, mapping)
```

## Arguments

- dn:

  A temporal network.

- mapping:

  A named character vector whose names are old node names and values are
  replacements, or a two-column data frame named `old` and `new`.

## Value

A new `dynet` object with edge endpoints, node attributes, vertex
activity, cograph labels, and groups renamed together.
