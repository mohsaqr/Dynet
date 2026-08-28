test_that("participation requires groups and rejects them elsewhere", {
  dn <- dynet(school_contacts, format = "contact")
  expect_error(dyn_centrality(dn, measure = "participation"),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = "degree", groups = "team"),
               class = "dynet_bad_input")
  expect_error(dyn_centrality(dn, measure = "participation", groups = "nosuch"),
               class = "dynet_unknown_attribute")
})

test_that("participation is a snapshot measure, not a temporal one", {
  # It loops over slices and involves no time-respecting path, so putting it
  # under scope = "temporal" would misrepresent it.
  dn <- dynet(school_contacts, format = "contact")
  expect_error(
    dyn_centrality(dn, measure = "participation", scope = "temporal"),
    class = "dynet_unknown_measure")
})

test_that("the coefficient matches a hand-computed share", {
  # X has two contacts in group A and two in group B, so the shares are 0.5
  # and 0.5 and the coefficient is 1 - (0.25 + 0.25) = 0.5.
  dn <- dynet(
    data.frame(from = c("X", "X", "X", "X"),
               to = c("a1", "a2", "b1", "b2"), time = 0),
    format = "contact", directed = FALSE,
    nodes = data.frame(name = c("X", "a1", "a2", "b1", "b2"),
                       g = c("A", "A", "A", "B", "B")))
  out <- as.data.frame(dyn_centrality(dn, measure = "participation",
                                      groups = "g"))
  expect_equal(out$value[out$node == "X"], 0.5)

  # All four contacts inside one group gives exactly zero.
  same <- dynet(
    data.frame(from = c("X", "X"), to = c("a1", "a2"), time = 0),
    format = "contact", directed = FALSE,
    nodes = data.frame(name = c("X", "a1", "a2"), g = c("A", "A", "A")))
  out2 <- as.data.frame(dyn_centrality(same, measure = "participation",
                                       groups = "g"))
  expect_equal(out2$value[out2$node == "X"], 0)
})

test_that("participation stays inside its 1 - 1/g bound under every mode", {
  dn <- random_dynet(nodes = 12, times = 8, model = "block", blocks = 3,
                     p_within = 0.4, p_between = 0.05, seed = 1)
  for (md in c("all", "out", "in")) {
    v <- as.data.frame(dyn_centrality(dn, measure = "participation",
                                      groups = "block", mode = md))$value
    v <- v[is.finite(v)]
    expect_true(all(v >= -1e-9), info = md)
    expect_true(all(v <= 2 / 3 + 1e-9), info = md)
  }
})

test_that("a degree-zero eligible vertex is NaN, not a fabricated zero", {
  # NA means not eligible; NaN means eligible with no contacts, so the shares
  # are 0/0. They are different statements and must not be conflated.
  # A vertex absent from a bin is not emitted at all, so the NaN case needs a
  # vertex that IS eligible there and simply has no contacts.
  dn <- dynet(
    data.frame(from = "A", to = "B", start = 0, end = 1),
    vertex_spells = data.frame(node = c("A", "B", "C"), start = 0, end = 2),
    observation_start = 0, observation_end = 2,
    nodes = data.frame(name = c("A", "B", "C"), g = c("x", "x", "y")))
  out <- as.data.frame(dyn_centrality(dn, measure = "participation",
                                      groups = "g"))
  isolated <- out$value[out$time == 0 & out$node == "C"]
  expect_identical(length(isolated), 1L)
  expect_true(is.nan(isolated))
  # and the two vertices that do have a contact are defined
  expect_false(any(is.nan(out$value[out$time == 0 & out$node %in% c("A", "B")])))
})

test_that("a single group makes every participation exactly zero", {
  dn <- random_dynet(nodes = 10, times = 6, model = "binomial", p = 0.4,
                     seed = 1)
  labels <- rep("only", nrow(dn$nodes))
  v <- as.data.frame(dyn_centrality(dn, measure = "participation",
                                    groups = labels))$value
  expect_true(all(v[is.finite(v)] == 0))
})

test_that("relabelling the groups changes no value", {
  dn <- random_dynet(nodes = 12, times = 6, model = "block", blocks = 2,
                     p_within = 0.4, p_between = 0.05, seed = 1)
  a <- as.data.frame(dyn_centrality(dn, measure = "participation",
                                    groups = "block"))$value
  relabelled <- c(b1 = "zebra", b2 = "aardvark")[
    as.data.frame(dn, what = "nodes")$block]
  b <- as.data.frame(dyn_centrality(dn, measure = "participation",
                                    groups = unname(relabelled)))$value
  expect_equal(a, b)
})

test_that("groups can be given as a vector or as an attribute name", {
  dn <- random_dynet(nodes = 10, times = 6, model = "block", blocks = 2,
                     p_within = 0.4, p_between = 0.05, seed = 1)
  by_name <- as.data.frame(dyn_centrality(dn, measure = "participation",
                                          groups = "block"))$value
  by_vector <- as.data.frame(dyn_centrality(
    dn, measure = "participation",
    groups = as.data.frame(dn, what = "nodes")$block))$value
  expect_equal(by_name, by_vector)
})
