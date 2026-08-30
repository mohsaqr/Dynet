# Print snapshot edges

Print snapshot edges

## Usage

``` r
# S3 method for class 'dynet_snapshot'
print(x, n = 10L, ...)
```

## Arguments

- x:

  A `dynet_snapshot` from
  [`snapshots()`](https://mohsaqr.github.io/Dynet/reference/snapshots.md).

- n:

  Number of rows to show.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
snapshots(dynet(school_contacts), at = 3)
#> # Snapshot edges | 1 bin | 12 tie rows | time in step
#>    time from    to weight n_spells
#> 1     3  Ana Jonas      1        1
#> 2     3 Kira   Leo      1        1
#> 3     3  Leo  Finn      1        1
#> 4     3 Nils   Eve      1        1
#> 5     3  Ben Jonas      1        1
#> 6     3  Ben   Eve      1        1
#> 7     3  Dan   Ana      1        1
#> 8     3  Dan Jonas      1        1
#> 9     3  Dan   Eve      1        1
#> 10    3 Gita Jonas      1        1
#> # 2 more rows. summary() counts them by bin.
```
