# The MOOC forum data

`mooc_posts` records 2,529 posts to the discussion forum of a massive
open online course, and `mooc_people` records the 445 participants who
wrote or received them. The two tables are the data behind chapter 17 of
*Learning Analytics Methods and Tutorials*, and they are the package’s
worked example of a **threaded** log: a forum post is not an interval
with a stated end, and it is not an instantaneous contact either. A post
stays relevant until its thread falls silent.

This article builds the network from those posts and reports what it
holds.

## The log

``` r

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
```

Each row is one post: who wrote it, who it replied to, when, and which
discussion it belongs to. There are 338 distinct discussions.

``` r

head(mooc_people)
#>   name experience
#> 1    1          1
#> 2    2          1
#> 3    3          2
#> 4    4          2
#> 5    5          3
#> 6    6          1
```

`experience` is the self-reported level the chapter recodes into expert,
student and teacher.

## Building the network

[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) reads the
log as threaded because `thread =` is named. An edge from a post stays
active until the last post in the same discussion, so a reply late in a
thread extends every earlier tie in it.

``` r

dn <- dynet(mooc_posts, from = "sender", to = "receiver",
            time = "timestamp", thread = "discussion")
dn
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 442 vertices | 2443 edge spells | 1936 distinct pairs
#> # observed from 0 to 73.02778 days, binned every 1
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

The network has 442 vertices and 2,443 spells. Three of the 445
participants in `mooc_people` never appear as a sender or a receiver, so
they are absent from the network the log implies.

Times are read as dates and converted to an offset in days from the
first post, which is what `time_unit` reports.

## What the forum looked like over time

[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md)
measures graph-level structure on the grid. Over the whole observed
period the network’s density is:

``` r

density <- metrics(dn, measure = "density", window = "all")
density
#> # Density (graph-level)
#> # 1 time points, 73.02778 per bin | time in days
#>  time measure       value
#>     0 density 0.009932178
```

Measured day by day instead, activity is concentrated rather than even:

``` r

per_day <- metrics(dn, measure = "edges", step = 7, window = 7)
per_day
#> # Active edges (graph-level)
#> # 11 time points, 7 per bin | time in days
#>  time measure value
#>     0   edges   451
#>     7   edges   702
#>    14   edges   913
#>    21   edges   945
#>    28   edges  1013
#>    35   edges   924
#>    42   edges   981
#>    49   edges  1007
#>    56   edges   831
#>    63   edges   715
#>    70   edges   231
```

Each row is one week of the course. The counts show where the forum was
busy and where it went quiet.

## Who was central

[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
measures each vertex on the same grid. Over the whole period, the ten
participants with the highest degree are:

``` r

degree <- dyn_centrality(dn, measure = "degree", window = "all")
head(degree, 10)
#> # Degree (node-level)
#> # 442 vertices | 1 time points, 73.02778 per bin | time in days
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

## Mixing between experience levels

`mooc_people` supplies the attribute the chapter mixes on. The network
is built with that table attached, and
[`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) then
reports how much tie activity ran within and between levels.

``` r

labelled <- dynet(mooc_posts, from = "sender", to = "receiver",
                  time = "timestamp", thread = "discussion",
                  nodes = mooc_people)
role_mixing <- mixing(labelled, attribute = "experience", window = "all")
role_mixing
#> # Mixing by experience (graph-level)
#> # 1 time points, 73.02778 per bin | time in days
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

Each row is an ordered pair of levels. `value` is the share of tie
activity running from the first group to the second, so the rows where
`from_group` equals `to_group` measure how much the forum kept
conversation inside an experience level.

## Cost

[`summary()`](https://rdrr.io/r/base/summary.html) on this network takes
about 28 seconds, because it measures every graph-level statistic on all
74 daily bins. [`print()`](https://rdrr.io/r/base/print.html) is
immediate, and a single measure on a stated grid — as used throughout
this article — costs a few hundredths of a second. Reach for
[`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md) with
the measure you want rather than
[`summary()`](https://rdrr.io/r/base/summary.html) when the network is
this size.

## Source

Kaliisa, R., Gudmundsdottir, G. B., & Jahn, T. (2022). The MOOC forum
data used in chapter 17 of *Learning Analytics Methods and Tutorials*.
The bundled tables are the anonymised sender, receiver, timestamp and
discussion columns of that log, with participant identifiers replaced by
integers.
