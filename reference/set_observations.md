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
  Overlapping and adjacent positive components are merged.

- start, end:

  Optional scalar continuous bounds used instead of `data`.

## Value

A new `dynet` object. Raw edge and vertex spells are unchanged; only the
non-destructive measurement view is replaced.
