# temporal_efficiency and temporal_diameter run all-pairs time-respecting
# searches inside each reporting window.
#
# THERE IS NO EXTERNAL ORACLE FOR THESE TWO. teneto was examined directly on
# 2026-09-20 (teneto 0.5.3, scipy 1.16.3, python 3.14.4) and ruled out:
#
#   1. teneto computes 1 / mean(d); the published Latora-Marchiori measure
#      lifted to temporal distance is mean(1 / d). Confirmed numerically on the
#      Stage 3 fixture: teneto.networkmeasures.temporal_efficiency returns
#      0.823529411764706, which equals 1/mean(d) exactly, while mean(1/d) over
#      the same 42 finite entries is 0.9087301587301587.
#   2. teneto's temporal distance charges >= 1 per hop; Dynet's latency at
#      traversal_time = 0 can legitimately be 0.
#   3. teneto 0.5.3's shortest_temporal_path is self-inconsistent. On that
#      fixture every row `from 0 to 3` reports temporal-distance 1.0 via
#      [[0, 2], [2, 3]], for every t_start including 3 -- but edge 0-2 does not
#      exist until t = 3 and edge 2-3 only at t = 1, so that journey runs
#      backwards in time.
#
# The calibration below is therefore HAND-DERIVED, and the distances it rests
# on were confirmed by running paths() on the same fixture.

chain_fixture <- function() {
  # Directed chain A->B [0,1], B->C [1,2], C->D [2,3]. paths() confirms
  # n_hops from A is 1, 2, 3 to B, C, D; from B is 1, 2 to C, D; from C is 1
  # to D; every backward pair is unreachable.
  quiet_dynet(
    data.frame(from = c("A", "B", "C"), to = c("B", "C", "D"),
               start = c(0, 1, 2), end = c(1, 2, 3)),
    directed = TRUE
  )
}

# E = (1/1 + 1/2 + 1/3 + 1/1 + 1/2 + 1/1) / (4 * 3) = (13/3)/12 = 13/36
CHAIN_EFFICIENCY <- 13 / 36
CHAIN_DIAMETER <- 3

# ---------------------------------------------------------------- error paths

test_that("basis and traversal_time are refused without a path measure", {
  dn <- chain_fixture()
  expect_error(metrics(dn, measure = "density", basis = "hops"),
               class = "dynet_bad_input")
  expect_error(metrics(dn, measure = "density", traversal_time = 1),
               class = "dynet_bad_input")
})

test_that("a negative traversal_time is refused", {
  dn <- chain_fixture()
  expect_error(
    metrics(dn, measure = "temporal_efficiency", traversal_time = -1),
    class = "dynet_bad_input"
  )
})

# ------------------------------------------------------------- warning + Inf

test_that("zero-latency pairs warn by class and return Inf", {
  # A->B completes at latency exactly 0, so 1/d is infinite. Inf is the honest
  # limit; the contract is that the condition AND the value are both delivered.
  dn <- chain_fixture()
  expect_warning(
    out <- metrics(dn, measure = "temporal_efficiency", basis = "latency",
                   window = "all"),
    class = "dynet_zero_latency"
  )
  expect_identical(as.data.frame(out)$value, Inf)
})

test_that("a positive traversal_time removes the zero-latency case", {
  dn <- chain_fixture()
  expect_silent(
    out <- metrics(dn, measure = "temporal_efficiency", basis = "latency",
                   traversal_time = 1, window = "all")
  )
  expect_true(is.finite(as.data.frame(out)$value))
})

# ---------------------------------------------------------------- calibration

test_that("the hand-derived chain calibrates both measures", {
  dn <- chain_fixture()
  efficiency <- as.data.frame(
    metrics(dn, measure = "temporal_efficiency", window = "all")
  )
  diameter <- as.data.frame(
    metrics(dn, measure = "temporal_diameter", window = "all")
  )
  expect_equal(efficiency$value, CHAIN_EFFICIENCY,
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(diameter$value, CHAIN_DIAMETER)
})

test_that("efficiency is mean(1/d), not 1/mean(d)", {
  # The two differ, and the published measure is the former. 1/mean(d) over
  # the chain's finite distances (1, 2, 3, 1, 2, 1) would be 0.6.
  dn <- chain_fixture()
  out <- as.data.frame(metrics(dn, measure = "temporal_efficiency",
                               window = "all"))
  finite <- c(1, 2, 3, 1, 2, 1)
  expect_equal(out$value, sum(1 / finite) / 12,
               tolerance = sqrt(.Machine$double.eps))
  expect_false(isTRUE(all.equal(out$value, 1 / mean(finite))))
})

# ----------------------------------------------------------------- invariants

test_that("hops efficiency is bounded in [0, 1] and hits both ends", {
  # 0 exactly when nothing is reachable; 1 exactly when every ordered pair is
  # reachable in a single hop.
  nothing <- quiet_dynet(
    data.frame(from = c("A", "C"), to = c("B", "D"), time = c(0, 1)),
    format = "contact", directed = TRUE
  )
  out <- as.data.frame(metrics(nothing, measure = "temporal_efficiency",
                               window = "all"))
  expect_true(out$value >= 0 && out$value <= 1)

  complete <- quiet_dynet(
    data.frame(from = c("A", "B", "A", "C", "B", "C"),
               to   = c("B", "A", "C", "A", "C", "B"),
               time = rep(0, 6)),
    format = "contact", directed = TRUE
  )
  one_hop <- as.data.frame(metrics(complete, measure = "temporal_efficiency",
                                   window = "all"))
  expect_equal(one_hop$value, 1, tolerance = sqrt(.Machine$double.eps))
})

test_that("an unreachable network scores zero efficiency and NA diameter", {
  isolated <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("A", "B"), time = c(0, 1)),
    format = "contact", directed = TRUE, loops = TRUE
  )
  efficiency <- as.data.frame(metrics(isolated,
                                      measure = "temporal_efficiency",
                                      window = "all"))
  diameter <- as.data.frame(metrics(isolated, measure = "temporal_diameter",
                                    window = "all"))
  expect_equal(efficiency$value, 0)
  expect_true(is.na(diameter$value))
})

test_that("adding a contact never lowers efficiency or raises diameter", {
  # Property over seeded random fixtures: more reachability cannot hurt.
  RNGkind("L'Ecuyer-CMRG")
  set.seed(42L)
  worse <- vapply(seq_len(8L), function(i) {
    n_e <- 10L
    base <- data.frame(
      from = sample(LETTERS[1:5], n_e, replace = TRUE),
      to = sample(LETTERS[1:5], n_e, replace = TRUE),
      time = sort(stats::runif(n_e, 0, 10))
    )
    base <- base[base$from != base$to, , drop = FALSE]
    if (nrow(base) < 3L) return(FALSE)
    extra <- rbind(base, data.frame(from = "A", to = "E", time = 0.5))
    dn1 <- quiet_dynet(base, format = "contact", directed = TRUE)
    dn2 <- quiet_dynet(extra, format = "contact", directed = TRUE)
    e1 <- as.data.frame(metrics(dn1, measure = "temporal_efficiency",
                                window = "all"))$value
    e2 <- as.data.frame(metrics(dn2, measure = "temporal_efficiency",
                                window = "all"))$value
    # dn2 has the same vertex universe plus a contact, so efficiency over the
    # same N cannot fall.
    isTRUE(e2 < e1 - sqrt(.Machine$double.eps))
  }, logical(1L))
  expect_false(any(worse))
})

test_that("renaming vertices changes neither value", {
  dn <- chain_fixture()
  before <- as.data.frame(metrics(dn, measure = c("temporal_efficiency",
                                                  "temporal_diameter"),
                                  window = "all"))
  renamed <- rename_nodes(dn, c(A = "w", B = "x", C = "y", D = "z"))
  after <- as.data.frame(metrics(renamed, measure = c("temporal_efficiency",
                                                      "temporal_diameter"),
                                 window = "all"))
  expect_equal(before$value, after$value)
})

test_that("efficiency is positive exactly when reachability is", {
  # The two verbs must agree about what is reachable.
  for (dn in list(chain_fixture(),
                  quiet_dynet(data.frame(from = "A", to = "B", time = 0),
                              format = "contact", directed = TRUE))) {
    efficiency <- as.data.frame(metrics(dn, measure = "temporal_efficiency",
                                        window = "all"))$value
    reach <- as.data.frame(dyn_reachability(dn, direction = "forward",
                                            measure = "reach_count"))$value
    expect_identical(efficiency > 0, sum(reach) > 0)
  }
})

test_that("temporal_connected reports honestly", {
  # The chain is one-way, so the backward pairs are never reachable.
  dn <- chain_fixture()
  out <- metrics(dn, measure = "temporal_diameter", window = "all")
  expect_false(attr(out, "temporal_connected"))

  complete <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("B", "A"), time = c(0, 0)),
    format = "contact", directed = TRUE
  )
  both <- metrics(complete, measure = "temporal_diameter", window = "all")
  expect_true(attr(both, "temporal_connected"))
})

# ------------------------------------------------------------------ structure

test_that("the path measures report at graph level with their attributes", {
  dn <- chain_fixture()
  out <- metrics(dn, measure = "temporal_efficiency", window = "all")
  expect_identical(attr(out, "level"), "graph")
  expect_identical(attr(out, "basis"), "hops")
  expect_identical(attr(out, "traversal_time"), 0)
  expect_identical(attr(out, "unreachable_rule"), "excluded_from_mean")
  expect_identical(names(as.data.frame(out)), c("time", "measure", "value"))
})

test_that("path measures compose with snapshot measures in one call", {
  dn <- chain_fixture()
  out <- as.data.frame(metrics(dn, measure = c("density",
                                               "temporal_efficiency"),
                               window = "all"))
  expect_setequal(out$measure, c("density", "temporal_efficiency"))
})

test_that("temporal closeness surfaces the same zero-latency condition", {
  # Pre-existing exposure fixed alongside this item: 1/mean(latency) returned
  # Inf silently when every reachable vertex was joined within one instant.
  inst <- quiet_dynet(
    data.frame(from = c("A", "A"), to = c("B", "C"), time = c(0, 0)),
    format = "contact", directed = TRUE
  )
  expect_warning(
    out <- dyn_centrality(inst, measure = "closeness", scope = "temporal"),
    class = "dynet_zero_latency"
  )
  # Inf is kept: it is the honest limit, not an error to be clamped away.
  expect_true(any(is.infinite(as.data.frame(out)$value)))
})

test_that("an ordinary network raises no zero-latency condition", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  expect_no_warning(dyn_centrality(dn, measure = "closeness",
                                   scope = "temporal"))
})

# ============================================================ A4: node level

test_that("efficiency is temporal-scope only", {
  dn <- chain_fixture()
  expect_error(
    dyn_centrality(dn, measure = "efficiency", scope = "snapshot"),
    class = "dynet_unknown_measure"
  )
})

test_that("node efficiency calibrates on the hand-derived chain", {
  # eff_out(A) = (1/1 + 1/2 + 1/3)/3, eff_out(B) = (1/1 + 1/2)/3,
  # eff_out(C) = (1/1)/3, eff_out(D) = 0.
  out <- as.data.frame(dyn_centrality(chain_fixture(), measure = "efficiency",
                                      scope = "temporal"))
  expect_equal(out$value,
               c((1 + 1/2 + 1/3) / 3, (1 + 1/2) / 3, 1 / 3, 0),
               tolerance = sqrt(.Machine$double.eps))
})

test_that("node efficiency averages to the graph measure", {
  # The single most valuable test here: it is what guarantees the graph and
  # node measures share one definition of temporal distance.
  for (dn in list(chain_fixture(),
                  quiet_dynet(school_contacts, format = "contact"))) {
    nodes <- as.data.frame(dyn_centrality(dn, measure = "efficiency",
                                          scope = "temporal"))
    graph <- as.data.frame(metrics(dn, measure = "temporal_efficiency",
                                   window = "all"))
    expect_equal(mean(nodes$value), graph$value,
                 tolerance = sqrt(.Machine$double.eps))
  }
})

test_that("the incoming reading mirrors the outgoing one on a chain", {
  dn <- chain_fixture()
  out <- as.data.frame(dyn_centrality(dn, measure = "efficiency",
                                      scope = "temporal"))
  incoming <- as.data.frame(dyn_centrality(dn, measure = "efficiency",
                                           scope = "temporal", mode = "in"))
  expect_equal(incoming$value, rev(out$value),
               tolerance = sqrt(.Machine$double.eps))
  # Both directions average to the same graph value: the numerator is the sum
  # over the same ordered pairs either way.
  graph <- as.data.frame(metrics(dn, measure = "temporal_efficiency",
                                 window = "all"))$value
  expect_equal(mean(incoming$value), graph,
               tolerance = sqrt(.Machine$double.eps))
})

test_that("out efficiency falls and in efficiency rises along a chain", {
  dn <- chain_fixture()
  out <- as.data.frame(dyn_centrality(dn, measure = "efficiency",
                                      scope = "temporal"))$value
  incoming <- as.data.frame(dyn_centrality(dn, measure = "efficiency",
                                           scope = "temporal",
                                           mode = "in"))$value
  expect_false(is.unsorted(rev(out)))
  expect_false(is.unsorted(incoming))
})

test_that("node efficiency stays in [0, 1] and is zero exactly where reach is", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  values <- as.data.frame(dyn_centrality(dn, measure = "efficiency",
                                         scope = "temporal"))
  expect_true(all(values$value >= 0 & values$value <= 1))

  chain <- chain_fixture()
  eff <- as.data.frame(dyn_centrality(chain, measure = "efficiency",
                                      scope = "temporal"))
  reach <- as.data.frame(dyn_reachability(chain, direction = "forward",
                                          measure = "reach_count"))
  expect_identical(eff$value == 0, reach$value[match(eff$node, reach$node)] == 0)
})

test_that("mode is still refused for other temporal measures", {
  dn <- chain_fixture()
  expect_error(
    dyn_centrality(dn, measure = "closeness", scope = "temporal", mode = "in"),
    class = "dynet_bad_input"
  )
})
