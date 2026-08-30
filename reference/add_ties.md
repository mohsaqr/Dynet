# Add temporal ties

Add temporal ties

## Usage

``` r
add_ties(dn, data, loops = FALSE)
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

A new `dynet` object. The input is unchanged; canonical temporal ties
and every flattened cograph field are rebuilt together.

## Details

Added times use the existing network clock. A sessioned network requires
an existing session label on every row; mutation does not create a new
session scheme. Implicit observation support expands to include the new
raw ties, while explicit observation support remains fixed. Added raw
rows are interval-format tie identities even when the source was
originally a contact, threaded, or co-presence log.

## Examples

``` r
dn <- dynet(data.frame(
  from = "A", to = "B", start = 0, end = 1
))
dn <- add_nodes(dn, "C")
add_ties(dn, data.frame(from = "B", to = "C", start = 1, end = 2))
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 3 vertices | 2 edge spells | 2 distinct pairs
#> # observed from 0 to 2 step, binned every 1
#> 
#>  from to start end duration weight
#>     A  B     0   1        1      1
#>     B  C     1   2        1      1
```
