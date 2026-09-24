# Posts in a MOOC discussion forum

The discussion log of chapter 17 of *Learning Analytics Methods and
Tutorials* (Saqr, 2024), one row per post in the Digital Learning
Transition MOOC, April to June 2013. A post names the participant who
wrote it and the participant it answers, so a tie runs from sender to
receiver; `discussion` is the thread the post belongs to, which is what
makes the log threaded in the sense
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) means by
`thread =`.

## Usage

``` r
mooc_posts
```

## Format

A data frame with 2529 rows and 4 columns:

- sender:

  Character. The participant who wrote the post.

- receiver:

  Character. The participant the post answers.

- timestamp:

  POSIXct (UTC). When the post was made, from 2013-04-04 16:32 to
  2013-06-16 17:12.

- discussion:

  Character. Thread title; 338 distinct threads.

## Source

Saqr, M. (2024). Temporal network analysis: Introduction, methods and
analysis with R. In M. Saqr & S. López-Pernas (Eds.), *Learning
Analytics Methods and Tutorials*. Springer.
[doi:10.1007/978-3-031-54464-4_17](https://doi.org/10.1007/978-3-031-54464-4_17)
. Data from <https://github.com/lamethods/data>, directory `6_snaMOOC`,
prepared by `data-raw/mooc_forum.R`.

## Details

Only the four columns the chapter's analysis reads are kept; the
category hierarchy and comment identifiers of the published file are
dropped.

## See also

[mooc_people](https://pak.dynasite.org/Dynet/reference/mooc_people.md)
for the participants, and
[`vignette("ch17-temporal-networks")`](https://pak.dynasite.org/Dynet/articles/ch17-temporal-networks.md)
for the chapter's analysis.

## Examples

``` r
# summary() measures every graph-level statistic on all 74 daily bins and
# takes about 28 seconds on this network; print() is immediate. The article
# `vignette("mooc-posts")` walks through the data with stated grids.
dn <- dynet(mooc_posts, from = "sender", to = "receiver",
            time = "timestamp", thread = "discussion")
#> Dropped 86 self-loop event(s). Use loops = TRUE to keep them.
dn
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 442 vertices | 2443 edge spells | 1936 distinct pairs
#> # observed from 0 to 73.02778 days, binned every 1
#> 
#>  from  to      start      end duration weight
#>   360 444 0.00000000 69.47778 69.47778      1
#>   356 444 0.09236111 69.47778 69.38542      1
#>   356 444 0.09375000 51.93889 51.84514      1
#>   344 444 0.09930556 69.47778 69.37847      1
#>   392 444 0.11180556 69.47778 69.36597      1
#>   219 444 0.11388889 69.47778 69.36389      1
#>                                              thread
#>  Most important change for your school or district?
#>  Most important change for your school or district?
#>              DLT Resources—Comments and Suggestions
#>  Most important change for your school or district?
#>  Most important change for your school or district?
#>  Most important change for your school or district?
#> # 2437 more spells. summary() describes the network; plot() draws it.
```
