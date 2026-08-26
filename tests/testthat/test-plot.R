test_that("the time-series views return ggplot objects", {
  skip_if_not_installed("ggplot2")
  dn <- quiet_dynet(school_contacts)
  for (type in c("timeline", "activity")) {
    p <- plot(dn, type = type)
    expect_s3_class(p, "ggplot")
    expect_no_error(ggplot2::ggplot_build(p))
  }
})

test_that("a dynet object is a cograph netobject that splot can draw", {
  dn <- quiet_dynet(school_contacts)
  expect_s3_class(dn, "netobject")
  expect_s3_class(dn, "cograph_network")
  expect_true(all(c("nodes", "edges", "directed", "weights", "data", "meta",
                    "node_groups") %in% names(dn)))
  expect_true(all(c("id", "label", "name", "x", "y") %in% names(dn$nodes)))
  expect_type(dn$edges$from, "integer")
  expect_type(dn$edges$to, "integer")

  skip_if_not_installed("cograph")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(cograph::splot(dn))
})

test_that("node-link views are drawn by cograph and return the network", {
  skip_if_not_installed("cograph")
  dn <- quiet_dynet(school_contacts)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(plot(dn, type = "network"), dn)
  expect_identical(plot(dn, type = "network", at = 5), dn)
  expect_identical(suppressMessages(plot(dn, type = "snapshots", panels = 4L)), dn)
  expect_identical(plot(dn, type = "proximity", phases = 2L, slices = 30L), dn)
  p <- paths(dn, from = "Ana")
  expect_error(plot(p), class = "dynet_unsupported_plot")
})

test_that("a bin with eligible isolates and no edge can be drawn", {
  skip_if_not_installed("cograph")
  gap <- data.frame(from = c("A", "C"), to = c("B", "D"),
                    start = c(0, 20), end = c(1, 21), stringsAsFactors = FALSE)
  dn <- quiet_dynet(gap, interval = 1)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(plot(dn, type = "network", at = 10), dn)
  view <- Dynet:::.bin_netobject(dn, 10)
  expect_equal(nrow(view$nodes), 4)
  expect_equal(nrow(view$edges), 0)
})

test_that("measures plot as lines, heatmaps and bars", {
  skip_if_not_installed("ggplot2")
  dn <- quiet_dynet(school_contacts)
  deg <- dyn_centrality(dn, measure = "degree")
  expect_no_error(ggplot2::ggplot_build(plot(deg, top = 5)))
  expect_no_error(ggplot2::ggplot_build(plot(deg, type = "heatmap")))
  expect_no_error(ggplot2::ggplot_build(plot(deg, highlight = c("Ana", "Ben"))))
  expect_no_error(ggplot2::ggplot_build(plot(burstiness(dn))))
  expect_no_error(ggplot2::ggplot_build(plot(durations(dn))))
})

test_that("infinite temporal closeness survives default bar selection", {
  skip_if_not_installed("ggplot2")
  targets <- sprintf("A%02d", seq_len(31L))
  dn <- quiet_dynet(data.frame(
    from = rep("ZZZ", length(targets)), to = targets, time = 0
  ))
  closeness <- dyn_centrality(
    dn, measure = "closeness", scope = "temporal", start = 0, end = 0
  )
  panel <- plot(closeness)
  expect_true("ZZZ" %in% panel$data$.row)
  expect_identical(panel$data$value[panel$data$.row == "ZZZ"], Inf)
})

test_that("the vertex partition is written where cograph looks for it", {
  dn <- quiet_dynet(forum_posts, thread = "thread", nodes = forum_people,
                    groups = "role")
  expect_true("groups" %in% names(dn$nodes))
  expect_identical(names(dn$node_groups), c("node", "group"))
  expect_setequal(unique(dn$node_groups$group),
                  c("Student", "Teacher", "Facilitator"))

  skip_if_not_installed("cograph")
  expect_identical(cograph::get_groups(dn)$group, dn$node_groups$group)

  expect_error(
    quiet_dynet(forum_posts, thread = "thread", nodes = forum_people,
                groups = "nope"),
    class = "dynet_unknown_attribute")
})

test_that("proximity slices are standardised, aligned and measured together", {
  dn <- quiet_dynet(school_contacts)
  prox <- .proximity_slices(dn, slices = 40L)
  expect_equal(dim(prox$pos), c(nrow(dn$nodes), 40L))
  # Position and thickness are read off the same window, so they always
  # describe the same moment.
  expect_equal(dim(prox$weight), dim(prox$pos))
  expect_true(all(is.finite(prox$pos)))
  expect_true(all(prox$weight >= 0))

  # Each slice is scaled to unit spread, so one slice's vertical distances
  # mean the same as another's.
  spreads <- apply(prox$pos, 2L, stats::sd)
  expect_true(all(abs(spreads[spreads > 0] - 1) < 1e-8))

  # Slices span the observation window and are evenly spaced.
  expect_equal(range(prox$times), unname(dn$meta$time_range))
  expect_true(all(abs(diff(diff(prox$times))) < 1e-9))
})

test_that("the line never leaves the corridor its measurements define", {
  dn <- quiet_dynet(school_contacts)
  prox <- .proximity_slices(dn, slices = 25L)
  f <- tempfile(fileext = ".png")
  grDevices::png(f, width = 8, height = 5, units = "in", res = 72)
  on.exit({grDevices::dev.off(); unlink(f)}, add = TRUE)
  graphics::plot(NA, xlim = range(prox$times), ylim = c(-4, 4))

  # With rounding off, the drawn points are exactly the measured slices.
  sharp <- .draw_proximity_line(prox$times, prox$pos[1L, ], prox$weight[1L, ],
                                "#000000", flow = 0L)
  expect_identical(sharp$x, prox$times)
  expect_identical(sharp$y, prox$pos[1L, ])

  # With rounding on there are more points, but none of them sits outside the
  # range the measurements span, and time still runs forwards.
  for (passes in 1:4) {
    rounded <- .draw_proximity_line(prox$times, prox$pos[1L, ],
                                    prox$weight[1L, ], "#000000",
                                    flow = passes)
    expect_lte(max(rounded$y), max(prox$pos[1L, ]))
    expect_gte(min(rounded$y), min(prox$pos[1L, ]))
    expect_equal(range(rounded$x), range(prox$times))
    expect_true(all(diff(rounded$x) >= 0))
  }
})

test_that("the default slice window keeps slices connected", {
  dn <- quiet_dynet(school_contacts)
  w <- .default_window(dn)
  span <- diff(unname(dn$meta$time_range))
  expect_equal(w, max(dn$meta$interval, span / 6))

  # A window one bin wide leaves vertices isolated, which is what makes the
  # untreated timeline jump; the default does not.
  isolates <- function(width) {
    enc <- .encode(dn)
    mean(vapply(seq(0, span, length.out = 20L), function(t) {
      b <- .binary(.adjacency(enc, .active(enc, t - width / 2, t + width / 2),
                              TRUE), FALSE)
      sum(rowSums(b) == 0)
    }, numeric(1L)))
  }
  expect_lt(isolates(w), isolates(dn$meta$interval))
})

test_that("phases follow sessions when the network has them", {
  e <- random_edges()
  e$session <- ifelse(e$start < 10, "before", "after")
  dn <- quiet_dynet(e, session = "session")
  auto <- .phase_table(dn)
  expect_setequal(auto$label, c("before", "after"))
  expect_true(all(auto$to >= auto$from))

  fixed <- .phase_table(dn, phases = 4L)
  expect_equal(nrow(fixed), 4L)
  expect_equal(fixed$from[1L], dn$meta$time_range[["start"]])
  expect_equal(fixed$to[4L], dn$meta$time_range[["end"]])
})

test_that("a phase network holds only the spells overlapping that span", {
  dn <- quiet_dynet(school_contacts)
  net <- .range_netobject(dn, 0, 5)
  expect_s3_class(net, "cograph_network")
  expect_true(all(net$spells$start < 5))
  expect_null(.range_netobject(dn, 1e6, 1e7))
})

test_that("labels are pushed apart without changing their order", {
  y <- c(0, 0.001, 0.002, 1)
  out <- .spread_labels(y, gap = 0.1)
  expect_equal(order(out), order(y))
  expect_true(all(diff(sort(out)) >= 0.1 - 1e-9))
  expect_equal(.spread_labels(c(0, 5), gap = 0.1), c(0, 5))
})

test_that("the styled panel contract validates its arguments", {
  st <- .dyn_style()
  expect_true(all(c("cex", "grid", "background", "grid_color", "axis_color",
                    "text_color", "frame_color") %in% names(st)))
  expect_identical(st$grid_color, "#ECEEF0")
  expect_error(.dyn_style(cex = -1), class = "dynet_bad_input")
  expect_error(.dyn_style(grid = NA), class = "dynet_bad_input")
})

test_that("the palette is Okabe-Ito", {
  okabe <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2",
             "#D55E00", "#CC79A7", "#999999", "#000000")
  expect_identical(.okabe_ito(9L), okabe)
  expect_identical(.okabe_ito(11L)[10:11], okabe[1:2])
})

test_that("path-tree coordinates put time on one axis and hops on the other", {
  dn <- quiet_dynet(chain_edges())
  p <- as.data.frame(paths(dn, from = "A"))
  expect_equal(.rescale(c(1, 2, 3)), c(-1, 0, 1))
  expect_equal(.rescale(c(2, 2, 2)), c(0, 0, 0))
  # Vertices sharing a hop count are separated, and the offsets stay small.
  off <- .jitter_within(c(1, 1, 1, 2))
  expect_equal(length(unique(off[1:3])), 3L)
  expect_true(all(abs(off) < 0.5))
})

test_that("the dynet theme is registered in cograph's theme registry", {
  skip_if_not_installed("cograph")
  .register_dynet_theme()
  expect_true("dynet" %in% cograph::list_themes())

  th <- cograph::get_theme("dynet")
  # A plain list registers but fails at draw time, because splot() reaches
  # into the theme with th$get(); it has to be a CographTheme object.
  expect_s3_class(th, "CographTheme")
  expect_identical(th$get("node_fill"), "#56B4E9")
  expect_identical(th$get("edge_positive_color"), "#4A6FE3")
  expect_identical(th$get("edge_negative_color"), "#D33F6A")
})

test_that("splot arguments default to the theme and yield to the caller", {
  dn <- quiet_dynet(school_contacts)
  plain <- .splot_args(dn, list())
  expect_identical(plain$theme, "dynet")
  expect_false(plain$tna_styling)
  # No partition, so no node_fill is forced and the theme's own fill applies.
  expect_null(plain$node_fill)

  overridden <- .splot_args(dn, list(theme = "dark", layout = "oval"))
  expect_identical(overridden$theme, "dark")
  expect_identical(overridden$layout, "oval")
  expect_false(overridden$tna_styling)
})

test_that("a partition supplies per-vertex Okabe-Ito fills a theme cannot hold", {
  dn <- quiet_dynet(forum_posts, thread = "thread", nodes = forum_people,
                    groups = "role")
  args <- .splot_args(dn, list())
  expect_length(args$node_fill, nrow(dn$nodes))
  expect_true(all(args$node_fill %in% .okabe_ito(9L)))
  expect_equal(length(unique(args$node_fill)), 3L)
})

test_that("arrowheads and vertices shrink as the network grows", {
  expect_equal(.arrow_size(14L), 1.7 / sqrt(14))
  expect_lt(.arrow_size(50L), .arrow_size(10L))
  expect_gte(.arrow_size(1000L), 0.35)
  expect_lte(.arrow_size(3L), 0.75)
  expect_lt(.node_size(100L), .node_size(10L))

  dn <- quiet_dynet(school_contacts)
  # cograph's own default is 1, which caps thin edges with wider heads.
  expect_lt(.splot_args(dn, list())$arrow_size, 1)
  expect_identical(.splot_args(dn, list(arrow_size = 2))$arrow_size, 2)
})

test_that("the temporal layout is registered with cograph", {
  skip_if_not_installed("cograph")
  .register_dynet_layout()
  expect_true("temporal" %in% cograph::list_layouts())
  expect_identical(cograph::get_layout("temporal"), .layout_temporal)
})

test_that("the temporal layout puts arrival time across and hops down", {
  net <- list(nodes = data.frame(
    arrival_time = c(0, 5, 10), n_hops = c(0L, 1L, 2L)))
  co <- .layout_temporal(net)
  expect_identical(names(co), c("x", "y"))
  expect_true(all(diff(co$x) > 0))   # later arrival is further right
  expect_true(all(diff(co$y) < 0))   # deeper in hops is further down

  expect_error(.layout_temporal(list(nodes = data.frame(a = 1))),
               class = "dynet_bad_input")
})

test_that("shortest-foremost path families reject a false tree rendering", {
  skip_if_not_installed("cograph")
  dn <- quiet_dynet(school_contacts)
  p <- paths(dn, from = "Ana")
  df <- as.data.frame(p)
  reached <- df[df$reachable, , drop = FALSE]

  # Rebuild what plot() builds, to check the object rather than the picture.
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_error(plot(p), class = "dynet_unsupported_plot")

  # A netobject with coordinates must have them forwarded, because
  # cograph::splot.netobject() passes on only $weights and drops $nodes.
  positioned <- quiet_dynet(school_contacts)
  positioned$nodes$x <- seq_len(nrow(positioned$nodes))
  positioned$nodes$y <- rev(seq_len(nrow(positioned$nodes)))
  expect_true(.has_layout(positioned))
  args <- .splot_args(positioned, list())
  expect_s3_class(args$layout, "data.frame")
  expect_equal(args$layout$x, positioned$nodes$x)

  unpositioned <- quiet_dynet(school_contacts)
  expect_false(.has_layout(unpositioned))
  expect_identical(.splot_args(unpositioned, list())$layout, "spring")
})

test_that("a device too small to hold the figure says so, and what to do", {
  skip_if_not_installed("cograph")
  dn <- quiet_dynet(school_contacts, interval = 3)
  f <- tempfile(fileext = ".png")
  grDevices::png(f, width = 4, height = 3, units = "in", res = 72)
  on.exit({grDevices::dev.off(); unlink(f)}, add = TRUE)
  expect_error(plot(dn, type = "proximity"), class = "dynet_device_too_small")
})

test_that("line thickness follows the requested measure", {
  dn <- quiet_dynet(school_contacts, interval = 3)
  f <- tempfile(fileext = ".png")
  grDevices::png(f, width = 11, height = 7, units = "in", res = 72)
  on.exit({grDevices::dev.off(); unlink(f)}, add = TRUE)
  expect_identical(plot(dn, type = "proximity", measure = "betweenness",
                        slices = 25L), dn)
  expect_error(plot(dn, type = "proximity", measure = "nonsense"),
               class = "dynet_unknown_measure")
  expect_error(plot(dn, type = "proximity", slices = 1),
               class = "dynet_bad_input")
  expect_error(plot(dn, type = "proximity", window = -1),
               class = "dynet_bad_input")
})

test_that("corner-cutting rounds joints without overshooting a measurement", {
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (!is.null(old)) assign(".Random.seed", old, globalenv()), add = TRUE)
  set.seed(11)
  worst <- vapply(seq_len(200L), function(i) {
    n <- sample(8:40, 1L)
    y <- stats::rnorm(n)
    out <- .chaikin(cbind(seq_len(n), y), passes = 2L)
    max(max(out[, 2L]) - max(y), min(y) - min(out[, 2L]))
  }, numeric(1L))
  # Every point it produces is a convex combination of measured points, so it
  # can never leave the range they span.
  expect_lte(max(worst), 0)

  # An interpolating spline through the same points is not so constrained.
  set.seed(11)
  y <- stats::rnorm(20L)
  sp <- stats::spline(seq_along(y), y, n = 400L, method = "natural")
  expect_gt(max(sp$y), max(y))
})

test_that("corner-cutting keeps the endpoints and the ordering of time", {
  m <- cbind(c(0, 1, 2, 3), c(0, 5, -5, 0))
  out <- .chaikin(m, passes = 3L)
  expect_equal(out[1L, ], m[1L, ])
  expect_equal(out[nrow(out), ], m[nrow(m), ])
  expect_true(all(diff(out[, 1L]) >= 0))
  expect_gt(nrow(out), nrow(m))
  expect_identical(.chaikin(m, passes = 0L), m)
})

test_that("flow is an argument and zero leaves the joints sharp", {
  dn <- quiet_dynet(school_contacts)
  prox <- .proximity_slices(dn, slices = 20L)
  f <- tempfile(fileext = ".png")
  grDevices::png(f, width = 8, height = 5, units = "in", res = 72)
  on.exit({grDevices::dev.off(); unlink(f)}, add = TRUE)
  graphics::plot(NA, xlim = range(prox$times), ylim = c(-3, 3))

  sharp <- .draw_proximity_line(prox$times, prox$pos[1L, ], prox$weight[1L, ],
                                "#000000", flow = 0L)
  expect_identical(sharp$x, prox$times)

  rounded <- .draw_proximity_line(prox$times, prox$pos[1L, ], prox$weight[1L, ],
                                  "#000000", flow = 2L)
  expect_gt(length(rounded$x), length(sharp$x))
  expect_lte(max(rounded$y), max(prox$pos[1L, ]))
  expect_gte(min(rounded$y), min(prox$pos[1L, ]))

  expect_error(plot(dn, type = "proximity", flow = -1),
               class = "dynet_bad_input")
})
