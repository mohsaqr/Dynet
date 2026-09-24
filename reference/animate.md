# Animate a temporal network over its measurement grid

Draws the network bin by bin over the measurement grid and writes the
frames to an animated GIF or a video. The grid is the same four
arguments every measuring verb takes, so an animation shows exactly what
[`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
tabulates and what `plot(dn, type = "snapshots")` draws as a filmstrip,
with the bins joined by motion.

## Usage

``` r
animate(
  dn,
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL,
  sessions = c("bounded", "collapse"),
  layout = "spring",
  measure = NULL,
  tween = 6L,
  fps = 12,
  file = tempfile(fileext = ".gif"),
  loop = TRUE,
  width = 800L,
  height = 800L,
  res = 120,
  palette = "okabe",
  tie_states = TRUE,
  timeline = TRUE,
  absent = c("fade", "away", "hide"),
  isolates = c("fade", "show", "hide"),
  ease = c("dwell", "continuous"),
  max_displacement = 0.08,
  anchor_strength = 1,
  layout_args = list(),
  seed = 42L,
  ...
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- start, end, step, window:

  The measurement grid, as in
  [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md).
  `NULL`, the default, takes each from the network's own observation
  window and bin width.

- sessions:

  How to treat sessions, as in
  [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md):
  `"bounded"` (the default) or `"collapse"`. An animation draws calendar
  bins, so `"separate"` is not offered.

- layout:

  `"spring"` (the default), `"relaxed"`, `"circle"`, `"oval"` or
  `"groups"`, or a data frame of coordinates. See details.

- measure:

  What node size follows. `NULL`, the default, keeps every vertex the
  same size. The name of a snapshot node measure from
  [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md),
  such as `"degree"` or `"betweenness"`, computes it on the animation's
  own grid, so a vertex grows and shrinks bin by bin. A node-level
  result of
  [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
  is matched by vertex and time; one computed with `window = "all"`
  holds a single value per vertex, so every vertex keeps one size for
  the whole film, for instance its degree over the whole period. The
  name of a numeric vertex attribute supplied through `dynet(nodes = )`
  does the same with the attribute's values, which is how a two-tier
  size (a circle of interest against everyone else) is drawn.

- tween:

  Frames drawn per bin. One positive whole number, `6` by default.

- fps:

  Frames per second. One positive number, `12` by default.

- file:

  Path to write to, ending in `.gif`, `.mp4` or `.webm`. Defaults to a
  GIF in the session's temporary directory; nothing is written to the
  working directory unless the path says so.

- loop:

  For a GIF: `TRUE`, the default, repeats for ever; `FALSE` plays once;
  a positive whole number repeats that many times. Ignored for a video.

- width, height:

  Frame size in pixels, `800` by default. A video needs both to be even.

- res:

  Resolution passed to
  [`grDevices::png()`](https://rdrr.io/r/grDevices/png.html), `120` by
  default.

- palette:

  Palette specification, as in
  [`plot.dynet()`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md).
  `"okabe"` by default.

- tie_states:

  Whether to draw forming, persisting and dissolving ties differently.
  `TRUE` by default.

- timeline:

  Whether to draw the timeline strip. `TRUE` by default.

- absent:

  How a vertex is drawn in a bin where it is not present. `"fade"`, the
  default, keeps it in place at a quarter of its opacity; `"away"` parks
  it, invisible, at the edge of the layout on its own side and glides it
  in over the transition in which it arrives and out over the one in
  which it leaves, opaque for most of the glide and, with
  `tie_states = TRUE`, wearing a thick ring in the forming colour on the
  way in and the dissolving colour on the way out; `"hide"` keeps it in
  place, invisible.

- isolates:

  How a vertex that is present but has no tie in a bin is drawn.
  `"fade"`, the default, at a third of its opacity; `"show"` at full
  opacity; `"hide"` invisible.

- ease:

  `"dwell"`, the default, holds each bin still before it changes;
  `"continuous"` keeps everything moving, with positions on a spline
  through the bins and linear fades. See details.

- max_displacement:

  How far a vertex may move between bins under `layout = "relaxed"`, in
  layout units. `0.08` by default; ignored otherwise.

- anchor_strength:

  How strongly a vertex is pulled back towards its previous position
  under `layout = "relaxed"`. `1` by default; ignored otherwise.

- layout_args:

  A named list of further arguments for
  [`cograph::layout_spring()`](https://sonsoles.me/cograph/reference/layout_spring.html),
  used by `layout = "spring"` and `"relaxed"`: `repulsion`,
  `attraction`, `area`, `gravity`, `iterations` or `cooling`. Empty by
  default. A larger `repulsion` opens a dense core.

- seed:

  Seed for the spring layouts, so `"spring"` and `"relaxed"` are
  reproducible; `42` by default. Under a seed the caller's random state
  is restored on exit. `NULL` draws from the current random state
  instead and leaves it advanced, which is what makes successive
  unseeded calls differ.

- ...:

  Passed to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
  for every frame, so the whole drawing surface of
  [`plot.dynet()`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md)'s
  network view is available. `labels` may also be the name of a vertex
  attribute supplied through `dynet(nodes = )`, such as a short form of
  each name, which is then drawn in place of the vertex names; `label`
  itself is reserved by the node table, so give the attribute another
  name. Seven arguments are read as the animation's baselines rather
  than passed on: `edge_width_range` (the widths the weight scale maps
  onto, `c(0.5, 3.5)` by default), `edge_alpha` (`0.6`), `edge_color`
  (the colour of a tie when `tie_states = FALSE`), `node_size` (the size
  a vertex has without a measure) and `node_size_range` (the smallest
  and largest radius a measure maps onto; by default 0.55 and 1.8 times
  `node_size`), `node_alpha` (`1`) and `node_border_color` (`"white"`),
  the last two being what `absent` and `isolates` fade from.

## Value

An object of class `"dynet_animation"`: a tidy data frame with one row
per bin and columns `bin`, `frame` (the first rendered frame of the
bin), `time` (the bin's label on the network's time scale),
`window_start` and `window_end` (its bounds), `nodes` (vertices
present), `idle` (of those, vertices with no tie), `ties` (ties drawn),
`forming` (ties not active in the previous bin, `NA` for the first),
`dissolving` (ties not active in the next bin, `NA` for the last), and
`file` (the same on every row). These are counts of what the picture
shows, not the risk-set accounting of
[`events()`](https://pak.dynasite.org/Dynet/reference/events.md). The
rendered-frame schedule is available through
`as.data.frame(x, what = "frames")`. Returned invisibly, since writing
the file is the verb's purpose.

## Details

**Frames.** Each bin is drawn `tween` times. Between one bin and the
next the vertices glide to their new positions, a tie that is about to
appear fades in and one that is about to vanish fades out, and a vertex
whose measure changes grows or shrinks. Under `ease = "dwell"`, the
default, the motion follows the smoothstep curve, so each bin holds
still before it starts to change and the bins can be read one by one.
Under `ease = "continuous"` nothing holds still: positions follow a
Catmull-Rom spline through the bins, so a vertex moving across several
bins traces one smooth path, and fades are linear. `tween = 1` gives one
frame per bin with hard cuts. A film that feels episodic usually has a
grid whose bins do not overlap; a sliding window, `step` smaller than
`window`, smooths the data itself, since a tie then persists across
several bins.

**Layouts.** Under every layout but `"relaxed"` a vertex keeps one
position for the whole animation, so the only thing that moves is the
ties; those are the layouts to read structure from. `"spring"`, the
default, lays out the union of every frame once with
[`cograph::layout_spring()`](https://sonsoles.me/cograph/reference/layout_spring.html),
so pairs that met often sit close. `"circle"` and `"oval"` are rings, in
vertex order. `"groups"` puts each partition on its own ring and needs a
network built with `groups = `. `"relaxed"` lays each frame out again,
seeded from the previous one and held near it by `max_displacement` and
`anchor_strength`, then smooths every vertex's path with a centred
triangular kernel over one bin each side; clusters can form and dissolve
without vertices jumping, and no vertex moves further than
`max_displacement` between consecutive bins. Each relaxed frame is
framed by its active vertices: a vertex that is absent or has no tie in
the bin is held at the border of that frame rather than drifting outward
under repulsion, which would shrink the picture. `layout_args` tunes the
spring layout for both. A data frame with columns `name` (or `node`),
`x` and `y` fixes the positions yourself.

**What is drawn.** Tie width follows weight on one scale fixed across
the whole animation, so a tie of the same weight has the same width in a
quiet frame and a busy one. With `tie_states = TRUE` a tie forming
during a transition is dotted and green, one persisting is solid and
grey, and one dissolving is dashed and vermilion, so the distinction
survives without colour. With `measure` given, node size follows that
measure, again on one scale across every frame, with the area of the
circle proportional to the measure's position in its range; see the
argument for the three forms it takes.

**Absence and idleness.** A vertex that is not present in a bin, under
declared vertex activity or observation bounds, is drawn as `absent`
says: faded in place, parked out of sight at the edge of the layout and
gliding in when it arrives and out when it leaves, or hidden in place. A
network built without vertex activity has every vertex present in every
bin; `set_vertex_spells(dn, "ties")` declares each vertex present from
its first tie to its last. A vertex that is present but has no tie in a
bin is drawn as `isolates` says. With `timeline = TRUE` a strip under
the network shows the grid with a marker at the current time and the key
to the drawing.

**Files.** The extension of `file` chooses the encoder: `.gif` is
written by the gifski package, `.mp4` and `.webm` by the av package. A
video needs even pixel dimensions. Writing the file is the point of the
verb, but the tidy bin table is still what comes back, so the animation
can be described without opening it.

## Conditions

Raises `dynet_unknown_format` for a `file` extension other than `.gif`,
`.mp4` or `.webm`; `dynet_needs_gifski` or `dynet_needs_av` when the
encoder that extension needs is not installed; `dynet_needs_cograph`
when cograph is not; `dynet_empty_result` when the grid holds no bin
that can be drawn; `dynet_unknown_attribute` for `layout = "groups"` on
a network without a partition or a `labels` naming no vertex attribute;
`dynet_missing_column` and `dynet_unknown_node` for a coordinate table
that is incomplete; `dynet_unknown_measure` for a `measure` that is
neither a measure
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
offers nor a numeric vertex attribute, and whatever
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
raises for one it refuses; `dynet_bad_input` for a
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
result that is not node-level or lands on none of the bins, and a
warning of class `dynet_partial_measure` when it lands on only some; and
`dynet_bad_input` for a non-positive `fps`, `tween`, `width`, `height`
or `res`, an odd video size, a `loop` that is neither logical nor a
positive whole number, or a negative `max_displacement` or
`anchor_strength`.

## See also

[`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
for the same grid as a table,
[`plot.dynet()`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md)
with `type = "snapshots"` for it as a static filmstrip, and
[`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
for the measures node size can follow.

## Examples

``` r
if (requireNamespace("gifski", quietly = TRUE) &&
  requireNamespace("cograph", quietly = TRUE)) {
  dn <- dynet(school_contacts)
  frames <- animate(dn, step = 4, window = 4, tween = 2)
  frames
  summary(frames)
}
#>   bins frames fps seconds tween  ease layout format measure first_time
#> 1    6     12  12       1     2 dwell spring    gif    <NA>          0
#>   last_time min_ties max_ties  turnover                                 file
#> 1        20       17       51 0.5490196 /tmp/RtmpbC9cDu/file1e841152de6a.gif
# \donttest{
if (requireNamespace("av", quietly = TRUE) &&
  requireNamespace("cograph", quietly = TRUE)) {
  dn <- dynet(school_contacts)
  video <- animate(dn, step = 2, window = 4, measure = "degree",
    layout = "relaxed",
    file = tempfile(fileext = ".mp4"))
  summary(video)
}
#>   bins frames fps seconds tween  ease  layout format measure first_time
#> 1   11     66  12     5.5     6 dwell relaxed    mp4  degree          0
#>   last_time min_ties max_ties  turnover                                 file
#> 1        20       17       54 0.3074074 /tmp/RtmpbC9cDu/file1e84550e49e4.mp4
# }
```
