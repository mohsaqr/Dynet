# A grid bin with no active tie is still a bin. similarity(), turnover(),
# persistence(), segregation() and phases() used to key their layers on the
# snapshot rows, so an empty bin vanished and the bins either side of it were
# compared as if consecutive. Audit 2026-11-01.
#
# Reference values from a live teneto 0.5.3 run on the same 6 x 6 x 5 array
# (bin 2 empty), 2026-11-01:
#   volatility(calc = "pertime", distance_func = "hamming")
#     -> [0.2, 0.2, 0.26666666666666666, 0.2]
#   fluctuability -> 0.5
#   topological_overlap(calc = "node")
#     -> [0.42677669529663687, 0.42677669529663687, 0.17677669529663687,
#         0.25, 0.17677669529663687, 0.17677669529663687]
#   topological_overlap(calc = "overtime") -> 0.2723139127471974
#   sid(communities = [0,0,0,1,1,1], calc = "overtime")
#     -> [0.7777777777777778, -0.1111111111111111, 0.0,
#         0.7777777777777778, 0.4444444444444444]
# With bin 2 deleted from the array teneto gives volatility 0.2444 and a
# temporal correlation of 0.4579, which is what the old code returned.

empty_bin_network <- function(directed = FALSE) {
  quiet_dynet(
    data.frame(
      from = c("A", "C", "A", "E", "A", "C", "B", "A", "E", "C", "D", "A",
               "C", "E"),
      to = c("B", "D", "C", "F", "B", "D", "E", "B", "F", "E", "F", "B",
             "D", "F"),
      start = c(0, 0, 0, 0, 1, 1, 1, 3, 3, 3, 3, 4, 4, 4),
      end = c(1, 1, 1, 1, 2, 2, 2, 4, 4, 4, 4, 5, 5, 5)
    ),
    directed = directed, observation_start = 0, observation_end = 5
  )
}
EMPTY_GRID <- list(start = 0, end = 4, step = 1, window = 1)

# ---------------------------------------------------------------- equivalence

test_that("turnover keeps the empty bin and matches teneto", {
  dn <- empty_bin_network()
  per_time <- as.data.frame(do.call(turnover, c(list(dn), EMPTY_GRID)))
  expect_identical(per_time$time, c(0, 1, 2, 3))
  expect_equal(per_time$value, c(0.2, 0.2, 0.26666666666666666, 0.2),
               tolerance = 1e-12)
  overall <- as.data.frame(do.call(turnover, c(
    list(dn, measure = c("volatility", "fluctuability"), scope = "overall"),
    EMPTY_GRID
  )))
  expect_equal(overall$value, c(0.21666666666666667, 0.5), tolerance = 1e-12)
})

test_that("persistence keeps the empty bin and matches teneto", {
  dn <- empty_bin_network()
  per_node <- as.data.frame(do.call(persistence,
                                    c(list(dn, scope = "node"), EMPTY_GRID)))
  expect_equal(per_node$value,
               c(0.42677669529663687, 0.42677669529663687, 0.17677669529663687,
                 0.25, 0.17677669529663687, 0.17677669529663687),
               tolerance = 1e-12)
  overall <- as.data.frame(do.call(persistence,
                                   c(list(dn, scope = "overall"), EMPTY_GRID)))
  expect_equal(overall$value, 0.2723139127471974, tolerance = 1e-12)
})

test_that("segregation scores the empty bin zero and matches teneto at C = 2", {
  dn <- empty_bin_network()
  halves <- c(A = "a", B = "a", C = "a", D = "b", E = "b", F = "b")
  sid <- as.data.frame(do.call(segregation,
                               c(list(dn, communities = halves), EMPTY_GRID)))
  expect_identical(sid$time, c(0, 1, 2, 3, 4))
  expect_equal(sid$value,
               c(0.7777777777777778, -0.1111111111111111, 0,
                 0.7777777777777778, 0.4444444444444444),
               tolerance = 1e-12)
})

test_that("similarity agrees with sna::gcor and sna::hdist on the pair domain", {
  skip_if_not_installed("sna")
  dn <- empty_bin_network()
  layers <- lapply(c(0, 1), function(t) {
    m <- matrix(0, 6, 6, dimnames = list(LETTERS[1:6], LETTERS[1:6]))
    snap <- as.data.frame(snapshots(dn, at = t + 0.5, step = 1, window = 1))
    m[cbind(snap$from, snap$to)] <- 1
    pmax(m, t(m))
  })
  grid <- list(start = 0, end = 1, step = 1, window = 1)
  pearson <- as.data.frame(do.call(similarity,
                                   c(list(dn, method = "pearson"), grid)))
  hamming <- as.data.frame(do.call(similarity,
                                   c(list(dn, method = "hamming"), grid)))
  expect_equal(pearson$value[[2L]],
               sna::gcor(layers, mode = "graph")[1L, 2L], tolerance = 1e-12)
  expect_equal(hamming$value[[2L]],
               sna::hdist(layers, mode = "graph")[1L, 2L])
})

# ---------------------------------------------------------------- contract

test_that("similarity has one row per ordered pair of grid bins", {
  dn <- empty_bin_network()
  s <- do.call(similarity, c(list(dn), EMPTY_GRID))
  expect_identical(nrow(s), 25L)
  expect_identical(attr(s, "empty_bins"), 2)
})

test_that("an empty bin gives NA for pearson without a warning", {
  dn <- empty_bin_network()
  expect_no_warning(
    s <- do.call(similarity, c(list(dn, method = "pearson"), EMPTY_GRID))
  )
  flat <- as.data.frame(s)
  expect_true(all(is.na(flat$value[flat$time == 2 | flat$other == 2])))
  expect_false(anyNA(flat$value[flat$time != 2 & flat$other != 2]))
})

test_that("phases refuses an undefined distance by class", {
  dn <- empty_bin_network()
  expect_error(do.call(phases, c(list(dn, k = 2, method = "cosine"),
                                 EMPTY_GRID)),
               class = "dynet_undefined_similarity")
})

test_that("phases keeps the empty bin under jaccard and hamming", {
  dn <- empty_bin_network()
  jac <- do.call(phases, c(list(dn, k = 2, method = "jaccard"), EMPTY_GRID))
  expect_identical(jac$time, c(0, 1, 2, 3, 4))
  ham <- do.call(phases, c(list(dn, k = 2, method = "hamming"), EMPTY_GRID))
  d <- attr(ham, "blocks")[[1L]]$distance
  # The Hamming distance is a share of the pair domain, so it cannot pass 1.
  expect_true(all(d >= 0 & d <= 1))
})

test_that("turnover refuses an unknown measure with the bad-input parent", {
  dn <- empty_bin_network()
  expect_error(turnover(dn, measure = "speed"),
               class = "dynet_unknown_measure")
  expect_error(turnover(dn, measure = "speed"), class = "dynet_bad_input")
})

# ---------------------------------------------------------------- invariants

test_that("similarity is symmetric and in range with an empty bin present", {
  dn <- empty_bin_network(directed = TRUE)
  invisible(lapply(c("jaccard", "overlap", "cosine", "pearson", "hamming"),
    function(m) {
      flat <- as.data.frame(do.call(similarity, c(list(dn, method = m),
                                                  EMPTY_GRID)))
      mirror <- flat$value[order(flat$other, flat$time)]
      expect_identical(is.na(flat$value), is.na(mirror))
      expect_equal(flat$value, mirror, tolerance = 1e-12)
      defined <- flat$value[!is.na(flat$value)]
      if (identical(m, "hamming")) {
        expect_true(all(defined >= 0 & defined <= 30))
      } else {
        expect_true(all(defined >= -1 - 1e-12 & defined <= 1 + 1e-12))
      }
    }))
})

test_that("an empty bin breaks a frozen run: volatility counts both sides", {
  # A-B is tied in bins 0 and 2 but not 1; A-C is tied throughout. Each
  # transition flips exactly one of the three dyads.
  dn <- quiet_dynet(
    data.frame(from = c("A", "A", "A"), to = c("B", "B", "C"),
               start = c(0, 2, 0), end = c(1, 3, 3)),
    directed = FALSE, observation_start = 0, observation_end = 3
  )
  vol <- as.data.frame(turnover(dn, start = 0, end = 2, step = 1, window = 1))
  expect_equal(vol$value, c(1, 1) / 3, tolerance = 1e-12)
  kept <- as.data.frame(persistence(dn, scope = "node", start = 0,
                                    end = 2, step = 1, window = 1))
  # B is isolated in bin 1, so neither transition keeps a neighbour of B;
  # C keeps A throughout.
  expect_identical(kept$node, c("A", "B", "C"))
  expect_equal(kept$value, c(sqrt(0.5), 0, 1), tolerance = 1e-12)
})
