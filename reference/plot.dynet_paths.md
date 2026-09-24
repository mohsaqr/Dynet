# Plot time-respecting paths when a valid renderer exists

A result from
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) records
the optimality criterion it was found under, and such a result is drawn
as a trajectory tree by
[`plot_path_trajectories()`](https://pak.dynasite.org/Dynet/reference/plot_path_trajectories.md).
That is the right picture for an endpoint-local family: the routes need
not share prefix-optimal subpaths, so a vertex reached under two
different temporal histories appears twice rather than being forced into
one predecessor tree.

Older serialised results carry no criterion. Those are drawn by the
legacy predecessor-tree renderer, which only defines a tree when the
sessions were collapsed; a bounded or separate-session result of that
vintage raises `dynet_unsupported_plot` instead of implying a tree the
criterion never promised.

## Usage

``` r
# S3 method for class 'dynet_paths'
plot(x, palette = "okabe", ...)
```

## Arguments

- x:

  A `dynet_paths` from
  [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md).

- palette:

  Palette specification, as in
  [`plot.dynet()`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md).
  Vertices are coloured by how many hops they are from the source. Read
  only by the legacy tree renderer.

- ...:

  Passed to
  [`plot_path_trajectories()`](https://pak.dynasite.org/Dynet/reference/plot_path_trajectories.md),
  or to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
  for a legacy result.

## Value

A `ggplot` object for a result carrying criterion metadata, which is
every result
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) returns.
A legacy result without it is drawn on the current device by
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
and `x` is returned invisibly.

A legacy result raises `dynet_unsupported_plot` when its sessions were
not collapsed, `dynet_empty_result` when the source reaches no other
vertex, `dynet_bad_palette` for an unusable `palette`, and
`dynet_needs_cograph` when cograph is not installed.

## Examples

``` r
dn <- dynet(school_contacts)
journeys <- paths(dn, from = "Ana")
plot(journeys)

```
