# Summarise a temporal measure

Collapses the time dimension. Node-level measures are summarised one row
per vertex and measure; graph-level measures one row per measure. The
peak time is reported alongside, because when a quantity peaked is
usually the question a temporal network is being asked.

## Usage

``` r
# S3 method for class 'dynet_metric'
summary(object, by = NULL, ...)
```

## Arguments

- object:

  A `dynet_metric`.

- by:

  Grouping for the summary: `"node"` (the default for node-level
  measures), `"time"`, or `"measure"`.

- ...:

  Ignored.

## Value

A `data.frame` with the grouping columns plus `n`, `mean`, `sd`, `min`,
`max` and, when time is available, `peak_time`. `n` counts the measured
values the statistics were computed from, so a vertex that was inactive
for part of the calendar reports fewer than the number of time points.

## Examples

``` r
dn <- dynet(school_contacts)
summary(dyn_centrality(dn, measure = "degree"))
#>     node measure  n     mean       sd min max peak_time
#> 1    Ana  degree 22 2.181818 2.015095   0   7         6
#> 2    Ben  degree 22 2.000000 1.234427   0   4         4
#> 3   Cara  degree 22 2.227273 1.342770   0   5         4
#> 4    Dan  degree 22 2.090909 1.444500   1   5        13
#> 5    Eve  degree 22 2.272727 2.051290   0   8        14
#> 6   Finn  degree 22 2.000000 1.661898   0   6        12
#> 7   Gita  degree 22 1.727273 1.777688   0   7         6
#> 8   Hugo  degree 22 2.318182 1.861550   0   6         6
#> 9   Iris  degree 22 1.772727 1.066004   0   4        11
#> 10 Jonas  degree 22 2.863636 2.076982   0   7        13
#> 11  Kira  degree 22 2.636364 1.255292   1   6         6
#> 12   Leo  degree 22 1.636364 1.432462   0   5         6
#> 13  Mira  degree 22 2.272727 1.695423   0   6        13
#> 14  Nils  degree 22 2.181818 2.174229   0   7        14
summary(dyn_centrality(dn, measure = "degree"), by = "time")
#>    time measure  n      mean        sd min max
#> 1     0  degree 14 1.4285714 0.7559289   0   3
#> 2     1  degree 14 1.1428571 1.2924123   0   4
#> 3     2  degree 14 1.4285714 0.9376145   0   3
#> 4     3  degree 14 1.7142857 1.1387288   0   4
#> 5     4  degree 14 1.8571429 1.5118579   0   5
#> 6     5  degree 14 2.2857143 1.2043876   1   4
#> 7     6  degree 14 4.1428571 1.8752289   1   7
#> 8     7  degree 14 2.7142857 1.6374733   1   6
#> 9     8  degree 14 2.5714286 1.7851648   0   6
#> 10    9  degree 14 2.2857143 1.7728105   0   6
#> 11   10  degree 14 2.7142857 1.2666474   1   5
#> 12   11  degree 14 2.5714286 1.5045718   0   5
#> 13   12  degree 14 2.5714286 1.4525461   1   6
#> 14   13  degree 14 4.1428571 1.7913099   1   7
#> 15   14  degree 14 4.2857143 2.2336094   1   8
#> 16   15  degree 14 1.4285714 1.3985864   0   5
#> 17   16  degree 14 1.4285714 1.1578684   0   4
#> 18   17  degree 14 1.1428571 0.9492623   0   3
#> 19   18  degree 14 1.0000000 0.7844645   0   2
#> 20   19  degree 14 1.2857143 0.9138735   0   3
#> 21   20  degree 14 2.4285714 1.2224997   1   5
#> 22   21  degree 14 0.8571429 1.0271052   0   3
```
