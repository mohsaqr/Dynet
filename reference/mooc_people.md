# Participants in a MOOC discussion forum

The participant table accompanying
[mooc_posts](https://pak.dynasite.org/Dynet/reference/mooc_posts.md):
every person who appears as a sender or a receiver there, with the
self-reported experience level as the chapter's integer code and as the
label it recodes the code into and uses as the mixing attribute.

## Usage

``` r
mooc_people
```

## Format

A data frame with 445 rows and 3 columns:

- name:

  Character. Participant identifier, matching the `sender` and
  `receiver` columns of
  [mooc_posts](https://pak.dynasite.org/Dynet/reference/mooc_posts.md).

- experience:

  Integer. Self-reported experience level: `1` expert, `2` student, `3`
  teacher.

- expert_level:

  Character. The same level as `Expert`, `Student` or `Teacher`.

## Source

As [mooc_posts](https://pak.dynasite.org/Dynet/reference/mooc_posts.md).

## See also

[mooc_posts](https://pak.dynasite.org/Dynet/reference/mooc_posts.md);
[`vignette("ch17-temporal-networks")`](https://pak.dynasite.org/Dynet/articles/ch17-temporal-networks.md).

## Examples

``` r
participants <- dynet(mooc_posts, from = "sender", to = "receiver",
                      time = "timestamp", thread = "discussion",
                      nodes = mooc_people)
#> Dropped 86 self-loop event(s). Use loops = TRUE to keep them.
as.data.frame(participants, what = "nodes")
#>     name experience expert_level
#> 1      1          1       Expert
#> 2      2          1       Expert
#> 3      3          2      Student
#> 4      4          2      Student
#> 5      5          3      Teacher
#> 6      6          1       Expert
#> 7      7          2      Student
#> 8      8          1       Expert
#> 9      9          1       Expert
#> 10    10          2      Student
#> 11    11          3      Teacher
#> 12    12          3      Teacher
#> 13    13          2      Student
#> 14    14          1       Expert
#> 15    15          3      Teacher
#> 16    16          1       Expert
#> 17    17          1       Expert
#> 18    18          1       Expert
#> 19    19          3      Teacher
#> 20    20          1       Expert
#> 21    21          1       Expert
#> 22    22          1       Expert
#> 23    23          3      Teacher
#> 24    24          2      Student
#> 25    25          2      Student
#> 26    26          3      Teacher
#> 27    27          1       Expert
#> 28    28          3      Teacher
#> 29    29          2      Student
#> 30    30          3      Teacher
#> 31    31          1       Expert
#> 32    32          1       Expert
#> 33    33          3      Teacher
#> 34    34          3      Teacher
#> 35    35          2      Student
#> 36    36          2      Student
#> 37    37          2      Student
#> 38    38          1       Expert
#> 39    39          2      Student
#> 40    40          3      Teacher
#> 41    41          1       Expert
#> 42    42          3      Teacher
#> 43    43          3      Teacher
#> 44    44          2      Student
#> 45    45          2      Student
#> 46    46          2      Student
#> 47    47          3      Teacher
#> 48    48          3      Teacher
#> 49    49          3      Teacher
#> 50    50          3      Teacher
#> 51    51          3      Teacher
#> 52    52          3      Teacher
#> 53    53          3      Teacher
#> 54    54          2      Student
#> 55    55          1       Expert
#> 56    56          3      Teacher
#> 57    57          3      Teacher
#> 58    58          2      Student
#> 59    59          1       Expert
#> 60    60          2      Student
#> 61    61          3      Teacher
#> 62    62          1       Expert
#> 63    63          1       Expert
#> 64    64          2      Student
#> 65    65          2      Student
#> 66    66          2      Student
#> 67    67          3      Teacher
#> 68    68          3      Teacher
#> 69    69          3      Teacher
#> 70    70          1       Expert
#> 71    71          3      Teacher
#> 72    72          2      Student
#> 73    73          3      Teacher
#> 74    74          3      Teacher
#> 75    75          3      Teacher
#> 76    76          3      Teacher
#> 77    77          2      Student
#> 78    78          3      Teacher
#> 79    79          1       Expert
#> 80    80          2      Student
#> 81    81          3      Teacher
#> 82    82          1       Expert
#> 83    83          3      Teacher
#> 84    84          1       Expert
#> 85    85          1       Expert
#> 86    86          3      Teacher
#> 87    87          2      Student
#> 88    88          1       Expert
#> 89    89          3      Teacher
#> 90    90          3      Teacher
#> 91    91          2      Student
#> 92    92          3      Teacher
#> 93    93          1       Expert
#> 94    94          1       Expert
#> 95    95          1       Expert
#> 96    96          2      Student
#> 97    97          1       Expert
#> 98    98          2      Student
#> 99    99          3      Teacher
#> 100  100          2      Student
#> 101  101          1       Expert
#> 102  102          3      Teacher
#> 103  103          2      Student
#> 104  104          3      Teacher
#> 105  105          2      Student
#> 106  106          3      Teacher
#> 107  107          2      Student
#> 108  108          1       Expert
#> 109  109          3      Teacher
#> 110  110          1       Expert
#> 111  111          2      Student
#> 112  112          2      Student
#> 113  113          2      Student
#> 114  114          2      Student
#> 115  115          2      Student
#> 116  116          3      Teacher
#> 117  117          1       Expert
#> 118  118          1       Expert
#> 119  119          2      Student
#> 120  120          3      Teacher
#> 121  121          2      Student
#> 122  122          3      Teacher
#> 123  123          2      Student
#> 124  124          2      Student
#> 125  125          3      Teacher
#> 126  126          2      Student
#> 127  127          2      Student
#> 128  128          1       Expert
#> 129  129          2      Student
#> 130  130          3      Teacher
#> 131  131          2      Student
#> 132  132          1       Expert
#> 133  133          3      Teacher
#> 134  134          1       Expert
#> 135  135          1       Expert
#> 136  136          3      Teacher
#> 137  137          3      Teacher
#> 138  138          2      Student
#> 139  139          2      Student
#> 140  140          3      Teacher
#> 141  141          3      Teacher
#> 142  142          2      Student
#> 143  143          2      Student
#> 144  144          2      Student
#> 145  145          1       Expert
#> 146  146          1       Expert
#> 147  147          2      Student
#> 148  148          2      Student
#> 149  149          1       Expert
#> 150  150          1       Expert
#> 151  151          2      Student
#> 152  152          2      Student
#> 153  153          1       Expert
#> 154  154          3      Teacher
#> 155  155          3      Teacher
#> 156  156          3      Teacher
#> 157  157          1       Expert
#> 158  158          3      Teacher
#> 159  159          2      Student
#> 160  160          3      Teacher
#> 161  161          3      Teacher
#> 162  162          3      Teacher
#> 163  163          1       Expert
#> 164  164          2      Student
#> 165  165          3      Teacher
#> 166  166          1       Expert
#> 167  167          3      Teacher
#> 168  168          3      Teacher
#> 169  169          3      Teacher
#> 170  170          1       Expert
#> 171  171          2      Student
#> 172  172          2      Student
#> 173  173          2      Student
#> 174  174          2      Student
#> 175  175          3      Teacher
#> 176  176          2      Student
#> 177  177          2      Student
#> 178  178          2      Student
#> 179  179          2      Student
#> 180  180          3      Teacher
#> 181  181          1       Expert
#> 182  182          1       Expert
#> 183  183          2      Student
#> 184  184          1       Expert
#> 185  185          2      Student
#> 186  186          1       Expert
#> 187  187          2      Student
#> 188  188          3      Teacher
#> 189  189          3      Teacher
#> 190  190          1       Expert
#> 191  191          3      Teacher
#> 192  192          3      Teacher
#> 193  193          2      Student
#> 194  194          3      Teacher
#> 195  195          3      Teacher
#> 196  196          1       Expert
#> 197  197          3      Teacher
#> 198  198          2      Student
#> 199  199          3      Teacher
#> 200  200          2      Student
#> 201  201          1       Expert
#> 202  202          2      Student
#> 203  203          3      Teacher
#> 204  204          2      Student
#> 205  205          1       Expert
#> 206  206          2      Student
#> 207  207          1       Expert
#> 208  208          2      Student
#> 209  209          3      Teacher
#> 210  210          2      Student
#> 211  211          2      Student
#> 212  212          3      Teacher
#> 213  213          2      Student
#> 214  214          1       Expert
#> 215  215          1       Expert
#> 216  216          3      Teacher
#> 217  217          3      Teacher
#> 218  218          1       Expert
#> 219  219          3      Teacher
#> 220  220          3      Teacher
#> 221  221          1       Expert
#> 222  222          3      Teacher
#> 223  223          2      Student
#> 224  224          3      Teacher
#> 225  225          3      Teacher
#> 226  226          3      Teacher
#> 227  227          2      Student
#> 228  228          1       Expert
#> 229  229          2      Student
#> 230  230          3      Teacher
#> 231  231          3      Teacher
#> 232  232          3      Teacher
#> 233  233          2      Student
#> 234  234          3      Teacher
#> 235  235          2      Student
#> 236  236          1       Expert
#> 237  237          2      Student
#> 238  238          1       Expert
#> 239  239          1       Expert
#> 240  240          1       Expert
#> 241  241          1       Expert
#> 242  242          1       Expert
#> 243  243          1       Expert
#> 244  244          3      Teacher
#> 245  245          1       Expert
#> 246  246          3      Teacher
#> 247  247          2      Student
#> 248  248          1       Expert
#> 249  249          2      Student
#> 250  250          2      Student
#> 251  251          2      Student
#> 252  252          2      Student
#> 253  253          3      Teacher
#> 254  254          3      Teacher
#> 255  255          2      Student
#> 256  256          3      Teacher
#> 257  257          3      Teacher
#> 258  258          3      Teacher
#> 259  259          3      Teacher
#> 260  260          3      Teacher
#> 261  261          2      Student
#> 262  262          3      Teacher
#> 263  263          2      Student
#> 264  264          2      Student
#> 265  265          3      Teacher
#> 266  266          1       Expert
#> 267  267          3      Teacher
#> 268  268          1       Expert
#> 269  269          3      Teacher
#> 270  270          1       Expert
#> 271  271          2      Student
#> 272  272          3      Teacher
#> 273  273          3      Teacher
#> 274  274          3      Teacher
#> 275  275          1       Expert
#> 276  276          3      Teacher
#> 277  277          3      Teacher
#> 278  278          2      Student
#> 279  279          3      Teacher
#> 280  280          3      Teacher
#> 281  281          3      Teacher
#> 282  282          1       Expert
#> 283  283          2      Student
#> 284  284          1       Expert
#> 285  285          1       Expert
#> 286  286          3      Teacher
#> 287  287          1       Expert
#> 288  288          1       Expert
#> 289  289          2      Student
#> 290  290          3      Teacher
#> 291  291          1       Expert
#> 292  292          1       Expert
#> 293  293          3      Teacher
#> 294  294          3      Teacher
#> 295  295          1       Expert
#> 296  296          3      Teacher
#> 297  297          3      Teacher
#> 298  298          3      Teacher
#> 299  299          3      Teacher
#> 300  300          2      Student
#> 301  301          2      Student
#> 302  302          3      Teacher
#> 303  303          3      Teacher
#> 304  304          1       Expert
#> 305  305          3      Teacher
#> 306  306          1       Expert
#> 307  307          2      Student
#> 308  308          1       Expert
#> 309  309          1       Expert
#> 310  310          2      Student
#> 311  311          2      Student
#> 312  312          2      Student
#> 313  313          2      Student
#> 314  314          2      Student
#> 315  315          3      Teacher
#> 316  316          3      Teacher
#> 317  317          3      Teacher
#> 318  318          2      Student
#> 319  319          2      Student
#> 320  320          3      Teacher
#> 321  321          2      Student
#> 322  322          1       Expert
#> 323  323          1       Expert
#> 324  324          3      Teacher
#> 325  325          2      Student
#> 326  326          3      Teacher
#> 327  327          1       Expert
#> 328  328          3      Teacher
#> 329  329          2      Student
#> 330  330          3      Teacher
#> 331  331          2      Student
#> 332  332          1       Expert
#> 333  333          1       Expert
#> 334  334          3      Teacher
#> 335  335          3      Teacher
#> 336  336          2      Student
#> 337  337          3      Teacher
#> 338  338          3      Teacher
#> 339  339          3      Teacher
#> 340  340          3      Teacher
#> 341  341          3      Teacher
#> 342  342          3      Teacher
#> 343  343          1       Expert
#> 344  344          3      Teacher
#> 345  345          3      Teacher
#> 346  346          1       Expert
#> 347  347          2      Student
#> 348  348          3      Teacher
#> 349  349          1       Expert
#> 350  350          2      Student
#> 351  351          2      Student
#> 352  352          1       Expert
#> 353  353          1       Expert
#> 354  354          2      Student
#> 355  355          2      Student
#> 356  356          2      Student
#> 357  357          3      Teacher
#> 358  358          3      Teacher
#> 359  359          3      Teacher
#> 360  360          1       Expert
#> 361  361          3      Teacher
#> 362  362          2      Student
#> 363  363          3      Teacher
#> 364  364          3      Teacher
#> 365  365          2      Student
#> 366  366          2      Student
#> 367  367          1       Expert
#> 368  368          2      Student
#> 369  369          3      Teacher
#> 370  370          3      Teacher
#> 371  371          2      Student
#> 372  372          3      Teacher
#> 373  373          1       Expert
#> 374  374          2      Student
#> 375  375          3      Teacher
#> 376  376          2      Student
#> 377  377          2      Student
#> 378  378          1       Expert
#> 379  379          2      Student
#> 380  380          3      Teacher
#> 381  381          2      Student
#> 382  382          2      Student
#> 383  383          3      Teacher
#> 384  384          2      Student
#> 385  385          3      Teacher
#> 386  386          2      Student
#> 387  387          3      Teacher
#> 388  388          2      Student
#> 389  389          3      Teacher
#> 390  390          1       Expert
#> 391  391          3      Teacher
#> 392  392          3      Teacher
#> 393  393          2      Student
#> 394  394          1       Expert
#> 395  395          2      Student
#> 396  396          2      Student
#> 397  397          1       Expert
#> 398  398          1       Expert
#> 399  399          2      Student
#> 400  400          3      Teacher
#> 401  401          2      Student
#> 402  402          2      Student
#> 403  403          3      Teacher
#> 404  404          1       Expert
#> 405  405          1       Expert
#> 406  406          2      Student
#> 407  407          3      Teacher
#> 408  408          3      Teacher
#> 409  409          1       Expert
#> 410  410          1       Expert
#> 411  411          3      Teacher
#> 412  412          1       Expert
#> 413  413          3      Teacher
#> 414  414          2      Student
#> 415  415          3      Teacher
#> 416  416          2      Student
#> 417  417          2      Student
#> 418  418          2      Student
#> 419  419          3      Teacher
#> 420  420          2      Student
#> 421  421          2      Student
#> 422  422          2      Student
#> 423  423          3      Teacher
#> 424  424          2      Student
#> 425  425          3      Teacher
#> 426  426          1       Expert
#> 427  427          3      Teacher
#> 428  428          3      Teacher
#> 429  429          1       Expert
#> 430  430          2      Student
#> 431  431          2      Student
#> 432  432          1       Expert
#> 433  433          3      Teacher
#> 434  434          1       Expert
#> 435  435          1       Expert
#> 436  436          2      Student
#> 437  437          1       Expert
#> 438  438          1       Expert
#> 439  439          1       Expert
#> 440  440          2      Student
#> 441  444          3      Teacher
#> 442  445          3      Teacher
```
