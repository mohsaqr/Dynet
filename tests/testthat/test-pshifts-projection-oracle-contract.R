# Participation shifts against a hand-classified turn sequence, and the
# vectorised time projection against tsna. Audit 2026-11-01.

gibson_turns <- function() {
  # One turn per row; a speaker naming two recipients at one instant is a
  # group turn ("0"). Classified by hand, the 13 transitions are, in order:
  # AB-BA, AB-B0, A0-XA, AB-BY, AB-A0, A0-AY, AB-AY, AB-X0, A0-X0, A0-XY,
  # AB-XA, AB-XB, AB-XY -- every Gibson class exactly once.
  time <- c(1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 9, 9, 10, 10, 11, 12, 13, 14)
  data.frame(
    from = c("A", "B", "A", "A", "C", "A", "A", "A", "A", "A", "D", "D", "B",
             "B", "C", "D", "B", "A"),
    to = c("B", "A", "B", "C", "A", "D", "B", "C", "B", "C", "A", "B", "C",
           "D", "A", "C", "C", "D"),
    start = time, end = time
  )
}

test_that("a sequence covering every Gibson class counts each once", {
  dn <- quiet_dynet(gibson_turns(), directed = TRUE)
  census <- as.data.frame(pshifts(dn))
  expect_identical(nrow(census), 13L)
  expect_identical(census$value, rep(1L, 13L))
})

test_that("pshifts refuses an undirected network by class", {
  dn <- quiet_dynet(gibson_turns(), directed = FALSE)
  expect_error(pshifts(dn), class = "dynet_needs_directed")
})

test_that("shuffled rows and relabelled vertices give the same census", {
  turns <- gibson_turns()
  base <- as.data.frame(pshifts(quiet_dynet(turns, directed = TRUE)))
  shuffled <- turns[rev(seq_len(nrow(turns))), ]
  again <- as.data.frame(pshifts(quiet_dynet(shuffled, directed = TRUE)))
  expect_identical(again, base)
  # An order-preserving rename keeps the within-instant tie-break order.
  renamed <- transform(
    turns, from = paste0("v", match(from, LETTERS)),
    to = paste0("v", match(to, LETTERS))
  )
  third <- as.data.frame(pshifts(quiet_dynet(renamed, directed = TRUE)))
  expect_identical(third, base)
})

test_that("an inclusive query limit is tolerant of float arithmetic", {
  t <- c(0.1, 0.2, 0.1 + 0.2)
  dn <- quiet_dynet(data.frame(from = c("A", "B", "A"), to = c("B", "A", "B"),
                               start = t, end = t), directed = TRUE)
  census <- as.data.frame(pshifts(dn, start = 0.1, end = 0.3))
  # Three turns, two transitions: AB-BA then AB-BA.
  expect_identical(sum(census$value), 2L)
})

test_that("the projection's arcs equal tsna::timeProjectedNetwork()'s", {
  skip_if_not_installed("tsna")
  skip_if_not_installed("networkDynamic")
  e <- data.frame(from = c("A", "B", "C", "A"), to = c("B", "C", "A", "B"),
                  start = c(0, 1, 2, 2.5), end = c(1, 2, 3, 3))
  dn <- quiet_dynet(e, directed = TRUE, observation_start = 0,
                    observation_end = 3)
  projected <- projection(dn, start = 0, end = 2, step = 1, window = 1)
  arcs <- as.data.frame(projected, what = "edges")
  nd <- suppressMessages(networkDynamic::networkDynamic(
    edge.spells = data.frame(onset = e$start, terminus = e$end,
                             tail = match(e$from, LETTERS),
                             head = match(e$to, LETTERS)),
    vertex.spells = data.frame(onset = 0, terminus = 3, vertex.id = 1:3),
    verbose = FALSE
  ))
  oracle <- network::as.edgelist(
    tsna::timeProjectedNetwork(nd, start = 0, end = 3, time.increment = 1)
  )
  expect_setequal(paste(arcs$from_state, arcs$to_state),
                  paste(oracle[, 1L], oracle[, 2L]))
})

test_that("categorical coupling joins every slice pair, ordinal the next", {
  dn <- quiet_dynet(random_edges(n_v = 6L, n_e = 20L, span = 8, seed = 4))
  n <- nrow(dn$nodes)
  ordinal <- as.data.frame(projection(dn, step = 2, window = 2),
                           what = "edges")
  categorical <- as.data.frame(
    projection(dn, step = 2, window = 2, coupling = "categorical"),
    what = "edges"
  )
  slices <- length(unique(ordinal$from_slice[
    ordinal$edge_type == "within_slice"
  ]))
  n_slices <- max(c(ordinal$from_slice, ordinal$to_slice))
  expect_identical(sum(ordinal$edge_type == "identity_arc"),
                   as.integer(n * (n_slices - 1L)))
  expect_identical(sum(categorical$edge_type == "identity_arc"),
                   as.integer(n * choose(n_slices, 2)))
  # Within-slice arcs do not depend on the coupling.
  expect_identical(
    categorical[categorical$edge_type == "within_slice", ],
    ordinal[ordinal$edge_type == "within_slice", ],
    ignore_attr = TRUE
  )
  expect_true(slices >= 1L)
})

test_that("an undirected projection has reciprocal within-slice arcs", {
  dn <- quiet_dynet(random_edges(n_v = 6L, n_e = 20L, span = 8, seed = 4),
                    directed = FALSE)
  arcs <- as.data.frame(projection(dn, step = 2, window = 2), what = "edges")
  within <- arcs[arcs$edge_type == "within_slice", ]
  expect_setequal(paste(within$from_state, within$to_state),
                  paste(within$to_state, within$from_state))
})

test_that("a projection is not a temporal network and is refused by class", {
  projected <- projection(quiet_dynet(chain_edges()))
  expect_error(projection(projected), class = "dynet_bad_input")
})
