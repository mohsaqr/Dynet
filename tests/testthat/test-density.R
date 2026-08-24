.temporal_density_value <- function(dn) {
  row <- subset(summary(dn), property == "temporal density", select = value)
  if (trimws(row$value) == "NA") return(NA_real_)
  as.numeric(row$value)
}

.density_oracle <- function(dn) {
  bounds <- unname(dn$meta$time_range)
  span <- bounds[[2L]] - bounds[[1L]]
  n <- nrow(as.data.frame(dn, what = "nodes"))
  possible_pairs <- if (dn$directed) n * (n - 1L) else choose(n, 2L)

  if (possible_pairs == 0L || span <= 0) return(NA_real_)

  spells <- subset(as.data.frame(dn), from != to)
  spells$start <- pmax(spells$start, bounds[[1L]])
  spells$end <- pmin(spells$end, bounds[[2L]])
  spells <- subset(spells, end > start)
  if (nrow(spells) == 0L) return(0)

  if (!dn$directed) {
    left <- pmin(spells$from, spells$to)
    right <- pmax(spells$from, spells$to)
    spells$from <- left
    spells$to <- right
  }
  pair <- paste(spells$from, spells$to, sep = "\r")
  change_points <- sort(unique(c(bounds, spells$start, spells$end)))
  widths <- diff(change_points)
  midpoints <- change_points[-length(change_points)] + widths / 2
  active_pairs <- vapply(midpoints, function(time) {
    active <- spells$start <= time & spells$end > time
    length(unique(pair[active]))
  }, integer(1L))

  sum(widths * active_pairs) / (possible_pairs * span)
}

.two_vertex_density <- function(start, end, to = rep("B", length(start)),
                                directed = TRUE) {
  spells <- data.frame(
    from = rep("A", length(start)),
    to = to,
    start = start,
    end = end,
    stringsAsFactors = FALSE
  )
  quiet_dynet(spells, directed = directed)
}

test_that("one pair's spell durations are unioned exactly", {
  cases <- list(
    list(start = numeric(), end = numeric(), expected = 0),
    list(start = c(0, 0, 0), end = c(10, 10, 10), expected = 10),
    list(start = c(0, 2, 4), end = c(10, 3, 9), expected = 10),
    list(start = c(0, 2, 6), end = c(4, 7, 10), expected = 10),
    list(start = c(0, 2, 7), end = c(2, 7, 10), expected = 10),
    list(start = c(0, 3, 8), end = c(2, 5, 10), expected = 6),
    list(start = c(6, 0, 2), end = c(10, 4, 7), expected = 10),
    list(start = c(2, 2), end = c(2, 2), expected = 0),
    list(start = c(0, 4, 4), end = c(3, 4, 8), expected = 7)
  )

  invisible(lapply(cases, function(case) {
    expect_equal(.union_duration(case$start, case$end), case$expected)
  }))
})

test_that("the interval-union helper rejects malformed intervals", {
  expect_error(.union_duration(0, c(1, 2)), class = "dynet_bad_input")
  expect_error(.union_duration(c(0, NA), c(1, 2)), class = "dynet_bad_input")
  expect_error(.union_duration(2, 1), class = "dynet_bad_input")
})

test_that("temporal density unions duplicate, nested, and overlapping spells", {
  fixtures <- list(
    duplicate = .two_vertex_density(c(0, 0, 0), c(10, 10, 10)),
    nested = .two_vertex_density(c(0, 2, 4), c(10, 3, 9)),
    overlap = .two_vertex_density(c(0, 2, 6), c(4, 7, 10)),
    touching = .two_vertex_density(c(0, 2, 7), c(2, 7, 10)),
    disjoint = .two_vertex_density(c(0, 3, 8), c(2, 5, 10))
  )
  expected <- c(duplicate = 0.5, nested = 0.5, overlap = 0.5,
                touching = 0.5, disjoint = 0.3)

  got <- vapply(fixtures, .temporal_density_value, numeric(1L))
  expect_equal(got, expected)
  expect_equal(vapply(fixtures, .temporal_density, numeric(1L)), expected)
})

test_that("directed reverse pairs remain separate opportunities", {
  spells <- data.frame(
    from = c("A", "A", "B"),
    to = c("B", "B", "A"),
    start = c(0, 0, 0),
    end = c(10, 10, 5),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells)

  expect_equal(.temporal_density_value(dn), 0.75)
  expect_equal(.temporal_density(dn), 0.75)
})

test_that("temporal density excludes loops but retains the observation window", {
  spells <- data.frame(
    from = c("A", "A"), to = c("A", "B"),
    start = c(0, 0), end = c(10, 10),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, loops = TRUE)

  expect_equal(.temporal_density_value(dn), 0.5)
})

test_that("collapsed sessions share one calendar and one pair opportunity", {
  spells <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(0, 0), end = c(10, 10), session = c("s1", "s2"),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(spells, session = "session")

  expect_equal(.temporal_density_value(dn), 0.5)
})

test_that("zero-duration contacts have zero occupancy", {
  contacts <- data.frame(
    from = c("A", "A"), to = c("B", "B"), time = c(0, 10),
    stringsAsFactors = FALSE
  )
  positive_span <- quiet_dynet(contacts, time = "time")
  zero_span <- quiet_dynet(subset(contacts, time == 0), time = "time")

  expect_equal(.temporal_density_value(positive_span), 0)
  expect_true(is.na(.temporal_density_value(zero_span)))
  expect_true(is.na(.temporal_density(zero_span)))
})

test_that("a network with no possible non-loop relation has undefined density", {
  loop <- data.frame(
    from = "A", to = "A", start = 0, end = 10,
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(loop, loops = TRUE)

  expect_true(is.na(.temporal_density_value(dn)))
  expect_true(is.na(.temporal_density(dn)))
})

test_that("temporal density clips spells to stored observation bounds", {
  crossing <- data.frame(
    from = c("A", "A"), to = c("B", "B"),
    start = c(-5, 8), end = c(2, 15),
    stringsAsFactors = FALSE
  )
  dn <- quiet_dynet(crossing)
  dn$meta$time_range <- c(start = 0, end = 10)

  expect_equal(.temporal_density(dn), 0.2)
  expect_equal(.temporal_density(dn), .density_oracle(dn))
})

test_that("complete directed and undirected networks have density one", {
  directed <- expand.grid(
    from = c("A", "B", "C"), to = c("A", "B", "C"),
    stringsAsFactors = FALSE
  ) |>
    subset(from != to) |>
    transform(start = 0, end = 10)
  undirected <- data.frame(
    from = c("A", "A", "B"), to = c("B", "C", "C"),
    start = 0, end = 10, stringsAsFactors = FALSE
  )

  expect_equal(.temporal_density_value(quiet_dynet(directed)), 1)
  expect_equal(
    .temporal_density_value(quiet_dynet(undirected, directed = FALSE)),
    1
  )
})

test_that("temporal density agrees with an independent change-point oracle", {
  random <- random_edges(n_v = 8L, n_e = 80L, span = 25, seed = 317L)
  random$session <- rep(c("one", "two"), length.out = nrow(random))
  duplicated <- rbind(random, random)
  translated <- transform(random, start = start + 100, end = end + 100)
  scaled <- transform(random, start = start * 7, end = end * 7)

  networks <- list(
    directed = quiet_dynet(random, session = "session"),
    undirected = quiet_dynet(random, session = "session", directed = FALSE),
    duplicated = quiet_dynet(duplicated, session = "session"),
    translated = quiet_dynet(translated, session = "session"),
    scaled = quiet_dynet(scaled, session = "session")
  )

  invisible(lapply(networks, function(dn) {
    expect_equal(.temporal_density(dn), .density_oracle(dn), tolerance = 1e-12)
    expect_true(.temporal_density(dn) >= 0 && .temporal_density(dn) <= 1)
  }))
  expect_equal(.temporal_density(networks$directed),
               .temporal_density(networks$duplicated))
  expect_equal(.temporal_density(networks$directed),
               .temporal_density(networks$translated))
  expect_equal(.temporal_density(networks$directed),
               .temporal_density(networks$scaled))
})

test_that("temporal density obeys representation invariants", {
  original <- data.frame(
    from = c("A", "A", "B"), to = c("B", "B", "A"),
    start = c(0, 4, 2), end = c(4, 10, 8),
    weight = c(1, 2, 3), stringsAsFactors = FALSE
  )
  split_spell <- data.frame(
    from = c("A", "A", "A", "B"), to = c("B", "B", "B", "A"),
    start = c(0, 4, 7, 2), end = c(4, 7, 10, 8),
    weight = c(12, 7, 99, 4), stringsAsFactors = FALSE
  )
  renamed <- transform(original,
                       from = ifelse(from == "A", "X", "Y"),
                       to = ifelse(to == "A", "X", "Y"))
  reversed <- transform(original, from = original$to, to = original$from)

  reference <- .temporal_density(quiet_dynet(original, weight = "weight"))
  variants <- list(
    split = quiet_dynet(split_spell, weight = "weight"),
    permuted = quiet_dynet(original[c(3, 1, 2), ], weight = "weight"),
    renamed = quiet_dynet(renamed, weight = "weight"),
    reversed = quiet_dynet(reversed, weight = "weight")
  )

  expect_equal(unname(vapply(variants, .temporal_density, numeric(1L))),
               rep(reference, length(variants)))
})
