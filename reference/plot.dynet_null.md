# Plot the surrogate activity profile against the observed one

Plot the surrogate activity profile against the observed one

## Usage

``` r
# S3 method for class 'dynet_null'
plot(x, ...)
```

## Arguments

- x:

  A `dynet_null` from
  [`randomise()`](https://pak.dynasite.org/Dynet/reference/randomise.md).

- ...:

  Ignored.

## Value

A `ggplot` object showing events per time bin for each surrogate with
the observed profile overplotted.
