test_that("path_network represents the union of endpoint-local optimal routes", {
  dn <- dynet(data.frame(
    from = c("A", "A", "B", "C"), to = c("B", "C", "D", "D"),
    start = c(0, 0, 1, 1), end = c(1, 1, 2, 2)
  ))
  paths <- dyn_paths(dn, from = "A", start = 0, end = 2)
  net <- path_network(paths)
  edges <- as.data.frame(net)

  expect_s3_class(net, "cograph_network")
  expect_setequal(edges$from, c("A", "A", "B", "C"))
  expect_setequal(edges$to, c("B", "C", "D", "D"))
  expect_equal(edges$weight[edges$from == "A" & edges$to == "B"], 2)
  expect_identical(net$meta$criterion, "foremost_then_shortest")
})
