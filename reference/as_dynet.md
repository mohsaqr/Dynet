# Convert an object to a Dynet temporal network

Imports a temporal network held in another R representation, so that
every Dynet verb applies to it. A method is supplied for
`networkDynamic` objects; the method for `dynet` is the identity.

## Usage

``` r
as_dynet(x, ...)

# S3 method for class 'dynet'
as_dynet(x, ...)
```

## Arguments

- x:

  An object representing a temporal network.

- ...:

  Passed to a class-specific method.

## Value

A [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md)
temporal network: an object of class
`c("dynet", "netobject", "cograph_network")` carrying the tie ledger,
the node table and the construction metadata. The `dynet` method is the
identity, returning `x` unchanged, so `as_dynet()` is safe to call on an
object that is already a temporal network.

## See also

[`as_dynet.networkDynamic()`](https://pak.dynasite.org/Dynet/reference/as_dynet.networkDynamic.md),
which imports a `networkDynamic` object.

## Examples

``` r
dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
as_dynet(dn)
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 2 vertices | 1 edge spells | 1 distinct pairs
#> # observed from 0 to 1 step, binned every 1
#> 
#>  from to start end duration weight
#>     A  B     0   1        1      1
dn <- dynet(school_contacts)
same <- as_dynet(dn)
same
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 14 vertices | 240 edge spells | 110 distinct pairs
#> # observed from 0 to 21.52 step, binned every 1
#> 
#>   from   to start  end duration weight
#>  Jonas  Dan  0.00 1.10     1.10      1
#>   Gita  Ana  0.14 0.98     0.84      1
#>    Leo Mira  0.15 0.42     0.27      1
#>    Leo Iris  0.15 0.96     0.81      1
#>   Kira  Ben  0.33 0.69     0.36      1
#>    Leo Iris  0.38 0.50     0.12      1
#> # 234 more spells. summary() describes the network; plot() draws it.
```
