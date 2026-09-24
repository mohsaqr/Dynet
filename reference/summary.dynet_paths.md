# Summarise time-respecting paths

Summarise time-respecting paths

## Usage

``` r
# S3 method for class 'dynet_paths'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_paths`.

- ...:

  Ignored.

## Value

A `data.frame` with columns `property` and `value`, one row per
property, both character so the table prints as one block. The eight
properties are `source`, `direction`, `reachable`, `reachable share`,
`median latency`, `max latency`, `median hops` and `max hops`; the
source is excluded from every count and share. Under
`sessions = "separate"` a leading `session` column is added and the
eight properties are repeated for each session.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- paths(dn, from = "Ana")
summary(routes)
#>          property   value
#> 1          source     Ana
#> 2       direction forward
#> 3       reachable      13
#> 4 reachable share       1
#> 5  median latency    7.51
#> 6     max latency   11.66
#> 7     median hops       2
#> 8        max hops       4
```
