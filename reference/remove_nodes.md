# Remove nodes from a temporal network

Remove nodes from a temporal network

## Usage

``` r
remove_nodes(dn, nodes, cascade = FALSE)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- nodes:

  Character node names.

- cascade:

  Whether to remove every incident temporal tie and vertex activity
  spell. The safe default rejects nodes that are not isolates.

## Value

A new internally consistent `dynet` object.

## Examples

``` r
dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
dn <- add_nodes(dn, "C")
remove_nodes(dn, "C")
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 2 vertices | 1 edge spells | 1 distinct pairs
#> # observed from 0 to 1 step, binned every 1
#> 
#>  from to start end duration weight
#>     A  B     0   1        1      1
```
