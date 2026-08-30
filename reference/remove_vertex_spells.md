# Remove declared vertex-activity components

Remove declared vertex-activity components

## Usage

``` r
remove_vertex_spells(dn, spells)
```

## Arguments

- dn:

  A temporal network.

- spells:

  Integer positions or a logical mask over
  `as.data.frame(dn, what = "vertex_spells")`.

## Value

A new `dynet` object. A node with no remaining declaration becomes
implicitly always active over observation support.
