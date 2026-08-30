# Summarise path trajectories

Summarise path trajectories

## Usage

``` r
# S3 method for class 'dynet_path_trajectories'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_path_trajectories` result.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per depth: `depth`, the number of distinct
`branches` reaching it, the `vertices` they land on, the summed `count`
of routes through it, and `mean_branching`, the average branching
fraction of those routes. Note `probability` in the underlying table is
CONDITIONAL on each parent, so it is averaged rather than summed: adding
conditional fractions across siblings would not be a probability at all.
Depth zero is the queried vertex itself and has no parent, so its
`mean_branching` is `NA`.

## Examples

``` r
summary(path_trajectories(paths(dynet(school_contacts), from = "Ana")))
#>   depth branches vertices count mean_branching
#> 1     0        1        1    19             NA
#> 2     1        5        3    18      0.1894737
#> 3     2        6        4    15      0.6845238
#> 4     3        6        4    10      0.6111111
#> 5     4        4        2     4      0.5000000
```
