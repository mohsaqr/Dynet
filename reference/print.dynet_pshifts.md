# Print participation shift counts

Print participation shift counts

## Usage

``` r
# S3 method for class 'dynet_pshifts'
print(x, ...)
```

## Arguments

- x:

  A `dynet_pshifts` result.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
pshifts(dynet(school_contacts))
#> # Participation shifts (Gibson 2003, 13 types)
#> # 235 classified turn transitions across 4 families
#>  shift          family count
#>  AB-BA  turn_receiving     0
#>  AB-B0  turn_receiving     0
#>  AB-BY  turn_receiving    18
#>  A0-X0   turn_claiming     0
#>  A0-XA   turn_claiming     1
#>  A0-XY   turn_claiming     2
#>  AB-X0   turn_usurping     3
#>  AB-XA   turn_usurping    14
#>  AB-XB   turn_usurping    20
#>  AB-XY   turn_usurping   169
#>  A0-AY turn_continuing     0
#>  AB-A0 turn_continuing     0
#>  AB-AY turn_continuing     8
```
