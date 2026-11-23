# collapse_network(sessions = "separate"): one collapsed network per session, stacked by as.data.frame() and
# summarised by summary(). The bundled school_contacts spells are labelled by week of their onset (three
# sessions), and the reference is a per-session ledger written here from the spell list: per session and ordered
# pair, the number of spells, their summed and unioned durations, the first onset and the last terminus.

spells <- transform(school_contacts, week = sprintf("week %d", floor(start / 7) + 1))
network <- dynet(spells, session = "week")
by_session <- collapse_network(network, sessions = "separate")

#' The length of the union of intervals (sorted by onset; a new run opens beyond every terminus seen so far)
union_length <- function(start, end) {
  by_onset <- order(start)
  start <- start[by_onset]
  reach <- cummax(end[by_onset])
  opens <- c(TRUE, start[-1L] > utils::head(reach, -1L))
  sum(tapply(reach, cumsum(opens), max) - start[opens])
}

ledger <- function() {
  parts <- split(spells, list(spells$week, spells$from, spells$to), drop = TRUE, sep = "\r")
  do.call(rbind, lapply(parts, \(one) data.frame(
    session = one$week[[1L]], from = one$from[[1L]], to = one$to[[1L]], spell_count = nrow(one),
    total_duration = sum(one$end - one$start), union_duration = union_length(one$start, one$end),
    first = min(one$start), last = max(one$end))))
}

test_that("the stacked per-session edge tables equal a per-session ledger of the spells", {
  # Sums of at most a dozen two-decimal numbers.
  expect_reference(as.data.frame(by_session), ledger(), reference = "independent: per-session ledger of the spells",
                   covers = c("collapse_network()", "as.data.frame.dynet_collapsed_list()"),
                   quantity = "session and pair", tolerance = 1e-10, key = c("session", "from", "to"))
})

test_that("sessions cut by set_tie_sessions(breaks = ) give the same per-session tables as the ledger", {
  # The same weeks, set on a network built without sessions: a spell starting at a break opens the later week.
  weeks <- seq_len(max(floor(spells$start / 7)))
  relabelled <- set_tie_sessions(dynet(school_contacts), breaks = 7 * weeks,
                                 labels = sprintf("week %d", c(weeks, max(weeks) + 1L)))
  # Sums of at most a dozen two-decimal numbers.
  expect_reference(as.data.frame(collapse_network(relabelled, sessions = "separate")), ledger(),
                   reference = "independent: per-session ledger of the spells",
                   covers = c("set_tie_sessions()", "collapse_network()"),
                   quantity = "session and pair, sessions set by breaks", tolerance = 1e-10,
                   key = c("session", "from", "to"))
})

test_that("one session's table alone equals that session's ledger", {
  theirs <- subset(ledger(), session == "week 2", select = -session)
  expect_reference(as.data.frame(by_session, session = "week 2"), theirs,
                   reference = "independent: per-session ledger of the spells",
                   covers = "as.data.frame.dynet_collapsed_list()", quantity = "week 2 pair", tolerance = 1e-10,
                   key = c("from", "to"))
})

test_that("summary() counts each session's pairs and vertices and sums its durations", {
  book <- ledger()
  parts <- split(book, book$session)
  theirs <- do.call(rbind, lapply(names(parts), \(s) {
    one <- parts[[s]]
    data.frame(session = s, pairs = nrow(one), nodes = length(unique(c(one$from, one$to))),
               union_duration = sum(one$union_duration), total_duration = sum(one$total_duration))
  }))
  expect_reference(summary(by_session), theirs, reference = "independent: per-session ledger of the spells",
                   covers = "summary.dynet_collapsed_list()", quantity = "per session", tolerance = 1e-10,
                   key = "session")
})
