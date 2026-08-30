# Print ranked pathways

Print ranked pathways

## Usage

``` r
# S3 method for class 'dynet_pathways'
print(x, n = 12L, ...)
```

## Arguments

- x:

  A `dynet_pathways` result.

- n:

  Number of routes to show. Defaults to twelve.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
pathways(dynet(school_contacts), from = "Ana")
#> # Time-respecting pathways (5 distinct routes)
#> # 7 optimal routes counted
#>                               route endpoint count     share n_hops
#>  Ana -> Jonas -> Kira -> Ben -> Eve      Eve     3 0.4285714      4
#>                 Ana -> Mira -> Gita     Gita     1 0.1428571      2
#>         Ana -> Cara -> Finn -> Iris     Iris     1 0.1428571      3
#>          Ana -> Cara -> Finn -> Leo      Leo     1 0.1428571      3
#>  Ana -> Cara -> Nils -> Hugo -> Dan      Dan     1 0.1428571      4
#>  arrival_time
#>         11.66
#>          6.36
#>         10.00
#>          9.65
#>          7.98
```
