# Remove temporal ties

Remove temporal ties

## Usage

``` r
remove_ties(
  dn,
  ties = NULL,
  from = NULL,
  to = NULL,
  start = NULL,
  end = NULL,
  session = NULL
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- ties:

  Which ties to remove: a condition on the spell table, evaluated the
  way [`subset()`](https://rdrr.io/r/base/subset.html) evaluates one –
  `duration > 2`, `course == "g1"` – over the columns
  `as.data.frame(dn)` returns, tie attributes included; or integer
  positions or a logical mask over that table.

- from, to, start, end, session:

  Optional selectors combined by conjunction. `start` and `end` match a
  spell's own boundary, compared with the package's magnitude-relative
  time tolerance rather than exactly, so a selector written `0.3` still
  matches a spell that accumulated as `0.1 + 0.1 + 0.1`. When `ties` is
  supplied, these selectors must be omitted. On undirected networks
  `from` and `to` must be supplied together and their order is ignored.

## Value

A new internally consistent `dynet` object, of the same class and
structure as the input, without the matched spells. At least one
temporal tie must remain. A request that matches nothing raises a
condition of class `dynet_tie_not_found`.

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "B"), to = c("B", "C"),
  start = c(0, 1), end = c(1, 2)
))
remove_ties(dn, ties = 1)
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 3 vertices | 1 edge spells | 1 distinct pairs
#> # observed from 1 to 2 step, binned every 1
#> 
#>  from to start end duration weight
#>     B  C     1   2        1      1
```
