# Similarity between the networks at each pair of time points

Compares the edge set at every time bin with the edge set at every
other, giving the pairwise similarity matrix as a tidy frame. This
answers how much the network at one moment resembles the network at
another, which no single-bin measure reports and which the formation and
dissolution quantities in
[`events()`](https://mohsaqr.github.io/Dynet/reference/events.md) only
address between neighbouring bins.

Coefficients are computed by
[`cograph::layer_similarity()`](https://sonsoles.me/cograph/reference/layer_similarity.html).

## Usage

``` r
similarity(
  dn,
  method = c("jaccard", "overlap", "hamming", "cosine", "pearson"),
  sessions = c("bounded", "collapse", "separate"),
  start = NULL,
  end = NULL,
  step = NULL,
  window = NULL,
  plot = FALSE
)
```

## Arguments

- dn:

  A temporal network from
  [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md).

- method:

  One of `"jaccard"` (the default), `"overlap"`, `"hamming"`, `"cosine"`
  or `"pearson"`.

- sessions:

  How to treat sessions, as in
  [`dyn_centrality()`](https://mohsaqr.github.io/Dynet/reference/dyn_centrality.md).

- start, end:

  First and last time to measure. Default to the observed range.

- step, window:

  How often to measure and how much time each measurement covers.
  Default to the interval the network was built with. `window = "all"`
  is rejected here, because a similarity matrix of one bin against
  itself says nothing.

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

A `dynet_similarity` data frame with one row per ordered pair of time
bins and columns `time`, `other`, `measure` and `value`. The diagonal is
included and is one for every coefficient except `"hamming"`, where
identical layers differ in nothing and score zero. `"pearson"` reaches
one only to floating-point accuracy, so compare it with a tolerance
rather than with `==`.

## See also

[`snapshots()`](https://mohsaqr.github.io/Dynet/reference/snapshots.md)
for the networks being compared,
[`events()`](https://mohsaqr.github.io/Dynet/reference/events.md) for
formation and dissolution between neighbouring bins.

## Examples

``` r
dn <- dynet(school_contacts)
similarity(dn)
#> # jaccard similarity across 22 time bins
#> # off-diagonal mean 0.079, range 0.000 to 0.636
#>    time other measure      value
#> 1     0     0 jaccard 1.00000000
#> 2     0     1 jaccard 0.28571429
#> 3     0     2 jaccard 0.00000000
#> 4     0     3 jaccard 0.00000000
#> 5     0     4 jaccard 0.00000000
#> 6     0     5 jaccard 0.08333333
#> 7     0     6 jaccard 0.08333333
#> 8     0     7 jaccard 0.03571429
#> 9     0     8 jaccard 0.12000000
#> 10    0     9 jaccard 0.08333333
#> # 474 more rows
similarity(dn, method = "cosine")
#> # cosine similarity across 22 time bins
#> # off-diagonal mean 0.144, range 0.000 to 0.783
#>    time other measure      value
#> 1     0     0  cosine 1.00000000
#> 2     0     1  cosine 0.44721360
#> 3     0     2  cosine 0.00000000
#> 4     0     3  cosine 0.00000000
#> 5     0     4  cosine 0.00000000
#> 6     0     5  cosine 0.15811388
#> 7     0     6  cosine 0.17616607
#> 8     0     7  cosine 0.07254763
#> 9     0     8  cosine 0.22360680
#> 10    0     9  cosine 0.15811388
#> # 474 more rows
```
