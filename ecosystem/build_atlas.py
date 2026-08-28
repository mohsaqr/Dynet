#!/usr/bin/env python3
"""Merge every enumerated package surface into one categorised JSON dataset."""
import csv, json, re, os

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

# ---------------------------------------------------------------- packages ---
# paradigm: describe | infer | diffuse | layer | community | substrate
PKG = {
 # ---- R, description layer -------------------------------------------------
 "Dynet":            ("R","describe","Tidy temporal networks: one object for four log formats, 63 measures, 9 plot types","live"),
 "networkDynamic":   ("R","describe","Spell-based temporal representation for statnet. Storage only, no metrics","live"),
 "tsna":             ("R","describe","Temporal metrics and time-respecting paths over networkDynamic","live"),
 "ndtv":             ("R","describe","Temporal network animation and static temporal plots","live"),
 "timeordered":      ("R","describe","Time-ordered graphs and twelve temporal randomisation null models","live"),
 "tnet":             ("R","describe","Weighted and two-mode networks; thin longitudinal support","live"),
 # ---- R, inference ---------------------------------------------------------
 "RSiena":           ("R","infer","Stochastic actor-oriented models; network and behaviour coevolution","live"),
 "tergm":            ("R","infer","Separable temporal ERGM estimation and simulation","live"),
 "btergm":           ("R","infer","Bootstrapped, MPLE and Bayesian TERGM with ROC/PR goodness of fit","live"),
 "relevent":         ("R","infer","Relational event models for time-stamped interaction streams","live"),
 "goldfish":         ("R","infer","Dynamic network actor models (DyNAM) and relational events","live"),
 "PAFit":            ("R","infer","Preferential attachment and node fitness estimation from growth","live"),
 "NetworkChange":    ("R","infer","Bayesian multiple changepoint detection in longitudinal network arrays","live"),
 "dyads":            ("R","infer","p2 and b2 dyadic multilevel models","live"),
 # ---- R, diffusion ---------------------------------------------------------
 "netdiffuseR":      ("R","diffuse","Diffusion of innovations over dynamic networks","live"),
 "EpiModel":         ("R","diffuse","Stochastic network epidemic models on tergm-simulated networks","live"),
 "manynet":          ("R","diffuse","Tidy multi-format network handling with wave-based longitudinal verbs","live"),
 "migraph":          ("R","diffuse","Statistical wrapper over manynet","live"),
 # ---- R, layers ------------------------------------------------------------
 "multinet":         ("R","layer","Multilayer networks; the only multilayer community detection in R","live"),
 "cograph":          ("R","layer","Network analysis and visualisation; supplies Dynet's supra-adjacency layer","live"),
 # ---- R, static substrate --------------------------------------------------
 "sna":              ("R","substrate","Static social network analysis; Dynet is verified against it","live"),
 "network":          ("R","substrate","The statnet network object","live"),
 "igraph":           ("R","substrate","General-purpose static graph library","live"),
 # ---- Python ---------------------------------------------------------------
 "teneto":           ("Py","describe","The reference temporal-metrics library; built around fMRI data","live"),
 "raphtory":         ("Py","describe","Rust temporal graph engine; time travel as a first-class operation","live"),
 "networkx_temporal":("Py","describe","Conversion hub plus multislice community detection","live"),
 "dynetx":           ("Py","describe","Thin NetworkX extension for slicing and I/O","live"),
 "dynetworkx":       ("Py","describe","Interval, impulse and snapshot graphs; one algorithm","live"),
 "tnetwork":         ("Py","community","Dynamic community detection specialist","live"),
 "phasik":           ("Py","community","Temporal phase identification by clustering","live"),
 "pathpy":           ("Py","describe","Higher-order and multi-order models of path memory","live"),
 "tgx":              ("Py","describe","Dataset diagnostics for temporal graph machine learning","live"),
 "TGLib":            ("Py","describe","C++ temporal graph library; deepest temporal distance suite","doc"),
 "Reticula":         ("Py","describe","C++ temporal networks, hypergraphs and event graphs","doc"),
}

CATS = ["repr","io","paths","centrality-t","centrality-s","events","global",
        "community","motif","null","model","diffusion","viz","edit","util","data"]

CAT_LABEL = {
 "repr":"Representation","io":"Import / export / convert","paths":"Temporal paths & reachability",
 "centrality-t":"Temporal centrality","centrality-s":"Static centrality","events":"Event dynamics",
 "global":"Global properties","community":"Communities & phases","motif":"Motifs & censuses",
 "null":"Null models & resampling","model":"Model estimation","diffusion":"Diffusion & contagion",
 "viz":"Visualisation","edit":"Editing","util":"Utility / accessor","data":"Data & generators",
}

# ------------------------------------------------------- curated overrides ---
# exact function name -> category, applied per package. These are the packages
# where the categorisation carries the argument, so they are assigned by hand.
CURATED = {
"tsna": {
 "tPath":"paths","tReach":"paths","forward.reachable":"paths","is.tPath":"util",
 "as.network.tPath":"io","plot.tPath":"viz","plotPaths":"viz",
 "timeProjectedNetwork":"paths","tDegree":"centrality-t",
 "tEdgeFormation":"events","tEdgeDissolution":"events","edgeDuration":"events",
 "vertexDuration":"events","tiedDuration":"events","pShiftCount":"motif",
 "tEdgeDensity":"global","tSnaStats":"centrality-s","tErgmStats":"model",
},
"timeordered": {
 "shortesttimepath":"paths","shortesthoppath":"paths",
 "generatetonetwork":"repr","generatetonetworkfromvel":"repr","generatenetworkslices":"repr",
 "generatetimeaggregatednetwork":"repr","generatevertexedgelist":"repr","generatetonetwork":"repr",
 "generatelatencies":"events","generatetimedeltas":"events","generatetimelags":"events",
 "applynetworkfunction":"util","maxpoints":"util","midpoints":"util",
 "plotnetworkslices":"viz","plottanet":"viz","plottonet":"viz",
 "spreadanalysis":"diffusion","transformspreadbyindividual":"diffusion",
 "contact_randomization":"null","edge_randomization":"null","time_reversal":"null",
 "randomizetimes":"null","randomizeidentities":"null","randomized_contacts":"null",
 "randomized_edges":"null","randomly_permuted_times":"null","total_randomization":"null",
 "vertex_randomization":"null","swap":"null","random_times":"null",
 "randomize_edges_helper":"null","rarefy":"null",
},
"teneto": {
 "temporal_degree_centrality":"centrality-t","temporal_closeness_centrality":"centrality-t",
 "temporal_betweenness_centrality":"centrality-t","temporal_participation_coeff":"centrality-t",
 "shortest_temporal_path":"paths","reachability_latency":"paths","temporal_efficiency":"paths","sid":"paths",
 "bursty_coeff":"events","intercontacttimes":"events","local_variation":"events",
 "fluctuability":"global","volatility":"global","topological_overlap":"global",
 "temporal_louvain":"community","tctc":"community","make_temporal_consensus":"community",
 "make_consensus_matrix":"community","create_supraadjacency_matrix":"community",
 "clean_community_indexes":"community","jaccard":"community","tnet_to_nx":"io",
 "allegiance":"community","flexibility":"community","integration":"community",
 "persistence":"community","promiscuity":"community","recruitment":"community",
 "rand_binomial":"data","rand_poisson":"data",
 "circle_plot":"viz","slice_plot":"viz","graphlet_stack_plot":"viz",
 "TemporalNetwork":"repr","TenetoBIDS":"repr","TenetoWorkflow":"repr",
},
"raphtory": {
 "temporally_reachable_nodes":"paths","dijkstra_single_source_shortest_paths":"paths",
 "single_source_shortest_path":"paths","in_component":"paths","out_component":"paths",
 "in_components":"paths","out_components":"paths",
 "global_temporal_three_node_motif":"motif","global_temporal_three_node_motif_multi":"motif",
 "local_temporal_three_node_motifs":"motif","local_triangle_count":"motif","triplet_count":"motif",
 "betweenness_centrality":"centrality-s","degree_centrality":"centrality-s","pagerank":"centrality-s",
 "hits":"centrality-s","fast_rp":"centrality-s","balance":"centrality-s",
 "louvain":"community","label_propagation":"community",
 "temporal_SEIR":"diffusion","Infected":"diffusion",
 "PersistentGraph":"repr","Graph":"repr","GraphView":"repr","WindowSet":"repr","Intervals":"repr",
 "global_clustering_coefficient":"global","local_clustering_coefficient":"global",
 "local_clustering_coefficient_batch":"global","directed_graph_density":"global",
 "average_degree":"global","max_degree":"global","min_degree":"global",
 "global_reciprocity":"global","all_local_reciprocity":"global",
 "weakly_connected_components":"global","strongly_connected_components":"global","k_core":"global",
},
"networkx_temporal": {
 "leiden_communities":"community","leiden_multislice_gpu":"community",
 "modularity_multislice":"community","modularity_spectral":"community","modularity":"community",
 "spectral_clustering":"community","spectral_clustering_bethe_hessian":"community",
 "spectral_clustering_laplacian":"community","spectral_clustering_modularity":"community",
 "transition_node_memberships":"community","conductance":"community",
 "partition_nodes":"community","partition_edges":"community",
 "temporal_node_similarity":"global","temporal_edge_similarity":"global",
 "to_unrolled":"paths","from_unrolled":"paths","to_supra_adjacency_matrix":"paths",
 "unrolled_layout":"viz",
 "degree_centrality":"centrality-s","in_degree_centrality":"centrality-s",
 "out_degree_centrality":"centrality-s","bridging_centrality":"centrality-s",
 "brokering_centrality":"centrality-s","centralization":"centrality-s",
 "degree_centralization":"centrality-s","in_degree_centralization":"centrality-s",
 "out_degree_centralization":"centrality-s",
},
"tnetwork": {
 "iterative_match":"community","smoothed_louvain":"community","smoothed_graph":"community",
 "rollingCPM":"community","MSSCD":"community","label_smoothing":"community",
 "longitudinal_similarity":"community","consecutive_sn_similarity":"community",
 "onmi":"community","entropy_by_node":"community","nb_node_change":"community",
 "quality_at_each_step":"community","similarity_at_each_step":"community",
 "dynamic_partition":"community","DynCommunitiesSN":"community","DynCommunitiesIG":"community",
 "ComScenario":"data","DCD_benchmark":"data","generate_multi_temporal_scale":"data",
 "generate_simple_random_graph":"data","generate_toy_random_network":"data",
 "plot_longitudinal":"viz","plot_as_graph":"viz",
 "DynGraphSN":"repr","DynGraphIG":"repr","DynGraphLS":"repr","Intervals":"repr",
},
"phasik": {
 "TemporalNetwork":"repr","PartiallyTemporalNetwork":"repr","TemporalData":"repr",
 "DistanceMatrix":"community","ClusterSet":"community","ClusterSets":"community",
 "cluster_sort":"community","aggregate_network_by_cluster":"community",
 "rand_index_over_methods_and_sizes":"community",
 "animate_temporal_network":"viz","plot_phases":"viz","plot_dendrogram":"viz",
 "plot_cluster_set":"viz","plot_cluster_sets":"viz","plot_average_silhouettes":"viz",
 "plot_edge_series":"viz","plot_events":"viz","plot_ns_clusters":"viz",
 "plot_randindex_bars_over_methods_and_sizes":"viz","threshold_plot":"viz","draw_graph":"viz",
},
"tgx": {
 "get_novelty":"events","get_reoccurrence":"events","get_surprise":"events",
 "get_avg_node_activity":"events","get_avg_node_engagement":"events",
 "degree_over_time":"global","nodes_over_time":"global","edges_over_time":"global",
 "nodes_and_edges_over_time":"global","connected_components_per_ts":"global",
 "size_connected_components":"global","degree_density":"global","get_avg_degree":"global",
 "get_avg_e_per_ts":"global","get_num_timestamps":"global","get_num_unique_edges":"global",
 "TEA":"viz","TET":"viz","plot_density_map":"viz","plot_for_snapshots":"viz",
 "plot_nodes_edges_per_ts":"viz",
 "discretize_edges":"repr","train_test_split":"util","subsampling":"util",
 "Graph":"repr","read_csv":"io","write_csv":"io","tgb_data":"data","node_list":"util",
},
"pathpy": {
 "HigherOrderNetwork":"model","MultiOrderModel":"model","NullModel":"null",
 "TemporalNetwork":"repr","Network":"repr","Path":"repr","PathCollection":"repr",
 "DirectedAcyclicGraph":"repr","HyperEdge":"repr","Node":"repr","Edge":"repr",
 "betweenness_centrality":"centrality-s","closeness_centrality":"centrality-s",
 "degree_centrality":"centrality-s","eigenvector_centrality":"centrality-s",
 "rank_centralities":"centrality-s",
 "shortest_paths":"paths","all_shortest_paths":"paths","all_longest_paths":"paths",
 "single_source_shortest_paths":"paths","distance_matrix":"paths","avg_path_length":"paths",
 "diameter":"paths","shortest_path_tree":"paths","subpaths":"paths",
 "community_detection":"community","modularity":"community","Q_modularity":"community",
 "Q_max_modularity":"community","Q_assortativity_coefficient":"community",
 "RandomWalk":"diffusion","random_walk":"diffusion",
},
"dynetworkx": {
 "IntervalGraph":"repr","IntervalDiGraph":"repr","ImpulseGraph":"repr","ImpulseDiGraph":"repr",
 "SnapshotGraph":"repr","SnapshotDiGraph":"repr","count_temporal_motif":"motif",
},
"dynetx": {
 "DynGraph":"repr","DynDiGraph":"repr","time_slice":"repr","temporal_snapshots_ids":"repr",
 "inter_event_time_distribution":"events","interactions_per_snapshots":"global",
 "number_of_interactions":"global","density":"global","degree":"centrality-s",
 "degree_histogram":"global","stream_interactions":"repr","coverage":"global",
},
}

# ---------------------------------------------------------------- heuristics -
RULES = [
 (r"^(plot|draw|render|animate|filmstrip|timeline|timePrism|proximity\.timeline|compute\.animation|layout|theme|scale_|palette|gplot|effect|multiplot|values2graphics|drawColorKey|comp_plot|geom_|brewer_ramp|color_tea|epiweb|funnelPlot|marginalplot|plotContour|threshold_plot)", "viz"),
 (r"(^read|^write|^export|^import|^as\.|^as_|^to_|^from_|_to_|to$|^convert|graph_from|_igraph$|_ucinet|_pajek|xtable|json)", "io"),
 (r"(random|rewire|shuffl|permut|reshuffl|bootstrap|^boot|rg_|^rgraph|^rdiffnet|_rand|simulate|resample|^rand)", "null"),
 (r"(commun|cluster|modular|louvain|infomap|walktrap|spinglass|fastgreedy|edgebetweenness|clique_percolation|glouvain|mdlp|abacus|nmi|omega_index|maxmod|blockmodel|kmeans)", "community"),
 (r"(motif|triad|dyad_census|census|clustering_|^triangles|kcycle|^esp$|^dsp$|^nsp$)", "motif"),
 (r"(centrality|centr_|_cent$|bonpow|betweenness|closeness|eigen|pagerank|degree_w|prestige|coreness|constraint|infocent|graphcent|loadcent|flowbet|authority|^hub)", "centrality-s"),
 (r"(path|reach|distance|geodesic|diameter|latency|eccentric|adjacen)", "paths"),
 (r"(burst|duration|interevent|inter_event|formation|dissolution|spell|onset|termin|age)", "events"),
 (r"(density|transitiv|reciproc|assortativ|component|efficiency|hierarchy|connectedness|isolate|dyad|mutual|degree_dist|_stats$|summary)", "global"),
 (r"(estimate|^siena|^tergm|^stergm|^btergm|^mtergm|^tbergm|^rem|^p2|^b2|^j2$|effects|Effects|gof|^control|^snctrl|likelihood|nlpost|nllik|coef|confint|Wald|score\.Test|Multipar|interpret|timecov|edgeprob|checkdegeneracy|godfather|NetworkChange|NetworkStatic|Waic|BreakPoint|BreakDiag|update[A-Z]|^start|PAFit|_estimate$|^Jeong$|^Newman$|test_linear_PA|get_statistics|iwlsm|meta)", "model"),
 (r"(diffus|adopt|exposure|threshold|hazard|infect|suscept|contag|epi|^dcm$|^icm$|^netsim|^netdx|transmat|phylo|bass|^play_)", "diffusion"),
 (r"(^add|^delete|^remove|^set|^update|^activate|^deactivate|^rename|^clear|^induce|^append|^drop|^insert|^copy|^adjust|^reconcile|^initialize|^dedup)", "edit"),
 (r"(^generate|^rg_|^ring_lattice|^grid_|_graph$|^ml_|scenario|benchmark|^siena_?data|Distribution)", "data"),
 (r"(^get|^is_|^is\.|^has|^list|^num_|^n[a-z]*count|^count|^find|^search|^which|^print|^head|^tail|check|valid)", "util"),
]

def categorise(pkg, fn, sub):
    cur = CURATED.get(pkg, {})
    if fn in cur:
        return cur[fn]
    if pkg in ("teneto",) and sub == "communitymeasures":
        return "community"
    if pkg in ("teneto",) and sub == "communitydetection":
        return "community"
    if pkg in ("teneto",) and sub == "plot":
        return "viz"
    for rx, cat in RULES:
        if re.search(rx, fn, re.I):
            return cat
    # package-level defaults
    return {"networkDynamic":"repr","network":"repr","EpiModel":"diffusion",
            "netdiffuseR":"diffusion","RSiena":"model","tergm":"model","btergm":"model",
            "relevent":"model","goldfish":"model","dyads":"model","PAFit":"model",
            "NetworkChange":"model","multinet":"repr","tnet":"centrality-s",
            "ndtv":"viz","raphtory":"repr"}.get(pkg, "util")

# ---------------------------------------------------------- documented rows ---
# TGLib: verbatim from Table II of arXiv:2209.12587 (text extracted from the PDF).
TGLIB = [
 ("Earliest arrival distance","paths"),("Latest departure distance","paths"),
 ("Minimum transition sum distance","paths"),("Minimum hops distance","paths"),
 ("Fastest path","paths"),("Shortest temporal path","paths"),
 ("Temporal closeness","centrality-t"),("Top-k closeness (min. duration)","centrality-t"),
 ("Top-k closeness (shortest)","centrality-t"),("Temporal edge betweenness","centrality-t"),
 ("Temporal Katz","centrality-t"),("Temporal PageRank","centrality-t"),
 ("Temporal walk centrality","centrality-t"),
 ("Burstiness (edges)","events"),("Burstiness (nodes)","events"),
 ("Temporal clustering coefficient","global"),("Temporal diameter","global"),
 ("Temporal efficiency","global"),("Topological overlap","global"),
 ("(In/Out-)degree","centrality-s"),
 ("STREAM (temporal edge stream)","repr"),("ILISTS (edge incidence lists)","repr"),
 ("TRS (time-respecting structure)","repr"),("DLG (directed line graph)","repr"),
]
# Reticula: from docs.reticula.network
RETICULA = [
 ("temporal network types","repr"),("temporal hypergraphs","repr"),("event graphs","paths"),
 ("out_cluster","paths"),("temporal_adjacency","paths"),("largest_connected_component","global"),
 ("assortativity","global"),("vertex / edge degree","centrality-s"),
 ("random_gnp_graph","data"),("random Barabasi-Albert","data"),("random k-regular","data"),
 ("random link activation temporal network","data"),
 ("link shuffling","null"),("event shuffling","null"),("timeline shuffling","null"),
 ("graphicallity testing","util"),("subgraph / union / cartesian product","edit"),
]

# ------------------------------------------------------------------- build ---
items, versions = [], {}

def load(path, cols):
    with open(path) as f:
        return list(csv.DictReader(f, delimiter="\t"))

for r in load(os.path.join(D, "r_exports.tsv"), None):
    p = r["pkg"]; versions[p] = r["version"]
    items.append({"pkg":p,"fn":r["fn"],"sub":"","cat":categorise(p, r["fn"], "")})

for fname in ("py_exports.tsv","py_exports2.tsv"):
    for r in load(os.path.join(D, fname), None):
        p = r["pkg"]
        if r["version"] not in ("?",""): versions[p] = r["version"]
        items.append({"pkg":p,"fn":r["fn"],"sub":r["sub"],"cat":categorise(p, r["fn"], r["sub"])})

# Dynet: exports plus every selector vocabulary, so it compares like for like
DYNET_KIND_CAT = {
 "export":None,
 "centrality (snapshot)":"centrality-s","centrality (temporal)":"centrality-t",
 "prestige variant":"centrality-s","graph metric":"global","input format":"repr",
 "collapse weight":"repr","similarity method":"global","plot type":"viz",
 "duration unit":"events","duration measure":"events","burstiness measure":"events",
 "events measure":"events","session mode":"repr","path direction":"paths",
 "plot link style":"viz",
}
DYNET_EXPORT_CAT = {
 "dynet":"repr","as_dynet":"io","snapshots":"repr","collapse_network":"repr",
 "induce_subgraph":"edit","projection":"paths","paths":"paths","dyn_reachability":"paths",
 "path_network":"paths","path_trajectories":"paths","plot_path_trajectories":"viz",
 "dyn_centrality":"centrality-t","metrics":"global","mixing":"global","similarity":"global",
 "events":"events","durations":"events","burstiness":"events","pshifts":"motif",
}
TEMPORAL_GLOBALS = {"temporal_density","observed_pair_density","onset_intensity",
                    "observed_pair_onset_intensity","concurrent_nodes","concurrent_share"}

versions["Dynet"] = "0.3.53"
for r in load(os.path.join(D, "dynet_surface.tsv"), None):
    kind, item = r["kind"], r["item"]
    if kind == "export":
        cat = DYNET_EXPORT_CAT.get(item)
        if cat is None:
            cat = categorise("Dynet", item, "")
            if cat not in ("edit","io","util","repr"): cat = "edit"
    else:
        cat = DYNET_KIND_CAT[kind]
        if kind == "graph metric" and item in TEMPORAL_GLOBALS: cat = "global"
    items.append({"pkg":"Dynet","fn":item,"sub":kind,"cat":cat})

for fn, cat in TGLIB:
    items.append({"pkg":"TGLib","fn":fn,"sub":"Table II","cat":cat})
for fn, cat in RETICULA:
    items.append({"pkg":"Reticula","fn":fn,"sub":"docs","cat":cat})

pkgs = {}
for name,(lang,para,role,src) in PKG.items():
    pkgs[name] = {"lang":lang,"paradigm":para,"role":role,"source":src,
                  "version":versions.get(name,"—")}

out = {"packages":pkgs,"items":items,
       "cats":CATS,"catLabels":CAT_LABEL}
with open(os.path.join(D,"atlas.json"),"w") as f:
    json.dump(out,f,separators=(",",":"))

from collections import Counter
print("items:", len(items), "packages:", len(pkgs))
print("by category:", dict(Counter(i["cat"] for i in items).most_common()))
missing = sorted(set(i["pkg"] for i in items) - set(pkgs))
print("packages with no metadata:", missing)
print("bytes:", os.path.getsize(os.path.join(D,"atlas.json")))
