# Tidy data frame of ranked pathways

Tidy data frame of ranked pathways

## Usage

``` r
# S3 method for class 'dynet_pathways'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("routes", "steps"),
  ...
)
```

## Arguments

- x:

  A `dynet_pathways` result.

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- what:

  `"routes"`, the default, gives one row per distinct route. `"steps"`
  gives one row per vertex visited – `route`, `step`, `vertex` and the
  `time` the route reaches it, preceded by `from` when pooled – which is
  the per-hop timing the plot draws and the shape to use for any
  waiting-time analysis of your own.

- ...:

  Ignored.

## Value

A plain `data.frame` with the columns described in
[`pathways()`](https://mohsaqr.github.io/Dynet/reference/pathways.md),
most frequent first, or the per-step table when `what = "steps"`.

## Examples

``` r
as.data.frame(pathways(dynet(school_contacts), from = "Ana"))
#>                                route endpoint count     share n_hops
#> 1 Ana -> Jonas -> Kira -> Ben -> Eve      Eve     3 0.4285714      4
#> 2                Ana -> Mira -> Gita     Gita     1 0.1428571      2
#> 3        Ana -> Cara -> Finn -> Iris     Iris     1 0.1428571      3
#> 4         Ana -> Cara -> Finn -> Leo      Leo     1 0.1428571      3
#> 5 Ana -> Cara -> Nils -> Hugo -> Dan      Dan     1 0.1428571      4
#>   arrival_time
#> 1        11.66
#> 2         6.36
#> 3        10.00
#> 4         9.65
#> 5         7.98
as.data.frame(pathways(dynet(school_contacts), from = "Ana"),
              what = "steps")
#>                                 route step vertex  time
#> 1         Ana -> Cara -> Finn -> Iris    0    Ana  0.00
#> 2         Ana -> Cara -> Finn -> Iris    1   Cara  6.67
#> 3         Ana -> Cara -> Finn -> Iris    2   Finn  6.96
#> 4         Ana -> Cara -> Finn -> Iris    3   Iris 10.00
#> 5          Ana -> Cara -> Finn -> Leo    0    Ana  0.00
#> 6          Ana -> Cara -> Finn -> Leo    1   Cara  6.67
#> 7          Ana -> Cara -> Finn -> Leo    2   Finn  6.96
#> 8          Ana -> Cara -> Finn -> Leo    3    Leo  9.65
#> 9  Ana -> Cara -> Nils -> Hugo -> Dan    0    Ana  0.00
#> 10 Ana -> Cara -> Nils -> Hugo -> Dan    1   Cara  6.67
#> 11 Ana -> Cara -> Nils -> Hugo -> Dan    2   Nils  7.51
#> 12 Ana -> Cara -> Nils -> Hugo -> Dan    3   Hugo  7.98
#> 13 Ana -> Cara -> Nils -> Hugo -> Dan    4    Dan  7.98
#> 14 Ana -> Jonas -> Kira -> Ben -> Eve    0    Ana  0.00
#> 15 Ana -> Jonas -> Kira -> Ben -> Eve    1  Jonas  2.12
#> 16 Ana -> Jonas -> Kira -> Ben -> Eve    2   Kira  6.12
#> 17 Ana -> Jonas -> Kira -> Ben -> Eve    3    Ben  9.59
#> 18 Ana -> Jonas -> Kira -> Ben -> Eve    4    Eve 11.66
#> 19                Ana -> Mira -> Gita    0    Ana  0.00
#> 20                Ana -> Mira -> Gita    1   Mira  6.36
#> 21                Ana -> Mira -> Gita    2   Gita  6.36
```
