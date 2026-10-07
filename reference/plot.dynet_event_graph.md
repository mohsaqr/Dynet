# Plot an event graph as a storyline

Draws the event graph as a storyline (Tanahashi and Ma, 2012): every
actor is a line through time, and every event is a column that gathers
the lines of its two endpoints in a light crimson capsule. The stretch
of an actor's line between two of its events is solid when the event
graph joins them through that actor, so something the actor received in
the first could be passed on in the second, and dashed when it does not,
because the wait exceeds `delta` or the direction of the events forbids
it. On a directed network an arrow in each column runs from the source
to the target.

## Usage

``` r
# S3 method for class 'dynet_event_graph'
plot(
  x,
  top = 8L,
  start = NULL,
  end = NULL,
  palette = "okabe",
  node_size = 2.5,
  node_shape = c(16, 17, 15, 18, 8, 4, 3, 1, 0),
  line_width = 0.9,
  line_alpha = 1,
  relay_style = "solid",
  no_relay_style = "22",
  capsule_color = "#DC143C",
  capsule_alpha = 0.16,
  capsule_width = 6,
  arrows = TRUE,
  arrow_color = "grey40",
  arrow_width = 0.4,
  arrow_size = 0.12,
  base_size = 12,
  label_size = 7,
  ...
)
```

## Arguments

- x:

  An event graph returned by
  [`event_graph()`](https://pak.dynasite.org/Dynet/reference/event_graph.md).

- top:

  The number of actors drawn, those in the most events (ties by name);
  `8` by default. `NULL` draws every actor. Columns are the events that
  involve at least one drawn actor.

- start, end:

  Draw only events starting in this period. Default to the whole
  network.

- palette:

  Actor line colours: `"okabe"` (the default; Okabe-Ito without its
  yellow, which is too faint for a thin line), `"extended"`, `"many"`, a
  vector of colours recycled over the actors, or a function of `n`
  returning `n` colours.

- node_size:

  Size of the points where a line meets its events; `2.5` by default.

- node_shape:

  Point shapes, recycled over the actors; ggplot shape codes. The
  default cycles nine shapes, so the first 72 actors differ in their
  pair of colour and shape.

- line_width, line_alpha:

  Width and opacity of the actor lines; `0.9` and `1` by default.

- relay_style, no_relay_style:

  Line types of a stretch that is an adjacency of the event graph and of
  one that is not; `"solid"` and `"22"` (dashed) by default. Any ggplot
  line type.

- capsule_color, capsule_alpha, capsule_width:

  Colour, opacity and width of the capsule gathering the endpoints of an
  event; a light crimson (`"#DC143C"` at `0.16`) of width `6` by
  default.

- arrows:

  Whether to draw the source-to-target arrow in each column of a
  directed network; `TRUE` by default.

- arrow_color, arrow_width, arrow_size:

  Colour, line width and head length (in centimetres) of those arrows;
  `"grey40"`, `0.4` and `0.12` by default.

- base_size:

  Base font size of the theme; `12` by default.

- label_size:

  Size of the time labels under the columns; `7` by default.

- ...:

  Ignored.

## Value

A `ggplot` object, so titles, themes and scales can be added with `+`.
Raises `dynet_bad_input` for a malformed `top`, `start`, `end` or
styling argument, `dynet_bad_palette` for an unusable `palette`,
`capsule_color` or `arrow_color`, and `dynet_empty_result` when no event
starts in the period.

## Details

Columns are events in time order, spaced by order rather than by elapsed
time, and labelled with their start. Lines are ordered by the barycentre
rule (Sugiyama et al., 1981) over repeated sweeps, keeping the ordering
with the fewest crossings, as in the storyline of the `hypergraphs`
package. Each actor has its own colour and point shape, so no actor is
told by colour alone.

## References

Tanahashi, Y., & Ma, K.-L. (2012). Design considerations for optimizing
storyline visualizations. *IEEE Transactions on Visualization and
Computer Graphics*, 18(12), 2679-2688.
[doi:10.1109/TVCG.2012.212](https://doi.org/10.1109/TVCG.2012.212)

Sugiyama, K., Tagawa, S., & Toda, M. (1981). Methods for visual
understanding of hierarchical system structures. *IEEE Transactions on
Systems, Man, and Cybernetics*, 11(2), 109-125.
[doi:10.1109/TSMC.1981.4308636](https://doi.org/10.1109/TSMC.1981.4308636)

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "B", "C", "A", "B"), to = c("B", "C", "D", "C", "D"),
  time = c(1, 2, 3, 4, 5)
))
eg <- event_graph(dn, delta = 1.5)
plot(eg)
```
