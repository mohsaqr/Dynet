# A truncated result must not describe itself as a whole one, and a plot label
# must survive the devices R CMD check actually draws on.

test_that("head() keeps the header describing the series, not the fragment", {
  dn <- quiet_dynet(random_edges())
  ev <- events(dn)
  full <- paste(utils::capture.output(print(ev)), collapse = "\n")
  cut  <- paste(utils::capture.output(print(head(ev, 6))), collapse = "\n")

  points <- sprintf("%d time points", length(unique(ev$time)))
  expect_true(grepl(points, full, fixed = TRUE))
  expect_true(grepl(points, cut, fixed = TRUE))
  expect_true(grepl(sprintf("first 6 of %d rows", nrow(ev)), cut, fixed = TRUE))
})

test_that("tail() records the side it kept", {
  dn <- quiet_dynet(random_edges())
  ev <- events(dn)
  cut <- paste(utils::capture.output(print(tail(ev, 4))), collapse = "\n")
  expect_true(grepl(sprintf("last 4 of %d rows", nrow(ev)), cut, fixed = TRUE))
})

test_that("head() and tail() return the measure, truncated", {
  dn <- quiet_dynet(random_edges())
  ev <- events(dn)
  expect_s3_class(head(ev, 6), "dynet_metric")
  expect_s3_class(tail(ev, 6), "dynet_metric")
  expect_identical(nrow(head(ev, 6)), 6L)
  expect_identical(nrow(tail(ev, 6)), 6L)
  expect_identical(as.data.frame(head(ev, 6)),
                   utils::head(as.data.frame(ev), 6))
})

test_that("truncating a fragment keeps the original series counts", {
  dn <- quiet_dynet(random_edges())
  ev <- events(dn)
  twice <- head(head(ev, 10), 3)
  expect_identical(attr(twice, "fragment"), attr(head(ev, 10), "fragment"))
  expect_true(grepl(sprintf("first 3 of %d rows", nrow(ev)),
                    paste(utils::capture.output(print(twice)), collapse = "\n"),
                    fixed = TRUE))
})

test_that("the recorded counts equal the source counts for every n", {
  dn <- quiet_dynet(random_edges())
  ev <- events(dn)
  invisible(lapply(c(1L, 2L, 5L, nrow(ev)), function(k) {
    counts <- attr(head(ev, k), "fragment")$counts
    expect_identical(counts$rows, nrow(ev))
    expect_identical(counts$time, length(unique(ev$time)))
  }))
})

test_that("an untruncated measure carries no fragment record", {
  dn <- quiet_dynet(random_edges())
  ev <- events(dn)
  expect_null(attr(ev, "fragment"))
  expect_false(grepl(" of ", paste(utils::capture.output(print(ev, n = 3)),
                                   collapse = "\n"), fixed = TRUE))
})

test_that("pair labels are ASCII, so single-byte devices render them", {
  expect_identical(.pair_label("A", "B", TRUE), "A -> B")
  expect_identical(.pair_label("A", "B", FALSE), "A - B")
  expect_identical(Encoding(.pair_label("A", "B", TRUE)), "unknown")
  expect_false(any(grepl("[^\x01-\x7f]", .pair_label("A", "B", TRUE))))
})

test_that("the timeline draws on a pdf device without substituting glyphs", {
  dn <- quiet_dynet(random_edges())
  file <- tempfile(fileext = ".pdf")
  grDevices::pdf(file)
  on.exit({
    if (grDevices::dev.cur() > 1L) grDevices::dev.off()
    unlink(file)
  }, add = TRUE)

  seen <- character()
  withCallingHandlers(
    print(plot(dn, type = "timeline")),
    warning = function(cond) {
      seen <<- c(seen, conditionMessage(cond))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl("mbcsToSbcs", seen)))
})

test_that("a projection prints a header instead of dumping its meta list", {
  dn <- quiet_dynet(random_edges())
  out <- utils::capture.output(print(projection(dn, step = 5)))
  expect_true(any(grepl("^# Time-projected network", out)))
  expect_false(any(grepl("session_aggregation", out[-2])))
})
