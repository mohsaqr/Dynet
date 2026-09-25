# Building and inspecting a temporal network

``` r

library(Dynet)
```

This vignette describes how to construct and inspect temporal networks
with [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md). It
covers four relational data formats, vertex attributes, sessions,
observation periods, and vertex activity spells. It also introduces
network editing and descriptive measures.
[`vignette("dynet")`](https://pak.dynasite.org/Dynet/articles/dynet.md)
provides a worked analysis of a simulated classroom network.

## The four input formats

[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) accepts
interval, contact, threaded, and co-presence data in tidy format. These
formats differ in how relational endpoints and timing are recorded. The
constructor selects a format from the supplied arguments and recognised
timing columns, or uses the format specified explicitly by the user.

### Interval data

Interval data record the onset and termination of each relationship.
Each relational spell identifies two endpoints and the period during
which their connection is active.

`school_contacts` contains 240 simulated face-to-face contacts among
fourteen students over approximately three weeks. The supplied variables
`from` and `to` identify the initiating and receiving students. `start`
and `end` record onset and termination in days since the beginning of
observation. Decimal values allow contacts to begin and end within a
day.

``` r

head(school_contacts, 4)
#>    from   to start  end
#> 1 Jonas  Dan  0.00 1.10
#> 2  Gita  Ana  0.14 0.98
#> 3   Leo Mira  0.15 0.42
#> 4   Leo Iris  0.15 0.96
```

[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md)
constructs the network directly from these data. Printing the result
reports its format, direction, vertex and spell counts, distinct pairs,
observation period, and measurement grid, followed by the first
relational spells.

``` r

school <- dynet(school_contacts)
school
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

Column recognition is case-insensitive. The endpoint aliases
`from`/`to`, `sender`/`receiver`, and `source`/`target` are equivalent,
as are `start`/`end` and `onset`/`terminus` for interval boundaries.
Explicit column specification is needed only when names do not match
recognised aliases or their interpretation is ambiguous. A `duration`
column may replace `end`; termination is then calculated as
`start + duration`.

The constructor standardises the supplied variables and derives
additional quantities where needed. Here, it calculates
`duration = end - start` and assigns `weight = 1` because no
multiplicity variable is supplied or recognised.

The 240 spells connect 110 distinct ordered pairs. With fourteen
vertices and self-links excluded, there are $`14 \times 13 = 182`$
possible ordered pairs. Approximately 60% are connected at least once
during observation. This aggregate proportion does not indicate how many
pairs are connected within any particular interval.

### Contact data

Contact data record a timestamp for each interaction without a
termination time. The resulting temporal network is a contact sequence:
each spell is instantaneous, with equal onset and termination and zero
duration.

`forum_posts` is a simulated course forum dataset containing sender and
receiver identifiers, a `POSIXct` timestamp, and a thread identifier.

``` r

head(forum_posts, 3)
#>       sender   receiver           timestamp    thread
#> 1 student_14 student_05 2024-09-02 19:59:20 thread_47
#> 2 student_10 student_05 2024-09-03 13:24:23 thread_47
#> 3  teacher_A student_09 2024-09-03 16:31:58 thread_11
```

The following call explicitly identifies the timestamp column. Its
recognised name also allows the constructor to infer it when `time` is
omitted.

``` r

clicks <- dynet(forum_posts, time = "timestamp")
clicks
#> # Temporal network (contact format, directed) | a cograph netobject
#> # 20 vertices | 241 edge spells | 172 distinct pairs
#> # observed from 0 to 54.96387 days, binned every 1
#> 
#>        from         to     start       end duration weight
#>  student_14 student_05 0.0000000 0.0000000        0      1
#>  student_10 student_05 0.7257216 0.7257216        0      1
#>   teacher_A student_09 0.8559934 0.8559934        0      1
#>  student_04 student_05 1.1715344 1.1715344        0      1
#>  student_02 student_09 1.2382611 1.2382611        0      1
#>  student_06  teacher_A 1.9797595 1.9797595        0      1
#> # 235 more spells. summary() describes the network; plot() draws it.
```

The 241 posts produce 241 instantaneous spells among twenty vertices,
connecting 172 of the 380 possible ordered pairs. Calendar times are
converted to elapsed time from the first event, with the unit selected
automatically from the temporal span. Here, the span is approximately 55
days, so the unit and default measurement interval are days. Numeric
times retain their supplied scale and are labelled `step`.

### Threaded data

Threaded data contain timestamps and discussion identifiers. A
discussion-based duration represents the period during which a post
remains part of an ongoing exchange, as subsequent interactions respond
to or address that discussion. Following the approach of Saqr and Nouri
(2020), Dynet treats a post as active from its timestamp until the last
retained post in the same thread. For a post at time $`t_i`$ in thread
$`T`$, the relational spell is $`[t_i, \max_{j \in T} t_j)`$. A final
post has zero duration. This is a modelling assumption about discussion
activity, rather than a directly observed contact duration.

Specifying `thread` selects this construction. The optional `nodes`
argument supplies vertex attributes.

``` r

forum <- dynet(forum_posts, thread = "thread", nodes = forum_people)
forum
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 20 vertices | 241 edge spells | 172 distinct pairs
#> # observed from 0 to 54.96387 days, binned every 1
#> # vertex attributes: role, achievement
#> 
#>        from         to     start      end duration weight    thread
#>  student_14 student_05 0.0000000 2.296969 2.296969      1 thread_47
#>  student_10 student_05 0.7257216 2.296969 1.571247      1 thread_47
#>   teacher_A student_09 0.8559934 3.235993 2.380000      1 thread_11
#>  student_04 student_05 1.1715344 2.296969 1.125435      1 thread_47
#>  student_02 student_09 1.2382611 3.235993 1.997732      1 thread_11
#>  student_06  teacher_A 1.9797595 3.235993 1.256234      1 thread_11
#> # 235 more spells. summary() describes the network; plot() draws it.
```

The network retains the same 241 spells, twenty vertices, and 172
ordered pairs as the contact representation. Each spell now carries its
thread identifier and a derived termination time. The 62 thread-closing
posts have zero duration; the remaining spells have positive duration.

`summary(..., temporal_density = TRUE)` compares the two representations
using both mean snapshot density and temporal density. Temporal density
is optional because its calculation integrates activity over eligible
vertex pairs and can be more computationally demanding.

``` r

summary(clicks, temporal_density = TRUE)
#>                 property    value
#> 1                 format  contact
#> 2               directed      yes
#> 3               vertices       20
#> 4            edge spells      241
#> 5         distinct pairs      172
#> 6              time unit     days
#> 7          observed from        0
#> 8            observed to 54.96387
#> 9                   span 54.96387
#> 10             bin width        1
#> 11             time bins       55
#> 12 mean snapshot density   0.0112
#> 13      temporal density        0
#> 14              sessions     none
#> 15     vertex attributes     none
```

``` r

summary(forum, temporal_density = TRUE)
#>                 property             value
#> 1                 format          threaded
#> 2               directed               yes
#> 3               vertices                20
#> 4            edge spells               241
#> 5         distinct pairs               172
#> 6              time unit              days
#> 7          observed from                 0
#> 8            observed to          54.96387
#> 9                   span          54.96387
#> 10             bin width                 1
#> 11             time bins                55
#> 12 mean snapshot density            0.0248
#> 13      temporal density            0.0139
#> 14              sessions              none
#> 15     vertex attributes role, achievement
```

**Mean snapshot density** averages the proportion of ordered pairs
connected at some point within each measurement bin. **Temporal
density** measures the proportion of available pair-time occupied by
connections. For a fixed population of $`n`$ vertices observed
continuously for duration $`\tau`$, with self-links excluded,

``` math
D_T = \frac{\sum_r U_r}{n(n - 1)\,\tau},
```

where $`U_r`$ is the total duration for which ordered pair $`r`$ has at
least one active spell. Overlapping spells on the same pair contribute
their union duration.

The contact representation has mean snapshot density 0.0112 and temporal
density 0: instantaneous contacts count within bins but occupy no
positive duration. The threaded representation has mean snapshot density
0.0248 and temporal density 0.0139. Its connections occupy 290.8
pair-days across 380 possible pairs and 54.96 observed days. These
differences follow from the specified duration rule, which is applied
when the threaded format is selected.

### Co-presence data

Co-presence data record actors’ participation in shared occasions rather
than direct relationships between actors. A projection connects actors
who attend the same occasion. `seminar_attendance` records attendance at
weekly seminars over one term.

``` r

head(seminar_attendance, 3)
#>   student seminar       date
#> 1     s12 week_01 2024-09-03
#> 2     s22 week_01 2024-09-03
#> 3     s23 week_01 2024-09-03
```

Specify `actor` and `group` to identify the participant and occasion
columns.

``` r

seminars <- dynet(seminar_attendance, actor = "student", group = "seminar")
seminars
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
```

Each seminar contributes a spell for every pair of attendees, tagged
with that seminar’s identifier. A seminar with $`k`$ attendees therefore
contributes $`\binom{k}{2}`$ spells. Across all seminars, the resulting
network contains 417 spells and 224 distinct pairs among 24 students.
These pairs represent approximately 81% of the $`\binom{24}{2} = 276`$
possible unordered pairs.

Co-presence is symmetric, so the constructor creates an undirected
network even if `directed = TRUE` is supplied. Here, the input supplies
a date without a termination time, so the projected spells are
instantaneous contacts on the seminar date.

### Choosing the format

With the default `format = "auto"`, specifying both `actor` and `group`
selects co-presence; otherwise, specifying `thread` selects threaded
data. If neither condition applies, an explicitly specified or
automatically recognised termination or duration column selects interval
data. Otherwise, the constructor selects contact data.

A thread column is not sufficient by itself to select threaded
construction. Consequently, the following call interprets `forum_posts`
as a contact sequence:

``` r

auto <- dynet(forum_posts)
auto
#> # Temporal network (contact format, directed) | a cograph netobject
#> # 20 vertices | 241 edge spells | 172 distinct pairs
#> # observed from 0 to 54.96387 days, binned every 1
#> 
#>        from         to     start       end duration weight
#>  student_14 student_05 0.0000000 0.0000000        0      1
#>  student_10 student_05 0.7257216 0.7257216        0      1
#>   teacher_A student_09 0.8559934 0.8559934        0      1
#>  student_04 student_05 1.1715344 1.1715344        0      1
#>  student_02 student_09 1.2382611 1.2382611        0      1
#>  student_06  teacher_A 1.9797595 1.9797595        0      1
#> # 235 more spells. summary() describes the network; plot() draws it.
```

Set `format` to `"interval"`, `"contact"`, `"threaded"`, or
`"copresence"` to select the representation explicitly. The required
variables must still be available through recognised aliases or explicit
column arguments.

## Inspecting the network

[`summary()`](https://rdrr.io/r/base/summary.html) returns network
properties in a tidy table.

``` r

summary(school)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices           14
#> 4            edge spells          240
#> 5         distinct pairs          110
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to        21.52
#> 9                   span        21.52
#> 10             bin width            1
#> 11             time bins           22
#> 12 mean snapshot density       0.0829
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         none
```

`vertices` reports the size of the vertex set, `edge spells` counts
relational spells, and `distinct pairs` counts the endpoint pairs they
connect. The classroom network has 240 spells on 110 ordered pairs,
indicating repeated contact for at least some pairs.

`time unit` is `step` for numeric input or the selected calendar unit
for date-time input. Without explicit observation bounds, the observed
range extends from the earliest onset to the latest termination.
`bin width` records the construction interval, and `time bins` counts
the intervals covering that range. Here, 22 bins cover 21.52 days; the
final bin is shorter than one day.

`mean snapshot density` is 0.0829: approximately 8.3% of possible
ordered pairs are connected in an average daily bin, compared with about
60% across the full observation period. `temporal density` is calculated
only when requested.

[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) extracts
the constructed relational spells, including `duration` and `weight`.

``` r

spells <- as.data.frame(school)
head(spells, 4)
#>    from   to start  end duration weight
#> 1 Jonas  Dan  0.00 1.10     1.10      1
#> 2  Gita  Ana  0.14 0.98     0.84      1
#> 3   Leo Mira  0.15 0.42     0.27      1
#> 4   Leo Iris  0.15 0.96     0.81      1
```

Use `what = "nodes"` to extract vertex attributes. For `forum`, these
include the attributes supplied through `nodes`.

``` r

forum_nodes <- as.data.frame(forum, what = "nodes")
head(forum_nodes, 4)
#>          name        role achievement
#> 1 facilitator Facilitator        <NA>
#> 2  student_01     Student      Middle
#> 3  student_02     Student         Low
#> 4  student_03     Student        High
```

Other options are `"bins"` for the measurement grid, `"network"` for the
aggregate edge list, `"observations"` for the observation calendar,
`"observed_edges"` for spells clipped to that calendar, and
`"vertex_spells"` for declared vertex activity.

``` r

bins <- as.data.frame(school, what = "bins")
head(bins, 4)
#>   bin lo hi time closed
#> 1   1  0  1    0  FALSE
#> 2   2  1  2    1  FALSE
#> 3   3  2  3    2  FALSE
#> 4   4  3  4    3  FALSE
```

Each bin extends from `lo` to `hi` and is labelled by its starting
`time`. Bins are half-open except for the final bin, whose `closed` flag
includes an event at the final observed instant.

``` r

pairs <- as.data.frame(school, what = "network")
head(pairs, 4)
#>   from  to weight
#> 1 Cara Ana      1
#> 2  Dan Ana      2
#> 3 Gita Ana      3
#> 4 Hugo Ana      2
```

The aggregate edge list groups spells by their relational endpoints and
sums their weights. Because every spell in `school` has weight 1, the
aggregate `weight` equals the spell count: Dan contacted Ana twice and
Gita contacted Ana three times. Aggregation summarises these
relationships without retaining their temporal order.

## Direction, loops, weights and attributes

The following dataset contains five spells among three vertices,
including a self-link from `A` to `A`. The supplied `posts` variable
records the number of messages represented by each spell.

``` r

tiny <- data.frame(
  from  = c("A", "B", "A", "C", "A"),
  to    = c("B", "A", "C", "A", "A"),
  start = c(0, 1, 2, 3, 4),
  end   = c(2, 3, 5, 4, 6),
  posts = c(3, 1, 2, 5, 1)
)
```

Set `directed = FALSE` to construct an undirected network and use
`weight` to identify the multiplicity variable. Columns named `weight`,
`weights`, or `strength` are recognised automatically; `posts` requires
explicit specification.

``` r

undirected <- dynet(tiny, directed = FALSE, weight = "posts")
#> Dropped 1 self-loop event(s). Use loops = TRUE to keep them.
undirected
#> # Temporal network (interval format, undirected) | a cograph netobject
#> # 3 vertices | 4 edge spells | 2 distinct pairs
#> # observed from 0 to 5 step, binned every 1
#> 
#>  from to start end duration weight
#>     A  B     0   2        2      3
#>     A  B     1   3        2      1
#>     A  C     2   5        3      2
#>     A  C     3   4        1      5
```

The result contains four spells on two unordered pairs. The spells
`A -> B` and `B -> A` connect the same undirected pair but retain their
individual onset and termination times; they overlap during $`[1, 2)`$.
The constructor removes the self-link because `loops = FALSE` by default
and records the supplied `posts` values as `weight`.

Set `loops = TRUE` to retain self-links. Under total degree, a retained
loop contributes twice, once at each endpoint.

``` r

with_loops <- dynet(tiny, loops = TRUE)
#> Keeping 1 self-loop event(s); each adds two to its vertex's degree.
with_loops
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 3 vertices | 5 edge spells | 5 distinct pairs
#> # observed from 0 to 6 step, binned every 1
#> 
#>  from to start end duration weight posts
#>     A  B     0   2        2      1     3
#>     B  A     1   3        2      1     1
#>     A  C     2   5        3      1     2
#>     C  A     3   4        1      1     5
#>     A  A     4   6        2      1     1
```

This call retains direction and all five spells, producing five distinct
ordered pairs. Because `weight` is not specified and `posts` is not a
recognised weight alias, `posts` remains a spell attribute and the
constructor assigns the default weight of 1.

`interval` sets the default spacing of measurements in the network’s
time unit.

``` r

tiny_dn <- dynet(tiny, interval = 2)
#> Dropped 1 self-loop event(s). Use loops = TRUE to keep them.
summary(tiny_dn)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices            3
#> 4            edge spells            4
#> 5         distinct pairs            4
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to            5
#> 9                   span            5
#> 10             bin width            2
#> 11             time bins            3
#> 12 mean snapshot density       0.3333
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         none
```

An interval of 2 covers the five-unit observation period with three
bins, the last of which is partial. Their active-pair counts are 2, 3,
and 1 out of six possible ordered pairs. Mean snapshot density is
therefore $`(2/6 + 3/6 + 1/6)/3 = 1/3`$.

The `nodes` argument supplies a vertex table whose identifier column is
recognised by name. `groups` selects an attribute to store as the vertex
grouping;
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
can then use it for vertex colours.

``` r

roles <- dynet(forum_posts, thread = "thread",
               nodes = forum_people, groups = "role")
role_nodes <- as.data.frame(roles, what = "nodes")
head(role_nodes, 4)
#>          name        role achievement      groups
#> 1 facilitator Facilitator        <NA> Facilitator
#> 2  student_01     Student      Middle     Student
#> 3  student_02     Student         Low     Student
#> 4  student_03     Student        High     Student
```

**Mixing** describes connections within and between groups defined by a
vertex attribute.
[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) counts
distinct connected vertex pairs for each ordered group pair and
measurement bin. Connections counted in a bin need not be active
simultaneously.

``` r

role_mixing <- mixing(roles, attribute = "role")
head(role_mixing, 4)
#> # Mixing by role (graph-level)
#> # 55 time points, 1 per bin | time in days
#> # measures: Facilitator -> Facilitator, Student -> Facilitator, Teacher -> Facilitator, Facilitator -> Student
#> # first 4 of 495 rows
#> # active binary-dyad counts between vertex groups per time bin
#>  time                    measure value  from_group    to_group
#>     0 Facilitator -> Facilitator     0 Facilitator Facilitator
#>     0     Student -> Facilitator     0     Student Facilitator
#>     0     Teacher -> Facilitator     0     Teacher Facilitator
#>     0     Facilitator -> Student     0 Facilitator     Student
```

Three roles produce nine ordered group pairs in each of 55 daily bins,
giving 495 observations. In the first bin, no connection involves a
facilitator. These are connection counts, not probabilities or counts of
simultaneous interactions.

## Sessions

Sessions identify contexts within which time-respecting paths may be
constrained, such as courses, terms, or class periods. By default, a
path must use spells assigned to a single session. Session labels do not
reset the clock.

Use `session` during construction to identify an existing session
column. Alternatively,
[`set_tie_sessions()`](https://pak.dynasite.org/Dynet/reference/set_tie_sessions.md)
can assign sessions from spell onset times. The following call assigns
spells to weeks using boundaries at days 7 and 14.

``` r

sessioned <- set_tie_sessions(school, breaks = c(7, 14),
                              labels = c("week_1", "week_2", "week_3"))
summary(sessioned)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices           14
#> 4            edge spells          240
#> 5         distinct pairs          110
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to        21.52
#> 9                   span        21.52
#> 10             bin width            1
#> 11             time bins           22
#> 12 mean snapshot density       0.0829
#> 13      temporal density not computed
#> 14              sessions            3
#> 15     vertex attributes         none
```

The summary now reports three sessions. The `sessions` argument controls
how path searches use these assignments.

``` r

collapsed <- paths(sessioned, from = "Ana", sessions = "collapse")
summary(collapsed)
#>          property   value
#> 1          source     Ana
#> 2       direction forward
#> 3       reachable      13
#> 4 reachable share       1
#> 5  median latency    7.51
#> 6     max latency   11.66
#> 7     median hops       2
#> 8        max hops       4
```

With `sessions = "collapse"`, session labels are ignored and the search
uses the complete temporal sequence. Ana reaches all thirteen other
students, with median latency 7.51 days and a maximum of four hops.

``` r

inside <- paths(sessioned, from = "Ana", sessions = "bounded")
summary(inside)
#>          property   value
#> 1          source     Ana
#> 2       direction forward
#> 3       reachable      13
#> 4 reachable share       1
#> 5  median latency    8.21
#> 6     max latency   13.21
#> 7     median hops       2
#> 8        max hops       5
```

With `sessions = "bounded"`, each path uses spells from a single
session. The search compares session-specific results and retains the
best result for each destination. Ana still reaches all thirteen
students, but median latency increases to 8.21 days, maximum latency to
13.21 days, and maximum hop count to five. Earlier paths that combined
spells assigned to different weeks are no longer admissible.

``` r

per_session <- paths(sessioned, from = "Ana", sessions = "separate")
summary(per_session)
#>    session        property   value
#> 1   week_1          source     Ana
#> 2   week_1       direction forward
#> 3   week_1       reachable       6
#> 4   week_1 reachable share   0.462
#> 5   week_1  median latency    6.36
#> 6   week_1     max latency    6.96
#> 7   week_1     median hops     1.5
#> 8   week_1        max hops       2
#> 9   week_2          source     Ana
#> 10  week_2       direction forward
#> 11  week_2       reachable      13
#> 12  week_2 reachable share       1
#> 13  week_2  median latency    3.36
#> 14  week_2     max latency    6.19
#> 15  week_2     median hops       3
#> 16  week_2        max hops       6
#> 17  week_3          source     Ana
#> 18  week_3       direction forward
#> 19  week_3       reachable       5
#> 20  week_3 reachable share   0.385
#> 21  week_3  median latency    6.42
#> 22  week_3     max latency    6.67
#> 23  week_3     median hops       2
#> 24  week_3        max hops       3
```

With `sessions = "separate"`, results are reported separately for each
session. Ana reaches six students in week 1, thirteen in week 2, and
five in week 3, corresponding to proportions of 0.462, 1, and 0.385. The
longest path within week 2 uses six hops.

`"bounded"` is the default. Without session assignments, it gives the
same result as `"collapse"`. `"separate"` requires session assignments
and otherwise raises `dynet_bad_input`.

## Observation windows

Without explicit bounds, the observation period extends from the
earliest spell onset to the latest termination. These event-derived
limits may differ from the study’s actual observation period. Specifying
`observation_start` and `observation_end` defines the measurement
horizon, including periods when no interaction was recorded.

``` r

bounded <- dynet(school_contacts, observation_start = 0, observation_end = 14)
summary(bounded)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices           14
#> 4            edge spells          240
#> 5         distinct pairs          110
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to           14
#> 9                   span           14
#> 10             bin width            1
#> 11             time bins           14
#> 12 mean snapshot density       0.0922
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         none
```

Restricting observation to days 0–14 produces fourteen bins instead of
22. Mean snapshot density is 0.0922, compared with 0.0829 across the
full period. This difference reflects the connections observed during
the selected period.

Observation bounds change the measurement period without deleting the
original spells:
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) still
returns them. Positive-duration spells contribute their intersection
with the observation window, and instantaneous events on either
observation boundary are retained.

For interrupted observation, supply `observation_spells` with the start
and end of each observed period. Overlapping or adjacent periods are
merged. `what = "observations"` extracts the resulting calendar.

``` r

gapped <- dynet(
  school_contacts,
  observation_spells = data.frame(start = c(0, 12), end = c(8, 21))
)
as.data.frame(gapped, what = "observations")
#>   observation start end duration instant
#> 1           1     0   8        8   FALSE
#> 2           2    12  21        9   FALSE
```

``` r

summary(gapped)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices           14
#> 4            edge spells          240
#> 5         distinct pairs          110
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to           21
#> 9                   span           21
#> 10             bin width            1
#> 11             time bins           17
#> 12 mean snapshot density       0.0824
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         none
```

The two periods contain eight and nine observed days. The measurement
grid restarts within each period, yielding seventeen bins and none
during the four-day gap. Exposure calculations use the seventeen
observed days, and events within the gap are excluded from measurements.

[`set_observations()`](https://pak.dynasite.org/Dynet/reference/set_observations.md)
replaces the observation calendar after construction.
[`clear_observations()`](https://pak.dynasite.org/Dynet/reference/clear_observations.md)
restores continuous observation from the earliest raw onset to the
latest raw termination.

``` r

narrowed <- set_observations(school, start = 2, end = 10)
as.data.frame(narrowed, what = "observations")
#>   observation start end duration instant
#> 1           1     2  10        8   FALSE
```

``` r

continuous <- clear_observations(gapped)
as.data.frame(continuous, what = "observations")
#>   observation start   end duration instant
#> 1           1     0 21.52    21.52   FALSE
```

## Vertex activity spells

Observation periods describe when data collection occurred. Vertex
activity spells describe when individual vertices were eligible to
participate, for example after enrolment or before departure. This
distinction separates an eligible participant with no connections from a
participant who was absent.

Supply `vertex_spells` as a table containing `node`, `start`, and `end`.
A vertex without an explicit activity declaration is treated as eligible
throughout observation.

``` r

arrivals <- data.frame(
  node  = c("Ana", "Ben"),
  start = c(0, 7),
  end   = c(21.52, 21.52)
)
scheduled <- dynet(school_contacts, vertex_spells = arrivals)
as.data.frame(scheduled, what = "vertex_spells")
#>   vertex_spell node start   end duration instant session onset_censored
#> 1            1  Ana     0 21.52    21.52   FALSE    <NA>          FALSE
#> 2            2  Ben     7 21.52    14.52   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE
```

Ben is declared eligible from day 7. His degree is `NA` in earlier bins,
rather than zero. The following calls compare degree with and without
this declaration.

``` r

school_degree <- centrality_series(school, measure = "degree")
head(school_degree, 4)
#> # Degree (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#> # first 4 of 308 rows
#>  time node measure value
#>     0  Ana  degree     1
#>     0  Ben  degree     1
#>     0 Cara  degree     1
#>     0  Dan  degree     1
```

``` r

scheduled_degree <- centrality_series(scheduled, measure = "degree")
head(scheduled_degree, 4)
#> # Degree (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#> # first 4 of 308 rows
#>  time node measure value
#>     0  Ana  degree     1
#>     0  Ben  degree    NA
#>     0 Cara  degree     1
#>     0  Dan  degree     1
```

[`summary()`](https://rdrr.io/r/base/summary.html) excludes missing
values when summarising the trajectories, so periods before declared
arrival no longer contribute to the mean.

``` r

school_degree_summary <- summary(school_degree)
head(school_degree_summary, 3)
#>   node measure  n     mean       sd min max peak_time
#> 1  Ana  degree 22 2.181818 2.015095   0   7         6
#> 2  Ben  degree 22 2.000000 1.234427   0   4         4
#> 3 Cara  degree 22 2.227273 1.342770   0   5         4
```

``` r

scheduled_degree_summary <- summary(scheduled_degree)
head(scheduled_degree_summary, 3)
#>   node measure  n     mean       sd min max peak_time
#> 1  Ana  degree 22 2.181818 2.015095   0   7         6
#> 2  Ben  degree 15 2.133333 1.125463   0   4        11
#> 3 Cara  degree 22 2.227273 1.342770   0   5         4
```

Ana’s mean degree remains 2.18 across 22 bins. Ben’s mean changes from
2.00 across 22 bins to 2.13 across fifteen eligible bins. His standard
deviation decreases from 1.23 to 1.13, and his peak moves from day 4 to
day 11. The eleven spells recorded for Ben before day 7 remain in the
raw data but are excluded from the eligible measurement period. This
example illustrates the effect of an activity declaration; in an
analysis, declarations should reflect the study’s participation
criteria.

Use
[`set_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/set_vertex_spells.md)
to replace declared activity and
[`add_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/add_vertex_spells.md)
to add periods of activity.

``` r

activity <- set_vertex_spells(school, arrivals)
extended <- add_vertex_spells(activity,
                              data.frame(node = "Cara", start = 3, end = 12))
as.data.frame(extended, what = "vertex_spells")
#>   vertex_spell node start   end duration instant session onset_censored
#> 1            1  Ana     0 21.52    21.52   FALSE    <NA>          FALSE
#> 2            2  Ben     7 21.52    14.52   FALSE    <NA>          FALSE
#> 3            3 Cara     3 12.00     9.00   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE
#> 3             FALSE
```

## Editing a network

Editing functions return a new network and leave their input unchanged.
They update the relational spells and associated network representation
together. Use these functions for temporal edits so that timing and
network structure remain consistent.

[`add_nodes()`](https://pak.dynasite.org/Dynet/reference/add_nodes.md)
adds vertices and attributes.
[`add_ties()`](https://pak.dynasite.org/Dynet/reference/add_ties.md)
adds relational spells whose endpoints already exist in the vertex set.

``` r

step1 <- add_nodes(school, data.frame(name = "Nova", role = "exchange"))
step2 <- add_ties(step1, data.frame(
  from = "Ana", to = "Nova", start = 4, end = 6
))
summary(step2)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices           15
#> 4            edge spells          241
#> 5         distinct pairs          111
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to        21.52
#> 9                   span        21.52
#> 10             bin width            1
#> 11             time bins           22
#> 12 mean snapshot density       0.0723
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         role
```

The edited network contains fifteen vertices, 241 spells, and 111
distinct pairs. Original vertices have `NA` for the newly introduced
`role` attribute. Mean snapshot density decreases from 0.0829 to 0.0723
despite the added connection: the additional vertex increases the number
of possible ordered pairs from 182 to 210.

The original network remains unchanged.

``` r

summary(school)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices           14
#> 4            edge spells          240
#> 5         distinct pairs          110
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to        21.52
#> 9                   span        21.52
#> 10             bin width            1
#> 11             time bins           22
#> 12 mean snapshot density       0.0829
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         none
```

[`remove_ties()`](https://pak.dynasite.org/Dynet/reference/remove_ties.md)
selects spells by their endpoints and onset, while
[`rename_nodes()`](https://pak.dynasite.org/Dynet/reference/rename_nodes.md)
updates vertex names using a mapping from old to new names.

``` r

step3 <- remove_ties(step2, from = "Ana", to = "Nova", start = 4)
summary(step3)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices           15
#> 4            edge spells          240
#> 5         distinct pairs          110
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to        21.52
#> 9                   span        21.52
#> 10             bin width            1
#> 11             time bins           22
#> 12 mean snapshot density       0.0719
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         role
```

``` r

renamed <- rename_nodes(step2, c(Nova = "Nova B."))
renamed_nodes <- as.data.frame(renamed, what = "nodes")
tail(renamed_nodes, 3)
#>       name     role
#> 13    Mira     <NA>
#> 14    Nils     <NA>
#> 15 Nova B. exchange
```

Removing the added spell restores the original 240 spells and 110
connected pairs, but Nova remains as an isolated vertex. Mean density is
therefore 0.0719, using the enlarged denominator of 210 possible pairs.

[`induce_subgraph()`](https://pak.dynasite.org/Dynet/reference/induce_subgraph.md)
restricts the network to selected vertices or spells. `nodes` accepts
vertex names, and `ties` can specify a condition over the spell table.

``` r

five <- induce_subgraph(school, nodes = c("Ana", "Ben", "Cara", "Dan", "Eve"))
summary(five)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices            5
#> 4            edge spells           18
#> 5         distinct pairs           11
#> 6              time unit         step
#> 7          observed from         3.17
#> 8            observed to        21.33
#> 9                   span        18.16
#> 10             bin width            1
#> 11             time bins           19
#> 12 mean snapshot density       0.0684
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         none
```

The five selected students share eighteen spells on eleven of twenty
possible ordered pairs. Without explicit observation bounds, the
subgraph’s observation period follows its own spell boundaries, here
days 3.17–21.33. Declare `observation_start` and `observation_end` when
the original study period should be retained.

## Descriptive measures

Dynet provides graph-level measures describing the network as a whole
and vertex-level measures describing individual positions. For
window-based calculations, spells active within each window form a
snapshot on which the selected measures are computed. Graph-level
trajectories are obtained with
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md);
vertex centrality trajectories use
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md).

The following call requests three graph-level measures in a tidy result
identified by `time` and `measure`.

``` r

basics <- metrics(school, measure = c("density", "edges", "active_nodes"))
head(basics, 6)
#> # Graph structure (graph-level)
#> # 22 time points, 1 per bin | time in step
#> # measures: density, edges, active_nodes
#> # first 6 of 66 rows
#>  time      measure       value
#>     0      density  0.05494505
#>     0        edges 10.00000000
#>     0 active_nodes 13.00000000
#>     1      density  0.04395604
#>     1        edges  8.00000000
#>     1 active_nodes  8.00000000
```

`edges` counts distinct connected ordered pairs, `density` divides that
count by the possible pairs, and `active_nodes` counts vertices with at
least one connection. On day 0, ten connections involve thirteen
students, giving density 0.055. On day 1, eight connections involve
eight students, giving density 0.044.

[`summary()`](https://rdrr.io/r/base/summary.html) reports the mean,
standard deviation, range, and peak time for each measure.

``` r

six <- metrics(school, measure = c("density", "edges", "active_nodes",
                                   "components", "transitivity",
                                   "reciprocity"))
summary(six)
#>        measure  n        mean         sd        min        max peak_time
#> 1 active_nodes 22 12.13636364 2.07698166 7.00000000 14.0000000         5
#> 2   components 22  3.59090909 2.38365647 1.00000000  9.0000000        21
#> 3      density 22  0.08291708 0.03929021 0.03296703  0.1648352        14
#> 4        edges 22 15.09090909 7.15081807 6.00000000 30.0000000        14
#> 5  reciprocity 22  0.14503815 0.13886108 0.00000000  0.4666667        14
#> 6 transitivity 22  0.11496262 0.12515367 0.00000000  0.4000000        11
```

Across 22 bins, mean density is 0.083 and reaches 0.165 on day 14, when
thirty pairs are connected. An average of 12.1 students have a
connection within a daily bin, with a minimum of seven.

`components` counts weakly connected components, ignoring direction and
including isolated vertices. It averages 3.6 and equals 1 on day 14. Its
maximum of nine occurs in the final partial bin, when six connections
leave seven students isolated.

`reciprocity` is the proportion of directed connections $`i \to j`$ for
which $`j \to i`$ is also present in the window. It averages 0.145 and
reaches 0.467 on day 14. `transitivity` is the proportion of two-paths
$`i \to j \to k`$ closed by $`i \to k`$, following the weak convention
of [`sna::gtrans()`](https://rdrr.io/pkg/sna/man/gtrans.html). It
averages 0.115 and peaks at 0.4 on day 11. Both measures describe
snapshot structure; they do not establish the temporal order of the
constituent interactions.

`step` specifies the interval between measurements, while `window`
specifies the duration covered from each measurement time. Equal values
produce non-overlapping windows. A larger `window` produces overlapping,
rolling measurements.

``` r

rolling <- metrics(school, measure = "density", step = 1, window = 7)
head(rolling, 4)
#> # Density (graph-level)
#> # 22 time points, step 1, window 7 (rolling) | time in step
#> # first 4 of 22 rows
#>  time measure     value
#>     0 density 0.3241758
#>     1 density 0.3461538
#>     2 density 0.3571429
#>     3 density 0.3791209
```

The first seven-day window contains 59 connected pairs, giving density
0.324, compared with ten pairs and density 0.055 in the first day alone.
Wider windows combine more relationships while providing less detail
about changes within each interval.

``` r

school_density <- metrics(school, measure = "density")
plot(school_density)
```

![](building-networks_files/figure-html/density-plot-1.png)

Snapshot measures count a connected pair once within a window regardless
of how long or how often it is connected. `temporal_density` instead
measures the occupied proportion of eligible pair-time.
`onset_intensity` divides the number of spell onsets by eligible
pair-time, giving a rate of formation per unit of relational
opportunity. For this fixed population, eligible pair-time is $`n(n-1)`$
multiplied by observed duration.

``` r

integrated <- metrics(school, measure = c("temporal_density", "onset_intensity"),
                      step = 7, window = 7)
integrated
#> # Graph structure (graph-level)
#> # 4 time points, 7 per bin | time in step
#> # measures: temporal_density, onset_intensity
#>  time          measure      value
#>     0 temporal_density 0.02428571
#>     0  onset_intensity 0.06043956
#>     7 temporal_density 0.03860283
#>     7  onset_intensity 0.08398744
#>    14 temporal_density 0.02352433
#>    14  onset_intensity 0.04395604
#>    21 temporal_density 0.01806847
#>    21  onset_intensity 0.00000000
```

Each complete week contains $`182 \times 7 = 1274`$ eligible pair-days.
Onset intensities of 0.0604, 0.0840, and 0.0440 correspond to 77, 107,
and 56 spell onsets, respectively. The final partial bin contains no
onsets.

Temporal density is highest in the second week at 0.0386, corresponding
to 49.2 occupied pair-days. It decreases to 0.0181 in the final partial
bin. These values account for connection duration, whereas snapshot
density records whether a connection occurred at any point in a bin.

[`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
lists the connections contributing to each snapshot. Supplying `at`
selects a measurement time; omitting it returns the measurement grid.

``` r

at_five <- snapshots(school, at = 5)
at_five
#> # Snapshot edges | 1 bin | 16 tie rows | time in step
#>    time from   to weight n_spells
#> 1     5 Kira  Leo      1        1
#> 2     5 Kira Gita      1        1
#> 3     5  Leo Cara      1        1
#> 4     5  Leo Finn      1        1
#> 5     5 Mira  Ana      1        1
#> 6     5 Nils  Ben      1        1
#> 7     5 Nils  Eve      1        1
#> 8     5  Ben  Eve      1        1
#> 9     5  Ben Finn      1        1
#> 10    5 Cara Kira      1        1
#> # 6 more rows. summary() counts them by bin.
```

At day 5, the result contains sixteen connected pairs, matching the
`edges` measure for that bin. Each pair has a weight and a count of
contributing spells.

[`events()`](https://pak.dynasite.org/Dynet/reference/events.md) counts
spell onsets and terminations within each bin.

``` r

changes <- events(school)
head(changes, 6)
#> # Edge dynamics (graph-level)
#> # 22 time points, 1 per bin | time in step
#> # measures: formation, dissolution
#> # first 6 of 44 rows
#>  time     measure value
#>     0   formation    11
#>     0 dissolution     7
#>     1   formation     4
#>     1 dissolution     6
#>     2   formation     8
#>     2 dissolution     6
```

The first bin contains eleven onsets and seven terminations; the second
contains four onsets and six terminations. These are spell counts, which
may include repeated relationships between the same endpoints.

[`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md)
summarises the length of relational spells. By default, it returns the
number of spells (`events`), summed duration (`total`), and mean
duration (`mean`) for each ordered pair. `unit` selects pair-level
histories (`"pair"`), individual relational spells (`"spell"`), vertex
activity (`"vertex_activity"` or `"vertex_spell"`), or spells incident
to vertices (`"node_ties"`).

``` r

tie_durations <- durations(school)
head(tie_durations, 6)
#> # Relationship duration (edge-level)
#> # time in step
#> # first 6 of 330 rows
#> # durations in step
#>  from    to measure value
#>   Ana  Cara  events     1
#>   Ana   Dan  events     3
#>   Ana  Gita  events     5
#>   Ana  Iris  events     1
#>   Ana Jonas  events     4
#>   Ana  Kira  events     1
```

Ana contacted Gita five times and Jonas four times, and Cara, Iris, and
Kira once each. The result contains three measures for each of 110
pairs, giving 330 observations.

``` r

spell_durations <- durations(school, unit = "spell")
head(spell_durations, 4)
#> # Relationship duration (edge-level)
#> # time in step
#> # first 4 of 240 rows
#> # durations in step
#>  from   to raw_spell  measure value
#>   Ana Cara        71 duration  0.10
#>   Ana  Dan       143 duration  0.32
#>   Ana  Dan       168 duration  0.51
#>   Ana  Dan       228 duration  0.19
```

With `unit = "spell"`, the result describes the 240 individual spells.
Spell identifiers refer to the constructed spell table. Ana’s three
contacts with Dan lasted 0.32, 0.51, and 0.19 days.

``` r

node_durations <- durations(school, unit = "node_ties", mode = "all")
head(node_durations, 4)
#> # Incident tie duration (node-level)
#> # 14 vertices | mode all | time in step
#> # first 4 of 28 rows
#> # durations in step
#>  node measure value
#>   Ana  events    36
#>   Ben  events    34
#>  Cara  events    35
#>   Dan  events    35
```

With `unit = "node_ties"` and `mode = "all"`, `events` counts spells
incident to each vertex in either direction. Ana participates in 36
spells and Ben in 34.

## Collapsing to a static network

[`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md)
aggregates a selected observation period into a static weighted network.
`start` and `end` delimit that period. The result contains connected
pairs and their available weight summaries.

``` r

flat <- collapse_network(school, start = 0, end = 7)
flat
#> # Collapsed temporal network | 14 vertices | 59 edges | weight: binary
#> # 0 to 7 step
#>  from    to binary union_duration total_duration duration_fraction spell_count
#>   Ana  Cara      1           0.10           0.10        0.01428571           1
#>   Ana  Gita      1           0.33           0.33        0.04714286           1
#>   Ana Jonas      1           1.44           1.44        0.20571429           3
#>   Ana  Mira      1           0.41           0.41        0.05857143           1
#>   Ben   Eve      1           1.58           1.58        0.22571429           2
#>   Ben  Finn      1           0.23           0.23        0.03285714           1
#>  weight_sum weighted_duration latest_weight first last activity.duration
#>           1              0.10             1  6.67 6.77              0.10
#>           1              0.33             1  6.57 6.90              0.33
#>           3              1.44             1  2.12 7.00              1.44
#>           1              0.41             1  6.36 6.77              0.41
#>           2              1.58             1  3.61 6.24              1.58
#>           1              0.23             1  4.91 5.14              0.23
#>  activity.count
#>               1
#>               1
#>               3
#>               1
#>               2
#>               1
```

The first week contains 59 connected pairs. For each pair, the result
records binary presence (`binary`), duration with at least one active
spell (`union_duration`), summed spell duration (`total_duration`), and
the proportion of observed time connected (`duration_fraction`). It also
records spell counts, weight summaries, and first and last contact
times.

Ana and Jonas have three spells within the first week, totalling 1.44
days, or approximately 21% of the week. Their first and last observed
boundaries are days 2.12 and 7.00. Union and total duration coincide
because their spells do not overlap.

Use `weight` to select the summary used as the static edge weight.

``` r

first_week <- collapse_network(school, start = 0, end = 7,
                               weight = "union_duration")
first_week
#> # Collapsed temporal network | 14 vertices | 59 edges | weight: union_duration
#> # 0 to 7 step
#>  from    to binary union_duration total_duration duration_fraction spell_count
#>   Ana  Cara      1           0.10           0.10        0.01428571           1
#>   Ana  Gita      1           0.33           0.33        0.04714286           1
#>   Ana Jonas      1           1.44           1.44        0.20571429           3
#>   Ana  Mira      1           0.41           0.41        0.05857143           1
#>   Ben   Eve      1           1.58           1.58        0.22571429           2
#>   Ben  Finn      1           0.23           0.23        0.03285714           1
#>  weight_sum weighted_duration latest_weight first last activity.duration
#>           1              0.10             1  6.67 6.77              0.10
#>           1              0.33             1  6.57 6.90              0.33
#>           3              1.44             1  2.12 7.00              1.44
#>           1              0.41             1  6.36 6.77              0.41
#>           2              1.58             1  3.61 6.24              1.58
#>           1              0.23             1  4.91 5.14              0.23
#>  activity.count
#>               1
#>               1
#>               3
#>               1
#>               2
#>               1
```

The collapsed network supports static analyses such as layouts and
community detection. Its aggregate summaries do not retain the complete
timing of individual spells, so time-respecting paths must be examined
using the temporal network.

## References

Holme, P., & Saramäki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97–125.

Kempe, D., Kleinberg, J., & Kumar, A. (2002). Connectivity and inference
problems for temporal networks. *Journal of Computer and System
Sciences*, 64(4), 820–842.

Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis
to understand and improve collaborative learning. In *Proceedings of the
Tenth International Conference on Learning Analytics & Knowledge*
(pp. 314–319). ACM.
