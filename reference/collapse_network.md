# Collapse temporal activity to a static weighted network

Creates a static cograph network from the exact observed, endpoint-valid
activity in a requested time range. Every collapsed edge retains all
common duration summaries, so choosing one weighting does not discard
the others.

## Usage

``` r
collapse_network(
  dn,
  start = NULL,
  end = NULL,
  weight = c("binary", "union_duration", "total_duration", "duration_fraction",
    "spell_count", "weight_sum", "weighted_duration", "latest_weight"),
  sessions = c("bounded", "collapse", "separate"),
  censored = c("include", "exclude")
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md) or
  [`as_dynet()`](https://mohsaqr.github.io/Dynet/reference/as_dynet.md).

- start, end:

  Collapse bounds. Defaults to the observed range. Positive intervals
  are clipped to `[start, end)`; genuine points at either bound are
  retained.

- weight:

  Edge field used as the cograph weight: `"binary"`, `"union_duration"`,
  `"total_duration"`, `"duration_fraction"`, `"spell_count"`,
  `"weight_sum"`, `"weighted_duration"`, or `"latest_weight"`.

- sessions:

  Session handling. `"collapse"` erases session labels, `"bounded"`
  respects session-specific endpoint activity before pooling, and
  `"separate"` returns one collapsed cograph network per session.

- censored:

  Whether raw edge and vertex identities carrying an explicit censor
  flag are included.

## Value

A `dynet_collapsed` cograph netobject, whose two tidy tables are reached
with `as.data.frame(x, what = "edges")` and
`as.data.frame(x, what = "nodes")`. With `sessions = "separate"`, a
named `dynet_collapsed_list` of such objects, one per session.

The edge table carries one row per collapsed pair and every weighting at
once, so choosing one does not discard the others: `from`, `to`,
`binary` (1 for a pair that was ever active), `union_duration` (time the
pair was active, overlaps counted once), `total_duration` (summed spell
lengths, overlaps counted twice), `duration_fraction` (`union_duration`
over the pair's joint activity opportunity, `NA` when that opportunity
is zero), `spell_count`, `weight_sum`, `weighted_duration` (weight times
duration, summed), `latest_weight` (the weight of the last spell to
end), `first` and `last` (the pair's earliest onset and latest
terminus), and the `activity.duration` and `activity.count` aliases for
compatibility with
[`networkDynamic::network.collapse()`](https://rdrr.io/pkg/networkDynamic/man/network.collapse.html).

The node table carries one row per vertex, with `name`,
`activity_duration` (time the vertex was active, overlaps counted once)
and its `activity.duration` alias.

## Examples

``` r
dn <- dynet(data.frame(
  from = c("A", "A"), to = c("B", "B"),
  start = c(0, 1), end = c(2, 3)
))
flat <- collapse_network(dn, weight = "union_duration")
as.data.frame(flat)
#>   from to binary union_duration total_duration duration_fraction spell_count
#> 1    A  B      1              3              4                 1           2
#>   weight_sum weighted_duration latest_weight first last activity.duration
#> 1          2                 4             1     0    3                 3
#>   activity.count
#> 1              2
```
