# Time-varying vertex centrality

Centrality for every vertex at every time point. Ask for several
measures in one call and they arrive stacked in a single tidy frame, one
row per vertex, time point and measure.

Two scopes answer two different questions. `"snapshot"` measures the
network as it stands in each time bin, so the result is a trajectory of
ordinary centrality. `"temporal"` measures the vertex against
time-respecting paths across the whole observation window, or the
supplied `start`-to-`end` traversal window for temporal reach,
closeness, and betweenness. This quantity has no counterpart in a static
network: it cannot run backwards in time, so it is never inflated the
way a flattened network is.

## Usage

``` r
dyn_centrality(
  dn,
  measure = "degree",
  scope = c("snapshot", "temporal"),
  sessions = c("bounded", "collapse", "separate"),
  sample = NULL,
  damping = 0.85,
  mode = c("all", "out", "in"),
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL,
  exponent = 1,
  traversal_time = 0,
  prestige = "indegree",
  rescale = FALSE,
  lambda = 1,
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- measure:

  One or more of `"degree"`, `"strength"`, `"prestige"`, `"closeness"`,
  `"betweenness"`, `"eigenvector"`, `"pagerank"`, `"hub"`,
  `"authority"`, `"coreness"`, `"constraint"`, `"power"`, `"harary"`,
  `"information"`, `"load"`, `"flow_betweenness"`, or `"diffusion"` for
  snapshot scope; `"closeness"`, `"betweenness"`, `"reach"` or
  `"reach_count"` for temporal scope.

- scope:

  `"snapshot"` for a value per time bin, `"temporal"` for one value per
  vertex computed on time-respecting paths.

- sessions:

  How to treat sessions: `"bounded"` keeps paths inside a session,
  `"collapse"` ignores sessions, `"separate"` reports each session on
  its own rows.

- sample:

  Deprecated. `"instant"` is equivalent to `window = 0`; `"window"` uses
  the current positive/default window.

- damping:

  Damping factor for PageRank.

- mode:

  Which edges count on a directed network: `"all"` both directions,
  `"out"` outgoing only, `"in"` incoming only. Name several at once –
  `mode = c("all", "in", "out")` – to get degree, in-degree and
  out-degree from a single call; the extra directions are then labelled
  `degree_in` and `degree_out` in the `measure` column, while a call
  naming one direction keeps the plain measure name. Applies to
  `"degree"`, `"strength"`, `"closeness"`, `"coreness"`, `"harary"`,
  `"eigenvector"` and `"diffusion"`; the remaining measures have a
  single directional definition and ignore it. Ignored entirely on an
  undirected network. In-degree is therefore `mode = "in"`. The old
  `"indegree"` and `"outdegree"` measure names remain as deprecated
  aliases.

- start, end:

  First and last time at which to measure. Default to the observed
  range. For temporal measures these are inclusive path-traversal
  bounds. A network built from dates may be addressed with dates.

- step:

  How often to measure. Defaults to the interval the network was built
  with.

- window:

  How much time each measurement covers. Defaults to `step`, which tiles
  the period into disjoint bins. A larger value slides an overlapping
  window; `0` samples the network at each point in time. `"all"`
  measures the whole observed period as one window, closed on the right
  so an event at the final instant is inside it; it cannot be combined
  with `step`, and under `sessions = "separate"` or discontinuous
  observation it gives one window per session or observed component.

- exponent:

  Attenuation factor for Bonacich `"power"`. Positive rewards being
  connected to well-connected others; negative rewards the opposite,
  which is the bargaining reading.

- traversal_time:

  Nonnegative duration charged for every temporal-path hop, in the
  network's time unit. A calendar network also accepts a scalar
  `difftime`. Nonzero values require `scope = "temporal"`.

- prestige:

  Prestige definition. `"indegree"` counts distinct active incoming
  dyads. `"indegree.rownorm"` first gives every active sender one unit
  split equally across its distinct outgoing dyads, then sums the
  received mass. `"indegree.rowcolnorm"` balances a total-support binary
  adjacency to doubly stochastic form; feasible scores are necessarily
  uniform. `"domain"` counts the distinct other vertices with a directed
  path into each vertex in the active snapshot. `"domain.proximity"`
  discounts that incoming domain fraction by its mean directed hop
  distance. `"eigenvector"` uses the unique nonnegative Perron ray of
  the transposed binary adjacency. `"eigenvector.rownorm"` first divides
  every nonzero binary sender row by its outgoing-dyad count and then
  solves the same certified incoming Perron equation.
  `"eigenvector.colnorm"` instead divides every nonzero binary receiver
  column by its incoming-dyad count before solving.
  `"eigenvector.rowcolnorm"` first certifies total support and balances
  binary adjacency to doubly stochastic form. Prestige is directed and
  snapshot-only.

- rescale:

  Whether to divide prestige by its total independently inside every
  reported time/session block. Zero-total count/proximity definitions
  return `NaN`; structurally undefined spectral definitions return `NA`.
  This argument requires `measure = "prestige"`.

- lambda:

  Nonnegative multiplier for `"diffusion"`. Diffusion degree is the sum
  of the selected degree of a vertex and all of its one-step neighbours,
  multiplied by `lambda`.

- plot:

  Whether to draw the result as well as return it. Drawing is a side
  effect in the manner of
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html): the verb
  still returns its tidy table, invisibly when it has drawn, so
  `plot = TRUE` saves the wrapping
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call without
  changing what comes back. Use
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on the result
  when the figure needs arguments of its own.

## Value

A `dynet_metric`: a tidy data frame with one row per vertex, time point
and measure. Columns are `session` (only when the network has sessions),
`time` (snapshot scope only), `node`, `measure` and `value`. Print it,
[`summary()`](https://rdrr.io/r/base/summary.html) it,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) it, or take the
plain frame with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html). A
closeness- or betweenness-only temporal result stores its mathematical
choices as direct attributes; a mixed temporal result stores named
records under `measure_metadata`. Snapshot prestige follows the same
direct-versus-scoped metadata convention. When a prestige variant is
structurally undefined or fails to converge, the affected values are
`NA`, a warning says how many reporting blocks were affected, and a
`prestige_diagnostics` record naming the stage and reason for each is
attached to the result.

## Details

`step` and `window` are separate on purpose. `step` is how often you
look; `window` is how much of the timeline each look takes in. Setting
them equal partitions the period; setting `window` larger than `step` is
a rolling window, which keeps the resolution of the smaller step while
smoothing over the noise of a sparse bin. The arguments match
[`tsna::tSnaStats()`](https://rdrr.io/pkg/tsna/man/tSnaStats.html),
where they are called `time.interval` and `aggregate.dur`.

`"eigenvector"` is uniquely determined when the Perron eigenvalue has a
one-dimensional eigenspace; strong connectivity is a sufficient
condition. Disconnected snapshots with equally dominant components can
have more than one correct eigenvector, so read the result as a
within-snapshot ranking rather than an automatically comparable number
across the whole series.

Indegree prestige is the column sum of the directed binary active-dyad
adjacency matrix. It is exactly snapshot degree with `mode = "in"`:
duplicate, split, and overlapping spells and edge weights do not
multiply the result, while an explicitly retained directed loop
contributes once. With `rescale = TRUE`, the column sums are divided by
their block total. A zero total is mathematically undefined and is
returned as literal `NaN`.

Row-normalized indegree prestige first converts every nonzero binary
adjacency row to sum one; zero rows remain all zero. Its column sums are
the received sender-nomination mass, so their total is the number of
active senders. `rescale = TRUE` divides again by that block total. This
closed-form transform is the `sna::prestige(cmode = "indegree.rownorm")`
definition on binary matrices. Dynet deliberately ignores edge weights,
whereas `sna` uses their magnitudes on valued matrices.

Row-column-normalized prestige uses deterministic Sinkhorn–Knopp scaling
only when the full binary vertex matrix has total support: every active
dyad must belong to a perfect matching. It preserves all binary dyads
and does not remove isolates or unsupported edges. Infeasible blocks
return `NA` for every vertex with a classed warning. A feasible
transform has every incoming column sum equal to one, so raw prestige is
uniformly one and rescaled prestige uniformly `1 / n`; this definition
is a transform diagnostic, not a vertex ranking. Dynet uses fixed-order
sweeps, maximum absolute row/column residual `1e-12`, and at most 10,000
sweeps. It never returns a partial iterate. This deliberately differs
from the randomized loose-tolerance annealer in `sna` 2.8.

Domain prestige is incoming indegree in the directed reachability graph
after excluding its reflexive diagonal. If `H[i,j]` records whether
`i = j` or a directed path from `i` to `j` exists, then
`p[j] = sum(H[,j]) - 1`. Every distinct reaching vertex counts once,
regardless of path length or multiplicity. Loops cannot add self credit,
isolates score zero, and a zero-total rescaling returns literal `NaN`.
Closure is computed on the binary active snapshot for each reporting
block, not on chronologically ordered temporal journeys through the raw
spells.

Domain-proximity prestige additionally uses the shortest incoming hop
distances. For the nonself domain `D[j]`, let `r[j]` be its size and
`s[j]` the sum of its finite distances into `j`. The score is zero when
`r[j] = 0` and otherwise `r[j]^2 / ((n - 1) * s[j])`: the incoming
domain fraction divided by mean hop distance. Unreachable vertices are
omitted before the distance sum. This deliberately fixes an arithmetic
artifact in `sna` 2.8, whose `FALSE * Inf` operation incorrectly zeros
partial nonempty domains.

Eigenvector prestige solves `t(B) %*% p = rho * p` for the nonnegative
Perron ray of binary adjacency `B`. It requires positive spectral radius
and a one-dimensional Perron eigenspace. Raw scores have Euclidean norm
one; `rescale = TRUE` makes their sum one. Zero-radius or nonunique
blocks return all `NA` with a classed warning and diagnostics. Periodic
cycles remain valid even when negative or complex roots share the
spectral radius. Dynet uses direct eigenvalues plus an SVD
nullity/residual check at tolerance `1e-10`, orients the ray as
nonnegative, and never applies elementwise absolute value.

Row-normalized eigenvector prestige first forms binary adjacency `B` and
divides each nonzero sender row by its number of distinct outgoing
dyads; zero rows remain exactly zero. It then solves the certified
incoming Perron equation for the transpose of that row-stochastic
matrix. Thus each active sender distributes one unit of recursive
nomination mass, with no teleportation or dangling-row imputation.
Binary session union and retained loop policy occur before row
normalization. The positive-radius, geometric- uniqueness,
nonnegative-sign, L2/sum-scale, warning, and diagnostic rules are
otherwise exactly those of ordinary eigenvector prestige.

Column-normalized eigenvector prestige divides each nonzero binary
receiver column by its number of distinct incoming dyads; zero columns
remain zero. It solves the incoming Perron equation only after that
transform. If every vertex has positive indegree, the transformed
transpose is row-stochastic and every certified score is necessarily
uniform. Nonuniform defined scores therefore require a zero-indegree
vertex. Binary union and retained-loop policy precede normalization;
certification and scaling remain those above.

Row-column-normalized eigenvector prestige composes the total-support
and deterministic Sinkhorn–Knopp contract with the certified Perron
contract. Infeasible support and nonconvergent balancing terminate
before the spectral solve. A completed doubly stochastic transform
always has the all-ones Perron ray, but reducible transforms have
several such rays and remain undefined. Every fully certified score is
therefore exactly uniform: `1 / sqrt(n)` raw or `1 / n` rescaled. This
selector diagnoses support, balance, and irreducibility; it is not a
vertex ranking.

Temporal betweenness is the raw dependency sum over reachable forward
ordered pairs. For each source-target pair, its unit dependency is
divided equally over every canonical shortest-foremost journey, and an
internal vertex receives the fraction of those journeys that contain it.
Sources and targets receive no endpoint credit. This ordered-pair
convention also applies to undirected contacts because temporal reach is
generally asymmetric. The result is not normalized; its fixed range is
`[0, (n - 1) * (n - 2)]`.

Temporal closeness is inverse mean forward latency over reachable
vertices: if \\R_s\\ is the set of reachable vertices other than source
\\s\\, \$\$C(s) = \|R_s\| / \sum\_{z \in R_s} (a_z - L),\$\$ where
\\a_z\\ is the foremost arrival time and \\L\\ is the traversal window's
lower bound. Every reachable endpoint is included once, regardless of
how many optimal paths reach it. A source with no reachable nonself
endpoints has value zero. If all reachable endpoints have zero latency,
the value is `Inf`; zero-latency endpoints remain in the numerator when
mixed with positive latencies. The measure therefore has inverse-time
units, is invariant to translating the time axis, and scales inversely
when time is rescaled.

Temporal measures use
[`paths()`](https://mohsaqr.github.io/Dynet/reference/paths.md)
traversal semantics: nondecreasing times, unlimited waiting, half-open
interval spells, and a separate exact timestamp rule for point events.
Positive `traversal_time` requires an interval traversal to finish
within continuous pair activity; a point event triggers at its timestamp
and reaches its endpoint after that duration. `start` and `end` bound
every temporal measure. Temporal `"reach"` is the proportion of other
vertices reachable in the forward direction, while `"reach_count"` is
their number. The source is excluded from both and a singleton
proportion is defined as zero. In separate-session output, a session
outside a one-sided bound contributes zero-reach rows.

At snapshot scope, declared vertex activity induces the eligible vertex
population before any kernel is evaluated. Positive windows
independently use any-time vertex and edge unions before induction,
while `window = 0` evaluates the exact state. Results remain rectangular
over the fixed vertex universe: inactive vertices receive typed `NA`,
while eligible isolates keep the centrality kernel's ordinary static
result. At temporal scope, declared vertex activity gates the exact
source anchor and every hop. Waiting after a valid anchor may cross
inactivity; interval traversal requires both endpoints through
completion, while a point trigger requires the receiver again after any
traversal delay. Fixed node rows and pre-V04 denominators are retained.

## References

Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97-125.

Tang, J., Musolesi, M., Mascolo, C., Latora, V., & Nicosia, V. (2010).
Analysing information flows and key mediators through temporal
centrality metrics. *Proceedings of SNS '10*.

Buss, S., Molter, H., Niedermeier, R., & Rymar, M. (2024). Algorithmic
aspects of temporal betweenness. *Network Science*, 12(2), 160-188.

Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora,
V. (2013). Graph metrics for temporal networks. In *Temporal Networks*
(pp. 15-40). Springer.

Wasserman, S., & Faust, K. (1994). *Social Network Analysis: Methods and
Applications*. Cambridge University Press, Chapter 5.

Butts, C. T. (2024). *sna: Tools for Social Network Analysis*, version
2.8. doi:10.32614/CRAN.package.sna.

Lin, N. (1976). *Foundations of Social Research*. McGraw-Hill.

Brandes, U. (2001). A faster algorithm for betweenness centrality.
*Journal of Mathematical Sociology*, 25(2), 163-177.

Bonacich, P. (1987). Power and centrality: a family of measures.
*American Journal of Sociology*, 92(5), 1170-1182.

Hage, P., & Harary, F. (1995). Eccentricity and centrality in networks.
*Social Networks*, 17(1), 57-63.

Stephenson, K., & Zelen, M. (1989). Rethinking centrality. *Social
Networks*, 11(1), 1-37.

Goh, K.-I., Kahng, B., & Kim, D. (2001). Universal behavior of load
distribution in scale-free networks. *Physical Review Letters*, 87(27),
278701.

Freeman, L. C., Borgatti, S. P., & White, D. R. (1991). Centrality in
valued graphs. *Social Networks*, 13(2), 141-154.

Bonacich, P. (1972). Factoring and weighting approaches to status scores
and clique identification. *Journal of Mathematical Sociology*, 2,
113-120. doi:10.1080/0022250X.1972.9989806.

Berman, A., & Plemmons, R. J. (1994). *Nonnegative Matrices in the
Mathematical Sciences*. SIAM. doi:10.1137/1.9781611971262.

Sinkhorn, R. (1964). A relationship between arbitrary positive matrices
and doubly stochastic matrices. *Annals of Mathematical Statistics*, 35,
876-879. doi:10.1214/aoms/1177703591.

Sinkhorn, R., & Knopp, P. (1967). Concerning nonnegative matrices and
doubly stochastic matrices. *Pacific Journal of Mathematics*, 21,
343-348. doi:10.2140/pjm.1967.21.343.

Knight, P. A. (2008). The Sinkhorn-Knopp algorithm: convergence and
applications. *SIAM Journal on Matrix Analysis and Applications*, 30,
261-275. doi:10.1137/060659624.

## Examples

``` r
dn <- dynet(school_contacts)

dyn_centrality(dn, measure = "degree")
#> # Degree (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node measure value
#>     0   Ana  degree     1
#>     0   Ben  degree     1
#>     0  Cara  degree     1
#>     0   Dan  degree     1
#>     0   Eve  degree     2
#>     0  Finn  degree     1
#>     0  Gita  degree     1
#>     0  Hugo  degree     1
#>     0  Iris  degree     2
#>     0 Jonas  degree     2
#>     0  Kira  degree     2
#>     0   Leo  degree     2
#> # 296 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = c("degree", "betweenness"))
#> # Centrality (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#> # measures: degree, betweenness
#>  time  node measure value
#>     0   Ana  degree     1
#>     0   Ben  degree     1
#>     0  Cara  degree     1
#>     0   Dan  degree     1
#>     0   Eve  degree     2
#>     0  Finn  degree     1
#>     0  Gita  degree     1
#>     0  Hugo  degree     1
#>     0  Iris  degree     2
#>     0 Jonas  degree     2
#>     0  Kira  degree     2
#>     0   Leo  degree     2
#> # 604 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = "prestige", rescale = TRUE)
#> # Indegree prestige (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node  measure value
#>     0   Ana prestige   0.1
#>     0   Ben prestige   0.1
#>     0  Cara prestige   0.1
#>     0   Dan prestige   0.1
#>     0   Eve prestige   0.0
#>     0  Finn prestige   0.1
#>     0  Gita prestige   0.0
#>     0  Hugo prestige   0.1
#>     0  Iris prestige   0.1
#>     0 Jonas prestige   0.0
#>     0  Kira prestige   0.1
#>     0   Leo prestige   0.0
#> # 296 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = "prestige",
               prestige = "indegree.rownorm")
#> # Row-normalized indegree prestige (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node  measure value
#>     0   Ana prestige   1.0
#>     0   Ben prestige   1.0
#>     0  Cara prestige   1.0
#>     0   Dan prestige   0.5
#>     0   Eve prestige   0.0
#>     0  Finn prestige   1.0
#>     0  Gita prestige   0.0
#>     0  Hugo prestige   0.5
#>     0  Iris prestige   0.5
#>     0 Jonas prestige   0.0
#>     0  Kira prestige   0.5
#>     0   Leo prestige   0.0
#> # 296 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = "prestige", prestige = "domain")
#> # Domain prestige (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node  measure value
#>     0   Ana prestige     1
#>     0   Ben prestige     2
#>     0  Cara prestige     2
#>     0   Dan prestige     1
#>     0   Eve prestige     0
#>     0  Finn prestige     3
#>     0  Gita prestige     0
#>     0  Hugo prestige     1
#>     0  Iris prestige     1
#>     0 Jonas prestige     0
#>     0  Kira prestige     1
#>     0   Leo prestige     0
#> # 296 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = "prestige",
               prestige = "domain.proximity")
#> # Domain proximity prestige (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node  measure      value
#>     0   Ana prestige 0.07692308
#>     0   Ben prestige 0.10256410
#>     0  Cara prestige 0.10256410
#>     0   Dan prestige 0.07692308
#>     0   Eve prestige 0.00000000
#>     0  Finn prestige 0.13846154
#>     0  Gita prestige 0.00000000
#>     0  Hugo prestige 0.07692308
#>     0  Iris prestige 0.07692308
#>     0 Jonas prestige 0.00000000
#>     0  Kira prestige 0.07692308
#>     0   Leo prestige 0.00000000
#> # 296 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = "prestige", prestige = "eigenvector")
#> Warning: Eigenvector prestige is undefined in 7 reporting block(s); values are NA. See `as.data.frame(x, what = "diagnostics")`.
#> # Eigenvector prestige (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node  measure value
#>     0   Ana prestige    NA
#>     0   Ben prestige    NA
#>     0  Cara prestige    NA
#>     0   Dan prestige    NA
#>     0   Eve prestige    NA
#>     0  Finn prestige    NA
#>     0  Gita prestige    NA
#>     0  Hugo prestige    NA
#>     0  Iris prestige    NA
#>     0 Jonas prestige    NA
#>     0  Kira prestige    NA
#>     0   Leo prestige    NA
#> # 296 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = "prestige",
               prestige = "eigenvector.rownorm")
#> Warning: Eigenvector prestige is undefined in 7 reporting block(s); values are NA. See `as.data.frame(x, what = "diagnostics")`.
#> # Row-normalized eigenvector prestige (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node  measure value
#>     0   Ana prestige    NA
#>     0   Ben prestige    NA
#>     0  Cara prestige    NA
#>     0   Dan prestige    NA
#>     0   Eve prestige    NA
#>     0  Finn prestige    NA
#>     0  Gita prestige    NA
#>     0  Hugo prestige    NA
#>     0  Iris prestige    NA
#>     0 Jonas prestige    NA
#>     0  Kira prestige    NA
#>     0   Leo prestige    NA
#> # 296 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = "prestige",
               prestige = "eigenvector.colnorm")
#> Warning: Eigenvector prestige is undefined in 7 reporting block(s); values are NA. See `as.data.frame(x, what = "diagnostics")`.
#> # Column-normalized eigenvector prestige (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node  measure value
#>     0   Ana prestige    NA
#>     0   Ben prestige    NA
#>     0  Cara prestige    NA
#>     0   Dan prestige    NA
#>     0   Eve prestige    NA
#>     0  Finn prestige    NA
#>     0  Gita prestige    NA
#>     0  Hugo prestige    NA
#>     0  Iris prestige    NA
#>     0 Jonas prestige    NA
#>     0  Kira prestige    NA
#>     0   Leo prestige    NA
#> # 296 more rows. summary() aggregates them; plot() draws them.
dyn_centrality(dn, measure = "prestige",
               prestige = "eigenvector.rowcolnorm")
#> Warning: Row-column prestige is structurally undefined in 22 reporting block(s); values are NA. See `as.data.frame(x, what = "diagnostics")`.
#> # Row-column-normalized eigenvector prestige (node-level)
#> # 14 vertices | 22 time points, 1 per bin | time in step
#>  time  node  measure value
#>     0   Ana prestige    NA
#>     0   Ben prestige    NA
#>     0  Cara prestige    NA
#>     0   Dan prestige    NA
#>     0   Eve prestige    NA
#>     0  Finn prestige    NA
#>     0  Gita prestige    NA
#>     0  Hugo prestige    NA
#>     0  Iris prestige    NA
#>     0 Jonas prestige    NA
#>     0  Kira prestige    NA
#>     0   Leo prestige    NA
#> # 296 more rows. summary() aggregates them; plot() draws them.
# Temporal scope walks journeys between every ordered pair, so it costs far
# more than a snapshot and grows steeply with the vertex count. Shown on a
# subgraph so the example stays quick.
few <- induce_subgraph(dn, nodes = c("Ana", "Ben", "Cara", "Dan", "Eve",
                                     "Finn", "Gita", "Hugo"))
dyn_centrality(few, measure = "closeness", scope = "temporal")
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
dyn_centrality(few, measure = "reach", scope = "temporal",
               start = 0, end = 10)
#> # Reachability (node-level)
#> # 8 vertices | time in step
#> # computed on time-respecting paths within the requested traversal window
#>  node measure     value
#>   Ana   reach 0.5714286
#>   Ben   reach 0.7142857
#>  Cara   reach 0.2857143
#>   Dan   reach 0.8571429
#>   Eve   reach 0.8571429
#>  Finn   reach 0.2857143
#>  Gita   reach 0.5714286
#>  Hugo   reach 0.8571429

# A seven-day window, stepped one day at a time.
dyn_centrality(dn, measure = "degree", step = 1, window = 7)
#> # Degree (node-level)
#> # 14 vertices | 22 time points, step 1, window 7 (rolling) | time in step
#>  time  node measure value
#>     0   Ana  degree     9
#>     0   Ben  degree     6
#>     0  Cara  degree     9
#>     0   Dan  degree     8
#>     0   Eve  degree     9
#>     0  Finn  degree     9
#>     0  Gita  degree    10
#>     0  Hugo  degree     7
#>     0  Iris  degree     9
#>     0 Jonas  degree    10
#>     0  Kira  degree    10
#>     0   Leo  degree     9
#> # 296 more rows. summary() aggregates them; plot() draws them.

summary(dyn_centrality(dn, measure = "degree"))
#>     node measure  n     mean       sd min max peak_time
#> 1    Ana  degree 22 2.181818 2.015095   0   7         6
#> 2    Ben  degree 22 2.000000 1.234427   0   4         4
#> 3   Cara  degree 22 2.227273 1.342770   0   5         4
#> 4    Dan  degree 22 2.090909 1.444500   1   5        13
#> 5    Eve  degree 22 2.272727 2.051290   0   8        14
#> 6   Finn  degree 22 2.000000 1.661898   0   6        12
#> 7   Gita  degree 22 1.727273 1.777688   0   7         6
#> 8   Hugo  degree 22 2.318182 1.861550   0   6         6
#> 9   Iris  degree 22 1.772727 1.066004   0   4        11
#> 10 Jonas  degree 22 2.863636 2.076982   0   7        13
#> 11  Kira  degree 22 2.636364 1.255292   1   6         6
#> 12   Leo  degree 22 1.636364 1.432462   0   5         6
#> 13  Mira  degree 22 2.272727 1.695423   0   6        13
#> 14  Nils  degree 22 2.181818 2.174229   0   7        14
```
