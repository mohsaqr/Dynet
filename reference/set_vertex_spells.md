# Replace declared vertex activity

Replace declared vertex activity

## Usage

``` r
set_vertex_spells(dn, data = NULL)
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

A new `dynet` object. Overlapping or adjacent spells are canonicalized
exactly as in
[`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).
Canonical spell identifiers may therefore change.
