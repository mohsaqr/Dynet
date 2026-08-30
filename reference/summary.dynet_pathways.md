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
summary(pathways(dynet(school_contacts), from = "Ana"))
#>   endpoint routes count     share min_hops first_arrival
#> 1      Eve      1     3 0.4285714        4         11.66
#> 2      Dan      1     1 0.1428571        4          7.98
#> 3     Gita      1     1 0.1428571        2          6.36
#> 4     Iris      1     1 0.1428571        3         10.00
#> 5      Leo      1     1 0.1428571        3          9.65
```
