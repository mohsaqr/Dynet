# Temporal community detection by generalized Louvain

Which vertices form a group, and how that group survives, splits or
dissolves as time passes. The partition is found by maximising the
multislice modularity of Mucha et al. (2010) over the time-expanded
network, so the slices are solved together rather than one at a time and
a community keeps its identity across bins by construction.

Two knobs decide what you get. `gamma` sets the resolution: how dense a
group has to be to count as one. `omega` sets how much a vertex is
rewarded for staying put, so it trades a partition that tracks each
bin's structure exactly against one that persists and is readable as a
story.

## Usage

``` r
temporal_communities(
  dn,
  gamma = 1,
  omega = 1,
  method = c("louvain", "consensus"),
  seeds = 1:10,
  coupling = c("ordinal", "categorical"),
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL,
  max_passes = 20L,
  tol = 1e-10
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- gamma:

  Resolution. Above one favours more, smaller communities; below one
  favours fewer, larger ones.

- omega:

  Interlayer coupling. Zero detects each bin independently and the
  labels are then matched by
  [`match_communities()`](https://pak.dynasite.org/Dynet/reference/match_communities.md);
  large values force one community per vertex for the whole series.

- method:

  `"louvain"` reports the best of the `seeds` runs. `"consensus"`
  reports the partition the runs agree on, built from their
  co-classification matrix (Lancichinetti & Fortunato 2012).

- seeds:

  The seeds to run from, one optimisation each. Modularity landscapes
  are near-degenerate, so a single run is not a result; the default runs
  ten and reports how much they agreed.

- coupling:

  `"ordinal"` couples consecutive slices, the temporal convention.
  `"categorical"` couples every pair, which asserts that the bins have
  no order.

- sessions:

  How to treat sessions. `"bounded"` and `"separate"` keep session-local
  blocks whose coupling never crosses a session wall.

- start, end:

  First and last slice times. Default to observed support.

- step:

  Spacing between slice starts.

- window:

  Width represented by each slice.

- max_passes:

  Cap on aggregation passes per run.

- tol:

  Smallest improvement that counts as a move.

## Value

A `dynet_communities` frame, one row per vertex per time bin: `session`
(only when the network has sessions), `time`, `node`, `community` (an
integer label, meaning the same group in every bin), `active` (was the
vertex eligible in this bin) and `stability` (in \\\[0, 1\]\\, how much
of the run-to-run variation this state survived). Print it,
[`summary()`](https://rdrr.io/r/base/summary.html) it,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) it, or take the
plain frame with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html), which
also serves `what = "runs"`, `"sizes"` and, after
[`match_communities()`](https://pak.dynasite.org/Dynet/reference/match_communities.md),
`"events"`.

## Details

The objective is
[`multislice_modularity()`](https://pak.dynasite.org/Dynet/reference/multislice_modularity.md),
and the two round-trip:
`multislice_modularity(dn, membership = temporal_communities(dn))`
returns the `q` this verb reports.

*Why several seeds.* Louvain visits vertices in some order and takes the
first improving move it finds, so its answer depends on that order, and
modularity landscapes are near-degenerate: very many partitions sit
within a hair of the maximum (Good, de Montjoye & Clauset 2010). One run
is a sample from that plateau, not the answer. This verb therefore runs
once per seed, reports the best, and reports how much the runs agreed –
`stability_ari`, the mean pairwise adjusted Rand index across runs, and
a per-state `stability` column. A `stability_ari` near one means the
labels can be read; near zero means they cannot, whatever the modularity
says. Asking for a single seed raises a `dynet_single_seed` warning for
that reason.

*What is not implemented.* The Leiden refinement (Traag, Waltman & van
Eck 2019) is not, so a community this verb reports can in principle be
internally disconnected – the known defect of Louvain. Running several
seeds and reading `stability_ari` is the mitigation on offer here.

*Inactive vertices.* A vertex with no activity in a bin still has its
identity arcs, because
[`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md)
lets a vertex wait through inactivity. It is therefore carried along by
the coupling and receives a label rather than being dropped, which would
break the chain. The `active` column marks those states.

*Reproducibility.* The result is a deterministic function of `seeds`:
two calls with the same seeds return identical frames. The caller's
random stream is saved and restored, so running this verb never changes
what the next [`sample()`](https://rdrr.io/r/base/sample.html) produces.

## References

Mucha, P. J., Richardson, T., Macon, K., Porter, M. A., & Onnela, J.-P.
(2010). Community structure in time-dependent, multiscale, and multiplex
networks. *Science*, 328(5980), 876-878.

Jeub, L. G. S., Bazzi, M., Jutla, I. S., & Mucha, P. J. (2011-2019). *A
generalized Louvain method for community detection implemented in
MATLAB.*

Blondel, V. D., Guillaume, J.-L., Lambiotte, R., & Lefebvre, E. (2008).
Fast unfolding of communities in large networks. *Journal of Statistical
Mechanics*, P10008.

Good, B. H., de Montjoye, Y.-A., & Clauset, A. (2010). Performance of
modularity maximization in practical contexts. *Physical Review E*,
81(4), 046106.

Lancichinetti, A., & Fortunato, S. (2012). Consensus clustering in
complex networks. *Scientific Reports*, 2, 336.

Bassett, D. S., Porter, M. A., Wymbs, N. F., Grafton, S. T., Carlson, J.
M., & Mucha, P. J. (2013). Robust detection of dynamic community
structure in networks. *Chaos*, 23(1), 013142.

Traag, V. A., Waltman, L., & van Eck, N. J. (2019). From Louvain to
Leiden: guaranteeing well-connected communities. *Scientific Reports*,
9, 5233.

## See also

[`multislice_modularity()`](https://pak.dynasite.org/Dynet/reference/multislice_modularity.md)
for the objective,
[`match_communities()`](https://pak.dynasite.org/Dynet/reference/match_communities.md)
for labels from an uncoupled run,
[`community_change()`](https://pak.dynasite.org/Dynet/reference/community_change.md)
for how much the partition moved,
[`community_trajectory()`](https://pak.dynasite.org/Dynet/reference/community_trajectory.md)
for what each vertex did, and
[`phases()`](https://pak.dynasite.org/Dynet/reference/phases.md) for
regimes found without communities at all.

## Examples

``` r
dn <- dynet(school_contacts)
found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
found
#> # Temporal communities: 3 over 5 bins | gamma = 1, omega = 1
#> # multislice Q = 0.5320 from 5 seeds | run agreement ARI = 1.000
#>  time  node community active stability
#>     0   Ana         1   TRUE         1
#>     0   Ben         2   TRUE         1
#>     0  Cara         3   TRUE         1
#>     0   Dan         1   TRUE         1
#>     0   Eve         2   TRUE         1
#>     0  Finn         3   TRUE         1
#>     0  Gita         1   TRUE         1
#>     0  Hugo         2   TRUE         1
#>     0  Iris         3   TRUE         1
#>     0 Jonas         1   TRUE         1
#>     0  Kira         2   TRUE         1
#>     0   Leo         3   TRUE         1
#> # 58 more rows. summary() gives one row per community.
summary(found)
#>   community n_states n_nodes first_time last_time n_bins persistence
#> 1         1       25       5          0        20      5           1
#> 2         2       25       5          0        20      5           1
#> 3         3       20       4          0        20      5           1
as.data.frame(found, what = "sizes")
#>    time community n_nodes n_active
#> 1     0         1       5        5
#> 2     0         2       5        5
#> 3     0         3       4        4
#> 13    5         1       5        5
#> 14    5         2       5        5
#> 15    5         3       4        4
#> 4    10         1       5        5
#> 5    10         2       5        5
#> 6    10         3       4        4
#> 7    15         1       5        5
#> 8    15         2       5        5
#> 9    15         3       4        4
#> 10   20         1       5        5
#> 11   20         2       5        5
#> 12   20         3       4        4
```
