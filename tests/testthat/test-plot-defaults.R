# ===========================================================================
# Plot defaults: vertex colours follow the vertex, `step` sets the timeline
# bin, collapsed and path networks draw with Dynet's defaults
# ===========================================================================

dn <- quiet_dynet(random_edges(seed = 11L))

test_that("a node-level bar chart colours bars by vertex in network order", {
  b <- plot(burstiness(dn, measure = "events"))
  built <- ggplot2::ggplot_build(b)
  fills <- unique(built$data[[1]]$fill)
  vertices <- as.data.frame(dn, what = "nodes")$name
  expect_setequal(fills, unname(Dynet:::.vertex_colours(vertices)))
  # a pair-level chart has no vertex to follow and keeps one colour
  p <- plot(durations(dn, unit = "pair", measure = "total"))
  expect_length(unique(ggplot2::ggplot_build(p)$data[[1]]$fill), 1L)
})

test_that("the frequency trajectory tree fills nodes by vertex, other measures by value", {
  tr <- path_trajectories(paths(dn, from = as.data.frame(dn, what = "nodes")$name[1]))
  freq <- ggplot2::ggplot_build(plot_path_trajectories(tr, measure = "frequency"))
  pts <- freq$data[[2]]
  expect_true(all(pts$fill %in% unname(Dynet:::.vertex_colours(attr(tr, "vertices")))))
  tm <- ggplot2::ggplot_build(plot_path_trajectories(tr, measure = "time"))
  expect_false(all(tm$data[[2]]$fill %in% unname(Dynet:::.vertex_colours(attr(tr, "vertices")))))
  expect_identical(attr(tr, "vertices"), as.data.frame(dn, what = "nodes")$name)
})

test_that("step sets the timeline bin width and beats bins", {
  sub <- function(p) p$labels$subtitle
  by_step <- plot(dn, type = "timeline", step = 0.5)
  expect_match(sub(by_step), "bins of 0.5")
  both <- plot(dn, type = "timeline", step = 2, bins = 100)
  expect_match(sub(both), "bins of 2")
  expect_error(plot(dn, type = "timeline", step = -1), class = "dynet_bad_input")
})

test_that("collapsed and path networks have plot methods that run and return invisibly", {
  skip_if_not_installed("cograph")
  grDevices::pdf(NULL); on.exit(grDevices::dev.off(), add = TRUE)
  cn <- collapse_network(dn)
  expect_identical(withVisible(plot(cn, layout = "oval"))$visible, FALSE)
  pn <- path_network(paths(dn, from = as.data.frame(dn, what = "nodes")$name[1]))
  expect_identical(withVisible(plot(pn, layout = "oval"))$visible, FALSE)
})
