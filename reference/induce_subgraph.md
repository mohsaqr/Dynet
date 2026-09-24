# Extract an induced temporal subgraph

Extract an induced temporal subgraph

## Usage

``` r
induce_subgraph(dn, nodes = NULL, ties = NULL, keep_isolates = FALSE)
```

## Arguments

- dn:

  A temporal network.

- nodes:

  Which vertices to keep. Either a condition on the vertex table,
  evaluated the way [`subset()`](https://rdrr.io/r/base/subset.html)
  evaluates one – `degree > 20`, `room == "A" & betweenness > 0` – with
  any centrality it names computed over the whole observed period; or a
  character vector of names, a factor, a logical mask, or any data frame
  carrying a `name` or `node` column. Only ties whose two endpoints are
  in this set are eligible. Default `NULL`, meaning every vertex.

- ties:

  Which ties to keep. Either a condition on the spell table, evaluated
  the way [`subset()`](https://rdrr.io/r/base/subset.html) evaluates one
  – `course == "g1"`, `duration > 2 & weight >= 1` – over the columns
  `as.data.frame(dn)` returns, tie attributes included; or integer row
  positions or a logical mask over that same table, in that order, a
  mask having exactly as many elements as there are spells. Default
  `NULL`, meaning every tie. At least one of `nodes` and `ties` must be
  supplied.

- keep_isolates:

  Whether named nodes without a selected tie remain. Default `FALSE`; it
  has an effect only when `nodes` is supplied.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, carrying only the selected
spells, the vertices they touch (plus any isolate named in `nodes` when
`keep_isolates = TRUE`), those vertices' activity spells, and all static
node and tie attributes. Metadata is rebuilt, so the observed range and
the canonical spell identifiers describe the subgraph, not the parent.
Raises `dynet_unknown_node` for a name that is not a vertex,
`dynet_empty_network` when the selection leaves no vertex or no tie, and
`dynet_bad_input` when neither `nodes` nor `ties` is supplied or a
selection is malformed.

## Examples

``` r
dn <- dynet(school_contacts)

# A condition on the vertex table, in one call.
induce_subgraph(dn, degree > 16)
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 5 vertices | 31 edge spells | 14 distinct pairs
#> # observed from 0 to 20.46 step, binned every 1
#> 
#>   from    to start  end duration weight
#>  Jonas   Dan  0.00 1.10     1.10      1
#>    Eve  Kira  0.77 1.42     0.65      1
#>   Kira   Eve  1.95 2.47     0.52      1
#>  Jonas  Kira  2.05 2.09     0.04      1
#>    Dan Jonas  3.14 3.49     0.35      1
#>    Dan   Eve  3.20 3.33     0.13      1
#> # 25 more spells. summary() describes the network; plot() draws it.

# Names still work, as does anything carrying them.
induce_subgraph(dn, nodes = c("Ana", "Ben", "Cara"))
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 3 vertices | 3 edge spells | 3 distinct pairs
#> # observed from 6.67 to 20.33 step, binned every 1
#> 
#>  from   to start   end duration weight
#>   Ana Cara  6.67  6.77     0.10      1
#>  Cara  Ben 16.84 17.09     0.25      1
#>  Cara  Ana 19.70 20.33     0.63      1
```
