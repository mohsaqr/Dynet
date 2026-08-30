# Tidy table of snapshot edges

Tidy table of snapshot edges

## Usage

``` r
# S3 method for class 'dynet_snapshot'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `dynet_snapshot` from
  [`snapshots()`](https://mohsaqr.github.io/Dynet/reference/snapshots.md).

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- ...:

  Ignored.

## Value

A plain `data.frame` with the same rows and columns.

## Examples

``` r
head(as.data.frame(snapshots(dynet(school_contacts))))
#>   time  from   to weight n_spells
#> 1    0 Jonas Mira      1        1
#> 2    0 Jonas  Dan      1        1
#> 3    0  Kira  Ben      1        1
#> 4    0   Leo Mira      1        1
#> 5    0   Leo Iris      2        2
#> 6    0  Mira Finn      1        1
```
