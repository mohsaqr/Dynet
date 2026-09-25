# The network sliced into snapshots

The edges alive in each time bin, as one tidy table. Useful for
exporting a slice, for feeding a layout routine, or for checking by eye
what the metric verbs are seeing.

## Usage

``` r
snapshots(
  dn,
  at = NULL,
  sessions = c("bounded", "collapse", "separate"),
  sample = NULL,
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL,
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- at:

  Optional single time, narrowing the result to the bins that cover it.
  A network built from dates may be addressed with a date. With the
  default disjoint tiling that is one bin; with an overlapping `window`
  every bin containing the time is returned. A time outside every bin
  falls back to the nearest bin rather than failing, but that bin may
  itself hold no active tie, in which case the result is a zero-row
  frame with the documented columns.

- sessions:

  How to treat sessions, as in
  [`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md):
  `"bounded"` (the default), `"collapse"` or `"separate"`. `"separate"`
  needs a network built with a session column and raises
  `dynet_no_sessions` otherwise.

- sample:

  Deprecated. `"instant"` is equivalent to `window = 0`; `"window"` uses
  the current positive/default window.

- start, end:

  First and last time at which to measure. Default to the observed
  range. A network built from dates may be addressed with dates.

- step:

  How often to measure. Defaults to the interval the network was built
  with.

- window:

  How much time each measurement covers. Defaults to `step`, which tiles
  the period into disjoint bins. A larger value slides an overlapping
  window; `0` samples the network at each point in time. `"all"`
  measures the whole observed period as one window, closed on the right
  so an event at the final instant is inside it; it cannot be combined
  with `step`, and under `sessions = "separate"` or discontinuous
  observation it gives one window per session or observed component.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn, so
  `plot = TRUE` saves the wrapping
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call without
  changing what comes back. Use
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on the result
  when the figure needs arguments of its own.

## Value

A `dynet_snapshot` data frame with one row per active edge per bin:
`session` (when the network has sessions), `observation` (when
observation is discontinuous, naming the observed component the bin
falls in), `time`, `from`, `to`, `weight` and `n_spells`.
[`print()`](https://rdrr.io/r/base/print.html) shows a header and the
first rows, [`summary()`](https://rdrr.io/r/base/summary.html) collapses
to one row per bin,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws how many
ties each bin holds, and
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
the plain table. A pair joined by more than one spell in the same bin is
one edge, with `n_spells` recording how many spells were collapsed – so
the edge counts here agree with those from
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md).
`weight` is the sum of those spells' full weights: a spell counts its
whole weight in every bin it touches, as
[`networkDynamic::network.collapse()`](https://rdrr.io/pkg/networkDynamic/man/network.collapse.html)
does. Snapshot `"strength"` in
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md)
instead splits a spell's weight by the share of its duration inside the
bin. Eligible isolates have no synthetic edge row; use
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md)
or [`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md)
when the eligible population itself is required.

## Conditions

Errors: `dynet_no_sessions` (`sessions = "separate"` without a session
column), `dynet_outside_observation` (the requested range misses
observed support; it also carries `dynet_bad_input`), and
`dynet_bad_input` for every other broken contract – `dn` not a `dynet`,
an `at`, `start` or `end` that is not a single finite time, and an
out-of-range `step` or `window`.

Warning: `dynet_deprecated` for the retired `sample` argument.

## Examples

``` r
dn <- dynet(school_contacts)
snapshots(dn, at = 3)
#> # Snapshot edges | 1 bin | 12 tie rows | time in step
#>    time from    to weight n_spells
#> 1     3  Ana Jonas      1        1
#> 2     3 Kira   Leo      1        1
#> 3     3  Leo  Finn      1        1
#> 4     3 Nils   Eve      1        1
#> 5     3  Ben Jonas      1        1
#> 6     3  Ben   Eve      1        1
#> 7     3  Dan   Ana      1        1
#> 8     3  Dan Jonas      1        1
#> 9     3  Dan   Eve      1        1
#> 10    3 Gita Jonas      1        1
#> # 2 more rows. summary() counts them by bin.
```
