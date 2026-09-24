# Build the union network of optimal temporal paths

[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) uses an
endpoint-local foremost-then-shortest criterion, so its routes need not
form one predecessor tree. This function therefore returns the honest
union of all expanded optimal route hops. Edge `weight` is the number of
endpoint/path families using the hop; `first_time` and `last_time`
retain its temporal range.

## Usage

``` r
path_network(x)
```

## Arguments

- x:

  A result from
  [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md).

## Value

A static `dynet_path_network` cograph netobject, whose two tidy tables
are reached with `as.data.frame(x, what = "edges")` and
`as.data.frame(x, what = "nodes")`. The edge table has one row per hop
used by at least one optimal route, with `from`, `to`, `weight` (how
many endpoint/path families use the hop), `first_time` and `last_time`
(the hop's temporal range) and `n_endpoints` (how many distinct
endpoints it serves). The node table has one row per vertex the source
actually reaches, the source included, with `name`, `arrival_time`,
`latency`, `n_hops`, `n_paths` and `groups` (hop count as a grouping
label for plotting). Unreachable vertices are absent, not present with
`NA`. The network is always directed, because a route hop has an
orientation even when the temporal network does not; hops of a backward
path result still point the way time runs, from the sender towards the
queried target, and its `arrival_time` is that vertex's latest-departure
supremum, as in
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md).

A result that is not from
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) raises
`dynet_bad_input`; a path result with no reachable vertex raises
`dynet_empty_result`.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- paths(dn, from = "Ana")
union_network <- path_network(routes)
as.data.frame(union_network)
#>     from    to weight first_time last_time n_endpoints
#> 1    Ana  Cara      7       6.67      6.67           7
#> 2    Ana Jonas      9       2.12      6.68           4
#> 3    Ana  Mira      2       6.36      6.36           2
#> 4    Ben   Eve      3      11.66     11.66           1
#> 5   Cara  Finn      3       6.96      6.96           3
#> 6   Cara  Nils      3       7.51      7.51           3
#> 7   Finn  Iris      1      10.00     10.00           1
#> 8   Finn   Leo      1       9.65      9.65           1
#> 9   Hugo   Dan      1       7.98      7.98           1
#> 10 Jonas  Kira      8       6.12      6.68           3
#> 11  Kira   Ben      6       9.59      9.59           2
#> 12  Mira  Gita      1       6.36      6.36           1
#> 13  Nils  Hugo      2       7.98      7.98           2
as.data.frame(union_network, what = "nodes")
#>     name arrival_time latency n_hops n_paths groups
#> 1    Ana         0.00    0.00      0       1      0
#> 2    Ben         9.59    9.59      3       3      3
#> 3   Cara         6.67    6.67      1       1      1
#> 4    Dan         7.98    7.98      4       1      4
#> 5    Eve        11.66   11.66      4       3      4
#> 6   Finn         6.96    6.96      2       1      2
#> 7   Gita         6.36    6.36      2       1      2
#> 8   Hugo         7.98    7.98      3       1      3
#> 9   Iris        10.00   10.00      3       1      3
#> 10 Jonas         2.12    2.12      1       1      1
#> 11  Kira         6.12    6.12      2       2      2
#> 12   Leo         9.65    9.65      3       1      3
#> 13  Mira         6.36    6.36      1       1      1
#> 14  Nils         7.51    7.51      2       1      2
```
