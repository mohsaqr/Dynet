# People in the discussion forum

Vertex attributes for
[forum_posts](https://mohsaqr.github.io/Dynet/reference/forum_posts.md).
Passed to
[`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md) through
its `nodes` argument, these become available to
[`mixing()`](https://mohsaqr.github.io/Dynet/reference/mixing.md).

## Usage

``` r
forum_people
```

## Format

A `data.frame` with 20 rows and 3 columns:

- name:

  Character. Matches the sender and receiver names in
  [forum_posts](https://mohsaqr.github.io/Dynet/reference/forum_posts.md).

- role:

  Character. `"Student"`, `"Teacher"` or `"Facilitator"`.

- achievement:

  Character. `"High"`, `"Middle"` or `"Low"` for students; `NA` for
  staff.

## Examples

``` r
dn <- dynet(forum_posts, thread = "thread", nodes = forum_people)
mixing(dn, attribute = "role")
#> # Mixing by role (graph-level)
#> # 55 time points, 1 per bin | time in days
#> # measures: Facilitator -> Facilitator, Student -> Facilitator, Teacher -> Facilitator, Facilitator -> Student, Student -> Student, Teacher -> Student, Facilitator -> Teacher, Student -> Teacher, Teacher -> Teacher
#> # active binary-dyad counts between vertex groups per time bin
#>  time                    measure value  from_group    to_group
#>     0 Facilitator -> Facilitator     0 Facilitator Facilitator
#>     0     Student -> Facilitator     0     Student Facilitator
#>     0     Teacher -> Facilitator     0     Teacher Facilitator
#>     0     Facilitator -> Student     0 Facilitator     Student
#>     0         Student -> Student     2     Student     Student
#>     0         Teacher -> Student     1     Teacher     Student
#>     0     Facilitator -> Teacher     0 Facilitator     Teacher
#>     0         Student -> Teacher     0     Student     Teacher
#>     0         Teacher -> Teacher     0     Teacher     Teacher
#>     1 Facilitator -> Facilitator     0 Facilitator Facilitator
#>     1     Student -> Facilitator     0     Student Facilitator
#>     1     Teacher -> Facilitator     0     Teacher Facilitator
#> # 483 more rows. summary() aggregates them; plot() draws them.
```
