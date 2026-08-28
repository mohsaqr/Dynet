# ===========================================================================
# Edge dynamics: formation, dissolution, durations, burstiness
# ===========================================================================

#' One-sided positive observation state
#' @param dn Parent temporal network.
#' @param time Numeric timestamp.
#' @param side Limit immediately `"before"` or `"after"` the timestamp batch.
#' @return A single logical value; punctual observations are false on both
#'   sides.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.one_sided_observation(dn, 1, "before")
#' @keywords internal
.one_sided_observation <- function(dn, time,
                                   side = c("before", "after")) {
  side <- match.arg(side)
  observations <- .observation_table(dn)
  if (is.null(observations)) {
    bounds <- dn$meta$time_range
    observations <- data.frame(
      start = bounds[["start"]], end = bounds[["end"]]
    )
  }
  positive <- observations$end > observations$start
  if (identical(side, "before")) {
    any(positive & observations$start < time & time <= observations$end)
  } else {
    any(positive & observations$start <= time & time < observations$end)
  }
}

#' One-sided vertex eligibility
#' @param activity Encoded canonical activity from
#'   [.encode_vertex_activity()].
#' @param time Numeric timestamp.
#' @param side Limit immediately `"before"` or `"after"` the timestamp batch.
#' @param session Optional session label; global rows also apply.
#' @param erase_sessions Whether to erase every activity-session label.
#' @return Fixed-universe logical eligibility; vertex points are false on both
#'   sides.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.one_sided_vertex_eligibility(
#'   Dynet:::.encode_vertex_activity(dn), 1, "after"
#' )
#' @keywords internal
.one_sided_vertex_eligibility <- function(
    activity, time, side = c("before", "after"), session = NULL,
    erase_sessions = FALSE) {
  side <- match.arg(side)
  eligible <- !activity$declared
  if (!length(activity$node)) return(eligible)
  session_rows <- if (erase_sessions || all(is.na(activity$session))) {
    rep(TRUE, length(activity$node))
  } else if (is.null(session)) {
    is.na(activity$session)
  } else {
    is.na(activity$session) | activity$session == session
  }
  positive <- !activity$instant & if (identical(side, "before")) {
    activity$start < time & time <= activity$end
  } else {
    activity$start <= time & time < activity$end
  }
  eligible[unique(activity$node[session_rows & positive])] <- TRUE
  eligible
}

#' Exact pair states around one timestamp batch
#' @param dn Parent temporal network.
#' @param enc Encoded session block.
#' @param time Numeric timestamp.
#' @param sessions Session aggregation policy.
#' @param label Session label for a separate block.
#' @return A list of collision-free integer pair-key sets for side eligibility,
#'   two-sided eligibility, binary pre/post activity, formation risk, confirmed
#'   formations, dissolution risk, and confirmed dissolutions, plus typed named
#'   counts. The existing formation `counts` vector is preserved; dissolution
#'   totals are in `dissolution_counts`.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 1, end = 2),
#'             observation_start = 0, observation_end = 3)
#' Dynet:::.transition_pair_ledger(dn, Dynet:::.encode(dn), 1, "collapse")
#' @keywords internal
.transition_pair_ledger <- function(
    dn, enc, time, sessions = c("bounded", "collapse", "separate"),
    label = "all") {
  sessions <- match.arg(sessions)
  opportunities <- .relational_opportunities(enc$n, dn$directed)
  empty <- list(
    eligible_before = integer(), eligible_after = integer(),
    two_sided = integer(), active_before = integer(),
    active_after = integer(), formation_risk = integer(),
    formations = integer(), onset_confirmation = integer(),
    terminus_confirmation = integer(), dissolution_risk = integer(),
    dissolutions = integer(),
    counts = c(formation_risk = 0L, formations = 0L),
    dissolution_counts = c(dissolution_risk = 0L, dissolutions = 0L)
  )
  if (!nrow(opportunities)) return(empty)
  observed_before <- .one_sided_observation(dn, time, "before")
  observed_after <- .one_sided_observation(dn, time, "after")
  activity <- .encode_vertex_activity(dn, enc$names)
  has_sessions <- !is.null(dn$meta$sessions)
  scopes <- if (identical(sessions, "collapse") || !has_sessions) {
    list(list(
      session = NULL, erase = TRUE,
      edge_rows = rep(TRUE, length(enc$start)),
      raw_rows = rep(TRUE, length(enc$raw_event_start))
    ))
  } else if (identical(sessions, "separate")) {
    list(list(
      session = label, erase = FALSE, edge_rows = enc$session == label,
      raw_rows = enc$raw_event_session == label
    ))
  } else lapply(dn$meta$sessions, function(one) list(
    session = one, erase = FALSE, edge_rows = enc$session == one,
    raw_rows = enc$raw_event_session == one
  ))

  local <- lapply(scopes, function(scope) {
    before_vertices <- if (observed_before) {
      .one_sided_vertex_eligibility(
        activity, time, "before", scope$session, scope$erase
      )
    } else rep(FALSE, enc$n)
    after_vertices <- if (observed_after) {
      .one_sided_vertex_eligibility(
        activity, time, "after", scope$session, scope$erase
      )
    } else rep(FALSE, enc$n)
    eligible_before <- opportunities$key[
      before_vertices[opportunities$from] &
        before_vertices[opportunities$to]
    ]
    eligible_after <- opportunities$key[
      after_vertices[opportunities$from] &
        after_vertices[opportunities$to]
    ]
    two_sided <- intersect(eligible_before, eligible_after)
    persistent <- enc$observed_activity & !enc$instant &
      enc$from != enc$to & scope$edge_rows
    before_rows <- which(
      persistent & enc$start < time & time <= enc$end
    )
    after_rows <- which(
      persistent & enc$start <= time & time < enc$end
    )
    active_before <- intersect(unique(.relational_pair_key(
      enc$from[before_rows], enc$to[before_rows], enc$n, dn$directed
    )), two_sided)
    active_after <- intersect(unique(.relational_pair_key(
      enc$from[after_rows], enc$to[after_rows], enc$n, dn$directed
    )), two_sided)
    raw_rows <- which(
      scope$raw_rows & enc$raw_from != enc$raw_to &
        enc$raw_event_end > time & enc$raw_event_start == time &
        !enc$raw_event_onset_censored
    )
    onset_confirmation <- intersect(unique(.relational_pair_key(
      enc$raw_from[raw_rows], enc$raw_to[raw_rows], enc$n, dn$directed
    )), two_sided)
    raw_termini <- which(
      scope$raw_rows & enc$raw_from != enc$raw_to &
        enc$raw_event_start < time & enc$raw_event_end == time &
        !enc$raw_event_terminus_censored
    )
    terminus_confirmation <- intersect(unique(.relational_pair_key(
      enc$raw_from[raw_termini], enc$raw_to[raw_termini], enc$n, dn$directed
    )), two_sided)
    list(
      eligible_before = eligible_before, eligible_after = eligible_after,
      two_sided = two_sided, active_before = active_before,
      active_after = active_after, onset_confirmation = onset_confirmation,
      terminus_confirmation = terminus_confirmation
    )
  })
  combine <- function(field) as.integer(sort(unique(unlist(
    lapply(local, `[[`, field), use.names = FALSE
  ))))
  eligible_before <- combine("eligible_before")
  eligible_after <- combine("eligible_after")
  two_sided <- combine("two_sided")
  active_before <- combine("active_before")
  active_after <- combine("active_after")
  onset_confirmation <- combine("onset_confirmation")
  terminus_confirmation <- combine("terminus_confirmation")
  formation_risk <- as.integer(sort(setdiff(two_sided, active_before)))
  formations <- as.integer(sort(intersect(
    intersect(formation_risk, active_after), onset_confirmation
  )))
  dissolution_risk <- active_before
  dissolutions <- as.integer(sort(intersect(
    setdiff(dissolution_risk, active_after), terminus_confirmation
  )))
  list(
    eligible_before = eligible_before, eligible_after = eligible_after,
    two_sided = two_sided, active_before = active_before,
    active_after = active_after, formation_risk = formation_risk,
    formations = formations, onset_confirmation = onset_confirmation,
    terminus_confirmation = terminus_confirmation,
    dissolution_risk = dissolution_risk, dissolutions = dissolutions,
    counts = c(
      formation_risk = length(formation_risk), formations = length(formations)
    ),
    dissolution_counts = c(
      dissolution_risk = length(dissolution_risk),
      dissolutions = length(dissolutions)
    )
  )
}

#' Exact formation-rate numerator and inactive exposure for one window
#' @param dn Parent temporal network.
#' @param enc Encoded session block.
#' @param bin One positive-width reporting window.
#' @param sessions Session aggregation policy.
#' @param label Session label for a separate block.
#' @return Named numerator, inactive pair-time exposure, and rate values.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2),
#'             observation_start = 0, observation_end = 3)
#' Dynet:::.formation_rate_ledger(
#'   dn, Dynet:::.encode(dn),
#'   data.frame(lo = 0, hi = 1, closed = FALSE), "collapse"
#' )
#' @keywords internal
.formation_rate_ledger <- function(dn, enc, bin,
                                   sessions = c("bounded", "collapse", "separate"),
                                   label = "all") {
  sessions <- match.arg(sessions)
  edge_ledger <- .temporal_edge_ledger(
    dn, enc, bin, sessions = sessions, label = label, cohort = integer()
  )
  exposure <- edge_ledger[["risk"]] - edge_ledger[["occupied"]]
  lo <- bin$lo[[1L]]
  hi <- bin$hi[[1L]]
  raw <- which(enc$raw_from != enc$raw_to)
  within <- if (isTRUE(bin$closed[[1L]])) {
    enc$raw_event_start[raw] >= lo & enc$raw_event_start[raw] <= hi
  } else {
    enc$raw_event_start[raw] >= lo & enc$raw_event_start[raw] < hi
  }
  times <- sort(unique(enc$raw_event_start[raw[within]]))
  formations <- if (!length(times)) 0L else sum(vapply(times, function(time) {
    .transition_pair_ledger(dn, enc, time, sessions, label)$counts[["formations"]]
  }, integer(1L)))
  c(
    formations = as.numeric(formations),
    inactive_exposure = as.numeric(exposure),
    formation_rate = if (exposure > 0) formations / exposure else NA_real_
  )
}

#' Exact dissolution-rate numerator and active exposure for one window
#' @param dn Parent temporal network.
#' @param enc Encoded session block.
#' @param bin One positive-width reporting window.
#' @param sessions Session aggregation policy.
#' @param label Session label for a separate block.
#' @return Named numerator, active pair-time exposure, and rate values.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2),
#'             observation_start = 0, observation_end = 3)
#' Dynet:::.dissolution_rate_ledger(
#'   dn, Dynet:::.encode(dn),
#'   data.frame(lo = 0, hi = 2, closed = FALSE), "collapse"
#' )
#' @keywords internal
.dissolution_rate_ledger <- function(
    dn, enc, bin, sessions = c("bounded", "collapse", "separate"),
    label = "all") {
  sessions <- match.arg(sessions)
  edge_ledger <- .temporal_edge_ledger(
    dn, enc, bin, sessions = sessions, label = label, cohort = integer()
  )
  exposure <- edge_ledger[["occupied"]]
  lo <- bin$lo[[1L]]
  hi <- bin$hi[[1L]]
  raw <- which(enc$raw_from != enc$raw_to)
  within <- if (isTRUE(bin$closed[[1L]])) {
    enc$raw_event_end[raw] >= lo & enc$raw_event_end[raw] <= hi
  } else {
    enc$raw_event_end[raw] >= lo & enc$raw_event_end[raw] < hi
  }
  times <- sort(unique(enc$raw_event_end[raw[within]]))
  dissolutions <- if (!length(times)) 0L else sum(vapply(times, function(time) {
    .transition_pair_ledger(dn, enc, time, sessions, label)$dissolution_counts[["dissolutions"]]
  }, integer(1L)))
  c(
    dissolutions = as.numeric(dissolutions),
    active_exposure = as.numeric(exposure),
    dissolution_rate = if (exposure > 0) dissolutions / exposure else NA_real_
  )
}

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
#'   during the bin), `"new_pairs"` (vertex pairs meeting for the first time),
#'   and `"formation_fraction"` (confirmed binary pair formations divided by
#'   their exact two-sided inactive risk set), or `"dissolution_fraction"`
#'   (confirmed binary pair dissolutions divided by their exact two-sided
#'   active risk set), or `"formation_rate"` (confirmed formations divided by
#'   exact integrated inactive eligible pair-time), or `"dissolution_rate"`
#'   (confirmed dissolutions divided by exact integrated active eligible
#'   pair-time).
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end First and last time at which to measure. Default to the
#'   observed range. A network built from dates may be addressed with dates.
#' @param step How often to measure. Defaults to the interval the network was
#'   built with.
#' @param window How much time each measurement covers. Defaults to `step`,
#'   which tiles the period into disjoint bins. A larger value slides an
#'   overlapping window; `0` samples the network at each point in time.
#'   `"all"` measures the whole observed period as one window, closed on the
#'   right so an event at the final instant is inside it; it cannot be combined
#'   with `step`, and under `sessions = "separate"` or discontinuous
#'   observation it gives one window per session or observed component.
#'
#' @return A `dynet_metric` at graph level, one row per time point and
#'   measure.
#'
#' @details
#' Formation and dissolution are counted inside each window, so overlapping
#' windows (`window > step`) count the same event more than once by design --
#' that is what a rolling total is. Setting `window` equal to `step`, the
#' default, gives disjoint counts that sum to the total turnover.
#' Explicitly onset-censored raw limits are not formations, and explicitly
#' terminus-censored limits are not dissolutions. A left-censored observed tie
#' is prior evidence for `new_pairs`; raw censor state never changes activity.
#'
#' Formation fraction is defined only with `window = 0`. For a positive
#' half-open interval `[s,e)`, its pre-batch state at `t` is
#' `s < t <= e` and its post-batch state is `s <= t < e`. These predicates are
#' binary-unioned per nonloop ordered pair or undirected dyad after the entire
#' timestamp batch. Points are absent on both sides. A pair enters risk only
#' when observation and both endpoints are eligible immediately before and
#' after `t` and the pair is inactive before. A formation is confirmed when it
#' is active after and at least one contributing positive raw spell has a known
#' onset at `t`. The ratio is in `[0,1]`; zero risk returns `NA`.
#'
#' Duplicate, overlapping, or adjacent raw spells cannot multiply pair-state
#' transitions. Observation and vertex boundaries are excluded by two-sided
#' eligibility. Onset censoring suppresses confirmation but not state;
#' terminus censoring, weights, loops, and point contacts do not contribute.
#' Collapse erases labels, bounded authorizes within sessions before unioning
#' each calendar pair, and separate returns session-local fractions.
#'
#' Dissolution fraction is the dual exact-time quantity. For each nonloop pair,
#' let `E-` and `E+` be binary-union state on the symbolic one-sided limits and
#' let `L` mean at least one positive raw spell ends exactly at the timestamp
#' with a known terminus. The numerator is `Z * E- * (1 - E+) * L`, where `Z`
#' requires two-sided observation and endpoint eligibility; the denominator is
#' `sum(Z * E-)`, including pairs that remain active. Zero risk returns
#' `NA_real_`, while positive risk with no confirmed dissolution returns zero.
#' Censor flags do not change state: one known terminus confirms a disappearance
#' but an all-censored disappearance is unconfirmed. Duplicate, overlapping,
#' adjacent, and tied rows are unioned; points, loops, weights, onset censoring,
#' and administrative observation/activity boundaries do not create transitions.
#' Collapse erases labels, bounded unions authorized session-local states, and
#' separate reports local rows. Positive windows are rejected because T04 owns
#' dissolution rates.
#'
#' Dissolution rate is the active-risk dual over a positive window. Its
#' numerator sums confirmed T02 binary pair dissolutions at included timestamp
#' batches; its denominator integrates exact eligible active nonloop pair-time
#' over observation, vertex, edge, and window change cells. Right-censored
#' termini retain state and exposure but do not confirm an event, while one
#' known duplicate suffices. Zero active exposure returns `NA_real_`; positive
#' exposure without a confirmed dissolution is zero. The unit is inverse
#' network time. It is not raw terminus intensity, spell-duration sum, or an
#' average of instantaneous fractions; positive windows are required and T04
#' owns this rate.
#'
#' Formation rate is the positive-window counterpart. Its numerator sums the
#' confirmed T01 binary pair formations at each included timestamp, while its
#' denominator integrates exact inactive eligible nonloop pair-time over
#' change-point cells cut by the window, observation components, vertex
#' activity, and edge state. It is not an average of instantaneous fractions,
#' a raw-onset intensity, or an ever-observed-pair quantity. Zero exposure
#' returns `NA_real_`; positive exposure with no confirmed formation returns
#' zero. The unit is inverse network time and scales inversely with positive
#' time scaling. Points have zero exposure, onset censoring suppresses only
#' confirmation, and gap/boundary, duplicate, overlap, adjacency, loop,
#' weight, and session rules follow the exact T01 ledger. `window = 0` is
#' rejected because T01 owns instant fractions.
#'
#' @references
#' Andersen, P. K., & Gill, R. D. (1982). Cox's regression model for counting
#' processes: a large sample study. *Annals of Statistics*, 10, 1100-1120.
#' \doi{10.1214/aos/1176345976}
#'
#' Butts, C. T., Leslie-Cook, A., Krivitsky, P. N., & Bender-deMoll, S.
#' (2024). *networkDynamic: Dynamic Extensions for Network Objects*, version
#' 0.11.5. \doi{10.32614/CRAN.package.networkDynamic}
#'
#' @examples
#' dn <- dynet(school_contacts)
#' events(dn)
#' plot(events(dn, measure = c("formation", "dissolution")))
#' events(dn, measure = "formation_fraction", start = 1, end = 1,
#'            window = 0)
#' events(dn, measure = "dissolution_fraction", start = 1, end = 1,
#'            window = 0)
#' events(dn, measure = "formation_rate", start = 1, end = 2,
#'            window = 1)
#' events(dn, measure = "dissolution_rate", start = 1, end = 2,
#'            window = 1)
#'
#' @export
events <- function(dn,
                       measure = c("formation", "dissolution"),
                       sessions = c("bounded", "collapse", "separate"),
                       start = NULL, end = NULL,
                       step = NULL, window = NULL) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  spec <- .window_spec(dn, start, end, step, window)
  allowed <- c(
    "formation", "dissolution", "active", "new_pairs",
    "formation_fraction", "dissolution_fraction", "formation_rate",
    "dissolution_rate"
  )
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }
  has_fraction <- any(c("formation_fraction", "dissolution_fraction") %in% measure)
  has_formation_rate <- "formation_rate" %in% measure
  has_dissolution_rate <- "dissolution_rate" %in% measure
  has_rate <- has_formation_rate || has_dissolution_rate
  has_transition <- has_fraction || has_rate
  if (has_fraction && has_rate) {
    stop(errorCondition(
      "transition fractions and rates cannot be requested in one window",
      class = c("dynet_incompatible_transition_windows", "dynet_bad_input"),
      call = NULL
    ))
  }
  if (has_fraction && spec$window > 0) {
    stop(errorCondition(
      paste0(
        "transition fractions require `window = 0`; positive windows need ",
        "the formation/dissolution rates defined by T03/T04."
      ),
      class = c("dynet_transition_requires_instant", "dynet_bad_input"),
      call = NULL
    ))
  }
  if (has_rate && spec$window <= 0) {
    stop(errorCondition(
      "transition rates require a positive `window`; use the corresponding fraction at an instant",
      class = c("dynet_rate_requires_positive_window", "dynet_bad_input"),
      call = NULL
    ))
  }

  df <- .over_bins(dn, sessions, node_level = FALSE, spec = spec,
    fun = function(enc, act, bin) {
      lo <- bin$lo; hi <- bin$hi
      pair <- paste(enc$raw_from, enc$raw_to, sep = "\r")
      evidence <- .raw_observation_evidence(enc, dn)
      pair_first <- stats::ave(evidence, pair, FUN = min)
      censored_evidence <- ifelse(
        enc$raw_event_onset_censored, evidence, Inf
      )
      pair_censored_first <- stats::ave(censored_evidence, pair, FUN = min)
      candidate <- which(
        .time_in_observation(dn, enc$raw_event_start) &
          !enc$raw_event_onset_censored &
          enc$raw_event_start == evidence & evidence == pair_first &
          enc$raw_event_start < pair_censored_first
      )
      candidate <- candidate[order(
        enc$raw_event_start[candidate], enc$raw_event_end[candidate],
        pair[candidate], enc$raw_event_spell[candidate]
      )]
      first_seen <- rep(FALSE, length(pair))
      first_seen[candidate[!duplicated(pair[candidate])]] <- TRUE
      # The final window of a defaulted grid is closed on the right, exactly as
      # it is for edge activity; without this a spell beginning on the last
      # observed instant would be counted by metrics() and lost here.
      within <- function(t) {
        if (spec$window == 0) return(t == lo)
        if (isTRUE(bin$closed)) t >= lo & t <= hi else t >= lo & t < hi
      }
      observed_event <- function(t) {
        .time_in_observation(dn, t)
      }
      transition <- if (has_fraction) {
        label <- if (identical(sessions, "separate")) {
          as.character(enc$raw_event_session[[1L]])
        } else "all"
        .transition_pair_ledger(dn, enc, lo, sessions, label)
      } else NULL
      rate <- if (has_rate) {
        label <- if (identical(sessions, "separate")) {
          as.character(enc$raw_event_session[[1L]])
        } else "all"
        list(
          formation = if (has_formation_rate) {
            .formation_rate_ledger(dn, enc, bin, sessions, label)
          },
          dissolution = if (has_dissolution_rate) {
            .dissolution_rate_ledger(dn, enc, bin, sessions, label)
          }
        )
      } else NULL
      vals <- vapply(measure, function(m) switch(m,
        formation   = sum(!enc$raw_event_onset_censored &
                            observed_event(enc$raw_event_start) &
                            within(enc$raw_event_start)),
        dissolution = sum(!enc$raw_event_terminus_censored &
                            observed_event(enc$raw_event_end) &
                            within(enc$raw_event_end)),
        active      = sum(act),
        new_pairs   = sum(first_seen &
                            within(enc$raw_event_start)),
        formation_fraction = if (
          transition$counts[["formation_risk"]] == 0L
        ) NA_real_ else transition$counts[["formations"]] /
          transition$counts[["formation_risk"]],
        dissolution_fraction = if (
          transition$dissolution_counts[["dissolution_risk"]] == 0L
        ) NA_real_ else transition$dissolution_counts[["dissolutions"]] /
          transition$dissolution_counts[["dissolution_risk"]],
        formation_rate = rate$formation[["formation_rate"]],
        dissolution_rate = rate$dissolution[["dissolution_rate"]]
      ), numeric(1L))
      vals
    })

  out <- .metric(df, level = "graph",
          what = if (length(measure) == 1L) .event_label(measure) else "Edge dynamics",
          dn = dn, spec = spec)
  attr(out, "raw_censoring") <- "known_endpoints_only"
  attr(out, "measure_scope") <- stats::setNames(
    ifelse(measure %in% c("formation_fraction", "dissolution_fraction"),
           "binary_pair_transition_at_time",
           if (spec$window == 0) "raw_event_at_time" else "raw_event_window"),
    measure
  )
  identities <- c(
    formation = "uncensored_raw_spell_start",
    dissolution = "uncensored_raw_spell_terminus",
    active = "observed_spell_activity",
    new_pairs = "first_observed_pair",
    formation_fraction = "binary_pair_union_transition",
    dissolution_fraction = "binary_pair_union_transition",
           formation_rate = "binary_pair_union_transition",
           dissolution_rate = "binary_pair_union_transition"
  )[measure]
  attr(out, "event_identity") <- if (length(measure) == 1L) {
    unname(identities)
  } else stats::setNames(unname(identities), measure)
  if (has_transition) {
    transition_measures <- intersect(
      measure, c("formation_fraction", "dissolution_fraction",
                 "formation_rate", "dissolution_rate")
    )
    transition_values <- c(
      formation_fraction = "inactive_to_active",
      dissolution_fraction = "active_to_inactive",
      formation_rate = "inactive_to_active",
      dissolution_rate = "active_to_inactive"
    )[transition_measures]
    risk_values <- c(
      formation_fraction = "two_sided_eligible_inactive_prestate_nonloop_pairs",
      dissolution_fraction = "two_sided_eligible_active_prestate_nonloop_pairs",
      formation_rate = "integrated_eligible_inactive_nonloop_pair_time",
      dissolution_rate = "integrated_eligible_active_nonloop_pair_time"
    )[transition_measures]
    confirmation_values <- c(
      formation_fraction = "at_least_one_uncensored_positive_raw_onset",
      dissolution_fraction = "at_least_one_uncensored_positive_raw_terminus",
      formation_rate = "at_least_one_uncensored_positive_raw_onset",
      dissolution_rate = "at_least_one_uncensored_positive_raw_terminus"
    )[transition_measures]
    scalar_transition <- length(transition_measures) == 1L
    named_rate_metadata <- has_rate && length(measure) > 1L
    attr(out, "transition") <- if (scalar_transition && !named_rate_metadata) {
      unname(transition_values)
    } else transition_values
    attr(out, "risk_set") <- if (scalar_transition && !named_rate_metadata) {
      unname(risk_values)
    } else risk_values
    attr(out, "batching") <- "all_boundaries_at_timestamp"
    attr(out, "interval_state") <- "half_open_one_sided_limits"
    attr(out, "confirmation") <- if (scalar_transition && !named_rate_metadata) {
      unname(confirmation_values)
    } else confirmation_values
    attr(out, "points") <- "impulses_excluded"
    attr(out, "weights") <- "ignored"
    attr(out, "window_rule") <- if (has_rate) {
      "positive_window_only"
    } else "exact_time_only"
    attr(out, "transition_grid") <-
      "requested_exact_times_not_auto_change_points"
    attr(out, "opportunity_domain") <- if (dn$directed) {
      "eligible_nonloop_ordered_pairs"
    } else "eligible_nonloop_unordered_dyads"
    attr(out, "transition_unit") <- if (has_rate) {
      unit <- paste0("per_", dn$meta$time_unit)
      if (named_rate_metadata) stats::setNames(
        rep(unit, length(transition_measures)),
        transition_measures
      ) else unit
    } else "probability"
    if (has_rate) {
      numerator_values <- c(
        formation_rate = "confirmed_pair_formations_in_window",
        dissolution_rate = "confirmed_pair_dissolutions_in_window"
      )[intersect(measure, c("formation_rate", "dissolution_rate"))]
      denominator_values <- c(
        formation_rate = "integrated_eligible_inactive_nonloop_pair_time",
        dissolution_rate = "integrated_eligible_active_nonloop_pair_time"
      )[intersect(measure, c("formation_rate", "dissolution_rate"))]
      attr(out, "transition_numerator") <- if (named_rate_metadata) {
        numerator_values
      } else unname(numerator_values)
      attr(out, "risk_clock") <- "positive_observed_time"
      attr(out, "risk_integration") <- "exact_change_point"
      attr(out, "transition_denominator") <- if (named_rate_metadata) {
        denominator_values
      } else unname(denominator_values)
      rate_names <- intersect(measure, c("formation_rate", "dissolution_rate"))
      attr(out, "measure_scope")[rate_names] <- "whole_window_exact"
    }
    effective_sessions <- if (identical(sessions, "bounded") &&
                              is.null(dn$meta$sessions)) "collapse" else sessions
    attr(out, "transition_session_aggregation") <- switch(
      effective_sessions, collapse = "labels_erased_calendar_union",
      bounded = "session_local_then_calendar_union",
      separate = "session_local"
    )
  }
  out
}

#' Earliest observed evidence contributed by each raw spell
#' @param enc Encoded measurement view.
#' @param dn Parent network.
#' @return One time per raw spell, or `Inf` when wholly unobserved.
#' @keywords internal
.raw_observation_evidence <- function(enc, dn) {
  evidence <- rep(Inf, length(enc$raw_event_spell))
  starts <- .time_in_observation(dn, enc$raw_event_start)
  ends <- .time_in_observation(dn, enc$raw_event_end)
  evidence[starts] <- enc$raw_event_start[starts]
  evidence[ends] <- pmin(evidence[ends], enc$raw_event_end[ends])
  if (length(enc$raw_spell)) {
    fragment_start <- tapply(enc$start, enc$raw_spell, min)
    raw_index <- match(as.integer(names(fragment_start)), enc$raw_event_spell)
    evidence[raw_index] <- pmin(evidence[raw_index], unname(fragment_start))
  }
  evidence
}

#' Human-readable label for an event measure
#' @param m Measure name.
#' @return A single character string.
#' @examples
#' Dynet:::.event_label("formation_fraction")
#' @keywords internal
.event_label <- function(m) {
  unname(c(formation = "Edges formed", dissolution = "Edges dissolved",
           active = "Active edges", new_pairs = "First-time pairs",
           formation_fraction = "Formation transition fraction",
           dissolution_fraction = "Dissolution transition fraction",
           formation_rate = "Formation transition rate",
           dissolution_rate = "Dissolution transition rate")[m] %||% m)
}


# ===========================================================================
# durations()
# ===========================================================================

#' Endpoint-valid fragments for duration subjects
#' @param dn Parent network.
#' @param enc Session-scoped or collapsed edge encoding.
#' @param session Effective activity-session label.
#' @param erase_sessions Whether vertex labels are calendar-unioned.
#' @param censored Raw censor policy.
#' @return Fragment table retaining raw-spell identity.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' enc <- Dynet:::.encode(dn)
#' Dynet:::.duration_fragments(dn, enc, erase_sessions = TRUE)
#' @keywords internal
.duration_fragments <- function(dn, enc, session = NULL,
                                erase_sessions = FALSE,
                                censored = c("include", "exclude")) {
  censored <- match.arg(censored)
  enc <- .prepare_path_encoding(
    dn, enc, session = session, erase_sessions = erase_sessions
  )
  rows <- which(enc$observed_activity)
  if (identical(censored, "exclude")) rows <- rows[
    !enc$onset_censored[rows] & !enc$terminus_censored[rows]
  ]
  empty <- data.frame(
    from = character(), to = character(), raw_spell = integer(),
    start = numeric(), end = numeric(), instant = logical(),
    stringsAsFactors = FALSE
  )
  pieces <- lapply(rows, function(row) {
    from <- enc$from[[row]]
    to <- enc$to[[row]]
    common <- data.frame(
      from = enc$names[[from]], to = enc$names[[to]],
      raw_spell = enc$raw_spell[[row]], stringsAsFactors = FALSE
    )
    if (enc$instant[[row]]) {
      time <- enc$start[[row]]
      if (!.path_vertex_active(enc$path_activity, from, time) ||
          !.path_vertex_active(enc$path_activity, to, time)) return(empty)
      return(data.frame(common, start = time, end = time, instant = TRUE))
    }
    tail <- .path_vertex_components(enc$path_activity, from)
    head <- .path_vertex_components(enc$path_activity, to)
    if (!nrow(tail) || !nrow(head)) return(empty)
    cross <- merge(tail, head, by = NULL, suffixes = c("_tail", "_head"))
    start <- pmax(enc$start[[row]], cross$start_tail, cross$start_head)
    end <- pmin(enc$end[[row]], cross$end_tail, cross$end_head)
    keep <- end > start
    if (!any(keep)) return(empty)
    data.frame(
      from = rep(common$from, sum(keep)), to = rep(common$to, sum(keep)),
      raw_spell = rep(common$raw_spell, sum(keep)), start = start[keep],
      end = end[keep], instant = FALSE, stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, pieces)
  if (is.null(out) || !nrow(out)) return(empty)
  rownames(out) <- NULL
  out
}

#' Build duration fragments under one session policy
#' @param dn Parent network.
#' @param sessions Session policy.
#' @param censored Raw censor policy.
#' @return Named list of fragment tables; bounded/collapse have one block.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.duration_fragment_blocks(dn, "bounded", "include")
#' @keywords internal
.duration_fragment_blocks <- function(dn, sessions, censored) {
  enc <- .encode(dn)
  if (identical(sessions, "collapse") || is.null(dn$meta$sessions)) {
    return(list(all = .duration_fragments(
      dn, enc, erase_sessions = TRUE, censored = censored
    )))
  }
  local <- lapply(dn$meta$sessions, function(label) {
    rows <- which(enc$session == label)
    sub <- .subset_path_encoding(enc, rows)
    .duration_fragments(
      dn, sub, session = label, erase_sessions = FALSE, censored = censored
    )
  })
  names(local) <- dn$meta$sessions
  if (identical(sessions, "separate")) return(local)
  list(all = do.call(rbind, local))
}

#' Observed canonical vertex-activity fragments for duration measurement
#' @param dn Parent network.
#' @param censored Canonical vertex-component censor policy.
#' @param session Optional session label for a local activity view.
#' @param erase_sessions Whether all activity labels are calendar-pooled.
#' @return A typed fragment table with canonical or implicit identity.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2),
#'             vertex_spells = data.frame(node = "A", start = 0, end = 1))
#' Dynet:::.vertex_duration_fragments(dn, "include")
#' @keywords internal
.vertex_duration_fragments <- function(dn, censored = c("include", "exclude"),
                                       session = NULL,
                                       erase_sessions = TRUE) {
  censored <- match.arg(censored)
  spells <- dn$vertex_spells %||% .empty_vertex_spells()
  fragments <- .observed_vertex_fragments(dn)
  if (!erase_sessions && !is.null(session) && nrow(fragments)) {
    fragments <- fragments[
      is.na(fragments$session) | fragments$session == session, , drop = FALSE
    ]
  }
  if (identical(censored, "exclude") && nrow(fragments)) {
    retained <- spells$vertex_spell[
      !spells$onset_censored & !spells$terminus_censored
    ]
    fragments <- fragments[
      fragments$vertex_spell %in% retained, , drop = FALSE
    ]
  }
  explicit <- data.frame(
    node = fragments$node, vertex_spell = fragments$vertex_spell,
    activity_identity = fragments$vertex_spell,
    start = fragments$start, end = fragments$end,
    instant = fragments$instant, implicit = rep(FALSE, nrow(fragments)),
    session = fragments$session, stringsAsFactors = FALSE
  )

  declared <- unique(spells$node)
  implicit_nodes <- setdiff(dn$nodes$name, declared)
  observations <- .observation_table(dn)
  if (is.null(observations)) {
    bounds <- dn$meta$time_range
    observations <- data.frame(
      start = bounds[["start"]], end = bounds[["end"]],
      instant = bounds[["start"]] == bounds[["end"]]
    )
  }
  implicit <- data.frame(
    node = character(), vertex_spell = integer(),
    activity_identity = integer(), start = numeric(), end = numeric(),
    instant = logical(), implicit = logical(), session = character(),
    stringsAsFactors = FALSE
  )
  if (length(implicit_nodes) && nrow(observations)) {
    index <- expand.grid(
      node_index = seq_along(implicit_nodes),
      observation_index = seq_len(nrow(observations))
    )
    implicit <- data.frame(
      node = implicit_nodes[index$node_index], vertex_spell = NA_integer_,
      activity_identity = nrow(spells) + match(
        implicit_nodes[index$node_index], dn$nodes$name
      ),
      start = observations$start[index$observation_index],
      end = observations$end[index$observation_index],
      instant = observations$start[index$observation_index] ==
        observations$end[index$observation_index],
      implicit = TRUE, session = NA_character_, stringsAsFactors = FALSE
    )
  }
  out <- rbind(explicit, implicit)
  if (!nrow(out)) return(implicit)
  out <- out[order(out$node, out$activity_identity, out$start, out$end), ]
  rownames(out) <- NULL
  out
}

#' Build vertex-duration fragments under one session policy
#' @param dn Parent network.
#' @param sessions Session policy.
#' @param censored Canonical vertex-component censor policy.
#' @return Named list of local or pooled vertex-activity fragment tables.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.vertex_duration_blocks(dn, "bounded", "include")
#' @keywords internal
.vertex_duration_blocks <- function(dn, sessions, censored) {
  if (identical(sessions, "collapse") || is.null(dn$meta$sessions)) {
    return(list(all = .vertex_duration_fragments(
      dn, censored, erase_sessions = TRUE
    )))
  }
  local <- lapply(dn$meta$sessions, function(label) {
    .vertex_duration_fragments(
      dn, censored, session = label, erase_sessions = FALSE
    )
  })
  names(local) <- dn$meta$sessions
  if (identical(sessions, "separate")) return(local)
  pooled <- do.call(rbind, local)
  pooled$session <- NA_character_
  pooled <- unique(pooled)
  rownames(pooled) <- NULL
  list(all = pooled)
}

#' Expand retained edge fragments into node-incidence fragments
#' @param fragments Endpoint-valid raw edge fragments from D01.
#' @param nodes Fixed vertex names.
#' @param directed Whether endpoint orientation is directed.
#' @param mode Requested directed incidence mode.
#' @return A fragment table with node and endpoint-stub identity.
#' @examples
#' fragments <- data.frame(from = "A", to = "B", raw_spell = 1L,
#'                         start = 0, end = 2, instant = FALSE)
#' Dynet:::.node_tie_fragments(fragments, c("A", "B"), TRUE, "all")
#' @keywords internal
.node_tie_fragments <- function(fragments, nodes, directed,
                                mode = c("out", "in", "all")) {
  mode <- match.arg(mode)
  empty <- data.frame(
    node = character(), raw_spell = integer(), stub = character(),
    start = numeric(), end = numeric(), instant = logical(),
    stringsAsFactors = FALSE
  )
  if (!nrow(fragments)) return(empty)
  effective <- if (directed) mode else "all"
  make_stub <- function(endpoint, stub) data.frame(
    node = fragments[[endpoint]], raw_spell = fragments$raw_spell,
    stub = stub, start = fragments$start, end = fragments$end,
    instant = fragments$instant, stringsAsFactors = FALSE
  )
  out <- if (identical(effective, "out")) {
    make_stub("from", "out")
  } else if (identical(effective, "in")) {
    make_stub("to", "in")
  } else rbind(make_stub("from", "out"), make_stub("to", "in"))
  out <- out[out$node %in% nodes, , drop = FALSE]
  out <- out[order(out$node, out$raw_spell, out$stub, out$start, out$end), ]
  rownames(out) <- NULL
  out
}

#' How long each relationship lasted
#'
#' @description
#' Pair unit returns one row per vertex pair and measure, summarising every
#' retained raw spell they shared. Spell unit returns each retained raw edge
#' identity. Vertex-activity unit returns fixed-universe vertex summaries;
#' vertex-spell unit returns canonical V01 activity components. Duration is
#' what separates an interval network from a contact network: a pair that met
#' fifty times briefly and a pair that met once at length have the same edge
#' weight in a static network and nothing else in common.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure For pair unit, one or more of `"events"` (number of spells),
#'   `"total"` (summed duration), `"union"` (binary pair occupancy), `"mean"`,
#'   `"median"`, `"first"`, and `"last"`. For spell unit, one or more of
#'   `"duration"`, `"first"`, and `"last"`; its default is `"duration"`.
#'   Vertex-activity unit allows the pair-like measures and defaults to
#'   `"events"`, `"total"`, and `"union"`; vertex-spell unit allows the same
#'   measures as edge spell and defaults to `"duration"`.
#'   Node-ties unit allows `"events"` (incident raw-spell endpoint stubs),
#'   `"total"` (their summed endpoint-valid duration), and `"union"` (binary
#'   incident calendar exposure), defaulting to events and total.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param censored Whether to `"include"` known follow-up or `"exclude"` an
#'   entire edge raw spell or canonical vertex component with either explicit
#'   outer censor flag. Administrative observation cuts never cause exclusion.
#' @param unit `"pair"` retains the existing pair summary and adds union
#'   duration; `"spell"` returns one row per retained raw edge-spell identity;
#'   `"vertex_activity"` returns fixed-node aggregates; `"vertex_spell"`
#'   returns retained canonical V01 activity identities; `"node_ties"` returns
#'   fixed-node incident-tie quantities.
#' @param mode For `unit = "node_ties"`, `"out"`, `"in"`, or `"all"` endpoint
#'   incidence. Undirected networks normalize every request to `"all"`. An
#'   explicitly supplied mode is invalid for every other duration unit.
#'
#' @return A `dynet_metric`. Pair and edge-spell units are edge-level: pair has
#'   columns `from`, `to`, `measure`, and `value`, while spell additionally has
#'   `raw_spell`.
#'   Administrative observation and endpoint-activity fragments are recombined
#'   by raw spell before the `censored` policy is applied. Vertex-activity unit
#'   has `node`, `measure`, and `value`; vertex-spell additionally has
#'   `vertex_spell` and `implicit`; both vertex units are node-level metrics.
#'   Node-ties is also node-level and has the fixed schema `node`, `measure`,
#'   and `value` (plus `session` only for separate mode).
#'
#' @details
#' Positive spell duration is the observed time during which both endpoints
#' are eligible. Genuine eligible point contacts are retained with duration
#' zero. Pair `total` sums these raw-spell durations, so overlapping identities
#' intentionally multiply time; pair `union` counts binary calendar occupancy
#' once. Consequently `union <= total`, and union cannot exceed the pair's V04
#' eligible opportunity time. Pair `events` counts retained raw identities.
#' Formally, if retained raw spell `i` has endpoint-valid fragments
#' `F[i]`, then `duration[i] = sum((b - a) for [a,b) in F[i])`.
#' For pair `p`, `total[p] = sum(duration[i])`, while
#' `union[p]` is the Lebesgue measure of the calendar union of every positive
#' fragment belonging to `p`. Point contacts therefore count as events and
#' spells but contribute zero duration. These conventions follow the spell and
#' dyad distinction in `tsna::edgeDuration()` (Butts, 2024,
#' doi:10.32614/CRAN.package.tsna), with Dynet additionally applying its
#' observation and endpoint-eligibility contract.
#'
#' Collapse erases edge and vertex session labels before gating. Bounded gates
#' within each session and then pools spell identities while unioning overlapping
#' pair occupancy once on the shared calendar. Separate returns local blocks.
#' Weights and vertex censor flags do not affect durations. Excluding raw edge
#' censoring removes the whole identity, never only an observed fragment.
#'
#' For a retained canonical vertex component `k`, let `S[k]` be its observed
#' support, `d[k]` its total positive width, and `f[k]` and `l[k]` its extrema.
#' Vertex `total` is `sum(d[k])`, while `union` is the measure of the calendar
#' union of every positive `S[k]`; therefore `0 <= union <= total`. Points count
#' as identities with zero duration. A declared vertex with no retained support
#' has zero events/total/union and missing mean/median/first/last. A wholly
#' undeclared vertex has one measurement-only implicit always-active identity
#' over observed support. This is stream-graph node presence duration as in
#' Latapy, Viard, and Magnien (2018), doi:10.1007/s13278-018-0537-7, and agrees
#' with `tsna::vertexDuration()` only under matching continuous-observation,
#' non-session conventions.
#'
#' Node-ties uses the same endpoint-valid raw spell supports as pair/spell
#' duration. Directed out credits the tail, in credits the head, and all adds
#' both endpoint stubs. A retained loop therefore contributes once to out,
#' once to in, and twice to additive all-mode events/total; undirected results
#' use the same two-stub rule. In contrast, node-tie `union` Boolean-unions all
#' positive incident fragments, so loops, reciprocal overlap, duplicate rows,
#' and simultaneous neighbors occupy calendar time only once. Consequently
#' `union <= total`, and directed all equals out plus in only for events and
#' total. Formally, for endpoint-stub multiplicity `c[v,i,m]`, retained raw
#' identity duration `d[i]`, and positive support `F[i]`, node-tie events are
#' `sum(c[v,i,m])`, total is `sum(c[v,i,m] * d[i])`, and union is the measure
#' of the calendar union of all `F[i]` having positive multiplicity. These
#' union values cannot exceed the corresponding D02 eligible vertex-activity
#' union. Isolates, inactive vertices, and loopless singletons receive exact
#' zeros for every node-tie measure. The additive quantities match
#' `tsna::tiedDuration()` only for continuous observation, static eligible
#' endpoints, uncensored matched spells, and no sessions; `tsna` is not an
#' oracle for union, gaps/points, endpoint schedules, source censor filtering,
#' or session policies (Bender-deMoll and Morris, 2025,
#' doi:10.32614/CRAN.package.tsna).
#'
#' @examples
#' dn <- dynet(school_contacts)
#' durations(dn)
#' durations(dn, measure = "union")
#' durations(dn, unit = "spell", measure = "duration")
#' durations(dn, unit = "vertex_activity")
#' durations(dn, unit = "vertex_spell")
#' durations(dn, unit = "node_ties", mode = "all")
#' summary(durations(dn), by = "measure")
#'
#' @export
durations <- function(dn, measure = c("events", "total", "mean"),
                          sessions = c("bounded", "collapse", "separate"),
                          censored = c("include", "exclude"),
                          unit = c("pair", "spell", "vertex_activity",
                                   "vertex_spell", "node_ties"),
                          mode = c("out", "in", "all")) {
  mode_supplied <- !missing(mode)
  sessions <- match.arg(sessions)
  censored <- match.arg(censored)
  unit <- match.arg(unit)
  mode <- match.arg(mode)
  .check_dynet(dn, sessions)
  if (mode_supplied && !identical(unit, "node_ties")) {
    stop(errorCondition(
      "`mode` applies only when `unit = \"node_ties\"`.",
      class = c("dynet_incompatible_duration_mode", "dynet_bad_input"),
      call = NULL
    ))
  }
  if (missing(measure) && unit %in% c("spell", "vertex_spell")) {
    measure <- "duration"
  } else if (missing(measure) && identical(unit, "vertex_activity")) {
    measure <- c("events", "total", "union")
  } else if (missing(measure) && identical(unit, "node_ties")) {
    measure <- c("events", "total")
  }
  allowed <- if (unit %in% c("pair", "vertex_activity")) {
    c("events", "total", "union", "mean", "median", "first", "last")
  } else if (identical(unit, "node_ties")) {
    c("events", "total", "union")
  } else {
    c("duration", "first", "last")
  }
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }

  if (identical(unit, "node_ties")) {
    effective_mode <- if (dn$directed) mode else "all"
    blocks <- .duration_fragment_blocks(dn, sessions, censored)
    frames <- Map(function(fragments, label) {
      incidence <- .node_tie_fragments(
        fragments, dn$nodes$name, dn$directed, effective_mode
      )
      key <- paste(incidence$node, incidence$raw_spell,
                   incidence$stub, sep = "\r")
      groups <- split(seq_len(nrow(incidence)), key)
      identity <- if (length(groups)) do.call(rbind, lapply(
        groups, function(i) data.frame(
          node = incidence$node[i[1L]], raw_spell = incidence$raw_spell[i[1L]],
          stub = incidence$stub[i[1L]],
          duration = sum(incidence$end[i] - incidence$start[i]),
          stringsAsFactors = FALSE
        )
      )) else data.frame(
        node = character(), raw_spell = integer(), stub = character(),
        duration = numeric(), stringsAsFactors = FALSE
      )
      node_stats <- lapply(dn$nodes$name, function(node) {
        i <- which(identity$node == node)
        occupied <- incidence[
          incidence$node == node & !incidence$instant, , drop = FALSE
        ]
        c(
          events = length(i), total = sum(identity$duration[i]),
          union = if (nrow(occupied)) .union_duration(
            occupied$start, occupied$end
          ) else 0
        )
      })
      names(node_stats) <- dn$nodes$name
      do.call(rbind, lapply(measure, function(m) data.frame(
        session = label, node = dn$nodes$name, measure = m,
        value = vapply(node_stats, `[[`, numeric(1L), m),
        stringsAsFactors = FALSE
      )))
    }, blocks, names(blocks))
    out <- do.call(rbind, frames)
    out <- out[order(out$measure, out$node), , drop = FALSE]
    if (!identical(sessions, "separate")) out$session <- NULL
    result <- .metric(
      out, level = "node", what = "Incident tie duration", dn = dn,
      note = sprintf("durations in %s", dn$meta$time_unit), mode = effective_mode
    )
    attr(result, "duration_unit") <- unit
    attr(result, "duration_quantity") <- unique(as.character(measure))
    attr(result, "requested_mode") <- mode
    attr(result, "incidence") <- "raw_spell_endpoint_occurrence"
    attr(result, "loop_contribution") <- "one_out_plus_one_in"
    attr(result, "occupancy") <- "binary_incident_calendar_union"
    attr(result, "weights") <- "ignored"
    attr(result, "vertex_rule") <- "both_endpoints_eligible_at_time"
    attr(result, "observation_rule") <- "positive_support_plus_genuine_points"
    attr(result, "raw_censoring") <- if (identical(censored, "include")) {
      "included"
    } else "excluded"
    effective_sessions <- if (identical(sessions, "bounded") &&
                              is.null(dn$meta$sessions)) "collapse" else sessions
    attr(result, "session_aggregation") <- switch(
      effective_sessions, collapse = "labels_erased",
      bounded = "session_local_then_union", separate = "session_local"
    )
    return(result)
  }

  if (unit %in% c("vertex_activity", "vertex_spell")) {
    blocks <- .vertex_duration_blocks(dn, sessions, censored)
    frames <- Map(function(fragments, label) {
      identity_groups <- split(
        seq_len(nrow(fragments)), fragments$activity_identity
      )
      identity_stats <- if (length(identity_groups)) do.call(rbind, lapply(
        identity_groups, function(i) data.frame(
          node = fragments$node[i[1L]],
          vertex_spell = fragments$vertex_spell[i[1L]],
          implicit = fragments$implicit[i[1L]],
          duration = sum(fragments$end[i] - fragments$start[i]),
          first = min(fragments$start[i]), last = max(fragments$end[i]),
          stringsAsFactors = FALSE
        )
      )) else data.frame(
        node = character(), vertex_spell = integer(), implicit = logical(),
        duration = numeric(), first = numeric(), last = numeric(),
        stringsAsFactors = FALSE
      )
      if (identical(unit, "vertex_spell")) {
        if (!nrow(identity_stats)) return(data.frame(
          session = character(), node = character(), vertex_spell = integer(),
          implicit = logical(), measure = character(), value = numeric(),
          stringsAsFactors = FALSE
        ))
        return(do.call(rbind, lapply(measure, function(m) data.frame(
          session = label, node = identity_stats$node,
          vertex_spell = identity_stats$vertex_spell,
          implicit = identity_stats$implicit, measure = m,
          value = identity_stats[[m]], stringsAsFactors = FALSE
        ))))
      }
      node_stats <- lapply(dn$nodes$name, function(node) {
        i <- which(identity_stats$node == node)
        pieces <- fragments[
          fragments$node == node & !fragments$instant, , drop = FALSE
        ]
        if (!length(i)) return(c(
          events = 0, total = 0, union = 0, mean = NA_real_,
          median = NA_real_, first = NA_real_, last = NA_real_
        ))
        c(
          events = length(i), total = sum(identity_stats$duration[i]),
          union = if (nrow(pieces)) {
            .union_duration(pieces$start, pieces$end)
          } else 0,
          mean = mean(identity_stats$duration[i]),
          median = stats::median(identity_stats$duration[i]),
          first = min(identity_stats$first[i]), last = max(identity_stats$last[i])
        )
      })
      names(node_stats) <- dn$nodes$name
      do.call(rbind, lapply(measure, function(m) data.frame(
        session = label, node = dn$nodes$name, measure = m,
        value = vapply(node_stats, `[[`, numeric(1L), m),
        stringsAsFactors = FALSE
      )))
    }, blocks, names(blocks))
    out <- do.call(rbind, frames)
    spell_order <- if ("vertex_spell" %in% names(out)) {
      out$vertex_spell
    } else rep(NA_integer_, nrow(out))
    out <- out[order(out$measure, out$node, spell_order), , drop = FALSE]
    if (!identical(sessions, "separate")) out$session <- NULL
    result <- .metric(
      out, level = "node", what = "Vertex activity duration", dn = dn,
      note = sprintf("durations in %s", dn$meta$time_unit)
    )
    attr(result, "duration_unit") <- unit
    attr(result, "duration_quantity") <- unique(as.character(measure))
    attr(result, "activity_identity") <-
      "canonical_v01_component_plus_implicit_static"
    attr(result, "activity_aggregation") <- "spell_sum_and_vertex_union"
    attr(result, "observation_rule") <- "positive_support_plus_genuine_points"
    attr(result, "vertex_censoring") <- if (identical(censored, "include")) {
      "included"
    } else "excluded"
    attr(result, "directedness") <- "irrelevant"
    effective_sessions <- if (identical(sessions, "bounded") &&
                              is.null(dn$meta$sessions)) "collapse" else sessions
    attr(result, "session_aggregation") <- switch(
      effective_sessions, collapse = "labels_erased",
      bounded = "session_local_then_union", separate = "session_local"
    )
    return(result)
  }

  blocks <- .duration_fragment_blocks(dn, sessions, censored)
  frames <- Map(function(fragments, label) {
    if (!nrow(fragments)) {
      return(data.frame(
        session = character(), from = character(), to = character(),
        raw_spell = integer(), measure = character(), value = numeric(),
        stringsAsFactors = FALSE
      ))
    }
    raw_groups <- split(seq_len(nrow(fragments)), fragments$raw_spell)
    raw_stats <- lapply(raw_groups, function(i) data.frame(
      from = fragments$from[i[1L]], to = fragments$to[i[1L]],
      raw_spell = fragments$raw_spell[i[1L]],
      duration = sum(fragments$end[i] - fragments$start[i]),
      first = min(fragments$start[i]), last = max(fragments$end[i]),
      stringsAsFactors = FALSE
    ))
    raw_stats <- do.call(rbind, raw_stats)
    if (identical(unit, "spell")) return(do.call(rbind, lapply(
      measure, function(m) data.frame(
        session = label, from = raw_stats$from, to = raw_stats$to,
        raw_spell = raw_stats$raw_spell, measure = m,
        value = raw_stats[[m]], stringsAsFactors = FALSE
      )
    )))
    key <- paste(raw_stats$from, raw_stats$to, sep = "\r")
    idx <- split(seq_len(nrow(raw_stats)), key)
    stats_tbl <- Map(function(i, pair_key) {
      pair_fragments <- fragments[
        paste(fragments$from, fragments$to, sep = "\r") == pair_key &
          !fragments$instant, , drop = FALSE
      ]
      c(
        events = length(i), total = sum(raw_stats$duration[i]),
        union = if (nrow(pair_fragments)) .union_duration(
          pair_fragments$start, pair_fragments$end
        ) else 0,
        mean = mean(raw_stats$duration[i]),
        median = stats::median(raw_stats$duration[i]),
        first = min(raw_stats$first[i]), last = max(raw_stats$last[i])
      )
    }, idx, names(idx))
    pairs <- do.call(rbind, strsplit(names(idx), "\r", fixed = TRUE))
    do.call(rbind, lapply(measure, function(m) data.frame(
      session = label, from = pairs[, 1L], to = pairs[, 2L], raw_spell = NA_integer_,
      measure = m, value = vapply(stats_tbl, `[[`, numeric(1L), m),
      stringsAsFactors = FALSE)))
  }, blocks, names(blocks))

  out <- do.call(rbind, frames)
  out <- out[order(out$measure, out$from, out$to, out$raw_spell), , drop = FALSE]
  if (!identical(sessions, "separate")) out$session <- NULL
  if (identical(unit, "pair")) out$raw_spell <- NULL
  result <- .metric(
    out, level = "edge", what = "Relationship duration", dn = dn,
    note = sprintf("durations in %s", dn$meta$time_unit)
  )
  attr(result, "raw_censoring") <- if (identical(censored, "include")) {
    "included"
  } else "excluded"
  attr(result, "duration_unit") <- unit
  attr(result, "duration_quantity") <- unique(as.character(measure))
  attr(result, "occupancy") <- "endpoint_valid_binary_intervals"
  attr(result, "vertex_rule") <- "both_endpoints_eligible_at_time"
  attr(result, "observation_rule") <- "positive_support_plus_genuine_points"
  effective_sessions <- if (identical(sessions, "bounded") &&
                            is.null(dn$meta$sessions)) "collapse" else sessions
  attr(result, "session_aggregation") <- switch(
    effective_sessions, collapse = "labels_erased", bounded = "session_local_then_union",
    separate = "session_local"
  )
  result
}


# ===========================================================================
# burstiness()
# ===========================================================================

#' Burstiness and memory of each vertex's activity
#'
#' @description
#' Whether a vertex acts in bursts or at a steady pace. Burstiness compares
#' the spread of the gaps between a vertex's events with their average: it
#' approaches `1` for increasingly heterogeneous sequences, has theoretical
#' reference value `0` for a Poisson process, and is `-1` for a metronome. The
#' memory coefficient asks a different question -- whether a short gap tends
#' to be followed by another short gap.
#'
#' Two vertices can post the same number of times and differ entirely on both.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure One or more of `"burstiness"`, `"memory"`, `"events"` and
#'   `"mean_gap"`.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#'
#' @return A `dynet_metric` at node level with no time column: one row per
#'   vertex and measure. Attributes record the event identity, dispersion,
#'   memory, loop, weight, and session-gap conventions as
#'   `event_identity = "incident_spell_start"`, `dispersion = "population"`,
#'   `memory = "lag1_pearson"`, `loop_contribution = "one_event"`,
#'   `weights = "ignored"`, and mode-specific `session_gaps`.
#'
#' @details
#' One raw spell row contributes its start time once to each distinct incident
#' vertex. A self-loop is one event, equal-time rows remain distinct events,
#' direction does not alter incidence, and interval ends and weights are
#' ignored. Sorted equal times therefore create legitimate zero gaps.
#' Explicitly onset-censored limits are not observed onset events and are
#' excluded; terminus censoring does not affect this onset sequence.
#'
#' If the usable interevent gaps are \eqn{\tau_1,\ldots,\tau_k}, burstiness is
#' \deqn{B=(\sigma-\mu)/(\sigma+\mu),}
#' where \eqn{\mu} is their mean and
#' \eqn{\sigma=\sqrt{k^{-1}\sum_i(\tau_i-\mu)^2}} is the population standard
#' deviation of the equal-mass empirical gap distribution. `mean_gap` needs at
#' least one gap. Burstiness needs at least two and is `NA` if every usable gap
#' is zero. Its finite-sample range is `[-1, 1)`.
#'
#' Memory is the ordinary Pearson correlation between consecutive gaps. It
#' needs at least two adjacent-gap pairs and nonzero variation on both sides;
#' otherwise it is `NA`. In `sessions = "bounded"`, primitive gaps and adjacent
#' pairs are formed within each session and then pooled, so no cross-session
#' gap is introduced. Collapse includes calendar gaps after erasing labels;
#' separate returns session-local blocks over the fixed vertex universe.
#'
#' @references
#' Goh, K.-I., & Barabasi, A.-L. (2008). Burstiness and memory in complex
#' systems. *Europhysics Letters*, 81(4), 48002, equations 1 and 4.
#' \doi{10.1209/0295-5075/81/48002}
#'
#' @examples
#' dn <- dynet(school_contacts)
#' burstiness(dn)
#'
#' @export
burstiness <- function(dn, measure = c("burstiness", "memory", "events"),
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

  parts <- .split_sessions(
    dn, if (identical(sessions, "separate")) "separate" else "collapse"
  )
  frames <- Map(function(enc, label) {
    raw_time <- enc$raw_event_start
    eligible <- .time_in_observation(dn, raw_time) &
      !enc$raw_event_onset_censored
    event_time <- if (!is.null(dn$meta$observations)) {
      .observed_time(dn, raw_time)
    } else raw_time
    per_node <- lapply(seq_len(enc$n), function(vertex) {
      rows <- which((enc$raw_from == vertex | enc$raw_to == vertex) & eligible)
      if (identical(sessions, "bounded") && !is.null(dn$meta$sessions)) {
        session_levels <- unique(enc$raw_event_session)
        sequences <- split(
          event_time[rows],
          factor(enc$raw_event_session[rows], levels = session_levels)
        )
        .burst_stats_sequences(sequences)
      } else {
        .burst_stats(event_time[rows])
      }
    })
    data.frame(session = label, node = rep(enc$names, times = length(measure)),
               measure = rep(measure, each = enc$n),
               value = unlist(lapply(measure, function(m)
                 vapply(per_node, `[[`, numeric(1L), m)), use.names = FALSE),
               stringsAsFactors = FALSE)
  }, parts, names(parts))

  out <- .metric(
    do.call(rbind, frames), level = "node", what = "Burstiness", dn = dn,
    note = "1 is the bursty limit, 0 is the Poisson reference, -1 is regular"
  )
  attr(out, "event_identity") <- "incident_spell_start"
  attr(out, "dispersion") <- "population"
  attr(out, "memory") <- "lag1_pearson"
  attr(out, "loop_contribution") <- "one_event"
  attr(out, "weights") <- "ignored"
  attr(out, "raw_censoring") <- "censored_onsets_excluded"
  attr(out, "session_gaps") <- switch(
    sessions, collapse = "included", bounded = "excluded",
    separate = "session_local"
  )
  out
}

#' Burstiness statistics for one vertex's event times
#' @param times Numeric vector of event times.
#' @return A named numeric vector with `burstiness`, `memory`, `events`,
#'   `mean_gap`.
#' @keywords internal
.burst_stats <- function(times) {
  .burst_stats_sequences(list(times))
}

#' Primitive gaps and lag pairs for burstiness statistics
#'
#' Each supplied event-time sequence is sorted independently. This keeps
#' session walls out of both the pooled gaps and the pooled adjacent-gap pairs.
#'
#' @param sequences List of numeric event-time vectors.
#' @return A list containing the event count, pooled gaps, and a two-column
#'   table of within-sequence adjacent-gap pairs.
#' @examples
#' Dynet:::.burst_primitives(list(c(0, 1, 2), c(100, 102, 106)))
#' @keywords internal
.burst_primitives <- function(sequences) {
  sequences <- lapply(sequences, sort)
  gaps_by_sequence <- lapply(sequences, diff)
  pair_tables <- lapply(gaps_by_sequence, function(one) {
    if (length(one) < 2L) return(NULL)
    data.frame(left = one[-length(one)], right = one[-1L])
  })
  pair_tables <- Filter(Negate(is.null), pair_tables)
  pairs <- if (length(pair_tables)) {
    do.call(rbind, pair_tables)
  } else {
    data.frame(left = numeric(), right = numeric())
  }
  list(
    events = sum(lengths(sequences)),
    gaps = unlist(gaps_by_sequence, use.names = FALSE),
    pairs = pairs
  )
}

#' Burstiness statistics pooled over one or more event sequences
#'
#' Gaps and lag pairs are formed inside each supplied sequence before pooling,
#' which is how bounded sessions exclude cross-wall intervals.
#'
#' @param sequences List of numeric event-time vectors.
#' @return A named numeric vector with `burstiness`, `memory`, `events`, and
#'   `mean_gap`.
#' @examples
#' Dynet:::.burst_stats_sequences(list(c(0, 1, 2), c(100, 101, 102)))
#' @keywords internal
.burst_stats_sequences <- function(sequences) {
  primitive <- .burst_primitives(sequences)
  gaps <- primitive$gaps
  n <- length(gaps)
  out <- c(burstiness = NA_real_, memory = NA_real_,
           events = primitive$events, mean_gap = NA_real_)
  if (n == 0L) return(out)
  out[["mean_gap"]] <- mean(gaps)
  if (n >= 2L) {
    gap_scale <- max(abs(gaps))
    if (gap_scale > 0) {
      stable_scale <- gap_scale < sqrt(.Machine$double.xmin) ||
        gap_scale > sqrt(.Machine$double.xmax)
      normalized <- if (stable_scale) gaps / gap_scale else gaps
      mu <- mean(normalized)
      sigma <- sqrt(mean((normalized - mu)^2))
      burstiness <- (sigma - mu) / (sigma + mu)
      out[["burstiness"]] <- max(
        -1, min(1 - .Machine$double.eps / 2, burstiness)
      )
    }
  }
  pairs <- primitive$pairs
  if (nrow(pairs) >= 2L) {
    left_scale <- max(abs(pairs$left))
    right_scale <- max(abs(pairs$right))
    if (left_scale > 0 && right_scale > 0) {
      left <- pairs$left / left_scale
      right <- pairs$right / right_scale
      left <- left - mean(left)
      right <- right - mean(right)
      denominator <- sqrt(sum(left^2)) * sqrt(sum(right^2))
      if (denominator > 0) {
        out[["memory"]] <- max(
          -1, min(1, sum(left * right) / denominator)
        )
      }
    }
  }
  out
}
