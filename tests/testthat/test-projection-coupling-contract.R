# Item 1: the projection records its coupling, and the coupling is a real
# choice rather than a label.

test_that("projection refuses a coupling it does not implement", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(projection(dn, coupling = "chain"))
  expect_error(projection(dn, omega = -1), class = "dynet_bad_input")
})

test_that("the identity arcs carry omega and the meta says so", {
  # Regression: identity_weight was once hard-coded to one while the arcs
  # carried omega, so the object contradicted itself.
  dn <- dynet(school_contacts, format = "contact")
  for (omega in c(0, 0.37, 3)) {
    p <- projection(dn, step = 5, window = 5, omega = omega)
    arcs <- as.data.frame(p, what = "edges")
    expect_identical(unique(arcs$weight[arcs$edge_type == "identity_arc"]),
                     omega)
    expect_identical(p$meta$omega, omega)
    expect_identical(p$meta$coupling, "ordinal")
  }
})

test_that("ordinal coupling joins consecutive slices and nothing else", {
  dn <- dynet(school_contacts, format = "contact")
  p <- projection(dn, step = 5, window = 5)
  arcs <- as.data.frame(p, what = "edges")
  identity <- arcs[arcs$edge_type == "identity_arc", ]
  expect_true(all(identity$to_slice - identity$from_slice == 1L))
  expect_identical(nrow(identity),
                   as.integer(p$meta$n_nodes * (p$meta$n_slices - 1L)))
})

test_that("categorical coupling joins every slice pair", {
  # This is the multiplex convention, appropriate for unordered aspect-layers
  # and wrong for time. It exists so a multiplex analysis can be reproduced.
  dn <- dynet(school_contacts, format = "contact")
  p <- projection(dn, step = 5, window = 5, coupling = "categorical")
  arcs <- as.data.frame(p, what = "edges")
  identity <- arcs[arcs$edge_type == "identity_arc", ]
  expect_identical(nrow(identity),
                   as.integer(p$meta$n_nodes * choose(p$meta$n_slices, 2)))
  expect_identical(p$meta$coupling, "categorical")
  expect_true(max(identity$to_slice - identity$from_slice) > 1L)
})

test_that("the supra assembler reproduces each slice's own adjacency", {
  dn <- dynet(school_contacts, format = "contact")
  p <- projection(dn, step = 5, window = 5)
  supra <- Dynet:::.supra(p)
  expect_identical(length(supra$blocks), 1L)
  layers <- supra$blocks[[1L]]$layers
  expect_identical(length(layers), p$meta$n_slices)
  # Each layer is the snapshot adjacency of its own bin, symmetrised.
  snaps <- snapshots(dn, step = 5, window = 5)
  for (slice in seq_along(layers)) {
    a <- layers[[slice]]
    expect_equal(a, t(a))
    expect_identical(dim(a), c(p$meta$n_nodes, p$meta$n_nodes))
  }
  expect_true(supra$symmetrised)
})

test_that("the categorical block matrix agrees with cograph, and ordinal does not", {
  # cograph's "diagonal" coupling is all-to-all across layers. That is exactly
  # our categorical case, and it is exactly not our ordinal one, so both the
  # equality and the inequality are asserted: the distinction must never
  # silently regress.
  skip_if_not_installed("cograph")
  dn <- dynet(school_contacts, format = "contact")
  omega <- 0.4
  supra <- Dynet:::.supra(projection(dn, step = 5, window = 5, omega = omega,
                                     coupling = "categorical"))
  layers <- supra$blocks[[1L]]$layers
  n <- nrow(layers[[1L]])
  n_slices <- length(layers)
  block <- matrix(0, n * n_slices, n * n_slices)
  for (s in seq_len(n_slices)) {
    span <- (s - 1L) * n + seq_len(n)
    block[span, span] <- layers[[s]]
  }
  for (s in seq_len(n_slices - 1L)) {
    for (r in seq.int(s + 1L, n_slices)) {
      rows <- (s - 1L) * n + seq_len(n)
      cols <- (r - 1L) * n + seq_len(n)
      block[cbind(rows, cols)] <- omega
      block[cbind(cols, rows)] <- omega
    }
  }
  reference <- as.matrix(cograph::supra_adjacency(layers, omega = omega,
                                                  coupling = "diagonal"))
  attributes(reference) <- list(dim = dim(reference))
  expect_equal(reference, block, tolerance = sqrt(.Machine$double.eps))

  # And the ordinal assembly must differ from it, or the two couplings would
  # be the same thing under two names.
  chain <- block
  for (s in seq_len(n_slices - 1L)) {
    for (r in seq.int(s + 1L, n_slices)) {
      if (r - s == 1L) next
      rows <- (s - 1L) * n + seq_len(n)
      cols <- (r - 1L) * n + seq_len(n)
      chain[cbind(rows, cols)] <- 0
      chain[cbind(cols, rows)] <- 0
    }
  }
  expect_true(n_slices >= 3L)
  expect_false(isTRUE(all.equal(chain, reference)))
})

test_that("coupling degree counts partners, not slices", {
  expect_identical(Dynet:::.coupling_degree(4L, "ordinal"), c(1, 2, 2, 1))
  expect_identical(Dynet:::.coupling_degree(4L, "categorical"), rep(3, 4L))
  expect_identical(Dynet:::.coupling_degree(1L, "ordinal"), 0)
})
