# Contracts pinned by the 2026-11-01 audit of the result-class method surface.
# Each block names the defect it guards against; every one was reproduced on
# the code before the fix.

session_contacts <- function() {
  e <- school_contacts
  e$session <- ifelse(e$start < 10, "s1", "s2")
  quiet_dynet(e)
}

# ---------------------------------------------------------------------------
# Unknown choices raise a classed condition, not match.arg()'s simpleError
# ---------------------------------------------------------------------------

test_that("an unknown what, layout, by or type is a classed bad-choice error", {
  dn <- quiet_dynet(chain_edges())
  degree <- centrality_series(dn, measure = "degree")
  routes <- paths(dn, from = "A")

  expect_error(as.data.frame(dn, what = "spells"), class = "dynet_bad_choice")
  expect_error(as.data.frame(dn, what = "spells"), class = "dynet_bad_input")
  expect_error(as.data.frame(degree, what = "zzz"), class = "dynet_bad_choice")
  expect_error(as.data.frame(degree, layout = "tall"),
               class = "dynet_bad_choice")
  expect_error(as.data.frame(routes, what = "zzz"), class = "dynet_bad_choice")
  expect_error(summary(degree, by = "zzz"), class = "dynet_bad_choice")
  expect_error(plot(degree, type = "pie"), class = "dynet_bad_choice")
  expect_error(plot(dn, type = "pie"), class = "dynet_bad_choice")
  expect_error(plot(dn, type = "events", link = "zigzag"),
               class = "dynet_bad_input")
})

test_that(".match_choice keeps match.arg's semantics for valid input", {
  choices <- c("long", "wide")
  # Invariant: wherever match.arg() returns a value, .match_choice() returns
  # the same one.
  inputs <- list(choices, NULL, "long", "wide", "w", "l")
  expect_identical(
    vapply(inputs, function(v) .match_choice(v, choices, "layout"), ""),
    vapply(inputs, function(v) match.arg(v, choices), "")
  )
  expect_error(.match_choice(c("long", "wide", "x"), choices, "layout"),
               class = "dynet_bad_choice")
  expect_error(.match_choice(NA_character_, choices, "layout"),
               class = "dynet_bad_choice")
  expect_error(.match_choice(1, choices, "layout"), class = "dynet_bad_choice")
})

# ---------------------------------------------------------------------------
# Facets: a session facet no longer replaces the measure facet
# ---------------------------------------------------------------------------

test_that("two measures over sessions draw one line per session, measure and vertex", {
  dns <- session_contacts()
  both <- centrality_series(dns, measure = c("degree", "betweenness"),
                            sessions = "separate", step = 4, window = 4)
  flat <- as.data.frame(both)
  drawn <- ggplot2::ggplot_build(plot(both))$data[[1L]]
  # Before the fix facet_wrap(~session) replaced facet_wrap(~measure) and
  # each vertex's line zigzagged between its degree and its betweenness.
  expect_identical(length(unique(paste(drawn$PANEL, drawn$group))),
                   nrow(unique(flat[c("session", "measure", "node")])))
  expect_identical(nrow(drawn), nrow(flat))

  ridge <- ggplot2::ggplot_build(plot(both, type = "ridge"))
  expect_identical(nrow(ridge$layout$layout), 4L)  # 2 measures x 2 sessions

  heat <- ggplot2::ggplot_build(plot(both, type = "heatmap"))$data[[1L]]
  # One tile per panel, row and column: no tile hides another.
  expect_false(anyDuplicated(heat[c("PANEL", "x", "y")]) > 0L)
})

# ---------------------------------------------------------------------------
# Pair-level measures over time are drawn per pair, not pooled per measure
# ---------------------------------------------------------------------------

test_that("a pair-level series draws one line per pair", {
  dn <- quiet_dynet(chain_edges())
  dn <- add_ties(dn, data.frame(from = c("A", "A", "B", "B"),
                                to = c("B", "B", "C", "C"),
                                start = c(6, 9, 7, 11), end = c(7, 10, 8, 12)))
  gap <- gaps(dn, unit = "pair")
  flat <- as.data.frame(gap)
  p <- plot(gap)
  drawn <- ggplot2::ggplot_build(p)$data[[1L]]
  # Two pairs with repeat spells, so pooling by measure would draw one line.
  expect_gt(nrow(unique(flat[c("from", "to")])), 1L)
  expect_identical(length(unique(drawn$group)),
                   nrow(unique(flat[c("from", "to")])))
  heat <- ggplot2::ggplot_build(plot(gap, type = "heatmap"))$data[[1L]]
  expect_false(anyDuplicated(heat[c("PANEL", "x", "y")]) > 0L)
})

test_that("highlight and top act on pairs for a pair-level series", {
  dn <- quiet_dynet(school_contacts)
  gap <- gaps(dn, unit = "pair")
  flat <- as.data.frame(gap)

  lit <- ggplot2::ggplot_build(plot(gap, highlight = "Ana"))$data
  # Layers: grey lines, coloured lines, grey marks, coloured marks.
  coloured <- lit[[4L]]
  expect_identical(nrow(coloured),
                   sum(flat$from == "Ana" | flat$to == "Ana"))

  # Every pair-level observation is marked, so the marks layer counts pairs
  # even when the top pairs were each observed once and draw no line.
  few <- ggplot2::ggplot_build(plot(gap, top = 3))$data[[2L]]
  expect_identical(length(unique(few$group)), 3L)
  expect_error(plot(gap, highlight = 1), class = "dynet_bad_input")
  expect_error(plot(gap, highlight = "Nobody"),
               class = "dynet_unknown_highlight")
})

test_that("summary(by = 'pair') gives one row per pair and measure", {
  dn <- quiet_dynet(school_contacts)
  gap <- gaps(dn, unit = "pair")
  flat <- as.data.frame(gap)
  by_pair <- summary(gap, by = "pair")
  expect_identical(names(by_pair)[1:3], c("from", "to", "measure"))
  expect_identical(nrow(by_pair), nrow(unique(flat[c("from", "to", "measure")])))
  # Totality: every defined value is counted exactly once.
  expect_identical(sum(by_pair$n), sum(!is.na(flat$value)))
})

# ---------------------------------------------------------------------------
# Recycled styling is announced, not silent
# ---------------------------------------------------------------------------

test_that("more series than colour x line type combinations warn", {
  many <- quiet_dynet(random_edges(n_v = 25L, n_e = 400L, seed = 3L))
  degree <- centrality_series(many, measure = "degree", step = 5, window = 5)
  n_series <- length(unique(as.data.frame(degree)$node))
  expect_gt(n_series, 18L)
  expect_warning(plot(degree), class = "dynet_palette_recycled")
  expect_no_warning(plot(degree, palette = "many"))
  expect_no_warning(plot(degree, top = 18))
})

test_that("without the warning every series has its own colour and line type", {
  dn <- quiet_dynet(school_contacts)
  degree <- centrality_series(dn, measure = "degree", step = 4, window = 4)
  expect_no_warning(p <- plot(degree))
  drawn <- ggplot2::ggplot_build(p)$data[[1L]]
  styles <- unique(drawn[c("group", "colour", "linetype")])
  expect_identical(nrow(unique(styles[c("colour", "linetype")])),
                   length(unique(drawn$group)))
})

test_that("node-link fills warn when groups outnumber colours", {
  net <- list(nodes = data.frame(groups = paste0("g", seq_len(12L))))
  expect_warning(fill <- .node_fill(net), class = "dynet_palette_recycled")
  expect_length(fill, 12L)
  expect_no_warning(.node_fill(net, palette = "many"))
  small <- list(nodes = data.frame(groups = c("a", "b", "a")))
  expect_no_warning(fill <- .node_fill(small))
  # The same group always gets the same colour.
  expect_identical(fill[[1L]], fill[[3L]])
})

# ---------------------------------------------------------------------------
# Palette: classed parent, derived tint
# ---------------------------------------------------------------------------

test_that("a bad palette is also a bad input", {
  expect_error(.dyn_palette("not_a_colour", 3L), class = "dynet_bad_input")
  expect_error(.dyn_palette(42, 3L), class = "dynet_bad_input")
  expect_error(.dyn_palette(function(n) "red", 4L), class = "dynet_bad_input")
})

test_that(".tint runs from white to the colour itself", {
  expect_identical(.tint("#0072B2", 1), "#0072B2")
  expect_identical(.tint("#0072B2", 0), "#FFFFFF")
  # Monotone: more share is never lighter.
  light <- vapply(c(0.1, 0.3, 0.6), function(s)
    sum(grDevices::col2rgb(.tint("#D55E00", s))), numeric(1L))
  expect_true(all(diff(light) < 0))
  expect_error(.tint("#0072B2", 2), class = "dynet_bad_input")
  expect_error(.tint("nope", 0.5), class = "dynet_bad_palette")
})

test_that("the timeline fill starts from an Okabe-Ito tint", {
  dn <- quiet_dynet(chain_edges())
  built <- ggplot2::ggplot_build(plot(dn, type = "timeline"))$data[[1L]]
  ends <- c(.tint("#0072B2", 0.14), "#0072B2")
  # Every drawn fill lies on the segment between the two ends.
  rgb_fill <- grDevices::col2rgb(built$fill)
  rgb_ends <- grDevices::col2rgb(ends)
  expect_true(all(rgb_fill >= pmin(rgb_ends[, 1L], rgb_ends[, 2L]) - 1 &
                    rgb_fill <= pmax(rgb_ends[, 1L], rgb_ends[, 2L]) + 1))
})

# ---------------------------------------------------------------------------
# plot.R conditions carry the parent class; paths forward their palette
# ---------------------------------------------------------------------------

test_that("plot failures are bad inputs as well as their specific class", {
  dn <- quiet_dynet(chain_edges())
  expect_error(plot(dn, start = 50, end = 60), class = "dynet_empty_result")
  expect_error(plot(dn, start = 50, end = 60), class = "dynet_bad_input")
  expect_error(plot(dn, type = "timeline", colour = "red"),
               class = "dynet_unknown_plot_arg")
  expect_error(plot(dn, type = "timeline", colour = "red"),
               class = "dynet_bad_input")
})

test_that("plot() of paths forwards palette to the trajectory tree", {
  dn <- quiet_dynet(school_contacts)
  routes <- paths(dn, from = "Ana")
  mine <- c("#000000", "#999999", "#CC79A7")
  via_method <- ggplot2::ggplot_build(plot(routes, palette = mine))
  direct <- ggplot2::ggplot_build(plot_path_trajectories(routes, palette = mine))
  default <- ggplot2::ggplot_build(plot(routes))
  fills <- function(b) unlist(lapply(b$data, function(d) d$fill), use.names = FALSE)
  # Before the fix `palette` was captured by plot.dynet_paths() and dropped.
  expect_identical(fills(via_method), fills(direct))
  expect_error(plot(routes, palette = 42), class = "dynet_bad_palette")
})

test_that(".effective_fill reads the theme's fill or falls back to white", {
  skip_if_not_installed("cograph")
  expect_identical(.effective_fill(list(node_fill = "#E69F00")), "#E69F00")
  expect_identical(.effective_fill(list(theme = "no_such_theme")), "#FFFFFF")
  themed <- .effective_fill(list(theme = "dynet"))
  expect_type(themed, "character")
  expect_length(themed, 1L)
})

test_that("a series observed once is marked rather than lost", {
  dn <- quiet_dynet(chain_edges())
  once <- centrality_series(dn, measure = "degree", window = "all")
  built <- ggplot2::ggplot_build(plot(once))$data
  # One bin: no vertex has a line, so every vertex is a point.
  expect_identical(nrow(built[[1L]]), 0L)
  expect_identical(nrow(built[[2L]]), nrow(as.data.frame(once)))
})

test_that("every observation of a pair-level series is marked, singletons included", {
  dn <- quiet_dynet(school_contacts)
  gap <- gaps(dn, unit = "pair")
  flat <- as.data.frame(gap)
  built <- ggplot2::ggplot_build(plot(gap, palette = "many"))
  points <- built$data[[2L]]
  # Totality: one point per defined observation, so a pair with one gap,
  # which geom_line() cannot draw, is still on the page.
  expect_identical(nrow(points), sum(!is.na(flat$value)))
  lit <- ggplot2::ggplot_build(plot(gap, highlight = "Ana"))$data
  expect_identical(nrow(lit[[3L]]) + nrow(lit[[4L]]), nrow(flat))
})
