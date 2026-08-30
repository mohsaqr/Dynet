# Plot path trajectories

A method wrapper so
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) works on the
result directly. It draws exactly what
[`plot_path_trajectories()`](https://mohsaqr.github.io/Dynet/reference/plot_path_trajectories.md)
draws; that function remains the place where the appearance arguments
are documented.

## Usage

``` r
# S3 method for class 'dynet_path_trajectories'
plot(x, ...)
```

## Arguments

- x:

  A `dynet_path_trajectories` result.

- ...:

  Passed to
  [`plot_path_trajectories()`](https://mohsaqr.github.io/Dynet/reference/plot_path_trajectories.md).

## Value

A `ggplot` object.

## Examples

``` r
plot(path_trajectories(paths(dynet(school_contacts), from = "Ana")))
```
