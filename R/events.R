# ===========================================================================
# Edge dynamics: formation, dissolution, durations, burstiness
# ===========================================================================

#' Edge formation and dissolution over time
#'
#' @description
#' When relationships are born and when they die. In a static network every
#' edge is present at once; here the turnover itself is the finding. A course
#' typically shows formation front-loaded and dissolution piling up at the
#' end, and a group that never dissolves an edge is behaving differently from
#' one that constantly re-forms them.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure One or more of `"formation"` (spells beginning in the bin),
#'   `"dissolution"` (spells ending in the bin), `"active"` (spells alive
#'   during the bin) and `"new_pairs"` (vertex pairs meeting for the first
#'   time).
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end First and last time at which to measure. Default to the
#'   observed range. A network built from dates may be addressed with dates.
#' @param step How often to measure. Defaults to the interval the network was
#'   built with.
#' @param window How much time each measurement covers. Defaults to `step`,
#'   which tiles the period into disjoint bins. A larger value slides an
#'   overlapping window; `0` samples the network at each point in time.
#'
#' @return A `dynet_metric` at graph level, one row per time point and
#'   measure.
#'
#' @details
#' Formation and dissolution are counted inside each window, so overlapping
#' windows (`window > step`) count the same event more than once by design --
#' that is what a rolling total is. Setting `window` equal to `step`, the
#' default, gives disjoint counts that sum to the total turnover.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' dyn_events(dn)
#' plot(dyn_events(dn, measure = c("formation", "dissolution")))
#'
#' @export
dyn_events <- function(dn,
                       measure = c("formation", "dissolution"),
                       sessions = c("bounded", "collapse", "separate"),
                       start = NULL, end = NULL,
                       step = NULL, window = NULL) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  spec <- .window_spec(dn, start, end, step, window)
  allowed <- c("formation", "dissolution", "active", "new_pairs")
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }

  df <- .over_bins(dn, sessions, node_level = FALSE, spec = spec,
    fun = function(enc, act, bin) {
      lo <- bin$lo; hi <- bin$hi
      pair <- paste(enc$from, enc$to, sep = "\r")
      first_seen <- !duplicated(pair[order(enc$start)])[order(order(enc$start))]
      # The final window of a defaulted grid is closed on the right, exactly as
      # it is for edge activity; without this a spell beginning on the last
      # observed instant would be counted by dyn_metrics() and lost here.
      within <- function(t) {
        if (spec$window == 0) return(t == lo)
        if (isTRUE(bin$closed)) t >= lo & t <= hi else t >= lo & t < hi
      }
      vals <- vapply(measure, function(m) switch(m,
        formation   = sum(within(enc$start)),
        dissolution = sum(within(enc$end)),
        active      = sum(act),
        new_pairs   = sum(first_seen & within(enc$start))
      ), numeric(1L))
      vals
    })

  .metric(df, level = "graph",
          what = if (length(measure) == 1L) .event_label(measure) else "Edge dynamics",
          dn = dn, spec = spec)
}

#' Human-readable label for an event measure
#' @param m Measure name.
#' @return A single character string.
#' @keywords internal
.event_label <- function(m) {
  unname(c(formation = "Edges formed", dissolution = "Edges dissolved",
           active = "Active edges", new_pairs = "First-time pairs")[m] %||% m)
}


# ===========================================================================
# dyn_durations()
# ===========================================================================

#' How long each relationship lasted
#'
#' @description
#' One row per vertex pair, summarising every spell they shared. Duration is
#' what separates an interval network from a contact network: a pair that met
#' fifty times briefly and a pair that met once at length have the same edge
#' weight in a static network and nothing else in common.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure One or more of `"events"` (number of spells), `"total"`
#'   (summed duration), `"mean"`, `"median"`, `"first"` (time of the first
#'   spell) and `"last"` (time the pair was last active).
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#'
#' @return A `dynet_metric` at edge level: one row per vertex pair and
#'   measure, with columns `from`, `to`, `measure` and `value`.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' dyn_durations(dn)
#' summary(dyn_durations(dn), by = "measure")
#'
#' @export
dyn_durations <- function(dn, measure = c("events", "total", "mean"),
                          sessions = c("bounded", "collapse", "separate")) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  allowed <- c("events", "total", "mean", "median", "first", "last")
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }

  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    key <- paste(enc$names[enc$from], enc$names[enc$to], sep = "\r")
    idx <- split(seq_along(key), key)
    dur <- enc$end - enc$start
    stats_tbl <- lapply(idx, function(i) c(
      events = length(i),
      total  = sum(dur[i]),
      mean   = mean(dur[i]),
      median = stats::median(dur[i]),
      first  = min(enc$start[i]),
      last   = max(enc$end[i])
    ))
    pairs <- do.call(rbind, strsplit(names(idx), "\r", fixed = TRUE))
    do.call(rbind, lapply(measure, function(m) data.frame(
      session = label, from = pairs[, 1L], to = pairs[, 2L],
      measure = m, value = vapply(stats_tbl, `[[`, numeric(1L), m),
      stringsAsFactors = FALSE)))
  }, parts, names(parts))

  out <- do.call(rbind, frames)
  out <- out[order(out$measure, out$from, out$to), , drop = FALSE]
  .metric(out, level = "edge", what = "Relationship duration", dn = dn,
          note = sprintf("durations in %s", dn$meta$time_unit))
}


# ===========================================================================
# dyn_burstiness()
# ===========================================================================

#' Burstiness and memory of each vertex's activity
#'
#' @description
#' Whether a vertex acts in bursts or at a steady pace. Burstiness compares
#' the spread of the gaps between a vertex's events with their average: it is
#' `1` for a perfectly bursty sequence, `0` for a Poisson process and `-1` for
#' a metronome. The memory coefficient asks a different question -- whether a
#' short gap tends to be followed by another short gap.
#'
#' Two vertices can post the same number of times and differ entirely on both.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure One or more of `"burstiness"`, `"memory"`, `"events"` and
#'   `"mean_gap"`.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#'
#' @return A `dynet_metric` at node level with no time column: one row per
#'   vertex and measure. Vertices with fewer than three events give `NA` for
#'   burstiness and fewer than four for memory, because the quantity is not
#'   defined there.
#'
#' @references
#' Goh, K.-I., & Barabasi, A.-L. (2008). Burstiness and memory in complex
#' systems. *Europhysics Letters*, 81(4), 48002.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' dyn_burstiness(dn)
#'
#' @export
dyn_burstiness <- function(dn, measure = c("burstiness", "memory", "events"),
                           sessions = c("bounded", "collapse", "separate")) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  allowed <- c("burstiness", "memory", "events", "mean_gap")
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }

  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    incident <- split(c(enc$start, enc$start),
                      factor(c(enc$from, enc$to), levels = seq_len(enc$n)))
    per_node <- lapply(incident, .burst_stats)
    data.frame(session = label, node = rep(enc$names, times = length(measure)),
               measure = rep(measure, each = enc$n),
               value = unlist(lapply(measure, function(m)
                 vapply(per_node, `[[`, numeric(1L), m)), use.names = FALSE),
               stringsAsFactors = FALSE)
  }, parts, names(parts))

  .metric(do.call(rbind, frames), level = "node", what = "Burstiness", dn = dn,
          note = "1 is fully bursty, 0 is Poisson, -1 is perfectly regular")
}

#' Burstiness statistics for one vertex's event times
#' @param times Numeric vector of event times.
#' @return A named numeric vector with `burstiness`, `memory`, `events`,
#'   `mean_gap`.
#' @keywords internal
.burst_stats <- function(times) {
  times <- sort(times)
  gaps <- diff(times)
  n <- length(gaps)
  out <- c(burstiness = NA_real_, memory = NA_real_,
           events = length(times), mean_gap = NA_real_)
  if (n == 0L) return(out)
  out[["mean_gap"]] <- mean(gaps)
  if (n >= 2L) {
    mu <- mean(gaps)
    s  <- stats::sd(gaps)
    out[["burstiness"]] <- if (s + mu > 0) (s - mu) / (s + mu) else NA_real_
  }
  if (n >= 3L) {
    a <- gaps[-n]; b <- gaps[-1L]
    out[["memory"]] <- if (stats::sd(a) > 0 && stats::sd(b) > 0) stats::cor(a, b)
      else NA_real_
  }
  out
}
