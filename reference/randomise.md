# Surrogate temporal networks from a null model

Produces networks that keep some of the observed structure and destroy
the rest, so that a measured value can be read against what an
unstructured network would have shown. Every measure in this package is
a point estimate until it is compared with a null;
[`significance()`](https://pak.dynasite.org/Dynet/reference/significance.md)
does that comparison.

Which structure each method holds fixed is the whole content of the
choice, so [`print()`](https://rdrr.io/r/base/print.html) states it and
the `@details` below tabulate it.

## Usage

``` r
randomise(
  dn,
  method = c("times", "timeline", "edges", "targets", "labels", "reversal"),
  n = 99L,
  within = c("network", "sender", "session"),
  transpose = FALSE,
  swaps = 10,
  max_tries = 100L,
  keep = c("networks", "spells"),
  respect = c("activity", "observation"),
  seed = NULL
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- method:

  The null model. `"times"` permutes event times across the network,
  `"timeline"` moves each pair's whole event sequence onto another pair,
  `"edges"` rewires the aggregate graph preserving degree, `"targets"`
  permutes who was reached, `"labels"` permutes vertex names, and
  `"reversal"` runs time backwards.

- n:

  Number of surrogates. Forced to one for `"reversal"`, which is
  deterministic.

- within:

  Scope a shuffle is confined to: the whole network, within each sender,
  or within each session.

- transpose:

  For `"reversal"` only, also swap edge direction.

- swaps:

  For `"edges"` only, double-edge swaps per distinct pair.

- max_tries:

  Iteration cap on the self-loop repair in `"targets"`.

- keep:

  Retain the surrogate networks so
  [`significance()`](https://pak.dynasite.org/Dynet/reference/significance.md)
  can reuse one set of replicates for many statistics, or drop them to
  save memory.

- respect:

  Constraints a surrogate must satisfy on a network that declares them:
  `"activity"` requires both endpoints eligible for the whole surrogate
  spell, `"observation"` requires the spell to lie inside an observed
  component, and `"none"` shuffles unconstrained. Constrained draws are
  feasible, not uniform over the feasible set, and `"none"` on such a
  network gives a biased null.

- seed:

  A single whole number for a reproducible draw, or `NULL`.

## Value

A `dynet_null` data frame with one row per surrogate spell per replicate
and columns `replicate`, `from`, `to`, `start`, `end`, `duration` and
`weight`, plus `session` when the network has sessions. The surrogate
networks themselves are carried on the object and are reached through
[`significance()`](https://pak.dynasite.org/Dynet/reference/significance.md),
never by hand.

## Details

- `"reversal"`:

  Preserves every spell duration, every pair, each pair's event count
  and all degrees. Destroys the arrow of time.

- `"times"`:

  Preserves the multiset of start and end times, so the activity profile
  and duration distribution exactly. Destroys the coupling between
  topology and timing, and each pair's burstiness.

- `"timeline"`:

  Preserves each pair's event sequence intact, so per-link burstiness
  and memory. Destroys which pair owns which timeline.

- `"edges"`:

  Preserves the aggregate degree sequence, in and out separately when
  directed. Destroys topology above the degree sequence.

- `"targets"`:

  Preserves each sender's event times. Destroys who was reached, so
  reciprocity and triadic closure.

- `"labels"`:

  Preserves everything structural: the surrogate is isomorphic to the
  original. It is therefore a null for attribute-dependent quantities
  only, such as
  [`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md).
  Every structural measure is exactly invariant under it, which makes it
  a free correctness test rather than a weak null.

On a network that declares vertex activity or observation spells, an
unconstrained shuffle can place an event while an endpoint is ineligible
or inside an unobserved gap, and the snapshot machinery would then
induce it away, biasing the null downward. `respect` enforces those
constraints by rejecting and redrawing infeasible spells. The result is
a feasible surrogate rather than a uniform draw from the feasible set;
[`summary()`](https://rdrr.io/r/base/summary.html) reports how many
proposals were rejected so the constraint's bite is visible.

## References

Gauvin, L., Genois, M., Karsai, M., Kivela, M., Takaguchi, T., Valdano,
E., and Vestergaard, C. L. (2022). Randomized reference models for
temporal networks. *SIAM Review*, 64(4), 763-830.

Holme, P., and Saramaki, J. (2012). Temporal networks. *Physics
Reports*, 519(3), 97-125.

Maslov, S., and Sneppen, K. (2002). Specificity and stability in
topology of protein networks. *Science*, 296(5569), 910-913.

## See also

[`significance()`](https://pak.dynasite.org/Dynet/reference/significance.md)
to turn a null into an interval and a p-value.

## Examples

``` r
dn <- dynet(school_contacts)
randomise(dn, method = "times", n = 9, seed = 1)
#> # 9 surrogate networks | method "times"
#> # holds fixed : the multiset of (start, end) pairs, so the activity profile and duration distribution exactly; the pair set; each pair's event count
#> # destroys    : which pair was active when, so all coupling between topology and timing, and each pair's burstiness
#>   replicate from    to start  end duration weight
#> 1         1  Eve Jonas  0.00 1.10     1.10      1
#> 2         1 Finn  Iris  0.14 0.98     0.84      1
#> 3         1 Iris  Nils  0.15 0.42     0.27      1
#> 4         1 Kira  Hugo  0.15 0.96     0.81      1
#> 5         1 Gita   Ana  0.33 0.69     0.36      1
#> 6         1 Cara   Ana  0.38 0.50     0.12      1
#> # 2154 more rows. significance() turns this into a p-value.
randomise(dn, method = "reversal")
#> # 1 surrogate network | method "reversal"
#> # holds fixed : every spell duration; every pair; each pair's event count; the aggregate weighted adjacency; all degrees
#> # destroys    : the arrow of time: every time-respecting path, all forward/backward asymmetry, causal ordering
#>   replicate from   to start  end duration weight
#> 1         1  Ana  Leo  0.00 1.19     1.19      1
#> 2         1 Hugo Kira  0.14 1.56     1.42      1
#> 3         1  Dan  Ana  0.19 0.57     0.38      1
#> 4         1 Kira Hugo  0.19 0.63     0.44      1
#> 5         1  Eve Hugo  0.40 0.75     0.35      1
#> 6         1  Dan Nils  0.49 0.84     0.35      1
#> # 234 more rows. significance() turns this into a p-value.
```
