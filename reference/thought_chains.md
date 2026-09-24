# Trees of Thought reply links, anonymised

Each row is one link from the code of a discussion message to the code
of the message it replies to, from the *Trees of Thought* study of coded
asynchronous discussions. It is the study's own reply table with every
identity removed and its shape trimmed, not a resampled or synthesised
set: each row is a real link with its real weekday and time of day.

Applied to the study table, in order: the two sparse weekdays (Thursday
and Friday, under one percent of links) were dropped; the bottom 20
percent of authors by number of distinct messages were removed together
with the links they authored (replies to them by others remain); author,
message and description columns were dropped, courses became `A` to `E`,
groups `A_01` and so on, discussions were renumbered and authors
relabelled `P001` onward in random order; every timestamp was shifted
back by one fixed random number of whole weeks, so the calendar is
hidden and the weekday kept; and the codes were renamed, with the
study's *Evaluation* and *Acceptance* merged into *Approving*.

A reply carrying two codes that both map to one label yields two
identical rows; the study counted such repeats as weight, and they are
kept as rows. A code answering itself is a self-link (9,452 rows);
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) drops
these unless `loops = TRUE`. The `course` column is recognised as the
session column, so the five courses become sessions unless `session = `
says otherwise.

## Usage

``` r
thought_chains
```

## Format

A `data.frame` with 23,017 rows and 7 columns:

- from:

  Character. Code of the replying message, one of the nine codes
  `Approving`, `Arguing`, `Coordinating`, `Drafting`, `Inquiring`,
  `Objecting`, `Resourcing`, `Socialising`, `Tutoring`.

- to:

  Character. Code of the message replied to, same set.

- time:

  `POSIXct` (UTC) time of the replying message, shifted by whole weeks;
  2006-09-23 to 2011-11-02 after the shift.

- participant:

  Character. Anonymous author label, `P001` to `P240`.

- discussion:

  Integer discussion (thread) id, 1 to 1169, all present.

- group:

  Character. Course group, `A_01` style; 29 groups.

- course:

  Character. Course, `A` to `E`.

## Source

Derived from the *Trees of Thought* study reply table by the procedure
in `data-raw/thought_chains.R`, which needs the study's private files
and is not run at build time.

## Examples

``` r
dynet(thought_chains, time = "time", loops = TRUE)
#> Keeping 9452 self-loop event(s); each adds two to its vertex's degree.
#> # Temporal network (contact format, directed) | a cograph netobject
#> # 9 vertices | 23017 edge spells | 80 distinct pairs
#> # observed from 0 to 1865.447 days, binned every 1
#> # 5 sessions: A, B, C, D, E
#> 
#>          from           to start end duration weight session participant
#>  Coordinating Coordinating     0   0        0      1       A        P028
#>  Coordinating Coordinating     0   0        0      1       A        P028
#>  Coordinating Coordinating     0   0        0      1       A        P028
#>  Coordinating Coordinating     0   0        0      1       A        P028
#>  Coordinating Coordinating     0   0        0      1       A        P028
#>  Coordinating Coordinating     0   0        0      1       A        P028
#>  discussion group
#>           1  A_01
#>           1  A_01
#>           1  A_01
#>           1  A_01
#>           1  A_01
#>           1  A_01
#> # 23011 more spells. summary() describes the network; plot() draws it.
dynet(thought_chains, thread = "discussion")
#> Dropped 9452 self-loop event(s). Use loops = TRUE to keep them.
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 9 vertices | 13565 edge spells | 71 distinct pairs
#> # observed from 0.0028125 to 1865.419 days, binned every 1
#> # 5 sessions: A, B, C, D, E
#> 
#>        from         to       start      end duration weight session thread
#>    Drafting Resourcing 0.002812500 3.111181 3.108368      1       A      2
#>  Resourcing   Drafting 0.002812500 3.111181 3.108368      1       A      2
#>     Arguing   Drafting 0.004525463 3.111181 3.106655      1       A      2
#>     Arguing Resourcing 0.004525463 3.111181 3.106655      1       A      2
#>  Resourcing    Arguing 0.006608796 3.111181 3.104572      1       A      2
#>     Arguing Resourcing 0.008043981 3.111181 3.103137      1       A      2
#>  participant group
#>         P028  A_01
#>         P028  A_01
#>         P028  A_01
#>         P028  A_01
#>         P028  A_01
#>         P028  A_01
#> # 13559 more spells. summary() describes the network; plot() draws it.
```
