strength_out <- function(dn, ...) {
  x <- centrality_series(dn, measure = "strength", mode = "out", ...)
  as.data.frame(x)
}

share_network <- function() {
  quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "C"),
    start = c(0, 1.5), end = c(4, 1.5), weight = c(8, 3)
  ))
}

test_that("a window receives the share of a spell's duration inside it", {
  got <- strength_out(share_network(), step = 2)
  a <- got$value[got$node == "A"]
  # 8 * 2/4 from the long spell plus the whole point contact, then 8 * 2/4.
  expect_equal(a, c(7, 4))
})

test_that("tiled windows give back every spell's full weight", {
  edges <- random_edges(seed = 21L)
  edges$weight <- seq_len(nrow(edges))
  dn <- quiet_dynet(edges)
  tiled <- strength_out(dn, step = 3)
  spells <- as.data.frame(dn)
  expect_equal(sum(tiled$value), sum(spells$weight))
})

test_that("point windows and the whole period keep full weights", {
  dn <- share_network()
  instant <- strength_out(dn, start = 1, end = 1, step = 1, window = 0)
  expect_equal(instant$value[instant$node == "A"], 8)
  whole <- strength_out(dn, window = "all")
  expect_equal(whole$value[whole$node == "A"], 11)
})

test_that("weight outside the observation period is not reassigned", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", start = 0, end = 4,
                               weight = 8),
                    observation_start = 0, observation_end = 2)
  got <- strength_out(dn, window = "all")
  expect_equal(got$value[got$node == "A"], 4)
})

test_that("degree is untouched by weight shares", {
  dn <- share_network()
  degree <- as.data.frame(centrality_series(dn, measure = "degree",
                                            mode = "out", step = 2))
  expect_equal(degree$value[degree$node == "A"], c(2, 1))
})

test_that("strength still validates its direction", {
  expect_error(centrality_series(share_network(), measure = "strength",
                                 mode = "sideways"),
               class = "dynet_bad_input")
})
