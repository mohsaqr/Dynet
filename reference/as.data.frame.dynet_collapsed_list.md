# Tidy data frame of session-specific collapsed networks

Stacks the per-session edge tables into one tidy frame with a `session`
key, so a session-separated collapse reads like every other verb's
result. Without this the base method flattened the list sideways into a
single row of `s1.from`, `s2.from`, ... columns.

## Usage

``` r
# S3 method for class 'dynet_collapsed_list'
as.data.frame(x, row.names = NULL, optional = FALSE, session = NULL, ...)
```

## Arguments

- x:

  A `dynet_collapsed_list` from
  `collapse_network(sessions = "separate")`.

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- session:

  Optional session name. Supply one to get that session's table alone,
  without the `session` key; the default stacks them all.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per collapsed pair per session, with
`session` first and then the columns
[`as.data.frame.dynet_collapsed()`](https://mohsaqr.github.io/Dynet/reference/as.data.frame.dynet_collapsed.md)
returns.

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "A"), to = c("B", "B"), start = c(0, 0), end = c(2, 3),
  session = c("s1", "s2")
), session = "session")
as.data.frame(collapse_network(dn, sessions = "separate"))
#>   session from to binary union_duration total_duration duration_fraction
#> 1      s1    A  B      1              2              2         0.6666667
#> 2      s2    A  B      1              3              3         1.0000000
#>   spell_count weight_sum weighted_duration latest_weight first last
#> 1           1          1                 2             1     0    2
#> 2           1          1                 3             1     0    3
#>   activity.duration activity.count
#> 1                 2              1
#> 2                 3              1
as.data.frame(collapse_network(dn, sessions = "separate"), session = "s1")
#>   from to binary union_duration total_duration duration_fraction spell_count
#> 1    A  B      1              2              2         0.6666667           1
#>   weight_sum weighted_duration latest_weight first last activity.duration
#> 1          1                 2             1     0    2                 2
#>   activity.count
#> 1              1
```
