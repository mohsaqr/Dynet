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
