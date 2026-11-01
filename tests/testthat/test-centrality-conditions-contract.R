# Every error the centrality verbs raise carries the parent class
# `dynet_bad_input`, so one handler catches them all (CLAUDE.md contract).

test_that("unknown measures carry dynet_bad_input on every centrality verb", {
  dn <- quiet_dynet(chain_edges())
  expect_error(centrality_series(dn, measure = "nonsense"),
               class = "dynet_unknown_measure")
  expect_error(centrality_series(dn, measure = "nonsense"),
               class = "dynet_bad_input")
  expect_error(path_centrality(dn, measure = "nonsense"),
               class = "dynet_bad_input")
  expect_error(edge_centrality(dn, measure = "closeness"),
               class = "dynet_bad_input")
  expect_error(legacy_centrality(dn, measure = "nonsense", scope = "temporal"),
               class = "dynet_bad_input")
})

test_that("direction, attribute and overflow errors carry dynet_bad_input", {
  undirected <- quiet_dynet(chain_edges(), directed = FALSE)
  expect_error(centrality_series(undirected, measure = "prestige"),
               class = "dynet_needs_directed")
  expect_error(centrality_series(undirected, measure = "prestige"),
               class = "dynet_bad_input")
  dn <- quiet_dynet(chain_edges())
  expect_error(centrality_series(dn, measure = "participation",
                                 groups = "no_such_attribute"),
               class = "dynet_unknown_attribute")
  expect_error(centrality_series(dn, measure = "participation",
                                 groups = "no_such_attribute"),
               class = "dynet_bad_input")
})

test_that("every malformed call fails with the one parent class", {
  # Invariant over a family of bad inputs: whatever the specific class, the
  # parent is always there.
  dn <- quiet_dynet(chain_edges())
  bad_calls <- list(
    function() centrality_series(dn, measure = "nonsense"),
    function() centrality_series(dn, mode = "sideways"),
    function() centrality_series(dn, damping = 2),
    function() path_centrality(dn, measure = "reach"),
    function() path_centrality(dn, measure = "betweenness",
                               criterion = "foremost"),
    function() edge_centrality(dn, measure = "katz"),
    function() edge_centrality(dn, criterion = "foremost"),
    function() centrality_series(dn, sessions = "bogus"),
    function() path_centrality(dn, criterion = "bogus"),
    function() path_centrality(dn, measure = "efficiency", mode = "all"),
    function() edge_centrality(dn, sessions = "bogus")
  )
  caught <- vapply(bad_calls, function(call) {
    condition <- tryCatch(call(), dynet_bad_input = function(e) e)
    inherits(condition, "dynet_bad_input")
  }, logical(1L))
  expect_true(all(caught))
})
