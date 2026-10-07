# What each vertex did across the community structure

Once labels mean the same thing in every bin, the interesting quantities
are about vertices rather than communities: how often one changes group,
how many groups it has belonged to, how reliably it stays put, how often
two vertices are found together, and how tightly a vertex sticks to its
own reference group rather than visiting others.

## Usage

``` r
community_trajectory(
  x,
  measure = c("flexibility", "promiscuity", "persistence"),
  reference = NULL
)
```

## Arguments

- x:

  A `dynet_communities` frame whose labels are consistent across bins –
  either from
  [`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md)
  with `omega > 0`, or from
  [`match_communities()`](https://pak.dynasite.org/Dynet/reference/match_communities.md).

- measure:

  One or more of `"flexibility"`, `"promiscuity"`, `"persistence"`,
  `"recruitment"` and `"integration"`.

- reference:

  For `"recruitment"` and `"integration"`: the name of a vertex
  attribute on the network the partition came from, or one group label
  per vertex. Those two measures compare a vertex's allegiance to its
  own reference group against its allegiance to the others, so they have
  no meaning without one.

## Value

A `dynet_metric` at node level, one row per vertex per measure, with
columns `session` (only when the network has sessions), `node`,
`measure` and `value`. Every measure here summarises the whole series,
so there is no `time` column; the per-bin and whole-series forms of
persistence, and the pairwise allegiance table, are reached by
`as.data.frame(x, what = )`.

## Details

Let \\C\_{it}\\ be the community of vertex \\i\\ in bin \\t\\, over
\\T\\ bins.

**Flexibility** is the share of consecutive bins in which a vertex
changed community, \\\frac{1}{T-1}\sum\_{t=2}^{T}\[C\_{it} \ne
C\_{i,t-1}\]\\.

**Promiscuity** is how much of the whole community structure a vertex
visited: its distinct-label count minus one, over the **global**
distinct-label count minus one. A vertex that never moves scores zero;
one that visits every community scores one. The denominator is global,
not per vertex; that is teneto's convention and it is what makes the
measure comparable across vertices.

**Persistence** is the complement of flexibility, and comes at three
granularities: per vertex, per bin, and one number for the whole series.
The per-bin form is `NA` in the first bin, which has no predecessor.

**Allegiance** \\P\_{ij} = \frac{1}{T}\sum_t \[C\_{it} = C\_{jt}\]\\ is
how often two vertices were in the same community. It divides by the
number of bins, not by the bins in which both were active – teneto's
convention, replicated here so the numbers agree.

**Recruitment** is a vertex's mean allegiance to the other members of
its own `reference` group; **integration** is its mean allegiance to
vertices outside it.

*Why the labels must be matched first.* All of these read a change of
label as a change of group. If the labels are per-bin arbitrary – which
they are whenever the slices were solved independently – then
flexibility measures relabelling noise and nothing else. This verb
therefore refuses to run on an unmatched partition rather than returning
a number that looks fine.

*Inactive vertices.* A vertex inactive in a bin still carries the label
its identity arc brought it, matching
[`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md)'s
waiting convention, so it is neither dropped nor treated as having left.
`n_inactive_states` records how many states that covers, so the reader
can judge.

## References

Bassett, D. S., Wymbs, N. F., Porter, M. A., Mucha, P. J., Carlson, J.
M., & Grafton, S. T. (2011). Dynamic reconfiguration of human brain
networks during learning. *PNAS*, 108(18), 7641-7646.

Papadopoulos, L., Puckett, J. G., Daniels, K. E., & Bassett, D. S.
(2016). Evolution of network architecture in a granular material under
compression. *Physical Review E*, 94(3), 032908.

Bassett, D. S., Porter, M. A., Wymbs, N. F., Grafton, S. T., Carlson, J.
M., & Mucha, P. J. (2013). Robust detection of dynamic community
structure in networks. *Chaos*, 23(1), 013142.

Bassett, D. S., Yang, M., Wymbs, N. F., & Grafton, S. T. (2015).
Learning-induced autonomy of sensorimotor systems. *Nature
Neuroscience*, 18(5), 744-751.

Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to
temporal network theory. *Network Neuroscience*, 1(2), 69-99.

## Examples

``` r
dn <- dynet(school_contacts)
found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
community_trajectory(found)
#> # Community trajectory (node-level)
#> # 14 vertices | time in step
#> # measures: flexibility, promiscuity, persistence
#>   node     measure value
#>    Ana flexibility     0
#>    Ben flexibility     0
#>   Cara flexibility     0
#>    Dan flexibility     0
#>    Eve flexibility     0
#>   Finn flexibility     0
#>   Gita flexibility     0
#>   Hugo flexibility     0
#>   Iris flexibility     0
#>  Jonas flexibility     0
#>   Kira flexibility     0
#>    Leo flexibility     0
#> # 30 more rows. summary() aggregates them; plot() draws them.
as.data.frame(community_trajectory(found), what = "time")
#>   time     measure value
#> 1    0 persistence    NA
#> 2    5 persistence     1
#> 3   10 persistence     1
#> 4   15 persistence     1
#> 5   20 persistence     1
```
