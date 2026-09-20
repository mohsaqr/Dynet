# persistence() is topological overlap (Tang et al. 2010) and the temporal
# correlation coefficient built from it. The three scopes are one computation
# averaged at three levels, so the invariant that matters most is that they
# cannot disagree with each other.

teneto_fixture <- function() {
  # Undirected, A B C D = teneto nodes 0..3. Contacts:
  #   (0,1,t=0) (1,2,t=0) (0,1,t=1) (2,3,t=1) (0,1,t=2) (1,2,t=2) (0,2,t=3)
  # teneto.networkmeasures.topological_overlap gives
  #   pertime  A = 1, 1, 0        B = 0.70710678, 0.70710678, 0
  #            C = 0, 0, 0        D = 0, 0, 0
  #   node     0.66666667 0.47140452 0 0
  #   overtime 0.2845177968644246
  quiet_dynet(
    data.frame(
      from = c("A", "B", "A", "C", "A", "B", "A"),
      to   = c("B", "C", "B", "D", "B", "C", "C"),
      time = c(0, 0, 1, 1, 2, 2, 3)
    ),
    format = "contact", directed = FALSE
  )
}

# The default grid closes its last bin and absorbs the t = 3 contact, giving
# three bins rather than teneto's four. Every equivalence test states the grid
# explicitly, or it would compare a 3-bin result against a 4-slice reference
# and the mismatch would look like a broken formula.
SPEC_GRID <- list(start = 0, end = 3, window = 0)

frozen_network <- function(n) {
  # A ring in which every edge is present in every bin: nothing can change, so
  # every vertex must score exactly 1 at every transition.
  ring <- data.frame(
    from = rep(LETTERS[seq_len(n)], times = 3L),
    to = rep(LETTERS[c(seq_len(n)[-1], 1L)], times = 3L),
    time = rep(c(0, 1, 2), each = n)
  )
  quiet_dynet(ring, format = "contact", directed = FALSE)
}

# ---------------------------------------------------------------- error paths

test_that("a single bin opens no transition", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 1),
                    format = "contact")
  expect_error(persistence(dn), class = "dynet_empty_result")
})

test_that("persistence refuses separate without sessions", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  expect_error(persistence(dn, sessions = "separate"),
               class = "dynet_no_sessions")
})

test_that("persistence refuses a network it was not given", {
  expect_error(persistence(data.frame(a = 1)), class = "dynet_bad_input")
})

# ----------------------------------------------------------------- invariants

test_that("every scope stays inside [0, 1]", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  for (scope in c("pertime", "node", "overall")) {
    out <- as.data.frame(persistence(dn, scope = scope))
    expect_true(all(out$value >= 0 & out$value <= 1), info = scope)
  }
})

test_that("the three scopes are one computation averaged twice", {
  # If these ever disagree, two of the scopes are computing something else.
  dn <- quiet_dynet(school_contacts, format = "contact")
  pertime <- as.data.frame(persistence(dn, scope = "pertime"))
  per_node <- as.data.frame(persistence(dn, scope = "node"))
  overall <- as.data.frame(persistence(dn, scope = "overall"))

  from_pertime <- vapply(split(pertime$value, pertime$node), mean, numeric(1L))
  expect_equal(per_node$value, unname(from_pertime[per_node$node]),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(overall$value, mean(per_node$value),
               tolerance = sqrt(.Machine$double.eps))
})

test_that("a frozen network scores exactly one everywhere", {
  # Property over sizes, not a single fixture: every vertex of a ring present
  # in every bin keeps every neighbour, so overlap is 1 and the temporal
  # correlation coefficient is 1.
  for (n in 3:8) {
    dn <- frozen_network(n)
    pertime <- as.data.frame(persistence(dn, scope = "pertime"))
    expect_equal(pertime$value, rep(1, nrow(pertime)),
                 tolerance = sqrt(.Machine$double.eps),
                 info = paste("n =", n))
    overall <- as.data.frame(persistence(dn, scope = "overall"))
    expect_equal(overall$value, 1, tolerance = sqrt(.Machine$double.eps),
                 info = paste("n =", n))
  }
})

test_that("a vertex that swaps every partner scores zero", {
  # Degrees are preserved, so this is the case that separates topological
  # overlap from any edge-set similarity measure.
  dn <- quiet_dynet(
    data.frame(from = c("A", "C", "A", "C"), to = c("B", "D", "D", "B"),
               time = c(0, 0, 1, 1)),
    format = "contact", directed = FALSE
  )
  out <- as.data.frame(persistence(dn, start = 0, end = 1, window = 0))
  expect_equal(out$value, rep(0, nrow(out)))
})

test_that("values follow vertex names through a rename", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  before <- as.data.frame(persistence(dn, scope = "node"))
  renamed <- rename_nodes(dn, stats::setNames(
    paste0("z_", before$node), before$node
  ))
  after <- as.data.frame(persistence(renamed, scope = "node"))
  expect_equal(after$value[match(paste0("z_", before$node), after$node)],
               before$value, tolerance = sqrt(.Machine$double.eps))
})

test_that("an isolated vertex scores zero rather than a missing value", {
  dn <- teneto_fixture()
  out <- as.data.frame(persistence(dn, scope = "pertime", start = 0, end = 3,
                                   window = 0))
  expect_false(anyNA(out$value))
  # D is isolated at t = 0 and tied at t = 1: the ratio is genuinely 0/0.
  expect_identical(out$value[out$node == "D" & out$time == 0], 0)
})

# ---------------------------------------------------------------- equivalence

test_that("pertime overlap reproduces teneto's topological_overlap", {
  out <- as.data.frame(persistence(teneto_fixture(), scope = "pertime",
                                   start = 0, end = 3, window = 0))
  value_of <- function(node, time) out$value[out$node == node & out$time == time]
  expect_equal(c(value_of("A", 0), value_of("A", 1), value_of("A", 2)),
               c(1, 1, 0), tolerance = 1e-12)
  expect_equal(c(value_of("B", 0), value_of("B", 1), value_of("B", 2)),
               c(0.70710678118654746, 0.70710678118654746, 0),
               tolerance = 1e-12)
  expect_equal(value_of("C", 0), 0, tolerance = 1e-12)
})

test_that("node and overall scopes reproduce teneto's calc='node' and 'overtime'", {
  dn <- teneto_fixture()
  per_node <- as.data.frame(persistence(dn, scope = "node", start = 0, end = 3,
                                        window = 0))
  expect_equal(per_node$value,
               c(0.66666666666666663, 0.47140452079103173, 0, 0),
               tolerance = 1e-12)
  overall <- as.data.frame(persistence(dn, scope = "overall", start = 0,
                                       end = 3, window = 0))
  expect_equal(overall$value, 0.2845177968644246, tolerance = 1e-12)
})

test_that("the final bin opens no transition and contributes no rows", {
  out <- as.data.frame(persistence(teneto_fixture(), scope = "pertime",
                                   start = 0, end = 3, window = 0))
  # Four bins, three transitions, four vertices.
  expect_identical(nrow(out), 12L)
  expect_setequal(unique(out$time), c(0, 1, 2))
  expect_false(3 %in% out$time)
})

# ------------------------------------------------------------------ structure

test_that("each scope reports at the right level with the right measure", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  pertime <- persistence(dn, scope = "pertime")
  per_node <- persistence(dn, scope = "node")
  overall <- persistence(dn, scope = "overall")

  expect_identical(attr(pertime, "level"), "node")
  expect_identical(attr(per_node, "level"), "node")
  expect_identical(attr(overall, "level"), "graph")
  expect_identical(unique(pertime$measure), "topological_overlap")
  expect_identical(unique(per_node$measure), "average_topological_overlap")
  expect_identical(unique(overall$measure), "temporal_correlation")
  expect_identical(names(as.data.frame(pertime)),
                   c("time", "node", "measure", "value"))
  expect_identical(names(as.data.frame(overall)), c("measure", "value"))
})

test_that("a directed network is read as undirected for this measure", {
  # The published definition is for undirected neighbourhoods, so A->B and
  # B->A must give the same overlap.
  one <- quiet_dynet(data.frame(from = c("A", "A"), to = c("B", "B"),
                                time = c(0, 1)),
                     format = "contact", directed = TRUE)
  other <- quiet_dynet(data.frame(from = c("B", "B"), to = c("A", "A"),
                                  time = c(0, 1)),
                       format = "contact", directed = TRUE)
  expect_equal(as.data.frame(persistence(one, start = 0, end = 1, window = 0))$value,
               as.data.frame(persistence(other, start = 0, end = 1, window = 0))$value)
})
