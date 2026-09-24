# Tidy table of time-bin similarity

Tidy table of time-bin similarity

## Usage

``` r
# S3 method for class 'dynet_similarity'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A result from
  [`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md).

- row.names, optional:

  Ignored; present for compatibility with the generic.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per ordered pair of time bins, with
columns `time`, `other`, `measure` and `value`.

## Examples

``` r
dn <- dynet(school_contacts)
resemblance <- similarity(dn, step = 4, window = 4)
as.data.frame(resemblance)
#>    time other measure      value
#> 1     0     0 jaccard 1.00000000
#> 2     0     4 jaccard 0.17910448
#> 3     0     8 jaccard 0.15625000
#> 4     0    12 jaccard 0.14285714
#> 5     0    16 jaccard 0.10416667
#> 6     0    20 jaccard 0.09523810
#> 7     4     0 jaccard 0.17910448
#> 8     4     4 jaccard 1.00000000
#> 9     4     8 jaccard 0.33802817
#> 10    4    12 jaccard 0.26250000
#> 11    4    16 jaccard 0.15625000
#> 12    4    20 jaccard 0.06349206
#> 13    8     0 jaccard 0.15625000
#> 14    8     4 jaccard 0.33802817
#> 15    8     8 jaccard 1.00000000
#> 16    8    12 jaccard 0.31506849
#> 17    8    16 jaccard 0.11290323
#> 18    8    20 jaccard 0.10714286
#> 19   12     0 jaccard 0.14285714
#> 20   12     4 jaccard 0.26250000
#> 21   12     8 jaccard 0.31506849
#> 22   12    12 jaccard 1.00000000
#> 23   12    16 jaccard 0.20967742
#> 24   12    20 jaccard 0.13333333
#> 25   16     0 jaccard 0.10416667
#> 26   16     4 jaccard 0.15625000
#> 27   16     8 jaccard 0.11290323
#> 28   16    12 jaccard 0.20967742
#> 29   16    16 jaccard 1.00000000
#> 30   16    20 jaccard 0.20588235
#> 31   20     0 jaccard 0.09523810
#> 32   20     4 jaccard 0.06349206
#> 33   20     8 jaccard 0.10714286
#> 34   20    12 jaccard 0.13333333
#> 35   20    16 jaccard 0.20588235
#> 36   20    20 jaccard 1.00000000
```
