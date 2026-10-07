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
dn <- dynet(school_contacts)
shifts <- pshifts(dn)
shifts
#> # Participation shifts (Gibson 2003, 13 types)
#> # 235 classified turn transitions across 4 families
#>  shift          family measure value
#>  AB-BA  turn_receiving   count     0
#>  AB-B0  turn_receiving   count     0
#>  AB-BY  turn_receiving   count    18
#>  A0-X0   turn_claiming   count     0
#>  A0-XA   turn_claiming   count     1
#>  A0-XY   turn_claiming   count     2
#>  AB-X0   turn_usurping   count     3
#>  AB-XA   turn_usurping   count    14
#>  AB-XB   turn_usurping   count    20
#>  AB-XY   turn_usurping   count   169
#>  A0-AY turn_continuing   count     0
#>  AB-A0 turn_continuing   count     0
#>  AB-AY turn_continuing   count     8
```
