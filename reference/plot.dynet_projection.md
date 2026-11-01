# Draw a time-projected network

Each vertex state is a point at its slice's time on its vertex's row.
Within-slice arcs are drawn as solid curves and identity arcs, which
carry a vertex into the next slice, as dashed straight segments, so the
two arc types differ by line type and geometry, never by colour alone.

## Usage

``` r
# S3 method for class 'dynet_projection'
plot(x, base_size = 12, ...)
```

## Arguments

- x:

  A `dynet_projection` from
  [`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md).

- base_size:

  Base font size.

- ...:

  Ignored.

## Value

A `ggplot` object.
