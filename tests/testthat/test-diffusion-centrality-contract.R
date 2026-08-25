test_that("diffusion degree sums degree over the closed one-step neighbourhood", {
  a <- matrix(0, 4, 4, dimnames = list(LETTERS[1:4], LETTERS[1:4]))
  a[cbind(c(1, 1, 2, 3), c(2, 3, 3, 1))] <- 1
  expect_equal(
    Dynet:::.diffusion_degree(a, TRUE, "out", lambda = 2),
    c(A = 8, B = 4, C = 6, D = 0)
  )
  expect_equal(
    Dynet:::.diffusion_degree(a, TRUE, "in", lambda = 1),
    c(A = 3, B = 2, C = 4, D = 0)
  )
})

test_that("diffusion degree is available over temporal snapshots", {
  dn <- dynet(data.frame(
    from = c("A", "A", "B"), to = c("B", "C", "C"),
    start = 0, end = 1
  ))
  out <- as.data.frame(dyn_centrality(
    dn, measure = "diffusion", mode = "out", lambda = 0.5,
    start = 0, end = 0, step = 1, window = 0
  ))
  expect_identical(out$measure, rep("diffusion", 3))
  expect_equal(out$value, c(1.5, 0.5, 0))
})
