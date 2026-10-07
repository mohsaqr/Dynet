# How much the community structure moved between bins

"Who is with whom" and "did the structure reorganise, and when" are
different questions. This one compares each bin's partition with another
bin's by a label-invariant statistic, so it says how much changed
without needing to know which community became which.

Because every statistic here is invariant to relabelling,
[`match_communities()`](https://pak.dynasite.org/Dynet/reference/match_communities.md)
is **not** a prerequisite. That is a common misunderstanding and it is
worth stating plainly: matching is needed to follow a community, not to
measure change.

## Usage

``` r
community_change(
  x,
  measure = c("nmi", "ami", "ari", "vi", "split_join", "jaccard", "omega_index", "uami",
    "iami"),
  against = c("previous", "first", "all")
)
```

## Arguments

- x:

  A `dynet_communities` frame from
  [`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md).

- measure:

  One or more of `"nmi"`, `"ami"`, `"uami"`, `"iami"`, `"ari"`, `"vi"`,
  `"split_join"`, `"jaccard"` and `"omega_index"`. The default asks for
  the first several; name them explicitly to choose.

- against:

  `"previous"` compares each bin with the one before it, `"first"` with
  the opening bin, `"all"` with every other bin.

## Value

A `dynet_metric` at graph level. For `"previous"` and `"first"`, one row
per bin per measure with columns `session`, `time`, `measure`, `value`;
for `"all"`, one row per ordered pair with an `other` column giving the
bin compared against, in the same long shape
[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md)
uses so both plot with the same code. The `n_compared` attribute records
how many vertices each comparison could actually use.

## Details

Every statistic is built from the contingency table of the two
labellings, restricted to the vertices **active in both** bins. A vertex
that merely goes quiet must not read as a reorganisation, so it is
dropped from both sides rather than counted as having left its
community. When fewer than two vertices are shared, nothing is defined
and the value is `NA` – a real absence, not a zero.

The first bin has no predecessor, so under `against = "previous"` its
value is `NA` by construction.

What each measures, briefly. `"nmi"` is shared information normalised by
the mean entropy, in \\\[0, 1\]\\, high for agreement; it is **not**
chance-corrected, so two unrelated partitions score above zero. `"ami"`
is the same quantity with the chance level subtracted, and is the one to
reach for. `"ari"` is chance-corrected pair agreement, centred on zero
for unrelated partitions. `"vi"` is a true metric in nats, zero for
agreement and unbounded above. `"split_join"` counts the vertices that
would have to move, so it is an integer in \\\[0, 2N\]\\. `"jaccard"`
scores agreement over co-classified pairs. `"omega_index"` is
chance-corrected pair agreement; for the disjoint partitions this
package produces it coincides exactly with `"ari"`, and it is offered
because it is what `multinet` reports and because it generalises to
overlapping communities.

`"uami"` and `"iami"` are Zhong et al.'s (2025) answer to a problem
every temporal network has: the vertex set moves between bins, and
ordinary mutual information assumes it does not. `"iami"` compares over
the **intersection**, the vertices both bins have. `"uami"` compares
over the **union**, giving each partition one extra virtual community
holding the vertices it does not have, so a vertex arriving or leaving
is itself information about the change rather than something discarded.
The two answer different questions: `"iami"` asks whether the vertices
that stayed kept their company, `"uami"` asks whether the whole
structure held. Since every other measure here is already restricted to
the shared vertices, `"iami"` is numerically identical to `"ami"` in
this package, and is offered under both names because the literature
uses both.

Two notes on the sources, because both cost time to discover. Adjusted
mutual information admits more than one normaliser: this package divides
by the **arithmetic mean** of the two entropies, matching `"nmi"` above,
`sklearn`'s default, and the stated intent of Zhong et al.;
`aricode::AMI` divides by the **maximum** instead, so the two disagree
by convention and not by error. And the expression printed for the
adjusted measures in Zhong et al. subtracts the chance term once in a
denominator that needs it twice, which scores two identical partitions
at 0.949 rather than 1; the corrected form is used here.

## References

Danon, L., Diaz-Guilera, A., Duch, J., & Arenas, A. (2005). Comparing
community structure identification. *Journal of Statistical Mechanics*,
P09008.

Hubert, L., & Arabie, P. (1985). Comparing partitions. *Journal of
Classification*, 2, 193-218.

Meila, M. (2007). Comparing clusterings – an information based distance.
*Journal of Multivariate Analysis*, 98(5), 873-895.

van Dongen, S. (2000). *Performance criteria for graph clustering and
Markov cluster experiments.* CWI Technical Report INS-R0012.

Collins, L. M., & Dent, C. W. (1988). Omega: a general formulation of
the Rand index of cluster recovery suitable for non-disjoint solutions.
*Multivariate Behavioral Research*, 23(2), 231-242.

Gates, A. J., & Ahn, Y.-Y. (2019). Element-centric clustering comparison
unifies overlaps and hierarchy. *Scientific Reports*, 9, 8574.

Vinh, N. X., Epps, J., & Bailey, J. (2010). Information theoretic
measures for clusterings comparison. *JMLR*, 11, 2837-2854.

Zhong, P., Ba, C., Mondragon, R., & Clegg, R. (2025). Quantifying
community evolution in temporal networks. *Scientific Reports*, 15,
45373.

## Examples

``` r
dn <- dynet(school_contacts)
found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
community_change(found)
#> # Community change (graph-level)
#> # 5 time points, 5 per bin | time in step
#> # measures: nmi, ami, ari, vi, split_join, jaccard, omega_index, uami, iami
#> # compared against the previous bin, over vertices active in both
#>  time     measure value
#>     0         nmi    NA
#>     0         ami    NA
#>     0         ari    NA
#>     0          vi    NA
#>     0  split_join    NA
#>     0     jaccard    NA
#>     0 omega_index    NA
#>     0        uami    NA
#>     0        iami    NA
#>     5         nmi     1
#>     5         ami     1
#>     5         ari     1
#> # 33 more rows. summary() aggregates them; plot() draws them.
community_change(found, measure = c("ami", "ari"))
#> # Community change (graph-level)
#> # 5 time points, 5 per bin | time in step
#> # measures: ami, ari
#> # compared against the previous bin, over vertices active in both
#>  time measure value
#>     0     ami    NA
#>     0     ari    NA
#>     5     ami     1
#>     5     ari     1
#>    10     ami     1
#>    10     ari     1
#>    15     ami     1
#>    15     ari     1
#>    20     ami     1
#>    20     ari     1
community_change(found, measure = c("iami", "uami"))
#> # Community change (graph-level)
#> # 5 time points, 5 per bin | time in step
#> # measures: iami, uami
#> # compared against the previous bin, over vertices active in both
#>  time measure value
#>     0    iami    NA
#>     0    uami    NA
#>     5    iami     1
#>     5    uami     1
#>    10    iami     1
#>    10    uami     1
#>    15    iami     1
#>    15    uami     1
#>    20    iami     1
#>    20    uami     1
```
