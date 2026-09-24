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
  replacements, a two-column data frame named `old` and `new`, or the
  name of one vertex attribute (given through `dynet(nodes = )`) whose
  values become the node names. The attribute must be complete and
  unique.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, with edge endpoints, node
attributes, vertex activity, cograph labels, and groups renamed
together. Raises `dynet_unknown_node` when an old name is not a vertex,
`dynet_duplicate_node` when a replacement collides with a name that is
being kept, `dynet_unknown_attribute` when `mapping` names a column that
is not a vertex attribute, and `dynet_bad_input` otherwise.

## Examples

``` r
dn <- dynet(school_contacts)
renamed <- rename_nodes(dn, c(Ana = "Anna", Ben = "Benjamin"))
renamed
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 14 vertices | 240 edge spells | 110 distinct pairs
#> # observed from 0 to 21.52 step, binned every 1
#> 
#>   from       to start  end duration weight
#>  Jonas      Dan  0.00 1.10     1.10      1
#>   Gita     Anna  0.14 0.98     0.84      1
#>    Leo     Mira  0.15 0.42     0.27      1
#>    Leo     Iris  0.15 0.96     0.81      1
#>   Kira Benjamin  0.33 0.69     0.36      1
#>    Leo     Iris  0.38 0.50     0.12      1
#> # 234 more spells. summary() describes the network; plot() draws it.
```
