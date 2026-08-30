# Summarise snapshot edges by time bin

Summarise snapshot edges by time bin

## Usage

``` r
# S3 method for class 'dynet_snapshot'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_snapshot` from
  [`snapshots()`](https://mohsaqr.github.io/Dynet/reference/snapshots.md).

- ...:

  Ignored.

## Value

A plain `data.frame` with one row per bin and columns `session` (when
present), `time`, `ties`, `nodes` and `weight`.

## Examples

``` r
summary(snapshots(dynet(school_contacts)))
#>    time ties nodes weight
#> 1     0   10    13     11
#> 2     1    8     8      8
#> 3     2   10    12     10
#> 4     3   12    12     12
#> 5     4   13    12     14
#> 6     5   16    14     16
#> 7     6   29    14     31
#> 8     7   19    14     19
#> 9     8   18    13     20
#> 10    9   16    13     17
#> 11   10   19    14     19
#> 12   11   18    13     19
#> 13   12   18    14     21
#> 14   13   29    14     35
#> 15   14   30    14     34
#> 16   15   10    10     11
#> 17   16   10    11     10
#> 18   17    8    10      8
#> 19   18    7    10      7
#> 20   19    9    11      9
#> 21   20   17    14     17
#> 22   21    6     7      6
```
