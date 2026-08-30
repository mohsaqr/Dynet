# Discussion forum posts

Posts in a course discussion forum over roughly eight weeks. Each row is
one post directed at an earlier poster in the same thread. Because a
post has a timestamp but no end, the duration of the tie has to be
derived: [`dynet()`](https://mohsaqr.github.io/Dynet/reference/dynet.md)
treats a post as active until the last post in its thread, so a message
that provoked a long argument stays live longer than one that fell flat.

## Usage

``` r
forum_posts
```

## Format

A `data.frame` with 241 rows and 4 columns:

- sender:

  Character. Who wrote the post.

- receiver:

  Character. Who the post replied to.

- timestamp:

  `POSIXct`. When the post was made.

- thread:

  Character. The discussion thread it belongs to.

## Details

Pairs with
[forum_people](https://mohsaqr.github.io/Dynet/reference/forum_people.md),
which carries the roles used for mixing analysis.

## Examples

``` r
dynet(forum_posts, thread = "thread", nodes = forum_people)
#> # Temporal network (threaded format, directed) | a cograph netobject
#> # 20 vertices | 241 edge spells | 172 distinct pairs
#> # observed from 0 to 54.96387 days, binned every 1
#> # vertex attributes: role, achievement
#> 
#>        from         to     start      end duration weight    thread
#>  student_14 student_05 0.0000000 2.296969 2.296969      1 thread_47
#>  student_10 student_05 0.7257216 2.296969 1.571247      1 thread_47
#>   teacher_A student_09 0.8559934 3.235993 2.380000      1 thread_11
#>  student_04 student_05 1.1715344 2.296969 1.125435      1 thread_47
#>  student_02 student_09 1.2382611 3.235993 1.997732      1 thread_11
#>  student_06  teacher_A 1.9797595 3.235993 1.256234      1 thread_11
#> # 235 more spells. summary() describes the network; plot() draws it.
```
