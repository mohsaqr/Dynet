# Tidy data frame of time-respecting paths

Tidy data frame of time-respecting paths

## Usage

``` r
# S3 method for class 'dynet_paths'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("paths", "steps"),
  ...
)
```

## Arguments

- x:

  A `dynet_paths`.

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- what:

  `"paths"` for the endpoint summary or `"steps"` for the tidy
  reconstructed optimal routes. The latter includes endpoint-local
  `path_id` values for tied contact sequences.

- ...:

  Ignored.

## Value

A plain `data.frame`. For `"paths"`, one row per endpoint vertex, the
source included, with the columns
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md)
documents: `node`, `reachable`, `arrival_time`, `attained`, `latency`,
`n_hops` and `n_paths`, plus `path_session` and `n_best_sessions` under
`sessions = "bounded"`, and `session` and `origin` under
`sessions = "separate"`. For `"steps"`, one row per step of every
reconstructed optimal route, with `endpoint` (the vertex the route ends
at), `path_id` (which of the tied optimal routes to that endpoint),
`path_session`, `step` (position along the route, starting at the
source), `node` (the vertex occupied at that step), `time` (when it was
reached) and `attained`.
