# Summarise ranked pathways

Summarise ranked pathways

## Usage

``` r
# S3 method for class 'dynet_pathways'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_pathways` result.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per endpoint: `endpoint`, the number of
distinct `routes` reaching it, their summed `count` and `share`, the
`min_hops` of the shortest, and `first_arrival`, the earliest time any
route lands there. Ordered by count.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- pathways(dn, from = "Ana")
summary(routes)
#>    endpoint routes count      share min_hops first_arrival
#> 1       Ben      1     3 0.16666667        3          9.59
#> 2       Eve      1     3 0.16666667        4         11.66
#> 3      Kira      1     2 0.11111111        2          6.12
#> 4      Cara      1     1 0.05555556        1          6.67
#> 5       Dan      1     1 0.05555556        4          7.98
#> 6      Finn      1     1 0.05555556        2          6.96
#> 7      Gita      1     1 0.05555556        2          6.36
#> 8      Hugo      1     1 0.05555556        3          7.98
#> 9      Iris      1     1 0.05555556        3         10.00
#> 10    Jonas      1     1 0.05555556        1          2.12
#> 11      Leo      1     1 0.05555556        3          9.65
#> 12     Mira      1     1 0.05555556        1          6.36
#> 13     Nils      1     1 0.05555556        2          7.51
```
