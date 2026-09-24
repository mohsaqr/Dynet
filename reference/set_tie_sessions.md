# Assign or remove tie sessions

Assign or remove tie sessions

## Usage

``` r
set_tie_sessions(dn, session = NULL, breaks = NULL, labels = NULL)
```

## Arguments

- dn:

  A temporal network.

- session:

  A complete, nonempty character vector of length one or the raw tie
  count; a length-one value labels every spell. Default `NULL`, which,
  when `breaks` is also `NULL`, removes all tie-session walls and erases
  session labels on vertex activity.

  **A vector of the full length is matched positionally against the
  spell table, not against the data frame the network was built from.**
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) sorts
  spells by `start`, `end`, `from` and `to`, so the two orders coincide
  only when the input was already in that order. To cut sessions by
  time, use `breaks` instead.

- breaks:

  Optional increasing numeric vector of cut points on the network's time
  axis. A spell belongs to the session of the interval its `start` falls
  in: before the first break, between two breaks, or from the last break
  on, so `k` breaks give `k + 1` sessions. Mutually exclusive with
  `session`.

- labels:

  Optional character vector naming the `k + 1` sessions that `breaks`
  defines, in time order. The default is `session_1`, `session_2` and so
  on.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, with a `session` column on
the spell table and the session scheme recorded in its metadata, or with
both removed when neither `session` nor `breaks` is given. Raises
`dynet_bad_input` when `session` has neither length one nor the raw tie
count, or carries `NA` or blank labels; when `session` and `breaks` are
both given; when `breaks` is not increasing and finite; or when `labels`
does not have one more element than `breaks`.

## Examples

``` r
dn <- dynet(school_contacts)
weeks <- set_tie_sessions(dn, breaks = c(7, 14),
                          labels = c("week_1", "week_2", "week_3"))
weeks
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 14 vertices | 240 edge spells | 110 distinct pairs
#> # observed from 0 to 21.52 step, binned every 1
#> # 3 sessions: week_1, week_2, week_3
#> 
#>   from   to start  end duration weight session
#>  Jonas  Dan  0.00 1.10     1.10      1  week_1
#>   Gita  Ana  0.14 0.98     0.84      1  week_1
#>    Leo Mira  0.15 0.42     0.27      1  week_1
#>    Leo Iris  0.15 0.96     0.81      1  week_1
#>   Kira  Ben  0.33 0.69     0.36      1  week_1
#>    Leo Iris  0.38 0.50     0.12      1  week_1
#> # 234 more spells. summary() describes the network; plot() draws it.
```
