# Case study: A MOOC discussion forum as a temporal network

In this vignette we analyse the discussion forum of a massive open
online course as a temporal network, in the order of the temporal
network chapter of *Learning Analytics Methods and Tutorials* (Saqr,
2024): the network as a whole, its structure over time, the position of
each participant, how far a post could travel, and how participants of
different experience levels addressed one another.

## Data

`mooc_posts` has one row per post: `sender` and `receiver` are the
participants, `timestamp` the moment of the post and `discussion` the
thread. `mooc_people` has one row per participant with the experience
code, 1 for expert, 2 for student and 3 for teacher, and its label in
`expert_level`, which serves later as the mixing attribute.

``` r

library(Dynet)
head(mooc_posts)
#>   sender receiver           timestamp
#> 1    360      444 2013-04-04 16:32:00
#> 2    356      444 2013-04-04 18:45:00
#> 3    356      444 2013-04-04 18:47:00
#> 4    344      444 2013-04-04 18:55:00
#> 5    392      444 2013-04-04 19:13:00
#> 6    219      444 2013-04-04 19:16:00
#>                                           discussion
#> 1 Most important change for your school or district?
#> 2 Most important change for your school or district?
#> 3             DLT Resources—Comments and Suggestions
#> 4 Most important change for your school or district?
#> 5 Most important change for your school or district?
#> 6 Most important change for your school or district?
head(mooc_people)
#>   name experience expert_level
#> 1    1          1       Expert
#> 2    2          1       Expert
#> 3    3          2      Student
#> 4    4          2      Student
#> 5    5          3      Teacher
#> 6    6          1       Expert
```

## The network

Following Saqr and Nouri (2020), a reply is taken to be active from the
moment it is posted until its thread falls silent. Two kinds of rows
carry no interaction: a post that answers its own author, which
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) drops by
default, and a thread that never received a second post, which
`min_thread_posts = 2` drops. To build the network, we call
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) with
`from` and `to` for the two participant columns, `time` for the
timestamp, `thread` for the thread column, which selects the threaded
rule, `nodes` for the participant table so that `expert_level` travels
with the network, and `time_unit = "days"`.

``` r

dn_full <- dynet(mooc_posts, from = "sender", to = "receiver",
                 time = "timestamp", thread = "discussion",
                 nodes = mooc_people, time_unit = "days",
                 min_thread_posts = 2)
#> Dropped 86 self-loop event(s). Use loops = TRUE to keep them.
#> Dropped 37 thread(s) with fewer than 2 post(s), 37 post(s) in all.
summary(dn_full)
#>                 property                    value
#> 1                 format                 threaded
#> 2               directed                      yes
#> 3               vertices                      441
#> 4            edge spells                     2406
#> 5         distinct pairs                     1907
#> 6              time unit                     days
#> 7          observed from                        0
#> 8            observed to                 72.01111
#> 9                   span                 72.01111
#> 10             bin width                        1
#> 11             time bins                       73
#> 12 mean snapshot density                   0.0035
#> 13      temporal density             not computed
#> 14              sessions                     none
#> 15     vertex attributes experience, expert_level
```

The 86 self-replies and the 37 single-post threads are reported and
dropped, leaving 2,406 posts in 299 threads. The network has 441
vertices and 2,406 spells on 1,907 distinct pairs, observed from day 0
to day 72.01 in 73 one-day bins. The mean snapshot density is 0.0035: on
an average day about one pair in three hundred is connected.

Most participants posted a few times. To restrict the analysis to the
participants with more than 20 ties, we call
[`induce_subgraph()`](https://pak.dynasite.org/Dynet/reference/induce_subgraph.md)
with a condition on the vertex table; a centrality named in the
condition is computed over the whole period.

``` r

dn <- induce_subgraph(dn_full, degree > 20)
dn
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 45 vertices | 686 edge spells | 428 distinct pairs
#> # observed from 0.1138889 to 72.01111 days, binned every 1
#> # vertex attributes: experience, expert_level
#> 
#>  from  to     start      end duration weight
#>   219 444 0.1138889 69.47778 69.36389      1
#>   310 444 0.1680556 68.38681 68.21875      1
#>    19 310 0.2784722 14.10486 13.82639      1
#>    19 444 0.2909722 69.47778 69.18681      1
#>    30 444 0.8791667 69.47778 68.59861      1
#>    30 444 0.8819444 68.38681 67.50486      1
#>                                                                     thread
#>                         Most important change for your school or district?
#>                                  Submitting Questions for the Expert Panel
#>  How important is teacher training in a digital learning transition phase?
#>                         Most important change for your school or district?
#>                         Most important change for your school or district?
#>                                  Submitting Questions for the Expert Panel
#> # 680 more spells. summary() describes the network; plot() draws it.
```

The active subnetwork has 45 vertices, 686 spells and 428 pairs,
observed from day 0.11 to day 72.01. The first spell shows the thread
rule at work: the reply from 219 to 444 posted on day 0.11 stays active
until day 69.48, because its thread received posts for that long.

## Visualisation

To draw the aggregate network, we call
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) with
`type = "network"`.

``` r

plot(dn, type = "network")
```

![](ch17-temporal-networks_files/figure-html/net-plot-1.png)

To draw the network in four one-day bins spaced across the period, with
a shared layout, we set `type` to `"snapshots"` and `panels` to 4.

``` r

plot(dn, type = "snapshots", panels = 4)
#> Drawing 4 of 72 bins, evenly spaced across the window.
```

![](ch17-temporal-networks_files/figure-html/snapshots-1.png)

To count what the first four weeks hold, we call
[`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
with a grid of four one-week windows beginning on day 1, and
[`summary()`](https://rdrr.io/r/base/summary.html) on the result. `ties`
is the number of distinct pairs active in the window, `nodes` the number
of participants with at least one active tie, and `weight` the number of
spells.

``` r

weekly <- snapshots(dn, start = 1, end = 22, step = 7, window = 7)
summary(weekly)
#>   time ties nodes weight
#> 1    1   58    29     75
#> 2    8   95    38    128
#> 3   15  137    41    193
#> 4   22  154    44    210
```

The week beginning on day 1 holds 58 pairs among 29 participants; the
week beginning on day 22 holds 154 pairs among 44 of the 45. The counts
grow because a reply stays active until its thread closes, so early ties
are still present in later windows.

To see when each participant was active, we set `type` to `"timeline"`
and `top` to the number of participants to show.

``` r

plot(dn, type = "timeline", top = 25)
```

![](ch17-temporal-networks_files/figure-html/timeline-1.png)

To count the ties that form and dissolve each day, we call
[`events()`](https://pak.dynasite.org/Dynet/reference/events.md) with
`measure` for the two counts and a grid of one-day bins.

``` r

turnover <- events(dn, measure = c("formation", "dissolution"),
                   start = 0, end = 72, step = 1, window = 1)
summary(turnover)
#>       measure  n    mean       sd min max peak_time
#> 1 dissolution 73 9.39726 15.96414   0  99        69
#> 2   formation 73 9.39726  8.60029   0  40        46
plot(turnover)
```

![](ch17-temporal-networks_files/figure-html/turnover-1.png)

On average 9.4 ties form and 9.4 dissolve per day; the means are equal
because every spell begins and ends inside the period. Formation peaks
at 40 on day 46. Dissolution peaks at 99 on day 69, when the threads
that had stayed open through the course fall silent together.

The proximity timeline places participants who interact near each other
and follows their positions through time. To draw it, we set `type` to
`"proximity"` and `slices` to the number of time slices.

``` r

plot(dn, type = "proximity", slices = 20)
```

![](ch17-temporal-networks_files/figure-html/proximity-1.png)

## Structure over time

Every measuring function takes `start`, `end`, `step` and `window`. To
measure density over a rolling week, we call
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md) with
`step = 1` and `window = 7`, so that each value covers the seven days
beginning at its time.

``` r

weekly_density <- metrics(dn, measure = "density",
                          start = 14, end = 60, step = 1, window = 7)
summary(weekly_density)
#>   measure  n      mean         sd        min       max peak_time
#> 1 density 47 0.1006233 0.02149729 0.06616162 0.1393939        45
plot(weekly_density)
```

![](ch17-temporal-networks_files/figure-html/density-1.png)

Over the 47 windows the weekly density averages 0.101 and ranges from
0.066 to 0.139, with the peak in the week beginning on day 45.

To obtain the density of the whole period, and the temporal density that
weights each pair by the share of the period during which it was live,
we set `window` to `"all"`.

``` r

scalars <- metrics(dn, measure = c("edges", "density", "temporal_density"),
                   window = "all")
scalars
#> # Graph structure (graph-level)
#> # 1 time points, 71.89722 per bin | time in days
#> # measures: edges, density, temporal_density
#>       time          measure        value
#>  0.1138889            edges 428.00000000
#>  0.1138889          density   0.21616162
#>  0.1138889 temporal_density   0.06348315
```

The 428 pairs give an aggregate density of 0.216. The temporal density
is 0.063, less than a third of it, because most pairs were live for only
part of the period.

Reciprocity is the share of ties that are returned. To obtain it per day
on the full network, we call
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md) with
`measure = "reciprocity"`.

``` r

reciprocity <- metrics(dn_full, measure = "reciprocity",
                       start = 1, end = 73, step = 1, window = 1)
summary(reciprocity)
#>       measure  n      mean         sd min       max peak_time
#> 1 reciprocity 73 0.1509793 0.04198243   0 0.2178218        47
plot(reciprocity)
```

![](ch17-temporal-networks_files/figure-html/recip-1.png)

Reciprocity averages 0.151 over the 73 days and peaks at 0.218 on day
47.

The dyad census classifies every pair as mutual, asymmetric or null
(Wasserman and Faust, 1994). To obtain it at each instant of the grid,
we name the three classes in `measure` and set `window` to 0.

``` r

dyad_census <- metrics(dn, measure = c("mutual", "asymmetric", "null"),
                       start = 0, end = 72, step = 1, window = 0)
summary(dyad_census)
#>      measure  n      mean       sd min max peak_time
#> 1 asymmetric 73  81.49315 37.31366   0 137        51
#> 2     mutual 73  20.97260 12.66225   0  46        48
#> 3       null 73 887.53425 47.64833 817 990         0
plot(dyad_census)
```

![](ch17-temporal-networks_files/figure-html/dyads-1.png)

The 45 vertices form 990 dyads, all null at the first instant. Over the
73 instants an average of 21.0 dyads are mutual and 81.5 asymmetric, and
the mutual count peaks at 46 on day 48.

Degree centralisation is 0 when every vertex has the same degree and 1
when one vertex holds every tie (Freeman, 1979). To obtain it per day,
we set `measure` to `"centralization_degree"`.

``` r

centralisation <- metrics(dn, measure = "centralization_degree",
                          start = 1, end = 73, step = 1, window = 1)
summary(centralisation)
#>                 measure  n      mean        sd min       max peak_time
#> 1 centralization_degree 73 0.3789387 0.1104169   0 0.5081924        31
plot(centralisation)
```

![](ch17-temporal-networks_files/figure-html/centralization-1.png)

Centralisation averages 0.379 and peaks at 0.508 on day 31, the day on
which one participant’s betweenness also peaks.

## Participants

To obtain degree in all three directions for every participant on every
day, we call
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
with `measure = "degree"` and `mode` for the directions, then
[`summary()`](https://rdrr.io/r/base/summary.html) with `by = "measure"`
for one row per measure.

``` r

degree_series <- dyn_centrality(dn, measure = "degree",
                                mode = c("all", "in", "out"),
                                start = 1, end = 73, step = 1, window = 1)
summary(degree_series, by = "measure")
#>      measure    n     mean       sd min max peak_time
#> 1     degree 3285 5.765601 7.273446   0  52        49
#> 2  degree_in 3285 2.882801 5.477055   0  35        50
#> 3 degree_out 3285 2.882801 2.706619   0  19        31
```

Mean degree is 5.77 per participant per day, with a maximum of 52 on day
49. In-degree and out-degree share the mean of 2.88, but in-degree is
far more dispersed: its maximum is 35 on day 50 against 19 for
out-degree on day 31. Replies concentrate on a few receivers more than
on a few senders.

To draw the trajectories of the ten most central participants, we call
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) with `top`.

``` r

degree <- dyn_centrality(dn, measure = "degree",
                         start = 1, end = 73, step = 1, window = 1)
plot(degree, top = 10)
```

![](ch17-temporal-networks_files/figure-html/degree-plot-1.png)

Closeness, betweenness and eigenvector centrality describe reach,
brokerage and connection to well-connected others (Freeman, 1979;
Bonacich, 1987). To obtain all three on the same grid, we name them in
`measure`.

``` r

other_centrality <- dyn_centrality(dn,
                                   measure = c("closeness", "betweenness",
                                               "eigenvector"),
                                   start = 1, end = 73, step = 1, window = 1)
summary(other_centrality, by = "measure")
#>       measure    n       mean         sd min      max peak_time
#> 1 betweenness 3285 34.5716895 98.4872310   0 974.0571        31
#> 2   closeness 3285  0.4221442  0.2069263   0   1.0000         1
#> 3 eigenvector 3285  0.2351984  0.2028102   0   1.0000         1
```

Betweenness averages 34.6 and peaks at 974.1 on day 31. Closeness
averages 0.42 and eigenvector centrality 0.24; both reach their bound of
1 on day 1.

``` r

betweenness <- dyn_centrality(dn, measure = "betweenness",
                              start = 1, end = 73, step = 1, window = 1)
plot(betweenness, top = 10)
```

![](ch17-temporal-networks_files/figure-html/betweenness-plot-1.png)

Aggregate centrality over the whole period is carried by the vertex
table. To obtain it, we call
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) with
`what = "nodes"` and `measure` for the centralities to annotate.

``` r

ranked <- as.data.frame(dn, what = "nodes",
                        measure = c("degree", "betweenness", "eigenvector"))
head(ranked)
#>   name experience expert_level degree betweenness eigenvector
#> 1    1          1       Expert     20   37.308745   0.4188396
#> 2    5          3      Teacher     10    4.222691   0.3152262
#> 3    6          1       Expert     13    4.759524   0.3337165
#> 4    7          2      Student     26   34.113923   0.5748078
#> 5   11          3      Teacher     47  180.530502   0.8963590
#> 6   13          2      Student     15   16.629447   0.4051050
```

Among the first six participants, 11, a teacher, has the highest
aggregate degree, 47, the highest betweenness, 180.5, and the highest
eigenvector centrality, 0.896.

## Reachability

A time-respecting path may only use ties in chronological order (Kempe,
Kleinberg and Kumar, 2002), so it shows how far, and how fast, something
posted by one participant could travel through the forum. To find the
earliest path from participant 444 to every other, we call
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) with
`from` for the source. `arrival_time` is the earliest moment a
participant can be reached, `latency` that moment minus the source’s
start, `n_hops` the number of ties on the earliest route and `n_paths`
the number of routes that arrive equally early.

``` r

forward <- paths(dn, from = "444", direction = "forward")
forward
#> # Time-respecting paths from '444', from t = 0.1138889
#> # reaches 44 of 44 other vertices | time in days
#>  node reachable arrival_time attained   latency n_hops n_paths
#>     1      TRUE     5.484028     TRUE  5.370139      2       1
#>     5      TRUE    33.213194     TRUE 33.099306      2       1
#>     6      TRUE    37.055556     TRUE 36.941667      2       1
#>     7      TRUE    11.863889     TRUE 11.750000      3       1
#>    11      TRUE    12.383333     TRUE 12.269444      1       1
#>    13      TRUE    26.195139     TRUE 26.081250      2       1
#>    15      TRUE     6.135417     TRUE  6.021528      5       1
#>    17      TRUE    20.250694     TRUE 20.136806      4       3
#>    19      TRUE     2.222222     TRUE  2.108333      1       1
#>    24      TRUE    21.067361     TRUE 20.953472      2       1
#>    26      TRUE    25.313889     TRUE 25.200000      2       1
#>    27      TRUE    21.071528     TRUE 20.957639      3       1
#> # 33 more rows. summary() aggregates them; plot() draws the tree.
summary(forward)
#>          property    value
#> 1          source      444
#> 2       direction  forward
#> 3       reachable       44
#> 4 reachable share        1
#> 5  median latency 17.63819
#> 6     max latency 50.87431
#> 7     median hops        2
#> 8        max hops        5
```

Participant 444 reaches all 44 others. Participant 19 is reached in one
hop after 2.11 days and participant 11 in one hop after 12.27 days;
participant 15 needs five hops but is reached after 6.02 days, earlier
than participant 11. The median latency is 17.6 days and the maximum
50.9; the median route has two hops and the longest five.

To draw the earliest routes as a tree, we call
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) on the result;
to draw them against time, we call
[`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
on the result and
[`plot_path_trajectories()`](https://pak.dynasite.org/Dynet/reference/plot_path_trajectories.md)
with `measure = "time"`.

``` r

plot(forward, base_size = 9)
```

![](ch17-temporal-networks_files/figure-html/path-plot-1.png)

``` r

tree <- path_trajectories(forward)
plot_path_trajectories(tree, measure = "time", base_size = 9)
```

![](ch17-temporal-networks_files/figure-html/trajectories-1.png)

## Mixing between experience levels

To count the ties within and between experience levels per day, we call
[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) with
`attribute` for the vertex attribute that defines the groups, then
[`summary()`](https://rdrr.io/r/base/summary.html) for one row per
ordered pair of levels. Each measure reads from the sender’s level to
the receiver’s (Newman, 2003).

``` r

mix <- mixing(dn, attribute = "expert_level",
              start = 1, end = 73, step = 1, window = 1)
summary(mix)
#>              measure  n      mean        sd min max peak_time
#> 1   Expert -> Expert 73  2.890411  3.138301   0   8        54
#> 2  Expert -> Student 73  5.849315  3.703119   0  14        50
#> 3  Expert -> Teacher 73 14.315068  6.220211   0  24        55
#> 4  Student -> Expert 73  4.315068  3.620454   0  12        50
#> 5 Student -> Student 73 10.000000  4.725816   0  22        50
#> 6 Student -> Teacher 73 33.493151 14.732922   0  56        50
#> 7  Teacher -> Expert 73  5.808219  3.984893   0  14        48
#> 8 Teacher -> Student 73 16.232877  8.280701   0  35        47
#> 9 Teacher -> Teacher 73 36.821918 15.738614   0  67        49
plot(mix)
```

![](ch17-temporal-networks_files/figure-html/mixing-1.png)

Teachers writing to teachers is the most common tie, 36.8 active ties
per day on average with a peak of 67, followed by students writing to
teachers at 33.5. Experts writing to experts is the rarest, at 2.9 per
day. Direction matters: ties from experts to teachers average 14.3 per
day, from teachers to experts 5.8.

## Interpretation

The forum is sparse on any given day and dense in aggregate: one pair in
three hundred is connected on an average day, one in five over the
course, and the gap between the temporal density of 0.063 and the
aggregate density of 0.216 says that most ties were live for only a
fraction of the period. Activity is concentrated on receivers rather
than senders, and on teachers: the most common exchange is between
teachers, students address teachers more than anyone else, and the most
central participant over the whole period is a teacher. Everything
posted by participant 444 could in principle reach every active
participant, but the median took more than two weeks and the longest
route seven weeks, so the forum spreads information slowly even though
it connects everyone.

## Limitations

A reply that stays active until its thread closes is a modelling choice;
a shorter tie life would give sparser windows and longer latencies. The
analysis of structure and centrality is restricted to the 45
participants with more than 20 ties, so it describes the active core,
not the course. Participants who wrote or received no surviving exchange
are absent, and the observation period is taken from the data rather
than the course calendar.

## References

Bonacich, P. (1987). Power and centrality: A family of measures.
*American Journal of Sociology*, 92(5), 1170–1182.

Freeman, L. C. (1979). Centrality in social networks: Conceptual
clarification. *Social Networks*, 1(3), 215–239.

Kempe, D., Kleinberg, J., & Kumar, A. (2002). Connectivity and inference
problems for temporal networks. *Journal of Computer and System
Sciences*, 64(4), 820–842.

Newman, M. E. J. (2003). Mixing patterns in networks. *Physical Review
E*, 67(2), 026126.

Saqr, M. (2024). Temporal network analysis: Introduction, methods and
analysis with R. In M. Saqr & S. López-Pernas (Eds.), *Learning
analytics methods and tutorials: A practical guide using R*. Springer.
<https://doi.org/10.1007/978-3-031-54464-4_17>

Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis
to understand and improve collaborative learning. In *Proceedings of the
Tenth International Conference on Learning Analytics & Knowledge*
(pp. 314–319). ACM.

Wasserman, S., & Faust, K. (1994). *Social network analysis: Methods and
applications*. Cambridge University Press.
