# Print session-specific collapsed networks

Print session-specific collapsed networks

## Usage

``` r
# S3 method for class 'dynet_collapsed_list'
print(x, ...)
```

## Arguments

- x:

  A `dynet_collapsed_list`.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "A"), to = c("B", "B"), start = c(0, 0), end = c(2, 3),
  session = c("s1", "s2")
), session = "session")
collapse_network(dn, sessions = "separate")
#> # Collapsed networks, one per session (2 sessions)
#> # 2 collapsed pairs in total
#>  session from to binary union_duration total_duration duration_fraction
#>       s1    A  B      1              2              2         0.6666667
#>       s2    A  B      1              3              3         1.0000000
#>  spell_count weight_sum weighted_duration latest_weight first last
#>            1          1                 2             1     0    2
#>            1          1                 3             1     0    3
#>  activity.duration activity.count
#>                  2              1
#>                  3              1
```
