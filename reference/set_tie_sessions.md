# Assign or remove tie sessions

Assign or remove tie sessions

## Usage

``` r
set_tie_sessions(dn, session = NULL)
```

## Arguments

- dn:

  A temporal network.

- session:

  A complete, nonempty character vector of length one or the raw tie
  count; a length-one value labels every spell. Default `NULL`, which
  removes all tie-session walls and erases session labels on vertex
  activity.

  **A vector of the full length is matched positionally against the
  spell table, not against the data frame the network was built from.**
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) sorts
  spells by `start`, `end`, `from` and `to`, so the two orders coincide
  only when the input was already in that order. Derive the labels from
  `as.data.frame(dn)`, which is the spell table itself, rather than from
  the original log.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, with a `session` column on
the spell table and the session scheme recorded in its metadata, or with
both removed when `session = NULL`. Raises `dynet_bad_input` when
`session` has neither length one nor the raw tie count, or carries `NA`
or blank labels.

## Examples

``` r
dn <- dynet(school_contacts)
weeks <- with(school_contacts, ifelse(start < 7, "week_1", "later"))
labelled <- set_tie_sessions(dn, session = weeks)
labelled
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 14 vertices | 240 edge spells | 110 distinct pairs
#> # observed from 0 to 21.52 step, binned every 1
#> # 2 sessions: later, week_1
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
