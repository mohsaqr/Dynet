# Tidy data frame of detected temporal phases

Tidy data frame of detected temporal phases

## Usage

``` r
# S3 method for class 'dynet_phases'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("bins", "profile", "phases"),
  ...
)
```

## Arguments

- x:

  A `dynet_phases` frame.

- row.names, optional:

  Ignored, for method consistency.

- what:

  `"bins"` for one row per time bin, `"profile"` for the sensitivity
  table over every `k` considered, or `"phases"` for one row per phase.

- ...:

  Ignored.

## Value

A plain data frame.
