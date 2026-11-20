# motifs(): the census of three-edge, three-node delta-temporal motifs of Paranjape, Benson & Leskovec (2017).
# The reference is an exhaustive enumeration written here from the definition: every triple of distinct events
# (i < j < k in time order) whose last event is no later than delta after the first, on at most three vertices,
# classified one by one. Nothing in it calls Dynet.
#
# The 40 classes are numbered as raphtory 0.17 numbers them (Dynet's documented order), written here as rules:
#   - a direction bit per edge relative to a vertex x: 1 when the edge leaves x (raphtory's OUTGOING), 0 when it
#     enters x (INCOMING); a pattern of three bits d1 d2 d3 in time order has code 4*d1 + 2*d2 + d3 (raphtory's
#     map3d);
#   - star (three vertices, two distinct pairs, a centre in every edge): the edge to the leaf seen once is the
#     lone edge; lone edge last = "pre" (classes 1-8), in the middle = "mid" (9-16), first = "post" (17-24);
#     class = offset + code + 1 with the bits taken at the centre; only the centre counts it locally;
#   - two-node (one pair): one class per endpoint x, 25 + code at x, and the global census counts both (as
#     raphtory does); each endpoint counts its own class locally;
#   - triangle (three distinct pairs): with the first edge u -> v and w the third vertex, a = 1 when the second
#     edge touches u, b = 1 when the second edge enters w, c = 1 when the third edge leaves w; class
#     33 + 4a + 2b + c; all three vertices count it locally.
# Simultaneous events are put in Dynet's documented order (time, then sender name, then receiver name, then row),
# which only the school_contacts case needs (its spell starts repeat); the synthetic case has distinct times.

#' Classify one triple of events, given in time order
#'
#' @param from,to Character vectors of length three.
#' @return A data frame with `node`, `motif` and `global` (whether the row adds to the global census), or `NULL`
#'   when the triple spans more than three vertices.
classify_triple <- function(from, to) {
  nodes <- unique(as.vector(rbind(from, to)))
  if (length(nodes) > 3L) return(NULL)
  bits_at <- function(x) as.integer(from == x)
  code <- function(bits) 4L * bits[[1L]] + 2L * bits[[2L]] + bits[[3L]]
  if (length(nodes) == 2L) {
    return(data.frame(node = nodes, motif = 25L + vapply(nodes, \(x) code(bits_at(x)), integer(1)),
                      global = TRUE))
  }
  pairs <- vapply(seq_len(3L), \(e) paste(sort(c(from[[e]], to[[e]])), collapse = "\r"), character(1))
  if (length(unique(pairs)) == 2L) {
    centre <- Reduce(intersect, Map(c, from, to))
    lone <- which(!duplicated(pairs) & !duplicated(pairs, fromLast = TRUE))
    offset <- c(16L, 8L, 0L)[[lone]]
    return(data.frame(node = centre, motif = offset + code(bits_at(centre)) + 1L, global = TRUE))
  }
  u <- from[[1L]]
  w <- setdiff(nodes, c(u, to[[1L]]))
  a <- as.integer(u %in% c(from[[2L]], to[[2L]]))
  b <- as.integer(to[[2L]] == w)
  c3 <- as.integer(from[[3L]] == w)
  data.frame(node = nodes, motif = 33L + 4L * a + 2L * b + c3, global = c(TRUE, FALSE, FALSE))
}

#' Every motif instance of an event list
#'
#' @param events A data frame with `from`, `to`, `time`.
#' @param delta The window.
#' @param slack The inclusive window's comparison slack, below the data's time resolution.
#' @return The stacked attributions of every instance (`classify_triple()` rows).
enumerate_motifs <- function(events, delta, slack = 1e-9) {
  events <- subset(events, from != to)
  events <- events[order(events$time, events$from, events$to, seq_len(nrow(events))), ]
  triples <- utils::combn(nrow(events), 3L)
  span <- events$time[triples[3L, ]] - events$time[triples[1L, ]]
  inside <- triples[, span <= delta + slack, drop = FALSE]
  rows <- lapply(seq_len(ncol(inside)), \(i) classify_triple(events$from[inside[, i]], events$to[inside[, i]]))
  do.call(rbind, rows)
}

family_of <- function(motif) {
  c("star_pre", "star_mid", "star_post", "two_node", "triangle")[(motif - 1L) %/% 8L + 1L]
}

global_census <- function(instances) {
  data.frame(motif = seq_len(40L),
             count = tabulate(subset(instances, global)$motif, nbins = 40L))
}

local_census <- function(instances, nodes) {
  grid <- expand.grid(motif = seq_len(40L), node = nodes, stringsAsFactors = FALSE)
  counts <- unclass(table(factor(instances$node, nodes), factor(instances$motif, seq_len(40L))))
  transform(grid, count = as.vector(counts[cbind(match(grid$node, nodes), grid$motif)]))
}

family_summary <- function(census) {
  total <- sum(census$count)
  parts <- split(census, family_of(census$motif))
  do.call(rbind, lapply(names(parts), \(f) {
    one <- parts[[f]]
    data.frame(family = f, count = sum(one$count), share = sum(one$count) / total,
               top_motif = if (sum(one$count) > 0) one$motif[[which.max(one$count)]] else NA_integer_)
  }))
}

synthetic_events <- function() {
  set.seed(20171)
  events <- data.frame(from = sample(LETTERS[1:6], 140, replace = TRUE),
                       to = sample(LETTERS[1:6], 140, replace = TRUE),
                       time = sort(sample(seq(0, 200, by = 0.01), 140)))
  subset(events, from != to)
}

motif_reference <- "independent: exhaustive enumeration of Paranjape et al. (2017) 3-edge delta-temporal motifs"

test_that("the global census of a synthetic event list equals an exhaustive enumeration", {
  events <- synthetic_events()
  census <- motifs(dynet(events, format = "contact"), delta = 8)
  theirs <- global_census(enumerate_motifs(events, delta = 8))
  # Counts of triples: integers.
  expect_reference(as.data.frame(census), theirs, reference = motif_reference,
                   covers = c("motifs()", "as.data.frame.dynet_motifs()"), quantity = "instances, delta = 8",
                   tolerance = 0, key = "motif")
})

test_that("the local census of a synthetic event list equals an exhaustive enumeration", {
  events <- synthetic_events()
  census <- motifs(dynet(events, format = "contact"), delta = 8, output = "local")
  theirs <- local_census(enumerate_motifs(events, delta = 8), sort(unique(c(events$from, events$to))))
  expect_reference(as.data.frame(census), theirs, reference = motif_reference,
                   covers = c("motifs()", "as.data.frame.dynet_motifs()"),
                   quantity = "instances per vertex, delta = 8", tolerance = 0, key = c("node", "motif"))
})

test_that("the family summary of a census equals the enumeration's counts, shares and largest class", {
  events <- synthetic_events()
  census <- motifs(dynet(events, format = "contact"), delta = 8)
  theirs <- family_summary(global_census(enumerate_motifs(events, delta = 8)))
  # Shares are ratios of counts below a thousand.
  expect_reference(summary(census), theirs, reference = motif_reference, covers = "summary.dynet_motifs()",
                   quantity = "by family, delta = 8", tolerance = 1e-12, key = "family")
})

test_that("the census of school_contacts (spell onsets as events) equals an exhaustive enumeration", {
  events <- transform(school_contacts, time = start)
  for_delta <- function(delta) {
    ours <- transform(as.data.frame(motifs(dynet(school_contacts), delta = delta)), delta = delta)
    theirs <- transform(global_census(enumerate_motifs(events, delta = delta)), delta = delta)
    list(ours = ours, theirs = theirs)
  }
  runs <- lapply(c(0.5, 1, 2), for_delta)
  # The onsets are recorded to 0.01, so the inclusive window is compared with a slack of 1e-9 in the enumeration.
  expect_reference(do.call(rbind, lapply(runs, `[[`, "ours")), do.call(rbind, lapply(runs, `[[`, "theirs")),
                   reference = motif_reference, covers = c("motifs()", "as.data.frame.dynet_motifs()"),
                   quantity = "school_contacts instances", tolerance = 0, key = c("delta", "motif"))
})

test_that("the census differs from the enumeration at another delta (negative control)", {
  events <- synthetic_events()
  census <- summary(motifs(dynet(events, format = "contact"), delta = 8))
  theirs <- family_summary(global_census(enumerate_motifs(events, delta = 4)))
  expect_differs(subset(census, family != "two_node", select = c(family, count)),
                 subset(theirs, family != "two_node", select = c(family, count)),
                 reference = motif_reference, covers = "motifs()",
                 quantity = "stars and triangles per family, delta 8 against delta 4", tolerance = 0, key = "family")
})
