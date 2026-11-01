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
[`pathways()`](https://pak.dynasite.org/Dynet/reference/pathways.md),
most frequent first, or the per-step table when `what = "steps"`.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- pathways(dn, from = "Ana")
as.data.frame(routes)
#>                                 route endpoint count      share n_hops
#> 1         Ana -> Jonas -> Kira -> Ben      Ben     3 0.16666667      3
#> 2  Ana -> Jonas -> Kira -> Ben -> Eve      Eve     3 0.16666667      4
#> 3                Ana -> Jonas -> Kira     Kira     2 0.11111111      2
#> 4                         Ana -> Cara     Cara     1 0.05555556      1
#> 5                        Ana -> Jonas    Jonas     1 0.05555556      1
#> 6                         Ana -> Mira     Mira     1 0.05555556      1
#> 7                 Ana -> Cara -> Finn     Finn     1 0.05555556      2
#> 8                 Ana -> Cara -> Nils     Nils     1 0.05555556      2
#> 9                 Ana -> Mira -> Gita     Gita     1 0.05555556      2
#> 10        Ana -> Cara -> Finn -> Iris     Iris     1 0.05555556      3
#> 11         Ana -> Cara -> Finn -> Leo      Leo     1 0.05555556      3
#> 12        Ana -> Cara -> Nils -> Hugo     Hugo     1 0.05555556      3
#> 13 Ana -> Cara -> Nils -> Hugo -> Dan      Dan     1 0.05555556      4
#>    arrival_time
#> 1          9.59
#> 2         11.66
#> 3          6.12
#> 4          6.67
#> 5          2.12
#> 6          6.36
#> 7          6.96
#> 8          7.51
#> 9          6.36
#> 10        10.00
#> 11         9.65
#> 12         7.98
#> 13         7.98
as.data.frame(routes, what = "steps")
#>                                 route step vertex  time
#> 1         Ana -> Jonas -> Kira -> Ben    0    Ana  0.00
#> 2         Ana -> Jonas -> Kira -> Ben    1  Jonas  2.12
#> 3         Ana -> Jonas -> Kira -> Ben    2   Kira  6.12
#> 4         Ana -> Jonas -> Kira -> Ben    3    Ben  9.59
#> 5                         Ana -> Cara    0    Ana  0.00
#> 6                         Ana -> Cara    1   Cara  6.67
#> 7  Ana -> Cara -> Nils -> Hugo -> Dan    0    Ana  0.00
#> 8  Ana -> Cara -> Nils -> Hugo -> Dan    1   Cara  6.67
#> 9  Ana -> Cara -> Nils -> Hugo -> Dan    2   Nils  7.51
#> 10 Ana -> Cara -> Nils -> Hugo -> Dan    3   Hugo  7.98
#> 11 Ana -> Cara -> Nils -> Hugo -> Dan    4    Dan  7.98
#> 12 Ana -> Jonas -> Kira -> Ben -> Eve    0    Ana  0.00
#> 13 Ana -> Jonas -> Kira -> Ben -> Eve    1  Jonas  2.12
#> 14 Ana -> Jonas -> Kira -> Ben -> Eve    2   Kira  6.12
#> 15 Ana -> Jonas -> Kira -> Ben -> Eve    3    Ben  9.59
#> 16 Ana -> Jonas -> Kira -> Ben -> Eve    4    Eve 11.66
#> 17                Ana -> Cara -> Finn    0    Ana  0.00
#> 18                Ana -> Cara -> Finn    1   Cara  6.67
#> 19                Ana -> Cara -> Finn    2   Finn  6.96
#> 20                Ana -> Mira -> Gita    0    Ana  0.00
#> 21                Ana -> Mira -> Gita    1   Mira  6.36
#> 22                Ana -> Mira -> Gita    2   Gita  6.36
#> 23        Ana -> Cara -> Nils -> Hugo    0    Ana  0.00
#> 24        Ana -> Cara -> Nils -> Hugo    1   Cara  6.67
#> 25        Ana -> Cara -> Nils -> Hugo    2   Nils  7.51
#> 26        Ana -> Cara -> Nils -> Hugo    3   Hugo  7.98
#> 27        Ana -> Cara -> Finn -> Iris    0    Ana  0.00
#> 28        Ana -> Cara -> Finn -> Iris    1   Cara  6.67
#> 29        Ana -> Cara -> Finn -> Iris    2   Finn  6.96
#> 30        Ana -> Cara -> Finn -> Iris    3   Iris 10.00
#> 31                       Ana -> Jonas    0    Ana  0.00
#> 32                       Ana -> Jonas    1  Jonas  2.12
#> 33               Ana -> Jonas -> Kira    0    Ana  0.00
#> 34               Ana -> Jonas -> Kira    1  Jonas  2.12
#> 35               Ana -> Jonas -> Kira    2   Kira  6.12
#> 36         Ana -> Cara -> Finn -> Leo    0    Ana  0.00
#> 37         Ana -> Cara -> Finn -> Leo    1   Cara  6.67
#> 38         Ana -> Cara -> Finn -> Leo    2   Finn  6.96
#> 39         Ana -> Cara -> Finn -> Leo    3    Leo  9.65
#> 40                        Ana -> Mira    0    Ana  0.00
#> 41                        Ana -> Mira    1   Mira  6.36
#> 42                Ana -> Cara -> Nils    0    Ana  0.00
#> 43                Ana -> Cara -> Nils    1   Cara  6.67
#> 44                Ana -> Cara -> Nils    2   Nils  7.51
```
