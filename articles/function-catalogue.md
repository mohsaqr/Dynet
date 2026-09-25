# Function catalogue

Dynet provides functions for temporal network construction, editing,
measurement, path analysis, aggregation, and animation. Vertices are
identified by name, and analytical results are returned in tidy formats
with methods for printing, summarising, and plotting. This catalogue
describes the principal inputs and outputs of the 39 exported functions.
Individual help pages document their arguments and conditions in detail.

| Category | Functions | Purpose |
|----|---:|----|
| Construction | 4 | Construct or convert networks and inspect spells and snapshots |
| Editing | 17 | Modify vertices, relational spells, sessions, and observation periods |
| Measurement | 9 | Measure centrality, reachability, structure, mixing, turn-taking, timing, duration, and similarity |
| Paths | 5 | Find time-respecting paths and summarise or visualise their routes |
| Structure | 3 | Project, aggregate, or subset a network |
| Animation | 1 | Animate successive temporal snapshots |

## Construction

[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md)
constructs a temporal network from relational data. It returns an object
of class `c("dynet", "netobject", "cograph_network")`, containing
relational spells, vertices, and construction metadata.

Four input formats are supported. Interval data supply onset and
termination, or onset and duration. Contact data supply instantaneous
interaction timestamps. Threaded data derive termination from the last
retained interaction in each thread. Co-presence data connect actors
attending the same occasion.

With `format = "auto"`, specifying `actor` and `group` selects
co-presence; otherwise, specifying `thread` selects threaded
construction. A specified or recognised termination or duration column
selects interval data when neither preceding condition applies.
Otherwise, contact data are selected. `format` can also be specified
explicitly.

Column matching is case-insensitive. Recognised endpoint aliases include
`from`/`to`, `sender`/`receiver`, and `source`/`target`; interval
boundaries include `start`/`end` and `onset`/`terminus`. Explicit column
specification is needed only for unrecognised or ambiguous names. The
constructor calculates `duration = end - start` and assigns `weight = 1`
when no multiplicity variable is supplied or recognised.

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

The example contains fourteen vertices, 240 relational spells, and 110
distinct ordered pairs, observed from time 0 to 21.52.

[`as_dynet()`](https://pak.dynasite.org/Dynet/reference/as_dynet.md)
converts supported network objects to `dynet`. Its `networkDynamic`
method imports edge spells, vertex activity spells, observation periods,
and edge attributes. Applied to a `dynet` object, it returns the input
unchanged.

[`events()`](https://pak.dynasite.org/Dynet/reference/events.md)
measures spell formation, dissolution, and activity over time. It
accepts `measure` and the measurement-grid arguments and returns a
graph-level `dynet_metric`. Available measures are `"formation"`,
`"dissolution"`, `"active"`, `"new_pairs"`, `"formation_fraction"`,
`"dissolution_fraction"`, `"formation_rate"`, and `"dissolution_rate"`.
Formation and dissolution rates divide transition counts by eligible
pair-time.

[`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
returns the connections active within each measurement bin as a
`dynet_snapshot`. Its tidy columns include `time`, `from`, `to`,
`weight`, and `n_spells`, with session identifiers when applicable.
Multiple spells on the same pair are combined within a bin: `weight`
sums their weights and `n_spells` counts them. `at` selects a single
measurement time.

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

The six four-unit bins contain 216 pair-by-bin observations. In the
first bin, two spells connect Ana and Jonas; `n_spells` records both and
`weight` sums their contributions.

## Editing

Editing functions return a new temporal network and leave their input
unchanged. They update relational spells, vertex attributes, and
associated network representations together. Rebuilding may change spell
identifiers, so subsequent selections should refer to the updated
object.

### Adding

[`add_nodes()`](https://pak.dynasite.org/Dynet/reference/add_nodes.md)
adds vertices from a character vector or a data frame containing `name`
and optional attributes. New vertices are treated as eligible throughout
observation unless activity spells are declared.

[`add_ties()`](https://pak.dynasite.org/Dynet/reference/add_ties.md)
adds relational spells from a data frame of endpoints and times.
Additional columns are retained as spell attributes, and `loops`
controls whether self-links are accepted. The endpoints must already
exist in the network.
[`add_arcs()`](https://pak.dynasite.org/Dynet/reference/add_arcs.md) is
the directed counterpart with the same arguments.

[`add_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/add_vertex_spells.md)
adds activity periods from a table containing `node`, `start`, and
`end`. Overlapping or adjacent periods for the same vertex are merged
with existing declarations.

### Removing

[`remove_nodes()`](https://pak.dynasite.org/Dynet/reference/remove_nodes.md)
removes vertices selected by name. With `cascade = TRUE`, it also
removes their incident spells and activity declarations. A selection
leaving no vertices or no ties raises `dynet_empty_network`.

[`remove_ties()`](https://pak.dynasite.org/Dynet/reference/remove_ties.md)
selects spells through positions or a condition in `ties`, or through
`from`, `to`, `start`, `end`, and `session`. A selection matching no
spells raises `dynet_tie_not_found`.
[`remove_arcs()`](https://pak.dynasite.org/Dynet/reference/remove_arcs.md)
is the directed counterpart.

[`remove_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/remove_vertex_spells.md)
removes declared activity components selected by integer positions or a
logical mask in `spells`. Remaining components are merged where needed
and assigned updated identifiers. A vertex with no remaining declaration
becomes implicitly eligible throughout observation.

### Updating and renaming

[`update_nodes()`](https://pak.dynasite.org/Dynet/reference/update_nodes.md)
adds or replaces vertex attributes from a table keyed by `name`.
Vertices absent from the supplied table retain their existing
attributes.

[`update_ties()`](https://pak.dynasite.org/Dynet/reference/update_ties.md)
replaces fields of spells selected through `ties`, using replacement
values supplied in `data`. Unselected spells are retained.

[`update_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/update_vertex_spells.md)
replaces fields of activity components selected through `spells`. The
updated and retained periods are combined, merging overlaps and adjacent
periods. Unrecognised fields raise `dynet_unknown_column`.

[`rename_nodes()`](https://pak.dynasite.org/Dynet/reference/rename_nodes.md)
updates vertex names throughout the network. `mapping` accepts a named
character vector, a data frame with `old` and `new` columns, or a vertex
attribute whose values provide the new names. Relational endpoints,
vertex attributes, activity declarations, and associated labels are
updated together.

[`rename_sessions()`](https://pak.dynasite.org/Dynet/reference/rename_sessions.md)
updates session identifiers using the supported mapping forms and
updates the session metadata. Unmapped session labels are retained.

### Observation periods and activity

[`set_observations()`](https://pak.dynasite.org/Dynet/reference/set_observations.md)
replaces the observation calendar using a table of intervals in `data`
or a `start` and `end` pair. The original relational spells remain
available through
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html);
measurements use their intersections with the declared periods.

[`clear_observations()`](https://pak.dynasite.org/Dynet/reference/clear_observations.md)
removes the explicit calendar and restores continuous observation from
the earliest raw onset to the latest raw termination.

[`set_tie_sessions()`](https://pak.dynasite.org/Dynet/reference/set_tie_sessions.md)
assigns session labels through `session`, using either a single label or
a vector matching the number of raw spells. A full-length vector follows
the sorted spell-table order and should therefore be derived from
`as.data.frame(dn)`. Setting `session = NULL` removes the assignments.
The function also supports assigning sessions from onset-time boundaries
through `breaks` and `labels`.

[`set_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/set_vertex_spells.md)
replaces declared vertex activity using a table in `data`. The special
value `"ties"` derives activity from each vertex’s first spell onset to
its last termination.

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
activity <- as.data.frame(present, what = "vertex_spells")
head(activity)
#>   vertex_spell node start   end duration instant session onset_censored
#> 1            1  Ana  0.14 21.52    21.38   FALSE    <NA>          FALSE
#> 2            2  Ben  0.33 20.81    20.48   FALSE    <NA>          FALSE
#> 3            3 Cara  0.78 20.91    20.13   FALSE    <NA>          FALSE
#> 4            4  Dan  0.00 21.33    21.33   FALSE    <NA>          FALSE
#> 5            5  Eve  0.43 21.12    20.69   FALSE    <NA>          FALSE
#> 6            6 Finn  0.83 20.26    19.43   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE
#> 3             FALSE
#> 4             FALSE
#> 5             FALSE
#> 6             FALSE
```

The relational spells are unchanged. The extracted activity table
records a derived participation period for each vertex; these boundaries
need not represent independently observed arrival or departure times.

## Measurement

Graph-level measures describe network structure as a whole. Vertex-level
measures describe individual positions, while pair-level measures
describe relationships between endpoints. Dynet returns these quantities
in tidy results identified by the relevant vertices or pairs, `measure`,
and `value`, with `time` and `session` where applicable.

The functions differ in their temporal arguments.
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md),
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md),
[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md), and
[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md)
accept `start`, `end`, `step`, and `window`.
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md),
[`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md),
and [`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md)
accept `start` and `end`.
[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
and
[`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md)
summarise the observation period without a measurement grid.

[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md)
applies the selected centrality measures to successive snapshots. For
measures supporting direction selection, `mode` selects incoming,
outgoing, or all connections.
[`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md)
calculates `"closeness"` and `"betweenness"` using time-respecting
paths; its results describe the selected search period and have no
`time` column.

``` r

between <- centrality_series(dn, measure = "betweenness")
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

The example calculates snapshot betweenness for fourteen vertices across
22 bins, giving 308 observations. Among the values printed for the first
bin, only Iris and Kira have nonzero betweenness.

[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md)
calculates the number or proportion of other vertices connected to each
vertex through time-respecting paths. `direction` selects forward or
backward search, and `measure` selects `"reach"` or `"reach_count"`.
Results are labelled `forward_reach`, `backward_reach`,
`forward_reach_count`, or `backward_reach_count`. A vertex is excluded
from its own reachable set.

[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md)
calculates graph-level measures selected through `measure`. Results are
indexed by measurement time and measure. Requesting `"triads"` returns
counts for the sixteen directed triad classes at each time.

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
summary(density)
#>   measure  n       mean         sd        min       max peak_time
#> 1 density 22 0.08291708 0.03929021 0.03296703 0.1648352        14
```

The example measures density in 22 bins.
[`summary()`](https://rdrr.io/r/base/summary.html) reports its mean,
standard deviation, range, and peak time. Mean density is 0.083, and the
maximum of 0.165 occurs in the bin beginning at time 14.

[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) counts
connections within and between groups defined by a vertex attribute.
`attribute` selects the grouping variable. The result identifies ordered
group pairs through `from_group` and `to_group`, with `value` counting
distinct connected vertex pairs in each window. Connections in the same
window need not be simultaneous, and these counts are not probabilities.

[`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md)
classifies consecutive directed interactions into the thirteen
participation-shift types of Gibson (2003). The returned `dynet_pshifts`
contains `shift`, `family`, and `count`. `output = "final"` reports all
thirteen types, including zero counts. `output = "cumulative"` reports
running counts after each classified turn.

[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
describes the spacing of spell onsets involving each vertex. `measure`
selects `"burstiness"`, `"memory"`, or `"events"`. Burstiness is
$`(\sigma-\mu)/(\sigma+\mu)`$, where $`\mu`$ and $`\sigma`$ are the mean
and population standard deviation of inter-event intervals. It equals −1
for equal positive intervals and approaches 1 with increasing relative
variability. A value of 0 matches the theoretical exponential
waiting-time reference but does not establish Poisson timing. Memory is
the correlation between successive intervals.

[`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md)
summarises observed spell durations. `unit` selects relational pairs
(`"pair"`), individual spells (`"spell"`), vertex activity
(`"vertex_activity"` or `"vertex_spell"`), or incident relational spells
(`"node_ties"`). Available measures depend on this unit. Pair-level
defaults are `"events"`, `"total"`, and `"mean"`; `"union"` and
`"median"` are also available. Individual-spell output defaults to
`"duration"`. `censored` controls inclusion of spells with unobserved
boundaries.

[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md)
compares the connection sets of temporal snapshots using `"jaccard"`,
`"overlap"`, `"hamming"`, `"cosine"`, or `"pearson"`. It returns a
`dynet_similarity` indexed by `time` and `other`, with the selected
coefficient in `measure` and its value in `value`. Self-comparisons are
included. Hamming distance is zero for identical snapshots; the other
coefficients express similarity. At least two measurement bins are
required.

### The shared grid

For functions supporting window-based measurement, four arguments define
the grid. Their relationship to
[`tsna::tSnaStats()`](https://rdrr.io/pkg/tsna/man/tSnaStats.html) is
shown below.

| Argument       | Meaning                                     | tsna equivalent |
|----------------|---------------------------------------------|-----------------|
| `start`, `end` | First and last measurement times            | `start`, `end`  |
| `step`         | Interval between measurements               | `time.interval` |
| `window`       | Duration covered from each measurement time | `aggregate.dur` |

By default, `step` uses the network’s construction interval and `window`
equals `step`, producing non-overlapping windows. A larger `window`
produces overlapping windows. `window = 0` evaluates individual time
points, while `window = "all"` aggregates the observation period into a
single window. The last option is unsuitable for
[`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md),
which requires multiple snapshots.

## Paths

[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) finds
time-respecting paths from the vertex named in `from`. Each interaction
must be available at or after arrival at its starting vertex. The
default search selects earliest arrival first and then the fewest
interactions among paths arriving at that time: the shortest foremost
criterion.

The returned `dynet_paths` describes each destination through `node`,
`reachable`, `arrival_time`, `attained`, `latency`, `n_hops`, and
`n_paths`. In a forward search, latency is elapsed time from the search
start to arrival, including waiting. A backward search instead
identifies the latest departure boundary from which the specified vertex
can be reached by the deadline. `attained` distinguishes an achievable
boundary time from a limiting time excluded by a spell’s termination.

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

Ana reaches all thirteen other students. Jonas is reached at time 2.12
in one hop; Eve is reached at time 11.66 in four hops through three
shortest foremost paths.

[`pathways()`](https://pak.dynasite.org/Dynet/reference/pathways.md)
groups paths by their sequence of vertices. It accepts a network and an
optional source in `from`, and returns a `dynet_pathways` containing
`route`, `endpoint`, `count`, `share`, `n_hops`, and `arrival_time`.
Routes correspond to leaves of the path tree, so an intermediate prefix
is not listed separately. Paths following the same vertex sequence
through different spells contribute to the same route count. `share` is
the route’s proportion of counted paths, and routes are ordered by
decreasing count.

[`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md)
converts a
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) result to
a static `dynet_path_network` containing the connections used by optimal
paths and the vertices they reach. Unreachable vertices are omitted.

[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
represents the paths as a tree whose branches share common initial
steps. It accepts a
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) result
and an optional `min_count` threshold. The returned
`dynet_path_trajectories` contains `node`, `parent`, `depth`, `count`,
`probability`, `vertex`, `time`, `session`, and `branch`. `probability`
expresses a tree node’s count relative to its parent’s count, rather
than an empirical probability of transmission.

[`plot_path_trajectories()`](https://pak.dynasite.org/Dynet/reference/plot_path_trajectories.md)
draws a [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md)
or
[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
result. `measure` selects `"frequency"`, `"time"`, or `"predictability"`
for fill, and the function returns a `ggplot` object. Labels identify
vertices and values.

A vertex with declared activity begins its search at its first eligible
time within the search period. A vertex absent throughout that period
reaches no other vertex.

## Structure and animation

[`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md)
constructs a network of vertex-time states. It accepts the grid
arguments and interlayer coupling weight `omega`. The returned
`dynet_projection` provides state and edge tables through
`as.data.frame(x, what = "vertices")` and
`as.data.frame(x, what = "edges")`. Interlayer connections join
consecutive slices.

[`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md)
aggregates temporal activity into a static weighted network. `weight`
selects `"binary"`, `"union_duration"`, `"total_duration"`,
`"duration_fraction"`, `"spell_count"`, `"weight_sum"`,
`"weighted_duration"`, or `"latest_weight"`. The default is binary
presence. The result is a `dynet_collapsed`; with
`sessions = "separate"`, a `dynet_collapsed_list` contains a network for
each session.

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

The collapsed classroom network contains fourteen vertices and 110
connected pairs. Its edge table includes the available weight summaries
and the first and last observed contact times for each pair.

[`induce_subgraph()`](https://pak.dynasite.org/Dynet/reference/induce_subgraph.md)
selects vertices through `nodes`, spells through `ties`, or both. It
retains the selected network’s attributes and vertex activity.
Centralities computed over the observation period are available within
vertex-selection conditions.

[`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md)
displays successive snapshots using `start`, `end`, `step`, and
`window`. `file` selects the output path and encoder; `layout` controls
positions, `measure` controls vertex size, and `tween` and `fps` control
frame generation. `absent`, `isolates`, and `ease` govern presence and
transitions.

The function writes the animation and invisibly returns a
`dynet_animation` containing `bin`, `frame`, `time`, `window_start`,
`window_end`, `nodes`, `idle`, `ties`, `forming`, `dissolving`, and
`file`. GIF output requires `gifski`; MP4 and WebM output require `av`.

## Result classes

Result classes provide methods appropriate to their contents, including
printing, summarising, plotting, and conversion to data frames. Use
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) with the
documented `what` argument to extract secondary tables.

| Class | Returned by |
|----|----|
| `dynet` | [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md), [`as_dynet()`](https://pak.dynasite.org/Dynet/reference/as_dynet.md), and editing functions |
| `dynet_metric` | [`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md), [`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md), [`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md), [`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md), [`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md), [`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md), [`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md), [`events()`](https://pak.dynasite.org/Dynet/reference/events.md) |
| `dynet_paths` | [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) |
| `dynet_pathways` | [`pathways()`](https://pak.dynasite.org/Dynet/reference/pathways.md) |
| `dynet_path_network` | [`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md) |
| `dynet_path_trajectories` | [`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md) |
| `dynet_snapshot` | [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md) |
| `dynet_similarity` | [`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md) |
| `dynet_pshifts` | [`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md) |
| `dynet_projection` | [`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md) |
| `dynet_collapsed` | [`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md) |
| `dynet_collapsed_list` | [`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md) with `sessions = "separate"` |
| `dynet_animation` | [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md) |

For example, `as.data.frame(x, what = "steps")` extracts individual path
steps, `as.data.frame(x, what = "vertex_spells")` extracts declared
vertex activity, and `as.data.frame(x, session = "s1")` selects a
session where supported.

For measurement functions supporting `plot = TRUE`, plotting is a side
effect: the analytical result is still returned, invisibly after the
plot is drawn.

## References

Gibson, D. R. (2003). Participation shifts: Order and differentiation in
group conversation. *Social Forces*, 81(4), 1335–1380.

Goh, K.-I., & Barabási, A.-L. (2008). Burstiness and memory in complex
systems. *EPL (Europhysics Letters)*, 81(4), 48002.

Kempe, D., Kleinberg, J., & Kumar, A. (2002). Connectivity and inference
problems for temporal networks. *Journal of Computer and System
Sciences*, 64(4), 820–842.
