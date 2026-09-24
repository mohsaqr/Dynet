# Print a time-projected network

Print a time-projected network

## Usage

``` r
# S3 method for class 'dynet_projection'
print(x, ...)
```

## Arguments

- x:

  A projection returned by
  [`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md).

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
dn <- dynet(school_contacts)
projected <- projection(dn, step = 4, window = 4)
projected
#> # Time-projected network | 84 states | 286 arcs | 1 slice block(s)
#> # step 4 | window 4 | labels_erased_single_block
#>  state slice time start end closed node active
#>      1     1    0     0   4  FALSE  Ana   TRUE
#>      2     1    0     0   4  FALSE  Ben   TRUE
#>      3     1    0     0   4  FALSE Cara   TRUE
#>      4     1    0     0   4  FALSE  Dan   TRUE
#>      5     1    0     0   4  FALSE  Eve   TRUE
#>      6     1    0     0   4  FALSE Finn   TRUE
```
