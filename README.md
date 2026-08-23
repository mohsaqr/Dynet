# Dynet

Temporal network construction, measurement and visualisation in R.

A static network says two people are connected. A temporal network says when,
for how long, and in which order — and refuses to let a path run backwards in
time. Aggregating time away inflates connectivity and hides the dynamics; every
verb here keeps time in the result.

## Two commitments

**Vertices are named, never numbered.** `dyn_paths(dn, from = "Ana")`. There is
no vertex index to look up first, and no result that hands you an integer where
you expected a person. (The aggregate edge table uses integer endpoints because
that is cograph's schema, but nothing in the public surface exposes them —
`as.data.frame()` returns names, in every layout.)

**Every verb returns a tidy data frame.** One row per observation, with the
columns you would expect. No matrices, no nested lists, no named list of
matrices when you ask for sessions. Nothing in this package asks you to reach
into an object with `$` or to subset a result to make it readable.

## Building a network

One constructor covers the four shapes relational logs arrive in. The shape is
inferred from the arguments you name.

```r
library(Dynet)

# Interval log: each row carries its own start and end
dynet(school_contacts)

# Contact log: instantaneous events, no duration
dynet(clicks, time = "timestamp")

# Threaded log: a post stays active until its thread falls silent
dynet(forum_posts, thread = "thread", nodes = forum_people)

# Co-presence log: actors sharing a group become connected
dynet(seminar_attendance, actor = "student", group = "seminar")
```

Column names are matched case-insensitively against a table of aliases, so
`Sender`/`Receiver`, `source`/`target` and `onset`/`terminus` all work without
being spelled out. Times may be numeric, `Date`, `POSIXct` or character
date-time strings; date-time input is converted to elapsed time in a unit
chosen to suit the span, and the unit is reported.

The threaded format is worth naming explicitly. Forum and chat data carry a
timestamp and no end, so the duration of a tie has to be derived. Dynet applies
the rule from Saqr and Nouri (2020): a post is active from the moment it appears
until the last post in the same thread, so a message that provoked a long
argument stays live longer than one that fell flat. Deriving that by hand takes
a grouped mutate before you can build anything; here it is one argument.

## Measuring

```r
dn <- dynet(school_contacts)

dyn_centrality(dn, measure = "degree")
dyn_centrality(dn, measure = c("degree", "betweenness"))
dyn_centrality(dn, measure = "closeness", scope = "temporal")

dyn_metrics(dn, measure = c("density", "reciprocity", "transitivity"))
dyn_events(dn)
dyn_durations(dn)
dyn_burstiness(dn)
dyn_paths(dn, from = "Ana")
dyn_reachability(dn)
dyn_mixing(forum, attribute = "role")
dyn_snapshots(dn, at = 3)
```

Ask for several measures in one call and they arrive stacked in one frame with
a `measure` column. Every result prints, summarises and plots:

```r
deg <- dyn_centrality(dn, measure = "degree")

summary(deg)                        # one row per vertex, with the peak time
summary(deg, by = "time")           # one row per time point
as.data.frame(deg)                  # the plain long frame
as.data.frame(deg, layout = "wide") # vertices by time, for export
plot(deg, top = 5)
```

### Snapshot scope and temporal scope

`scope = "snapshot"` measures the network as it stands in each bin, giving a
trajectory of ordinary centrality. `scope = "temporal"` measures the vertex
against time-respecting paths across the whole window. The second has no static
counterpart: it cannot travel backwards in time, so it is never inflated the way
a flattened network is.

### Two ways to sample a bin

`sample = "window"`, the default, counts an edge whose spell overlaps the bin at
all. `sample = "instant"` samples the network at the bin's left edge, which is
the convention `tsna` uses. Window sampling is the default because instant
sampling silently drops any edge that begins and ends between two sample points
— a real loss on bursty data.

## Drawing

**A `dynet` object is a cograph netobject.** Its class is
`c("dynet", "netobject", "cograph_network")` and it carries cograph's canonical
fields, so cograph renders it with no conversion:

```r
library(cograph)
splot(dn)                       # works directly
splot(dn, layout = "oval")      # every cograph argument applies
```

All node-link drawing in this package is cograph's. `plot()` adds the views
that are about *time* rather than about topology, and routes the topological
ones to `splot()`:

```r
plot(dn)                          # edge spells over time          (ggplot)
plot(dn, type = "activity")       # formation and dissolution      (ggplot)
plot(dn, type = "proximity")      # composite, see below           (cograph)

plot(dn, type = "network")        # the flattened network          (cograph)
plot(dn, type = "network", at = 13)  # one time bin                (cograph)
plot(dn, type = "snapshots")      # small multiples, shared layout (cograph)
plot(dyn_paths(dn, from = "Ana")) # the path tree                  (cograph)
```

### The proximity timeline

One composite figure rather than a line chart. Each time bin is reduced to one
dimension by classical scaling, so vertices that are interacting sit near one
another; the lines are then joined through time, and clusters appear as bands
travelling together.

```r
plot(dn, type = "proximity")
plot(dn, type = "proximity", measure = "betweenness", phases = 4)
plot(dn, type = "proximity", networks = FALSE, highlight = c("Ana", "Ben"))
```

Reading it:

- **Line thickness** follows a node-level measure — degree by default, any
  measure `dyn_centrality()` accepts. A vertex that is merely present looks
  different from one that is busy.
- **Vertical marks** are times at which edges formed, shaded by how many.
- **Names sit at the right-hand end** of each line instead of in a legend, so
  no distinction rests on colour alone even when the palette repeats.
- **The strip beneath** is the phase each network panel covers — the network's
  own sessions when it has them, otherwise equal thirds.
- **The panels beneath that** are one `cograph::splot()` per phase, sharing the
  line colours, so a band in the timeline can be traced to a group in the
  network.

**The line never leaves the corridor its measurements define.** The network is
measured at 120 overlapping slices by default. Corners are rounded by *cutting*
them — Chaikin's algorithm, where every point produced is a convex combination
of measured points — so the curve flows without ever overshooting a
measurement.

That is the difference from interpolating a spline through the same points. A
spline is free to travel anywhere between two knots: on evenly spaced slices an
`fmm` or `natural` spline overshoots the pair it is joining by around one
standard deviation, and even a monotone Hermite spline by about half of one. It
draws the network passing through places no slice ever put it. Corner-cutting
provably cannot, and there is a test asserting so.

Set `flow = 0` for sharp joints, or a larger number to round harder.

Each slice is standardised before the lines are drawn, so a vertical distance
means the same thing at one time as at another. Slice width defaults to a sixth
of the observation window, because scaling is only meaningful on a slice whose
network is connected — measured over one narrow bin most vertices are isolated
and their placement is arbitrary. `slices` and `window` are both arguments:
narrow the window to resolve more, at the cost of a noisier picture.

The figure needs roughly nine by six inches; below that it declines to draw and
says so.

Colour comes from a **`"dynet"` theme registered in cograph's theme registry**,
so it shows up in `cograph::list_themes()` and can be asked for by name from
any cograph call:

```r
cograph::list_themes()          # ... "nature", "dynet"
splot(dn, theme = "dynet")      # from a bare cograph call
plot(dn, type = "network", theme = "dark")   # or ask for another
```

Anything passed through `...` reaches `splot()` and overrides Dynet's defaults
— the same delegation contract `lagdynamics::plot_transitions()` uses.

Two things sit outside the theme and have to, which is worth knowing if you
edit this:

- `splot()` treats a directed netobject with no `$method` as a *transition*
  network and applies its TNA look — a per-state colour ramp and a number on
  every edge. Right for a transition matrix, wrong here where an edge weight
  is a count of meetings. The TNA block also runs *before* the theme block and
  fills `node_fill`, which the theme block then declines to overwrite, so a
  theme alone cannot undo it. Hence `tna_styling = FALSE`.
- A theme holds one `node_fill`. Colouring vertices by partition needs a
  vector, so that is passed separately — and only when a partition exists, so
  an unpartitioned network still takes its fill from whichever theme you ask
  for. The colours are Okabe–Ito; cograph's own `palette_colorblind()` is an
  interpolated ramp, not the Okabe–Ito set.

Set the vertex partition once at construction and cograph picks it up
everywhere:

```r
forum <- dynet(forum_posts, thread = "thread", nodes = forum_people,
               groups = "role")
splot(forum)                      # coloured by role, no further argument
```

### Palettes

`palette` is an argument on every plot, and you can override it with anything:

```r
plot(dn, type = "network")                          # "okabe", the default
plot(dn, type = "proximity", palette = "extended")  # ~12 distinct
plot(dn, type = "proximity", palette = "many")      # one per vertex, any n
plot(dn, type = "network",  palette = c("#D55E00", "#0072B2"))   # your own
plot(dn, type = "network",  palette = function(n) hcl(seq(0, 340, length = n), 80, 60))
```

All three built-ins begin with Okabe–Ito, so a small network looks the same
whichever you pick, and they are deterministic — no `sample()`, no seed, the
same network gets the same colours every run.

The choice is a measurable trade, not a matter of taste. Minimum distance
between any two colours in CIE Lab, where 2.3 is the just-noticeable
difference and 10 a comfortable categorical gap:

| palette | n | min ΔE | under deuteranopia |
|---|---|---|---|
| `"okabe"` | 9 | 26.4 | **7.3** |
| `"extended"` | 20 | 13.5 | 2.4 |
| `"many"` | 60 | **23.6** | 1.2 |
| evenly spaced hue ramp | 60 | 4.7 | 0.0 |
| every qualitative ColorBrewer palette concatenated | 60 | **0.4** | 0.4 |

Two things worth knowing before reaching for `"many"`:

- **Hue alone collapses under colour blindness.** An evenly spaced hue ramp is
  already below the just-noticeable difference at eight colours. Okabe–Ito
  holds because it varies *lightness*, not only hue.
- **`"many"` is not colour-blind safe and cannot be.** Sixty categories do not
  fit in the space dichromatic vision leaves. It is for grouping and
  decoration; the labels do the identifying. Beyond about twelve colours,
  identification is a matching-and-memory limit rather than a perceptual one,
  and no palette fixes it — use `highlight`, or set a partition with
  `dynet(groups = )` so colour is back to a handful of categories.

Labels take their colour from the fill — black or white, whichever has the
higher contrast ratio — so a vertex that lands on Okabe–Ito's ninth colour
(black) still has a readable name. Pass `label_color` to override.

Nothing depends on colour alone: the
network views pair colour with shape, the ggplot views with a line type, and
the proximity timeline names every line at its right-hand end.

Line type is deliberately *not* the second channel in the proximity view. Base
graphics scales dash length by line width, so a dashed line disintegrates
exactly where it is thinnest — and thin there means low activity, not missing
data. Solid lines plus direct labels say the true thing.

## What it depends on

`cograph` for rendering, `ggplot2` for the time-series views. Nothing else.

Every metric — geodesics, Brandes betweenness, PageRank, HITS, k-cores, Burt's
constraint, the dyad and triad censuses — is base R matrix algebra, so
measurement works on a machine with no graph package installed. `igraph`,
`sna`, `tsna` and `networkDynamic` appear only in `Suggests`, where the test
suite uses them to check the numbers.

## How the numbers were checked

All 78 kernel comparisons against `igraph` and `sna` agree, across directed and
undirected graphs at three sizes. Earliest-arrival times agree with
`tsna::tPath` on twenty source-network combinations. Two conventions differ
deliberately and are documented where they are implemented:

- **Closeness** uses the reachable-set normalisation from `igraph`.
  `sna::closeness()` sums distance over unreachable vertices too, so it returns
  zero for every vertex as soon as the graph is disconnected — and every
  snapshot of a temporal network is disconnected.
- **Isolates** report a closeness of zero rather than `NaN`, so that averaging a
  series does not propagate a missing value.

## References

Holme, P., & Saramäki, J. (2012). Temporal networks. *Physics Reports*, 519(3),
97–125.

Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora, V.
(2013). Graph metrics for temporal networks. In *Temporal Networks* (pp. 15–40).
Springer.

Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis to
understand and improve collaborative learning. *Proceedings of the Tenth
International Conference on Learning Analytics & Knowledge*, 314–319.

Saqr, M. (2024). Temporal network analysis: Introduction, methods and analysis
with R. In M. Saqr & S. López-Pernas (Eds.), *Learning Analytics Methods and
Tutorials*. Springer.
