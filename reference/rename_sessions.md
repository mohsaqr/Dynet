# Rename session walls

Rename session walls

## Usage

``` r
rename_sessions(dn, mapping)
```

## Arguments

- dn:

  A sessioned temporal network.

- mapping:

  A named character vector from old to new labels, or an `old`/`new`
  data frame.

## Value

A new `dynet` object with edge and vertex session labels renamed.
