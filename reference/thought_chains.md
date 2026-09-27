# Trees of Thought reply links, augmented by simulation

A table of reply links between the codes of messages in coded
asynchronous discussions, based on the *Trees of Thought* study. Each
row is one link from the code of a message to the code of the message it
replies to. About 20 percent of the study's records were removed, dates
and rates were changed and anonymised, and the data were augmented by
simulation, so the table is not the study's data, and the participant,
group, course and time values do not identify anyone.

Thursdays and Fridays do not occur. Some rows repeat exactly (8,122
duplicates); aggregating the log counts them as weight. A code answering
itself is a self-link (9,452 rows);
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

  `POSIXct` (UTC) time of the replying message, 2006-09-23 to
  2011-11-02; changed and anonymised, not the study's dates.

- participant:

  Character. Author label, `P001` to `P240`.

- discussion:

  Integer discussion (thread) id, 1 to 1169, all present.

- group:

  Character. Course group, `A_01` style; 29 groups.

- course:

  Character. Course, `A` to `E`.

## Source

Based on the *Trees of Thought* study of coded asynchronous discussions,
with about 20 percent of the records removed, dates and rates changed
and anonymised, and the data augmented by simulation: Saqr, M.,
López-Pernas, S. and Törmänen, T. (2026). A temporal network approach to
reveal the longitudinal dynamics of CSCL group regulation and productive
collaboration. *International Journal of Computer-Supported
Collaborative Learning*, 21, 237-270.
[doi:10.1007/s11412-025-09464-5](https://doi.org/10.1007/s11412-025-09464-5)

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
