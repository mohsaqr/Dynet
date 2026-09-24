# The MOOC forum from the published files

In this article we build the MOOC forum network of
[`vignette("ch17-temporal-networks")`](https://pak.dynasite.org/Dynet/articles/ch17-temporal-networks.md)
from the two CSV files that chapter 17 of *Learning Analytics Methods
and Tutorials* (Saqr, 2024) publishes, rather than from the bundled
`mooc_posts` and `mooc_people`. The files are read and prepared with
`rio` and `dplyr`, as a reader following the chapter would, and the
network they give is identical to the vignette’s, so the analysis is not
repeated here.

## Data

The chapter reads an edge list with one row per post and a node list
with one row per participant. To read them, we call
[`rio::import()`](http://gesistsa.github.io/rio/reference/import.md) on
each URL;
[`janitor::clean_names()`](https://sfirke.github.io/janitor/reference/clean_names.html)
puts the edge list’s column names in snake case.

``` r

library(Dynet)
library(dplyr)
library(rio)
net_edges <- import("https://raw.githubusercontent.com/lamethods/data/main/6_snaMOOC/DLT1%20Edgelist.csv") |>
  janitor::clean_names()
net_nodes <- import("https://raw.githubusercontent.com/lamethods/data/main/6_snaMOOC/DLT1%20Nodes.csv")
head(net_edges)
#>   sender receiver    timestamp
#> 1    360      444 4/4/13 16:32
#> 2    356      444 4/4/13 18:45
#> 3    356      444 4/4/13 18:47
#> 4    344      444 4/4/13 18:55
#> 5    392      444 4/4/13 19:13
#> 6    219      444 4/4/13 19:16
#>                                     discussion_title discussion_category
#> 1 Most important change for your school or district?             Group N
#> 2 Most important change for your school or district?           Group D-L
#> 3             DLT Resources—Comments and Suggestions           Group D-L
#> 4 Most important change for your school or district?           Group O-T
#> 5 Most important change for your school or district?           Group U-Z
#> 6 Most important change for your school or district?             Group M
#>               parent_category category_text
#> 1 Units 1-3 Discussion Groups              
#> 2 Units 1-3 Discussion Groups              
#> 3 Units 1-3 Discussion Groups              
#> 4 Units 1-3 Discussion Groups              
#> 5 Units 1-3 Discussion Groups              
#> 6 Units 1-3 Discussion Groups              
#>                                                                    discussion_identifier
#> 1   Most important change for your school or district?Group NUnits 1-3 Discussion Groups
#> 2 Most important change for your school or district?Group D-LUnits 1-3 Discussion Groups
#> 3             DLT Resources—Comments and SuggestionsGroup D-LUnits 1-3 Discussion Groups
#> 4 Most important change for your school or district?Group O-TUnits 1-3 Discussion Groups
#> 5 Most important change for your school or district?Group U-ZUnits 1-3 Discussion Groups
#> 6   Most important change for your school or district?Group MUnits 1-3 Discussion Groups
#>   comment_id discussion_id
#> 1          2             2
#> 2          3             1
#> 3          4             3
#> 4          5             4
#> 5          6             5
#> 6          7             6
```

[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) matches
the node table to the log by a column named `name`, so the participant
identifier is renamed. The experience code is recoded into the three
labels the chapter mixes on, and the columns the analysis does not read
are dropped.

``` r

net_nodes <- net_nodes |>
  rename(name = UID) |>
  mutate(expert_level = as.character(factor(experience, levels = 1:3,
                                            labels = c("Expert", "Student",
                                                       "Teacher")))) |>
  select(name, experience, expert_level)
head(net_nodes)
#>   name experience expert_level
#> 1    1          1       Expert
#> 2    2          1       Expert
#> 3    3          2      Student
#> 4    4          2      Student
#> 5    5          3      Teacher
#> 6    6          1       Expert
```

## The network

Following Saqr and Nouri (2020), a reply is active from the moment it is
posted until its thread falls silent. To build the network, we call
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) with
`from` and `to` for the participant columns, `time` for the timestamp,
which is parsed from the chapter’s month/day/year strings, `thread` for
the discussion title, `nodes` for the participant table,
`time_unit = "days"`, and `min_thread_posts = 2` to drop threads that
never became an exchange. Self-replies are dropped by default.

``` r

dn_full <- dynet(net_edges, from = "sender", to = "receiver",
                 time = "timestamp", thread = "discussion_title",
                 nodes = net_nodes, time_unit = "days",
                 min_thread_posts = 2)
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

The network has 441 vertices and 2,406 spells on 1,907 pairs over 73
one-day bins, the same as the vignette’s. To restrict it to the
participants with more than 20 ties, we call
[`induce_subgraph()`](https://pak.dynasite.org/Dynet/reference/induce_subgraph.md)
with a condition on the vertex table.

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
#>  discussion_category                   parent_category category_text
#>              Group M       Units 1-3 Discussion Groups              
#>  Unit 1 Expert Panel Unit 1-3 Expert Panel Discussions              
#>            Group A-C       Units 1-3 Discussion Groups              
#>              Group M       Units 1-3 Discussion Groups              
#>              Group N       Units 1-3 Discussion Groups              
#>  Unit 1 Expert Panel Unit 1-3 Expert Panel Discussions              
#>                                                                                          discussion_identifier
#>                           Most important change for your school or district?Group MUnits 1-3 Discussion Groups
#>                  Submitting Questions for the Expert PanelUnit 1 Expert PanelUnit 1-3 Expert Panel Discussions
#>  How important is teacher training in a digital learning transition phase?Group A-CUnits 1-3 Discussion Groups
#>                           Most important change for your school or district?Group MUnits 1-3 Discussion Groups
#>                           Most important change for your school or district?Group NUnits 1-3 Discussion Groups
#>                  Submitting Questions for the Expert PanelUnit 1 Expert PanelUnit 1-3 Expert Panel Discussions
#>  comment_id discussion_id
#>           7             6
#>          13             8
#>          16             9
#>          18             6
#>          32             2
#>          33             8
#> # 680 more spells. summary() describes the network; plot() draws it.
```

The active subnetwork has 45 vertices, 686 spells and 428 pairs,
observed from day 0.11 to day 72.01. Every measure of
[`vignette("ch17-temporal-networks")`](https://pak.dynasite.org/Dynet/articles/ch17-temporal-networks.md)
applies to this object unchanged.

## References

Saqr, M. (2024). Temporal network analysis: Introduction, methods and
analysis with R. In M. Saqr & S. López-Pernas (Eds.), *Learning
analytics methods and tutorials: A practical guide using R*. Springer.
<https://doi.org/10.1007/978-3-031-54464-4_17>

Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis
to understand and improve collaborative learning. In *Proceedings of the
Tenth International Conference on Learning Analytics & Knowledge*
(pp. 314–319). ACM.
