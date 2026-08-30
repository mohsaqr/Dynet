# Summarise snapshot similarity

Summarise snapshot similarity

## Usage

``` r
# S3 method for class 'dynet_similarity'
summary(object, ...)
```

## Arguments

- object:

  A `dynet_similarity` result.

- ...:

  Ignored.

## Value

A plain `data.frame`, one row per bin: `time`, the `mean`, `min` and
`max` similarity to every other bin, and `nearest`, the time of the most
similar other bin. The self-comparison is excluded throughout, so a bin
with no comparable neighbour reports `NaN` and `NA`.

## Examples

``` r
summary(similarity(dynet(school_contacts), step = 5, window = 5))
#>   time      mean        min       max nearest
#> 1    0 0.2056708 0.11764706 0.2987013       5
#> 2    5 0.2484987 0.08450704 0.3707865      10
#> 3   10 0.2614999 0.14492754 0.3707865       5
#> 4   15 0.2273164 0.17741935 0.3013699      10
#> 5   20 0.1343895 0.08450704 0.1904762      15
```
