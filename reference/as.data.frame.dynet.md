# Tidy tables from a temporal network

Tidy tables from a temporal network

## Usage

``` r
# S3 method for class 'dynet'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("edges", "nodes", "bins", "network", "observations", "observed_edges",
    "vertex_spells"),
  measure = NULL,
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  ...
)
```

## Arguments

- x:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- what:

  `"edges"` for raw edge spells, `"observed_edges"` for derived
  observation fragments, `"observations"` for canonical observed
  support, `"vertex_spells"` for canonical declared vertex activity,
  `"nodes"` for the vertex table, `"bins"` for the measurement grid, or
  `"network"` for the aggregate edge list cograph renders.

- measure:

  Optional centrality measures to annotate the vertex table with, valid
  only for `what = "nodes"`. Each becomes one column holding the value
  over the whole observed period, so the vertex table can be filtered or
  ranked without a second call. Any measure
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md)
  accepts at snapshot scope is allowed, plus `"indegree"` and
  `"outdegree"`.

- sessions, start, end:

  Passed to
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md)
  when `measure` is given, and ignored otherwise.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per whatever `what` names.

`"edges"`: one row per unchanged raw spell, with `from`, `to`, `start`,
`end`, `duration` and `weight`. A `session` column is present when the
network was built with sessions, `onset_censored` and
`terminus_censored` when interval censoring was declared explicitly, and
any column the construction carried through – `thread` for a threaded
log, `group` for a co-presence log.

`"observations"`: one row per canonical observation component, with
`observation`, `start`, `end`, `duration` and `instant`.

`"observed_edges"`: one row per derived observation fragment, with
`raw_spell`, `observation` and `fragment` locating it, `from`, `to`,
`start`, `end` (clipped to the observation), `raw_start`, `raw_end` (as
supplied), `weight`, `instant`, `duration`, and the strict
`left_observation_censored` and `right_observation_censored` flags.
`session` and the explicit `onset_censored`/`terminus_censored` flags
are copied unchanged from the raw spell when the network carries them.

`"vertex_spells"`: one row per maximal declared activity component, with
`vertex_spell`, `node`, `start`, `end`, `duration`, `instant`,
`session`, `onset_censored` and `terminus_censored`. Half-open positive
spells and exact points are both representable. Undeclared vertices are
implicitly always active and receive no synthetic rows, so this table is
empty for a network with no declared vertex activity.

`"nodes"`: one row per vertex, with `name`, any static attributes
supplied at construction, and one column per measure named in `measure`.

`"bins"`: one row per measurement window, with `bin`, `lo`, `hi`, `time`
(the bin's representative time) and `closed` (whether the upper bound is
included). Bins are component-qualified under discontinuous observation.

`"network"`: one row per aggregate vertex pair, with `from`, `to` and
the summed `weight` cograph renders.

## Examples

``` r
dn <- dynet(school_contacts)
head(as.data.frame(dn))
#>    from   to start  end duration weight
#> 1 Jonas  Dan  0.00 1.10     1.10      1
#> 2  Gita  Ana  0.14 0.98     0.84      1
#> 3   Leo Mira  0.15 0.42     0.27      1
#> 4   Leo Iris  0.15 0.96     0.81      1
#> 5  Kira  Ben  0.33 0.69     0.36      1
#> 6   Leo Iris  0.38 0.50     0.12      1
as.data.frame(dn, what = "nodes")
#>     name
#> 1    Ana
#> 2    Ben
#> 3   Cara
#> 4    Dan
#> 5    Eve
#> 6   Finn
#> 7   Gita
#> 8   Hugo
#> 9   Iris
#> 10 Jonas
#> 11  Kira
#> 12   Leo
#> 13  Mira
#> 14  Nils
as.data.frame(dn, what = "vertex_spells")
#> [1] vertex_spell      node              start             end              
#> [5] duration          instant           session           onset_censored   
#> [9] terminus_censored
#> <0 rows> (or 0-length row.names)

# Annotate the vertex table so it can be filtered without a second call.
busy <- as.data.frame(dn, what = "nodes",
                      measure = c("degree", "indegree", "outdegree"))
subset(busy, degree > 15)
#>     name degree indegree outdegree
#> 1    Ana     16        8         8
#> 3   Cara     17        7        10
#> 4    Dan     18        8        10
#> 5    Eve     17       10         7
#> 10 Jonas     18        9         9
#> 11  Kira     17        9         8
#> 13  Mira     16        8         8
#> 14  Nils     16        9         7
```
