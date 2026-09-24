# Function catalogue

Dynet exports 38 functions in six categories, plus 50 S3 methods across
the result classes. Every verb addresses vertices by name and returns a
tidy one-row-per-observation data frame.

| Category | Verbs | What it does |
|----|---:|----|
| Construction | 4 | Build a network from a relational log; read it back as a time series |
| Editing | 17 | Rewrite spells and vertex activity without breaking time |
| Measurement | 8 | Centrality, reachability, structure, mixing, turn-taking, burstiness, duration, similarity |
| Paths | 5 | Time-respecting paths and four views of the result |
| Structure | 3 | Turn the network into another object |
| Animation | 1 | Render the measurement grid as a film |

## Construction

[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) builds a
temporal network from a relational log. It takes a data frame of ties
and a set of column selectors, infers one of four log formats from which
selectors are named, and returns an object of class
`c("dynet", "netobject", "cograph_network")` carrying the spell table,
the node table and the construction metadata. The four formats are
interval logs with explicit start and end times, contact logs of
instantaneous events, threaded logs where an edge stays active until its
thread falls silent, and co-presence logs where actors sharing a group
become connected.

``` r

dn <- dynet(school_contacts)
dn
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

[`as_dynet()`](https://pak.dynasite.org/Dynet/reference/as_dynet.md)
converts an object of another class to a temporal network. It takes that
object and returns a `dynet`. The method for `networkDynamic` imports
edge spells, vertex spells, the observation period and per-edge
attributes. The method for `dynet` is the identity and returns its input
unchanged, so the call is safe on an object that is already a temporal
network.

[`events()`](https://pak.dynasite.org/Dynet/reference/events.md) counts
edge formation and dissolution over time. It takes a network, a measure
name, and the four grid arguments, and returns a `dynet_metric` at graph
level with one row per time point and measure. Eight measures are
available, from raw `"formation"` and `"dissolution"` counts through to
the formation and dissolution rates, which divide confirmed transitions
by exact eligible pair-time.

[`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
slices the network into one edge list per time bin. It takes a network
and the grid arguments and returns a `dynet_snapshot` data frame with
one row per active edge per bin, holding `time`, `from`, `to`, `weight`
and `n_spells`, preceded by `session` when the network has sessions. A
pair joined by more than one spell inside one bin is a single edge, and
`n_spells` records how many spells produced it.

``` r

bins <- snapshots(dn, step = 4)
bins
#> # Snapshot edges | 6 bins | 216 tie rows | time in step
#>    time  from    to weight n_spells
#> 1     0   Ana Jonas      2        2
#> 2     0 Jonas  Kira      1        1
#> 3     0 Jonas  Mira      1        1
#> 4     0 Jonas   Dan      1        1
#> 5     0  Kira   Leo      1        1
#> 6     0  Kira   Ben      1        1
#> 7     0  Kira   Eve      1        1
#> 8     0   Leo  Mira      1        1
#> 9     0   Leo  Finn      1        1
#> 10    0   Leo  Iris      2        2
#> # 206 more rows. summary() counts them by bin.
```

## Editing

Seventeen verbs rewrite the spell table, the node table or the
vertex-activity table. Each takes a network, returns a new one of class
`c("dynet", "netobject", "cograph_network")`, and leaves its input
unchanged. Edits go through a rebuild, so canonical spell identifiers
can renumber after any of them.

### Adding

[`add_nodes()`](https://pak.dynasite.org/Dynet/reference/add_nodes.md)
adds vertices. It takes a character vector of names or a data frame with
a `name` column and static attributes, and returns a network in which
the new vertices are implicit always-active isolates until ties or
vertex activity are supplied.

[`add_ties()`](https://pak.dynasite.org/Dynet/reference/add_ties.md)
adds tie spells. It takes a data frame of endpoints and times, and
returns a network with the canonical temporal ties and every flattened
cograph field rebuilt together. Columns beyond the canonical spell
fields are carried as tie attributes.

[`add_arcs()`](https://pak.dynasite.org/Dynet/reference/add_arcs.md) is
the directed counterpart of
[`add_ties()`](https://pak.dynasite.org/Dynet/reference/add_ties.md) and
delegates to it.

[`add_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/add_vertex_spells.md)
declares periods in which a vertex is present. It takes a data frame
with `node`, `start` and `end`, and returns a network whose existing
activity and the supplied spells are canonicalised together, so an added
spell that overlaps or abuts an existing one for the same vertex is
merged into it.

### Removing

[`remove_nodes()`](https://pak.dynasite.org/Dynet/reference/remove_nodes.md)
removes vertices. It takes their names and a `cascade` flag, and returns
a network without them and, under `cascade = TRUE`, without their ties
and activity spells. At least one temporal tie must remain.

[`remove_ties()`](https://pak.dynasite.org/Dynet/reference/remove_ties.md)
removes tie spells. It takes row positions, a condition over the spell
table, or endpoint and time selectors, and returns a network without the
matched spells. A request that matches nothing raises
`dynet_tie_not_found`.

[`remove_arcs()`](https://pak.dynasite.org/Dynet/reference/remove_arcs.md)
is the directed counterpart of
[`remove_ties()`](https://pak.dynasite.org/Dynet/reference/remove_ties.md).

[`remove_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/remove_vertex_spells.md)
drops declared activity components. It takes integer positions or a
logical mask and returns a network with the rest canonicalised again, so
the remaining spell identifiers renumber. A vertex left with no
declaration becomes implicitly always active.

### Updating and renaming

[`update_nodes()`](https://pak.dynasite.org/Dynet/reference/update_nodes.md)
adds or replaces static vertex attributes. It takes a data frame with a
`name` key and one or more attribute columns, and returns a network with
the same spells, activity and metadata, and the attributes written onto
the named vertices. Unnamed vertices keep their existing values.

[`update_ties()`](https://pak.dynasite.org/Dynet/reference/update_ties.md)
edits selected spells. It takes a selection and a data frame of
replacement values, and returns a network holding the unselected spells
unchanged and the selected ones with the supplied values substituted.

[`update_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/update_vertex_spells.md)
edits selected activity components. It takes positions and a data frame
of replacement fields, and returns a network in which the updated
components are canonicalised with the retained ones. A column outside
the vertex-spell schema raises `dynet_unknown_column`.

[`rename_nodes()`](https://pak.dynasite.org/Dynet/reference/rename_nodes.md)
renames vertices. It takes a named character vector, or an `old`/`new`
data frame, and returns a network with edge endpoints, node attributes,
vertex activity, cograph labels and groups renamed together.

[`rename_sessions()`](https://pak.dynasite.org/Dynet/reference/rename_sessions.md)
renames session labels. It takes the same mapping forms and returns a
network with edge and vertex session labels renamed together and the
session scheme in the metadata updated. Labels absent from the mapping
are left alone.

### Declaring support

[`set_observations()`](https://pak.dynasite.org/Dynet/reference/set_observations.md)
replaces the observation window. It takes either a two-column data frame
of components or a `start` and `end` pair, and returns a network whose
raw spells are unchanged and whose measurement view alone is replaced,
so `as.data.frame(x)` still returns the originals.

[`clear_observations()`](https://pak.dynasite.org/Dynet/reference/clear_observations.md)
restores implicit support. It takes a network and returns one observed
continuously from its earliest raw start through its latest raw end,
with every explicit observation field dropped from the metadata.

[`set_tie_sessions()`](https://pak.dynasite.org/Dynet/reference/set_tie_sessions.md)
assigns or removes session walls. It takes a character vector of length
one or of the raw tie count, and returns a network with a `session`
column on the spell table and the scheme recorded in metadata, or with
both removed under `session = NULL`. A full-length vector is matched
positionally against the sorted spell table, so labels should be derived
from `as.data.frame(dn)`.

[`set_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/set_vertex_spells.md)
replaces declared vertex activity outright. It takes a vertex-spell data
frame, or the string `"ties"` to declare each vertex present from its
first tie to its last, and returns a network whose declared activity is
exactly that.

``` r

present <- set_vertex_spells(dn, "ties")
present
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

## Measurement

Eight verbs measure a network over time. Each returns a `dynet_metric`:
a tidy data frame whose columns are ordered `session`, `time`, the unit
of observation, `measure` and `value`. The `session` column appears only
under `sessions = "separate"`, which is the one mode that keeps session
labels apart.

The grid arguments are not shared by all eight.
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md),
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md),
[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) and
[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md)
take all four;
[`dyn_reachability()`](https://pak.dynasite.org/Dynet/reference/dyn_reachability.md)
and [`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md)
take `start` and `end` only; and
[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
and
[`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md)
summarise the whole observed period.

[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
computes vertex centrality. It takes one or more measure names and a
`scope`, and returns one row per vertex, time point and measure.
Nineteen measures are available at `scope = "snapshot"`, which treats
each time bin as a static graph, and four at `scope = "temporal"`, which
measures along time-respecting paths and reports no `time` column
because the whole window yields one value per vertex.

``` r

between <- dyn_centrality(dn, measure = "betweenness")
between
#> # Betweenness (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node     measure value
#>     0   Ana betweenness     0
#>     0   Ben betweenness     0
#>     0  Cara betweenness     0
#>     0   Dan betweenness     0
#>     0   Eve betweenness     0
#>     0  Finn betweenness     0
#>     0  Gita betweenness     0
#>     0  Hugo betweenness     0
#>     0  Iris betweenness     1
#>     0 Jonas betweenness     0
#>     0  Kira betweenness     1
#>     0   Leo betweenness     0
#> # 296 more rows. summary() aggregates them; plot() draws them.
```

[`dyn_reachability()`](https://pak.dynasite.org/Dynet/reference/dyn_reachability.md)
computes how much of the network each vertex can reach. It takes a
direction and a measure name and returns one row per vertex per measure
at node level. Proportions are labelled `forward_reach` and
`backward_reach`, counts `forward_reach_count` and
`backward_reach_count`. A vertex is excluded from its own reachable set.

[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md)
computes graph-level structure. It takes one or more of forty measure
names and returns one row per time point and measure. The measure
`"triads"` contributes sixteen rows per time point, one per triad class.

``` r

density <- metrics(dn, measure = "density")
density
#> # Density (graph-level)
#> # 22 time points, 1 per bin | time in step
#>  time measure      value
#>     0 density 0.05494505
#>     1 density 0.04395604
#>     2 density 0.05494505
#>     3 density 0.06593407
#>     4 density 0.07142857
#>     5 density 0.08791209
#>     6 density 0.15934066
#>     7 density 0.10439560
#>     8 density 0.09890110
#>     9 density 0.08791209
#>    10 density 0.10439560
#>    11 density 0.09890110
#> # 10 more rows. summary() aggregates them; plot() draws them.
```

[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md)
computes how much tie activity runs within and between vertex groups. It
takes the name of a node attribute and returns one row per time point
and ordered group pair, with `from_group` and `to_group` naming the
pair.

[`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md)
classifies consecutive turns into Gibson’s thirteen participation-shift
types. It takes a directed network and an `output` shape, and returns a
`dynet_pshifts` data frame. Under `output = "final"` that is thirteen
rows, one per shift class, always all thirteen even when a class never
occurred. Under `"cumulative"` it is thirteen rows per classified turn,
carrying the running count.

[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
measures how unevenly each vertex’s events are spaced. It takes a
measure name and returns one row per vertex and measure, with no time
column. The burstiness coefficient is 1 in the bursty limit, 0 at the
Poisson reference and -1 for perfectly regular activity; memory is the
lag-1 correlation between consecutive inter-event gaps.

[`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md)
measures how long relationships lasted. It takes a `unit` that selects
the row identity and a measure name, and returns an edge-level table
under `unit = "pair"` or `"spell"`, and a node-level table under the
vertex-activity units. The `censored` argument decides whether spells
whose boundaries were never observed are retained.

[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md)
compares the network at each pair of time points. It takes a coefficient
name and returns a `dynet_similarity` data frame with one row per
ordered pair of time bins and columns `time`, `other`, `measure` and
`value`. The diagonal is included and is one for every coefficient
except `"hamming"`, where identical layers differ in nothing and score
zero.

### The shared grid

Four arguments decide when the network is measured, following
[`tsna::tSnaStats()`](https://rdrr.io/pkg/tsna/man/tSnaStats.html):

| Argument       | Meaning                               | tsna equivalent |
|----------------|---------------------------------------|-----------------|
| `start`, `end` | First and last measurement            | `start`, `end`  |
| `step`         | How often to measure                  | `time.interval` |
| `window`       | How much time each measurement covers | `aggregate.dur` |

`window == step` tiles, `window > step` slides, `window == 0` samples an
instant, and `window = "all"` treats the whole observed period as one
bin.

## Paths

[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) finds
time-respecting journeys from one vertex. It takes a network, a source
vertex name, and a direction, and returns a `dynet_paths` data frame
with one row per vertex: `node`, `reachable`, `arrival_time`,
`attained`, `latency`, `n_hops` and `n_paths`. A journey is
time-respecting when each hop leaves no earlier than the previous hop
arrived. The criterion is foremost-then-shortest: earliest arrival
first, fewest contacts second.

``` r

routes <- paths(dn, from = "Ana")
routes
#> # Time-respecting paths from 'Ana', from t = 0
#> # reaches 13 of 13 other vertices | time in step
#>   node reachable arrival_time attained latency n_hops n_paths
#>    Ana      TRUE         0.00     TRUE    0.00      0       1
#>    Ben      TRUE         9.59     TRUE    9.59      3       3
#>   Cara      TRUE         6.67     TRUE    6.67      1       1
#>    Dan      TRUE         7.98     TRUE    7.98      4       1
#>    Eve      TRUE        11.66     TRUE   11.66      4       3
#>   Finn      TRUE         6.96     TRUE    6.96      2       1
#>   Gita      TRUE         6.36     TRUE    6.36      2       1
#>   Hugo      TRUE         7.98     TRUE    7.98      3       1
#>   Iris      TRUE        10.00     TRUE   10.00      3       1
#>  Jonas      TRUE         2.12     TRUE    2.12      1       1
#>   Kira      TRUE         6.12     TRUE    6.12      2       2
#>    Leo      TRUE         9.65     TRUE    9.65      3       1
#> # 2 more rows. summary() aggregates them; plot() draws the tree.
```

[`pathways()`](https://pak.dynasite.org/Dynet/reference/pathways.md)
counts the routes those journeys take. It takes a network, optionally
one source, and returns a `dynet_pathways` data frame with one row per
distinct route, most frequent first: `route` as the vertex sequence
joined by arrows, `endpoint`, `count`, and `share` as the route’s
fraction of all counted routes.

[`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md)
builds the union of the optimal routes. It takes a
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) result
and returns a static `dynet_path_network`, whose edge table has one row
per hop used by at least one optimal route and whose node table has one
row per reached vertex. Unreachable vertices are absent rather than
present with missing values.

[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
arranges the routes as a counted prefix tree. It takes a
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) result
and a `min_count` threshold and returns a `dynet_path_trajectories` data
frame with one row per tree node: `node` as the route prefix, `parent`,
`depth`, `count`, `probability`, `vertex`, `time`, `session` and
`branch`.

[`plot_path_trajectories()`](https://pak.dynasite.org/Dynet/reference/plot_path_trajectories.md)
draws that tree. It takes a
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) or
[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
result and a `measure` that decides what the fill encodes, and returns a
`ggplot` object. Each vertex name is printed beside its value, so no
distinction rests on colour alone.

A vertex with declared spells begins its search at its own first
presence inside the window rather than at the window edge. A vertex
never present in the window reaches nothing.

## Structure and animation

[`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md)
expands the network into vertex-time states. It takes the grid arguments
and an interlayer coupling weight `omega`, and returns a
`dynet_projection` holding two tables, reached with
`as.data.frame(x, what = "vertices")` for the states and
`as.data.frame(x, what = "edges")` for the directed arcs between them.
Coupling is ordinal: each slice is joined to the next one only.

[`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md)
reduces temporal activity to one static weighted network. It takes a
`weight` rule that decides what an edge weight means, from `"binary"`
through to summed durations and spell counts, and returns a
`dynet_collapsed` cograph netobject with an edge table and a node table.
Under `sessions = "separate"` it returns one such object per session.

``` r

static <- collapse_network(dn)
static
#> # Collapsed temporal network | 14 vertices | 110 edges | weight: binary
#> # 0 to 21.52 step
#>  from    to binary union_duration total_duration duration_fraction spell_count
#>   Ana  Cara      1           0.10           0.10       0.004646840           1
#>   Ana   Dan      1           1.02           1.02       0.047397770           3
#>   Ana  Gita      1           1.99           2.11       0.092472119           5
#>   Ana  Iris      1           0.50           0.50       0.023234201           1
#>   Ana Jonas      1           2.34           2.34       0.108736059           4
#>   Ana  Kira      1           0.11           0.11       0.005111524           1
#>  weight_sum weighted_duration latest_weight first  last activity.duration
#>           1              0.10             1  6.67  6.77              0.10
#>           3              1.02             1 12.04 20.10              1.02
#>           5              2.11             1  6.57 14.16              1.99
#>           1              0.50             1 13.80 14.30              0.50
#>           4              2.34             1  2.12  9.13              2.34
#>           1              0.11             1 11.60 11.71              0.11
#>  activity.count
#>               1
#>               3
#>               5
#>               1
#>               4
#>               1
```

[`induce_subgraph()`](https://pak.dynasite.org/Dynet/reference/induce_subgraph.md)
extracts a subgraph. It takes a condition over the node table, a
condition over the spell table, or both, and returns a network carrying
only the selected spells, the vertices they touch, those vertices’
activity spells, and all static attributes. Centralities are available
as columns inside the `nodes` condition.

[`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md)
renders the measurement grid as a film. It takes the same four grid
arguments as every measuring verb, a `file` whose extension selects the
encoder, and returns a `dynet_animation` data frame with one row per bin
holding `bin`, `frame`, `time`, `window_start`, `window_end`, `nodes`,
`idle`, `ties`, `forming` and `dissolving`. The table is returned
invisibly, since writing the file is the purpose of the call. GIF output
requires gifski; mp4 and webm require av.

## Result classes

Every result class carries `print`, `summary`, `plot` and
`as.data.frame` – 50 S3 methods in total. A secondary table always comes
out through an argument, never by reaching in with `$`.

| Class | Returned by |
|----|----|
| `dynet` | [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md), [`as_dynet()`](https://pak.dynasite.org/Dynet/reference/as_dynet.md), and every editing verb |
| `dynet_metric` | [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md), [`dyn_reachability()`](https://pak.dynasite.org/Dynet/reference/dyn_reachability.md), [`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md), [`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md), [`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md), [`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md), [`events()`](https://pak.dynasite.org/Dynet/reference/events.md) |
| `dynet_paths` | [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) |
| `dynet_pathways` | [`pathways()`](https://pak.dynasite.org/Dynet/reference/pathways.md) |
| `dynet_path_network` | [`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md) |
| `dynet_path_trajectories` | [`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md) |
| `dynet_snapshot` | [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md) |
| `dynet_similarity` | [`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md) |
| `dynet_pshifts` | [`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md) |
| `dynet_projection` | [`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md) |
| `dynet_collapsed` | [`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md) |
| `dynet_animation` | [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md) |

Secondary tables arrive as `as.data.frame(x, what = "steps")`,
`as.data.frame(x, what = "vertex_spells")`,
`as.data.frame(x, session = "s1")` and the like.

On a measuring verb, `plot = TRUE` follows
[`hist()`](https://rdrr.io/r/graphics/hist.html): drawing is a side
effect and the tidy result still comes back, invisibly when it has
drawn.
