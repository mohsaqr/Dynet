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
#>  from_event to_event      first     second  via wait
#>           1       16 Jonas->Dan   Dan->Leo  Dan 0.93
#>           3       10  Leo->Mira Mira->Finn Mira 0.41
#>           3       12  Leo->Mira  Mira->Eve Mira 0.81
#>           4       14  Leo->Iris Iris->Gita Iris 0.99
#>           6        9  Leo->Iris Iris->Cara Iris 0.28
#>           8       15  Eve->Kira  Kira->Eve Kira 0.53
#> # as.data.frame(x, what = "adjacencies") adds the times and the tie attributes of both events.
```
