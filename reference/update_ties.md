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
  loops may always be retained.

## Value

A new internally consistent `dynet` object.
