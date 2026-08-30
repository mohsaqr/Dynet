# Add declared vertex-activity spells

Add declared vertex-activity spells

## Usage

``` r
add_vertex_spells(dn, data)
```

## Arguments

- dn:

  A temporal network.

- data:

  A vertex-spell data frame with `node`, `start`, and `end`, plus
  optional `session`, `onset_censored`, and `terminus_censored`. `NULL`
  clears explicit activity, making every retained node implicitly
  active.

## Value

A new `dynet` object with old and new activity canonicalized together.
