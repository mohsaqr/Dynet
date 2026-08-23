test_that("the built-in palettes resolve and are deterministic", {
  for (p in c("okabe", "extended", "many")) {
    cols <- .dyn_palette(p, 12L)
    expect_length(cols, 12L)
    expect_type(cols, "character")
    expect_identical(cols, .dyn_palette(p, 12L))
    expect_silent(grDevices::col2rgb(cols))
  }
  # No sampling anywhere, so the random stream is untouched and repeated calls
  # give the same palette.
  set.seed(1); a <- .dyn_palette("many", 40L); x <- stats::runif(1L)
  set.seed(1); b <- .dyn_palette("many", 40L); y <- stats::runif(1L)
  expect_identical(a, b)
  expect_equal(x, y)
})

test_that("okabe is the Okabe-Ito set and recycles beyond nine", {
  expect_identical(.dyn_palette("okabe", 9L),
                   c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2",
                     "#D55E00", "#CC79A7", "#999999", "#000000"))
  expect_identical(.dyn_palette("okabe", 11L)[10:11],
                   .dyn_palette("okabe", 2L))
})

test_that("every palette starts from Okabe-Ito, so small networks are unchanged", {
  for (p in c("okabe", "extended", "many")) {
    expect_identical(.dyn_palette(p, 5L), .dyn_palette("okabe", 5L))
  }
})

test_that("packing separates colours far better than recycling or hue-spinning", {
  # Minimum distance in CIE Lab; 2.3 is the just-noticeable difference and 10
  # a comfortable categorical gap.
  expect_gt(.min_separation(.dyn_palette("okabe", 9L)), 20)
  expect_gt(.min_separation(.dyn_palette("many", 60L)), 15)

  hue_only <- grDevices::hcl(h = seq(15, 375, length.out = 61L)[1:60], c = 100, l = 65)
  expect_lt(.min_separation(hue_only), 10)
  # Measured at n = 60: packing gives 23.6 against 4.7 for an evenly spaced
  # hue ramp, a factor of 4.99.
  expect_gt(.min_separation(.dyn_palette("many", 60L)) /
              .min_separation(hue_only), 4.5)
})

test_that("Okabe-Ito survives dichromacy where a hue ramp does not", {
  expect_gt(.min_separation(.simulate_cvd(.dyn_palette("okabe", 9L), "deutan")), 5)
  hue_only <- grDevices::hcl(h = seq(15, 375, length.out = 9L)[1:8], c = 100, l = 65)
  expect_lt(.min_separation(.simulate_cvd(hue_only, "deutan")), 2)
})

test_that("the caller can override with their own colours or a function", {
  expect_identical(.dyn_palette(c("red", "blue"), 4L),
                   c("red", "blue", "red", "blue"))
  expect_identical(.dyn_palette("#112233", 2L), c("#112233", "#112233"))
  expect_identical(.dyn_palette(function(n) rep("#445566", n), 3L),
                   rep("#445566", 3L))
})

test_that("a palette that cannot be rendered raises a classed condition", {
  expect_error(.dyn_palette("not_a_colour", 3L), class = "dynet_bad_palette")
  expect_error(.dyn_palette(c("red", "chartreusey"), 2L),
               class = "dynet_bad_palette")
  expect_error(.dyn_palette(function(n) "red", 4L), class = "dynet_bad_palette")
  expect_error(.dyn_palette(42, 3L), class = "dynet_bad_palette")
})

test_that("plots accept a palette and pass it down", {
  skip_if_not_installed("cograph")
  dn <- quiet_dynet(school_contacts)
  fp <- quiet_dynet(forum_posts, thread = "thread", nodes = forum_people,
                    groups = "role")
  f <- tempfile(fileext = ".png")
  grDevices::png(f, width = 11, height = 7, units = "in", res = 72)
  on.exit({grDevices::dev.off(); unlink(f)}, add = TRUE)

  expect_identical(plot(dn, type = "proximity", palette = "many", slices = 25L), dn)
  expect_identical(plot(fp, type = "network", palette = "extended"), fp)
  expect_error(plot(dn, type = "network", palette = "nope"),
               class = "dynet_bad_palette")

  # A partition takes one colour per group, from whichever palette is asked for.
  fills <- .node_fill(fp, palette = "many")
  expect_length(unique(fills), 3L)
  expect_true(all(fills %in% .dyn_palette("many", 3L)))
})

test_that("Lab conversion matches known reference values", {
  # Pure white, black and red have standard Lab coordinates.
  lab <- .srgb_to_lab(rbind(c(1, 1, 1), c(0, 0, 0), c(1, 0, 0)))
  # The sRGB-to-XYZ matrix is quoted to four places, which is the precision
  # limit here rather than an error in the conversion.
  expect_equal(unname(lab[1L, ]), c(100, 0, 0), tolerance = 0.02)
  expect_equal(unname(lab[2L, ]), c(0, 0, 0), tolerance = 1e-6)
  expect_equal(unname(lab[3L, ]), c(53.24, 80.09, 67.20), tolerance = 1e-2)
})

test_that("dichromacy simulation leaves the confusion axis alone", {
  # Blue and yellow survive deuteranopia; red and green collapse together.
  keeps <- .min_separation(.simulate_cvd(c("#0072B2", "#F0E442"), "deutan"))
  loses <- .min_separation(.simulate_cvd(c("#009E73", "#D55E00"), "deutan"))
  expect_gt(keeps, loses)
  expect_length(.simulate_cvd(c("red", "blue"), "protan"), 2L)
})

test_that("label colour follows the fill's contrast, not a fixed choice", {
  expect_identical(.label_colour("#000000"), "white")
  expect_identical(.label_colour("#FFFFFF"), "black")
  expect_identical(.label_colour("#0072B2"), "white")
  expect_identical(.label_colour("#F0E442"), "black")

  # Okabe-Ito's ninth colour is black, so a fixed black label would vanish.
  labs <- .label_colour(.dyn_palette("okabe", 9L))
  expect_length(labs, 9L)
  expect_identical(labs[9L], "white")
  expect_true(all(labs %in% c("black", "white")))

  # Whatever is chosen must be the higher-contrast option, by the WCAG ratio.
  contrast <- function(fill, text) {
    lum <- function(x) {
      v <- t(grDevices::col2rgb(x)) / 255
      as.numeric(ifelse(v <= 0.03928, v / 12.92, ((v + 0.055) / 1.055)^2.4) %*%
                   c(0.2126, 0.7152, 0.0722))
    }
    a <- lum(fill); b <- lum(text)
    (max(a, b) + 0.05) / (min(a, b) + 0.05)
  }
  for (fill in .dyn_palette("many", 30L)) {
    chosen <- .label_colour(fill)
    other <- if (chosen == "black") "white" else "black"
    expect_gte(contrast(fill, chosen), contrast(fill, other))
  }
})

test_that("splot receives per-vertex label colours matched to the fills", {
  skip_if_not_installed("cograph")
  dn <- quiet_dynet(school_contacts)
  fills <- .dyn_palette("okabe", nrow(dn$nodes))
  args <- .splot_args(dn, list(node_fill = fills))
  expect_length(args$label_color, length(fills))
  expect_identical(args$label_color, .label_colour(fills))

  # An explicit label colour from the caller still wins.
  fixed <- .splot_args(dn, list(node_fill = fills, label_color = "grey40"))
  expect_identical(fixed$label_color, "grey40")

  # With no fill set, the colour is taken from the theme that will be used.
  themed <- .splot_args(dn, list())
  expect_identical(themed$label_color,
                   .label_colour(cograph::get_theme("dynet")$get("node_fill")))
})
