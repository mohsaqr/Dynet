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
  loops = FALSE
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

## Value

An object of class `dynet_event_graph`. Take its tables with
`as.data.frame(x)` for the events, one row per spell, with `event`,
`session` (under `sessions = "separate"`), `from`, `to`, `start`, `end`,
`duration`, `weight` and `spell` (the row of `as.data.frame(dn)` the
event came from); and `as.data.frame(x, what = "adjacencies")` for the
arcs, one row per pair of events and shared vertex, with `from_event`,
`to_event`, `via` (the shared vertex), `from_time` (when the earlier
event ends), `to_time` (when the later one starts), `wait` and, under
`sessions = "separate"`, `session`.
[`summary()`](https://rdrr.io/r/base/summary.html) gives one row per
event and [`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws
the graph.

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
#>  from_event to_event  via from_time to_time wait
#>           1       16  Dan      1.10    2.03 0.93
#>           3       10 Mira      0.42    0.83 0.41
#>           3       12 Mira      0.42    1.23 0.81
#>           4       14 Iris      0.96    1.95 0.99
#>           6        9 Iris      0.50    0.78 0.28
#>           8       15 Kira      1.42    1.95 0.53
as.data.frame(eg, what = "adjacencies")
#>     from_event to_event   via from_time to_time wait
#> 1            1       16   Dan      1.10    2.03 0.93
#> 2            3       10  Mira      0.42    0.83 0.41
#> 3            3       12  Mira      0.42    1.23 0.81
#> 4            4       14  Iris      0.96    1.95 0.99
#> 5            6        9  Iris      0.50    0.78 0.28
#> 6            8       15  Kira      1.42    1.95 0.53
#> 7            9       18  Cara      1.31    2.07 0.76
#> 8           13       14  Iris      1.85    1.95 0.10
#> 9           13       21  Iris      1.85    2.74 0.89
#> 10          14       23  Gita      2.26    2.91 0.65
#> 11          16       26   Leo      2.30    3.15 0.85
#> 12          21       40  Finn      3.96    4.77 0.81
#> 13          22       29  Kira      3.12    3.20 0.08
#> 14          26       40  Finn      3.94    4.77 0.83
#> 15          27       30   Ana      3.27    3.43 0.16
#> 16          29       39   Leo      4.16    4.76 0.60
#> 17          34       42   Ben      4.85    4.91 0.06
#> 18          34       46   Ben      4.85    5.27 0.42
#> 19          36       38  Iris      4.67    4.76 0.09
#> 20          37       48  Iris      5.07    5.71 0.64
#> 21          38       46   Ben      4.91    5.27 0.36
#> 22          39       55  Cara      5.12    6.11 0.99
#> 23          40       55  Cara      5.19    6.11 0.92
#> 24          41       46   Ben      5.03    5.27 0.24
#> 25          44       57   Leo      6.11    6.13 0.02
#> 26          44       73   Leo      6.11    6.76 0.65
#> 27          44       76   Leo      6.11    6.83 0.72
#> 28          45       60  Gita      5.74    6.15 0.41
#> 29          47       74 Jonas      6.13    6.79 0.66
#> 30          48       55  Cara      6.00    6.11 0.11
#> 31          48       77  Cara      6.00    6.96 0.96
#> 32          49       63  Finn      5.90    6.31 0.41
#> 33          49       64  Finn      5.90    6.32 0.42
#> 34          53       75  Gita      6.20    6.81 0.61
#> 35          54       75  Gita      6.43    6.81 0.38
#> 36          57       71  Iris      6.20    6.67 0.47
#> 37          60       80  Mira      6.92    7.09 0.17
#> 38          60       88  Mira      6.92    7.72 0.80
#> 39          61       84   Ben      7.50    7.51 0.01
#> 40          61       87   Ben      7.50    7.65 0.15
#> 41          62       75  Gita      6.55    6.81 0.26
#> 42          65       84   Ben      6.68    7.51 0.83
#> 43          65       87   Ben      6.68    7.65 0.97
#> 44          66       80  Mira      6.77    7.09 0.32
#> 45          66       88  Mira      6.77    7.72 0.95
#> 46          69       79   Ana      6.75    7.04 0.29
#> 47          69       86   Ana      6.75    7.63 0.88
#> 48          70       77  Cara      6.77    6.96 0.19
#> 49          70       85  Cara      6.77    7.51 0.74
#> 50          71       94   Eve      7.62    8.33 0.71
#> 51          72       92 Jonas      7.53    8.21 0.68
#> 52          73       78  Hugo      6.87    7.02 0.15
#> 53          73       82  Hugo      6.87    7.37 0.50
#> 54          73       89  Hugo      6.87    7.79 0.92
#> 55          76       79   Ana      7.00    7.04 0.04
#> 56          76       86   Ana      7.00    7.63 0.63
#> 57          78       94   Eve      7.66    8.33 0.67
#> 58          80      100   Ana      8.15    8.76 0.61
#> 59          80      101   Ana      8.15    8.77 0.62
#> 60          82       92 Jonas      8.15    8.21 0.06
#> 61          82       99 Jonas      8.15    8.61 0.46
#> 62          83       91   Leo      7.71    8.00 0.29
#> 63          83       98   Leo      7.71    8.59 0.88
#> 64          85      106  Nils      8.49    9.40 0.91
#> 65          86       95  Mira      8.04    8.35 0.31
#> 66          86       97  Mira      8.04    8.56 0.52
#> 67          88       92 Jonas      8.14    8.21 0.07
#> 68          88       99 Jonas      8.14    8.61 0.47
#> 69          91      102  Cara      8.50    8.78 0.28
#> 70          93       99 Jonas      8.59    8.61 0.02
#> 71          93      105 Jonas      8.59    9.35 0.76
#> 72          93      108 Jonas      8.59    9.49 0.90
#> 73          94      112  Hugo      8.84    9.84 1.00
#> 74          95      110  Gita      8.84    9.61 0.77
#> 75          96      114  Nils      9.53    9.93 0.40
#> 76          96      121  Nils      9.53   10.38 0.85
#> 77         100      105 Jonas      9.13    9.35 0.22
#> 78         100      108 Jonas      9.13    9.49 0.36
#> 79         102      112  Hugo      9.71    9.84 0.13
#> 80         103      105 Jonas      9.01    9.35 0.34
#> 81         103      108 Jonas      9.01    9.49 0.48
#> 82         104      123 Jonas      9.82   10.56 0.74
#> 83         105      120  Gita     10.09   10.35 0.26
#> 84         107      112  Hugo      9.58    9.84 0.26
#> 85         109      132   Ben     10.26   11.21 0.95
#> 86         110      114  Nils      9.65    9.93 0.28
#> 87         110      121  Nils      9.65   10.38 0.73
#> 88         111      118   Leo      9.79   10.04 0.25
#> 89         112      121  Nils     10.32   10.38 0.06
#> 90         115      123 Jonas     10.53   10.56 0.03
#> 91         116      130  Iris     10.35   11.13 0.78
#> 92         116      131  Iris     10.35   11.20 0.85
#> 93         117      120  Gita     10.24   10.35 0.11
#> 94         118      128  Cara     10.51   11.03 0.52
#> 95         119      122  Mira     10.44   10.48 0.04
#> 96         119      125  Mira     10.44   10.77 0.33
#> 97         119      133  Mira     10.44   11.40 0.96
#> 98         120      125  Mira     10.60   10.77 0.17
#> 99         120      133  Mira     10.60   11.40 0.80
#> 100        120      134  Mira     10.60   11.55 0.95
#> 101        121      128  Cara     10.68   11.03 0.35
#> 102        122      140   Dan     11.52   11.75 0.23
#> 103        122      145   Dan     11.52   12.20 0.68
#> 104        123      136   Ana     10.83   11.60 0.77
#> 105        124      154  Mira     11.90   12.86 0.96
#> 106        128      131  Iris     11.18   11.20 0.02
#> 107        130      146   Leo     11.77   12.21 0.44
#> 108        131      151  Cara     11.89   12.65 0.76
#> 109        133      165  Gita     12.94   13.30 0.36
#> 110        133      171  Gita     12.94   13.42 0.48
#> 111        133      180  Gita     12.94   13.88 0.94
#> 112        134      145   Dan     12.09   12.20 0.11
#> 113        137      148   Eve     11.93   12.38 0.45
#> 114        137      153   Eve     11.93   12.78 0.85
#> 115        138      147  Finn     12.09   12.34 0.25
#> 116        138      149  Finn     12.09   12.42 0.33
#> 117        138      152  Finn     12.09   12.73 0.64
#> 118        139      155 Jonas     12.12   12.91 0.79
#> 119        140      155 Jonas     12.13   12.91 0.78
#> 120        141      146   Leo     12.02   12.21 0.19
#> 121        143      160   Dan     12.36   13.23 0.87
#> 122        145      155 Jonas     12.79   12.91 0.12
#> 123        145      161 Jonas     12.79   13.24 0.45
#> 124        145      168 Jonas     12.79   13.33 0.54
#> 125        145      174 Jonas     12.79   13.65 0.86
#> 126        146      151  Cara     12.62   12.65 0.03
#> 127        146      156  Cara     12.62   13.14 0.52
#> 128        146      159  Cara     12.62   13.21 0.59
#> 129        147      154  Mira     12.41   12.86 0.45
#> 130        147      158  Mira     12.41   13.19 0.78
#> 131        147      163  Mira     12.41   13.26 0.85
#> 132        148      166  Hugo     12.64   13.31 0.67
#> 133        150      175   Ben     13.67   13.73 0.06
#> 134        151      164  Finn     13.02   13.27 0.25
#> 135        151      170  Finn     13.02   13.35 0.33
#> 136        151      181  Finn     13.02   13.95 0.93
#> 137        152      187   Dan     13.24   14.13 0.89
#> 138        152      188   Dan     13.24   14.13 0.89
#> 139        153      156  Cara     13.12   13.14 0.02
#> 140        153      159  Cara     13.12   13.21 0.09
#> 141        154      161 Jonas     13.19   13.24 0.05
#> 142        154      168 Jonas     13.19   13.33 0.14
#> 143        154      174 Jonas     13.19   13.65 0.46
#> 144        154      178 Jonas     13.19   13.82 0.63
#> 145        154      182 Jonas     13.19   13.96 0.77
#> 146        155      167   Ana     13.29   13.33 0.04
#> 147        155      172   Ana     13.29   13.55 0.26
#> 148        155      177   Ana     13.29   13.80 0.51
#> 149        157      180  Gita     13.67   13.88 0.21
#> 150        157      185  Gita     13.67   14.01 0.34
#> 151        157      189  Gita     13.67   14.16 0.49
#> 152        158      192  Kira     13.91   14.44 0.53
#> 153        158      194  Kira     13.91   14.55 0.64
#> 154        159      191   Eve     13.69   14.30 0.61
#> 155        161      191   Eve     13.44   14.30 0.86
#> 156        162      191   Eve     13.49   14.30 0.81
#> 157        166      191   Eve     14.00   14.30 0.30
#> 158        166      195   Eve     14.00   14.76 0.76
#> 159        166      199   Eve     14.00   14.95 0.95
#> 160        167      187   Dan     13.84   14.13 0.29
#> 161        167      188   Dan     13.84   14.13 0.29
#> 162        170      202  Mira     14.39   15.29 0.90
#> 163        176      197  Kira     14.86   14.92 0.06
#> 164        181      192  Kira     14.09   14.44 0.35
#> 165        181      194  Kira     14.09   14.55 0.46
#> 166        181      197  Kira     14.09   14.92 0.83
#> 167        182      198  Hugo     14.08   14.93 0.85
#> 168        182      200  Hugo     14.08   14.96 0.88
#> 169        183      191   Eve     14.13   14.30 0.17
#> 170        183      195   Eve     14.13   14.76 0.63
#> 171        183      199   Eve     14.13   14.95 0.82
#> 172        186      196   Ben     14.34   14.78 0.44
#> 173        187      198  Hugo     14.26   14.93 0.67
#> 174        187      200  Hugo     14.26   14.96 0.70
#> 175        190      195   Eve     14.30   14.76 0.46
#> 176        190      199   Eve     14.30   14.95 0.65
#> 177        192      198  Hugo     14.50   14.93 0.43
#> 178        192      200  Hugo     14.50   14.96 0.46
#> 179        193      204  Iris     14.72   15.41 0.69
#> 180        198      205  Kira     15.47   16.16 0.69
#> 181        203      206  Iris     15.67   16.25 0.58
#> 182        207      211  Finn     16.41   16.84 0.43
#> 183        207      214  Finn     16.41   16.97 0.56
#> 184        211      217  Kira     17.61   18.17 0.56
#> 185        213      216   Dan     17.25   17.46 0.21
#> 186        214      221  Mira     18.03   18.95 0.92
#> 187        219      222 Jonas     18.70   18.96 0.26
#> 188        222      226  Cara     19.23   19.70 0.47
#> 189        224      239  Kira     20.17   20.89 0.72
#> 190        225      228   Ana     19.80   19.91 0.11
#> 191        225      233   Ana     19.80   20.33 0.53
#> 192        228      234   Dan     20.10   20.43 0.33
#> 193        228      237   Dan     20.10   20.68 0.58
#> 194        228      240   Dan     20.10   20.95 0.85
#> 195        230      237   Dan     20.46   20.68 0.22
#> 196        230      240   Dan     20.46   20.95 0.49
summary(eg)
#>     event  time in_degree out_degree mean_wait
#> 1       1  0.00         0          1 0.9300000
#> 2       2  0.14         0          0        NA
#> 3       3  0.15         0          2 0.6100000
#> 4       4  0.15         0          1 0.9900000
#> 5       5  0.33         0          0        NA
#> 6       6  0.38         0          1 0.2800000
#> 7       7  0.43         0          0        NA
#> 8       8  0.77         0          1 0.5300000
#> 9       9  0.78         1          1 0.7600000
#> 10     10  0.83         1          0        NA
#> 11     11  0.92         0          0        NA
#> 12     12  1.23         1          0        NA
#> 13     13  1.34         0          2 0.4950000
#> 14     14  1.95         2          1 0.6500000
#> 15     15  1.95         1          0        NA
#> 16     16  2.03         1          1 0.8500000
#> 17     17  2.05         0          0        NA
#> 18     18  2.07         1          0        NA
#> 19     19  2.12         0          0        NA
#> 20     20  2.25         0          0        NA
#> 21     21  2.74         1          1 0.8100000
#> 22     22  2.91         0          1 0.0800000
#> 23     23  2.91         1          0        NA
#> 24     24  3.09         0          0        NA
#> 25     25  3.14         0          0        NA
#> 26     26  3.15         1          1 0.8300000
#> 27     27  3.17         0          1 0.1600000
#> 28     28  3.20         0          0        NA
#> 29     29  3.20         1          1 0.6000000
#> 30     30  3.43         1          0        NA
#> 31     31  3.61         0          0        NA
#> 32     32  4.31         0          0        NA
#> 33     33  4.37         0          0        NA
#> 34     34  4.53         0          2 0.2400000
#> 35     35  4.55         0          0        NA
#> 36     36  4.58         0          1 0.0900000
#> 37     37  4.73         0          1 0.6400000
#> 38     38  4.76         1          1 0.3600000
#> 39     39  4.76         1          1 0.9900000
#> 40     40  4.77         2          1 0.9200000
#> 41     41  4.89         0          1 0.2400000
#> 42     42  4.91         1          0        NA
#> 43     43  4.92         0          0        NA
#> 44     44  5.01         0          3 0.4633333
#> 45     45  5.19         0          1 0.4100000
#> 46     46  5.27         3          0        NA
#> 47     47  5.58         0          1 0.6600000
#> 48     48  5.71         1          2 0.5350000
#> 49     49  5.86         0          2 0.4150000
#> 50     50  5.90         0          0        NA
#> 51     51  5.95         0          0        NA
#> 52     52  5.96         0          0        NA
#> 53     53  6.04         0          1 0.6100000
#> 54     54  6.08         0          1 0.3800000
#> 55     55  6.11         3          0        NA
#> 56     56  6.12         0          0        NA
#> 57     57  6.13         1          1 0.4700000
#> 58     58  6.14         0          0        NA
#> 59     59  6.14         0          0        NA
#> 60     60  6.15         1          2 0.4850000
#> 61     61  6.16         0          2 0.0800000
#> 62     62  6.21         0          1 0.2600000
#> 63     63  6.31         1          0        NA
#> 64     64  6.32         1          0        NA
#> 65     65  6.36         0          2 0.9000000
#> 66     66  6.36         0          2 0.6350000
#> 67     67  6.37         0          0        NA
#> 68     68  6.57         0          0        NA
#> 69     69  6.58         0          2 0.5850000
#> 70     70  6.67         0          2 0.4650000
#> 71     71  6.67         1          1 0.7100000
#> 72     72  6.68         0          1 0.6800000
#> 73     73  6.76         1          3 0.5233333
#> 74     74  6.79         1          0        NA
#> 75     75  6.81         3          0        NA
#> 76     76  6.83         1          2 0.3350000
#> 77     77  6.96         2          0        NA
#> 78     78  7.02         1          1 0.6700000
#> 79     79  7.04         2          0        NA
#> 80     80  7.09         2          2 0.6150000
#> 81     81  7.34         0          0        NA
#> 82     82  7.37         1          2 0.2600000
#> 83     83  7.51         0          2 0.5850000
#> 84     84  7.51         2          0        NA
#> 85     85  7.51         1          1 0.9100000
#> 86     86  7.63         2          2 0.4150000
#> 87     87  7.65         2          0        NA
#> 88     88  7.72         2          2 0.2700000
#> 89     89  7.79         1          0        NA
#> 90     90  7.98         0          0        NA
#> 91     91  8.00         1          1 0.2800000
#> 92     92  8.21         3          0        NA
#> 93     93  8.23         0          3 0.5600000
#> 94     94  8.33         2          1 1.0000000
#> 95     95  8.35         1          1 0.7700000
#> 96     96  8.35         0          2 0.6250000
#> 97     97  8.56         1          0        NA
#> 98     98  8.59         1          0        NA
#> 99     99  8.61         3          0        NA
#> 100   100  8.76         1          2 0.2900000
#> 101   101  8.77         1          0        NA
#> 102   102  8.78         1          1 0.1300000
#> 103   103  8.81         0          2 0.4100000
#> 104   104  9.15         0          1 0.7400000
#> 105   105  9.35         3          1 0.2600000
#> 106   106  9.40         1          0        NA
#> 107   107  9.41         0          1 0.2600000
#> 108   108  9.49         3          0        NA
#> 109   109  9.59         0          1 0.9500000
#> 110   110  9.61         1          2 0.5050000
#> 111   111  9.65         0          1 0.2500000
#> 112   112  9.84         3          1 0.0600000
#> 113   113  9.85         0          0        NA
#> 114   114  9.93         2          0        NA
#> 115   115  9.98         0          1 0.0300000
#> 116   116 10.00         0          2 0.8150000
#> 117   117 10.02         0          1 0.1100000
#> 118   118 10.04         1          1 0.5200000
#> 119   119 10.18         0          3 0.4433333
#> 120   120 10.35         2          3 0.6400000
#> 121   121 10.38         3          1 0.3500000
#> 122   122 10.48         1          2 0.4550000
#> 123   123 10.56         2          1 0.7700000
#> 124   124 10.56         0          1 0.9600000
#> 125   125 10.77         2          0        NA
#> 126   126 10.77         0          0        NA
#> 127   127 10.97         0          0        NA
#> 128   128 11.03         2          1 0.0200000
#> 129   129 11.13         0          0        NA
#> 130   130 11.13         1          1 0.4400000
#> 131   131 11.20         2          1 0.7600000
#> 132   132 11.21         1          0        NA
#> 133   133 11.40         2          3 0.5933333
#> 134   134 11.55         1          1 0.1100000
#> 135   135 11.58         0          0        NA
#> 136   136 11.60         1          0        NA
#> 137   137 11.66         0          2 0.6500000
#> 138   138 11.69         0          3 0.4066667
#> 139   139 11.73         0          1 0.7900000
#> 140   140 11.75         1          1 0.7800000
#> 141   141 11.86         0          1 0.1900000
#> 142   142 11.99         0          0        NA
#> 143   143 12.04         0          1 0.8700000
#> 144   144 12.12         0          0        NA
#> 145   145 12.20         2          4 0.4925000
#> 146   146 12.21         2          3 0.3800000
#> 147   147 12.34         1          3 0.6933333
#> 148   148 12.38         1          1 0.6700000
#> 149   149 12.42         1          0        NA
#> 150   150 12.47         0          1 0.0600000
#> 151   151 12.65         2          3 0.5033333
#> 152   152 12.73         1          2 0.8900000
#> 153   153 12.78         1          2 0.0550000
#> 154   154 12.86         2          5 0.4100000
#> 155   155 12.91         3          3 0.2700000
#> 156   156 13.14         2          0        NA
#> 157   157 13.16         0          3 0.3466667
#> 158   158 13.19         1          2 0.5850000
#> 159   159 13.21         2          1 0.6100000
#> 160   160 13.23         1          0        NA
#> 161   161 13.24         2          1 0.8600000
#> 162   162 13.25         0          1 0.8100000
#> 163   163 13.26         1          0        NA
#> 164   164 13.27         1          0        NA
#> 165   165 13.30         1          0        NA
#> 166   166 13.31         1          3 0.6700000
#> 167   167 13.33         1          2 0.2900000
#> 168   168 13.33         2          0        NA
#> 169   169 13.33         0          0        NA
#> 170   170 13.35         1          1 0.9000000
#> 171   171 13.42         1          0        NA
#> 172   172 13.55         1          0        NA
#> 173   173 13.57         0          0        NA
#> 174   174 13.65         2          0        NA
#> 175   175 13.73         1          0        NA
#> 176   176 13.78         0          1 0.0600000
#> 177   177 13.80         1          0        NA
#> 178   178 13.82         1          0        NA
#> 179   179 13.84         0          0        NA
#> 180   180 13.88         2          0        NA
#> 181   181 13.95         1          3 0.5466667
#> 182   182 13.96         1          2 0.8650000
#> 183   183 13.97         0          3 0.5400000
#> 184   184 13.97         0          0        NA
#> 185   185 14.01         1          0        NA
#> 186   186 14.02         0          1 0.4400000
#> 187   187 14.13         2          2 0.6850000
#> 188   188 14.13         2          0        NA
#> 189   189 14.16         1          0        NA
#> 190   190 14.18         0          2 0.5550000
#> 191   191 14.30         5          0        NA
#> 192   192 14.44         2          2 0.4450000
#> 193   193 14.50         0          1 0.6900000
#> 194   194 14.55         2          0        NA
#> 195   195 14.76         3          0        NA
#> 196   196 14.78         1          0        NA
#> 197   197 14.92         2          0        NA
#> 198   198 14.93         3          1 0.6900000
#> 199   199 14.95         3          0        NA
#> 200   200 14.96         3          0        NA
#> 201   201 15.13         0          0        NA
#> 202   202 15.29         1          0        NA
#> 203   203 15.30         0          1 0.5800000
#> 204   204 15.41         1          0        NA
#> 205   205 16.16         1          0        NA
#> 206   206 16.25         1          0        NA
#> 207   207 16.37         0          2 0.4950000
#> 208   208 16.61         0          0        NA
#> 209   209 16.69         0          0        NA
#> 210   210 16.84         0          0        NA
#> 211   211 16.84         1          1 0.5600000
#> 212   212 16.91         0          0        NA
#> 213   213 16.91         0          1 0.2100000
#> 214   214 16.97         1          1 0.9200000
#> 215   215 17.40         0          0        NA
#> 216   216 17.46         1          0        NA
#> 217   217 18.17         1          0        NA
#> 218   218 18.36         0          0        NA
#> 219   219 18.62         0          1 0.2600000
#> 220   220 18.66         0          0        NA
#> 221   221 18.95         1          0        NA
#> 222   222 18.96         1          1 0.4700000
#> 223   223 19.03         0          0        NA
#> 224   224 19.46         0          1 0.7200000
#> 225   225 19.54         0          2 0.3200000
#> 226   226 19.70         1          0        NA
#> 227   227 19.81         0          0        NA
#> 228   228 19.91         1          3 0.5866667
#> 229   229 19.96         0          0        NA
#> 230   230 20.00         0          2 0.3550000
#> 231   231 20.01         0          0        NA
#> 232   232 20.14         0          0        NA
#> 233   233 20.33         1          0        NA
#> 234   234 20.43         1          0        NA
#> 235   235 20.45         0          0        NA
#> 236   236 20.49         0          0        NA
#> 237   237 20.68         2          0        NA
#> 238   238 20.77         0          0        NA
#> 239   239 20.89         1          0        NA
#> 240   240 20.95         2          0        NA

# Only the earliest successors, as for temporal motifs
sparse <- event_graph(dn, delta = 1, adjacency = "next")
sparse
#> # Event graph | 240 events | 124 adjacencies
#> # delta 1 | adjacency "next" | direction "respect" | sessions_ignored
#>  from_event to_event  via from_time to_time wait
#>           1       16  Dan      1.10    2.03 0.93
#>           3       10 Mira      0.42    0.83 0.41
#>           4       14 Iris      0.96    1.95 0.99
#>           6        9 Iris      0.50    0.78 0.28
#>           8       15 Kira      1.42    1.95 0.53
#>           9       18 Cara      1.31    2.07 0.76
```
