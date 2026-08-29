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

#' Earliest feasible entry from a possibly open ready time
#'
#' `ready_attained = FALSE` means the traveller is ready arbitrarily close
#' before `ready` but not at it: the from-below convention the backward search
#' uses for suprema, applied to a forward infimum. Entry then happens just
#' before `ready` inside any domain that contains it, or exactly at the onset
#' of a later domain, whichever is earlier.
#'
#' @param domains One atom's feasible entry domains.
#' @param ready Earliest permitted entry.
#' @param ready_attained Whether entry exactly at `ready` is permitted.
#' @return Named numeric `value` (`NA_real_` when no entry exists) and
#'   logical-as-numeric `attained`.
#' @keywords internal
.path_forward_entry_open <- function(domains, ready, ready_attained) {
  if (isTRUE(ready_attained)) {
    value <- .path_forward_entry(domains, ready)
    return(c(value = value, attained = !is.na(value)))
  }
  if (!nrow(domains)) return(c(value = NA_real_, attained = FALSE))
  inside <- domains$start < ready & ready <= domains$end
  later <- domains$start >= ready &
    (domains$start < domains$end | domains$end_closed)
  if (any(inside)) return(c(value = ready, attained = FALSE))
  if (!any(later)) return(c(value = NA_real_, attained = FALSE))
  c(value = min(domains$start[later]), attained = TRUE)
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

#' Atom and entry-domain tables for one encoding
#'
#' Both depend only on the encoding and the traversal time, so a caller that
#' runs many searches on one encoding computes them once.
#'
#' @param enc Encoded edge list.
#' @param traversal_time Nonnegative duration per hop.
#' @return A list of `atoms` and `domains`.
#' @keywords internal
.path_search_tables <- function(enc, traversal_time) {
  atoms <- .canonical_path_atoms(enc)
  list(atoms = atoms, domains = .path_entry_domains(atoms, traversal_time))
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
#' @param criterion Which optimisation problem to solve.
#' @param max_states State budget; only `criterion = "foremost"` can reach it.
#' @param origin_attained Whether the anchor is ready exactly at `origin`.
#'   `FALSE` makes a forward source ready arbitrarily close before `origin`,
#'   so arrivals can be unattained infima, mirroring backward suprema.
#' @param prepared Atom and domain tables from [.path_search_tables()], which
#'   a caller running many searches on one encoding computes once.
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
                                 traversal_time = 0,
                                 criterion = "foremost_then_shortest",
                                 max_states = 1e5, origin_attained = TRUE,
                                 prepared = NULL) {
  direction <- match.arg(direction)
  prepared <- prepared %||% .path_search_tables(enc, traversal_time)
  atoms <- prepared$atoms
  domains <- prepared$domains
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
  attained <- isTRUE(origin_attained)
  hops <- 0L
  count <- 1
  via_atom <- NA_integer_
  pred_state <- list(integer(0))
  pred_atom <- list(integer(0))
  state_index <- new.env(hash = TRUE, parent = emptyenv())
  # The pure foremost family keeps every vertex-simple journey attaining the
  # earliest arrival, including ones longer than the minimum. Two prefixes at
  # the same appearance with different vertex sets extend differently, so the
  # state must carry its vertex set; this is exact enumeration of the family
  # and is budgeted by `max_states`. The other criteria keep only minimum-hop
  # prefixes per appearance, which are simple by construction.
  simple_family <- identical(criterion, "foremost")
  visited <- list(source)
  forward <- identical(direction, "forward")
  if (simple_family) {
    # Exact pruning of dead prefixes. The optimum per endpoint comes from the
    # tractable search; a prefix sitting at `v` at time `t` can only belong to
    # the family of an unvisited endpoint `z` if a completion from `v` still
    # attains that optimum, and the latest (forward) or earliest (backward)
    # time at which that is possible is the label the opposite-direction
    # search anchored at `z`'s optimum assigns to `v`. Dropping prefixes that
    # fail this for every unvisited endpoint changes no count.
    ahead <- .optimal_path_search(
      enc, source, origin, direction, lower, upper, traversal_time,
      prepared = prepared
    )
    optimum <- ahead$arrival
    live <- which(is.finite(optimum))
    completion <- matrix(if (forward) -Inf else Inf, n, n)
    completion[, live] <- vapply(live, function(endpoint) {
      .optimal_path_search(
        enc, endpoint, optimum[[endpoint]],
        if (forward) "backward" else "forward", lower, upper, traversal_time,
        prepared = prepared
      )$arrival
    }, numeric(n))
  }
  prefix_alive <- function(v, value, set) {
    if (value == optimum[[v]]) return(TRUE)
    open <- setdiff(live, set)
    if (!length(open)) return(FALSE)
    if (forward) any(value <= completion[v, open]) else
      any(value >= completion[v, open])
  }

  state_key <- function(v, value, is_attained, set = NULL) {
    if (value == 0) value <- 0
    key <- paste(v, sprintf("%.17g", value), as.integer(is_attained),
                 sep = "\r")
    if (simple_family) key <- paste(key, paste(set, collapse = ","), sep = "\r")
    key
  }
  assign(state_key(source, origin, attained, source), 1L, envir = state_index)

  add_candidate <- function(v, value, is_attained, depth, parent, atom) {
    set <- NULL
    if (simple_family) {
      if (v %in% visited[[parent]]) return(FALSE)
      set <- sort(c(visited[[parent]], v))
      if (!prefix_alive(v, value, set)) return(FALSE)
    }
    key <- state_key(v, value, is_attained, set)
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
    if (id > max_states) {
      stop(errorCondition(
        sprintf(paste0(
          "The %s journey family from %s exceeds the state budget of %s; ",
          "counting every vertex-simple foremost journey is exhaustive. ",
          "Raise `max_states` or use criterion = \"foremost_then_shortest\"."),
          sQuote(criterion), sQuote(enc$names[[source]]),
          format(max_states, big.mark = ",")),
        class = "dynet_path_family_too_large", call = NULL
      ))
    }
    vertex[[id]] <<- v
    time[[id]] <<- value
    attained[[id]] <<- is_attained
    hops[[id]] <<- depth
    count[[id]] <<- count[[parent]]
    via_atom[[id]] <<- atom
    pred_state[[id]] <<- parent
    pred_atom[[id]] <<- atom
    if (simple_family) visited[[id]] <<- set
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
          entry <- .path_forward_entry_open(
            domains[[row]], time[[parent]], attained[[parent]]
          )
          value <- unname(entry[["value"]])
          candidate <- value + traversal_time
          usable <- !is.na(value) && candidate <= upper
          if (!usable) next
          added <- add_candidate(
            atoms$to[[row]], candidate, as.logical(entry[["attained"]]),
            depth, parent, row
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
  .finalize_optimal_search(search, criterion)
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

.finalize_optimal_search <- function(search,
                                     criterion = "foremost_then_shortest") {
  rule <- .criterion_select(criterion)
  state <- search$state
  n <- search$n
  forward <- identical(search$direction, "forward")
  arrival <- rep(if (forward) Inf else -Inf, n)
  attained <- rep(FALSE, n)
  n_hops <- rep(NA_integer_, n)
  path_cost <- rep(NA_real_, n)
  n_paths <- rep(0, n)
  selected_states <- vector("list", n)
  for (endpoint in seq_len(n)) {
    ids <- which(state$vertex == endpoint)
    if (length(ids) == 0L) next
    # The primary key is whatever this criterion optimises. Only `time` is
    # direction-sensitive: a backward search maximises departure.
    primary <- state[[rule$primary]][ids]
    take_max <- forward == FALSE && identical(rule$primary, "time")
    best <- if (take_max) max(primary) else min(primary)
    ids <- ids[primary == best]
    arrival[[endpoint]] <- if (identical(rule$primary, "time")) {
      best
    } else if (forward) min(state$time[ids]) else max(state$time[ids])
    # An optimum is attained when some state at it is; otherwise it is a
    # backward supremum or a forward infimum with no realising journey.
    has_optimum <- any(state$attained[ids])
    attained[[endpoint]] <- has_optimum
    if (!has_optimum) next
    ids <- ids[state$attained[ids]]
    if (!is.null(rule$secondary)) {
      secondary <- state[[rule$secondary]][ids]
      take_max2 <- forward == FALSE && identical(rule$secondary, "time")
      best2 <- if (take_max2) max(secondary) else min(secondary)
      ids <- ids[secondary == best2]
    }
    # A family whose journeys differ in length has no single hop count.
    family_hops <- unique(state$hops[ids])
    n_hops[[endpoint]] <- if (length(family_hops) == 1L) family_hops else
      NA_integer_
    path_cost[[endpoint]] <- if (identical(rule$cost, "hops")) {
      n_hops[[endpoint]]
    } else arrival[[endpoint]]
    n_paths[[endpoint]] <- Reduce(
      .path_count_add, state$count[ids], init = 0
    )
    selected_states[[endpoint]] <- ids
  }
  search$arrival <- arrival
  search$attained <- attained
  search$n_hops <- n_hops
  search$path_cost <- path_cost
  search$n_paths <- n_paths
  search$criterion <- criterion
  search$selected_states <- selected_states
  search
}

#' The optimal-family selection rule for one criterion
#'
#' Each criterion is a different optimisation problem over the same feasible
#' journey set, so it selects a different family of optimal journeys and can
#' report a different answer. This returns the primary key to optimise and the
#' tie-break applied within it.
#'
#' @param criterion One of `"foremost_then_shortest"`, `"min_hops"` or
#'   `"foremost"`.
#' @return A list with `primary` and `secondary` (`NULL` when the criterion
#'   applies no tie-break), each naming a state field, plus `cost` naming the
#'   field the criterion optimised.
#' @keywords internal
.criterion_select <- function(criterion) {
  switch(criterion,
    foremost_then_shortest = list(primary = "time", secondary = "hops",
                                  cost = "time"),
    min_hops = list(primary = "hops", secondary = "time", cost = "hops"),
    foremost = list(primary = "time", secondary = NULL, cost = "time"),
    stop(errorCondition(sprintf("Unknown path criterion %s.",
                                sQuote(criterion)),
                        class = "dynet_bad_input", call = NULL))
  )
}

#' Whether a criterion minimises or maximises its cost
#' @param criterion A path criterion accepted by [paths()].
#' @return `"minimum"` or `"maximum"`.
#' @keywords internal
.criterion_optimality <- function(criterion) {
  switch(criterion,
    foremost_then_shortest = "minimum",
    min_hops = "minimum",
    foremost = "minimum",
    fastest = "minimum",
    latest_departure = "maximum",
    stop(errorCondition(sprintf("Unknown path criterion %s.",
                                sQuote(criterion)),
                        class = "dynet_bad_input", call = NULL))
  )
}

#' Latest-departure journeys from one source into every target
#'
#' The latest time one can leave `source` and still reach a target `z` by
#' `upper` is exactly the latest-departure label that a backward search rooted
#' at `z` assigns to `source`. So this runs one backward search per target and
#' reads off the source's label, inheriting every session, activity, bound and
#' attainment rule unchanged. A forward search from that departure then
#' identifies the journeys of the latest-departing family: it is bounded above
#' by `upper`, so every journey it finds departs at or before the latest
#' departure, and it starts there, so every journey departs at or after it.
#' Its earliest arrival, hop count and path count are therefore those of the
#' latest-departing journeys, with the package's usual foremost-then-shortest
#' tie-break inside that family.
#'
#' @param dn A `dynet` object.
#' @param enc Encoded edge list.
#' @param source Integer source.
#' @param lower,upper Query bounds; `upper` is the deadline and must be finite.
#' @param bounded Whether sessions are walls.
#' @param traversal_time Nonnegative duration per hop.
#' @param activity_mode,activity_session As in [.optimal_bounded_search()].
#' @return A forward-shaped search object with an extra `departure` vector and
#'   the per-target forward searches under `per_target`. `arrival` is
#'   `NA_real_` for a supremum that no journey attains.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' Dynet:::.latest_departure_search(dn, enc, 1L, 0, 10, FALSE)
#' @keywords internal
.latest_departure_search <- function(dn, enc, source, lower, upper, bounded,
                                     traversal_time = 0,
                                     activity_mode = c("collapse", "separate"),
                                     activity_session = NULL) {
  activity_mode <- match.arg(activity_mode)
  stopifnot("`upper` must be a finite deadline" = is.finite(upper))
  n <- enc$n
  search_from <- function(anchor, origin, direction, origin_attained = TRUE) {
    .optimal_bounded_search(
      dn, enc, anchor, origin, direction, bounded,
      lower = lower, upper = upper, traversal_time = traversal_time,
      activity_mode = activity_mode, activity_session = activity_session,
      criterion = "foremost_then_shortest", origin_attained = origin_attained
    )
  }
  backward <- lapply(seq_len(n), function(target) {
    search_from(target, upper, "backward")
  })
  departure <- vapply(backward, function(result) {
    result$arrival[[source]]
  }, numeric(1L))
  attained <- vapply(backward, function(result) {
    result$attained[[source]]
  }, logical(1L))
  reachable <- is.finite(departure)
  # The forward search from the departure (open when the supremum is not
  # attained) identifies the latest-departing family. Its arrival is the
  # family's earliest arrival even when no journey realises the supremum;
  # hops, counts and routes exist only when one does.
  per_target <- lapply(seq_len(n), function(target) {
    if (!reachable[[target]]) return(NULL)
    forward <- search_from(source, departure[[target]], "forward",
                           origin_attained = attained[[target]])
    stopifnot(
      "internal: latest departure has no forward journey" =
        is.finite(forward$arrival[[target]])
    )
    forward
  })
  family <- .family_from_targets(per_target, n, attained)
  departure[!reachable] <- NA_real_
  duration <- family$arrival - departure
  list(
    direction = "forward", source = source, origin = lower,
    deadline = upper, names = enc$names, n = n,
    arrival = family$arrival, departure = departure, duration = duration,
    attained = attained & reachable, n_hops = family$n_hops,
    n_paths = family$n_paths, per_target = per_target,
    best_sessions = family$best_sessions,
    session_names = backward[[1L]]$session_names,
    anchor_valid = any(reachable)
  )
}

#' Read one endpoint's family off its own forward search
#' @param per_target One forward search per target, or `NULL`.
#' @param n Number of vertices.
#' @param attained Whether each target's optimum is realised by a journey.
#' @return A list of `arrival`, `n_hops`, `n_paths` and `best_sessions`.
#' @keywords internal
.family_from_targets <- function(per_target, n, attained) {
  pick <- function(field, empty) {
    vapply(seq_len(n), function(target) {
      forward <- per_target[[target]]
      if (is.null(forward)) return(empty)
      if (!identical(field, "arrival") && !attained[[target]]) return(empty)
      forward[[field]][[target]]
    }, empty)
  }
  list(
    arrival = pick("arrival", NA_real_),
    n_hops = pick("n_hops", NA_integer_),
    n_paths = pick("n_paths", 0),
    best_sessions = lapply(seq_len(n), function(target) {
      forward <- per_target[[target]]
      if (is.null(forward) || !attained[[target]] ||
            is.null(forward$best_sessions)) integer(0) else
        forward$best_sessions[[target]]
    })
  )
}

#' Candidate departures for a fastest-journey sweep
#'
#' `EA_d(z)`, the earliest arrival at `z` when the source is ready at `d`, is a
#' nondecreasing step function of `d`, so `EA_d(z) - d` is minimised at the
#' right end of one of its constant pieces. Those ends are latest-departure
#' values, which the backward recursion builds from atom-domain endpoints and
#' the query bounds shifted by whole multiples of the traversal time. Every
#' such point is a candidate, both exactly and from below (an open domain end
#' is approached but never reached), restricted to times at which the source
#' can actually depart.
#'
#' @param encodings Prepared encodings whose atom domains supply endpoints.
#' @param source Integer source.
#' @param lower,upper Query bounds.
#' @param traversal_time Nonnegative duration per hop.
#' @return A data frame of `time` and `attained`, sorted with a from-below
#'   candidate before the same exact time.
#' @keywords internal
.fastest_departure_candidates <- function(encodings, source, lower, upper,
                                          traversal_time) {
  empty <- data.frame(start = numeric(), end = numeric(),
                      end_closed = logical())
  pieces <- lapply(encodings, function(enc) {
    atoms <- .canonical_path_atoms(enc)
    domains <- .path_entry_domains(atoms, traversal_time)
    list(all = do.call(rbind, c(list(empty), domains)),
         first = do.call(rbind, c(list(empty),
                                  domains[atoms$from == source])))
  })
  all <- do.call(rbind, lapply(pieces, `[[`, "all"))
  first <- do.call(rbind, lapply(pieces, `[[`, "first"))
  n_shift <- if (traversal_time > 0) {
    max(vapply(encodings, function(enc) enc$n, integer(1L))) - 1L
  } else 0L
  shifts <- seq.int(-n_shift, n_shift) * traversal_time
  points <- unique(c(all$start, all$end, lower, upper))
  points <- points[is.finite(points)]
  times <- unique(as.vector(outer(points, shifts, `+`)))
  times <- times[times >= lower & times <= upper]
  exact <- vapply(times, function(t) {
    t == lower || any(first$start <= t &
                        (t < first$end | (t == first$end & first$end_closed)))
  }, logical(1L))
  below <- vapply(times, function(t) {
    any(first$start < t & t <= first$end)
  }, logical(1L))
  out <- rbind(
    data.frame(time = times[below], attained = rep(FALSE, sum(below))),
    data.frame(time = times[exact], attained = rep(TRUE, sum(exact)))
  )
  out <- out[order(out$time, out$attained), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Fastest journeys from one source into every target
#'
#' For a fixed source-ready time the problem is prefix-optimal again, so the
#' minimum duration into `z` is the minimum over departures `d` of
#' `EA_d(z) - d`, where `EA_d(z)` is a nondecreasing step function of `d`.
#' Each constant piece of it is best at its right end, which is the latest
#' departure achieving that arrival. The search therefore alternates: a
#' forward search from the current departure gives the piece's arrival, a
#' backward search from that arrival gives the piece's latest departure, and
#' the first candidate departure after it starts the next piece. Candidates
#' come from [.fastest_departure_candidates()], which contains every jump
#' point, so no piece is skipped. Forward searches are cached across targets.
#'
#' A piece's duration is attained only when both its arrival and its
#' departure are; a minimiser, if one exists, is exactly such a piece, so the
#' minimum is realised iff some minimising piece is. Among equal durations
#' the earliest departure wins unless it is unattained and a later one is
#' realised. Hops, counts and routes come from a forward search rooted at the
#' winning departure, whose earliest-arrival journeys all depart exactly then,
#' so the family is fastest, then earliest departure, then fewest hops.
#'
#' @inheritParams .latest_departure_search
#' @return A forward-shaped search object with `departure` and `duration`
#'   vectors and the per-target forward searches under `per_target`.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' Dynet:::.fastest_search(dn, enc, 1L, 0, 10, FALSE)
#' @keywords internal
.fastest_search <- function(dn, enc, source, lower, upper, bounded,
                            traversal_time = 0,
                            activity_mode = c("collapse", "separate"),
                            activity_session = NULL) {
  activity_mode <- match.arg(activity_mode)
  n <- enc$n
  session_walls <- bounded && !is.null(dn$meta$sessions)
  encodings <- if (session_walls) {
    groups <- split(seq_along(enc$from), enc$session)
    Map(function(rows, label) {
      .prepare_path_encoding(dn, .subset_path_encoding(enc, rows),
                             session = label, erase_sessions = FALSE)
    }, groups, names(groups))
  } else {
    list(.prepare_path_encoding(
      dn, enc, session = activity_session,
      erase_sessions = identical(activity_mode, "collapse")
    ))
  }
  candidates <- .fastest_departure_candidates(
    encodings, source, lower, upper, traversal_time
  )
  # Candidates are sorted by time with a from-below candidate before the
  # same exact time; "after" is that lexicographic order.
  after <- function(time, attained) {
    candidates$time > time |
      (candidates$time == time & candidates$attained & !attained)
  }
  span <- max(1, diff(range(c(lower, candidates$time))))
  tolerance <- sqrt(.Machine$double.eps) * span

  cache <- new.env(hash = TRUE, parent = emptyenv())
  table_cache <- new.env(hash = TRUE, parent = emptyenv())
  n_searches <- 0L
  search <- function(anchor, origin, direction, origin_attained) {
    key <- paste(anchor, sprintf("%.17g", origin), direction,
                 as.integer(origin_attained), sep = "\r")
    if (exists(key, envir = cache, inherits = FALSE)) {
      return(get(key, envir = cache, inherits = FALSE))
    }
    n_searches <<- n_searches + 1L
    result <- .optimal_bounded_search(
      dn, enc, anchor, origin, direction, bounded,
      lower = lower, upper = upper, traversal_time = traversal_time,
      activity_mode = activity_mode, activity_session = activity_session,
      criterion = "foremost_then_shortest", origin_attained = origin_attained,
      table_cache = table_cache
    )
    assign(key, result, envir = cache)
    result
  }

  pieces_for <- function(target) {
    best <- list(duration = NA_real_, departure = NA_real_,
                 departure_attained = FALSE, arrival = NA_real_,
                 attained = FALSE)
    floor <- if (target == source) 0 else traversal_time
    index <- 1L
    # Pieces are visited in departure order; each needs the previous one's
    # latest departure, a sequential dependency.
    while (index <= nrow(candidates)) {
      forward <- search(source, candidates$time[[index]], "forward",
                        candidates$attained[[index]])
      arrival <- forward$arrival[[target]]
      if (!is.finite(arrival)) break
      arrival_attained <- forward$attained[[target]]
      if (arrival == candidates$time[[index]]) {
        # Arriving when one departed pins the departure: the latest departure
        # lies between the candidate and the arrival, which coincide.
        departure <- arrival
        departure_attained <- arrival_attained
      } else {
        backward <- search(target, arrival, "backward", arrival_attained)
        departure <- backward$arrival[[source]]
        departure_attained <- backward$attained[[source]]
        stopifnot("internal: fastest piece has no departure" =
                    is.finite(departure))
      }
      duration <- arrival - departure
      realised <- arrival_attained && departure_attained
      improves <- is.na(best$duration) || duration < best$duration - tolerance
      ties <- !improves && abs(duration - best$duration) <= tolerance &&
        realised && !best$attained
      if (improves || ties) {
        best <- list(duration = duration, departure = departure,
                     departure_attained = departure_attained,
                     arrival = arrival, attained = realised)
      }
      # Nothing beats an attained duration at the floor, and ties keep the
      # earliest departure, which this already is.
      if (best$attained && best$duration <= floor + tolerance) break
      later <- which(after(departure, departure_attained))
      if (!length(later)) break
      index <- min(later)
    }
    best
  }
  pieces <- lapply(seq_len(n), pieces_for)
  field <- function(name, empty) {
    vapply(pieces, function(piece) piece[[name]], empty)
  }
  departure <- field("departure", NA_real_)
  departure_attained <- field("departure_attained", FALSE)
  attained <- field("attained", FALSE)
  reachable <- !is.na(departure)
  per_target <- lapply(seq_len(n), function(target) {
    if (!reachable[[target]]) return(NULL)
    search(source, departure[[target]], "forward",
           departure_attained[[target]])
  })
  family <- .family_from_targets(per_target, n, attained)
  list(
    direction = "forward", source = source, origin = lower,
    names = enc$names, n = n,
    arrival = family$arrival, departure = departure,
    duration = field("duration", NA_real_), attained = attained,
    n_hops = family$n_hops, n_paths = family$n_paths,
    per_target = per_target, best_sessions = family$best_sessions,
    session_names = per_target[[source]]$session_names,
    anchor_valid = any(reachable), n_searches = n_searches
  )
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
#' @param activity_mode,activity_session Session handling for vertex activity.
#' @param criterion Which optimisation problem to solve.
#' @param max_states State budget for `criterion = "foremost"`.
#' @param origin_attained Whether the anchor is ready exactly at `origin`.
#' @param table_cache An environment in which atom and domain tables are
#'   shared across the searches of one query, or `NULL`.
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
                                    activity_session = NULL,
                                    criterion = "foremost_then_shortest",
                                    max_states = 1e5, origin_attained = TRUE,
                                    table_cache = NULL) {
  activity_mode <- match.arg(activity_mode)
  run <- function(sub, session = activity_session,
                  erase_sessions = identical(activity_mode, "collapse")) {
    sub <- .prepare_path_encoding(
      dn, sub, session = session, erase_sessions = erase_sessions
    )
    # Within one query the prepared encoding for a given session split is
    # always the same, so its tables can be shared across searches.
    prepared <- NULL
    if (!is.null(table_cache)) {
      key <- paste(session %||% "", erase_sessions, sep = "\r")
      if (!exists(key, envir = table_cache, inherits = FALSE)) {
        assign(key, .path_search_tables(sub, traversal_time),
               envir = table_cache)
      }
      prepared <- get(key, envir = table_cache, inherits = FALSE)
    }
    .optimal_path_search(
      sub, source, origin, direction, lower, upper, traversal_time, criterion,
      max_states = max_states, origin_attained = origin_attained,
      prepared = prepared
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
    realized <- candidates[vapply(per[candidates], function(result) {
      result$attained[[endpoint]]
    }, logical(1L))]
    attained[[endpoint]] <- length(realized) > 0L
    if (!length(realized)) next
    candidates <- realized
    hop_values <- vapply(per[candidates], function(result) {
      result$n_hops[[endpoint]]
    }, integer(1L))
    if (identical(criterion, "foremost")) {
      # Every session attaining the optimum contributes its whole family.
      winners <- candidates
      family_hops <- unique(hop_values)
      n_hops[[endpoint]] <- if (length(family_hops) == 1L) family_hops else
        NA_integer_
    } else {
      best_hops <- min(hop_values)
      winners <- candidates[hop_values == best_hops]
      n_hops[[endpoint]] <- best_hops
    }
    n_paths[[endpoint]] <- Reduce(.path_count_add, vapply(
      per[winners], function(result) result$n_paths[[endpoint]], numeric(1L)
    ), init = 0)
    best_sessions[[endpoint]] <- winners
  }
  if (any(vapply(per, function(result) result$anchor_valid, logical(1L)))) {
    # The valid empty journey is session-vacuous in bounded mode.
    arrival[[source]] <- origin
    attained[[source]] <- isTRUE(origin_attained)
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
  if (!is.null(search$per_target)) {
    return(.optimal_endpoint_routes(search$per_target[[endpoint]], endpoint))
  }
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
  # A latest-departure search reports its supremum in `departure`; that is
  # what decides reachability there, and `arrival` is already NA when the
  # supremum is not attained.
  reachable <- is.finite(search$departure %||% search$arrival)
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
  if (!is.null(search$departure)) {
    paths <- data.frame(
      paths[c("node", "reachable", "arrival_time")],
      departure_time = search$departure,
      duration = search$duration,
      paths[c("attained", "latency", "n_hops", "n_paths")],
      stringsAsFactors = FALSE
    )
  }
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
#' @param criterion Which optimisation problem to solve.
#'   `"foremost_then_shortest"` (the default, and what every earlier release
#'   computed) takes the earliest arrival and, among journeys attaining it, the
#'   fewest hops. `"min_hops"` takes the fewest time-respecting contacts and,
#'   among those, the earliest arrival. `"foremost"` is pure earliest arrival
#'   with no tie-break: the whole family of vertex-simple journeys attaining
#'   it, so `n_paths` counts every one and `n_hops` is `NA` when they differ
#'   in length. Counting foremost paths is #P-hard in general (Buss et al.,
#'   2024), so the family is enumerated exactly, keeping only prefixes that
#'   can still attain some endpoint's optimum; the search raises
#'   `dynet_path_family_too_large` if it exceeds `max_states`. `"fastest"`
#'   minimises journey duration, arrival minus departure, the one criterion
#'   that measures transit rather than clock position; among equally fast
#'   journeys it takes the earliest departure, then the fewest hops. Its
#'   minimum can be an infimum with no minimising journey (a departure that
#'   approaches an interval's excluded terminus), reported with
#'   `attained = FALSE` and an empty family. `"latest_departure"` asks the planning
#'   question: leaving `from`, how late can one set off and still reach each
#'   vertex by `end`? It is a forward query and needs a finite deadline, so
#'   `end` (or `at`) must be given unless the network has an explicit
#'   observation window; combining it with `direction = "backward"` is an
#'   error, because the target-pivoted latest departure is what a backward
#'   query already reports. These are different problems and can select
#'   different journeys; only reachability is identical across criteria.
#' @param direction `"forward"` traces where the vertex can reach;
#'   `"backward"` traces who could have reached it.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end Inclusive lower and upper traversal-time bounds. Interval
#'   spells remain terminus-exclusive. When these are supplied, use them
#'   instead of `at`.
#' @param traversal_time Nonnegative duration charged for every hop, in the
#'   network's time unit. A calendar network also accepts a scalar `difftime`.
#' @param max_states For `criterion = "foremost"` only: the largest number of
#'   search states one source may expand before the family is declared too
#'   large. Supplying it with any other criterion is an error.
#'
#' @return An object of class `"dynet_paths"`: a tidy data frame with one row
#'   per vertex and columns `node`, `reachable`, `arrival_time`, `attained`
#'   (whether that optimum itself is realized), `latency` (time taken from the
#'   source), `n_hops`, and the exact count `n_paths`. Under
#'   `criterion = "latest_departure"` a `departure_time` column follows
#'   `arrival_time`, holding the latest departure supremum from `from`, and a
#'   `duration` column; `arrival_time`, `n_hops` and `n_paths` then describe
#'   the journeys that depart exactly then (earliest arrival, then fewest
#'   hops, within that family). Under `criterion = "fastest"` the same two
#'   columns hold the fastest journey's departure and its duration. In both
#'   cases an unattained optimum keeps its limiting departure, arrival and
#'   duration but has `n_hops = NA` and `n_paths = 0`. Bounded mode adds `path_session` and
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
#' A latest-departure query is solved by time reversal: the latest departure
#' from `from` into a vertex `z` by `end` is the label a backward search rooted
#' at `z` assigns to `from`, so one backward search per vertex answers it with
#' every session, activity and attainment rule inherited unchanged. In
#' particular each target inherits the backward anchor rule and must be active
#' at `end`; the empty journey departs from `from` at `end` itself. The
#' `optimality` attribute records `"maximum"` for this criterion and
#' `"minimum"` for the others, and `deadline` records the resolved `end`.
#'
#' A fastest query is a sweep over candidate departures: for a fixed
#' source-ready time the problem is prefix-optimal again, so the minimum
#' duration is the minimum over departures `d` of the earliest arrival from
#' `d` minus `d`. The candidates are the atom-domain endpoints (shifted by
#' whole multiples of `traversal_time`), each taken exactly and from below,
#' at which the source can depart; one forward search runs per candidate.
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
#' Buss, S., Molter, H., Niedermeier, R., & Rymar, M. (2024). Algorithmic
#' aspects of temporal betweenness. *Network Science*, 12(2), 160-188.
#'
#' Wu, H., Cheng, J., Huang, S., Ke, Y., Lu, Y., & Xu, Y. (2014). Path
#' problems in temporal graphs. *Proceedings of the VLDB Endowment*, 7(9),
#' 721-732.
#'
#' Bui-Xuan, B., Ferreira, A., & Jarry, A. (2003). Computing shortest, fastest,
#' and foremost journeys in dynamic networks. *International Journal of
#' Foundations of Computer Science*, 14(2), 267-285.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' paths(dn, from = "Ana")
#' paths(dn, from = "Ana", start = 0, end = 10)
#' paths(dn, from = "Ana", criterion = "latest_departure", end = 10)
#'
#' # Every earliest-arrival journey, not only the shortest ones
#' few <- dynet(data.frame(from = c("A", "A", "B", "C"),
#'                         to = c("D", "B", "C", "D"),
#'                         time = c(4, 1, 2, 4)),
#'              format = "contact", directed = TRUE)
#' paths(few, from = "A", criterion = "foremost")
#' paths(few, from = "A", criterion = "fastest")
#' summary(paths(dn, from = "Ana"))
#'
#' @export
paths <- function(dn, from, at = NULL,
                      direction = c("forward", "backward"),
                      criterion = c("foremost_then_shortest", "min_hops",
                                    "foremost", "fastest", "latest_departure"),
                      sessions = c("bounded", "collapse", "separate"),
                      start = NULL, end = NULL, traversal_time = 0,
                      max_states = 1e5) {
  budget_given <- !missing(max_states)
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  direction <- match.arg(direction)
  criterion <- match.arg(criterion)
  latest <- identical(criterion, "latest_departure")
  fastest <- identical(criterion, "fastest")
  if (fastest && identical(direction, "backward")) {
    stop(errorCondition(
      "`criterion = \"fastest\"` is a forward query from `from`; it has no backward form yet.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (budget_given && !identical(criterion, "foremost")) {
    stop(errorCondition(
      "`max_states` applies only to criterion = \"foremost\", the one exhaustive family.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  .check(
    "`max_states` must be a single number of at least 1." =
      is.numeric(max_states) && length(max_states) == 1L &&
        is.finite(max_states) && max_states >= 1
  )
  if (latest && identical(direction, "backward")) {
    stop(errorCondition(
      paste0("`criterion = \"latest_departure\"` is a forward query from `from`. ",
             "The latest departure of every vertex INTO a target is the existing ",
             "`paths(dn, from = <target>, direction = \"backward\", end = )`."),
      class = "dynet_bad_input", call = NULL
    ))
  }
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
      search <- if (latest) {
        .check_latest_deadline(window)
        .latest_departure_search(
          dn, enc, src, window$start, window$end, FALSE,
          traversal_time = traversal_time, activity_mode = "separate",
          activity_session = label
        )
      } else if (fastest) {
        .fastest_search(
          dn, enc, src, window$start, window$end, FALSE,
          traversal_time = traversal_time, activity_mode = "separate",
          activity_session = label
        )
      } else {
        .optimal_bounded_search(
          dn, enc, src, origin, direction, FALSE,
          lower = window$start, upper = window$end,
          traversal_time = traversal_time, activity_mode = "separate",
          activity_session = label, criterion = criterion,
          max_states = max_states
        )
      }
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
    deadlines <- vapply(blocks, function(block) {
      block$search$deadline %||% NA_real_
    }, numeric(1L))
    names(deadlines) <- names(parts)
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
    search <- if (latest) {
      .check_latest_deadline(window)
      .latest_departure_search(
        dn, enc, src, window$start, window$end, bounded,
        traversal_time = traversal_time, activity_mode = "collapse"
      )
    } else if (fastest) {
      .fastest_search(
        dn, enc, src, window$start, window$end, bounded,
        traversal_time = traversal_time, activity_mode = "collapse"
      )
    } else {
      .optimal_bounded_search(
        dn, enc, src, origin, direction, bounded,
        lower = window$start, upper = window$end,
        traversal_time = traversal_time, activity_mode = "collapse",
        criterion = criterion, max_states = max_states
      )
    }
    path_mode <- if (bounded) "bounded" else "collapse"
    out <- .optimal_paths_table(search, path_mode)
    origins <- origin
    deadlines <- window$end
    tree_previous <- NULL
    search_descriptor <- list(mode = path_mode, search = search)
  }
  rownames(out) <- NULL
  result <- structure(out, class = c("dynet_paths", "data.frame"),
                      source = base_enc$names[src], direction = direction,
                      origin = origins, time_unit = dn$meta$time_unit,
                      traversal_time = traversal_time,
                      criterion = criterion,
                      optimality = .criterion_optimality(criterion),
                      deadline = if (latest) deadlines else NULL,
                      path_mode = path_mode, optimal_search = search_descriptor,
                      tree_previous = tree_previous)
  .vertex_path_metadata(result, path_mode)
}

#' Require a finite deadline for a latest-departure query
#' @param window A resolved path window.
#' @return `NULL`, invisibly; raises `dynet_bad_input` otherwise.
#' @keywords internal
.check_latest_deadline <- function(window) {
  if (!is.finite(window$end)) {
    stop(errorCondition(
      paste0("`criterion = \"latest_departure\"` needs a deadline. Supply `end` ",
             "(or `at`), or build the network with an explicit observation window."),
      class = "dynet_bad_input", call = NULL
    ))
  }
  invisible(NULL)
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

#' Reduce reachability trees to reach and to cost measures
#'
#' Reach counts the feasible set and is the same under every criterion. The
#' cost measures summarise the optimal journeys themselves and therefore depend
#' on which criterion selected them.
#'
#' @param trees Breadth-first trees, one per source.
#' @param cost_trees Optimal-search trees, or `NULL` when no cost measure was
#'   asked for.
#' @param n Size of the vertex universe.
#' @param measure Which measures to reduce to.
#' @return A named list of numeric vectors, one per measure.
#' @keywords internal
.reachability_values <- function(trees, cost_trees, n, measure) {
  count <- vapply(trees, function(tree) as.numeric(sum(
    is.finite(tree$arrival) & seq_len(n) != tree$source
  )), numeric(1L))
  stats::setNames(lapply(measure, function(m) {
    switch(m,
      reach_count = count,
      reach = count / max(1, n - 1L),
      latency = vapply(cost_trees, function(tree) {
        target <- seq_len(n) != tree$source & is.finite(tree$arrival)
        # An empty reachable set is 0/0, so NaN, never a fabricated zero.
        if (!any(target)) return(NaN)
        mean(abs(tree$arrival[target] - tree$origin))
      }, numeric(1L)),
      hops = vapply(cost_trees, function(tree) {
        target <- seq_len(n) != tree$source & is.finite(tree$arrival)
        if (!any(target)) return(NaN)
        mean(as.numeric(tree$n_hops[target]))
      }, numeric(1L))
    )
  }), measure)
}

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
#' @param measure One or more of `"reach"`, the share of other vertices joined
#'   by a time-respecting path; `"reach_count"`, their number; `"latency"`, the
#'   mean elapsed time to reach them; and `"hops"`, the mean number of contacts
#'   taken. The source vertex is excluded from all four. The two cost measures
#'   are `NaN` when nothing is reachable, since the mean is then 0/0.
#'
#' @param criterion Which optimisation problem the journeys solve. Reach and
#'   reach count are identical under every criterion, because they depend on
#'   the feasible set rather than on which journey wins; `latency` and `hops`
#'   summarise the selected journeys and do depend on it.
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
                             measure = "reach",
                             criterion = c("foremost_then_shortest",
                                           "min_hops")) {
  sessions <- match.arg(sessions)
  criterion <- match.arg(criterion)
  .check_dynet(dn, sessions)
  direction <- match.arg(direction)
  traversal_time <- .as_traversal_time(traversal_time, dn)
  .check(
    "`measure` must be a character vector." = is.character(measure),
    "`measure` must name at least one measure." = length(measure) > 0L,
    "`measure` cannot contain missing values." = !anyNA(measure)
  )
  allowed <- c("reach", "reach_count", "latency", "hops")
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
      # Cost measures need the optimal search, which is also what temporal
      # closeness uses; that is what makes 1/latency == closeness exact rather
      # than merely close. Reach itself is criterion-invariant and keeps the
      # cheaper breadth-first walk.
      wants_cost <- any(measure %in% c("latency", "hops"))
      cost_trees <- if (!wants_cost) NULL else lapply(seq_len(enc$n), function(s)
        .optimal_bounded_search(
          dn, e2, s, t0, d, identical(sessions, "bounded"),
          lower = window$start, upper = window$end,
          traversal_time = traversal_time,
          activity_mode = if (identical(sessions, "separate")) {
            "separate"
          } else {
            "collapse"
          },
          activity_session = if (identical(sessions, "separate")) label else NULL,
          criterion = criterion
        ))
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
      .reachability_values(trees, cost_trees, enc$n, measure)
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
