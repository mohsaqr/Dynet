# Stage 5 — visualisation and representation gaps

Implementation TODOs for `Dynet` 0.3.53. Specs only; no package code is written
here.

Everything below obeys the package idiom: one call with named arguments,
vertices addressed **by name**, base R plus the four existing Imports
(`cograph`, `ggplot2`, `grDevices`, `graphics`), `.check_dynet()` then
`match.arg()`, classed `errorCondition(..., class = "dynet_*", call = NULL)`,
Okabe-Ito colour with a second channel (shape, linetype or a direct label)
carrying every distinction, and `on.exit(add = TRUE, after = FALSE)` for any
touched global.

---

## What I verified in this session, before writing anything

Facts below were produced by running code now, not recalled. Where a briefing
assumption turned out to be wrong I say so.

| Claim | Verified how | Result |
|---|---|---|
| `as_dynet()` is import-only | `NAMESPACE` | Only `S3method(as_dynet,dynet)` and `S3method(as_dynet,networkDynamic)`. **No export path exists.** Confirmed. |
| `cograph::to_igraph(dn)` works | ran it on `dynet(school_contacts)` | Returns an `igraph`, 14 vertices, 110 directed edges, `V(g)$name` correct. The source network has **240 spells over 70 distinct unordered pairs**, so this is the whole-window *aggregate*, not a spell multigraph (`igraph::is_simple()` is `TRUE`). Correct, but silent about the flattening and unmentioned anywhere on Dynet's surface. Confirmed as a Rule 0 problem. |
| `add_nodes()`/`update_nodes()` are static only | read `R/edit.R`, `dn$nodes` | `dn$nodes` is one row per vertex with atomic columns; `update_nodes()` replaces values wholesale. `dn$vertex_spells` carries *activity* (`node`, `start`, `end`, `duration`, `instant`, `session`, censoring) and **no value column**. Confirmed. |
| `projection()` ≠ an event graph | read `R/projection.R` | `projection()` vertices are `(vertex, slice)` states. Different object; see item 5. Confirmed. |
| ndtv's stability mechanism | `deparse(ndtv::compute.animation)` | Chained seeding: slice *s* is laid out with slice *s−1*'s coordinates as `seed.coords`, restricted **positionally** to active vertices, then `ndtv::layout.center()` (translation only). No rotation alignment. |
| ndtv's tweening | `ndtv:::coord.interp.smoothstep` | `coords1 + (coords2 - coords1) * (t^2 * (3 - 2t))` — smoothstep. |
| ndtv seeds randomly | `compute.animation` body | `seed.coords <- matrix(runif(network.size(net) * 2), ncol = 2)`. Its animations are **not reproducible** without an external `set.seed()`. |
| ndtv's dependency weight | `ndtv` DESCRIPTION | Depends on `network`, `networkDynamic`, `animation`, `sna`; Imports `MASS`, `statnet.common`, `tsna`, `jsonlite`, `base64`, `htmlwidgets`, `scatterplot3d`. Ten packages. Not a model Dynet can copy. |
| `cograph::layout_spring()` is seedable | `args()` then ran it | Signature includes `initial =`, `anchor_strength =`, `seed =`. Seeding a bin layout with the previous layout at `anchor_strength = 0.5` moved vertices **0.079** mean units. **This is the key finding: a seeded layout engine is already in Imports.** No new dependency is needed for item 1. |
| Procrustes actually helps | computed it | `school_contacts`, 7 slices of width 3, `ndtv::compute.animation(animation.mode = "kamadakawai")`: mean per-node inter-slice displacement **1.422** with ndtv's chained-seed-plus-centre, **1.081** after adding orthogonal Procrustes — a **24% reduction**. This is why item 1 exists as an algorithm, not a rendering detail. |
| networkDynamic's TEA surface | `getNamespaceExports("networkDynamic")` | `activate.vertex.attribute`, `deactivate.vertex.attribute`, `get.vertex.attribute.active` (with `rule = c("any","all","earliest","latest")`, `return.tea =`), `list.vertex.attributes.active`. All exported in 0.11.5. |
| A geodesic kernel already exists | `grep` | `.geodesic()` in `R/kernels.R:48`. Item 1's stress layout reuses it; no second BFS. |
| Device capability | `capabilities()` | `png`, `cairo`, `jpeg` all `TRUE` here. `grDevices::svg()` exists. **There is no GIF writer in base R or `grDevices`** — see item 2. |

**One correction to the brief.** The brief framed the animation layout as
possibly needing a from-scratch Kamada-Kawai implementation. It does not:
`cograph::layout_spring(initial =, anchor_strength =)` is already an
Imports-level seedable engine. A stress-majorization method is still worth
adding as a second option (it is the one that respects graph distances), but it
is an improvement, not a prerequisite.

---

## Item order

```
1  layout_sequence()            ── no dependencies
2  animate()                    ── needs 1
3  stable layout in static views ── needs 1
4  time-varying node attributes ── no dependencies
5  event_graph()                ── no dependencies
6  export / interop verbs       ── TEA half needs 4
```

Items 4, 5 and 6 are independent of 1–3 and can be worked in parallel.

---

# 1. Compute a stable layout sequence, one position per vertex per slice

**Why.** Every one of Dynet's nine plot types either draws one moment or draws
every moment on one page; none of them can say where a vertex *went*. A layout
sequence in which a vertex's position is continuous across slices is the object
that animation, filmstrips and trajectory views all need, and computing it is a
genuine algorithmic problem — a per-slice layout run independently gives a
different rotation, reflection and scale each time, so vertices appear to move
when nothing changed. This item builds the object; items 2 and 3 only draw it.

**Proposed API**

```r
layout_sequence(dn,
                sessions = c("bounded", "collapse", "separate"),
                start = NULL, end = NULL, step = NULL, window = NULL,
                method = c("spring", "stress", "fixed", "attribute"),
                align = c("procrustes", "translate", "none"),
                anchor = 0.5,
                default_dist = NULL,
                x = NULL, y = NULL,
                direction = c("forward", "reverse"),
                iterations = 100L,
                tolerance = 1e-4,
                seed = 1L)
```

```r
dn <- dynet(school_contacts)

layout_sequence(dn, step = 3)
layout_sequence(dn, step = 3, method = "stress", align = "translate")
layout_sequence(dn, step = 3, method = "attribute", x = "room_x", y = "room_y")
summary(layout_sequence(dn, step = 3))
```

**Return.** A `dynet_layout` object; `as.data.frame()` gives one row per vertex
per slice — exactly `nrow(dn$nodes) * n_slices` rows, so a vertex has a position
in every slice whether or not it is active, which is what makes the sequence
continuous.

| column | type | meaning |
|---|---|---|
| `session` | chr | present only when the network has sessions |
| `slice` | int | 1-based slice index |
| `time` | num | slice midpoint, the same value `snapshots()` reports |
| `start`, `end` | num | slice bounds |
| `node` | chr | vertex **name** |
| `x`, `y` | num | position, globally normalised to `[-1, 1]` |
| `active` | lgl | eligibility in this slice, from `.snapshot_state()` |
| `displacement` | num | Euclidean distance from this vertex's own position in the previous slice; `NA` in slice 1 |

`print()` shows a header (`n` vertices × `k` slices, method, alignment, mean
displacement) and the first rows. `summary()` collapses to **one row per
slice**: `slice`, `time`, `n_active`, `mean_displacement`, `max_displacement`,
`stress` (for `method = "stress"`), `converged`. `plot()` draws the
displacement-per-slice curve as a `ggplot` — the diagnostic that tells you
whether the animation will be readable before you render it.

**Algorithm**

1. **Slice.** `.window_spec(dn, start, end, step, window)` then `.grid_for()` —
   the same slicing every other verb uses, so a slice here is the same slice as
   in `snapshots()` and `projection()`. Sessions go through `.split_sessions()`;
   under `"bounded"`/`"separate"` each session block is laid out independently
   and no seed crosses a session wall.
2. **Fixed universe.** The vertex set is `dn$nodes$name` in full, every slice.
   `.bin_netobject()` returns only *eligible* vertices for a bin, so the seed
   passed into the layout engine is selected **by name**, never by row position.
   (ndtv does this positionally with `coords[activev, ]`; that is safe only
   because networkDynamic never reorders vertices. Dynet must not assume it.)
3. **Seed slice 1 deterministically.** `cograph::layout_oval(dn)` on the
   whole-window flattened network. Not `runif()`: ndtv's animations are
   irreproducible without an external seed, and Dynet's contract is that the
   same network gets the same picture every run. `seed` is still accepted and
   forwarded to `layout_spring()`, whose internals are stochastic.
4. **Per slice, in `direction` order** (`"reverse"` mirrors ndtv's
   `chain.direction`; it matters because chained seeding is order-dependent and
   the first slice is the only unconditioned one):
   - `method = "spring"` — `cograph::layout_spring(net, initial = seed,
     anchor_strength = anchor, seed = seed)`. Verified seedable this session.
   - `method = "stress"` — stress majorization (SMACOF) in base R on the slice's
     geodesic distance matrix from `.geodesic()` (`R/kernels.R:48`), with
     unreachable pairs set to `default_dist`, defaulting to `sqrt(n)` following
     `ndtv::layout.distance()`. Weights `w_ij = d_ij^-2`; iterate the Guttman
     transform `X ← (1/n) · B(X) · X` where `B_ij = -w_ij d_ij / ||x_i - x_j||`
     off-diagonal and `B_ii = -Σ_{j≠i} B_ij`; start at the seed. Stop when the
     relative change in stress falls below `tolerance` or `iterations` is hit.
     **Surface non-convergence** — a `converged` column in `summary()` and a
     `warningCondition(..., class = "dynet_no_converge")`, never a silently
     unconverged layout. Guard the `||x_i - x_j|| = 0` division explicitly
     rather than letting `NaN` propagate.
   - `method = "fixed"` — one layout of the flattened network, reused verbatim.
     Zero movement by construction. This is the honest baseline: if the
     animation is no less readable under `"fixed"`, the movement was noise.
   - `method = "attribute"` — positions read from the vertex columns named by
     `x` and `y`, the counterpart of
     `ndtv::network.layout.animate.useAttribute()`. Once item 4 lands these may
     themselves be time-varying, which is the case ndtv cannot express either.
5. **Align to the previous slice** over the vertices active in both, by name:
   - `"translate"` — centre each slice on its centroid. This is all ndtv does.
   - `"procrustes"` — orthogonal Procrustes (Schönemann 1966). Centre the shared
     rows of the previous layout `A` and the new layout `B`; take
     `svd(t(B) %*% A) = U D Vᵀ`; rotate by `R = U Vᵀ`. **Reflection is allowed**
     (a reflected drawing is the same drawing); **scaling is not applied**,
     because scaling would undo the distances the layout just solved for. Apply
     `R` and the translation to *all* vertices of the new slice, not only the
     shared ones. Measured benefit on `school_contacts`: mean displacement
     1.422 → 1.081.
   - Vertices inactive in this slice keep their previous coordinate, so a vertex
     that disappears and returns does not teleport.
6. **Normalise once, globally.** Rescale all slices together into `[-1, 1]`
   using the bounding box over the whole sequence. Per-slice rescaling is itself
   a source of spurious motion; ndtv centres per slice and computes the global
   box only later, at render time.
7. `displacement` is computed after alignment and normalisation, so it measures
   what the viewer will actually see.

**References**

- Kamada, T., & Kawai, S. (1989). An algorithm for drawing general undirected
  graphs. *Information Processing Letters*, 31(1), 7–15.
- de Leeuw, J. (1977). Applications of convex analysis to multidimensional
  scaling. In *Recent Developments in Statistics*, 133–146. (SMACOF.)
- Gansner, E. R., Koren, Y., & North, S. (2004). Graph drawing by stress
  majorization. *Graph Drawing 2004*, LNCS 3383, 239–250.
- Schönemann, P. H. (1966). A generalized solution of the orthogonal Procrustes
  problem. *Psychometrika*, 31(1), 1–10.
- Brandes, U., & Mader, M. (2011). A quantitative comparison of
  stress-minimization approaches for offline dynamic graph drawing.
  *Graph Drawing 2011*, LNCS 7034, 99–110.
- Baur, M., & Schank, T. (2008). *Dynamic Graph Drawing in Visone*. Technical
  Report, Universität Karlsruhe.
- Bender-deMoll, S., & McFarland, D. A. (2006). The art and science of dynamic
  network visualization. *Journal of Social Structure*, 7(2).

**Verify against.** `ndtv::compute.animation(net, animation.mode =
"kamadakawai")` on the same network converted with item 6's
`as_networkDynamic()`. Two comparisons, both of which are already scripted in
this session's exploration:
1. *Not* coordinate equality — KK and stress majorization are different
   optimisers of related objectives and there is no reason for them to agree
   pointwise. Comparing coordinates would be a false test.
2. **Stress equality.** Compute the raw KK stress `Σ w_ij (||x_i − x_j|| −
   d_ij)²` of ndtv's coordinates and of Dynet's, on the *same* distance matrix
   from `ndtv::layout.distance()`. Dynet's `method = "stress"` must not be worse
   by more than a stated tolerance on any slice; assert it and record the
   tolerance.
3. **Stability comparison**, the actual claim: mean per-node inter-slice
   displacement under Dynet's `align = "procrustes"` must be ≤ ndtv's on the
   same slicing. Measured 1.081 vs 1.422 this session; the test asserts the
   inequality, not the numbers, so it survives an ndtv update.

**Tests** — `tests/testthat/test-layout-sequence.R`

- Error paths (assert the **class**, never the message):
  - `expect_error(layout_sequence(dn, default_dist = -1), class = "dynet_bad_input")`
  - `expect_error(layout_sequence(dn, method = "attribute", x = "nope", y = "nope"), class = "dynet_unknown_attribute")`
  - `expect_error(layout_sequence(dn, start = 5, end = 1), class = "dynet_bad_input")`
  - `expect_error(layout_sequence(dn, sessions = "separate"), class = "dynet_no_sessions")` on a session-free network (class already exists).
- Invariant / property tests:
  - **Completeness.** `nrow(as.data.frame(...)) == nrow(dn$nodes) * n_slices`, and every node name appears exactly once per slice.
  - **Zero-motion baseline.** Under `method = "fixed"` every `displacement` is 0 within `sqrt(.Machine$double.eps)`. This is the test that catches an alignment step that silently moves everything.
  - **Alignment monotonicity.** With everything else fixed, mean displacement under `"procrustes"` ≤ under `"translate"` ≤ under `"none"`.
  - **Rigid-motion invariance.** Rotate the slice-1 seed by a fixed angle; under `"procrustes"` no `displacement` value changes.
  - **Determinism.** Two calls with the same `seed` are `identical()`.
  - **Name, not index.** Rebuild the network with the vertex table in a different order; per-node coordinates are unchanged.
  - **Non-convergence is surfaced.** `layout_sequence(dn, method = "stress", iterations = 1L)` emits a `dynet_no_converge` warning and reports `converged = FALSE` in `summary()`.
- Snapshot test on `print()` and `summary()` with `expect_snapshot()`.
- **Visual review, per CLAUDE.md.** Render `tmp/layout-sequence.Rmd` →
  `tmp/layout-sequence.html`: for two real datasets, small multiples under
  `align = "none"` beside `align = "procrustes"`, plus the displacement curve
  from `plot()`. Do **not** judge it by inspection — present the HTML and ask
  the user to review before continuing.

**Effort — L.** The layout maths is ~120 lines. The work is the correctness
surface: inactive vertices, slices with one vertex or none, isolates with no
distance constraint (hold them at their seed rather than letting the optimiser
scatter them), reflections, session blocks, and a new result class with four
methods.

**Depends on** — nothing.

**New dependency?** **No.** `cograph::layout_spring()` is Imports and verified
seedable; `svd()`, `.geodesic()` and the rest are base R and existing internals.

---

# 2. Render the layout sequence as an animation

**Why.** This is the largest visible gap against ndtv, the field's benchmark.
Dynet has nine static views and nothing that moves, so the one thing a temporal
network does that a static one cannot — change — is the one thing the package
cannot show. Item 1 makes the positions; this item turns them into something a
person can watch, without acquiring ndtv's ten-package dependency chain.

**Proposed API**

```r
animate(dn,
        file = NULL,
        format = c("html", "png", "svg", "filmstrip"),
        layout = NULL,
        sessions = c("bounded", "collapse", "separate"),
        start = NULL, end = NULL, step = NULL, window = NULL,
        tween = 10L, fps = 10L,
        width = 800, height = 600,
        edge_fade = TRUE,
        highlight = NULL, labels = TRUE,
        palette = "okabe",
        ...)
```

```r
dn <- dynet(school_contacts)

animate(dn, step = 2)                                  # writes an HTML player
animate(dn, step = 2, format = "filmstrip")            # draws to the device
animate(dn, step = 2, format = "png", file = "frames") # numbered PNG frames
animate(dn, layout = layout_sequence(dn, step = 2, method = "stress"))
```

`layout` accepts a `dynet_layout` from item 1, or `NULL` to compute one with
that verb's defaults from the slicing arguments given here. Passing the object
is what lets a user tune the layout once and render it three ways.

**Return.** A `dynet_animation` object, invisibly. `as.data.frame()` gives **one
row per drawn frame**: `frame` (int), `slice` (int), `tween_step` (int, 0 at a
slice), `time` (num, the interpolated clock position), `file` (chr, the path
written, `NA` for `"html"` and `"filmstrip"`). `print()` names what was written
and, for `format = "png"`, prints the exact one-line `ffmpeg` and `magick`
command that turns the frames into an MP4 or a GIF. `summary()` gives one row
per slice. `plot()` redraws the filmstrip.

Files written, by format:

| `format` | written | needs |
|---|---|---|
| `"html"` (default) | one self-contained `.html` file | nothing |
| `"png"` | `frame-0001.png` … in `file`, a directory | `grDevices::png()` |
| `"svg"` | one `.svg` with declarative `<animate>` elements | nothing |
| `"filmstrip"` | nothing — small multiples on the current device | nothing |

**Algorithm**

*Tweening.* Frame `j` between slices `s` and `s+1` at `t = j / tween`:

```
p = p_s + (p_{s+1} - p_s) * (t^2 * (3 - 2t))
```

Smoothstep, the same easing `ndtv:::coord.interp.smoothstep` uses (printed and
confirmed this session). Total frames `(n_slices - 1) * tween + 1`. Edges are
those of the slice being left; with `edge_fade = TRUE` a tie's alpha ramps out
across the tween and the next slice's ramps in, so ties cross-dissolve rather
than blink — ndtv blinks, and on a sparse contact network blinking is the main
reason the animation is hard to read. Colour never carries a distinction alone:
a vertex named in `highlight` gets a different `node_shape` and a direct label
as well as a different Okabe-Ito colour, and there is no legend.

*Global restoration.* `format = "png"`/`"svg"` open devices —
`on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)`. `"filmstrip"`
touches `par(mfrow)` — `old <- graphics::par(...)`, then
`on.exit(graphics::par(old), add = TRUE, after = FALSE)`, exactly as
`.splot_snapshots()` already does.

### Output format — the honest analysis

The brief asked me not to hand-wave this, so:

**Animated GIF is not achievable without a dependency, and Dynet should not
try.** There is no GIF encoder anywhere in base R or `grDevices`; `grDevices`
writes single PNG/JPEG/TIFF/BMP/SVG/PDF images only. GIF requires LZW
compression. `animation::saveGIF()` shells out to ImageMagick or GraphicsMagick;
`gifski` is a Rust binding; `magick` is an ImageMagick binding. A pure-R LZW GIF
encoder is roughly 200 lines, slow on 8-bit-quantised frames, and impossible to
test properly without also writing a decoder. For a package whose value is
temporal-network mathematics, that is the wrong thing to own. **Recommendation:
do not ship an encoder.** `format = "png"` writes correctly numbered frames and
`print()` hands the user the encoding command. Dynet does the hard part —
computing a stable layout — and the user's own `ffmpeg` or `magick` does the
part their machine already does well.

**A self-contained HTML player is achievable with no dependency, and should be
the default.** Not by embedding images — by embedding *data*. The layout
sequence and per-slice edge lists are a few hundred numbers and strings; write
them into a `<script>` block and let ~150 lines of hand-written vanilla
JavaScript draw and tween them in an SVG element in the browser. No d3, no
`htmlwidgets`, no base64, no external fetch. The JS lives in
`inst/animate/player.js`, is read with `readLines()` and inlined, so the shipped
artefact is auditable and the R side is `writeLines()` plus `sprintf()`.

Three costs the maintainer must accept, stated plainly:

1. **Dynet would contain JavaScript.** That is a real change in what the package
   is, and it needs the maintainer's explicit consent. It is not a dependency in
   the DESCRIPTION sense, but it is code in a second language that has to be
   maintained and reviewed.
2. **The JSON must be hand-written** — base R has no JSON writer. For a fixed
   schema of numbers and strings that is ~25 lines, with `encodeString()`
   handling vertex names that contain quotes or backslashes. It is testable: a
   guarded `skip_if_not_installed("jsonlite")` test round-trips the emitted file
   and asserts the node names and coordinates come back unchanged. That is the
   right use of a Suggests package — verifying our own output, not producing it.
3. **An HTML file is not a video.** It cannot be dropped into a manuscript.
   `format = "png"` plus the printed encoding command is the answer for that,
   and the docs must say so rather than implying the HTML replaces a movie.

What the player buys, free, once it exists: a time scrubber, play/pause, speed
control and hover-to-name. Explicitly **not** proposed: a Shiny binding or an
`htmlwidgets` widget. `ndtv::ndtvAnimationWidget()` exists for people who want
that and `as_networkDynamic()` (item 6) reaches it in one call.

**A script-free SVG alternative is worth shipping too, because it is 40 lines.**
`format = "svg"` writes one SVG whose `<circle>` elements carry `<animate>`
children interpolating `cx`/`cy` between slice times, generated by `sprintf()`
alone. One portable file, no JavaScript, renders in any browser and in most
document tools. Honest limitations: SMIL's long-term browser support is
uncertain, there is no scrubber, and edge appearance/disappearance is clumsier
to express than in script. Ship it as an option; do not make it the default.

**`format = "filmstrip"` is what makes the feature testable.** It draws the
tweened frames as static small multiples through `cograph::splot()` — the
counterpart of `ndtv::filmstrip()` — writing no file and opening no browser, so
it runs under `R CMD check`, in a vignette, and in the PDF manual. Every
invariant about frame count, frame times and coordinate bounds is asserted
against the `dynet_animation` table, which every format produces identically, so
the file-writing formats are tested through the same contract without any test
writing outside `tempdir()`.

**References**

- Bender-deMoll, S. (2016–2024). *ndtv: Network Dynamic Temporal
  Visualizations*, version 0.13.4. \doi{10.32614/CRAN.package.ndtv}
- Bender-deMoll, S., & McFarland, D. A. (2006). The art and science of dynamic
  network visualization. *Journal of Social Structure*, 7(2).
- Moody, J., McFarland, D., & Bender-deMoll, S. (2005). Dynamic network
  visualization. *American Journal of Sociology*, 110(4), 1206–1241.
- Okabe, M., & Ito, K. (2008). *Color Universal Design*.

Note on the easing: smoothstep has no canonical citation — it is a folklore
Hermite blend. Cite `ndtv:::coord.interp.smoothstep` as the implementation being
matched rather than inventing a source for it.

**Verify against.** `ndtv::render.animation()` and `ndtv::render.d3movie()` on
the same network via `as_networkDynamic()`. Frame *counts* and frame *times*
must agree exactly with ndtv's for the same `slice.par` and
`render.par$tween.frames`, because the tween schedule is arithmetic, not a
layout choice — that is a genuine equivalence check. Frame *coordinates* are not
compared, for the reason given in item 1. `ndtv::filmstrip()` is the visual
reference for the filmstrip format.

**Tests** — `tests/testthat/test-animate.R`

- Error paths:
  - `expect_error(animate(dn, tween = 0), class = "dynet_bad_input")`
  - `expect_error(animate(dn, format = "png", file = file.path(tempdir(), "no-such-dir", "f")), class = "dynet_cannot_write")` — a new class; the package currently has nothing for an unwritable target.
  - `expect_error(animate(dn, start = 100, end = 101), class = "dynet_empty_result")`
- Invariant / property tests:
  - Frame count is exactly `(n_slices - 1) * tween + 1`; frame times strictly increasing.
  - First and last frame coordinates equal the first and last slice coordinates **exactly** (`identical()`, not `all.equal()` — smoothstep is exactly 0 and 1 at the endpoints).
  - **No overshoot.** Every tweened coordinate lies inside the axis-aligned box of its two bracketing slice coordinates. This is the test that catches someone substituting a spline for the easing.
  - Monotone easing: with `tween = 10`, per-frame displacement is unimodal in the frame index (smoothstep accelerates then decelerates).
  - Round-trip: the HTML file's embedded JSON parses under `jsonlite` (guarded by `skip_if_not_installed`) and its node names equal `dn$nodes$name`.
  - All four formats produce the same `as.data.frame()` frame table apart from the `file` column.
- Everything that writes uses `tempfile()`/`tempdir()` and `skip_on_cran()`. Nothing writes into the package or the working directory.
- **Visual review, per CLAUDE.md.** `tmp/animation.html` is the real product;
  additionally render `tmp/animate-review.Rmd` → `tmp/animate-review.html`
  embedding the filmstrip and linking the player, for two datasets and both
  `edge_fade` settings. Present it and ask the user to review; do not claim it
  looks right.

**Effort — L.** The R side is moderate. The JavaScript player, the hand-written
JSON writer, four output formats and a test strategy that never writes outside
`tempdir()` are the bulk of it.

**Depends on** — item 1.

**New dependency?** **No new Imports and no new hard dependency.** Two flags for
the maintainer: (a) the package would ship JavaScript in `inst/`, which is a
policy decision, not a dependency one; (b) **`jsonlite` should be added to
Suggests**, used only inside a guarded test to verify our own emitted JSON.
`animation`, `gifski`, `magick`, `av`, `gganimate` and `htmlwidgets` are all
explicitly **not** proposed.

---

# 3. Give the static views the stable layout, and add a time-prism view

**Why.** `.splot_snapshots()` currently pins one `cograph::layout_oval()` across
every panel: comparable, but structurally blind — every panel is the same ring
and only the edges differ. Item 1 makes panels that are comparable *and*
structure-revealing. Separately, `type = "layers"` draws slices as multilayer
planes via `cograph::plot_mlna()`, but nothing draws a vertex's *trajectory*
through those planes, which is the one static figure that shows movement.

**Proposed API**

```r
plot(dn, type = "snapshots", positions = c("shared", "stable", "free"), ...)
plot(dn, type = "prism", positions = "stable", step = 3, ...)
```

```r
dn <- dynet(school_contacts)
plot(dn, type = "snapshots", positions = "stable", step = 3)
plot(dn, type = "prism", step = 3, highlight = "Ana")
```

**Naming warning.** The argument must be `positions`, **not** `layout`.
`.check_plot_dots()` folds `names(formals(cograph::splot))` into the accepted
names for the delegating views, and `.splot_args()` already sets
`defaults$layout` — a `layout` argument on `plot.dynet()` would silently
collide with splot's own. Add `"prism"` to the `type` vector and to the
`delegate` switch in `.check_plot_dots()` (delegate `"splot"`).

**Return.** Drawn on the current device; `x` returned invisibly — the same
contract the other node-link views already have.

**Algorithm.** `positions = "shared"` keeps today's single `layout_oval()`;
`"stable"` calls `layout_sequence()` with the plot's own slicing arguments and
writes each slice's coordinates onto that bin's netobject with
`cograph::set_layout()`, matching **by name** as `.splot_snapshots()` already
does with `match(net$nodes$name, x$nodes$name)`; `"free"` lets each panel lay
itself out, which is the wrong answer but is worth being able to show people
that it is the wrong answer.

`type = "prism"` draws the slices as stacked planes on one base-graphics panel
built with `.dyn_panel()`: each plane is the slice's vertices at their
`layout_sequence()` positions, sheared by a fixed angle so the planes read as
depth, with each vertex's positions joined across planes by a light polyline —
its trajectory. `highlight` names vertices whose trajectory is drawn in colour
*and* with a heavier linetype *and* directly labelled at the last plane; the
rest are grey. This is `ndtv::timePrism()`'s idea, drawn with Dynet's own panel
style rather than `scatterplot3d`. `on.exit(graphics::par(old), add = TRUE,
after = FALSE)`.

**References**

- Bender-deMoll, S. (2024). `timePrism()` and `filmstrip()` in *ndtv* 0.13.4.
- Bach, B., Pietriga, E., & Fekete, J.-D. (2014). Visualizing dynamic networks
  with matrix cubes. *CHI 2014*, 877–886.
- Brandes, U., & Corman, S. R. (2003). Visual unrolling of network evolution and
  the analysis of dynamic discourse. *Information Visualization*, 2(1), 40–50.

**Verify against.** `ndtv::filmstrip()` and `ndtv::timePrism()` on the same
network via `as_networkDynamic()` — a structural comparison (same slices, same
vertices per plane, same trajectory topology), not a pixel one.

**Tests** — extend `tests/testthat/test-plot.R`

- Error paths: `expect_error(plot(dn, type = "prism", positions = "nonsense"))` via `match.arg`; and, the classed one, `expect_error(plot(dn, type = "prism", layout = "spring"), class = "dynet_unknown_plot_arg")` — proving the `positions`/`layout` collision is caught rather than silently ignored.
- Invariants: under `positions = "stable"`, a vertex present in two panels has coordinates equal to the corresponding `layout_sequence()` rows (matched by name); under `positions = "shared"`, all panels share one coordinate set exactly.
- Every drawing test restores `par()` — assert `identical(graphics::par("mfrow"), before)` after the call.
- **Visual review, per CLAUDE.md.** `tmp/stable-views.Rmd` → `tmp/stable-views.html`, showing all three `positions` values side by side plus the prism. Present and ask.

**Effort — M.** Mostly wiring an existing object into existing views; the prism
panel is new drawing code but sits on `.dyn_panel()` and `.spread_labels()`,
which already exist.

**Depends on** — item 1.

**New dependency?** No.

---

# 4. Store node attributes that change over time

**Why.** Verified: `dn$nodes` is one static row per vertex and `dn$vertex_spells`
records only *activity*, with no value column — `man/add_nodes.Rd` says "static
attributes" and it is accurate. networkDynamic has carried temporally extended
attributes since 0.9 via `activate.vertex.attribute()` /
`get.vertex.attribute.active()`, both exported in 0.11.5. The consequence is
concrete rather than theoretical: `mixing()` reads `dn$nodes[[attribute]]` once,
so a vertex's group is fixed for all time, and the package therefore cannot
answer whether mixing changed *because the attribute changed* — which for
role-change, group-membership or achievement-band data is the question.

**Proposed API**

Constructor gains one argument, alongside the existing `vertex_spells`:

```r
dynet(data, ..., node_spells = NULL)
```

Editing verbs mirror the existing `*_vertex_spells()` family exactly, so there
is nothing new to learn:

```r
set_node_spells(dn, data)
add_node_spells(dn, data)
update_node_spells(dn, spells, data)
remove_node_spells(dn, spells)
```

Reading, through accessors rather than `$`:

```r
as.data.frame(dn, what = "node_spells")
as.data.frame(dn, what = "nodes", at = 3)
```

`mixing()` gains one argument:

```r
mixing(dn, attribute, rule = c("start", "any", "all", "majority"), ...)
```

```r
roles <- data.frame(
  name = c("Ana", "Ana", "Ben"),
  attribute = "role",
  value = c("lurker", "leader", "leader"),
  start = c(0, 10, 0), end = c(10, 22, 22)
)
dn <- dynet(school_contacts, node_spells = roles)

as.data.frame(dn, what = "node_spells")
as.data.frame(dn, what = "nodes", at = 12)
mixing(dn, attribute = "role", step = 4)
mixing(dn, attribute = "role", step = 4, rule = "all")
```

**Return / storage.** A third ledger, `dn$node_spells`, one row per
(node, attribute, spell):

| column | type | meaning |
|---|---|---|
| `node_spell` | int | stable id, as `vertex_spell` already is |
| `node` | chr | vertex **name** |
| `attribute` | chr | attribute name |
| `value` | chr | the value, stored as character |
| `start`, `end` | num | half-open `[start, end)`, the package's existing interval convention |
| `session` | chr | present when the network has sessions |
| `onset_censored`, `terminus_censored` | lgl | as elsewhere |

Value is stored as **character**, with the original class kept in
`dn$meta$node_attribute_classes` (a named character vector) and restored on
read. The alternative — a list-column, or one table per attribute — either
breaks the tidy one-row-per-observation contract or produces something that does
not print. Say this in the roxygen `@details` so the choice is visible.

`as.data.frame(dn, what = "nodes", at = 3)` returns the vertex table as it stood
at that instant: static columns unchanged, dynamic columns resolved and restored
to their original class, plus a `changing` logical column naming vertices whose
value is not unique over the requested window. `at = NULL` keeps today's exact
behaviour, so no existing call changes.

**Algorithm**

*Validation, at the entry point.* Names must exist in the vertex table
(`dynet_unknown_node`, already a class). Spells for the same
`(node, attribute)` **may not overlap** — a vertex cannot hold two values of one
attribute at one time — raising `dynet_overlapping_attribute`. This is stricter
than networkDynamic, which permits overlap and resolves it at read time with
`rule = c("any", "all", "earliest", "latest")`; the difference must be
documented, because it changes what `as_dynet()` can import losslessly (see
below). Gaps *are* allowed and read back as `NA`, which is the same
missing-value path `mixing()` already handles with its collision-safe
`"(missing)"` level.

*Resolution per bin.* For each bin, take each vertex's value in force under
`rule`:

- `"start"` (default) — the value in force at the bin's start instant. The only
  rule that never invents a group and never double-counts.
- `"any"` — a vertex holding two values inside the bin contributes to both
  cells. The table total then exceeds the active dyad count; the returned
  object's `normalization` attribute must say so rather than letting a reader
  assume the margins still add up.
- `"all"` — only vertices whose value is constant across the bin are counted;
  the rest go to an explicit `"(changing)"` level, built with the same
  collision-safe candidate search `"(missing)"` already uses.
- `"majority"` — the value holding the largest share of the bin's duration; ties
  broken by the earlier value, deterministically.

*What changes in `mixing()`.* Structurally, nothing: still one row per bin per
group pair, still every cell emitted including zeros. Three real changes:

1. The **level universe is the union over the whole window**, not per bin, so a
   group that only exists late still gets its zero cells early. Without this the
   result stops being a rectangle and the plot method breaks.
2. New attributes: `attr(out, "attribute_time") <- "dynamic"` (or `"static"`)
   and `attr(out, "attribute_rule") <- rule`. Dynet's habit of recording its own
   conventions on the result is exactly right here.
3. **An honesty note in `@details`**, which matters more than the code: with a
   dynamic attribute the diagonal of the mixing table stops being interpretable
   as homophily without a null model, because attribute and tie can change
   together and the observed diagonal has no baseline. Point at the missing
   `randomise()` verb (`ECOSYSTEM.md` gap 1) rather than implying the count is
   inferential. This is the "10 of 59 measures are genuinely temporal" habit
   applied to a new construct.

*Import path.* `as_dynet.networkDynamic()` gains TEA import:
`networkDynamic::list.vertex.attributes.active()` to find them, then
`get.vertex.attribute.active(..., return.tea = TRUE)` to lift each into
`node_spells`. Overlapping source spells cannot be represented under the
non-overlap rule above; raise `dynet_overlapping_attribute` naming the
attribute and the vertex, rather than silently picking one. Both functions are
exported in networkDynamic 0.11.5 (verified).

**References**

- Butts, C. T., Leslie-Cook, A., Krivitsky, P. N., & Bender-deMoll, S. (2024).
  *networkDynamic: Dynamic Extensions for Network Objects*, version 0.11.5.
  \doi{10.32614/CRAN.package.networkDynamic}
- Newman, M. E. J. (2003). Mixing patterns in networks. *Physical Review E*, 67,
  026126. (Already cited by `mixing()`.)
- Morris, M., Handcock, M. S., & Hunter, D. R. (2008). Specification of
  exponential-family random graph models. *Journal of Statistical Software*,
  24(4).
- Snijders, T. A. B., van de Bunt, G. G., & Steglich, C. E. G. (2010).
  Introduction to stochastic actor-based models for network dynamics. *Social
  Networks*, 32(1), 44–60. (The co-evolution problem the honesty note points at.)

**Verify against.** networkDynamic, directly. Build the same network both ways;
for every `t` on a grid across the window, assert
`get.vertex.attribute.active(nd, "role", at = t)` equals the `role` column of
`as.data.frame(dn, what = "nodes", at = t)`, matched **by vertex name**, not by
position. Then assert the round trip
`as_dynet(as_networkDynamic(dn))` (item 6) preserves `node_spells` exactly.

**Tests** — `tests/testthat/test-node-spells-contract.R`, plus additions to
`test-mixing-contract.R`

- Error paths:
  - `expect_error(dynet(edges, node_spells = overlapping), class = "dynet_overlapping_attribute")`
  - `expect_error(dynet(edges, node_spells = unknown_name), class = "dynet_unknown_node")`
  - `expect_error(mixing(dn, attribute = "not_there"), class = "dynet_unknown_attribute")` — existing class, retained on the new path.
- Invariant / property tests:
  - **Backward compatibility, the important one.** An attribute whose spells
    cover the whole window with a single constant value gives `mixing()` output
    numerically **identical** to supplying the same attribute statically —
    values, columns and every recorded attribute except `attribute_time`. This
    proves the new path did not move the old answer.
  - **Margins.** Under `rule = "start"`, the sum of all cells in a bin equals
    that bin's active binary-dyad count, the invariant the static path already
    satisfies. Under `rule = "any"` it may exceed it, and the test asserts the
    `normalization` attribute says so.
  - **Rectangularity.** The level universe is identical in every bin.
  - **Rule ordering.** The `"all"` cell counts are ≤ the `"start"` counts, since
    `"all"` can only move vertices into `"(changing)"`.
  - Round-trip through the editing verbs: `remove_node_spells()` after
    `add_node_spells()` restores the original object (`all.equal()` on the
    accessor tables).
- Visual: `plot(mixing(...))` gains a subtitle naming the rule. That is a visual
  change, so render `tmp/mixing-dynamic.html` and present it.

**Effort — L.** It touches the constructor, four new editing verbs, two
accessors, the networkDynamic importer and `mixing()`. Each of those has an
existing contract test that must stay green, and `test-mixing-contract.R` is one
of the strictest files in the suite.

**Depends on** — nothing. (Item 1's `method = "attribute"` becomes more useful
once this lands, but does not require it.)

**New dependency?** No. `networkDynamic` stays in Suggests, guarded.

---

# 5. Build the event graph — events as vertices

**Why.** Verified against `R/projection.R`: `projection()` builds the
*time-expanded* graph, whose vertices are `(vertex, slice)` **node-states** —
`n_nodes × n_slices` of them, every vertex present in every slice whether active
or not, joined by `within_slice` arcs from the snapshot adjacency and
`identity_arc` arcs carrying a vertex forward with weight `omega`. That is the
supra-adjacency object you run multislice modularity or a random walk on. An
**event graph** is a different object: its vertices are the *events themselves*
— one per spell — and an arc joins two events that share a vertex and are
temporally adjacent at it. Its size is O(events), it has no slicing parameters
at all, and a directed path in it **is** a time-respecting path, so reachability
becomes ordinary graph reachability. Nothing in R computes it.

The distinction, stated precisely:

| | `projection()` | `event_graph()` |
|---|---|---|
| vertex | a `(vertex, slice)` node-state | one spell of `as.data.frame(dn)` |
| vertex count | `n_nodes × n_slices` | `n_spells` |
| arcs | snapshot adjacency within a slice; identity arcs between slices | one event to its temporally adjacent successor at a shared vertex |
| needs a time grid | yes (`step`, `window`) | **no** |
| a path in it means | a walk in the time-expanded graph | a time-respecting path in the original network |
| what it is for | multislice community detection, supra-adjacency spectra, diffusion | reachability, temporal motifs, temporal percolation |

**Proposed API**

```r
event_graph(dn,
            sessions = c("bounded", "collapse", "separate"),
            delta = Inf,
            adjacency = c("next", "all"),
            direction = c("respect", "ignore"),
            loops = FALSE)
```

```r
dn <- dynet(school_contacts)

event_graph(dn)
event_graph(dn, delta = 2)
as.data.frame(event_graph(dn, delta = 2), what = "adjacencies")
summary(event_graph(dn))
plot(event_graph(dn, delta = 2))
```

- `delta` — the maximum waiting time at the shared vertex (δ-adjacency).
  `Inf` is unbounded.
- `adjacency = "next"` (default) links only the *first* qualifying successor per
  shared vertex — Kovanen et al.'s definition, which keeps the graph sparse and
  makes it a genuine adjacency structure. `"all"` links every qualifying
  successor within δ, which some tools use and which is denser by a large
  factor; the default is stated and justified in `@details`.
- `direction = "respect"` requires, on a directed network, that the shared
  vertex is the *head* of the earlier event and the *tail* of the later one, so
  an arc means something could have flowed. `"ignore"` treats any shared
  endpoint as adjacency, which is what an undirected network needs.

**Return.** A `dynet_event_graph`. `as.data.frame(x, what = c("events",
"adjacencies"))`:

*events* — one row per spell:
`event` (int), `session` (when present), `from` (chr), `to` (chr), `start`,
`end`, `duration`, `weight`, `spell` (the original `.raw_spell`, so the row
traces back to the input).

*adjacencies* — one row per adjacency:
`from_event` (int), `to_event` (int), `via` (chr — **the shared vertex's name**,
which is the column a line graph normally hides and the one that makes this
readable), `from_time`, `to_time`, `wait` (`= to_time - from_time`), `session`.
Two events sharing *two* vertices produce **two rows**, one per `via`. That is
correct and must be documented, because it is the first thing that surprises
people.

`print()` — header (`n` events, `m` adjacencies, δ, adjacency rule) plus the
first rows. `summary()` — one row per event: `event`, `time`, `in_degree`,
`out_degree`, `mean_wait`. `plot()` — the DAG through `cograph::splot()` using
the **already-registered** `"temporal"` layout (`R/theme.R`), feeding
`arrival_time = start` and `n_hops` from a longest-path depth, so this view is
almost free.

**Algorithm**

1. Order spells by `(start, end, from, to)` — a deterministic total order with
   an explicit secondary key, never input order.
2. For each vertex `v`, take the ordered list of events incident to `v`,
   filtered by `direction`.
3. Because that list is sorted by `start`, the successors of event `e` at `v`
   are a contiguous range: `findInterval()` on `e$end` gives the lower bound and
   `findInterval()` on `e$end + delta` the upper. `adjacency = "next"` takes the
   first element of that range; `"all"` takes all of it. One merge pass per
   vertex — **no O(E²) pair scan and no `for` loop over pairs**.
4. Instantaneous events (`start == end`) reuse the tie-breaking convention the
   package already applies: an event is never its own successor, and two
   simultaneous events at one vertex are **not** adjacent, since there is no
   ordering between them. State the rule in `@details` and test it directly —
   this is where implementations of this construct usually disagree.
5. `loops = FALSE` drops self-loop spells from the event set before adjacency;
   `TRUE` keeps them, and a self-loop is adjacent at its single vertex.
6. Sessions go through `.split_sessions()`; under `"bounded"`/`"separate"` no
   adjacency crosses a session wall, matching `projection()`'s behaviour exactly
   so the two constructs cannot disagree about what a session is.

**The correctness property, and it is a good one.** With `delta = Inf` and the
same session mode, a directed path in the event graph from an event incident to
`u` to an event incident to `w` exists **iff** `paths(dn, from = u)` reports `w`
reachable. Dynet can verify a new construct against its own independently
implemented path engine — rare, and worth exploiting as the primary test.

**References**

- Kivelä, M., Cambiotti, R., Saramäki, J., & Karsai, M. (2018). Mapping
  temporal-network percolation to weighted, static event graphs. *Scientific
  Reports*, 8, 12357.
- Mellor, A. (2018). The temporal event graph. *Journal of Complex Networks*,
  6(4), 639–659.
- Kovanen, L., Karsai, M., Kaski, K., Kertész, J., & Saramäki, J. (2011).
  Temporal motifs in time-dependent networks. *Journal of Statistical
  Mechanics*, P11005. (δ-adjacency.)
- Badie-Modiri, A., Karsai, M., & Kivelä, M. (2020). Efficient limited-time
  reachability estimation in temporal networks. *Physical Review E*, 101,
  052303.
- Badie-Modiri, A., & Kivelä, M. (2023). Reticula: A temporal network and
  hypergraph analysis software package. *SoftwareX*, 21, 101301.
- Holme, P., & Saramäki, J. (2012). Temporal networks. *Physics Reports*,
  519(3), 97–125.

**Verify against.** **No R package computes this** — say so in the docs rather
than implying a comparison exists. Verification is therefore threefold and all
of it is real:
1. **Internal.** The reachability equivalence above, against `paths()` and
   `dyn_reachability()`.
2. **External, partial.** `tsna::tPath()` (tsna is already in Suggests) gives
   forward-reachable sets from a source; the set of vertices touched by events
   reachable in the event graph must equal it.
3. **Brute force.** A deliberately naive O(E²) double-loop reference
   implementation written *inside the test file*, compared against the
   `findInterval()` implementation on 20 random networks with different seeds.
   That is the honest way to check a clever single-pass algorithm, and the loop
   is fine there because it is the reference, not the product.

**Tests** — `tests/testthat/test-event-graph-contract.R`

- Error paths:
  - `expect_error(event_graph(dn, delta = -1), class = "dynet_bad_input")`
  - `expect_error(event_graph(dn, sessions = "separate"), class = "dynet_no_sessions")` on a session-free network.
  - `expect_error(event_graph(empty_dn), class = "dynet_empty_network")`
- Invariant / property tests:
  - **No time travel.** Every `wait` is ≥ 0.
  - **`via` is real.** Every `via` is in `dn$nodes$name` and is an endpoint of both events it joins.
  - **Monotonicity in δ.** The adjacency set for `delta = a` is a subset of that for `delta = b` whenever `a ≤ b`.
  - **Nesting.** `adjacency = "next"` adjacencies are a subset of `adjacency = "all"` adjacencies.
  - **Acyclicity.** With `delta = Inf` the adjacency relation is a DAG — assert no cycle, which catches an off-by-one in the `findInterval()` bound that would make an event its own successor.
  - **Simultaneity.** Two events with identical `start` at a shared vertex are not adjacent.
  - Brute-force agreement across 20 seeds.
  - Reachability equivalence against `paths()`.
- Visual: `plot()` is new, so render `tmp/event-graph.html` showing the DAG on
  two datasets at two δ values, and present it for review.

**Effort — M.** The algorithm is a sorted merge pass and is short. The work is
the tie-breaking rules at instants, the session blocks, a new result class with
four methods, and the brute-force reference in the tests.

**Depends on** — nothing.

**New dependency?** No. `tsna` stays in Suggests, guarded, and is used only in
tests.

---

# 6. Export a temporal network — the missing half of `as_dynet()`

**Why.** Verified: `NAMESPACE` registers `as_dynet` methods for `dynet` and
`networkDynamic` and nothing else — the package imports and never exports.
`cograph::to_igraph(dn)` *does* work, because a `dynet` inherits
`cograph_network`: it returned an `igraph` with 14 vertices and 110 directed
edges for a 240-spell network, i.e. the whole-window aggregate. But nothing in
Dynet's own help, `print()` output or README mentions it, so the user cannot
find a capability the package already has. That is a Rule 0 problem — the fix is
a verb with a name, not a sentence in a vignette.

**Proposed API**

```r
as_networkDynamic(dn, sessions = c("bounded", "collapse", "separate"),
                  attributes = TRUE, ...)

as_network(dn, at = NULL, start = NULL, end = NULL,
           weights = c("sum", "count", "binary", "none"), ...)

as_igraph(dn,  at = NULL, start = NULL, end = NULL,
          weights = c("sum", "count", "binary", "none"), ...)

as_matrix(dn,  at = NULL, start = NULL, end = NULL,
          weights = c("sum", "count", "binary", "none"), ...)
```

```r
dn <- dynet(school_contacts)

as_networkDynamic(dn)
as_igraph(dn, at = 3)
as_matrix(dn, start = 0, end = 5, weights = "count")

# and the reason it matters:
ndtv::render.d3movie(as_networkDynamic(dn))
```

Four `as_*` S3-style verbs rather than one `export(dn, to = )`: `as_*` is the R
idiom, it tab-completes, and each target has genuinely different arguments —
`as_networkDynamic()` has no `at` because it does not flatten, and the other
three have no `sessions` because a flattened network has none.

**Return.**

| verb | returns |
|---|---|
| `as_networkDynamic()` | a `networkDynamic` (and `network`) object carrying `net.obs.period`, vertex names, static attributes, vertex activity, and — once item 4 lands — TEAs |
| `as_network()` | a `network` object, one edge per aggregated pair |
| `as_igraph()` | an `igraph`, one edge per aggregated pair, `V(g)$name` = vertex names |
| `as_matrix()` | a square numeric matrix, `dimnames` = `dn$nodes$name` on both margins |

`as_matrix()` returns a matrix, which is the one deliberate exception to the
tidy-return rule — a matrix *is* the requested object here. Say so explicitly in
`@return` and point at `snapshots()` as the tidy route, so the exception reads
as a decision rather than an oversight.

**Algorithm**

*`as_networkDynamic()` — the true inverse of `as_dynet.networkDynamic()`.*
Build `edge.spells` (`onset`, `terminus`, `tail`, `head`) from `dn$spells` with
endpoints mapped through `match(name, dn$nodes$name)`; build `vertex.spells`
from `dn$vertex_spells`; set `vertex.names` from `dn$nodes$name`; write static
attributes with `network::set.vertex.attribute()`; write the observation table
into `net.obs.period`, taking `time.unit` from `dn$meta$time_unit` and
`time.increment` from `dn$meta$interval` — the exact fields
`as_dynet.networkDynamic()` already reads back. Preserve `onset_censored` /
`terminus_censored` when `dn$meta$raw_censoring` is `"explicit"`. With item 4,
write each `node_spells` attribute with
`networkDynamic::activate.vertex.attribute()`. Guard on
`requireNamespace("networkDynamic")` and `requireNamespace("network")` and raise
the **existing** `dynet_needs_networkDynamic` class from `R/coercion.R` — reuse
it rather than minting a second name for the same condition.

*The three flatteners.* **Flattening is a decision, not a conversion**, and the
verb must make it explicit rather than perform it quietly:

- `at =` selects one bin, reusing `.bin_netobject()` — which already raises
  `dynet_empty_result` for a time nothing is active at, so that error path comes
  free and consistent.
- `start`/`end` select a window via `.clip_plot_range()`'s underlying
  `.range_netobject()`.
- Neither given means the whole observed period, and the verb **messages** what
  it collapsed — e.g. `"240 spells over [0, 21.5] flattened to 110 directed
  edges."` A silent flattening is precisely the error this package exists to
  prevent; a `message()` is suppressible and is the right severity.
- `weights = "sum"` sums spell weights, `"count"` counts spells, `"binary"`
  gives 0/1, `"none"` drops the attribute.
- Construction then **delegates** to `cograph::to_igraph()` / `to_network()` /
  `to_matrix()` on the resulting netobject. That is the honest fix for the
  discoverability problem: expose cograph's existing capability under Dynet's
  own name, with Dynet's time semantics attached and stated.

*Discoverability, since that is the actual complaint.* Name the four verbs in
`?dynet`'s `@seealso`, in the README's interop section, and in one line of
`print.dynet()`'s footer: `# as_igraph(), as_network(), as_networkDynamic() to
export`. A print footer that names **verbs** is not the `$table` anti-pattern —
Rule 0 objects to teaching `$`, and this teaches the opposite.

*Deliberately not proposed.* `as_tsna()` and `as_ndtv()`. Both packages consume
`networkDynamic` objects directly, so `as_networkDynamic()` already reaches all
of `tsna::tPath()`, `ndtv::compute.animation()`, `ndtv::render.d3movie()` and
`ndtv::proximity.timeline()`. Shipping aliases would be three names for one
capability. State this in the docs — it is also the honest answer to "why not
just depend on ndtv": one export verb gives users all of ndtv without Dynet
taking on ten dependencies.

**References**

- Butts, C. T. (2008). network: A package for managing relational data in R.
  *Journal of Statistical Software*, 24(2).
- Butts, C. T., Leslie-Cook, A., Krivitsky, P. N., & Bender-deMoll, S. (2024).
  *networkDynamic*, version 0.11.5.
- Csárdi, G., & Nepusz, T. (2006). The igraph software package for complex
  network research. *InterJournal Complex Systems*, 1695.
- Bender-deMoll, S. (2024). *ndtv*, version 0.13.4.

**Verify against.** networkDynamic and igraph, both installed:

- **Round trip.** `as_dynet(as_networkDynamic(dn))` must reproduce
  `as.data.frame(dn)` exactly up to row order — compare the sorted tables with
  `all.equal()` at the default tolerance.
- **Spell ledger.** `networkDynamic::get.edge.activity(as.spellList = TRUE)` on
  the exported object must reproduce every onset and terminus in
  `as.data.frame(dn)`.
- **Bin agreement.** `igraph::ecount(as_igraph(dn, at = t))` must equal
  `nrow(snapshots(dn, at = t))` for every `t` on the bin grid — an independent
  check that the export and the measurement path see the same network. (For
  reference, `nrow(snapshots(dn, at = 3))` is 12 on `school_contacts`, measured
  this session.)
- **Observation period.** The `net.obs.period` written out must equal
  `as.data.frame(dn, what = "observations")`.

**Tests** — `tests/testthat/test-export-contract.R`

- Error paths:
  - `expect_error(as_igraph(dn, at = 999), class = "dynet_empty_result")` — existing class, via `.bin_netobject()`.
  - `expect_error(as_matrix(dn, start = 5, end = 1), class = "dynet_bad_input")`
  - `expect_error(as_networkDynamic(dn), class = "dynet_needs_networkDynamic")` with the namespace unavailable; otherwise `skip_if_not_installed("networkDynamic")`.
- Invariant / property tests:
  - Round trip identity, as above.
  - `as_matrix(dn, at = t)` is symmetric **iff** `!dn$directed`.
  - Its row sums equal the weighted degree `dyn_centrality()` reports for that
    bin — the export agreeing with the measurement path is the test that catches
    a silent aggregation bug.
  - `dimnames` are `dn$nodes$name` in order on both margins; rebuilding the
    network with the vertex table permuted changes nothing that is looked up by
    name.
  - `weights = "binary"` gives a matrix whose entries are all 0 or 1, and whose
    nonzero pattern matches `weights = "count"`.
  - The flattening `message()` is emitted when neither `at` nor `start`/`end` is
    given, and not emitted otherwise — `expect_message()` / `expect_no_message()`.
- No visual output, so no `./tmp/` render is required for this item.

**Effort — M.** `as_networkDynamic()` is the substantial half (spell ledger,
vertex activity, observation period, censoring, TEAs). The three flatteners are
S each because they delegate to cograph. Ship `as_networkDynamic()` without the
TEA block if item 4 has not landed, and add it when it does.

**Depends on** — item 4, for the TEA half of `as_networkDynamic()` only. The
rest has no dependencies.

**New dependency?** **No.** `network`, `networkDynamic` and `igraph` are already
in Suggests and stay there, guarded at every use site with
`requireNamespace(..., quietly = TRUE)`.

---

## Cross-cutting notes for whoever implements this

**Colour.** Every new view uses `.dyn_palette()`. No distinction is ever carried
by colour alone: `highlight` in items 2 and 3 changes shape *and* linetype *and*
adds a direct label; the event graph's `via` is a printed name, not a hue; the
animation's active/inactive vertices differ by shape and border, not only fill.
The heat ramp convention in `.dyn_heat_ramp()` (white → the palette's blue)
applies to anything continuous.

**Globals.** `animate()`, `plot(type = "prism")` and the filmstrip all touch
devices or `par()`. Every one of them restores with
`on.exit(..., add = TRUE, after = FALSE)`, and every drawing test asserts the
restoration.

**Randomness.** Item 1 is deterministic by construction (`layout_oval()` seed,
explicit `seed` forwarded to `layout_spring()`). Any test that compares layouts
sets a seed and reports results from more than one, since a single-seed layout
comparison is not a finding.

**The `./tmp/` rule.** Items 1, 2, 3, 5 and the `mixing()` plot in item 4 change
visual output. Each one renders an HTML file to `./tmp/`, presents it, and asks
the user whether to review or skip. None of them is reported as "looks correct"
without that step.

**Sequencing suggestion.** Item 1 first — it is the only genuinely hard
algorithm here and items 2 and 3 are drawing code on top of it. Items 4, 5 and 6
can proceed in parallel with it; item 6 is the highest value per hour of the
three, because `as_networkDynamic()` alone gives users all of ndtv and tsna in
one call and closes the Rule 0 discoverability hole.
