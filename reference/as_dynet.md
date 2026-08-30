# Convert an object to a Dynet temporal network

Convert an object to a Dynet temporal network

## Usage

``` r
as_dynet(x, ...)

# S3 method for class 'dynet'
as_dynet(x, ...)
```

## Arguments

- x:

  An object representing a temporal network.

- ...:

  Passed to a class-specific method.

## Value

A [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md)
temporal network: an object of class `dynet` carrying the tie ledger,
the node table and the construction metadata. The `dynet` method is the
identity, returning `x` unchanged, so `as_dynet()` is safe to call on an
object that is already a temporal network.
