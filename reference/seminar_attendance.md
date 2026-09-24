# Seminar attendance

Which students attended which weekly seminar over one term. This is
two-mode data: students are not linked to each other directly, only to
the seminars they turned up to.
[`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) projects
it, connecting every pair of students who shared a room in the week they
shared it.

## Usage

``` r
seminar_attendance
```

## Format

A `data.frame` with 104 rows and 3 columns:

- student:

  Character. Student identifier, `s01` to `s24`.

- seminar:

  Character. Which weekly seminar, `week_01` to `week_12`.

- date:

  `Date`. When the seminar was held, 2024-09-03 to 2024-11-19.

## Source

Simulated, not observed. Generated deterministically under a fixed seed
by `data-raw/make-data.R`.

## Examples

``` r
dynet(seminar_attendance, actor = "student", group = "seminar")
#> # Temporal network (copresence format, undirected) | a cograph netobject
#> # 24 vertices | 417 edge spells | 224 distinct pairs
#> # observed from 0 to 77 days, binned every 1
#> 
#>  from  to start end duration weight   group
#>   s03 s10     0   0        0      1 week_01
#>   s03 s12     0   0        0      1 week_01
#>   s03 s21     0   0        0      1 week_01
#>   s03 s22     0   0        0      1 week_01
#>   s03 s23     0   0        0      1 week_01
#>   s10 s12     0   0        0      1 week_01
#> # 411 more spells. summary() describes the network; plot() draws it.
```
