# gaps() exposes the inter-event distribution that burstiness() reduces to a
# mean. The contract that matters is that the two never disagree: they share
# `.burst_primitives()` precisely so a gap here is a gap there.

teneto_fixture <- function() {
  # The fixture the Stage 3 spec generated teneto reference values on, with
  # node 0..3 written as A..D. Contacts:
  #   (0,1,t=0) (1,2,t=0) (0,1,t=1) (2,3,t=1) (0,1,t=2) (1,2,t=2) (0,2,t=3)
  # teneto.networkmeasures.intercontacttimes gives
  #   ict[0,1] = [1 1]   ict[1,2] = [2]
  quiet_dynet(
    data.frame(
      from = c("A", "B", "A", "C", "A", "B", "A"),
      to   = c("B", "C", "B", "D", "B", "C", "C"),
      time = c(0, 0, 1, 1, 2, 2, 3)
    ),
    format = "contact", directed = FALSE
  )
}

two_session_fixture <- function() {
  quiet_dynet(
    data.frame(
      from    = c("A", "A", "A", "B", "B", "A", "A", "B"),
      to      = c("B", "B", "B", "C", "C", "B", "B", "C"),
      time    = c(0, 1, 2, 0, 2, 10, 11, 10),
      session = c(rep("s1", 5), rep("s2", 3))
    ),
    format = "contact"
  )
}

# ---------------------------------------------------------------- error paths

test_that("gaps refuses a unit it does not own", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  # match.arg() raises a plain error, not a classed one. Assert what is
  # actually raised rather than pretending the condition carries a class.
  expect_error(gaps(dn, unit = "session"), "'arg' should be one of")
})

test_that("gaps refuses separate without sessions", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  expect_error(gaps(dn, sessions = "separate"), class = "dynet_no_sessions")
})

test_that("gaps refuses a network it was not given", {
  expect_error(gaps(data.frame(a = 1)), class = "dynet_bad_input")
})

# ----------------------------------------------------------------- invariants

test_that("the row count is the event count less one sequence per vertex", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  events <- as.data.frame(burstiness(dn, measure = "events",
                                     sessions = "collapse"))
  expected <- sum(events$value) - sum(events$value >= 1)
  expect_identical(nrow(gaps(dn, sessions = "collapse")), as.integer(expected))
})

test_that("the mean gap per vertex is burstiness's own mean_gap", {
  # The test that catches the two implementations drifting apart, and the
  # reason gaps() and burstiness() share `.burst_primitives()`.
  dn <- quiet_dynet(school_contacts, format = "contact")
  mine <- as.data.frame(gaps(dn))
  theirs <- as.data.frame(burstiness(dn, measure = "mean_gap"))

  per_node <- vapply(split(mine$value, mine$node), mean, numeric(1L))
  reference <- stats::setNames(theirs$value, theirs$node)[names(per_node)]
  expect_equal(unname(per_node), unname(reference),
               tolerance = sqrt(.Machine$double.eps))
})

test_that("gaps are non-negative and indexed in time order", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  out <- as.data.frame(gaps(dn))
  expect_true(all(out$value >= 0))
  well_formed <- vapply(split(out, out$node), function(block) {
    identical(block$index, seq_len(nrow(block))) && !is.unsorted(block$time)
  }, logical(1L))
  expect_true(all(well_formed))
})

test_that("a zero gap is kept, not dropped as a degenerate one", {
  # Two distinct spells incident to A at one instant. Dropping the zero would
  # silently raise the mean above burstiness's.
  dn <- quiet_dynet(
    data.frame(from = c("A", "A"), to = c("B", "C"), time = c(5, 5)),
    format = "contact"
  )
  out <- as.data.frame(gaps(dn))
  expect_identical(nrow(out[out$node == "A", , drop = FALSE]), 1L)
  expect_identical(out$value[out$node == "A"], 0)
})

test_that("session walls remove exactly the cross-wall gaps", {
  dn <- two_session_fixture()
  bounded <- gaps(dn, sessions = "bounded")
  collapsed <- gaps(dn, sessions = "collapse")

  # One gap per vertex is lost: the one that would have spanned the wall.
  active_in_both <- vapply(c("A", "B", "C"), function(v) {
    blocks <- as.data.frame(gaps(dn, sessions = "separate"))
    length(unique(blocks$session[blocks$node == v])) > 1L ||
      v %in% blocks$node
  }, logical(1L))
  expect_lt(nrow(bounded), nrow(collapsed))
  expect_identical(nrow(collapsed) - nrow(bounded), sum(active_in_both))
})

test_that("separate reports each session on its own rows and restarts index", {
  dn <- two_session_fixture()
  out <- as.data.frame(gaps(dn, sessions = "separate"))
  expect_true("session" %in% names(out))
  expect_setequal(unique(out$session), c("s1", "s2"))
  restarts <- vapply(split(out, list(out$session, out$node), drop = TRUE),
                     function(block) identical(block$index,
                                               seq_len(nrow(block))),
                     logical(1L))
  expect_true(all(restarts))
})

# ---------------------------------------------------------------- equivalence

test_that("pair gaps reproduce teneto's intercontacttimes", {
  out <- as.data.frame(gaps(teneto_fixture(), unit = "pair"))
  ab <- out$value[out$from == "A" & out$to == "B"]
  bc <- out$value[out$from == "B" & out$to == "C"]
  expect_equal(ab, c(1, 1), tolerance = 1e-12)
  expect_equal(bc, 2, tolerance = 1e-12)
})

test_that("an undirected dyad is reported once, not in both orientations", {
  # teneto returns the same array for (i, j) and (j, i); Dynet must not.
  out <- as.data.frame(gaps(teneto_fixture(), unit = "pair"))
  expect_identical(nrow(out), 3L)
  expect_false(any(out$from == "B" & out$to == "A"))
})

test_that("a pair with one event contributes no row", {
  out <- as.data.frame(gaps(teneto_fixture(), unit = "pair"))
  expect_false("D" %in% c(out$from, out$to))
})

test_that("pair unit excludes loops and node unit counts them once", {
  # dynet() drops self-loops unless asked to keep them, so the loop policy is
  # only reachable with loops = TRUE. A has events at 0, 2 and 5; the pair
  # A-B has a single event and therefore no gap at all.
  dn <- quiet_dynet(
    data.frame(from = c("A", "A", "A"), to = c("A", "A", "B"),
               time = c(0, 2, 5)),
    format = "contact", directed = TRUE, loops = TRUE
  )
  expect_identical(nrow(as.data.frame(gaps(dn, unit = "pair"))), 0L)
  node_rows <- as.data.frame(gaps(dn))
  expect_identical(node_rows$value[node_rows$node == "A"], c(2, 3))
})

# ------------------------------------------------------------------ structure

test_that("the result is a tidy dynet_metric at the right level", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  by_node <- gaps(dn)
  by_pair <- gaps(dn, unit = "pair")
  expect_s3_class(by_node, "dynet_metric")
  expect_identical(attr(by_node, "level"), "node")
  expect_identical(attr(by_pair, "level"), "edge")
  expect_identical(names(as.data.frame(by_node)),
                   c("time", "node", "index", "measure", "value"))
  expect_identical(names(as.data.frame(by_pair)),
                   c("time", "from", "to", "index", "measure", "value"))
  expect_identical(unique(by_node$measure), "gap")
})
