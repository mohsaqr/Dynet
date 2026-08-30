# Remove directed temporal arcs

The same operation as
[`remove_ties()`](https://mohsaqr.github.io/Dynet/reference/remove_ties.md),
with one extra guarantee: the network must already be directed, so a
`from`/`to` pair names one arc and not both orientations. Removing an
arc from an undirected network raises a condition of class
`dynet_needs_directed`.

## Usage

``` r
remove_arcs(
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
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- ties:

  Optional integer positions or logical mask referring to the rows of
  `as.data.frame(dn, what = "edges")`.

- from, to, start, end, session:

  Optional selectors combined by conjunction. When `ties` is supplied,
  these selectors must be omitted. On undirected networks `from` and
  `to` must be supplied together and their order is ignored.

## Value

A new directed `dynet` object without the matched spells, with the same
structure as the input.

## See also

[`remove_ties()`](https://mohsaqr.github.io/Dynet/reference/remove_ties.md),
which does not require a directed network.

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "B"), to = c("B", "C"),
  start = c(0, 1), end = c(1, 2)
))
remove_arcs(dn, ties = 1)
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 3 vertices | 1 edge spells | 1 distinct pairs
#> # observed from 1 to 2 step, binned every 1
#> 
#>  from to start end duration weight
#>     B  C     1   2        1      1
```
