# significance(): a measure read against a null model. The surrogates are drawn on the package's own stream, so
# they are taken as given (randomise(), keep = "networks") and everything downstream is recomputed outside the
# package: the statistic on each surrogate spell table with igraph, and the null summaries, the plus-one
# permutation p-value (North et al. 2002), the percentile interval, z, the Benjamini-Hochberg adjustment and the
# Monte Carlo standard error from their definitions. Several seeds, each a different set of surrogates.

spells <- school_contacts
people <- sort(unique(c(spells$from, spells$to)))
onsets <- c(0, 7, 14, 21)
network <- dynet(school_contacts)
seeds <- 1:4
draws <- 39L
significance_covers <- c("significance()", "as.data.frame.dynet_significance()")

#' Density of every window of a spell table, by igraph
window_density <- function(tbl) {
  vapply(onsets, \(lo) igraph::edge_density(ref_snapshot(tbl, lo, lo + 7, people)), numeric(1))
}

#' The igraph null distribution of a dynet_null: one row per window and replicate
igraph_null <- function(null) {
  drawn <- as.data.frame(null)
  parts <- split(drawn, drawn$replicate)
  do.call(rbind, lapply(names(parts), \(r) data.frame(time = onsets, measure = "density",
                                                      replicate = as.integer(r),
                                                      value = window_density(parts[[r]]))))
}

#' The result columns of a permutation test from the observed values and the null draws, written out
permutation_summary <- function(observed, null, alternative, conf_level = 0.95) {
  rows <- lapply(seq_along(onsets), \(i) {
    v <- subset(null, time == onsets[[i]])$value
    obs <- observed[[i]]
    m <- mean(v)
    # Ties at the observed value count as extreme; 1e-9 is far below the 1/182 grid of a density.
    hits <- switch(alternative,
                   greater = sum(v >= obs - 1e-9),
                   less = sum(v <= obs + 1e-9),
                   two.sided = sum(abs(v - m) >= abs(obs - m) - 1e-9))
    p <- (1 + hits) / (1 + length(v))
    data.frame(time = onsets[[i]], measure = "density", observed = obs, null_mean = m, null_sd = stats::sd(v),
               null_lo = unname(stats::quantile(v, (1 - conf_level) / 2, type = 7)),
               null_hi = unname(stats::quantile(v, 1 - (1 - conf_level) / 2, type = 7)),
               z = (obs - m) / stats::sd(v), p = p, p_mcse = sqrt(p * (1 - p) / (length(v) + 1)),
               n_ties = sum(abs(v - obs) <= 1e-9), n_null = length(v))
  })
  out <- do.call(rbind, rows)
  transform(out, p_adj = stats::p.adjust(p, method = "BH"))
}

test_that("the null distribution equals igraph's density of each surrogate spell table", {
  skip_without_reference("igraph")
  rows <- lapply(seeds, \(s) {
    null <- randomise(network, method = "times", n = draws, seed = s)
    tested <- significance(null, statistic = metrics, measure = "density", step = 7, window = 7)
    list(ours = transform(as.data.frame(tested, what = "null"), seed = s),
         theirs = transform(igraph_null(null), seed = s))
  })
  # Ratios of small counts.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "igraph", covers = c(significance_covers, "as.data.frame.dynet_null()"),
                   quantity = "null density per window and surrogate", tolerance = 1e-12,
                   key = c("seed", "time", "measure", "replicate"))
})

test_that("observed value, null summaries, p-values and their adjustment equal the definitions", {
  skip_without_reference("igraph")
  observed <- window_density(spells)
  rows <- lapply(seeds, \(s) {
    null <- randomise(network, method = "targets", n = draws, seed = s)
    reference_null <- igraph_null(null)
    per_alternative <- lapply(c("two.sided", "greater", "less"), \(alt) {
      tested <- significance(null, statistic = metrics, measure = "density", step = 7, window = 7,
                             alternative = alt)
      list(ours = transform(as.data.frame(tested), seed = s, alternative = alt),
           theirs = transform(permutation_summary(observed, reference_null, alt), seed = s, alternative = alt))
    })
    list(ours = do.call(rbind, lapply(per_alternative, `[[`, "ours")),
         theirs = do.call(rbind, lapply(per_alternative, `[[`, "theirs")))
  })
  # Means, standard deviations and quantiles of 39 ratios of small counts.
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "independent: permutation test summaries (North et al. 2002; Benjamini-Hochberg)",
                   covers = significance_covers, quantity = "density, targets null",
                   tolerance = 1e-10, key = c("seed", "alternative", "time", "measure"))
})

test_that("summary() counts the tested and BH-significant cells and the median z per measure", {
  skip_without_reference("igraph")
  observed <- window_density(spells)
  null <- randomise(network, method = "times", n = draws, seed = 11)
  tested <- significance(null, statistic = metrics, measure = "density", step = 7, window = 7)
  reference_table <- permutation_summary(observed, igraph_null(null), "two.sided")
  theirs <- data.frame(measure = "density", tested = nrow(reference_table),
                       significant = sum(reference_table$p_adj < 0.05),
                       median_z = stats::median(reference_table$z))
  expect_reference(summary(tested), theirs,
                   reference = "independent: permutation test summaries (North et al. 2002; Benjamini-Hochberg)",
                   covers = "summary.dynet_significance()", quantity = "density, times null", tolerance = 1e-10,
                   key = "measure")
})

test_that("every p-value lies in [1 / (n + 1), 1] for every seed and alternative", {
  bounds <- do.call(rbind, lapply(seeds, \(s) do.call(rbind, lapply(c("two.sided", "greater", "less"), \(alt) {
    tested <- as.data.frame(significance(network, statistic = metrics, measure = "density", step = 7, window = 7,
                                         method = "times", n = draws, alternative = alt, seed = s))
    data.frame(seed = s, alternative = alt, time = tested$time,
               inside = tested$p >= 1 / (draws + 1) - 1e-12 & tested$p <= 1 + 1e-12)
  }))))
  expect_reference(bounds, transform(bounds, inside = TRUE),
                   reference = "independent: the range of a plus-one permutation p-value",
                   covers = "significance()", quantity = "p-value inside its range, times null", tolerance = 0,
                   key = c("seed", "alternative", "time"))
})
