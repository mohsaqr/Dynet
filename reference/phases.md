# Detect temporal phases by clustering the between-bin similarity

A similarity heatmap invites the question "so how many regimes are
there, and where does each begin". This answers it: cluster the bins by
how alike their networks are, and report the blocks.

It is the other way of thinking about temporal structure from
[`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md).
That one asks which vertices group together and lets the grouping change
over time; this one asks which *moments* group together and does not
look at vertices at all.

## Usage

``` r
phases(
  dn,
  k = NULL,
  method = c("jaccard", "overlap", "hamming", "cosine", "pearson"),
  linkage = c("ward.D2", "average", "complete"),
  contiguous = TRUE,
  k_max = 10L,
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

- k:

  Number of phases. `NULL` chooses it by the silhouette maximum over
  `2:k_max` and reports the whole profile, so the choice is visible and
  its sensitivity checkable.

- method:

  How to compare two bins, passed to
  [`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md).

- linkage:

  Agglomeration method for
  [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html), used only
  when `contiguous = FALSE`.

- contiguous:

  `TRUE`, the default and the temporally meaningful choice, forces each
  phase to be an unbroken stretch of time and solves that partition
  exactly. `FALSE` lets a phase recur, which is what cyclic data such as
  weekday-and-weekend needs.

- k_max:

  Largest number of phases to consider when `k` is `NULL`.

- sessions:

  How to treat sessions.

- start, end:

  First and last bin times.

- step:

  Spacing between bin starts.

- window:

  Width represented by each bin.

## Value

A `dynet_phases` frame, one row per time bin: `session` (only when the
network has sessions), `time`, `phase`, `boundary` (is this the first
bin of its phase) and `silhouette` (this bin's width under the chosen
`k`). Print it, [`plot()`](https://rdrr.io/r/graphics/plot.default.html)
it, or take the plain frame with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html), which
also serves `what = "profile"` for the \\k\\-by-\\k\\ sensitivity table
and `what = "phases"` for one row per phase.

## Details

The distance between two bins is `1 - similarity` for every method
except `"hamming"`, which already reports disagreement and is instead
divided by the number of vertex pairs that could carry a tie. Getting
that one backwards would silently invert the answer, so it is handled
explicitly. `"pearson"` similarity can be negative, so its distance runs
in \\\[0, 2\]\\ rather than \\\[0, 1\]\\; that is a valid distance, but
do not expect the unit scale.

With `contiguous = TRUE` the bins are partitioned by Fisher's (1958)
dynamic program, which minimises total within-phase scatter over all
contiguous partitions. That is exact and deterministic. Cutting a
dendrogram is neither: it is a greedy agglomeration and it can put bin 3
and bin 40 in a phase that bin 20 is not in, which is not a regime.

**Nothing here is random.**
[`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md)
needs seeds because modularity maximisation is a heuristic on a
near-degenerate landscape; this verb needs none because both of its
steps are exact. Two calls return identical results and the caller's
random stream is never touched. The difference is deliberate.

For the Bayesian changepoint approach to the same question – a different
paradigm, with MCMC and its own diagnostics – see the `NetworkChange`
package, which this deliberately does not reimplement.

## References

Fisher, W. D. (1958). On grouping for maximum homogeneity. *Journal of
the American Statistical Association*, 53(284), 789-798.

Rousseeuw, P. J. (1987). Silhouettes: a graphical aid to the
interpretation and validation of cluster analysis. *Journal of
Computational and Applied Mathematics*, 20, 53-65.

Murtagh, F., & Legendre, P. (2014). Ward's hierarchical agglomerative
clustering method: which algorithms implement Ward's criterion? *Journal
of Classification*, 31, 274-295.

Lucas, M., Morris, A., Townsend-Teague, A., Tichit, L., Habermann, B.
H., & Barrat, A. (2023). Inferring cell cycle phases from a partially
temporal network of protein interactions. *Cell Reports Methods*, 3(3),
100397.

Park, J. H., & Sohn, Y. (2020). Detecting structural changes in
longitudinal network data. *Bayesian Analysis*, 15(1), 133-157.

## See also

[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md),
whose matrix this clusters, and
[`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md)
for the vertex-side question.

## Examples

``` r
dn <- dynet(school_contacts)
phases(dn, step = 2, window = 2)
#> # Temporal phases: 10 over 11 bins | jaccard distance, contiguous (exact)
#> # phases begin at  0,  2,  4,  6,  8, 10, 12, 16, 18, 20 (step)
#> # mean silhouette 0.214  <- weak separation; the phases may not be real
#>  time phase boundary silhouette
#>     0     1     TRUE         NA
#>     2     2     TRUE         NA
#>     4     3     TRUE         NA
#>     6     4     TRUE         NA
#>     8     5     TRUE         NA
#>    10     6     TRUE         NA
#>    12     7     TRUE  0.1640867
#>    14     7    FALSE  0.2647059
#>    16     8     TRUE         NA
#>    18     9     TRUE         NA
#>    20    10     TRUE         NA
as.data.frame(phases(dn, step = 2, window = 2), what = "profile")
#>    k silhouette_mean within_ss n_singletons
#> 1  2      0.08624354 3.3415465            0
#> 2  3      0.08626214 2.7928177            0
#> 3  4      0.09890611 2.3001677            1
#> 4  5      0.10917620 1.8469686            2
#> 5  6      0.10328176 1.4167754            2
#> 6  7      0.13445671 1.0306414            4
#> 7  8      0.15258988 0.7146499            5
#> 8  9      0.16044399 0.4258499            7
#> 9 10      0.21439628 0.1730104            9
```
