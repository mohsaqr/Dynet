# Replace observation support

Replace observation support

## Usage

``` r
set_observations(dn, data = NULL, start = NULL, end = NULL)
```

## Arguments

- dn:

  A temporal network.

- data:

  Optional data frame with `start` and `end` observation components.
  Overlapping and adjacent positive components are merged. Default
  `NULL`.

- start, end:

  Optional scalar continuous bounds used instead of `data`, each
  defaulting to `NULL`. Supply exactly one of `data` or the
  `start`/`end` pair; supplying both, or neither, is an error.

## Value

A new `dynet` object, class
`c("dynet", "netobject", "cograph_network")`. Raw edge and vertex spells
are unchanged – `as.data.frame(x)` still returns the originals – and
only the non-destructive measurement view is replaced, so every verb now
clips exposure and path horizons to this support. Read the components
back with `as.data.frame(x, what = "observations")`, one row per
component with `observation`, `start`, `end`, `duration` and `instant`.
Raises `dynet_bad_input` when neither or both of `data` and the bounds
are given.

## Examples

``` r
dn <- dynet(school_contacts)
first_week <- set_observations(dn, start = 0, end = 7)
as.data.frame(first_week, what = "observations")
#>   observation start end duration instant
#> 1           1     0   7        7   FALSE
```
