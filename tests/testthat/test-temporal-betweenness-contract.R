betweenness_values <- function(dn, ...) {
  result <- as.data.frame(dyn_centrality(
    dn, measure = "betweenness", scope = "temporal", ...
  ))
  stats::setNames(result$value, result$node)
}

p10_binary_diamonds <- function(k) {
  from <- to <- character()
  time <- numeric()
  merge <- "M0"
  # Each layer depends on the merge vertex created by its predecessor.
  for (stage in seq_len(k)) {
    left <- paste0("A", stage)
    right <- paste0("B", stage)
    next_merge <- paste0("M", stage)
    from <- c(from, merge, merge, left, right)
    to <- c(to, left, right, next_merge, next_merge)
    time <- c(time, rep(stage, 4L))
    merge <- next_merge
  }
  data.frame(from = from, to = to, time = time)
}

test_that("appearance-DAG helpers count endpoint numerators without expansion", {
  dn <- quiet_dynet(data.frame(
    from = c("S", "S", "A", "B"), to = c("A", "B", "T", "T"),
    time = c(1, 1, 2, 2)
  ))
  enc <- .encode(dn)
  search <- .optimal_path_search(
    enc, match("S", enc$names), 0, "forward", lower = 0, upper = 2
  )
  target <- match("T", enc$names)
  numerator <- .optimal_endpoint_dependency(search, target)
  expected_numerator <- c(S = 0, A = 1, B = 1, T = 0)
  expect_identical(stats::setNames(numerator, enc$names),
                   expected_numerator[enc$names])
  expect_identical(
    stats::setNames(.temporal_betweenness_values(list(search), enc$n),
                    enc$names),
    c(S = 0, A = 1 / 2, B = 1 / 2, T = 0)[enc$names]
  )
})

test_that("temporal betweenness preserves the raw ordered-pair chain scale", {
  chain <- quiet_dynet(data.frame(
    from = c("A", "B", "C", "D"), to = c("B", "C", "D", "E"),
    time = 1:4
  ))
  value <- betweenness_values(chain, start = 0, end = 4)
  expect_identical(unname(value[c("A", "B", "C", "D", "E")]),
                   c(0, 3, 4, 3, 0))
})

test_that("equal and recurrent optimal branches split exact dependency", {
  diamond <- quiet_dynet(data.frame(
    from = c("S", "S", "A", "B"), to = c("A", "B", "T", "T"),
    time = c(1, 1, 2, 2)
  ))
  equal <- betweenness_values(diamond, start = 0, end = 2)
  expect_identical(unname(equal[c("S", "A", "B", "T")]),
                   c(0, 1 / 2, 1 / 2, 0))

  recurrent <- quiet_dynet(data.frame(
    from = c("S", "S", "S", "A", "B"),
    to = c("A", "A", "B", "T", "T"), time = c(0, 1, 1, 2, 2)
  ))
  asymmetric <- betweenness_values(recurrent, start = 0, end = 2)
  expect_equal(unname(asymmetric[c("S", "A", "B", "T")]),
               c(0, 2 / 3, 1 / 3, 0))
})

test_that("dependency is conserved through a three-way merge and suffix", {
  dn <- quiet_dynet(data.frame(
    from = c(rep("S", 3), c("A", "B", "C"), "M"),
    to = c("A", "B", "C", rep("M", 3), "T"),
    time = c(rep(1, 3), rep(2, 3), 3)
  ))
  value <- betweenness_values(dn, start = 0, end = 3)
  expect_equal(unname(value[c("S", "A", "B", "C", "M", "T")]),
               c(0, 2 / 3, 2 / 3, 2 / 3, 4, 0))
  expect_equal(sum(value), 6)
})

test_that("endpoint-specific appearances retain later shorter prefixes", {
  dn <- quiet_dynet(data.frame(
    from = c("S", "A", "S", "X"), to = c("A", "X", "X", "T"),
    time = c(1, 1, 2, 5)
  ))
  value <- betweenness_values(dn, start = 0, end = 5)
  expect_identical(unname(value[c("S", "A", "X", "T")]),
                   c(0, 1, 2, 0))
})

test_that("simultaneous cycles and the shortest-foremost priority add no padding", {
  cycle <- quiet_dynet(data.frame(
    from = c("S", "S", "A", "B", "A", "B"),
    to = c("A", "B", "B", "A", "T", "T"),
    time = c(1, 1, 1, 1, 2, 2)
  ))
  cycle_value <- betweenness_values(cycle, start = 0, end = 2)
  expect_identical(unname(cycle_value[c("S", "A", "B", "T")]),
                   c(0, 1 / 2, 1 / 2, 0))

  priority <- quiet_dynet(data.frame(
    from = c("S", "A", "S"), to = c("A", "T", "T"),
    time = c(1, 2, 3)
  ))
  expect_identical(unname(betweenness_values(
    priority, start = 0, end = 3
  )[["A"]]), 1)
})

test_that("session walls and full-cost winning families govern dependency", {
  wall <- data.frame(
    from = c("S", "A"), to = c("A", "T"), time = c(1, 2),
    session = c("s1", "s2")
  )
  wall_dn <- quiet_dynet(wall, session = "session")
  expect_identical(unname(betweenness_values(
    wall_dn, sessions = "collapse", start = 0, end = 2
  )[c("S", "A", "T")]), c(0, 1, 0))
  expect_identical(unname(betweenness_values(
    wall_dn, sessions = "bounded", start = 0, end = 2
  )[c("S", "A", "T")]), c(0, 0, 0))

  tied <- data.frame(
    from = c("S", "A", "S", "B"), to = c("A", "T", "B", "T"),
    time = c(1, 2, 1, 2), session = c("s1", "s1", "s2", "s2")
  )
  tied_dn <- quiet_dynet(tied, session = "session")
  bounded <- betweenness_values(
    tied_dn, sessions = "bounded", start = 0, end = 2
  )
  expect_identical(unname(bounded[c("S", "A", "B", "T")]),
                   c(0, 1 / 2, 1 / 2, 0))

  separate <- as.data.frame(dyn_centrality(
    tied_dn, measure = "betweenness", scope = "temporal",
    sessions = "separate", start = 0, end = 2
  ))
  s1 <- stats::setNames(separate$value[separate$session == "s1"],
                        separate$node[separate$session == "s1"])
  s2 <- stats::setNames(separate$value[separate$session == "s2"],
                        separate$node[separate$session == "s2"])
  expect_identical(unname(s1[c("S", "A", "B", "T")]), c(0, 1, 0, 0))
  expect_identical(unname(s2[c("S", "A", "B", "T")]), c(0, 0, 1, 0))

  duplicated <- rbind(
    transform(tied[tied$session == "s1", ], session = "s1"),
    transform(tied[tied$session == "s1", ], session = "s2")
  )
  duplicated_dn <- quiet_dynet(duplicated, session = "session")
  expect_identical(unname(betweenness_values(
    duplicated_dn, sessions = "bounded", start = 0, end = 2
  )[["A"]]), 1)

  competition <- quiet_dynet(data.frame(
    from = c("S", "A", "S"), to = c("A", "T", "T"),
    time = c(1, 5, 5), session = c("s1", "s1", "s2")
  ), session = "session")
  expect_identical(unname(betweenness_values(
    competition, sessions = "bounded", start = 0, end = 5
  )[["A"]]), 0)
})

test_that("disconnected additions and duplicate rows do not change raw shares", {
  diamond <- data.frame(
    from = c("S", "S", "A", "B"), to = c("A", "B", "T", "T"),
    time = c(1, 1, 2, 2), weight = c(2, 3, 4, 5)
  )
  base <- betweenness_values(quiet_dynet(diamond), start = 0, end = 2)
  extended <- rbind(diamond, data.frame(
    from = "X", to = "Y", time = 1, weight = 99
  ))
  more <- betweenness_values(quiet_dynet(extended), start = 0, end = 2)
  duplicate <- betweenness_values(
    quiet_dynet(rbind(diamond, diamond[1L, ])), start = 0, end = 2
  )
  expect_identical(unname(base[c("A", "B")]), c(1 / 2, 1 / 2))
  expect_identical(unname(more[c("A", "B")]), unname(base[c("A", "B")]))
  expect_identical(duplicate, base)
})

test_that("interval segmentation and overlap do not multiply dependency", {
  base <- data.frame(
    from = c("S", "A"), to = c("A", "T"),
    start = c(0, 3), end = c(2, 3), weight = c(1, 1)
  )
  split <- data.frame(
    from = c("S", "S", "A"), to = c("A", "A", "T"),
    start = c(0, 1, 3), end = c(1, 2, 3), weight = c(4, 5, 1)
  )
  overlap <- data.frame(
    from = c("S", "S", "A"), to = c("A", "A", "T"),
    start = c(0, 1, 3), end = c(1.5, 2, 3), weight = c(8, 9, 1)
  )
  values <- lapply(list(base, split, overlap), function(spells) {
    betweenness_values(quiet_dynet(spells), start = 0, end = 3)
  })
  expect_true(all(vapply(values, function(value) {
    identical(unname(value[["A"]]), 1)
  }, logical(1L))))
})

test_that("undirected temporal betweenness still uses ordered pairs", {
  staggered <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(1, 2)
  ), directed = FALSE)
  simultaneous <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(1, 1)
  ), directed = FALSE)
  expect_identical(unname(betweenness_values(
    staggered, start = 0, end = 2
  )[["B"]]), 1)
  expect_identical(unname(betweenness_values(
    simultaneous, start = 0, end = 1
  )[["B"]]), 2)
})

test_that("bounds and traversal duration select the dependency family first", {
  dn <- quiet_dynet(data.frame(
    from = c("S", "S", "A", "B"), to = c("A", "B", "T", "T"),
    time = c(1, 2, 4, 4)
  ))
  full <- betweenness_values(dn, start = 0, end = 4)
  late <- betweenness_values(dn, start = 2, end = 4)
  early <- betweenness_values(dn, start = 0, end = 3)
  expect_identical(unname(full[c("A", "B")]), c(1 / 2, 1 / 2))
  expect_identical(unname(late[c("A", "B")]), c(0, 1))
  expect_identical(unname(early[c("A", "B")]), c(0, 0))

  chain <- quiet_dynet(data.frame(
    from = c("S", "A"), to = c("A", "T"), time = c(1, 2)
  ))
  expect_identical(unname(betweenness_values(
    chain, start = 0, end = 2, traversal_time = 0
  )[["A"]]), 1)
  expect_identical(unname(betweenness_values(
    chain, start = 0, end = 2, traversal_time = 1
  )[["A"]]), 0)
})

test_that("betweenness is translation, scale, row, and relabelling invariant", {
  spells <- data.frame(
    from = c("S", "S", "A", "B"), to = c("A", "B", "T", "T"),
    time = c(1, 1, 2, 2)
  )
  base <- betweenness_values(quiet_dynet(spells), start = 0, end = 2)
  reversed <- betweenness_values(
    quiet_dynet(spells[nrow(spells):1L, ]), start = 0, end = 2
  )
  shifted <- betweenness_values(
    quiet_dynet(transform(spells, time = time + 17)), start = 17, end = 19
  )
  scaled <- betweenness_values(
    quiet_dynet(transform(spells, time = time * 3)), start = 0, end = 6
  )
  rename <- c(S = "Q", A = "Z", B = "M", T = "R")
  renamed_spells <- transform(
    spells, from = unname(rename[from]), to = unname(rename[to])
  )
  renamed <- betweenness_values(quiet_dynet(renamed_spells), start = 0, end = 2)
  expect_identical(reversed, base)
  expect_identical(shifted, base)
  expect_identical(scaled, base)
  expect_identical(unname(renamed[unname(rename[names(base)])]), unname(base))
})

test_that("betweenness respects session permutation and reversed transpose", {
  tied <- data.frame(
    from = c("S", "A", "S", "B"), to = c("A", "T", "B", "T"),
    time = c(1, 2, 1, 2), session = c("s1", "s1", "s2", "s2")
  )
  base <- betweenness_values(
    quiet_dynet(tied, session = "session"),
    sessions = "bounded", start = 0, end = 2
  )
  shuffled <- tied[c(4, 2, 1, 3), ]
  shuffled$session <- c(s2 = "right", s1 = "left")[shuffled$session]
  permuted <- betweenness_values(
    quiet_dynet(shuffled, session = "session"),
    sessions = "bounded", start = 0, end = 2
  )
  expect_identical(permuted, base)

  reversed <- transform(
    tied[c("from", "to", "time")],
    from = to, to = from, time = 2 - time
  )
  dual <- betweenness_values(quiet_dynet(reversed), start = 0, end = 2)
  collapsed <- betweenness_values(
    quiet_dynet(tied[c("from", "to", "time")]), start = 0, end = 2
  )
  expect_identical(dual, collapsed)
})

test_that("time scaling includes positive traversal duration", {
  chain <- data.frame(from = c("S", "A"), to = c("A", "T"),
                      time = c(1, 3))
  base <- betweenness_values(
    quiet_dynet(chain), start = 0, end = 4, traversal_time = 1
  )
  scaled <- betweenness_values(
    quiet_dynet(transform(chain, time = time * 3)),
    start = 0, end = 12, traversal_time = 3
  )
  expect_identical(scaled, base)
  expect_identical(unname(base[["A"]]), 1)
})

test_that("large dependency families remain compact and propagate overflow", {
  compact <- quiet_dynet(p10_binary_diamonds(20L))
  value <- betweenness_values(compact, start = 0, end = 20)
  expect_true(all(is.finite(value)))
  expect_gt(value[["M10"]], 0)

  expect_error(
    betweenness_values(
      quiet_dynet(p10_binary_diamonds(54L)), start = 0, end = 54
    ),
    class = "dynet_path_overflow"
  )
})

test_that("singleton, two-node, and all-direct families are zero", {
  singleton <- quiet_dynet(
    data.frame(from = "Q", to = "Q", time = 0), loops = TRUE
  )
  pair <- quiet_dynet(data.frame(from = "A", to = "B", time = 0))
  expect_identical(unname(betweenness_values(
    singleton, start = 0, end = 0
  )), 0)
  expect_identical(unname(betweenness_values(pair, start = 0, end = 0)),
                   c(0, 0))
})

test_that("temporal betweenness publishes scoped mathematical metadata", {
  dn <- quiet_dynet(data.frame(from = "A", to = "B", time = 1))
  result <- dyn_centrality(
    dn, measure = "betweenness", scope = "temporal", start = 0, end = 1
  )
  expect_identical(attr(result, "criterion"), "foremost_then_shortest")
  expect_identical(attr(result, "pair_domain"),
                   "forward_reachable_ordered")
  expect_identical(attr(result, "normalization"), "none")
  expect_identical(attr(result, "path_identity"),
                   "canonical_atom_sequence")

  mixed <- dyn_centrality(
    dn, measure = c("betweenness", "reach"), scope = "temporal"
  )
  expect_null(attr(mixed, "pair_domain"))
  expect_identical(
    attr(mixed, "measure_metadata")$betweenness$normalization, "none"
  )
})
