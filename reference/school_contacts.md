# Student contacts recorded as intervals

Face-to-face contacts among fourteen students over three weeks. Each row
is one contact with an explicit start and end, which makes this an
interval log: duration carries information, and two students who met
once at length are distinguishable from two who met briefly many times.
The students fall into three loosely-connected friendship clusters and
overall activity rises through the second week before falling away.

## Usage

``` r
school_contacts
```

## Format

A `data.frame` with 240 rows and 4 columns:

- from:

  Character. The student initiating the contact.

- to:

  Character. The other student.

- start:

  Numeric. Day the contact began, counted from day zero.

- end:

  Numeric. Day the contact ended.

## Examples

``` r
dynet(school_contacts)
#> # Temporal network (interval format, directed) | a cograph netobject
#> # 14 vertices | 240 edge spells | 110 distinct pairs
#> # observed from 0 to 21.52 step, binned every 1
#> 
#>   from   to start  end duration weight
#>  Jonas  Dan  0.00 1.10     1.10      1
#>   Gita  Ana  0.14 0.98     0.84      1
#>    Leo Mira  0.15 0.42     0.27      1
#>    Leo Iris  0.15 0.96     0.81      1
#>   Kira  Ben  0.33 0.69     0.36      1
#>    Leo Iris  0.38 0.50     0.12      1
#> # 234 more spells. summary() describes the network; plot() draws it.
```
