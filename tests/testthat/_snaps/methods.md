# print output is stable

    Code
      print(dn)
    Output
      # Temporal network (interval format, directed) | a cograph netobject
      # 5 vertices | 4 edge spells | 4 distinct pairs
      # observed from 1 to 5 step, binned every 1
      
       from to start end duration weight
          A  B     1   2        1      1
          B  C     2   3        1      1
          C  D     3   4        1      1
          D  E     4   5        1      1

---

    Code
      print(dyn_centrality(dn, measure = "degree"))
    Output
      # Degree (node-level)
      # 5 vertices | 4 time points, 1 per bin | time in step
       time node measure value
          1    A  degree     1
          1    B  degree     1
          1    C  degree     0
          1    D  degree     0
          1    E  degree     0
          2    A  degree     0
          2    B  degree     1
          2    C  degree     1
          2    D  degree     0
          2    E  degree     0
          3    A  degree     0
          3    B  degree     0
      # 8 more rows. summary() aggregates them; plot() draws them.

---

    Code
      print(dyn_paths(dn, from = "A"))
    Output
      # Time-respecting paths from 'A', from t = 1
      # reaches 4 of 4 other vertices | time in step
       node reachable arrival_time attained latency n_hops n_paths
          A      TRUE            1     TRUE       0      0       1
          B      TRUE            1     TRUE       0      1       1
          C      TRUE            2     TRUE       1      2       1
          D      TRUE            3     TRUE       2      3       1
          E      TRUE            4     TRUE       3      4       1

---

    Code
      print(summary(dn), row.names = FALSE)
    Output
                    property    value
                      format interval
                    directed      yes
                    vertices        5
                 edge spells        4
              distinct pairs        4
                   time unit     step
               observed from        1
                 observed to        5
                        span        4
                   bin width        1
                   time bins        4
       mean snapshot density     0.05
            temporal density     0.05
                    sessions     none
           vertex attributes     none

