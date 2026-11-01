# Summarise surrogate networks

Summarise surrogate networks

## Usage

``` r
# S3 method for class 'dynet_null'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_null` from
  [`randomise()`](https://pak.dynasite.org/Dynet/reference/randomise.md).

- ...:

  Ignored.

## Value

A data frame with one row per replicate and columns `replicate`,
`n_events`, `n_pairs`, `t_min`, `t_max`, `mean_duration` and `rejected`
(the infeasible spells met while drawing that replicate under `respect`,
zero when no constraint binds), so the conservation each method claims
and the bite of the constraints are visible.
