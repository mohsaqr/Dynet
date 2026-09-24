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

  `"paths"`, the default, for the endpoint summary, or `"steps"` for the
  tidy reconstructed optimal routes. The latter includes endpoint-local
  `path_id` values for tied contact sequences.

- ...:

  Ignored.

## Value

A plain `data.frame`. For `"paths"`, one row per endpoint vertex, the
source included, with the columns
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md)
documents: `node`, `reachable`, `arrival_time`, `attained`, `latency`,
`n_hops` and `n_paths`, plus `path_session` and `n_best_sessions` under
`sessions = "bounded"`, and `session` and `origin` under
`sessions = "separate"`. For `"steps"`, one row per step of every
reconstructed optimal route, with `endpoint` (the vertex the route ends
at), `path_id` (which of the tied optimal routes to that endpoint),
`path_session`, `step` (position along the route, starting at the
source), `node` (the vertex occupied at that step), `time` (when it was
reached) and `attained`.

## Examples

``` r
dn <- dynet(school_contacts)
reach <- paths(dn, from = "Ana")
as.data.frame(reach)
#>     node reachable arrival_time attained latency n_hops n_paths
#> 1    Ana      TRUE         0.00     TRUE    0.00      0       1
#> 2    Ben      TRUE         9.59     TRUE    9.59      3       3
#> 3   Cara      TRUE         6.67     TRUE    6.67      1       1
#> 4    Dan      TRUE         7.98     TRUE    7.98      4       1
#> 5    Eve      TRUE        11.66     TRUE   11.66      4       3
#> 6   Finn      TRUE         6.96     TRUE    6.96      2       1
#> 7   Gita      TRUE         6.36     TRUE    6.36      2       1
#> 8   Hugo      TRUE         7.98     TRUE    7.98      3       1
#> 9   Iris      TRUE        10.00     TRUE   10.00      3       1
#> 10 Jonas      TRUE         2.12     TRUE    2.12      1       1
#> 11  Kira      TRUE         6.12     TRUE    6.12      2       2
#> 12   Leo      TRUE         9.65     TRUE    9.65      3       1
#> 13  Mira      TRUE         6.36     TRUE    6.36      1       1
#> 14  Nils      TRUE         7.51     TRUE    7.51      2       1
as.data.frame(reach, what = "steps")
#>    endpoint path_id path_session step  node  time attained
#> 1       Ana       1         <NA>    0   Ana  0.00     TRUE
#> 2       Ben       1         <NA>    0   Ana  0.00     TRUE
#> 3       Ben       1         <NA>    1 Jonas  2.12     TRUE
#> 4       Ben       1         <NA>    2  Kira  6.12     TRUE
#> 5       Ben       1         <NA>    3   Ben  9.59     TRUE
#> 6       Ben       2         <NA>    0   Ana  0.00     TRUE
#> 7       Ben       2         <NA>    1 Jonas  3.43     TRUE
#> 8       Ben       2         <NA>    2  Kira  6.12     TRUE
#> 9       Ben       2         <NA>    3   Ben  9.59     TRUE
#> 10      Ben       3         <NA>    0   Ana  0.00     TRUE
#> 11      Ben       3         <NA>    1 Jonas  6.68     TRUE
#> 12      Ben       3         <NA>    2  Kira  6.68     TRUE
#> 13      Ben       3         <NA>    3   Ben  9.59     TRUE
#> 14     Cara       1         <NA>    0   Ana  0.00     TRUE
#> 15     Cara       1         <NA>    1  Cara  6.67     TRUE
#> 16      Dan       1         <NA>    0   Ana  0.00     TRUE
#> 17      Dan       1         <NA>    1  Cara  6.67     TRUE
#> 18      Dan       1         <NA>    2  Nils  7.51     TRUE
#> 19      Dan       1         <NA>    3  Hugo  7.98     TRUE
#> 20      Dan       1         <NA>    4   Dan  7.98     TRUE
#> 21      Eve       1         <NA>    0   Ana  0.00     TRUE
#> 22      Eve       1         <NA>    1 Jonas  2.12     TRUE
#> 23      Eve       1         <NA>    2  Kira  6.12     TRUE
#> 24      Eve       1         <NA>    3   Ben  9.59     TRUE
#> 25      Eve       1         <NA>    4   Eve 11.66     TRUE
#> 26      Eve       2         <NA>    0   Ana  0.00     TRUE
#> 27      Eve       2         <NA>    1 Jonas  3.43     TRUE
#> 28      Eve       2         <NA>    2  Kira  6.12     TRUE
#> 29      Eve       2         <NA>    3   Ben  9.59     TRUE
#> 30      Eve       2         <NA>    4   Eve 11.66     TRUE
#> 31      Eve       3         <NA>    0   Ana  0.00     TRUE
#> 32      Eve       3         <NA>    1 Jonas  6.68     TRUE
#> 33      Eve       3         <NA>    2  Kira  6.68     TRUE
#> 34      Eve       3         <NA>    3   Ben  9.59     TRUE
#> 35      Eve       3         <NA>    4   Eve 11.66     TRUE
#> 36     Finn       1         <NA>    0   Ana  0.00     TRUE
#> 37     Finn       1         <NA>    1  Cara  6.67     TRUE
#> 38     Finn       1         <NA>    2  Finn  6.96     TRUE
#> 39     Gita       1         <NA>    0   Ana  0.00     TRUE
#> 40     Gita       1         <NA>    1  Mira  6.36     TRUE
#> 41     Gita       1         <NA>    2  Gita  6.36     TRUE
#> 42     Hugo       1         <NA>    0   Ana  0.00     TRUE
#> 43     Hugo       1         <NA>    1  Cara  6.67     TRUE
#> 44     Hugo       1         <NA>    2  Nils  7.51     TRUE
#> 45     Hugo       1         <NA>    3  Hugo  7.98     TRUE
#> 46     Iris       1         <NA>    0   Ana  0.00     TRUE
#> 47     Iris       1         <NA>    1  Cara  6.67     TRUE
#> 48     Iris       1         <NA>    2  Finn  6.96     TRUE
#> 49     Iris       1         <NA>    3  Iris 10.00     TRUE
#> 50    Jonas       1         <NA>    0   Ana  0.00     TRUE
#> 51    Jonas       1         <NA>    1 Jonas  2.12     TRUE
#> 52     Kira       1         <NA>    0   Ana  0.00     TRUE
#> 53     Kira       1         <NA>    1 Jonas  2.12     TRUE
#> 54     Kira       1         <NA>    2  Kira  6.12     TRUE
#> 55     Kira       2         <NA>    0   Ana  0.00     TRUE
#> 56     Kira       2         <NA>    1 Jonas  3.43     TRUE
#> 57     Kira       2         <NA>    2  Kira  6.12     TRUE
#> 58      Leo       1         <NA>    0   Ana  0.00     TRUE
#> 59      Leo       1         <NA>    1  Cara  6.67     TRUE
#> 60      Leo       1         <NA>    2  Finn  6.96     TRUE
#> 61      Leo       1         <NA>    3   Leo  9.65     TRUE
#> 62     Mira       1         <NA>    0   Ana  0.00     TRUE
#> 63     Mira       1         <NA>    1  Mira  6.36     TRUE
#> 64     Nils       1         <NA>    0   Ana  0.00     TRUE
#> 65     Nils       1         <NA>    1  Cara  6.67     TRUE
#> 66     Nils       1         <NA>    2  Nils  7.51     TRUE
```
