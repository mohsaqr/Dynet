# Dynet: Tidy Temporal Network Analysis

Construction, measurement and visualisation of temporal networks.
Networks are built from four kinds of relational log with a single
constructor: interval logs with explicit start and end times, contact
logs of instantaneous events, threaded logs such as forum or chat data
where an edge stays active until its thread falls silent, and
co-presence logs where actors sharing a group become connected. Vertices
are addressed by name throughout; integer vertex indices are never
exposed. Every verb returns a tidy one-row-per-observation data frame
carrying vertex names, so results print, plot and subset without
reaching into the object. Metrics cover time-varying centrality,
graph-level structure, edge formation and dissolution, burstiness,
time-respecting paths, reachability and mixing. Implemented in base R;
values are checked for numerical equivalence against the 'statnet'
ecosystem.

## See also

Useful links:

- <https://github.com/mohsaqr/Dynet>

- Report bugs at <https://github.com/mohsaqr/Dynet/issues>

## Author

**Maintainer**: Mohammed Saqr <saqr@saqr.me>
