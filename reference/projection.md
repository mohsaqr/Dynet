# Project a temporal network into directed vertex-time states

`projection()` discretizes a temporal network into snapshot slices and
connects each vertex state to its realization in the next slice. Within
a slice it uses the same independently aggregated, endpoint-induced
snapshot as
[`snapshots()`](https://mohsaqr.github.io/Dynet/reference/snapshots.md).
Identity arcs always point forward and carry the coupling weight
`omega`. The result is a tidy projection object rather than a bare
matrix.

## Usage

``` r
projection(
  dn,
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL,
  omega = 1
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- sessions:

  Session handling. `"collapse"` erases labels. For a sessioned network,
  `"bounded"` and `"separate"` both preserve disjoint session-local
  projection blocks so identity arcs never cross a wall.

- start, end:

  First and last slice times. Defaults to observed support.

- step:

  Spacing between slice starts. `NULL` uses the construction interval.

- window:

  Width represented by each slice. `NULL` uses `step`; zero samples an
  exact point; `"all"` represents the whole observed period as a single
  slice, closed on the right.

- omega:

  Weight on the identity arcs that carry a vertex from one slice to the
  next, that is, the interlayer coupling of the time-expanded network.
  One keeps an identity arc as heavy as a unit contact; zero leaves the
  slices uncoupled. Must be a single non-negative number.

## Value

An object of class `dynet_projection`. Use
`as.data.frame(x, what = "vertices")` for vertex states and
`as.data.frame(x, what = "edges")` for directed projected arcs.

## Details

Every fixed-universe vertex receives one state in every emitted slice.
`active` records whether the vertex was eligible in that slice. Identity
arcs are retained through inactive slices because Dynet permits waiting
through vertex inactivity; inactive states simply have no incident
endpoint-induced within-slice edge. Consecutive observed slices are also
linked across an observation gap, matching Dynet's calendar-time waiting
convention.

Directed source edges produce one within-slice arc. An undirected
nonloop edge produces reciprocal arcs, while an undirected loop is
emitted once. Parallel active spells are one within-slice pair whose
`weight` is their summed weight and whose `n_spells` records their
count. Identity arcs have `weight = omega` and `n_spells = 0`, and
`meta$identity_weight` reports the same value.

## References

Bender-deMoll, S., & Moody, J. `timeProjectedNetwork()` in the `tsna`
package, version 0.3.6.

Butts, C. T., Leslie-Cook, A., Krivitsky, P. N., & Bender-deMoll, S.
(2024). *networkDynamic: Dynamic Extensions for Network Objects*,
version 0.11.5.
[doi:10.32614/CRAN.package.networkDynamic](https://doi.org/10.32614/CRAN.package.networkDynamic)

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "B", "C"), to = c("B", "C", "A"),
  start = 0:2, end = 1:3
), observation_start = 0, observation_end = 3)
projected <- projection(dn, step = 1, window = 1)
as.data.frame(projected, what = "vertices")
#>   state slice time start end closed node active
#> 1     1     1    0     0   1  FALSE    A   TRUE
#> 2     2     1    0     0   1  FALSE    B   TRUE
#> 3     3     1    0     0   1  FALSE    C   TRUE
#> 4     4     2    1     1   2  FALSE    A   TRUE
#> 5     5     2    1     1   2  FALSE    B   TRUE
#> 6     6     2    1     1   2  FALSE    C   TRUE
#> 7     7     3    2     2   3   TRUE    A   TRUE
#> 8     8     3    2     2   3   TRUE    B   TRUE
#> 9     9     3    2     2   3   TRUE    C   TRUE
as.data.frame(projected, what = "edges")
#>   from_state to_state from_node to_node from_slice to_slice from_time to_time
#> 1          1        2         A       B          1        1         0       0
#> 2          1        4         A       A          1        2         0       1
#> 3          2        5         B       B          1        2         0       1
#> 4          3        6         C       C          1        2         0       1
#> 5          5        6         B       C          2        2         1       1
#> 6          4        7         A       A          2        3         1       2
#> 7          5        8         B       B          2        3         1       2
#> 8          6        9         C       C          2        3         1       2
#> 9          9        7         C       A          3        3         2       2
#>      edge_type weight n_spells lag
#> 1 within_slice      1        1   0
#> 2 identity_arc      1        0   1
#> 3 identity_arc      1        0   1
#> 4 identity_arc      1        0   1
#> 5 within_slice      1        1   0
#> 6 identity_arc      1        0   1
#> 7 identity_arc      1        0   1
#> 8 identity_arc      1        0   1
#> 9 within_slice      1        1   0
```
