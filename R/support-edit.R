# ===========================================================================
# Editing vertex activity, observation support, and sessions
# ===========================================================================

.vertex_spells_input <- function(spells) {
  keep <- c("node", "start", "end")
  if (nrow(spells) && any(!is.na(spells$session))) keep <- c(keep, "session")
  keep <- c(keep, "onset_censored", "terminus_censored")
  spells[, keep, drop = FALSE]
}

.normalize_edited_vertex_spells <- function(dn, data) {
  normalized <- .normalize_vertex_spells(
    data, dn$meta$origin, dn$meta$time_unit, dn$meta$sessions
  )
  unknown <- setdiff(unique(normalized$spells$node), dn$nodes$name)
  if (length(unknown)) {
    stop(errorCondition(
      sprintf("Unknown vertex-activity node(s): %s.",
              paste(sort(unknown), collapse = ", ")),
      class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL
    ))
  }
  normalized$spells
}

#' Replace declared vertex activity
#'
#' @param dn A temporal network.
#' @param data A vertex-spell data frame with `node`, `start`, and `end`, plus
#'   optional `session`, `onset_censored`, and `terminus_censored`. `NULL`
#'   clears explicit activity, making every retained node implicitly active.
#' @return A new `dynet` object. Overlapping or adjacent spells are
#'   canonicalized exactly as in [dynet()]. Canonical spell identifiers may
#'   therefore change.
#' @export
set_vertex_spells <- function(dn, data = NULL) {
  .check_dynet(dn, "bounded")
  vertex_spells <- if (is.null(data)) .empty_vertex_spells() else
    .normalize_edited_vertex_spells(dn, data)
  .rebuild_ties(
    dn, dn$spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), vertex_spells = vertex_spells
  )
}

#' Add declared vertex-activity spells
#' @inheritParams set_vertex_spells
#' @return A new `dynet` object with old and new activity canonicalized
#'   together.
#' @export
add_vertex_spells <- function(dn, data) {
  .check_dynet(dn, "bounded")
  if (!is.data.frame(data) || !nrow(data)) {
    stop(errorCondition("`data` must be a nonempty vertex-spell data frame.",
                        class = "dynet_bad_input", call = NULL))
  }
  existing <- .vertex_spells_input(dn$vertex_spells)
  # Reconcile optional columns before binding; the normalizer supplies false
  # censor flags and a global session when they are absent.
  canonical <- c("node", "start", "end", "session",
                 "onset_censored", "terminus_censored")
  bind_vertex <- function(x, prototype) {
    missing <- setdiff(canonical, names(x))
    for (name in missing) {
      x[[name]] <- if (identical(name, "session")) {
        rep(NA_character_, nrow(x))
      } else if (name %in% c("onset_censored", "terminus_censored")) {
        rep(FALSE, nrow(x))
      } else prototype[[name]][rep(NA_integer_, nrow(x))]
    }
    x[canonical]
  }
  existing <- bind_vertex(existing, data)
  added <- bind_vertex(data, existing)
  combined <- rbind(existing, added)
  if (is.null(dn$meta$sessions)) combined$session <- NULL
  set_vertex_spells(dn, combined)
}

#' Remove declared vertex-activity components
#'
#' @param dn A temporal network.
#' @param spells Integer positions or a logical mask over
#'   `as.data.frame(dn, what = "vertex_spells")`.
#' @return A new `dynet` object. A node with no remaining declaration becomes
#'   implicitly always active over observation support.
#' @export
remove_vertex_spells <- function(dn, spells) {
  .check_dynet(dn, "bounded")
  index <- .edit_row_selector(spells, nrow(dn$vertex_spells), "spells")
  kept <- dn$vertex_spells[-index, , drop = FALSE]
  set_vertex_spells(
    dn, if (nrow(kept)) .vertex_spells_input(kept) else NULL
  )
}

#' Update declared vertex-activity components
#'
#' @param dn A temporal network.
#' @param spells Integer positions or a logical mask over canonical vertex
#'   activity.
#' @param data One row or one row per selected component, containing fields to
#'   replace.
#' @return A new `dynet` object. Updated components are canonicalized with the
#'   retained components, so overlaps can merge and identifiers can change.
#' @export
update_vertex_spells <- function(dn, spells, data) {
  .check_dynet(dn, "bounded")
  index <- .edit_row_selector(spells, nrow(dn$vertex_spells), "spells")
  if (!is.data.frame(data) || !nrow(data) || !ncol(data) ||
      anyDuplicated(names(data))) {
    stop(errorCondition("`data` must be a nonempty update data frame.",
                        class = "dynet_bad_input", call = NULL))
  }
  if (any(names(data) %in% c("vertex_spell", "duration", "instant"))) {
    stop(errorCondition(
      "`vertex_spell`, `duration`, and `instant` are derived and read-only.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (nrow(data) != 1L && nrow(data) != length(index)) {
    stop(errorCondition(
      "`data` must have one row or one row per selected component.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (nrow(data) == 1L && length(index) > 1L) {
    data <- data[rep(1L, length(index)), , drop = FALSE]
  }
  current <- .vertex_spells_input(dn$vertex_spells)
  for (attribute in names(data)) current[[attribute]][index] <- data[[attribute]]
  set_vertex_spells(dn, current)
}

.set_observation_meta <- function(dn, observations, call) {
  meta <- dn$meta
  meta$event_range <- c(start = min(dn$spells$start), end = max(dn$spells$end))
  meta$observations <- observations
  meta$time_range <- c(start = min(observations$start), end = max(observations$end))
  meta$observation <- meta$time_range
  meta$observation_explicit <- TRUE
  meta$observation_interval <- "positive_half_open_instant_closed"
  meta$observation_clipping <- "non_destructive_measurement_view"
  meta$boundary_events <- "raw_not_fabricated"
  meta$censoring <- "not_inferred"
  meta$observation_duration <- sum(observations$duration)
  meta$observation_spells_explicit <- TRUE
  meta$observation_gap_waiting <- "allowed"
  meta$latency_clock <- "calendar"
  meta$n_bins <- sum(pmax(
    1L, as.integer(ceiling(observations$duration / meta$interval - 1e-9))
  ))
  meta$call <- call
  out <- dn
  out$meta <- meta
  out
}

#' Replace observation support
#'
#' @param dn A temporal network.
#' @param data Optional data frame with `start` and `end` observation
#'   components. Overlapping and adjacent positive components are merged.
#' @param start,end Optional scalar continuous bounds used instead of `data`.
#' @return A new `dynet` object. Raw edge and vertex spells are unchanged;
#'   only the non-destructive measurement view is replaced.
#' @export
set_observations <- function(dn, data = NULL, start = NULL, end = NULL) {
  .check_dynet(dn, "bounded")
  use_data <- !is.null(data)
  use_bounds <- !is.null(start) || !is.null(end)
  if (use_data == use_bounds) {
    stop(errorCondition(
      "Supply either `data` or scalar `start`/`end` bounds.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  observations <- if (use_data) {
    .normalize_observation_spells(data, dn$meta$origin, dn$meta$time_unit)
  } else {
    raw_range <- c(start = min(dn$spells$start), end = max(dn$spells$end))
    bounds <- .observation_bounds(
      raw_range, dn$meta$origin, dn$meta$time_unit, start, end
    )
    data.frame(
      observation = 1L, start = bounds[["start"]], end = bounds[["end"]],
      duration = bounds[["end"]] - bounds[["start"]],
      instant = bounds[["start"]] == bounds[["end"]]
    )
  }
  .set_observation_meta(dn, observations, match.call())
}

#' Restore implicit observation support
#'
#' @param dn A temporal network.
#' @return A new `dynet` object observed continuously from its earliest raw
#'   start through its latest raw end.
#' @export
clear_observations <- function(dn) {
  .check_dynet(dn, "bounded")
  meta <- dn$meta
  raw_range <- c(start = min(dn$spells$start), end = max(dn$spells$end))
  fields <- c(
    "event_range", "observation", "observation_explicit",
    "observation_interval", "observation_clipping", "boundary_events",
    "censoring", "observations", "observation_duration",
    "observation_spells_explicit", "observation_gap_waiting", "latency_clock"
  )
  meta[fields] <- NULL
  meta$time_range <- raw_range
  meta$n_bins <- max(1L, as.integer(ceiling(
    (raw_range[["end"]] - raw_range[["start"]]) / meta$interval
  )))
  meta$call <- match.call()
  out <- dn
  out$meta <- meta
  out
}

#' Assign or remove tie sessions
#'
#' @param dn A temporal network.
#' @param session A complete character vector of length one or the raw tie
#'   count. `NULL` removes all tie-session walls and erases session labels on
#'   vertex activity.
#' @return A new `dynet` object.
#' @export
set_tie_sessions <- function(dn, session = NULL) {
  .check_dynet(dn, "bounded")
  n <- nrow(dn$spells)
  if (is.null(session)) {
    value <- rep(NA_character_, n)
  } else {
    if (!is.atomic(session) || is.null(dim(session)) == FALSE ||
        !length(session) || !(length(session) %in% c(1L, n))) {
      stop(errorCondition(
        "`session` must have length one or the raw tie count.",
        class = "dynet_bad_input", call = NULL
      ))
    }
    value <- rep(as.character(session), length.out = n)
    if (anyNA(value) || any(!nzchar(trimws(value)))) {
      stop(errorCondition("Session labels must be complete and nonempty.",
                          class = "dynet_bad_input", call = NULL))
    }
  }
  spells <- dn$spells
  spells$session <- value
  vertex_spells <- dn$vertex_spells
  if (is.null(session) && nrow(vertex_spells)) {
    vertex_spells$session <- NA_character_
  }
  .rebuild_ties(
    dn, spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), vertex_spells = vertex_spells
  )
}

#' Rename session walls
#'
#' @param dn A sessioned temporal network.
#' @param mapping A named character vector from old to new labels, or an
#'   `old`/`new` data frame.
#' @return A new `dynet` object with edge and vertex session labels renamed.
#' @export
rename_sessions <- function(dn, mapping) {
  .check_dynet(dn, "bounded")
  if (is.null(dn$meta$sessions)) {
    stop(errorCondition("This temporal network has no session scheme.",
                        class = "dynet_bad_input", call = NULL))
  }
  if (is.data.frame(mapping) && all(c("old", "new") %in% names(mapping))) {
    old <- as.character(mapping$old)
    new <- as.character(mapping$new)
  } else if (is.character(mapping) && !is.null(names(mapping))) {
    old <- names(mapping)
    new <- as.character(mapping)
  } else {
    stop(errorCondition(
      "`mapping` must be a named character vector or an old/new data frame.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (!length(old) || anyNA(old) || anyNA(new) || anyDuplicated(old) ||
      any(!nzchar(trimws(new)))) {
    stop(errorCondition("Session rename mappings must be complete and unique.",
                        class = "dynet_bad_input", call = NULL))
  }
  unknown <- setdiff(old, dn$meta$sessions)
  if (length(unknown)) {
    stop(errorCondition(
      sprintf("Unknown session label(s): %s.", paste(unknown, collapse = ", ")),
      class = c("dynet_unknown_session", "dynet_bad_input"), call = NULL
    ))
  }
  unaffected <- setdiff(dn$meta$sessions, old)
  if (anyDuplicated(c(unaffected, new))) {
    stop(errorCondition("Session renaming would create duplicate labels.",
                        class = "dynet_bad_input", call = NULL))
  }
  translate <- function(value) {
    hit <- match(value, old)
    value[!is.na(hit)] <- new[hit[!is.na(hit)]]
    value
  }
  spells <- dn$spells
  spells$session <- translate(spells$session)
  vertex_spells <- dn$vertex_spells
  vertex_spells$session <- translate(vertex_spells$session)
  .rebuild_ties(
    dn, spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), vertex_spells = vertex_spells
  )
}

