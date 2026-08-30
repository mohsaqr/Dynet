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

  Static edge attribute used as spell weight. Supply `NULL` to use unit
  weights.

- session_attribute:

  Optional static edge attribute used as the spell session label.

- interval:

  Positive measurement interval. `NULL` uses the legacy observation time
  increment when available, otherwise one.

- active_default:

  Whether legacy edges with no explicit activity spell are active over
  the observation period, matching the same argument in
  `networkDynamic`.

- import_edge_attributes:

  Whether to retain compatible static legacy edge attributes on the raw
  Dynet spell ledger.

- ...:

  Ignored.

## Value

A `dynet` object carrying `legacy_source = "networkDynamic"` in its
metadata.

## Details

Dynamic edge attributes other than activity itself are not part of the
`networkDynamic` spell-list interface and are therefore not imported.
Ordinary per-edge attributes are repeated onto every imported spell of
the corresponding aggregate edge.
