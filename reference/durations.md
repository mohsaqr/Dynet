# How long each relationship lasted

Pair unit returns one row per vertex pair and measure, summarising every
retained raw spell they shared. Spell unit returns each retained raw
edge identity. Vertex-activity unit returns fixed-universe vertex
summaries; vertex-spell unit returns canonical V01 activity components.
Duration is what separates an interval network from a contact network: a
pair that met fifty times briefly and a pair that met once at length
have the same edge weight in a static network and nothing else in
common.

## Usage

``` r
durations(
  dn,
  measure = c("events", "total", "mean"),
  sessions = c("bounded", "collapse", "separate"),
  censored = c("include", "exclude"),
  unit = c("pair", "spell", "vertex_activity", "vertex_spell", "node_ties"),
  mode = c("out", "in", "all"),
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- measure:

  For pair unit, one or more of `"events"` (number of spells), `"total"`
  (summed duration), `"union"` (binary pair occupancy), `"mean"`,
  `"median"`, `"first"`, and `"last"`. For spell unit, one or more of
  `"duration"`, `"first"`, and `"last"`; its default is `"duration"`.
  Vertex-activity unit allows the pair-like measures and defaults to
  `"events"`, `"total"`, and `"union"`; vertex-spell unit allows the
  same measures as edge spell and defaults to `"duration"`. Node-ties
  unit allows `"events"` (incident raw-spell endpoint stubs), `"total"`
  (their summed endpoint-valid duration), and `"union"` (binary incident
  calendar exposure), defaulting to events and total.

- sessions:

  How to treat sessions, as in
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md).

- censored:

  Whether to `"include"` known follow-up or `"exclude"` an entire edge
  raw spell or canonical vertex component with either explicit outer
  censor flag. Administrative observation cuts never cause exclusion.

- unit:

  `"pair"` retains the existing pair summary and adds union duration;
  `"spell"` returns one row per retained raw edge-spell identity;
  `"vertex_activity"` returns fixed-node aggregates; `"vertex_spell"`
  returns retained canonical V01 activity identities; `"node_ties"`
  returns fixed-node incident-tie quantities.

- mode:

  For `unit = "node_ties"`, `"out"`, `"in"`, or `"all"` endpoint
  incidence. Undirected networks normalize every request to `"all"`. An
  explicitly supplied mode is invalid for every other duration unit.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn, so
  `plot = TRUE` saves the wrapping
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call without
  changing what comes back. Use
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on the result
  when the figure needs arguments of its own.

## Value

A `dynet_metric`. Pair and edge-spell units are edge-level: pair has
columns `from`, `to`, `measure`, and `value`, while spell additionally
has `raw_spell`. Administrative observation and endpoint-activity
fragments are recombined by raw spell before the `censored` policy is
applied. Vertex-activity unit has `node`, `measure`, and `value`;
vertex-spell additionally has `vertex_spell` and `implicit`; both vertex
units are node-level metrics. Node-ties is also node-level and has the
fixed schema `node`, `measure`, and `value` (plus `session` only for
separate mode).

## Details

Positive spell duration is the observed time during which both endpoints
are eligible. Genuine eligible point contacts are retained with duration
zero. Pair `total` sums these raw-spell durations, so overlapping
identities intentionally multiply time; pair `union` counts binary
calendar occupancy once. Consequently `union <= total`, and union cannot
exceed the pair's V04 eligible opportunity time. Pair `events` counts
retained raw identities. Formally, if retained raw spell `i` has
endpoint-valid fragments `F[i]`, then
`duration[i] = sum((b - a) for [a,b) in F[i])`. For pair `p`,
`total[p] = sum(duration[i])`, while `union[p]` is the Lebesgue measure
of the calendar union of every positive fragment belonging to `p`. Point
contacts therefore count as events and spells but contribute zero
duration. These conventions follow the spell and dyad distinction in
[`tsna::edgeDuration()`](https://rdrr.io/pkg/tsna/man/durations.html)
(Butts, 2024, doi:10.32614/CRAN.package.tsna), with Dynet additionally
applying its observation and endpoint-eligibility contract.

Collapse erases edge and vertex session labels before gating. Bounded
gates within each session and then pools spell identities while unioning
overlapping pair occupancy once on the shared calendar. Separate returns
local blocks. Weights and vertex censor flags do not affect durations.
Excluding raw edge censoring removes the whole identity, never only an
observed fragment.

For a retained canonical vertex component `k`, let `S[k]` be its
observed support, `d[k]` its total positive width, and `f[k]` and `l[k]`
its extrema. Vertex `total` is `sum(d[k])`, while `union` is the measure
of the calendar union of every positive `S[k]`; therefore
`0 <= union <= total`. Points count as identities with zero duration. A
declared vertex with no retained support has zero events/total/union and
missing mean/median/first/last. A wholly undeclared vertex has one
measurement-only implicit always-active identity over observed support.
This is stream-graph node presence duration as in Latapy, Viard, and
Magnien (2018), doi:10.1007/s13278-018-0537-7, and agrees with
[`tsna::vertexDuration()`](https://rdrr.io/pkg/tsna/man/durations.html)
only under matching continuous-observation, non-session conventions.

Node-ties uses the same endpoint-valid raw spell supports as pair/spell
duration. Directed out credits the tail, in credits the head, and all
adds both endpoint stubs. A retained loop therefore contributes once to
out, once to in, and twice to additive all-mode events/total; undirected
results use the same two-stub rule. In contrast, node-tie `union`
Boolean-unions all positive incident fragments, so loops, reciprocal
overlap, duplicate rows, and simultaneous neighbors occupy calendar time
only once. Consequently `union <= total`, and directed all equals out
plus in only for events and total. Formally, for endpoint-stub
multiplicity `c[v,i,m]`, retained raw identity duration `d[i]`, and
positive support `F[i]`, node-tie events are `sum(c[v,i,m])`, total is
`sum(c[v,i,m] * d[i])`, and union is the measure of the calendar union
of all `F[i]` having positive multiplicity. These union values cannot
exceed the corresponding D02 eligible vertex-activity union. Isolates,
inactive vertices, and loopless singletons receive exact zeros for every
node-tie measure. The additive quantities match
[`tsna::tiedDuration()`](https://rdrr.io/pkg/tsna/man/tiedDuration.html)
only for continuous observation, static eligible endpoints, uncensored
matched spells, and no sessions; `tsna` is not an oracle for union,
gaps/points, endpoint schedules, source censor filtering, or session
policies (Bender-deMoll and Morris, 2025,
doi:10.32614/CRAN.package.tsna).

## Examples

``` r
dn <- dynet(school_contacts)
durations(dn)
#> # Relationship duration (edge-level)
#> # time in step
#> # measures: events, mean, total
#> # durations in step
#>  from    to measure value
#>   Ana  Cara  events     1
#>   Ana   Dan  events     3
#>   Ana  Gita  events     5
#>   Ana  Iris  events     1
#>   Ana Jonas  events     4
#>   Ana  Kira  events     1
#>   Ana   Leo  events     1
#>   Ana  Mira  events     3
#>   Ben   Eve  events     5
#>   Ben  Finn  events     1
#>   Ben  Gita  events     1
#>   Ben  Hugo  events     4
#> # 318 more rows. summary() aggregates them; plot() draws them.
durations(dn, measure = "union")
#> # Relationship duration (edge-level)
#> # time in step
#> # durations in step
#>  from    to measure value
#>   Ana  Cara   union  0.10
#>   Ana   Dan   union  1.02
#>   Ana  Gita   union  1.99
#>   Ana  Iris   union  0.50
#>   Ana Jonas   union  2.34
#>   Ana  Kira   union  0.11
#>   Ana   Leo   union  1.19
#>   Ana  Mira   union  1.04
#>   Ben   Eve   union  3.05
#>   Ben  Finn   union  0.23
#>   Ben  Gita   union  0.34
#>   Ben  Hugo   union  0.59
#> # 98 more rows. summary() aggregates them; plot() draws them.
durations(dn, unit = "spell", measure = "duration")
#> # Relationship duration (edge-level)
#> # time in step
#> # durations in step
#>  from    to raw_spell  measure value
#>   Ana  Cara        71 duration  0.10
#>   Ana   Dan       143 duration  0.32
#>   Ana   Dan       168 duration  0.51
#>   Ana   Dan       228 duration  0.19
#>   Ana  Gita        68 duration  0.33
#>   Ana  Gita        79 duration  0.44
#>   Ana  Gita       117 duration  0.22
#>   Ana  Gita       157 duration  0.51
#>   Ana  Gita       172 duration  0.61
#>   Ana  Iris       177 duration  0.50
#>   Ana Jonas        19 duration  0.55
#>   Ana Jonas        30 duration  0.57
#> # 228 more rows. summary() aggregates them; plot() draws them.
durations(dn, unit = "vertex_activity")
#> # Vertex activity duration (node-level)
#> # 14 vertices | time in step
#> # measures: events, total, union
#> # durations in step
#>   node measure value
#>    Ana  events     1
#>    Ben  events     1
#>   Cara  events     1
#>    Dan  events     1
#>    Eve  events     1
#>   Finn  events     1
#>   Gita  events     1
#>   Hugo  events     1
#>   Iris  events     1
#>  Jonas  events     1
#>   Kira  events     1
#>    Leo  events     1
#> # 30 more rows. summary() aggregates them; plot() draws them.
durations(dn, unit = "vertex_spell")
#> # Vertex activity duration (node-level)
#> # 14 vertices | time in step
#> # durations in step
#>   node vertex_spell implicit  measure value
#>    Ana           NA     TRUE duration 21.52
#>    Ben           NA     TRUE duration 21.52
#>   Cara           NA     TRUE duration 21.52
#>    Dan           NA     TRUE duration 21.52
#>    Eve           NA     TRUE duration 21.52
#>   Finn           NA     TRUE duration 21.52
#>   Gita           NA     TRUE duration 21.52
#>   Hugo           NA     TRUE duration 21.52
#>   Iris           NA     TRUE duration 21.52
#>  Jonas           NA     TRUE duration 21.52
#>   Kira           NA     TRUE duration 21.52
#>    Leo           NA     TRUE duration 21.52
#> # 2 more rows. summary() aggregates them; plot() draws them.
durations(dn, unit = "node_ties", mode = "all")
#> # Incident tie duration (node-level)
#> # 14 vertices | mode all | time in step
#> # measures: events, total
#> # durations in step
#>   node measure value
#>    Ana  events    36
#>    Ben  events    34
#>   Cara  events    35
#>    Dan  events    35
#>    Eve  events    34
#>   Finn  events    29
#>   Gita  events    31
#>   Hugo  events    34
#>   Iris  events    30
#>  Jonas  events    46
#>   Kira  events    38
#>    Leo  events    28
#> # 16 more rows. summary() aggregates them; plot() draws them.
summary(durations(dn), by = "measure")
#>   measure   n      mean        sd  min  max
#> 1  events 110 2.1818182 1.4218596 1.00 8.00
#> 2    mean 110 0.4518795 0.2553268 0.04 1.34
#> 3   total 110 1.0438182 0.9014514 0.04 4.65
```
