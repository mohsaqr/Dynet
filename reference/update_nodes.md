# Update static node attributes

Update static node attributes

## Usage

``` r
update_nodes(dn, data)
```

## Arguments

- dn:

  A temporal network.

- data:

  A nonempty data frame with a `name` key and one or more attributes to
  add or replace. Only named nodes are changed.

## Value

A new internally consistent `dynet` object.

## Examples

``` r
dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
update_nodes(dn, data.frame(name = "A", role = "initiator"))
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 2 vertices | 1 edge spells | 1 distinct pairs
#> # observed from 0 to 1 step, binned every 1
#> # vertex attributes: role
#> 
#>  from to start end duration weight
#>     A  B     0   1        1      1
```
