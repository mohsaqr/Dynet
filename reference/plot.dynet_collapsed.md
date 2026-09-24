# Draw a collapsed temporal network

The union of a network's ties over a window, as a node-link diagram with
Dynet's rendering defaults; any
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
argument overrides them.

## Usage

``` r
# S3 method for class 'dynet_collapsed'
plot(x, palette = "okabe", ...)
```

## Arguments

- x:

  A result from
  [`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md).

- palette:

  Palette specification, as in
  [`plot.dynet()`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md).

- ...:

  Passed to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).

## Value

`x`, invisibly.

## Examples

``` r
dn <- dynet(school_contacts)
flat <- collapse_network(dn)
plot(flat, layout = "oval")
```
