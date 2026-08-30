# Gibson participation shifts from raw temporal turns

Gibson participation shifts from raw temporal turns

## Usage

``` r
pshifts(
  dn,
  sessions = c("bounded", "collapse", "separate"),
  output = c("final", "cumulative"),
  start = NULL,
  end = NULL,
  group_events = c("simultaneous", "none"),
  plot = FALSE
)
```

## Arguments

- dn:

  A directed temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- sessions:

  Session aggregation policy.

- output:

  Return final class totals or cumulative rows.

- start, end:

  Optional inclusive query limits; each query is a fresh sequence and
  never uses a predecessor outside the range.

- group_events:

  Infer one group-directed turn from simultaneous distinct recipients,
  or retain every dyadic row.

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

A `dynet_pshifts` data frame whose shape follows `output`. `"final"`
gives one row per shift class – thirteen rows, always all thirteen even
when a class never occurred – with columns `shift` (the Gibson label),
`family` (the label's group) and `count`. `"cumulative"` gives one row
per turn and class, that is thirteen rows per classified turn, with
`sequence` and `event` locating the turn in its sequence, `time`,
`speaker`, `target` and `group` describing the turn, and `shift`,
`family` and `count` carrying the running total of that class up to and
including the turn.

## Details

Only uncensored raw spell onsets inside the observed query and
observation components are turns; duration, weights, fragments and
terminus censoring are ignored. Consecutive turns are classified using
Gibson's fixed thirteen labels. Session and component walls, loops,
ties, duplicate multiplicity, and simultaneous-recipient group inference
are retained in metadata. `output = "final"` emits one typed row per
class; `output = "cumulative"` emits the running class vector for each
turn.

## References

Gibson, D. R. (2003). Participation shifts and institutional change in
relational systems. *Social Forces*, 81, 1335–1380.
[doi:10.1353/sof.2003.0055](https://doi.org/10.1353/sof.2003.0055)

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "B"), to = c("B", "A"), start = c(1, 2), end = c(1, 2)
))
pshifts(dn)
#> # Participation shifts (Gibson 2003, 13 types)
#> # 1 classified turn transition across 4 families
#>  shift          family count
#>  AB-BA  turn_receiving     1
#>  AB-B0  turn_receiving     0
#>  AB-BY  turn_receiving     0
#>  A0-X0   turn_claiming     0
#>  A0-XA   turn_claiming     0
#>  A0-XY   turn_claiming     0
#>  AB-X0   turn_usurping     0
#>  AB-XA   turn_usurping     0
#>  AB-XB   turn_usurping     0
#>  AB-XY   turn_usurping     0
#>  A0-AY turn_continuing     0
#>  AB-A0 turn_continuing     0
#>  AB-AY turn_continuing     0
```
