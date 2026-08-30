# Add directed temporal arcs

The same operation as
[`add_ties()`](https://mohsaqr.github.io/Dynet/reference/add_ties.md),
with one extra guarantee: the network must already be directed, so
`from` and `to` keep the direction the caller means. Adding an arc to an
undirected network raises a condition of class `dynet_needs_directed`
rather than silently recording a symmetric tie.

## Usage

``` r
add_arcs(dn, data, loops = FALSE)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- data:

  A nonempty data frame with `from`, `to`, `start`, and `end`. Optional
  columns are `weight`, `session`, `onset_censored`, and
  `terminus_censored`. Endpoints must already exist in `dn`.

- loops:

  Whether added self-loops are permitted.

## Value

A new directed `dynet` object carrying the added spells, with the same
structure as the input.

## See also

[`add_ties()`](https://mohsaqr.github.io/Dynet/reference/add_ties.md),
which does not require a directed network.

## Examples

``` r
dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
dn <- add_nodes(dn, "C")
add_arcs(dn, data.frame(from = "B", to = "C", start = 1, end = 2))
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 3 vertices | 2 edge spells | 2 distinct pairs
#> # observed from 0 to 2 step, binned every 1
#> 
#>  from to start end duration weight
#>     A  B     0   1        1      1
#>     B  C     1   2        1      1
```
