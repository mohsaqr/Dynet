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
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- ties:

  Optional integer positions or logical mask referring to the rows of
  `as.data.frame(dn, what = "edges")`.

- from, to, start, end, session:

  Optional selectors combined by conjunction. When `ties` is supplied,
  these selectors must be omitted. On undirected networks `from` and
  `to` must be supplied together and their order is ignored.

## Value

A new internally consistent `dynet` object. At least one temporal tie
must remain.

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
