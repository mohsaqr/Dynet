# randomise(): surrogate temporal networks from six null models (Gauvin et al. 2022). The draws come from the
# package's own random stream and cannot be supplied, so the evidence is a property check from the definition
# that holds for every draw: what each method declares it holds fixed, computed in base R from the surrogate spell
# table (as.data.frame()) and from the observed spells, replicate by replicate, over several seeds. A Monte Carlo
# summary is not needed: each property is exact for every replicate, so the tolerance is zero (or 1e-12 for sums of
# two-decimal times). Each draw's property table is compared whole, through its digest (equal or not).

spells <- school_contacts
network <- dynet(school_contacts)
seeds <- 1:5
draws_per_seed <- 20L
property_reference <- "independent: the invariant each null model holds fixed (Gauvin et al. 2022), base R"

pair_of <- function(tbl) paste(tbl$from, tbl$to, sep = " -> ")

#' The surrogates of every seed, stacked, with a `draw` key `<seed>.<replicate>`
surrogates <- function(method) {
  do.call(rbind, lapply(seeds, \(s) {
    one <- as.data.frame(randomise(network, method = method, n = draws_per_seed, seed = s))
    transform(one, draw = sprintf("%d.%d", s, replicate))
  }))
}

#' A property of each draw beside the same property of the observed spells, keyed by draw
#'
#' The property is a table (one row per item); its rows are written out in order and the text is reduced to its
#' number of rows and its SHA-256 digest, so that each draw is one comparison of identity (equal or not) rather
#' than hundreds of numbers. Equal digests mean equal tables.
per_draw <- function(drawn, property) {
  as_word <- \(tbl) {
    text <- paste(do.call(paste, c(unname(as.list(tbl)), sep = ":")), collapse = ";")
    sprintf("%d rows, sha256 %s", nrow(tbl), tools::sha256sum(bytes = charToRaw(text)))
  }
  parts <- split(drawn, drawn$draw)
  observed <- as_word(property(spells))
  list(ours = data.frame(draw = names(parts), property = vapply(parts, \(one) as_word(property(one)), character(1))),
       theirs = data.frame(draw = names(parts), property = observed))
}

sorted_times <- function(tbl) {
  by_time <- order(tbl$start, tbl$end)
  data.frame(item = seq_len(nrow(tbl)), start = tbl$start[by_time], end = tbl$end[by_time])
}

pair_counts <- function(tbl) {
  counts <- table(pair_of(tbl))
  data.frame(item = names(counts), events = as.vector(counts))
}

degrees <- function(tbl) {
  pairs <- unique(data.frame(from = tbl$from, to = tbl$to))
  people <- sort(unique(c(spells$from, spells$to)))
  data.frame(item = people, out_degree = as.vector(table(factor(pairs$from, people))),
             in_degree = as.vector(table(factor(pairs$to, people))))
}

test_that("method = 'times' keeps the multiset of spell times and of pairs in every draw", {
  drawn <- surrogates("times")
  times <- per_draw(drawn, sorted_times)
  expect_reference(times$ours, times$theirs, reference = property_reference,
                   covers = c("randomise()", "as.data.frame.dynet_null()"),
                   quantity = "times: sorted spell onsets and termini", tolerance = 0, key = "draw")
  pairs <- per_draw(drawn, pair_counts)
  expect_reference(pairs$ours, pairs$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "times: events per pair", tolerance = 0, key = "draw")
})

test_that("method = 'timeline' moves each pair's whole timeline onto a pair, keeping the timelines and the pairs", {
  timelines <- function(tbl) {
    tbl <- tbl[order(pair_of(tbl), tbl$start, tbl$end), ]
    strings <- tapply(sprintf("%.2f-%.2f", tbl$start, tbl$end), pair_of(tbl), paste, collapse = ";")
    data.frame(item = seq_along(strings), timeline = sort(unname(strings)))
  }
  drawn <- surrogates("timeline")
  moved <- per_draw(drawn, timelines)
  expect_reference(moved$ours, moved$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "timeline: the multiset of pair timelines", tolerance = 0, key = "draw")
  pairs <- per_draw(drawn, \(tbl) data.frame(item = sort(unique(pair_of(tbl))), present = TRUE))
  expect_reference(pairs$ours, pairs$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "timeline: the set of pairs", tolerance = 0, key = "draw")
})

test_that("method = 'edges' keeps every vertex's aggregate in- and out-degree and the spell times", {
  drawn <- surrogates("edges")
  kept <- per_draw(drawn, degrees)
  expect_reference(kept$ours, kept$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "edges: aggregate degrees", tolerance = 0, key = "draw")
  times <- per_draw(drawn, sorted_times)
  expect_reference(times$ours, times$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "edges: sorted spell onsets and termini", tolerance = 0, key = "draw")
})

test_that("method = 'targets' keeps each sender's spell times and the multiset of receivers", {
  sender_times <- function(tbl) {
    tbl <- tbl[order(tbl$from, tbl$start, tbl$end), ]
    data.frame(item = paste(tbl$from, stats::ave(tbl$start, tbl$from, FUN = seq_along)),
               start = tbl$start, end = tbl$end)
  }
  receivers <- function(tbl) {
    counts <- table(tbl$to)
    data.frame(item = names(counts), events = as.vector(counts))
  }
  drawn <- surrogates("targets")
  senders <- per_draw(drawn, sender_times)
  expect_reference(senders$ours, senders$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "targets: each sender's spells", tolerance = 0, key = "draw")
  reached <- per_draw(drawn, receivers)
  expect_reference(reached$ours, reached$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "targets: events per receiver", tolerance = 0, key = "draw")
})

test_that("method = 'labels' keeps the network up to a renaming: sorted degrees and spell times", {
  sorted_degrees <- function(tbl) {
    d <- degrees(tbl)
    by_degree <- order(d$out_degree, d$in_degree)
    data.frame(item = seq_len(nrow(d)), out_degree = d$out_degree[by_degree], in_degree = d$in_degree[by_degree])
  }
  drawn <- surrogates("labels")
  kept <- per_draw(drawn, sorted_degrees)
  expect_reference(kept$ours, kept$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "labels: degree sequence", tolerance = 0, key = "draw")
  times <- per_draw(drawn, sorted_times)
  expect_reference(times$ours, times$theirs, reference = property_reference, covers = "randomise()",
                   quantity = "labels: sorted spell onsets and termini", tolerance = 0, key = "draw")
})

test_that("method = 'reversal' reflects every spell about the observed span", {
  lo <- min(spells$start)
  hi <- max(spells$end)
  reflected <- with(spells, data.frame(from = from, to = to, start = lo + hi - end, end = lo + hi - start))
  keyed <- function(tbl) {
    tbl <- tbl[order(pair_of(tbl), tbl$start, tbl$end), ]
    data.frame(item = paste(pair_of(tbl), stats::ave(tbl$start, pair_of(tbl), FUN = seq_along)),
               start = tbl$start, end = tbl$end)
  }
  ours <- keyed(as.data.frame(randomise(network, method = "reversal")))
  # Differences of two-decimal times.
  expect_reference(ours, keyed(reflected), reference = property_reference,
                   covers = c("randomise()", "as.data.frame.dynet_null()"),
                   quantity = "reversal: reflected spells", tolerance = 1e-12, key = "item")
})

test_that("summary() of the surrogates counts each replicate's events, pairs, span and mean duration", {
  null <- randomise(network, method = "timeline", n = draws_per_seed, seed = 7)
  drawn <- as.data.frame(null)
  parts <- split(drawn, drawn$replicate)
  theirs <- do.call(rbind, lapply(parts, \(p) data.frame(
    replicate = p$replicate[[1L]], n_events = nrow(p), n_pairs = length(unique(pair_of(p))),
    t_min = min(p$start), t_max = max(p$end), mean_duration = mean(p$end - p$start), rejected = 0)))
  # Means of 240 two-decimal durations.
  expect_reference(summary(null), theirs, reference = "independent: counts and means of the surrogate spell table",
                   covers = "summary.dynet_null()", quantity = "per replicate", tolerance = 1e-12,
                   key = "replicate")
})

test_that("method = 'times' does not keep the pair timelines (negative control of the digests)", {
  timelines <- function(tbl) {
    tbl <- tbl[order(pair_of(tbl), tbl$start, tbl$end), ]
    strings <- tapply(sprintf("%.2f-%.2f", tbl$start, tbl$end), pair_of(tbl), paste, collapse = ";")
    data.frame(item = seq_along(strings), timeline = sort(unname(strings)))
  }
  moved <- per_draw(surrogates("times"), timelines)
  expect_differs(moved$ours, moved$theirs, reference = property_reference, covers = "randomise()",
                 quantity = "times: the multiset of pair timelines (must change)", tolerance = 0, key = "draw")
})
