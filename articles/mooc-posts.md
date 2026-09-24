# The MOOC forum data

In this article we describe the bundled MOOC forum data, `mooc_posts`
and `mooc_people`, build the threaded network from them, and read its
size, its activity over time, the degree of its participants and the
mixing between experience levels. The same data carry the case study in
[`vignette("ch17-temporal-networks")`](https://pak.dynasite.org/Dynet/articles/ch17-temporal-networks.md).

## The log

Each row of `mooc_posts` is one post: the participant who wrote it, the
participant it answers, the time it was written and the discussion it
belongs to.

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
nrow(mooc_posts)
#> [1] 2529
```

The log holds 2,529 posts. The timestamps are date-times and the
discussion titles are the thread identifiers.

`mooc_people` has one row per participant with the self-reported
experience level, coded 1 for expert, 2 for student and 3 for teacher,
and its label in `expert_level`, which serves as the mixing attribute.

``` r

head(mooc_people)
#>   name experience expert_level
#> 1    1          1       Expert
#> 2    2          1       Expert
#> 3    3          2      Student
#> 4    4          2      Student
#> 5    5          3      Teacher
#> 6    6          1       Expert
nrow(mooc_people)
#> [1] 445
```

There are 445 participants.

## Building the network

To build the network, we call
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) with the
log, `from` and `to` for the endpoint columns, `time` for the timestamp
and `thread` for the discussion. Naming `thread` selects the threaded
format: each tie starts at its post and ends at the last post of the
same discussion, so a late reply extends every earlier tie in its
thread. Printing the network gives its format, its size and the first
spells.

``` r

dn <- dynet(mooc_posts, from = "sender", to = "receiver",
            time = "timestamp", thread = "discussion")
dn
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 442 vertices | 2443 edge spells | 1936 distinct pairs
#> # observed from 0 to 72.01111 days, binned every 1
#> 
#>  from  to      start      end duration weight
#>   360 444 0.00000000 69.47778 69.47778      1
#>   356 444 0.09236111 69.47778 69.38542      1
#>   356 444 0.09375000 51.93889 51.84514      1
#>   344 444 0.09930556 69.47778 69.37847      1
#>   392 444 0.11180556 69.47778 69.36597      1
#>   219 444 0.11388889 69.47778 69.36389      1
#>                                              thread
#>  Most important change for your school or district?
#>  Most important change for your school or district?
#>              DLT Resources—Comments and Suggestions
#>  Most important change for your school or district?
#>  Most important change for your school or district?
#>  Most important change for your school or district?
#> # 2437 more spells. summary() describes the network; plot() draws it.
```

The network has 442 vertices, 2,443 spells and 1,936 distinct ordered
pairs, observed over 73.03 days. Two differences from the log are worth
noting. The spell count is lower than the post count because a post that
answers its own author is a self-loop, and
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) drops
self-loops unless `loops = TRUE` is set. The vertex count is lower than
the participant count because three of the 445 participants in
`mooc_people` are never a sender or a receiver of a kept post, so they
are not part of the network the log implies. Times are read as
date-times and converted to days since the first post; the unit is
stated in the header of every result.

## Activity over time

Graph-level measures are computed on the grid shared by every measuring
function: `start` and `end` bound the period, `step` is the interval
between measurements and `window` the length of time each one covers. To
measure the network over the whole observed period as a single window,
we call
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md) with
`measure` set to `"density"` and `window` set to `"all"`.

``` r

density <- metrics(dn, measure = "density", window = "all")
density
#> # Density (graph-level)
#> # 1 time points, 72.01111 per bin | time in days
#>  time measure       value
#>     0 density 0.009932178
```

The density over the whole period is 0.0099: about one ordered pair in a
hundred was connected at some point during the course.

To count the ties active in each week, we call
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md) with
`measure` set to `"edges"`, and `step` and `window` both set to seven
days, so that the bins tile the period.

``` r

per_day <- metrics(dn, measure = "edges", step = 7, window = 7)
per_day
#> # Active edges (graph-level)
#> # 11 time points, 7 per bin | time in days
#>  time measure value
#>     0   edges   451
#>     7   edges   702
#>    14   edges   913
#>    21   edges   943
#>    28   edges  1013
#>    35   edges   924
#>    42   edges   981
#>    49   edges  1007
#>    56   edges   831
#>    63   edges   704
#>    70   edges   219
```

Each row is one week of the course. The first week holds 451 active
ties. The count rises to 1,013 in the week that begins on day 28, stays
above 900 until the week that begins on day 49, and falls to 231 in the
last bin, which begins on day 70 and covers only the final three days of
observation.

## Degree

To obtain the number of distinct contacts of every participant over the
whole period, we call
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
with `measure` set to `"degree"` and `window` set to `"all"`. The result
has one row per vertex. [`head()`](https://rdrr.io/r/utils/head.html)
prints the first ten rows, in the order of the vertex table.

``` r

degree <- dyn_centrality(dn, measure = "degree", window = "all")
head(degree, 10)
#> # Degree (node-level)
#> # 442 vertices | 1 time points, 72.01111 per bin | time in days
#> # first 10 of 442 rows
#>  time node measure value
#>     0    1  degree    40
#>     0    2  degree     7
#>     0    3  degree     6
#>     0    4  degree    13
#>     0    5  degree    22
#>     0    6  degree    24
#>     0    7  degree    48
#>     0    8  degree    19
#>     0    9  degree    10
#>     0   10  degree    16
```

Among the first ten participants, participant 7 has the highest degree
with 48 distinct contacts and participant 1 the next with 40;
participant 3 has 6.

## Mixing between experience levels

To count the ties within and between experience levels, the network must
carry the level as a vertex attribute. We build it again with `nodes`
set to `mooc_people`, so that the attribute travels with the network,
and call
[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) with
`attribute` set to `"experience"` and `window` set to `"all"`.

``` r

labelled <- dynet(mooc_posts, from = "sender", to = "receiver",
                  time = "timestamp", thread = "discussion",
                  nodes = mooc_people)
role_mixing <- mixing(labelled, attribute = "experience", window = "all")
role_mixing
#> # Mixing by experience (graph-level)
#> # 1 time points, 72.01111 per bin | time in days
#> # measures: 1 -> 1, 2 -> 1, 3 -> 1, 1 -> 2, 2 -> 2, 3 -> 2, 1 -> 3, 2 -> 3, 3 -> 3
#> # active binary-dyad counts between vertex groups per time bin
#>  time measure value from_group to_group
#>     0  1 -> 1    73          1        1
#>     0  2 -> 1   113          2        1
#>     0  3 -> 1   131          3        1
#>     0  1 -> 2   128          1        2
#>     0  2 -> 2   184          2        2
#>     0  3 -> 2   242          3        2
#>     0  1 -> 3   257          1        3
#>     0  2 -> 3   383          2        3
#>     0  3 -> 3   425          3        3
```

Each row is one ordered pair of levels, named by `from_group` and
`to_group`, and `value` is the number of ordered pairs of participants
with at least one active tie from the first level to the second.
Within-level counts are 73 for level 1, 184 for level 2 and 425 for
level 3. The three largest counts are the ties directed into level 3,
the teachers: 257 from level 1, 383 from level 2 and 425 from level 3
itself.

## Cost

[`summary()`](https://rdrr.io/r/base/summary.html) on a network
describes it in one table and computes every graph-level statistic in
every daily bin of the observed period. On a network of this size that
is the one slow call; the single-measure calls used in this article,
each on a stated grid, are not. When only one quantity is wanted,
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md) with
that measure is the call to make.

## Source

The log is the chapter 17 data of *Learning Analytics Methods and
Tutorials* (Saqr, 2024), taken from the `6_snaMOOC` directory of the
book’s data repository at <https://github.com/lamethods/data>. The
bundled table keeps the four columns the chapter reads, `sender`,
`receiver`, `timestamp` and `discussion`, and drops the category
hierarchy and comment identifiers of the published file.
[`?mooc_posts`](https://pak.dynasite.org/Dynet/reference/mooc_posts.md)
documents the preparation.

## References

Saqr, M. (2024). Temporal network analysis: Introduction, methods and
analysis with R. In M. Saqr & S. López-Pernas (Eds.), *Learning
analytics methods and tutorials: A practical guide using R*. Springer.

Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis
to understand and improve collaborative learning. In *Proceedings of the
Tenth International Conference on Learning Analytics & Knowledge*
(pp. 314–319). ACM.
