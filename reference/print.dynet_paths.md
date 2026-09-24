# Print time-respecting paths

Print time-respecting paths

## Usage

``` r
# S3 method for class 'dynet_paths'
print(x, n = 12L, ...)
```

## Arguments

- x:

  A `dynet_paths` from
  [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md).

- n:

  Number of rows to show. Defaults to twelve.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- paths(dn, from = "Ana")
routes
#> # Time-respecting paths from ‘Ana’, from t = 0
#> # reaches 13 of 13 other vertices | time in step
#>   node reachable arrival_time attained latency n_hops n_paths
#>    Ana      TRUE         0.00     TRUE    0.00      0       1
#>    Ben      TRUE         9.59     TRUE    9.59      3       3
#>   Cara      TRUE         6.67     TRUE    6.67      1       1
#>    Dan      TRUE         7.98     TRUE    7.98      4       1
#>    Eve      TRUE        11.66     TRUE   11.66      4       3
#>   Finn      TRUE         6.96     TRUE    6.96      2       1
#>   Gita      TRUE         6.36     TRUE    6.36      2       1
#>   Hugo      TRUE         7.98     TRUE    7.98      3       1
#>   Iris      TRUE        10.00     TRUE   10.00      3       1
#>  Jonas      TRUE         2.12     TRUE    2.12      1       1
#>   Kira      TRUE         6.12     TRUE    6.12      2       2
#>    Leo      TRUE         9.65     TRUE    9.65      3       1
#> # 2 more rows. summary() aggregates them; plot() draws the tree.
print(routes, n = 4)
#> # Time-respecting paths from ‘Ana’, from t = 0
#> # reaches 13 of 13 other vertices | time in step
#>  node reachable arrival_time attained latency n_hops n_paths
#>   Ana      TRUE         0.00     TRUE    0.00      0       1
#>   Ben      TRUE         9.59     TRUE    9.59      3       3
#>  Cara      TRUE         6.67     TRUE    6.67      1       1
#>   Dan      TRUE         7.98     TRUE    7.98      4       1
#> # 10 more rows. summary() aggregates them; plot() draws the tree.
```
