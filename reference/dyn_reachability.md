# Deprecated name for `reachability()`

`dyn_reachability()` was renamed
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md).
The old name still works: it passes every argument through unchanged and
returns the same result, with a warning of class `dynet_deprecated`. It
will be removed in a future release.

## Usage

``` r
dyn_reachability(...)
```

## Arguments

- ...:

  Arguments passed to
  [`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md).

## Value

The result of
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md):
a node-level `dynet_metric`.

## Conditions

Warning: `dynet_deprecated` on every call. Errors are those of
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md).

## Examples

``` r
dn <- dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                       start = c(0, 1), end = c(1, 2)))
# Warns, then returns what reachability(dn) returns.
dyn_reachability(dn)
#> Warning: `dyn_reachability()` is deprecated; use `reachability()`.
#> # Reachability (node-level)
#> # 3 vertices | time in step
#> # measures: forward_reach, backward_reach
#> # share of other vertices joined by a time-respecting path
#>  node        measure value
#>     A  forward_reach   1.0
#>     B  forward_reach   0.5
#>     C  forward_reach   0.0
#>     A backward_reach   0.0
#>     B backward_reach   0.5
#>     C backward_reach   1.0
```
