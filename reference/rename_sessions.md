# Rename session walls

Rename session walls

## Usage

``` r
rename_sessions(dn, mapping)
```

## Arguments

- dn:

  A sessioned temporal network.

- mapping:

  A named character vector from old to new labels, or an `old`/`new`
  data frame.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, with edge and vertex
session labels renamed together and the session scheme in its metadata
updated. Labels absent from `mapping` are left alone. Raises
`dynet_unknown_session` when an old label is not a session, and
`dynet_bad_input` when the network has no session scheme, when `mapping`
is malformed, or when the renaming would produce duplicate labels.

## Examples

``` r
dn <- dynet(school_contacts)
weeks <- with(school_contacts, ifelse(start < 7, "week_1", "later"))
labelled <- set_tie_sessions(dn, session = weeks)
renamed <- rename_sessions(labelled, c(week_1 = "opening"))
renamed
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 14 vertices | 240 edge spells | 110 distinct pairs
#> # observed from 0 to 21.52 step, binned every 1
#> # 2 sessions: later, opening
#> 
#>   from   to start  end duration weight session
#>  Jonas  Dan  0.00 1.10     1.10      1 opening
#>   Gita  Ana  0.14 0.98     0.84      1 opening
#>    Leo Mira  0.15 0.42     0.27      1 opening
#>    Leo Iris  0.15 0.96     0.81      1 opening
#>   Kira  Ben  0.33 0.69     0.36      1 opening
#>    Leo Iris  0.38 0.50     0.12      1 opening
#> # 234 more spells. summary() describes the network; plot() draws it.
```
