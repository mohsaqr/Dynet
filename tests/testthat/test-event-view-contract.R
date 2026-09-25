# Contract for the event view and the intensity timeline.

.contact_net <- function() {
  dynet(data.frame(
    from = c("A", "B", "C", "A", "D", "B"),
    to   = c("B", "C", "D", "C", "A", "D"),
    time = c(1, 1, 2, 2, 3, 3)
  ), format = "contact")
}

test_that("every glyph, axis and nesting combination builds", {
  dn <- .contact_net()
  grid <- expand.grid(
    link = c("hook", "arc", "chevron", "wave", "bracket"),
    time = c("bin", "event", "clock"),
    nest = c("pair", "column"), stringsAsFactors = FALSE
  )
  invisible(Map(function(link, time, nest) {
    plot <- plot(dn, type = "events", link = link, time = time, nest = nest)
    expect_s3_class(plot, "ggplot")
    expect_no_error(ggplot2::ggplot_build(plot))
  }, grid$link, grid$time, grid$nest))
})

test_that("a link runs source colour first, whichever way it points", {
  # The polyline is always built high row to low row so bows nest
  # consistently, which discards direction. The colour run has to put it back
  # or an upward link arrives source-coloured at its target.
  down <- .link_cols("FROM", "TO", 10L, split = 0.8)
  expect_identical(down[[1L]], "FROM")
  expect_identical(down[[10L]], "TO")
  expect_equal(mean(down == "FROM"), 0.8)

  up <- .link_cols("TO", "FROM", 10L, split = 0.2)
  expect_identical(up[[10L]], "FROM")
  expect_identical(up[[1L]], "TO")
  expect_equal(mean(up == "FROM"), 0.8)

  expect_length(.link_cols("#E69F00", "#0072B2", 30L, blend = TRUE), 30L)
})

test_that("aggregation folds a repeated pair inside one column only", {
  # Two firings of A->B land in one bin but are distinct onsets, so folding
  # depends entirely on the axis resolution.
  dn <- dynet(data.frame(from = c("A", "A", "B"), to = c("B", "B", "C"),
                         time = c(1, 2, 5)), format = "contact")
  folded <- ggplot2::ggplot_build(
    plot(dn, type = "events", time = "bin", bins = 1L, aggregate = TRUE)
  )$data[[2L]]
  kept <- ggplot2::ggplot_build(
    plot(dn, type = "events", time = "bin", bins = 1L, aggregate = FALSE)
  )$data[[2L]]
  expect_lt(length(unique(folded$group)), length(unique(kept$group)))

  # At event resolution every column is one onset, so nothing can fold.
  a <- ggplot2::ggplot_build(
    plot(dn, type = "events", time = "event", aggregate = TRUE))$data[[2L]]
  b <- ggplot2::ggplot_build(
    plot(dn, type = "events", time = "event", aggregate = FALSE))$data[[2L]]
  expect_identical(length(unique(a$group)), length(unique(b$group)))
})

test_that("pair nesting fans fewer links than column nesting", {
  dn <- .contact_net()
  bow <- function(nest) {
    d <- ggplot2::ggplot_build(
      plot(dn, type = "events", nest = nest, time = "bin", bins = 2L)
    )$data[[2L]]
    diff(range(d$x))
  }
  expect_lte(bow("pair"), bow("column"))
})

test_that("the axis never labels time the data does not contain", {
  dn <- .contact_net()
  breaks <- function(...) {
    b <- ggplot2::ggplot_build(plot(dn, type = "events", ...))
    b$layout$panel_params[[1L]]$x$breaks
  }
  expect_false(any(breaks(time = "event") < 1, na.rm = TRUE))
  expect_false(any(breaks(time = "bin", bins = 4L) < 0, na.rm = TRUE))
})

test_that("the timeline heatmap reports a share that cannot exceed one", {
  dn <- dynet(school_contacts)
  built <- ggplot2::ggplot_build(plot(dn, type = "timeline", top = 10L))
  fill <- built$data[[1L]]$fill
  expect_false(any(is.na(fill)))          # NA fill renders grey, not blue
  values <- built$plot$data$value
  expect_true(all(values > 0 & values <= 1))
})

test_that("a union counts overlapping spells once", {
  expect_equal(.union_len(c(0, 0.5), c(1, 2), 0, 3), 2)
  expect_equal(.union_len(c(0, 2), c(1, 3), 0, 3), 2)
  expect_equal(.union_len(0, 10, 2, 3), 1)     # clipped to the bin
  expect_equal(.union_len(5, 6, 0, 1), 0)      # outside the bin
})

test_that("bad event arguments raise classed conditions", {
  dn <- .contact_net()
  expect_error(plot(dn, type = "events", split = 2), class = "dynet_bad_input")
  expect_error(plot(dn, type = "events", bins = 0), class = "dynet_bad_input")
  expect_error(plot(dn, type = "events", aggregate = NA),
               class = "dynet_bad_input")
  expect_error(plot(dn, type = "events", nonsense = 1),
               class = "dynet_unknown_plot_arg")
})

test_that("cograph aesthetic names are honoured by the event view", {
  dn <- .contact_net()
  built <- function(...) ggplot2::ggplot_build(plot(dn, type = "events", ...))

  nodes <- built(node_size = 5)$data[[4L]]
  expect_true(all(nodes$size == 5))
  expect_identical(unique(built(node_shape = "square")$data[[4L]]$shape), 22L)
  expect_true(all(built(node_fill = "grey80")$data[[4L]]$fill == "grey80"))

  # A single edge_color overrides the source-to-target run entirely.
  expect_identical(unique(built(edge_color = "#D55E00")$data[[2L]]$colour),
                   "#D55E00")
  expect_true(all(built(edge_style = 2)$data[[2L]]$linetype == 2))
})

test_that("a non-solid link falls back to one colour per link", {
  # ggplot cannot vary colour along a dashed path, so the source-to-target
  # run is replaced by the source's colour rather than failing to draw.
  dn <- .contact_net()
  expect_no_error(ggplot2::ggplot_build(plot(dn, type = "events",
                                             edge_style = 2)))
  dashed <- ggplot2::ggplot_build(
    plot(dn, type = "events", edge_style = 2))$data[[2L]]
  per_link <- vapply(split(dashed$colour, dashed$group),
                     \(v) length(unique(v)), integer(1L))
  expect_true(all(per_link == 1L))

  solid <- ggplot2::ggplot_build(plot(dn, type = "events"))$data[[2L]]
  mixed <- vapply(split(solid$colour, solid$group),
                  \(v) length(unique(v)), integer(1L))
  expect_true(any(mixed > 1L))
})

test_that("curvature zero draws straight links", {
  dn <- .contact_net()
  flat <- ggplot2::ggplot_build(
    plot(dn, type = "events", curvature = 0, nest = "pair"))$data[[2L]]
  # With no bow and no nesting step, every link is vertical: one x per link.
  widths <- vapply(split(flat$x, flat$group), \(v) diff(range(v)), numeric(1L))
  expect_true(all(widths < 1e-9))
  expect_error(plot(dn, type = "events", curvature = -1),
               class = "dynet_bad_input")
})

test_that("curve_pivot moves where the bow peaks", {
  # Re-parameterising t for the y values as well would leave the drawn curve
  # identical, so this asserts the peak actually travels.
  peak <- function(pv) {
    p <- .link_path("arc", 0, 10, 0, 1, n = 201L, pivot = pv)
    p$y[which.min(p$x)]
  }
  expect_gt(peak(0.25), peak(0.5))
  expect_gt(peak(0.5), peak(0.75))
})

test_that("splot aesthetic names still reach splot for delegating views", {
  skip_if_not_installed("cograph")
  dn <- .contact_net()
  # These are now formals of plot.dynet, so they must be spliced back into the
  # forwarded dots or the node-link views would silently lose them.
  expect_s3_class(plot(dn, type = "network", node_size = 8), "dynet")
  expect_s3_class(plot(dn, type = "network", curvature = 0.3), "dynet")
  expect_error(plot(dn, type = "network", nodesize = 8),
               class = "dynet_unknown_plot_arg")
})

test_that("the event view colours each row label with its actor", {
  dn <- .contact_net()
  built <- ggplot2::ggplot_build(plot(dn, type = "events"))
  nodes <- built$data[[4L]]
  labels <- built$data[[length(built$data)]]
  # Each label sits on its row in the colour of the nodes drawn on that row,
  # and no separate legend is added.
  row_colours <- vapply(split(nodes$fill, nodes$y), unique, character(1L))
  expect_identical(labels$colour, unname(row_colours[as.character(labels$y)]))
  expect_identical(trimws(labels$label), rev(dn$nodes$name))
  expect_null(built$plot$scales$get_scales("fill"))
  fixed <- ggplot2::ggplot_build(plot(dn, type = "events",
                                      label_color = "grey20"))
  expect_true(all(fixed$data[[length(fixed$data)]]$colour == "grey20"))
})

test_that("only the origin of a link is dotted, as in cograph's TNA style", {
  dn <- .contact_net()
  built <- ggplot2::ggplot_build(plot(dn, type = "events", time = "event"))
  solid <- built$data[[2L]]
  origin <- built$data[[3L]]
  expect_true(all(origin$linetype == "12"))
  expect_true(all(solid$linetype == 1))
  # One dotted origin per link, in one colour, the source's; it covers the
  # first fifth of the link and the solid rest carries the colour run.
  expect_identical(length(unique(origin$group)), length(unique(solid$group)))
  per_piece <- vapply(split(origin$colour, origin$group),
                      \(v) length(unique(v)), integer(1L))
  expect_true(all(per_piece == 1L))
  share <- nrow(origin) / (nrow(origin) + nrow(solid) - length(unique(solid$group)))
  expect_equal(share, 0.2, tolerance = 0.02)
  longer <- ggplot2::ggplot_build(plot(dn, type = "events", time = "event",
                                       edge_start_length = 0.4))
  expect_gt(nrow(longer$data[[3L]]), nrow(origin))
  off <- ggplot2::ggplot_build(plot(dn, type = "events",
                                    edge_start_style = "solid"))
  expect_identical(nrow(off$data[[3L]]), 0L)
  expect_error(plot(dn, type = "events", edge_start_length = 0.9),
               class = "dynet_bad_input")
  expect_error(plot(dn, type = "events", edge_start_style = "wavy"),
               class = "dynet_bad_input")
})
