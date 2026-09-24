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

  Integer positions or a logical mask over canonical vertex activity, as
  returned by `as.data.frame(dn, what = "vertex_spells")`.

- data:

  A data frame with one row, or one row per selected component,
  containing the fields to replace: `node`, `start`, `end`, `session`,
  `onset_censored` or `terminus_censored`. Any other column name raises
  `dynet_unknown_column`, so a misspelled field is refused rather than
  quietly doing nothing.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`. Updated components are
canonicalised with the retained components, so overlaps can merge and
spell identifiers can change. Raises `dynet_bad_input` when `spells` is
not a valid selection, when `data` is malformed or of the wrong height,
or when it names the read-only derived columns `vertex_spell`,
`duration` or `instant`.

## Examples

``` r
dn <- dynet(school_contacts)
present <- data.frame(node = c("Ana", "Ben"), start = 0, end = 10)
enrolled <- set_vertex_spells(dn, present)
extended <- update_vertex_spells(enrolled, spells = 1,
                                 data = data.frame(end = 12))
as.data.frame(extended, what = "vertex_spells")
#>   vertex_spell node start end duration instant session onset_censored
#> 1            1  Ana     0  12       12   FALSE    <NA>          FALSE
#> 2            2  Ben     0  10       10   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE
```
