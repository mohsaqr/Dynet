contacts <- function(from, to, time, end = max(time) + 1) {
  nm <- sort(unique(c(from, to)))
  dynet(data.frame(from = from, to = to, time = time), format = "contact",
        nodes = data.frame(name = nm),
        observation_start = 0, observation_end = end)
}
katz <- function(dn, ...) {
  as.data.frame(dyn_centrality(dn, measure = "katz", scope = "temporal",
                               ...))$value
}

test_that("katz rejects parameters outside their range and wrong scope", {
  dn <- contacts("A", "B", 0)
  expect_error(katz(dn, beta = 0), class = "dynet_bad_input")
  expect_error(katz(dn, beta = 1.5), class = "dynet_bad_input")
  expect_error(katz(dn, decay = -1), class = "dynet_bad_input")
  expect_error(
    dyn_centrality(dn, measure = "katz", scope = "snapshot"),
    class = "dynet_unknown_measure")
})

test_that("a single contact gives exactly beta to its receiver", {
  expect_equal(katz(contacts("A", "B", 0), beta = 0.3), c(0, 0.3))
})

test_that("a two-hop chain gives beta and beta plus beta squared", {
  # A->B at 0 then B->C at 1: C is reached by the length-one contact and by
  # the length-two walk through B.
  expect_equal(katz(contacts(c("A", "B"), c("B", "C"), c(0, 1)), beta = 0.3),
               c(0, 0.3, 0.3 + 0.09))
})

test_that("on a temporal DAG katz equals the closed matrix form", {
  # Times increase strictly along every arc, so temporal walks coincide with
  # static walks and Katz has an exact matrix expression to check against.
  nm <- c("a", "b", "c", "d", "e")
  df <- data.frame(from = c("a", "a", "b", "b", "c", "d"),
                   to = c("b", "c", "c", "d", "e", "e"),
                   time = c(1, 2, 3, 4, 5, 6))
  dn <- dynet(df, format = "contact", nodes = data.frame(name = nm),
              observation_start = 0, observation_end = 7)
  beta <- 0.25
  A <- matrix(0, 5L, 5L, dimnames = list(nm, nm))
  for (i in seq_len(nrow(df))) A[df$from[[i]], df$to[[i]]] <- 1
  want <- numeric(5L)
  power <- diag(5L)
  for (k in seq_len(5L)) {
    power <- power %*% A
    want <- want + beta^k * colSums(power)
  }
  expect_equal(katz(dn, beta = beta), unname(want), tolerance = 1e-12)
})

test_that("simultaneous contacts are batched, so row order cannot matter", {
  # The strict rule: every contact sharing a timestamp reads the pre-batch
  # scores. Without it the answer would depend on the arbitrary order of rows
  # inside one instant.
  base <- data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"),
                     time = c(0, 0, 0))
  nm <- c("A", "B", "C")
  mk <- function(df) dynet(df, format = "contact",
                           nodes = data.frame(name = nm),
                           observation_start = 0, observation_end = 1)
  first <- katz(mk(base), beta = 0.4)
  for (perm in list(c(2L, 3L, 1L), c(3L, 1L, 2L), c(3L, 2L, 1L))) {
    expect_equal(katz(mk(base[perm, , drop = FALSE]), beta = 0.4), first)
  }
  # And a batch of three simultaneous contacts gives each receiver exactly
  # beta, because no walk can compose inside one instant.
  expect_equal(first, rep(0.4, 3L))
})

test_that("scores are monotone in beta and in decay", {
  dn <- dynet(school_contacts, format = "contact")
  low <- katz(dn, beta = 0.05)
  high <- katz(dn, beta = 0.2)
  expect_true(all(high >= low - 1e-12))

  none <- katz(dn, beta = 0.1, decay = 0)
  faded <- katz(dn, beta = 0.1, decay = 0.5)
  expect_true(all(faded <= none + 1e-12))
})

test_that("decay of zero takes the exact branch, not exp(0)", {
  dn <- dynet(school_contacts, format = "contact")
  expect_identical(katz(dn, beta = 0.1, decay = 0),
                   katz(dn, beta = 0.1))
})

test_that("a vertex that never receives scores exactly zero", {
  dn <- contacts(c("A", "A"), c("B", "C"), c(0, 1))
  out <- as.data.frame(dyn_centrality(dn, measure = "katz",
                                      scope = "temporal", beta = 0.3))
  expect_identical(out$value[out$node == "A"], 0)
})

test_that("katz needs no path search, so traversal_time is not accepted", {
  # It streams contacts rather than walking journeys; silently accepting a
  # per-hop traversal cost would imply it was doing something it is not.
  dn <- dynet(school_contacts, format = "contact")
  expect_error(
    dyn_centrality(dn, measure = "katz", scope = "temporal",
                   traversal_time = 1),
    class = "dynet_bad_input")
})

test_that("relabelling vertices permutes the scores and changes no value", {
  dn <- dynet(school_contacts, format = "contact")
  before <- as.data.frame(dyn_centrality(dn, measure = "katz",
                                         scope = "temporal", beta = 0.1))
  renamed <- rename_nodes(dn, c(Ana = "Zara"))
  after <- as.data.frame(dyn_centrality(renamed, measure = "katz",
                                        scope = "temporal", beta = 0.1))
  expect_equal(sort(before$value), sort(after$value))
})
