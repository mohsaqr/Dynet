# collapse_network(): its edge set over a window and the boundary tolerance of
# its clipping. Audit 2026-11-01. The comparison with
# networkDynamic::network.collapse() is in tests/equivalence.

# ---------------------------------------------------------------- oracle

test_that("the collapsed edge set equals network.collapse() over a window", {
  skip_if_not_installed("networkDynamic")
  e <- data.frame(from = c("A", "A", "B", "C"), to = c("B", "B", "C", "A"),
                  start = c(0, 1, 2, 5), end = c(2, 3, 6, 8))
  dn <- quiet_dynet(e, directed = TRUE)
  flat <- collapse_network(dn, start = 1, end = 5)
  mine <- as.data.frame(flat)
  expect_identical(paste(mine$from, mine$to), c("A B", "B C"))
  expect_equal(mine$union_duration, c(2, 3))
})

# ---------------------------------------------------------------- tolerance

test_that("a spell ending at a bound to within tolerance leaves no edge", {
  e <- data.frame(from = c("A", "B"), to = c("B", "C"),
                  start = c(0, 0.5), end = c(0.1 + 0.2, 1))
  dn <- quiet_dynet(e)
  flat <- collapse_network(dn, start = 0.3, end = 1)
  expect_identical(as.data.frame(flat)$from, "B")

  big <- data.frame(from = c("A", "B"), to = c("B", "C"),
                    start = 1.7e9 + c(0, 0.5),
                    end = 1.7e9 + c(0.3 + 2.4e-7, 1))
  dn_big <- quiet_dynet(big)
  flat_big <- collapse_network(dn_big, start = 1.7e9 + 0.3, end = 1.7e9 + 1)
  expect_identical(as.data.frame(flat_big)$from, "B")
})

test_that("a reversed range is refused by class", {
  dn <- quiet_dynet(chain_edges())
  expect_error(collapse_network(dn, start = 4, end = 1),
               class = "dynet_bad_input")
})

# ---------------------------------------------------------------- invariants

test_that("windows partition the whole span: edge union and durations add", {
  dn <- quiet_dynet(random_edges(seed = 3))
  whole <- as.data.frame(collapse_network(dn))
  cuts <- seq(dn$meta$time_range[["start"]], dn$meta$time_range[["end"]],
              length.out = 5)
  parts <- lapply(seq_len(4), function(i) {
    as.data.frame(collapse_network(dn, start = cuts[[i]], end = cuts[[i + 1L]]))
  })
  pieces <- do.call(rbind, parts)
  expect_setequal(unique(paste(pieces$from, pieces$to)),
                  paste(whole$from, whole$to))
  expect_equal(sum(pieces$union_duration), sum(whole$union_duration),
               tolerance = 1e-12)
  expect_equal(sum(pieces$weighted_duration), sum(whole$weighted_duration),
               tolerance = 1e-12)
})

test_that("shuffling the spell rows changes nothing", {
  e <- random_edges(seed = 3)
  shuffled <- e[rev(seq_len(nrow(e))), ]
  one <- as.data.frame(collapse_network(quiet_dynet(e)))
  two <- as.data.frame(collapse_network(quiet_dynet(shuffled)))
  expect_identical(one, two)
})

test_that("the collapsed object is a cograph network cograph can use", {
  skip_if_not_installed("cograph")
  flat <- collapse_network(quiet_dynet(random_edges(seed = 3)),
                           weight = "union_duration")
  expect_s3_class(flat, "cograph_network")
  expect_s3_class(summary(flat), "data.frame")
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(flat))
})
