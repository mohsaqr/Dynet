# Stage 0 — defects in shipped code

Found while specifying the other stages. Each was reproduced in this session on
Dynet 0.3.53; the reproductions are pasted, not recalled. These outrank every
new feature, because they are wrong output from a released package.

---

## D1 — WITHDRAWN. Not a defect.

**This item was wrong and is retained only so nobody re-files it.**

I reported that `dyn_centrality(measure = "closeness", scope = "temporal")`
returning `Inf` on a zero-latency network was silently wrong output. It is not.
The behaviour is deliberate, documented on the public surface, and pinned by an
existing test.

`man/dyn_centrality.Rd:243`:

> "...endpoints has value zero. If all reachable endpoints have zero latency,
> the value is `Inf`; zero-latency endpoints remain in the numerator when
> mixed..."

`tests/testthat/test-temporal-closeness-contract.R:28`:

    expect_identical(unname(value[c("S", "A", "B")]), c(Inf, Inf, 0))

and the internal roxygen on `.temporal_closeness_values()` states it a third
time. `Inf` is the honest limit — instantaneous reach — and clamping it would
be the silent failure, not the current behaviour.

**What went wrong in the analysis.** I read the function body, saw an unguarded
`1 / mean(latency)`, reproduced an `Inf`, and called it a bug without checking
the public documentation or the test suite first. The reproduction was real; the
diagnosis was not. Verify against the docs and the tests before filing, not
after.

**What is still true and still worth doing.** Stage 3 item A1 (temporal
efficiency) divides by the same latency and will need a stated convention for
the zero-latency case. It should adopt this one — return `Inf`, document it —
rather than inventing a second policy. That is a note on A1, not a defect here.

---

## D2 — `projection()` records `identity_weight = 1` while its arcs carry `omega`

**Severity: medium.** Metadata contradicts the data it describes.

`R/projection.R:293` hard-codes

    identity_weight = 1,

in the result metadata, while the identity arcs themselves are weighted by the
`omega` argument. `omega` is never stored in `meta` at all, so a saved
projection cannot report the interlayer coupling it was built with.

**Fix.** Record `omega` in `meta` and set `identity_weight` from it. Stage 4
builds directly on `projection(omega =)`, so fix this before starting there.

---

## D3 — `pshifts()` breaks the package's own column contract

**Severity: low, but it blocks Stage 1.** Not wrong output — an inconsistency.

`pshifts()` returns `shift`, `family`, `count`. Every other measurement verb —
`metrics`, `dyn_centrality`, `events`, `burstiness`, `durations`,
`dyn_reachability`, `mixing`, `similarity` — returns a `measure`/`value` pair.

**Reproduction:** `head(as.data.frame(pshifts(dynet(school_contacts))), 3)`
gives columns `shift`, `family`, `count`.

**Consequence.** Stage 1's `significance()` keys on `measure`/`value` and can
wrap every measurement verb in the package except this one — so participation
shifts, the construct with the clearest permutation-test literature, is the one
that cannot be tested.

**Fix.** Rename `count` to `value` and add a constant `measure = "count"`.
This is a breaking change to a public column name: it needs a `revdepcheck`
pass and a `CHANGES.md` entry.

---

## Not a defect, but verify before trusting any equivalence test

Building the standard 4-slice teneto fixture in Dynet and measuring it on the
**default grid gives three bins, not four** — confirmed this session:

    d  <- data.frame(from = c("A","B","A","C","A","B","A"),
                     to   = c("B","C","B","D","B","C","C"),
                     time = c(0,0,1,1,2,2,3))
    dn <- dynet(d, format = "contact", directed = FALSE)

    metrics(dn, measure = "edges")                          # 2, 2, 3   (3 bins)
    metrics(dn, measure = "edges", start = 0, end = 3, window = 0)
                                                            # 2, 2, 2, 1 (4 bins)

The default last bin is closed and absorbs the `t = 3` contact. **Every
cross-implementation equivalence test must pass `start`, `end` and `window = 0`
explicitly**, or it compares a 3-bin Dynet result against a 4-slice reference
and the mismatch gets blamed on the formula.
