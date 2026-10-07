# Simulate a random temporal network

Generates a temporal network with a known generating process, so a
measure can be checked against an answer that is known in advance rather
than only against another implementation. A Poisson process has
burstiness exactly zero; a binomial network has expected per-slice
density exactly `p`; a block network carries its planted partition as a
node attribute.

## Usage

``` r
random_dynet(
  nodes = 20L,
  times = 20L,
  model = c("binomial", "poisson", "block", "activation"),
  p = 0.1,
  birth = NULL,
  persist = NULL,
  rate = 1,
  blocks = 2L,
  p_within = 0.3,
  p_between = 0.02,
  block_switch = 0,
  waiting = c("exponential", "weibull", "lognormal"),
  shape = 1,
  directed = TRUE,
  interval = 1,
  loops = FALSE,
  seed = NULL
)
```

## Arguments

- nodes:

  A vertex count, or a character vector of names. A count generates
  zero-padded names so that lexical and numeric order agree.

- times:

  Number of slices for the slice models, or the length of the
  observation window for the event models.

- model:

  `"binomial"` for independent per-slice edges, `"poisson"` for a
  renewal process on every dyad, `"block"` for a planted partition, or
  `"activation"` for a static graph whose links activate as a renewal
  process with tunable burstiness.

- p:

  Per-slice edge probability for `"binomial"`, or the density of the
  underlying static graph for `"activation"`.

- birth, persist:

  The two-state Markov variant of `"binomial"`: probability an inactive
  dyad becomes active, and probability an active one stays active. Named
  `persist`, not a death rate, because that is what it is. Supplying
  either requires both and forbids `p`.

- rate:

  Mean events per unit time for the event models.

- blocks:

  A block count, or one block label per vertex.

- p_within, p_between:

  Per-slice edge probability inside and between blocks.

- block_switch:

  Per-slice probability a vertex changes block, so the planted partition
  drifts. Zero gives a static partition.

- waiting, shape:

  The renewal gap distribution for `"activation"`. Weibull with
  `shape < 1` is bursty, `shape > 1` regular, `shape = 1` Poisson. The
  scale is set so the mean gap is `1 / rate` at every shape.

- directed, interval, loops:

  Passed through to
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- seed:

  A single whole number for a reproducible draw, or `NULL`.

## Value

A `dynet`, so every verb, plot and accessor applies with no special
casing. `"binomial"` and `"block"` produce interval networks;
`"poisson"` and `"activation"` produce contact networks. For `"block"`
the planted partition is written into the node table as `block`, so
`mixing(dn, attribute = "block")` reads it with no further argument.

## Details

The slice models draw a dyad-by-slice activity matrix and then collapse
each maximal run of consecutive active slices into one spell. The
generated network therefore has fewer, longer spells than the model has
active slices, which is what makes it a spell network rather than a
stack of snapshots.

`"poisson"` and `"activation"` use **exponential** waiting times, so
they are genuine renewal processes. teneto's `rand_poisson` draws
integer gaps that can be zero, which is not a Poisson process and is not
numerically comparable with these.

**Reading burstiness off a generated network.**
[`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
is a node-level measure: it pools the events of every dyad incident to a
vertex. Superposing independent renewal processes drives the pooled
process toward Poisson, so a vertex with many partners scores near zero
however bursty each of its links is. Measured here at `shape = 0.5`,
whose per-link burstiness is 0.382: a vertex with one incident process
scored 0.36, with three 0.26, with seven 0.19 and with fifteen 0.14. To
calibrate against the per-link value, generate
`nodes = 2, directed = FALSE`, which gives each vertex exactly one
process. This is a property of the measure, not of the generator.

Weibull waiting has a closed-form burstiness, \\B = (\sigma -
\mu)/(\sigma + \mu)\\ with \\\mu = \Gamma(1 + 1/k)\\ and \\\sigma^2 =
\Gamma(1 + 2/k) - \mu^2\\, giving 0.381966 at `shape = 0.5`, 0 at
`shape = 1` and -0.313436 at `shape = 2`. The generated network
approaches these from a finite window; `shape = 0.5` converges most
slowly because its gaps are heavy-tailed.

## References

Erdos, P., and Renyi, A. (1959). On random graphs I. *Publicationes
Mathematicae*, 6, 290-297.

Holland, P. W., Laskey, K. B., and Leinhardt, S. (1983). Stochastic
blockmodels: first steps. *Social Networks*, 5(2), 109-137.

Goh, K.-I., and Barabasi, A.-L. (2008). Burstiness and memory in complex
systems. *Europhysics Letters*, 81(4), 48002.

Vazquez, A., Oliveira, J. G., Dezso, Z., Goh, K.-I., Kondor, I., and
Barabasi, A.-L. (2006). Modeling bursts and heavy tails in human
dynamics. *Physical Review E*, 73, 036127.

## See also

[`randomise()`](https://pak.dynasite.org/Dynet/reference/randomise.md)
for destroying structure in an observed network rather than generating
it.

## Examples

``` r
random_dynet(nodes = 10, times = 12, model = "binomial", p = 0.2, seed = 1)
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 10 vertices | 175 edge spells | 78 distinct pairs
#> # observed from 0 to 12 step, binned every 1
#> 
#>  from  to start end duration weight
#>   n02 n04     0   1        1      1
#>   n04 n09     0   1        1      1
#>   n05 n09     0   1        1      1
#>   n06 n05     0   1        1      1
#>   n07 n01     0   1        1      1
#>   n07 n08     0   1        1      1
#> # 169 more spells. summary() describes the network; plot() draws it.
random_dynet(nodes = 8, times = 50, model = "poisson", rate = 0.5, seed = 1)
#> # Temporal network (contact format, directed) | a cograph netobject
#> # 8 vertices | 1352 edge spells | 56 distinct pairs
#> # observed from 0 to 50 step, binned every 1
#> 
#>  from to      start        end duration weight
#>    n8 n5 0.02359703 0.02359703        0      1
#>    n4 n7 0.05120572 0.05120572        0      1
#>    n2 n4 0.05766733 0.05766733        0      1
#>    n4 n7 0.06961835 0.06961835        0      1
#>    n5 n2 0.07040424 0.07040424        0      1
#>    n3 n6 0.07912021 0.07912021        0      1
#> # 1346 more spells. summary() describes the network; plot() draws it.
random_dynet(nodes = 12, times = 15, model = "block", blocks = 2, seed = 1)
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 12 vertices | 206 edge spells | 76 distinct pairs
#> # observed from 0 to 15 step, binned every 1
#> # vertex attributes: block
#> 
#>  from  to start end duration weight
#>   n02 n04     0   1        1      1
#>   n04 n12     0   1        1      1
#>   n05 n01     0   1        1      1
#>   n05 n10     0   1        1      1
#>   n07 n01     0   1        1      1
#>   n07 n09     0   1        1      1
#> # 200 more spells. summary() describes the network; plot() draws it.
```
