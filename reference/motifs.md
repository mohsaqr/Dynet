# Delta-temporal three-node motif census

Counts the 40 Paranjape three-edge, three-node temporal motif classes,
in the class ordering of raphtory 0.17.0 so a census can be checked
against an independent implementation index by index.

## Usage

``` r
motifs(
  dn,
  delta,
  output = c("global", "local"),
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL
)
```

## Arguments

- dn:

  A directed temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- delta:

  Window width, in the network's time unit. A triple of events is a
  motif instance when its last event is no later than `delta` after its
  first. **Required, with no default**: there is no principled default
  width, and a silent one would make every count an artefact of a number
  the user never chose.
  [`gaps()`](https://pak.dynasite.org/Dynet/reference/gaps.md) is the
  honest way to pick one.

- output:

  `"global"`, the default, for the 40-row network census, or `"local"`
  for 40 rows per vertex.

- sessions:

  How to treat sessions, as in
  [`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md).

- start, end:

  Optional inclusive query limits.

## Value

A `dynet_motifs` data frame. Under `output = "global"` the columns are
`motif` (the 1-based raphtory index), `family`, `pattern` and `count`;
under `"local"` a `node` column precedes them. A leading `session`
column is present under `sessions = "separate"`. All 40 classes are
always present, zeros included – a census with rows silently missing is
not a census. Print it,
[`summary()`](https://rdrr.io/r/base/summary.html) it,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) it, or take the
plain frame with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

## Details

**The definition.** Three incompatible motif families exist in the
literature. This adopts Paranjape, Benson & Leskovec (2017): exactly
three edge events on at most three distinct vertices, with
`t_last - t_first <= delta` over the three times in sorted order.
Kovanen et al. (2011) instead allow arbitrary size and bound
*consecutive* gaps, which is a strictly weaker condition and agrees only
for two-edge patterns; that family's instance count is unbounded and
does not reduce to a fixed census.

The three edges are three distinct *events*; the same pair may repeat,
which is exactly what the two-node classes are. Loops are excluded, and
instances may share edges – every qualifying triple is counted, as in
the reference implementations. Edge-disjoint counting is a different and
much harder problem, and is not what any reference computes.

**Local counting is not uniform across families**, and this is
raphtory's rule, adopted verbatim. For a star only the centre counts the
instance; for a triangle all three vertices do; for a two-node motif the
global census itself already records one count at each endpoint's class.
So the local counts sum to the global counts for stars and two-node
motifs, and to three times the global counts for triangles.

**Simultaneous events** are ordered by the deterministic key
`(time, from, to, spell)`. Paranjape assumes distinct timestamps; this
is Dynet's choice, so that a census never depends on input row order.

The enumeration is the direct one, quadratic in the number of events
sharing a window. Paranjape's incremental algorithm is linear; this is
not it, and a very large `delta` on a bursty network will be slow.

## Conditions

Errors: `dynet_needs_directed` on an undirected network, since the
40-class taxonomy is defined by edge directions and has no honest
undirected reading; `dynet_bad_input` when `delta` is missing, not a
single finite non-negative number, or when `dn` is not a `dynet`;
`dynet_no_sessions` under `sessions = "separate"` without a session
column; `dynet_count_overflow` when a class exceeds `2^53`.

## References

Paranjape, A., Benson, A. R., & Leskovec, J. (2017). Motifs in temporal
networks. *WSDM '17*, 601-610.
[doi:10.1145/3018661.3018731](https://doi.org/10.1145/3018661.3018731)

Kovanen, L., Karsai, M., Kaski, K., Kertesz, J., & Saramaki, J. (2011).
Temporal motifs in time-dependent networks. *Journal of Statistical
Mechanics*, P11005.
[doi:10.1088/1742-5468/2011/11/P11005](https://doi.org/10.1088/1742-5468/2011/11/P11005)

## See also

[`gaps()`](https://pak.dynasite.org/Dynet/reference/gaps.md) for
choosing `delta`, and
[`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md) for
the dyadic turn-taking census, which counts the same events with a
different arity.

## Examples

``` r
dn <- dynet(school_contacts)
census <- motifs(dn, delta = 2)
census
#> # Temporal motifs (Paranjape 2017, 40 classes), delta = 2 step
#> # 1471 instances across 40 non-zero classes | global output
#>  motif    family     pattern count
#>     15  star_mid         OOI    60
#>     14  star_mid         OIO    55
#>      7  star_pre         OOI    53
#>     39  triangle 0>1,0>2,1>2    53
#>     11  star_mid         IOI    52
#>     13  star_mid         OII    52
#>     18 star_post         IIO    52
#>     23 star_post         OOI    52
#>     16  star_mid         OOO    51
#>     19 star_post         IOI    50
#> # 30 more rows; as.data.frame() for the whole census
```
