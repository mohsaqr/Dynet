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
  [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md).

- base_size:

  Base font size.

- palette:

  Palette specification, as in
  [`plot.dynet()`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md).

- ...:

  Ignored.

## Value

A `ggplot` object, faceted by session when the result carries one. A
result in which no tie is active raises an error of class
`dynet_empty_result` rather than drawing an empty panel.

## Examples

``` r
dn <- dynet(school_contacts)
bins <- snapshots(dn)
plot(bins)
```
