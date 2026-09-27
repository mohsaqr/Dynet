# Most frequent time-respecting routes

`pathways()` reports whole journeys rather than per-vertex summaries:
one row per distinct route, ranked by how many optimal routes follow it.
It answers "which pathways does this network actually use", where
[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
answers "where do the routes diverge" and
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) answers
"who is reachable".

## Usage

``` r
pathways(dn, from = NULL, top = NULL, min_hops = 1L, ..., plot = FALSE)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- from:

  Optional source vertex. A name gives the routes leaving that vertex,
  and several names give the routes leaving each of them. The default,
  `NULL`, pools every vertex, which is the network-wide question, and is
  the only case that adds a `from` column naming each route's source; a
  named source is already the first step of every `route` string.

- top:

  Optional number of routes to keep, most frequent first. The default
  keeps all of them.

- min_hops:

  Shortest route to report. Defaults to one, which drops the zero-hop
  route from a vertex to itself.

- ...:

  Passed to
  [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md), so
  `start`, `end`, `at`, `direction`, `sessions` and `traversal_time` all
  apply.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn, so
  `plot = TRUE` saves the wrapping
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call without
  changing what comes back. Use
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on the result
  when the figure needs arguments of its own.

## Value

An object of class `dynet_pathways`, a data frame with one row per
distinct route, most frequent first: `route`, the vertex sequence joined
by arrows; `endpoint`, where it lands; `count`, how many optimal routes
follow it; `share`, its fraction of every counted route, so the shares
of a result limited by `top` do not sum to one; `n_hops`; and
`arrival_time`, the earliest time the route lands. Pooling over every
source adds `from` as the first column. Use
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) for a
plain frame and `as.data.frame(x, what = "steps")` for the per-hop
timing of the routes that were kept.

An unknown `from` raises `dynet_unknown_node`; a `top` or `min_hops`
that is not one finite number in range raises `dynet_bad_input`; and a
query that leaves no route of at least `min_hops` hops raises
`dynet_empty_result`. Conditions raised by
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) on the
arguments passed through `...` reach the caller unchanged.

## Details

The result is already ordered and already carries the share of the
total, so a caller never sorts or subsets it; `top` limits it in the
call.

Routes are keyed on their **vertex sequence**. The trajectory tree keys
a node on vertex *and* time, so one sequence realised through different
contacts appears there as several branches; those are one pathway here
and their counts are added. Under the foremost criterion this loses
nothing: only earliest-arrival routes survive to be counted, so
duplicates of a sequence necessarily share an arrival time, and a test
asserts it.

## See also

[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) for
reachability,
[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
for the prefix tree those routes share.

## Examples

``` r
dn <- dynet(school_contacts)
pathways(dn, from = "Ana")
#> # Time-respecting pathways (5 distinct routes)
#> # 7 optimal routes counted
#>                               route endpoint count     share n_hops
#>  Ana -> Jonas -> Kira -> Ben -> Eve      Eve     3 0.4285714      4
#>                 Ana -> Mira -> Gita     Gita     1 0.1428571      2
#>         Ana -> Cara -> Finn -> Iris     Iris     1 0.1428571      3
#>          Ana -> Cara -> Finn -> Leo      Leo     1 0.1428571      3
#>  Ana -> Cara -> Nils -> Hugo -> Dan      Dan     1 0.1428571      4
#>  arrival_time
#>         11.66
#>          6.36
#>         10.00
#>          9.65
#>          7.98
pathways(dn, from = c("Ana", "Ben", "Kira"), top = 5)
#> # Time-respecting pathways (22 distinct routes, showing 5)
#> # 30 optimal routes counted
#>                               route endpoint count      share n_hops
#>         Kira -> Leo -> Finn -> Nils     Nils     3 0.10000000      3
#>  Ana -> Jonas -> Kira -> Ben -> Eve      Eve     3 0.10000000      4
#>                 Kira -> Leo -> Iris     Iris     2 0.06666667      2
#>          Kira -> Leo -> Hugo -> Dan      Dan     2 0.06666667      3
#>   Ben -> Eve -> Kira -> Leo -> Hugo     Hugo     2 0.06666667      4
#>  arrival_time
#>          6.31
#>         11.66
#>          6.13
#>          7.79
#>          6.76
```
