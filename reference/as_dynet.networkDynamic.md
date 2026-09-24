# Import a networkDynamic object

Converts the edge-activity spell ledger, observation support, explicit
vertex activity, weights, static vertex attributes, and static edge
attributes of a `networkDynamic` object. Integer vertex identifiers are
replaced by a complete unique vertex attribute. By default Dynet tries
`Name`, `Label`, and then `vertex.names`, in that order.

## Usage

``` r
# S3 method for class 'networkDynamic'
as_dynet(
  x,
  name_attribute = NULL,
  group_attribute = NULL,
  weight_attribute = "weight",
  session_attribute = NULL,
  interval = NULL,
  active_default = TRUE,
  import_edge_attributes = TRUE,
  ...
)
```

## Arguments

- x:

  A `networkDynamic` object.

- name_attribute:

  Optional vertex attribute holding the public node names. `NULL`
  chooses the first complete unique attribute among `Name`, `Label`, and
  `vertex.names`.

- group_attribute:

  Optional static vertex attribute used as the cograph grouping
  variable.

- weight_attribute:

  Static edge attribute used as spell weight, `"weight"` by default.
  Supply `NULL` to use unit weights. A name that is not a static edge
  attribute of `x` also yields unit weights.

- session_attribute:

  Optional static edge attribute used as the spell session label.
  `NULL`, the default, leaves the network unsessioned; a name that is
  not a static edge attribute raises a condition of class
  `dynet_unknown_attribute`.

- interval:

  Positive measurement interval. `NULL`, the default, uses the legacy
  observation time increment when available, otherwise one.

- active_default:

  Whether legacy edges with no explicit activity spell are active over
  the observation period, matching the same argument in
  `networkDynamic`. `TRUE` by default.

- import_edge_attributes:

  Whether to retain compatible static legacy edge attributes on the raw
  Dynet spell ledger. `TRUE` by default; an attribute whose name would
  collide with a canonical spell column is prefixed with `edge_`.

- ...:

  Ignored.

## Value

A [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md)
temporal network: an object of class
`c("dynet", "netobject", "cograph_network")` whose spell table has one
row per imported edge-activity spell, with the legacy vertex and edge
attributes, observation support, vertex activity and censor flags
carried across. Its metadata additionally carries
`legacy_source = "networkDynamic"`, the chosen `legacy_name_attribute`,
the retained `legacy_edge_attributes` and any
`legacy_edge_attribute_renames`.

## Details

Dynamic edge attributes other than activity itself are not part of the
`networkDynamic` spell-list interface and are therefore not imported.
Ordinary per-edge attributes are repeated onto every imported spell of
the corresponding aggregate edge, matched on the canonical endpoint
order [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md)
stores, so an undirected pair carries its own attributes.

## See also

[`as_dynet()`](https://pak.dynasite.org/Dynet/reference/as_dynet.md),
the generic.

## Examples

``` r
if (requireNamespace("networkDynamic", quietly = TRUE) &&
    requireNamespace("network", quietly = TRUE)) {
  spells <- data.frame(onset = c(0, 1), terminus = c(2, 3),
                       tail = c(1, 2), head = c(2, 3))
  legacy <- networkDynamic::networkDynamic(edge.spells = spells)
  network::set.vertex.attribute(legacy, "Name", c("A", "B", "C"))
  dn <- as_dynet(legacy)
  as.data.frame(dn)
}
#> Initializing base.net of size 3 imputed from maximum vertex id in edge records
#> Created net.obs.period to describe network
#>  Network observation period info:
#>   Number of observation spells: 1 
#>   Maximal time range observed: 0 until 3 
#>   Temporal mode: continuous 
#>   Time unit: unknown 
#>   Suggested time increment: NA 
#>   from to start end duration weight onset_censored terminus_censored
#> 1    A  B     0   2        2      1          FALSE             FALSE
#> 2    B  C     1   3        2      1          FALSE             FALSE
```
