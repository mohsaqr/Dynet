# The event graph of a temporal network

Builds the event graph: every spell becomes a vertex, and an arc joins
two events that share a vertex and follow one another in time there. A
directed path in it is a time-respecting chain of events, so questions
about temporal reachability, waiting times and cascades become questions
about an ordinary static directed acyclic graph. It needs no time grid.
The time-expanded graph of
[`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md)
is the other static representation; it has one vertex per vertex and
time slice instead.

## Usage

``` r
event_graph(
  dn,
  sessions = c("bounded", "collapse", "separate"),
  delta = Inf,
  adjacency = c("all", "next"),
  direction = c("respect", "ignore"),
  loops = FALSE,
  events = c("ties", "messages")
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- sessions:

  How to treat sessions: `"bounded"` (the default) and `"separate"`
  never join events across a session boundary, `"collapse"` ignores
  sessions. `"separate"` also reports a `session` column, and on a
  network built without a session column it raises `dynet_no_sessions`.

- delta:

  The longest admissible wait at the shared vertex, in the network's
  time unit: an arc requires the later event to start no more than
  `delta` after the earlier one ends. `Inf`, the default, admits any
  wait; zero admits none, since a wait is always positive. A single
  non-negative number, or `dynet_bad_input` is raised.

- adjacency:

  `"all"` (the default) joins an event to every admissible successor;
  `"next"` joins it only to the earliest admissible successors at each
  shared vertex (every successor starting at that earliest time). See
  Details for what each one preserves.

- direction:

  On a directed network, `"respect"` (the default) joins an event to a
  successor only through the earlier event's target and the later
  event's source, so an arc is a hop that could pass something along.
  `"ignore"` joins through any shared endpoint. An undirected network is
  read as `"ignore"` either way.

- loops:

  Whether self-loop spells take part. `FALSE`, the default, drops them
  before adjacency is computed; a kept self-loop is adjacent at its one
  vertex.

- events:

  `"ties"` (the default) makes every spell an event. `"messages"` merges
  the spells that share their source, start, end and session into one
  event, a message from one source to several targets, such as an email
  to several recipients or an action addressed to a whole group
  (`dynet(format = "broadcast")`). A message arrives at all its targets
  and leaves from its source, so a later event follows it when it leaves
  any one of the targets.

## Value

An object of class `dynet_event_graph`. Take its tables with
`as.data.frame(x)` for the events, one row per spell (or per message),
with `event`, `session` (under `sessions = "separate"`), `from`, `to`
(for a message, its targets joined by commas), `n_targets` (messages
only), `start`, `end`, `duration`, `weight`, `spell` (the spell the
event came from, or a message's first spell, numbered in the order
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) built
them) and the tie attributes of that spell, except one whose name is
already among these columns; and
`as.data.frame(x, what = "adjacencies")` for the arcs, one row per pair
of events and shared vertex, with `from_event`, `to_event` (the numbers
of the two events in the event table), `via` (the shared vertex),
`first` and `second` (the two events written as `from->to`, or
`from--to` on an undirected network; a message to several targets as
`from->9 targets`), `from_time` (when the earlier event ends), `to_time`
(when the later one starts), `wait`, under `sessions = "separate"`
`session`, and each tie attribute of the two events as `first_<name>`
and `second_<name>`. [`summary()`](https://rdrr.io/r/base/summary.html)
gives one row per event and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
graph.

## Details

Events are ordered by `start`, then `end`, `from` and `to`, and numbered
in that order. Event `e1` precedes `e2` at a shared vertex `v` when `e2`
starts strictly after `e1` ends, and no more than `delta` later. An
event therefore occupies its whole spell, as in the event graphs of
Kivela et al. (2018): something carried by it is available at its
endpoints once it has ended. Because the later event must start strictly
after, two instantaneous events at the same instant are never adjacent,
nor is an event that starts at the very instant another ends; every wait
is positive, the graph is acyclic, and numbering events by start is a
topological order. This is the rule of Reticula (Badie-Modiri and
Kivela, 2023), the reference implementation of the construct.

Two events that share both endpoints are joined once per shared vertex,
so they produce two adjacency rows with different `via`. This is
correct: each row is a different way the second event can follow the
first.

With `adjacency = "all"` every arc is an admissible hop and every chain
of admissible hops is a path, so a path from an event leaving `u` to an
event arriving at `w` exists exactly when `w` can be reached from `u`
through events taken one after another. On contact data (instantaneous
events), that is the reachability of
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) with a
`traversal_time` shorter than the smallest gap between distinct contact
times. It is not the reachability of
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) on
interval spells, which may be entered at any instant while they are
active rather than only as a whole. `"next"` keeps the earliest
successors only, the consecutive-event adjacency of Kovanen et al.
(2011) used for temporal motifs. It is much sparser, and with
`delta = Inf` on an undirected network of instantaneous contacts it
reaches the same events as `"all"`. Otherwise it can lose reachability:
on a directed network the earliest departure from a vertex need not lead
where a later one does, and with interval spells the earliest successor
can end after a later one has started.

No R package computes this construct, so it is checked against Dynet's
own path search and against direct enumeration of event pairs.

## Conditions

Errors: `dynet_bad_input` for a `dn` that is not a `dynet`, a `delta`
that is not one non-negative number, or a `loops` that is not one
logical value; `dynet_no_sessions` for `sessions = "separate"` without a
session column; `dynet_empty_network` when no spell remains once
self-loops are dropped.

## References

Kivela, M., Cambe, J., Saramaki, J., & Karsai, M. (2018). Mapping
temporal- network percolation to weighted, static event graphs.
*Scientific Reports*, 8, 12357.
[doi:10.1038/s41598-018-29577-2](https://doi.org/10.1038/s41598-018-29577-2)

Mellor, A. (2018). The temporal event graph. *Journal of Complex
Networks*, 6(4), 639-659.
[doi:10.1093/comnet/cnx048](https://doi.org/10.1093/comnet/cnx048)

Badie-Modiri, A., & Kivela, M. (2023). Reticula: A temporal network and
hypergraph analysis software package. *SoftwareX*, 21, 101301.
[doi:10.1016/j.softx.2022.101301](https://doi.org/10.1016/j.softx.2022.101301)

Kovanen, L., Karsai, M., Kaski, K., Kertesz, J., & Saramaki, J. (2011).
Temporal motifs in time-dependent networks. *Journal of Statistical
Mechanics: Theory and Experiment*, P11005.
[doi:10.1088/1742-5468/2011/11/P11005](https://doi.org/10.1088/1742-5468/2011/11/P11005)

## See also

[`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md)
for the time-expanded graph,
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) for
time-respecting paths between vertices.

## Examples

``` r
dn <- dynet(school_contacts)
eg <- event_graph(dn, delta = 1)
eg
#> # Event graph | 240 events | 196 adjacencies
#> # delta 1 | adjacency "all" | direction "respect" | sessions_ignored
#>  from_event to_event      first     second  via wait
#>           1       16 Jonas->Dan   Dan->Leo  Dan 0.93
#>           3       10  Leo->Mira Mira->Finn Mira 0.41
#>           3       12  Leo->Mira  Mira->Eve Mira 0.81
#>           4       14  Leo->Iris Iris->Gita Iris 0.99
#>           6        9  Leo->Iris Iris->Cara Iris 0.28
#>           8       15  Eve->Kira  Kira->Eve Kira 0.53
#> # as.data.frame(x, what = "adjacencies") adds the times and the tie attributes of both events.
as.data.frame(eg, what = "adjacencies")
#>     from_event to_event   via       first      second from_time to_time wait
#> 1            1       16   Dan  Jonas->Dan    Dan->Leo      1.10    2.03 0.93
#> 2            3       10  Mira   Leo->Mira  Mira->Finn      0.42    0.83 0.41
#> 3            3       12  Mira   Leo->Mira   Mira->Eve      0.42    1.23 0.81
#> 4            4       14  Iris   Leo->Iris  Iris->Gita      0.96    1.95 0.99
#> 5            6        9  Iris   Leo->Iris  Iris->Cara      0.50    0.78 0.28
#> 6            8       15  Kira   Eve->Kira   Kira->Eve      1.42    1.95 0.53
#> 7            9       18  Cara  Iris->Cara  Cara->Nils      1.31    2.07 0.76
#> 8           13       14  Iris   Eve->Iris  Iris->Gita      1.85    1.95 0.10
#> 9           13       21  Iris   Eve->Iris  Iris->Finn      1.85    2.74 0.89
#> 10          14       23  Gita  Iris->Gita Gita->Jonas      2.26    2.91 0.65
#> 11          16       26   Leo    Dan->Leo   Leo->Finn      2.30    3.15 0.85
#> 12          21       40  Finn  Iris->Finn  Finn->Cara      3.96    4.77 0.81
#> 13          22       29  Kira  Hugo->Kira   Kira->Leo      3.12    3.20 0.08
#> 14          26       40  Finn   Leo->Finn  Finn->Cara      3.94    4.77 0.83
#> 15          27       30   Ana    Dan->Ana  Ana->Jonas      3.27    3.43 0.16
#> 16          29       39   Leo   Kira->Leo   Leo->Cara      4.16    4.76 0.60
#> 17          34       42   Ben   Nils->Ben   Ben->Finn      4.85    4.91 0.06
#> 18          34       46   Ben   Nils->Ben    Ben->Eve      4.85    5.27 0.42
#> 19          36       38  Iris  Cara->Iris   Iris->Ben      4.67    4.76 0.09
#> 20          37       48  Iris   Dan->Iris  Iris->Cara      5.07    5.71 0.64
#> 21          38       46   Ben   Iris->Ben    Ben->Eve      4.91    5.27 0.36
#> 22          39       55  Cara   Leo->Cara  Cara->Kira      5.12    6.11 0.99
#> 23          40       55  Cara  Finn->Cara  Cara->Kira      5.19    6.11 0.92
#> 24          41       46   Ben   Nils->Ben    Ben->Eve      5.03    5.27 0.24
#> 25          44       57   Leo   Kira->Leo   Leo->Iris      6.11    6.13 0.02
#> 26          44       73   Leo   Kira->Leo   Leo->Hugo      6.11    6.76 0.65
#> 27          44       76   Leo   Kira->Leo    Leo->Ana      6.11    6.83 0.72
#> 28          45       60  Gita  Kira->Gita  Gita->Mira      5.74    6.15 0.41
#> 29          47       74 Jonas Hugo->Jonas Jonas->Gita      6.13    6.79 0.66
#> 30          48       55  Cara  Iris->Cara  Cara->Kira      6.00    6.11 0.11
#> 31          48       77  Cara  Iris->Cara  Cara->Finn      6.00    6.96 0.96
#> 32          49       63  Finn   Dan->Finn  Finn->Nils      5.90    6.31 0.41
#> 33          49       64  Finn   Dan->Finn  Finn->Kira      5.90    6.32 0.42
#> 34          53       75  Gita  Hugo->Gita   Gita->Ana      6.20    6.81 0.61
#> 35          54       75  Gita  Mira->Gita   Gita->Ana      6.43    6.81 0.38
#> 36          57       71  Iris   Leo->Iris   Iris->Eve      6.20    6.67 0.47
#> 37          60       80  Mira  Gita->Mira   Mira->Ana      6.92    7.09 0.17
#> 38          60       88  Mira  Gita->Mira Mira->Jonas      6.92    7.72 0.80
#> 39          61       84   Ben   Nils->Ben   Ben->Iris      7.50    7.51 0.01
#> 40          61       87   Ben   Nils->Ben   Ben->Hugo      7.50    7.65 0.15
#> 41          62       75  Gita   Dan->Gita   Gita->Ana      6.55    6.81 0.26
#> 42          65       84   Ben   Nils->Ben   Ben->Iris      6.68    7.51 0.83
#> 43          65       87   Ben   Nils->Ben   Ben->Hugo      6.68    7.65 0.97
#> 44          66       80  Mira   Ana->Mira   Mira->Ana      6.77    7.09 0.32
#> 45          66       88  Mira   Ana->Mira Mira->Jonas      6.77    7.72 0.95
#> 46          69       79   Ana   Hugo->Ana   Ana->Gita      6.75    7.04 0.29
#> 47          69       86   Ana   Hugo->Ana   Ana->Mira      6.75    7.63 0.88
#> 48          70       77  Cara   Ana->Cara  Cara->Finn      6.77    6.96 0.19
#> 49          70       85  Cara   Ana->Cara  Cara->Nils      6.77    7.51 0.74
#> 50          71       94   Eve   Iris->Eve   Eve->Hugo      7.62    8.33 0.71
#> 51          72       92 Jonas  Ana->Jonas  Jonas->Dan      7.53    8.21 0.68
#> 52          73       78  Hugo   Leo->Hugo   Hugo->Eve      6.87    7.02 0.15
#> 53          73       82  Hugo   Leo->Hugo Hugo->Jonas      6.87    7.37 0.50
#> 54          73       89  Hugo   Leo->Hugo   Hugo->Dan      6.87    7.79 0.92
#> 55          76       79   Ana    Leo->Ana   Ana->Gita      7.00    7.04 0.04
#> 56          76       86   Ana    Leo->Ana   Ana->Mira      7.00    7.63 0.63
#> 57          78       94   Eve   Hugo->Eve   Eve->Hugo      7.66    8.33 0.67
#> 58          80      100   Ana   Mira->Ana  Ana->Jonas      8.15    8.76 0.61
#> 59          80      101   Ana   Mira->Ana   Ana->Mira      8.15    8.77 0.62
#> 60          82       92 Jonas Hugo->Jonas  Jonas->Dan      8.15    8.21 0.06
#> 61          82       99 Jonas Hugo->Jonas  Jonas->Dan      8.15    8.61 0.46
#> 62          83       91   Leo   Iris->Leo   Leo->Cara      7.71    8.00 0.29
#> 63          83       98   Leo   Iris->Leo   Leo->Iris      7.71    8.59 0.88
#> 64          85      106  Nils  Cara->Nils   Nils->Ana      8.49    9.40 0.91
#> 65          86       95  Mira   Ana->Mira  Mira->Gita      8.04    8.35 0.31
#> 66          86       97  Mira   Ana->Mira   Mira->Dan      8.04    8.56 0.52
#> 67          88       92 Jonas Mira->Jonas  Jonas->Dan      8.14    8.21 0.07
#> 68          88       99 Jonas Mira->Jonas  Jonas->Dan      8.14    8.61 0.47
#> 69          91      102  Cara   Leo->Cara  Cara->Hugo      8.50    8.78 0.28
#> 70          93       99 Jonas Finn->Jonas  Jonas->Dan      8.59    8.61 0.02
#> 71          93      105 Jonas Finn->Jonas Jonas->Gita      8.59    9.35 0.76
#> 72          93      108 Jonas Finn->Jonas  Jonas->Dan      8.59    9.49 0.90
#> 73          94      112  Hugo   Eve->Hugo  Hugo->Nils      8.84    9.84 1.00
#> 74          95      110  Gita  Mira->Gita  Gita->Nils      8.84    9.61 0.77
#> 75          96      114  Nils  Kira->Nils  Nils->Hugo      9.53    9.93 0.40
#> 76          96      121  Nils  Kira->Nils  Nils->Cara      9.53   10.38 0.85
#> 77         100      105 Jonas  Ana->Jonas Jonas->Gita      9.13    9.35 0.22
#> 78         100      108 Jonas  Ana->Jonas  Jonas->Dan      9.13    9.49 0.36
#> 79         102      112  Hugo  Cara->Hugo  Hugo->Nils      9.71    9.84 0.13
#> 80         103      105 Jonas Kira->Jonas Jonas->Gita      9.01    9.35 0.34
#> 81         103      108 Jonas Kira->Jonas  Jonas->Dan      9.01    9.49 0.48
#> 82         104      123 Jonas Kira->Jonas  Jonas->Ana      9.82   10.56 0.74
#> 83         105      120  Gita Jonas->Gita  Gita->Mira     10.09   10.35 0.26
#> 84         107      112  Hugo  Kira->Hugo  Hugo->Nils      9.58    9.84 0.26
#> 85         109      132   Ben   Kira->Ben   Ben->Gita     10.26   11.21 0.95
#> 86         110      114  Nils  Gita->Nils  Nils->Hugo      9.65    9.93 0.28
#> 87         110      121  Nils  Gita->Nils  Nils->Cara      9.65   10.38 0.73
#> 88         111      118   Leo   Finn->Leo   Leo->Cara      9.79   10.04 0.25
#> 89         112      121  Nils  Hugo->Nils  Nils->Cara     10.32   10.38 0.06
#> 90         115      123 Jonas  Eve->Jonas  Jonas->Ana     10.53   10.56 0.03
#> 91         116      130  Iris  Finn->Iris   Iris->Leo     10.35   11.13 0.78
#> 92         116      131  Iris  Finn->Iris  Iris->Cara     10.35   11.20 0.85
#> 93         117      120  Gita   Ana->Gita  Gita->Mira     10.24   10.35 0.11
#> 94         118      128  Cara   Leo->Cara  Cara->Iris     10.51   11.03 0.52
#> 95         119      122  Mira  Iris->Mira   Mira->Dan     10.44   10.48 0.04
#> 96         119      125  Mira  Iris->Mira  Mira->Gita     10.44   10.77 0.33
#> 97         119      133  Mira  Iris->Mira  Mira->Gita     10.44   11.40 0.96
#> 98         120      125  Mira  Gita->Mira  Mira->Gita     10.60   10.77 0.17
#> 99         120      133  Mira  Gita->Mira  Mira->Gita     10.60   11.40 0.80
#> 100        120      134  Mira  Gita->Mira   Mira->Dan     10.60   11.55 0.95
#> 101        121      128  Cara  Nils->Cara  Cara->Iris     10.68   11.03 0.35
#> 102        122      140   Dan   Mira->Dan  Dan->Jonas     11.52   11.75 0.23
#> 103        122      145   Dan   Mira->Dan  Dan->Jonas     11.52   12.20 0.68
#> 104        123      136   Ana  Jonas->Ana   Ana->Kira     10.83   11.60 0.77
#> 105        124      154  Mira  Kira->Mira Mira->Jonas     11.90   12.86 0.96
#> 106        128      131  Iris  Cara->Iris  Iris->Cara     11.18   11.20 0.02
#> 107        130      146   Leo   Iris->Leo   Leo->Cara     11.77   12.21 0.44
#> 108        131      151  Cara  Iris->Cara  Cara->Finn     11.89   12.65 0.76
#> 109        133      165  Gita  Mira->Gita  Gita->Mira     12.94   13.30 0.36
#> 110        133      171  Gita  Mira->Gita Gita->Jonas     12.94   13.42 0.48
#> 111        133      180  Gita  Mira->Gita Gita->Jonas     12.94   13.88 0.94
#> 112        134      145   Dan   Mira->Dan  Dan->Jonas     12.09   12.20 0.11
#> 113        137      148   Eve    Ben->Eve   Eve->Hugo     11.93   12.38 0.45
#> 114        137      153   Eve    Ben->Eve   Eve->Cara     11.93   12.78 0.85
#> 115        138      147  Finn   Leo->Finn  Finn->Mira     12.09   12.34 0.25
#> 116        138      149  Finn   Leo->Finn  Finn->Iris     12.09   12.42 0.33
#> 117        138      152  Finn   Leo->Finn   Finn->Dan     12.09   12.73 0.64
#> 118        139      155 Jonas Mira->Jonas  Jonas->Ana     12.12   12.91 0.79
#> 119        140      155 Jonas  Dan->Jonas  Jonas->Ana     12.13   12.91 0.78
#> 120        141      146   Leo   Finn->Leo   Leo->Cara     12.02   12.21 0.19
#> 121        143      160   Dan    Ana->Dan   Dan->Mira     12.36   13.23 0.87
#> 122        145      155 Jonas  Dan->Jonas  Jonas->Ana     12.79   12.91 0.12
#> 123        145      161 Jonas  Dan->Jonas  Jonas->Eve     12.79   13.24 0.45
#> 124        145      168 Jonas  Dan->Jonas Jonas->Gita     12.79   13.33 0.54
#> 125        145      174 Jonas  Dan->Jonas  Jonas->Ana     12.79   13.65 0.86
#> 126        146      151  Cara   Leo->Cara  Cara->Finn     12.62   12.65 0.03
#> 127        146      156  Cara   Leo->Cara   Cara->Leo     12.62   13.14 0.52
#> 128        146      159  Cara   Leo->Cara   Cara->Eve     12.62   13.21 0.59
#> 129        147      154  Mira  Finn->Mira Mira->Jonas     12.41   12.86 0.45
#> 130        147      158  Mira  Finn->Mira  Mira->Kira     12.41   13.19 0.78
#> 131        147      163  Mira  Finn->Mira   Mira->Ana     12.41   13.26 0.85
#> 132        148      166  Hugo   Eve->Hugo   Hugo->Eve     12.64   13.31 0.67
#> 133        150      175   Ben   Nils->Ben   Ben->Nils     13.67   13.73 0.06
#> 134        151      164  Finn  Cara->Finn  Finn->Mira     13.02   13.27 0.25
#> 135        151      170  Finn  Cara->Finn  Finn->Mira     13.02   13.35 0.33
#> 136        151      181  Finn  Cara->Finn  Finn->Kira     13.02   13.95 0.93
#> 137        152      187   Dan   Finn->Dan   Dan->Hugo     13.24   14.13 0.89
#> 138        152      188   Dan   Finn->Dan  Dan->Jonas     13.24   14.13 0.89
#> 139        153      156  Cara   Eve->Cara   Cara->Leo     13.12   13.14 0.02
#> 140        153      159  Cara   Eve->Cara   Cara->Eve     13.12   13.21 0.09
#> 141        154      161 Jonas Mira->Jonas  Jonas->Eve     13.19   13.24 0.05
#> 142        154      168 Jonas Mira->Jonas Jonas->Gita     13.19   13.33 0.14
#> 143        154      174 Jonas Mira->Jonas  Jonas->Ana     13.19   13.65 0.46
#> 144        154      178 Jonas Mira->Jonas  Jonas->Dan     13.19   13.82 0.63
#> 145        154      182 Jonas Mira->Jonas Jonas->Hugo     13.19   13.96 0.77
#> 146        155      167   Ana  Jonas->Ana    Ana->Dan     13.29   13.33 0.04
#> 147        155      172   Ana  Jonas->Ana   Ana->Gita     13.29   13.55 0.26
#> 148        155      177   Ana  Jonas->Ana   Ana->Iris     13.29   13.80 0.51
#> 149        157      180  Gita   Ana->Gita Gita->Jonas     13.67   13.88 0.21
#> 150        157      185  Gita   Ana->Gita   Gita->Ana     13.67   14.01 0.34
#> 151        157      189  Gita   Ana->Gita   Gita->Dan     13.67   14.16 0.49
#> 152        158      192  Kira  Mira->Kira  Kira->Hugo     13.91   14.44 0.53
#> 153        158      194  Kira  Mira->Kira   Kira->Eve     13.91   14.55 0.64
#> 154        159      191   Eve   Cara->Eve   Eve->Nils     13.69   14.30 0.61
#> 155        161      191   Eve  Jonas->Eve   Eve->Nils     13.44   14.30 0.86
#> 156        162      191   Eve    Ben->Eve   Eve->Nils     13.49   14.30 0.81
#> 157        166      191   Eve   Hugo->Eve   Eve->Nils     14.00   14.30 0.30
#> 158        166      195   Eve   Hugo->Eve   Eve->Hugo     14.00   14.76 0.76
#> 159        166      199   Eve   Hugo->Eve  Eve->Jonas     14.00   14.95 0.95
#> 160        167      187   Dan    Ana->Dan   Dan->Hugo     13.84   14.13 0.29
#> 161        167      188   Dan    Ana->Dan  Dan->Jonas     13.84   14.13 0.29
#> 162        170      202  Mira  Finn->Mira Mira->Jonas     14.39   15.29 0.90
#> 163        176      197  Kira  Nils->Kira   Kira->Eve     14.86   14.92 0.06
#> 164        181      192  Kira  Finn->Kira  Kira->Hugo     14.09   14.44 0.35
#> 165        181      194  Kira  Finn->Kira   Kira->Eve     14.09   14.55 0.46
#> 166        181      197  Kira  Finn->Kira   Kira->Eve     14.09   14.92 0.83
#> 167        182      198  Hugo Jonas->Hugo  Hugo->Kira     14.08   14.93 0.85
#> 168        182      200  Hugo Jonas->Hugo   Hugo->Eve     14.08   14.96 0.88
#> 169        183      191   Eve   Nils->Eve   Eve->Nils     14.13   14.30 0.17
#> 170        183      195   Eve   Nils->Eve   Eve->Hugo     14.13   14.76 0.63
#> 171        183      199   Eve   Nils->Eve  Eve->Jonas     14.13   14.95 0.82
#> 172        186      196   Ben   Nils->Ben    Ben->Eve     14.34   14.78 0.44
#> 173        187      198  Hugo   Dan->Hugo  Hugo->Kira     14.26   14.93 0.67
#> 174        187      200  Hugo   Dan->Hugo   Hugo->Eve     14.26   14.96 0.70
#> 175        190      195   Eve   Finn->Eve   Eve->Hugo     14.30   14.76 0.46
#> 176        190      199   Eve   Finn->Eve  Eve->Jonas     14.30   14.95 0.65
#> 177        192      198  Hugo  Kira->Hugo  Hugo->Kira     14.50   14.93 0.43
#> 178        192      200  Hugo  Kira->Hugo   Hugo->Eve     14.50   14.96 0.46
#> 179        193      204  Iris  Cara->Iris   Iris->Leo     14.72   15.41 0.69
#> 180        198      205  Kira  Hugo->Kira  Kira->Nils     15.47   16.16 0.69
#> 181        203      206  Iris  Cara->Iris  Iris->Finn     15.67   16.25 0.58
#> 182        207      211  Finn  Cara->Finn  Finn->Kira     16.41   16.84 0.43
#> 183        207      214  Finn  Cara->Finn  Finn->Mira     16.41   16.97 0.56
#> 184        211      217  Kira  Finn->Kira   Kira->Ben     17.61   18.17 0.56
#> 185        213      216   Dan   Mira->Dan   Dan->Gita     17.25   17.46 0.21
#> 186        214      221  Mira  Finn->Mira   Mira->Ben     18.03   18.95 0.92
#> 187        219      222 Jonas  Dan->Jonas Jonas->Cara     18.70   18.96 0.26
#> 188        222      226  Cara Jonas->Cara   Cara->Ana     19.23   19.70 0.47
#> 189        224      239  Kira  Nils->Kira  Kira->Hugo     20.17   20.89 0.72
#> 190        225      228   Ana   Hugo->Ana    Ana->Dan     19.80   19.91 0.11
#> 191        225      233   Ana   Hugo->Ana    Ana->Leo     19.80   20.33 0.53
#> 192        228      234   Dan    Ana->Dan   Dan->Mira     20.10   20.43 0.33
#> 193        228      237   Dan    Ana->Dan   Dan->Nils     20.10   20.68 0.58
#> 194        228      240   Dan    Ana->Dan    Dan->Ana     20.10   20.95 0.85
#> 195        230      237   Dan  Jonas->Dan   Dan->Nils     20.46   20.68 0.22
#> 196        230      240   Dan  Jonas->Dan    Dan->Ana     20.46   20.95 0.49
summary(eg)
#>     event  time  from    to in_degree out_degree mean_wait
#> 1       1  0.00 Jonas   Dan         0          1 0.9300000
#> 2       2  0.14  Gita   Ana         0          0        NA
#> 3       3  0.15   Leo  Mira         0          2 0.6100000
#> 4       4  0.15   Leo  Iris         0          1 0.9900000
#> 5       5  0.33  Kira   Ben         0          0        NA
#> 6       6  0.38   Leo  Iris         0          1 0.2800000
#> 7       7  0.43   Eve  Hugo         0          0        NA
#> 8       8  0.77   Eve  Kira         0          1 0.5300000
#> 9       9  0.78  Iris  Cara         1          1 0.7600000
#> 10     10  0.83  Mira  Finn         1          0        NA
#> 11     11  0.92 Jonas  Mira         0          0        NA
#> 12     12  1.23  Mira   Eve         1          0        NA
#> 13     13  1.34   Eve  Iris         0          2 0.4950000
#> 14     14  1.95  Iris  Gita         2          1 0.6500000
#> 15     15  1.95  Kira   Eve         1          0        NA
#> 16     16  2.03   Dan   Leo         1          1 0.8500000
#> 17     17  2.05 Jonas  Kira         0          0        NA
#> 18     18  2.07  Cara  Nils         1          0        NA
#> 19     19  2.12   Ana Jonas         0          0        NA
#> 20     20  2.25  Nils   Eve         0          0        NA
#> 21     21  2.74  Iris  Finn         1          1 0.8100000
#> 22     22  2.91  Hugo  Kira         0          1 0.0800000
#> 23     23  2.91  Gita Jonas         1          0        NA
#> 24     24  3.09   Ben Jonas         0          0        NA
#> 25     25  3.14   Dan Jonas         0          0        NA
#> 26     26  3.15   Leo  Finn         1          1 0.8300000
#> 27     27  3.17   Dan   Ana         0          1 0.1600000
#> 28     28  3.20   Dan   Eve         0          0        NA
#> 29     29  3.20  Kira   Leo         1          1 0.6000000
#> 30     30  3.43   Ana Jonas         1          0        NA
#> 31     31  3.61   Ben   Eve         0          0        NA
#> 32     32  4.31  Mira   Ana         0          0        NA
#> 33     33  4.37  Kira Jonas         0          0        NA
#> 34     34  4.53  Nils   Ben         0          2 0.2400000
#> 35     35  4.55  Cara   Leo         0          0        NA
#> 36     36  4.58  Cara  Iris         0          1 0.0900000
#> 37     37  4.73   Dan  Iris         0          1 0.6400000
#> 38     38  4.76  Iris   Ben         1          1 0.3600000
#> 39     39  4.76   Leo  Cara         1          1 0.9900000
#> 40     40  4.77  Finn  Cara         2          1 0.9200000
#> 41     41  4.89  Nils   Ben         0          1 0.2400000
#> 42     42  4.91   Ben  Finn         1          0        NA
#> 43     43  4.92  Cara  Kira         0          0        NA
#> 44     44  5.01  Kira   Leo         0          3 0.4633333
#> 45     45  5.19  Kira  Gita         0          1 0.4100000
#> 46     46  5.27   Ben   Eve         3          0        NA
#> 47     47  5.58  Hugo Jonas         0          1 0.6600000
#> 48     48  5.71  Iris  Cara         1          2 0.5350000
#> 49     49  5.86   Dan  Finn         0          2 0.4150000
#> 50     50  5.90   Eve  Kira         0          0        NA
#> 51     51  5.95   Leo  Finn         0          0        NA
#> 52     52  5.96  Nils   Eve         0          0        NA
#> 53     53  6.04  Hugo  Gita         0          1 0.6100000
#> 54     54  6.08  Mira  Gita         0          1 0.3800000
#> 55     55  6.11  Cara  Kira         3          0        NA
#> 56     56  6.12 Jonas  Kira         0          0        NA
#> 57     57  6.13   Leo  Iris         1          1 0.4700000
#> 58     58  6.14  Nils   Ben         0          0        NA
#> 59     59  6.14  Hugo  Kira         0          0        NA
#> 60     60  6.15  Gita  Mira         1          2 0.4850000
#> 61     61  6.16  Nils   Ben         0          2 0.0800000
#> 62     62  6.21   Dan  Gita         0          1 0.2600000
#> 63     63  6.31  Finn  Nils         1          0        NA
#> 64     64  6.32  Finn  Kira         1          0        NA
#> 65     65  6.36  Nils   Ben         0          2 0.9000000
#> 66     66  6.36   Ana  Mira         0          2 0.6350000
#> 67     67  6.37  Hugo  Nils         0          0        NA
#> 68     68  6.57   Ana  Gita         0          0        NA
#> 69     69  6.58  Hugo   Ana         0          2 0.5850000
#> 70     70  6.67   Ana  Cara         0          2 0.4650000
#> 71     71  6.67  Iris   Eve         1          1 0.7100000
#> 72     72  6.68   Ana Jonas         0          1 0.6800000
#> 73     73  6.76   Leo  Hugo         1          3 0.5233333
#> 74     74  6.79 Jonas  Gita         1          0        NA
#> 75     75  6.81  Gita   Ana         3          0        NA
#> 76     76  6.83   Leo   Ana         1          2 0.3350000
#> 77     77  6.96  Cara  Finn         2          0        NA
#> 78     78  7.02  Hugo   Eve         1          1 0.6700000
#> 79     79  7.04   Ana  Gita         2          0        NA
#> 80     80  7.09  Mira   Ana         2          2 0.6150000
#> 81     81  7.34 Jonas   Ana         0          0        NA
#> 82     82  7.37  Hugo Jonas         1          2 0.2600000
#> 83     83  7.51  Iris   Leo         0          2 0.5850000
#> 84     84  7.51   Ben  Iris         2          0        NA
#> 85     85  7.51  Cara  Nils         1          1 0.9100000
#> 86     86  7.63   Ana  Mira         2          2 0.4150000
#> 87     87  7.65   Ben  Hugo         2          0        NA
#> 88     88  7.72  Mira Jonas         2          2 0.2700000
#> 89     89  7.79  Hugo   Dan         1          0        NA
#> 90     90  7.98  Nils  Hugo         0          0        NA
#> 91     91  8.00   Leo  Cara         1          1 0.2800000
#> 92     92  8.21 Jonas   Dan         3          0        NA
#> 93     93  8.23  Finn Jonas         0          3 0.5600000
#> 94     94  8.33   Eve  Hugo         2          1 1.0000000
#> 95     95  8.35  Mira  Gita         1          1 0.7700000
#> 96     96  8.35  Kira  Nils         0          2 0.6250000
#> 97     97  8.56  Mira   Dan         1          0        NA
#> 98     98  8.59   Leo  Iris         1          0        NA
#> 99     99  8.61 Jonas   Dan         3          0        NA
#> 100   100  8.76   Ana Jonas         1          2 0.2900000
#> 101   101  8.77   Ana  Mira         1          0        NA
#> 102   102  8.78  Cara  Hugo         1          1 0.1300000
#> 103   103  8.81  Kira Jonas         0          2 0.4100000
#> 104   104  9.15  Kira Jonas         0          1 0.7400000
#> 105   105  9.35 Jonas  Gita         3          1 0.2600000
#> 106   106  9.40  Nils   Ana         1          0        NA
#> 107   107  9.41  Kira  Hugo         0          1 0.2600000
#> 108   108  9.49 Jonas   Dan         3          0        NA
#> 109   109  9.59  Kira   Ben         0          1 0.9500000
#> 110   110  9.61  Gita  Nils         1          2 0.5050000
#> 111   111  9.65  Finn   Leo         0          1 0.2500000
#> 112   112  9.84  Hugo  Nils         3          1 0.0600000
#> 113   113  9.85   Ben  Nils         0          0        NA
#> 114   114  9.93  Nils  Hugo         2          0        NA
#> 115   115  9.98   Eve Jonas         0          1 0.0300000
#> 116   116 10.00  Finn  Iris         0          2 0.8150000
#> 117   117 10.02   Ana  Gita         0          1 0.1100000
#> 118   118 10.04   Leo  Cara         1          1 0.5200000
#> 119   119 10.18  Iris  Mira         0          3 0.4433333
#> 120   120 10.35  Gita  Mira         2          3 0.6400000
#> 121   121 10.38  Nils  Cara         3          1 0.3500000
#> 122   122 10.48  Mira   Dan         1          2 0.4550000
#> 123   123 10.56 Jonas   Ana         2          1 0.7700000
#> 124   124 10.56  Kira  Mira         0          1 0.9600000
#> 125   125 10.77  Mira  Gita         2          0        NA
#> 126   126 10.77  Finn  Cara         0          0        NA
#> 127   127 10.97   Leo  Iris         0          0        NA
#> 128   128 11.03  Cara  Iris         2          1 0.0200000
#> 129   129 11.13   Leo  Cara         0          0        NA
#> 130   130 11.13  Iris   Leo         1          1 0.4400000
#> 131   131 11.20  Iris  Cara         2          1 0.7600000
#> 132   132 11.21   Ben  Gita         1          0        NA
#> 133   133 11.40  Mira  Gita         2          3 0.5933333
#> 134   134 11.55  Mira   Dan         1          1 0.1100000
#> 135   135 11.58   Ben  Kira         0          0        NA
#> 136   136 11.60   Ana  Kira         1          0        NA
#> 137   137 11.66   Ben   Eve         0          2 0.6500000
#> 138   138 11.69   Leo  Finn         0          3 0.4066667
#> 139   139 11.73  Mira Jonas         0          1 0.7900000
#> 140   140 11.75   Dan Jonas         1          1 0.7800000
#> 141   141 11.86  Finn   Leo         0          1 0.1900000
#> 142   142 11.99   Ben  Hugo         0          0        NA
#> 143   143 12.04   Ana   Dan         0          1 0.8700000
#> 144   144 12.12   Ben  Hugo         0          0        NA
#> 145   145 12.20   Dan Jonas         2          4 0.4925000
#> 146   146 12.21   Leo  Cara         2          3 0.3800000
#> 147   147 12.34  Finn  Mira         1          3 0.6933333
#> 148   148 12.38   Eve  Hugo         1          1 0.6700000
#> 149   149 12.42  Finn  Iris         1          0        NA
#> 150   150 12.47  Nils   Ben         0          1 0.0600000
#> 151   151 12.65  Cara  Finn         2          3 0.5033333
#> 152   152 12.73  Finn   Dan         1          2 0.8900000
#> 153   153 12.78   Eve  Cara         1          2 0.0550000
#> 154   154 12.86  Mira Jonas         2          5 0.4100000
#> 155   155 12.91 Jonas   Ana         3          3 0.2700000
#> 156   156 13.14  Cara   Leo         2          0        NA
#> 157   157 13.16   Ana  Gita         0          3 0.3466667
#> 158   158 13.19  Mira  Kira         1          2 0.5850000
#> 159   159 13.21  Cara   Eve         2          1 0.6100000
#> 160   160 13.23   Dan  Mira         1          0        NA
#> 161   161 13.24 Jonas   Eve         2          1 0.8600000
#> 162   162 13.25   Ben   Eve         0          1 0.8100000
#> 163   163 13.26  Mira   Ana         1          0        NA
#> 164   164 13.27  Finn  Mira         1          0        NA
#> 165   165 13.30  Gita  Mira         1          0        NA
#> 166   166 13.31  Hugo   Eve         1          3 0.6700000
#> 167   167 13.33   Ana   Dan         1          2 0.2900000
#> 168   168 13.33 Jonas  Gita         2          0        NA
#> 169   169 13.33   Ben  Nils         0          0        NA
#> 170   170 13.35  Finn  Mira         1          1 0.9000000
#> 171   171 13.42  Gita Jonas         1          0        NA
#> 172   172 13.55   Ana  Gita         1          0        NA
#> 173   173 13.57  Nils   Dan         0          0        NA
#> 174   174 13.65 Jonas   Ana         2          0        NA
#> 175   175 13.73   Ben  Nils         1          0        NA
#> 176   176 13.78  Nils  Kira         0          1 0.0600000
#> 177   177 13.80   Ana  Iris         1          0        NA
#> 178   178 13.82 Jonas   Dan         1          0        NA
#> 179   179 13.84  Iris  Nils         0          0        NA
#> 180   180 13.88  Gita Jonas         2          0        NA
#> 181   181 13.95  Finn  Kira         1          3 0.5466667
#> 182   182 13.96 Jonas  Hugo         1          2 0.8650000
#> 183   183 13.97  Nils   Eve         0          3 0.5400000
#> 184   184 13.97  Nils   Ben         0          0        NA
#> 185   185 14.01  Gita   Ana         1          0        NA
#> 186   186 14.02  Nils   Ben         0          1 0.4400000
#> 187   187 14.13   Dan  Hugo         2          2 0.6850000
#> 188   188 14.13   Dan Jonas         2          0        NA
#> 189   189 14.16  Gita   Dan         1          0        NA
#> 190   190 14.18  Finn   Eve         0          2 0.5550000
#> 191   191 14.30   Eve  Nils         5          0        NA
#> 192   192 14.44  Kira  Hugo         2          2 0.4450000
#> 193   193 14.50  Cara  Iris         0          1 0.6900000
#> 194   194 14.55  Kira   Eve         2          0        NA
#> 195   195 14.76   Eve  Hugo         3          0        NA
#> 196   196 14.78   Ben   Eve         1          0        NA
#> 197   197 14.92  Kira   Eve         2          0        NA
#> 198   198 14.93  Hugo  Kira         3          1 0.6900000
#> 199   199 14.95   Eve Jonas         3          0        NA
#> 200   200 14.96  Hugo   Eve         3          0        NA
#> 201   201 15.13  Cara   Dan         0          0        NA
#> 202   202 15.29  Mira Jonas         1          0        NA
#> 203   203 15.30  Cara  Iris         0          1 0.5800000
#> 204   204 15.41  Iris   Leo         1          0        NA
#> 205   205 16.16  Kira  Nils         1          0        NA
#> 206   206 16.25  Iris  Finn         1          0        NA
#> 207   207 16.37  Cara  Finn         0          2 0.4950000
#> 208   208 16.61  Gita Jonas         0          0        NA
#> 209   209 16.69  Kira  Hugo         0          0        NA
#> 210   210 16.84  Cara   Ben         0          0        NA
#> 211   211 16.84  Finn  Kira         1          1 0.5600000
#> 212   212 16.91   Ben  Hugo         0          0        NA
#> 213   213 16.91  Mira   Dan         0          1 0.2100000
#> 214   214 16.97  Finn  Mira         1          1 0.9200000
#> 215   215 17.40  Kira  Nils         0          0        NA
#> 216   216 17.46   Dan  Gita         1          0        NA
#> 217   217 18.17  Kira   Ben         1          0        NA
#> 218   218 18.36  Cara   Leo         0          0        NA
#> 219   219 18.62   Dan Jonas         0          1 0.2600000
#> 220   220 18.66  Iris   Eve         0          0        NA
#> 221   221 18.95  Mira   Ben         1          0        NA
#> 222   222 18.96 Jonas  Cara         1          1 0.4700000
#> 223   223 19.03  Iris   Ben         0          0        NA
#> 224   224 19.46  Nils  Kira         0          1 0.7200000
#> 225   225 19.54  Hugo   Ana         0          2 0.3200000
#> 226   226 19.70  Cara   Ana         1          0        NA
#> 227   227 19.81  Gita  Mira         0          0        NA
#> 228   228 19.91   Ana   Dan         1          3 0.5866667
#> 229   229 19.96  Hugo  Kira         0          0        NA
#> 230   230 20.00 Jonas   Dan         0          2 0.3550000
#> 231   231 20.01  Finn  Cara         0          0        NA
#> 232   232 20.14   Eve   Ben         0          0        NA
#> 233   233 20.33   Ana   Leo         1          0        NA
#> 234   234 20.43   Dan  Mira         1          0        NA
#> 235   235 20.45  Nils  Cara         0          0        NA
#> 236   236 20.49 Jonas   Ben         0          0        NA
#> 237   237 20.68   Dan  Nils         2          0        NA
#> 238   238 20.77   Eve  Hugo         0          0        NA
#> 239   239 20.89  Kira  Hugo         1          0        NA
#> 240   240 20.95   Dan   Ana         2          0        NA

# Only the earliest successors, as for temporal motifs
sparse <- event_graph(dn, delta = 1, adjacency = "next")
sparse
#> # Event graph | 240 events | 124 adjacencies
#> # delta 1 | adjacency "next" | direction "respect" | sessions_ignored
#>  from_event to_event      first     second  via wait
#>           1       16 Jonas->Dan   Dan->Leo  Dan 0.93
#>           3       10  Leo->Mira Mira->Finn Mira 0.41
#>           4       14  Leo->Iris Iris->Gita Iris 0.99
#>           6        9  Leo->Iris Iris->Cara Iris 0.28
#>           8       15  Eve->Kira  Kira->Eve Kira 0.53
#>           9       18 Iris->Cara Cara->Nils Cara 0.76
#> # as.data.frame(x, what = "adjacencies") adds the times and the tie attributes of both events.
```
