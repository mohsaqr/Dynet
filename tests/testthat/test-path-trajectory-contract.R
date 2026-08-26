# Contract for the temporal trajectory tree ported from `transitiontrees`.
# The equivalence blocks below check that the ported prefix-tree construction
# and leaf placement reproduce the original implementation exactly, so the
# plot rests on proven machinery rather than fresh geometry.

.fixed_sequences <- function() {
  list(c("A", "B", "C"), c("A", "B", "C"), c("A", "B", "D"),
       c("A", "E"), c("A", "E"), c("A", "E"))
}

.school_paths <- function() {
  paths(dynet(school_contacts), from = "Ana")
}

# ---- structural equivalence with transitiontrees -------------------------

test_that("the ported prefix tree matches transitiontrees node for node", {
  skip_if_not_installed("transitiontrees")
  seqs <- .fixed_sequences()
  tree <- transitiontrees::context_tree(
    seqs, max_depth = 2L, min_count = 1L
  )
  reference <- getFromNamespace(".trajectory_data", "transitiontrees")(
    tree, min_count = 1L
  )
  ported <- .path_prefix_tree(seqs, min_count = 1L)

  keys <- c("node", "parent", "depth", "count", "last")
  tidy <- function(d) {
    d <- d[order(d$node), keys, drop = FALSE]
    rownames(d) <- NULL
    d$depth <- as.integer(d$depth)
    d$count <- as.integer(d$count)
    d
  }
  expect_identical(tidy(ported), tidy(reference))
})

test_that("counts after pruning match transitiontrees, orphans included", {
  skip_if_not_installed("transitiontrees")
  seqs <- .fixed_sequences()
  tree <- transitiontrees::context_tree(seqs, max_depth = 2L, min_count = 1L)
  trajectory_data <- getFromNamespace(".trajectory_data", "transitiontrees")

  compare <- function(min_count) {
    reference <- trajectory_data(tree, min_count = min_count)
    ported <- .path_prefix_tree(seqs, min_count = min_count)
    expect_setequal(ported$node, reference$node)
    at <- match(ported$node, reference$node)
    expect_identical(as.integer(ported$count), as.integer(reference$count[at]))
    expect_identical(ported$parent, reference$parent[at])
  }
  lapply(c(1L, 2L, 3L), compare)

  # Pruning is monotone and never leaves a node without its parent.
  sizes <- vapply(1:3, \(k) nrow(.path_prefix_tree(seqs, k)), numeric(1L))
  expect_true(all(diff(sizes) <= 0))
  kept <- .path_prefix_tree(seqs, min_count = 3L)
  expect_true(all(is.na(kept$parent) | kept$parent %in% kept$node))
})

test_that("leaf placement reproduces the transitiontrees layout", {
  skip_if_not_installed("transitiontrees")
  seqs <- .fixed_sequences()
  tree <- transitiontrees::context_tree(seqs, max_depth = 2L, min_count = 1L)
  built <- ggplot2::ggplot_build(
    transitiontrees::plot_trajectories(tree, measure = "frequency",
                                       min_count = 1L)
  )
  reference <- built$data[[4L]][, c("label", "x", "y")]

  placed <- .path_tree_branches(.path_prefix_tree(seqs, min_count = 1L))
  placed <- placed[placed$node != "(start)", , drop = FALSE]
  at <- match(reference$label, placed$last)

  expect_identical(as.numeric(placed$depth[at]), as.numeric(reference$x))
  # The port stacks the same leaves and then flips the canvas so the first
  # route reads at the top, so placement is the reference under one reversal.
  flipped <- max(placed$branch) + 1 - placed$branch[at]
  expect_equal(flipped, reference$y, tolerance = 1e-12)
})

test_that("the plot keeps the horizontal phylogram's layer grammar", {
  skip_if_not_installed("transitiontrees")
  seqs <- .fixed_sequences()
  tree <- transitiontrees::context_tree(seqs, max_depth = 2L, min_count = 1L)
  reference <- vapply(
    stats::setNames(plot(tree, style = "horizontal")$layers, NULL),
    \(layer) class(layer$geom)[[1L]], character(1L)
  )
  ported <- vapply(
    plot_path_trajectories(.school_paths())$layers,
    \(layer) class(layer$geom)[[1L]], character(1L)
  )
  # Branches, node points, node labels, root point, root label.
  expect_identical(unname(ported), unname(reference))
  expect_identical(unname(ported),
                   c("GeomPath", "GeomPoint", "GeomText",
                     "GeomPoint", "GeomText"))
})

test_that("a frequency fill does not print the size legend twice", {
  paths <- .school_paths()
  guide_of <- function(measure) {
    scales <- plot_path_trajectories(paths, measure = measure)$scales$scales
    fill <- Filter(\(s) identical(s$aesthetics, "fill"), scales)
    fill[[1L]]$guide
  }
  expect_identical(guide_of("frequency"), "none")
  expect_identical(guide_of("time"), "colourbar")
})

# ---- temporal contract ---------------------------------------------------

test_that("no optimal route is lost by the tree", {
  paths <- .school_paths()
  reported <- sum(as.data.frame(paths)$n_paths)
  tree <- path_trajectories(paths)
  # The synthetic root is dropped when it has a single child, so the anchor
  # itself is the root and carries every route.
  expect_identical(as.numeric(tree$count[[1L]]), as.numeric(reported))
  expect_identical(tree$vertex[[1L]], "Ana")
  expect_identical(tree$depth[[1L]], 0L)
  expect_false(any(tree$node == "(start)"))
  expect_true(is.na(tree$parent[[1L]]))
})

test_that("the synthetic root is kept only when it really branches", {
  # One child: the root is clutter, spending a hop and pushing the anchor to
  # hop 1 when it is hop 0.
  forward <- path_trajectories(.school_paths())
  expect_false(any(forward$node == "(start)"))
  expect_identical(min(forward$depth), 0L)

  # Several children, one per session: the root is a real branching point.
  dn <- dynet(data.frame(
    from = c("A", "B", "A", "B"), to = c("B", "C", "B", "C"),
    start = c(0, 1, 0, 1), end = c(1, 2, 1, 2),
    term = c("t1", "t1", "t2", "t2")
  ), session = "term")
  sessioned <- path_trajectories(paths(dn, from = "A",
                                          sessions = "separate"))
  expect_true(any(sessioned$node == "(start)"))
  expect_identical(sum(sessioned$parent %in% "(start)"), 2L)
})

test_that("branch colour is indexed on children, not on drawn nodes", {
  # Dropping the root leaves the anchor parentless, so the drawn body and the
  # edge subset differ by one row. Indexing the wrong one shifted every branch
  # colour: an n=1 branch was drawn with an n=3 branch's colour.
  paths <- .school_paths()
  tree <- path_trajectories(paths)
  built <- ggplot2::ggplot_build(plot_path_trajectories(paths))
  edges <- built$data[[1L]]
  children <- tree[!is.na(tree$parent), , drop = FALSE]

  expect_identical(length(unique(edges$group)), nrow(children))
  # Each polyline carries one linewidth, and it must be its own child's count.
  widths <- vapply(split(edges$linewidth, edges$group), \(v) v[[1L]],
                   numeric(1L))
  expect_identical(order(unname(widths)), order(children$count))
})

test_that("a vertex repeats under distinct temporal histories", {
  tree <- path_trajectories(.school_paths())
  jonas <- tree[tree$vertex %in% "Jonas", , drop = FALSE]
  # Ben's three optimal routes share the vertex sequence Ana -> Jonas ->
  # Kira -> Ben and differ only in when the Jonas hop fires. Keying nodes on
  # the vertex name alone would merge them and lose two routes.
  expect_gt(nrow(jonas), 1L)
  expect_identical(anyDuplicated(jonas$time), 0L)
  expect_identical(anyDuplicated(tree$node), 0L)
})

test_that("branch counts and probabilities are internally consistent", {
  tree <- path_trajectories(.school_paths())
  child_total <- vapply(tree$node, \(nd) sum(tree$count[tree$parent %in% nd]),
                        numeric(1L))
  # A parent carries at least the routes that continue past it.
  expect_true(all(child_total <= tree$count))
  expect_true(all(tree$probability > 0 & tree$probability <= 1,
                  na.rm = TRUE))
  expect_true(is.na(tree$probability[[1L]]))
  expect_true(all(diff(sort(tree$depth)) >= 0))
})

test_that("a backward family is rooted at the queried target", {
  paths <- paths(dynet(school_contacts), from = "Ben",
                     direction = "backward", at = 14)
  tree <- path_trajectories(paths)
  expect_identical(tree$vertex[tree$depth == 0L], "Ben")
  expect_identical(attr(tree, "direction"), "backward")
  expect_s3_class(plot_path_trajectories(paths), "ggplot")
})

test_that("caller pruning is the only way to drop a branch", {
  paths <- .school_paths()
  full <- path_trajectories(paths, min_count = 1L)
  pruned <- path_trajectories(paths, min_count = 3L)
  expect_lt(nrow(pruned), nrow(full))
  expect_true(all(pruned$node %in% full$node))
  expect_true(all(pruned$count >= 3L))
  expect_identical(attr(pruned, "min_count"), 3L)
})

test_that("separate sessions never merge into one branch", {
  dn <- dynet(data.frame(
    from = c("A", "B", "A", "B"), to = c("B", "C", "B", "C"),
    start = c(0, 1, 0, 1), end = c(1, 2, 1, 2),
    term = c("t1", "t1", "t2", "t2")
  ), session = "term")
  paths <- paths(dn, from = "A", sessions = "separate")
  tree <- path_trajectories(paths)

  # Both sessions carry the identical vertex sequence at identical times, so
  # a tree keyed on vertex and time alone would silently fuse them.
  expect_setequal(stats::na.omit(tree$session), c("t1", "t1", "t1",
                                                  "t2", "t2", "t2"))
  by_session <- split(tree$vertex[tree$depth == 1L],
                      tree$session[tree$depth == 1L])
  expect_length(by_session, 2L)
  expect_identical(unname(vapply(by_session, \(v) v[[1L]], character(1L))),
                   c("A", "A"))
  expect_identical(as.numeric(tree$count[[1L]]),
                   sum(as.data.frame(paths)$n_paths))
})

test_that("every measure and orientation builds", {
  paths <- .school_paths()
  grid <- expand.grid(
    measure = c("frequency", "time", "predictability"),
    orientation = c("horizontal", "vertical"), stringsAsFactors = FALSE
  )
  invisible(Map(function(measure, orientation) {
    plot <- plot_path_trajectories(paths, measure = measure,
                                   orientation = orientation)
    expect_s3_class(plot, "ggplot")
    expect_no_error(ggplot2::ggplot_build(plot))
  }, grid$measure, grid$orientation))
})

test_that("a prebuilt tree can be plotted without recomputing", {
  tree <- path_trajectories(.school_paths(), min_count = 2L)
  expect_s3_class(plot_path_trajectories(tree), "ggplot")
  expect_s3_class(as.data.frame(tree), "data.frame")
  expect_false(inherits(as.data.frame(tree), "dynet_path_trajectories"))
})

# ---- error paths, by class not message ----------------------------------

test_that("bad input raises classed conditions", {
  expect_error(path_trajectories(data.frame(a = 1)),
               class = "dynet_bad_input")
  expect_error(path_trajectories(.school_paths(), min_count = 0L),
               class = "dynet_bad_input")
  expect_error(path_trajectories(.school_paths(), min_count = 2.5),
               class = "dynet_bad_input")
  expect_error(plot_path_trajectories(.school_paths(), base_size = -1),
               class = "dynet_bad_input")
  expect_error(path_trajectories(.school_paths(), min_count = 10000L),
               class = "dynet_empty_result")
  expect_error(.path_prefix_tree(list(), min_count = 1L),
               class = "dynet_empty_result")
})

test_that("a backward family with no attained departure has no branch", {
  # At the calendar end every latest-departure supremum is unattained, so no
  # sender has a maximising journey and only the queried target's own
  # zero-hop route survives. The tree must show that emptiness honestly
  # rather than inventing branches or refusing to build.
  paths <- paths(dynet(school_contacts), from = "Ben",
                     direction = "backward", at = 21.52)
  expect_identical(sum(as.data.frame(paths)$n_paths), 1)

  tree <- path_trajectories(paths)
  expect_identical(nrow(tree), 1L)
  expect_identical(tree$vertex[tree$depth == 0L], "Ben")
  expect_identical(as.numeric(tree$count[[1L]]), 1)
  expect_identical(max(tree$depth), 0L)
})

# ---- visual regression ---------------------------------------------------
# vdiffr is not installed here, so these pin the built plot's geometry and
# scales rather than a rendered image. They fail on any change to placement,
# branch geometry, glyph tracing, labelling or fill mapping.

.plot_fingerprint <- function(plot) {
  built <- ggplot2::ggplot_build(plot)
  edges <- built$data[[1L]]
  nodes <- built$data[[2L]]
  labels <- built$data[[3L]]
  at <- order(nodes$x, nodes$y)
  list(
    edge_vertices = nrow(edges),
    edge_groups = length(unique(edges$group)),
    edge_widths = round(sort(unique(edges$linewidth)), 6L),
    node_x = round(nodes$x[at], 6L),
    node_y = round(nodes$y[at], 6L),
    node_sizes = round(nodes$size[at], 6L),
    node_fills = nodes$fill[at],
    node_labels = labels$label[order(labels$x, labels$y)],
    root_points = nrow(built$data[[4L]])
  )
}

test_that("a branching forward family is visually stable", {
  expect_snapshot(str(.plot_fingerprint(
    plot_path_trajectories(.school_paths(), measure = "frequency")
  )))
})

test_that("a backward family is visually stable", {
  paths <- paths(dynet(school_contacts), from = "Ben",
                     direction = "backward", at = 14)
  expect_snapshot(str(.plot_fingerprint(
    plot_path_trajectories(paths, measure = "time",
                           orientation = "vertical")
  )))
})
