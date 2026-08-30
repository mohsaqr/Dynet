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

  A complete character vector of length one or the raw tie count. `NULL`
  removes all tie-session walls and erases session labels on vertex
  activity.

## Value

A new `dynet` object.
