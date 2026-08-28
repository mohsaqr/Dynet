# ===========================================================================
# Permutation inference over any Dynet measure
# ===========================================================================
# randomise() leaves the caller holding surrogates and no inference. This file
# closes that gap: one call takes a measurement verb and returns the observed
# value, the null distribution it sits in, an interval and a p-value.

#' Compare a measure against a temporal null model
#'
#' @description
#' Runs a measurement verb on the observed network and on every surrogate from
#' a null model, then reports the observed value beside the null distribution,
#' a percentile interval and a permutation p-value. This is what turns any of
#' this package's measures from a point estimate into a result.
#'
#' Works with every verb that returns a `measure` and a `value` column, which
#' is all of them: [metrics()], [dyn_centrality()], [events()], [burstiness()],
#' [durations()], [dyn_reachability()], [mixing()], [similarity()] and
#' [pshifts()].
#'
#' @param x A temporal network from [dynet()], or a `dynet_null` from
#'   [randomise()] when reusing one set of surrogates for several statistics.
#' @param statistic A measurement verb, passed as a function.
#' @param ... Passed to `statistic`, so `measure = "density"` and friends work
#'   without a wrapper.
#' @param method,n,within Null model settings, as in [randomise()]. Supplying
#'   any of them alongside a `dynet_null` is an error rather than a silent
#'   override.
#' @param alternative `"two.sided"`, `"greater"` or `"less"`.
#' @param conf_level Width of the reported percentile interval of the null.
#' @param p_adjust Multiplicity correction, passed to [stats::p.adjust()].
#' @param seed A single whole number for a reproducible draw, or `NULL`.
#' @return A `dynet_significance` data frame with one row per cell of the
#'   observed statistic. It carries every key column the statistic produced,
#'   then `observed`, `null_mean`, `null_sd`, `null_lo`, `null_hi`, `z`, `p`,
#'   `p_adj`, `p_mcse`, `n_ties` and `n_null`. `null_lo` and `null_hi` bound
#'   the null distribution, not the observed value, which is why they are not
#'   named as a confidence interval for it.
#' @details
#' The p-value carries the standard plus-one correction,
#' \eqn{p = (1 + r) / (1 + n)}, so with 999 surrogates the smallest reportable
#' value is 0.001 and never zero. `p_mcse` is the Monte-Carlo standard error on
#' `p` itself, computed from the same draws, so the precision of the p-value is
#' visible beside it.
#'
#' A cell present in the observed result but absent from a surrogate counts as
#' missing, never as zero: a bin with no eligible pairs did not have zero
#' density, it had no density. `n_null` reports how many surrogates actually
#' produced each cell.
#'
#' Under `method = "labels"` every structural measure is exactly invariant, so
#' every p is exactly one. That is correct, and it is a useful check that the
#' machinery is aligned rather than a failure.
#'
#' `n_ties` counts surrogates numerically equal to the observed value. Read it:
#' a discrete statistic on a small network, such as density where every value
#' is a count over a fixed number of pairs, can put most of the null mass
#' exactly on the observed value. The p-value is then decided by how ties are
#' counted rather than by the tail, and it does **not** stabilise as `n` grows.
#' Measured on `school_contacts`, the density p-value varied by 0.61 across
#' five seeds at both 199 and 999 surrogates, while the continuous burstiness
#' p-value tightened from 0.19 to 0.07 over the same increase. A large
#' `n_ties` relative to `n_null` means more surrogates will not help; a
#' statistic with finer resolution will.
#' @examples
#' dn <- dynet(school_contacts)
#' significance(dn, statistic = metrics, measure = "density", n = 99, seed = 1)
#' @seealso [randomise()] for the null models and what each one holds fixed.
#' @references
#' Davison, A. C., and Hinkley, D. V. (1997). *Bootstrap Methods and Their
#' Application*. Cambridge University Press.
#'
#' North, B. V., Curtis, D., and Sham, P. C. (2002). A note on the calculation
#' of empirical P values from Monte Carlo procedures. *American Journal of
#' Human Genetics*, 71(2), 439-441.
#'
#' Benjamini, Y., and Hochberg, Y. (1995). Controlling the false discovery
#' rate. *Journal of the Royal Statistical Society B*, 57(1), 289-300.
#' @export
significance <- function(x, statistic, ...,
                         method = c("times", "timeline", "edges", "targets",
                                    "labels"),
                         n = 999L,
                         alternative = c("two.sided", "greater", "less"),
                         conf_level = 0.95,
                         p_adjust = "BH",
                         within = c("network", "sender", "session"),
                         seed = NULL) {
  alternative <- match.arg(alternative)
  .check(
    "`statistic` must be a measurement verb, passed as a function." =
      is.function(statistic),
    "`conf_level` must be a single number strictly between 0 and 1." =
      length(conf_level) == 1L && is.numeric(conf_level) &&
        is.finite(conf_level) && conf_level > 0 && conf_level < 1
  )
  supplied <- c(method = !missing(method), n = !missing(n),
                within = !missing(within))

  if (inherits(x, "dynet_null")) {
    if (any(supplied)) {
      stop(errorCondition(sprintf(
        "Surrogates were already drawn, so %s cannot be set here; set them in randomise().",
        paste(names(supplied)[supplied], collapse = ", ")),
        class = "dynet_bad_input", call = NULL))
    }
    null <- x
    dn <- attr(null, "source")
  } else {
    .check_dynet(x)
    method <- match.arg(method)
    within <- match.arg(within)
    dn <- x
    null <- randomise(dn, method = method, n = n, within = within,
                      keep = "networks", seed = seed)
  }
  networks <- attr(null, "networks")
  if (is.null(networks)) {
    stop(errorCondition(
      "These surrogates were built with keep = \"spells\"; re-draw with keep = \"networks\".",
      class = "dynet_bad_input", call = NULL))
  }

  obs <- as.data.frame(statistic(dn, ...))
  if (!all(c("measure", "value") %in% names(obs))) {
    stop(errorCondition(
      "`statistic` must return a data frame with `measure` and `value` columns.",
      class = "dynet_bad_statistic", call = NULL))
  }
  keys <- setdiff(names(obs), "value")
  obs_key <- do.call(paste, c(obs[keys], sep = "\r"))

  draws <- vapply(networks, function(net) {
    got <- try(as.data.frame(statistic(net, ...)), silent = TRUE)
    if (inherits(got, "try-error")) return(rep(NA_real_, nrow(obs)))
    idx <- match(obs_key, do.call(paste, c(got[keys], sep = "\r")))
    as.numeric(got$value[idx])
  }, numeric(nrow(obs)))
  if (is.null(dim(draws))) draws <- matrix(draws, nrow = nrow(obs))

  n_null <- rowSums(is.finite(draws))
  null_mean <- rowMeans(draws, na.rm = TRUE)
  null_sd <- apply(draws, 1L, stats::sd, na.rm = TRUE)
  probs <- c((1 - conf_level) / 2, 1 - (1 - conf_level) / 2)
  bounds <- t(apply(draws, 1L, function(v) {
    v <- v[is.finite(v)]
    if (!length(v)) return(c(NA_real_, NA_real_))
    unname(stats::quantile(v, probs, type = 7, names = FALSE))
  }))

  observed <- as.numeric(obs$value)
  # Never compare doubles bare: a surrogate numerically identical to the
  # observed value must count consistently on both sides of the test.
  tol <- sqrt(.Machine$double.eps) * pmax(1, abs(observed))
  extreme <- switch(alternative,
    greater   = draws >= observed - tol,
    less      = draws <= observed + tol,
    two.sided = abs(draws - null_mean) >= abs(observed - null_mean) - tol
  )
  hits <- rowSums(extreme & is.finite(draws), na.rm = TRUE)
  # Surrogates numerically equal to the observed value. When these dominate,
  # the p-value is decided by tie counting rather than by the tail, and it
  # will not stabilise as `n` grows -- a discrete statistic such as density on
  # a small network is the usual cause.
  ties <- rowSums(abs(draws - observed) <= tol & is.finite(draws), na.rm = TRUE)
  p <- (1 + hits) / (1 + n_null)
  p[n_null == 0L] <- NA_real_
  z <- ifelse(is.finite(null_sd) & null_sd > 0,
              (observed - null_mean) / null_sd, NA_real_)

  out <- obs[keys]
  out$observed <- observed
  out$null_mean <- null_mean
  out$null_sd <- null_sd
  out$null_lo <- bounds[, 1L]
  out$null_hi <- bounds[, 2L]
  out$z <- z
  out$p <- p
  out$p_adj <- stats::p.adjust(p, method = p_adjust)
  out$p_mcse <- sqrt(p * (1 - p) / (n_null + 1))
  out$n_ties <- ties
  out$n_null <- n_null
  rownames(out) <- NULL

  if (any(n_null < 0.9 * attr(null, "n"))) {
    warning(warningCondition(
      "Some cells were missing from more than a tenth of the surrogates; see n_null.",
      class = "dynet_null_incomplete"))
  }

  structure(out,
    class = c("dynet_significance", "data.frame"),
    method = attr(null, "method"), n = attr(null, "n"),
    seed = attr(null, "seed"), alternative = alternative,
    conf_level = conf_level, p_adjust = p_adjust,
    preserves = attr(null, "preserves"), destroys = attr(null, "destroys"),
    statistic = deparse(substitute(statistic))[[1L]],
    draws = draws
  )
}

#' Print a permutation test
#' @param x A `dynet_significance` from [significance()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet_significance <- function(x, ...) {
  df <- as.data.frame(x)
  cat(sprintf("# %s against %d surrogates | null \"%s\" | %s\n",
              attr(x, "statistic"), attr(x, "n"), attr(x, "method"),
              attr(x, "alternative")))
  cat(sprintf("# null holds fixed: %s\n", attr(x, "preserves")))
  cat(sprintf("# %.0f%% interval bounds the null, not the observed value\n",
              100 * attr(x, "conf_level")))
  sig <- sum(df$p_adj < 0.05, na.rm = TRUE)
  cat(sprintf("# %d of %d rows outside the null after %s correction\n",
              sig, nrow(df), attr(x, "p_adjust")))
  print(utils::head(df, 8L))
  if (nrow(df) > 8L) cat(sprintf("# %d more rows.\n", nrow(df) - 8L))
  invisible(x)
}

#' Summarise a permutation test
#' @param object A `dynet_significance` from [significance()].
#' @param ... Ignored.
#' @return A data frame with one row per measure and columns `measure`,
#'   `tested`, `significant` and `median_z`.
#' @export
summary.dynet_significance <- function(object, ...) {
  df <- as.data.frame(object)
  key <- if ("measure" %in% names(df)) df$measure else rep("value", nrow(df))
  parts <- split(df, key)
  out <- do.call(rbind, lapply(names(parts), function(m) data.frame(
    measure = m, tested = nrow(parts[[m]]),
    significant = sum(parts[[m]]$p_adj < 0.05, na.rm = TRUE),
    median_z = stats::median(parts[[m]]$z, na.rm = TRUE),
    stringsAsFactors = FALSE
  )))
  rownames(out) <- NULL
  out
}

#' Coerce a permutation test to a data frame
#' @param x A `dynet_significance` from [significance()].
#' @param row.names Passed to the data frame method.
#' @param optional Passed to the data frame method.
#' @param ... Ignored.
#' @return A base data frame, one row per tested cell.
#' @export
as.data.frame.dynet_significance <- function(x, row.names = NULL,
                                             optional = FALSE, ...) {
  attributes(x) <- list(names = names(x), row.names = seq_len(nrow(x)),
                        class = "data.frame")
  x
}

#' Plot a permutation test
#'
#' @param x A `dynet_significance` from [significance()].
#' @param type `"null"` draws the surrogate distribution with the observed
#'   value marked, `"series"` draws the observed value over time inside the
#'   null band, and `"z"` orders vertices or cells by standardised deviation.
#' @param ... Ignored.
#' @return A `ggplot` object.
#' @export
plot.dynet_significance <- function(x, type = c("null", "series", "z"), ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop(errorCondition("Plotting needs ggplot2.",
                        class = "dynet_missing_package", call = NULL))
  }
  type <- match.arg(type)
  df <- as.data.frame(x)
  draws <- attr(x, "draws")
  measure <- if ("measure" %in% names(df)) df$measure else rep("value", nrow(df))
  base <- ggplot2::theme_minimal(base_size = 12)

  if (identical(type, "series")) {
    if (!"time" %in% names(df)) {
      stop(errorCondition(
        "type = \"series\" needs a statistic measured over time; use type = \"null\" or \"z\".",
        class = "dynet_bad_input", call = NULL))
    }
    df$flag <- ifelse(!is.na(df$p_adj) & df$p_adj < 0.05, "outside", "inside")
    return(
      ggplot2::ggplot(df, ggplot2::aes(x = df$time)) +
        ggplot2::geom_ribbon(
          ggplot2::aes(ymin = df$null_lo, ymax = df$null_hi),
          fill = "#999999", alpha = 0.35) +
        ggplot2::geom_line(ggplot2::aes(y = df$observed),
                           colour = "#0072B2", linewidth = 0.8) +
        ggplot2::geom_point(
          ggplot2::aes(y = df$observed, shape = df$flag, colour = df$flag),
          size = 2) +
        ggplot2::scale_shape_manual(
          values = c(inside = 1, outside = 17), name = NULL) +
        ggplot2::scale_colour_manual(
          values = c(inside = "#0072B2", outside = "#D55E00"), name = NULL) +
        ggplot2::facet_wrap(~ measure, scales = "free_y") +
        ggplot2::labs(x = "time", y = "observed",
                      title = "Observed value inside the null band",
                      subtitle = "band is the null interval; triangles fall outside it after correction") +
        base
    )
  }

  if (identical(type, "z")) {
    keys <- setdiff(names(df), c("observed", "null_mean", "null_sd", "null_lo",
                                 "null_hi", "z", "p", "p_adj", "p_mcse",
                                 "n_ties", "n_null", "measure"))
    df$label <- if (length(keys)) {
      do.call(paste, c(df[keys], sep = " "))
    } else as.character(seq_len(nrow(df)))
    df <- df[is.finite(df$z), , drop = FALSE]
    if (!nrow(df)) {
      stop(errorCondition(
        "Every z is undefined, so there is nothing to order; the null has no spread.",
        class = "dynet_empty_result", call = NULL))
    }
    df$flag <- ifelse(!is.na(df$p_adj) & df$p_adj < 0.05, "outside", "inside")
    df$label <- stats::reorder(df$label, df$z)
    return(
      ggplot2::ggplot(df, ggplot2::aes(x = df$z, y = df$label)) +
        ggplot2::geom_vline(xintercept = 0, colour = "#999999",
                            linetype = "22") +
        ggplot2::geom_point(
          ggplot2::aes(shape = df$flag, colour = df$flag), size = 2.4) +
        ggplot2::scale_shape_manual(
          values = c(inside = 1, outside = 17), name = NULL) +
        ggplot2::scale_colour_manual(
          values = c(inside = "#0072B2", outside = "#D55E00"), name = NULL) +
        ggplot2::labs(x = "z against the null", y = NULL,
                      title = "Standardised deviation from the null",
                      subtitle = "triangles fall outside the null after correction") +
        base
    )
  }

  pooled <- data.frame(
    value = as.numeric(draws),
    measure = rep(measure, times = ncol(draws)),
    stringsAsFactors = FALSE
  )
  pooled <- pooled[is.finite(pooled$value), , drop = FALSE]
  marks <- data.frame(measure = measure, observed = df$observed,
                      stringsAsFactors = FALSE)
  ggplot2::ggplot(pooled, ggplot2::aes(x = pooled$value)) +
    ggplot2::geom_histogram(bins = 30, fill = "#999999", colour = NA) +
    ggplot2::geom_vline(
      data = marks, ggplot2::aes(xintercept = marks$observed),
      colour = "#D55E00", linewidth = 0.8, linetype = "solid") +
    ggplot2::facet_wrap(~ measure, scales = "free") +
    ggplot2::labs(
      x = "surrogate value", y = "surrogates",
      title = sprintf("Null distribution against the observed value (%s)",
                      attr(x, "method")),
      subtitle = "vermillion rule marks the observed value") +
    base
}
