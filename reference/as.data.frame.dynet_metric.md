# Tidy data frame of a temporal measure

Tidy data frame of a temporal measure

## Usage

``` r
# S3 method for class 'dynet_metric'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  layout = c("long", "wide"),
  what = c("values", "diagnostics"),
  ...
)
```

## Arguments

- x:

  A `dynet_metric` produced by any measurement verb.

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- layout:

  `"long"` gives one row per observation, which is the default and the
  shape every other verb expects. `"wide"` spreads time across columns,
  giving one row per vertex (or per measure for graph-level quantities),
  which is convenient for exporting a table.

- what:

  `"values"`, the default, gives the measured values. `"diagnostics"`
  gives the record a prestige computation keeps when it cannot produce a
  value, which is what the accompanying warning refers to: one row per
  reporting block that was undefined, infeasible or nonconverged, with
  `session`, `time`, `stage`, `status` and `reason`, the solver's
  `iterations` and `residual`, the `balance_*` family for the row-column
  scaling step, and `spectral_radius`, `eigenspace_dimension` and
  `eigen_residual` for the eigen step. A result with nothing to report
  gives a zero-row frame of those same columns rather than `NULL`.

- ...:

  Ignored.

## Value

A plain `data.frame`. Long layout carries `measure` and `value` with one
row per observation, alongside whichever columns say what was measured:
`session` when the network has sessions, `time` for anything measured on
a grid of bins, `node` for a vertex-level quantity, `from` and `to` for
a pair-level one, `vertex_spell` and `implicit` for per-spell vertex
durations from
[`durations()`](https://mohsaqr.github.io/Dynet/reference/durations.md),
and `from_group` and `to_group` for
[`mixing()`](https://mohsaqr.github.io/Dynet/reference/mixing.md). A
graph-level series carries `time`, `measure` and `value` alone. In wide
layout the identifying columns come first and the remaining columns are
the time points, one per bin.

## Examples

``` r
dn <- dynet(school_contacts)
as.data.frame(dyn_centrality(dn, measure = "degree"))
#>     time  node measure value
#> 1      0   Ana  degree     1
#> 2      0   Ben  degree     1
#> 3      0  Cara  degree     1
#> 4      0   Dan  degree     1
#> 5      0   Eve  degree     2
#> 6      0  Finn  degree     1
#> 7      0  Gita  degree     1
#> 8      0  Hugo  degree     1
#> 9      0  Iris  degree     2
#> 10     0 Jonas  degree     2
#> 11     0  Kira  degree     2
#> 12     0   Leo  degree     2
#> 13     0  Mira  degree     3
#> 14     0  Nils  degree     0
#> 15     1   Ana  degree     0
#> 16     1   Ben  degree     0
#> 17     1  Cara  degree     1
#> 18     1   Dan  degree     1
#> 19     1   Eve  degree     4
#> 20     1  Finn  degree     0
#> 21     1  Gita  degree     1
#> 22     1  Hugo  degree     0
#> 23     1  Iris  degree     3
#> 24     1 Jonas  degree     2
#> 25     1  Kira  degree     2
#> 26     1   Leo  degree     0
#> 27     1  Mira  degree     2
#> 28     1  Nils  degree     0
#> 29     2   Ana  degree     1
#> 30     2   Ben  degree     0
#> 31     2  Cara  degree     1
#> 32     2   Dan  degree     1
#> 33     2   Eve  degree     2
#> 34     2  Finn  degree     1
#> 35     2  Gita  degree     2
#> 36     2  Hugo  degree     1
#> 37     2  Iris  degree     2
#> 38     2 Jonas  degree     3
#> 39     2  Kira  degree     3
#> 40     2   Leo  degree     1
#> 41     2  Mira  degree     0
#> 42     2  Nils  degree     2
#> 43     3   Ana  degree     2
#> 44     3   Ben  degree     2
#> 45     3  Cara  degree     0
#> 46     3   Dan  degree     3
#> 47     3   Eve  degree     3
#> 48     3  Finn  degree     2
#> 49     3  Gita  degree     1
#> 50     3  Hugo  degree     1
#> 51     3  Iris  degree     1
#> 52     3 Jonas  degree     4
#> 53     3  Kira  degree     2
#> 54     3   Leo  degree     2
#> 55     3  Mira  degree     0
#> 56     3  Nils  degree     1
#> 57     4   Ana  degree     1
#> 58     4   Ben  degree     4
#> 59     4  Cara  degree     5
#> 60     4   Dan  degree     1
#> 61     4   Eve  degree     1
#> 62     4  Finn  degree     2
#> 63     4  Gita  degree     0
#> 64     4  Hugo  degree     0
#> 65     4  Iris  degree     3
#> 66     4 Jonas  degree     1
#> 67     4  Kira  degree     3
#> 68     4   Leo  degree     3
#> 69     4  Mira  degree     1
#> 70     4  Nils  degree     1
#> 71     5   Ana  degree     1
#> 72     5   Ben  degree     3
#> 73     5  Cara  degree     4
#> 74     5   Dan  degree     2
#> 75     5   Eve  degree     3
#> 76     5  Finn  degree     4
#> 77     5  Gita  degree     1
#> 78     5  Hugo  degree     1
#> 79     5  Iris  degree     2
#> 80     5 Jonas  degree     1
#> 81     5  Kira  degree     4
#> 82     5   Leo  degree     3
#> 83     5  Mira  degree     1
#> 84     5  Nils  degree     2
#> 85     6   Ana  degree     7
#> 86     6   Ben  degree     2
#> 87     6  Cara  degree     3
#> 88     6   Dan  degree     1
#> 89     6   Eve  degree     4
#> 90     6  Finn  degree     4
#> 91     6  Gita  degree     7
#> 92     6  Hugo  degree     6
#> 93     6  Iris  degree     2
#> 94     6 Jonas  degree     4
#> 95     6  Kira  degree     6
#> 96     6   Leo  degree     5
#> 97     6  Mira  degree     3
#> 98     6  Nils  degree     4
#> 99     7   Ana  degree     6
#> 100    7   Ben  degree     3
#> 101    7  Cara  degree     2
#> 102    7   Dan  degree     1
#> 103    7   Eve  degree     2
#> 104    7  Finn  degree     1
#> 105    7  Gita  degree     2
#> 106    7  Hugo  degree     5
#> 107    7  Iris  degree     3
#> 108    7 Jonas  degree     5
#> 109    7  Kira  degree     1
#> 110    7   Leo  degree     1
#> 111    7  Mira  degree     3
#> 112    7  Nils  degree     3
#> 113    8   Ana  degree     3
#> 114    8   Ben  degree     0
#> 115    8  Cara  degree     3
#> 116    8   Dan  degree     3
#> 117    8   Eve  degree     1
#> 118    8  Finn  degree     1
#> 119    8  Gita  degree     1
#> 120    8  Hugo  degree     5
#> 121    8  Iris  degree     1
#> 122    8 Jonas  degree     6
#> 123    8  Kira  degree     2
#> 124    8   Leo  degree     2
#> 125    8  Mira  degree     5
#> 126    8  Nils  degree     3
#> 127    9   Ana  degree     2
#> 128    9   Ben  degree     2
#> 129    9  Cara  degree     1
#> 130    9   Dan  degree     2
#> 131    9   Eve  degree     1
#> 132    9  Finn  degree     1
#> 133    9  Gita  degree     2
#> 134    9  Hugo  degree     4
#> 135    9  Iris  degree     0
#> 136    9 Jonas  degree     5
#> 137    9  Kira  degree     4
#> 138    9   Leo  degree     1
#> 139    9  Mira  degree     1
#> 140    9  Nils  degree     6
#> 141   10   Ana  degree     3
#> 142   10   Ben  degree     2
#> 143   10  Cara  degree     3
#> 144   10   Dan  degree     1
#> 145   10   Eve  degree     1
#> 146   10  Finn  degree     2
#> 147   10  Gita  degree     4
#> 148   10  Hugo  degree     2
#> 149   10  Iris  degree     3
#> 150   10 Jonas  degree     3
#> 151   10  Kira  degree     2
#> 152   10   Leo  degree     2
#> 153   10  Mira  degree     5
#> 154   10  Nils  degree     5
#> 155   11   Ana  degree     1
#> 156   11   Ben  degree     4
#> 157   11  Cara  degree     4
#> 158   11   Dan  degree     2
#> 159   11   Eve  degree     1
#> 160   11  Finn  degree     3
#> 161   11  Gita  degree     2
#> 162   11  Hugo  degree     1
#> 163   11  Iris  degree     4
#> 164   11 Jonas  degree     2
#> 165   11  Kira  degree     3
#> 166   11   Leo  degree     5
#> 167   11  Mira  degree     4
#> 168   11  Nils  degree     0
#> 169   12   Ana  degree     2
#> 170   12   Ben  degree     3
#> 171   12  Cara  degree     3
#> 172   12   Dan  degree     4
#> 173   12   Eve  degree     2
#> 174   12  Finn  degree     6
#> 175   12  Gita  degree     1
#> 176   12  Hugo  degree     2
#> 177   12  Iris  degree     1
#> 178   12 Jonas  degree     3
#> 179   12  Kira  degree     1
#> 180   12   Leo  degree     3
#> 181   12  Mira  degree     4
#> 182   12  Nils  degree     1
#> 183   13   Ana  degree     5
#> 184   13   Ben  degree     3
#> 185   13  Cara  degree     4
#> 186   13   Dan  degree     5
#> 187   13   Eve  degree     6
#> 188   13  Finn  degree     4
#> 189   13  Gita  degree     4
#> 190   13  Hugo  degree     2
#> 191   13  Iris  degree     2
#> 192   13 Jonas  degree     7
#> 193   13  Kira  degree     3
#> 194   13   Leo  degree     1
#> 195   13  Mira  degree     6
#> 196   13  Nils  degree     6
#> 197   14   Ana  degree     4
#> 198   14   Ben  degree     3
#> 199   14  Cara  degree     2
#> 200   14   Dan  degree     5
#> 201   14   Eve  degree     8
#> 202   14  Finn  degree     3
#> 203   14  Gita  degree     5
#> 204   14  Hugo  degree     6
#> 205   14  Iris  degree     3
#> 206   14 Jonas  degree     7
#> 207   14  Kira  degree     5
#> 208   14   Leo  degree     1
#> 209   14  Mira  degree     1
#> 210   14  Nils  degree     7
#> 211   15   Ana  degree     0
#> 212   15   Ben  degree     1
#> 213   15  Cara  degree     2
#> 214   15   Dan  degree     1
#> 215   15   Eve  degree     5
#> 216   15  Finn  degree     0
#> 217   15  Gita  degree     0
#> 218   15  Hugo  degree     3
#> 219   15  Iris  degree     2
#> 220   15 Jonas  degree     2
#> 221   15  Kira  degree     2
#> 222   15   Leo  degree     1
#> 223   15  Mira  degree     1
#> 224   15  Nils  degree     0
#> 225   16   Ana  degree     0
#> 226   16   Ben  degree     2
#> 227   16  Cara  degree     2
#> 228   16   Dan  degree     1
#> 229   16   Eve  degree     0
#> 230   16  Finn  degree     4
#> 231   16  Gita  degree     1
#> 232   16  Hugo  degree     2
#> 233   16  Iris  degree     1
#> 234   16 Jonas  degree     1
#> 235   16  Kira  degree     3
#> 236   16   Leo  degree     0
#> 237   16  Mira  degree     2
#> 238   16  Nils  degree     1
#> 239   17   Ana  degree     0
#> 240   17   Ben  degree     2
#> 241   17  Cara  degree     1
#> 242   17   Dan  degree     2
#> 243   17   Eve  degree     0
#> 244   17  Finn  degree     3
#> 245   17  Gita  degree     1
#> 246   17  Hugo  degree     1
#> 247   17  Iris  degree     1
#> 248   17 Jonas  degree     0
#> 249   17  Kira  degree     2
#> 250   17   Leo  degree     0
#> 251   17  Mira  degree     2
#> 252   17  Nils  degree     1
#> 253   18   Ana  degree     0
#> 254   18   Ben  degree     2
#> 255   18  Cara  degree     2
#> 256   18   Dan  degree     1
#> 257   18   Eve  degree     1
#> 258   18  Finn  degree     1
#> 259   18  Gita  degree     0
#> 260   18  Hugo  degree     0
#> 261   18  Iris  degree     1
#> 262   18 Jonas  degree     2
#> 263   18  Kira  degree     1
#> 264   18   Leo  degree     1
#> 265   18  Mira  degree     2
#> 266   18  Nils  degree     0
#> 267   19   Ana  degree     3
#> 268   19   Ben  degree     2
#> 269   19  Cara  degree     2
#> 270   19   Dan  degree     1
#> 271   19   Eve  degree     0
#> 272   19  Finn  degree     0
#> 273   19  Gita  degree     1
#> 274   19  Hugo  degree     2
#> 275   19  Iris  degree     1
#> 276   19 Jonas  degree     1
#> 277   19  Kira  degree     2
#> 278   19   Leo  degree     0
#> 279   19  Mira  degree     2
#> 280   19  Nils  degree     1
#> 281   20   Ana  degree     4
#> 282   20   Ben  degree     3
#> 283   20  Cara  degree     3
#> 284   20   Dan  degree     5
#> 285   20   Eve  degree     2
#> 286   20  Finn  degree     1
#> 287   20  Gita  degree     1
#> 288   20  Hugo  degree     3
#> 289   20  Iris  degree     1
#> 290   20 Jonas  degree     2
#> 291   20  Kira  degree     3
#> 292   20   Leo  degree     1
#> 293   20  Mira  degree     2
#> 294   20  Nils  degree     3
#> 295   21   Ana  degree     2
#> 296   21   Ben  degree     0
#> 297   21  Cara  degree     0
#> 298   21   Dan  degree     2
#> 299   21   Eve  degree     1
#> 300   21  Finn  degree     0
#> 301   21  Gita  degree     0
#> 302   21  Hugo  degree     3
#> 303   21  Iris  degree     0
#> 304   21 Jonas  degree     0
#> 305   21  Kira  degree     2
#> 306   21   Leo  degree     1
#> 307   21  Mira  degree     0
#> 308   21  Nils  degree     1
as.data.frame(dyn_centrality(dn, measure = "degree"), layout = "wide")
#>     node measure t0 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11 t12 t13 t14 t15 t16 t17
#> 1    Ana  degree  1  0  1  2  1  1  7  6  3  2   3   1   2   5   4   0   0   0
#> 2    Ben  degree  1  0  0  2  4  3  2  3  0  2   2   4   3   3   3   1   2   2
#> 3   Cara  degree  1  1  1  0  5  4  3  2  3  1   3   4   3   4   2   2   2   1
#> 4    Dan  degree  1  1  1  3  1  2  1  1  3  2   1   2   4   5   5   1   1   2
#> 5    Eve  degree  2  4  2  3  1  3  4  2  1  1   1   1   2   6   8   5   0   0
#> 6   Finn  degree  1  0  1  2  2  4  4  1  1  1   2   3   6   4   3   0   4   3
#> 7   Gita  degree  1  1  2  1  0  1  7  2  1  2   4   2   1   4   5   0   1   1
#> 8   Hugo  degree  1  0  1  1  0  1  6  5  5  4   2   1   2   2   6   3   2   1
#> 9   Iris  degree  2  3  2  1  3  2  2  3  1  0   3   4   1   2   3   2   1   1
#> 10 Jonas  degree  2  2  3  4  1  1  4  5  6  5   3   2   3   7   7   2   1   0
#> 11  Kira  degree  2  2  3  2  3  4  6  1  2  4   2   3   1   3   5   2   3   2
#> 12   Leo  degree  2  0  1  2  3  3  5  1  2  1   2   5   3   1   1   1   0   0
#> 13  Mira  degree  3  2  0  0  1  1  3  3  5  1   5   4   4   6   1   1   2   2
#> 14  Nils  degree  0  0  2  1  1  2  4  3  3  6   5   0   1   6   7   0   1   1
#>    t18 t19 t20 t21
#> 1    0   3   4   2
#> 2    2   2   3   0
#> 3    2   2   3   0
#> 4    1   1   5   2
#> 5    1   0   2   1
#> 6    1   0   1   0
#> 7    0   1   1   0
#> 8    0   2   3   3
#> 9    1   1   1   0
#> 10   2   1   2   0
#> 11   1   2   3   2
#> 12   1   0   1   1
#> 13   2   2   2   0
#> 14   0   1   3   1
as.data.frame(dyn_centrality(dn, measure = "degree"), what = "diagnostics")
#>  [1] session              time                 stage               
#>  [4] status               reason               iterations          
#>  [7] residual             balance_status       balance_reason      
#> [10] balance_iterations   balance_residual     spectral_radius     
#> [13] eigenspace_dimension eigen_residual      
#> <0 rows> (or 0-length row.names)
```
