# ===========================================================================
# Time-respecting paths and reachability
# ===========================================================================

.path_edge_fields <- c(
  "from", "to", "start", "end", "raw_start", "raw_end", "weight",
  "session", "instant", "observed_activity", "raw_spell", "observation",
  "fragment", "left_observation_censored", "right_observation_censored",
  "onset_censored", "terminus_censored"
)

#' Subset every row-parallel field of a path encoding
#' @param enc Encoded edge list.
#' @param rows Integer row positions.
#' @return Encoding with all edge provenance arrays aligned.
#' @keywords internal
.subset_path_encoding <- function(enc, rows) {
  fields <- .path_edge_fields[.path_edge_fields %in% names(enc)]
  enc[fields] <- lapply(fields, function(field) enc[[field]][rows])
  enc
}

#' Union continuous interval activity for positive traversal
#'
#' Overlapping or touching positive intervals for the same oriented pair form
#' one continuous activity component. Point events stay separate because they
#' trigger at one exact timestamp. Session-specific callers split the encoding
#' before this helper; collapsed callers deliberately union across labels.
#'
#' @param enc Encoded edge list from [.encode()].
#' @return An encoding with continuous positive intervals coalesced by pair.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.coalesce_traversal_intervals(Dynet:::.encode(dn))
#' @keywords internal
.coalesce_traversal_intervals <- function(enc) {
  if (!is.null(enc$observed_activity)) {
    rows <- which(enc$observed_activity)
    enc <- .subset_path_encoding(enc, rows)
  }
  interval_rows <- which(!enc$instant)
  if (length(interval_rows) < 2L) return(enc)
  keys <- paste(
    enc$from[interval_rows], enc$to[interval_rows],
    enc$observation[interval_rows] %||% 1L, sep = "\r"
  )
  groups <- split(interval_rows, keys)
  merged <- lapply(groups, function(rows) {
    rows <- rows[order(enc$start[rows], enc$end[rows])]
    starts <- enc$start[rows]
    running_end <- cummax(enc$end[rows])
    new_component <- c(
      TRUE,
      starts[-1L] > running_end[-length(running_end)]
    )
    components <- split(seq_along(rows), cumsum(new_component))
    first <- vapply(components, function(index) rows[index[1L]], integer(1L))
    data.frame(
      from = enc$from[first],
      to = enc$to[first],
      start = vapply(components, function(index) {
        min(enc$start[rows[index]])
      }, numeric(1L)),
      end = vapply(components, function(index) {
        max(enc$end[rows[index]])
      }, numeric(1L)),
      weight = enc$weight[first],
      session = enc$session[first],
      observation = enc$observation[first] %||% 1L,
      raw_spell = enc$raw_spell[first] %||% first,
      fragment = seq_along(first),
      left_observation_censored = FALSE,
      right_observation_censored = FALSE,
      onset_censored = enc$onset_censored[first],
      terminus_censored = enc$terminus_censored[first],
      instant = FALSE,
      stringsAsFactors = FALSE
    )
  })
  points <- which(enc$instant)
  point_frame <- data.frame(
    from = enc$from[points], to = enc$to[points],
    start = enc$start[points], end = enc$end[points],
    weight = enc$weight[points], session = enc$session[points],
    observation = enc$observation[points] %||% rep(1L, length(points)),
    raw_spell = enc$raw_spell[points] %||% points,
    fragment = enc$fragment[points] %||% rep(1L, length(points)),
    left_observation_censored = rep(FALSE, length(points)),
    right_observation_censored = rep(FALSE, length(points)),
    onset_censored = enc$onset_censored[points],
    terminus_censored = enc$terminus_censored[points],
    instant = rep(TRUE, length(points)), stringsAsFactors = FALSE
  )
  spells <- rbind(do.call(rbind, merged), point_frame)
  spells <- spells[order(
    spells$start, spells$end, spells$from, spells$to, spells$instant
  ), , drop = FALSE]
  fields <- c(
    "from", "to", "start", "end", "weight", "session", "instant",
    "observation", "raw_spell", "fragment", "left_observation_censored",
    "right_observation_censored", "onset_censored", "terminus_censored"
  )
  out <- enc
  out[fields] <- lapply(fields, function(field) spells[[field]])
  out$raw_start <- out$start
  out$raw_end <- out$end
  out$observed_activity <- rep(TRUE, length(out$start))
  out
}

#' Canonical transition atoms for optimal temporal paths
#'
#' A transition atom is one maximal continuous interval component or one
#' unique point contact for an oriented pair. Raw row duplication, interval
#' segmentation, weights, and (after a collapsed encoding reaches this helper)
#' session labels do not multiply paths.
#'
#' @param enc Encoded edge list from [.encode()]. Session-specific callers
#'   split the encoding before calling this helper.
#' @return A canonical encoding with a stable integer `atom_id`.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.canonical_path_atoms(Dynet:::.encode(dn))
#' @keywords internal
.canonical_path_atoms <- function(enc) {
  canonical <- .coalesce_traversal_intervals(enc)
  fields <- c("from", "to", "start", "end", "instant", "observation")
  semantic <- as.data.frame(canonical[fields], stringsAsFactors = FALSE)
  keep <- !duplicated(semantic)
  canonical <- .subset_path_encoding(canonical, which(keep))
  ord <- order(canonical$start, canonical$end, canonical$from,
               canonical$to, canonical$instant)
  canonical <- .subset_path_encoding(canonical, ord)
  canonical$atom_id <- seq_along(canonical$from)
  canonical
}

#' Prepare vertex activity for temporal traversal
#'
#' V03 keeps vertex schedules on the path encoding rather than filtering raw
#' edge rows.  This lets one canonical edge atom retain its identity when
#' activity creates several feasible timing domains.
#'
#' @param dn A `dynet` object.
#' @param enc Encoded edges.
#' @param session Optional effective session label.
#' @param erase_sessions Whether all vertex-session labels are unioned.
#' @return `enc` with an internal `path_activity` context.
#' @keywords internal
.prepare_path_encoding <- function(dn, enc, session = NULL,
                                   erase_sessions = FALSE) {
  activity <- .encode_vertex_activity(dn, enc$names)
  if (!any(activity$declared)) return(enc)
  keep <- if (erase_sessions || all(is.na(activity$session))) {
    rep(TRUE, length(activity$node))
  } else if (is.null(session) || is.na(session)) {
    is.na(activity$session)
  } else {
    is.na(activity$session) | activity$session == session
  }
  row_fields <- c("node", "start", "end", "instant", "session",
                  "observation")
  activity[row_fields] <- lapply(row_fields, function(field) {
    activity[[field]][keep]
  })
  activity$observations <- .observation_table(dn)
  activity$effective_session <- session
  activity$erase_sessions <- erase_sessions
  enc$path_activity <- activity
  enc
}

#' Whether a vertex is eligible at an exact path time
#' @param activity Internal V03 activity context, or `NULL`.
#' @param vertex Integer vertex ID.
#' @param time Numeric calendar time.
#' @return A scalar logical.
#' @keywords internal
.path_vertex_active <- function(activity, vertex, time) {
  if (is.null(activity) || !activity$declared[[vertex]]) return(TRUE)
  observations <- activity$observations
  if (!is.null(observations) && !any(
    time >= observations$start & time <= observations$end
  )) return(TRUE)
  rows <- which(activity$node == vertex)
  if (!length(rows)) return(FALSE)
  positive <- !activity$instant[rows]
  any((positive & activity$start[rows] <= time &
         time < activity$end[rows]) |
        (!positive & activity$start[rows] == time))
}

#' Positive activity components that can support interval traversal
#' @param activity Internal V03 activity context, or `NULL`.
#' @param vertex Integer vertex ID.
#' @return Two-column start/end data frame; undeclared vertices are unbounded.
#' @keywords internal
.path_vertex_components <- function(activity, vertex) {
  if (is.null(activity) || !activity$declared[[vertex]]) {
    return(data.frame(start = -Inf, end = Inf))
  }
  rows <- which(activity$node == vertex & !activity$instant)
  if (!length(rows)) return(data.frame(start = numeric(), end = numeric()))
  frame <- data.frame(start = activity$start[rows], end = activity$end[rows])
  frame <- frame[order(frame$start, frame$end), , drop = FALSE]
  starts <- frame$start
  running_end <- cummax(frame$end)
  component <- c(TRUE, starts[-1L] > running_end[-length(running_end)])
  groups <- split(seq_len(nrow(frame)), cumsum(component))
  data.frame(
    start = vapply(groups, function(index) min(frame$start[index]), numeric(1L)),
    end = vapply(groups, function(index) max(frame$end[index]), numeric(1L))
  )
}

#' Canonicalize a union of feasible entry domains
#' @param domains Data frame with `start`, `end`, and `end_closed`.
#' @return Ordered disjoint domains with inclusive left endpoints.
#' @keywords internal
.merge_path_domains <- function(domains) {
  if (!nrow(domains)) return(domains)
  domains <- unique(domains[order(domains$start, domains$end,
                                  !domains$end_closed), , drop = FALSE])
  out <- domains[1L, , drop = FALSE]
  if (nrow(domains) == 1L) return(out)
  # Union construction is sequential: each domain is compared with the
  # accumulated rightmost component.
  for (i in 2:nrow(domains)) {
    last <- nrow(out)
    if (domains$start[[i]] <= out$end[[last]]) {
      if (domains$end[[i]] > out$end[[last]]) {
        out$end[[last]] <- domains$end[[i]]
        out$end_closed[[last]] <- domains$end_closed[[i]]
      } else if (domains$end[[i]] == out$end[[last]]) {
        out$end_closed[[last]] <- out$end_closed[[last]] ||
          domains$end_closed[[i]]
      }
    } else {
      out <- rbind(out, domains[i, , drop = FALSE])
    }
  }
  rownames(out) <- NULL
  out
}

#' Derive feasible entry domains for canonical path atoms
#' @param atoms Canonical path atoms.
#' @param traversal_time Nonnegative hop duration.
#' @return A list parallel to atoms, retaining one parent atom per list item.
#' @keywords internal
.path_entry_domains <- function(atoms, traversal_time) {
  activity <- atoms$path_activity
  empty <- data.frame(start = numeric(), end = numeric(),
                      end_closed = logical())
  domains <- vector("list", length(atoms$from))
  # Atom feasibility is independent across rows; the loop preserves the
  # parent atom identity while accumulating its timing-domain union.
  for (row in seq_along(atoms$from)) {
    from <- atoms$from[[row]]
    to <- atoms$to[[row]]
    if (atoms$instant[[row]]) {
      trigger <- atoms$start[[row]]
      completion <- trigger + traversal_time
      valid <- .path_vertex_active(activity, from, trigger) &&
        .path_vertex_active(activity, to, trigger) &&
        .path_vertex_active(activity, to, completion)
      domains[[row]] <- if (valid) data.frame(
        start = trigger, end = trigger, end_closed = TRUE
      ) else empty
      next
    }

    tail <- .path_vertex_components(activity, from)
    head <- .path_vertex_components(activity, to)
    pieces <- empty
    if (traversal_time == 0) {
      if (nrow(tail) && nrow(head)) {
        cross <- merge(tail, head, by = NULL, suffixes = c("_tail", "_head"))
        lo <- pmax(atoms$start[[row]], cross$start_tail, cross$start_head)
        hi <- pmin(atoms$end[[row]], cross$end_tail, cross$end_head)
        keep <- hi > lo
        if (any(keep)) pieces <- data.frame(
          start = lo[keep], end = hi[keep], end_closed = FALSE
        )
      }
      point_rows <- which(activity$instant &
                            activity$node %in% c(from, to))
      candidates <- unique(activity$start[point_rows])
      candidates <- candidates[
        candidates >= atoms$start[[row]] & candidates < atoms$end[[row]]
      ]
      candidates <- candidates[vapply(candidates, function(one) {
        .path_vertex_active(activity, from, one) &&
          .path_vertex_active(activity, to, one)
      }, logical(1L))]
      if (length(candidates)) pieces <- rbind(
        pieces, data.frame(start = candidates, end = candidates,
                           end_closed = TRUE)
      )
    } else if (nrow(tail) && nrow(head)) {
      cross <- merge(tail, head, by = NULL, suffixes = c("_tail", "_head"))
      lo <- pmax(atoms$start[[row]], cross$start_tail, cross$start_head)
      hi <- pmin(atoms$end[[row]] - traversal_time,
                 cross$end_tail - traversal_time,
                 cross$end_head - traversal_time)
      # Each endpoint must contain completion as well as the open interior.
      closed <- vapply(seq_along(hi), function(i) {
        x <- hi[[i]]
        y <- x + traversal_time
        x >= lo[[i]] && y <= atoms$end[[row]] &&
          cross$end_tail[[i]] >= y && cross$end_head[[i]] >= y &&
          .path_vertex_active(activity, from, y) &&
          .path_vertex_active(activity, to, y)
      }, logical(1L))
      keep <- hi > lo
      if (any(keep)) pieces <- data.frame(
        start = lo[keep], end = hi[keep], end_closed = closed[keep]
      )
      point <- hi == lo & closed
      if (any(point)) pieces <- rbind(
        pieces, data.frame(start = lo[point], end = hi[point],
                           end_closed = TRUE)
      )
    }
    domains[[row]] <- .merge_path_domains(pieces)
  }
  domains
}

#' Earliest feasible entry into one atom domain
#' @param domains One atom's feasible entry domains.
#' @param ready Earliest permitted entry.
#' @return Earliest entry, or `NA_real_`.
#' @keywords internal
.path_forward_entry <- function(domains, ready) {
  if (!nrow(domains)) return(NA_real_)
  candidate <- pmax(ready, domains$start)
  usable <- candidate < domains$end |
    (candidate == domains$end & domains$end_closed)
  if (!any(usable)) return(NA_real_)
  min(candidate[usable])
}

#' Latest feasible entry supremum into one atom domain
#' @param domains One atom's feasible entry domains.
#' @param bound Downstream completion bound.
#' @param bound_attained Whether equality at `bound` is admissible.
#' @param traversal_time Hop duration.
#' @return Named numeric `value` and logical-as-numeric `attained`.
#' @keywords internal
.path_backward_entry <- function(domains, bound, bound_attained,
                                 traversal_time) {
  if (!nrow(domains) || !is.finite(bound)) {
    return(c(value = -Inf, attained = FALSE))
  }
  cap <- bound - traversal_time
  candidate <- pmin(domains$end, cap)
  membership <- candidate >= domains$start &
    (candidate < domains$end |
       (candidate == domains$end & domains$end_closed))
  downstream <- candidate + traversal_time < bound |
    (candidate + traversal_time == bound & bound_attained)
  possible <- candidate > domains$start |
    (candidate == domains$start & membership & downstream)
  if (!any(possible)) return(c(value = -Inf, attained = FALSE))
  value <- max(candidate[possible])
  realized <- any(candidate == value & membership & downstream & possible)
  c(value = value, attained = realized)
}

#' Attach the frozen V03 traversal contract to a result
#' @param out Public path or temporal metric result.
#' @param mode Effective session aggregation mode.
#' @return `out` with V03 metadata attributes.
#' @keywords internal
.vertex_path_metadata <- function(out, mode) {
  attr(out, "vertex_path_rule") <- "endpoint_activity_gated"
  attr(out, "vertex_anchor") <- "exact_required"
  attr(out, "vertex_waiting") <- "allowed_through_inactivity"
  attr(out, "interval_vertex_occupancy") <- "both_endpoints_continuous_closed"
  attr(out, "point_vertex_occupancy") <-
    "both_at_trigger_receiver_at_completion"
  attr(out, "activity_domain_identity") <- "parent_canonical_atom"
  attr(out, "vertex_observation") <-
    "observed_support_with_unobserved_time_unconstrained"
  attr(out, "vertex_session_aggregation") <- switch(
    mode, collapse = "labels_erased", bounded = "session_integral_winner",
    separate = "session_local", mode
  )
  out
}

#' Add exact temporal-path counts
#'
#' Base-R doubles represent every integer through `2^53` exactly. This helper
#' rejects an addition before that range would be exceeded.
#'
#' @param left,right Nonnegative exact counts.
#' @return Their exact numeric sum.
#' @examples
#' Dynet:::.path_count_add(2, 3)
#' @keywords internal
.path_count_add <- function(left, right) {
  limit <- 2^53
  if (any(left > limit - right)) {
    stop(errorCondition(
      "The number of optimal temporal paths exceeds the exact counting limit (2^53).",
      class = "dynet_path_overflow", call = NULL
    ))
  }
  left + right
}

#' Build the state DAG for shortest-foremost temporal paths
#'
#' States are exact vertex appearances. Only minimum-hop prefixes at the same
#' appearance are retained, while every distinct appearance time remains.
#' Contact-labelled predecessor arcs preserve recurrent-contact multiplicity.
#' Backward states additionally carry attainment because an unattained suffix
#' can become attained when an incoming contact caps it strictly below its
#' supremum.
#'
#' @param enc Encoded edge list.
#' @param source Integer source (forward) or target (backward).
#' @param origin Source-ready time or target deadline.
#' @param direction Search direction.
#' @param lower,upper Inclusive query bounds.
#' @param traversal_time Nonnegative duration charged per hop.
#' @return An internal optimal-path search object.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.optimal_path_search(
#'   Dynet:::.encode(dn), 1L, 0, "forward", upper = 10
#' )
#' @keywords internal
.optimal_path_search <- function(enc, source, origin,
                                 direction = c("forward", "backward"),
                                 lower = -Inf, upper = Inf,
                                 traversal_time = 0) {
  direction <- match.arg(direction)
  atoms <- .canonical_path_atoms(enc)
  domains <- .path_entry_domains(atoms, traversal_time)
  n <- enc$n
  anchor_valid <- .path_vertex_active(enc$path_activity, source, origin)
  if (!anchor_valid) {
    return(list(
      direction = direction, source = source, origin = origin,
      names = enc$names, n = n, atoms = atoms, anchor_valid = FALSE,
      state = list(
        vertex = integer(), time = numeric(), attained = logical(),
        hops = integer(), count = numeric(), pred_state = list(),
        pred_atom = list()
      ),
      arrival = rep(if (identical(direction, "forward")) Inf else -Inf, n),
      attained = rep(FALSE, n), n_hops = rep(NA_integer_, n),
      n_paths = rep(0, n), selected_states = vector("list", n)
    ))
  }
  vertex <- source
  time <- origin
  attained <- TRUE
  hops <- 0L
  count <- 1
  via_atom <- NA_integer_
  pred_state <- list(integer(0))
  pred_atom <- list(integer(0))
  state_index <- new.env(hash = TRUE, parent = emptyenv())

  state_key <- function(v, value, is_attained) {
    if (value == 0) value <- 0
    paste(v, sprintf("%.17g", value), as.integer(is_attained), sep = "\r")
  }
  assign(state_key(source, origin, TRUE), 1L, envir = state_index)

  add_candidate <- function(v, value, is_attained, depth, parent, atom) {
    key <- state_key(v, value, is_attained)
    if (exists(key, envir = state_index, inherits = FALSE)) {
      id <- get(key, envir = state_index, inherits = FALSE)
      if (hops[[id]] < depth) return(FALSE)
      if (hops[[id]] == depth) {
        count[[id]] <<- .path_count_add(count[[id]], count[[parent]])
        pred_state[[id]] <<- c(pred_state[[id]], parent)
        pred_atom[[id]] <<- c(pred_atom[[id]], atom)
      }
      return(FALSE)
    }
    id <- length(vertex) + 1L
    vertex[[id]] <<- v
    time[[id]] <<- value
    attained[[id]] <<- is_attained
    hops[[id]] <<- depth
    count[[id]] <<- count[[parent]]
    via_atom[[id]] <<- atom
    pred_state[[id]] <<- parent
    pred_atom[[id]] <<- atom
    assign(key, id, envir = state_index)
    TRUE
  }

  # Hop layers are sequential: layer h depends on the complete h - 1 layer.
  for (depth in seq_len(max(0L, n - 1L))) {
    parents <- which(hops == depth - 1L)
    added <- FALSE
    for (parent in parents) {
      rows <- if (identical(direction, "forward")) {
        which(atoms$from == vertex[[parent]])
      } else {
        which(atoms$to == vertex[[parent]])
      }
      if (length(rows) == 0L) next
      for (row in rows) {
        if (identical(direction, "forward")) {
          ready <- time[[parent]]
          entry <- .path_forward_entry(domains[[row]], ready)
          candidate <- entry + traversal_time
          usable <- !is.na(entry) && candidate <= upper
          if (!usable) next
          added <- add_candidate(
            atoms$to[[row]], candidate, TRUE, depth, parent, row
          ) || added
        } else {
          bound <- time[[parent]]
          bound_attained <- attained[[parent]]
          entry <- .path_backward_entry(
            domains[[row]], bound, bound_attained, traversal_time
          )
          candidate <- unname(entry[["value"]])
          candidate_attained <- as.logical(entry[["attained"]])
          usable <- is.finite(candidate)
          usable <- usable && (candidate > lower ||
            (candidate == lower && candidate_attained))
          if (!usable) next
          added <- add_candidate(
            atoms$from[[row]], candidate, candidate_attained,
            depth, parent, row
          ) || added
        }
      }
    }
    if (!added && !any(hops == depth)) break
  }

  search <- list(
    direction = direction, source = source, origin = origin,
    names = enc$names, n = n, atoms = atoms, anchor_valid = TRUE,
    state = list(vertex = vertex, time = time, attained = attained,
                 hops = hops, count = count,
                 pred_state = pred_state, pred_atom = pred_atom)
  )
  .finalize_optimal_search(search)
}

#' Select each endpoint's shortest-foremost state family
#' @param search Raw state-DAG search.
#' @return `search` with compact endpoint arrays and selected state IDs.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' raw <- Dynet:::.optimal_path_search(enc, 1L, 0, upper = 10)
#' Dynet:::.finalize_optimal_search(raw)
#' @keywords internal
.finalize_optimal_search <- function(search) {
  state <- search$state
  n <- search$n
  forward <- identical(search$direction, "forward")
  arrival <- rep(if (forward) Inf else -Inf, n)
  attained <- rep(FALSE, n)
  n_hops <- rep(NA_integer_, n)
  n_paths <- rep(0, n)
  selected_states <- vector("list", n)
  for (endpoint in seq_len(n)) {
    ids <- which(state$vertex == endpoint)
    if (length(ids) == 0L) next
    best <- if (forward) min(state$time[ids]) else max(state$time[ids])
    ids <- ids[state$time[ids] == best]
    arrival[[endpoint]] <- best
    if (!forward) {
      has_optimum <- any(state$attained[ids])
      attained[[endpoint]] <- has_optimum
      if (!has_optimum) next
      ids <- ids[state$attained[ids]]
    } else {
      attained[[endpoint]] <- TRUE
    }
    best_hops <- min(state$hops[ids])
    ids <- ids[state$hops[ids] == best_hops]
    n_hops[[endpoint]] <- best_hops
    n_paths[[endpoint]] <- Reduce(
      .path_count_add, state$count[ids], init = 0
    )
    selected_states[[endpoint]] <- ids
  }
  search$arrival <- arrival
  search$attained <- attained
  search$n_hops <- n_hops
  search$n_paths <- n_paths
  search$selected_states <- selected_states
  search
}

#' Run an optimal path search with optional session walls
#' @param dn A `dynet` object.
#' @param enc Encoded edge list.
#' @param source Integer source/target.
#' @param origin Query anchor.
#' @param direction Search direction.
#' @param bounded Whether sessions are walls.
#' @param lower,upper Query bounds.
#' @param traversal_time Nonnegative duration per hop.
#' @return A direct or session-envelope optimal search.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' Dynet:::.optimal_bounded_search(
#'   dn, enc, 1L, 0, "forward", FALSE, upper = 10
#' )
#' @keywords internal
.optimal_bounded_search <- function(dn, enc, source, origin, direction,
                                    bounded, lower = -Inf, upper = Inf,
                                    traversal_time = 0,
                                    activity_mode = c("collapse", "separate"),
                                    activity_session = NULL) {
  activity_mode <- match.arg(activity_mode)
  run <- function(sub, session = activity_session,
                  erase_sessions = identical(activity_mode, "collapse")) {
    sub <- .prepare_path_encoding(
      dn, sub, session = session, erase_sessions = erase_sessions
    )
    .optimal_path_search(
    sub, source, origin, direction, lower, upper, traversal_time
    )
  }
  if (!bounded || is.null(dn$meta$sessions)) return(run(enc))
  groups <- split(seq_along(enc$from), enc$session)
  missing <- setdiff(dn$meta$sessions, names(groups))
  if (length(missing)) groups <- c(
    groups, stats::setNames(rep(list(integer()), length(missing)), missing)
  )
  per <- Map(function(rows, label) {
    sub <- .subset_path_encoding(enc, rows)
    run(sub, session = label, erase_sessions = FALSE)
  }, groups, names(groups))
  forward <- identical(direction, "forward")
  n <- enc$n
  arrival <- rep(if (forward) Inf else -Inf, n)
  attained <- rep(FALSE, n)
  n_hops <- rep(NA_integer_, n)
  n_paths <- rep(0, n)
  best_sessions <- vector("list", n)
  for (endpoint in seq_len(n)) {
    values <- vapply(per, function(result) result$arrival[[endpoint]],
                     numeric(1L))
    finite <- is.finite(values)
    if (!any(finite)) next
    best <- if (forward) min(values[finite]) else max(values[finite])
    candidates <- which(finite & values == best)
    arrival[[endpoint]] <- best
    if (!forward) {
      realized <- candidates[vapply(per[candidates], function(result) {
        result$attained[[endpoint]]
      }, logical(1L))]
      attained[[endpoint]] <- length(realized) > 0L
      if (!length(realized)) next
      candidates <- realized
    } else {
      attained[[endpoint]] <- TRUE
    }
    hop_values <- vapply(per[candidates], function(result) {
      result$n_hops[[endpoint]]
    }, integer(1L))
    best_hops <- min(hop_values)
    winners <- candidates[hop_values == best_hops]
    n_hops[[endpoint]] <- best_hops
    n_paths[[endpoint]] <- Reduce(.path_count_add, vapply(
      per[winners], function(result) result$n_paths[[endpoint]], numeric(1L)
    ), init = 0)
    best_sessions[[endpoint]] <- winners
  }
  if (any(vapply(per, function(result) result$anchor_valid, logical(1L)))) {
    # The valid empty journey is session-vacuous in bounded mode.
    arrival[[source]] <- origin
    attained[[source]] <- TRUE
    n_hops[[source]] <- 0L
    n_paths[[source]] <- 1
    best_sessions[[source]] <- integer(0)
  }
  list(
    direction = direction, source = source, origin = origin,
    names = enc$names, n = n, arrival = arrival, attained = attained,
    n_hops = n_hops, n_paths = n_paths, per_session = per,
    best_sessions = best_sessions, session_names = names(per),
    anchor_valid = any(vapply(per, function(result) {
      result$anchor_valid
    }, logical(1L)))
  )
}

#' Earliest-arrival times from one source
#'
#' Relaxation continues until no arrival time improves. A single forward sweep
#' is not enough: an edge with an early onset but a late terminus can be
#' boarded long after it first appears, so its usefulness may only become
#' apparent once a later edge has been relaxed.
#'
#' @param enc Encoded edge list from [.encode()].
#' @param source Integer index of the source vertex.
#' @param t0 Time at which the source becomes active.
#' @param max_sweeps Iteration cap.
#' @param upper Latest admissible traversal time.
#' @param traversal_time Nonnegative duration charged for every hop.
#' @return A list with `arrival`, `previous`, `source` and `origin`.
#'
#' @details
#' Forward traversal follows non-strict, vertex-simple temporal journeys.
#' Waiting is allowed. At zero traversal duration, a positive interval
#' `[start, end)` can be entered after arrival only strictly before `end`, and
#' a point event transmits exactly at its timestamp. With positive duration,
#' continuous interval activity is unioned by oriented pair and the complete
#' traversal must fit inside one activity component; completion exactly at its
#' terminus is allowed. A point event triggers at its timestamp and reaches the
#' endpoint after the same delay. Consequently equal-time point chains compose
#' only when the traversal duration is zero.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.temporal_bfs(Dynet:::.encode(dn), source = 1L, t0 = 0)
#' @keywords internal
.temporal_bfs <- function(enc, source, t0, max_sweeps = NULL, upper = Inf,
                          traversal_time = 0) {
  search <- .optimal_path_search(
    enc, source, t0, "forward", upper = upper,
    traversal_time = traversal_time
  )
  previous <- rep(NA_integer_, search$n)
  # Each predecessor is read independently from one selected optimal state.
  for (endpoint in seq_len(search$n)) {
    ids <- search$selected_states[[endpoint]]
    if (!length(ids)) next
    parent <- search$state$pred_state[[ids[[1L]]]]
    if (length(parent)) previous[[endpoint]] <-
      search$state$vertex[[parent[[1L]]]]
  }
  list(arrival = search$arrival, previous = previous, source = source,
       origin = t0, attained = search$attained,
       anchor_valid = search$anchor_valid)
}

#' Latest-departure suprema into one target
#'
#' @param enc Encoded edge list from [.encode()].
#' @param target Integer index of the target vertex.
#' @param deadline Latest permitted arrival time at the target.
#' @param max_sweeps Iteration cap.
#' @param lower Earliest admissible traversal time.
#' @param traversal_time Nonnegative duration charged for every hop.
#' @return A list with `arrival`, `attained`, `previous`, `source` and
#'   `origin`. Here `arrival` contains latest-departure suprema and `previous`
#'   points from each predecessor toward the target.
#'
#' @details
#' Backward traversal is evaluated in original time. At zero traversal
#' duration, an interval's latest usable entry can equal its excluded terminus
#' only as an unattained supremum. With positive duration, entry at
#' `end - traversal_time` is attained because occupancy finishes exactly at
#' `end`. The `attained` state preserves both cases and prevents an exact point
#' event from composing through an unavailable downstream bound.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.temporal_bfs_backward(
#'   Dynet:::.encode(dn), target = 1L, deadline = 10
#' )
#' @keywords internal
.temporal_bfs_backward <- function(enc, target, deadline,
                                   max_sweeps = NULL, lower = -Inf,
                                   traversal_time = 0) {
  search <- .optimal_path_search(
    enc, target, deadline, "backward", lower = lower,
    traversal_time = traversal_time
  )
  previous <- rep(NA_integer_, search$n)
  # Each successor is read independently from one selected backward state.
  for (endpoint in seq_len(search$n)) {
    ids <- search$selected_states[[endpoint]]
    if (!length(ids)) next
    parent <- search$state$pred_state[[ids[[1L]]]]
    if (length(parent)) previous[[endpoint]] <-
      search$state$vertex[[parent[[1L]]]]
  }
  list(arrival = search$arrival, attained = search$attained,
       previous = previous, source = target, origin = deadline,
       anchor_valid = search$anchor_valid)
}

#' Follow a predecessor chain back to the source
#' @param previous Integer vector of predecessors.
#' @param source Source vertex index.
#' @param target Target vertex index.
#' @return An integer vector from source to target, or `integer(0)`.
#' @keywords internal
.trace <- function(previous, source, target) {
  path <- target
  seen <- rep(FALSE, length(previous))
  cur <- target
  while (!identical(cur, source)) {
    if (is.na(previous[cur]) || seen[cur]) return(integer(0))
    seen[cur] <- TRUE
    cur <- previous[cur]
    path <- c(cur, path)
  }
  path
}

#' Reverse a network in time, for latest-departure computations
#' @param enc Encoded edge list.
#' @return An encoded edge list with direction and time both reversed.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.reverse_time(Dynet:::.encode(dn))
#' @keywords internal
.reverse_time <- function(enc) {
  out <- enc
  out$from  <- enc$to
  out$to    <- enc$from
  out$start <- -enc$end
  out$end   <- -enc$start
  if (!is.null(enc$raw_start)) {
    out$raw_start <- -enc$raw_end
    out$raw_end <- -enc$raw_start
  }
  out$reversed <- !isTRUE(enc$reversed)
  out
}

#' Run reachability with sessions acting as walls
#' @param dn A `dynet` object.
#' @param enc Encoded edge list.
#' @param source Source vertex index.
#' @param t0 Start time.
#' @param bounded Whether a path must stay within one session.
#' @param upper Latest admissible traversal time.
#' @param traversal_time Nonnegative duration charged for every hop.
#' @return A BFS result list.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.bfs_bounded(
#'   dn, Dynet:::.encode(dn), source = 1L, t0 = 0, bounded = FALSE
#' )
#' @keywords internal
.bfs_bounded <- function(dn, enc, source, t0, bounded, upper = Inf,
                         traversal_time = 0,
                         activity_mode = c("collapse", "separate"),
                         activity_session = NULL) {
  activity_mode <- match.arg(activity_mode)
  if (!bounded || is.null(dn$meta$sessions)) {
    enc <- .prepare_path_encoding(
      dn, enc, session = activity_session,
      erase_sessions = identical(activity_mode, "collapse")
    )
    return(.temporal_bfs(
      enc, source, t0, upper = upper, traversal_time = traversal_time
    ))
  }
  # A bounded path may not cross a session wall, so each session is searched
  # on its own and the earliest arrival across sessions wins.
  groups <- split(seq_along(enc$from), enc$session)
  missing <- setdiff(dn$meta$sessions, names(groups))
  if (length(missing)) groups <- c(
    groups, stats::setNames(rep(list(integer()), length(missing)), missing)
  )
  per <- Map(function(rows, label) {
    sub <- .subset_path_encoding(enc, rows)
    sub <- .prepare_path_encoding(
      dn, sub, session = label, erase_sessions = FALSE
    )
    .temporal_bfs(
      sub, source, t0, upper = upper, traversal_time = traversal_time
    )
  }, groups, names(groups))
  arr <- do.call(pmin, lapply(per, `[[`, "arrival"))
  best_sessions <- lapply(seq_along(arr), function(v) {
    cand <- vapply(per, function(p) p$arrival[v], numeric(1L))
    which(is.finite(cand) & cand == arr[v])
  })
  best_sessions[[source]] <- integer(0)
  previous <- vapply(seq_along(arr), function(v) {
    selected <- best_sessions[[v]]
    if (length(selected) != 1L) return(NA_integer_)
    per[[selected]]$previous[v]
  }, integer(1L))
  list(arrival = arr, previous = previous, source = source, origin = t0,
       per_session = per, best_sessions = best_sessions,
       session_names = names(per))
}

#' Run backward reachability with sessions acting as walls
#'
#' @param dn A `dynet` object.
#' @param enc Encoded edge list.
#' @param target Target vertex index.
#' @param deadline Latest permitted arrival time at the target.
#' @param bounded Whether a path must stay within one session.
#' @param lower Earliest admissible traversal time.
#' @param traversal_time Nonnegative duration charged for every hop.
#' @return A backward BFS result list.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.bfs_backward_bounded(
#'   dn, Dynet:::.encode(dn), target = 1L, deadline = 10,
#'   bounded = FALSE
#' )
#' @keywords internal
.bfs_backward_bounded <- function(dn, enc, target, deadline, bounded,
                                  lower = -Inf, traversal_time = 0,
                                  activity_mode = c("collapse", "separate"),
                                  activity_session = NULL) {
  activity_mode <- match.arg(activity_mode)
  if (!bounded || is.null(dn$meta$sessions)) {
    enc <- .prepare_path_encoding(
      dn, enc, session = activity_session,
      erase_sessions = identical(activity_mode, "collapse")
    )
    return(.temporal_bfs_backward(
      enc, target, deadline, lower = lower,
      traversal_time = traversal_time
    ))
  }
  # A bounded journey is contained in one session. Search each session and
  # retain the greatest latest-departure supremum across those searches.
  groups <- split(seq_along(enc$from), enc$session)
  missing <- setdiff(dn$meta$sessions, names(groups))
  if (length(missing)) groups <- c(
    groups, stats::setNames(rep(list(integer()), length(missing)), missing)
  )
  per <- Map(function(rows, label) {
    sub <- .subset_path_encoding(enc, rows)
    sub <- .prepare_path_encoding(
      dn, sub, session = label, erase_sessions = FALSE
    )
    .temporal_bfs_backward(
      sub, target, deadline, lower = lower,
      traversal_time = traversal_time
    )
  }, groups, names(groups))
  latest <- do.call(pmax, lapply(per, `[[`, "arrival"))
  attained <- vapply(seq_along(latest), function(v) {
    any(vapply(per, function(result) {
      result$arrival[v] == latest[v] && result$attained[v]
    }, logical(1L)))
  }, logical(1L))
  best_sessions <- lapply(seq_along(latest), function(v) {
    candidate <- vapply(per, function(result) result$arrival[v], numeric(1L))
    candidate_attained <- vapply(per, function(result) {
      result$attained[v]
    }, logical(1L))
    which(is.finite(candidate) & candidate == latest[v] &
      candidate_attained == attained[v])
  })
  best_sessions[[target]] <- integer(0)
  previous <- vapply(seq_along(latest), function(v) {
    selected <- best_sessions[[v]]
    if (length(selected) != 1L) return(NA_integer_)
    per[[selected]]$previous[v]
  }, integer(1L))
  list(arrival = latest, attained = attained, previous = previous,
       source = target, origin = deadline, per_session = per,
       best_sessions = best_sessions, session_names = names(per))
}

#' Resolve a path traversal window
#'
#' @param dn A `dynet` object.
#' @param direction `"forward"` or `"backward"`.
#' @param at Directional compatibility alias for an anchor.
#' @param start,end Canonical traversal bounds.
#' @param default_start,default_end Default observed bounds for this encoding.
#' @param clamp_missing Whether an implicit bound may clamp to an explicit one
#'   for a non-overlapping separate session.
#' @return A list containing numeric `start` and `end`.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.path_window(dn, "forward", start = 0, end = 10)
#' @keywords internal
.path_window <- function(dn, direction, at = NULL, start = NULL, end = NULL,
                         default_start = dn$meta$time_range[["start"]],
                         default_end = dn$meta$time_range[["end"]],
                         clamp_missing = FALSE) {
  direction <- match.arg(direction, c("forward", "backward"))
  stopifnot(is.logical(clamp_missing), length(clamp_missing) == 1L,
            !is.na(clamp_missing))
  if (!is.null(at) && (!is.null(start) || !is.null(end))) {
    stop(errorCondition(
      "`at` is an alias for one path bound; use `start` and `end` for a bounded window.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  at <- .as_time(at, dn, "at")
  start <- .as_time(start, dn, "start")
  end <- .as_time(end, dn, "end")
  if (identical(direction, "forward")) {
    lower <- start %||% at %||% default_start
    upper <- end %||% if (isTRUE(dn$meta$observation_explicit)) {
      default_end
    } else Inf
    if (clamp_missing && is.null(start) && is.null(at) && lower > upper) {
      lower <- upper
    }
  } else {
    lower <- start %||% if (isTRUE(dn$meta$observation_explicit)) {
      default_start
    } else -Inf
    upper <- end %||% at %||% default_end
    if (clamp_missing && is.null(end) && is.null(at) && lower > upper) {
      upper <- lower
    }
  }
  if (isTRUE(dn$meta$observation_explicit)) {
    components <- .observation_table(dn)
    intersects <- any(lower <= components$end & upper >= components$start)
    if (!intersects) {
      stop(errorCondition(
        "The requested path range does not intersect observed support.",
        class = c("dynet_outside_observation", "dynet_bad_input"),
        call = NULL
      ))
    }
    hull <- dn$meta$observation
    lower <- max(lower, hull[["start"]])
    upper <- min(upper, hull[["end"]])
  }
  if (lower > upper) {
    stop(errorCondition(
      sprintf("Path `start` (%s) must not exceed `end` (%s).",
              format(lower), format(upper)),
      class = "dynet_bad_input", call = NULL
    ))
  }
  list(start = lower, end = upper)
}

#' Reconstruct endpoint-specific path routes
#'
#' @param bfs A forward or backward search result.
#' @param n Number of vertices.
#' @param direction `"forward"` or `"backward"`.
#' @return A list per endpoint; each element contains every best-session route.
#' @examples
#' dn <- dynet(school_contacts)
#' as.data.frame(paths(dn, from = "Ana"), what = "steps")
#' @keywords internal
.path_routes <- function(bfs, n, direction) {
  direction <- match.arg(direction, c("forward", "backward"))
  lapply(seq_len(n), function(endpoint) {
    if (!is.finite(bfs$arrival[endpoint])) return(list())
    if (endpoint == bfs$source) {
      return(list(list(vertices = bfs$source, path_session = NA_character_,
                            result = bfs)))
    }
    if (is.null(bfs$best_sessions)) {
      selected <- list(list(result = bfs, path_session = NA_character_))
    } else {
      indices <- bfs$best_sessions[[endpoint]]
      selected <- lapply(indices, function(index) list(
        result = bfs$per_session[[index]],
        path_session = bfs$session_names[index]
      ))
    }
    routes <- lapply(selected, function(choice) {
      vertices <- .trace(
        choice$result$previous, bfs$source, endpoint
      )
      if (identical(direction, "backward")) vertices <- rev(vertices)
      list(vertices = vertices, path_session = choice$path_session,
           result = choice$result)
    })
    routes[vapply(routes, function(route) length(route$vertices) > 0L,
                  logical(1L))]
  })
}

#' Build primary and step tables from one path search
#'
#' @param enc Encoded edge list.
#' @param bfs Forward or backward search result.
#' @param direction `"forward"` or `"backward"`.
#' @param mode Session mode for this result.
#' @param session_label Session label for a separate-session block.
#' @return A list with tidy `paths` and `steps` data frames.
#' @examples
#' dn <- dynet(school_contacts)
#' as.data.frame(paths(dn, from = "Ana"), what = "steps")
#' @keywords internal
.paths_tables <- function(enc, bfs, direction,
                          mode = c("collapse", "bounded", "separate"),
                          session_label = NULL) {
  direction <- match.arg(direction, c("forward", "backward"))
  mode <- match.arg(mode)
  routes <- .path_routes(bfs, enc$n, direction)
  reachable <- is.finite(bfs$arrival)
  hops <- vapply(seq_len(enc$n), function(endpoint) {
    if (endpoint == bfs$source) return(0L)
    if (!reachable[endpoint]) return(NA_integer_)
    values <- vapply(routes[[endpoint]], function(route) {
      length(route$vertices) - 1L
    }, integer(1L))
    if (length(values) == 0L || length(unique(values)) > 1L) {
      return(NA_integer_)
    }
    values[1L]
  }, integer(1L))
  path_session <- vapply(seq_len(enc$n), function(endpoint) {
    if (endpoint == bfs$source || !reachable[endpoint]) return(NA_character_)
    if (identical(mode, "separate")) return(as.character(session_label))
    labels <- unique(vapply(routes[[endpoint]], function(route) {
      route$path_session
    }, character(1L)))
    if (length(labels) == 1L && !is.na(labels)) labels else NA_character_
  }, character(1L))
  n_best_sessions <- if (identical(mode, "collapse")) {
    rep(NA_integer_, enc$n)
  } else {
    vapply(seq_len(enc$n), function(endpoint) {
      if (endpoint == bfs$source || !reachable[endpoint]) return(0L)
      length(routes[[endpoint]])
    }, integer(1L))
  }
  attained <- if (identical(direction, "backward")) {
    bfs$attained & reachable
  } else {
    reachable
  }
  latency <- if (identical(direction, "backward")) {
    bfs$origin - bfs$arrival
  } else {
    bfs$arrival - bfs$origin
  }
  latency[!reachable] <- NA_real_
  paths <- data.frame(
    node = enc$names,
    reachable = reachable,
    arrival_time = ifelse(reachable, bfs$arrival, NA_real_),
    attained = attained,
    latency = latency,
    n_hops = hops,
    stringsAsFactors = FALSE
  )
  if (identical(mode, "bounded")) {
    paths$path_session <- path_session
    paths$n_best_sessions <- n_best_sessions
  }
  if (identical(mode, "separate")) {
    paths <- data.frame(
      session = rep(as.character(session_label), enc$n),
      origin = rep(bfs$origin, enc$n), paths,
      stringsAsFactors = FALSE
    )
  }

  step_frames <- unlist(lapply(seq_len(enc$n), function(endpoint) {
    lapply(routes[[endpoint]], function(route) {
      vertices <- route$vertices
      route_session <- if (endpoint == bfs$source) {
        NA_character_
      } else if (identical(mode, "separate")) {
        as.character(session_label)
      } else {
        route$path_session
      }
      state_attained <- if (identical(direction, "backward")) {
        route$result$attained[vertices]
      } else {
        rep(TRUE, length(vertices))
      }
      frame <- data.frame(
        endpoint = rep(enc$names[endpoint], length(vertices)),
        path_session = rep(route_session, length(vertices)),
        step = seq_along(vertices) - 1L,
        node = enc$names[vertices],
        time = route$result$arrival[vertices],
        attained = state_attained,
        stringsAsFactors = FALSE
      )
      if (identical(mode, "separate")) {
        frame <- data.frame(
          session = rep(as.character(session_label), nrow(frame)), frame,
          stringsAsFactors = FALSE
        )
      }
      frame
    })
  }), recursive = FALSE)
  steps <- do.call(rbind, step_frames)
  rownames(paths) <- NULL
  rownames(steps) <- NULL
  list(paths = paths, steps = steps, routes = routes)
}

#' Expand one selected state into canonical atom-sequence routes
#' @param search A direct optimal search.
#' @param state_id Selected terminal state ID.
#' @return A list of routes, each with parallel state and atom IDs.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' search <- Dynet:::.optimal_path_search(enc, 1L, 0, upper = 10)
#' Dynet:::.expand_optimal_state(search, 1L)
#' @keywords internal
.expand_optimal_state <- function(search, state_id) {
  state <- search$state
  forward <- identical(search$direction, "forward")
  expand <- function(id) {
    if (id == 1L) {
      return(list(list(states = 1L, atoms = integer(0))))
    }
    Map(function(parent, atom) {
      prefixes <- expand(parent)
      lapply(prefixes, function(prefix) {
        if (forward) {
          list(states = c(prefix$states, id), atoms = c(prefix$atoms, atom))
        } else {
          list(states = c(id, prefix$states), atoms = c(atom, prefix$atoms))
        }
      })
    }, state$pred_state[[id]], state$pred_atom[[id]]) |>
      unlist(recursive = FALSE)
  }
  expand(state_id)
}

#' Recover all compact optimal routes for one endpoint
#' @param search Direct or bounded optimal search.
#' @param endpoint Integer endpoint.
#' @return A list of route records with state-specific labels.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' search <- Dynet:::.optimal_path_search(enc, 1L, 0, upper = 10)
#' Dynet:::.optimal_endpoint_routes(search, 1L)
#' @keywords internal
.optimal_endpoint_routes <- function(search, endpoint) {
  if (!is.finite(search$arrival[[endpoint]]) ||
      !search$attained[[endpoint]]) return(list())
  if (!is.null(search$per_session)) {
    sessions <- search$best_sessions[[endpoint]]
    if (endpoint == search$source && length(sessions) == 0L) {
      return(list(list(
        vertices = search$source, times = search$origin, attained = TRUE,
        atoms = integer(0), path_session = NA_character_
      )))
    }
    return(unlist(lapply(sessions, function(index) {
      routes <- .optimal_endpoint_routes(search$per_session[[index]], endpoint)
      lapply(routes, function(route) {
        route$path_session <- search$session_names[[index]]
        route
      })
    }), recursive = FALSE))
  }
  ids <- search$selected_states[[endpoint]]
  routes <- unlist(lapply(ids, function(id) {
    .expand_optimal_state(search, id)
  }), recursive = FALSE)
  routes <- lapply(routes, function(route) {
    list(
      vertices = search$state$vertex[route$states],
      times = search$state$time[route$states],
      attained = search$state$attained[route$states],
      atoms = route$atoms,
      path_session = NA_character_
    )
  })
  if (length(routes) > 1L) {
    signature <- vapply(routes, function(route) {
      paste(sprintf("%09d", route$atoms), collapse = "-")
    }, character(1L))
    routes <- routes[order(signature)]
  }
  routes
}

#' Build the compact primary table for an optimal search
#' @param search Direct or bounded optimal search.
#' @param mode Session mode.
#' @param session_label Separate-session label.
#' @return A tidy endpoint table.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' search <- Dynet:::.optimal_path_search(enc, 1L, 0, upper = 10)
#' Dynet:::.optimal_paths_table(search)
#' @keywords internal
.optimal_paths_table <- function(search,
                                 mode = c("collapse", "bounded", "separate"),
                                 session_label = NULL) {
  mode <- match.arg(mode)
  reachable <- is.finite(search$arrival)
  latency <- if (identical(search$direction, "backward")) {
    search$origin - search$arrival
  } else {
    search$arrival - search$origin
  }
  latency[!reachable] <- NA_real_
  paths <- data.frame(
    node = search$names,
    reachable = reachable,
    arrival_time = ifelse(reachable, search$arrival, NA_real_),
    attained = search$attained & reachable,
    latency = latency,
    n_hops = search$n_hops,
    n_paths = as.numeric(search$n_paths),
    stringsAsFactors = FALSE
  )
  if (identical(mode, "bounded")) {
    paths$path_session <- vapply(seq_len(search$n), function(endpoint) {
      winners <- search$best_sessions[[endpoint]]
      if (length(winners) == 1L) search$session_names[[winners]] else
        NA_character_
    }, character(1L))
    paths$n_best_sessions <- vapply(search$best_sessions, length, integer(1L))
  }
  if (identical(mode, "separate")) {
    paths <- data.frame(
      session = rep(as.character(session_label), search$n),
      origin = rep(search$origin, search$n), paths,
      stringsAsFactors = FALSE
    )
  }
  paths
}

#' Lazily materialize optimal route steps
#' @param descriptor Search descriptor stored on a `dynet_paths` result.
#' @return A tidy route-step data frame.
#' @examples
#' paths <- paths(dynet(school_contacts), from = "Ana")
#' Dynet:::.optimal_steps(attr(paths, "optimal_search"))
#' @keywords internal
.optimal_steps <- function(descriptor) {
  mode <- descriptor$mode
  blocks <- if (identical(mode, "separate")) descriptor$blocks else
    list(descriptor$search)
  labels <- if (identical(mode, "separate")) descriptor$labels else NA_character_
  expansion_size <- sum(vapply(blocks, function(search) {
    sum(pmin(search$n_paths, 1e6 + 1))
  }, numeric(1L)))
  if (expansion_size > 1e6) {
    stop(errorCondition(
      "Expanded optimal routes would exceed one million paths; use the compact `n_paths` result instead.",
      class = "dynet_path_expansion_too_large", call = NULL
    ))
  }
  frames <- unlist(Map(function(search, session_label) {
    unlist(lapply(seq_len(search$n), function(endpoint) {
      routes <- .optimal_endpoint_routes(search, endpoint)
      Map(function(route, path_id) {
        route_session <- if (endpoint == search$source) {
          NA_character_
        } else if (identical(mode, "separate")) {
          as.character(session_label)
        } else {
          route$path_session
        }
        frame <- data.frame(
          endpoint = rep(search$names[[endpoint]], length(route$vertices)),
          path_id = rep(as.numeric(path_id), length(route$vertices)),
          path_session = rep(route_session, length(route$vertices)),
          step = seq_along(route$vertices) - 1L,
          node = search$names[route$vertices],
          time = route$times,
          attained = route$attained,
          stringsAsFactors = FALSE
        )
        if (identical(mode, "separate")) {
          frame <- data.frame(
            session = rep(as.character(session_label), nrow(frame)), frame,
            stringsAsFactors = FALSE
          )
        }
        frame
      }, routes, seq_along(routes))
    }), recursive = FALSE)
  }, blocks, labels), recursive = FALSE)
  if (length(frames) == 0L) {
    out <- data.frame(
      endpoint = character(), path_id = numeric(),
      path_session = character(), step = integer(), node = character(),
      time = numeric(), attained = logical(), stringsAsFactors = FALSE
    )
    if (identical(mode, "separate")) out$session <- character()
    return(out)
  }
  out <- do.call(rbind, frames)
  rownames(out) <- NULL
  out
}


# ===========================================================================
# paths()
# ===========================================================================

#' Time-respecting paths from a vertex
#'
#' @description
#' Follows every time-respecting path out of (or into) one vertex and reports
#' where it gets to, when, and through whom. A path may only use edges whose
#' timing runs forward, so unlike a path in a flattened network it can never
#' travel back in time.
#'
#' The source vertex is named, not numbered. `paths(dn, from = "Ana")`
#' works; there is no vertex index to look up first.
#'
#' At the default zero traversal duration, forward paths use nondecreasing hop
#' times, so relations active at the same instant may form a multi-hop chain.
#' Waiting is allowed. Interval spells are onset-inclusive and
#' terminus-exclusive; point events trigger at their exact timestamp through a
#' distinct event rule. A positive duration separates a hop's trigger or entry
#' from its completion, as detailed below. Reach and arrival do not depend on
#' edge-row order or duplicate spell rows.
#'
#' @param dn A temporal network from [dynet()].
#' @param from Name of the vertex to start from.
#' @param at Forward source-availability time or backward arrival deadline.
#'   Defaults to the start of the observation window for forward paths and its
#'   end for backward paths. Date and date-time values use the network's time
#'   scale. It cannot be combined with `start` or `end`.
#' @param direction `"forward"` traces where the vertex can reach;
#'   `"backward"` traces who could have reached it.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end Inclusive lower and upper traversal-time bounds. Interval
#'   spells remain terminus-exclusive. When these are supplied, use them
#'   instead of `at`.
#' @param traversal_time Nonnegative duration charged for every hop, in the
#'   network's time unit. A calendar network also accepts a scalar `difftime`.
#'
#' @return An object of class `"dynet_paths"`: a tidy data frame with one row
#'   per vertex and columns `node`, `reachable`, `arrival_time`, `attained`
#'   (whether that optimum itself is realized), `latency` (time taken from the
#'   source), `n_hops`, and the exact count `n_paths`. Bounded mode adds `path_session` and
#'   `n_best_sessions`; separate mode adds `session` and `origin`. Use
#'   `as.data.frame(x, what = "steps")` for every reconstructed optimal route;
#'   its endpoint-local `path_id` distinguishes tied atom sequences.
#'
#' @details
#' A valid forward journey has distinct vertices, hop-entry times `x`, and
#' completion times `y = x + traversal_time`. The source is ready at `start`,
#' each later entry is no earlier than the preceding completion, and final
#' completion is at or before `end`. At zero duration, entry and completion
#' coincide and recover P01's nondecreasing traversal times. The empty journey
#' reaches the source at `start`. With `at`, that value supplies `start` for
#' forward paths or `end` for backward paths. Cycles are unnecessary for reach
#' and earliest arrival because deleting a repeated-vertex section and waiting
#' at that vertex preserves every later hop.
#'
#' `start` and `end` form a closed bound on the complete journey: entry may
#' equal `start` and completion may equal `end`. This does not close interval
#' activity on the right. At zero duration, an event or interval onset at
#' `end` is eligible while an interval terminating there cannot be entered.
#' With positive duration, no nonempty hop can both enter and complete at
#' `end`; `start = end` therefore leaves only the empty journey.
#'
#' Declared vertex activity gates traversal appearances. The forward source
#' must be active exactly at `start`, and the backward target exactly at `end`;
#' otherwise every fixed-universe row, including the anchor, is unreachable.
#' After a valid anchor, waiting may cross inactive periods. A zero-duration
#' hop requires both endpoints at its time. A positive-duration interval hop
#' requires both endpoints continuously on the closed traversal from entry
#' through completion. A delayed point contact requires both endpoints at its
#' trigger and the receiver again at completion, but creates no continuous
#' edge or tail occupancy. Several activity-created timing domains of one
#' canonical contact remain one path atom and cannot multiply `n_paths`.
#'
#' For backward paths, `arrival_time` is the latest-departure supremum for a
#' journey ending at the named target by the resolved `end`, and `latency` is
#' `end` minus that value. A supremum at an interval's excluded terminus need
#' not itself be an attainable departure.
#'
#' With `sessions = "bounded"`, each endpoint is optimized across complete
#' session-specific searches. A unique winner is named in `path_session`; ties
#' leave it missing and are counted in `n_best_sessions`. No merged predecessor
#' tree is exposed. The steps accessor retains a complete route from every tied
#' best session, so each route stays inside one session. With
#' `sessions = "separate"`, every session contributes a complete vertex block
#' and resolves its own default origin. In the steps table, `time` is the
#' optimal search label at that route vertex. For backward interval paths it
#' can be an unattained supremum, as indicated by `attained = FALSE`.
#'
#' With positive `traversal_time`, an interval hop entered at `x` arrives at
#' `x + traversal_time` and must fit within continuous activity for that pair;
#' overlapping or touching interval spells form one component. Completion
#' exactly at the component terminus is allowed. A point event triggers at its
#' timestamp and arrives after the same duration; it does not represent
#' continued edge activity. The query `end` bounds completion, not only entry.
#'
#' Optimal forward journeys are shortest foremost: final completion is
#' minimized first and hop count second. Journey identity is the ordered
#' sequence of canonical oriented contacts. Duplicate points, overlapping or
#' touching interval segmentation, weights, and waiting schedules do not
#' multiply paths; genuinely recurrent contacts do. `n_paths` is exact through
#' `2^53`, after which a `dynet_path_overflow` condition is raised. The empty
#' journey has one path, an unreachable endpoint has zero, and an unattained
#' backward supremum has zero because it has no maximizing journey.
#'
#' @references
#' Kempe, D., Kleinberg, J., & Kumar, A. (2002). Connectivity and inference
#' problems for temporal networks. *Journal of Computer and System Sciences*,
#' 64(4), 820-842.
#'
#' Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
#' 519(3), 97-125.
#'
#' Casteigts, A., Corsini, A., & Sarkar, W. (2024). Simple, strict, proper,
#' happy: A study of reachability in temporal graphs. *Theoretical Computer
#' Science*, 991, 114434.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' paths(dn, from = "Ana")
#' paths(dn, from = "Ana", start = 0, end = 10)
#' summary(paths(dn, from = "Ana"))
#'
#' @export
paths <- function(dn, from, at = NULL,
                      direction = c("forward", "backward"),
                      sessions = c("bounded", "collapse", "separate"),
                      start = NULL, end = NULL, traversal_time = 0) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  direction <- match.arg(direction)
  traversal_time <- .as_traversal_time(traversal_time, dn)
  .check("`from` must be a single vertex name." =
              length(from) == 1L && !is.na(from))

  base_enc <- .encode(dn)
  src <- match(as.character(from), base_enc$names)
  if (is.na(src)) {
    stop(errorCondition(
      sprintf("Vertex %s is not in this network. Vertices are: %s",
              sQuote(from), paste(utils::head(base_enc$names, 10), collapse = ", ")),
      class = "dynet_unknown_vertex", call = NULL))
  }

  if (identical(sessions, "separate")) {
    parts <- .split_sessions(dn, "separate")
    blocks <- Map(function(enc, label) {
      if (!dn$directed) {
        enc <- .undirect_or_reverse(enc, FALSE, "forward")
      }
      window <- .path_window(
        dn, direction, at, start, end,
        default_start = .encoding_time_range(dn, enc)[["start"]],
        default_end = .encoding_time_range(dn, enc)[["end"]],
        clamp_missing = TRUE
      )
      origin <- if (identical(direction, "backward")) {
        window$end
      } else {
        window$start
      }
      search <- .optimal_bounded_search(
        dn, enc, src, origin, direction, FALSE,
        lower = window$start, upper = window$end,
        traversal_time = traversal_time, activity_mode = "separate",
        activity_session = label
      )
      list(
        paths = .optimal_paths_table(search, "separate", label),
        search = search
      )
    }, parts, names(parts))
    out <- do.call(rbind, lapply(blocks, `[[`, "paths"))
    origins <- vapply(blocks, function(block) {
      unique(block$paths$origin)
    }, numeric(1L))
    names(origins) <- names(parts)
    path_mode <- "separate"
    tree_previous <- NULL
    search_descriptor <- list(
      mode = "separate", blocks = lapply(blocks, `[[`, "search"),
      labels = names(parts)
    )
  } else {
    window <- .path_window(dn, direction, at, start, end)
    enc <- base_enc
    if (!dn$directed) enc <- .undirect_or_reverse(enc, FALSE, "forward")
    origin <- if (identical(direction, "backward")) {
      window$end
    } else {
      window$start
    }
    bounded <- identical(sessions, "bounded") && !is.null(dn$meta$sessions)
    search <- .optimal_bounded_search(
      dn, enc, src, origin, direction, bounded,
      lower = window$start, upper = window$end,
      traversal_time = traversal_time, activity_mode = "collapse"
    )
    path_mode <- if (bounded) "bounded" else "collapse"
    out <- .optimal_paths_table(search, path_mode)
    origins <- origin
    tree_previous <- NULL
    search_descriptor <- list(mode = path_mode, search = search)
  }
  rownames(out) <- NULL
  result <- structure(out, class = c("dynet_paths", "data.frame"),
                      source = base_enc$names[src], direction = direction,
                      origin = origins, time_unit = dn$meta$time_unit,
                      traversal_time = traversal_time,
                      criterion = "foremost_then_shortest",
                      path_mode = path_mode, optimal_search = search_descriptor,
                      tree_previous = tree_previous)
  .vertex_path_metadata(result, path_mode)
}

#' Adapt an encoding for undirected traversal or backward search
#' @param enc Encoded edge list.
#' @param directed Whether the network is directed.
#' @param direction `"forward"` or `"backward"`.
#' @return An encoded edge list.
#' @keywords internal
.undirect_or_reverse <- function(enc, directed, direction) {
  if (!directed) {
    both <- enc
    both$from   <- c(enc$from, enc$to)
    both$to     <- c(enc$to, enc$from)
    both$start  <- rep(enc$start, 2L)
    both$end    <- rep(enc$end, 2L)
    both$weight <- rep(enc$weight, 2L)
    both$session <- rep(enc$session, 2L)
    both$instant <- rep(enc$instant, 2L)
    both$raw_start <- rep(enc$raw_start, 2L)
    both$raw_end <- rep(enc$raw_end, 2L)
    both$observed_activity <- rep(enc$observed_activity, 2L)
    both$raw_spell <- rep(enc$raw_spell, 2L)
    both$observation <- rep(enc$observation, 2L)
    both$fragment <- rep(enc$fragment, 2L)
    both$left_observation_censored <-
      rep(enc$left_observation_censored, 2L)
    both$right_observation_censored <-
      rep(enc$right_observation_censored, 2L)
    both$onset_censored <- rep(enc$onset_censored, 2L)
    both$terminus_censored <- rep(enc$terminus_censored, 2L)
    enc <- both
  }
  if (identical(direction, "backward")) enc <- .reverse_time(enc)
  enc
}


# ===========================================================================
# dyn_reachability()
# ===========================================================================

#' Reachability of every vertex
#'
#' @description
#' The number or share of other vertices each vertex can reach along
#' time-respecting paths, and the number or share that can reach it.
#' Reachability is the temporal replacement for component membership: in a
#' static network two vertices in the same component reach each other by
#' definition, whereas in a temporal network reach depends on whether the
#' timing lines up.
#'
#' @param dn A temporal network from [dynet()].
#' @param direction `"forward"`, `"backward"` or `"both"`.
#' @param at Forward source-availability time or backward arrival deadline.
#'   Defaults to the beginning or end of each observed period, respectively.
#'   Date and date-time values use the network's time scale. It cannot be
#'   combined with `start` or `end`.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end Inclusive lower and upper traversal-time bounds. Interval
#'   spells remain terminus-exclusive.
#' @param traversal_time Nonnegative duration charged for every hop, in the
#'   network's time unit. A calendar network also accepts a scalar `difftime`.
#' @param measure One or both of `"reach"`, the proportion of other vertices,
#'   and `"reach_count"`, their number. The source vertex is excluded from
#'   both.
#'
#' @return A `dynet_metric` at node level. Proportion measures are named
#'   `forward_reach` and `backward_reach`; counts are named
#'   `forward_reach_count` and `backward_reach_count`.
#'
#' @details
#' Reachability uses [paths()] traversal semantics: nondecreasing times,
#' unlimited waiting, half-open interval spells, and a separate exact timestamp
#' rule for point events. Positive `traversal_time` requires interval occupancy
#' to finish within continuous pair activity and delays a point-trigger arrival.
#' Declared vertex activity additionally requires an exact active query anchor
#' and active hop endpoints. Waiting after a valid anchor may cross vertex
#' inactivity; interval traversal requires both endpoints continuously through
#' completion, while a delayed point requires the receiver again at completion.
#' For backward reachability, the resolved `end` is a common deadline and
#' latest-departure suprema determine whether a vertex can reach the target.
#' The canonical `start` and `end` bounds apply one closed traversal-time window
#' to both forward and backward queries.
#'
#' The source is excluded: a count is the number of distinct other vertices in
#' the reachable set, not the number of journeys. A proportion divides that
#' count by the full network size minus one. It is defined as zero for a
#' singleton network. In separate-session output the same full-network
#' denominator is retained in every session block.
#'
#' In separate-session output, a session entirely outside a one-sided bound
#' contributes zero-reach rows rather than aborting the complete result. Its
#' missing implicit bound is clamped to the supplied bound, producing the
#' empty journey at that boundary and no eligible hop.
#'
#' @examples
#' # Reachability searches every ordered pair, so the example uses a small
#' # inline network to stay fast. The verb takes any `dynet`.
#' dn <- dynet(data.frame(
#'   from  = c("A", "B", "C", "A"),
#'   to    = c("B", "C", "D", "D"),
#'   start = c(0, 1, 2, 3),
#'   end   = c(1, 2, 3, 4)
#' ))
#' dyn_reachability(dn)
#' dyn_reachability(dn, direction = "forward")
#' dyn_reachability(dn, start = 0, end = 2)
#'
#' @export
dyn_reachability <- function(dn, direction = c("both", "forward", "backward"),
                             at = NULL,
                             sessions = c("bounded", "collapse", "separate"),
                             start = NULL, end = NULL, traversal_time = 0,
                             measure = "reach") {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  direction <- match.arg(direction)
  traversal_time <- .as_traversal_time(traversal_time, dn)
  .check(
    "`measure` must be a character vector." = is.character(measure),
    "`measure` must name at least one measure." = length(measure) > 0L,
    "`measure` cannot contain missing values." = !anyNA(measure)
  )
  allowed <- c("reach", "reach_count")
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown reach measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL
    ))
  }
  wanted <- if (identical(direction, "both")) c("forward", "backward") else direction

  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    vals <- lapply(wanted, function(d) {
      e2 <- .undirect_or_reverse(enc, dn$directed, "forward")
      encoding_range <- .encoding_time_range(dn, enc)
      window <- .path_window(
        dn, d, at, start, end,
        default_start = encoding_range[["start"]],
        default_end = encoding_range[["end"]],
        clamp_missing = identical(sessions, "separate")
      )
      t0 <- if (identical(d, "backward")) window$end else window$start
      trees <- lapply(seq_len(enc$n), function(s) {
        if (identical(d, "backward")) {
          .bfs_backward_bounded(
            dn, e2, s, t0, identical(sessions, "bounded"),
            lower = window$start, traversal_time = traversal_time,
            activity_mode = if (identical(sessions, "separate")) {
              "separate"
            } else {
              "collapse"
            },
            activity_session = if (identical(sessions, "separate")) label else NULL
          )
        } else {
          .bfs_bounded(
            dn, e2, s, t0, identical(sessions, "bounded"),
            upper = window$end, traversal_time = traversal_time,
            activity_mode = if (identical(sessions, "separate")) {
              "separate"
            } else {
              "collapse"
            },
            activity_session = if (identical(sessions, "separate")) label else NULL
          )
        }
      })
      .temporal_reach_values(trees, enc$n, measure)
    })
    data.frame(session = label, node = enc$names,
               measure = unlist(lapply(wanted, function(d) {
                 rep(paste0(d, "_", measure), each = enc$n)
               }), use.names = FALSE),
               value = as.numeric(unlist(vals, use.names = FALSE)),
               stringsAsFactors = FALSE)
  }, parts, names(parts))

  requested <- unique(measure)
  note <- if (identical(requested, "reach")) {
    "share of other vertices joined by a time-respecting path"
  } else if (identical(requested, "reach_count")) {
    "number of other vertices joined by a time-respecting path"
  } else {
    "count and share of other vertices joined by a time-respecting path"
  }
  out <- .metric(do.call(rbind, frames), level = "node", what = "Reachability",
                 dn = dn, note = note,
                 traversal_time = traversal_time)
  effective_mode <- if (identical(sessions, "bounded") &&
                        is.null(dn$meta$sessions)) "collapse" else sessions
  .vertex_path_metadata(out, effective_mode)
}
