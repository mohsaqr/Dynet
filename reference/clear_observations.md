# Restore implicit observation support

Restore implicit observation support

## Usage

``` r
clear_observations(dn)
```

## Arguments

- dn:

  A temporal network.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, observed continuously from
its earliest raw start through its latest raw end. Every explicit
observation field is dropped from the metadata and the bin count is
recomputed over the raw range; spells and attributes are untouched. Safe
on a network that never had explicit observations, which is returned
with only its recorded call changed.

## Examples

``` r
dn <- dynet(school_contacts)
first_week <- set_observations(dn, start = 0, end = 7)
restored <- clear_observations(first_week)
restored
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 14 vertices | 240 edge spells | 110 distinct pairs
#> # observed from 0 to 21.52 step, binned every 1
#> 
#>   from   to start  end duration weight
#>  Jonas  Dan  0.00 1.10     1.10      1
#>   Gita  Ana  0.14 0.98     0.84      1
#>    Leo Mira  0.15 0.42     0.27      1
#>    Leo Iris  0.15 0.96     0.81      1
#>   Kira  Ben  0.33 0.69     0.36      1
#>    Leo Iris  0.38 0.50     0.12      1
#> # 234 more spells. summary() describes the network; plot() draws it.
```
