# ===========================================================================
# One `measure` contract for metrics(), events(), durations() and
# burstiness() (audit 2026-11-01). Before it, an unknown name raised
# `dynet_unknown_measure` without the `dynet_bad_input` parent, an empty
# `measure` reached data.frame() and failed with an unclassed error, and a
# repeated name duplicated every row.
# ===========================================================================

measure_verbs <- list(
  metrics = function(dn, measure) metrics(dn, measure = measure),
  events = function(dn, measure) events(dn, measure = measure),
  durations = function(dn, measure) durations(dn, measure = measure),
  burstiness = function(dn, measure) burstiness(dn, measure = measure)
)
valid_measure <- c(metrics = "edges", events = "formation",
                   durations = "events", burstiness = "events")

test_that("an unknown measure carries both condition classes", {
  dn <- quiet_dynet(chain_edges())
  for (verb in names(measure_verbs)) {
    expect_error(measure_verbs[[verb]](dn, "no_such_measure"),
                 class = "dynet_unknown_measure", info = verb)
    expect_error(measure_verbs[[verb]](dn, "no_such_measure"),
                 class = "dynet_bad_input", info = verb)
  }
})

test_that("an empty, missing or non-character measure is dynet_bad_input", {
  dn <- quiet_dynet(chain_edges())
  for (verb in names(measure_verbs)) {
    expect_error(measure_verbs[[verb]](dn, character()),
                 class = "dynet_bad_input", info = verb)
    expect_error(measure_verbs[[verb]](dn, NA_character_),
                 class = "dynet_bad_input", info = verb)
    expect_error(measure_verbs[[verb]](dn, 1),
                 class = "dynet_bad_input", info = verb)
  }
})

test_that("a repeated measure is measured once", {
  dn <- quiet_dynet(random_edges(seed = 2L))
  for (verb in names(measure_verbs)) {
    once <- as.data.frame(measure_verbs[[verb]](dn, valid_measure[[verb]]))
    twice <- as.data.frame(
      measure_verbs[[verb]](dn, rep(valid_measure[[verb]], 2L))
    )
    expect_identical(twice, once, info = verb)
  }
})

test_that("every duration unit honours plot = TRUE and validates it", {
  # node_ties, vertex_activity and vertex_spell returned before reaching the
  # plot step, so plot = TRUE drew nothing and plot = NA was accepted.
  dn <- quiet_dynet(chain_edges())
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (unit in c("pair", "spell", "vertex_activity", "vertex_spell",
                 "node_ties")) {
    plain <- durations(dn, unit = unit)
    drawn <- withVisible(durations(dn, unit = unit, plot = TRUE))
    expect_false(drawn$visible, info = unit)
    expect_identical(as.data.frame(drawn$value), as.data.frame(plain),
                     info = unit)
    expect_error(durations(dn, unit = unit, plot = NA),
                 class = "dynet_bad_input", info = unit)
  }
})
