# Add nodes to a temporal network

Add nodes to a temporal network

## Usage

``` r
add_nodes(dn, data)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- data:

  A character vector of new node names or a data frame containing a
  `name` column and optional static attributes.

## Value

A new `dynet` object with the added nodes represented as implicit
always-active isolates until ties or vertex activity are supplied.

## Details

Existing nodes and attributes are unchanged. Missing attribute values
are filled with typed `NA`. If the source has a cograph grouping, each
new node must supply its group through `groups` or through the source
attribute from which that grouping was derived.

## Examples

``` r
dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
add_nodes(dn, "C")
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 3 vertices | 1 edge spells | 1 distinct pairs
#> # observed from 0 to 1 step, binned every 1
#> 
#>  from to start end duration weight
#>     A  B     0   1        1      1
```
