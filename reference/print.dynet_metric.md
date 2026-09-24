# Print a temporal measure

Print a temporal measure

## Usage

``` r
# S3 method for class 'dynet_metric'
print(x, n = 12L, ...)
```

## Arguments

- x:

  A `dynet_metric`.

- n:

  Number of rows to show. Defaults to twelve.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
dn <- dynet(school_contacts)
degree <- dyn_centrality(dn, step = 4, window = 4)
degree
#> # Degree (node-level)
#> # 14 vertices | 6 time points, 4 per bin | time in step
#>  time  node measure value
#>     0   Ana  degree     3
#>     0   Ben  degree     3
#>     0  Cara  degree     2
#>     0   Dan  degree     5
#>     0   Eve  degree     8
#>     0  Finn  degree     3
#>     0  Gita  degree     3
#>     0  Hugo  degree     2
#>     0  Iris  degree     5
#>     0 Jonas  degree     7
#>     0  Kira  degree     6
#>     0   Leo  degree     5
#> # 72 more rows. summary() aggregates them; plot() draws them.
print(degree, n = 4)
#> # Degree (node-level)
#> # 14 vertices | 6 time points, 4 per bin | time in step
#>  time node measure value
#>     0  Ana  degree     3
#>     0  Ben  degree     3
#>     0 Cara  degree     2
#>     0  Dan  degree     5
#> # 80 more rows. summary() aggregates them; plot() draws them.
```
