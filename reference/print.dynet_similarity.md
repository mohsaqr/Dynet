# Print time-bin similarity

Print time-bin similarity

## Usage

``` r
# S3 method for class 'dynet_similarity'
print(x, ...)
```

## Arguments

- x:

  A result from
  [`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md).

- ...:

  Passed to the data frame print method.

## Value

`x`, invisibly.

## Examples

``` r
dn <- dynet(school_contacts)
resemblance <- similarity(dn, step = 4, window = 4)
resemblance
#> # jaccard similarity across 6 time bins
#> # off-diagonal mean 0.172, range 0.063 to 0.338
#>    time other measure     value
#> 1     0     0 jaccard 1.0000000
#> 2     0     4 jaccard 0.1791045
#> 3     0     8 jaccard 0.1562500
#> 4     0    12 jaccard 0.1428571
#> 5     0    16 jaccard 0.1041667
#> 6     0    20 jaccard 0.0952381
#> 7     4     0 jaccard 0.1791045
#> 8     4     4 jaccard 1.0000000
#> 9     4     8 jaccard 0.3380282
#> 10    4    12 jaccard 0.2625000
#> # 26 more rows
```
