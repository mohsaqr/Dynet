# Summarise temporal phases

Summarise temporal phases

## Usage

``` r
# S3 method for class 'dynet_phases'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_phases` from
  [`phases()`](https://pak.dynasite.org/Dynet/reference/phases.md).

- ...:

  Ignored.

## Value

A `data.frame` with one row per phase: `phase`, `start`, `end`, `n_bins`
and `cohesion`, as `as.data.frame(object, what = "phases")`.
