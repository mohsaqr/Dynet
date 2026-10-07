# Centrality on time-respecting paths and temporal walks

Centrality computed from the time-respecting paths that
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) finds, or
from the temporal walks of the contact stream, taken across the whole
observation period (or the `start`-to-`end` window). A path may only
continue along a tie that is available after it arrives, so these values
cannot be inflated by ties that occur in the wrong order, as a flattened
network is. The result is one value per vertex, not a series: for
centrality that changes from window to window, use
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md);
for the number of vertices a vertex can reach, use
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md).

## Usage

``` r
path_centrality(
  dn,
  measure = "closeness",
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  traversal_time = 0,
  criterion = c("foremost_then_shortest", "min_hops", "foremost", "fastest", "shortest"),
  cost = c("hops", "weight"),
  top = NULL,
  mode = c("out", "in"),
  beta = 0.1,
  decay = 0,
  damping = 0.85,
  transition = 1,
  rescale = TRUE,
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- measure:

  One or more of the path measures `"closeness"` (the default),
  `"betweenness"` and `"efficiency"`, and the stream measures `"katz"`,
  `"pagerank"` and `"walk"`. Any other name raises
  `dynet_unknown_measure`.

- sessions:

  How to treat sessions: `"bounded"` (the default) keeps paths inside a
  session, `"collapse"` ignores sessions, `"separate"` reports each
  session on its own rows. `"separate"` on a network built without a
  session column raises `dynet_no_sessions`.

- start, end:

  Inclusive path-traversal bounds. Default to the observed range. A
  network built from dates may be addressed with dates.

- traversal_time:

  Nonnegative duration charged for every hop, in the network's time
  unit; `0` by default. A calendar network also accepts a scalar
  `difftime`.

- criterion:

  Which optimisation problem the journeys solve.
  `"foremost_then_shortest"` is the default and what every earlier
  release computed; `"min_hops"` counts fewest contacts, which makes
  closeness dimensionless and comparable with its static counterpart.
  `"foremost"` (pure earliest arrival) is accepted for closeness, where
  it equals the default because closeness reads only the arrival, and
  refused for betweenness with `dynet_intractable_criterion`, because
  that needs the count of every vertex-simple foremost journey, which is
  \#P-hard (Buss et al., 2024). `"fastest"` measures closeness by
  journey duration rather than arrival, so a vertex that is reached late
  but quickly is close; betweenness under it is not implemented.
  `"shortest"` minimises a summed cost per contact, `cost`: with hop
  costs it is `"min_hops"`, with weight costs closeness is the inverse
  mean summed weight of the cheapest journeys and betweenness counts
  those journeys. Reach and reach count are identical under all.

- cost:

  For `criterion = "shortest"` only: `"hops"` (one per contact) or
  `"weight"` (the tie weight, which must be positive and finite). See
  [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md).

- top:

  For `measure = "closeness"` under `criterion = "min_hops"` or
  `"shortest"` only: return the `top` most central vertices, plus every
  vertex tied at the `top`-th value, computing only the searches that
  ranking needs. Temporal closeness costs one full path search per
  vertex; a source is dropped as soon as the closeness of what it has
  reached so far, which can only fall as the search continues, is below
  the `top`-th best value found. The answer is exact, the same rows and
  values the full computation gives, and the result records how many
  sources ran to completion as `sources_evaluated`. Under
  `sessions = "separate"` the ranking is within each session; under
  `sessions = "bounded"` on a network with sessions no source can be
  dropped early, and the count says so. The remaining vertices are
  absent, not `NA`, and the print header says they were not computed.

- mode:

  For `measure = "efficiency"` only: `"out"` (the default) averages over
  the targets a vertex reaches, `"in"` over the sources that reach it.
  Every other measure follows the network's recorded direction, and
  naming `mode` with one raises `dynet_bad_input`.

- beta:

  For `measure = "katz"` and `"walk"` only: walk attenuation in
  `(0, 1]`. Under `"katz"` a walk of `l` contacts weighs `beta^l`; under
  `"walk"` it weighs `beta^(l - 1)`, so a contact alone weighs one and
  each further contact multiplies by `beta` (Oettershagen, Mutzel and
  Kriege, 2022, Definition 4.1).

- decay:

  For `measure = "katz"` and `"walk"` only: exponential time-decay rate.
  Under `"katz"` it discounts every past walk by the time elapsed; under
  `"walk"` it discounts each pairing of an arrival with a later
  departure by the waiting time between them. Zero weights every walk,
  or every pairing, equally.

- damping:

  For `measure = "pagerank"` only: the jumping probability, a single
  number strictly between zero and one, `0.85` by default. Each extra
  step of a temporal walk is worth `damping` times the last.

- transition:

  For temporal `measure = "pagerank"` only: the transition probability
  in `(0, 1]`. A walk waiting at a vertex declines each passing outgoing
  contact with probability `transition` and takes it otherwise, so a
  smaller value spreads a walk's next step further into the future. The
  boundary value `1` is a separate rule, not a limit: the walk takes the
  first contact that passes.

- rescale:

  For `measure = "pagerank"` only: whether to divide the scores by their
  total in each block, `TRUE` by default. The raw score grows with the
  length of the stream, so only the rescaled one compares across
  windows. Naming it with any other measure raises `dynet_bad_input`.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn.

## Value

A node-level `dynet_metric`: a tidy data frame with one row per vertex
and measure, columns `node`, `measure` and `value`, preceded by
`session` under `sessions = "separate"`. There is no `time` column. A
single-measure result stores its mathematical choices as direct
attributes; a two-measure result stores named records under
`measure_metadata`.

## Details

Betweenness is the raw dependency sum over reachable forward ordered
pairs. For each source-target pair, its unit dependency is divided
equally over every canonical shortest-foremost journey, and an internal
vertex receives the fraction of those journeys that contain it. Sources
and targets receive no endpoint credit. This ordered-pair convention
also applies to undirected contacts because temporal reach is generally
asymmetric. The result is not normalised; its fixed range is
`[0, (n - 1) * (n - 2)]`.

Closeness is inverse mean forward latency over reachable vertices: if
\\R_s\\ is the set of reachable vertices other than source \\s\\,
\$\$C(s) = \|R_s\| / \sum\_{z \in R_s} (a_z - o_s),\$\$ where \\a_z\\ is
the foremost arrival time and \\o_s\\ is the source's resolved origin:
the traversal window's lower bound, or – when vertex activity was
declared – the source's first presence inside that window. Every
reachable endpoint is included once, regardless of how many optimal
paths reach it. A source with no reachable nonself endpoints has value
zero. If all reachable endpoints have zero latency, the value is `Inf`;
zero-latency endpoints remain in the numerator when mixed with positive
latencies. The measure therefore has inverse-time units, is invariant to
translating the time axis, and scales inversely when time is rescaled.

Both measures use
[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) traversal
semantics: nondecreasing times, unlimited waiting, half-open interval
spells, and a separate exact timestamp rule for point events. Positive
`traversal_time` requires an interval traversal to finish within
continuous pair activity; a point event triggers at its timestamp and
reaches its endpoint after that duration. `start` and `end` bound every
measure. In separate-session output, a session outside a one-sided bound
contributes zero rows.

Efficiency is the mean reciprocal temporal distance from a vertex to
every other vertex (`mode = "out"`), or to it from every other
(`mode = "in"`), with the distance the `criterion` optimises.
Unreachable vertices contribute zero rather than being dropped, so it is
defined on a disconnected network; it is therefore not the reciprocal of
closeness, which averages over reachable vertices only.

Temporal Katz centrality is the attenuated, time-decayed count of
temporal walks ending at each vertex (Beres et al., 2018): each contact
`(u, v, t)` passes `beta` times whatever had reached `u`, plus one for
the walk that is that contact alone.

Temporal PageRank scores a vertex by the damped, transition-weighted
count of temporal walks that end at it, following Rozenshtein and Gionis
(2016). It is computed by their Algorithm 1 in one pass over the contact
stream: a contact `(u, v, t)` starts a fresh walk at `u` worth
`1 - damping`, then carries `damping` times whatever mass is waiting at
`u` across to `v`. With `transition < 1` the mass left behind at `u` is
multiplied by `transition` for each contact it declines, so a walk\\s
next step follows a geometric distribution over the outgoing contacts
that pass. `transition = 1` is a distinct rule rather than the limit of
that one: the waiting mass leaves entirely on the first passing contact.

Two consequences are worth stating plainly. The raw score grows linearly
with the number of contacts, so it is comparable only within one window;
`rescale = TRUE`, the default for this measure, divides by the total and
is what makes two windows comparable. And the walk does not restart
uniformly: a walk begins at `u` once per outgoing contact of `u`, so the
implied personalization is the out-degree distribution. Under repeated
uniform sampling from a fixed digraph and `transition = 1`, the rescaled
scores converge to static PageRank personalized by weighted out-degree;
on a digraph of constant out-degree that is exactly the uniform-teleport
PageRank reported at snapshot scope. There is no teleportation matrix
and so no dangling-mass correction: a vertex with no outgoing contact
simply holds its mass. A vertex that never appears as a contact endpoint
scores exactly zero, and a block with no eligible contact at all scores
`NaN` throughout once rescaled.

`"walk"` is temporal walk centrality (Oettershagen, Mutzel and Kriege,
2022): a vertex scores by the walks that arrive at it and the walks that
leave it afterwards,
`sum over t1 < t2 of W_in(v, t1) * W_out(v, t2) * exp(-decay * (t2 - t1))`,
where `W_in(v, t)` is the summed weight of temporal walks ending at `v`
at `t` and `W_out(v, t)` of those starting there. It is the one measure
of the family that scores brokerage in time, obtaining then
distributing, rather than accumulated arrivals; it costs two passes over
the contact stream. The pairing is strict: an arrival and a departure at
the same instant are two contacts that cannot chain, so they are not
paired. A vertex with no incoming or no outgoing contact scores zero. On
an undirected network every contact runs both ways. The result records
`attenuation`, `decay`, `walk_weight`, `waiting_weight`, `walk_rule` and
`pairing`.

Simultaneous contacts are batched strictly for the stream measures,
`"katz"`, `"pagerank"` and `"walk"`: every contact sharing a timestamp
reads the active mass as it stood before that instant, and the arrivals
it produces are only available afterwards. This deliberately differs
from [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md),
which composes equal-time contacts at `traversal_time = 0`, and from a
literal reading of Algorithm 1, which would let one contact continue a
walk another contact delivered in the same instant. Without the batch
rule the answer would depend on the arbitrary order of rows inside one
instant, and therefore on the vertex labelling. On a stream whose
timestamps are distinct and which carries no self-contact, the batched
recurrence reduces to Algorithm 1 exactly.

Declared vertex activity gates the exact source anchor and every hop.
Waiting after a valid anchor may cross inactivity; interval traversal
requires both endpoints through completion, while a point trigger
requires the receiver again after any traversal delay. Fixed node rows
and full-network denominators are retained.

## Conditions

Errors: `dynet_unknown_measure` (a measure not listed under `measure`),
`dynet_intractable_criterion` (betweenness under
`criterion = "foremost"`; it also carries `dynet_bad_input`),
`dynet_no_sessions` (`sessions = "separate"` without a session column),
`dynet_outside_observation` (the requested range misses observed
support; it also carries `dynet_bad_input`), and `dynet_bad_input` for
every other broken contract – `dn` not a `dynet`, a malformed `measure`,
an out-of-range `start`, `end` or `traversal_time`, an argument named
with a measure it does not apply to, betweenness under
`criterion = "fastest"`, and `top` outside closeness under `"min_hops"`
or `"shortest"`.

## References

Pan, R. K., & Saramaki, J. (2011). Path lengths, correlations, and
centrality in temporal networks. *Physical Review E*, 84(1), 016105.

Tang, J., Musolesi, M., Mascolo, C., Latora, V., & Nicosia, V. (2010).
Analysing information flows and key mediators through temporal
centrality metrics. *Proceedings of SNS '10*.

Buss, S., Molter, H., Niedermeier, R., & Rymar, M. (2024). Algorithmic
aspects of temporal betweenness. *Network Science*, 12(2), 160-188.

Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora,
V. (2013). Graph metrics for temporal networks. In *Temporal Networks*
(pp. 15-40). Springer.

Beres, F., Palovics, R., Olah, A., & Benczur, A. A. (2018). Temporal
walk based centrality metric for graph streams. *Applied Network
Science*, 3, 32.

Oettershagen, L., Mutzel, P., and Kriege, N. M. (2022). Temporal walk
centrality: ranking nodes in evolving networks. *Proceedings of the ACM
Web Conference 2022*, 1640-1650.
[doi:10.1145/3485447.3512210](https://doi.org/10.1145/3485447.3512210)

Rozenshtein, P., & Gionis, A. (2016). Temporal PageRank. In *Machine
Learning and Knowledge Discovery in Databases (ECML PKDD 2016)*, LNCS
9852, 674-689.

## See also

[`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md),
[`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md),
[`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md).

## Examples

``` r
# Every ordered pair is searched, so the cost grows steeply with the
# vertex count; a subgraph keeps the example quick.
dn <- dynet(school_contacts)
few <- induce_subgraph(dn, nodes = c("Ana", "Ben", "Cara", "Dan", "Eve",
                                     "Finn", "Gita", "Hugo"))
path_centrality(few)
#> # Closeness (node-level)
#> # 8 vertices | time in step
#> # computed on time-respecting paths across the whole window
#>  node   measure      value
#>   Ana closeness 0.09987159
#>   Ben closeness 0.13180192
#>  Cara closeness 0.07404273
#>   Dan closeness 0.14198783
#>   Eve closeness 0.13908206
#>  Finn closeness 0.07579859
#>  Gita closeness 0.10995916
#>  Hugo closeness 0.12297962
path_centrality(few, measure = c("closeness", "betweenness"),
                start = 0, end = 10)
#> # Temporal centrality (node-level)
#> # 8 vertices | time in step
#> # measures: closeness, betweenness
#> # computed on time-respecting paths within the requested traversal window
#>  node     measure     value
#>   Ana   closeness 0.1380262
#>   Ben   closeness 0.1731902
#>  Cara   closeness 0.1270648
#>   Dan   closeness 0.1794258
#>   Eve   closeness 0.1740644
#>  Finn   closeness 0.1476015
#>  Gita   closeness 0.1773836
#>  Hugo   closeness 0.1461276
#>   Ana betweenness 8.0000000
#>   Ben betweenness 0.0000000
#>  Cara betweenness 7.0000000
#>   Dan betweenness 0.0000000
#> # 4 more rows. summary() aggregates them; plot() draws them.

# The leaders only, searching just what the ranking needs
path_centrality(few, criterion = "min_hops", top = 3)
#> # Closeness (node-level)
#> # 3 vertices | time in step
#> # top 3 by closeness, ties kept: 3 of 8 vertices shown; 4 of 8 sources searched to completion; the other vertices were not computed
#>  node   measure     value
#>   Ben closeness 0.7000000
#>  Cara closeness 0.8750000
#>   Dan closeness 0.7777778

# Stream measures need no path search, so they run on the whole network.
path_centrality(dn, measure = "katz")
#> # NA (node-level)
#> # 14 vertices | time in step
#> # computed on time-respecting paths across the whole window
#>   node measure    value
#>    Ana    katz 5.006780
#>    Ben    katz 4.935766
#>   Cara    katz 3.939342
#>    Dan    katz 5.814129
#>    Eve    katz 5.096034
#>   Finn    katz 2.191632
#>   Gita    katz 4.206658
#>   Hugo    katz 5.748278
#>   Iris    katz 2.942059
#>  Jonas    katz 6.694350
#>   Kira    katz 4.353163
#>    Leo    katz 2.945684
#> # 2 more rows. summary() aggregates them; plot() draws them.
path_centrality(dn, measure = "walk", decay = 0.1)
#> # NA (node-level)
#> # 14 vertices | time in step
#> # computed on time-respecting paths across the whole window
#>   node measure    value
#>    Ana    walk 396.6499
#>    Ben    walk 213.2662
#>   Cara    walk 313.5378
#>    Dan    walk 342.7202
#>    Eve    walk 240.7718
#>   Finn    walk 259.4787
#>   Gita    walk 352.5831
#>   Hugo    walk 219.2807
#>   Iris    walk 257.7428
#>  Jonas    walk 598.7884
#>   Kira    walk 363.6357
#>    Leo    walk 175.9248
#> # 2 more rows. summary() aggregates them; plot() draws them.
path_centrality(dn, measure = "pagerank", transition = 0.5)
#> # PageRank (node-level)
#> # 14 vertices | time in step
#> # computed on time-respecting paths across the whole window
#>   node  measure      value
#>    Ana pagerank 0.08159719
#>    Ben pagerank 0.05479939
#>   Cara pagerank 0.06713915
#>    Dan pagerank 0.08384345
#>    Eve pagerank 0.07095400
#>   Finn pagerank 0.03910293
#>   Gita pagerank 0.06675614
#>   Hugo pagerank 0.09261850
#>   Iris pagerank 0.04028956
#>  Jonas pagerank 0.11014546
#>   Kira pagerank 0.08294823
#>    Leo pagerank 0.04541915
#> # 2 more rows. summary() aggregates them; plot() draws them.
```
