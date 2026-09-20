# Four defects that all failed the same way: the verb accepted input it could
# not honour and returned something the caller did not ask for, with no
# condition raised. Each test below fails if the silence comes back.

test_that("add_vertex_spells refuses a session the network cannot represent", {
  # It used to drop the label and return normally, while the sibling
  # update_vertex_spells errored on the identical input.
  dn <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                               start = c(0, 1), end = c(2, 3)))
  expect_error(
    add_vertex_spells(dn, data.frame(node = "A", start = 0, end = 2,
                                     session = "s1")),
    class = "dynet_incompatible_vertex_spells"
  )
  # The same declaration without a session is still accepted.
  expect_s3_class(
    add_vertex_spells(dn, data.frame(node = "A", start = 0, end = 2)),
    "dynet"
  )
})

test_that("the two vertex-spell verbs agree about a session they cannot hold", {
  # The invariant the fix restores: siblings treat one input one way.
  dn <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                               start = c(0, 1), end = c(2, 3)))
  declared <- add_vertex_spells(dn, data.frame(node = "A", start = 0, end = 2))
  expect_error(
    add_vertex_spells(dn, data.frame(node = "A", start = 0, end = 2,
                                     session = "s1")),
    class = "dynet_bad_input"
  )
  expect_error(
    update_vertex_spells(declared, spells = 1,
                         data = data.frame(session = "s1")),
    class = "dynet_bad_input"
  )
})

test_that("update_vertex_spells refuses a field it does not own", {
  # A misspelled field used to return the object unchanged: a silent no-op.
  dn <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                               start = c(0, 1), end = c(2, 3)))
  declared <- add_vertex_spells(dn, data.frame(node = "A", start = 0, end = 2))
  expect_error(
    update_vertex_spells(declared, spells = 1, data = data.frame(colour = "red")),
    class = "dynet_unknown_column"
  )
  # A real field still writes.
  updated <- update_vertex_spells(declared, spells = 1,
                                  data = data.frame(end = 12))
  expect_identical(as.data.frame(updated, what = "vertex_spells")$end[[1L]], 12)
})

test_that("remove_ties matches a time with tolerance, not exact equality", {
  # 0.1 + 0.1 + 0.1 is not 0.3 in a double, so `%in%` missed a spell the
  # caller could name exactly.
  dn <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                               start = c(0.1 + 0.1 + 0.1, 5), end = c(1, 6)))
  expect_false(identical(as.data.frame(dn)$start[[1L]], 0.3))
  trimmed <- remove_ties(dn, from = "A", to = "B", start = 0.3)
  expect_identical(nrow(as.data.frame(trimmed)), 1L)
  # A time that genuinely is not there still raises.
  expect_error(remove_ties(dn, from = "A", to = "B", start = 99),
               class = "dynet_tie_not_found")
})

test_that("an undirected networkDynamic import keeps attributes on their own spell", {
  skip_if_not_installed("networkDynamic")
  skip_if_not_installed("network")
  # dynet() canonicalises an undirected pair with pmin/pmax before sorting;
  # the importer sorted on the raw tail and head, so attributes landed on the
  # wrong spell whenever the two permutations disagreed.
  net <- network::network.initialize(3, directed = FALSE)
  net <- network::add.edges(net, tail = c(2, 1), head = c(1, 3))
  network::set.vertex.attribute(net, "vertex.names", c("A", "B", "C"))
  nd <- networkDynamic::networkDynamic(
    base.net = net,
    edge.spells = data.frame(onset = c(0, 0), terminus = c(1, 1),
                             tail = c(2, 1), head = c(1, 3))
  )
  network::set.edge.attribute(nd, "kind", c("k1", "k2"))
  imported <- as.data.frame(suppressMessages(as_dynet(nd)))

  ab <- imported$kind[imported$from == "A" & imported$to == "B"]
  ac <- imported$kind[imported$from == "A" & imported$to == "C"]
  expect_identical(ab, "k1")
  expect_identical(ac, "k2")
})
