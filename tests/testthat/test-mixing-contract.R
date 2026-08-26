mixing_cells <- function(result) {
  df <- as.data.frame(result)
  stats::setNames(
    df$value,
    paste(df$from_group, df$to_group, sep = "\r")
  )
}

mixing_fixture <- function() {
  list(
    spells = data.frame(
      from = c("a1", "a1", "a2", "b1", "b1"),
      to = c("a2", "b1", "b1", "a1", "b2"), time = 0
    ),
    nodes = data.frame(
      name = c("a1", "a2", "b1", "b2"),
      group = c("A", "A", "B", "B")
    )
  )
}

test_that("directed mixing is the complete ordered binary-dyad table", {
  fixture <- mixing_fixture()
  result <- mixing(
    quiet_dynet(fixture$spells, nodes = fixture$nodes), "group",
    start = 0, end = 0, window = 0
  )
  cells <- mixing_cells(result)
  expect_identical(
    cells[c("A\rA", "A\rB", "B\rA", "B\rB")],
    c("A\rA" = 1, "A\rB" = 2, "B\rA" = 1, "B\rB" = 1)
  )
  table <- matrix(cells, 2L, 2L, dimnames = list(c("A", "B"), c("A", "B")))
  expect_identical(rowSums(table), c(A = 3, B = 2))
  expect_identical(colSums(table), c(A = 2, B = 3))
  expect_identical(sum(cells), 5)
})

test_that("undirected mixing emits one unordered triangle with stub margins", {
  fixture <- mixing_fixture()
  result <- mixing(
    quiet_dynet(fixture$spells, nodes = fixture$nodes, directed = FALSE),
    "group", start = 0, end = 0, window = 0
  )
  df <- as.data.frame(result)
  cells <- mixing_cells(result)
  expect_identical(cells[c("A\rA", "A\rB", "B\rB")],
                   c("A\rA" = 1, "A\rB" = 2, "B\rB" = 1))
  expect_identical(sum(cells), 4)
  expect_identical(c(A = 2 * cells[["A\rA"]] + cells[["A\rB"]],
                     B = 2 * cells[["B\rB"]] + cells[["A\rB"]]),
                   c(A = 4, B = 4))
  expect_true(all(grepl(" -- ", df$measure, fixed = TRUE)))
  expect_false(any(duplicated(paste(df$to_group, df$from_group))))
})

test_that("the mixing kernel retains one loop and collapses parallel spells", {
  directed <- matrix(c(2, 0, 3, 1), 2L, 2L)
  pairs <- expand.grid(from = 1:2, to = 1:2)
  expect_identical(
    .mixing_counts(directed, c(1L, 2L), pairs, directed = TRUE),
    c(1, 0, 1, 1)
  )

  undirected <- pmax(directed, t(directed))
  upper_pairs <- pairs[pairs$from <= pairs$to, , drop = FALSE]
  expect_identical(
    .mixing_counts(undirected, c(1L, 2L), upper_pairs, directed = FALSE),
    c(1, 1, 1)
  )
})

test_that("retained loops are one mixing edge, including for a singleton", {
  nodes <- data.frame(name = "a", group = "A")
  for (directed in c(TRUE, FALSE)) {
    result <- mixing(
      quiet_dynet(data.frame(from = "a", to = "a", time = 0),
                  nodes = nodes, directed = directed, loops = TRUE),
      "group", start = 0, end = 0, window = 0
    )
    expect_identical(mixing_cells(result)[["A\rA"]], 1)
  }
})

test_that("missing values have a collision-safe explicit group level", {
  nodes <- data.frame(
    name = c("a", "b", "c", "d"),
    group = c("A", NA, "(missing)", "B")
  )
  spells <- data.frame(
    from = c("a", "b", "d", "c"), to = c("b", "d", "a", "a"), time = 0
  )
  result <- mixing(
    quiet_dynet(spells, nodes = nodes), "group",
    start = 0, end = 0, window = 0
  )
  df <- as.data.frame(result)
  expect_true(all(c("(missing)", "(missing NA)") %in%
                    c(df$from_group, df$to_group)))
  cells <- mixing_cells(result)
  expect_identical(cells[["A\r(missing NA)"]], 1)
  expect_identical(cells[["(missing NA)\rB"]], 1)
  expect_identical(cells[["B\rA"]], 1)
  expect_identical(cells[["(missing)\rA"]], 1)
})

test_that("group display delimiters are never parsed back into columns", {
  nodes <- data.frame(
    name = c("a", "b"), group = c("A -> inner", "B -- inner")
  )
  result <- expect_no_warning(mixing(
    quiet_dynet(data.frame(from = "a", to = "b", time = 0), nodes = nodes),
    "group", start = 0, end = 0, window = 0
  ))
  df <- subset(as.data.frame(result), value == 1)
  expect_identical(df$from_group, "A -> inner")
  expect_identical(df$to_group, "B -- inner")
})

test_that("distinct structured cells always have distinct display labels", {
  nodes <- data.frame(
    name = c("a", "b", "c", "d"),
    group = c("A", "B -> C", "A -> B", "C")
  )
  spells <- data.frame(from = c("a", "c"), to = c("b", "d"), time = 0)
  result <- mixing(
    quiet_dynet(spells, nodes = nodes), "group",
    start = 0, end = 0, window = 0
  )
  active <- subset(as.data.frame(result), value == 1)
  expect_identical(nrow(active), 2L)
  expect_identical(length(unique(active$measure)), 2L)
  summarized <- subset(summary(result), mean == 1)
  expect_identical(nrow(summarized), 2L)
  expect_true(all(summarized$n == 1L))
})

test_that("mixing is binary across duplicates, overlaps, splits, and weights", {
  base <- data.frame(
    from = "a", to = "b", start = 0, end = 4, weight = 7
  )
  represented <- rbind(
    base, base,
    data.frame(from = "a", to = "b", start = 0, end = 2, weight = 2),
    data.frame(from = "a", to = "b", start = 2, end = 4, weight = 50),
    data.frame(from = "a", to = "b", start = 1, end = 3, weight = 100)
  )
  nodes <- data.frame(name = c("a", "b"), group = c("A", "B"))
  args <- list(attribute = "group", start = 1, end = 1, window = 1)
  one <- do.call(mixing, c(list(
    dn = quiet_dynet(base, nodes = nodes, weight = "weight")
  ), args))
  many <- do.call(mixing, c(list(
    dn = quiet_dynet(represented, nodes = nodes, weight = "weight")
  ), args))
  expect_identical(mixing_cells(many), mixing_cells(one))
  expect_identical(mixing_cells(many)[["A\rB"]], 1)
})

test_that("mixing uses interval overlap and exact point-event boundaries", {
  spells <- data.frame(
    from = rep("a", 4), to = c("b", "c", "d", "e"),
    start = c(0, 1, 2, 3), end = c(3, 1, 2, 4)
  )
  nodes <- data.frame(
    name = c("a", "b", "c", "d", "e"),
    group = c("A", "B", "B", "B", "B")
  )
  window <- mixing(
    quiet_dynet(spells, nodes = nodes), "group",
    start = 1, end = 1, window = 1
  )
  point <- mixing(
    quiet_dynet(spells, nodes = nodes), "group",
    start = 2, end = 2, window = 0
  )
  terminus <- mixing(
    quiet_dynet(spells, nodes = nodes), "group",
    start = 3, end = 3, window = 0
  )
  expect_identical(mixing_cells(window)[["A\rB"]], 2)
  expect_identical(mixing_cells(point)[["A\rB"]], 2)
  expect_identical(mixing_cells(terminus)[["A\rB"]], 1)
})

test_that("empty bins retain complete zero support", {
  fixture <- mixing_fixture()
  for (directed in c(TRUE, FALSE)) {
    result <- mixing(
      quiet_dynet(fixture$spells, nodes = fixture$nodes,
                  directed = directed),
      "group", start = 10, end = 10, window = 0
    )
    expect_identical(nrow(result), if (directed) 4L else 3L)
    expect_true(all(result$value == 0))
  }
})

test_that("bounded is a binary calendar union and separate is session local", {
  spells <- data.frame(
    from = c("a", "a"), to = c("b", "b"), time = c(0, 0),
    session = c("s1", "s2")
  )
  nodes <- data.frame(name = c("a", "b"), group = c("A", "B"))
  dn <- quiet_dynet(spells, nodes = nodes, session = "session")
  collapsed <- mixing(dn, "group", sessions = "collapse",
                          start = 0, end = 0, window = 0)
  bounded <- mixing(dn, "group", sessions = "bounded",
                        start = 0, end = 0, window = 0)
  separate <- as.data.frame(mixing(
    dn, "group", sessions = "separate", start = 0, end = 0, window = 0
  ))
  expect_identical(mixing_cells(bounded), mixing_cells(collapsed))
  expect_identical(mixing_cells(bounded)[["A\rB"]], 1)
  expect_identical(separate$value[
    separate$from_group == "A" & separate$to_group == "B"
  ], c(1, 1))

  permuted <- spells[c(2, 1), ]
  permuted$session <- c("later", "earlier")
  expect_identical(
    mixing_cells(mixing(
      quiet_dynet(permuted, nodes = nodes, session = "session"), "group",
      sessions = "bounded", start = 0, end = 0, window = 0
    )),
    mixing_cells(bounded)
  )
})

test_that("separate mixing keeps fixed support for session-absent groups", {
  spells <- data.frame(
    from = c("a", "c"), to = c("b", "a"), time = c(0, 0),
    session = c("s1", "s2")
  )
  nodes <- data.frame(
    name = c("a", "b", "c"), group = factor(
      c("A", "B", "C"), levels = c("C", "B", "A")
    )
  )
  result <- as.data.frame(mixing(
    quiet_dynet(spells, nodes = nodes, session = "session"), "group",
    sessions = "separate", start = 0, end = 0, window = 0
  ))
  session_rows <- table(result$session)
  expect_identical(as.integer(session_rows), c(9L, 9L))
  expect_identical(names(session_rows), c("s1", "s2"))
  s1 <- subset(result, session == "s1")
  expect_true(all(s1$value[s1$from_group == "C" | s1$to_group == "C"] == 0))
  expect_identical(unique(s1$from_group), c("A", "B", "C"))
})

test_that("mixing transforms by its table units", {
  fixture <- mixing_fixture()
  value <- function(spells, nodes = fixture$nodes, directed = TRUE,
                    start = 0, end = 0) {
    mixing_cells(mixing(
      quiet_dynet(spells, nodes = nodes, directed = directed), "group",
      start = start, end = end, window = 0
    ))
  }
  base <- value(fixture$spells)
  expect_identical(value(fixture$spells[5:1, ]), base)
  expect_identical(value(transform(fixture$spells, time = time + 17),
                         start = 17, end = 17), base)
  expect_identical(value(transform(fixture$spells, time = time * 3),
                         start = 0, end = 0), base)

  reversed <- transform(fixture$spells, from = to, to = from)
  reverse_cells <- value(reversed)
  base_df <- do.call(rbind, strsplit(names(base), "\r", fixed = TRUE))
  transpose_key <- paste(base_df[, 2L], base_df[, 1L], sep = "\r")
  expect_identical(unname(reverse_cells[names(base)]),
                   unname(base[transpose_key]))
  expect_identical(value(reversed, directed = FALSE),
                   value(fixture$spells, directed = FALSE))

  vertex_map <- c(a1 = "q", a2 = "x", b1 = "m", b2 = "z")
  renamed_spells <- transform(
    fixture$spells, from = unname(vertex_map[from]), to = unname(vertex_map[to])
  )
  renamed_nodes <- transform(
    fixture$nodes, name = unname(vertex_map[name])
  )
  expect_identical(value(renamed_spells, renamed_nodes), base)

  relabelled_nodes <- transform(
    fixture$nodes, group = ifelse(group == "A", "Z", "C")
  )
  relabelled <- value(fixture$spells, relabelled_nodes)
  relabelled_keys <- do.call(rbind, strsplit(names(relabelled), "\r", fixed = TRUE))
  inverse_group <- c(C = "B", Z = "A")
  names(relabelled) <- paste(
    inverse_group[relabelled_keys[, 1L]],
    inverse_group[relabelled_keys[, 2L]], sep = "\r"
  )
  expect_identical(relabelled[names(base)], base)
})

test_that("mixing publishes its mathematical conventions", {
  fixture <- mixing_fixture()
  directed <- mixing(
    quiet_dynet(fixture$spells, nodes = fixture$nodes), "group",
    start = 0, end = 0, window = 0
  )
  undirected <- mixing(
    quiet_dynet(fixture$spells, nodes = fixture$nodes, directed = FALSE),
    "group", start = 0, end = 0, window = 0
  )
  expect_identical(attr(directed, "unit"), "active_binary_dyads")
  expect_identical(attr(directed, "pair_domain"), "directed_ordered")
  expect_identical(attr(undirected, "pair_domain"), "undirected_unordered")
  expect_identical(attr(directed, "normalization"), "none")
  expect_identical(attr(directed, "weights"), "ignored")
  expect_identical(attr(directed, "loops"), "retained_once")
  expect_identical(attr(directed, "missing_group"), "explicit_level")
  expect_identical(attr(directed, "session_aggregation"),
                   "binary_calendar_union")
})
