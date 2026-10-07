# Give community labels a meaning that carries across time

A community label is arbitrary within a bin. If bin 3's "community 2" is
bin 4's "community 1", then flexibility, persistence and allegiance
measure relabelling noise and nothing else. This verb walks the bins in
order and gives a community the label of whichever earlier community it
most overlaps with, so a label means the same group throughout.

**You usually do not need this.** When
[`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md)
runs with `omega > 0`, the interlayer coupling *is* the matching,
performed inside the objective rather than as a post-hoc heuristic, and
the labels are already consistent. Matching is for `omega = 0`, for
per-bin detection, for comparing runs at different `gamma`, and for a
partition computed elsewhere.

## Usage

``` r
match_communities(
  x,
  method = c("hungarian", "greedy"),
  overlap = c("jaccard", "intersection"),
  threshold = 0.1
)
```

## Arguments

- x:

  A `dynet_communities` frame from
  [`temporal_communities()`](https://pak.dynasite.org/Dynet/reference/temporal_communities.md),
  or any data frame with `time`, `node` and `community` columns.

- method:

  `"hungarian"` solves the assignment optimally, so the answer does not
  depend on the order of the rows. `"greedy"` takes the best overlap
  first and is offered only for comparability with the published
  event-detection literature; it is order-dependent and therefore not
  reproducible across row permutations.

- overlap:

  How to score a candidate pairing: `"jaccard"`, the shared members over
  the members of either, which is comparable across communities of
  different sizes; or `"intersection"`, the raw count of shared members.

- threshold:

  Minimum overlap for a community to inherit an earlier label rather
  than start a new one. In \\\[0, 1\]\\ for `"jaccard"`, a non-negative
  count for `"intersection"`.

## Value

A `dynet_communities` frame with the same rows as `x` and three
guarantees: `community` now carries the matched, time-consistent label;
`community_raw` keeps the original per-bin label so the matching is
auditable; and `event` records what happened to this state's community
at this bin, one of `"born"`, `"persist"`, `"split"` or `"merge"`. The
community-level lifecycle table, which also carries `"dissolve"`, is
`as.data.frame(x, what = "events")`.

## Details

Overlaps are computed only over the vertices active in **both** bins, so
a community whose members merely go quiet is not read as dissolving.

The event taxonomy is Greene, Doyle and Cunningham's (2010), with an
optimal assignment step in place of their greedy one. A bin-\\s\\
community that overlaps two or more bin-\\s{+}1\\ communities above
`threshold` has **split**: the assigned one inherits the label and the
others are born, and every state involved is marked `"split"`. The
mirror case, two earlier communities feeding one later one, is a
**merge**. When both descriptions fit, `"split"` is reported.

Labels are never recycled. A community that dissolves at bin 10 and an
unrelated one born at bin 40 cannot share a label, so a long series does
not silently reconnect two different groups.

## References

Kuhn, H. W. (1955). The Hungarian method for the assignment problem.
*Naval Research Logistics Quarterly*, 2(1-2), 83-97.

Jonker, R., & Volgenant, A. (1987). A shortest augmenting path algorithm
for dense and sparse linear assignment problems. *Computing*, 38,
325-340.

Greene, D., Doyle, D., & Cunningham, P. (2010). Tracking the evolution
of communities in dynamic social networks. *ASONAM 2010*, 176-183.

Palla, G., Barabasi, A.-L., & Vicsek, T. (2007). Quantifying social
group evolution. *Nature*, 446, 664-667.

Cazabet, R., & Rossetti, G. (2019). Challenges in community discovery on
temporal networks. In *Temporal Network Theory*, Springer, 181-197.

## Examples

``` r
dn <- dynet(school_contacts)
loose <- temporal_communities(dn, omega = 0, step = 5, window = 5,
                              seeds = 1:3)
match_communities(loose)
#> # Temporal communities: 4 over 5 bins | gamma = 1, omega = 0
#> # multislice Q = 0.3455 from 3 seeds | run agreement ARI = 0.977
#> # labels matched across bins by hungarian assignment on jaccard overlap
#>  time  node community active stability community_raw event
#>     0   Ana         3   TRUE         1             3  born
#>     0   Ben         2   TRUE         1             2  born
#>     0  Cara         1   TRUE         1             1  born
#>     0   Dan         3   TRUE         1             3  born
#>     0   Eve         2   TRUE         1             2  born
#>     0  Finn         1   TRUE         1             1  born
#>     0  Gita         3   TRUE         1             3  born
#>     0  Hugo         2   TRUE         1             2  born
#>     0  Iris         1   TRUE         1             1  born
#>     0 Jonas         3   TRUE         1             3  born
#>     0  Kira         2   TRUE         1             2  born
#>     0   Leo         1   TRUE         1             1  born
#> # 58 more rows. summary() gives one row per community.
```
