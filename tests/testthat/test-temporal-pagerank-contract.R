# Temporal PageRank: Algorithm 1 of Rozenshtein & Gionis (2016), generalized to
# simultaneous contacts by a strict batch rule.

contacts <- function(from, to, time, end = max(time) + 1, nodes = NULL) {
  nm <- nodes %||% sort(unique(c(from, to)))
  dynet(data.frame(from = from, to = to, time = time), format = "contact",
        nodes = data.frame(name = nm),
        observation_start = 0, observation_end = end)
}

pagerank <- function(dn, ...) {
  as.data.frame(dyn_centrality(dn, measure = "pagerank", scope = "temporal",
                               ...))$value
}

# A literal, line-for-line transcription of the paper's Algorithm 1. It is the
# oracle, not the implementation: it walks one contact at a time and so is
# defined only where no two contacts share a timestamp.
algorithm_one <- function(from, to, n, damping, transition) {
  r <- numeric(n)
  s <- numeric(n)
  for (i in seq_along(from)) {                     # a stream is sequential
    u <- from[[i]]
    v <- to[[i]]
    r[u] <- r[u] + (1 - damping)
    s[u] <- s[u] + (1 - damping)
    r[v] <- r[v] + s[u] * damping
    if (transition < 1) {
      s[v] <- s[v] + s[u] * (1 - transition) * damping
      s[u] <- s[u] * transition
    } else {
      s[v] <- s[v] + s[u] * damping
      s[u] <- 0
    }
  }
  r
}

# One random loop-free stream with distinct timestamps, as a network and as the
# integer edge list the oracle reads. A cycle over every vertex opens the
# stream because dynet() keeps only vertices that a contact touches, and the
# oracle scores the whole universe.
random_stream <- function(n, m) {
  cycle <- sample(n)
  from <- c(cycle, sample(n, m, replace = TRUE))
  to <- c(cycle[c(seq_len(n - 1L) + 1L, 1L)], sample(n, m, replace = TRUE))
  keep <- from != to
  from <- from[keep]
  to <- to[keep]
  nm <- sprintf("v%02d", seq_len(n))
  list(
    dn = contacts(nm[from], nm[to], seq_along(from),
                  end = length(from) + 1, nodes = nm),
    from = from, to = to, n = n, names = nm
  )
}

# The scores keyed by vertex name, for the tests where the vertex universe is
# not the same on both sides of the comparison.
pagerank_by_name <- function(dn, ...) {
  out <- as.data.frame(dyn_centrality(dn, measure = "pagerank",
                                      scope = "temporal", ...))
  stats::setNames(out$value, out$node)
}

test_that("transition is refused outside (0, 1] and away from temporal pagerank", {
  dn <- contacts("A", "B", 0)
  expect_error(pagerank(dn, transition = 0), class = "dynet_bad_input")
  expect_error(pagerank(dn, transition = 1.5), class = "dynet_bad_input")
  expect_error(pagerank(dn, transition = c(0.5, 0.5)), class = "dynet_bad_input")
  expect_error(pagerank(dn, transition = NA_real_), class = "dynet_bad_input")
  # An argument the requested measure ignores is an error, never dropped.
  expect_error(
    dyn_centrality(dn, measure = "katz", scope = "temporal", transition = 0.5),
    class = "dynet_bad_input")
  expect_error(
    dyn_centrality(dn, measure = "pagerank", transition = 0.5),
    class = "dynet_bad_input")
})

test_that("temporal pagerank streams contacts, so traversal_time is refused", {
  dn <- contacts(c("A", "B"), c("B", "C"), c(0, 1))
  expect_error(
    dyn_centrality(dn, measure = "pagerank", scope = "temporal",
                   traversal_time = 1),
    class = "dynet_bad_input")
})

test_that("rescale is accepted for temporal pagerank and still refused elsewhere", {
  dn <- contacts(c("A", "B"), c("B", "C"), c(0, 1))
  expect_equal(sum(pagerank(dn, rescale = TRUE)), 1)
  expect_error(
    dyn_centrality(dn, measure = "pagerank", scope = "snapshot",
                   rescale = TRUE),
    class = "dynet_bad_input")
  expect_error(
    dyn_centrality(dn, measure = "closeness", scope = "temporal",
                   rescale = TRUE),
    class = "dynet_bad_input")
})

test_that("a single contact gives the hand-computed damping split", {
  dn <- contacts("A", "B", 0)
  # r(A) = 1 - a from line 3; r(B) = a(1 - a) from line 5, reading the active
  # mass that line 4 has just created at A.
  expect_equal(pagerank(dn, damping = 0.85, rescale = FALSE),
               c(0.15, 0.85 * 0.15))
  expect_equal(pagerank(dn, damping = 0.85),
               c(0.15, 0.1275) / 0.2775)
  # Transition governs only what is left behind, so it cannot touch a stream
  # with nothing after it.
  expect_equal(pagerank(dn, damping = 0.85, transition = 0.3, rescale = FALSE),
               c(0.15, 0.1275))
})

test_that("a two-hop chain accumulates the walk the first contact started", {
  # A->B at 0 then B->C at 1. The second contact starts a walk at B worth
  # 1 - a and also carries across the a(1 - a) that the first contact left.
  dn <- contacts(c("A", "B"), c("B", "C"), c(0, 1))
  a <- 0.85
  want <- c(1 - a, a * (1 - a) + (1 - a), a * (a * (1 - a) + (1 - a)))
  expect_equal(pagerank(dn, damping = a, rescale = FALSE), want)
})

test_that("the batched recurrence reproduces Algorithm 1 line for line", {
  # Distinct timestamps put one contact in every batch, which is exactly the
  # case the paper's sequential algorithm defines. Agreement there is what
  # licenses the batch generalization elsewhere.
  set.seed(20160901)
  for (trial in seq_len(40L)) {
    n <- sample(3:8, 1L)
    stream <- random_stream(n, sample(8:40, 1L))
    if (length(stream$from) < 2L) next
    damping <- runif(1L, 0.1, 0.95)
    transition <- if (trial %% 3L == 0L) 1 else runif(1L, 0.05, 0.99)
    want <- stats::setNames(
      algorithm_one(stream$from, stream$to, n, damping, transition),
      stream$names)
    got <- pagerank_by_name(stream$dn, damping = damping,
                            transition = transition, rescale = FALSE)
    expect_equal(got[stream$names], want, tolerance = 1e-12)
  }
})

test_that("rescaled scores are a simplex point", {
  dn <- dynet(school_contacts, format = "contact")
  for (transition in c(0.2, 0.75, 1)) {
    value <- pagerank(dn, transition = transition)
    expect_equal(sum(value), 1, tolerance = sqrt(.Machine$double.eps))
    expect_true(all(value >= 0 & value <= 1))
  }
})

test_that("rescaling is the default, and switching it off returns the raw mass", {
  dn <- dynet(school_contacts, format = "contact")
  expect_identical(pagerank(dn), pagerank(dn, rescale = TRUE))
  raw <- pagerank(dn, rescale = FALSE)
  expect_true(sum(raw) > 1)
  expect_equal(raw / sum(raw), pagerank(dn))
})

test_that("simultaneous contacts are batched, so row order cannot matter", {
  base <- data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"),
                     time = c(0, 0, 0))
  nm <- c("A", "B", "C")
  mk <- function(df) dynet(df, format = "contact",
                           nodes = data.frame(name = nm),
                           observation_start = 0, observation_end = 1)
  first <- pagerank(mk(base), transition = 0.4, rescale = FALSE)
  for (perm in list(c(2L, 3L, 1L), c(3L, 1L, 2L), c(3L, 2L, 1L))) {
    expect_equal(pagerank(mk(base[perm, , drop = FALSE]), transition = 0.4,
                          rescale = FALSE), first)
  }
  # No walk composes inside one instant, so each vertex receives only the
  # length-one walk its own incoming contact carried.
  a <- 0.85
  expect_equal(first, rep((1 - a) + a * (1 - a), 3L))
})

test_that("a vertex declines every simultaneous offer it does not take", {
  # Two contacts leave A at once and a third leaves at the next instant. The
  # mass waiting at A has declined two offers by then, so it is attenuated by
  # transition squared, not by transition. Nothing in Algorithm 1 fixes this
  # case: it walks one contact at a time and never sees two at once.
  dn <- contacts(c("A", "A", "A"), c("B", "C", "D"), c(0, 0, 1))
  a <- 0.85
  b <- 0.4
  want <- c(3 * (1 - a), a * (1 - a), a * (1 - a), a * (1 - a) * (2 * b^2 + 1))
  expect_equal(pagerank(dn, damping = a, transition = b, rescale = FALSE),
               want)
  # The strict branch empties A instead, so the third contact carries only the
  # walk it starts itself.
  expect_equal(pagerank(dn, damping = a, transition = 1, rescale = FALSE),
               c(3 * (1 - a), a * (1 - a), a * (1 - a), a * (1 - a)))
})

test_that("the batch rule survives relabelling, which reorders an instant", {
  # Sorting the stream is not enough on its own: a canonical order keyed on
  # vertex names would make the answer depend on the names. Every contact here
  # shares one timestamp, so a rename that moves a vertex to the other end of
  # the sort is the sharpest available probe.
  nm <- c("A", "B", "C", "D")
  dn <- contacts(c("A", "A", "B", "C"), c("B", "C", "C", "D"), rep(0, 4L),
                 nodes = nm)
  before <- pagerank_by_name(dn, transition = 0.4, rescale = FALSE)
  renamed <- pagerank_by_name(rename_nodes(dn, c(A = "Z")),
                              transition = 0.4, rescale = FALSE)
  expect_equal(unname(before), unname(renamed[c("Z", "B", "C", "D")]))
})

test_that("relabelling vertices permutes the scores and changes no value", {
  dn <- dynet(school_contacts, format = "contact")
  before <- pagerank(dn, transition = 0.6)
  after <- pagerank(rename_nodes(dn, c(Ana = "Zara")), transition = 0.6)
  expect_equal(sort(before), sort(after))
})

test_that("a vertex outside the measured window scores exactly zero", {
  # Not NaN: the block does have contacts, so the total is positive and these
  # vertices genuinely carry none of it.
  dn <- contacts(c("A", "C"), c("B", "D"), c(1, 8), end = 20)
  value <- pagerank_by_name(dn, start = 0, end = 5)
  expect_identical(unname(value[c("C", "D")]), c(0, 0))
  expect_true(all(value[c("A", "B")] > 0))
})

test_that("a window with no eligible contact is undefined, not zero", {
  dn <- contacts(c("A", "B"), c("B", "C"), c(1, 2), end = 20)
  expect_true(all(is.nan(pagerank(dn, start = 10, end = 20))))
  expect_identical(pagerank(dn, start = 10, end = 20, rescale = FALSE),
                   c(0, 0, 0))
})

test_that("a longer stream never demotes a vertex out of positive score", {
  set.seed(4)
  n <- 8L
  from <- sample(n, 60L, replace = TRUE)
  to <- sample(n, 60L, replace = TRUE)
  keep <- from != to
  from <- from[keep]
  to <- to[keep]
  nm <- sprintf("v%02d", seq_len(n))
  positive <- lapply(c(10L, 20L, 30L, length(from)), function(m) {
    dn <- contacts(nm[from[seq_len(m)]], nm[to[seq_len(m)]], seq_len(m),
                   end = m + 1, nodes = nm)
    value <- pagerank_by_name(dn)
    nm %in% names(value)[value > 0]
  })
  expect_false(all(positive[[1L]]))
  for (i in seq_len(length(positive) - 1L)) {
    expect_true(all(positive[[i]] <= positive[[i + 1L]]))
  }
})

test_that("metadata records the recurrence's own parameters", {
  dn <- dynet(school_contacts, format = "contact")
  strict <- dyn_centrality(dn, measure = "pagerank", scope = "temporal")
  expect_identical(attr(strict, "damping"), 0.85)
  expect_identical(attr(strict, "transition"), 1)
  expect_identical(attr(strict, "normalization"), "sum_to_one")
  expect_identical(attr(strict, "walk_rule"), "strict")
  expect_identical(attr(strict, "static_limit"),
                   "out_degree_personalized_pagerank")
  # Proposition 2 covers the strict branch only; no limit is claimed below it.
  waiting <- dyn_centrality(dn, measure = "pagerank", scope = "temporal",
                            transition = 0.5, rescale = FALSE)
  expect_identical(attr(waiting, "static_limit"), "none_established")
  expect_identical(attr(waiting, "normalization"), "none")
  # A mixed call scopes each measure's record by name instead.
  mixed <- dyn_centrality(dn, measure = c("pagerank", "reach"),
                          scope = "temporal")
  expect_identical(attr(mixed, "measure_metadata")$pagerank$transition, 1)
})

test_that("rescaled scores converge to static PageRank on a regular digraph", {
  # Proposition 2 of Rozenshtein & Gionis (2016): sampling contacts from a
  # fixed digraph makes temporal PageRank converge to static PageRank
  # personalized by weighted out-degree. On a digraph of constant out-degree
  # that personalization is the uniform teleport .pagerank() already uses, and
  # no vertex is dangling, so the comparison is exact rather than approximate.
  skip_on_cran()
  RNGkind("L'Ecuyer-CMRG")
  old <- .Random.seed
  on.exit(assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  n <- 10L
  degree <- 3L
  damping <- 0.85
  nm <- sprintf("v%02d", seq_len(n))
  lengths <- c(1500L, 6000L)

  one_seed <- function(seed) {
    set.seed(seed)
    to <- unlist(lapply(seq_len(n), \(u) sample(setdiff(seq_len(n), u), degree)))
    edges <- data.frame(from = rep(seq_len(n), each = degree), to = to)
    a <- matrix(0, n, n, dimnames = list(nm, nm))
    a[cbind(edges$from, edges$to)] <- 1
    want <- unname(.pagerank(a, damping = damping))
    vapply(lengths, function(m) {
      pick <- sample(nrow(edges), m, replace = TRUE)
      dn <- contacts(nm[edges$from[pick]], nm[edges$to[pick]], seq_len(m),
                     end = m + 1, nodes = nm)
      max(abs(pagerank(dn, damping = damping) - want))
    }, numeric(1L))
  }

  deviation <- vapply(seq_len(20L), one_seed, numeric(length(lengths)))
  worst <- apply(deviation, 1L, max)
  # Pinned from the measured decay: the Monte Carlo error falls as one over
  # the square root of the stream, so quadrupling the stream roughly halves
  # the deviation. These bounds sit above the worst of twenty seeds with room
  # for the sampler, and would fail outright for a wrong recurrence.
  expect_lt(worst[[1L]], 0.05)
  expect_lt(worst[[2L]], 0.025)
  expect_lt(worst[[2L]], worst[[1L]])
})
