# Burstiness and memory of each vertex's activity

Whether a vertex acts in bursts or at a steady pace. Burstiness compares
the spread of the gaps between a vertex's events with their average: it
approaches `1` for increasingly heterogeneous sequences, has theoretical
reference value `0` for a Poisson process, and is `-1` for a metronome.
The memory coefficient asks a different question – whether a short gap
tends to be followed by another short gap.

Two vertices can post the same number of times and differ entirely on
both.

## Usage

``` r
burstiness(
  dn,
  measure = c("burstiness", "memory", "events"),
  sessions = c("bounded", "collapse", "separate"),
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- measure:

  One or more of `"burstiness"`, `"memory"`, `"events"` and
  `"mean_gap"`.

- sessions:

  How to treat sessions, as in
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md).

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

A `dynet_metric` at node level with no time column: one row per vertex
and measure. Attributes record the event identity, dispersion, memory,
loop, weight, and session-gap conventions as
`event_identity = "incident_spell_start"`, `dispersion = "population"`,
`memory = "lag1_pearson"`, `loop_contribution = "one_event"`,
`weights = "ignored"`, and mode-specific `session_gaps`.

## Details

One raw spell row contributes its start time once to each distinct
incident vertex. A self-loop is one event, equal-time rows remain
distinct events, direction does not alter incidence, and interval ends
and weights are ignored. Sorted equal times therefore create legitimate
zero gaps. Explicitly onset-censored limits are not observed onset
events and are excluded; terminus censoring does not affect this onset
sequence.

If the usable interevent gaps are \\\tau_1,\ldots,\tau_k\\, burstiness
is \$\$B=(\sigma-\mu)/(\sigma+\mu),\$\$ where \\\mu\\ is their mean and
\\\sigma=\sqrt{k^{-1}\sum_i(\tau_i-\mu)^2}\\ is the population standard
deviation of the equal-mass empirical gap distribution. `mean_gap` needs
at least one gap. Burstiness needs at least two and is `NA` if every
usable gap is zero. Its finite-sample range is `[-1, 1)`.

Memory is the ordinary Pearson correlation between consecutive gaps. It
needs at least two adjacent-gap pairs and nonzero variation on both
sides; otherwise it is `NA`. In `sessions = "bounded"`, primitive gaps
and adjacent pairs are formed within each session and then pooled, so no
cross-session gap is introduced. Collapse includes calendar gaps after
erasing labels; separate returns session-local blocks over the fixed
vertex universe.

## References

Goh, K.-I., & Barabasi, A.-L. (2008). Burstiness and memory in complex
systems. *Europhysics Letters*, 81(4), 48002, equations 1 and 4.
[doi:10.1209/0295-5075/81/48002](https://doi.org/10.1209/0295-5075/81/48002)

## Examples

``` r
dn <- dynet(school_contacts)
burstiness(dn)
#> # Burstiness (node-level)
#> # 14 vertices | time in step
#> # measures: burstiness, memory, events
#> # 1 is the bursty limit, 0 is the Poisson reference, -1 is regular
#>   node    measure       value
#>    Ana burstiness  0.24575324
#>    Ben burstiness  0.03288611
#>   Cara burstiness -0.05610924
#>    Dan burstiness -0.05061772
#>    Eve burstiness  0.09217906
#>   Finn burstiness  0.02938507
#>   Gita burstiness  0.06104200
#>   Hugo burstiness  0.09885443
#>   Iris burstiness -0.05968068
#>  Jonas burstiness -0.02750549
#>   Kira burstiness -0.07048265
#>    Leo burstiness -0.01020265
#> # 30 more rows. summary() aggregates them; plot() draws them.
```
