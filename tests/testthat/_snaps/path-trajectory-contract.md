# a branching forward family is visually stable

    Code
      str(.plot_fingerprint(plot_path_trajectories(.school_paths(), measure = "frequency")))
    Output
      List of 9
       $ edge_vertices: int 840
       $ edge_groups  : int 21
       $ edge_widths  : num [1:5] 0.3 0.667 1.033 1.4 2.5
       $ node_x       : num [1:22] 0 1 1 1 1 1 2 2 2 2 ...
       $ node_y       : num [1:22] 0.358 0 0.167 0.333 0.5 ...
       $ node_sizes   : num [1:22] 14 6.36 6.36 7.33 8.08 ...
       $ node_fills   : chr [1:22] "#0072B2" "#D3E2F1" "#D3E2F1" "#CADBEE" ...
       $ node_labels  : chr [1:22] "Ana (n=19)" "Mira (n=2)" "Jonas (n=2)" "Jonas (n=3)" ...
       $ root_points  : int 0

# a backward family is visually stable

    Code
      str(.plot_fingerprint(plot_path_trajectories(paths, measure = "time",
        orientation = "vertical")))
    Output
      List of 9
       $ edge_vertices: int 200
       $ edge_groups  : int 5
       $ edge_widths  : num [1:5] 0.3 0.85 1.4 1.95 2.5
       $ node_x       : num [1:6] 0.5 0.5 0.5 0.5 0.5 0.5
       $ node_y       : num [1:6] -5 -4 -3 -2 -1 0
       $ node_sizes   : num [1:6] 4 8.47 10.32 11.75 12.94 ...
       $ node_fills   : chr [1:6] "#F0A271" "#F0A271" "#F0A271" "#F0A271" ...
       $ node_labels  : chr [1:6] "Gita (t=14)" "Jonas (t=14)" "Ana (t=14)" "Iris (t=14)" ...
       $ root_points  : int 0

