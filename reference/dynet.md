# Build a temporal network

Builds a temporal network from a relational log. One constructor covers
the four shapes relational data actually arrives in, and the shape is
inferred from the arguments you name:

- interval:

  Each row is an edge active over `[start, end)`. Used when the data
  carry an end time or a duration.

- contact:

  Each row is an instantaneous event with a time and no duration – a
  message, a click, a citation.

- threaded:

  Forum, chat or email data. An edge is treated as active from its own
  post until the last post in the same thread, following Saqr and Nouri
  (2020). Name the `thread` argument to select this.

- copresence:

  Two-mode attendance data. Actors sharing a group become connected for
  the span of that group. Name `actor` and `group`.

Column names are resolved case-insensitively from a table of aliases, so
`Sender`/`Receiver`, `source`/`target` and `onset`/`terminus` are all
understood without being spelled out. Times may be numeric, `Date`,
`POSIXct` or character date-time strings; character and date-time input
is converted to elapsed time since the first event in a readable unit.

Vertices are addressed by name everywhere in this package. Integer
vertex indices are used internally for speed but are never part of any
result.

Explicit observation bounds are administrative measurement limits, not a
destructive filter. A positive spell `[s,e)` contributes the half-open
intersection `[max(s,L),min(e,U))` when it has positive duration, while
a genuine instantaneous event is retained at either `L` or `U`. Original
endpoints remain the only formation and dissolution events, censoring is
never inferred from equality with a limit, and temporal paths must both
start and finish inside the declared interval.

Vertex activity is a separate declaration. A vertex with at least one
row in `vertex_spells` is eligible only on the union of those half-open
positive spells and exact points; a vertex with no row remains eligible
at all times. Snapshot measurements independently union eligible
vertices and active edges over each positive window and then induce on
eligible endpoints; point snapshots evaluate both at the exact time.
Explicit vertex censor flags describe raw outer-boundary state and are
never inferred from observation limits or used to alter eligibility.

## Usage

``` r
dynet(
  data,
  from = NULL,
  to = NULL,
  start = NULL,
  end = NULL,
  duration = NULL,
  time = NULL,
  thread = NULL,
  actor = NULL,
  group = NULL,
  session = NULL,
  weight = NULL,
  nodes = NULL,
  groups = NULL,
  format = c("auto", "interval", "contact", "threaded", "copresence"),
  directed = TRUE,
  interval = 1,
  time_unit = "auto",
  observation_start = NULL,
  observation_end = NULL,
  observation_spells = NULL,
  loops = FALSE,
  onset_censored = NULL,
  terminus_censored = NULL,
  vertex_spells = NULL
)
```

## Arguments

- data:

  Data frame holding one relational event per row.

- from, to:

  Column names for the source and target vertex. Auto-detected from
  `from`/`to`, `source`/`target`, `sender`/`receiver`, `tail`/`head`,
  `ego`/`alter`.

- start, end:

  Column names for the start and end of an edge spell. Auto-detected
  from `start`/`end`, `onset`/`terminus`, `begin`/`finish`.

- duration:

  Column name for a spell duration, used in place of `end`.

- time:

  Column name for an event time, used in place of `start`. Auto-detected
  from `time`, `timestamp`, `date`, `datetime`.

- thread:

  Column name identifying a conversation thread. Naming it selects the
  threaded format.

- actor, group:

  Column names for the actor and the shared group. Naming both selects
  the co-presence format.

- session:

  Column name for a session or period grouping. Sessions act as walls
  that time-respecting paths do not cross.

- weight:

  Column name for event multiplicity. Defaults to one event per row.

- nodes:

  Optional data frame of vertex attributes. The vertex key is
  auto-detected, or given as the first column.

- groups:

  Name of a column in `nodes` to use as the vertex partition. Written
  into the places cograph looks for it, so
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
  colours and groups by it without further argument.

- format:

  One of `"auto"`, `"interval"`, `"contact"`, `"threaded"`,
  `"copresence"`. `"auto"` infers the format from the arguments you name
  and the columns present.

- directed:

  Whether edges are directed. Co-presence networks are always
  undirected.

- interval:

  Width of one time bin, in the network's time unit.

- time_unit:

  Unit for converting `Date`/`POSIXct`/character times: `"auto"`,
  `"seconds"`, `"minutes"`, `"hours"`, `"days"` or `"weeks"`. Numeric
  times are left alone and reported as `"step"`.

- observation_start, observation_end:

  Optional bounds of the continuous observation interval. Supply numeric
  values in the network's internal time scale, or `Date`/`POSIXct`
  values for a calendar network. Either bound may be omitted, in which
  case the corresponding raw event limit is used. Positive spells are
  measured on their half-open intersection with this interval;
  instantaneous events are retained at either boundary. Raw spell
  endpoints returned by
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) are
  never changed.

- observation_spells:

  Optional data frame with `start` and `end` columns defining
  discontinuous observed support. Overlapping and adjacent positive
  intervals are merged; isolated points are retained. This is mutually
  exclusive with `observation_start` and `observation_end`.

- loops:

  Whether to keep self-loops. `FALSE` drops them with a message, which
  is almost always what relational logs need.

- onset_censored, terminus_censored:

  Optional logical column names for explicit raw interval-boundary
  censor state. These selectors are available only for interval input,
  are never auto-detected, and may not flag a zero-duration point.

- vertex_spells:

  Optional tidy vertex-activity table with exact columns `node`,
  `start`, and `end`, plus optional `session`, `onset_censored`, and
  `terminus_censored`. Positive spells use `[start,end)` and points are
  exact. Overlapping and adjacent positive spells are unioned
  independently by node and session. A vertex absent from this table
  remains active at all times.

## Value

An object of class `c("dynet", "netobject", "cograph_network")`. It is a
cograph network, so
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
draws it directly and every cograph rendering argument applies. Use
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) for the
tidy spell table, `as.data.frame(x, what = "nodes")` for the vertex
table, `as.data.frame(x, what = "network")` for the aggregate edge list,
[`summary()`](https://rdrr.io/r/base/summary.html) for the description
and [`plot()`](https://rdrr.io/r/graphics/plot.default.html) for a
picture. Nothing in this package requires you to reach into the object.

## References

Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis
to understand and improve collaborative learning. *Proceedings of the
Tenth International Conference on Learning Analytics & Knowledge*,
314-319.

Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97-125.

Butts, C. T. (2008). network: a package for managing relational data in
R. *Journal of Statistical Software*, 24(2), 1-36.

## Examples

``` r
# An interval log: each row carries its own start and end
dynet(school_contacts)
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

# A threaded log: edge stays active until its thread falls silent
dynet(forum_posts, thread = "thread")
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 20 vertices | 241 edge spells | 172 distinct pairs
#> # observed from 0 to 54.96387 days, binned every 1
#> 
#>        from         to     start      end duration weight    thread
#>  student_14 student_05 0.0000000 2.296969 2.296969      1 thread_47
#>  student_10 student_05 0.7257216 2.296969 1.571247      1 thread_47
#>   teacher_A student_09 0.8559934 3.235993 2.380000      1 thread_11
#>  student_04 student_05 1.1715344 2.296969 1.125435      1 thread_47
#>  student_02 student_09 1.2382611 3.235993 1.997732      1 thread_11
#>  student_06  teacher_A 1.9797595 3.235993 1.256234      1 thread_11
#> # 235 more spells. summary() describes the network; plot() draws it.

# A co-presence log: actors sharing a group become connected
dynet(seminar_attendance, actor = "student", group = "seminar")
#> # Temporal network (copresence format, undirected) | a cograph netobject
#> # 24 vertices | 417 edge spells | 224 distinct pairs
#> # observed from 0 to 77 days, binned every 1
#> 
#>  from  to start end duration weight   group
#>   s03 s10     0   0        0      1 week_01
#>   s03 s12     0   0        0      1 week_01
#>   s03 s21     0   0        0      1 week_01
#>   s03 s22     0   0        0      1 week_01
#>   s03 s23     0   0        0      1 week_01
#>   s10 s12     0   0        0      1 week_01
#> # 411 more spells. summary() describes the network; plot() draws it.

# Declare observation time without rewriting the source spell.
bounded <- dynet(data.frame(
  from = "A", to = "B", start = -2, end = 8
), observation_start = 0, observation_end = 5)
as.data.frame(bounded)
#>   from to start end duration weight
#> 1    A  B    -2   8       10      1

# Declare changing vertex eligibility without altering edge spells.
scheduled <- dynet(data.frame(
  from = "A", to = "B", start = 0, end = 10
), vertex_spells = data.frame(
  node = c("A", "A"), start = c(0, 7), end = c(4, 10)
))
as.data.frame(scheduled, what = "vertex_spells")
#>   vertex_spell node start end duration instant session onset_censored
#> 1            1    A     0   4        4   FALSE    <NA>          FALSE
#> 2            2    A     7  10        3   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE
```
