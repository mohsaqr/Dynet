reach_contract_rows <- function(x, measure, nodes, session = NULL) {
  out <- as.data.frame(x)
  out <- out[out$measure == measure, , drop = FALSE]
  if (!is.null(session)) {
    out <- out[out$session == session, , drop = FALSE]
  }
  out[match(nodes, out$node), , drop = FALSE]
}

reach_contract_diamond <- function() {
  data.frame(
    from = c("A", "A", "B", "C"),
    to = c("B", "C", "D", "D"),
    time = c(1, 1, 2, 2), stringsAsFactors = FALSE
  )
}

test_that("the default reachability call remains proportion-only", {
  dn <- quiet_dynet(reach_contract_diamond())
  default <- dyn_reachability(dn)
  explicit <- dyn_reachability(dn, measure = "reach")
  out <- as.data.frame(default)

  expect_identical(default, explicit)
  expect_identical(names(out), c("node", "measure", "value"))
  expect_identical(
    out$measure,
    rep(c("forward_reach", "backward_reach"), each = 4L)
  )
  expect_equal(out$value, c(1, 1 / 3, 1 / 3, 0,
                            0, 1 / 3, 1 / 3, 1))
  expect_s3_class(default, "dynet_metric")
  # `measure` and `plot` were both appended after the original arguments, so a
  # positional call written before either existed still means what it did.
  expect_identical(tail(names(formals(dyn_reachability)), 2L),
                   c("measure", "plot"))
})

test_that("reach counts and proportions are distinct ordered measures", {
  dn <- quiet_dynet(reach_contract_diamond())
  result <- dyn_reachability(
    dn, direction = "both", measure = c("reach_count", "reach")
  )
  out <- as.data.frame(result)

  expect_identical(out$node, rep(c("A", "B", "C", "D"), 4L))
  expect_identical(out$measure, rep(c(
    "forward_reach_count", "forward_reach",
    "backward_reach_count", "backward_reach"
  ), each = 4L))
  expect_equal(out$value, c(
    3, 1, 1, 0,
    1, 1 / 3, 1 / 3, 0,
    0, 1, 1, 3,
    0, 1 / 3, 1 / 3, 1
  ))
  expect_type(out$value, "double")

  reversed <- as.data.frame(dyn_reachability(
    dn, direction = "forward", measure = c("reach", "reach_count")
  ))
  expect_identical(
    reversed$measure,
    rep(c("forward_reach", "forward_reach_count"), each = 4L)
  )
  expect_equal(reversed$value, c(1, 1 / 3, 1 / 3, 0, 3, 1, 1, 0))
})

test_that("a singleton and isolates have finite source-excluding reach", {
  singleton <- quiet_dynet(
    data.frame(from = "A", to = "A", time = 1), loops = TRUE
  )
  singleton_reach <- as.data.frame(dyn_reachability(
    singleton, measure = c("reach_count", "reach")
  ))
  singleton_centrality <- as.data.frame(dyn_centrality(
    singleton, measure = c("reach_count", "reach"), scope = "temporal"
  ))
  expect_equal(singleton_reach$value, rep(0, 4L))
  expect_equal(singleton_centrality$value, c(0, 0))
  expect_true(all(is.finite(singleton_reach$value)))
  expect_true(all(is.finite(singleton_centrality$value)))

  isolate_dn <- quiet_dynet(
    data.frame(
      from = c("A", "C"), to = c("B", "D"), time = c(1, 5),
      stringsAsFactors = FALSE
    )
  )
  isolates <- dyn_reachability(
    isolate_dn, start = 0, end = 1,
    measure = c("reach_count", "reach")
  )
  nodes <- c("A", "B", "C", "D")
  expect_equal(
    reach_contract_rows(
      isolates, "forward_reach_count", nodes
    )$value,
    c(1, 0, 0, 0)
  )
  expect_equal(
    reach_contract_rows(isolates, "forward_reach", nodes)$value,
    c(1 / 3, 0, 0, 0)
  )
  expect_equal(
    reach_contract_rows(
      isolates, "backward_reach_count", nodes
    )$value,
    c(0, 1, 0, 0)
  )
  expect_equal(
    reach_contract_rows(isolates, "backward_reach", nodes)$value,
    c(0, 1 / 3, 0, 0)
  )
})

test_that("temporal reach centrality shares the reachability reducer", {
  dn <- quiet_dynet(reach_contract_diamond())
  reachability <- as.data.frame(dyn_reachability(
    dn, direction = "forward", start = 1, end = 2,
    measure = c("reach_count", "reach")
  ))
  centrality <- as.data.frame(dyn_centrality(
    dn, measure = c("reach_count", "reach"), scope = "temporal",
    start = 1, end = 2
  ))

  expect_identical(centrality$measure,
                   rep(c("reach_count", "reach"), each = 4L))
  expect_equal(centrality$node, reachability$node)
  expect_equal(
    centrality$value,
    reachability$value
  )
})

test_that("closed path bounds determine both reach directions", {
  dn <- quiet_dynet(reach_contract_diamond())
  full <- dyn_reachability(
    dn, direction = "both", start = 1, end = 2,
    measure = "reach_count"
  )
  late <- dyn_reachability(
    dn, direction = "both", start = 1 + 1e-6, end = 2,
    measure = "reach_count"
  )
  early_end <- dyn_reachability(
    dn, direction = "both", start = 1, end = 1,
    measure = "reach_count"
  )
  nodes <- c("A", "B", "C", "D")

  expect_equal(
    reach_contract_rows(full, "forward_reach_count", nodes)$value,
    c(3, 1, 1, 0)
  )
  expect_equal(
    reach_contract_rows(full, "backward_reach_count", nodes)$value,
    c(0, 1, 1, 3)
  )
  expect_equal(
    reach_contract_rows(late, "forward_reach_count", nodes)$value,
    c(0, 1, 1, 0)
  )
  expect_equal(
    reach_contract_rows(late, "backward_reach_count", nodes)$value,
    c(0, 0, 0, 2)
  )
  expect_equal(
    reach_contract_rows(early_end, "forward_reach_count", nodes)$value,
    c(2, 0, 0, 0)
  )
  expect_equal(
    reach_contract_rows(early_end, "backward_reach_count", nodes)$value,
    c(0, 1, 1, 0)
  )
})

test_that("reach inherits positive traversal duration", {
  dn <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    start = c(0, 2), end = c(2, 4), stringsAsFactors = FALSE
  ))
  exact <- dyn_reachability(
    dn, direction = "both", start = 0, end = 4,
    traversal_time = 2, measure = c("reach_count", "reach")
  )
  too_slow <- dyn_reachability(
    dn, direction = "both", start = 0, end = 4,
    traversal_time = 2.01, measure = "reach_count"
  )
  nodes <- c("A", "B", "C")

  expect_equal(
    reach_contract_rows(exact, "forward_reach_count", nodes)$value,
    c(2, 1, 0)
  )
  expect_equal(
    reach_contract_rows(exact, "forward_reach", nodes)$value,
    c(1, 1 / 2, 0)
  )
  expect_equal(
    reach_contract_rows(exact, "backward_reach_count", nodes)$value,
    c(0, 1, 2)
  )
  expect_equal(
    reach_contract_rows(exact, "backward_reach", nodes)$value,
    c(0, 1 / 2, 1)
  )
  expect_true(all(as.data.frame(too_slow)$value == 0))

  centrality <- dyn_centrality(
    dn, measure = c("reach_count", "reach"), scope = "temporal",
    start = 0, end = 4, traversal_time = 2
  )
  expect_equal(
    as.data.frame(centrality)$value,
    c(2, 1, 0, 1, 1 / 2, 0)
  )
})

test_that("finite unattained backward suprema still count", {
  dn <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 5,
    stringsAsFactors = FALSE
  ))
  paths <- paths(
    dn, from = "B", direction = "backward", start = 0, end = 10
  )
  actor <- as.data.frame(paths)
  actor <- actor[actor$node == "A", , drop = FALSE]
  reach <- dyn_reachability(
    dn, direction = "backward", start = 0, end = 10,
    measure = c("reach_count", "reach")
  )

  expect_true(actor$reachable)
  expect_false(actor$attained)
  expect_equal(
    reach_contract_rows(reach, "backward_reach_count", c("A", "B"))$value,
    c(0, 1)
  )
  expect_equal(
    reach_contract_rows(reach, "backward_reach", c("A", "B"))$value,
    c(0, 1)
  )

  boundary_only <- quiet_dynet(data.frame(
    from = "A", to = "B", start = 0, end = 2,
    stringsAsFactors = FALSE
  ))
  excluded <- dyn_reachability(
    boundary_only, direction = "backward", start = 2, end = 5,
    measure = c("reach_count", "reach")
  )
  expect_equal(as.data.frame(excluded)$value, rep(0, 4L))
})

test_that("reach counts obey collapse, bounded, and separate sessions", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(1, 2),
    session = c("s1", "s2"), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(
    spells, session = "session",
    nodes = data.frame(name = c("A", "B", "C"))
  )
  nodes <- c("A", "B", "C")
  collapsed <- dyn_reachability(
    dn, direction = "both", sessions = "collapse", start = 0, end = 2,
    measure = c("reach_count", "reach")
  )
  bounded <- dyn_reachability(
    dn, direction = "both", sessions = "bounded", start = 0, end = 2,
    measure = c("reach_count", "reach")
  )
  separate <- dyn_reachability(
    dn, direction = "both", sessions = "separate", start = 0, end = 2,
    measure = c("reach_count", "reach")
  )

  expect_equal(
    reach_contract_rows(collapsed, "forward_reach_count", nodes)$value,
    c(2, 1, 0)
  )
  expect_equal(
    reach_contract_rows(collapsed, "backward_reach_count", nodes)$value,
    c(0, 1, 2)
  )
  expect_equal(
    reach_contract_rows(bounded, "forward_reach_count", nodes)$value,
    c(1, 1, 0)
  )
  expect_equal(
    reach_contract_rows(bounded, "backward_reach_count", nodes)$value,
    c(0, 1, 1)
  )

  separate_frame <- as.data.frame(separate)
  expect_identical(unique(separate_frame$session), c("s1", "s2"))
  expect_identical(
    separate_frame$measure[separate_frame$session == "s1"],
    rep(c(
      "forward_reach_count", "forward_reach",
      "backward_reach_count", "backward_reach"
    ), each = 3L)
  )
  expect_equal(
    reach_contract_rows(
      separate, "forward_reach_count", nodes, "s1"
    )$value,
    c(1, 0, 0)
  )
  expect_equal(
    reach_contract_rows(separate, "forward_reach", nodes, "s1")$value,
    c(1 / 2, 0, 0)
  )
  expect_equal(
    reach_contract_rows(
      separate, "backward_reach_count", nodes, "s2"
    )$value,
    c(0, 0, 1)
  )
  expect_equal(
    reach_contract_rows(separate, "backward_reach", nodes, "s2")$value,
    c(0, 0, 1 / 2)
  )

  duplicated <- quiet_dynet(data.frame(
    from = c("A", "A"), to = c("B", "B"), time = c(1, 2),
    session = c("s1", "s2"), stringsAsFactors = FALSE
  ), session = "session")
  duplicate_reach <- dyn_reachability(
    duplicated, direction = "forward", sessions = "bounded",
    start = 0, end = 2, measure = "reach_count"
  )
  expect_equal(
    reach_contract_rows(
      duplicate_reach, "forward_reach_count", c("A", "B")
    )$value,
    c(1, 0)
  )
})

test_that("reachability and temporal centrality agree in every session mode", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(1, 2),
    session = c("s1", "s2"), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(
    spells, session = "session",
    nodes = data.frame(name = c("A", "B", "C"))
  )

  invisible(lapply(c("collapse", "bounded", "separate"), function(mode) {
    reach <- as.data.frame(dyn_reachability(
      dn, direction = "forward", sessions = mode, start = 0, end = 2,
      measure = c("reach_count", "reach")
    ))
    centrality <- as.data.frame(dyn_centrality(
      dn, measure = c("reach_count", "reach"), scope = "temporal",
      sessions = mode, start = 0, end = 2
    ))
    reach$measure <- sub("^forward_", "", reach$measure)
    expect_equal(centrality, reach)
  }))
})

test_that("an out-of-window separate session returns complete zero rows", {
  spells <- data.frame(
    from = c("A", "B"), to = c("B", "C"), time = c(1, 10),
    session = c("early", "late"), stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")
  reach <- dyn_reachability(
    dn, direction = "forward", sessions = "separate", start = 5,
    measure = c("reach_count", "reach")
  )
  early <- as.data.frame(reach)
  early <- early[early$session == "early", , drop = FALSE]

  expect_equal(nrow(early), 2L * 3L)
  expect_true(all(early$value == 0))
  expect_equal(
    reach_contract_rows(reach, "forward_reach_count", c("A", "B", "C"),
                        "late")$value,
    c(0, 1, 0)
  )
  expect_equal(
    reach_contract_rows(reach, "forward_reach", c("A", "B", "C"),
                        "late")$value,
    c(0, 1 / 2, 0)
  )
})

test_that("reach measure validation is classed", {
  dn <- quiet_dynet(reach_contract_diamond())

  expect_error(
    dyn_reachability(dn, measure = "degree"),
    class = "dynet_unknown_measure"
  )
  expect_error(
    dyn_reachability(dn, measure = character()),
    class = "dynet_bad_input"
  )
  expect_error(
    dyn_reachability(dn, measure = 1),
    class = "dynet_bad_input"
  )
  expect_error(
    dyn_reachability(dn, measure = c("reach", NA_character_)),
    class = "dynet_bad_input"
  )
  expect_error(
    dyn_centrality(
      dn, measure = c("reach_count", NA_character_), scope = "temporal"
    ),
    class = "dynet_bad_input"
  )
  expect_no_error(
    dyn_centrality(
      dn, measure = c("reach_count", "closeness"), scope = "temporal",
      start = 1, end = 2
    )
  )
})
