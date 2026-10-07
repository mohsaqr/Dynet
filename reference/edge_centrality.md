# Temporal centrality of the contacts themselves

Credits every optimal time-respecting journey to the contacts that
carried it, giving a betweenness score per contact rather than per
vertex. This is the measure intervention questions actually ask: not
which people matter, but which meetings did.

The row unit is one canonical contact, not one pair. The same `A -> B`
pair active in two disjoint spells is two rows, because a journey uses
one of them and not the other.

## Usage

``` r
edge_centrality(
  dn,
  measure = "betweenness",
  criterion = c("foremost_then_shortest", "min_hops", "foremost", "fastest"),
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  traversal_time = 0
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- measure:

  Currently `"betweenness"`.

- criterion:

  Which optimisation problem the credited journeys solve, as in
  [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md).
  `"foremost"` is refused with `dynet_intractable_criterion`: crediting
  contacts needs the count of every vertex-simple foremost journey,
  which is \#P-hard.

- sessions:

  Session aggregation policy.

- start, end:

  First and last time to search.

- traversal_time:

  Nonnegative duration charged for every hop.

## Value

A `dynet_metric` at edge level, one row per contact, with columns
`from`, `to`, `start`, `end`, `measure` and `value`. A contact used by
no optimal journey is present with value zero rather than dropped, so
the result is a complete census.

## Details

The score is not normalised, and its range is the same `[0, (n-1)(n-2)]`
as the vertex measure.

An exact identity ties this to
[`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md):
because every optimal journey is vertex-simple, it enters each vertex
through exactly one contact, so the scores of the contacts arriving at a
vertex sum to that vertex's temporal betweenness plus the number of
sources that reach it. The tests assert it, which makes this verb
checkable without any external reference.

## References

Oettershagen, L., and Mutzel, P. (2022). TGLib: an open-source library
for temporal graph analysis. *ICDM Workshops*. arXiv:2209.12587.

Brandes, U. (2001). A faster algorithm for betweenness centrality.
*Journal of Mathematical Sociology*, 25(2), 163-177.

## See also

[`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md)
for the vertex form.

## Examples

``` r
dn <- dynet(school_contacts)
edge_centrality(dn)
#> # Contact betweenness (edge-level)
#> # time in step
#> # optimal journeys credited to the contacts that carried them
#>   from   to     measure     value start  end
#>  Jonas  Dan betweenness  5.333333  0.00 1.10
#>   Gita  Ana betweenness  9.000000  0.14 0.98
#>    Leo Mira betweenness  5.000000  0.15 0.42
#>    Leo Iris betweenness  6.000000  0.15 0.96
#>   Kira  Ben betweenness  2.583333  0.33 0.69
#>    Eve Hugo betweenness  3.333333  0.43 0.81
#>    Eve Kira betweenness  9.166667  0.77 1.42
#>   Iris Cara betweenness 10.000000  0.78 1.31
#>   Mira Finn betweenness  5.083333  0.83 0.97
#>  Jonas Mira betweenness  6.500000  0.92 1.31
#>   Mira  Eve betweenness 15.416667  1.23 1.86
#>    Eve Iris betweenness 12.500000  1.34 1.85
#> # 219 more rows. summary() aggregates them; plot() draws them.
```
