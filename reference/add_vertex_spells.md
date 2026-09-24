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

  A nonempty vertex-spell data frame with `node`, `start`, and `end`,
  plus optional `session`, `onset_censored`, and `terminus_censored`.
  Unlike
  [`set_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/set_vertex_spells.md)
  this argument is required; `NULL` is an error.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, with the network's
existing activity and `data` canonicalised together, so an added spell
that overlaps or abuts an existing one for the same vertex is merged
into it and canonical spell identifiers may change. Raises
`dynet_unknown_node` for a vertex the network does not have, and
`dynet_bad_input` when `data` is not a nonempty data frame, and
`dynet_incompatible_vertex_spells` when `session` is supplied to a
network with no session scheme – the same refusal
[`update_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/update_vertex_spells.md)
makes, rather than dropping the label.

## Examples

``` r
dn <- dynet(school_contacts)
present <- data.frame(node = c("Ana", "Ben"), start = 0, end = 10)
enrolled <- set_vertex_spells(dn, present)
extended <- add_vertex_spells(enrolled,
                              data.frame(node = "Cara", start = 5, end = 20))
as.data.frame(extended, what = "vertex_spells")
#>   vertex_spell node start end duration instant session onset_censored
#> 1            1  Ana     0  10       10   FALSE    <NA>          FALSE
#> 2            2  Ben     0  10       10   FALSE    <NA>          FALSE
#> 3            3 Cara     5  20       15   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE
#> 3             FALSE
```
