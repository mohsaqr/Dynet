# Plot time-respecting paths when a valid renderer exists

Rendering endpoint-local shortest-foremost families is not currently
supported. Such paths need not share prefix-optimal routes, so they do
not form one predecessor tree. Inspect their compact counts and expanded
steps instead.

All P08 shortest-foremost results raise a `dynet_unsupported_plot`
condition, regardless of session mode. This keeps rendering from
implying a prefix-compatible tree that the endpoint-local criterion does
not define.

## Usage

``` r
# S3 method for class 'dynet_paths'
plot(x, palette = "okabe", ...)
```

## Arguments

- x:

  A `dynet_paths` from
  [`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md).

- palette:

  Palette specification, as in
  [`plot.dynet()`](https://mohsaqr.github.io/Dynet/reference/plot.dynet.md).
  Vertices are coloured by how many hops they are from the source.

- ...:

  Passed to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).

## Value

A `ggplot` object for current shortest-foremost results. The legacy
`cograph` tree renderer remains only for older serialized results
without criterion metadata, and draws to the active device.

## Examples

``` r
dn <- dynet(school_contacts)
journeys <- paths(dn, from = "Ana")
plot(journeys)

```
