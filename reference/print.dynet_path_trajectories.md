# Print a temporal trajectory tree

Print a temporal trajectory tree

## Usage

``` r
# S3 method for class 'dynet_path_trajectories'
print(x, ...)
```

## Arguments

- x:

  A result from
  [`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md).

- ...:

  Passed to the data frame print method.

## Value

`x`, invisibly. Called for the side effect of printing a header naming
the direction, anchor, node count, depth and number of routes, followed
by the tidy table.

## Examples

``` r
dn <- dynet(school_contacts)
routes <- paths(dn, from = "Ana")
trajectories <- path_trajectories(routes)
print(trajectories)
#> # Forward temporal trajectory tree from Ana
#> # 22 nodes, 4 hops deep, 19 routes
#>                                                         node
#> 1                                                      Ana@0
#> 2                                         Ana@0 -> Cara@6.67
#> 3                            Ana@0 -> Cara@6.67 -> Finn@6.96
#> 4                 Ana@0 -> Cara@6.67 -> Finn@6.96 -> Iris@10
#> 5                Ana@0 -> Cara@6.67 -> Finn@6.96 -> Leo@9.65
#> 6                            Ana@0 -> Cara@6.67 -> Nils@7.51
#> 7               Ana@0 -> Cara@6.67 -> Nils@7.51 -> Hugo@7.98
#> 8   Ana@0 -> Cara@6.67 -> Nils@7.51 -> Hugo@7.98 -> Dan@7.98
#> 9                                        Ana@0 -> Jonas@2.12
#> 10                          Ana@0 -> Jonas@2.12 -> Kira@6.12
#> 11              Ana@0 -> Jonas@2.12 -> Kira@6.12 -> Ben@9.59
#> 12 Ana@0 -> Jonas@2.12 -> Kira@6.12 -> Ben@9.59 -> Eve@11.66
#> 13                                       Ana@0 -> Jonas@3.43
#> 14                          Ana@0 -> Jonas@3.43 -> Kira@6.12
#> 15              Ana@0 -> Jonas@3.43 -> Kira@6.12 -> Ben@9.59
#> 16 Ana@0 -> Jonas@3.43 -> Kira@6.12 -> Ben@9.59 -> Eve@11.66
#> 17                                       Ana@0 -> Jonas@6.68
#> 18                          Ana@0 -> Jonas@6.68 -> Kira@6.68
#> 19              Ana@0 -> Jonas@6.68 -> Kira@6.68 -> Ben@9.59
#> 20 Ana@0 -> Jonas@6.68 -> Kira@6.68 -> Ben@9.59 -> Eve@11.66
#> 21                                        Ana@0 -> Mira@6.36
#> 22                           Ana@0 -> Mira@6.36 -> Gita@6.36
#>                                          parent depth count probability vertex
#> 1                                          <NA>     0    19          NA    Ana
#> 2                                         Ana@0     1     7   0.3684211   Cara
#> 3                            Ana@0 -> Cara@6.67     2     3   0.4285714   Finn
#> 4               Ana@0 -> Cara@6.67 -> Finn@6.96     3     1   0.3333333   Iris
#> 5               Ana@0 -> Cara@6.67 -> Finn@6.96     3     1   0.3333333    Leo
#> 6                            Ana@0 -> Cara@6.67     2     3   0.4285714   Nils
#> 7               Ana@0 -> Cara@6.67 -> Nils@7.51     3     2   0.6666667   Hugo
#> 8  Ana@0 -> Cara@6.67 -> Nils@7.51 -> Hugo@7.98     4     1   0.5000000    Dan
#> 9                                         Ana@0     1     4   0.2105263  Jonas
#> 10                          Ana@0 -> Jonas@2.12     2     3   0.7500000   Kira
#> 11             Ana@0 -> Jonas@2.12 -> Kira@6.12     3     2   0.6666667    Ben
#> 12 Ana@0 -> Jonas@2.12 -> Kira@6.12 -> Ben@9.59     4     1   0.5000000    Eve
#> 13                                        Ana@0     1     3   0.1578947  Jonas
#> 14                          Ana@0 -> Jonas@3.43     2     3   1.0000000   Kira
#> 15             Ana@0 -> Jonas@3.43 -> Kira@6.12     3     2   0.6666667    Ben
#> 16 Ana@0 -> Jonas@3.43 -> Kira@6.12 -> Ben@9.59     4     1   0.5000000    Eve
#> 17                                        Ana@0     1     2   0.1052632  Jonas
#> 18                          Ana@0 -> Jonas@6.68     2     2   1.0000000   Kira
#> 19             Ana@0 -> Jonas@6.68 -> Kira@6.68     3     2   1.0000000    Ben
#> 20 Ana@0 -> Jonas@6.68 -> Kira@6.68 -> Ben@9.59     4     1   0.5000000    Eve
#> 21                                        Ana@0     1     2   0.1052632   Mira
#> 22                           Ana@0 -> Mira@6.36     2     1   0.5000000   Gita
#>     time session branch
#> 1   0.00    <NA>   3.15
#> 2   6.67    <NA>   5.75
#> 3   6.96    <NA>   6.50
#> 4  10.00    <NA>   7.00
#> 5   9.65    <NA>   6.00
#> 6   7.51    <NA>   5.00
#> 7   7.98    <NA>   5.00
#> 8   7.98    <NA>   5.00
#> 9   2.12    <NA>   4.00
#> 10  6.12    <NA>   4.00
#> 11  9.59    <NA>   4.00
#> 12 11.66    <NA>   4.00
#> 13  3.43    <NA>   3.00
#> 14  6.12    <NA>   3.00
#> 15  9.59    <NA>   3.00
#> 16 11.66    <NA>   3.00
#> 17  6.68    <NA>   2.00
#> 18  6.68    <NA>   2.00
#> 19  9.59    <NA>   2.00
#> 20 11.66    <NA>   2.00
#> 21  6.36    <NA>   1.00
#> 22  6.36    <NA>   1.00
```
