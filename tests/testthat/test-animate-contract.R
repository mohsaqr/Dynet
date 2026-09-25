# animate() writes a file, so every test here writes into tempdir() and
# nothing touches the working directory.

skip_if_no_gif <- function() {
  skip_if_not_installed("gifski")
  skip_if_not_installed("cograph")
}

# One output path per test, inside the session temporary directory, which R
# removes when it exits. Nothing is written to the working directory.
out_path <- function(ext = ".gif") tempfile(fileext = ext)

# The frames of a grid, laid out over every vertex, as the verb builds them.
grid_frames <- function(dn, step, window) {
  enc <- Dynet:::.encode(dn)
  spec <- Dynet:::.window_spec(dn, NULL, NULL, step, window)
  grid <- Dynet:::.grid_for(enc, dn, spec)
  lapply(seq_len(nrow(grid)), function(k) {
    Dynet:::.frame_netobject(dn, enc, grid[k, , drop = FALSE], spec$window,
      all_vertices = TRUE)
  })
}

largest_move <- function(positions) {
  steps <- vapply(seq_along(positions)[-1L], function(k) {
    max(sqrt((positions[[k]]$x - positions[[k - 1L]]$x)^2 +
      (positions[[k]]$y - positions[[k - 1L]]$y)^2))
  }, numeric(1L))
  max(steps)
}

# Whether a GIF carries the NETSCAPE looping block, and its count.
gif_loop_count <- function(path) {
  bytes <- readBin(path, "raw", file.size(path))
  at <- grepRaw("NETSCAPE2.0", bytes)
  if (!length(at)) return(NA_integer_)
  as.integer(bytes[at + 13L]) + 256L * as.integer(bytes[at + 14L])
}

test_that("animate writes a GIF and returns a tidy bin table", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  target <- out_path()
  frames <- animate(dn, step = 6, window = 6, tween = 3, file = target)

  expect_s3_class(frames, "dynet_animation")
  expect_s3_class(frames, "data.frame")
  expect_identical(names(frames),
                   c("bin", "frame", "time", "window_start", "window_end",
                     "nodes", "idle", "ties", "forming", "dissolving", "file"))
  expect_identical(frames$bin, seq_len(nrow(frames)))
  expect_true(file.exists(target))
  expect_gt(file.size(target), 0)

  # The invariants: one row per bin in order, the first rendered frame of
  # each bin three frames after the last, and the file column naming the one
  # file that was written.
  expect_identical(frames$frame, as.integer((frames$bin - 1L) * 3L + 1L))
  expect_true(all(frames$window_end > frames$window_start))
  expect_false(is.unsorted(frames$time))
  expect_identical(unique(frames$file), target)
  expect_true(all(frames$ties >= 0))
  expect_true(all(frames$nodes > 0))
  expect_true(all(frames$idle >= 0 & frames$idle <= frames$nodes))
  # Forming has no meaning for the first bin, dissolving none for the last.
  expect_true(is.na(frames$forming[[1L]]))
  expect_true(is.na(frames$dissolving[[nrow(frames)]]))
  expect_true(all(frames$forming[-1L] >= 0))
  expect_true(all(utils::head(frames$dissolving, -1L) >= 0))
})

test_that("the animation bins are the snapshot grid", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  target <- out_path()
  frames <- animate(dn, start = 0, end = 20, step = 5, window = 5,
    tween = 1, file = target)
  tabulated <- snapshots(dn, start = 0, end = 20, step = 5, window = 5)
  counted <- summary(tabulated)

  # animate() and snapshots() take the same four grid arguments, so they
  # must describe the same bins. Anything else and the animation is showing a
  # timeline the tables do not.
  expect_identical(frames$time, counted$time)
  expect_identical(frames$ties, as.integer(counted$ties))
})

test_that("the rendered-frame schedule holds tween frames per bin", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  frames <- animate(dn, step = 6, window = 6, tween = 4,
    file = out_path())
  schedule <- as.data.frame(frames, what = "frames")

  expect_identical(names(schedule), c("frame", "bin", "phase", "time"))
  expect_identical(nrow(schedule), nrow(frames) * 4L)
  expect_identical(schedule$frame, seq_len(nrow(schedule)))
  expect_identical(schedule$bin, rep(frames$bin, each = 4L))
  expect_true(all(schedule$phase >= 0 & schedule$phase < 1))
  expect_false(is.unsorted(schedule$time))
  # The last bin has nowhere to go, so it is held.
  expect_true(all(schedule$phase[schedule$bin == nrow(frames)] == 0))
  # One frame per bin means hard cuts and no schedule beyond the bins.
  single <- animate(dn, step = 6, window = 6, tween = 1,
    file = out_path())
  expect_identical(nrow(as.data.frame(single, what = "frames")),
    nrow(single))
})

test_that("a video is written when av is installed", {
  skip_if_no_gif()
  skip_if_not_installed("av")
  dn <- quiet_dynet(school_contacts)
  target <- out_path(".mp4")
  frames <- animate(dn, step = 6, window = 6, tween = 2,
    width = 320, height = 320, file = target)
  expect_true(file.exists(target))
  expect_gt(file.size(target), 0)
  expect_identical(attr(frames, "format"), "mp4")
  info <- av::av_media_info(target)$video
  expect_identical(as.integer(info$width), 320L)
  expect_identical(as.integer(info$height), 320L)

  # A video needs even pixel dimensions, and says so rather than failing
  # inside the encoder.
  expect_error(animate(dn, step = 6, window = 6, width = 321,
    file = out_path(".mp4")),
  class = "dynet_bad_input")
  expect_error(animate(dn, step = 6, window = 6, file = out_path(".avi")),
    class = "dynet_unknown_format")
})

test_that("a GIF loops for ever by default and once when asked", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  looping <- out_path()
  once <- out_path()
  thrice <- out_path()
  animate(dn, step = 6, window = 6, tween = 1, file = looping)
  animate(dn, step = 6, window = 6, tween = 1, file = once, loop = FALSE)
  animate(dn, step = 6, window = 6, tween = 1, file = thrice, loop = 3)
  # Regression: `loop = 0`, the old default, wrote a GIF with no looping
  # block, which players show once. The block with count 0 means for ever.
  expect_identical(gif_loop_count(looping), 0L)
  expect_true(is.na(gif_loop_count(once)))
  expect_identical(gif_loop_count(thrice), 3L)
  expect_error(animate(dn, file = out_path(), loop = 0),
    class = "dynet_bad_input")
})

test_that("tie states describe the transition between two bins", {
  before <- matrix(c(0, 2, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 0,
    3, 0, 0, 0), 4L, byrow = TRUE)
  after <- matrix(c(0, 2, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 5,
    3, 0, 0, 0), 4L, byrow = TRUE)
  edges <- Dynet:::.transition_edges(before, after, directed = TRUE)
  key <- paste(edges$from, edges$to)
  expect_identical(edges$state[key == "1 2"], "persisting")
  expect_identical(edges$state[key == "4 1"], "persisting")
  expect_identical(edges$state[key == "2 3"], "dissolving")
  expect_identical(edges$state[key == "3 4"], "forming")
  expect_identical(nrow(edges), 4L)
  # A dissolving tie keeps its old weight, a forming one has its new weight.
  expect_identical(edges$before[key == "2 3"], 1)
  expect_identical(edges$after[key == "2 3"], 0)
  expect_identical(edges$after[key == "3 4"], 5)
  # The transition of a bin with itself has nothing forming or dissolving.
  same <- Dynet:::.transition_edges(after, after, directed = TRUE)
  expect_true(all(same$state == "persisting"))
})

test_that("per-edge vectors follow the order cograph draws", {
  skip_if_no_gif()
  # Every width, alpha, colour and line type the animation hands to splot()
  # is aligned to `.matrix_edges()`. cograph derives its own edge order from
  # the weights matrix; if that ever changed, every per-edge vector would be
  # drawn on the wrong tie. This pins the agreement on both kinds of network.
  for (directed in c(TRUE, FALSE)) {
    dn <- quiet_dynet(school_contacts, directed = directed)
    frames <- grid_frames(dn, step = 4, window = 4)
    for (k in seq_along(frames)[-length(frames)]) {
      edges <- Dynet:::.transition_edges(frames[[k]]$weights,
        frames[[k + 1L]]$weights, directed)
      w <- Dynet:::.transition_matrix(edges, seq_len(nrow(edges)),
        nrow(dn$nodes), directed)
      drawn <- cograph::get_edges(cograph::cograph(w, directed = directed))
      expect_identical(as.integer(drawn$from), edges$from)
      expect_identical(as.integer(drawn$to), edges$to)
    }
  }
})

test_that("one scale maps weights to widths in every frame", {
  # The defect this guards against: cograph scales widths against each
  # frame's own weight range, so a weight of 3 was drawn wide in a quiet
  # frame and narrow in a busy one. The animation maps through one range.
  widths <- Dynet:::.scale_to(c(1, 3, 5), from = c(1, 5), to = c(0.5, 3.5))
  expect_equal(widths, c(0.5, 2, 3.5))
  # The same weight gives the same width whatever else the frame holds.
  expect_equal(Dynet:::.scale_to(3, c(1, 5), c(0.5, 3.5)),
    Dynet:::.scale_to(c(3, 1, 1, 1), c(1, 5), c(0.5, 3.5))[[1L]])
  # A degenerate range gives the middle width rather than a division by zero.
  expect_equal(Dynet:::.scale_to(c(2, 2), c(2, 2), c(0.5, 3.5)), c(2, 2))
  expect_false(is.unsorted(Dynet:::.scale_to(1:9, c(1, 9), c(0.5, 3.5))))
})

test_that("node size follows the square root, so area follows the measure", {
  radii <- Dynet:::.size_scale(c(0, 10, 40), from = c(0, 40), to = c(1, 5))
  expect_equal(radii, c(1, 3, 5))
  # Monotone, bounded, and the same value gives the same radius whatever
  # else the frame holds.
  expect_false(is.unsorted(Dynet:::.size_scale(0:40, c(0, 40), c(1, 5))))
  expect_true(all(Dynet:::.size_scale(0:40, c(0, 40), c(1, 5)) <= 5))
  expect_equal(Dynet:::.size_scale(4, c(0, 16), c(1, 3)), 2)
  expect_equal(Dynet:::.size_scale(c(2, 2), c(2, 2), c(1, 5)), c(3, 3))
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  expect_error(animate(dn, step = 6, window = 6, measure = "degree",
                       node_size_range = c(5, 2), file = out_path()),
               class = "dynet_bad_input")
})

test_that("fixed layouts never move a vertex and a relaxed one is bounded", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  frames <- grid_frames(dn, step = 2, window = 4)
  own <- data.frame(name = dn$nodes$name,
    x = seq_len(nrow(dn$nodes)), y = rev(seq_len(nrow(dn$nodes))))

  for (layout in list("spring", "circle", "oval", own)) {
    fixed <- Dynet:::.animation_layouts(dn, frames, layout, 0.08, 1, 42)
    expect_length(fixed, length(frames))
    expect_identical(nrow(fixed[[1L]]), nrow(dn$nodes))
    expect_equal(largest_move(fixed), 0)
  }

  # The invariant that makes a relaxed animation readable: no vertex may move
  # further than `max_displacement` between consecutive bins, whatever the
  # structure does. Smoothing is a convex combination of the raw steps, so it
  # cannot break the bound.
  for (limit in c(0.02, 0.08, 0.3)) {
    relaxed <- Dynet:::.animation_layouts(dn, frames, "relaxed", limit, 1, 42)
    expect_lte(largest_move(relaxed), limit + 1e-9)
  }
})

test_that("smoothing shortens the largest move and leaves stillness alone", {
  set.seed(3)
  raw <- replicate(8, data.frame(x = stats::runif(5), y = stats::runif(5)),
    simplify = FALSE)
  smoothed <- Dynet:::.smooth_positions(raw)
  expect_length(smoothed, length(raw))
  expect_lte(largest_move(smoothed), largest_move(raw))
  still <- rep(list(raw[[1L]]), 6L)
  expect_equal(Dynet:::.smooth_positions(still), still)
  short <- raw[1:2]
  expect_identical(Dynet:::.smooth_positions(short), short)
})

test_that("a coordinate table must name every vertex once", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  n <- nrow(dn$nodes)
  full <- data.frame(name = dn$nodes$name, x = seq_len(n), y = seq_len(n))
  coords <- Dynet:::.custom_layout(dn, full[rev(seq_len(n)), ])
  # Rows come back in the network's vertex order whatever order they were
  # given in.
  expect_equal(coords$x, seq_len(n))
  expect_error(Dynet:::.custom_layout(dn, full[-1L, ]),
    class = "dynet_unknown_node")
  expect_error(Dynet:::.custom_layout(dn, rbind(full, full[1L, ])),
    class = "dynet_unknown_node")
  expect_error(Dynet:::.custom_layout(dn, full[c("name", "x")]),
    class = "dynet_missing_column")
  expect_error(animate(dn, step = 6, window = 6, layout = "groups",
    file = out_path()),
  class = "dynet_unknown_attribute")
})

test_that("a relaxed layout is reproducible from its seed", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  frames <- grid_frames(dn, step = 6, window = 6)
  first <- Dynet:::.animation_layouts(dn, frames, "relaxed", 0.08, 1, 7)
  again <- Dynet:::.animation_layouts(dn, frames, "relaxed", 0.08, 1, 7)
  expect_equal(first, again)
  other <- Dynet:::.animation_layouts(dn, frames, "relaxed", 0.08, 1, 8)
  expect_false(isTRUE(all.equal(first, other)))

  # The caller's random state survives the call, with and without a seed.
  set.seed(99)
  before <- .Random.seed
  invisible(Dynet:::.animation_layouts(dn, frames, "relaxed", 0.08, 1, 7))
  expect_identical(.Random.seed, before)
  invisible(animate(dn, step = 6, window = 6, tween = 1,
    file = out_path()))
  expect_identical(.Random.seed, before)
})

test_that("every vertex keeps one position across the whole animation", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  frames <- grid_frames(dn, step = 4, window = 4)
  # Laying a frame out over only its active vertices would move a vertex
  # whenever its neighbours came and went, which is the defect the
  # `all_vertices` argument exists to prevent.
  sizes <- vapply(frames, function(net) nrow(net$nodes), integer(1L))
  expect_true(all(sizes == nrow(dn$nodes)))
})

test_that("presence follows declared vertex activity", {
  skip_if_no_gif()
  dn <- quiet_dynet(forum_posts, thread = "thread", time = "timestamp",
    directed = TRUE)
  enc <- Dynet:::.encode(dn)
  spec <- Dynet:::.window_spec(dn, NULL, NULL, 5, 10)
  grid <- Dynet:::.grid_for(enc, dn, spec)
  present <- Dynet:::.frame_presence(dn, enc, grid, spec$window, "bounded")
  expect_identical(dim(present), c(nrow(grid), nrow(dn$nodes)))
  expect_true(any(present))
  frames <- animate(dn, step = 5, window = 10, tween = 1,
    file = out_path())
  expect_identical(frames$nodes, as.integer(rowSums(present)))
})

test_that("node size follows a measure computed on the animation's grid", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  enc <- Dynet:::.encode(dn)
  spec <- Dynet:::.window_spec(dn, NULL, NULL, 4, 4)
  grid <- Dynet:::.grid_for(enc, dn, spec)
  # `.animation_measure()` returns the matrix beside its axis label, which is
  # what animate() consumes; the matrix itself is `$values`.
  measured <- Dynet:::.animation_measure(dn, "degree", grid, "bounded",
    NULL, NULL, 4, 4)
  values <- measured$values
  expect_identical(dim(values), c(nrow(grid), nrow(dn$nodes)))
  # Each cell is the measure the verb reports for that bin and vertex.
  reported <- centrality_series(dn, measure = "degree", step = 4, window = 4)
  reported <- as.data.frame(reported)
  hit <- reported$node == "Ana" & abs(reported$time - grid$time[[2L]]) < 1e-9
  expect_equal(values[2L, match("Ana", dn$nodes$name)], reported$value[hit])

  frames <- animate(dn, step = 4, window = 4, tween = 1,
    measure = "degree", file = out_path())
  expect_identical(attr(frames, "measure"), "degree")
  expect_identical(summary(frames)$measure, "degree")
  expect_error(animate(dn, step = 4, window = 4, measure = "bogus",
    file = out_path()),
  class = "dynet_unknown_measure")
  undirected <- quiet_dynet(school_contacts, directed = FALSE)
  expect_error(animate(undirected, step = 4, window = 4,
    measure = "hub", file = out_path()),
  class = "dynet_needs_directed")
})

test_that("measure may be a centrality_series result or a vertex attribute", {
  skip_if_no_gif()
  dn <- quiet_dynet(
    school_contacts,
    nodes = data.frame(name = c("Ana", "Ben", "Cara", "Dan", "Eve", "Finn",
                                "Gita", "Hugo", "Iris", "Jonas", "Kira",
                                "Leo", "Mira", "Nils"),
                       tier = c(4, rep(1, 13L)),
                       house = rep(c("a", "b"), 7L))
  )
  enc <- Dynet:::.encode(dn)
  spec <- Dynet:::.window_spec(dn, NULL, NULL, 4, 4)
  grid <- Dynet:::.grid_for(enc, dn, spec)

  # A result on the same grid gives exactly what the name gives.
  by_name <- Dynet:::.animation_measure(dn, "degree", grid, "bounded",
                                        NULL, NULL, 4, 4)
  per_bin <- centrality_series(dn, measure = "degree", step = 4, window = 4)
  by_object <- Dynet:::.animation_measure(dn, per_bin, grid, "bounded",
                                          NULL, NULL, 4, 4)
  expect_identical(by_object$values, by_name$values)

  # One time point means one size per vertex for the whole film.
  whole <- centrality_series(dn, measure = "degree", window = "all")
  fixed <- Dynet:::.animation_measure(dn, whole, grid, "bounded",
                                      NULL, NULL, 4, 4)
  expect_identical(dim(fixed$values), c(nrow(grid), nrow(dn$nodes)))
  expect_true(all(apply(fixed$values, 2L, function(v) length(unique(v)) == 1L)))
  expect_match(fixed$label, "whole period")
  whole_tbl <- as.data.frame(whole)
  expect_equal(fixed$values[1L, match("Ana", dn$nodes$name)],
               whole_tbl$value[whole_tbl$node == "Ana"])

  # A numeric attribute is constant too; a non-numeric one is refused.
  tier <- Dynet:::.animation_measure(dn, "tier", grid, "bounded",
                                     NULL, NULL, 4, 4)
  expect_identical(tier$values[3L, ], c(4, rep(1, 13L)))
  expect_error(Dynet:::.animation_measure(dn, "house", grid, "bounded",
                                          NULL, NULL, 4, 4),
               class = "dynet_unknown_measure")
  expect_error(Dynet:::.animation_measure(dn, "nothing", grid, "bounded",
                                          NULL, NULL, 4, 4),
               class = "dynet_unknown_measure")

  # A result on another grid lands on no bin and says so; one that lands
  # on only some bins warns; a graph-level result is not a node measure.
  elsewhere <- centrality_series(dn, measure = "degree", start = 0.5, end = 10,
                                 step = 3, window = 3)
  expect_error(Dynet:::.animation_measure(dn, elsewhere, grid, "bounded",
                                          NULL, NULL, 4, 4),
               class = "dynet_bad_input")
  partial <- centrality_series(dn, measure = "degree", start = 0, end = 8,
                               step = 4, window = 4)
  expect_warning(Dynet:::.animation_measure(dn, partial, grid, "bounded",
                                            NULL, NULL, 4, 4),
                 class = "dynet_partial_measure")
  graph_level <- metrics(dn, measure = "density", step = 4, window = 4)
  expect_error(Dynet:::.animation_measure(dn, graph_level, grid, "bounded",
                                          NULL, NULL, 4, 4),
               class = "dynet_bad_input")

  frames <- animate(dn, step = 4, window = 4, tween = 1, measure = whole,
                    file = out_path())
  expect_match(summary(frames)$measure, "whole period")
  frames <- animate(dn, step = 4, window = 4, tween = 1, measure = "tier",
                    file = out_path())
  expect_identical(summary(frames)$measure, "tier")
})

test_that("an absent vertex can wait at the edge of the layout", {
  set.seed(5)
  pos <- data.frame(x = c(stats::runif(9), 0.5), y = c(stats::runif(9), 0.5))
  parked <- Dynet:::.park_positions(pos)
  expect_identical(dim(parked), dim(pos))
  # Every parking spot lies on the layout's own bounding box, so parked
  # vertices never widen the picture.
  on_box <- abs(parked$x - min(pos$x)) < 1e-9 |
    abs(parked$x - max(pos$x)) < 1e-9 |
    abs(parked$y - min(pos$y)) < 1e-9 |
    abs(parked$y - max(pos$y)) < 1e-9
  expect_true(all(on_box))
  expect_equal(range(c(parked$x, pos$x)), range(pos$x))
  expect_equal(range(c(parked$y, pos$y)), range(pos$y))
  # A vertex at the exact centre leaves to the right rather than nowhere.
  centre <- data.frame(x = mean(range(pos$x)), y = mean(range(pos$y)))
  expect_true(abs(Dynet:::.park_positions(rbind(pos, centre))$x[[11L]] -
                    max(pos$x)) < 1e-9)
  # One vertex has nowhere to go and stays put.
  expect_equal(Dynet:::.park_positions(data.frame(x = 0.3, y = 0.7)),
               data.frame(x = 0.3, y = 0.7))
})

test_that("absence and idleness are drawn as asked", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  spanned <- set_vertex_spells(dn, "ties")
  for (choice in c("fade", "away", "hide")) {
    frames <- animate(spanned, step = 6, window = 6, tween = 2,
                      absent = choice, file = out_path())
    expect_s3_class(frames, "dynet_animation")
  }
  for (choice in c("fade", "show", "hide")) {
    frames <- animate(dn, step = 6, window = 6, tween = 2,
                      isolates = choice, file = out_path())
    expect_s3_class(frames, "dynet_animation")
  }
  expect_error(animate(dn, step = 6, window = 6, absent = "vanish",
                       file = out_path()))
  expect_error(animate(dn, step = 6, window = 6, isolates = "drop",
                       file = out_path()))
})

test_that("continuous easing runs a spline through the bins", {
  # Through the two inner points exactly, and straight when the points are
  # collinear and evenly spaced.
  line <- lapply(0:3, function(i) data.frame(x = i, y = 2 * i))
  at_start <- Dynet:::.catmull_rom(line[[1]], line[[2]], line[[3]], line[[4]], 0)
  at_end <- Dynet:::.catmull_rom(line[[1]], line[[2]], line[[3]], line[[4]], 1)
  expect_equal(at_start, line[[2]])
  expect_equal(at_end, line[[3]])
  midway <- Dynet:::.catmull_rom(line[[1]], line[[2]], line[[3]], line[[4]], 0.5)
  expect_equal(midway, data.frame(x = 1.5, y = 3))

  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  bins <- data.frame(lo = c(0, 4, 8), hi = c(4, 8, 12), time = c(0, 4, 8))
  dwell <- Dynet:::.frame_schedule(bins, 4L, "dwell")
  flow <- Dynet:::.frame_schedule(bins, 4L, "continuous")
  expect_equal(flow$eased, flow$phase)
  expect_true(all(dwell$eased <= dwell$phase | dwell$phase > 0.5))
  frames <- animate(dn, step = 4, window = 8, tween = 3, ease = "continuous",
                    layout = "relaxed", absent = "away", file = out_path())
  expect_identical(summary(frames)$ease, "continuous")
  expect_error(animate(dn, step = 4, window = 4, ease = "bouncy",
                       file = out_path()))
})

test_that("a relaxed frame is framed by its active vertices", {
  pos <- data.frame(x = c(0.2, 0.4, 0.6, 0.9, 0.05),
                    y = c(0.3, 0.5, 0.4, 0.95, 0.1))
  active <- c(TRUE, TRUE, TRUE, FALSE, FALSE)
  framed <- Dynet:::.frame_to_active(pos, active)
  # Active vertices stay put; the others land on the border of their box.
  expect_equal(framed[active, ], pos[active, ])
  expect_equal(range(framed$x), range(pos$x[active]))
  expect_equal(range(framed$y), range(pos$y[active]))
  expect_equal(framed$x[[4L]], 0.6)
  expect_equal(framed$y[[5L]], 0.3)
  # Nothing active, nothing to frame by.
  expect_identical(Dynet:::.frame_to_active(pos, rep(FALSE, 5L)), pos)

  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  frames <- grid_frames(dn, step = 4, window = 4)
  # `layout_args` reaches the spring layout: fewer iterations, another layout.
  default <- Dynet:::.animation_layouts(dn, frames, "spring", 0.08, 1, 42)
  brief <- Dynet:::.animation_layouts(dn, frames, "spring", 0.08, 1, 42,
                                      layout_args = list(iterations = 3L))
  expect_false(isTRUE(all.equal(default[[1L]], brief[[1L]])))
  expect_error(animate(dn, step = 6, window = 6, layout_args = list(3),
                       file = out_path()),
               class = "dynet_bad_input")
})

test_that("bins nobody is present in are skipped with a message", {
  skip_if_no_gif()
  log <- data.frame(from = c("A", "C"), to = c("B", "D"),
    start = c(0, 8), end = c(2, 10))
  # Presence is declared through `vertex_spells`, not through the node table:
  # onset/terminus columns on `nodes` are ordinary attributes and leave every
  # vertex active at all times, so nothing would be skipped.
  spells <- data.frame(name = c("A", "B", "C", "D"),
    onset = c(0, 0, 8, 8), terminus = c(2, 2, 10, 10))
  dn <- quiet_dynet(log, nodes = data.frame(name = c("A", "B", "C", "D")),
    vertex_spells = spells)
  expect_message(
    frames <- animate(dn, start = 0, end = 10, step = 2, window = 2,
      tween = 1, file = out_path()),
    "Skipping"
  )
  expect_lt(nrow(frames), 5L)
  expect_true(all(frames$nodes > 0))
})

test_that("every named layout and drawing option renders", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  grouped <- quiet_dynet(
    school_contacts,
    nodes = data.frame(name = dn$nodes$name,
      house = rep(c("a", "b", "c"), length.out = 14L)),
    groups = "house"
  )
  for (layout in c("circle", "oval", "relaxed")) {
    frames <- animate(dn, step = 6, window = 6, tween = 2,
      layout = layout, file = out_path())
    expect_identical(attr(frames, "layout"), layout)
  }
  frames <- animate(grouped, step = 6, window = 6, tween = 2,
    layout = "groups", file = out_path())
  expect_identical(attr(frames, "layout"), "groups")
  own <- data.frame(name = dn$nodes$name, x = seq_len(14L), y = seq_len(14L))
  frames <- animate(dn, step = 6, window = 6, tween = 2, layout = own,
    file = out_path())
  expect_identical(attr(frames, "layout"), "custom")
  plain <- animate(dn, step = 6, window = 6, tween = 2,
    tie_states = FALSE, timeline = FALSE,
    sessions = "collapse", edge_width_range = c(1, 6),
    edge_alpha = 0.9, node_size = 10, file = out_path())
  expect_s3_class(plain, "dynet_animation")
})

test_that("labels may name a vertex attribute", {
  skip_if_no_gif()
  dn <- quiet_dynet(
    school_contacts,
    nodes = data.frame(name = c("Ana", "Ben", "Cara", "Dan", "Eve", "Finn",
                                "Gita", "Hugo", "Iris", "Jonas", "Kira",
                                "Leo", "Mira", "Nils"),
                       short = c("An", "Be", "Ca", "Da", "Ev", "Fi", "Gi",
                                 "Hu", "Ir", "Jo", "Ki", "Le", "Mi", "Ni"))
  )
  frames <- animate(dn, step = 6, window = 6, tween = 1, labels = "short",
                    file = out_path())
  expect_s3_class(frames, "dynet_animation")
  expect_error(animate(dn, step = 6, window = 6, labels = "nickname",
                       file = out_path()),
               class = "dynet_unknown_attribute")
  # `label` is the reserved node-table column and holds the vertex name.
  expect_error(animate(dn, step = 6, window = 6, labels = "label",
                       file = out_path()),
               class = "dynet_unknown_attribute")
})

test_that("animate rejects bad arguments by class", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  target <- out_path()
  expect_error(animate(dn, file = target, fps = 0),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, fps = c(2, 3)),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, tween = 0),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, tween = 1.5),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, loop = -1),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, width = 0),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, res = -10),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, measure = c("degree", "load")),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, tie_states = NA),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, max_displacement = -1),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = target, anchor_strength = -1),
    class = "dynet_bad_input")
  expect_error(animate(dn, file = NA_character_), class = "dynet_bad_input")
  expect_error(animate(dn, file = target, layout = "wiggle"))
  expect_error(animate(dn, file = target, sessions = "separate"))
})

test_that("the print, summary and as.data.frame methods hold their contract", {
  skip_if_no_gif()
  dn <- quiet_dynet(school_contacts)
  target <- out_path()
  frames <- animate(dn, step = 6, window = 6, tween = 3, file = target,
    fps = 4)

  expect_output(print(frames), "Animation of")
  expect_output(print(frames), "spring layout")
  expect_output(print(frames), "gif")
  # print() returns its argument invisibly; capture the drawing so the test
  # output stays readable.
  returned <- NULL
  invisible(utils::capture.output(returned <- print(frames)))
  expect_identical(returned, frames)

  described <- summary(frames)
  expect_s3_class(described, "data.frame")
  expect_identical(nrow(described), 1L)
  expect_identical(described$bins, nrow(frames))
  expect_identical(described$frames, nrow(frames) * 3L)
  expect_equal(described$seconds, nrow(frames) * 3L / 4)
  expect_identical(described$tween, 3L)
  expect_identical(described$layout, "spring")
  expect_identical(described$format, "gif")
  expect_true(is.na(described$measure))
  expect_identical(described$file, target)
  # Turnover is a share, and it is what the forming column says it is.
  expect_true(described$turnover >= 0 && described$turnover <= 1)
  later <- as.data.frame(frames)[-1L, ]
  expect_equal(described$turnover, stats::median(later$forming / later$ties))
  single <- animate(dn, step = 24, window = 24, tween = 1, file = out_path())
  expect_true(is.na(summary(single)$turnover))

  plain <- as.data.frame(frames)
  expect_identical(class(plain), "data.frame")
  expect_identical(nrow(plain), nrow(frames))
  schedule <- as.data.frame(frames, what = "frames")
  expect_identical(class(schedule), "data.frame")
  expect_identical(nrow(schedule), nrow(frames) * 3L)
})
