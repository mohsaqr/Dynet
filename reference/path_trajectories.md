# Optimal temporal routes as a counted trajectory tree

Turns the optimal route family returned by
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md) into a
tidy prefix tree. Every row is one tree node: a route prefix reaching
`vertex` at `time`, used by `count` optimal routes. A named vertex
reached through a different temporal history is a separate row, so
branches never create the misleading crossings of a path-union graph and
two routes that differ only in when a hop fires stay separate.

Forward routes grow away from the queried source. Backward routes are
reversed, so the queried target is the root and possible senders branch
away from it.

## Usage

``` r
path_trajectories(x, min_count = 1L, plot = FALSE)
```

## Arguments

- x:

  A result from
  [`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md).

- min_count:

  Keep only branches used by at least this many optimal routes. The
  default of `1` keeps the complete family; a higher value is the
  caller's explicit pruning.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn, so
  `plot = TRUE` saves the wrapping
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call without
  changing what comes back. Use
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on the result
  when the figure needs arguments of its own.

## Value

A `dynet_path_trajectories` data frame with one row per tree node and
columns `node`, `parent`, `depth`, `count`, `probability`, `vertex`,
`time`, `session` and `branch`. `depth` is the hop number from the
queried vertex, `probability` is the branching fraction of the parent's
routes that continue along this branch, and `branch` is the node's
placement across the tree.

## See also

[`plot_path_trajectories()`](https://mohsaqr.github.io/Dynet/reference/plot_path_trajectories.md)
to draw the tree,
[`path_network()`](https://mohsaqr.github.io/Dynet/reference/path_network.md)
for the route union as a network.

## Examples

``` r
dn <- dynet(school_contacts)
paths <- paths(dn, from = "Ana")
path_trajectories(paths)
#> # Forward temporal trajectory tree from Ana
#> # 22 nodes, 4 hops deep, 19 routes
#>                                                         node
#> 1                                                      Ana@0
#> 2                                         Ana@0 -> Cara@6.67
#> 3                            Ana@0 -> Cara@6.67 -> Finn@6.96
#> 4                 Ana@0 -> Cara@6.67 -> Finn@6.96 -> Iris@10
#> 5                Ana@0 -> Cara@6.67 -> Finn@6.96 -> Leo@9.65
#> 6                            Ana@0 -> Cara@6.67 -> Nils@7.51
#> 7               Ana@0 -> Cara@6.67 -> Nils@7.51 -> Hugo@7.98
#> 8   Ana@0 -> Cara@6.67 -> Nils@7.51 -> Hugo@7.98 -> Dan@7.98
#> 9                                        Ana@0 -> Jonas@2.12
#> 10                          Ana@0 -> Jonas@2.12 -> Kira@6.12
#> 11              Ana@0 -> Jonas@2.12 -> Kira@6.12 -> Ben@9.59
#> 12 Ana@0 -> Jonas@2.12 -> Kira@6.12 -> Ben@9.59 -> Eve@11.66
#> 13                                       Ana@0 -> Jonas@3.43
#> 14                          Ana@0 -> Jonas@3.43 -> Kira@6.12
#> 15              Ana@0 -> Jonas@3.43 -> Kira@6.12 -> Ben@9.59
#> 16 Ana@0 -> Jonas@3.43 -> Kira@6.12 -> Ben@9.59 -> Eve@11.66
#> 17                                       Ana@0 -> Jonas@6.68
#> 18                          Ana@0 -> Jonas@6.68 -> Kira@6.68
#> 19              Ana@0 -> Jonas@6.68 -> Kira@6.68 -> Ben@9.59
#> 20 Ana@0 -> Jonas@6.68 -> Kira@6.68 -> Ben@9.59 -> Eve@11.66
#> 21                                        Ana@0 -> Mira@6.36
#> 22                           Ana@0 -> Mira@6.36 -> Gita@6.36
#>                                          parent depth count probability vertex
#> 1                                          <NA>     0    19          NA    Ana
#> 2                                         Ana@0     1     7   0.3684211   Cara
#> 3                            Ana@0 -> Cara@6.67     2     3   0.4285714   Finn
#> 4               Ana@0 -> Cara@6.67 -> Finn@6.96     3     1   0.3333333   Iris
#> 5               Ana@0 -> Cara@6.67 -> Finn@6.96     3     1   0.3333333    Leo
#> 6                            Ana@0 -> Cara@6.67     2     3   0.4285714   Nils
#> 7               Ana@0 -> Cara@6.67 -> Nils@7.51     3     2   0.6666667   Hugo
#> 8  Ana@0 -> Cara@6.67 -> Nils@7.51 -> Hugo@7.98     4     1   0.5000000    Dan
#> 9                                         Ana@0     1     4   0.2105263  Jonas
#> 10                          Ana@0 -> Jonas@2.12     2     3   0.7500000   Kira
#> 11             Ana@0 -> Jonas@2.12 -> Kira@6.12     3     2   0.6666667    Ben
#> 12 Ana@0 -> Jonas@2.12 -> Kira@6.12 -> Ben@9.59     4     1   0.5000000    Eve
#> 13                                        Ana@0     1     3   0.1578947  Jonas
#> 14                          Ana@0 -> Jonas@3.43     2     3   1.0000000   Kira
#> 15             Ana@0 -> Jonas@3.43 -> Kira@6.12     3     2   0.6666667    Ben
#> 16 Ana@0 -> Jonas@3.43 -> Kira@6.12 -> Ben@9.59     4     1   0.5000000    Eve
#> 17                                        Ana@0     1     2   0.1052632  Jonas
#> 18                          Ana@0 -> Jonas@6.68     2     2   1.0000000   Kira
#> 19             Ana@0 -> Jonas@6.68 -> Kira@6.68     3     2   1.0000000    Ben
#> 20 Ana@0 -> Jonas@6.68 -> Kira@6.68 -> Ben@9.59     4     1   0.5000000    Eve
#> 21                                        Ana@0     1     2   0.1052632   Mira
#> 22                           Ana@0 -> Mira@6.36     2     1   0.5000000   Gita
#>     time session branch
#> 1   0.00    <NA>   3.15
#> 2   6.67    <NA>   5.75
#> 3   6.96    <NA>   6.50
#> 4  10.00    <NA>   7.00
#> 5   9.65    <NA>   6.00
#> 6   7.51    <NA>   5.00
#> 7   7.98    <NA>   5.00
#> 8   7.98    <NA>   5.00
#> 9   2.12    <NA>   4.00
#> 10  6.12    <NA>   4.00
#> 11  9.59    <NA>   4.00
#> 12 11.66    <NA>   4.00
#> 13  3.43    <NA>   3.00
#> 14  6.12    <NA>   3.00
#> 15  9.59    <NA>   3.00
#> 16 11.66    <NA>   3.00
#> 17  6.68    <NA>   2.00
#> 18  6.68    <NA>   2.00
#> 19  9.59    <NA>   2.00
#> 20 11.66    <NA>   2.00
#> 21  6.36    <NA>   1.00
#> 22  6.36    <NA>   1.00
```
