# Print an event graph

Print an event graph

## Usage

``` r
# S3 method for class 'dynet_event_graph'
print(x, ...)
```

## Arguments

- x:

  An event graph returned by
  [`event_graph()`](https://pak.dynasite.org/Dynet/reference/event_graph.md).

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
dn <- dynet(school_contacts)
event_graph(dn, delta = 1)
#> # Event graph | 240 events | 196 adjacencies
#> # delta 1 | adjacency "all" | direction "respect" | sessions_ignored
#>  from_event to_event  via from_time to_time wait
#>           1       16  Dan      1.10    2.03 0.93
#>           3       10 Mira      0.42    0.83 0.41
#>           3       12 Mira      0.42    1.23 0.81
#>           4       14 Iris      0.96    1.95 0.99
#>           6        9 Iris      0.50    0.78 0.28
#>           8       15 Kira      1.42    1.95 0.53
```
