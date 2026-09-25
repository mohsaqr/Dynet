# Deprecated name for `centrality_series()` and `path_centrality()`

`dyn_centrality()` was split in two. Its default `scope = "snapshot"` is
now
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md);
`scope = "temporal"` is
[`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md)
for closeness and betweenness and
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md)
for reach. The old name still works and returns what it always returned,
with a warning of class `dynet_deprecated`. It will be removed in a
future release.

## Usage

``` r
dyn_centrality(
  dn,
  measure = "degree",
  scope = c("snapshot", "temporal"),
  sessions = c("bounded", "collapse", "separate"),
  sample = NULL,
  damping = 0.85,
  mode = c("all", "out", "in"),
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL,
  exponent = 1,
  traversal_time = 0,
  prestige = "indegree",
  rescale = FALSE,
  lambda = 1,
  plot = FALSE
)
```

## Arguments

- dn, measure, sessions, sample, damping, mode, start, end, step,
  window, exponent, prestige, rescale, lambda, plot:

  As in
  [`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md).

- scope:

  `"snapshot"` (the default) or `"temporal"`.

- traversal_time:

  As in
  [`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md);
  nonzero only with `scope = "temporal"`.

## Value

A node-level `dynet_metric`, as returned by the function it forwards to.

## Conditions

Warning: `dynet_deprecated` on every call. Errors are those of the
function it forwards to, plus `dynet_bad_input` for `mode`, `step` or
`window` with `scope = "temporal"` and a nonzero `traversal_time` with
`scope = "snapshot"`.

## Examples

``` r
dn <- dynet(school_contacts)
# Warns, then returns what centrality_series(dn) returns.
dyn_centrality(dn)
#> Warning: `dyn_centrality()` is deprecated; use `centrality_series()`.
#> # Degree (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node measure value
#>     0   Ana  degree     1
#>     0   Ben  degree     1
#>     0  Cara  degree     1
#>     0   Dan  degree     1
#>     0   Eve  degree     2
#>     0  Finn  degree     1
#>     0  Gita  degree     1
#>     0  Hugo  degree     1
#>     0  Iris  degree     2
#>     0 Jonas  degree     2
#>     0  Kira  degree     2
#>     0   Leo  degree     2
#> # 296 more rows. summary() aggregates them; plot() draws them.
```
