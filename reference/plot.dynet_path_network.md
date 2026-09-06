# Draw a path network

The hops used by a set of optimal temporal paths, as a node-link diagram
with Dynet's rendering defaults; any
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
argument overrides them.

## Usage

``` r
# S3 method for class 'dynet_path_network'
plot(x, palette = "okabe", ...)
```

## Arguments

- x:

  A result from
  [`path_network()`](https://mohsaqr.github.io/Dynet/reference/path_network.md).

- palette:

  Palette specification, as in
  [`plot.dynet()`](https://mohsaqr.github.io/Dynet/reference/plot.dynet.md).

- ...:

  Passed to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).

## Value

`x`, invisibly.

## Examples

``` r
dn <- dynet(school_contacts)
plot(path_network(paths(dn, from = "Ana")), layout = "oval")
```
