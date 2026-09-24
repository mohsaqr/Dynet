# Tidy tables from a temporal path-union network

Tidy tables from a temporal path-union network

## Usage

``` r
# S3 method for class 'dynet_path_network'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("edges", "nodes"),
  ...
)
```

## Arguments

- x:

  A network returned by
  [`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md).

- row.names, optional:

  Ignored.

- what:

  `"edges"`, the default, or `"nodes"`.

- ...:

  Ignored.

## Value

A plain `data.frame`. For `"edges"`, one row per hop used by an optimal
route, with `from`, `to`, `weight`, `first_time`, `last_time` and
`n_endpoints`. For `"nodes"`, one row per reached vertex, with `name`,
`arrival_time`, `latency`, `n_hops`, `n_paths` and `groups`. See
[`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md)
for what each column means.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- paths(dn, from = "Ana")
union_network <- path_network(routes)
as.data.frame(union_network, what = "edges")
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
