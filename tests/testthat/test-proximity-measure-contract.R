# The proximity view reads one centrality per slice through the same kernels
# as centrality_series(); these pin the measure contract of that view.

test_that("a measure the view cannot read is refused by class", {
  dn <- quiet_dynet(school_contacts)
  expect_error(plot(dn, type = "proximity", measure = c("degree", "strength"),
                    networks = FALSE),
               class = "dynet_bad_input")
  expect_error(plot(dn, type = "proximity", measure = "participation",
                    networks = FALSE),
               class = "dynet_unknown_measure")
  expect_error(plot(dn, type = "proximity", measure = "participation",
                    networks = FALSE),
               class = "dynet_bad_input")
  undirected <- quiet_dynet(school_contacts, directed = FALSE)
  expect_error(plot(undirected, type = "proximity", measure = "prestige",
                    networks = FALSE),
               class = "dynet_bad_input")
})

test_that("proximity strength reads tie weights, not spell counts", {
  edges <- school_contacts
  edges$weight <- 1
  light <- quiet_dynet(edges)
  edges$weight <- 3
  heavy <- quiet_dynet(edges)
  # Strength is linear in the weights; degree ignores them.
  strength_light <- .proximity_slices(light, "strength", slices = 6L)$weight
  strength_heavy <- .proximity_slices(heavy, "strength", slices = 6L)$weight
  expect_equal(strength_heavy, 3 * strength_light)
  expect_equal(.proximity_slices(heavy, "degree", slices = 6L)$weight,
               .proximity_slices(light, "degree", slices = 6L)$weight)
})

test_that("proximity strength agrees with centrality_series on the same grid", {
  dn <- quiet_dynet(transform(school_contacts, weight = seq_along(from)))
  width <- 7
  slices <- .proximity_slices(dn, "strength", slices = NULL, window = width)
  series <- as.data.frame(centrality_series(dn, measure = "strength",
                                            window = width))
  expected <- vapply(slices$times, function(at) {
    block <- series[series$time == at, ]
    block$value[match(slices$names, block$node)]
  }, numeric(length(slices$names)))
  expect_equal(slices$weight, unname(expected))
})
