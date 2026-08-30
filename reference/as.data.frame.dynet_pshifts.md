# Tidy data frame of participation shift counts

Tidy data frame of participation shift counts

## Usage

``` r
# S3 method for class 'dynet_pshifts'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `dynet_pshifts` result.

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per shift type: `shift`, `family` and
`count`, preceded by `session` when the result is session-local. The
thirteen Gibson shift types are always present, including those with a
count of zero.

## Examples

``` r
as.data.frame(pshifts(dynet(school_contacts)))
#>    shift          family count
#> 1  AB-BA  turn_receiving     0
#> 2  AB-B0  turn_receiving     0
#> 3  AB-BY  turn_receiving    18
#> 4  A0-X0   turn_claiming     0
#> 5  A0-XA   turn_claiming     1
#> 6  A0-XY   turn_claiming     2
#> 7  AB-X0   turn_usurping     3
#> 8  AB-XA   turn_usurping    14
#> 9  AB-XB   turn_usurping    20
#> 10 AB-XY   turn_usurping   169
#> 11 A0-AY turn_continuing     0
#> 12 AB-A0 turn_continuing     0
#> 13 AB-AY turn_continuing     8
```
