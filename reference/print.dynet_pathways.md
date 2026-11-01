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

`x`, invisibly. Called for the side effect of printing a header giving
the number of distinct routes and of optimal routes counted, followed by
the first `n` rows.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- pathways(dn, from = "Ana")
print(routes)
#> # Time-respecting pathways (13 distinct routes)
#> # 18 optimal routes counted
#>                               route endpoint count      share n_hops
#>         Ana -> Jonas -> Kira -> Ben      Ben     3 0.16666667      3
#>  Ana -> Jonas -> Kira -> Ben -> Eve      Eve     3 0.16666667      4
#>                Ana -> Jonas -> Kira     Kira     2 0.11111111      2
#>                         Ana -> Cara     Cara     1 0.05555556      1
#>                        Ana -> Jonas    Jonas     1 0.05555556      1
#>                         Ana -> Mira     Mira     1 0.05555556      1
#>                 Ana -> Cara -> Finn     Finn     1 0.05555556      2
#>                 Ana -> Cara -> Nils     Nils     1 0.05555556      2
#>                 Ana -> Mira -> Gita     Gita     1 0.05555556      2
#>         Ana -> Cara -> Finn -> Iris     Iris     1 0.05555556      3
#>          Ana -> Cara -> Finn -> Leo      Leo     1 0.05555556      3
#>         Ana -> Cara -> Nils -> Hugo     Hugo     1 0.05555556      3
#>  arrival_time
#>          9.59
#>         11.66
#>          6.12
#>          6.67
#>          2.12
#>          6.36
#>          6.96
#>          7.51
#>          6.36
#>         10.00
#>          9.65
#>          7.98
#> # 1 more of the 13 kept. Use top = to keep a different number.
```
