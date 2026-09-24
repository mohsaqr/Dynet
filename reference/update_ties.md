# Update temporal ties and their attributes

Update temporal ties and their attributes

## Usage

``` r
update_ties(dn, ties, data, loops = FALSE)
```

## Arguments

- dn:

  A temporal network.

- ties:

  Which ties to update: a condition on the spell table, evaluated the
  way [`subset()`](https://rdrr.io/r/base/subset.html) evaluates one,
  over the columns `as.data.frame(dn)` returns; or integer row positions
  or a logical mask over that table.

- data:

  A data frame with one row or one row per selected tie. Columns may be
  canonical tie fields or arbitrary atomic spell attributes.

- loops:

  Whether an endpoint update may introduce a new self-loop. Existing
  loops may always be retained. Default `FALSE`.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`, holding the unselected
spells unchanged and the selected spells with the supplied values
substituted. Because the edited spells are rebuilt together with the
rest, spell order and the canonical spell identifiers may change. Raises
`dynet_loop_not_allowed` when an endpoint update would create a new
self-loop without `loops = TRUE`, and `dynet_bad_input` when the
selection or `data` is malformed, or names the read-only derived columns
`duration` or `.raw_spell`.

## Examples

``` r
dn <- dynet(school_contacts)
marked <- update_ties(dn, ties = end - start > 1,
                      data = data.frame(kind = "long"))
marked
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 14 vertices | 240 edge spells | 110 distinct pairs
#> # observed from 0 to 21.52 step, binned every 1
#> 
#>   from   to start  end duration weight kind
#>  Jonas  Dan  0.00 1.10     1.10      1 long
#>   Gita  Ana  0.14 0.98     0.84      1 <NA>
#>    Leo Mira  0.15 0.42     0.27      1 <NA>
#>    Leo Iris  0.15 0.96     0.81      1 <NA>
#>   Kira  Ben  0.33 0.69     0.36      1 <NA>
#>    Leo Iris  0.38 0.50     0.12      1 <NA>
#> # 234 more spells. summary() describes the network; plot() draws it.
```
