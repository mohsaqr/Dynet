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
  `as.data.frame(dn, what = "vertex_spells")`. A logical mask must have
  one element per declared component and no `NA`.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, with the selected activity
components dropped and the rest canonicalised again, so the remaining
spell identifiers renumber. A node with no remaining declaration becomes
implicitly always active over observation support. Raises
`dynet_bad_input` when `spells` is not a valid selection.

## Examples

``` r
dn <- dynet(school_contacts)
present <- data.frame(node = c("Ana", "Ben"), start = 0, end = 10)
enrolled <- set_vertex_spells(dn, present)
trimmed <- remove_vertex_spells(enrolled, spells = 1)
as.data.frame(trimmed, what = "vertex_spells")
#>   vertex_spell node start end duration instant session onset_censored
#> 1            1  Ben     0  10       10   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
```
