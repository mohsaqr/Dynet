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

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, with the same spells,
vertex activity and metadata as `dn` and the supplied attributes added
to or replaced on the named vertices. Unnamed vertices keep their
existing values, gaining `NA` in any column the network did not already
have. Raises `dynet_unknown_node` when a name is not a vertex, and
`dynet_bad_input` when `data` is malformed or names a cograph structural
column (`id`, `label`, `x`, `y`).

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
