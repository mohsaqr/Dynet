# Update declared vertex-activity components

Update declared vertex-activity components

## Usage

``` r
update_vertex_spells(dn, spells, data)
```

## Arguments

- dn:

  A temporal network.

- spells:

  Integer positions or a logical mask over canonical vertex activity.

- data:

  One row or one row per selected component, containing fields to
  replace.

## Value

A new `dynet` object. Updated components are canonicalized with the
retained components, so overlaps can merge and identifiers can change.
