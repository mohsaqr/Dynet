# random_dynet(): temporal networks drawn from a known process. The draws come from the package's own stream, so
# the evidence is statistical: per seed, a Monte Carlo summary of the generated network (an estimated probability
# or rate) against the model's value, with a tolerance of four standard errors of that summary, worked out below
# from the model's parameters and the number of draws BEFORE any run. Eight seeds per model; a two-sided
# 4-standard-error band is missed with probability about 6e-5 per comparison under the model. Exact properties of
# every draw (spells are maximal runs of whole slices) are checked with tolerance zero.

seeds <- 1:8
mc_reference <- "independent: the generating model's probabilities and rates (Monte Carlo summary)"

#' Dyad-by-slice activity of an interval network whose spells are runs of whole slices
activity_matrix <- function(spells, dyads, times) {
  key <- paste(spells$from, spells$to)
  out <- matrix(0L, nrow = length(dyads), ncol = times, dimnames = list(dyads, NULL))
  cells <- do.call(rbind, lapply(seq_len(nrow(spells)), \(i) {
    cbind(match(key[[i]], dyads), seq.int(spells$start[[i]] + 1, spells$end[[i]]))
  }))
  out[cells] <- 1L
  out
}

ordered_dyads <- function(names) {
  grid <- expand.grid(from = names, to = names, stringsAsFactors = FALSE)
  subset(grid, from != to)
}

test_that("binomial model: the share of active dyad-slices is p (Monte Carlo summary)", {
  nodes <- 12L
  times <- 25L
  p <- 0.15
  cells <- nodes * (nodes - 1L) * times
  # Binomial standard error of a share of 3300 independent cells: sqrt(0.15 * 0.85 / 3300) = 0.0062.
  tolerance <- 4 * sqrt(p * (1 - p) / cells)
  ours <- do.call(rbind, lapply(seeds, \(s) {
    drawn <- as.data.frame(random_dynet(nodes = nodes, times = times, model = "binomial", p = p, seed = s))
    data.frame(seed = s, active_share = sum(drawn$end - drawn$start) / cells)
  }))
  expect_reference(ours, data.frame(seed = seeds, active_share = p), reference = mc_reference,
                   covers = "random_dynet()", quantity = "Monte Carlo summary: binomial active share",
                   tolerance = tolerance, key = "seed")
})

test_that("binomial model: every spell is a maximal run of whole slices", {
  rows <- do.call(rbind, lapply(seeds, \(s) {
    drawn <- as.data.frame(random_dynet(nodes = 8, times = 15, model = "binomial", p = 0.4, seed = s))
    drawn <- drawn[order(drawn$from, drawn$to, drawn$start), ]
    same_pair <- c(FALSE, utils::head(paste(drawn$from, drawn$to), -1L) == utils::tail(paste(drawn$from, drawn$to), -1L))
    gap <- drawn$start - c(NA, utils::head(drawn$end, -1L))
    data.frame(seed = s, whole_slices = all(drawn$start == round(drawn$start) & drawn$end == round(drawn$end)),
               maximal_runs = !any(same_pair & gap <= 0), inside_window = all(drawn$start >= 0 & drawn$end <= 15))
  }))
  expect_reference(rows, transform(rows, whole_slices = TRUE, maximal_runs = TRUE, inside_window = TRUE),
                   reference = "independent: spells as maximal runs of active slices (the documented construction)",
                   covers = "random_dynet()", quantity = "binomial spells", tolerance = 0, key = "seed")
})

test_that("Markov binomial model: persistence, birth and the stationary share (Monte Carlo summary)", {
  nodes <- 12L
  times <- 40L
  birth <- 0.1
  persist <- 0.7
  stationary <- birth / (1 - persist + birth)
  dyads <- nodes * (nodes - 1L)
  # Transitions out of an active cell: about stationary * dyads * (times - 1) = 1287 of them, so the standard error
  # of the estimated persistence is sqrt(0.7 * 0.3 / 1287) = 0.0128; out of inactive cells about 3861, so the
  # birth estimate has sqrt(0.1 * 0.9 / 3861) = 0.0048. The stationary share is a mean over a chain whose lag-one
  # correlation is persist - birth = 0.6, which multiplies its variance by (1 + 0.6) / (1 - 0.6) = 4:
  # sqrt(0.25 * 0.75 * 4 / (132 * 40)) = 0.0119.
  lag <- persist - birth
  tolerance_persist <- 4 * sqrt(persist * (1 - persist) / (stationary * dyads * (times - 1)))
  tolerance_birth <- 4 * sqrt(birth * (1 - birth) / ((1 - stationary) * dyads * (times - 1)))
  tolerance_share <- 4 * sqrt(stationary * (1 - stationary) * (1 + lag) / (1 - lag) / (dyads * times))
  names <- sprintf("n%02d", seq_len(nodes))
  pairs <- with(ordered_dyads(names), paste(from, to))
  per_seed <- lapply(seeds, \(s) {
    drawn <- as.data.frame(random_dynet(nodes = nodes, times = times, model = "binomial", birth = birth,
                                        persist = persist, seed = s))
    a <- activity_matrix(drawn, pairs, times)
    now <- a[, -times]
    nxt <- a[, -1L]
    data.frame(seed = s, persist = sum(now == 1L & nxt == 1L) / sum(now == 1L),
               birth = sum(now == 0L & nxt == 1L) / sum(now == 0L), share = mean(a))
  })
  ours <- do.call(rbind, per_seed)
  expect_reference(subset(ours, select = c(seed, persist)), data.frame(seed = seeds, persist = persist),
                   reference = mc_reference, covers = "random_dynet()",
                   quantity = "Monte Carlo summary: Markov persistence", tolerance = tolerance_persist, key = "seed")
  expect_reference(subset(ours, select = c(seed, birth)), data.frame(seed = seeds, birth = birth),
                   reference = mc_reference, covers = "random_dynet()",
                   quantity = "Monte Carlo summary: Markov birth", tolerance = tolerance_birth, key = "seed")
  expect_reference(subset(ours, select = c(seed, share)), data.frame(seed = seeds, share = stationary),
                   reference = mc_reference, covers = "random_dynet()",
                   quantity = "Monte Carlo summary: Markov stationary share", tolerance = tolerance_share,
                   key = "seed")
})

test_that("block model: within- and between-block shares are p_within and p_between (Monte Carlo summary)", {
  nodes <- 12L
  times <- 20L
  p_within <- 0.3
  p_between <- 0.05
  # Two blocks of six: 60 ordered within-block dyads (1200 cells), 72 between (1440 cells). Standard errors
  # sqrt(0.3 * 0.7 / 1200) = 0.0132 and sqrt(0.05 * 0.95 / 1440) = 0.0057.
  tolerance_within <- 4 * sqrt(p_within * (1 - p_within) / (60 * times))
  tolerance_between <- 4 * sqrt(p_between * (1 - p_between) / (72 * times))
  ours <- do.call(rbind, lapply(seeds, \(s) {
    network <- random_dynet(nodes = nodes, times = times, model = "block", blocks = 2, p_within = p_within,
                            p_between = p_between, seed = s)
    drawn <- as.data.frame(network)
    block <- with(as.data.frame(network, what = "nodes"), stats::setNames(block, name))
    within <- block[drawn$from] == block[drawn$to]
    duration <- drawn$end - drawn$start
    data.frame(seed = s, within = sum(duration[within]) / (60 * times),
               between = sum(duration[!within]) / (72 * times))
  }))
  expect_reference(subset(ours, select = c(seed, within)), data.frame(seed = seeds, within = p_within),
                   reference = mc_reference, covers = "random_dynet()",
                   quantity = "Monte Carlo summary: block within share", tolerance = tolerance_within, key = "seed")
  expect_reference(subset(ours, select = c(seed, between)), data.frame(seed = seeds, between = p_between),
                   reference = mc_reference, covers = "random_dynet()",
                   quantity = "Monte Carlo summary: block between share", tolerance = tolerance_between,
                   key = "seed")
})

test_that("Poisson model: the event rate per dyad is `rate` (Monte Carlo summary)", {
  nodes <- 5L
  times <- 100L
  rate <- 0.5
  exposure <- nodes * (nodes - 1L) * times
  # The event count over 20 dyads and 100 time units is Poisson(1000): the rate estimate has standard error
  # sqrt(0.5 / 2000) = 0.0158.
  tolerance <- 4 * sqrt(rate / exposure)
  ours <- do.call(rbind, lapply(seeds, \(s) {
    drawn <- as.data.frame(random_dynet(nodes = nodes, times = times, model = "poisson", rate = rate, seed = s))
    data.frame(seed = s, rate = nrow(drawn) / exposure)
  }))
  expect_reference(ours, data.frame(seed = seeds, rate = rate), reference = mc_reference,
                   covers = "random_dynet()", quantity = "Monte Carlo summary: Poisson event rate",
                   tolerance = tolerance, key = "seed")
})

test_that("activation model: the static density is p and each active link's rate is `rate` (Monte Carlo summary)", {
  nodes <- 12L
  times <- 30L
  p <- 0.3
  rate <- 1
  dyads <- nodes * (nodes - 1L)
  # 132 dyads each chosen with probability 0.3: standard error sqrt(0.21 / 132) = 0.0399. A chosen link fires as a
  # Poisson process of rate 1 over 30 units (it is silent with probability exp(-30), negligible); about 40 links
  # give about 1188 expected events, standard error of the rate sqrt(1 / 1188) = 0.029.
  tolerance_density <- 4 * sqrt(p * (1 - p) / dyads)
  tolerance_rate <- 4 * sqrt(rate / (p * dyads * times))
  ours <- do.call(rbind, lapply(seeds, \(s) {
    drawn <- as.data.frame(random_dynet(nodes = nodes, times = times, model = "activation", p = p, rate = rate,
                                        seed = s))
    links <- length(unique(paste(drawn$from, drawn$to)))
    data.frame(seed = s, density = links / dyads, rate = nrow(drawn) / (links * times))
  }))
  expect_reference(subset(ours, select = c(seed, density)), data.frame(seed = seeds, density = p),
                   reference = mc_reference, covers = "random_dynet()",
                   quantity = "Monte Carlo summary: activation static density", tolerance = tolerance_density,
                   key = "seed")
  expect_reference(subset(ours, select = c(seed, rate)), data.frame(seed = seeds, rate = rate),
                   reference = mc_reference, covers = "random_dynet()",
                   quantity = "Monte Carlo summary: activation event rate", tolerance = tolerance_rate, key = "seed")
})

test_that("binomial and block models: active shares agree with sna::rgraph() draws of the same model (Monte Carlo)", {
  skip_without_reference("sna")
  nodes <- 12L
  times <- 25L
  p <- 0.15
  cells <- nodes * (nodes - 1L) * times
  # Two independent estimates of one share: the standard error of their difference is sqrt(2) times one's,
  # sqrt(2 * 0.15 * 0.85 / 3300) = 0.0088; four of it, fixed before any run.
  tolerance <- 4 * sqrt(2 * p * (1 - p) / cells)
  sna_share <- \(seed, tprob) {
    old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
    on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
            add = TRUE)
    set.seed(1000L + seed)
    # rgraph() draws `times` independent digraphs; m x n x n.
    sna::rgraph(nodes, m = times, tprob = tprob, mode = "digraph", diag = FALSE)
  }
  binomial <- lapply(seeds, \(s) {
    drawn <- as.data.frame(random_dynet(nodes = nodes, times = times, model = "binomial", p = p, seed = s))
    list(ours = data.frame(seed = s, active_share = sum(drawn$end - drawn$start) / cells),
         theirs = data.frame(seed = s, active_share = sum(sna_share(s, p)) / cells))
  })
  expect_reference(do.call(rbind, lapply(binomial, `[[`, "ours")), do.call(rbind, lapply(binomial, `[[`, "theirs")),
                   reference = "sna", covers = "random_dynet()",
                   quantity = "Monte Carlo: binomial active share against sna::rgraph()", tolerance = tolerance,
                   key = "seed")
  p_within <- 0.3
  p_between <- 0.05
  block <- rep(1:2, each = nodes / 2)
  same <- outer(block, block, `==`)
  tprob <- ifelse(same, p_within, p_between)
  # Within: 60 ordered dyads x 25 slices on each side; between: 72 x 25. Standard errors of the difference
  # sqrt(2 * 0.21 / 1500) = 0.0167 and sqrt(2 * 0.0475 / 1800) = 0.0073.
  tolerance_within <- 4 * sqrt(2 * p_within * (1 - p_within) / (60 * times))
  tolerance_between <- 4 * sqrt(2 * p_between * (1 - p_between) / (72 * times))
  blocks <- lapply(seeds, \(s) {
    network <- random_dynet(nodes = nodes, times = times, model = "block", blocks = 2, p_within = p_within,
                            p_between = p_between, seed = s)
    drawn <- as.data.frame(network)
    label <- with(as.data.frame(network, what = "nodes"), stats::setNames(block, name))
    within <- label[drawn$from] == label[drawn$to]
    duration <- drawn$end - drawn$start
    theirs <- sna_share(s, tprob)
    within_sna <- sum(vapply(seq_len(times), \(slice) sum(theirs[slice, , ][same & !diag(nodes)]), numeric(1)))
    between_sna <- sum(vapply(seq_len(times), \(slice) sum(theirs[slice, , ][!same]), numeric(1)))
    list(ours = data.frame(seed = s, within = sum(duration[within]) / (60 * times),
                           between = sum(duration[!within]) / (72 * times)),
         theirs = data.frame(seed = s, within = within_sna / (60 * times), between = between_sna / (72 * times)))
  })
  stack <- \(part, column) do.call(rbind, lapply(blocks, \(b) b[[part]][c("seed", column)]))
  expect_reference(stack("ours", "within"), stack("theirs", "within"), reference = "sna", covers = "random_dynet()",
                   quantity = "Monte Carlo: block within share against sna::rgraph()", tolerance = tolerance_within,
                   key = "seed")
  expect_reference(stack("ours", "between"), stack("theirs", "between"), reference = "sna", covers = "random_dynet()",
                   quantity = "Monte Carlo: block between share against sna::rgraph()", tolerance = tolerance_between,
                   key = "seed")
})
