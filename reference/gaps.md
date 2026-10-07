# Inter-event gaps

Every interval between one event and the next, as a tidy table with one
row per gap.
[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
computes these gaps to reach `B` and `M` and then reports only their
mean; this returns the distribution itself, so it can be plotted,
fitted, or tested against a Poisson null.

## Usage

``` r
gaps(
  dn,
  unit = c("node", "pair"),
  sessions = c("bounded", "collapse", "separate"),
  censored = c("exclude", "include"),
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- unit:

  `"node"`, the default, for the gaps between the events incident to
  each vertex, a loop counting once and direction ignored; `"pair"` for
  the gaps between the events of each ordered pair, or each unordered
  dyad on an undirected network. Loops are excluded from `"pair"`,
  matching
  [`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md).

- sessions:

  How to treat sessions, as in
  [`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md).
  `"bounded"`, the default, forms gaps inside each session so no gap
  spans a session wall; `"collapse"` erases the labels and pools one
  calendar sequence; `"separate"` reports each session on its own rows
  and needs a network built with a session column.

- censored:

  `"exclude"`, the default, drops events whose onset is censored, which
  is what
  [`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
  does, so the mean of these gaps is its `"mean_gap"`. `"include"` keeps
  them, at the cost of gaps measured from an onset that was never
  observed. Note the default is the opposite of
  [`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md),
  whose `"include"` default is about retaining spells rather than
  trusting their onsets.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn.

## Value

A `dynet_metric` data frame with one row per gap and no aggregation,
`level = "node"` under `unit = "node"` and `level = "edge"` under
`unit = "pair"`. Columns are `time`, the onset of the later event of the
pair, so the row sits at the moment the gap closed; `node`, or `from`
and `to` under `unit = "pair"`; `index`, the 1-based rank of the gap
within that vertex's or pair's ordered sequence, restarting at one in
each session under `"bounded"` and `"separate"`; `measure`, the constant
`"gap"`; and `value`, the gap in the network's time unit. A leading
`session` column is present under `sessions = "separate"`. A vertex or
pair with fewer than two usable events contributes no rows rather than a
missing one. Print it,
[`summary()`](https://rdrr.io/r/base/summary.html) it,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) it, or take the
plain frame with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

## Details

A gap of exactly zero is legitimate and is kept: it is the signature of
two distinct raw spells incident to the same vertex at one instant.
Dropping those would silently raise the mean above the `"mean_gap"` that
[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
reports from the same numbers.

## Conditions

Errors: `dynet_bad_input` when `dn` is not a `dynet`, and
`dynet_no_sessions` when `sessions = "separate"` is asked of a network
with no session column. An unmatched `unit`, `sessions` or `censored` is
rejected by [`match.arg()`](https://rdrr.io/r/base/match.arg.html) and
is a plain error, not a classed one.

## References

Goh, K.-I., & Barabasi, A.-L. (2008). Burstiness and memory in complex
systems. *Europhysics Letters*, 81(4), 48002.
[doi:10.1209/0295-5075/81/48002](https://doi.org/10.1209/0295-5075/81/48002)

Karsai, M., Kaski, K., Barabasi, A.-L., & Kertesz, J. (2012). Universal
features of correlated bursty behaviour. *Scientific Reports*, 2, 397.
[doi:10.1038/srep00397](https://doi.org/10.1038/srep00397)

Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97-125.
[doi:10.1016/j.physrep.2012.03.001](https://doi.org/10.1016/j.physrep.2012.03.001)

## See also

[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
for the summary statistics of these gaps, and
[`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md)
for how long a tie was up rather than how long a pair was quiet.

## Examples

``` r
dn <- dynet(school_contacts)
quiet <- gaps(dn)
quiet
#> # Inter-event gaps (node-level)
#> # 14 vertices | 216 time points, 1 per bin | time in step
#> # one row per gap; zero is a real gap, not a missing one
#>  time node index measure value
#>  2.12  Ana     1     gap  1.98
#>  3.17  Ana     2     gap  1.05
#>  3.43  Ana     3     gap  0.26
#>  4.31  Ana     4     gap  0.88
#>  6.36  Ana     5     gap  2.05
#>  6.57  Ana     6     gap  0.21
#>  6.58  Ana     7     gap  0.01
#>  6.67  Ana     8     gap  0.09
#>  6.68  Ana     9     gap  0.01
#>  6.81  Ana    10     gap  0.13
#>  6.83  Ana    11     gap  0.02
#>  7.04  Ana    12     gap  0.21
#> # 454 more rows. summary() aggregates them; plot() draws them.
summary(quiet)
#>     node measure  n      mean        sd  min  max peak_time
#> 1    Ana     gap 35 0.5945714 0.9963620 0.01 5.53     19.54
#> 2    Ben     gap 33 0.6109091 0.6625725 0.02 2.76      3.09
#> 3   Cara     gap 34 0.5785294 0.5248326 0.01 2.48      4.55
#> 4    Dan     gap 34 0.6161765 0.5651764 0.00 2.03      2.03
#> 5    Eve     gap 33 0.6163636 0.7530306 0.01 3.70     18.66
#> 6   Finn     gap 28 0.6850000 0.7398073 0.01 3.04     20.01
#> 7   Gita     gap 30 0.6556667 0.7535831 0.02 2.45     16.61
#> 8   Hugo     gap 33 0.6200000 0.7677483 0.03 2.67      5.58
#> 9   Iris     gap 29 0.6510345 0.5879282 0.00 2.41     18.66
#> 10 Jonas     gap 45 0.4553333 0.4358252 0.02 2.01     18.62
#> 11  Kira     gap 37 0.5556757 0.4891577 0.01 2.03      8.35
#> 12   Leo     gap 27 0.7474074 0.7462604 0.00 2.95     18.36
#> 13  Mira     gap 35 0.5794286 0.7180732 0.01 3.08      4.31
#> 14  Nils     gap 33 0.5639394 0.6778364 0.00 2.28      4.53

dyads <- gaps(dn, unit = "pair")
dyads
#> # Inter-event gaps (edge-level)
#> # 123 time points, 1 per bin | time in step
#> # one row per gap; zero is a real gap, not a missing one
#>   time from    to index measure value
#>  13.33  Ana   Dan     1     gap  1.29
#>  19.91  Ana   Dan     2     gap  6.58
#>   7.04  Ana  Gita     1     gap  0.47
#>  10.02  Ana  Gita     2     gap  2.98
#>  13.16  Ana  Gita     3     gap  3.14
#>  13.55  Ana  Gita     4     gap  0.39
#>   3.43  Ana Jonas     1     gap  1.31
#>   6.68  Ana Jonas     2     gap  3.25
#>   8.76  Ana Jonas     3     gap  2.08
#>   7.63  Ana  Mira     1     gap  1.27
#>   8.77  Ana  Mira     2     gap  1.14
#>   5.27  Ben   Eve     1     gap  1.66
#> # 118 more rows. summary() aggregates them; plot() draws them.
```
