# Animating a temporal network

In this article we animate two temporal networks with
[`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md): a
classroom of fourteen students whose contacts are brief, and a course
forum whose participants arrive and leave over ten weeks.
[`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md) takes
the same grid as every measuring function, `start`, `end`, `step` and
`window`, and writes a GIF or a video; a GIF needs the `gifski` package
and a video needs `av`.

## Data

`school_contacts` is a simulated interval log of 240 face-to-face
contacts among fourteen students, with a start and an end for each
contact. To build the network, we call
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) with the
log.

``` r

library(Dynet)
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

## The bins

To see the bins an animation will show, we call
[`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
with `step` for the interval between bins and `window` for the length of
time each bin covers, and
[`summary()`](https://rdrr.io/r/base/summary.html) on the result.

``` r

bins <- snapshots(dn, step = 2, window = 4)
summary(bins)
#>    time ties nodes weight
#> 1     0   29    14     31
#> 2     2   33    14     39
#> 3     4   50    14     61
#> 4     6   54    14     69
#> 5     8   45    14     59
#> 6    10   54    14     76
#> 7    12   51    14     70
#> 8    14   40    14     50
#> 9    16   24    14     25
#> 10   18   25    14     25
#> 11   20   17    14     17
```

A window of four units moved two units at a time gives eleven
overlapping bins. The number of active ties rises from 29 in the first
bin to 54 in the bins that begin at 6 and at 10, and falls to 17 in the
last.

## The animation

To write the animation, we call
[`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md) with
the same grid and `file` for the output path; the extension selects the
encoder, `.gif` here and `.mp4` or `.webm` for a video. The result is a
table with one row per bin.

``` r

film <- animate(dn, step = 2, window = 4, file = "animating_files/classroom.gif")
film
#> # Animation of 11 bins in 66 frames at 12 fps | spring layout | gif | time in step
#> # animating_files/classroom.gif
#>  bin frame time window_start window_end nodes idle ties forming dissolving
#>    1     1    0            0          4    14    0   29      NA         10
#>    2     7    2            2          6    14    0   33      14          9
#>    3    13    4            4          8    14    0   50      26          9
#>    4    19    6            6         10    14    0   54      13         20
#>    5    25    8            8         12    14    0   45      11         11
#>    6    31   10           10         14    14    0   54      20         12
#>    7    37   12           12         16    14    0   51       9         15
#>    8    43   14           14         18    14    0   40       4         25
#>    9    49   16           16         20    14    0   24       9          9
#>   10    55   18           18         22    14    0   25      10          8
#>   11    61   20           20         24    14    0   17       0         NA
```

![](animating_files/classroom.gif)

The `ties` column agrees with the snapshot table. `forming` counts the
ties of a bin that were not active in the bin before and `dissolving`
the ties that are not active in the bin after; the first bin has no
predecessor and the last no successor, so those cells are `NA`. The
third bin, which begins at 4, holds 50 ties, 26 of them new and 9 gone
by the next bin.

In every frame a forming tie is dotted and green, a persisting tie solid
and grey, and a dissolving tie dashed and vermilion, so the state is
carried by line type as well as colour. Tie width follows weight on one
scale across the whole animation. Each bin is drawn `tween` times, six
by default, forming ties fade in and dissolving ties fade out over the
transition, and a timeline under the network marks the current bin.

To describe the animation in one row, we call
[`summary()`](https://rdrr.io/r/base/summary.html) on the result.

``` r

summary(film)
#>   bins frames fps seconds tween  ease layout format measure first_time
#> 1   11     66  12     5.5     6 dwell spring    gif    <NA>          0
#>   last_time min_ties max_ties  turnover                          file
#> 1        20       17       54 0.3074074 animating_files/classroom.gif
```

Eleven bins at six frames each give 66 frames, 5.5 seconds at 12 frames
per second. `turnover` is the median share of a bin’s ties that were not
active in the bin before; it is 0.31 here.

## Vertex size

To let vertex size follow a centrality computed in each bin, we set
`measure` to the name of any snapshot measure of
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md).
The area of the circle is proportional to the measure, on one scale
across every frame.

``` r

per_bin <- animate(dn, step = 2, window = 4, measure = "degree",
                   file = "animating_files/classroom-degree.gif")
summary(per_bin)
#>   bins frames fps seconds tween  ease layout format measure first_time
#> 1   11     66  12     5.5     6 dwell spring    gif  degree          0
#>   last_time min_ties max_ties  turnover                                 file
#> 1        20       17       54 0.3074074 animating_files/classroom-degree.gif
```

![](animating_files/classroom-degree.gif)

A size that changes from bin to bin shows who is active; a constant size
shows who is central over the whole period and leaves the ties as the
only moving element. To obtain whole-period degree, we call
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
with `window = "all"`, and pass the result to `measure`.

``` r

whole <- dyn_centrality(dn, measure = "degree", window = "all")
print(whole, n = 14)
#> # Degree (node-level)
#> # 14 vertices | 1 time points, 21.52 per bin | time in step
#>  time  node measure value
#>     0   Ana  degree    16
#>     0   Ben  degree    15
#>     0  Cara  degree    17
#>     0   Dan  degree    18
#>     0   Eve  degree    17
#>     0  Finn  degree    15
#>     0  Gita  degree    13
#>     0  Hugo  degree    15
#>     0  Iris  degree    15
#>     0 Jonas  degree    18
#>     0  Kira  degree    17
#>     0   Leo  degree    12
#>     0  Mira  degree    16
#>     0  Nils  degree    16
```

``` r

fixed <- animate(dn, step = 2, window = 4, measure = whole,
                 file = "animating_files/classroom-whole.gif")
summary(fixed)
#>   bins frames fps seconds tween  ease layout format
#> 1   11     66  12     5.5     6 dwell spring    gif
#>                        measure first_time last_time min_ties max_ties  turnover
#> 1 Degree over the whole period          0        20       17       54 0.3074074
#>                                  file
#> 1 animating_files/classroom-whole.gif
```

![](animating_files/classroom-whole.gif)

Dan and Jonas have 18 distinct contacts over the period and Leo 12, so
Dan and Jonas are the largest circles in every frame and Leo the
smallest.

## Layout

Under `layout = "spring"`, the default, the union of every bin is laid
out once and every frame reuses those positions, so only the ties move
and frames are comparable. Under `layout = "relaxed"`, each bin is laid
out again, seeded from the bin before and pulled back towards it, so
groups gather and drift apart. No vertex moves further than
`max_displacement` between bins, 0.08 layout units by default.

``` r

drift <- animate(dn, step = 2, window = 4, measure = "degree",
                 layout = "relaxed",
                 file = "animating_files/classroom-relaxed.mp4")
summary(drift)
#>   bins frames fps seconds tween  ease  layout format measure first_time
#> 1   11     66  12     5.5     6 dwell relaxed    mp4  degree          0
#>   last_time min_ties max_ties  turnover                                  file
#> 1        20       17       54 0.3074074 animating_files/classroom-relaxed.mp4
```

The relaxed layout suits a network whose structure changes; the fixed
layout suits one whose structure holds while its activity changes, which
is the case of the classroom.

## Presence

The forum of `mooc_posts` is threaded: a reply stays active until its
discussion falls silent, and participants join and leave over ten weeks.
To build it, we call
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) with
`min_thread_posts = 2` to drop threads that never became an exchange,
`nodes` for the participant table and `groups` for the experience level
that colours the vertices, and restrict it to the participants with more
than 20 distinct contacts with
[`induce_subgraph()`](https://pak.dynasite.org/Dynet/reference/induce_subgraph.md).

``` r

dn_full <- dynet(mooc_posts, from = "sender", to = "receiver",
                 time = "timestamp", thread = "discussion",
                 nodes = mooc_people, time_unit = "days",
                 groups = "expert_level", min_thread_posts = 2)
forum <- induce_subgraph(dn_full, degree > 20)
forum
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 45 vertices | 686 edge spells | 428 distinct pairs
#> # observed from 0.1138889 to 72.01111 days, binned every 1
#> # vertex attributes: experience, expert_level, groups
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

The network has 45 vertices and 686 spells on 428 pairs, observed from
day 0.11 to day 72.01. The log records when each participant posted but
not when they joined or left, so all 45 are treated as present
throughout. To declare each participant present from their first tie to
their last, we call
[`set_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/set_vertex_spells.md)
with `"ties"`, and read the spells back with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) and
`what = "vertex_spells"`.

``` r

forum <- set_vertex_spells(forum, "ties")
spans <- as.data.frame(forum, what = "vertex_spells")
head(spans)
#>   vertex_spell node     start      end duration instant session onset_censored
#> 1            1    1  4.120139 71.40625 67.28611   FALSE    <NA>          FALSE
#> 2            2  100 12.842361 70.53958 57.69722   FALSE    <NA>          FALSE
#> 3            3   11  4.061806 71.43819 67.37639   FALSE    <NA>          FALSE
#> 4            4  116  3.164583 70.53958 67.37500   FALSE    <NA>          FALSE
#> 5            5   13 18.147222 72.01111 53.86389   FALSE    <NA>          FALSE
#> 6            6  137 11.107639 69.47778 58.37014   FALSE    <NA>          FALSE
#>   terminus_censored
#> 1             FALSE
#> 2             FALSE
#> 3             FALSE
#> 4             FALSE
#> 5             FALSE
#> 6             FALSE
```

Participant 1 is present from day 4.12 to day 71.41, participant 13 from
day 18.15 to day 72.01.

`absent` decides how a participant is drawn in a bin where they are not
present: `"fade"`, the default, keeps them in place at a quarter
opacity; `"away"` parks them out of sight and moves them in over the
transition in which they arrive and out over the one in which they
leave. To write the animation with a seven-day window moved two days at
a time, we call
[`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md) with
`absent = "away"`, `labels = FALSE` to omit the identifiers, and three
Okabe-Ito colours for the three levels in `palette`.

``` r

arrivals <- animate(forum, start = 0, end = 70, step = 2, window = 7,
                    measure = "degree", absent = "away", labels = FALSE,
                    palette = c("#E69F00", "#56B4E9", "#CC79A7"),
                    file = "animating_files/forum.mp4")
print(arrivals, n = 36)
#> # Animation of 36 bins in 216 frames at 12 fps | spring layout | mp4 | time in days
#> # node size follows degree
#> # animating_files/forum.mp4
#>  bin frame time window_start window_end nodes idle ties forming dissolving
#>    1     1    0            0          7    29    0   53      NA          0
#>    2     7    2            2          9    29    0   59       6          0
#>    3    13    4            4         11    29    0   66       7          0
#>    4    19    6            6         13    37    0   81      15          4
#>    5    25    8            8         15    38    0   95      18          0
#>    6    31   10           10         17    39    0  101       6          6
#>    7    37   12           12         19    41    0  113      18          0
#>    8    43   14           14         21    41    0  131      18          9
#>    9    49   16           16         23    41    0  140      18         13
#>   10    55   18           18         25    42    0  134       7          3
#>   11    61   20           20         27    43    1  143      12          3
#>   12    67   22           22         29    45    1  154      14         13
#>   13    73   24           24         31    45    1  158      17          1
#>   14    79   26           26         33    45    1  180      23          5
#>   15    85   28           28         35    45    2  195      20         10
#>   16    91   30           30         37    45    2  201      16         21
#>   17    97   32           32         39    45    2  193      13         13
#>   18   103   34           34         41    44    3  186       6          6
#>   19   109   36           36         43    44    3  195      15          2
#>   20   115   38           38         45    44    3  196       3          5
#>   21   121   40           40         47    44    2  229      38         12
#>   22   127   42           42         49    44    2  242      25          6
#>   23   133   44           44         51    44    0  275      39          4
#>   24   139   46           46         53    44    0  276       5          4
#>   25   145   48           48         55    44    0  276       4         27
#>   26   151   50           50         57    44    0  251       2         34
#>   27   157   52           52         59    44    0  220       3         18
#>   28   163   54           54         61    44    0  208       6          9
#>   29   169   56           56         63    44    0  207       8          3
#>   30   175   58           58         65    44    0  204       0         25
#>   31   181   60           60         67    44    0  181       2         22
#>   32   187   62           62         69    44    0  160       1          7
#>   33   193   64           64         71    44    0  160       7          1
#>   34   199   66           66         73    44    0  164       5          7
#>   35   205   68           68         75    44    0  157       0         87
#>   36   211   70           70         77    34    0   70       0         NA
```

With presence declared, `nodes` counts the participants present in each
bin: 29 in the first, 45 from the bin that begins on day 22, and 44 from
the bin that begins on day 34, when one participant’s last tie has
passed. `idle` counts the participants present without an active tie and
stays between 0 and 3. Active ties rise from 53 in the first bin to 276
in the bins that begin on days 46 and 48 and fall to 70 in the last.

``` r

summary(arrivals)
#>   bins frames fps seconds tween  ease layout format measure first_time
#> 1   36    216  12      18     6 dwell spring    mp4  degree          0
#>   last_time min_ties max_ties   turnover                      file
#> 1        70       53      276 0.06735751 animating_files/forum.mp4
```

Thirty-six bins at six frames each give 216 frames, 18 seconds, with a
turnover of 0.07.

## Smoothing

An animation reads as separate pictures for two reasons, each with its
own remedy. The first is the grid. With `window` equal to `step` the
bins tile the period and a short tie appears and vanishes; with `window`
larger than `step` the bins overlap and each frame carries part of the
previous one. To compare, we write the forum with a two-day window that
tiles.

``` r

tiled <- animate(forum, start = 0, end = 70, step = 2, window = 2,
                 measure = "degree", absent = "away", labels = FALSE,
                 palette = c("#E69F00", "#56B4E9", "#CC79A7"),
                 file = "animating_files/forum-tiled.mp4")
print(tiled, n = 6)
#> # Animation of 36 bins in 216 frames at 12 fps | spring layout | mp4 | time in days
#> # node size follows degree
#> # animating_files/forum-tiled.mp4
#>  bin frame time window_start window_end nodes idle ties forming dissolving
#>    1     1    0            0          2     7    0   10      NA          0
#>    2     7    2            2          4    14    0   22      12          0
#>    3    13    4            4          6    29    0   44      22          0
#>    4    19    6            6          8    29    0   58      14          4
#>    5    25    8            8         10    29    1   56       2          0
#>    6    31   10           10         12    34    1   71      15          6
#> # 30 more bins.
summary(tiled)
#>   bins frames fps seconds tween  ease layout format measure first_time
#> 1   36    216  12      18     6 dwell spring    mp4  degree          0
#>   last_time min_ties max_ties   turnover                            file
#> 1        70       10      242 0.09504132 animating_files/forum-tiled.mp4
```

The tiled animation opens with 7 participants and 10 ties where the
sliding one opens with 29 and 53, and its turnover is 0.10 against 0.07.
Both are low because a threaded tie lasts for the life of its
discussion; the classroom, a contact network, has a turnover of 0.31 on
a comparable grid.

The second reason is the easing. Under `ease = "dwell"`, the default,
each bin holds still before it changes. Under `ease = "continuous"`
nothing holds still: positions follow a spline through the bins (Catmull
and Rom, 1974) and fades are linear.

``` r

flowing <- animate(forum, start = 0, end = 70, step = 2, window = 7,
                   measure = "degree", absent = "away", labels = FALSE,
                   layout = "relaxed", ease = "continuous",
                   palette = c("#E69F00", "#56B4E9", "#CC79A7"),
                   file = "animating_files/forum-continuous.mp4")
summary(flowing)
#>   bins frames fps seconds tween       ease  layout format measure first_time
#> 1   36    216  12      18     6 continuous relaxed    mp4  degree          0
#>   last_time min_ties max_ties   turnover                                 file
#> 1        70       53      276 0.06735751 animating_files/forum-continuous.mp4
```

A relaxed layout under continuous easing gives the most continuous
motion, and the animation in which no single bin can be read from a
frame.

## Choosing the arguments

| Argument | Value | Use when |
|----|----|----|
| `layout` | `"spring"` | the structure holds and the activity changes |
|  | `"relaxed"` | groups form and dissolve |
| `measure` | a measure name | vertex size should show who is active in each bin |
|  | a whole-period result | vertex size should show who is central over the period |
| `absent` | `"fade"` | the position of absent vertices should stay visible |
|  | `"away"` | arrivals and departures are the subject |
| `window` | equal to `step` | each frame should show one bin |
|  | larger than `step` | ties should persist across frames |
| `ease` | `"dwell"` | bins are to be read one by one |
|  | `"continuous"` | motion is to be read |
| `file` | `.gif` | a short animation that must play without a video player |
|  | `.mp4` or `.webm` | a long animation |

## References

Catmull, E., & Rom, R. (1974). A class of local interpolating splines.
In R. E. Barnhill & R. F. Riesenfeld (Eds.), *Computer aided geometric
design* (pp. 317–326). Academic Press.
