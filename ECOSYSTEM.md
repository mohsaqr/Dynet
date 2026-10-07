# The temporal-network ecosystem, and where Dynet sits

Companion to `COMPARISON.md`. Where `COMPARISON.md` compares Dynet function by
function against four packages, this document maps the whole field: 21 R
packages and 9 Python libraries, enumerated live in one session (2026-08-28).

**Companion documents**

- `ECOSYSTEM-INDEX.md` — the complete function-level index: all 3,556 exported
  functions across 34 packages, sorted into sixteen capability categories.
- `ecosystem/*.tsv` — the raw live enumerations these were built from.
- `ecosystem/build_atlas.py` — regenerates `ecosystem/atlas.json` and the index.
- `tmp/temporal-atlas.html` — the narrative review as a standalone page.
- `tmp/capability-index.html` — the searchable, filterable capability index.

Both open by double-clicking, or `open tmp/temporal-atlas.html` from the project root.

## Provenance

Live via `getNamespaceExports()`: networkDynamic 0.11.5, tsna 0.3.6, ndtv 0.13.4,
tnet 3.0.16, timeordered 1.0.3, tergm 4.2.2, btergm 1.11.1, RSiena 1.6.6,
goldfish 1.6.12, relevent 1.2.1, netdiffuseR 1.25.0, EpiModel 2.6.1,
NetworkChange 1.1.0, PAFit 1.2.11, multinet 4.3.4, dyads 1.2.1,
networkDynamicData 0.3.0, manynet 2.2.3, migraph 1.6.8, cograph 2.4.5,
Dynet 0.3.53.

Live via Python introspection: teneto 0.5.3, networkx-temporal 1.4.4,
dynetx 0.3.2, DyNetworkX 0.4.2, tnetwork 1.2, phasik 1.3.4, raphtory 0.17.0,
pathpy 3.0.0a2, TGX (py-tgx).

Not first-hand: TGLib (Table II of arXiv:2209.12587, text extracted from the
PDF), Reticula (docs.reticula.network). Tacoma and pathpyG were not examined.
The CRAN package `rem` failed to download and is excluded.

## The field is five paradigms, not one

| Paradigm | Question | R | Python | Dynet |
|---|---|---|---|---|
| Description | What did the network look like, and when? | networkDynamic, tsna, ndtv, timeordered, tnet, **Dynet** | teneto, networkx-temporal, dynetx, DyNetworkX, raphtory, TGLib, TGX, Reticula | its lane |
| Inference | What process produced the changes? | RSiena, tergm, btergm, relevent, goldfish, PAFit, NetworkChange, dyads | essentially nothing | none |
| Diffusion | How did something spread? | netdiffuseR, EpiModel, manynet/migraph | raphtory `temporal_SEIR` | none |
| Multilayer | Time as layers | multinet, cograph | networkx-temporal, teneto | via cograph |
| Communities & phases | Which groups persisted; when did the regime break? | NetworkChange, multinet (layers only) | tnetwork, teneto, phasik, networkx-temporal | none |

Dynet competes only in row one. R owns inference outright; Python owns scale,
temporal community detection, temporal motifs and higher-order models.

## Dynet 0.3.53, verified by running it

4 input formats; 19 snapshot centralities (all ran, 0 failed); 9 prestige
variants; 4 time-respecting centralities (closeness, betweenness, reach,
reach_count); 40 graph-level metrics (all ran, 0 failed); 5 path/reach verbs;
7 event-dynamics constructs; 8 collapse weights; 5 similarity methods;
9 plot types; 18 editing verbs. Base R, no compiled code.

Of the 59 node- and graph-level measures, 10 have a genuinely temporal
definition; the other 49 are static formulas recomputed per bin. Dynet says so
in its own error vocabulary, which is unusual in this field.

## Gaps, ranked

1. **Temporal null models.** Dynet exports nothing matching `rand|null|perm|boot|shuffle`,
   so no measure can carry a CI or a p-value. Prior art is in-language:
   timeordered ships 12 randomisations (`time_reversal`, `randomizetimes`,
   `randomized_edges`, `randomizeidentities` are the canonical four); Reticula
   ships the same family. A `randomise(dn, method =, n =)` verb returning a tidy
   null distribution would make every existing measure inferential without
   adding a statistic.
2. **Temporal community detection.** No R package does it. `projection(omega =)`
   already builds the time-expanded graph and `cograph::supra_adjacency()`
   already exists — only multislice modularity optimisation is missing.
3. **Temporal motifs.** Absent from all of R. `pshifts()` is the nearest thing;
   extending it to ordered three-node motifs is the natural step.
4. **Animation.** ndtv's `compute.animation` + `render.d3movie` with four
   interpolating layouts has no counterpart.
5. **Temporally extended attributes.** `add_nodes()` takes "static attributes";
   networkDynamic's `activate.vertex.attribute` lets an attribute change over
   time, which `mixing()` would need.

Worth *not* doing: inferential modelling (RSiena/tergm/relevent/goldfish cover
it) and diffusion (netdiffuseR/EpiModel). A `as_diffnet()` bridge beats a
reimplementation.
