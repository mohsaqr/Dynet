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
  optional `session`, `onset_censored`, and `terminus_censored`; or the
  string `"ties"`, which declares each vertex present from the start of
  its first tie spell to the end of its last, so that a vertex is absent
  before it has had a tie and after it has had its last. Default `NULL`,
  which clears explicit activity, making every retained node implicitly
  active over observation support.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, whose declared vertex
activity is exactly `data` and whose edge spells, node attributes and
metadata are those of `dn`. Overlapping or adjacent spells are
canonicalised exactly as in
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md), so
canonical spell identifiers may change. Read the result back with
`as.data.frame(x, what = "vertex_spells")`. Raises `dynet_unknown_node`
when `data` names a vertex the network does not have, and
`dynet_bad_input` for a string other than `"ties"`.

## Examples

``` r
dn <- dynet(school_contacts)
present <- data.frame(node = c("Ana", "Ben"), start = 0, end = 10)
enrolled <- set_vertex_spells(dn, present)
as.data.frame(enrolled, what = "vertex_spells")
#>   vertex_spell node start end duration instant session onset_censored
#> 1            1  Ana     0  10       10   FALSE    <NA>          FALSE
#> 2            2  Ben     0  10       10   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE

# Present from the first contact to the last, vertex by vertex.
spanned <- set_vertex_spells(dn, "ties")
as.data.frame(spanned, what = "vertex_spells")
#>    vertex_spell  node start   end duration instant session onset_censored
#> 1             1   Ana  0.14 21.52    21.38   FALSE    <NA>          FALSE
#> 2             2   Ben  0.33 20.81    20.48   FALSE    <NA>          FALSE
#> 3             3  Cara  0.78 20.91    20.13   FALSE    <NA>          FALSE
#> 4             4   Dan  0.00 21.33    21.33   FALSE    <NA>          FALSE
#> 5             5   Eve  0.43 21.12    20.69   FALSE    <NA>          FALSE
#> 6             6  Finn  0.83 20.26    19.43   FALSE    <NA>          FALSE
#> 7             7  Gita  0.14 20.75    20.61   FALSE    <NA>          FALSE
#> 8             8  Hugo  0.43 21.38    20.95   FALSE    <NA>          FALSE
#> 9             9  Iris  0.15 20.41    20.26   FALSE    <NA>          FALSE
#> 10           10 Jonas  0.00 20.81    20.81   FALSE    <NA>          FALSE
#> 11           11  Kira  0.33 21.38    21.05   FALSE    <NA>          FALSE
#> 12           12   Leo  0.15 21.52    21.37   FALSE    <NA>          FALSE
#> 13           13  Mira  0.15 20.78    20.63   FALSE    <NA>          FALSE
#> 14           14  Nils  2.07 21.03    18.96   FALSE    <NA>          FALSE
#>    terminus_censored
#> 1              FALSE
#> 2              FALSE
#> 3              FALSE
#> 4              FALSE
#> 5              FALSE
#> 6              FALSE
#> 7              FALSE
#> 8              FALSE
#> 9              FALSE
#> 10             FALSE
#> 11             FALSE
#> 12             FALSE
#> 13             FALSE
#> 14             FALSE
```
