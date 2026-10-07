# Multislice modularity of a partition of a temporal network

The Mucha et al. (2010) quality function: how much better a partition
explains the network than a degree-preserving null does, computed slice
by slice with the slices tied together by the interlayer coupling
`omega`.

Score a partition you already have – a class roster, a set of research
groups, an externally computed clustering – or score the one
[`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md)
found. It is the objective that verb maximises, so the two round-trip
with no reshaping by the caller.

## Usage

``` r
multislice_modularity(
  dn,
  membership = NULL,
  gamma = 1,
  omega = 1,
  coupling = c("ordinal", "categorical"),
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- membership:

  A data frame with columns `time`, `node` and `community`, plus
  `session` when the network has sessions. This is exactly the shape
  [`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md)
  returns. `NULL` scores the partition that puts every state in one
  community.

- gamma:

  Resolution. Values above one favour more, smaller communities; values
  below one favour fewer, larger ones.

- omega:

  Interlayer coupling: how much a vertex is rewarded for keeping its
  community from one slice to the next. Zero scores the slices
  independently.

- coupling:

  Which slices are coupled, `"ordinal"` (consecutive, the temporal
  convention) or `"categorical"` (all pairs). See
  [`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md).

- sessions:

  How to treat sessions: `"bounded"` and `"separate"` keep session-local
  blocks whose coupling never crosses a session wall, `"collapse"`
  erases the labels.

- start, end:

  First and last slice times. Default to observed support.

- step:

  Spacing between slice starts.

- window:

  Width represented by each slice.

## Value

A `dynet_metric` at graph level, one row per component of the
decomposition: `q` (the multislice modularity), `q_intra` and `q_inter`
(its within-slice and interlayer parts, which sum to `q`), `two_mu` (the
normaliser), `n_communities` and `n_empty_slices`. Columns are `measure`
and `value`; there is no `time` column because \\Q\\ is a property of
the whole series, not of a bin. Attributes carry `gamma`, `omega`,
`coupling` and `symmetrised`.

## Details

With \\A\_{ijs}\\ the weight of edge \\i\\–\\j\\ in slice \\s\\,
\\k\_{is}\\ its slice-local strength, \\2m_s\\ the slice total,
\\\omega\_{jsr}\\ the coupling of vertex \\j\\ between slices \\s\\ and
\\r\\, and \\2\mu = \sum\_{js}(k\_{js} + \sum_r \omega\_{jsr})\\, \$\$Q
= \frac{1}{2\mu}\sum\_{ijsr}\left\[\left(A\_{ijs} -
\gamma\frac{k\_{is}k\_{js}}{2m_s}\right)\delta\_{sr} +
\delta\_{ij}\omega\_{jsr}\right\]\delta(g\_{is}, g\_{jr}).\$\$

Three things in that formula are not the static null, and getting any of
them wrong gives a different objective that still looks plausible:

1.  The null uses \\k\_{is}\\, \\k\_{js}\\ and \\2m_s\\ **from slice
    \\s\\ alone**, never the supra-degree. That is what lets a sparse
    bin and a dense bin be compared at all.

2.  The null is multiplied by \\\delta\_{sr}\\, so **no null is
    subtracted from the interlayer arcs**. Identity arcs are not edges
    to be explained away; they assert that a vertex is the same vertex.

3.  The normaliser \\2\mu\\ **includes** the coupling strength, which is
    why \\Q\\ does not diverge as `omega` grows.

Running
[`igraph::cluster_louvain()`](https://r.igraph.org/reference/cluster_louvain.html)
on the supra-adjacency matrix gets all three wrong: it applies the
static Newman–Girvan null to the whole supra-graph. That is a different
objective function, not a different implementation of this one.

Two exact reductions follow from the formula and are pinned by tests.
With one slice and `omega = 0`, \\Q\\ is ordinary Newman–Girvan
modularity. With `omega = 0` and any number of slices, \\Q\\ is the
\\2m_s\\- weighted mean of the per-slice Newman–Girvan modularities.

An edgeless slice has \\2m_s = 0\\ and would divide by zero; its null
contribution is defined as exactly zero, and `n_empty_slices` reports
how many such slices there were. A network with no edges and no coupling
has \\2\mu = 0\\ and no defined \\Q\\ at all, which raises
`dynet_empty_result` rather than returning `NaN`.

A directed network is averaged with its transpose before scoring,
because the published quality function is defined for symmetric slices.
The result records this in its `symmetrised` attribute.

## References

Mucha, P. J., Richardson, T., Macon, K., Porter, M. A., & Onnela, J.-P.
(2010). Community structure in time-dependent, multiscale, and multiplex
networks. *Science*, 328(5980), 876-878.

Newman, M. E. J., & Girvan, M. (2004). Finding and evaluating community
structure in networks. *Physical Review E*, 69(2), 026113.

Reichardt, J., & Bornholdt, S. (2006). Statistical mechanics of
community detection. *Physical Review E*, 74(1), 016110.

Bazzi, M., Porter, M. A., Williams, S., McDonald, M., Fenn, D. J., &
Howison, S. D. (2016). Community detection in temporal multilayer
networks, with an application to correlation networks. *Multiscale
Modeling & Simulation*, 14(1), 1-41.

## See also

[`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md),
which maximises this quantity, and
[`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md),
which builds the time-expanded network it is defined on.

## Examples

``` r
dn <- dynet(school_contacts)
multislice_modularity(dn, step = 5, window = 5)
#> # Multislice modularity (graph-level)
#> # time in step
#> # measures: q, q_intra, q_inter, two_mu, n_communities, n_empty_slices
#> # directed slices averaged with their transpose
#>         measure       value
#>               q   0.2955145
#>         q_intra   0.0000000
#>         q_inter   0.2955145
#>          two_mu 379.0000000
#>   n_communities   1.0000000
#>  n_empty_slices   0.0000000
multislice_modularity(dn, membership = temporal_communities(
  dn, step = 5, window = 5, seeds = 1:3
), step = 5, window = 5)
#> # Multislice modularity (graph-level)
#> # time in step
#> # measures: q, q_intra, q_inter, two_mu, n_communities, n_empty_slices
#> # directed slices averaged with their transpose
#>         measure       value
#>               q   0.5320048
#>         q_intra   0.2364903
#>         q_inter   0.2955145
#>          two_mu 379.0000000
#>   n_communities   3.0000000
#>  n_empty_slices   0.0000000
```
