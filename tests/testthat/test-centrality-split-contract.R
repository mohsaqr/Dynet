test_that("path_centrality refuses measures it does not compute", {
  dn <- quiet_dynet(chain_edges())
  expect_error(path_centrality(dn, measure = "degree"),
               class = "dynet_unknown_measure")
  expect_error(path_centrality(dn, measure = "reach"),
               class = "dynet_unknown_measure")
  expect_error(path_centrality(dn, measure = NA_character_),
               class = "dynet_bad_input")
  expect_error(path_centrality(dn, traversal_time = -1),
               class = "dynet_bad_input")
})

test_that("centrality_series leaves temporal reach to reachability()", {
  dn <- quiet_dynet(chain_edges())
  expect_error(centrality_series(dn, measure = "reach"),
               class = "dynet_unknown_measure")
})

test_that("path_centrality returns one row per vertex and no time column", {
  dn <- quiet_dynet(random_edges(seed = 3L))
  out <- as.data.frame(path_centrality(dn, measure = c("closeness",
                                                       "betweenness")))
  expect_false("time" %in% names(out))
  n <- nrow(as.data.frame(dn, what = "nodes"))
  expect_identical(nrow(out), 2L * n)
  expect_setequal(unique(out$measure), c("closeness", "betweenness"))
})

test_that("path_centrality is invariant to input row order", {
  edges <- random_edges(seed = 5L)
  shuffled <- edges[rev(seq_len(nrow(edges))), , drop = FALSE]
  a <- as.data.frame(path_centrality(quiet_dynet(edges),
                                     measure = c("closeness", "betweenness")))
  b <- as.data.frame(path_centrality(quiet_dynet(shuffled),
                                     measure = c("closeness", "betweenness")))
  expect_equal(a, b)
})

test_that("the retired dyn_centrality warns by class and routes by scope", {
  dn <- quiet_dynet(random_edges(seed = 2L))
  expect_warning(dyn_centrality(dn), class = "dynet_deprecated")
  expect_identical(legacy_centrality(dn, measure = "degree"),
                   centrality_series(dn, measure = "degree"))
  expect_identical(
    legacy_centrality(dn, measure = "closeness", scope = "temporal"),
    path_centrality(dn, measure = "closeness")
  )
  expect_error(legacy_centrality(dn, traversal_time = 1),
               class = "dynet_bad_input")
  expect_error(legacy_centrality(dn, measure = "closeness",
                                 scope = "temporal", step = 1),
               class = "dynet_bad_input")
})

test_that("path_centrality draws on request and still returns the table", {
  dn <- quiet_dynet(chain_edges())
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  drawn <- withVisible(path_centrality(dn, plot = TRUE))
  expect_false(drawn$visible)
  expect_s3_class(drawn$value, "dynet_metric")
})
