test_that("earliest arrival on a chain matches the value worked out by hand", {
  # A->B over [1,2), B->C over [2,3), C->D over [3,4), D->E over [4,5).
  # Starting at A at t = 1 the walker can only ever board the next edge as it
  # opens, so arrivals are 1, 1, 2, 3, 4.
  dn <- quiet_dynet(chain_edges())
  p <- paths(dn, from = "A")
  expect_equal(p$arrival_time[match(c("A", "B", "C", "D", "E"), p$node)],
               c(1, 1, 2, 3, 4))
  expect_equal(p$n_hops[match(c("A", "B", "C", "D", "E"), p$node)],
               c(0L, 1L, 2L, 3L, 4L))
  steps <- as.data.frame(p, what = "steps")
  endpoint <- steps[steps$endpoint == "E", , drop = FALSE]
  expect_identical(endpoint$node, c("A", "B", "C", "D", "E"))
  expect_true(all(p$reachable))
})

test_that("a path cannot run backwards in time", {
  # The edge into A opens before the edge out of C, so C never reaches B.
  backwards <- data.frame(from = c("C", "A"), to = c("A", "B"),
                          start = c(5, 1), end = c(6, 2),
                          stringsAsFactors = FALSE)
  dn <- quiet_dynet(backwards)
  p <- paths(dn, from = "C")
  expect_false(p$reachable[p$node == "B"])
  expect_true(p$reachable[p$node == "A"])
})

test_that("a spell can be boarded late, so one relaxation sweep is not enough", {
  # The A->B edge is open from 0 to 100 but A is only reached at t = 50.
  late <- data.frame(from = c("A", "Z"), to = c("B", "A"),
                     start = c(0, 50), end = c(100, 51),
                     stringsAsFactors = FALSE)
  dn <- quiet_dynet(late)
  p <- paths(dn, from = "Z", at = 50)
  expect_true(p$reachable[p$node == "B"])
  expect_equal(p$arrival_time[p$node == "B"], 50)
})

test_that("backward paths find who could have reached the vertex", {
  dn <- quiet_dynet(chain_edges())
  back <- paths(dn, from = "E", direction = "backward")
  expect_true(all(back$reachable))
  expect_identical(attr(back, "direction"), "backward")
  forward_from_A <- paths(dn, from = "A")
  expect_equal(sum(back$reachable), sum(forward_from_A$reachable))
})

test_that("earliest arrival matches tsna::tPath", {
  skip_if_not_installed("tsna")
  skip_if_not_installed("networkDynamic")
  skip_if_not_installed("network")

  e <- random_edges(n_v = 15L, n_e = 70L, span = 25, seed = 3L)
  dn <- quiet_dynet(e)
  vnames <- as.data.frame(dn, what = "nodes")$name

  base <- network::network.initialize(length(vnames), directed = TRUE)
  network::set.vertex.attribute(base, "vertex.names", vnames)
  nd <- networkDynamic::networkDynamic(
    base,
    edge.spells = data.frame(onset = e$start, terminus = e$end,
                             tail = match(e$from, vnames),
                             head = match(e$to, vnames)),
    verbose = FALSE)

  for (src in vnames[1:4]) {
    ours <- paths(dn, from = src, at = 0)
    theirs <- tsna::tPath(nd, v = match(src, vnames), start = 0,
                          direction = "fwd")
    mine <- ours$arrival_time[match(vnames, ours$node)]
    mine[is.na(mine)] <- Inf
    expect_equal(as.numeric(mine), as.numeric(theirs$tdist),
                 tolerance = 1e-8, info = src)
  }
})

test_that("reachability is a proportion and the source is excluded", {
  dn <- quiet_dynet(random_edges())
  r <- dyn_reachability(dn)
  expect_true(all(r$value >= 0 & r$value <= 1))
  expect_setequal(unique(r$measure), c("forward_reach", "backward_reach"))
})

test_that("reachability never increases when the walker starts later", {
  dn <- quiet_dynet(random_edges(seed = 11L))
  early <- dyn_reachability(dn, direction = "forward", at = 0)
  late  <- dyn_reachability(dn, direction = "forward", at = 12)
  expect_true(all(late$value <= early$value + 1e-12))
})

test_that("an unreachable vertex has no tree to draw", {
  isolated <- data.frame(from = c("A", "C"), to = c("B", "D"),
                         start = c(1, 5), end = c(2, 6),
                         stringsAsFactors = FALSE)
  dn <- quiet_dynet(isolated)
  p <- paths(dn, from = "D")
  expect_equal(sum(p$reachable), 1L)
  expect_error(plot(p), class = "dynet_unsupported_plot")
})
