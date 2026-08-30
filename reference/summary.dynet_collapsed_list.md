# Summarise session-specific collapsed networks

Summarise session-specific collapsed networks

## Usage

``` r
# S3 method for class 'dynet_collapsed_list'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_collapsed_list`.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per session: `session`, the number of
collapsed `pairs`, the `nodes` those pairs span, and the summed
`union_duration` and `total_duration`.

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "A"), to = c("B", "B"), start = c(0, 0), end = c(2, 3),
  session = c("s1", "s2")
), session = "session")
summary(collapse_network(dn, sessions = "separate"))
#>   session pairs nodes union_duration total_duration
#> 1      s1     1     2              2              2
#> 2      s2     1     2              3              3
```
