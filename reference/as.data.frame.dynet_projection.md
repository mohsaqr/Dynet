# Tidy tables from a time-projected network

Tidy tables from a time-projected network

## Usage

``` r
# S3 method for class 'dynet_projection'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("vertices", "edges"),
  ...
)
```

## Arguments

- x:

  A projection returned by
  [`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md).

- row.names:

  Ignored; present for compatibility with the generic.

- optional:

  Ignored; present for compatibility with the generic.

- what:

  `"vertices"`, the default, returns vertex-time states, and `"edges"`
  returns directed within-slice and identity arcs.

- ...:

  Ignored.

## Value

A plain data frame. Vertex rows contain `state`, optional `session` and
`observation`, `slice`, `time`, `start`, `end`, `closed`, `node`,
`active`, and copied node attributes. Edge rows contain `from_state`,
`to_state`, `from_node`, `to_node`, optional `session`, `from_slice`,
`to_slice`, `from_time`, `to_time`, `edge_type`, `weight`, `n_spells`,
and `lag`.

## Examples

``` r
dn <- dynet(school_contacts)
projected <- projection(dn, step = 4, window = 4)
as.data.frame(projected)
#>    state slice time start end closed  node active
#> 1      1     1    0     0   4  FALSE   Ana   TRUE
#> 2      2     1    0     0   4  FALSE   Ben   TRUE
#> 3      3     1    0     0   4  FALSE  Cara   TRUE
#> 4      4     1    0     0   4  FALSE   Dan   TRUE
#> 5      5     1    0     0   4  FALSE   Eve   TRUE
#> 6      6     1    0     0   4  FALSE  Finn   TRUE
#> 7      7     1    0     0   4  FALSE  Gita   TRUE
#> 8      8     1    0     0   4  FALSE  Hugo   TRUE
#> 9      9     1    0     0   4  FALSE  Iris   TRUE
#> 10    10     1    0     0   4  FALSE Jonas   TRUE
#> 11    11     1    0     0   4  FALSE  Kira   TRUE
#> 12    12     1    0     0   4  FALSE   Leo   TRUE
#> 13    13     1    0     0   4  FALSE  Mira   TRUE
#> 14    14     1    0     0   4  FALSE  Nils   TRUE
#> 15    15     2    4     4   8  FALSE   Ana   TRUE
#> 16    16     2    4     4   8  FALSE   Ben   TRUE
#> 17    17     2    4     4   8  FALSE  Cara   TRUE
#> 18    18     2    4     4   8  FALSE   Dan   TRUE
#> 19    19     2    4     4   8  FALSE   Eve   TRUE
#> 20    20     2    4     4   8  FALSE  Finn   TRUE
#> 21    21     2    4     4   8  FALSE  Gita   TRUE
#> 22    22     2    4     4   8  FALSE  Hugo   TRUE
#> 23    23     2    4     4   8  FALSE  Iris   TRUE
#> 24    24     2    4     4   8  FALSE Jonas   TRUE
#> 25    25     2    4     4   8  FALSE  Kira   TRUE
#> 26    26     2    4     4   8  FALSE   Leo   TRUE
#> 27    27     2    4     4   8  FALSE  Mira   TRUE
#> 28    28     2    4     4   8  FALSE  Nils   TRUE
#> 29    29     3    8     8  12  FALSE   Ana   TRUE
#> 30    30     3    8     8  12  FALSE   Ben   TRUE
#> 31    31     3    8     8  12  FALSE  Cara   TRUE
#> 32    32     3    8     8  12  FALSE   Dan   TRUE
#> 33    33     3    8     8  12  FALSE   Eve   TRUE
#> 34    34     3    8     8  12  FALSE  Finn   TRUE
#> 35    35     3    8     8  12  FALSE  Gita   TRUE
#> 36    36     3    8     8  12  FALSE  Hugo   TRUE
#> 37    37     3    8     8  12  FALSE  Iris   TRUE
#> 38    38     3    8     8  12  FALSE Jonas   TRUE
#> 39    39     3    8     8  12  FALSE  Kira   TRUE
#> 40    40     3    8     8  12  FALSE   Leo   TRUE
#> 41    41     3    8     8  12  FALSE  Mira   TRUE
#> 42    42     3    8     8  12  FALSE  Nils   TRUE
#> 43    43     4   12    12  16  FALSE   Ana   TRUE
#> 44    44     4   12    12  16  FALSE   Ben   TRUE
#> 45    45     4   12    12  16  FALSE  Cara   TRUE
#> 46    46     4   12    12  16  FALSE   Dan   TRUE
#> 47    47     4   12    12  16  FALSE   Eve   TRUE
#> 48    48     4   12    12  16  FALSE  Finn   TRUE
#> 49    49     4   12    12  16  FALSE  Gita   TRUE
#> 50    50     4   12    12  16  FALSE  Hugo   TRUE
#> 51    51     4   12    12  16  FALSE  Iris   TRUE
#> 52    52     4   12    12  16  FALSE Jonas   TRUE
#> 53    53     4   12    12  16  FALSE  Kira   TRUE
#> 54    54     4   12    12  16  FALSE   Leo   TRUE
#> 55    55     4   12    12  16  FALSE  Mira   TRUE
#> 56    56     4   12    12  16  FALSE  Nils   TRUE
#> 57    57     5   16    16  20  FALSE   Ana   TRUE
#> 58    58     5   16    16  20  FALSE   Ben   TRUE
#> 59    59     5   16    16  20  FALSE  Cara   TRUE
#> 60    60     5   16    16  20  FALSE   Dan   TRUE
#> 61    61     5   16    16  20  FALSE   Eve   TRUE
#> 62    62     5   16    16  20  FALSE  Finn   TRUE
#> 63    63     5   16    16  20  FALSE  Gita   TRUE
#> 64    64     5   16    16  20  FALSE  Hugo   TRUE
#> 65    65     5   16    16  20  FALSE  Iris   TRUE
#> 66    66     5   16    16  20  FALSE Jonas   TRUE
#> 67    67     5   16    16  20  FALSE  Kira   TRUE
#> 68    68     5   16    16  20  FALSE   Leo   TRUE
#> 69    69     5   16    16  20  FALSE  Mira   TRUE
#> 70    70     5   16    16  20  FALSE  Nils   TRUE
#> 71    71     6   20    20  24   TRUE   Ana   TRUE
#> 72    72     6   20    20  24   TRUE   Ben   TRUE
#> 73    73     6   20    20  24   TRUE  Cara   TRUE
#> 74    74     6   20    20  24   TRUE   Dan   TRUE
#> 75    75     6   20    20  24   TRUE   Eve   TRUE
#> 76    76     6   20    20  24   TRUE  Finn   TRUE
#> 77    77     6   20    20  24   TRUE  Gita   TRUE
#> 78    78     6   20    20  24   TRUE  Hugo   TRUE
#> 79    79     6   20    20  24   TRUE  Iris   TRUE
#> 80    80     6   20    20  24   TRUE Jonas   TRUE
#> 81    81     6   20    20  24   TRUE  Kira   TRUE
#> 82    82     6   20    20  24   TRUE   Leo   TRUE
#> 83    83     6   20    20  24   TRUE  Mira   TRUE
#> 84    84     6   20    20  24   TRUE  Nils   TRUE
as.data.frame(projected, what = "edges")
#>     from_state to_state from_node to_node from_slice to_slice from_time to_time
#> 1            1       10       Ana   Jonas          1        1         0       0
#> 2            2        5       Ben     Eve          1        1         0       0
#> 3            2       10       Ben   Jonas          1        1         0       0
#> 4            3       14      Cara    Nils          1        1         0       0
#> 5            4        1       Dan     Ana          1        1         0       0
#> 6            4        5       Dan     Eve          1        1         0       0
#> 7            4       10       Dan   Jonas          1        1         0       0
#> 8            4       12       Dan     Leo          1        1         0       0
#> 9            5        8       Eve    Hugo          1        1         0       0
#> 10           5        9       Eve    Iris          1        1         0       0
#> 11           5       11       Eve    Kira          1        1         0       0
#> 12           7        1      Gita     Ana          1        1         0       0
#> 13           7       10      Gita   Jonas          1        1         0       0
#> 14           8       11      Hugo    Kira          1        1         0       0
#> 15           9        3      Iris    Cara          1        1         0       0
#> 16           9        6      Iris    Finn          1        1         0       0
#> 17           9        7      Iris    Gita          1        1         0       0
#> 18          10        4     Jonas     Dan          1        1         0       0
#> 19          10       11     Jonas    Kira          1        1         0       0
#> 20          10       13     Jonas    Mira          1        1         0       0
#> 21          11        2      Kira     Ben          1        1         0       0
#> 22          11        5      Kira     Eve          1        1         0       0
#> 23          11       12      Kira     Leo          1        1         0       0
#> 24          12        6       Leo    Finn          1        1         0       0
#> 25          12        9       Leo    Iris          1        1         0       0
#> 26          12       13       Leo    Mira          1        1         0       0
#> 27          13        5      Mira     Eve          1        1         0       0
#> 28          13        6      Mira    Finn          1        1         0       0
#> 29          14        5      Nils     Eve          1        1         0       0
#> 30           1       15       Ana     Ana          1        2         0       4
#> 31           2       16       Ben     Ben          1        2         0       4
#> 32           3       17      Cara    Cara          1        2         0       4
#> 33           4       18       Dan     Dan          1        2         0       4
#> 34           5       19       Eve     Eve          1        2         0       4
#> 35           6       20      Finn    Finn          1        2         0       4
#> 36           7       21      Gita    Gita          1        2         0       4
#> 37           8       22      Hugo    Hugo          1        2         0       4
#> 38           9       23      Iris    Iris          1        2         0       4
#> 39          10       24     Jonas   Jonas          1        2         0       4
#> 40          11       25      Kira    Kira          1        2         0       4
#> 41          12       26       Leo     Leo          1        2         0       4
#> 42          13       27      Mira    Mira          1        2         0       4
#> 43          14       28      Nils    Nils          1        2         0       4
#> 44          15       17       Ana    Cara          2        2         4       4
#> 45          15       21       Ana    Gita          2        2         4       4
#> 46          15       24       Ana   Jonas          2        2         4       4
#> 47          15       27       Ana    Mira          2        2         4       4
#> 48          16       19       Ben     Eve          2        2         4       4
#> 49          16       20       Ben    Finn          2        2         4       4
#> 50          16       22       Ben    Hugo          2        2         4       4
#> 51          16       23       Ben    Iris          2        2         4       4
#> 52          17       20      Cara    Finn          2        2         4       4
#> 53          17       23      Cara    Iris          2        2         4       4
#> 54          17       25      Cara    Kira          2        2         4       4
#> 55          17       26      Cara     Leo          2        2         4       4
#> 56          17       28      Cara    Nils          2        2         4       4
#> 57          18       20       Dan    Finn          2        2         4       4
#> 58          18       21       Dan    Gita          2        2         4       4
#> 59          18       23       Dan    Iris          2        2         4       4
#> 60          19       25       Eve    Kira          2        2         4       4
#> 61          20       17      Finn    Cara          2        2         4       4
#> 62          20       25      Finn    Kira          2        2         4       4
#> 63          20       28      Finn    Nils          2        2         4       4
#> 64          21       15      Gita     Ana          2        2         4       4
#> 65          21       27      Gita    Mira          2        2         4       4
#> 66          22       15      Hugo     Ana          2        2         4       4
#> 67          22       18      Hugo     Dan          2        2         4       4
#> 68          22       19      Hugo     Eve          2        2         4       4
#> 69          22       21      Hugo    Gita          2        2         4       4
#> 70          22       24      Hugo   Jonas          2        2         4       4
#> 71          22       25      Hugo    Kira          2        2         4       4
#> 72          22       28      Hugo    Nils          2        2         4       4
#> 73          23       16      Iris     Ben          2        2         4       4
#> 74          23       17      Iris    Cara          2        2         4       4
#> 75          23       19      Iris     Eve          2        2         4       4
#> 76          23       26      Iris     Leo          2        2         4       4
#> 77          24       15     Jonas     Ana          2        2         4       4
#> 78          24       21     Jonas    Gita          2        2         4       4
#> 79          24       25     Jonas    Kira          2        2         4       4
#> 80          25       21      Kira    Gita          2        2         4       4
#> 81          25       24      Kira   Jonas          2        2         4       4
#> 82          25       26      Kira     Leo          2        2         4       4
#> 83          26       15       Leo     Ana          2        2         4       4
#> 84          26       17       Leo    Cara          2        2         4       4
#> 85          26       20       Leo    Finn          2        2         4       4
#> 86          26       22       Leo    Hugo          2        2         4       4
#> 87          26       23       Leo    Iris          2        2         4       4
#> 88          27       15      Mira     Ana          2        2         4       4
#> 89          27       21      Mira    Gita          2        2         4       4
#> 90          27       24      Mira   Jonas          2        2         4       4
#> 91          28       16      Nils     Ben          2        2         4       4
#> 92          28       19      Nils     Eve          2        2         4       4
#> 93          28       22      Nils    Hugo          2        2         4       4
#> 94          15       29       Ana     Ana          2        3         4       8
#> 95          16       30       Ben     Ben          2        3         4       8
#> 96          17       31      Cara    Cara          2        3         4       8
#> 97          18       32       Dan     Dan          2        3         4       8
#> 98          19       33       Eve     Eve          2        3         4       8
#> 99          20       34      Finn    Finn          2        3         4       8
#> 100         21       35      Gita    Gita          2        3         4       8
#> 101         22       36      Hugo    Hugo          2        3         4       8
#> 102         23       37      Iris    Iris          2        3         4       8
#> 103         24       38     Jonas   Jonas          2        3         4       8
#> 104         25       39      Kira    Kira          2        3         4       8
#> 105         26       40       Leo     Leo          2        3         4       8
#> 106         27       41      Mira    Mira          2        3         4       8
#> 107         28       42      Nils    Nils          2        3         4       8
#> 108         29       35       Ana    Gita          3        3         8       8
#> 109         29       38       Ana   Jonas          3        3         8       8
#> 110         29       39       Ana    Kira          3        3         8       8
#> 111         29       41       Ana    Mira          3        3         8       8
#> 112         30       33       Ben     Eve          3        3         8       8
#> 113         30       35       Ben    Gita          3        3         8       8
#> 114         30       36       Ben    Hugo          3        3         8       8
#> 115         30       39       Ben    Kira          3        3         8       8
#> 116         30       42       Ben    Nils          3        3         8       8
#> 117         31       36      Cara    Hugo          3        3         8       8
#> 118         31       37      Cara    Iris          3        3         8       8
#> 119         31       42      Cara    Nils          3        3         8       8
#> 120         32       38       Dan   Jonas          3        3         8       8
#> 121         33       36       Eve    Hugo          3        3         8       8
#> 122         33       38       Eve   Jonas          3        3         8       8
#> 123         34       31      Finn    Cara          3        3         8       8
#> 124         34       37      Finn    Iris          3        3         8       8
#> 125         34       38      Finn   Jonas          3        3         8       8
#> 126         34       40      Finn     Leo          3        3         8       8
#> 127         35       41      Gita    Mira          3        3         8       8
#> 128         35       42      Gita    Nils          3        3         8       8
#> 129         36       32      Hugo     Dan          3        3         8       8
#> 130         36       38      Hugo   Jonas          3        3         8       8
#> 131         36       42      Hugo    Nils          3        3         8       8
#> 132         37       31      Iris    Cara          3        3         8       8
#> 133         37       40      Iris     Leo          3        3         8       8
#> 134         37       41      Iris    Mira          3        3         8       8
#> 135         38       29     Jonas     Ana          3        3         8       8
#> 136         38       32     Jonas     Dan          3        3         8       8
#> 137         38       35     Jonas    Gita          3        3         8       8
#> 138         39       30      Kira     Ben          3        3         8       8
#> 139         39       36      Kira    Hugo          3        3         8       8
#> 140         39       38      Kira   Jonas          3        3         8       8
#> 141         39       41      Kira    Mira          3        3         8       8
#> 142         39       42      Kira    Nils          3        3         8       8
#> 143         40       31       Leo    Cara          3        3         8       8
#> 144         40       34       Leo    Finn          3        3         8       8
#> 145         40       37       Leo    Iris          3        3         8       8
#> 146         41       29      Mira     Ana          3        3         8       8
#> 147         41       32      Mira     Dan          3        3         8       8
#> 148         41       35      Mira    Gita          3        3         8       8
#> 149         41       38      Mira   Jonas          3        3         8       8
#> 150         42       29      Nils     Ana          3        3         8       8
#> 151         42       31      Nils    Cara          3        3         8       8
#> 152         42       36      Nils    Hugo          3        3         8       8
#> 153         29       43       Ana     Ana          3        4         8      12
#> 154         30       44       Ben     Ben          3        4         8      12
#> 155         31       45      Cara    Cara          3        4         8      12
#> 156         32       46       Dan     Dan          3        4         8      12
#> 157         33       47       Eve     Eve          3        4         8      12
#> 158         34       48      Finn    Finn          3        4         8      12
#> 159         35       49      Gita    Gita          3        4         8      12
#> 160         36       50      Hugo    Hugo          3        4         8      12
#> 161         37       51      Iris    Iris          3        4         8      12
#> 162         38       52     Jonas   Jonas          3        4         8      12
#> 163         39       53      Kira    Kira          3        4         8      12
#> 164         40       54       Leo     Leo          3        4         8      12
#> 165         41       55      Mira    Mira          3        4         8      12
#> 166         42       56      Nils    Nils          3        4         8      12
#> 167         43       46       Ana     Dan          4        4        12      12
#> 168         43       49       Ana    Gita          4        4        12      12
#> 169         43       51       Ana    Iris          4        4        12      12
#> 170         44       47       Ben     Eve          4        4        12      12
#> 171         44       50       Ben    Hugo          4        4        12      12
#> 172         44       53       Ben    Kira          4        4        12      12
#> 173         44       56       Ben    Nils          4        4        12      12
#> 174         45       46      Cara     Dan          4        4        12      12
#> 175         45       47      Cara     Eve          4        4        12      12
#> 176         45       48      Cara    Finn          4        4        12      12
#> 177         45       51      Cara    Iris          4        4        12      12
#> 178         45       54      Cara     Leo          4        4        12      12
#> 179         46       50       Dan    Hugo          4        4        12      12
#> 180         46       52       Dan   Jonas          4        4        12      12
#> 181         46       55       Dan    Mira          4        4        12      12
#> 182         47       45       Eve    Cara          4        4        12      12
#> 183         47       50       Eve    Hugo          4        4        12      12
#> 184         47       52       Eve   Jonas          4        4        12      12
#> 185         47       56       Eve    Nils          4        4        12      12
#> 186         48       46      Finn     Dan          4        4        12      12
#> 187         48       47      Finn     Eve          4        4        12      12
#> 188         48       51      Finn    Iris          4        4        12      12
#> 189         48       53      Finn    Kira          4        4        12      12
#> 190         48       54      Finn     Leo          4        4        12      12
#> 191         48       55      Finn    Mira          4        4        12      12
#> 192         49       43      Gita     Ana          4        4        12      12
#> 193         49       46      Gita     Dan          4        4        12      12
#> 194         49       52      Gita   Jonas          4        4        12      12
#> 195         49       55      Gita    Mira          4        4        12      12
#> 196         50       47      Hugo     Eve          4        4        12      12
#> 197         50       53      Hugo    Kira          4        4        12      12
#> 198         51       54      Iris     Leo          4        4        12      12
#> 199         51       56      Iris    Nils          4        4        12      12
#> 200         52       43     Jonas     Ana          4        4        12      12
#> 201         52       46     Jonas     Dan          4        4        12      12
#> 202         52       47     Jonas     Eve          4        4        12      12
#> 203         52       49     Jonas    Gita          4        4        12      12
#> 204         52       50     Jonas    Hugo          4        4        12      12
#> 205         53       47      Kira     Eve          4        4        12      12
#> 206         53       50      Kira    Hugo          4        4        12      12
#> 207         54       45       Leo    Cara          4        4        12      12
#> 208         54       48       Leo    Finn          4        4        12      12
#> 209         55       43      Mira     Ana          4        4        12      12
#> 210         55       46      Mira     Dan          4        4        12      12
#> 211         55       49      Mira    Gita          4        4        12      12
#> 212         55       52      Mira   Jonas          4        4        12      12
#> 213         55       53      Mira    Kira          4        4        12      12
#> 214         56       44      Nils     Ben          4        4        12      12
#> 215         56       46      Nils     Dan          4        4        12      12
#> 216         56       47      Nils     Eve          4        4        12      12
#> 217         56       53      Nils    Kira          4        4        12      12
#> 218         43       57       Ana     Ana          4        5        12      16
#> 219         44       58       Ben     Ben          4        5        12      16
#> 220         45       59      Cara    Cara          4        5        12      16
#> 221         46       60       Dan     Dan          4        5        12      16
#> 222         47       61       Eve     Eve          4        5        12      16
#> 223         48       62      Finn    Finn          4        5        12      16
#> 224         49       63      Gita    Gita          4        5        12      16
#> 225         50       64      Hugo    Hugo          4        5        12      16
#> 226         51       65      Iris    Iris          4        5        12      16
#> 227         52       66     Jonas   Jonas          4        5        12      16
#> 228         53       67      Kira    Kira          4        5        12      16
#> 229         54       68       Leo     Leo          4        5        12      16
#> 230         55       69      Mira    Mira          4        5        12      16
#> 231         56       70      Nils    Nils          4        5        12      16
#> 232         57       60       Ana     Dan          5        5        16      16
#> 233         58       64       Ben    Hugo          5        5        16      16
#> 234         59       57      Cara     Ana          5        5        16      16
#> 235         59       58      Cara     Ben          5        5        16      16
#> 236         59       62      Cara    Finn          5        5        16      16
#> 237         59       68      Cara     Leo          5        5        16      16
#> 238         60       63       Dan    Gita          5        5        16      16
#> 239         60       66       Dan   Jonas          5        5        16      16
#> 240         62       67      Finn    Kira          5        5        16      16
#> 241         62       69      Finn    Mira          5        5        16      16
#> 242         63       66      Gita   Jonas          5        5        16      16
#> 243         63       69      Gita    Mira          5        5        16      16
#> 244         64       57      Hugo     Ana          5        5        16      16
#> 245         64       67      Hugo    Kira          5        5        16      16
#> 246         65       58      Iris     Ben          5        5        16      16
#> 247         65       61      Iris     Eve          5        5        16      16
#> 248         65       62      Iris    Finn          5        5        16      16
#> 249         66       59     Jonas    Cara          5        5        16      16
#> 250         67       58      Kira     Ben          5        5        16      16
#> 251         67       64      Kira    Hugo          5        5        16      16
#> 252         67       70      Kira    Nils          5        5        16      16
#> 253         69       58      Mira     Ben          5        5        16      16
#> 254         69       60      Mira     Dan          5        5        16      16
#> 255         70       67      Nils    Kira          5        5        16      16
#> 256         57       71       Ana     Ana          5        6        16      20
#> 257         58       72       Ben     Ben          5        6        16      20
#> 258         59       73      Cara    Cara          5        6        16      20
#> 259         60       74       Dan     Dan          5        6        16      20
#> 260         61       75       Eve     Eve          5        6        16      20
#> 261         62       76      Finn    Finn          5        6        16      20
#> 262         63       77      Gita    Gita          5        6        16      20
#> 263         64       78      Hugo    Hugo          5        6        16      20
#> 264         65       79      Iris    Iris          5        6        16      20
#> 265         66       80     Jonas   Jonas          5        6        16      20
#> 266         67       81      Kira    Kira          5        6        16      20
#> 267         68       82       Leo     Leo          5        6        16      20
#> 268         69       83      Mira    Mira          5        6        16      20
#> 269         70       84      Nils    Nils          5        6        16      20
#> 270         71       74       Ana     Dan          6        6        20      20
#> 271         71       82       Ana     Leo          6        6        20      20
#> 272         73       71      Cara     Ana          6        6        20      20
#> 273         74       71       Dan     Ana          6        6        20      20
#> 274         74       83       Dan    Mira          6        6        20      20
#> 275         74       84       Dan    Nils          6        6        20      20
#> 276         75       72       Eve     Ben          6        6        20      20
#> 277         75       78       Eve    Hugo          6        6        20      20
#> 278         76       73      Finn    Cara          6        6        20      20
#> 279         77       83      Gita    Mira          6        6        20      20
#> 280         78       81      Hugo    Kira          6        6        20      20
#> 281         79       72      Iris     Ben          6        6        20      20
#> 282         80       72     Jonas     Ben          6        6        20      20
#> 283         80       74     Jonas     Dan          6        6        20      20
#> 284         81       78      Kira    Hugo          6        6        20      20
#> 285         84       73      Nils    Cara          6        6        20      20
#> 286         84       81      Nils    Kira          6        6        20      20
#>        edge_type weight n_spells lag
#> 1   within_slice      2        2   0
#> 2   within_slice      1        1   0
#> 3   within_slice      1        1   0
#> 4   within_slice      1        1   0
#> 5   within_slice      1        1   0
#> 6   within_slice      1        1   0
#> 7   within_slice      1        1   0
#> 8   within_slice      1        1   0
#> 9   within_slice      1        1   0
#> 10  within_slice      1        1   0
#> 11  within_slice      1        1   0
#> 12  within_slice      1        1   0
#> 13  within_slice      1        1   0
#> 14  within_slice      1        1   0
#> 15  within_slice      1        1   0
#> 16  within_slice      1        1   0
#> 17  within_slice      1        1   0
#> 18  within_slice      1        1   0
#> 19  within_slice      1        1   0
#> 20  within_slice      1        1   0
#> 21  within_slice      1        1   0
#> 22  within_slice      1        1   0
#> 23  within_slice      1        1   0
#> 24  within_slice      1        1   0
#> 25  within_slice      2        2   0
#> 26  within_slice      1        1   0
#> 27  within_slice      1        1   0
#> 28  within_slice      1        1   0
#> 29  within_slice      1        1   0
#> 30  identity_arc      1        0   4
#> 31  identity_arc      1        0   4
#> 32  identity_arc      1        0   4
#> 33  identity_arc      1        0   4
#> 34  identity_arc      1        0   4
#> 35  identity_arc      1        0   4
#> 36  identity_arc      1        0   4
#> 37  identity_arc      1        0   4
#> 38  identity_arc      1        0   4
#> 39  identity_arc      1        0   4
#> 40  identity_arc      1        0   4
#> 41  identity_arc      1        0   4
#> 42  identity_arc      1        0   4
#> 43  identity_arc      1        0   4
#> 44  within_slice      1        1   0
#> 45  within_slice      2        2   0
#> 46  within_slice      1        1   0
#> 47  within_slice      2        2   0
#> 48  within_slice      2        2   0
#> 49  within_slice      1        1   0
#> 50  within_slice      1        1   0
#> 51  within_slice      1        1   0
#> 52  within_slice      1        1   0
#> 53  within_slice      1        1   0
#> 54  within_slice      2        2   0
#> 55  within_slice      1        1   0
#> 56  within_slice      1        1   0
#> 57  within_slice      1        1   0
#> 58  within_slice      1        1   0
#> 59  within_slice      1        1   0
#> 60  within_slice      1        1   0
#> 61  within_slice      1        1   0
#> 62  within_slice      1        1   0
#> 63  within_slice      1        1   0
#> 64  within_slice      1        1   0
#> 65  within_slice      1        1   0
#> 66  within_slice      1        1   0
#> 67  within_slice      1        1   0
#> 68  within_slice      1        1   0
#> 69  within_slice      1        1   0
#> 70  within_slice      2        2   0
#> 71  within_slice      1        1   0
#> 72  within_slice      1        1   0
#> 73  within_slice      1        1   0
#> 74  within_slice      1        1   0
#> 75  within_slice      1        1   0
#> 76  within_slice      1        1   0
#> 77  within_slice      1        1   0
#> 78  within_slice      1        1   0
#> 79  within_slice      1        1   0
#> 80  within_slice      1        1   0
#> 81  within_slice      1        1   0
#> 82  within_slice      2        2   0
#> 83  within_slice      1        1   0
#> 84  within_slice      1        1   0
#> 85  within_slice      1        1   0
#> 86  within_slice      1        1   0
#> 87  within_slice      1        1   0
#> 88  within_slice      2        2   0
#> 89  within_slice      1        1   0
#> 90  within_slice      1        1   0
#> 91  within_slice      5        5   0
#> 92  within_slice      1        1   0
#> 93  within_slice      1        1   0
#> 94  identity_arc      1        0   4
#> 95  identity_arc      1        0   4
#> 96  identity_arc      1        0   4
#> 97  identity_arc      1        0   4
#> 98  identity_arc      1        0   4
#> 99  identity_arc      1        0   4
#> 100 identity_arc      1        0   4
#> 101 identity_arc      1        0   4
#> 102 identity_arc      1        0   4
#> 103 identity_arc      1        0   4
#> 104 identity_arc      1        0   4
#> 105 identity_arc      1        0   4
#> 106 identity_arc      1        0   4
#> 107 identity_arc      1        0   4
#> 108 within_slice      1        1   0
#> 109 within_slice      1        1   0
#> 110 within_slice      1        1   0
#> 111 within_slice      2        2   0
#> 112 within_slice      1        1   0
#> 113 within_slice      1        1   0
#> 114 within_slice      1        1   0
#> 115 within_slice      1        1   0
#> 116 within_slice      1        1   0
#> 117 within_slice      1        1   0
#> 118 within_slice      1        1   0
#> 119 within_slice      1        1   0
#> 120 within_slice      1        1   0
#> 121 within_slice      1        1   0
#> 122 within_slice      1        1   0
#> 123 within_slice      1        1   0
#> 124 within_slice      1        1   0
#> 125 within_slice      1        1   0
#> 126 within_slice      2        2   0
#> 127 within_slice      1        1   0
#> 128 within_slice      1        1   0
#> 129 within_slice      1        1   0
#> 130 within_slice      1        1   0
#> 131 within_slice      1        1   0
#> 132 within_slice      1        1   0
#> 133 within_slice      1        1   0
#> 134 within_slice      1        1   0
#> 135 within_slice      1        1   0
#> 136 within_slice      3        3   0
#> 137 within_slice      1        1   0
#> 138 within_slice      1        1   0
#> 139 within_slice      1        1   0
#> 140 within_slice      2        2   0
#> 141 within_slice      1        1   0
#> 142 within_slice      1        1   0
#> 143 within_slice      3        3   0
#> 144 within_slice      1        1   0
#> 145 within_slice      2        2   0
#> 146 within_slice      1        1   0
#> 147 within_slice      3        3   0
#> 148 within_slice      3        3   0
#> 149 within_slice      2        2   0
#> 150 within_slice      1        1   0
#> 151 within_slice      1        1   0
#> 152 within_slice      2        2   0
#> 153 identity_arc      1        0   4
#> 154 identity_arc      1        0   4
#> 155 identity_arc      1        0   4
#> 156 identity_arc      1        0   4
#> 157 identity_arc      1        0   4
#> 158 identity_arc      1        0   4
#> 159 identity_arc      1        0   4
#> 160 identity_arc      1        0   4
#> 161 identity_arc      1        0   4
#> 162 identity_arc      1        0   4
#> 163 identity_arc      1        0   4
#> 164 identity_arc      1        0   4
#> 165 identity_arc      1        0   4
#> 166 identity_arc      1        0   4
#> 167 within_slice      2        2   0
#> 168 within_slice      2        2   0
#> 169 within_slice      1        1   0
#> 170 within_slice      2        2   0
#> 171 within_slice      2        2   0
#> 172 within_slice      1        1   0
#> 173 within_slice      2        2   0
#> 174 within_slice      1        1   0
#> 175 within_slice      1        1   0
#> 176 within_slice      1        1   0
#> 177 within_slice      2        2   0
#> 178 within_slice      1        1   0
#> 179 within_slice      1        1   0
#> 180 within_slice      3        3   0
#> 181 within_slice      1        1   0
#> 182 within_slice      1        1   0
#> 183 within_slice      2        2   0
#> 184 within_slice      1        1   0
#> 185 within_slice      1        1   0
#> 186 within_slice      1        1   0
#> 187 within_slice      1        1   0
#> 188 within_slice      1        1   0
#> 189 within_slice      1        1   0
#> 190 within_slice      1        1   0
#> 191 within_slice      3        3   0
#> 192 within_slice      1        1   0
#> 193 within_slice      1        1   0
#> 194 within_slice      2        2   0
#> 195 within_slice      1        1   0
#> 196 within_slice      2        2   0
#> 197 within_slice      1        1   0
#> 198 within_slice      1        1   0
#> 199 within_slice      1        1   0
#> 200 within_slice      2        2   0
#> 201 within_slice      1        1   0
#> 202 within_slice      1        1   0
#> 203 within_slice      1        1   0
#> 204 within_slice      1        1   0
#> 205 within_slice      2        2   0
#> 206 within_slice      1        1   0
#> 207 within_slice      1        1   0
#> 208 within_slice      1        1   0
#> 209 within_slice      1        1   0
#> 210 within_slice      1        1   0
#> 211 within_slice      1        1   0
#> 212 within_slice      3        3   0
#> 213 within_slice      1        1   0
#> 214 within_slice      3        3   0
#> 215 within_slice      1        1   0
#> 216 within_slice      1        1   0
#> 217 within_slice      1        1   0
#> 218 identity_arc      1        0   4
#> 219 identity_arc      1        0   4
#> 220 identity_arc      1        0   4
#> 221 identity_arc      1        0   4
#> 222 identity_arc      1        0   4
#> 223 identity_arc      1        0   4
#> 224 identity_arc      1        0   4
#> 225 identity_arc      1        0   4
#> 226 identity_arc      1        0   4
#> 227 identity_arc      1        0   4
#> 228 identity_arc      1        0   4
#> 229 identity_arc      1        0   4
#> 230 identity_arc      1        0   4
#> 231 identity_arc      1        0   4
#> 232 within_slice      1        1   0
#> 233 within_slice      1        1   0
#> 234 within_slice      1        1   0
#> 235 within_slice      1        1   0
#> 236 within_slice      1        1   0
#> 237 within_slice      1        1   0
#> 238 within_slice      1        1   0
#> 239 within_slice      1        1   0
#> 240 within_slice      1        1   0
#> 241 within_slice      1        1   0
#> 242 within_slice      1        1   0
#> 243 within_slice      1        1   0
#> 244 within_slice      1        1   0
#> 245 within_slice      1        1   0
#> 246 within_slice      1        1   0
#> 247 within_slice      1        1   0
#> 248 within_slice      1        1   0
#> 249 within_slice      1        1   0
#> 250 within_slice      1        1   0
#> 251 within_slice      1        1   0
#> 252 within_slice      2        2   0
#> 253 within_slice      1        1   0
#> 254 within_slice      1        1   0
#> 255 within_slice      1        1   0
#> 256 identity_arc      1        0   4
#> 257 identity_arc      1        0   4
#> 258 identity_arc      1        0   4
#> 259 identity_arc      1        0   4
#> 260 identity_arc      1        0   4
#> 261 identity_arc      1        0   4
#> 262 identity_arc      1        0   4
#> 263 identity_arc      1        0   4
#> 264 identity_arc      1        0   4
#> 265 identity_arc      1        0   4
#> 266 identity_arc      1        0   4
#> 267 identity_arc      1        0   4
#> 268 identity_arc      1        0   4
#> 269 identity_arc      1        0   4
#> 270 within_slice      1        1   0
#> 271 within_slice      1        1   0
#> 272 within_slice      1        1   0
#> 273 within_slice      1        1   0
#> 274 within_slice      1        1   0
#> 275 within_slice      1        1   0
#> 276 within_slice      1        1   0
#> 277 within_slice      1        1   0
#> 278 within_slice      1        1   0
#> 279 within_slice      1        1   0
#> 280 within_slice      1        1   0
#> 281 within_slice      1        1   0
#> 282 within_slice      1        1   0
#> 283 within_slice      1        1   0
#> 284 within_slice      1        1   0
#> 285 within_slice      1        1   0
#> 286 within_slice      1        1   0
```
