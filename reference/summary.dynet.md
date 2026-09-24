# Describe a temporal network

A tidy description of the whole network, one row per property. Two
densities are reported and they answer different questions. Snapshot
density is the mean over time bins of realised against possible edges.
Temporal density is the proportion of all possible relational exposure
occupied during the observation window. Overlapping and duplicate spells
for the same ordered pair, or dyad in an undirected network, are unioned
before their duration is counted.

## Usage

``` r
# S3 method for class 'dynet'
summary(object, temporal_density = FALSE, ...)
```

## Arguments

- object:

  A temporal network from
  [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md).

- temporal_density:

  Whether to compute the temporal-density row. `FALSE`, the default,
  reports `"not computed"` for it. The quantity integrates exact
  occupancy over every eligible ordered pair, so its cost grows with the
  square of the vertex count: on a 442-vertex forum network it takes
  about 32 seconds, while every other row in the table is immediate.
  Pass `TRUE` when the number is wanted.

- ...:

  Ignored.

## Value

A `data.frame` with columns `property` and `value`, one row per
property.

## Details

Let \\Y_q(t)\\ indicate that both endpoints of relational opportunity
\\q\\ are eligible at positive observed time \\t\\, and let \\E_q(t)\\
indicate binary union edge activity. Temporal density is \$\$\rho =
\frac{\sum_q \int Y_q(t)E_q(t)dt} {\sum_q \int Y_q(t)dt}.\$\$ Directed
opportunities are ordered; undirected opportunities are unordered. The
integrals are evaluated exactly over observation, vertex, and edge
change points. Self-loops, weights, session labels, duplicate spells,
genuine points, and observation gaps do not add exposure. A network with
no positive time containing two coeligible distinct vertices has
undefined temporal density and reports `NA`.

This is an occupancy definition. Unlike summing spell durations, it
remains in `[0, 1]` when the same relation has overlapping or duplicated
spells.

## References

Bender-deMoll, S., & Morris, M. (2025). *tsna: Tools for Temporal Social
Network Analysis*. R package version 0.3.6.

Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
519(3), 97-125.

Latapy, M., Viard, T., & Magnien, C. (2018). Stream graphs and link
streams for the modeling of interactions over time. *Social Network
Analysis and Mining*, 8, 61.

## Examples

``` r
dn <- dynet(school_contacts)
summary(dn)
#>                 property        value
#> 1                 format     interval
#> 2               directed          yes
#> 3               vertices           14
#> 4            edge spells          240
#> 5         distinct pairs          110
#> 6              time unit         step
#> 7          observed from            0
#> 8            observed to        21.52
#> 9                   span        21.52
#> 10             bin width            1
#> 11             time bins           22
#> 12 mean snapshot density       0.0829
#> 13      temporal density not computed
#> 14              sessions         none
#> 15     vertex attributes         none

# The temporal density is opt-in, since it is quadratic in the vertex count.
summary(dn, temporal_density = TRUE)
#>                 property    value
#> 1                 format interval
#> 2               directed      yes
#> 3               vertices       14
#> 4            edge spells      240
#> 5         distinct pairs      110
#> 6              time unit     step
#> 7          observed from        0
#> 8            observed to    21.52
#> 9                   span    21.52
#> 10             bin width        1
#> 11             time bins       22
#> 12 mean snapshot density   0.0829
#> 13      temporal density   0.0285
#> 14              sessions     none
#> 15     vertex attributes     none
```
