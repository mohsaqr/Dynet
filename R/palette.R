# ===========================================================================
# Palettes
# ===========================================================================

.okabe <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2",
            "#D55E00", "#CC79A7", "#999999", "#000000")

#' Okabe-Ito qualitative palette
#'
#' Colour-blind safe. Recycled when more colours are asked for than the nine
#' it holds, on the understanding that whatever is drawn also carries a label.
#'
#' @param n Number of colours needed.
#' @return A character vector of hex colours.
#' @references Okabe, M., & Ito, K. (2008). Color universal design.
#' @noRd
.okabe_ito <- function(n = 9L) rep(.okabe, length.out = max(1L, n))

#' Resolve a palette specification to colours
#'
#' @param palette One of `"okabe"`, `"extended"`, `"many"`, a character vector
#'   of colours, or a function taking `n` and returning `n` colours.
#' @param n Number of colours needed.
#' @return A character vector of `n` colours.
#'
#' @details
#' The three built-in options trade separability against colour-blind safety,
#' and the trade is real rather than a matter of taste. Measured as the
#' smallest distance between any two colours in CIE Lab, where 2.3 is the
#' just-noticeable difference and 10 a comfortable categorical gap:
#'
#' \describe{
#'   \item{`"okabe"`}{Nine colours, minimum separation 26.4, and 7.3 under
#'     simulated deuteranopia. Recycles beyond nine.}
#'   \item{`"extended"`}{Hue varied together with lightness, which is what
#'     lets a palette survive dichromacy: an evenly spaced hue ramp collapses
#'     to a minimum separation below 1 at only eight colours, whereas varying
#'     lightness holds roughly twelve.}
#'   \item{`"many"`}{Okabe-Ito extended by farthest-point packing in Lab, for
#'     as many colours as asked. At sixty it holds a minimum separation of
#'     about 23, against 0.4 for the common recipe of concatenating every
#'     qualitative ColorBrewer palette -- which puts `#E41A1C` and `#E31A1C`
#'     in the same vector. It is not colour-blind safe, and cannot be: sixty
#'     categories do not fit in the space dichromatic vision leaves. Treat it
#'     as grouping and decoration, and let labels do the identifying.}
#' }
#'
#' Every option is deterministic; none draws a random sample, so the same
#' network gets the same colours on every run.
#'
#' @noRd
.dyn_palette <- function(palette = "okabe", n = 9L) {
  n <- max(1L, as.integer(n))
  if (is.function(palette)) {
    out <- palette(n)
    if (!is.character(out) || length(out) < n) {
      stop(errorCondition(
        sprintf("A palette function must return at least %d colours; it returned %d.",
                n, length(out)),
        class = "dynet_bad_palette", call = NULL))
    }
    return(.check_colours(out[seq_len(n)]))
  }
  if (!is.character(palette) || length(palette) == 0L) {
    stop(errorCondition(
      "`palette` must be \"okabe\", \"extended\", \"many\", a vector of colours, or a function of n.",
      class = "dynet_bad_palette", call = NULL))
  }
  if (length(palette) == 1L && palette %in% c("okabe", "extended", "many")) {
    return(switch(palette,
      okabe    = .okabe_ito(n),
      extended = .palette_extended(n),
      many     = .palette_many(n)))
  }
  # Anything else is taken as the caller's own colours.
  .check_colours(rep(palette, length.out = n))
}

#' Reject anything R cannot render as a colour
#' @param x Character vector.
#' @return `x`, unchanged.
#' @noRd
.check_colours <- function(x) {
  ok <- vapply(x, function(v) {
    !inherits(try(grDevices::col2rgb(v), silent = TRUE), "try-error")
  }, logical(1L))
  if (!all(ok)) {
    stop(errorCondition(
      sprintf("Not a colour: %s", paste(unique(x[!ok]), collapse = ", ")),
      class = "dynet_bad_palette", call = NULL))
  }
  unname(x)
}

#' Qualitative palette varying hue together with lightness
#' @param n Number of colours needed.
#' @return A character vector of `n` colours.
#' @noRd
.palette_extended <- function(n) {
  if (n <= length(.okabe)) return(.okabe[seq_len(n)])
  levels <- c(40, 58, 76, 90)
  chroma <- c(85, 100, 70, 55)
  per <- ceiling(n / length(levels))
  bands <- lapply(seq_along(levels), function(i) {
    hues <- (seq(15, 375, length.out = per + 1L)[seq_len(per)] +
               (i - 1L) * 360 / (per * length(levels))) %% 360
    grDevices::hcl(h = hues, c = chroma[i], l = levels[i])
  })
  unlist(bands, use.names = FALSE)[seq_len(n)]
}

#' Palette packed for maximum separation in CIE Lab
#'
#' Starts from Okabe-Ito so that small networks keep the familiar colours, and
#' extends by repeatedly taking the colour furthest from everything chosen so
#' far. Deterministic: no sampling and no seed.
#'
#' @param n Number of colours needed.
#' @param grid Points per sRGB axis in the candidate lattice.
#' @return A character vector of `n` colours.
#' @noRd
.palette_many <- function(n, grid = 16L) {
  if (n <= length(.okabe)) return(.okabe[seq_len(n)])
  steps <- seq(0.06, 0.94, length.out = grid)
  rgb_grid <- as.matrix(expand.grid(r = steps, g = steps, b = steps))
  lab <- .srgb_to_lab(rgb_grid)
  hexes <- grDevices::rgb(rgb_grid[, 1L], rgb_grid[, 2L], rgb_grid[, 3L])

  seed_lab <- .srgb_to_lab(t(grDevices::col2rgb(.okabe)) / 255)
  dmin <- Reduce(pmin, lapply(seq_len(nrow(seed_lab)), function(i)
    sqrt(colSums((t(lab) - seed_lab[i, ])^2))))

  out <- .okabe
  # Each pick depends on every pick before it, so this cannot be vectorised.
  while (length(out) < n) {
    k <- which.max(dmin)
    out <- c(out, hexes[k])
    dmin <- pmin(dmin, sqrt(colSums((t(lab) - lab[k, ])^2)))
  }
  out
}


# ---------------------------------------------------------------------------
# Colour science, in base R, so palettes can be checked rather than trusted
# ---------------------------------------------------------------------------

#' Convert sRGB to CIE Lab
#' @param rgb Matrix of sRGB values in `[0, 1]`, one colour per row.
#' @return A matrix with columns `L`, `a`, `b`.
#' @noRd
.srgb_to_lab <- function(rgb) {
  lin <- ifelse(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4)
  m <- matrix(c(0.4124, 0.3576, 0.1805,
                0.2126, 0.7152, 0.0722,
                0.0193, 0.1192, 0.9505), 3L, 3L, byrow = TRUE)
  xyz <- lin %*% t(m)
  white <- c(0.95047, 1, 1.08883)
  f <- function(t) ifelse(t > (6 / 29)^3, t^(1 / 3), t / (3 * (6 / 29)^2) + 4 / 29)
  fx <- f(xyz[, 1L] / white[1L])
  fy <- f(xyz[, 2L] / white[2L])
  fz <- f(xyz[, 3L] / white[3L])
  cbind(L = 116 * fy - 16, a = 500 * (fx - fy), b = 200 * (fy - fz))
}

#' Smallest distance between any two colours in a palette
#' @param colours Character vector of colours.
#' @return A single numeric; `NA` for fewer than two colours.
#' @noRd
.min_separation <- function(colours) {
  if (length(colours) < 2L) return(NA_real_)
  min(stats::dist(.srgb_to_lab(t(grDevices::col2rgb(colours)) / 255)))
}

#' Simulate how a palette looks to dichromatic vision
#' @param colours Character vector of colours.
#' @param type `"deutan"` or `"protan"`.
#' @return A character vector of simulated colours.
#' @references Vienot, F., Brettel, H., & Mollon, J. D. (1999). Digital video
#'   colourmaps for checking the legibility of displays by dichromats.
#'   *Color Research and Application*, 24(4), 243-252.
#' @noRd
.simulate_cvd <- function(colours, type = c("deutan", "protan")) {
  type <- match.arg(type)
  rgb_in <- t(grDevices::col2rgb(colours)) / 255
  lin <- ifelse(rgb_in <= 0.04045, rgb_in / 12.92, ((rgb_in + 0.055) / 1.055)^2.4)
  to_lms <- matrix(c(17.8824, 43.5161, 4.11935,
                     3.45565, 27.1554, 3.86714,
                     0.0299566, 0.184309, 1.46709), 3L, 3L, byrow = TRUE)
  collapse <- switch(type,
    deutan = matrix(c(1, 0, 0, 0.494207, 0, 1.24827, 0, 0, 1), 3L, 3L, byrow = TRUE),
    protan = matrix(c(0, 2.02344, -2.52581, 0, 1, 0, 0, 0, 1), 3L, 3L, byrow = TRUE))
  back <- ((lin %*% t(to_lms)) %*% t(collapse)) %*% t(solve(to_lms))
  back <- pmin(pmax(back, 0), 1)
  out <- ifelse(back <= 0.0031308, 12.92 * back, 1.055 * back^(1 / 2.4) - 0.055)
  grDevices::rgb(out[, 1L], out[, 2L], out[, 3L])
}


#' Choose label colours that stay readable on their background
#'
#' Black or white per fill, whichever gives the greater contrast ratio. Needed
#' because Okabe-Ito's ninth colour is black, and a black label on it is
#' invisible; the same applies to any dark fill a caller supplies.
#'
#' @param fills Character vector of background colours.
#' @return A character vector of `"black"` or `"white"`, one per fill.
#' @references W3C (2018). Web Content Accessibility Guidelines 2.1,
#'   relative luminance and contrast ratio.
#' @noRd
.label_colour <- function(fills) {
  rgb_in <- t(grDevices::col2rgb(fills)) / 255
  lin <- ifelse(rgb_in <= 0.03928, rgb_in / 12.92,
                ((rgb_in + 0.055) / 1.055)^2.4)
  luminance <- as.numeric(lin %*% c(0.2126, 0.7152, 0.0722))
  on_black <- (luminance + 0.05) / 0.05
  on_white <- 1.05 / (luminance + 0.05)
  ifelse(on_black >= on_white, "black", "white")
}
