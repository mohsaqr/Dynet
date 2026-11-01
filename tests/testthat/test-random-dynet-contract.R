test_that("a generated network is a dynet every verb accepts", {
  dn <- random_dynet(nodes = 10, times = 12, model = "binomial", p = 0.25,
                     seed = 1)
  expect_s3_class(dn, "dynet")
  for (f in list(metrics, centrality_series, events, burstiness, durations,
                 snapshots)) {
    expect_s3_class(as.data.frame(f(dn)), "data.frame")
  }
  expect_identical(dn$meta$source, "random_dynet")
})

test_that("an argument the model ignores is rejected, never silently dropped", {
  expect_error(random_dynet(model = "poisson", p = 0.3),
               class = "dynet_bad_input")
  expect_error(random_dynet(model = "block", waiting = "weibull"),
               class = "dynet_bad_input")
  expect_error(random_dynet(model = "binomial", blocks = 3),
               class = "dynet_bad_input")
  expect_error(random_dynet(model = "binomial", birth = 0.1),
               class = "dynet_bad_input")
  expect_error(random_dynet(model = "poisson", birth = 0.1, persist = 0.5),
               class = "dynet_bad_input")
  expect_error(random_dynet(model = "activation", waiting = "weibull",
                            shape = 0),
               class = "dynet_bad_input")
})

test_that("a draw with no edges is a classed error, not a constructor failure", {
  expect_error(random_dynet(nodes = 4, times = 3, model = "binomial", p = 0,
                            seed = 1),
               class = "dynet_generator_empty")
})

test_that("generated node names sort stably", {
  dn <- random_dynet(nodes = 12, times = 5, model = "binomial", p = 0.4,
                     seed = 1)
  names <- as.data.frame(dn, what = "nodes")$name
  # Zero-padded, so lexical and numeric order agree; unpadded names would put
  # n10 before n2 and make every downstream fixture fragile.
  expect_identical(names, sort(names))
  expect_true(all(grepl("^n[0-9]{2}$", names)))
})

test_that("the same seed gives an identical network and leaves the stream alone", {
  set.seed(11)
  before <- get(".Random.seed", envir = globalenv())
  a <- random_dynet(nodes = 8, times = 8, model = "binomial", p = 0.3, seed = 2)
  b <- random_dynet(nodes = 8, times = 8, model = "binomial", p = 0.3, seed = 2)
  expect_identical(as.data.frame(a), as.data.frame(b))
  expect_identical(get(".Random.seed", envir = globalenv()), before)
})

test_that("expected per-slice density equals p", {
  skip_on_cran()
  for (p in c(0.1, 0.25)) {
    d <- vapply(seq_len(60), function(s) {
      mean(as.data.frame(metrics(
        random_dynet(nodes = 12, times = 12, model = "binomial", p = p,
                     seed = s), measure = "density"))$value)
    }, numeric(1L))
    expect_lt(abs(mean(d) - p), 4 * stats::sd(d) / sqrt(length(d)))
  }
})

test_that("a Poisson process has zero burstiness", {
  skip_on_cran()
  # The calibration target burstiness() has never had: an exactly known value.
  b <- vapply(seq_len(3), function(s) {
    as.data.frame(burstiness(
      random_dynet(nodes = 2, times = 20000, model = "poisson", rate = 1,
                   directed = FALSE, seed = s),
      measure = "burstiness"))$value[[1L]]
  }, numeric(1L))
  for (i in seq_along(b)) expect_lt(abs(b[[i]]), 0.02)
})

test_that("Weibull waiting reproduces the closed-form burstiness", {
  skip_on_cran()
  closed <- function(k) {
    mu <- gamma(1 + 1 / k)
    sigma <- sqrt(gamma(1 + 2 / k) - mu^2)
    (sigma - mu) / (sigma + mu)
  }
  # nodes = 2 undirected gives each vertex exactly ONE renewal process. With
  # more partners the superposition drives burstiness toward zero and the
  # closed form no longer applies -- see the superposition test below.
  # Tolerances are looser at shape = 0.5 because its gaps are heavy-tailed and
  # a finite window converges more slowly; measured error there was -0.012 at
  # this window against -0.001 and +0.002 for shapes 1 and 2.
  for (spec in list(list(k = 0.5, tol = 0.05), list(k = 1, tol = 0.02),
                    list(k = 2, tol = 0.02))) {
    b <- vapply(seq_len(3), function(s) {
      as.data.frame(burstiness(
        random_dynet(nodes = 2, times = 20000, model = "activation", p = 1,
                     rate = 1, waiting = "weibull", shape = spec$k,
                     directed = FALSE, seed = s),
        measure = "burstiness"))$value[[1L]]
    }, numeric(1L))
    expect_lt(abs(mean(b) - closed(spec$k)), spec$tol)
  }
})

test_that("node-level burstiness falls toward zero as incident processes are superposed", {
  skip_on_cran()
  # Palm-Khintchine: superposing independent renewal processes tends to Poisson.
  # This is a property of burstiness(), not of the generator, and it is why the
  # closed-form check above uses a two-node network.
  b <- vapply(c(2L, 4L, 8L, 16L), function(nn) {
    mean(as.data.frame(burstiness(
      random_dynet(nodes = nn, times = 3000, model = "activation", p = 1,
                   rate = 1, waiting = "weibull", shape = 0.5,
                   directed = FALSE, seed = 1),
      measure = "burstiness"))$value)
  }, numeric(1L))
  expect_true(all(diff(b) < 0))
  expect_gt(b[[1L]], 0.3)
  expect_lt(b[[length(b)]], 0.2)
})

test_that("changing shape does not change the event rate", {
  skip_on_cran()
  # The Weibull scale is corrected so the mean gap stays 1/rate at every shape.
  # Without that correction, shape would change burstiness and rate together
  # and no test could separate the two effects.
  ev <- vapply(c(0.5, 1, 2), function(k) {
    mean(as.data.frame(burstiness(
      random_dynet(nodes = 6, times = 2000, model = "activation", p = 1,
                   rate = 1, waiting = "weibull", shape = k, seed = 1),
      measure = "events"))$value)
  }, numeric(1L))
  expect_lt(max(ev) / min(ev) - 1, 0.02)
})

test_that("a block network carries its planted partition as a node attribute", {
  dn <- random_dynet(nodes = 12, times = 10, model = "block", blocks = 3,
                     p_within = 0.5, p_between = 0.02, seed = 1)
  nodes <- as.data.frame(dn, what = "nodes")
  expect_true("block" %in% names(nodes))
  expect_identical(length(unique(nodes$block)), 3L)
  # The ground truth is IN the object, so mixing() reads it with no extra
  # argument and no reattachment by the caller.
  expect_s3_class(as.data.frame(mixing(dn, attribute = "block")), "data.frame")
})

test_that("a block network is assortative on its planted partition", {
  skip_on_cran()
  dn <- random_dynet(nodes = 16, times = 40, model = "block", blocks = 2,
                     p_within = 0.5, p_between = 0.02, seed = 1)
  mix <- as.data.frame(mixing(dn, attribute = "block"))
  within <- sum(mix$value[mix$from_group == mix$to_group])
  between <- sum(mix$value[mix$from_group != mix$to_group])
  expect_gt(within, between)
})

test_that("blocks = 1 reproduces the binomial model", {
  skip_on_cran()
  # A same-package consistency oracle: with one block there is no partition,
  # so the block model must be distributionally identical to binomial at
  # p = p_within.
  one <- vapply(seq_len(30), function(s) mean(as.data.frame(metrics(
    random_dynet(nodes = 10, times = 10, model = "block", blocks = 1,
                 p_within = 0.3, seed = s), measure = "density"))$value),
    numeric(1L))
  plain <- vapply(seq_len(30), function(s) mean(as.data.frame(metrics(
    random_dynet(nodes = 10, times = 10, model = "binomial", p = 0.3,
                 seed = s), measure = "density"))$value), numeric(1L))
  pooled <- sqrt(stats::var(one) / 30 + stats::var(plain) / 30)
  expect_lt(abs(mean(one) - mean(plain)), 4 * pooled)
})

test_that("the Markov variant reaches its stationary activity", {
  skip_on_cran()
  birth <- 0.1
  persist <- 0.7
  target <- birth / (1 - persist + birth)
  d <- vapply(seq_len(40), function(s) mean(as.data.frame(metrics(
    random_dynet(nodes = 10, times = 20, model = "binomial", birth = birth,
                 persist = persist, seed = s), measure = "density"))$value),
    numeric(1L))
  expect_lt(abs(mean(d) - target), 4 * stats::sd(d) / sqrt(length(d)))
})

test_that("an out-of-range or malformed generator argument is a classed error", {
  expect_error(random_dynet(p = 2, seed = 1), class = "dynet_bad_input")
  expect_error(random_dynet(p = NA_real_, seed = 1), class = "dynet_bad_input")
  expect_error(random_dynet(model = "block", p_within = 3, seed = 1),
               class = "dynet_bad_input")
  expect_error(random_dynet(model = "block", p_between = c(0.1, 0.2),
                            seed = 1),
               class = "dynet_bad_input")
  expect_error(random_dynet(model = "block", block_switch = 2, seed = 1),
               class = "dynet_bad_input")
  expect_error(random_dynet(model = "block", blocks = 2.5, seed = 1),
               class = "dynet_bad_input")
  expect_error(random_dynet(nodes = 2.7, seed = 1), class = "dynet_bad_input")
  expect_error(random_dynet(nodes = c("a", "a", "b"), seed = 1),
               class = "dynet_bad_input")
  expect_error(random_dynet(nodes = c("a", NA), seed = 1),
               class = "dynet_bad_input")
  expect_error(random_dynet(directed = NA, seed = 1), class = "dynet_bad_input")
  expect_error(random_dynet(loops = NA, seed = 1), class = "dynet_bad_input")
  expect_error(random_dynet(birth = 0, persist = 1, seed = 1),
               class = "dynet_bad_input")
  expect_error(random_dynet(nodes = 4, times = 3, p = 0, seed = 1),
               class = "dynet_bad_input")
})

test_that("every requested vertex is in the network, tied or not", {
  sizes <- vapply(seq_len(6), function(s) {
    dn <- random_dynet(nodes = 10, times = 2, model = "binomial", p = 0.03,
                       seed = s)
    nrow(as.data.frame(dn, what = "nodes"))
  }, integer(1L))
  expect_identical(sizes, rep(10L, 6L))
  named <- random_dynet(nodes = c("x", "y", "z", "w"), times = 2,
                        model = "activation", p = 0.2, rate = 2, seed = 3)
  expect_setequal(as.data.frame(named, what = "nodes")$name,
                  c("x", "y", "z", "w"))
})

test_that("block_switch = 0 leaves the planted partition static", {
  args <- list(nodes = 8, times = 6, model = "block", blocks = 2,
               p_within = 1, p_between = 0, seed = 4)
  static <- do.call(random_dynet, args)
  explicit <- do.call(random_dynet, c(args, block_switch = 0))
  expect_identical(as.data.frame(explicit), as.data.frame(static))
  # With certain within-block ties and none between, every within-block pair
  # is one spell covering the whole window.
  spells <- as.data.frame(static)
  expect_equal(unique(spells$start), 0)
  expect_equal(unique(spells$end), 6)
})

test_that("a positive block_switch makes the partition drift", {
  dn <- random_dynet(nodes = 9, times = 12, model = "block", blocks = 3,
                     p_within = 1, p_between = 0, block_switch = 0.5,
                     seed = 2)
  spells <- as.data.frame(dn)
  # Drift breaks some within-block run before the window ends.
  expect_true(any(spells$end - spells$start < 12))
  # Invariant: with p_within = 1 and p_between = 0 each slice is a disjoint
  # union of cliques, so tie-sharing is transitive within every slice.
  transitive <- vapply(seq_len(12) - 0.5, function(t) {
    live <- spells[spells$start <= t & spells$end > t, c("from", "to")]
    pairs <- unique(c(paste(live$from, live$to), paste(live$to, live$from)))
    triples <- merge(data.frame(near = live$from, mid = live$to),
                     data.frame(mid = live$from, far = live$to), by = "mid")
    triples <- triples[triples$near != triples$far, , drop = FALSE]
    all(paste(triples$near, triples$far) %in% pairs)
  }, logical(1L))
  expect_true(all(transitive))
  expect_identical(dn$meta$generator$block_switch, 0.5)
})
