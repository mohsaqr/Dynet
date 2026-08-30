# Building and inspecting a temporal network

``` r

library(Dynet)
```

A temporal network is a relational log plus a clock. Everything Dynet
measures depends on that clock being right, so this vignette is about
the first half of the work: getting a log into a `dynet` object,
declaring what the clock means, and reading back what you actually built
before you measure anything.

There is one constructor,
[`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md). It
covers the four shapes relational logs arrive in, and the shape is
inferred from the arguments you name.

## The four log formats

### Interval log: each row carries its own start and end

This is the richest shape. Duration is recorded, so two students who met
once at length are distinguishable from two who met briefly many times.
Face-to-face sensor data, class attendance with sign-in and sign-out,
tutoring sessions and collaboration episodes all arrive this way.

`school_contacts` is fourteen students over three weeks:

``` r

head(school_contacts, 4)
#>    from   to start  end
#> 1 Jonas  Dan  0.00 1.10
#> 2  Gita  Ana  0.14 0.98
#> 3   Leo Mira  0.15 0.42
#> 4   Leo Iris  0.15 0.96
```

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

No column names had to be spelled out. `from`, `to`, `start` and `end`
were matched from a table of aliases, case-insensitively and after
stripping punctuation, so `Sender`/`Receiver`, `source`/`target` and
`onset`/`terminus` also work untouched. A `duration` column is accepted
in place of `end`.

### Contact log: instantaneous events with no duration

A message, a click, a citation, a card swipe. There is a time and
nothing else; the tie exists at an instant and has zero length.
`forum_posts` can be read this way, because a post has a timestamp and
no end:

``` r

head(forum_posts, 3)
#>       sender   receiver           timestamp    thread
#> 1 student_14 student_05 2024-09-02 19:59:20 thread_47
#> 2 student_10 student_05 2024-09-03 13:24:23 thread_47
#> 3  teacher_A student_09 2024-09-03 16:31:58 thread_11
```

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

The timestamps are `POSIXct`, and Dynet converted them to elapsed time
in a unit it chose to suit the span — days, here, reported in the
header. Numeric times are left alone and the unit is reported as
`"step"`.

Every spell has `duration` zero. That is the honest reading of a contact
log, but it has a consequence worth knowing before you measure:
quantities that integrate occupied time over the clock are exactly zero
on point contacts, because points occupy no time.

``` r

summary(clicks)
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

`temporal density` is `0`, while `mean snapshot density` is not. The
snapshot measures ask whether a tie was present anywhere inside a bin;
the integrated measures ask how much of the bin it occupied. On
instantaneous data those are genuinely different questions with
genuinely different answers.

### Threaded log: an edge stays active until its thread falls silent

Forum, chat and email data have a timestamp and no end, but treating
them as points throws away the fact that a post which provoked a long
argument stayed relevant longer than one that fell flat. Dynet applies
the rule from Saqr and Nouri (2020): a post is active from the moment it
appears until the last post in the same thread. Name the `thread`
argument and you get that derivation.

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

Same 241 rows as the contact reading above, same 20 vertices, but the
spells now have length — and the network has an integrated density that
is not zero:

``` r

summary(forum)
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

### Co-presence log: actors sharing a group become connected

Two-mode attendance data. Students are not linked to each other in the
source at all, only to the seminars they turned up to; the ties have to
be projected. Name both `actor` and `group`:

``` r

head(seminar_attendance, 3)
#>   student seminar       date
#> 1     s12 week_01 2024-09-03
#> 2     s22 week_01 2024-09-03
#> 3     s23 week_01 2024-09-03
```

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

Every pair of students who shared a room becomes a spell, tagged with
the group that created it. Co-presence networks are always undirected —
`directed = TRUE` is silently overridden, because “A attended with B”
has no direction. Note again that `seminar_attendance` carries a `date`
and no end time, so each seminar contributes point contacts; give the
source a genuine start and end column if you know how long the meetings
ran.

### `format = "auto"`, and when to say it out loud

The default `format = "auto"` infers the shape from the arguments you
name and the columns present. Naming `thread` selects threaded; naming
`actor` and `group` selects co-presence; an end or duration column gives
interval; a bare time column gives contact.

The inference is deliberately driven by what you *name*, not by what
happens to be in the data. `forum_posts` has a `thread` column, but:

``` r

dynet(forum_posts)
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

That is a contact network, not a threaded one. Auto-detection will not
silently apply the thread-persistence rule on your behalf — it is a
modelling decision, so you have to ask for it. State `format` explicitly
whenever the same table could plausibly be read two ways, or when you
are building inside a function and want the shape pinned:

``` r

dynet(school_contacts, format = "interval")
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

## Inspecting what you built

[`summary()`](https://rdrr.io/r/base/summary.html) on a `dynet` returns
a tidy two-column description, one row per property. Read it before you
measure anything.

``` r

summary(school)
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices       14
#> 4            edge spells      240
#> 5         distinct pairs      110
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to    21.52
#> 9                   span    21.52
#> 10             bin width        1
#> 11             time bins       22
#> 12 mean snapshot density   0.0829
#> 13      temporal density   0.0285
#> 14              sessions     none
#> 15     vertex attributes     none
```

Row by row:

- **format** — which of the four readings was used. Check it matches
  what you intended.
- **directed** — whether `from -> to` is meaningful.
- **vertices** — the fixed vertex universe. Every result keeps these
  rows, so a vertex that never sends a tie still appears with a zero.
- **edge spells** — one per derived spell, which for interval input is
  one per source row.
- **distinct pairs** — how many different dyads those spells fall on.
  The gap between 240 spells and 110 pairs is repetition: these students
  met each other again and again.
- **time unit** — `step` for numeric input; `seconds` to `weeks` for
  calendar input, chosen to suit the span.
- **observed from / observed to / span** — the measurement calendar.
  Without an explicit declaration these are the first and last event
  times.
- **bin width** — the default measurement grid, set by the `interval`
  argument.
- **time bins** — how many bins of that width fit the observed period.
- **mean snapshot density** — averaged over the bins, the share of
  possible edges present *anywhere* inside each bin.
- **temporal density** — occupied pair-time divided by eligible
  pair-time over the whole history. This one integrates; it is not an
  average of the row above.
- **sessions** — how many session labels, if the network has any.
- **vertex attributes** — which node columns came along.

The spell table itself, and the vertex table, come back through
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html):

``` r

head(as.data.frame(school), 4)
#>    from   to start  end duration weight
#> 1 Jonas  Dan  0.00 1.10     1.10      1
#> 2  Gita  Ana  0.14 0.98     0.84      1
#> 3   Leo Mira  0.15 0.42     0.27      1
#> 4   Leo Iris  0.15 0.96     0.81      1
```

``` r

head(as.data.frame(forum, what = "nodes"), 4)
#>          name        role achievement
#> 1 facilitator Facilitator        <NA>
#> 2  student_01     Student      Middle
#> 3  student_02     Student         Low
#> 4  student_03     Student        High
```

`what` also takes `"bins"` for the measurement grid, `"network"` for the
aggregate edge list, `"observations"` for the observation calendar,
`"observed_edges"` for spells intersected with it, and `"vertex_spells"`
for declared vertex activity.

``` r

head(as.data.frame(school, what = "bins"), 4)
#>   bin lo hi time closed
#> 1   1  0  1    0  FALSE
#> 2   2  1  2    1  FALSE
#> 3   3  2  3    2  FALSE
#> 4   4  3  4    3  FALSE
```

``` r

head(as.data.frame(school, what = "network"), 4)
#>   from  to weight
#> 1 Cara Ana      1
#> 2  Dan Ana      2
#> 3 Gita Ana      3
#> 4 Hugo Ana      2
```

## Directedness, loops, weights, node attributes

These are all
[`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md)
arguments. A small hand-written log makes each one visible:

``` r

tiny <- data.frame(
  from  = c("A", "B", "A", "C", "A"),
  to    = c("B", "A", "C", "A", "A"),
  start = c(0, 1, 2, 3, 4),
  end   = c(2, 3, 5, 4, 6),
  posts = c(3, 1, 2, 5, 1)
)
```

`directed = FALSE` folds `A -> B` and `B -> A` onto one dyad, and
`weight` names a column of event multiplicity:

``` r

dynet(tiny, directed = FALSE, weight = "posts")
#> Dropped 1 self-loop event(s). Use loops = TRUE to keep them.
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

Five source rows became four spells and two distinct pairs. The fifth
row is a self-loop, `A -> A`, and self-loops are dropped by default with
a message — almost always what a relational log needs. Keep them if the
loop means something in your design:

``` r

dynet(tiny, loops = TRUE)
#> Keeping 1 self-loop event(s); they are excluded from degree.
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 3 vertices | 5 edge spells | 5 distinct pairs
#> # observed from 0 to 6 step, binned every 1
#> 
#>  from to start end duration weight
#>     A  B     0   2        2      1
#>     B  A     1   3        2      1
#>     A  C     2   5        3      1
#>     C  A     3   4        1      1
#>     A  A     4   6        2      1
```

`interval` sets the default bin width used by every measurement verb, in
the network’s own time unit:

``` r

summary(dynet(tiny, interval = 2))
#> Dropped 1 self-loop event(s). Use loops = TRUE to keep them.
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices        3
#> 4            edge spells        4
#> 5         distinct pairs        4
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to        5
#> 9                   span        5
#> 10             bin width        2
#> 11             time bins        3
#> 12 mean snapshot density   0.3333
#> 13      temporal density   0.2667
#> 14              sessions     none
#> 15     vertex attributes     none
```

Vertex attributes come in through `nodes`. The vertex key column is
auto-detected, and `groups` names one attribute to use as the vertex
partition — written into the places cograph looks for it, so
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
colours and groups by it without further argument.

``` r

roles <- dynet(forum_posts, thread = "thread",
               nodes = forum_people, groups = "role")
head(as.data.frame(roles, what = "nodes"), 4)
#>          name        role achievement      groups
#> 1 facilitator Facilitator        <NA> Facilitator
#> 2  student_01     Student      Middle     Student
#> 3  student_02     Student         Low     Student
#> 4  student_03     Student        High     Student
```

Those attributes are what
[`mixing()`](https://mohsaqr.github.io/Dynet/reference/mixing.md)
partitions on:

``` r

head(mixing(roles, attribute = "role"), 4)
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

## Sessions

A session is a wall in time. Terms, courses, class periods, hospital
admissions: periods that a time-respecting path should not be allowed to
walk across, even though the clock runs continuously through them. Name
a column with `session`.

`school_contacts` has no session column, so derive one — three weeks of
contact give three weekly sessions:

``` r

weekly <- transform(
  school_contacts,
  week = paste0("week_", floor(start / 7) + 1)
)
head(weekly, 3)
#>    from   to start  end   week
#> 1 Jonas  Dan  0.00 1.10 week_1
#> 2  Gita  Ana  0.14 0.98 week_1
#> 3   Leo Mira  0.15 0.42 week_1
```

``` r

sessioned <- dynet(weekly, session = "week")
summary(sessioned)
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices       14
#> 4            edge spells      240
#> 5         distinct pairs      110
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to    21.52
#> 9                   span    21.52
#> 10             bin width        1
#> 11             time bins       22
#> 12 mean snapshot density   0.0829
#> 13      temporal density   0.0285
#> 14              sessions        3
#> 15     vertex attributes     none
```

Every verb that takes time then takes a `sessions` argument with three
settings, and the choice changes the answer rather than the formatting.
Temporal paths show it most sharply:

``` r

summary(paths(sessioned, from = "Ana", sessions = "collapse"))
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

`"collapse"` ignores the labels entirely and treats the history as one
continuous stream. Ana reaches all thirteen other students, at a median
latency of 7.51 time steps.

``` r

summary(paths(sessioned, from = "Ana", sessions = "bounded"))
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

`"bounded"` keeps every path inside a single session. Ana still reaches
everyone, but she has to do it by routes that never cross a week
boundary, so the journeys get longer — median latency rises to 8.21 and
the longest journey grows from four hops to five.

``` r

summary(paths(sessioned, from = "Ana", sessions = "separate"))
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

`"separate"` reports each session on its own rows instead of pooling
them. Now the weeks are visibly different: within week 1 Ana reaches 6
of the other 13 students, within week 2 all 13, within week 3 only 5.

`"bounded"` is the default everywhere. On a network with no sessions
there is nothing to bound, so `"bounded"` and `"collapse"` give the same
answer and the default costs nothing when you have not declared any
sessions. `"separate"` is the exception: with no session column there is
nothing to report separately, and it raises an error rather than
silently pooling.

## Observation windows

The observed range defaults to the first and last event in the log. That
is a guess, and it is usually wrong: a study that ran for four weeks but
saw no contact in the last three days is not a study that ran for 25
days. Since the observed range is the denominator of every rate and the
horizon of every path, declare it when you know it.

``` r

bounded <- dynet(school_contacts, observation_start = 0, observation_end = 14)
summary(bounded)
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices       14
#> 4            edge spells      240
#> 5         distinct pairs      110
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to       14
#> 9                   span       14
#> 10             bin width        1
#> 11             time bins       14
#> 12 mean snapshot density   0.0922
#> 13      temporal density   0.0314
#> 14              sessions     none
#> 15     vertex attributes     none
```

The span is now 14 rather than 21.52, and both densities changed because
the exposure they divide by changed. This is an administrative limit,
not a filter: the raw spell boundaries are untouched, and
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) still
returns them exactly as supplied. Positive spells contribute their
half-open intersection with the window; a genuine point contact sitting
on either limit is kept.

For interrupted observation — a holiday, a sensor outage, a gap between
waves — give the observed periods directly. Overlapping and adjacent
spells are merged into canonical components.

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
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices       14
#> 4            edge spells      240
#> 5         distinct pairs      110
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to       21
#> 9                   span       21
#> 10             bin width        1
#> 11             time bins       17
#> 12 mean snapshot density   0.0824
#> 13      temporal density   0.0278
#> 14              sessions     none
#> 15     vertex attributes     none
```

Seventeen bins, not 21: the grid restarts inside each component and
never creates a bin that lies entirely in the gap. Exposure sums the
component durations rather than taking the hull, so events falling in
the gap are excluded from the denominator instead of quietly inflating
it.

The same calendar is editable after the fact, and
[`clear_observations()`](https://mohsaqr.github.io/Dynet/reference/clear_observations.md)
puts back the implicit continuous window:

``` r

as.data.frame(set_observations(school, start = 2, end = 10),
              what = "observations")
#>   observation start end duration instant
#> 1           1     2  10        8   FALSE
```

``` r

as.data.frame(clear_observations(gapped), what = "observations")
#>   observation start   end duration instant
#> 1           1     0 21.52    21.52   FALSE
```

## Vertex activity spells

Observation windows say when *the study* was running. Vertex spells say
when a *vertex* was eligible to have ties at all — a student who
enrolled late, a nurse on a rota, a user who deleted their account.
Supply a tidy table with `node`, `start` and `end`.

A vertex with no row in the table stays eligible at all times, so you
only declare the ones that change.

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

Ben becomes eligible at time 7. Every measurement now runs on the
eligible population rather than the fixed one. The fixed vertex universe
is unchanged and Ben keeps a row in every bin, but the bins before he
arrives report `NA` rather than a degree of zero — the difference
between “had no contacts” and “was not there to have any”:

``` r

head(as.data.frame(dyn_centrality(school, measure = "degree")), 4)
#>   time node measure value
#> 1    0  Ana  degree     1
#> 2    0  Ben  degree     1
#> 3    0 Cara  degree     1
#> 4    0  Dan  degree     1
```

``` r

head(as.data.frame(dyn_centrality(scheduled, measure = "degree")), 4)
#>   time node measure value
#> 1    0  Ana  degree     1
#> 2    0  Ben  degree    NA
#> 3    0 Cara  degree     1
#> 4    0  Dan  degree     1
```

That distinction moves the summaries, because the empty bins are no
longer averaged in as zeroes:

``` r

head(summary(dyn_centrality(school, measure = "degree")), 3)
#>   node measure  n     mean       sd min max peak_time
#> 1  Ana  degree 22 2.181818 2.015095   0   7         6
#> 2  Ben  degree 22 2.000000 1.234427   0   4         4
#> 3 Cara  degree 22 2.227273 1.342770   0   5         4
```

``` r

head(summary(dyn_centrality(scheduled, measure = "degree")), 3)
#>   node measure  n     mean       sd min max peak_time
#> 1  Ana  degree 22 2.181818 2.015095   0   7         6
#> 2  Ben  degree 15 2.133333 1.125463   0   4        11
#> 3 Cara  degree 22 2.227273 1.342770   0   5         4
```

Ana is untouched, at mean degree 2.182 either way. Ben’s mean rises from
2.000 to 2.133: the same contacts, divided by the fifteen bins in which
he was actually eligible rather than all twenty-two.

The same declaration is editable.
[`set_vertex_spells()`](https://mohsaqr.github.io/Dynet/reference/set_vertex_spells.md)
replaces the table,
[`add_vertex_spells()`](https://mohsaqr.github.io/Dynet/reference/add_vertex_spells.md)
adds to it:

``` r

activity <- set_vertex_spells(school, arrivals)
as.data.frame(add_vertex_spells(activity,
                                data.frame(node = "Cara",
                                           start = 3, end = 12)),
              what = "vertex_spells")
#>   vertex_spell node start   end duration instant session onset_censored
#> 1            1  Ana     0 21.52    21.52   FALSE    <NA>          FALSE
#> 2            2  Ben     7 21.52    14.52   FALSE    <NA>          FALSE
#> 3            3 Cara     3 12.00     9.00   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE
#> 3             FALSE
```

## Editing without breaking time

Every editing verb returns a **new** network. Nothing is modified in
place, so a chain of edits is a chain of objects and the source stays
exactly as it was. Each edit rebuilds the canonical spell identities and
the cograph projection together, which is why the temporal object must
be edited through these verbs rather than through cograph’s static
setters.

Add an isolate before you refer to it as a tie endpoint:

``` r

step1 <- add_nodes(school, data.frame(name = "Nova", role = "exchange"))
step2 <- add_ties(step1, data.frame(
  from = "Ana", to = "Nova", start = 4, end = 6
))
summary(step2)
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices       15
#> 4            edge spells      241
#> 5         distinct pairs      111
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to    21.52
#> 9                   span    21.52
#> 10             bin width        1
#> 11             time bins       22
#> 12 mean snapshot density   0.0723
#> 13      temporal density   0.0252
#> 14              sessions     none
#> 15     vertex attributes     role
```

Fifteen vertices, 241 spells, 111 distinct pairs, and a `role` attribute
that did not exist a moment ago. The original is untouched:

``` r

summary(school)
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices       14
#> 4            edge spells      240
#> 5         distinct pairs      110
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to    21.52
#> 9                   span    21.52
#> 10             bin width        1
#> 11             time bins       22
#> 12 mean snapshot density   0.0829
#> 13      temporal density   0.0285
#> 14              sessions     none
#> 15     vertex attributes     none
```

Removal addresses a tie by name and time, and renaming takes a named
vector of old-to-new:

``` r

summary(remove_ties(step2, from = "Ana", to = "Nova", start = 4))
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices       15
#> 4            edge spells      240
#> 5         distinct pairs      110
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to    21.52
#> 9                   span    21.52
#> 10             bin width        1
#> 11             time bins       22
#> 12 mean snapshot density   0.0719
#> 13      temporal density   0.0247
#> 14              sessions     none
#> 15     vertex attributes     role
```

``` r

tail(as.data.frame(rename_nodes(step2, c(Nova = "Nova B.")), what = "nodes"), 3)
#>       name     role
#> 13    Mira     <NA>
#> 14    Nils     <NA>
#> 15 Nova B. exchange
```

[`induce_subgraph()`](https://mohsaqr.github.io/Dynet/reference/induce_subgraph.md)
cuts a temporal subgraph by vertex or by an edge-level condition,
keeping the time structure of what survives:

``` r

summary(induce_subgraph(school, nodes = c("Ana", "Ben", "Cara", "Dan", "Eve")))
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices        5
#> 4            edge spells       18
#> 5         distinct pairs       11
#> 6              time unit     step
#> 7          observed from     3.17
#> 8            observed to    21.33
#> 9                   span    18.16
#> 10             bin width        1
#> 11             time bins       19
#> 12 mean snapshot density   0.0684
#> 13      temporal density   0.0193
#> 14              sessions     none
#> 15     vertex attributes     none
```

Note that the observed range narrowed too, from `0`–`21.52` to
`3.17`–`21.33`: these five students’ first contact with one another was
not on day zero.

## Basic summaries

With the network built and its calendar declared, the descriptive verbs
all follow the same shape — one call, named arguments, a tidy frame
back.

[`metrics()`](https://mohsaqr.github.io/Dynet/reference/metrics.md)
measures graph-level structure in each bin. Ask for several at once and
they arrive stacked with a `measure` column:

``` r

head(metrics(school, measure = c("density", "edges", "active_nodes")), 6)
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

[`summary()`](https://rdrr.io/r/base/summary.html) collapses a series to
one row per measure, with the time at which it peaked:

``` r

summary(metrics(school, measure = c("density", "edges", "active_nodes",
                                    "components", "transitivity",
                                    "reciprocity")))
#>        measure  n        mean         sd        min        max peak_time
#> 1 active_nodes 22 12.13636364 2.07698166 7.00000000 14.0000000         5
#> 2   components 22  3.59090909 2.38365647 1.00000000  9.0000000        21
#> 3      density 22  0.08291708 0.03929021 0.03296703  0.1648352        14
#> 4        edges 22 15.09090909 7.15081807 6.00000000 30.0000000        14
#> 5  reciprocity 22  0.14503815 0.13886108 0.00000000  0.4666667        14
#> 6 transitivity 22  0.11496262 0.12515367 0.00000000  0.4000000        11
```

`step` and `window` are separate arguments and that separation is the
point. `step` is how often you look; `window` is how much of the
timeline each look takes in. Equal values tile the period into disjoint
bins, which is the default; a larger window slides an overlapping one:

``` r

head(metrics(school, measure = "density", step = 1, window = 7), 4)
#> # Density (graph-level)
#> # 22 time points, step 1, window 7 (rolling) | time in step
#> # first 4 of 22 rows
#>  time measure     value
#>     0 density 0.3241758
#>     1 density 0.3461538
#>     2 density 0.3571429
#>     3 density 0.3791209
```

``` r

plot(metrics(school, measure = "density"))
```

![](building-networks_files/figure-html/unnamed-chunk-48-1.png)

The `temporal_density` and `onset_intensity` selectors are the
integrated counterparts — occupied pair-time and known spell starts per
unit of eligible pair-time, rather than a presence indicator:

``` r

metrics(school, measure = c("temporal_density", "onset_intensity"),
        step = 7, window = 7)
#> # Graph structure (graph-level)
#> # 4 time points, 7 per bin | time in step
#> # measures: temporal_density, onset_intensity
#>  time          measure       value
#>     0 temporal_density 0.024285714
#>     0  onset_intensity 0.060439560
#>     7 temporal_density 0.038602826
#>     7  onset_intensity 0.083987441
#>    14 temporal_density 0.023524333
#>    14  onset_intensity 0.043956044
#>    21 temporal_density 0.001342229
#>    21  onset_intensity 0.000000000
```

[`snapshots()`](https://mohsaqr.github.io/Dynet/reference/snapshots.md)
returns the edges themselves rather than a statistic — the network as it
stood, one row per edge per time point. Give `at` for a single instant,
or leave it out for the whole grid:

``` r

head(snapshots(school, at = 5), 5)
#> # Snapshot edges | 1 bin | 5 tie rows | time in step
#>   time from   to weight n_spells
#> 1    5 Kira  Leo      1        1
#> 2    5 Kira Gita      1        1
#> 3    5  Leo Cara      1        1
#> 4    5  Leo Finn      1        1
#> 5    5 Mira  Ana      1        1
```

[`events()`](https://mohsaqr.github.io/Dynet/reference/events.md) counts
what changed rather than what was present: how many ties formed and
dissolved in each bin.

``` r

head(events(school), 6)
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

[`durations()`](https://mohsaqr.github.io/Dynet/reference/durations.md)
summarises how long relationships lasted. `unit` decides what a duration
belongs to — `"pair"` for a dyad’s whole history, `"spell"` for the raw
episodes, `"vertex_activity"` and `"vertex_spell"` for vertex presence,
`"node_ties"` for incident tie time.

``` r

head(durations(school), 6)
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

``` r

head(durations(school, unit = "spell"), 4)
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

``` r

head(durations(school, unit = "node_ties", mode = "all"), 4)
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

## Collapsing to a static network

Sometimes the last step is a static picture — a figure, a handover to a
static-network tool, a sanity check.
[`collapse_network()`](https://mohsaqr.github.io/Dynet/reference/collapse_network.md)
flattens any range and returns a cograph network carrying every
weighting it can compute, so you choose the one you want by name rather
than recomputing it.

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

``` r

head(as.data.frame(collapse_network(school, start = 0, end = 7,
                                    weight = "union_duration")), 4)
#>   from    to binary union_duration total_duration duration_fraction spell_count
#> 1  Ana  Cara      1           0.10           0.10        0.01428571           1
#> 2  Ana  Gita      1           0.33           0.33        0.04714286           1
#> 3  Ana Jonas      1           1.44           1.44        0.20571429           3
#> 4  Ana  Mira      1           0.41           0.41        0.05857143           1
#>   weight_sum weighted_duration latest_weight first last activity.duration
#> 1          1              0.10             1  6.67 6.77              0.10
#> 2          1              0.33             1  6.57 6.90              0.33
#> 3          3              1.44             1  2.12 7.00              1.44
#> 4          1              0.41             1  6.36 6.77              0.41
#>   activity.count
#> 1              1
#> 2              1
#> 3              3
#> 4              1
```

`weight` selects which column drives the static edge weight: `"binary"`
for presence, `"union_duration"` for calendar time with at least one
spell, `"total_duration"` for the sum with repetition, `"spell_count"`,
`"weight_sum"`, `"duration_fraction"`, `"weighted_duration"` or
`"latest_weight"`. The result is a `cograph_network`, so
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
draws it directly.

Collapsing is the end of the analysis, not the start of it. Everything
the static picture cannot say — the order events happened in, how long
each tie lasted, whether a path could have run at all — is in the object
you built at the top of this vignette.

## References

Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97–125.

Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis
to understand and improve collaborative learning. *Proceedings of the
Tenth International Conference on Learning Analytics & Knowledge*,
314–319.
