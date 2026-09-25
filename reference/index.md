# Package index

## Construction

One constructor for four log shapes, and the two verbs that read a
network back out as a time series.

- [`dynet()`](https://pak.dynasite.org/Dynet/reference/dynet.md) : Build
  a temporal network
- [`as_dynet()`](https://pak.dynasite.org/Dynet/reference/as_dynet.md) :
  Convert an object to a Dynet temporal network
- [`as_dynet(`*`<networkDynamic>`*`)`](https://pak.dynasite.org/Dynet/reference/as_dynet.networkDynamic.md)
  : Import a networkDynamic object
- [`events()`](https://pak.dynasite.org/Dynet/reference/events.md) :
  Edge formation and dissolution over time
- [`snapshots()`](https://pak.dynasite.org/Dynet/reference/snapshots.md)
  : The network sliced into snapshots

## Editing

Rewrite the spell and vertex tables without breaking time. Every verb
returns a new network and leaves the input unchanged.

- [`add_nodes()`](https://pak.dynasite.org/Dynet/reference/add_nodes.md)
  : Add nodes to a temporal network
- [`add_ties()`](https://pak.dynasite.org/Dynet/reference/add_ties.md) :
  Add temporal ties
- [`add_arcs()`](https://pak.dynasite.org/Dynet/reference/add_arcs.md) :
  Add directed temporal arcs
- [`add_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/add_vertex_spells.md)
  : Add declared vertex-activity spells
- [`remove_nodes()`](https://pak.dynasite.org/Dynet/reference/remove_nodes.md)
  : Remove nodes from a temporal network
- [`remove_ties()`](https://pak.dynasite.org/Dynet/reference/remove_ties.md)
  : Remove temporal ties
- [`remove_arcs()`](https://pak.dynasite.org/Dynet/reference/remove_arcs.md)
  : Remove directed temporal arcs
- [`remove_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/remove_vertex_spells.md)
  : Remove declared vertex-activity components
- [`update_nodes()`](https://pak.dynasite.org/Dynet/reference/update_nodes.md)
  : Update static node attributes
- [`update_ties()`](https://pak.dynasite.org/Dynet/reference/update_ties.md)
  : Update temporal ties and their attributes
- [`update_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/update_vertex_spells.md)
  : Update declared vertex-activity components
- [`rename_nodes()`](https://pak.dynasite.org/Dynet/reference/rename_nodes.md)
  : Rename nodes everywhere in a temporal network
- [`rename_sessions()`](https://pak.dynasite.org/Dynet/reference/rename_sessions.md)
  : Rename session walls
- [`set_observations()`](https://pak.dynasite.org/Dynet/reference/set_observations.md)
  : Replace observation support
- [`set_tie_sessions()`](https://pak.dynasite.org/Dynet/reference/set_tie_sessions.md)
  : Assign or remove tie sessions
- [`set_vertex_spells()`](https://pak.dynasite.org/Dynet/reference/set_vertex_spells.md)
  : Replace declared vertex activity
- [`clear_observations()`](https://pak.dynasite.org/Dynet/reference/clear_observations.md)
  : Restore implicit observation support

## Measurement

The measuring verbs. All take the same four grid arguments - start, end,
step, window - and return a tidy one-row-per-observation table.

- [`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md)
  : Time-varying vertex centrality
- [`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md)
  : Closeness and betweenness on time-respecting paths
- [`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md)
  : Reachability of every vertex
- [`metrics()`](https://pak.dynasite.org/Dynet/reference/metrics.md) :
  Time-varying graph-level structure
- [`mixing()`](https://pak.dynasite.org/Dynet/reference/mixing.md) :
  Mixing between vertex groups over time
- [`pshifts()`](https://pak.dynasite.org/Dynet/reference/pshifts.md) :
  Gibson participation shifts from raw temporal turns
- [`burstiness()`](https://pak.dynasite.org/Dynet/reference/burstiness.md)
  : Burstiness and memory of each vertex's activity
- [`durations()`](https://pak.dynasite.org/Dynet/reference/durations.md)
  : How long each relationship lasted
- [`similarity()`](https://pak.dynasite.org/Dynet/reference/similarity.md)
  : Similarity between the networks at each pair of time points

## Paths

Time-respecting paths, and the four ways of looking at what they found.

- [`paths()`](https://pak.dynasite.org/Dynet/reference/paths.md) :
  Time-respecting paths from a vertex
- [`pathways()`](https://pak.dynasite.org/Dynet/reference/pathways.md) :
  Most frequent time-respecting routes
- [`path_network()`](https://pak.dynasite.org/Dynet/reference/path_network.md)
  : Build the union network of optimal temporal paths
- [`path_trajectories()`](https://pak.dynasite.org/Dynet/reference/path_trajectories.md)
  : Optimal temporal routes as a counted trajectory tree
- [`plot_path_trajectories()`](https://pak.dynasite.org/Dynet/reference/plot_path_trajectories.md)
  : Draw optimal temporal paths as a trajectory tree

## Structure

Turn a temporal network into another object: a time-expanded projection,
a static weighted network, or a subgraph.

- [`projection()`](https://pak.dynasite.org/Dynet/reference/projection.md)
  : Project a temporal network into directed vertex-time states
- [`collapse_network()`](https://pak.dynasite.org/Dynet/reference/collapse_network.md)
  : Collapse temporal activity to a static weighted network
- [`induce_subgraph()`](https://pak.dynasite.org/Dynet/reference/induce_subgraph.md)
  : Extract an induced temporal subgraph

## Animation

- [`animate()`](https://pak.dynasite.org/Dynet/reference/animate.md) :
  Animate a temporal network over its measurement grid

## Data

Bundled logs used throughout the documentation and examples.

- [`forum_people`](https://pak.dynasite.org/Dynet/reference/forum_people.md)
  : People in the discussion forum
- [`forum_posts`](https://pak.dynasite.org/Dynet/reference/forum_posts.md)
  : Discussion forum posts
- [`mooc_people`](https://pak.dynasite.org/Dynet/reference/mooc_people.md)
  : Participants in a MOOC discussion forum
- [`mooc_posts`](https://pak.dynasite.org/Dynet/reference/mooc_posts.md)
  : Posts in a MOOC discussion forum
- [`school_contacts`](https://pak.dynasite.org/Dynet/reference/school_contacts.md)
  : Student contacts recorded as intervals
- [`seminar_attendance`](https://pak.dynasite.org/Dynet/reference/seminar_attendance.md)
  : Seminar attendance
- [`synthdata`](https://pak.dynasite.org/Dynet/reference/synthdata.md) :
  Synthetic code-transition network (Trees of Thought stand-in)
- [`thought_chains`](https://pak.dynasite.org/Dynet/reference/thought_chains.md)
  : Trees of Thought reply links, anonymised

## Methods

Print, summary, plot and as.data.frame for every result class.

- [`Dynet`](https://pak.dynasite.org/Dynet/reference/Dynet-package.md)
  [`Dynet-package`](https://pak.dynasite.org/Dynet/reference/Dynet-package.md)
  : Dynet: Tidy Temporal Network Analysis

- [`dyn_centrality()`](https://pak.dynasite.org/Dynet/reference/dyn_centrality.md)
  :

  Deprecated name for
  [`centrality_series()`](https://pak.dynasite.org/Dynet/reference/centrality_series.md)
  and
  [`path_centrality()`](https://pak.dynasite.org/Dynet/reference/path_centrality.md)

- [`dyn_reachability()`](https://pak.dynasite.org/Dynet/reference/dyn_reachability.md)
  :

  Deprecated name for
  [`reachability()`](https://pak.dynasite.org/Dynet/reference/reachability.md)

- [`print(`*`<dynet>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet.md)
  : Print a temporal network

- [`print(`*`<dynet_animation>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_animation.md)
  : Print an animation's bin table

- [`print(`*`<dynet_collapsed>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_collapsed.md)
  : Print a collapsed temporal network

- [`print(`*`<dynet_collapsed_list>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_collapsed_list.md)
  : Print session-specific collapsed networks

- [`print(`*`<dynet_metric>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_metric.md)
  : Print a temporal measure

- [`print(`*`<dynet_path_trajectories>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_path_trajectories.md)
  : Print a temporal trajectory tree

- [`print(`*`<dynet_paths>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_paths.md)
  : Print time-respecting paths

- [`print(`*`<dynet_pathways>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_pathways.md)
  : Print ranked pathways

- [`print(`*`<dynet_projection>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_projection.md)
  : Print a time-projected network

- [`print(`*`<dynet_pshifts>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_pshifts.md)
  : Print participation shift counts

- [`print(`*`<dynet_similarity>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_similarity.md)
  : Print time-bin similarity

- [`print(`*`<dynet_snapshot>`*`)`](https://pak.dynasite.org/Dynet/reference/print.dynet_snapshot.md)
  : Print snapshot edges

- [`summary(`*`<dynet>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet.md)
  : Describe a temporal network

- [`summary(`*`<dynet_animation>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_animation.md)
  : Summarise an animation

- [`summary(`*`<dynet_collapsed_list>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_collapsed_list.md)
  : Summarise session-specific collapsed networks

- [`summary(`*`<dynet_metric>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_metric.md)
  : Summarise a temporal measure

- [`summary(`*`<dynet_path_trajectories>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_path_trajectories.md)
  : Summarise path trajectories

- [`summary(`*`<dynet_paths>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_paths.md)
  : Summarise time-respecting paths

- [`summary(`*`<dynet_pathways>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_pathways.md)
  : Summarise ranked pathways

- [`summary(`*`<dynet_projection>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_projection.md)
  : Summarise a time projection

- [`summary(`*`<dynet_pshifts>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_pshifts.md)
  : Summarise participation shifts by family

- [`summary(`*`<dynet_similarity>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_similarity.md)
  : Summarise snapshot similarity

- [`summary(`*`<dynet_snapshot>`*`)`](https://pak.dynasite.org/Dynet/reference/summary.dynet_snapshot.md)
  : Summarise snapshot edges by time bin

- [`plot(`*`<dynet>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet.md)
  : Draw a temporal network

- [`plot(`*`<dynet_collapsed>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_collapsed.md)
  : Draw a collapsed temporal network

- [`plot(`*`<dynet_metric>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_metric.md)
  : Plot a temporal measure

- [`plot(`*`<dynet_path_network>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_path_network.md)
  : Draw a path network

- [`plot(`*`<dynet_path_trajectories>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_path_trajectories.md)
  : Plot path trajectories

- [`plot(`*`<dynet_paths>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_paths.md)
  : Plot time-respecting paths when a valid renderer exists

- [`plot(`*`<dynet_pathways>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_pathways.md)
  : Plot pathways on a time axis

- [`plot(`*`<dynet_pshifts>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_pshifts.md)
  : Plot participation shift counts

- [`plot(`*`<dynet_similarity>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_similarity.md)
  : Draw time-bin similarity as a heatmap

- [`plot(`*`<dynet_snapshot>`*`)`](https://pak.dynasite.org/Dynet/reference/plot.dynet_snapshot.md)
  : Plot how many ties each snapshot holds

- [`plot_path_trajectories()`](https://pak.dynasite.org/Dynet/reference/plot_path_trajectories.md)
  : Draw optimal temporal paths as a trajectory tree

- [`head(`*`<dynet_metric>`*`)`](https://pak.dynasite.org/Dynet/reference/head.dynet_metric.md)
  : First rows of a temporal measure

- [`tail(`*`<dynet_metric>`*`)`](https://pak.dynasite.org/Dynet/reference/tail.dynet_metric.md)
  : Last rows of a temporal measure

- [`as.data.frame(`*`<dynet>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet.md)
  : Tidy tables from a temporal network

- [`as.data.frame(`*`<dynet_animation>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_animation.md)
  : Coerce an animation to a data frame

- [`as.data.frame(`*`<dynet_collapsed>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_collapsed.md)
  : Tidy tables from a collapsed temporal network

- [`as.data.frame(`*`<dynet_collapsed_list>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_collapsed_list.md)
  : Tidy data frame of session-specific collapsed networks

- [`as.data.frame(`*`<dynet_metric>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_metric.md)
  : Tidy data frame of a temporal measure

- [`as.data.frame(`*`<dynet_path_network>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_path_network.md)
  : Tidy tables from a temporal path-union network

- [`as.data.frame(`*`<dynet_path_trajectories>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_path_trajectories.md)
  : Tidy table of a temporal trajectory tree

- [`as.data.frame(`*`<dynet_paths>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_paths.md)
  : Tidy data frame of time-respecting paths

- [`as.data.frame(`*`<dynet_pathways>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_pathways.md)
  : Tidy data frame of ranked pathways

- [`as.data.frame(`*`<dynet_projection>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_projection.md)
  : Tidy tables from a time-projected network

- [`as.data.frame(`*`<dynet_pshifts>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_pshifts.md)
  : Tidy data frame of participation shift counts

- [`as.data.frame(`*`<dynet_similarity>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_similarity.md)
  : Tidy table of time-bin similarity

- [`as.data.frame(`*`<dynet_snapshot>`*`)`](https://pak.dynasite.org/Dynet/reference/as.data.frame.dynet_snapshot.md)
  : Tidy table of snapshot edges
