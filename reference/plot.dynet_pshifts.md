# Plot participation shift counts

One horizontal bar per shift type, grouped and coloured by family.
Families are distinguished by a direct axis grouping as well as by fill,
so the figure does not rely on colour alone.

## Usage

``` r
# S3 method for class 'dynet_pshifts'
plot(x, ...)
```

## Arguments

- x:

  A `dynet_pshifts` result.

- ...:

  Ignored.

## Value

A `ggplot` object.

## Examples

``` r
plot(pshifts(dynet(school_contacts)))
```
