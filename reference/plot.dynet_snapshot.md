# Plot how many ties each snapshot holds

Plot how many ties each snapshot holds

## Usage

``` r
# S3 method for class 'dynet_snapshot'
plot(x, base_size = 12, palette = "okabe", ...)
```

## Arguments

- x:

  A `dynet_snapshot` from
  [`snapshots()`](https://mohsaqr.github.io/Dynet/reference/snapshots.md).

- base_size:

  Base font size.

- palette:

  Palette specification, as in
  [`plot.dynet()`](https://mohsaqr.github.io/Dynet/reference/plot.dynet.md).

- ...:

  Ignored.

## Value

A `ggplot` object.

## Examples

``` r
plot(snapshots(dynet(school_contacts)))
```
