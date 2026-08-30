# Draw a temporal network

Nine views, each answering a different question.

- `"events"`:

  Every contact as a link drawn at the moment it fires, with actors on
  the vertical axis. A link leaves its source in the source's colour and
  arrives in the target's.

- `"timeline"`:

  Edge activity as an intensity heatmap, one row per pair. This is the
  view a static network cannot give you: it shows at a glance whether
  the network was busy throughout or concentrated in a few bursts.

- `"activity"`:

  Edges forming and dissolving over time.

- `"network"`:

  The network as a node-link diagram, drawn by
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).
  With no `at`, the whole window is flattened into one picture – useful
  as a reference point, and as a reminder of how much it overstates,
  since every tie appears simultaneous. With `at`, only that time bin is
  drawn.

- `"snapshots"`:

  Small multiples, one
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
  per time bin, laid out on shared coordinates so positions are
  comparable across panels.

- `"layers"`:

  The multilayer view: one network per time slice, drawn as a stack of
  layers in which each vertex appears once per slice and is joined to
  its own copy in the next by an identity arc of weight `omega`.

- `"heatmap"`:

  The matrix counterpart of `"layers"`: each slice is a tilted heatmap
  plane rather than a node-link diagram.

- `"stack"`:

  The same slices projected as a node-link stack, each vertex keeping
  one colour through the whole stack so it can be followed between
  planes.

- `"proximity"`:

  Vertices placed on a vertical line at each time point according to how
  close they are in the network, and joined through time. Clusters
  appear as bands of lines travelling together.

All node-link rendering is cograph's. A `dynet` object is a cograph
netobject, so `cograph::splot(dn)` works directly and every one of its
rendering arguments is available here through `...`.

## Usage

``` r
# S3 method for class 'dynet'
plot(
  x,
  type = c("timeline", "events", "activity", "network", "snapshots", "proximity",
    "layers", "heatmap", "stack"),
  at = NULL,
  start = NULL,
  end = NULL,
  top = 40L,
  step = NULL,
  omega = 1,
  bins = NULL,
  link = c("hook", "arc", "chevron", "wave", "bracket"),
  time = c("bin", "event", "clock"),
  aggregate = TRUE,
  nest = c("pair", "column"),
  split = 0.8,
  blend = FALSE,
  weight = TRUE,
  node_size = NULL,
  node_shape = NULL,
  node_fill = NULL,
  node_border_color = NULL,
  node_border_width = NULL,
  node_alpha = NULL,
  edge_color = NULL,
  edge_alpha = NULL,
  edge_width = NULL,
  edge_width_range = NULL,
  edge_style = NULL,
  curvature = NULL,
  curve_pivot = NULL,
  label_size = NULL,
  label_color = NULL,
  label_fontface = NULL,
  panels = 9L,
  measure = "degree",
  phases = NULL,
  networks = TRUE,
  events = TRUE,
  labels = TRUE,
  highlight = NULL,
  slices = 120L,
  window = NULL,
  flow = 2L,
  palette = "okabe",
  default_dist = 2,
  base_size = 12,
  style = .dyn_style(),
  ...
)
```

## Arguments

- x:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- type:

  One of `"timeline"`, `"events"`, `"activity"`, `"network"`,
  `"snapshots"`, `"layers"`, `"heatmap"`, `"stack"` or `"proximity"`.

- at:

  For `"network"`, the time to draw. `NULL` draws the whole window
  flattened.

- start, end:

  Window the plot to `[start, end]` before drawing. Either may be
  `NULL`, which keeps that side of the observed range. Every view is
  windowed, and an empty window is an error rather than an empty panel.

- top:

  For the timeline, draw only the `top` busiest vertex pairs.

- step:

  For `"layers"`, `"heatmap"` and `"stack"`, the width of each time
  slice. `NULL` uses the construction interval. At least two slices are
  needed, so too wide a `step` is an error rather than a single panel.

- omega:

  For `"layers"`, the weight on the identity arcs carrying a vertex
  between adjacent slices, that is, the interlayer coupling.

- bins:

  Number of equal time bins for `"timeline"` and `"events"`. `NULL` uses
  the network's own interval.

- link:

  Link glyph for `"events"`: `"hook"` (default), `"arc"`, `"chevron"`,
  `"wave"` or `"bracket"`.

- time:

  Time axis for `"events"`. `"bin"` groups onsets into equal windows and
  keeps duration honest, `"event"` gives one evenly spaced column per
  distinct onset, `"clock"` uses true positions.

- aggregate:

  For `"events"`, fold repeat firings of one pair inside one column into
  a single link. Binning merges distinct onsets, and without this they
  stack as parallel bows carrying no extra reading.

- nest:

  For `"events"`, which links are fanned apart. `"pair"` fans only links
  joining the same two rows in the same column; `"column"` fans every
  link sharing a column.

- split:

  For `"events"`, the share of each link that keeps its source colour
  before switching to its target's, so direction reads without
  arrowheads.

- blend:

  For `"events"`, fade between the two endpoint colours instead of
  switching at a boundary.

- weight:

  For `"events"`, scale alpha and width by how often the pair occurs
  across the network, so one-off links recede and habitual ones stand
  out.

- node_size, node_shape, node_fill, node_border_color,
  node_border_width, node_alpha:

  Node aesthetics, named as in
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).
  `NULL` uses the view's own default. For the node-link views these are
  forwarded to splot.

- edge_color, edge_alpha, edge_width, edge_width_range, edge_style:

  Link aesthetics, named as in
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).
  An `edge_color` overrides the source-to-target colour run with one
  colour.

- curvature, curve_pivot:

  Bow geometry, as in
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).
  `curvature` is the base bow as a fraction of the column gap and `0`
  draws straight links; `curve_pivot` slides where the bow peaks.

- label_size, label_color, label_fontface:

  Axis label aesthetics, named as in
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).

- panels:

  For snapshots, the maximum number of panels to draw. Bins are sampled
  evenly across the window and the choice is reported.

- measure:

  For the proximity view, the node-level measure that line thickness
  follows. Any measure
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md)
  accepts at snapshot scope; the temporal-scope-only measures `"reach"`
  and `"reach_count"` are not available here, because the view redraws
  the measure over many short slices.

- phases:

  For the proximity view, how many phases to split the window into for
  the network panels. `NULL` uses the network's sessions when it has
  them and three phases otherwise.

- networks:

  Whether the proximity view draws a network panel per phase.

- events:

  Whether the proximity view marks the times edges formed.

- labels:

  Whether vertices are named in place of a legend: at the right-hand end
  of each line in the proximity view, and beside each node in the
  `"layers"` and `"stack"` views.

- highlight:

  Vertex names to draw in colour in the proximity view, with the rest in
  grey.

- slices:

  How many times the proximity view measures the network across the
  window. Smoothness comes from measuring often, never from
  interpolation. `NULL` measures once per time bin.

- window:

  Width of each proximity slice. `NULL` uses a sixth of the observation
  window, or the bin width if that is wider: scaling is only meaningful
  on a slice whose network is connected, and over one narrow bin most
  vertices are isolated.

- flow:

  How much to round the corners of each proximity line. Rounding only
  ever takes convex combinations of measurements, so it softens the
  joints without letting the curve overshoot one. `0` leaves them sharp.

- palette:

  Colours for vertices and lines: `"okabe"` (the default, nine
  colour-blind safe colours, recycled), `"extended"` (hue varied with
  lightness, about twelve distinct), `"many"` (packed for separation,
  any number, not colour-blind safe), your own vector of colours, or a
  function of `n` returning `n` colours.

- default_dist:

  Distance assumed between vertices with no path between them, in the
  proximity view.

- base_size:

  Base font size for the ggplot views.

- style:

  A base-graphics style list from `.dyn_style()`, used by the proximity
  view.

- ...:

  Passed to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
  for the network, snapshot and proximity views.

## Value

For `"timeline"`, `"events"`, `"activity"` and `"heatmap"`, a `ggplot`
object, which prints itself when the call is not assigned. For
`"network"`, `"snapshots"`, `"layers"`, `"stack"` and `"proximity"`, the
figure is drawn on the current device and `x` is returned invisibly.

## References

Okabe, M., & Ito, K. (2008). Color universal design: how to make figures
and presentations that are friendly to colorblind people.

Chaikin, G. M. (1974). An algorithm for high-speed curve generation.
*Computer Graphics and Image Processing*, 3(4), 346-349.

## Examples

``` r
dn <- dynet(school_contacts)
plot(dn)

plot(dn, type = "proximity")

plot(dn, type = "proximity", measure = "betweenness", phases = 4)

plot(dn, type = "network", node_fill = "#56B4E9")

```
