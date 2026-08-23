test_that("every result class has print, summary, plot and as.data.frame", {
  dn <- quiet_dynet(random_edges())
  objects <- list(
    dynet        = dn,
    dynet_metric = dyn_centrality(dn, measure = "degree"),
    dynet_paths  = dyn_paths(dn, from = "v1")
  )
  for (cls in names(objects)) {
    for (generic in c("print", "summary", "plot", "as.data.frame")) {
      expect_true(!is.null(utils::getS3method(generic, cls, optional = TRUE)),
                  info = paste(generic, cls))
    }
  }
})

test_that("summary of the network is a tidy table, not a console dump", {
  dn <- quiet_dynet(random_edges())
  s <- summary(dn)
  expect_s3_class(s, "data.frame")
  expect_identical(names(s), c("property", "value"))
  expect_true(all(c("temporal density", "mean snapshot density", "vertices")
                  %in% s$property))
})

test_that("the network's tidy tables are reachable without touching the object", {
  dn <- quiet_dynet(random_edges())
  expect_true(all(c("from", "to", "start", "end", "duration", "weight")
                  %in% names(as.data.frame(dn))))
  expect_identical(names(as.data.frame(dn, what = "nodes")), "name")
  expect_true(all(c("bin", "lo", "hi", "time")
                  %in% names(as.data.frame(dn, what = "bins"))))
})

test_that("temporal density counts observed duration against possible duration", {
  # Two vertices, one spell covering half the window: with two possible
  # directed pairs the temporal density is a quarter.
  half <- data.frame(from = c("A", "A"), to = c("B", "B"),
                     start = c(0, 10), end = c(5, 10),
                     stringsAsFactors = FALSE)
  dn <- quiet_dynet(half)
  s <- summary(dn)
  expect_equal(as.numeric(s$value[s$property == "temporal density"]), 0.25)
})

test_that("printing does not tell the reader to reach into the object", {
  dn <- quiet_dynet(random_edges())
  shown <- paste(c(capture.output(print(dn)),
                   capture.output(print(dyn_centrality(dn, measure = "degree"))),
                   capture.output(print(dyn_paths(dn, from = "v1")))),
                 collapse = "\n")
  expect_false(grepl("$", shown, fixed = TRUE))
})

test_that("print output is stable", {
  dn <- quiet_dynet(chain_edges())
  expect_snapshot(print(dn))
  expect_snapshot(print(dyn_centrality(dn, measure = "degree")))
  expect_snapshot(print(dyn_paths(dn, from = "A")))
  expect_snapshot(print(summary(dn), row.names = FALSE))
})
